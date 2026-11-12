# Helix Peek — app

Helix Peek is a Flutter app that walks one protein from its gene to its fold:
a grid of squares morphs through gene, mRNA, protein and mature chains, then
ends on the 3D structure. Each curated protein is drawn from a
stored GenBank record plus its evidence tracks (ESM-2 constraint, AlphaGenome
variant impact, ClinVar, fold). Any other reviewed human protein can be built
on demand, with its record, its ESM-2 track, its AlphaGenome and ClinVar
tracks, and its fold: an experimental PDB entry chosen by rule, which folds
as the twenty's do, or AlphaFold DB's model where the PDB has none that
passes. All of it is served by `../helix-peak-backend`; the app ships no
protein data.

## THE CONTRACT — read this first

Two things are frozen. The code is not.

1. **BEHAVIOUR.** The walk (`lib/features/gene_lookup/`) renders and responds
   exactly as it does now. You may move its files, promote its widgets into
   the shared layer and change import paths anywhere. You may not change what
   it draws or how it responds.
2. **DATA SHAPE.** The catalog payload and every existing track's bytes, format
   and provenance stay as they are: no new column on the protein table, no new
   field in `targets.py` or `curated/catalog.json`, no edit to an applied
   migration. New data is a new track kind (`TrackKind`).

**Promote, don't clone.** A widget a new flow needs is promoted into the shared
layer, and the walk and the new flow both import it from there. Duplicate only
when the extraction cannot be done without changing behaviour, and say so.

**Every session proves itself** with a zero render baseline diff and a green
suite. Done means all of these:
- `flutter analyze` and `flutter test` green with **no walk test edited**. A
  walk test that had to change means behaviour changed: stop and say which.
- The render baseline diffs to zero. Never regenerate it to make a session pass.
- `git diff -M --stat` shows moved files as renames, not rewrites.

