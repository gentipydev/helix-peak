# Reuse audit

What each of the 41 files under `lib/features/gene_lookup/presentation/`
(19,840 lines) would cost a new flow to reuse, read from the import graph.
Audited on 2026-09-26 at `fb6e5ce`. This is a report only: no code was changed.
Where it disagrees with Appendix C of the feature-concepts design document,
this report is the one that was read off the code.

## Method

- Every `import` and `export` in `lib/` and `test/` was resolved the way
  `test/architecture_test.dart` resolves them (relative paths and
  `package:helixpeek/`), then followed **transitively**. A moved file takes
  its imports with it. So a sibling import such as `'anatomy_stages.dart'` is
  a `gene_lookup` import, and whatever that sibling reaches, the file reaches
  too.
- Tiers are judged against the layering the architecture test already
  enforces:
  - **Rule 2.** Nothing under `lib/shared/` or `lib/core/` imports anything
    under `lib/features/`, domain entities included.
  - **Rule 3.** No feature imports another feature's `presentation/`, and
    `lab/` is a feature.
- Context budget: `anatomy_screen.dart`, `anatomy_painter.dart` and
  `evidence_strip.dart` were read only for:
  - their import lines;
  - their top-level declarations;
  - the screen's constructors and its State's field declarations;
  - counts of the domain type names they use.

  No method body in those three files was read.

## The answer

| Tier | Files | What it means |
|---|---|---|
| **1: move now** | 8 | Nothing in the file's closure is under `lib/features/`. A pure `git mv` into `lib/shared/`. |
| **2: promote on demand** | 29 | The closure reaches a `gene_lookup` domain entity (24 files) or its data layer (5). Such a file can't be imported where it stands (rule 3) or promoted as it is (rule 2). Each one waits until its blocker, named below, has a home. |
| **3: the walk's own state** | inside `anatomy_screen.dart` | All the orchestration lives as private members of one `State`. No other file is bound to it. |
| **Stays the walk's** | 4 | `anatomy_screen.dart`, `gene_screen.dart`, the cubit and its state. |

The three findings that matter most:

1. **Tier 1 is 8 files, and only 5 of Appendix C's 9 are in it.**
   `anatomy_layout.dart` is not among them.
2. **"Import unchanged" is not available.** The architecture test forbids it.
3. **One file holds the anatomy engine to the walk.** `anatomy_stages.dart`
   imports `GeneRecord`. It also imports `format.dart`, whose only domain
   reference is `GeneImpact.middlePhred`. Two changes fix that:
   - move `gene_record.dart` (119 lines, imports only `flutter/foundation`)
     to `lib/core/biology/`;
   - split `genomeRank` out of `format.dart`.

   After them, 12 more files become pure moves, 20 in all (route R below).

## Where this disagrees with Appendix C

1. **Four of Appendix C's nine tier 1 files are not tier 1.**
   - `anatomy_layout.dart`, `anatomy_ruler.dart`, `anatomy_translation.dart`
     and `anatomy_selection.dart` each reach `GeneRecord` through
     `anatomy_stages.dart`.
   - Placed under `lib/shared/`, each of them fails rule 2.
   - `anatomy_layout.dart` is one of the four, although the appendix calls it
     "the single most valuable thing to share".
2. **Tier 1 misses three files.** `sequence_scrubber.dart`, `level_pips.dart`
   and `score_bar.dart` import only Flutter and `core/theme/`. The appendix
   puts them in tier 2.
3. **Tier 2's action, "import unchanged", breaks the architecture test.**
   - Rule 3 fails any file under `lib/features/lab/` that imports
     `lib/features/gene_lookup/presentation/`. The test's own self-check uses
     `anatomy_canvas.dart` as its example.
   - A tier 2 file can't be promoted as it is either, because rule 2 forbids
     `shared/` from importing a domain entity.
   - So every tier 2 file needs its blocker resolved before a new flow can use
     it.
   - The same rule rules out the fallback in the appendix's "Working alongside
     the rework" section: "leave it; the lab can import it where it stands".
4. **Three of the appendix's tier 2 files reach the data layer**, not only
   entities and the theme:
   - `evidence_row.dart`, `clinvar_block.dart` and `variants_overview.dart`
     all go through `impact_explanation_view.dart`, which reads
     `ImpactExplanationRepository` from context.
   - `structure_view.dart` also depends on `TrackSource` from `core/network/`,
     which it reads from context.
