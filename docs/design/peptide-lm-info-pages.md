# Peptide LM: writing a stage's info page

How to write the ⓘ page of a Peptide Language Model stage, so that the
eleven still to come are built the way Tokenise's was. The stages
themselves are in `peptide-lm.md`; the code is
`lib/features/peptide_lm/`. Every number below was checked on the live
run, sha `83cc0cc2…` (schema 9; `runs/curated/trace.json` in the backend is
the same 5,379,295 bytes), on 2026-11-07.

## Contents

1. What a page is
2. Where the pages stand
3. The rules for the words
4. How to write one, step by step
5. The code
6. The tests
7. The tools
8. The engine, as each page must describe it
9. The run's facts
10. A brief for each stage still to come
11. When all twelve exist
12. Checklist

## 1. What a page is

The user's ask (2026-11-06): "For every step I want an info that is
specialised only for that particular step, that gives various info so the
user creates the right intuition and mental model for the whole flow …
these info pages will be like helpers for the user to better understand
the context, but make a deep analysis so they contain only necessary
informations and are concise."

The template, the user's pick for all twelve, is the **screen key**:

- a **lead**, unheaded, under the title: what the stage takes, what it
  gives, and the one framing fact the stage needs (Tokenise's: it is made
  once, the same at every step, and learns nothing);
- a **section for each part the canvas tags**, titled with the tag in
  sentence case, in the order the tags appear: what the part is and why it
  is there;
- a **link to a later stage beside what it explains**, said once, at its
  cause ("alike in all six, it leaves that guess at one in six" sits with
  `<bos>`; Loss and Loop show the floor it makes).

The user turned down two other layouts: four fixed headings (Takes · Gives
· Why · Leads to), which forces filler and splits one idea across two
headings, and questions as headings, which ties less directly to the tags.

A page is not a transcript of the stage's captions and notes, not a
summary of the About sheet, and not a tutorial of the field. It is the
key to one screen and its place in the flow.

The reference page is Tokenise's: `TokeniseScene.info` in
`presentation/scenes/tokenise_scene.dart`. Its analysis is in
`peptide-lm.md` under "Info pages".

## 2. Where the pages stand

| Stage | Beats | Own page | Notes on its canvas |
| --- | --- | --- | --- |
| Tokenise | 11 | yes, 2026-11-06 | none (captions only) |
| Shift | 5 | no | none (captions and two glossed tags) |
| Embedding | 15 | no | yes, five |
| Scores | 20 | no | yes, six |
| Attention | 25 | no | yes, ten (three of them the worked answer's) |
| Feed-forward | 20 | no | yes, eight |
| Forward | 12 | no | yes, four |
| Predict | 14 | no | yes, six |
| Loss | 17 | no | yes, five (the last a line longer at step 200) |
| Backward | 44 | no | yes, nineteen |
| Update | 38 | no | yes, eighteen |
| Loop | 44 | no | yes, one at each part and hold |

A stage with no page of its own opens the About sheet, "How this model
learns" (`LmAboutSheet`), from its ⓘ, whose tooltip then says so; a stage
with one opens it, tooltip `About <Stage>`. Nothing has to be wired: the
screen asks `sceneOf(stage).info(view)`.

The column on notes matters. Tokenise and Shift explain nothing on their
canvas but their captions, so their pages carry the stage's explanation.
From Embedding on, the canvas already explains each mini-step in a note.
There the page is a map and a key: the stage's place in the flow, what
its tags name, the misreadings it invites, and the links across stages,
never the notes' worked numbers again.

## 3. The rules for the words

### 3.1 The filter

A sentence stays only if it does one of three things:

1. explains a mark on the stage's canvas (a tag, a colour, a glyph, a
   struck or hatched cell);
2. keeps a reader from a wrong model (Tokenise's: "an id is an amount",
   "padding distorts training", "this stage learns");
3. names, at its source, something a later stage shows (Tokenise's: the
   counts are Loss's and Loop's "residue counts" level; `<bos>` makes the
   floor).

Everything else goes, however true.

### 3.2 Say each fact once

- Not again what the stage's own captions and notes say: dump them with
  `test/peptide_lm_words_check.dart` (section 7) and read them before
  drafting. Tokenise's page points to the vocabulary's counts but does
  not repeat the caption's "L the commonest, 23 of 174".
- Not again what another stage works out: point to it. Tokenise's page
  says the counts "would cost 2.856 nats, the level Loss and Loop call
  residue counts"; it does not explain the level, which Loop's hold does.
- Within a page, each fact in one section.

### 3.3 Data first

- Every number comes from the run, through code, never a literal: the
  trace's accessors (section 9 lists them) and the scenes' own helpers
  (section 10, under each stage). R4.1 of `docs/protein-pipeline-rules.md`.
- Counts in words up to twelve (`spelled`, `spelledLeading`), larger ones
  grouped (`grouped`), losses with `nats`, shares with `percent`,
  signed numbers with `signed`/`fixed` (true minus), small rates with
  `scientific` (`1.0e−5`): `lib/shared/format.dart`,
  `presentation/lm_format.dart`.
- A claim that holds only for some runs is guarded, and its sentence
  dropped, not bent, where it does not hold. Tokenise's guards: "one in
  six" only where every first residue differs; "first beats it at step
  21" only where a checkpoint was kept for passing residue counts; the
  example pair only where two ids follow on because their letters do.
- The words must read right on the toy run too (two peptides: "both",
  "one in two"; section 6).
- Check every example against what it claims. The approved preview of
  Tokenise's page said "A, 3, and C, 4, are neighbours only in the
  alphabet"; B lies between them, so the page says C, 4, and D, 5.

### 3.4 Audience and register

Biologists, for whom biology is home ground and machine learning is not
(the user is learning the ML through these screens, and did not know an
embedding's rows are trained). So:

- never a biology basic;
- an ML basic only where the screen raises it, in one clause (Tokenise:
  "an id is a name, not an amount");
- the field's own terms once the stage introduces them (token,
  vocabulary, batch, embedding, LayerNorm, query, key, value, softmax,
  logit, GELU, cross-entropy, nats, gradient, AdamW), each with the
  meaning the screen gives it;