**An edited walk test is a failure, not a fix.** A walk test is any test
committed before the session began under `test/features/gene_lookup/`,
`test/core/` or `test/goldens/`, along with the `test/support/` helpers and
`test/fixtures/` files those tests read. A session may change exactly one thing in them: an `import`
line that follows a file the session moved. Anything else is an edit: an
expectation, finder, key, type name, pump duration, surface size, text scale or
fixture; a loosened matcher; a `skip`; a deleted test; and a regenerated
golden (`test/goldens/**/*.png`). If a refactor needs any of these, it has changed
behaviour. Revert the step, name the test and the assertion that failed, and
say what the walk now does differently. Walk behaviour changes only when the
user asks for it by name. The tests read internals (`AnatomyPainter`'s `scene`,
`maskedIndex`, `groove` and `tracer`, panel and strip fields, over 40
`ValueKey`s), so a rename or reshaped field that a test names falls under this
rule too: list it for its own session and make the test edit there, with the
user's approval. Adding a test is always allowed. So is adding a curated
protein to `test/fixtures/`: its files, and its row in `catalog.json`, after
the rows already there (the curated list grows, the user's decision of
2026-10-17); the walk's tests then run on it too, and a new protein's golden
pages are added PNGs. Before committing,
`git diff -M -U0 --diff-filter=MRD <start> -- test/features/gene_lookup test/core test/support test/goldens | grep -E '^[+-]' | grep -vE '^(\+\+\+|---) |^[+-]import '`
must print nothing, and `python3 tool/fixtures_added_only.py <start>` and
`git diff --quiet --diff-filter=MRD <start> -- 'test/goldens/**/*.png'` must
exit 0 (the first command cannot see a PNG change: git prints "Binary files
differ" for it, with no `+` or `-` line), where `<start>` is the commit the
session began from.

Git: commit the session's own changes locally. Never push, in any form.

## Extraction discipline

1. **Move, don't improve.** A move changes paths and imports only. List any
   rename, parameter change, comment tidy or lint fix for its own session.
2. **Defaults preserve behaviour.** A new parameter on a shared widget defaults
   to what the walk does today, and a test pins that default.
3. **No caller-aware branches in shared widgets.** A shared widget never asks
   who is calling. Variation belongs in the caller.
4. **Refactor sessions are separate from feature sessions.** Never do both.
5. **Extract on demand.** Promote only what the current session needs.

## Where code lives

- `lib/core/`: biology tables and `GeneRecord`, the parsed GenBank record
  (`biology/`); `ProteinTarget`, `ProteinTrack` and `GeneQuery`, and
  `ProteinResolver` with its `ProteinSuggestion` and `ResolveStatus`
  (`catalog/`); the evidence tracks as entities (`GeneClinVar`,
  `ProteinConstraint`, `GeneImpact`, `ImpactExplanations`, `VariantEvidence`)
  and `ImpactExplanationRepository` (`evidence/`); `.env` config, DI,
  network, router, theme. It is not
  feature-free yet: `di/` and `router/` import `gene_lookup`.
- `lib/shared/widgets/`: the app chrome (`AppLogo`, `ErrorView`,
  `LoadingView`). Nothing promoted goes here.
- `lib/shared/<area>/`: promoted code, in the sub-folder it had in the walk.
  `presentation/<area>/<file>.dart` becomes `lib/shared/<area>/<file>.dart`.
- `lib/shared/helix/`: the home screen's double helix as geometry
  (`HelixModel`), promoted out of `lib/features/home/` for the lab's
  replication flow, and its painter (`DnaHelixPainter`), promoted for the
  zoom's DNA stop. The home screen's widget stays in home.
- `lib/shared/ribosome/`: translation on the ribosome (`TranslationTimeline`,
  `TranslationDirector`, `CaptionGenerator`, `TranslationPainter`), its
  player (`TranslationPlayer`) and the chain's flight into the protein page
  (`TranslationFlightPainter`): the walk's ribosome. The lab had it first and
  no longer has one. The NMD threshold it shares with mutate is
  `lib/core/biology/nmd.dart`.
- `lib/shared/folding/`: a chain folding, promoted out of the lab for the
  walk's fold page, which the lab no longer has. `FoldTimeline` tells it in
  four steps (hydrophobic collapse, helices coil, strands pair, bridges snap
  shut) from the `folding` track (`pipeline/folding` in the backend): each
  chain's CA trace and secondary structure in the stored model's frame, and,
  since schema 2, the model's bridges atom by atom, its cartoon's sizes and
  its ribbon as measured by each helix and strand residue. The ribbon it
  folds is the model's own mesh: `FoldSkin` binds each chain node of the
  loaded model to the chain ring by ring (PyMOL's strips give every vertex its
  ring) and carries it as the chain folds, each residue growing from a thread;
  `FoldBonds` grows the model's own rods. `FoldMesh` draws what the model does
  not: beads that melt, and threads for residues the entry never placed,
  which shrink away. `StructureView(folds: true)` draws it in its own scene
  (`lib/shared/structure/fold_morph.dart`), plays it each time the page opens,
  with no words on the page (a screen reader hears each step's name), and
  swaps the untouched model in at the end, which changes no pixel: once the
  bridges close, the fold is the model float for float;
  `folds` defaults to false, the finished fold. The
  scene holds the model with z negated, and so does the fold
  (`docs/folding-renderer.md`). Reduced motion, no ready track, or a model the
  fold cannot be bound to, opens on the model.
- `lib/shared/share/`: sharing, promoted out of the lab for the walk.
  - It draws a flow's frames offscreen, one at a time (`FrameRenderer`).
    Each frame carries the protein's link, `helixpeek://open/gene/<slug>`
    (`geneLink`), the scheme `AndroidManifest.xml` and `Info.plist`
    register. Flutter hands the path to the router.
  - Clips (`VideoEncoder`) are made on Android and iOS, on channel
    `helixpeak/share/video_encoder`, one frame per call: MediaCodec and
    MediaMuxer in `android/.../VideoEncoderChannel.kt`, and AVAssetWriter in
    `ios/Runner/VideoEncoderChannel.swift` (`docs/video-encoding-spike.md`).
    Other platforms share nothing. The next frame is drawn while the
    platform encodes the last, never more than one sent. On Android a clip
    goes on while the app is away: `ClipKeepAlive` (channel
    `helixpeak/share/clip_keepalive`) starts `ClipExportService.kt`, a
    foreground service (`mediaProcessing` from Android 15, `shortService` on
    14) with a wake lock and the clip's progress in a notification, which
    can stop it. Swiping the app out of Recents ends it, with its engine.
    On iOS nothing may draw in the background (Flutter parks `toImage`, and
    no iPhone offers background GPU), so a clip pauses with the app: as the
    app leaves, `VideoEncoderChannel.swift` finishes the part it is writing,
    the next frame starts another, and `finish` joins the parts without
    encoding again. Frames of a part that could not be finished are drawn
    again (`FrameRenderer.frames(from:)`). Where nothing keeps it going or
    pauses it, an export is cancelled, its file deleted, if the app is
    paused.
  - On Android a frame crosses as NV12, packed on the GPU (`Nv12Packer`,
    `shaders/nv12_pack.frag`) with the Kotlin loop's own integer BT.709
    coefficients, so Kotlin only copies rows. Each launch packs a small
    frame and compares it with `nv12Reference` first; where they differ, and
    on iOS, frames cross as RGBA. `--dart-define=CLIP_TIMING=true` builds
    report each clip's time per step (the clip's sheet, and the log), and
    `CLIP_NV12=false` forces RGBA to time the two against each other.
  - A clip is a job of the whole app (`ClipExporter`, provided in
    `core/di/dependencies.dart`), one at a time, so it outlives the page that
    asked for it. `ShareClipButton` starts it and shows it in a sheet
    (`showClipSheet`) that can be put away while it goes on; the button then
    wears its progress as a ring. A made clip waits for Share. One that ends
    while no sheet shows it is said in a snackbar on any screen
    (`ClipReadyListener`, in `MaterialApp.builder`). Between frames the job
    gives way to the app's own (`ClipExporter.giveWayToFrames`).
- `lib/features/gene_lookup/`: **the walk**. It has `data/`, `domain/` and
  `presentation/` (`anatomy/`, `clinvar/`, `constraint/`, `inspector/`,
  `structure/`, `cubit/`, `screens/`). The mRNA page, untouched, offers
  "Ribosome ›" in its header: the translation plays over the page on the
  shared player, under the walk's header, and at the stop codon the chain
  flies into the protein page, which the walk turns to under it
  (`anatomy/walk_ribosome.dart`). While it is up, the header shares it as a
  clip (`lib/shared/share/`), and the stage bar
  stands down, its band given to the player's controls: no swipe turns a page
  until the chain has landed, and Back puts it away onto the transcript.
  Without it the swipe plays the walk's own translation, as it always has.
  The gene page, with nothing picked, offers "Zoom ›" in the same place for
  a protein whose `locus` track is ready, and never in a ClinVar landing:
  it opens the zoom over the walk (see "Zoom" below), which comes back to
  this page. A protein with no ready locus is drawn as it always was.
- `lib/features/home/` and `lib/features/search/`: the home screen and the
  search: the curated list, and below it every reviewed human protein, which
  can be built on demand (its own `ProteinSuggestionsCubit`; the builds are
  the app's, see "How data arrives" 4). With nothing typed, two tabs sit
  under the field: Curated, which it opens on, and Built on demand, every
  install's builds (`BuiltProteinsCubit`); typing hides them, and a search
  covers everything whichever was chosen. Search is not the walk; it reaches
  the walk only by opening `/gene/<slug>`.
- `lib/features/replication/` and `lib/features/zoom/`: the replication tour
  and the zoom (see "Replication" and "Zoom" below).
- `lib/features/peptide_lm/`: the peptide language model's recorded training
  run, stage by stage (see "Peptide Language Model" below).

There was a lab (`lib/features/lab/`, behind `LAB_ENABLED`) where flows were
tried before they earned a place; replication, the zoom, the fold animation
and the walk's ribosome came out of it. It was deleted on 2026-10-09 with
every flow still in it. Links from then (`/lab/replication`, `/lab/zoom`)
still redirect; `/lab` itself is not a page.

`test/architecture_test.dart` holds that layering to the import lines:
`core/` and `shared/` import no feature, and no feature imports another's
`presentation/` (domain entities are the crossing point), so no feature reuses
the walk's screens or its cubit. The imports that already broke it are listed in its
`knownBreaches`. The list may only shrink: close an entry by moving code,
never by adding one.

Domain code must not import `package:flutter/material.dart`; `@immutable`
comes from `flutter/foundation.dart`. There is one existing violation:
`lib/core/catalog/protein_target.dart` imports material so that `ChainTint` can
name a colour. Don't copy it. Colours come from the theme (`AppColorTokens`,
`context.nucleotideColors`, `context.anatomyColors`), never from a raw hex.
The whole app is on one ground: `AppTheme.analysis`, the walk's, is the app's
theme, and home wears `AppTheme.home`, the same ground with the helix in its
own bases (`NucleotideColors.helix`: the convention warmed and softened, never
more saturated than the accent; the zoom's DNA draws them too). The walk letters
its bases in `NucleotideColors.muted`, and `NucleotideColors.dark`, the
convention at full strength, is the reference both are measured from.
`AppTheme.dark`, the cool ground the app began on, is worn by no screen; the
walk's tests still set the walk inside it. Small print is
`theme.caption` (`core/theme/app_typography.dart`), never a bare `bodySmall`,
which is Material's in the bright ink.

## Replication (`lib/features/replication/`)

A story of its own subject at `/replication`, in every build: no record and
no track. Home offers it as its DNA Replication row only where `.env` sets
`SHOW_DNA_REPLICATION=true` (`Env.showDnaReplication`, off by default, the
user's choice of 2026-11-04); the route is there either way. It began in the lab
and left it; links from then (`/lab/replication`, `/lab/replication/<slug>`)
redirect. `replication_routes.dart` wraps it in `AppTheme.analysis`, which the
lab's shell used to give it. A 212 s guided tour (`ReplicationTimeline`,
chapters in `replication_tour.dart`) on an illustrative sequence
(`GenomeReplication`): an A/T-rich origin licensed
by ORC, Cdc6 and Cdt1 with an MCM2–7 double hexamer, fired into two CMGs and
a bubble, then the upper fork through two Okazaki fragments, topoisomerase
II, primer replacement and ligation, ending on the whole bubble. The lower
fork is the upper one turned 180° about the origin: the model mirrors its
pieces onto the other template (`ReplicationFrame.pieces`), and the painter
draws a turned pass. Everything on screen is a continuous function of time:
exact strand ends (`DaughterPiece`), staged as keyed values
(`ReplicationStaging`), and `replication_smoothness_test` walks the tour at
60 fps and fails on any jump, pop or kink. One colour per strand, from theme
tokens (`ReplicationInks`): grey parental, teal new DNA, amber RNA. The DNA
and the rings (`replication_rings.dart`: PCNA, MCM2–7, RFC, ORC) are drawn
flat, the rings in two halves round the DNA; the other proteins are lit,
folded envelopes, and topoisomerase II has its own (`replication_topo.dart`).
A label's line must land on what it names (`replication_targets_test`).
`docs/design/replication-fork.md` has the design and its sources.

## Peptide Language Model (`lib/features/peptide_lm/`)

The home screen's last row, at `/peptide-lm`, in every build: one training
run of the backend's de novo model, HelixPeekLM (`pipeline/denovo/` in the
backend), on the curated proteins' peptides, played stage by stage. It is a
recorded run and says so ("Recorded run" under its title; where the header
is narrower than the title or that line, each shrinks just enough to stay
whole, never cut, and the Step menu is as wide as its widest step, so the
header never moves when the step changes: the user's pick of 2026-11-10): the backend's
`trace.py` drives the engine's own `train_step` and keeps every number, and
`GET /peptide-lm/runs/curated` names the bytes in storage, which the page
reads through `TrackClient.readRow` (its own client, folder `peptide_lm`, so a
run never evicts a protein's track): the row kept on disk opens the run while
the service is asleep. `TrainingTrace.parse` refuses another run, another
schema or an array of another shape; the payload's shape is the backend's
`check_trace.py`.

Twelve stages (`TrainingTimeline`, 266 beats), named on the shared
`StageBar`, which scrolls sideways at full size where a phone is too narrow
for it (a stage played whose name is partly out of view is scrolled just
far enough to show it whole). A tap on a stage plays it once from its start, at the page's one
speed, a beat every two seconds (`TrainingRunView.beat`, the old 0.5×), and
it holds on its last frame (`TrainingTimeline.frameIn`); nothing runs on
into the next stage, and a tap on the stage on screen plays it again. The
page opens playing Tokenise. Beside the caption, the stage's own player
plays that stage and nothing else: Replay, and Play/Pause (Play from the
end plays it again); no stepping between stages and no speeds (the user's
choices of 2026-10-30, which retired the shared `TransportBar` here). The
caption's box is held at the stage's tallest caption at its width, so the
canvas never resizes while a stage plays, and each caption starts at the
box's top, so a stage's first line never moves (the user's pick of
2026-11-10). Tokenise, Shift, Embedding, Scores, Attention,
Feed-forward, Forward, Predict, Loss, Backward and Update show one training step at the checkpoint picked ("Step N": the
steps the run kept whole, the one on screen in the accent in its menu, as Loop ticks it), and Loop plays all of them, from step 1 (`LoopPace`). Each stage is a painter in
`presentation/scenes/`, a pure function of the frame; a tap or a drag on the
canvas puts a peptide, a position or an attention head in focus. Shift
opens on Tokenise's last frame, pixel for pixel (`TokeniseScene.paintEnd`,
`TokeniseEnd`), and draws input x and next token y one place apart
(`shift_scene.dart`): the batch opened out into its peptides, input x, what
the model reads; under it a copy, target y, the answer key, in the same
columns; and every line of the copy moved one place left, so that each place
of y holds the token after the same place of x. Only x goes into the model;
Loss grades its guesses against y. Embedding opens on Shift's last frame, pixel for
pixel (`ShiftScene.paintEnd`, `ShiftLayout`), and in 15 beats draws the
engine's steps from ids to x0 (`embedding_scene.dart`): the token embedding
across the whole width, every number written out on a soft tile of its colour
(`LmInks.cell`) to two places, and only where it fits; each id lighting the
row it reads, one place at a time; the rows read gathering in place order; each place's position
row, alone and then added; and their sum, x0, both tables the run's own (each
checkpoint keeps them whole, float32, since the run's schema 2 of
2026-10-30), and over the table a note of why each part happens. The run is 16 wide
for it, two blocks of two heads (recorded again on 2026-10-30, 8,167
parameters; schema 4 since 2026-10-31: the stream kept whole, each block's
insides, the row each block's attention reads evened out with its LayerNorm's
scale and shift and the weights that make the queries, keys and values, those
whole, and the stream read out early; schema 5 since 2026-11-01: the output
weights that mix the heads' answers back into one row, and the heads' mix
whole; schema 6 since 2026-11-02: the output layer's weights at each
checkpoint and its logits whole, for Predict; schema 7 the same day: the
loss's gradient at every point of the stream, whole, for Backward; schema 8
since 2026-11-03: the output layer's clipped gradient, AdamW's two running
averages for it as the step found them, and the update, whole, with the
optimiser's settings, for Update; schema 9 the same day: every step's
probabilities over the tokens that can come next at every place, for Loop,
a kept step's the same bytes as its checkpoint's). The
forward pass is four
stages, each
opening on the last frame of the one before, pixel for pixel, on Embedding's
layout, a row a place (`StreamTable`, `stream_table.dart`), the user's splits
of 2026-10-30 and 2026-10-31. Scores, Attention and Feed-forward work block 1
alone and name it on what they label: `block 1 · query weights · 16 × 16`,
`block 1 · head 1 · values`, `block 1 · head 1 · shares in % · 22 × 22`,
`x0 + block 1's attention`, `what block 1's feed-forward adds` (the user's
ask of 2026-11-02, after the stages read as the whole model until Forward
showed a block 2); block 2 is Forward's:
- **Scores** (`scores_scene.dart`), block 1's attention up to its shares,
  opens on x0's table. The table narrows to a strip a place, and a copy of the
  row in focus stands up on the bench at its right, evened out on a chart
  beside it: less its mean, over its standard deviation (a z-score), its
  bars hanging from the mean line, so the first slides the whole row onto
  zero as one and the second draws every bar in by the same factor, a
  faint tail where each stood (the user's dislike of 2026-11-01: bars on
  zero shrank and grew unevenly, x0's outlined over them); then
  the norm's learned scale and shift, written out where the chart was, a row
  a number, as the sum `z-score × scale + shift = evened` (every scale 1 and
  shift 0 at step 1). Then the row times the model's own weights, a query, a
  key and a value of 16 in turn (the user's ask of 2026-10-31, to read as a
  vector times a matrix drawn at random from the run's seed and nudged by
  every update): each part's column stands as empty slots, the query nearer
  the row and room between the three, with no strings yet (the user's word:
  no strings before the row flows). Then the row flows through: each number's
  16 strings burst out of the row, lit, each carrying its number times its
  weight, a dot at each tip, the number made only as they land (the query's
  first alone and slowly, the rest in a cascade; the key's and the value's
  one cascade each), the later strings passing behind the columns already
  made. Landed strings stay, faint, a weight on each (colour its sign,
  strength its size), until the next part's slots come: the part's 16 × 16
  weights, named on a plate under them, `block 1 · query weights · 16 × 16`, with where
  they stand, `random start (seed 0), no update yet` at step 1 and
  `random start (seed 0), then N training updates` later. Each column then parts into a slice a head (head 1
  numbers 1–8, head 2 9–16: why the width must divide by the heads, and the 8
  of √8). Head 1's query and key lie down by the row in focus and every place's
  key comes out of its row, under head 1's tag (`block 1 · head 1 · query and
  keys`); x0's tag steps aside just before it comes and is back once head 2's
  tag has gone in Attention (the head tag lay on its tail, `22 × 16` showing
  through its plate; the user's pick of 2026-11-02). One score is worked out
  on the bench, the top one: query over key, their products number by
  number, the sum, over √8; then
  the query passes every key up to its own. Softmax makes the scores shares,
  a bar each across the bench, where the stage ends (the √8 slide that showed
  why the scores are divided was removed at the user's word, 2026-10-31, as
  redundant). Shares are softmax of the kept scores, whole, here and
  in Attention (`AttentionScene.shares`).
- **Attention** (`attention_scene.dart`) opens on Scores' last frame. Head 1's
  keys turn into values and arcs carry each share of each value into the
  head's answer, as its bars go; an arc from a row near the answers' own
  rises first, just enough to keep half a row above the answers it passes
  over (more for each row higher, so they nest), and comes down onto the
  middle of its answer from above. The places after it are struck through. Head
  2 reads in full, quicker. The heads' answers, on the row in focus, take the
  room right of the keys that the arcs leave them (at least 50 pt). Side by
  side, they go through the output weights as Scores' row goes through the
  query's (the user's choice of 2026-11-01, over strings down to a segment
  under the row), but first, as soon as head 2 has read, number 1 of head
  1's answer is worked out (`worked_answer.dart`, 9 beats, the user's ask of
  2026-11-01: where each place's value comes from, and how the values make
  the answer). No number of the answers is written before it is: they stand
  up off the row straight to the bench's right edge, a slice a head, faint
  and unwritten, number 1 an empty slot (the user's ask of 2026-11-02:
  showing the numbers, explaining them, then showing them again said
  nothing); a copy of the row in focus stands up where Scores stood it, evened,
  and the 16 value weights into number 1 run from it into a cell on its row,
  number 1 of its value as Scores made it (insulin A's C11 at step 1:
  −1.22); `<bos>`'s row takes its place and the same weights make its own
  (+0.11; the user's pick: the place in focus, then `<bos>`); every other
  place's comes on its row; each is written times its share (to a tenth, so
  share × value reads right), what it adds after it; then one place at a
  time, each with its own caption and its reasons lit in the accent, the
  largest share and what it adds, then the place that adds most and why
  (the user's ask: "brings most" and "read most" said nothing); those run, a
  string each, into the slot and make it (0.30, the first time it is
  written); numbers 2–16 come, written, with a caption (the user's pick, no
  pass over them), and the column goes where Scores stood the evened row,
  with Scores' cut and the heads named. Then an empty column
  stands where Scores stood the query, the plate `block 1 · output weights · 16 × 16`
  under the strings (`weight_flow.dart`, promoted from Scores); each number
  of what attention adds is made as its 16 strings land, number 1 alone and
  slowly ("Output number 1": insulin A's C11 at step 1, 0.11, which only
  rounds like `<bos>`'s value 1), the other 15 in one cascade; the bench
  clears and the column lies down onto the row, where the answers sat. Every
  place at once then fills head 1's
  map, as large as the canvas allows (one map at a time, the user's ask
  of 2026-10-31). The answers' box grows out of the row in focus into the
  map, up, down and left to the token column, as the table narrows to that
  column, which names the map's rows; the map lies on the table's own rows,
  the places read named by tiles under its columns. It comes in as empty
  slots, the places after each row hatched; the row in focus fills first,
  with the shares Scores found, then every other row, each share on a soft
  tile and written as a percentage where it fits. A tap on a row of it puts
  that place in focus. Then head 2's map takes the same rows (the user's ask
  of 2026-11-02: what attention adds is both heads' answers through the
  output weights, and only head 1's map was drawn): head 1's cells empty to
  their slots, `block 1 · head 2 · shares in % · 22 × 22` takes the tag's
  place, and head 2's map fills the same way, a little quicker, its caption
  counting the rows whose place read most changes (insulin A at step 200:
  17 of 22; 19 at step 1), its note that the two answers, side by side, go
  through the output weights. The table widens again to what attention
  adds, alone ("Every row made as C11's: both heads' answers × output
  weights"), then the sums, `x0 + block 1's attention`. 25 beats.
- **Feed-forward** (`feed_forward_scene.dart`), block 1's: a copy of the row
  in focus, `x0 + block 1's attention`, turns straight off it and stands up as
  the 16 inputs of a network drawn left to right (no lift-off first since
  the chart came, the user's word of 2026-11-01). Before any weight is drawn, the block's
  second LayerNorm evens the inputs out on Scores' own chart beside them
  (`ScoresScene.eveningChart`, shared, Scores pixel-identical), where the
  network will be: less their mean, over their standard deviation, then the
  norm's own scale and shift, each step its caption with the row's own
  numbers (the user's asks of 2026-11-01: the copy's numbers changed with
  nothing saying why, and numbers changing alone still did not explain it).
  The run keeps no scale and shift of this norm, only what it made
  (`Evening.plain`), so the last step says evened = z-score where the run's
  numbers show that (step 1) and names the learned scale and shift
  otherwise. The chart goes and the weights grow from the evened inputs. All
  1,024 weights reach the 64 neurons, each line coloured by the sign of
  input × weight. Then GELU is worked out (the user's asks of 2026-11-01:
  the explanations as clear as they can be, GELU said; taken out for a
  note and a small curve, then wanted back to see how GELU is worked
  out): the brightest neuron's 16 lines stand out, a dot running once along
  each, GELU's curve beside them from then on, and the caption gives its
  sum (`FeedForwardScene.sums`: the evened row × its
  weights + its bias, from the run); GELU's curve is drawn right of the
  neurons, where the outputs will be, its line in the accent (`GeluChart`,
  `FeedForwardScene.gelu`, x · Φ(x) as the engine's `nn.GELU`); the sum
  goes up to the curve and across to what it passes on; then the neuron
  with the most negative sum, nearly silenced; then every neuron at once,
  lit by what it passes on, a dot for each that lights along its strongest
  input, and the curve its line alone (the user's word: no points on it). Notes say
  what a line is (weights' random start or updates since), what a weighted
  sum is, what GELU is, and why the bend (without it the two layers are
  one weighted sum). Then come the 16 outputs (each output's dot along its
  strongest neuron; no GELU), which lie back down onto the row, and what
  every place gains, alone, then added: block 1's output. 20 beats.
- **Forward** (`forward_scene.dart`), the place in focus's row through the
  whole pass, layer to layer, down the canvas (`TowerLayout`; the user's ask
  of 2026-11-01, the old network of tokens being crowded and not
  explanatory): a slot a point of the stream, the table's own columns, each
  named over it (x0, + block 1's attention, ..., final LayerNorm: what
  Predict reads). It opens on Feed-forward's last frame: the table goes and
  the place's row waits, faint, in block 1's output's slot while the route
  comes in as empty slots; x0 fills the top. A part at a time, what it adds
  comes in as a thin strip (one scale for the four) and a copy of the row
  above drops through it into the next slot, turning into the sum: block 1's
  two onto the row that waited, then block 2's. Block 2's attention reads
  every place's row as block 1 left it (the note: each block after the first
  reads the rows the one before left), so its caption follows its head 1's
  top read back into block 1: `In block 2, C11 reads T8 46%, which in block 1
  read C6 37%` (insulin A at step 200; at step 1 Q5 12%, which read E4 33%).
  Where the place read is the one in focus, or read itself most in block 1,
  there is no second hop, and it sets the top read against block 1's,
  `In block 2, V3 reads V3 51% (block 1: G1 89%)` (step 200; 430 of the run's 1,260
  places and steps; the two-hop replaced that comparison wherever there is
  one, the call the user left to me on 2026-11-02, for both do not fit two
  lines at 375). The last drop goes through the final LayerNorm
  (mean and standard deviation in the caption; z-score at step 1, its own
  learned scale and shift after), and that row, outlined, is what Predict
  reads. Each row writes its numbers from when it lands to the end, so x0's
  can be read against every row after it (the user's ask of 2026-11-02; each
  copy drops out from under the row it copies, its numbers left clear), in
  the ladder's own face (`TowerLayout.numberStyle`, so a 40-place peptide's
  numbers show too).
  Once the table has gone a tap asks for nothing. 12 beats. Until
  2026-11-01 Forward drew every place read out early through the output
  layer (a probe, the user's pick of 2026-10-30) as a network of tokens; it
  drew Predict's layer and Loss's grading before either stage and at step 1
  read nothing right, so it left the screen. The run still keeps the
  readout; it is for Predict's review. A Block 2 stage (block 2's map, then
  what its parts add) was built the same day and removed at the user's word
  as redundant with the ladder; don't re-add it.

**Predict** (`predict_scene.dart`, 14 beats, the user's picks of
2026-11-02) opens on Forward's last frame, pixel for pixel
(`ForwardScene.paintEnd`, `ForwardFade`), and turns the place's last row into
a guess, as the engine's output layer and softmax do (`PredictLayout`, on
Embedding's): the ladder goes and the row turns off its slot into a standing
column at the left; a slot for each of the 23 tokens stands at the right, its
tile beside it, in id order, under the plate `output layer · 23 × 16`. The
row flows through the output layer's weights as Scores' row goes through the
query's (`weight_flow.dart`): the top logit alone and slowly, its caption the
sum (insulin A's C11 at step 1: K, 1.00), then the other 22 in one cascade,
the 368 strings left faint. `<pad>` and `<bos>` are struck to −∞, the bench
clears and the logits slide left; softmax is worked out in two steps, each bar
growing to e to its logit, the largest across the room (e to K's 1.00 is
2.72; at step 200 e to S's 9.14 is 9,318 and the rest vanish), then every bar
shrinking by their sum (27.12) into its share of a dashed 100% (K 10%), what
came next lit: a soft band toward the tracer behind its row, from its tile to
the dashed 100%, the room its bar would fill if right and certain (the user's
ask of 2026-11-02, replacing the white box there too). Then every place at once, on a map of its
own look (the user's picks of 2026-11-02, after the first map, head 1's tiles
with a number on every cell and a white box on each answer, read as noise:
at step 1 the cells spanned ~1.4:1 while the boxes and 462 numbers stood at
~10:1). Each share is a square in a dark slot, its area that share of the
slot's (`PredictScene.slotOf`/`fillOf`, the slot the largest square its cell
holds), so a place's squares add up to one slot; no number in the field and
no outline. Each bar goes into its square in a standing column of slots, the
light on what came next gathering into its slot, and the column
lies down onto the place's row (`StreamTable.turn`, the strip's turn,
promoted); every other row's squares grow in, top to bottom. Then the slot of
what came next at every place lights, a soft fill toward the tracer
(`drawSlot`, never louder than the squares), and the answer key comes in at
the map's right: each row's next token, Shift's y, on a tile as large as the
row's own, and p(y), the share the guess gave it, the number Loss scores
(`PredictLayout.answerTile`, `givenStyle`; titled `y` and `p(y)`). A right
and certain guess is one square filling its lit slot: the top guess is right
at 0 of insulin A's 22 places at step 1, 21 at step 200 (`<bos>`'s row
spreads a sixth over the six first residues). Shares are softmax of the whole
logits, as Attention's are of the whole scores, and Loss's and Backward's
are Predict's. On the bench a tap asks for nothing; on the map a
row, or its answer, puts its place in focus.

**Loss** (`loss_scene.dart`, 17 beats, the user's picks of 2026-11-02)
opens on Predict's last frame, pixel for pixel (`PredictScene.paintEnd`,
`PredictFade`), and scores each guess by −ln p(y), then takes their mean
(`LossLayout`, on Predict's): every cell of the map but what came next goes,
and each row's lit slot slides along its row to the key, beside its y, the
focus row's outline narrowing with it. On the bench that leaves, −ln p(y) is
worked out on its curve, as Feed-forward works GELU (`LossChart`): p(y) from
0 to 100% along, nats up, the curve drawn from a sure, right guess up; an
even guess, 1/21 a token, costs ln 21 = 3.045 on a dashed line across it;
then the place in focus's square flies down to the p(y) axis and a guide
runs up to the curve and across to its cost (insulin A's C11 at step 1:
1.34%, −ln 0.0134 = 4.31, the sum worked from the share as written). Then
the targets, paying Shift's y off (the user's choice of 2026-10-30), the
peptide first and then the batch (the user's ask the same day, the six at
once having read as crowded): the key's y tiles tip over to the left about
the column's last tile, kept upright, into the peptide's line of target y
alone across the canvas, as Shift drew it, the cost's axis in whole nats at
its left, and a bar rises on each target to its −ln p(y), the even guess
dashed across, the place in focus's bar in the loss's full honey with its
cost over it, the others quiet (honey at half strength, the user's choice
over residue colours, whose lightness skews heights). The line then shrinks
into its place among the batch's lines, the other five come in, their
padding dimmed and never scored, and their bars rise, on one scale for
every step (`LossScene.ceiling`, 5 nats). Last, their mean, the step's
loss, as LayerNorm's chart draws a row's mean: a line in the loss's full
honey draws itself across every line's bars, named "mean" once, the bars
left at their own heights, and a legend names the loss and the even guess
(the bars levelling out into the mean, with ghosts, was tried first and
left the user asking why every bar changed; don't bring it back). The last caption names what the
checkpoint was kept for passing (worse than an even guess at step 1; first
under it, under residue counts, under residue pairs, under one nat, under a
tenth; at step 200, the floor, 0.060), and where the `<bos>` places hold
over half the loss the note says so (93% at step 200: from `<bos>` alone no
model can know which of six peptides comes). Each p(y) is Predict's own
share: −ln of it is the run's kept loss for that target within 5 × 10⁻⁴ at
every checkpoint, and their mean the step's loss (`lm_scenes_test`, the live
check). On the table a row puts its place in focus, and so does a target of
the line alone; on the batch a line puts its peptide in focus, and a target
of the focus line its place; while the key swings, or the line shrinks, a
tap asks for nothing.

**Backward** (`backward_scene.dart`, 46 beats, the user's picks of
2026-11-02) is the forward pass played back, along the same strings and the
same ladder, carrying how the loss would change instead of numbers. Every
mini-step holds for its own caption (what happens, in the run's numbers) and
its own note (why), and names its marks on the canvas where they need it (the
user's ask, the same evening: "as many explanations as possible"): the
answer key y as the target's lit row, brightened while read; a legend line over the bars, in
the rows of the two tokens that never come next, naming each colour of
p − y as it comes and their sum to 0; the first gradient number worked out
in a box beside its strings (the three tokens bringing most, error × weight,
the rest, the sum); the gradient read, its most negative and positive
numbers ringed; the strongest string's error × number written on it; and at
each + of the climb one number worked out beside the part's name, its three
tiles ringed (`number 10: −0.17 + 0.02 = −0.15`, without "number" where only
that fits), the final LayerNorm's spread beside its own. It opens
on Loss's last frame, pixel for pixel (`LossScene.paintEnd`, `LossFade`,
whose `zoom` takes the line in focus back out of the batch): the other lines,
the card, the mean's line and the legend go, and the line in focus grows back
into the line alone, Loss's zoom in reverse; then its tiles and bars go and
the place's target flies up to its row of Predict's bench, the shares as
softmax left them (`PredictScene.barColour`, `litBand`, `drawWhole`,
promoted). There the gradient starts: p − y, each share less one at what
came next, so the target's row fills to the dashed 100% in the negative ink,
"raise its logit", and every other bar turns positive, its own share,
"lower each"; the bars condense into a column where the logits were made,
signed, `<pad>` and `<bos>` struck. The place's last row stands at the left
as Predict stood it, with empty slots for its gradient beside it, and the
errors run back along the output layer's strings (`weight_flow.dart`, the
closures transposed, the tips in the loss's honey): the largest number of the
gradient alone (insulin A's C11 at step 1: number 10, −0.32), the rest in a
cascade, then the gradient read, its extremes ringed. Two mini-steps after it,
each string relit by its own weight's gradient (error × the number at its
start) and then by the batch's mean, were cut at the user's word the same
night: the same strings again, ending on the gradient column while the
number multiplied stood two columns left, and the batch's strings beside
columns that were still the one place's. A weight's gradient is Update's to
show (see below); ÷ 180 is said in the note where every place
climbs. The gradient's column lies down into Forward's ladder and climbs it from the bottom (`TowerLayout`, its
number face sized for the gradient, `styleFor`): back through the final
LayerNorm, then each part from the last, its strip what it sends back (the
gradient above less the one below), a copy of the gradient under it rising
through it into the slot above and turning into the sum, each row framed in
honey; attention's captions count the later places whose blame comes back
through it. At x0 its gradient goes on to its token row and its position
row, and Forward's opening plays in reverse: the row goes home to the table
and every place's x0 gradient comes in (at step 200 only `<bos>`'s is left),
where the stage ends: all the gradients' length against the clip moved to
Update on 2026-11-03, for it needs every weight's gradient (Backward 46 → 44
beats). Every number is the run's: the shares are
Predict's; each point's gradient is the one the run kept whole (schema 7),
drawn times the 180 targets, what the sum of their costs sends back; the
ladder's, the strips' and the table's colours, and the strings' strength,
are the whole batch's at that step, so a place with nothing left to learn is
drawn as faint as it is. While the batch shows a line puts its peptide in
focus; on the line alone a target its place; on the bench and the ladder a
tap asks for nothing; on the table a row puts its place in focus.

**Update** (`update_scene.dart`, 39 beats, the user's picks of 2026-11-03)
gives every weight its gradient, guards their length and takes AdamW's step.
It opens on Backward's last frame, pixel for pixel, and moves it, as every
stage opens (the user's ask of 2026-11-10: it had faded the table out and
the bench in, through a nearly empty canvas): Update draws Backward's table
itself, and a wave runs down it, each row's gradient dimming as its last row,
what the output layer read, comes in where it was, under the tag
`last rows · n × 16`; then the place's row turns off the table into the
bench's left column, as Predict stands it, while p − y comes in where the
logits were made (`BackwardScene.drawLastRow`, `drawErrors`,
`PredictScene.drawPlate`, promoted) and then the 368 strings between them,
faint, drawn from the row's numbers, each a weight. One string is worked, the
place's largest error × number (insulin A's C11 at step 1: S's from number
6, `−0.99 × 1.94 = −1.92` written on it from the written factors): a
weight's gradient is the error at its end times the number at its start.
Then the same weight at every place (the user's pick over every place's
whole grid added): the bench goes the way it came, the place's column lying
back down into its row as every other place's last row comes back round it,
and the other fifteen numbers dim, leaving the worked number's column; the
table narrows to that column, each place's p − y at the worked token beside
it (the rows where it came next softly lit) and each place's pull, its row's
product; the peptide's pulls added under them, then a card of the six
peptides' sums and all 180 (−4.075), and ÷ 180, as the loss is their mean
(−0.0226, the gradient the optimiser read). Every weight at once: the output
layer's gradient as a grid on the bench's token rows, the worked mean flying
into its cell. The grid is Predict's map's kind (the user's pick of
2026-11-10, after its full-colour tiles and hatched rows read as loud): a
dark slot a weight, and in it a square whose area is the weight's size
against its scale, at most half its slot, its colour its sign's, as soft as
a table's tiles; `<pad>` and `<bos>` (never next, no gradient) are empty
slots; each token's tile sits right beside its row; the worked token's row
is lit as Predict lights what came next. The grid shrinks into its row of a
chart of the run's ten groups, each named with its weights and a honey bar
of its gradients' length (the error reaching each weight's end × the number
at its start, every layer the same way); then all 8,167 together, their
lengths added as squares, against the clip's dashed 1.0 (no checkpoint is
clipped; nine of the run's steps were). Then AdamW on the worked token's 16
weights (the user's pick of a re-recorded run, schema 8, so every
checkpoint's step is worked, not only step 1's): the output layer's bar grows
back into the grid, faint, and the grid's row stands up as its gradients
beside the weights, a bar a weight on Scores' evening-chart way of drawing a
row (bars from a dashed 0); the bars move to AdamW's running mean, a tick
marks each running size, each bar goes over its own size to its ratio (at
step 1, with no past, every one ±1: the sign alone), then flips and scales
by the rate, a small schedule marking this step, into the step; the bars
condense into a step column and a copy of the weights goes through it to
after (`−0.0598 + 0.0001 = −0.0597` at number 6). Last the step lies back
into the grid: every weight's step (0.0001 each at step 1, whatever its
gradient: 368 squares one size), then the layer after, its plate's status
one update on (`ScoresScene.weightsStatus(after:)`). Nothing in the stage is
ringed (the user's word of 2026-11-10: the honey rings, one inside the place
in focus's green outline, read as double borders): the worked weight is
followed by its own numbers written in the honey of its string, 1.94 and
−0.99 at the string's ends, the place's pull, the mean, and number 6 in each
of AdamW's columns, and the place in focus's green outline is the only line
round anything. Every number is the run's and held to it (`lm_scenes_test`,
the live check): the pulls added and ÷ 180, times the clip, are the kept
gradient; AdamW's rule from the kept running averages makes every kept
update. While the table is up, Backward's and then the last rows', and on
the table of every place's last rows later, a row puts its place in focus;
elsewhere a tap asks for nothing.