5. **Twelve of the 41 files are missing from the appendix:**
   - `anatomy_address`, `anatomy_run_labels`, `anatomy_scene`,
     `anatomy_selection_canvas`, `anatomy_stages`, `anatomy_tracer`,
     `record_sheet`, `stage_bar`;
   - `evidence_sections`, `coding_evidence`, `impact_explanation_view`,
     `impact_panel`.

   Two of them matter most. `anatomy_stages.dart` decides whether the engine
   can move at all. `anatomy_scene.dart` is a file the playbook expects to be
   promoted already.
6. **The sequencing advice doesn't protect the file it names.**
   - "Promote tier 1 before the rework starts" is meant to keep the rework and
     the move off `anatomy_layout.dart` at the same time.
   - `anatomy_layout.dart` can't be in the first promotion.
   - If the rework touches it, route R's R1–R3 (or route S) have to land
     before the rework as well.
7. **Tier 3 and "stays the walk's" are right.** The one exception: the three
   routes are outside `presentation/` and nothing in the imports ties them to
   the walk (see "Noticed, not changed").

Consequences for the playbook and the session prompts:

- **Session 07 (playbook 0.4)** has been rewritten (2026-09-26) to move the
  eight files below and then carry out route R, in five steps.
- **Session 11 (playbook 1.1)** reads "the promoted `anatomy_motion.dart` and
  `anatomy_scene.dart`". Motion moves in session 07's step 1 and scene in its
  step 5.
- **Session 24 (playbook AR.2)** says `StructureView` "embeds as-is" because
  the audit puts it in tier 2.
  - An import of it from `lib/features/lab/ar/` breaks rule 3.
  - It has to be promoted, and `ProteinTarget` and `TrackKind` block that.

## Tier 1: move now

In the imports column, `dart:` libraries are omitted and Flutter SDK
libraries are given by name.

| File | Lines | Imports | Imported by (lib) | Appendix C |
|---|---:|---|---|---|
| `inspector/inspector_sheet.dart` | 431 | material | `anatomy_screen`, `constraint_panel`, `impact_panel` | tier 1 ✓ |
| `anatomy/anatomy_motion.dart` | 71 | none | `anatomy_layout`, `anatomy_scene` (which re-exports it), `anatomy_translation` | tier 1 ✓ |
| `structure/structure_loading_view.dart` | 44 | material, `lottie` | `structure_view` | tier 1 ✓ |
| `structure/structure_rotation.dart` | 34 | `vector_math` | `structure_view` | tier 1 ✓ |
| `constraint/constraint_colors.dart` | 22 | material | `anatomy_painter`, `evidence_strip`, `variants_overview`, `constraint_toolbar` | tier 1 ✓ |
| `anatomy/sequence_scrubber.dart` | 199 | material; `core/theme/app_spacing`, `app_typography` | `anatomy_screen`, `variants_overview` | tier 2 ✗ |
| `inspector/level_pips.dart` | 72 | material; `core/theme/app_typography` | `constraint_panel`, `impact_panel` | tier 2 ✗ |
| `inspector/score_bar.dart` | 249 | material; `core/theme/app_typography` | `constraint_panel`, `impact_panel` | tier 2 ✗ |

`structure_loading_view.dart` names its animation as the asset key
`assets/animations/process.json`. That key doesn't depend on where the Dart
file lives.

The four files that Appendix C lists as tier 1 but aren't:

| File | Lines | Imports | What holds it |
|---|---:|---|---|
| `anatomy/anatomy_layout.dart` | 1,194 | foundation; `anatomy_motion`, `anatomy_ruler`, `anatomy_stages` | It uses only the stage model (`AnatomyStage`, `StageBlock`, `StageKind`). But `anatomy_stages.dart` imports `entities/gene_record.dart`. It also imports `format.dart`, and through it `entities/gene_impact.dart`. |
| `anatomy/anatomy_ruler.dart` | 103 | `anatomy_stages` | The same. It uses only `AnatomyStage`, `StageBlock` and `StageKind`. |
| `anatomy/anatomy_translation.dart` | 125 | `anatomy_layout`, `anatomy_motion` | It names no stage type itself and is held only through `anatomy_layout`. |
| `anatomy/anatomy_selection.dart` | 127 | foundation; `anatomy_stages` | It names `AnatomyModel` itself: `AnatomySelection.of(AnatomyModel model, int position)`. |

