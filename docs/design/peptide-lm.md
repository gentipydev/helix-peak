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
  residual stream at its ten points, the gradient reaching each, every head's attention map (worked out
  again from the layer's input, within 4 × 10⁻⁷ of the layer's own output),
  the logits and the probabilities over the 21 tokens that can follow, and
  the output layer's clipped gradient and update.

Recorded again, the run is the same bytes (CPU, deterministic kernels, one
thread); `trace.py --check --against <service>` is that proof against what
production serves. The run itself:

| | |
|---|---|
| data | six peptides, 174 residues: insulin A and B chains and C-peptide, relaxin A and B chains, copeptin; nothing held out |
| model | 4 blocks of 4 heads, width 16, feed-forward 64: 14,727 parameters (recorded again 16 wide on 2026-10-30, for the Embedding stage's numbers; it was 96 wide, 456,887 parameters) |
| training | AdamW 1e−2 (at 1e−3 a model 16 wide never passes one nat in 200 steps), weight decay 0.1 on matrices, 100 warm-up steps then cosine, clip 1.0, dropout 0, all six a step, 200 steps, seed 0 |
| loss | 3.205 at step 1 (worse than uniform, 3.045) to 0.065 at step 200 |
| baselines | uniform 3.045, unigram 2.856, bigram 2.043 |
| floor | 0.060 = 6 ln 6 / 180: from `<bos>` alone nothing says which peptide comes |
| checkpoints | 1, then the first step under uniform (10), unigram (18), bigram (45), one nat (62) and a tenth of one (93), and 200 |

Dropout is off so that the forward pass drawn is the forward pass trained.

## The stages

Each is a painter in `lib/features/peptide_lm/presentation/scenes/`, a pure
function of the frame, at the checkpoint picked ("Step N ▾"); the loop plays
every step. A tap on a stage plays it once, a beat every two seconds, and it
holds on its last frame until another is tapped, or the same one again.
Beside the caption, a player of that stage alone: Replay, and Play/Pause.
The stage bar keeps its names at full size and scrolls sideways where a
phone is too narrow for all nine; a stage played whose name stands partly
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
   - *the copy*: under x comes a copy of the same peptides, under the
     `target y` tag ("Target y starts as a copy of the same peptides");
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
   (`HelixPeekLM.forward`) in 12 beats. Over the tag, a note says why each
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
   - *the gather* (6.6–9.4): the table goes, and each place's copy of the
     row it read moves to the place's own row, its numbers going before it
     moves and coming back once it has, so that rows passing one another
     never print over each other; the tile that read it goes up to label the
     row, turning back into its residue (x embedded, 22 × 16). Once they
     have landed, the first token's two places are outlined in the accent
     (the two Cs at 6 and 7), the note naming them, and stay outlined
     through the adding: "The two Cs at places 6 and 7 are the same row:
     nothing yet says where each is.";
   - *the position embedding* (9.4–11.4): each place's own row alone, on
     its own colour scale, its numbers to two places, then added ("Adding
     the position embedding, rows 0–21, 42× smaller than the token rows" for
     insulin A at step 1, 5× at step 200); a cell shows one set of numbers
     at a time. Note, three lines, the mental model the user asked for in
     place of "attention alone ignores order": "token row: what the residue
     is, the same for every C / position row: where it sits, the same at
     place 7 whatever is there / added: each place carries both, so the Cs
     at 6 and 7 now differ";
   - *x0* (11.4–12): the sum is `x0`, as the engine makes it; the run's
     stored stream holds it to within its own rounding, and Forward's
     stand-up turns the one into the other ("x0, 22 × 16: the start of the
     residual stream"). Note, what the end result is: "x0: insulin A chain
     as the model takes it in / each row: which residue (token row) plus
     where (position row) / next: four blocks let each place read the places
     before it"

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
4. **Forward.** It opens on Embedding's last frame, pixel for pixel. In its
   first beat x0's rows stand up as the stream's columns, each turning
   upright and landing as its place's column, its first number at the top,
   its numbers going as it narrows; the tiles that labelled the rows come
   down to the token row; the rail comes up with Embed lit, and the head
   maps, faint ("x0 stands up as the residual stream: a column a place").
   The stream is no taller than 250 pt whatever the model's width. The
   stage, the heads included, is the user's to review next (2026-10-30).

   Then the residual stream, a column of 16 numbers a position, rises
   through the tower at the left: each block's LayerNorm, attention (arcs
   from every earlier position into the one in focus, each against the
   strongest, particles riding them; above, each head's causal map, nothing
   above the diagonal) and its contribution added, then the feed-forward
   (each column breathing out to 64 and back) and its contribution added,
   then the final norm.
5. **Predict.** The final column runs down the output layer's 23 rows and
   each row's logit grows; `<pad>` and `<bos>` are struck to −∞; softmax
   turns the rest into 21 bars in the residues' colours, what came next
   outlined. Untrained, after GIVEQCCTSIC the model says K 11%; at step 200,
   S 99.6% (100% as the page rounds it), and S is next.
6. **Loss.** A ghost bar rises to certainty at the target, the gap bracketed
   and read off the −ln p curve; every target's surprise fills a strip a
   peptide and pools into the step's loss, set against ln 21.
7. **Backward.** The bars turn into p − y; the error comes down the tower,
   each module's gradient norm filling its bar and each position's glowing at
   every point of the stream (by step 200 only `<bos>`'s, the unknowable first
   residue, glows); the clip gauge reads the total against 1.0.
8. **Update.** The output layer's weights, then the clipped gradient on them,
   then AdamW's update (drawn magnified, the factor said), then the weights
   moved. Per weight, the gradient differs between modules many times over
   and Adam's step hardly at all. The learning-rate schedule marks the step.
9. **Loop.** The loss curve draws itself past the three baselines to the
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