**Loop** (`loop_scene.dart`, 44 beats, the user's picks of 2026-11-03) is
that step again and again, 200 times, on the batch made once: what the
training does, as the stages showed it, seen over the run. Its pace is the
domain's (`LoopPace`, a pure function of the run: `TrainingFrame` carries no
step since): it opens on Update's last frame, pixel for pixel
(`UpdateScene.paintEnd`, `UpdateFade`), every weight moved once; Update's
grid glides down and widens into the map's frame, its squares going as it
goes and its slots giving way to the map's (`UpdateFade.glide`, `gridTo`;
until 2026-11-10 it faded out to a nearly empty canvas first), and step 1 is
put back together on a canvas of Loop's own
(`LoopLayout`): its guesses as Predict's map, on rows of its own under the
note (`share_map.dart`: `ShareMapLayout` and `ShareMap`, Predict's map
promoted, Predict, Loss and Backward byte-identical), and their cost, the
first point of a curve in the loss's honey above the map, the levels to beat
dashed and named in Loss's words (even guess, residue counts, residue pairs)
and the floor dotted, Update's rate schedule under it
(`UpdateScene.drawSchedule`, promoted). Then the run: steps 2 to 4 one at a
time (each a hair lower: −0.003, −0.005, −0.008, the rate warming up), then a
move to each step the run kept whole and a hold there for its caption and
note (the user's pick): the level the loss passed, brightened, the run's
count of right guesses (insulin A's at checkpoint 1: right at 12 of 180 at
step 13; L, the commonest residue, the top guess at 80 places at step 21;
71 at 49; 139 at 66; 175 at 95), and the steps whose gradients went over the
clip. A move of many steps takes at least 1.2 beats and the rest goes by how
far the loss falls on it, so the burst between steps 50 and 95, where the
squares jump into their lit slots one place after another, gets the time.
The map is drawn from every step's own probabilities (schema 9, the user's
pick), lerped between whole steps; every number written (p(y), the head's
loss, the rate) is a kept step's whole one, and only while the run stands,
for numbers that change every frame cannot be read; the key's y stays named
over its tiles while its p(y) comes and goes (`drawAnswerKey(titleWithTiles:)`).
The moves carry no note, so the eye is on the map. The end: every row but `<bos>`'s dims, its six
squares a sixth each, 93% of the loss, the floor; then the run whole and how
far the weight Update worked travelled (S's from number 6: −0.0598 to
0.0938; the weights appear in the opening only, the user's pick). The run
always starts at step 1, whichever checkpoint is picked: the opening names
it. A kept step's tick picks it and holds the run there; a row of the map
puts its place in focus; nothing while Update's frame shows.

Reduced motion shows each stage played through, the loop at its last step. The
captions and the stages' info pages are built from the run's own numbers
(R4.1). The ⓘ opens the stage on screen's own page (`LmScene.info`, required
of every stage, an `LmInfo` that `LmInfoSheet` draws, built when tapped;
Tokenise's since 2026-11-06, the other eleven since 2026-11-07, each
previewed with the user). Every page is the screen's key, the user's pick for
all twelve: a lead saying what the stage takes and gives, in the bright
ink over the sections' quiet paragraphs (the user's pick of 2026-11-10), then a short
section for each part of its canvas the page adds to, under its tag, a link
to a later stage beside what it explains; where the notes already say it
all, a part has no section. The About sheet, how the whole model learns,
which the ⓘ opened until then, is deleted: its "This run" and the peptides'
records end Loop's page (the user's pick). `docs/design/peptide-lm-info-pages.md`
is how a page is written: the rules for the words, the steps, the code, the
tests, the tools, the engine and the run's checked facts, and each stage's
brief; `peptide-lm.md`'s Info pages keep each page's record.
Its colours are the theme's (`LmInks`, held by `lm_inks_test`): the accent
for what flows forward, the tracer for what came next, the helix's honey for
the loss and what flows back, and the helix's denim and clay, from the base
tile at zero, for every signed number. `docs/design/peptide-lm.md` has the
design.