## Tier 2: promote on demand

Appendix C defines tier 2 as "depends only on domain entities and the theme".
That describes 24 of these 29 files, and the other 5 also reach the data
layer. None of them can be used by a new flow as it stands, so the tier is cut
here by **what blocks promotion**. Resolving the blocker is what turns a file
into a move.

### 2a: held only by `GeneRecord` (12 files)

These reach the domain only through two paths:
- `anatomy_stages.dart` → `entities/gene_record.dart`;
- `format.dart` → `entities/gene_impact.dart`, for one constant.

Route R unlocks all twelve.

| File | Lines | Imports | The blocker, exactly |
|---|---:|---|---|
| `anatomy/anatomy_stages.dart` | 1,739 | foundation; `entities/gene_record`, `format` | The file has two halves (details below). |
| `format.dart` | 83 | `entities/gene_impact` | `genomeRank` reads `GeneImpact.middlePhred`. `grouped`, `spelled`, `spelledLeading` and `formatScore` name nothing from the domain. See below for who imports it. |
| `anatomy/anatomy_layout.dart` | 1,194 | foundation; `anatomy_motion`, `anatomy_ruler`, `anatomy_stages` | Stage model only. |
| `anatomy/anatomy_ruler.dart` | 103 | `anatomy_stages` | Stage model only. |
| `anatomy/anatomy_translation.dart` | 125 | `anatomy_layout`, `anatomy_motion` | Held only through `anatomy_layout`. |
| `anatomy/anatomy_run_labels.dart` | 410 | material; `core/theme/app_typography`; `anatomy_layout`, `anatomy_stages` | Stage model only (`AnatomyStage`, `StageRun`). |
| `anatomy/anatomy_selection.dart` | 127 | foundation; `anatomy_stages` | `AnatomyModel`: `AnatomySelection.of(model, position)` and `_frameOf(model, …)`. |
| `anatomy/anatomy_scene.dart` | 510 | foundation; `core/biology/amino_acids`, `core/theme/anatomy_colors`; `anatomy_layout`, `anatomy_motion`, `anatomy_stages`, `anatomy_translation`; re-exports `anatomy_motion` | `AnatomyModel`: a field, and a parameter of each of its four static builders (`resting`, `between`, `selection`, `_build`). |
| `anatomy/anatomy_address.dart` | 259 | foundation; `core/biology/amino_acids`; `format`, `anatomy_stages` | `AnatomyModel`: `AnatomyAddress.of(model)`. |
| `anatomy/anatomy_tracer.dart` | 516 | foundation; `core/biology/amino_acids`; `format`, `anatomy_address`, `anatomy_stages` | `AnatomyModel`, in `TracerReader`'s static methods. |
| `anatomy/stage_bar.dart` | 153 | material; `core/theme/app_spacing`; `anatomy_stages` | `AnatomyModel`: `StageBar.labelsFor(model)`. |
| `clinvar/evidence_sections.dart` | 69 | `anatomy/anatomy_stages` | `AnatomyModel`: `geneRuns(model)`. |

The two halves of `anatomy_stages.dart`:

- **Lines 1–580** are the stage model: `RoleKind`, `CodonMark`, `Role`,
  `StageKind`, `StageBlock`, `regionFloor`, `StageRun` and `AnatomyStage`. They
  name neither `GeneRecord` nor anything from `format.dart`.
- **Lines 582–1739** are `AnatomyModel`, which holds the `GeneRecord`, and
  `_AnatomyDerivation`, which reads `GeneRecord`, `Segment` and `Peptide` and
  calls `grouped`.
- **No private name crosses between them.** `_set` and `_geneRoleAt` are
  declared in the second half and are only mentioned in doc comments in the
  first.

`format.dart` is imported by 14 lib files. Two of them are outside the walk,
and they are the architecture test's two `features` known breaches:
- `search_screen.dart`, which uses `spelled`;
- `protein_card.dart`, which uses `grouped`.

### 2b: held by another entity (12 files)