- the app's voice: short clauses, colons for consequence, British
  spelling, no exclamation, no "simply", no "just".

### 3.5 Words the user has settled

| Use | Not | Why |
| --- | --- | --- |
| trainable, for numbers no update has moved yet | learned, at step 1 | nothing is learned at step 1 (2026-10-31) |
| standard deviation, in full | SD | the user's ask, 2026-10-31 |
| the top bet / the true next residue (or token) | bare "next", "given" | "given" read as "y given"; guess and answer key must stay apart (2026-11-02) |
| the largest share, adds most, with the reason | "read most", "brings most" | the shorthand said nothing (2026-11-01) |
| output number N, for what attention adds | value N | the user conflated `<bos>`'s value 1 with output number 1 |
| even guess, residue counts, residue pairs, the floor | uniform, unigram, bigram | Loss's and Loop's words |
| `<bos>` (<), `<eos>` (>), `<pad>` (·) | the bare glyph | the captions' form; the glyph is `glyph(trace, id)` |
| block 1's attention, x0 + block 1's attention | attention, alone | the stages read as the whole model until block 1 was named (2026-11-02) |
| input x, target y (the answer key) | next token y | Shift's tags |
| x0, p(y), p − y | | the canvas's own names |

### 3.6 What the sheet's font can draw