## Zoom (`lib/features/zoom/`)

From a body down to one protein's DNA, at `/zoom/<slug>`, in every build. It
began in the lab and left it for the walk: links from then (`/lab/zoom/<slug>`,
and `/lab/zoom`, its picker) redirect, the second to the protein list.
`zoom_routes.dart` wraps it in `AppTheme.analysis`, which the lab's shell used
to give it, and it reads through the app's own `TrackSource`, the walk's: a
`locus` payload is a few kilobytes, and its record is the one the walk holds.

It is reached from the walk's gene page, which offers "Zoom ›" on its strip
for a protein whose `locus` track is `ready`: every curated one today,
by their rows and by no list, so a protein built on demand gets it the day it
gets a locus. The walk opens it by route (`RoutePaths.zoomFor(target,
overWalk: true)`, `?over=walk`), never by import. At the DNA, "Walk ›" unzips
the helix and goes back to the gene page it left; opened any other way, with
no walk under it, it opens the walk at `/gene/<slug>`. `ZoomRoute` resolves
its slug with a loader of its own: a shared loader would have to read
`ProteinCatalogRepository` from core or shared, which the layering test
forbids.

The dive is nine stops on one depth (`ZoomDepth`): body, organ, tissue,
cell, nucleus, chromosome, band, gene, DNA. The card's ‹ › step from one to
the next (a step asked for mid-flight carries straight on at the speed the
depth has), and a pinch and a flick move the same number. Everything drawn
is a function of it, but what moves at rest (a helix turning, vesicles
leaving a cell), which is drawn on a layer of its own on the ambient clock:
`zoom_smoothness_test` walks every protein's dive, and every step either way
at 60 fps, and fails on a pop, a blink or a jump. Each scene builds what it
caches (`ZoomScene.prepare`) one a frame while nothing moves, so no step
pays for a scene's first frame: a scene that caches something costly
builds it there. Each stop is a scene in its own units, nested in the one
before where its portal lies (`ZoomCamera`), and drawn the way its scale is
seen:
- the body as the Expression Atlas anatomogram's figure (EMBL-EBI,
  CC BY 4.0), the organs the Atlas reads the gene raised in lit;
  `tool/zoom/anatomogram.py` generates `anatomy_figures.g.dart` from it,
  and the body carries its credit, with the Atlas's, in one caption line;