| File | Lines | Imports | The blocker, exactly |
|---|---:|---|---|
| `clinvar/clinvar_colors.dart` | 121 | material; `entities/gene_clinvar` | The `ClinVarGroup` enum, and nothing else. |
| `constraint/constraint_toolbar.dart` | 284 | material; `core/biology/amino_acids`, `core/theme/anatomy_colors`, `app_typography`; `entities/gene_clinvar`; `clinvar/clinvar_colors`, `constraint_colors` | `ClinVarGroup`, and nothing else. |
| `clinvar/sources_note.dart` | 92 | material; `core/theme/app_typography`; `entities/variant_evidence` | One constant: `VariantEvidence.esmStrong`. |
| `constraint/constraint_panel.dart` | 368 | material; `core/theme/anatomy_colors`, `app_typography`; `entities/gene_clinvar`, `protein_constraint`; `clinvar/clinvar_colors`, `format`, `inspector/inspector_sheet`, `level_pips`, `score_bar` | `ClinVarGroup`, `ResidueConstraint`, `ConstraintLevel` and `SubstitutionScore`. |
| `anatomy/anatomy_fasta.dart` | 161 | `entities/protein_target`; `anatomy_stages` | `ProteinTarget` and `AnatomyModel`: every method takes both. |
| `anatomy/record_sheet.dart` | 339 | material, services; `core/theme/app_spacing`, `app_typography`; `entities/gene_clinvar`, `protein_target`; `clinvar/sources_note`, `format`, `anatomy_fasta`, `anatomy_stages` | `ProteinTarget`, `GeneClinVar` and `AnatomyModel`. It is the screen's About sheet, and nothing else opens it. |
| `inspector/coding_evidence.dart` | 65 | foundation; `core/biology/genetic_code`; `entities/gene_impact`, `protein_constraint`; `anatomy/anatomy_address`, `anatomy_stages` | `GeneImpact`, `ProteinConstraint`, `ResidueConstraint` and `AnatomyModel`. |
| `anatomy/anatomy_painter.dart` | 2,247 | foundation, material, semantics; `core/theme/anatomy_colors`, `app_typography`, `nucleotide_colors`; `entities/protein_constraint`; `clinvar/clinvar_colors`, `constraint/constraint_colors`, `format`; `anatomy_layout`, `anatomy_ruler`, `anatomy_run_labels`, `anatomy_scene`, `anatomy_stages`, `anatomy_tracer`, `anatomy_translation` | `ProteinConstraint` and `ClinVarMark` (from `clinvar_colors`, so `ClinVarGroup`). Through `anatomy_scene` and `anatomy_tracer` it also reaches everything in 2a. |
| `anatomy/anatomy_canvas.dart` | 565 | material, semantics; `core/theme/anatomy_colors`, `nucleotide_colors`; `entities/protein_constraint`; `clinvar/clinvar_colors`; `anatomy_layout`, `anatomy_painter`, `anatomy_scene`, `anatomy_stages`, `anatomy_tracer` | `AnatomyModel` (its `model` field), `ProteinConstraint`, `ClinVarMark`, and the painter. |
| `anatomy/anatomy_selection_canvas.dart` | 377 | foundation, material, semantics; `core/theme/anatomy_colors`, `app_typography`, `nucleotide_colors`; `anatomy_canvas`, `anatomy_layout`, `anatomy_painter`, `anatomy_scene`, `anatomy_selection`, `anatomy_stages`, `anatomy_tracer` | `AnatomyModel`, plus the canvas and the painter. |
| `clinvar/evidence_strip.dart` | 1,915 | foundation, gestures, material, semantics; `core/theme/app_typography`; `entities/gene_clinvar`, `gene_impact`, `protein_constraint`, `variant_evidence`; `constraint/constraint_colors`, `format`, `clinvar_colors`, `evidence_sections` | `ClinVarGroup`, `VariantEvidence`, `ConstraintRegion`, `ProteinConstraint` and `GeneImpact`. It reaches `AnatomyModel` through `evidence_sections`. |
| `structure/structure_view.dart` | 647 | gestures, material, `flutter_bloc`, `flutter_scene`, `vector_math`; `core/network/track_source`, `core/theme/anatomy_colors`, `app_spacing`; `entities/protein_target`, `protein_track`; `structure_loading_view`, `structure_rotation` | `ProteinTarget` (for `slug`, `chains` and the structure caption) and `TrackKind.structure`. It reads `TrackSource?` from context. |

### 2c: reaches the data layer (5 files)

