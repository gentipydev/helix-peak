# Peptide Language Model: one training run, stage by stage

The home screen's last row. It shows HelixPeekLM, the backend's de novo
peptide model (`helix-peek-backend/pipeline/denovo/`), learning the curated
proteins' peptides, one stage of a training step at a time, and then the
whole run.

## What is drawn is the run itself

The page plays a recorded run, and says so. `pipeline/denovo/trace.py` drives
the engine's own `train.build` and `train.train_step`, as `train.run` drives
them, and keeps every number through read-only hooks:

- **every step**: the loss (residues and `<eos>` apart), the learning rate the
  step used, the gradients' norm before clipping and the clip applied, each
  parameter group's gradient and update norm and size, every target's loss,
  the output layer's weights and biases as the step found them, and (schema 9,
  2026-11-03, for Loop) the probabilities over the 21 tokens that can come
  next at every place, in 255ths, a kept step's the same bytes as its
  checkpoint's;
- **at each checkpoint**, everything else: the two embedding tables as the
  step found them, whole as float32 (the token embedding, 23 × 16, and the
  position embedding, 51 × 16; added 2026-10-30, kept whole since schema 2
  the same day), the
  residual stream at its six points, whole (float32, since schema 3), the
  gradient reaching each, every head's attention map (worked out again from
  the layer's input, within 4 × 10⁻⁷ of the layer's own output), what each
  block worked out on the way (schema 3: its queries, keys and values, every
  score before softmax, each head's mix of values, its feed-forward's input,
  neurons and weights; schema 4, 2026-10-31, for the Scores stage: the row its
  attention reads, evened out, its first LayerNorm's scale and shift, the
  weights and biases that make the queries, keys and values, and those whole,
  float32 rather than int8, the training byte for byte the same; schema 5,
  2026-11-01, for Attention: the output weights and biases that mix the
  heads' answers back into one row, and the mix whole, the training again
  byte for byte the same; schema 6, 2026-11-02, for Predict: the output
  layer's weights at each checkpoint, and the logits whole, the training byte
  for byte the same), the stream read out early (the final norm and the
  output layer applied at every point before it, with the step's own
  weights: a probe the Forward stage drew until 2026-11-01, kept for
  Predict's review, the last point's the model's own output), the logits and the probabilities over the 21 tokens that can
  follow, and the output layer's clipped gradient and update. `check_trace`
  holds the insides to each other: softmax of the scores is the map, each
  head's mix its shares of the values, what attention adds the output
  weights' sum of the mix, every neuron GELU of its input, and the
  feed-forward adds what the stream gained.

Recorded again, the run is the same bytes (CPU, deterministic kernels, one
thread); `trace.py --check --against <service>` is that proof against what
production serves. The run itself:

| | |
|---|---|
| data | six peptides, 174 residues: insulin A and B chains and C-peptide, relaxin A and B chains, copeptin; nothing held out |
| model | 2 blocks of 2 heads, width 16, feed-forward 64, 51 places: 8,167 parameters (recorded again at 2 × 2 on 2026-10-30, at the user's ask, for the forward pass told in three stages, now four; it was 4 × 4, 14,727 parameters, and before that 96 wide, 456,887. Sized to the six's longest, 40 places, the same evening and put back: the user chose to keep the engine's 51, `<bos>` and up to 50 residues, and to explain it on the page) |
| training | AdamW 1e−2 (at 1e−3 a model 16 wide never passes one nat in 200 steps), weight decay 0.1 on matrices, 100 warm-up steps then cosine, clip 1.0, dropout 0, all six a step, 200 steps, seed 0 |
| loss | 3.220 at step 1 (worse than uniform, 3.045) to 0.065 at step 200 |
| baselines | uniform 3.045, unigram 2.856, bigram 2.043 |
| floor | 0.060 = 6 ln 6 / 180: from `<bos>` alone nothing says which peptide comes |
| checkpoints | 1, then the first step under uniform (13), unigram (21), bigram (49), one nat (66) and a tenth of one (95), and 200 |

Dropout is off so that the forward pass drawn is the forward pass trained.

## The stages

Each is a painter in `lib/features/peptide_lm/presentation/scenes/`, a pure
function of the frame, at the checkpoint picked ("Step N ▾"); the loop plays
every step. A tap on a stage plays it once, a beat every two seconds, and it
holds on its last frame until another is tapped, or the same one again.
Beside the caption, a player of that stage alone: Replay, and Play/Pause.
The stage bar keeps its names at full size and scrolls sideways where a
phone is too narrow for all twelve; a stage played whose name stands partly
out of view is scrolled just far enough to show it whole.

1. **Tokenise.** The dataset, a peptide a row folded onto two lines where
   the canvas lets square tiles carry their numbers (one line of tall tiles
   where it does not), and under it the 23-token vocabulary on one row. A
   light crosses each peptide; every residue it passes flips into its id,
   and the vocabulary's count of it rises. `<bos>` leads each peptide from
   the first frame; `<eos>` drops in after the last residue and padding fills
   to the longest (6 × 41). Then the peptides close
   up into one matrix, a row each: the batch Forward reads, its dataset's tags
   fading where they are and the batch's (batch 2D matrix, padding) coming up
   over it. The matrix rises
   to the top, and the vocabulary turns into a list under it: one token
   after another flies up to its row, its bar swinging down from standing on
   the token to lie along the row while still short, then growing to the
   list's length, its count coming up at the row's end and its id going
   round the tile's corner to its left (two columns where one would be too
   cramped). Padding has no count: it is none of the data. The stage is 11
   beats; the vocabulary's turn is its last three. Each part is named on a
   tag, as the zoom names its parts, in the field's words: dataset, padding,
   vocabulary, token counts (on the bar of the commonest token), special
   tokens (bracketed under their ids) and token ids.
2. **Shift.** Input x and target y, one place apart, as
   `sequences.batches` cuts the batch (`frame[:, :-1]`, `frame[:, 1:]`).
   The user's ask of 2026-10-30, to keep each stage to one idea: x and y
   left Forward for a stage of their own, drawn the dataset's way, the
   vocabulary gone, as two groups, all six peptides as input x and under
   them all six again as target y, in the same columns. Each tag says
   what its group is for, beside its plate in the quiet ink: x "what the
   model reads", y "the answer key: what each place should predict" ("the
   answer key" where a phone is too narrow). Only x goes into the model;
   y is what Loss grades its guesses against, which is where it comes back
   (the user's choice of the two, the same day). It opens on Tokenise's
   last frame, pixel for pixel, and is 5 beats:
   - *the open* (1½ beats): the vocabulary's list, bars, counts and tags
     fade; each row of the matrix opens out into its peptide again, named,
     under the `input x` tag, and lets go of the frame's last place, which
     nothing reads ("Input x: each frame less its last place, 6 × 40
     tokens");
   - *the copy* (1½ beats, the user's ask of 2026-10-30 that y be seen
     to come out of x): a copy of x lifts off it as a shadow, a few
     points under each line and faint, then falls as one block to its
     place under x, faint while it crosses x's lines and stronger once it
     has come out under the last of them, solid as it settles, and the
     `target y` tag comes in as it lands ("Target y starts as a copy of
     the same peptides"). The frame's last place, which x let go of,
     comes back in the copy as it falls;
   - *the move*: every line of the copy moves one place to the left, so
     each place of y holds the token after the same place of x ("One place
     to the left: each place's answer is the token after it"). `<bos>`
     slips off the line's left edge, never a target; the token that leaves
     a second line's start comes in at the first line's end, as text
     reflows;
   - *the padding*: the pairs whose target is padding dim ("Only x goes in;
     Loss grades each guess against y: 180 targets"; every caption keeps to
     two lines on a 375-wide phone, measured in the app's font).

   Why so few moves: what the stage must show is that y is x's own
   tokens, moved exactly one place. A copy says the first, one rigid move
   the second, and the move itself says what a target is, each token
   settling one place earlier. Both move whole groups and lines, so the eye
   follows them, not 240 tiles. Two versions came first, both the user's to
   judge on 2026-10-30: one walked the places one at a time under a veil
   over what each had not read, swept the rest in a wave and lit every pair
   at once (too much for what the stage has to show; not seeing ahead is
   Forward's to draw, in its head maps); one put each line of y right under
   its line of x, which read as four alternating lines a peptide (confusing,
   so back to two groups). The tiles are the dataset's, folded onto two
   lines where both groups' tiles can still carry their ids (the Pro Max),
   else one line of tall tiles a peptide. At the user's asks the same day,
   the groups stand 28 pt apart, and the tiles fill their columns across
   the whole width, a peptide's two lines touching (the tiles' own inset
   parts them), each tile as tall as the height allows and its id drawn at
   0.62 of the tile's height (Tokenise's 0.52; `drawIdTile(numberScale:)`):
   on a Pro Max about 17 × 15 pt drawn, 9 pt ids.
3. **Embedding.** The user's ask of 2026-10-30: the lookup Forward used to
   open with, as a stage of its own, the table 16 numbers wide across the
   whole width and every number written out on a soft tile of its colour
   (the run was recorded again 16 wide for it, see above). It opens on
   Shift's last frame, pixel for pixel, and takes the engine's first steps
   (`HelixPeekLM.forward`) in 15 beats. Over the tag, a note says why each
   part happens, in the quiet ink, its parts fading out and in at the
   caption's turns, while the caption under the canvas says what happens,
   neither repeating the other (the user's ask of 2026-10-30). A live
   readout of the place being read ("S · place 9 · id 18 → row 18") was
   tried over it and removed the same evening at the user's word: it
   switched too fast to read.
   - *the table* (beats 0–2.4): y goes off to the right and the other
     peptides fade; the peptide in focus comes down to the foot, a tile a
     place, its ids kept, under its name as Shift writes it ("insulin A
     chain · 21 aa", the user's ask: the row is the first peptide, not the
     batch), which goes as its tiles go up to the rows; the token
     embedding's tokens and ids come in, top to bottom, and its rows grow
     out on the stream's own scale, then their numbers ("The token
     embedding, 23 × 16, learned with the rest of the model"; then "At step
     1 no update has moved them yet; <pad>'s row is zero at every
     checkpoint", or how many updates a later step has had). Note: "A model
     computes with numbers, not letters: each token gets 16 of its own.";
   - *the lookup* (2.4–6.6): one place at a time (three or four lit at once
     was too quick to follow; a 13 s version, the user's next ask, was then
     too slow): `<bos>` alone for a beat, then each place in turn, its tile
     at the foot and the row it reads lit together, held and let go before
     the next, each place's time falling in a line to 0.6 of the first's,
     about 0.35 s to 0.2 s for insulin A (`EmbeddingScene.slot`; a longer
     peptide is quicker in the same 3 beats); a row read stays faintly
     marked ("22 places read 12 rows of the table, C's four times"). Note:
     "The lookup is only this: the id picks its row, no arithmetic.";
   - *the gather* (6.6–11.6): the table goes, and each place's copy of the
     row it read moves to the place's own row, its numbers going before it
     moves and coming back once it has, so that rows passing one another
     never print over each other; the tile that read it goes up to label the
     row, turning back into its residue (input x embedded, 22 × 16, the
     user's word: input, as Shift names x). Slowly, at
     the user's ask, so that the row of ids is seen to stand up as the column
     of residues: one tile after another, top to bottom, over 2.4 beats, each
     flight 1.4, the peptide's name staying over the row until its last tile
     goes. A copy still waiting on the table's row lies under a place that
     has landed there, its numbers left out. Caption: "Each row is one
     place: <bos> (<), then insulin A chain's 21 residues" (each special
     token named with the glyph it is drawn as, here and in Tokenise, the
     user's ask of 2026-10-31). Once they
     have landed, the first token's two places are outlined in the accent
     (the two Cs at 6 and 7), the note naming them, and stay outlined to
     the stage's end: "At this stage the model doesn't know order: the two
     Cs at places 6 and 7 are the same row." (the user's wording, the
     claim before its example);
   - *the position embedding* (11.6–13.4): each place's own row alone, on
     its own colour scale, its numbers to two places, the rows labelled by
     place (0–21) instead of residue while they show alone, since a position
     row belongs to its place whatever sits there ("The position embedding:
     one trainable row per place, here rows 0–21 of 51", trainable and
     not learned, since at step 1 nothing is, the user's word of
     2026-10-31; note: "where it comes from: a second table in the model,
     random at first and trained like the token one / why 22 of 51: 51 is
     the model's context length, a row for each place it can hold, <bos>
     (<) and up to 50 residues; insulin A chain fills 22", the user's two
     questions answered where they arise, the model kept at the engine's 51
     places by their choice, and the words "context length" theirs, as the
     name every reader knows). 51 is the engine's `max_len`, not the
     longest peptide: copeptin, the longest, fills 40 places, so rows 40–50
     are never read and never move. The user asked where the table came
     from and why the chain stays the same while its numbers change: hence
     the place labels and the two captions;
   - *the sum, x0* (13.4–15), one screen since 2026-10-31 at the user's
     word: it had been the adding, then a still beat that only renamed the
     same numbers, its tag a beat behind them. The position rows are added,
     the residues back, a cell showing one set of numbers at a time, and the
     tag turns from the position embedding straight to `x0 = token +
     position · 22 × 16` at the same turn as the note and caption (beat
     13.4, the user's ask: the old tag lingered 0.75 beat under the new
     note), and Scores keeps it. The sum is `x0` as the engine
     makes it; the run's stored stream holds it to within its own rounding.
     Caption: "Token + position, number by number: x0, the rows every block
     reads and adds to" (the residual stream's meaning, moved here from the
     note, in plain words at the user's choice: "the residual stream each
     block adds to" read as jargon).
     The two Cs stay outlined to the end, and Scores draws the outlines
     over its own rows as it opens, fading them with the note. Note, the
     user's ask of 2026-10-31 evening: the labelled fragments ("token row:
     what it is; position row: where it sits / added: … / size: … / why
     add: … / residual stream: …") were not clear, so the note is now one
     argument, a sentence a line, the explanation the user was given in
     answer to "why do we add the token embedding with the position
     embedding": "Attention, next, reads rows as a bag, blind to their
     order. / So each token row (what) gets a position row (where) added. /
     The Cs at 6 and 7 share a token row, but now differ by place. /
     Training grows position rows from 43× smaller to 4× by step 200." (a
     fifth line, "Added, not side by side: that makes 32 numbers; layers
     take 16.", was removed at the user's word: adding matrices is
     obvious), and a last line, the end result the user asked for: "x0:
     one row per place, carrying what + where; the model's input." (with a
     causal mask a place reads only the rows up to its own, and those as a
     bag: hence "rows", not "the sequence"). The last sentence is the run's
     own, from the first checkpoint to the last at step 1, to the step in
     view later ("…to 10× by step 49"), in the past at the last ("Training
     grew…"); insulin A: 43× at step 1, 10× at 49, 4× by 200, the position
     rows growing about twelvefold while the token rows stay near 1. Each
     sentence keeps one line on an SE in the app's fonts and two in the
     tests' square font, so the note is never taller than the stage's
     others (five lines), and the caption fits the stage's own box
     at every width. The note's room is the tallest it is at any step, so a
     change of step never moves the table. "next: two blocks let each place
     read the places before it" went: Scores' first caption says it

   Every number is written to two places. At first the token rows were
   written to one, all that int8 storage (steps of 0.03) allowed; the user
   saw that then adding a position row of ±0.02 changed only 67 of insulin
   A's 352 numbers at step 1, and wrongly by a whole 0.1 where it did. So
   the run keeps both tables whole (float32, schema 2), and G at place 1
   reads −0.90 + 0.01 = −0.89; the two Cs at places 6 and 7, the same row of
   the table, part as soon as their places are added. All are as large as
   fits a cell, 9 pt at most (about 7 pt on a Pro, 5.5 on an SE), and a row
   too small for 5.5 pt is drawn in its colours alone (copeptin's 40 rows
   on an SE come close). Each row is as tall as the canvas allows for
   the longer of the vocabulary and the peptide, 22 pt at most. At the
   user's ask the matrix runs 4 pt from either side of the canvas, the id
   5 pt from its tile and the tile 3 pt from the numbers, so the numbers
   have the width (about 25 pt a cell on a Pro Max).
4. **Scores.** The user's split of 2026-10-31 (the forward pass had been
   three stages since 2026-10-30): Attention was too much at once, so block
   1's attention up to its shares is a stage of its own, 20 beats, opening on
   Embedding's last frame pixel for pixel, on its layout, a row a place, at
   the place in focus (insulin A's C11 by default). It is drawn from the run's
   schema 4, which keeps the row attention reads, the LayerNorm's scale and
   shift, the weights that make the queries, keys and values, and those whole.
   - x0's table narrows to a strip a place, and a copy of the row in focus
     lifts off and stands up on the bench at its right, its numbers beside it;
   - evened out (LayerNorm) on a chart beside it, each bar hanging from the
     mean line and coloured by its side of it, so that less the mean (C11:
     0.08 at step 1) slides the whole row onto zero as one, no bar growing
     or shrinking, and over the standard deviation (1.10) draws every bar
     in toward zero by the same factor, a z-score, a faint tail of the same
     thickness left where each bar stood (only where the bar is not). Until
     2026-11-01 the bars stood on zero, x0's outlined over them: less the
     mean shrank the positive bars and grew the negative ones, and a bar
     grown past its outline looked thinner beyond it, which the user
     disliked in Feed-forward's copy of the chart;
     then the learned scale and shift, written out where the chart was, a
     row a number, headed so it reads as the sum z-score × scale + shift =
     evened (the user found "a learned scale and shift a column" unclear,
     2026-10-31): × 1.00 + 0.00 at step 1, × 1.21 − 0.01 and the like at
     step 200;
   - the evened row times the model's own weights, the query, then the key,
     then the value (redone on 2026-10-31 at the user's ask: the strings had
     all come at once and the numbers after them, two events; it must read as
     a vector times a matrix drawn at random from a seed and nudged by every
     update; the user chose "weights first, then the row flows through" over
     strings growing a number at a time). Each part's column stands as empty
     slots, the query nearer the row than before and more room between the
     three (a step a column, its numbers and a gap of 7.5% of the bench,
     14–26 pt, the query's strings never under 52 pt where the old 10 pt gap
     allows it), with no strings yet: a first version drew the weights as a
     faint web before the row flowed (and moved the query's from step 1's to
     the checkpoint's at later steps); the user liked the animation but
     asked for no strings before it starts, the same evening. Then the row
     flows through: each number's 16 strings burst out of the row, lit, each
     carrying its number times its weight in that product's colour, a dot at
     each tip, and the number is made only as they land; the query's first
     alone and slowly (C11 at step 1: 16 products summed, −0.19; at step 200
     with its bias, −0.29), its second and third quicker, the rest in a
     cascade; the key's and the value's one cascade each, their strings
     passing behind the columns already made. Landed strings stay until the
     next part's slots come, faint (quieter still while the row flows): the
     part's 16 × 16 weights, a weight on each, in the colour of its sign, as
     strong as it against the part's largest, named on a plate under them
     (`block 1 · query weights · 16 × 16`, as x0's table is named) with where they
     stand: `random start (seed 0), no update yet` at step 1, the run's
     `attn_in` there being PyTorch's draw from seed 0, uniform within ±0.31,
     every bias 0 (the checkpoint is kept before its step's update); later,
     `random start (seed 0), then N training updates`. By rms the query's and
     key's weights move 4% by step 13, 10% by 21, 39% by 49 and 77% by 200
     (47 of the query's 256 change sign), the value's 51%. Each column then parts between its
     8th and 9th number: head 1 takes 1–8, head 2 9–16. The note says why the
     width must divide by the heads (the model refuses a width they do not,
     `d_model % nhead`) and that this 8 is the √8 of the score;
   - head 1's query and key lie down by the row in focus, every place's key
     comes out of its row, and the places after it are struck through; head
     1's tag, `block 1 · head 1 · query and keys`, names them over the keys,
     and x0's tag steps aside just before it comes (13.9–14.2), back once
     head 2's tag has gone in Attention (4.55–4.8): until 2026-11-02 the head
     tag lay on x0's, `22 × 16` showing through its plate, and the user chose
     this over leaving the head tags unnamed;
   - one score worked out, the top one (S9 at step 1): the query over the key,
     their products number by number, Σ = 3.60, ÷ √8 = 1.27, which flies to
     its place; then the query passes every key up to <bos>;
   - softmax makes the scores shares, a bar each across the bench with its
     percentage (S9 23%, I2 11%);
   - (a "why √8" part, the divisor taken back to 1 and put back with the
     bars sharpening, was removed on 2026-10-31 at the user's word: the
     explanation and its animation were redundant. The stage ends on the
     shares.)

   The shares here, and in Attention's captions, are softmax of the kept
   scores, whole (the u1 maps differed by up to 0.5 points: S9 read 24%).
5. **Attention.** It opens on Scores' last frame, in 25 beats:
   - head 1's scores give way to its shares, its keys turn into values, and
     arcs carry each share of each value into the head's eight-number answer,
     values riding them, as Scores' bars go;
   - head 2 reads in full, quicker (C11 reads C11 29%, C6 27%, C7 26% at step
     200);
   - the heads' answers sit on C11's row and take the room right of the keys
     that the arcs leave them, at least 50 pt (the user's ask, 2026-10-31,
     "there is more space"): 170 pt on a Pro Max, was 112; 132 at 402; at 375
     there is no room to spare and they stay 111;
   - an arc from a row near the answers' own rose only 6–8 pt above them, so
     head 2's lower arcs ran along head 1's segment (C11's own about 1 pt
     above it). Now both handles of such an arc are lifted just enough that,
     over the answers before its own and its own near side, it keeps half a
     row above their tops (`AttentionLayout.clearance`, at least 8 pt), plus
     half that again for each row it starts above the answers' own, so the
     lifted arcs nest instead of crossing; a lifted arc's first handle moves
     toward its value, so it climbs early and runs flatter. Every arc ends on
     the middle of its answer's top, coming straight down onto it. Arcs from
     higher rows already clear the answers and are unchanged (the user's
     ask: "a higher upper arc so they don't touch the segments before");
   - number 1 of head 1's answer, worked out (beats 4.4–13.4,
     `worked_answer.dart`). Once the answers stood side by side, the user
     asked on 2026-11-01 for what the page left unsaid: where each place's
     value comes from (Scores made only C11's: "+0.11 is the first value of
     the multiplication of the <bos> x0 embedding with the value matrix and
     that is NOT CLEAR AT ALL"), and how the values become the answer's
     numbers (only motion along the arcs showed it). Their table, place ·
     score · share · value (number 1) · share × value, summed to 0.301 →
     0.30, is what the part draws. The user's two picks: the place in focus
     and then `<bos>` through the same strings, and the other fifteen
     numbers left to a caption. Until 2026-11-02 it opened and ended on the
     frame the answers stood in, all 16 numbers written ("The heads' 8 + 8
     numbers, side by side: 16"), and it hid them to work number 1 out; the
     user asked for that frame to go: "there is no point on showing the
     values then explaining how we got them, and then showing them again".
     Now it starts as soon as head 2 has read, on the answers on C11's row,
     and ends on them written where the output weights take them; no number
     of theirs is written before number 1 is made. The stage lost 0.9 beats
     (24 to 23); every frame after the goal is the old one, 0.9 beats
     earlier, pixel for pixel.
     - The goal: the answers stand up off C11's row straight to the bench's
       right edge, a slice a head, unwritten, their tiles going faint as
       they turn (each kept inside the canvas, a strip turning so near the
       edge would swing past it), number 1 emptying into a slot, outlined
       ("Number 1 of head 1's answer, worked out": its 0.30 only once it
       is made).
     - Where the values come from: a copy of C11's row lifts off and stands
       up where Scores stood it, evened, its numbers at its left. The cells
       of number 1 of every place's value come, empty, on the places' rows
       where Scores stood the query, headed "value 1", and the plate `value
       weights · 16 × 16`. The 16 value weights into number 1 run from the
       row into C11's cell, lit with what they carry, and make −1.22, then
       settle faint, a weight on each ("C11's value 1, as in Scores: its
       row × 16 weights: −1.22"). Then `<bos>`'s row lifts off, outlined, and
       takes C11's place, and the same weights make +0.11 on its own row
       ("`<bos>`'s value 1: its own row, the same 16 weights: +0.11"): two
       faint fans, one pattern of weights. Every other place's value 1 then
       comes, top to bottom ("Every place the same: its own row, the same
       weights"). The values are the run's own; each recomputes from the
       evened row and the value weights (and their bias, once training has
       made one: "+ bias", as Scores folds its own).
     - How they make the answer: each share comes before its value, to a
       tenth, so share × value reads right ("6.8% × ■ +0.11 = +0.007"); then
       what each place adds, one after another ("Each place adds its value 1
       × its share: the last column"). Then one place at a time, marked, the
       numbers its caption gives lit in the accent: the largest share
       ("Largest share: S9, 23.4%, but its value is −0.11: it adds only
       −0.027"), then the place that adds most ("Q5 adds most, +0.208: a
       smaller share, 11.2%, but its value is +1.86"). The first version
       said both in one caption ("Q5 brings most, +0.208; S9, read most,
       −0.027") with both rows marked at once; the user asked what "brings
       most" and "read most" meant, so the part grew 2 beats (9). One place
       that is both is marked once ("Largest share: G1, 54.9%, of a value of
       +1.74: it adds most, +0.957", step 200). Places after C11 are
       hatched, never read. What each adds then runs, a string each, into
       the empty slot, and number 1 is made again ("Summed: 0.30, number 1
       of head 1's answer"); the strings are the arcs' work, written out.
     - The rest: the table goes, numbers 2–16 come, written for the first
       time, and the column goes where Scores stood the evened row, Scores'
       cut and the heads named beside it ("Numbers 2–16 the same way, each
       head with its own shares").
     - Notes: a value is made as a query is, a place's evened row × weights,
       one 16 × 16 for every place; the shares are weights too, made fresh
       at each place from its query and the keys, not learned like the
       matrices; the shares add to 100%, so the sum is an average of the
       values, and number by number, answer number 1 mixes only the values'
       1s. Head 2's note goes as head 2 finishes, and the output weights'
       note comes after the part.
     - At step 200 the same table reads G1 54.9% × 1.74 and Q5 29.5% × 1.85,
       summed 1.35.
     - The 0.11 of out_proj's number 1 (0.1135) is not `<bos>`'s value 1
       (0.1084); the two round alike at step 1, so the next caption names
       its column: "Output number 1: …".
   - the answers, side by side, through the output weights, a fourth trainable
     16 × 16 (beats 13.4–16.3). The user asked on 2026-11-01 how
     C11's row of what attention adds (0.11, 0.44, −0.19, …) is made: it had
     been a caption over a colour fade ("The heads' 8 + 8 numbers × output
     weights 16 × 16: what C11 read"), so the numbers seemed to come from
     nowhere. The run keeps the weights since its schema 5, and the mix whole,
     so the strings add up to the row written. Shown stills of two layouts,
     the user chose Scores' own staging over strings down to a segment under
     the row (`weight_flow.dart`, Scores' flow promoted, its frames
     byte-identical): the answers stand, a slice a head with Scores' cut and
     its labels, where Scores stood the evened row (stood up off the row
     before the worked answer until 2026-11-02, "The heads' 8 + 8 numbers,
     side by side: 16"; now the worked answer leaves them there); an empty
     column stands where Scores stood the query, the plate `block 1 · output
     weights · 16 × 16` under the
     strings with where they stand (`random start (seed 0), no update yet` at
     step 1); the row flows through as through the query's weights, number 1
     alone and slowly ("Output number 1: all 16 × their weights, summed:
     0.11"), then the other 15 in one cascade ("The other 15 the same: 256
     output weights, 16 into each"); the bench clears and the column, what
     attention adds, lies down onto the row where the answers sat ("What
     attention adds to C11"), and the map grows from there as before. The bias
     is folded in as Scores folds its own: "+ bias" in the caption once
     training has made it nonzero (0 at step 1). Note: "Output weights mix the
     heads' findings into one row of 16. / A fourth trainable 16 × 16, random
     at first like the others." The stage gained three beats, not the two
     first planned, so each new caption has about 2 s, as Scores' do.
     The worked example, insulin A's C11 at step 1, block 1: head 1's answer
     0.301, −0.415, 0.451, −0.604, 0.464, 0.112, 0.297, 0.352; head 2's
     0.018, 0.222, −0.222, −0.079, 0.051, −0.231, −0.344, −0.709; the output
     weights' first row −0.159, −0.203, −0.046, 0.195, 0.219, −0.218, −0.011,
     0.147, 0.110, 0.205, −0.007, −0.168, 0.165, −0.086, 0.129, −0.062, bias 0;
     the 16 products sum to 0.1135, written 0.11, and the whole row, what
     the stream gained across attention, is 0.11, 0.44, −0.19, 0.40, 0.04,
     −0.17, 0.16, 0.38, 0.01, −0.06, 0.29, −0.13, −0.17, 0.21, 0.46, −0.23
     (the app's live check holds these against what production serves);
   - every place at once: head 1's map, as large as the canvas allows (beats
     16.3–19.7). The two heads' maps stacked beside the table left each half the
     height, rows of 10 pt on a Pro Max and 6.6 at 375 wide, out of line with
     the table's rows; at the user's ask (2026-10-31) only head 1's is drawn.
     - The answers' numbers go, and their box grows out of C11's row into the
       map (beats 16.35–17.0): up to <bos>'s row, down to the column tiles and
       left to the token column, the map's empty slots and hatch seen only
       inside it; the x0 rows go into their tiles at the same pace, so the
       box never covers them. The user picked this over moving the map before
       the join (head 1's own segment growing into its map and back): after
       the join the box's halves are mixed, so the box says "C11 read through
       one row; the map is every place's row", not that its numbers become
       the shares.
     - The token column names the map's rows: the map lies on the table's own
       rows (22, 20 and 14 pt on the three phone canvases), from where the
       rows started to the canvas's side. Cells are about 19 × 22 pt on a Pro
       Max (16 × 14 at 375).
     - The user's four choices: each share on a soft tile of the share ramp
       (`LmInks.share`, softened as the tables' tiles are) with its
       percentage written where it fits, the tables' rule (insulin A and
       relaxin A; 30–40 places, colours alone); the places read named by
       tiles under the columns; the map comes in as empty slots, the places
       after each row hatched as Scores strikes them, and the row in focus
       fills first, cell by cell from `<bos>`, with the shares Scores found
       (the same softmax, number for number), then every other row, top to
       bottom; a tap on a row of it puts that place in focus (no tap picks a
       head now).
     - The notes read the map in the earlier stages' words: a row is one
       place's query on each key up to its own, as shares; a column, one
       place's key and value; each row adds to 100%, the first places sharing
       it among few (why the top left is brightest at step 1); the hatched
       places are never read, as the next one is the answer (Shift's y).
     - Head 1's map at step 1 is diffuse (C11 reads S9 23%); by step 200 it
       is sharp (L13 reads Q5 94%, Q5 reads E4 92%, the G1 and Q5 columns
       bright): over the six peptides the mean top share goes from 19% to
       44%, and rows giving one place half or more from 10 to 59 of 174. A
       "sharpest row" caption was weighed and left out: at step 1 it always
       names row 1's two-way split.
   - then head 2's map on the same rows (the user's ask of 2026-11-02: what
     attention adds is both heads' answers through the output weights, and
     until then only head 1's map was drawn, as the user asked on
     2026-10-31, one map at a time as large as the canvas): from 19.4 head
     1's cells empty to their slots and its tag gives way to `block 1 ·
     head 2 · shares in % · 22 × 22`; head 2's map fills as head 1's did, a
     little quicker, the row in focus first (19.75–20.25), then every other
     row (20.3–20.9), and holds until the table widens at 21.7. With more
     than two heads, each later head's map takes an equal share of that
     span. Its caption counts the rows whose place read most is another than
     in head 1's map, "Head 2's map: the place read most changes in 17 of
     22 rows" (insulin A at step 200; 19 at step 1; over the six peptides
     143 of 174 rows at step 200); C11's own reads are already in head 2's
     caption earlier in the stage (C11 29%, C6 27% at step 200, against
     head 1's G1 55%, Q5 30%). Its note: head 2 reads with its own query
     and keys, a map of its own, and the two answers, side by side, go
     through the output weights.
   - the table widens again, out of its tiles, to what attention adds to each
     place, alone on its own scale ("Every row made as C11's: both heads'
     answers × output weights"; until 2026-11-02 "Each row made as C11's
     was: its shares × the values, × output weights", one head's shares and
     three lines at 375), then the sums: x0 + block 1's attention.
   - What the stage names of the block it names as block 1's: its head tags,
     the value and output weights' plates, head 1's map (`block 1 · head 1 ·
     shares in % · 22 × 22`), what block 1's attention adds and the sums (the
     user's ask of 2026-11-02: Scores, Attention and Feed-forward work block 1
     alone, and until then only Scores' first caption and Feed-forward's said
     so, Attention never).

   Over it a note says why each part happens.
6. **Feed-forward.** Block 1's feed-forward, in 20 beats:
   - a copy of the row in focus, x0 + block 1's attention, turns straight
     off it and stands up as the 16 inputs of a network drawn left to
     right, numbers beside them (it lifted off the row first until
     2026-11-01, when the user found that opening no longer needed once the
     chart does the evening out);
   - before any weight is drawn, the block's second LayerNorm evens the
     inputs out on Scores' chart, drawn beside them where the network will
     be (`ScoresScene.eveningChart`, shared, so Scores' bars hang from the
     mean too): the caption names it with the row's mean and standard
     deviation; less the mean, the bars, the mean line and the band slide
     onto zero as one; over the standard deviation, z-scores; then the
     norm's own scale and shift, the z-scores left faint behind the bars,
     and the band goes. Added on
     2026-11-01 at the user's asks: the copy's numbers had changed in half a
     second with nothing saying why, and a first fix, the numbers changing
     on the lying copy step by step, still did not make it clear. The run
     keeps no scale and shift of this norm, only its output (`ff_input`),
     so the last step says "evened = z-score" where the output is the
     z-scores to float32's precision (`Evening.plain`, step 1) and names
     the learned scale and shift otherwise; Scores' `z-score × scale +
     shift` sum is not drawn here. A note says the row itself keeps its
     numbers and the network reads an evened copy, as attention did;
   - all 1,024 weights reach the 64 neurons, each line coloured by the sign
     of input × weight and as bright as its size; a note says so, and where
     the weights stand (random start at step 1, the updates since);
   - GELU worked out: the brightest neuron's 16 lines stand out, ringed
     and numbered, a dot running once along each, GELU's curve beside the
     neurons from then on, its sum in the caption (insulin A's
     C11 at step 1: neuron 36, 1.10; the evened row × its weights + its
     bias, from the run); the curve stands right of the neurons, where the
     outputs will be, its line in the accent, and the sum goes up to it
     and across, GELU(1.10) = 0.95; then the neuron with the most negative
     sum, 57, GELU(−1.83) = −0.06, nearly nothing; then every neuron at
     once, lit by what it passes on, the 23 that light (a tenth of the
     brightest or more) a dot each along its strongest input, and the curve
     its line alone. Notes: a weighted sum and its bias; GELU(x) = x ×
     the chance that a standard normal number falls below x; why the bend
     (without it the two layers are one weighted sum). Each neuron the run
     kept is GELU of its sum to its int8 step (held by `lm_scenes_test`).
     History, all 2026-11-01 at the user's asks: first worked out with a
     point for every neuron (57a696e); taken out for a concise note and a
     small curve, its line alone (226c1f8), the curve then grown to its room
     with the lit neurons as white dots (243dce7); the three examples then
     wanted back, to see how GELU is worked out (299b353), the dots into a
     worked neuron running once, the curve from its start, and no points on
     the curve while every neuron lights;
   - then the 16 outputs, numbers written, each output's dot along the
     neuron that pushes it hardest;
   - they lie down onto the row in focus, and every place gains the same
     network's output, alone, then added: block 1's output.
7. **Forward.** The place in focus's row through the whole pass, layer to
   layer, down the canvas, in 12 beats (`TowerLayout`): a slot a point of the
   stream, six for two blocks, with the table's own columns, each named over
   it: x0, as Embedding made it; + block 1's attention; + block 1's
   feed-forward; + block 2's attention; + block 2's feed-forward; final
   LayerNorm: what Predict reads.
   - It opens on Feed-forward's last frame. The table goes; the place's row
     goes to block 1's output's slot and waits there, faint; its tile goes to
     the ladder's top; the route comes in as empty slots, every part named.
   - x0 fills the top. A part at a time, what it adds comes in as a thin
     strip (the four on one scale, so they can be set against each other)
     and a copy of the row above drops through it into the next slot,
     turning into the sum as it passes: block 1's two land on the row that
     waited, then block 2's go on. Block 2's attention reads every place's
     row as block 1 left it, so a place it reads brings what that place read
     there: its caption follows head 1's top read back a block, as
     Attention's map reads them, "In block 2, C11 reads T8 46%, which in
     block 1 read C6 37%" (insulin A at step 200; at step 1 Q5 12%, which
     read E4 33%). Where the place read is the one in focus, or read itself
     most in block 1, there is no second hop and the caption sets the top
     read against block 1's: "In block 2, V3 reads V3 51% (block 1: G1 89%)"
     (step 200). Over the run's 1,260 places and steps, 830 follow the two
     hops. Until 2026-11-02 the caption was only that comparison, "Block 2's
     attention: C11 reads Q5 12% (block 1: S9 23%)"; the two together do not
     fit two lines at 375, and the two hops say why block 2 reads otherwise
     (the call the user left to me). "Block 2's attention: …" took three
     lines at 375 wherever the place read had read <bos>, so it opens
     "In block 2, …".
   - The last drop goes through the final LayerNorm: the caption gives the
     row's mean and standard deviation (C11 at step 1: 0.19 and 1.23), then,
     from the run's numbers (`Evening.plain`), evened = z-score at step 1 and
     its own learned scale and shift after. That row, outlined in the accent,
     is what Predict reads.
   - Each row writes its numbers from when it lands to the end, so x0's can
     be read against every row after it (the user's ask of 2026-11-02, over
     only the row last made writing them); each copy drops out from under the
     row it copies, its numbers left clear. They are in the ladder's own face,
     so a 40-place peptide, whose table is drawn in colours alone, has numbers
     here. Once the table has gone a tap asks for nothing: the ladder is one
     place's.
   - Notes: each part reads the row as it stands and adds to it, never
     replacing it; each block after the first reads the rows the one before
     left, with weights of its own; one last evening out, so the output layer
     reads rows of one size; every place goes down the same pass at once,
     and Predict turns the last row into a guess.
   Until 2026-11-01 Forward condensed the rows into a network of a row a
   place and a column a point, lines for the attention shares, and each node
   the place **read out early**, the token the output layer would give it if
   the model stopped there (a probe the user chose on 2026-10-30), with each
   column's count of places right (insulin A at step 200: 3 · 5 · 11 · 11 · 21
   of 22; at step 1, none). It drew Predict's output layer and Loss's grading
   against y before either stage, its last column was Predict's answer, and
   at step 1 its nodes read nothing right; the readout is kept in the run for
   Predict's review. The same day a Block 2 stage came between Feed-forward
   and Forward (head 1's map turning from block 1's shares to block 2's, then
   what block 2's two parts add, alone and added, 13 beats); the user found
   it redundant with the ladder and it was removed, its one fact, block 2's
   own reading, kept in the caption above.
8. **Predict.** The place's last row through the output layer and softmax,
   in 14 beats (`PredictLayout`, on Embedding's), the user's picks of
   2026-11-02: the run kept again whole (schema 6), the output layer drawn as
   Scores draws a row through its weights, softmax worked in two steps, and
   an end on every place's guess.
   - It opens on Forward's last frame (`ForwardScene.paintEnd`; `ForwardFade`
     fades the ladder and leaves out its last row). The ladder goes; the last
     row's numbers go, and it turns straight off its slot into a standing
     column at the left, as Feed-forward stands its copy, its numbers left of
     it.
   - A slot a token stands at the right, 23 in id order, each with its tile,
     the vocabulary as Embedding listed it, titled logits, the plate
     `output layer · 23 × 16` under the strings with where its weights stand
     (random start, or the updates since).
   - The row flows through the weights (`weight_flow.dart`): the top logit of
     the 21 that can come next alone and slowly, its caption the sum
     (insulin A's C11 at step 1: K's logit, the row × K's 16 weights, summed,
     + bias: 1.00), then the other 22 in one cascade; the 368 strings stay,
     faint, a weight on each. A logit is high where row and weights agree in
     sign and size.
   - `<pad>` and `<bos>` can never come next: their numbers go, −∞ comes, and
     their rows are hatched as Attention strikes what is never read. The bench
     clears, and the logits slide left with their numbers and tiles.
   - Softmax in two steps, each its caption: a bar on each token's row grows
     to e to its logit, the largest across the room (e to K's 1.00 is 2.72;
     at step 200 S's 9.14 makes 9,318 and every other bar vanishes); then
     every bar shrinks by the same sum (27.12) into its share, written at its
     end, against a dashed 100%. What came next is lit, a soft band 13%
     toward the tracer behind its row from its tile to the dashed 100% (it
     was a white outline until the map's redraw, then replaced at the user's
     ask the same day): the room its bar would fill were the guess right and
     certain. "Top bet after …CCTSIC: K, 10%. True next residue, S, got
     1.3%" ("token" for <eos>); at step 200, "…: S, 100%, the true next
     residue". It said
     "next is S, given 1.3%" until the user read S as the model's second
     guess (2026-11-02): guess and answer key are now named apart.
   - Every place at once, on a map of shares drawn as squares (the user's
     picks of 2026-11-02, redrawing the first map, which was head 1's: a
     soft tile and a number on every cell and a white box on each answer).
     Why it was redrawn, measured on insulin A at step 1:
     - Every share lay between 1% and 21% (median 4%). On head 1's ramp,
       softened for the numbers on it, the cells spanned ~1.4:1 in
       luminance. The boxes, in the tracer's white, stood ~11.6:1 against
       a cell, and 462 numbers ~9.5:1, so the marks outshouted the data.
     - No row's top guess could be seen without reading every number.
     - The tracer, the walk's one unambiguous box, had become 22.

     Now:
     - Each share is a square in a dark slot, its area that share of the
       slot's (`PredictScene.slotOf`, the largest square its cell holds;
       `fillOf`, the slot scaled about its centre by the share's square
       root). A place's squares therefore add up to one slot.
     - Squares are the accent, muted for the least and the accent itself
       for a certainty (`fillColour`). There is no number in the field and
       no outline.
     - Each bar goes into its square in a standing column of slots, and the
       band on what came next gathers into its slot, which stays lit. The
       column lies down onto the place's row (`StreamTable.turn`, the
       strip's turn, promoted, every other stage's frames byte-identical),
       then every other row's squares grow in, top to bottom.
     - Then the slot of what came next lights at every place: a soft fill
       13% toward the tracer (`drawSlot`), ~1.7:1 on a slot, under the
       squares.
     - The answer key comes in at the map's right, as Shift's y: each row's
       next token on a tile as large as the row's own, and p(y), the share
       the guess gave it, the number Loss scores. It is titled `y` and
       `p(y)`, its room the wider of the widest share and the two titles.
     - A right and certain guess is one square filling its lit slot. The
       top guess is right at 0 of insulin A's 22 places at step 1 (p(y)
       median 4%), 9 at step 49 (13%) and 21 at step 200 (99.5%). There
       `<bos>`'s row spreads a sixth over the six first residues, the
       floor Loss explains.
   - Shares are softmax of the logits as the run keeps them, whole (as
     Attention's are of the scores), and so are Loss's and Backward's. Every number is the run's: the last
     row, the output layer's weights and biases as the step found them, the
     logits. On the bench a tap asks for nothing; on the map a row, or its
     answer, puts its place in focus.
9. **Loss.** Each guess scored by −ln p(y), and their mean, the step's
   loss: 17 beats, opening on Predict's last frame, pixel for pixel. The
   user's ask of 2026-11-02 was to start where Predict leaves off, reuse the
   earlier stages' parts and make the stage far clearer. It had opened on a
   bar chart of the 21 tokens in the old look, worked "−ln 0.01 = 4.315" for
   a share of 1.34% (the share rounded, the cost not), boxed the answer in a
   white dashed ghost, and ended on 180 honey strips nearly alike at step 1;
   it read the stored probabilities, not Predict's shares. Now, four parts,
   the user's three picks (all recommended):
   - *p(y) alone* (2 beats): every cell of the map but what came next goes,
     and each row's lit slot slides along its row to the key, beside its y
     (the map's last column); the focus row's outline narrows with its slot,
     clear of the chart to come, its tile ringed instead
     (`outlineToken`, `drawToken`'s ring, shared). "Loss reads one share a
     place, p(y): here from 1.3% to 8.1%"; the note answers why the other
     20 still count: all 21 add to 100%, so p(y) rises only as they fall.
   - *−ln p(y), worked* (4.4 beats; picked over a scale labelled in both
     units, and over words alone): the curve on the bench the gather left,
     drawn as Feed-forward draws GELU's (`LossChart`): p(y) along, from 0 to
     100%, nats up; the curve draws itself up from a sure, right guess; an
     even guess, 1/21 a token, costs ln 21 = 3.045 at every place, a dashed
     line across the chart where the curve meets it at 1/21; then the place
     in focus's square flies from its slot down to the p(y) axis, a dot as
     it lands, and a guide runs up to the curve and across to the nats axis,
     each number written where it meets its axis over the axis's own
     ("C11 gave S 1.34%: −ln 0.0134 = 4.31 nats, over an even guess"; the
     sum is worked from the share as written, to three figures, so it reads
     right). The note: 0 for a sure, right guess; each halving of p(y) adds
     ln 2 = 0.69 nats; a sure miss costs most.
   - *the peptide alone* (3.4 beats): the key's y tiles tip over to the
     left about the column's last tile, which moves least, so a long
     peptide stays on the canvas, each tile upright, into the peptide's line
     of target y, as Shift drew it, alone across the canvas (insulin A:
     tiles ~18 pt, letters 14 pt), the user's choice of 2026-10-30 paid off;
     Shift's tag `target y` with its gloss ("−ln p(y), a bar each",
     `ShiftScene.drawRole`, promoted), the cost's axis in whole nats at the
     line's left, as the curve's. A bar rises on each target to its −ln
     p(y), as tall as the line is wide at most, the even guess dashed
     across; the place in focus's bar in the loss's full honey with its cost
     over it (4.31 for C11 at step 1, on a ground backing where it crosses
     the dashed line), every other bar quiet, honey at half strength. No
     mean here: the step's loss is the batch's, said once. At step 200 one
     bar stands, `<bos>`'s, 1.80.
   - *the batch* (2.8 beats; picked over the key as six columns, and over
     the peptide in focus alone): the line shrinks into its place among
     Shift's lines, its axis with it; the other five come in under their
     names, padding dimmed (`ShiftScene.dimmed`), the focus line on Shift's
     card and its target in focus ringed, and their bars rise, on one scale
     for every step (`LossScene.ceiling`: the largest cost at any
     checkpoint, 4.66, up to 5 nats). At step 1 they stand 2.06–4.66 around
     the dashed line; at step 49 most are under it; at step 200 only six
     stand, each peptide's first, ln 6 apiece.
   - *the mean* (4.4 beats): a line in the loss's full honey draws itself
     across every line's bars at their mean, the step's loss, named "mean"
     once, at the first line's end, as LayerNorm's chart in Scores and
     Feed-forward draws a row's mean; the bars stay at their own heights,
     quiet; a legend, the honey line `loss 3.220` and dashed `even guess
     3.045`; the note's first line, "The honey line is the mean of all 180
     bars: the step's loss". The user first picked the bars levelling out
     into the mean (water finding its level, ghosts above, brightening to
     full honey) over a mean line, then, seeing it, asked why every bar
     changed: nothing named the pour, and it looked as if each target's
     cost had changed. Offered the mean line or the pour with words, they
     chose the line.

   The first cut (14 beats) went from the curve straight to all six lines
   and levelled them in full honey; the user found it crowded and asked why
   the whole dataset was there (one step is one batch, so the step's loss
   is all six's), then asked for the peptide alone first and the dataset
   after, and for the bars not to be honey everywhere. Residue colours were
   rendered beside the honey and a quiet honey, and set aside: the
   palette's lightness skews the bars' heights, a residue's colour reads as
   the residue's cost when the cost is the guess's at that place, and the
   levelled mean became a rainbow. The caption names what the checkpoint was kept for
     passing (its `why`): worse than an even guess at step 1, then the first
     step under it (13), under residue counts (21), under residue pairs
     (49), under one nat (66), under a tenth (95), and at 200 "the floor
     here is 0.060". The note calls it cross-entropy, says Backward comes
     next, and where the `<bos>` places hold over half the loss says how
     much (63% at step 95, 93% at 200: from `<bos>` alone no model can know
     which of six peptides comes).

   Each p(y) is Predict's own share, softmax of the whole logits; −ln of it
   is the loss the run kept for that target within 5 × 10⁻⁴ (the stored
   u2 step, 1.2 × 10⁻⁴ in fact) at every checkpoint, and their mean is the
   step's loss to 10⁻⁴ (`lm_scenes_test` on the toy run,
   `expectTheLoss` in the live check on the curated one). On the table a row
   puts its place in focus; on the batch a line puts its peptide in focus,
   and a target of the focus line its place; while the key swings a tap asks
   for nothing, and so does the line while it shrinks; on the line alone a
   target puts its place in focus. Every caption keeps to two lines at 375,
   402 and 440 wide, at every peptide, place and step, and every note to its
   own lines.
10. **Backward** (46 beats, reworked 2026-11-02; the user's picks: the
   run re-recorded as schema 7 with the stream's gradient whole, one stage,
   and the opening back to the place in focus, then its bars). The forward
   pass played back, along the same strings and the same ladder. It opens on
   Loss's last frame pixel for pixel (`LossScene.paintEnd`, `LossFade`): the
   other lines, the card, the mean and the legend go, the line in focus grows
   back to stand alone (Loss's zoom reversed), then its target flies to its
   row of Predict's shares, settled, the dashed 100%, its row lit. p − y: the
   target's row fills to 100% in the negative ink ("raise its logit"), every
   other bar turns positive, its share ("lower each"), and the bars condense
   into a signed column where the logits were made. The place's last row
   stands at the left with its gradient's empty slots beside it; the errors
   run back along the output layer's strings, the largest number alone
   (insulin A's C11 at step 1: number 10, −0.32), the rest in a cascade. The
   gradient lies down into Forward's ladder and climbs it:
   the final LayerNorm, then each part from the last, its strip what it sends
   back, a copy rising through it into the sum; attention's captions count the
   later places that send blame back. At x0 it goes to the token and position
   rows, and every place's x0 gradient comes in on the table (at step 200
   99.9% of insulin A's is `<bos>`'s, the unknowable first residue), where the
   stage ends: the gradients' length against the clip, its last caption
   until 2026-11-03, moved to Update, which is where every weight has its
   gradient (46 → 44 beats). Numbers are the
   run's gradients times the 180 targets, what each place's own cost sends
   back; ÷ 180 is said once, in the note where every place climbs. Colours and string
   strength are the whole batch's at that step, so a place with nothing left
   to learn is drawn faint (copeptin's R20 at step 200 is all 0.00). The old
   stage (a module rail, a clip gauge, a dot per place and point, the stored
   probabilities) is gone. The same evening, at the user's ask for as many
   explanations as possible, every mini-step got its own caption and note,
   held for reading (two seconds a beat, 4 to 6 seconds each, so 21 beats
   became 51), and the canvas names its marks: y, the answer key, as the
   target's lit row, brightened while read (an outline was tried and
   dropped at the user's word: too heavy); a legend line over the bars in the rows of `<pad>`
   and `<bos>` (lit y, blue what the target lacks, clay what the others
   took, their sum 0); number 10 worked out in a box (S −0.99 × 0.23 =
   −0.23, M, R, the other 18 −0.09, sum −0.32); the gradient read, its
   extremes ringed; and at each + of the climb one number worked out beside
   the part's name. Later that night the user asked whether the third and
   fourth animations on the strings were needed, and they were cut (51 → 46
   beats): each string relit by its own weight's gradient, the error at its
   end × the number at its start (S from 6, −0.99 × 1.94 = −1.92), then by
   the batch's mean, the output layer's gradient as the run kept it. Both
   reused the strings that had just carried the errors back, with a new
   meaning; the strings ended on the gradient column while the number
   multiplied stood two columns left, in the place's row; and the batch's
   strings sat between columns that were still the one place's. Backward is
   now one flow, the error carried back row by row to x0. A weight's own
   gradient (error × the number that went in, averaged over the 180) is what
   Update opens on.
11. **Update** (38 beats, reworked 2026-11-03; the user's picks: the same
   weight at every place on the table, over every place's whole grid added;
   and the run re-recorded as schema 8, AdamW's running averages for the
   output layer kept, so the step is worked out at every checkpoint). It
   opens on Backward's last frame pixel for pixel and goes back to the output
   layer's strings, from the place in focus's last row to its p − y. One
   string is worked: the place's largest error × number (insulin A's C11 at
   step 1: S's from number 6, −0.99 × 1.94 = −1.92, written from the written
   factors). The same weight at every place, on the table of every place's
   last row, narrowed to the worked column: each place's p − y at the worked
   token, its pull, the peptide's sum (−1.31), a card of the six peptides'
   sums and all 180 (−4.075), ÷ 180 = −0.0226, the kept gradient. Every
   weight at once, a grid on the bench's token rows; it shrinks into its row
   of a chart of the ten groups' gradient lengths, and all 8,167 together,
   0.611, are set against the clip's 1.0 (none of the seven checkpoints is
   clipped; steps 59 to 73 were, nine of them). AdamW on the worked token's
   16 weights, a bar each: the gradient; the running mean (0.9 of the last
   and 0.1 of this, corrected for starting at zero); the running size as a
   tick (a light tick, not an outline: Backward's white borders were
   removed at the user's word); each bar over its own size, its ratio (±1 at
   step 1: no past, the sign alone; at step 49 from −1.18 to +1.41); times
   −rate, the schedule marking the step; the bars condense into a step
   column and the weights go through it to after (−0.0598 + 0.0001 =
   −0.0597). Last every weight's step on the grid (0.0001 each at step 1,
   soft tiles; the full ramp read as a loud checkerboard) and the layer
   after, its plate one update on. The old stage (a grid lerping gradient →
   update → weights, module bars against their largest, a lone schedule) is
   gone, and with it `ModuleRail`.
12. **Loop** (44 beats, reworked 2026-11-03; the user's picks: Predict's map
   at every step, the run re-recorded as schema 9 for it; a hold at each
   kept step; the weights in the opening only). Training is the step the
   stages showed, 200 times on the batch made once; Loop shows what that
   does. It opens on Update's last frame pixel for pixel (every weight moved
   once), and puts step 1 back together on a canvas of its own: its guesses
   as Predict's map, on rows of its own (`share_map.dart`, Predict's map
   promoted, its frames byte-identical), and their cost, 3.220, the first
   point of a curve in the loss's honey, the levels dashed in Loss's words
   (even guess 3.045, residue counts 2.856, residue pairs 2.043), the floor
   dotted (0.060), Update's rate schedule under it. Steps 2 to 4 go one at a
   time, each a hair lower (−0.003, −0.005, −0.008, the rate warming up), then
   the run moves to each kept step and holds there (`LoopPace`, a pure
   function of the run; the moves share the beats by how far the loss falls
   on them, at least 1.2 each). What the map shows, in order, is the
   mental model's last piece: random guesses worse than even at step 1
   (right at 7 of 180); no better than an even guess at 13 (12); at 21 the
   guesses follow residue counts, L, the commonest residue (23 of 180
   targets), the top guess at 80 places; at 49 they follow the residue
   before (71); then the burst, squares jumping into their lit slots one
   place after another (p(y) over ½ at 0 places before step 50, 75 at 66,
   166 at 80), one nat at 66 (139), a tenth at 95 (175), nine steps from 59
   to 73 over the clip; then the rate's cosine flattens the loss to 0.065
   against the floor. The end dims every row but `<bos>`'s: from `<bos>` no
   model can tell which of six peptides comes, so each first residue gets a
   sixth (16.5% each), ln 6 at six of 180 places, 93% of the loss, the
   floor. Last, the run whole: insulin A right at 21 of its 22 places, only
   the weights changed (S's from number 6, which Update worked: −0.0598 to
   0.0938), nothing held out, learned by heart. Squares are the steps' own
   probabilities, lerped between whole steps; every number written is a
   kept step's, whole, and only while the run stands. The moves carry no
   note, so the eye is on the map. The run starts at step 1 whatever
   checkpoint is picked; a tick picks a checkpoint and holds the run there.
   The old stage (residue-coloured tiles lit by p(y), the output layer's
   grid drifting, an `lr` strip, one linear sweep) is gone.

## Info pages

How a page is written is `peptide-lm-info-pages.md`; this section keeps
each page's record.

The ⓘ opens the stage on screen's own page (`LmScene.info`, required of
every stage, an `LmInfo` that `LmInfoSheet` draws, built when tapped):
Tokenise's since 2026-11-06, the other eleven since 2026-11-07, each
previewed with the user with the live run's numbers and approved as
drafted. Every page is the screen's key, the user's pick for all twelve
(over four fixed headings, Takes · Gives · Why · Leads to, and over
questions as headings): a lead saying what the stage takes and what it
gives, then a short section for each part its canvas tags, in the order
they come, saying why it is there, a link to a later stage beside what it
explains and said there once. Every number is the run's own, as the
captions' are. The sheet is as tall as its words, up to four fifths of the
screen.

From Embedding on, every stage's notes explain each mini-step, so a page
there is a map and a key: a part gets a section only where the page adds to
what its notes say, and a tag whose notes say it all gets none. A section is
titled as its tag, less its size; a breadcrumb tag by its last part
(`block 1 · head 1 · values`: Values); a tag that names the place, with
its name (C11's row, layer to layer).

The About sheet, how the whole model learns, which the ⓘ opened for a stage
with no page of its own, was deleted on 2026-11-07: each of its stage
paragraphs is superseded by that stage's page, and its "This run" and the
peptides' records end Loop's page (the user's pick, over a page of their own
behind the "Recorded run" line and over keeping the sheet behind a link on
every page). Its sentence on √8 is Scores' now.

A sentence stays only where it explains a mark on the canvas, keeps a
reader from a wrong model, or names at its source what a later stage
shows. Tokenise's, part by part:
- the lead: six peptides, 174 residues, become one 6 × 41 matrix of ids,
  all the model sees of them; made once, the same at every step, nothing
  learned (so the step menu changes nothing here);
- token ids: an id is its token's row, a name and not an amount: C, 4, and
  D, 5, are neighbours only in the alphabet (the first pair whose ids and
  letters both follow on; the preview's A and C have B between them).
  Embedding gives every token but `<pad>`, whose row the engine holds at
  zero, 16 trainable numbers, and Predict ends on the same vocabulary, the
  21 tokens that can come next;
- special tokens, a paragraph each, named by the glyph the canvas draws:
  `<bos>` gives the first residue a place to be predicted from and, alike
  in all six, leaves it one in six however long the model trains (said only
  where the first residues all differ); `<eos>` teaches where a peptide
  ends; `<pad>` squares the batch, never read by a real token (a place
  reads only up to its own, and pads come last) and never scored;
- batch 2D matrix: all six at once, the whole dataset every step, none held
  out, so the run shows a model learning six peptides, not generalising;
- token counts: guessing by these counts alone costs 2.856 nats, Loss's and
  Loop's residue counts, first beaten at step 21, the checkpoint the run
  kept for it (said only where it kept one). The model's mean guess
  converges on these counts: r = −0.12 at step 1, 0.77 at 21, 1.00 at 49.

Left out: the peptides' names and the commonest count (the canvas and the
caption say them), the floor and residue counts worked out (Loss's and
Loop's own notes carry them), text models' word pieces, and why only six
peptides. The page scrolls by 53 pt on a 440 × 956 phone and more on
smaller ones (73 pt until 2026-11-10, when a page came to end 24 pt under
its last line).

Shift's carries its stage, whose canvas says nothing but its captions, and
answers the user's three questions of 2026-10-30 (what x and y are, whether
both are used, why show them):
- the lead: the 6 × 41 matrix cut once into x and y, 6 × 40 each; no
  answer comes from outside, each peptide is its own answer key, one place
  on;
- input x: each place asks what comes next; the frame's last place has
  nothing after it (the mark: x letting its 41st go); every place reads the
  true tokens, never the model's guesses, so all 180 are asked in one pass,
  unlike writing, which feeds each guess back;
- target y: x moved one place left; n + 1 answers, the residues and
  `<eos>`, never `<bos>` (the mark: `<bos>` leaving at the left); an answer
  also stands in x one place on, so a place never reads past its own, the
  cause of Scores' struck keys and Attention's hatch, said here once ("Each
  answer" in the preview became "An answer": copeptin's last, `<eos>`, has
  no place in x); the 60 dimmed places have nothing to ask (one on the toy,
  no sentence where none); y never goes in, Predict writes it, Loss scores
  against it.
Left out: teacher forcing by name, and the mask drawn here (left to the
attention stages, the user's call of 2026-10-30).

Embedding's adds what its five notes leave out:
- the lead: x0 from two tables, the model's first trainable numbers, 1,184
  of 8,167, after two fixed stages;
- token embedding: every row but `<pad>`'s (held at zero; added after the
  preview) starts as 16 random numbers, none a property, the model using a
  row whole; training moves the table about 15% of its size by step 200
  (`EmbeddingScene.tokenMoved`; 23% on the toy);
- position embedding: their 43× smaller start is the engine's, not learned
  (`smaller` at the first checkpoint, the note's own number);
- x0 = token + position: Backward ends here, and a row learns only from
  the scored places that read it: `<eos>`'s row, read only where nothing is
  scored, keeps its random start, as do position rows 40 to 50, which no
  peptide reaches (`rowStill`, `unreadFrom`; each clause only where the
  run's rows bear it out).
Left out: similar residues coming to have similar rows (this run moves the
table too little to show it), and the starts' standard deviations as
numbers (over the whole tables they make 47×, the note's insulin A 43×).

Scores' lead says where attention stands: the one part of the model where
places exchange anything. Query, key and value: the plates' weights, three
16 × 16 and 48 biases, 816, are what training keeps, the scores and shares
worked out afresh every time. Head 1 and head 2: why a score is over √8,
the About sheet's sentence, flagged in the preview (the √8 slide stays
removed). Left out: LayerNorm (its chart, sum and note say it all), the
cut (its note) and the shares' sharpening (Attention's, where every row
shows).

Attention's lead: from here a row holds, as well as its token and place,
what the places up to its own handed over, which is how a guess comes to
depend on what came before (Loop's residue pairs show it). Values: a key
does not turn into its value, as the canvas's colour turn suggests; both
come side by side from the evened row. Shares: training sharpens where each
place looks, head 1's largest share, every place but `<bos>`'s, 19% at
step 1 and 44% at step 200 over the six (`AttentionScene.largestShare`, held
to the maps; "in head 1" added after the preview, head 2 going 18% to 33%;
no section where the last is not sharper). Left out: heads' roles (none
here: no head mostly reads the place before or the first residue).

Feed-forward's is short, for its eight notes explain the network: the
lead, its weights 2,128 a block, the two blocks' 52% of 8,167 (not "most of
the model": on the toy they are 28%, under the attentions); and what block
1's feed-forward adds, the neuron by neuron view the canvas lacks, each
neuron adding its own 16 output weights times what GELU lets through, none
set to a residue or a property.

Forward's lead: one place's row through the whole pass, what Scores,
Attention and Feed-forward took apart. Its one section, titled as the
ladder is tagged: the strips share one scale, unlike the earlier stages'
tables of what each part adds, so the four can be set against each other;
block 2 reads the rows block 1 left, so two blocks reach two hops back, the
principle of the caption's example. Left out: the early readout, which left
the screen on 2026-11-01.

Predict's lead: a guess is the whole row of 21 shares, not its top letter;
writing a peptide would draw from them. Output layer: 368 weights and 23
biases, a table of its own, not the token embedding's rows used again:
`<eos>`'s row learns there, an answer six times, while its embedding row
never moves (`PredictScene.ownOutputRow`). Left out: the right guesses
(caption and Loop's), −∞ and softmax (the notes').

Loss's lead: the loss is the only thing training lowers, Backward's start
and Loop's curve. Even guess, drawn first here: the first level Loop's
curve passes, at step 13 (`LossScene.passedEven`). Mean, the canvas's name
for the honey line: e to the loss is how many tokens the model is as unsure
as, 25.02 at step 1, more than an even guess's 21, and 1.07 at step 200.
Left out: the floor and `<bos>`'s share (Loop's and the note's), and
perplexity by name.

Backward's lead: it measures and changes nothing; Update moves the weights.
The ladder's section: what the stream's +s are for, the gradient handed
back whole to every block, however many are stacked. Gradient at x0: every
gradient's colours are on the whole batch's scale at that step, so a place
with little left to learn is faint (why step 200 looks empty). Left out:
the mechanism, which its nineteen notes carry.

Update's lead: the one stage that changes the model. Rate: the rate, its
warm-up and cosine, the clip and the decay are settings the run was given,
only its 8,167 numbers trainable. Step: decay shrinks only the weight
matrices, 6,512 of 8,167, never the embeddings, biases or LayerNorms, more
exact than the note's "each weight" (`UpdateScene.decayed`, held to the
groups; the run bears it out, the never-next tokens' biases never moving
while decay alone shrinks their weights). Left out: why Adam and the clip's
steps (the notes').

Loop's lead: the one stage that shows the run. Next-token probabilities: a
model meant to write is judged on peptides it never saw, this one on the
same six. 200 steps, the axis's label: the ticks are the seven steps kept
whole, by rule, which the Step menu picks for every other stage. This run:
the About sheet's paragraph and the peptides' records, from the run's own
record (`LoopScene.thisRun`). Left out: the run's shape (its captions
narrate every move) and the corpus run's size (not in the run's record).

Every page fits a 440 × 956 without scrolling, and a 393 × 852 too; on a
375 × 667 Shift's scrolls 134 pt, Embedding's 33 and Loop's 159. These are
since 2026-11-10, when a page came to end 24 pt under its last line, not
44: before, Loop's scrolled 10 pt on a 393 × 852 and Scores' 7 on a 375. A test holds every page to the sheet's font (no glyph Space
Grotesk lacks) and the app's voice.

## The page's frame

What holds the stages: the header, the caption under the canvas beside the
stage's player, the stage bar, the Step menu and the info sheet. A pass on
2026-11-10 (the user's ask: small improvements across the whole flow, the
flow itself untouched) measured each in the app's own fonts, on the real
run, at 440, 402 and 375 pt, and fixed what it found; the user picked the
three calls that were a matter of taste.

- **Header.** "Peptide Language Model" is 240 pt wide at the title's 20 pt.
  Beside the back arrow (56 pt), the title's spacing (16 pt each side), the
  Step menu (59 to 80 pt as the step's name grew) and the ⓘ (48 pt), it had
  159 to 245 pt: a 17 Pro read "Peptide Language…" at every step, a Pro Max
  had it whole at Step 1 only, and the subtitle was cut at 393 pt and under.
  The title and "Recorded run · N parameters" now each shrink just enough to
  stay whole (`_Whole`, a `FittedBox` that only scales down), and the Step
  menu is as wide as its widest step's name, its own name at the end where
  it stood, so nothing in the header moves when the step changes: title
  18.6 pt on a Pro Max, 15.4 pt on a 17 Pro, 13.2 pt at 375; subtitle 12,
  11.2 and 9.6 pt. The user picked this over "Peptide LM" in the header and
  over leaving it cut. The wait's header, with no actions, shows the title
  at 20 pt, so it shrinks when the run lands, as the rest of the page
  changes.
- **Caption.** Its box is held at the stage's tallest caption
  (`_captionReserve`), so the canvas never resizes. Each caption starts at
  the box's top, which the row centres on the player, so a stage's first
  line never moves (the user's pick). Centred, as it was, a one-line caption
  among two-line ones dropped 10.5 pt and came back up (Scores, Attention,
  Feed-forward, Loss, Backward), and at 375 pt and step 200 Feed-forward's
  three-line box held its captions at three heights. Stages whose captions
  are all one length look as they did.
- **Step menu.** The step on screen is written in the accent, as the button
  writes it and Loop ticks it, and a screen reader hears it as the one
  selected. Its tooltip is "Steps kept whole", Loop's page's own words; it
  said "Checkpoint", a word no page uses.
- **Info sheet.** The lead takes the bright ink the title and headings are
  in, the sections' paragraphs keep the quiet ink (the user's pick), and a
  page ends 24 pt under its last line: the last section's 20 pt had stood
  on the list's own 24.
- **Loop's scale names.** "nats" over the curve's numbers and "rate" by its
  strip are names, so both are in the label face and end at one x
  (`LoopLayout.namesRight`); numbers and levels stay in the mono. "rate" had
  been in the mono, 22.4 pt wide, 5 pt left of a plot 26 pt in: it began
  1.4 pt off the canvas at every size. The loss written by the run's first
  points (3.220 at step 1) touched "nats"; it now starts clear of it
  (`LoopLayout.writtenLeft`), still over its point. `loop_names_test` holds
  both in the app's fonts; every other frame of every stage is byte for byte
  as it was.

Left as they are: the stage bar's hard edge (a fade would cover the end of
a stage's name that `_reveal` brings just into view), a ▾ beside "Step N"
(it would cost the title its room), the caption's 20 pt margin against the
canvas's 4, and the mixed case of the canvas's notes (words, not the frame).

## Colours

`LmInks`, every one the theme's (`lm_inks_test`): the accent for what flows
forward and the reader's focus; the tracer for what actually came next; the
helix's honey for the loss and everything that flows back from it; the
helix's denim below zero and clay above, from the base tile at zero, for
every signed number (the AVI and ESM-2 page's validated pair); residues in
the walk's own colours, letters knocked out in the ground. A signed number is
shaded in proportion, so most of a layer stays near the tile and what is
large stands out.

## Not drawn

Sampling new peptides (the backend's step 6, not written); the corpus run
on 10,416 peptides; a run trained on demand or with other settings.