- the organ: thirty are drawn from general anatomy as lit specimens
  (`presentation/scenes/organs/<organ>/`, four files each: the anatomy in
  millimetres with its sources, the style, the form, the art), the part
  the zoom's cell lives in in the accent, by the Atlas's name for the cell
  or its kind and never by gene, their main parts named at the canvas's
  edges: the pancreas among its neighbours; the testis and the bone
  marrow's femur cut down their length, and the brain down its middle;
  the epididymis cut down its length on its testis, seen from the side;
  the salivary gland's parotid and the thyroid in place; the breast in
  place, its lower half dissected; the eye cut through its optic nerve;
  the heart, the kidney and the liver cut open from front to back; the
  stomach, the esophagus and the urinary bladder opened from the front;
  the gallbladder laid open from the front with its ducts; the
  intestines in place from the front, a window cut at the ileocecal
  junction where GTEx samples them;
  the lungs in place from the front, the trachea between them, the left
  one cut open from front to back where GTEx samples it; the left ovary
  cut through its thickness, its tube arching over it; the prostate in
  place from the front, cut through its ejaculatory ducts in McNeal's
  plane, gone into in its peripheral zone; a parathyroid gland, the right
  superior, seen from behind on its thyroid lobe and cut through its
  thickness, the inferior thyroid artery and the recurrent nerve beside
  it; the front of the thigh for skeletal muscle; the adrenal cut on its
  kidney; the pituitary cut down its middle in the brain's own frame; a
  lymph node cut through its hilum; the fallopian tube opened along its
  length, and the cervix along its canal; and blocks of skin, placenta and
  abdominal fat. Twenty-three draw in from the body's own outline of them
  (the breast to its mound, its axillary tail coming up with it; the
  cervix from the one of its two halves the body follows; the epididymis
  from its band, its testis coming up beside it; the lungs from the body's
  left lung, its right lung giving way under their own; the ovary from
  the body's disc, its slit dropped; the prostate from its oval), most
  with the figure's
  parts kept faint round them (round the bladder all but its smooth
  muscle, which the anatomogram draws as the bladder's own wall, round the
  cervix all but the vagina, which it draws as its own vault, round the
  epididymis all but the testis, which it draws whole beside it, round
  the ovary all but its tube, which it draws arching over it, and round
  the prostate all but its seminal vesicle, which it draws above
  its base); the seven the body draws no outline of that shows them
  crossfade, the parathyroid over the body's thyroid, which stands in for
  it.
  The other organs are the anatomogram's outline, grown to its real size
  and sculpted with a surface for its kind, the figure's parts faint round
  it, and a vessel has a drawing of its own;
- the tissue as a section under an eyepiece (`TissueSlide`: one engine, a
  recipe a tissue architecture, the zoom's cell laid where it lives);
- the cell, the protein glowing where the Atlas finds it, and the nucleus
  with its chromosome territories; the nucleolus, lobed, plain and near
  black, is one shape in one tone at both (`scenes/nucleolus.dart`), named
  at the nucleus alone (the user's ask of 2026-10-19; the cell names it
  nowhere), its line in the quiet ink, its plate outside the nucleus on
  its left;
- a metaphase chromosome with the form a scanning micrograph shows
  (`presentation/scenes/chromosome/`), after a picture of chromosome 16
  the user sent (2026-10-23): two sisters of dense, overlapping globules
  under the organs' lamp, taken as the organs take it, each a sphere of
  one material with a soft highlight of its own and a crevice cast away
  from the light, a fine grain in them, a cleft between the sisters and a
  blurred shadow under them; in the organs' colours (the user's choice of
  2026-10-26, after the soft blue read louder than every stop round it):
  the arms a warm stone, their G-bands faint changes of its value, the
  centromere's neck clay and the four chromatid ends honey, mixed into
  the stone (half way, and over a third; stronger at the user's ask the
  same day) but never as saturated as the band, and the gene's band, all
  round both sisters and two rows of globules at the least, in the
  organs' home tone, nothing glowing over it, the gene's place pinged on
  arrival; its parts (p arm, centromere, q arm, chromatid, telomere) named
  in a column at either edge of the canvas, level with each (the user's
  asks of 2026-10-19), their lines in the quiet ink. It condenses out of
  its territory, and on the way out turns into a smooth tube that is, by
  the time it lies along the genome, the band map's strip pixel for pixel;
- a genome map of the band opened out of the whole chromosome; the gene,
  opened out of its mark on the band's strip, as a genome browser draws a
  transcript, the record's exons at their real lengths, still (its own stop
  again, the user's choice of 2026-10-15, after a day as one stop with the
  DNA); and its DNA from the 5′ end, chromatin and then the home screen's
  own double helix (`DnaHelixPainter`, from `lib/shared/helix/`), lying 5′
  to 3′ with the record's first bases, whole: unlike the home screen's,
  nothing transcribes it (`transcription: null`), so no strand peels away.
  The gene reads 5′ to 3′ from its first frame whatever its strand, a
  reverse one mirrored about its middle: its mark on the strip has nothing
  inside it to turn, so nothing turns.