| File | Lines | Imports | The blocker, exactly |
|---|---:|---|---|
| `inspector/impact_explanation_view.dart` | 211 | material, services, `flutter_bloc`, `url_launcher`; `core/theme/app_typography`; `data/repositories/impact_explanation_repository`; `entities/impact_explanations` | It reads `ImpactExplanationRepository?` from context unless it is handed one as `repository`. It is the only file under `presentation/` that imports `gene_lookup/data/`. |
| `clinvar/evidence_row.dart` | 606 | material, services, `url_launcher`; `core/biology/amino_acids`, `core/theme/app_typography`; `entities/gene_clinvar`, `variant_evidence`; `format`, `inspector/impact_explanation_view`, `clinvar_colors` | `ImpactExplanationView`, and through it the data layer. `VariantEvidence`, `ClinVarVariant`, `ClinVarTrait`, `ClinVarGroup`. `genomeRank`. |
| `clinvar/clinvar_block.dart` | 143 | material; `core/theme/app_typography`; `entities/variant_evidence`; `format`, `evidence_row` | `evidence_row`, and so the data layer. `VariantEvidence`. |
| `inspector/impact_panel.dart` | 590 | material; `core/theme/anatomy_colors`, `app_typography`; `entities/gene_clinvar`, `gene_impact`, `impact_explanations`; `clinvar/clinvar_colors`, `format`, `coding_evidence`, `impact_explanation_view`, `inspector_sheet`, `level_pips`, `score_bar` | `ImpactExplanationView`. `GeneImpact`, `BaseImpact`, `ImpactLevel`, `AltScore`, `ClinVarGroup`, `ImpactExplanationRequest`. It reaches `AnatomyModel` through `coding_evidence`. |
| `clinvar/variants_overview.dart` | 1,489 | material, rendering; `core/router/landscape_route`, `core/theme/app_spacing`, `app_typography`; `entities/gene_clinvar`, `protein_constraint`, `variant_evidence`; `anatomy/sequence_scrubber`, `constraint/constraint_colors`, `format`, `clinvar_colors`, `evidence_row`, `evidence_sections`, `evidence_strip`, `sources_note` | `evidence_row`, and so the data layer. `VariantEvidence`, `ClinVarGroup`, `GeneClinVar`, `ProteinConstraint`. It reaches `AnatomyModel` through `evidence_sections`. |

## Tier 3: the walk's own state

The coupling Appendix C describes is real, and it is all in one place:

- No file under `presentation/` imports `anatomy_screen.dart`.
  `gene_screen.dart` is its only importer in `lib/`.
- The only public type it declares is `AnatomyScreen`.
- Everything below is a private member of `_AnatomyScreenState`, or a private
  class in the same file, and the members share its fields. None of them can
  be named from another file.

To extract any one of them, cut it out of the `State` and turn the fields it
shares into parameters or callbacks. That is a refactor, so do one per
session, each with its own baseline check.

The grouping below is by the members' names and the fields they declare; no
method bodies were read.

