# Peptide Language Model: one training run, stage by stage

The home screen's third row. It shows HelixPeekLM, the backend's de novo
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
  and the output layer's weights and biases as the step found them;
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
  float32 rather than int8, the training byte for byte the same), the stream read out early (the final norm and the
  output layer applied at every point before it, with the step's own
  weights: a probe the Forward stage draws, the last point's the model's
  own output), the logits and the probabilities over the 21 tokens that can
  follow, and the output layer's clipped gradient and update. `check_trace`
  holds the insides to each other: softmax of the scores is the map, each
  head's mix its shares of the values, every neuron GELU of its input, and
  the feed-forward adds what the stream gained.

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
     Caption: "Token row + position row, number by number: x0, the start of
     the residual stream". The two Cs stay outlined to the end, and Scores
     draws the outlines over its own rows as it opens, fading them with the
     note. Note, every explanation the user asked for on one screen, a
     thought a line, each short enough to keep one line on an SE (so an
     SE's table loses no room, a Pro's one line, 14 pt): "token row: what
     it is; position row: where it sits / added: each place carries both;
     the Cs at 6 and 7 now differ / size: 43× smaller than token rows at
     step 1, 4× by step 200 / why add: side by side would make 32; every
     layer takes 16 / residual stream: what each block adds to, never
     replaces". The size line is the run's own, at the step in view against
     the first or the last (insulin A: 43× at step 1, 10× at 49, 4× by 200;
     training grows the position rows about twelvefold while the token rows
     stay near 1). The note's room is the tallest it is at any step, so a
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
   - evened out (LayerNorm) on a chart beside it, x0's bars outlined as they
     move: less the mean (C11: 0.08 at step 1), over the standard deviation (1.10), a z-score;
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
     (`query weights · 16 × 16`, as x0's table is named) with where they
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
     comes out of its row, and the places after it are struck through;
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
5. **Attention.** It opens on Scores' last frame, in 12 beats:
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
   - the answers, side by side, are mixed back to 16 ("what C11 read");
   - every place at once: head 1's map, as large as the canvas allows (beats
     5.2–8.6). The two heads' maps stacked beside the table left each half the
     height, rows of 10 pt on a Pro Max and 6.6 at 375 wide, out of line with
     the table's rows; at the user's ask (2026-10-31) only head 1's is drawn.
     - The answers' numbers go, and their box grows out of C11's row into the
       map (beats 5.25–5.9): up to <bos>'s row, down to the column tiles and
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
       places are never read, as the next one is the answer (Shift's y);
       head 2 has a map of its own.
     - Head 1's map at step 1 is diffuse (C11 reads S9 23%); by step 200 it
       is sharp (L13 reads Q5 94%, Q5 reads E4 92%, the G1 and Q5 columns
       bright): over the six peptides the mean top share goes from 19% to
       44%, and rows giving one place half or more from 10 to 59 of 174. A
       "sharpest row" caption was weighed and left out: at step 1 it always
       names row 1's two-way split.
   - the table widens again, out of its tiles, to what attention adds to each
     place, alone on its own scale, then the sums: x0 + attention.

   Over it a note says why each part happens.
6. **Feed-forward.** Block 1's feed-forward, in 10 beats:
   - a copy lifts off the row in focus, its numbers re-written as its
     LayerNorm's, and stands up as the 16 inputs of a network drawn left to
     right, numbers beside them;
   - all 1,024 weights reach the 64 neurons, coloured by the sign of what
     each carries, the signal riding the strongest, each neuron lit by what
     GELU lets through (the caption counts those lit);
   - then the 16 outputs, numbers written;
   - they lie down onto the row in focus, and every place gains the same
     network's output, alone, then added: block 1's output.
7. **Forward.** The pass layer to layer, in 11 beats: block 1's output
   condenses into a network, a row a place and a column a point of the
   stream (x0, then after each block's attention and feed-forward), flowing
   left to right.
   - Lines: in an attention, from every place to each place after it, as
     strong as its share (the heads' mean; no tap picks a head since
     2026-10-31), the place in focus's bright; in a feed-forward, each place's
     own line.
   - Nodes: each is the place **read out early**, the token the output layer
     would give it if the model stopped there, a probe the user chose,
     labelled as one in the note and the About sheet. Each is faded by its
     probability and outlined in the tracer where it is the token that comes
     next.
   - The signal runs block 1 again, then block 2 (its heads' reads for the
     place in focus captioned) and the final norm.
   - Each column then counts the places it reads out right: at step 200,
     insulin A 3 · 5 · 11 · 11 · 21 of 22 and copeptin 7 · 9 · 23 · 30 · 40
     of 40; at step 1, none. C11 reads out T 64% at x0, T 94% after block 1
     (confidently wrong: CCT comes earlier in the chain) and S 100% after
     block 2, and S is next.
8. **Predict.** The final column runs down the output layer's 23 rows and
   each row's logit grows; `<pad>` and `<bos>` are struck to −∞; softmax
   turns the rest into 21 bars in the residues' colours, what came next
   outlined. Untrained, after GIVEQCCTSIC the model says K 10%; at step 200,
   S 99.6% (100% as the page rounds it), and S is next.
9. **Loss.** A ghost bar rises to certainty at the target, the gap bracketed
   and read off the −ln p curve; every target's surprise fills a strip a
   peptide and pools into the step's loss, set against ln 21.
10. **Backward.** The bars turn into p − y; the error comes down the tower,
   each module's gradient norm filling its bar and each position's glowing at
   every point of the stream (by step 200 only `<bos>`'s, the unknowable first
   residue, glows); the clip gauge reads the total against 1.0.
11. **Update.** The output layer's weights, then the clipped gradient on them,
   then AdamW's update (drawn magnified, the factor said), then the weights
   moved. Per weight, the gradient differs between modules many times over
   and Adam's step hardly at all. The learning-rate schedule marks the step.
12. **Loop.** The loss curve draws itself past the three baselines to the
   floor; under it every target's tile lights up with the probability the
   model gives it, all but each peptide's first; the output layer drifts.

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