The organ and the cell are one path the bake chose, a cell that lives in
the organ (`path` in the `locus` track's schema 2, `pipeline/locus` in the
backend). Where that cell has no nucleus (red cells, platelets), the zoom
lands in the precursor that has one. The band is marked and named, never
the gene. The card says the place and one line of data, nothing that
explains: there is no About sheet, no source tag and no player. Its
colours are the app's own (`ZoomInks`): one ground at every stop, the
accent for the gene and what it makes (the organs its RNA is raised in, its
cell, its protein, its chromosome's territory, its band) and nothing else,
and every other form sculpted in the warm neutrals; a chromosome's are
ramps in the theme (`core/theme/chromosome_colors.dart`: a ramp each,
crevice to specular, mixed from the app's own colours: the stone, the
helix's clay and honey over it, and the organs' home tone for the gene's
band); `zoom_inks_test` holds that no colour in the zoom is written out
as a number. `docs/design/zoom.md` has the design and
its checks.

## State

Use flutter_bloc cubits, created per route visit. The router builds a new
`GeneLookupCubit` each time a walk opens and calls `load` immediately, so a
deep link behaves like a pick from search. Each feature owns its own cubit and
screen; a new flow does not reuse `GeneLookupCubit` or `GeneScreen`.
Repositories are app-wide `RepositoryProvider`s in `core/di/dependencies.dart`.

## Lints that bite (`analysis_options.yaml`)

- `prefer_single_quotes`, `require_trailing_commas`, `prefer_final_locals`.
- `always_declare_return_types`: every function and method, `void` included.
- `avoid_print`: `debugPrint` inside `assert(() { ...; return true; }())`, as
  `Env` and `TrackClient._note` do.
- `strict-casts`: read JSON as `json['x'] as String?`. `strict-inference` and
  `strict-raw-types`: spell out type arguments (`<String>[]`, `Future<void>`).
- Also on: `unawaited_futures`, `directives_ordering`, `avoid_dynamic_calls`.

## How data arrives

The backend URL is `API_BASE_URL` in `.env` (copy `.env.example`). If it's
missing, the app falls back to `http://localhost:8000` with a debug warning.

1. **`/catalog`** → `ProteinCatalogRepository`. `main` restores the last
   complete catalog from disk before the first frame, then refreshes it. A
   failed refresh keeps the catalog the reader already had. A deep link to a
   slug outside the catalog goes to `/protein/{slug}`.
2. **`/protein/{slug}/tracks`** → `TrackClient.tracksOf`, remembered per
   protein, turns each family's state into a url, sha256 and provenance. A
   failure is not remembered. On a transport or 5xx failure the cached rows
   are used; on a 4xx they are not.
3. **Payloads** come from Supabase Storage as bytes through `TrackClient`'s own
   Dio (`ApiClient` is JSON-only). They are cached on device by **sha256**
   (a re-bake is a new name, so nothing needs invalidating), with the least
   recently read dropped past 200 MB. Each parser refuses a payload that
   names another protein.

UI code calls `TrackSource.read(slug, kind)` and never sees a storage path.
Tests use `test/support/fixture_track_source.dart` over `test/fixtures/`.

4. **Beyond the catalog (Phase 6)** → `ProteinResolver`. `/proteins/suggest`
   names every reviewed human protein (`listed`, `ready`, `buildable`,
   `unavailable`); `POST /proteins/resolve` asks for one to be built, and
   `GET /proteins/resolve/{gene}` says how far it has got. The backend's
   resolver (on the dev Mac until Modal runs it) writes its row
   (`catalog_order` null, so never in `/catalog`) and its record, then makes
   its AlphaGenome (AVI) and ClinVar tracks with the twenty's bakers (since
   2026-10-09), then scores ESM-2 650M, the twenty's model.
   Builds are one job of the whole app, `ProteinBuilds`
   (`core/catalog/protein_builds.dart`, provided in `core/di`), so a build
   outlives the search that asked for it. Each is watched through
   `GET /proteins/resolve/{gene}`, whose `build` (`BuildReport`) names the step
   (queued, record, evidence, scoring, check, done; `evidence` is shown as
   "AlphaGenome and ClinVar", and offers no Stop), the proteins ahead, the residues
   ESM-2 has scored with the time the scorer says is left, and every number
   by the service's clock. Search pins each build at its top, whatever is
   typed, as a `BuildCard` with those steps and a residue bar, until it is
   opened; a suggestion the service marks `building` is watched, never
   opened. Between two answers the card's clock runs on (elapsed, and the
   time left running down, each second), and the bar glides at the scorer's
   own rate with a sheen, never more than one of its lines (25 residues)
   ahead of its count (`BuildCard.advance`); reduced motion keeps the count.
   The phone that asked may stop a build while it is queued or scoring, after
   a dialog: each ask carries this install's own random id (`InstallId`, no
   accounts), and only it may stop (`POST /proteins/resolve/{gene}/stop`).
   Stopped while scoring, it opens unscored and Build scores it again; a
   suggestion marks such a protein `stopped`. A build that ends while search
   is not on top is said in a snackbar on any screen (`BuildReadyListener`,
   in `MaterialApp.builder`). Nothing is given up on by the app: a report
   that stands still for ten minutes says so. From a service without the
   report, the constraint track's state is read instead. Where the service
   makes folds, the card has a "Structure" row after "Gene record", marked
   from the report's `fold` (being made, made, or refused with no model;
   hidden where none is made), and a build whose scores are over while its
   first fold is still being made is held: the service reports its
   `structure` step, read as every step behind it and `BuildReport.holding`,
   and it opens once the fold is made or the service stops waiting (20
   minutes at most). `BuildStep` keeps its six values: a walk test pins them.
   `GET /proteins/built` lists every install's builds, newest first, as the
   same suggestions: one under way is left out until it is done, one stopped
   is kept and opens unscored there, with no Build (scoring it again is
   search's, not a tap on a list of everyone's builds; the user's choice of
   2026-10-09). A build of this phone's that ends with a protein to open asks for
   the list again; pinned, it is its card there and not a row as well.
   It opens the walk only once its AVI and ClinVar are in and ESM-2 has
   scored it or declined to (the backend's ESM-2 bake waits for the first
   two). `TrackClient` and `ProteinCatalogRepository` each remember a protein
   once read, and a catalog protein opens on what they remember, at once, as
   it always has. A protein outside the catalog is asked for again at every
   open, its row and its track rows together
   (`ProteinCatalogRepository.protein(fresh:)`, `TrackClient.refresh`),
   because its fold can be published again while the app runs (a backfill, or
   an earlier fold put back); one opened mid-bake has what was made since at
   its next open, with no restart. Its walk reads by the rows it opened with
   alone (`pinWalk` in `core/router`, a `PinnedTrackSource`, which is
   `TrackRows`): one generation of its fold for the walk, whatever is
   published while it is open. Where the two answers disagree (a fold
   published between them, `foldCoherence`), both are asked for once more.

   **The page it opens on is the walk's own from its first frame**
   (`_WalkLoader` in `core/router`), as a curated protein's is: the walk's
   ground, its header, and the walk landing in the places its wait held.
   Never a page of the loader's own before it, which is what a reader saw as
   a flash of another ground with no header.
   - Opened before in this run, it opens at once on the row and rows the app
     holds (`TrackClient.known`), and the service is asked behind the walk.
     Where it answers within `walkPatience` (two seconds) with other rows,
     the walk is opened again on them, unless the reader has touched it by
     then; slower, or touched, this walk stays whole as it opened and the
     next adopts. Until the service answers, the rows remembered stay the
     ones every read gets.
   - Not read yet, it shows the walk's wait (`GeneScreen` over a lookup not
     yet asked for the record), headed by the names the list it was opened
     from hands the route (`RoutePaths.walkNames`, the route's `extra`:
     search's tiles, a build's card, the build-ready snackbar). The record is
     asked for once the row and its rows are in.
   - A link from outside the app names nothing: its wait has no heading, on
     the same ground under a header of the same height. So has the page that
     says a protein could not be read.
   The walk reads a built protein's AVI and ClinVar as it reads the twenty's
   (`test/features/gene_lookup/anatomy/built_evidence_test.dart`, with B2M's
   stored tracks beside its record in `test/support/built_on_demand/`). Tests
   use `test/features/search/support/resolver_api.dart`.

   **Its fold is an experimental entry's, with the twenty's fold animation,
   where one passes** (R5.4: chosen by rule, baked and held to this app's
   own binding of it by the backend, `test/fold_bundle_check.dart`), and
   AlphaFold DB's model, drawn still, only where a whole search finds none
   (the user's decision of 2026-10-08, now the fallback). Its row carries
   what the twenty's do, a fold description (`StructureChrome`) and a tint for
   each node, and the fold page draws it by the same code:
   - An experimental fold is drawn as the twenty's are: its chains
     `mature1` to `mature3` in precursor order, `bonds` in `cysteine`, and its
     `folding` track played on the walk's fold page. Where its record names
     no peptides (no record built on demand does) and the model has two or
     more chains, the fold legend names each by its region in the row's table
     (`ProteinTarget.regions`, `/protein/{slug}`'s `regions`; the user's
     decision of 2026-10-12). The fold page holds the row, the model and the
     fold to each other by the rows its walk was opened with: a fold made in
     another model's frame (`FoldingTrack.glbSha256`) is not played, and the
     page opens on the model; a row naming another model than its track holds
     is a model that could not be loaded. Its caches are named by that
     generation of the fold (`StructureView`), a failed binding included.
   - AlphaFold's nodes are pLDDT's four bands, not its chains
     (`ChainTint.plddtVeryHigh` to `plddtVeryLow`, in AlphaFold DB's own
     colours as `AnatomyColors` tokens, kept exact). The legend names a band
     the same on every protein (`ChainTint.confidence`). Its entry id is
     AlphaFold DB's (`AF-<accession>-F1`), which `StructureChrome.predicted`
     reads; the header and the About sheet name the source by
     `StructureChrome.source`, and the About sheet credits it (CC BY 4.0)
     through `SourcesNote(also:)`. The twenty's lines come out of the same
     code, unchanged.
   - It may have no model: no experimental entry passes and AlphaFold DB has
     none, or none sure enough. Then its row has no fold description and its
     `structure` track is `refused`, and the fold page says why in one line,
     the track row's own sentence (`StructureView`, "A protein with no
     model"). Never "could not be loaded", which stays a model that exists
     and did not arrive.

   `ChainTint.fromWire` throws on a tint it does not know, on purpose: a
   build older than these tints cannot open a protein once its model is
   made. `test/support/built_on_demand.dart` is such a protein for the tests
   (B2M's stored record and row), kept out of `test/fixtures/`.

## The four track states (`TrackState` in `protein_track.dart`)

`ready` (stored, and `url` points at it); `pending` (a bake is queued or
running, so the track is on its way); `absent` (nothing is coming, and unknown
wire values read as this); `refused` (the pipeline declined, and `reason` says
why, for example titin's exons exceed the page budget).

These replaced four booleans (R9.3). An unbaked gene, a snapshot still
arriving and a declined gene are three different things, and a boolean can
tell the reader only one of them. "Not yet included" said of a pending track
is exactly the claim the rules forbid. A track that isn't ready is a state the
walk draws, not an error: the page is drawn without it. A *ready* track that
fails to fetch is a real failure. Keep the two cases apart. The fold page is
where a reader is shown a `refused` track's sentence: a protein built on
demand that neither the PDB nor AlphaFold DB has a model of says so there.

## House rules (`docs/protein-pipeline-rules.md`: read it first)

- **No per-protein code.** Nothing branches on a slug, gene or accession.
- **No per-protein prose.** Captions are built from the record. The structure
  page's `sentence` and `semantics` are the only exception (see R4.5), with
  a curated protein's one-line summary, and only for curated proteins (the
  twenty, and those added to the list since, the user's decision of
  2026-10-17): a protein built on demand has its words templated by the
  backend from its index row and its model's own numbers.
- **Every claim traceable to the record.** Numbers come from data, never from
  a literal: no hard-coded lengths and no count of the catalog (R4.1).
  Captions agree with their own numbers via `grouped`, `spelled` and
  `spelledLeading` (R4.2). Formats follow R4.4.
- ClinVar (§9): clinical words appear only inside `ClinVarSourced`, hue belongs
  to ClinVar alone, and absence is never called benign.

## The compressed-intron genes: DMD, APP, CFTR, PAPPA, TG, B3GAT1, DMC1, DNM1, LGI1, PADI6, CASR, ACP3, ANGPT1, LOXL2, CKMT2, GAS6

These sixteen genes exceed the gene page's 24,000-base budget, so their introns
arrive shortened and their exons whole (R2.4). PAPPA and TG joined the list
with the third ten (2026-10-17), B3GAT1, DMC1, DNM1 and LGI1 with the
fourth batch (2026-10-18), and PADI6, CASR, ACP3, ANGPT1, LOXL2, CKMT2 and
GAS6 with the fifth (2026-10-25); a curated protein added later may join it too,
by its record and not by a list: `GeneRecord.isIntronCompressed` says which. `GeneRecord.isIntronCompressed`
is true, and `realSpanBp` and `realIntronBp` hold the real lengths. A shortened
intron keeps its own first and last bases and drops its middle. The transcript
and protein pages show the real molecule.

Drawn bases are **not contiguous**, and code that assumes they are breaks:
- `AnatomyStage.cellAt(position)` returns -1 for a base cut from an intron.
- The record-to-chromosome map is one `ImpactRun` per exon, with a gap at each
  shortened intron. A single run misfiles AVI scores and ClinVar records.
- A stage's `count` is cells drawn; `shownCount` is the molecule. The scale
  can't recover real lengths (42 of dystrophin's 78 introns sit at the floor).
- A ClinVar record in a cut middle is "not drawn", not "outside the gene"
  (R9.2). `AnatomyFasta` refuses to copy a shortened gene's letters.

## Commands

```bash
flutter analyze
flutter test                   # offline and deterministic: fixtures only
dart run build_runner build    # after editing gene_record_dto.dart
(cd ../helix-peak-backend && python3 pipeline/fetch_tracks.py \
  && python3 pipeline/check_assets.py)   # stored tracks against each other
```

**Opt-in checks** skip unless their variable is set; run `*_check.dart` by path.
- `LIVE_BACKEND=http://localhost:8000 flutter test test/live_backend_check.dart`
  fetches and parses every track through the production client.
- `LIVE_BACKEND=<url> LIVE_RESOLVED=<GENE> flutter test test/live_resolved_check.dart`
  reads a protein built on demand the same way and walks every page of it
  (`LIVE_EXPECT=refused` for one whose ESM-2 track was refused, `absent` for one
  whose scoring was stopped; `LIVE_EVIDENCE` likewise for its AVI and ClinVar,
  `ready` by default).
- `FOLD_BUNDLE=<dir> flutter test test/fold_bundle_check.dart` holds a fold the
  backend has baked for a protein built on demand (its row, `.glb`, scene and
  `folding` track) to the fold page's rules: the scene is the model, every
  ring and rod binds, the fold ends on the stored mesh float for float, and
  nothing jumps. It writes its verdict to `check.json` (`ok`, `unsuitable`,
  `fault`); the backend's worker runs it on every such model before storing
  it (`pipeline/structure/experimental.py`).
- `WORDS=<file> TRACE=<trace.json> flutter test test/peptide_lm_words_check.dart`
  writes every caption, note and info page of the Peptide LM's stages, from a
  recorded run (`TRACE`: the backend's `pipeline/denovo/runs/curated/trace.json`),
  at its first and last checkpoints: what a stage's info page must not say again.
- `SHOTS=<dir> TRACE=<trace.json> STAGES=tokenise SIZES=440x956,375x667 flutter
  test test/peptide_lm_info_shots_check.dart` plays each stage to its end on the
  real page, taps its ⓘ and writes the sheet as PNGs, scrolled and not, with how
  far it scrolls (`STEP` picks a checkpoint).
- `SHOT_DIR=<dir> flutter test test/goldens` writes PNGs (the catalog walk,
  ClinVar, constraint and impact tests do too). Also:
  `TRANSLATION_SHOT_DIR`, `SELECTION_SHOT_DIR`, `HELIX_OUT`, `HELIX_MOTION=1`.

**Render baseline: `tool/goldens/goldens.sh`** (Git Bash, with Docker running).
It runs `flutter test` in the one environment the goldens are made and checked
in: `tool/goldens/Dockerfile`, Ubuntu 24.04 pinned by digest, Flutter 3.47.5,
x86-64. The zero-diff proof is `tool/goldens/goldens.sh test/goldens`; the
whole suite, as CI runs it, is `tool/goldens/goldens.sh`. A native
`flutter test` skips every golden test with that reason, because text is
rasterised by the host and a native Windows run differs at every glyph edge.
A failed golden leaves its diff in `test/goldens/failures/`. Regenerating is
session 99's job alone: `docs/goldens.md` has the environment, the commands
and the rules.

Natively on Windows, `protein_catalog_test.dart`'s "every track is fetched,
and none of them ships" fails before any session touches it: it compares
`File.path` against `/`-separated literals, and Windows lists
`assets\animations\process.json`. It passes in the container.