| Piece | State it owns | Methods | What it drives |
|---|---|---|---|
| The model | `_model`: `AnatomyModel.derive(widget.record, chain: widget.target.chain)`, in the field initialiser and again in `didUpdateWidget` | none | everything below |
| Stage paging and swipe | `_stage`, `_scroll`, `_sourceScrollOffset`, `_swipeOrigin`, `_swipeTravel`, `_verticalSwipe`, `_geneScrollHold` | `_step`, `_goToPage`, `_land`, `_settled`, `_trackSwipe`, `_finishSwipe`, `_restoreScroll`, `_shownStage`, `_shownLayout`, `_scrolls`, `_scrubs`, `_rowLabelAt`, `_pageCount`, `_structureIndex` | `AnatomyCanvas`, `StageBar`, `SequenceScrubber`, and the fold page, which comes after the last stage |
| Region selection: a gene feature opened into its DNA | `_selection`, `_selectionHistory` (a `LocalHistoryEntry`, so Back closes it), `_selectionActive`, `_selectionReturning`, `_selectionProgress`, `_geneScrollOffset`, `_detailScrollOffset`, `_liftedBase` | `_prepareSelection`, `_openSelection`, `_returnToGene`, `_clearSelection`, `_selectionChanged`, `_removeSelectionHistory`, `_liftBase`, `_liftedStatus`, `_openRegionAt`, `_liftPending` | `AnatomySelectionCanvas`, `AnatomySelection` |
| Tracer and taps | `_tracer` | `_select`, `_isSame`, `_selectCell`, `_withImpact`, `_withBridge`, `_bridgesOn` | the header's status line |
| Inspector sheet | `_maskedIndex`, `_mask`, `_panelVisible`, `_panelClosing`, `_visibilityScheduled`, `_dismissGeneration`, `_sheet` (a `DraggableScrollableController`), `_sheetHistory`, `_sheetLanded`, `_sheetReveal`, `_sheetSlide`, `_reveal` (a `Timer`), `_panelHeight`, `_canvasViewport` | `_showPanel`, `_dismissPanel`, `_clearPanel`, `_clearMask`, `_sheetSizeChanged`, `_addSheetHistory`, `_removeSheetHistory`, `_panelSubject`, `_inspector`, `_basePanel`, `_keepMaskedResidueVisible` | `InspectorSheet`, `ConstraintPanel`, `ImpactPanel` |
| Track loading | `_tracks` (`TrackSource`, read from context), `_constraint`, `_constraintFailed`, `_constraintLoading`, `_impact`, `_impactLoading`, `_clinvar`, `_clinvarFailed`, `_clinvarGeneration` | `_loadConstraint`, `_loadImpact`, `_startClinVar`, `_loadClinVar`, `_supportsConstraint`, `_supportsImpact`, `_prepareStructure` | every evidence widget, and `StructureView.prepare` |
| ClinVar reading and the overview | `_ClinVarReading` (it indexes `VariantEvidence` by residue and by position), `_evidenceMemo`, `_overviewOpen`, `_overviewMemory`, `_geneRunsMemo` | `_evidence`, `_residueMarks`, `_evidenceAt`, `_clinvarBlock`, `_reported`, `_openVariants`, `_routeThemes`, `_leave` | `ClinVarBlock`, `VariantsOverview`, and the painter's marks |
| Landing: a ClinVar record opens a second walk above the list | The private constructor `AnatomyScreen._landing`, which hands over the parent's `_model` and `_reading`. Also `_arrivalWaiting`. | `_openLanding`, `_arrive`, `_arriveWaiting`, `_pageOf`, `_goToResidue`, `_goToBase`, `_mrnaHolding`, `_revealCell` | `core/router/rise_route`, `walk_route` |
| Page chrome | The private classes `_PageChrome`, `_Header`, `_CountBadge`, `_ContextStrip` and `_OpenDnaAction` | `_openAbout`, `_copyPage`, `_copySelection`, `_copy` | `record_sheet`, `AnatomyFasta`, the clipboard |

### Stays the walk's

| File | Lines | Imports | Why |
|---|---:|---|---|
| `anatomy/anatomy_screen.dart` | 3,037 | See below the table. | The orchestration above. |
| `screens/gene_screen.dart` | 89 | material, `flutter_bloc`; `core/theme/app_spacing`, `app_theme`; `shared/widgets/error_view`, `loading_view`; `entities/gene_record`, `protein_target`; `anatomy/anatomy_screen`, `cubit/gene_lookup_cubit`, `gene_lookup_state` | The walk's route body. Rule 1 forbids `lab/` from importing it. |
| `cubit/gene_lookup_cubit.dart` | 49 | `bloc`; `core/network/api_exception`; `entities/gene_query`, `gene_record`; `usecases/fetch_gene`; `gene_lookup_state` | The walk's fetch lifecycle. Rule 1. |
| `cubit/gene_lookup_state.dart` | 35 | foundation; `entities/gene_query`, `gene_record` | The same. |

`anatomy_screen.dart` has 38 `lib/` imports:

- **Flutter:** material, semantics, services, `flutter_bloc`.
- **`core/`:** `biology/amino_acids`, `network/track_source`,
  `router/rise_route`, `walk_route`, `theme/anatomy_colors`, `app_spacing`,
  `app_typography`.
- **Entities:** `gene_clinvar`, `gene_impact`, `gene_record`,
  `protein_constraint`, `protein_target`, `variant_evidence`.
- **`clinvar/`:** `clinvar_block`, `clinvar_colors`, `evidence_row`,
  `evidence_sections`, `variants_overview`.
- **`constraint/`:** `constraint_panel`, `constraint_toolbar`.
- **The top-level `format`.**
- **`inspector/`:** `coding_evidence`, `impact_panel`, `inspector_sheet`.
- **`structure/`:** `structure_view`.
- **`anatomy/`:** 13 siblings.

## Shared-layer structure

**Recommendation: give the anatomy engine its own folder,
`lib/shared/anatomy/`, beside `lib/shared/widgets/` rather than inside it.**
The general rule for promoted code is to keep the sub-folder it had in the
walk: `presentation/<area>/<file>.dart` becomes
`lib/shared/<area>/<file>.dart`.

