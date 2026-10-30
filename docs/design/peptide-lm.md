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
  step found them (the token embedding, 23 × 96, and the position embedding,
  51 × 96; added 2026-10-30, every other byte of the run unchanged), the
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
| model | 4 blocks of 4 heads, width 96, feed-forward 384: 456,887 parameters |
| training | AdamW 1e−3, weight decay 0.1 on matrices, 100 warm-up steps then cosine, clip 1.0, dropout 0, all six a step, 200 steps, seed 0 |
| loss | 3.145 at step 1 (worse than uniform, 3.045) to 0.068 at step 200 |
| baselines | uniform 3.045, unigram 2.856, bigram 2.043 |
| floor | 0.060 = 6 ln 6 / 180: from `<bos>` alone nothing says which peptide comes |
| checkpoints | 1, then the first step under uniform (8), unigram (14), bigram (35), one nat (55) and a tenth of one (100), and 200 |

Dropout is off so that the forward pass drawn is the forward pass trained.

## The stages

Each is a painter in `lib/features/peptide_lm/presentation/scenes/`, a pure
function of the frame, at the checkpoint picked ("Step N ▾"); the loop plays
every step. A tap on a stage plays it once, a beat every two seconds, and it
holds on its last frame until another is tapped, or the same one again.
Beside the caption, a player of that stage alone: Replay, and Play/Pause.

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
2. **Forward.** It opens on Tokenise's last frame, pixel for pixel, and in
   six beats takes the engine's steps from the matrix of ids to the stream
   (the user's ask of 2026-10-30: the stage had jumped from ids to one
   peptide's numbers with nothing between):
   - *the cut* (two beats): the matrix splits as `sequences.batches` cuts it,
     input x the batch less its last place and target y, under it, the batch
     less its first, a place to the left, so each place sits over the token
     it learns; a place whose target is padding dims in both. The
     vocabulary's bars, counts and tags go, and the list closes up into one
     column at the left. Caption: x and y one place apart, 180 targets;
   - *the table* (one beat): y goes off to the right and the other peptides
     fade; the peptide in focus spreads to the token row's places and comes
     down to it, its ids turning back into residues; the list goes up its
     column and in, and its rows grow out into the token embedding, 96
     numbers a token on the stream's own scale (the padding row zero). The
     rail comes up with Embed lit;
   - *the lookup* (two beats): left to right, each place's row in the table
     lights, is lifted, turns upright and lands as that place's column, its
     first number at the top; the first places far enough apart to follow
     one at a time, the rest closer. A repeated id lifts the same row
     again (C's four times in insulin A);
   - *the position embedding* (one beat): each place's own row, alone over
     the columns, drawn larger by as many times as it is smaller than the
     token rows (×54 for insulin A at step 1, said on its tag and in the
     caption), then added; the stream is then `x0` as the run kept it, which
     the sum is to within its rounding, and the head maps come up, faint.

   Then the residual stream, a column of 96 numbers a position, rises
   through the tower at the left: each block's LayerNorm, attention (arcs
   from every earlier position into the one in focus, each against the
   strongest, particles riding them; above, each head's causal map, nothing
   above the diagonal) and its contribution added, then the feed-forward
   (each column breathing out to 384 and back) and its contribution added,
   then the final norm.
3. **Predict.** The final column runs down the output layer's 23 rows and
   each row's logit grows; `<pad>` and `<bos>` are struck to −∞; softmax
   turns the rest into 21 bars in the residues' colours, what came next
   outlined. Untrained, after GIVEQCCTSIC the model says V 17%; at step 200,
   S 99%, and S is next.
4. **Loss.** A ghost bar rises to certainty at the target, the gap bracketed
   and read off the −ln p curve; every target's surprise fills a strip a
   peptide and pools into the step's loss, set against ln 21.
5. **Backward.** The bars turn into p − y; the error comes down the tower,
   each module's gradient norm filling its bar and each position's glowing at
   every point of the stream (by step 200 only `<bos>`'s, the unknowable first
   residue, glows); the clip gauge reads the total against 1.0.
6. **Update.** The output layer's weights, then the clipped gradient on them,
   then AdamW's update (drawn magnified, the factor said), then the weights
   moved. Per weight, the gradient differs between modules many times over
   and Adam's step hardly at all. The learning-rate schedule marks the step.
7. **Loop.** The loss curve draws itself past the three baselines to the
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