The page is set in Space Grotesk (the theme's `bodyMedium`). It has
`× ÷ √ − ∞ ≥ ≤ ± → ← · … ′ ″ ² ³ ⁿ ‰ ≈ ≠ Δ π` and `∑` (U+2211). It has
no Greek letter but Δ and π (no γ β Σ σ μ θ λ α ε φ Φ), no `‖`, no
superscript minus, no `ⓘ`. Write words ("mean", "standard deviation",
"sum", "norm"), `1.0e−5` for powers of ten, and the true minus `−`
(U+2212) for negatives. Checked with fontTools on
`assets/fonts/SpaceGrotesk-Regular.ttf`.

### 3.7 Length

Tokenise's page is about 245 words in a lead and four sections. It
scrolls 73 pt on a 440 × 956 phone (the user's Pro Max), 219 pt on a
393 × 852 and 416 pt on a 375 × 667. About 200 words fit the Pro Max
without scrolling. Measure every page with the shots check (section 7);
say in the preview how far it scrolls.

### 3.8 Shape

- Title: the stage's name, `LmStage.<stage>.label`.
- Lead: one to three sentences, takes → gives, the framing fact.
- Sections: the canvas's tags, sentence case, in the order they appear.
  Two tags that name one idea share a section (Tokenise's special tokens
  section covers the "special tokens" and "padding" tags; its token ids
  section covers "vocabulary" and "token ids").
- A section may have several paragraphs (Tokenise's special tokens: one a
  token, in the canvas's order of ids, `<bos>`, `<eos>`, `<pad>`).
- Plain sentences: no bullets, no inline styles, no symbols the font
  lacks.

## 4. How to write one, step by step

1. **Inventory the screen.** Play the stage, and list every tag, plate,
   column title, legend and mark in the order it appears (section 10 has
   each stage's labels, from the code). Dump its captions and notes at
   steps 1 and 200 with `test/peptide_lm_words_check.dart`.
2. **List the questions it raises,** the misreadings it invites, and what
   later stages show of it. A newcomer's questions are the user's own:
   those recorded under "Settled by the user" in section 10 are the best
   guide.
3. **Check every fact** in the engine (section 8) and in the run: the
   trace's accessors, or a read-only Python snippet over the trace (section
   7). Note where each number comes from in code.
4. **Filter and draft** (section 3): lead, a section a tag, links at
   their causes. Compute every number; guard every claim that depends on
   the run.
5. **Preview with the user before building:** an `AskUserQuestion` with
   the page as a preview (an ASCII box at about 46 characters a line), the
   real run's numbers in it, and how far it will scroll. Tokenise's page
   was approved this way, with its layout.
6. **Build** it (section 5).
7. **Test** it (section 6), including the two existing tests that list
   which stages have pages.
8. **Render** it at 375 × 667, 393 × 852 and 440 × 956 with the shots
   check, read every wrap, and give the user the PNG paths. No device run
   unless asked.
9. **Record** it: a paragraph a page in `peptide-lm.md` under "Info
   pages" (each sentence's job, what was left out and why), the table in
   section 2 here, the line in `CLAUDE.md` that names the stages with
   pages, and Claude's Peptide LM memory, where one is kept.
10. **Commit** locally (never push): the page with its tests, then the
    docs.

## 5. The code

A page is the scene's `info`, plain data that `LmInfoSheet` draws:

```dart
// lib/features/peptide_lm/presentation/lm_info_sheet.dart
LmInfo(title: …, lead: …, sections: <LmInfoSection>[
  LmInfoSection('Tag in sentence case', <String>['paragraph', 'paragraph']),
]);
```

Override `info` in the stage's scene; the screen does the rest (the ⓘ,
its tooltip, the sheet, the pause while it is up):

```dart
/// <Stage>'s own page: what it takes and gives, then each part its canvas
/// names, why it is there and what later stage it shapes, in the run's
/// numbers.
@override
LmInfo info(LmView view) {
  final TrainingTrace trace = view.trace;
  // Every number from the run; every claim that depends on it guarded.
  return LmInfo(
    title: LmStage.shift.label,
    lead: '…',
    sections: <LmInfoSection>[
      LmInfoSection('Input x', <String>['…']),
      LmInfoSection('Target y', <String>['…']),
    ],
  );
}
```

- `info` takes the `LmView` as `caption` does: the picked checkpoint
  (`view.checkpoint`, `view.step`), the peptide and place in focus
  (`view.focus`, `view.position`) are there. A page may quote the picked
  step's numbers, but the page is opened at any moment of the stage, so
  its words never depend on the frame.
- Reuse the scene's own helpers for numbers the canvas shows; a page's
  number must equal the canvas's.
- Reuse the 1, 2, many wording of the captions:
  `switch (peptides) { 1 => 'the one', 2 => 'both', _ => 'all $count' }`.
- Imports a scene needs: `../lm_info_sheet.dart`, and `../lm_format.dart`
  for `nats`, `percent`, `signed`, `fixed`, `scientific`.
- The sheet is as tall as its words, up to 0.8 of the screen, then
  scrolls (`LmInfoSheet`); the list's key is `peptide-lm-info-sheet`, the
  ⓘ's `peptide-lm-info`.

## 6. The tests

### A test for the page, in `test/features/peptide_lm/lm_scenes_test.dart`

Model it on "Tokenise's info page says the run's own numbers; no other
stage has one yet":

- the title and the section titles, in order;
- the lead and paragraphs contain the run's numbers, each computed from
  the trace in the test, never written out (`contains('${trace.model.width} trainable numbers')`);
- each guard both ways: build an edited toy run where the claim fails,
  and check its sentence is gone. The pattern:

```dart
TrainingTrace edited(void Function(Map<String, Object?> json) edit) {
  final Map<String, Object?> json = jsonDecode(utf8.decode(toyBytes())) as Map<String, Object?>;
  edit(json);
  return TrainingTrace.parse(Uint8List.fromList(utf8.encode(jsonEncode(json))), name: 'toy');
}
```

  `TrainingTrace.parse` checks shapes, not meanings, so a peptide's
  letters or a checkpoint's `why` can be changed without touching the
  arrays.

### The two tests to change when a page lands

1. `lm_scenes_test.dart`, the Tokenise test's last loop: it checks that
   every stage but Tokenise has no page. Take the new stage out of it.
2. `peptide_lm_screen_test.dart`, "the info button opens the stage's own
   page, and how the model learns where it has none": its second half
   uses **Shift** as the stage with no page. When Shift gets one, move
   that half to a stage still without a page (Loop will be last), and add
   the new page's tooltip and section titles to the first half's checks.

### The toy run (`test/features/peptide_lm/support/toy_trace.json`)

Two peptides, toy A (GIVEQCCTSIC, 11) and toy B (QLYSALANKCCH, 12): 23
residues, x 2 × 13, a frame 14 wide, 25 targets. Width 8, two heads, two
blocks, feed-forward 16, 2,015 parameters; 20 steps, warm-up 2, rate
5e−2. Checkpoints 1, 2, 3, 9, 11, 20, kept for first, uniform, unigram,
bigram, one_nat and last: no tenth_nat, so a claim about "a tenth of one"
needs a guard. Baselines 3.045, 2.587, 1.284; floor 0.055.

### Widget tests' quirks

- Their font has square glyphs, wider than the app's: a page is taller in
  a test than on a phone, and the sheet's list builds lazily. Find a
  section with `tester.scrollUntilVisible(finder, 120, scrollable: …)`
  inside the sheet, never by its position.
- Stage names are on the stage bar too: find a page's title with
  `find.descendant(of: sheet, matching: find.text(title))`.
- After the sheet is put away the stage plays on, so `pumpAndSettle`
  waits for the stage to end: pump a second instead.

## 7. The tools

All opt-in: `flutter test` skips them (they are `*_check.dart`, run by
path). `TRACE` is the backend's
`helix-peek-backend/pipeline/denovo/runs/curated/trace.json`.

- **Everything a stage says:**
  `WORDS=/tmp/lm_words.txt TRACE=… flutter test test/peptide_lm_words_check.dart`
  writes every caption (at the beat it first shows), every note (with the
  beats it stays up) and every info page, of every stage, at the first and
  last checkpoints, insulin A's middle place in focus. `CHECKPOINTS`
  (indices), `PEPTIDE` and `POSITION` pick others.
- **A page as a phone shows it:**
  `SHOTS=/tmp/lm_info TRACE=… STAGES=shift SIZES=440x956,393x852,375x667 flutter test test/peptide_lm_info_shots_check.dart`
  plays each stage to its last frame on the real page, taps its ⓘ, and
  writes `<stage>_<size>.png`, `<stage>_<size>_end.png` (scrolled to the
  end) and `<stage>_<size>.txt` (how far it scrolls). `STEP=200` picks a
  checkpoint through the step menu. It also writes `about_<size>.png`,
  the About sheet alone: the same bytes before and after a change that
  must not touch it.
- **The run in Python** (read only; `-I`, from the backend's
  `pipeline/denovo`):

```python
import json, base64, array
t = json.load(open('runs/curated/trace.json'))
def f4(spec):  # a float32 array; u1 arrays are bytes × spec['scale']
    a = array.array('f'); a.frombytes(base64.b64decode(spec['data'])); return list(a)
loss = f4(t['steps']['loss'])                # step s at loss[s - 1]
cp = t['checkpoints'][0]                     # keys: step, why, token_embedding, …
```

- **A stage's frames:** `test/features/peptide_lm/_scratch_stage_shots_test.dart`,
  git-excluded, so it may not exist in another checkout. It renders exact
  moments of one stage of the real run: `SHOTS`, `TRACE`, `STAGE`,
  `MOMENTS` (shares of the stage) or `BEATS`, `SIZES`, `DPR`, `PEPTIDE`,
  `POSITION`, `CHECKPOINT` (an index); `CAPTIONS=1` writes the captions
  at those moments instead.

## 8. The engine, as each page must describe it

The backend's `pipeline/denovo/`. A page's claim about how the model works
must match these.

| What | Where | What it does |
| --- | --- | --- |
| Vocabulary | `alphabet.py` | `<pad>` 0, `<bos>` 1, `<eos>` 2, the twenty in alphabetical order 3–22; peptides of 10 to 50 residues of the twenty (`MIN_LENGTH`, `MAX_LENGTH`); the context, 51 = `<bos>` and 50 |
| Tokenising | `tokenizer.encode` | one token a residue, `<bos>` first, `<eos>` last; refuses any other letter |
| The batch | `sequences.build_dataset`, `batches` | pads every frame with `<pad>`, cuts the batch to its longest frame; yields x = frame less its last place, y = frame less its first |
| The data | `curated_peptides.collect`, `trace.py` | the curated records' chains that fit; all six in one batch, shortest first, nothing held out |
| Embedding | `helix_peek_LM.py` | `nn.Embedding(23, 16, padding_idx=0)`: rows random, normal with standard deviation 1 (PyTorch's default), `<pad>`'s held at zero; position rows a parameter, normal with standard deviation 0.02; x0 = token row + position row |
| The blocks | `nn.TransformerEncoderLayer(norm_first=True, activation="gelu")` | a LayerNorm before each part, on a copy; attention (`nn.MultiheadAttention`: one 48 × 16 projection makes the query, key and value, scores over the root of the head's size, a causal mask, softmax, an output 16 × 16), added to the stream; another LayerNorm; the feed-forward 16 → 64 → 16 with GELU between, added to the stream; dropout 0 in this run |
| Causal mask | `HelixPeekLM.causal` | a place reads itself and the places before it, never after |
| Final norm | `nn.TransformerEncoder(norm=nn.LayerNorm(16))` | one LayerNorm after the last block: hf, the row the output layer reads |
| Output layer | `lm_head = nn.Linear(16, 23)` | a row of 16 weights and a bias a token; its own table, not the token embedding's |
| Never next | `bigram_torch.masked` | `<pad>` and `<bos>` logits set to −∞ before softmax |
| Loss | `train._token_losses`, `train_step` | cross-entropy of each target, padding ignored (`ignore_index`), their mean over the batch's real targets |
| Gradients | `train_step` | `loss.backward()`; the trace records them before clipping (`after_backward`) |
| Clip | `clip_grad_norm_(…, 1.0)` | every gradient scaled by one factor where their total length is over 1.0 |
| Optimiser | `torch.optim.AdamW`, `train.param_groups` | betas 0.9, 0.999, eps 1e−8; weight decay 0.1 on weight matrices only, none on embeddings, biases or LayerNorms |
| Rate | `train.lr_schedule` | warm-up: (step + 1)/100 of 1e−2 for 100 steps; then a cosine down toward 1e−5, 1.2e−5 at step 200 |
| The run | `trace.py` (`SHOWCASE`) | width 16, two heads, two blocks, feed-forward 64, rate 1e−2, dropout 0, seed 0, 200 steps, CPU, one thread |

## 9. The run's facts

Checked on the live run; `trace` is `view.trace` in the app.

| Fact | Value | From |
| --- | --- | --- |
| Peptides, residues | 6, 174 | `trace.peptides`, `trace.residues` |
| Frame, batch | 41 wide; 6 × 41 | `trace.width + 1` |
| x and y | 6 × 40 each; 180 targets; 60 pads | `trace.inputs`, `trace.targets`, `trace.targetCount`, `trace.pads` |
| Vocabulary | 23 tokens; 21 can come next | `trace.vocab`, `trace.allowed` |
| Model | width 16, two heads of 8, two blocks, feed-forward 64, context 51 | `trace.model`, `trace.headSize` |
| Parameters | 8,167: token embedding 368 (4.5%), position 816 (10.0%), each block's attention 1,088 (13.3%), feed-forward 2,128 (26.1%), norms 64 (0.8%); final norm 32; output layer 391 (4.8%). The two feed-forwards hold 52% | `trace.groups`, `trace.groupSizes` |
| Checkpoints | 1 first, 13 even guess, 21 residue counts, 49 residue pairs, 66 one nat, 95 a tenth, 200 last | `trace.checkpoints[i].step`, `.why` |
| Loss at them | 3.220, 3.032, 2.836, 2.042, 0.993, 0.097, 0.064 | `trace.loss(step)` |
| e to the loss | 25.0, 20.7, 17.1, 7.7, 2.7, 1.10, 1.07: as unsure as a pick among that many equal tokens | `math.exp(trace.loss(step))` |
| Levels | even guess 3.045 (21.0), residue counts 2.856 (17.4), residue pairs 2.043 (7.7), floor 0.060 (1.062) | `trace.uniform`, `.unigram`, `.bigram`, `.floor` |
| The floor | 6 ln 6 / 180: from `<bos>` no model can tell which of six comes; 93% of the loss at step 200 | `LossScene.bosShare` |
| Rate | 1.0e−4 at step 1; 1.0e−2 at 100; 1.2e−5 at 200 | `trace.steps.learningRate` |
| Gradient length | 0.611 at step 1; at most 1.718, at step 60; 0.0082 at 200 | `trace.steps.gradNorm` |
| Clipped | nine steps: 59–62, 64, 70–73 | `trace.steps.clip`, `LoopScene.clipped` |
| Embedding scales | token rows' root mean square 0.97 at step 1, 0.93 at 200; position rows' 0.021, then 0.23: 47× smaller, then 4.1× over every row (the note's 43× is `EmbeddingScene.smaller`, the same ratio over the rows the peptide in focus reads) | `trace.tokenEmbedding`, `.positionEmbedding` |
| Attention sharpening | a row's largest share, on average: 19% at step 1, 44% at 200 (block 1 head 1); rows giving one place half or more: 10 then 59 of 174 (the other heads alike: 33–44% at 200) | `checkpoint.attention`, `AttentionScene.allShares` |
| Right guesses | insulin A 0 of 22 at step 1, 21 at 200; the batch 12, 71, 139, 175, 175 of 180 at 13, 49, 66, 95, 200; at 21, L tops 80 places | `PredictScene.right`, `LoopScene.right`, `LoopScene.commonestGuess` |
| The model's mean guess against the counts | correlation −0.12 at step 1, 0.77 at 21, 0.97 at 30, 1.00 at 49 | `trace.steps.probs` |

The trace's other accessors, for the pages to come: `stream`,
`pointGrad`, `streamGrad`, `attnInput`, `normScale`, `normShift`,
`projection`, `projectionBias`, `query`, `key`, `value`, `score`,
`mixed`, `outWeight`, `outBias`, `ffInput`, `hidden`, `ffIn`, `ffInBias`,
`ffOut`, `ffOutBias`, `readout`, `logit`, `outputWeight`, `outputBias`,
`probability`, `headGrad`, `headAdamMean`, `headAdamSquare`, `headUpdate`,
`targetLoss`, `stepProbability`, `groupGrad`, `groupUpdate`; and
`trace.optimizer`, `trace.config`, `trace.provenance`. The run keeps no
scale and shift for the blocks' second LayerNorm or for the final one,
only what they made (`Evening.plain` tells where they are 1 and 0).

## 10. A brief for each stage still to come

Each brief lists the stage's labels (the sections), what its canvas
already says (not to repeat), what its page could add (candidates, to be
filtered and previewed, not decided), the facts and their sources, and
what the user has settled. The numbers are the live run's, at insulin A's
C11 where a place is in focus.

### Shift (`shift_scene.dart`, 5 beats)

- **On screen:** the batch opens into its six peptides; input x, each
  frame less its last place; a faint copy falls under it, target y, and
  moves one place left, so under each place lies the token after it;
  padding dims.
- **Labels:** `input x` (glossed "what the model reads"), `target y`
  (glossed "the answer key: what each place should predict", "the answer
  key" where narrow).
- **Already said:** captions only: "Input x: each frame less its last
  place, 6 × 40 tokens"; "Target y starts as a copy of the same
  peptides"; "One place to the left: each place's answer is the token
  after it"; "Only x goes in; Loss grades each guess against y: 180
  targets".
- **Could add:** the lead: the batch in, x and y out, both 6 × 40, made
  once with the batch. Every place is one question, "what comes next?",
  and y holds the answers: one peptide of n residues gives n + 1 targets,
  its residues and `<eos>`; 180 in all, 60 of y's 240 slots padding,
  never scored. Every place reads the true tokens before it, never the
  model's own guesses (teacher forcing), which is why all 180 are asked
  in one pass; a model writing a peptide would feed each guess back, one
  place at a time (not drawn). A place must answer without seeing its
  answer, which sits at the next place of x: attention never reads a
  place after its own (Scores' struck keys, Attention's hatched cells).
  y never goes in: Predict's key column and Loss's line are y.
- **Facts:** `sequences.batches` (x = `frame[:, :-1]`, y = `frame[:, 1:]`);
  `trace.inputs`, `trace.targets`, `trace.targetCount`, `trace.width`,
  `trace.pads`.
- **Settled by the user:** x and y as two groups, not interleaved by
  line; the tags and their glosses; "not seeing ahead" left to the
  attention stages; y paid off at Loss. They asked "what are input x and
  target y actually?", "are we going to use both?", "what is the point of
  showing these?": the page should answer those three.

### Embedding (`embedding_scene.dart`, 15 beats)

- **On screen:** the token embedding written out; each id lights its row,
  one place at a time; the rows gather in place order; the position
  embedding's rows, alone, then added number by number into x0; the two
  Cs at places 6 and 7 outlined.
- **Labels:** `token embedding · 23 × 16`, `input x embedded · 22 × 16`,
  `position embedding · first 22 of 51 rows`,
  `x0 = token + position · 22 × 16`.
- **Already said:** learned with the model; at step 1 no update has moved
  them; `<pad>`'s row zero at every checkpoint; the lookup is only the id
  picking its row; 22 places read 12 rows; the model does not know order
  (the twin Cs share a row); the position table random at first and
  trained; 51 is the context; attention reads rows as a bag, so position
  is added; added, not side by side; position rows from 43× smaller to
  4×; x0 is the model's input, what + where.
- **Could add:** the lead: x's ids in, x0 out, a row of 16 numbers a
  place, the model's first trainable layer: 1,184 of its 8,167 numbers
  (token 368, position 816). No single one of the 16 means anything: a
  row is a token's place in a space that training shapes. Where the
  starting numbers come from: random from seed 0, token rows with a
  standard deviation of 1, position rows of 0.02 by the engine's choice,
  which is why position starts so much smaller. What changes them:
  Backward ends at x0, and a token row gets the sum over every place that
  read it (Backward's last note). x0 is the residual stream: every later
  part reads it and adds to it (Forward's ladder). Do not claim the run
  learns that similar residues get similar rows: the token table barely
  moves in 200 steps (root mean square 0.97 to 0.93).
- **Facts:** `helix_peek_LM.py`; `train.param_groups` (embeddings never
  decayed); `trace.tokenEmbedding`, `trace.positionEmbedding`,
  `trace.groupSizes`; `EmbeddingScene.smaller`, `EmbeddingScene.value`.
- **Settled by the user:** "trainable", not "learned", for rows no update
  has moved; the five-sentence position note; x0 is not shown as a sum
  (reverted); no live readout ("not readable, they switch"); the
  engine's 51 places kept and explained; they did not know embedding rows
  are trained.

### Scores (`scores_scene.dart`, 20 beats)

- **On screen:** x0's table narrows to strips; C11's row stands up and is
  evened on a chart (less its mean, over its standard deviation, then
  z-score × scale + shift = evened); the query, key and value made
  through their 16 × 16 weights, strings bursting out of the row; each
  cut into a slice a head; head 1's query and every key lie down; one
  score worked (eight products, summed, over √8); the query scans every
  key up to its own; softmax makes the shares, a bar each.
- **Labels:** `x0 = token + position · 22 × 16`; the chart's `mean`,
  standard deviation band and `z-score`; the column titles, the
  place's name (`C11`) over its standing row, then `query`, `key`,
  `value`; the plates `block 1 · query weights · 16 × 16` (and
  key, value) with their status, `random start (seed 0), no update yet`
  or `…, then N training updates`; the cut's `head 1 / 1–8`;
  `block 1 · head 1 · query and keys`.
- **Already said:** a place knows only itself; attention reads up to its
  own, never after; LayerNorm (z-score, learned scale and shift, one
  scale for every row); query, key and value: what a place looks for,
  offers, hands over, each from the model's own weights; the cut into
  heads, 16 ÷ 2 = 8, why the width must divide; a score; softmax.
- **Could add:** the lead: x0 in; out, block 1's query, key and value
  for every place, and the shares of the place in focus.
  Attention is the one part where places exchange anything; everything
  else works on each place alone (Feed-forward's note says so later). The
  same weights make every place's query, key and value; the scores and
  shares are made fresh for every peptide and step, never stored. Each
  score is divided by √8, which keeps a wider head's scores from
  swamping softmax (the About sheet's sentence; its slide was removed as
  redundant, so ask before saying more). Training sharpens the shares: a
  row's largest averages 19% at step 1, 44% at 200 (C11: S9 23% then G1
  55%).
- **Facts:** `nn.MultiheadAttention` in the engine's encoder layer
  (`norm_first=True`); `trace.attnInput`, `normScale`, `normShift`,
  `projection`, `projectionBias`, `query`, `key`, `value`, `score`;
  `ScoresScene.evening`, `evenScale`, `topKey`, `weightsName`,
  `weightsStatus`; `AttentionScene.shares`.
- **Settled by the user:** the weight table was reverted ("I don't like
  the new view"), so don't re-add it; the √8 slide was removed as
  redundant; "standard deviation" in full; no strings before the row
  flows; the evening written as the sum `z-score × scale + shift =
  evened`; block 1 named on every plate.

### Attention (`attention_scene.dart`, `worked_answer.dart`, 25 beats)

- **On screen:** head 1's keys turn into values, and arcs carry each share
  of each value into its answer; head 2 reads; number 1 of head 1's answer
  worked out place by place (each value × its share, the largest share
  and the place that adds most, summed: 0.30); the output weights make
  what attention adds (output number 1 alone: 0.11); head 1's map, then
  head 2's, on the table's rows, the places after each row hatched; the
  table widens to what block 1's attention adds, then the sums.
- **Labels:** `block 1 · head N · query and keys`, then `… · values`;
  `block 1 · value weights · 16 × 16` (the worked answer's plate);
  `output`, `block 1 · output weights · 16 × 16` with its status;
  `block 1 · head N · shares in % · 22 × 22`; the hatch;
  `what block 1's attention adds · 22 × 16`;
  `x0 + block 1's attention · 22 × 16`.
- **Already said:** a value is what a place hands over; the answer is each
  value × its share, summed; two heads, two questions; a value is made as
  a query is; the shares are made fresh, not learned; the sum is an
  average; output weights mix the heads; a row of the map, a column;
  each row adds to 100%; hatched never read, the next is its answer; head
  2 its own map; nothing overwritten: added.
- **Could add:** the lead: Scores' shares and values in, x0 + block 1's
  attention out. Reading is a weighted average: the answer is a blend of
  the values read, never a copy unless one share is near 100%. The map
  is where each place looks (a row) and who reads each place (a column).
  Attention's weights, four 16 × 16 matrices and their biases, are 1,088
  a block, 13% of the model. Training sharpens the maps (section 9);
  heads in a model this small have no textbook roles. The row is added
  to, never replaced: x0 is still in it (Forward's ladder).
- **Facts:** the engine's multi-head attention (softmax of the scores ×
  the values a head, the heads side by side, `out_proj`); `trace.mixed`,
  `outWeight`, `outBias`, `checkpoint.attention`;
  `AttentionScene.allShares`, `movedRows`, `readsMost`, `answerScale`;
  `WorkedAnswer.values`, `brought`, `answer`.
- **Settled by the user:** one map at a time, as large as the canvas
  allows, percentages where they fit; a tap on a row puts its place in
  focus; "read most" and "brings most" retired; "Output number 1"; the
  answers' box grows into the map; low arcs lifted to nest.

### Feed-forward (`feed_forward_scene.dart`, 20 beats)

- **On screen:** C11's row, x0 + block 1's attention, turns into the 16
  inputs of a network; the block's second LayerNorm on Scores' chart; the
  1,024 weights to 64 neurons; the brightest neuron worked (sum 1.10,
  GELU 0.95); the most negative (−1.83, GELU −0.06); all 64 (23 lit);
  the 16 outputs; back to the row; what every place gains; added: block
  1's output.
- **Labels:** `x0 + block 1's attention · 22 × 16`; the chart; GELU's
  curve; `block 1's output · 22 × 16`.
- **Already said:** attention moved numbers between places, the
  feed-forward works on each alone; LayerNorm again on a copy; a line is
  a weight, its colour input × weight; a weighted sum plus a bias; GELU
  defined; why the bend; 16 → 64 → 16; nothing overwritten; block 2
  next.
- **Could add:** the lead: x0 + block 1's attention in, block 1's output
  out. Attention gathers, the feed-forward works on what was gathered,
  each place alone, the same network at all 22. It holds most of the
  model: the two feed-forwards are 4,256 of 8,167 numbers, 52%. A neuron
  is a detector for one pattern of the 16 inputs. The run keeps no scale
  and shift for this LayerNorm: say nothing of their values.
- **Facts:** the engine's encoder layer (LayerNorm, `linear1` 64 × 16,
  GELU, `linear2` 16 × 64, added); `trace.ffInput`, `hidden`, `ffIn`,
  `ffInBias`, `ffOut`, `ffOutBias`; `FeedForwardScene.sums`, `gelu`,
  `worked`, `litNeurons`, `evening`.
- **Settled by the user:** the three worked GELU examples kept (after one
  removal); no points on the curve once all 64 are lit; one dot a lit
  neuron along its strongest input; no lift-off before the stand-up; the
  chart's bars hang from the mean line.

### Forward (`forward_scene.dart`, 12 beats)

- **On screen:** C11's row down the whole pass, a slot a point of the
  stream: x0, + block 1's attention, + block 1's feed-forward, + block
  2's attention, + block 2's feed-forward, the final LayerNorm; each
  part's strip, a copy dropping through it; every row keeps its numbers;
  the last row outlined, what Predict reads.
- **Labels:** `block 1's output · 22 × 16` (as it opens); the slot names;
  the outline on the last row.
- **Already said:** each part reads the row and adds to it, never
  replacing it; each block reads the rows the one before left; a last
  evening out; every place at once; Predict next. The captions give
  block 2's two-hop read (C11 reads Q5 12%, which in block 1 read E4 33%,
  at step 1).
- **Could add:** the lead: x0 in, the last row (hf) out, for every place
  at once. The row is a shared workspace: the final row is x0 plus four
  additions, then evened. Two blocks mean two hops: block 2 reads rows
  that already hold what block 1 gathered. This pass is the whole model
  at work, the same when it writes a peptide (Predict on). The early
  readout (the output layer applied at every point, a probe) left the
  screen on 2026-11-01 and the run still keeps it: mention it only if the
  user asks for it back.
- **Facts:** the encoder's two layers and its final `norm`;
  `trace.points` (x0, m1, h1, m2, h2, hf), `trace.stream`;
  `ForwardScene.partName`, `readsThrough`, `topRead`, `evening`.
- **Settled by the user:** a Block 2 stage was built and removed ("take it
  away"), so don't re-add it; every row keeps its numbers; the two-hop
  caption replaced the comparison.

### Predict (`predict_scene.dart`, 14 beats)

- **On screen:** C11's last row through the output layer's 368 weights to
  23 logits (K's worked: 1.00 at step 1); `<pad>` and `<bos>` struck to
  −∞; e to each logit, then over their sum: shares of 100% (K 10%; S,
  what came next, 1.3%); the answer's band lit; every place at once on a
  map of squares in slots, the slot of what came next lit; the key, y and
  p(y).
- **Labels:** `logits`; `output layer · 23 × 16` with its status;
  `next-token probabilities · 22 × 21`; `y`, `p(y)`.
- **Already said:** only the last row is read; a row of weights and a
  bias a token; a logit is high where row and weights agree; logits are
  raw scores; −∞ and why; softmax; every place through the same layer;
  a square's area is its share; y and p(y); Loss next.
- **Could add:** the lead: every place's last row in, a probability for
  each of 21 tokens out. The output layer has its own row for each token,
  separate from the token embedding's. The model's answer is a
  distribution, not a letter: writing a peptide would draw from it (not
  drawn). The same 23 tokens Tokenise made are its menu. How guesses
  change: insulin A's top bet right at 0 of 22 places at step 1, 21 at
  200 (Loop shows the run between).
- **Facts:** `lm_head`, `bigram_torch.masked`; `trace.logit`,
  `outputWeight`, `outputBias`, `probability`; `PredictScene.logits`,
  `shares`, `allShares`, `top`, `right`, `blocked`, `likeliest`.
- **Settled by the user:** no white boxes anywhere in Predict (squares in
  lit slots, a soft lit band); "given" retired; "Top bet after …: K, 10%.
  True next residue, S, got 1.3%": guess and answer key named apart.

### Loss (`loss_scene.dart`, 17 beats)

- **On screen:** every square but what came next goes; the lit slots
  slide to the key; −ln p(y) worked on its curve (C11: 1.34% costs 4.31
  nats), an even guess dashed at ln 21 = 3.045; insulin A's target y line
  alone with a bar a target; the batch, six lines; their mean, a honey
  line: the step's loss (3.220).
- **Labels:** `p(y) · probability of the target · 22`; `target y`
  (with Shift's gloss); the nats axis; `even guess`; the legend `loss`;
  `mean`.
- **Already said:** why p(y) alone; 0 for a sure right guess, ln 2 a
  halving; a bar a place; over the dashed line, worse than an even guess;
  padding never scored; the mean is the loss; cross-entropy; Backward
  next; at step 200, 93% at `<bos>`.
- **Could add:** the lead: every place's p(y) in, one number out, the
  loss, the only thing training lowers. e to the loss is how many equal
  tokens the model is as unsure as: 25.0 at step 1, worse than the even
  guess's 21; 17.1 at step 21; 2.7 at 66; 1.07 at 200, the floor 1.062.
  Each place weighs the same in the mean: a peptide's `<eos>` counts, a
  pad does not. The levels a page names are Loop's: even guess, residue
  counts, residue pairs, the floor (point to them; Loop's holds explain
  each).
- **Facts:** `train._token_losses`; `trace.loss`, `trace.targetLoss`,
  `trace.steps.residueLoss`, `eosLoss`; `LossScene.given`, `surprises`,
  `bosShare`, `worked`, `mean`, `ceiling`.
- **Settled by the user:** the peptide alone first, then the batch; the
  others' bars a quiet honey, not residue colours; the mean as a line
  (levelling and ghosts removed); "residue pairs" in the words.

### Backward (`backward_scene.dart`, 44 beats)

- **On screen:** back to C11 and its cost; Predict's bars; y, the answer
  key; p − y (S: 0.013 − 1 = −0.99; the others their shares); the errors
  condense into a column; they run back along the output layer's strings
  to C11's row gradient (number 10: −0.32), its extremes ringed; the
  gradient climbs Forward's ladder, each + passing it whole, each part
  adding its own (attention's from the later places that read C11); at
  x0 it goes to the token row and the position row; every place's x0
  gradient.
- **Labels:** `p − y`, `gradient`; `output layer · 23 × 16`; the legend
  over the bars; the ladder's part names; `gradient at x0 · 22 × 16`.
- **Already said:** nearly every mechanism, mini-step by mini-step: what a
  gradient is; p − y and its sign; the chain rule along the strings; a
  row is not a weight; through LayerNorm; through a +; blame from later
  places; x0 to its two rows; ÷ 180; Update next.
- **Could add:** the lead: the loss in, how the loss changes with every
  number of every row out, from the output back to x0. Backward changes
  nothing: it measures; Update moves the weights. The + of the residual
  stream passes the gradient back whole, which is why a deep stack can
  learn at all. As the loss nears its floor the gradients vanish: their
  total length 0.611 at step 1, 0.008 at 200, and at step 200 all of
  x0's gradient is at `<bos>`. The trace keeps them before clipping.
- **Facts:** `train_step` (`loss.backward()`, `after_backward`);
  `trace.pointGrad`, `streamGrad`, `headGrad`, `steps.gradNorm`;
  `BackwardScene.errors`, `rowGradient`, `ladder`, `sentBack`,
  `bosShare`, `extremes`, `workedNumber`, `climb`.
- **Settled by the user:** every mini-step its own caption and note; no
  borders or outlines on the bars; the two string relights (a weight's
  gradient, the batch mean) cut and moved to Update; scales the whole
  batch's; numbers × 180.

### Update (`update_scene.dart`, 38 beats)

- **On screen:** the output layer's strings; one weight worked (S's from
  number 6: −0.99 at its end × 1.94 at its start = −1.92); the same weight
  at every place, a pull a row; the peptide's sum, all 180 (−4.075), ÷
  180 (−0.0226); every weight's gradient as a grid; the ten groups'
  lengths and their total (0.611) against the clip, 1.0; AdamW on S's 16
  weights (running mean, running size, their ratio, × −rate: the step);
  the weights after.
- **Labels:** `last rows · 22 × 16`; the table's columns
  (`number N`, `× p − y at S`, `= pull`); the groups' names and
  `all · 8,167`; AdamW's columns (`gradient`, …, `step`, `after`); the
  plate's status, one update on.
- **Already said:** the whole of gradient descent here: a weight's
  gradient from the two ends of its string, the mean of its 180 pulls,
  the grid, the groups, the clip (nine steps between 59 and 73), Adam's
  two averages, the ratio (±1 at step 1), the minus, the rate's warm-up
  and cosine, decay, a step's size, Loop next.
- **Could add:** the lead: every weight's gradient in, every weight
  moved out: the one place the model changes. The picture: each weight a
  small step downhill, all 8,167 at once; one step moves a guess by a
  hair (Loop shows the hairs add up). Why Adam: every weight steps about
  the same distance whatever its gradient's size (at step 1, exactly the
  rate, 1.0e−4). Decay shrinks weight matrices only, never the
  embeddings, biases or LayerNorms: more exact than the note's "each
  weight". The clip guards against a too-large step: the gradients'
  length peaked at 1.718, at step 60.
- **Facts:** `clip_grad_norm_`, `torch.optim.AdamW`, `train.param_groups`,
  `train.lr_schedule`; `trace.steps.learningRate`, `gradNorm`, `clip`,
  `groupGrad`, `groupUpdate`, `trace.headGrad`, `headAdamMean`,
  `headAdamSquare`, `headUpdate`, `trace.optimizer`;
  `UpdateScene.worked`, `pulls`, `adam`, `rate`, `groupName`, `total`,
  `largestGradient`, `gradientRange`, `stepRange`, `signsAlone`.
- **Settled by the user:** one weight first, then every place on the
  table; size marks as ticks, not outlines; the step grid soft; AdamW's
  bars drawn as Scores' chart draws a row.

### Loop (`loop_scene.dart`, `domain/loop_pace.dart`, 44 beats)

- **On screen:** step 1 rebuilt from Update's end: its guesses as
  Predict's map, its cost the first point of a honey curve, the levels
  dashed and the floor dotted, the rate's schedule; steps 2 to 4 one at a
  time; moves to each kept step and a hold there; the end: `<bos>`'s six
  squares a sixth each, the run whole, how far Update's weight travelled.
- **Labels:** `next-token probabilities · 22 × 21`; `even guess`,
  `residue counts`, `residue pairs` (dashed) and the floor (dotted);
  `rate`; the checkpoints' ticks.
- **Already said:** the step repeated on the batch made once; the map one
  peptide's, the loss all six's; the levels; each update a hair; the
  rate's climb; each level at its hold; guesses turning sure; the clip;
  the cosine; the floor at `<bos>`; only the weights changed; none held
  out, the model has them by heart.
- **Could add:** the lead: step 1's weights in, step 200's out, the batch
  unchanged. The run's shape: a slow start (steps 1 to 49, the loss from
  3.220 to 2.042), a burst (50 to 95, to 0.097, the squares jumping into
  their lit slots), then polish (96 to 200, to 0.064). Why these seven
  steps: kept by rule, the first, the first under each level, the last;
  the step menu picks one for every stage. This run learns six peptides
  by heart; a model meant to write new ones is trained on many and
  checked on peptides it never saw (the engine's corpus run, 10,416
  peptides, is not drawn). If the About sheet is retired, its "This run"
  paragraph may belong here (ask).
- **Facts:** `LoopPace`; `trace.steps.probs`, `loss`, `learningRate`,
  `clip`; `LoopScene.right`, `sure`, `commonestGuess`, `commonestTarget`,
  `clipped`, `why`, `everRose`, `lossAt`.
- **Settled by the user:** Predict's map at every step (schema 9); a hold
  with a caption and a note at each kept step; weights in the opening
  only; numbers written only while the run stands; the curve in honey;
  the run always from step 1.

## 11. When all twelve exist

The About sheet is then reached from no stage. Two of its paragraphs have
no page yet: "This run" (the model's size, seed, device, PyTorch, recorded
and replayed byte for byte) and the sources of "The data" (the six
peptides' records). Ask the user where they go: Loop's page, a page of
their own behind the "Recorded run" line, or the sheet kept behind a link.

## 12. Checklist

- [ ] Inventory: labels, captions and notes at steps 1 and 200 (words
      check)
- [ ] Questions, misreadings, later consequences listed
- [ ] Every fact checked in the engine and the run
- [ ] Draft: lead + a section a tag, links at their causes, the filter
      applied, the words of 3.5, the font of 3.6
- [ ] Every number computed; every run-dependent claim guarded
- [ ] Previewed with the user, with its scroll measured
- [ ] `info` overridden; no other wiring
- [ ] Page test with its guards both ways; the two listing tests changed
- [ ] `flutter analyze`; `flutter test test/features/peptide_lm`; the full
      suite (the only known red: `test/features/zoom/_scratch_shots_test.dart`
      without its variable)
- [ ] Shots at three sizes, read; paths given to the user
- [ ] `peptide-lm.md`, this file's table, `CLAUDE.md`, Claude's memory
- [ ] Committed locally, not pushed