After tier 1 moves:

```
lib/shared/
├── widgets/      app_logo, error_view, loading_view   (unchanged)
├── anatomy/      anatomy_motion, sequence_scrubber
├── inspector/    inspector_sheet, level_pips, score_bar
├── structure/    structure_loading_view, structure_rotation
└── constraint/   constraint_colors
```

After route R, `lib/shared/anatomy/` gains the stage model, layout, ruler,
translation, run labels, selection, scene, address, tracer and stage bar.
`evidence_sections` goes to `lib/shared/clinvar/` and `format.dart` to
`lib/shared/format.dart`.

Why the engine goes beside `widgets/`, not inside it:

- **Most of the engine is not widgets.** Of the 12 anatomy files that tier 1
  and route R make movable, two are widgets: `sequence_scrubber` and
  `stage_bar`. The rest is geometry, timing and lookup in plain Dart: the stage
  model, layout, ruler, motion, translation, run labels, scene, address, tracer
  and selection. Session 11 builds its timeline abstraction on motion, and
  filing that under `widgets/` misnames it.
- **It moves as a unit whose files import each other as siblings.** For
  example:
  - `layout` imports `motion`, `ruler` and `stages`;
  - `translation` imports `layout` and `motion`;
  - `scene` imports `layout`, `motion`, `stages` and `translation`.

  If they stay siblings, those import lines are byte-identical after the move.
  Git then reports renames, and the only lines that change are in the
  importers.
- **Mirroring the walk's folders makes every later promotion's destination
  mechanical.** When the painter's turn comes, it goes where its siblings
  already are, and nobody has to decide.
- **The architecture test needs no change.** Rule 2 matches any path under
  `lib/shared/`.
- **`widgets/` keeps its present meaning:** app chrome that knows no biology.

Why not somewhere else:

- **Not `lib/core/`.** Core is config, DI, network, router, theme and the
  biology tables. That is infrastructure, not presentation, and core is not
  feature-free yet. The one exception proposed below is `gene_record.dart`,
  which is data, not presentation.
- **Not a new feature folder such as `lib/features/anatomy/`.** Rule 3 would
  stop `lab/` from importing its `presentation/`, which is the problem this is
  meant to solve.

CLAUDE.md says of `lib/shared/widgets/`: "Promoted widgets go here". That
line has to change in the first session that moves anything.

## The engine: what unlocks it

Tier 1 does not include the engine. There are two routes to it.

**Route R (chosen): move the record down instead of splitting the
engine.**

- **R1.** Move `gene_record.dart` to `lib/core/biology/gene_record.dart`.
  - It is 119 lines and imports only `flutter/foundation`, so core stays
    feature-free.
  - 25 importers change a path: 11 in `lib/`, 14 in `test/`.
  - `gene_record_dto.g.dart` is a `part` file with no imports, so nothing
    needs regenerating.
- **R2.** Split `genomeRank` out of `format.dart`.
  - `grouped`, `spelled`, `spelledLeading` and `formatScore` go to
    `lib/shared/format.dart`.
  - The walk's `format.dart` keeps `genomeRank` and re-exports the shared
    file, so its 12 walk importers and `format_test.dart` don't change.
  - `search_screen.dart` and `protein_card.dart` switch to the shared file.
    That closes both `features` entries in `knownBreaches`, which must come out
    of the list in the same commit, as the test requires.
  - This is the only step that isn't a rename. Its proof is that the bodies of
    the two files concatenate to the original.
- **R3.** Move the stage geometry to `lib/shared/anatomy/`: `anatomy_stages`,
  `anatomy_layout`, `anatomy_ruler`, `anatomy_translation` and
  `anatomy_run_labels`. Each is a `git mv` and nothing else.
- **R4.** Move the model readers: `anatomy_selection`, `anatomy_scene`,
  `anatomy_address`, `anatomy_tracer` and `stage_bar` go to
  `lib/shared/anatomy/`, and `evidence_sections` goes to
  `lib/shared/clinvar/`. Each is a `git mv` and nothing else.

Why R:

- Every step except R2 is a pure rename.
- It never splits the 1,739-line model file.
- It is the only route that makes `anatomy_scene.dart` promotable, and session
  11 already assumes that.

What R changes conceptually: `GeneRecord` stops being a `gene_lookup` domain
entity and becomes core biology. Rule 3's crossing point is unaffected, since
`lab/` could import the record from either place. The only change is that
`shared/` can now name it. **Decided on 2026-09-26: route R.**

**Route S (the alternative): split the engine instead.**

- Split `anatomy_stages.dart` after line 580. The stage model moves to
  `lib/shared/anatomy/`.
- `AnatomyModel` stays in the walk's `anatomy_stages.dart`, which re-exports
  the model so that its 38 importers don't change.
- Then `anatomy_layout`, `anatomy_ruler`, `anatomy_translation` and
  `anatomy_run_labels` move.
- It is smaller than R: about 21 files, 15 of them importers (5 lib, 10 test).
- But it unlocks only the geometry. `scene`, `tracer`, `address` and
  `selection` all name `AnatomyModel`, so they stay blocked.
- Route R is needed anyway on the day a lab flow wants the gene grid drawn
  from a record.
- Git also shows the split of a 1,739-line file as a rewrite, not a rename.

**What stays in tier 2 after route R: 17 files.** They are held by ClinVar,
constraint, impact or target entities, or by the data layer. The cheapest are:
- `clinvar_colors` and `constraint_toolbar`, which name only `ClinVarGroup`;
- `sources_note`, which names only `VariantEvidence.esmStrong`.

Decide them when a lab flow first needs them, not before.

## How many files change if tier 1 moves

In the "Directives rewritten" column, "in moved files" means the moved files'
own imports of `core/theme/`. Those change only in their `../` depth.

| Move | Files moved | Importers that change | Directives rewritten | Risk |
|---|---:|---|---|---|
| Appendix C's tier 1, as listed | 9 | n/a | n/a | Can't be done. The architecture test fails as soon as any of the four files listed above sits under `lib/shared/`. |
| **Tier 1 (slice A)** | **8** | **17** (11 lib, 6 test) | 25 in importers, 4 in moved files | **Low.** Five of the eight moves are byte-identical renames. `sequence_scrubber`, `level_pips` and `score_bar` change only the depth of their `core/theme/` imports. One session. |
| R1: `gene_record` | 1 | 25 (11 lib, 14 test) | one per importer | Low. Many walk tests change, but only in import lines. |
| R2: `format` split | 0, plus 1 new file | 2, plus the known-breaches list | 2 | Low, but it is not a rename. |
| R3: stage geometry | 5 | 35 (13 lib, 22 test) | 59 in importers, 5 in moved files | Medium. It has the largest walk-test churn of any step. |
| R4: model readers | 6 | 22 (7 lib, 15 test) | 34 in importers, 17 in moved files | Medium. |

**Slice A is not large enough to be risky: move it in one session.**

Slicing matters for the engine. The reason is not the file count but that the
steps prove themselves differently:
- R2 is a split; the rest are renames.
- R3 changes 22 walk tests, which is more than one review should carry
  alongside anything else.

Session 07 runs R1–R4 as its steps 2–5, in that order, after tier 1. Each step
commits on its own with the zero-diff proof. Running them before the rework
keeps `anatomy_layout.dart` out of the "both in flight" case.

Two things not to do:

- **Don't leave re-export shims at the old paths when whole files move.** With
  the old path still present, `git diff -M` can't pair the files as a rename.
  Route R uses a re-export only in R2, where the old file keeps real content.
- **Don't move tests in slice A.** The tests of promoted files stay where they
  are and change only their import lines. Moving a walk test to
  `test/shared/` is not an import-line change, so under CLAUDE.md's rule it
  needs its own approval.

## Noticed, not changed

- **Raw colours.** `constraint_colors.dart` defines its ramp as raw hex
  (`Color(0xFF6F8594)` and two more), and `inspector_sheet.dart` uses
  `Colors.black54`. CLAUDE.md says colours come from the theme. Move them as
  they are; the fix is its own session.
- **The routes.** `walk_route.dart`, `rise_route.dart` and
  `landscape_route.dart` are under `lib/core/router/`, not `presentation/`,
  and import only Flutter and `go_router`.
  - Appendix C lists them as the walk's, but nothing in the import graph ties
    them to it.
  - `variants_overview` already uses `landscape_route`.
  - They can stay the walk's by policy, but they need no promotion to be
    reused.
- **The rework conflict.** `anatomy_layout.dart` is the file the design
  document names as the rework-conflict risk, and it can't move in slice A.
  See point 6 under "Where this disagrees with Appendix C".
