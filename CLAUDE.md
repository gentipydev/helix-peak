# Helix Peek — app

Helix Peek is a Flutter app that walks one protein from its gene to its fold:
a grid of squares morphs through gene, mRNA, protein and mature chains, then
ends on the 3D structure. Each of the twenty curated proteins is drawn from a
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
user's approval. Adding a test is always allowed. Before committing,
`git diff -M -U0 --diff-filter=MRD <start> -- test/features/gene_lookup test/core test/support test/goldens | grep -E '^[+-]' | grep -vE '^(\+\+\+|---) |^[+-]import '`
must print nothing, and `git diff --quiet <start> -- test/fixtures` and
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
theme, and home wears `AppTheme.home`, the same ground with the helix's bases
at full strength. `AppTheme.dark`, the cool ground the app began on, is worn by
no screen; the walk's tests still set the walk inside it. Small print is
`theme.caption` (`core/theme/app_typography.dart`), never a bare `bodySmall`,
which is Material's in the bright ink.

## Replication (`lib/features/replication/`)

A story of its own subject at `/replication`, the home screen's DNA
Replication row, in every build: no record and no track. It began in the lab
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

## Zoom (`lib/features/zoom/`)

From a body down to one protein's DNA, at `/zoom/<slug>`, in every build. It
began in the lab and left it for the walk: links from then (`/lab/zoom/<slug>`,
and `/lab/zoom`, its picker) redirect, the second to the protein list.
`zoom_routes.dart` wraps it in `AppTheme.analysis`, which the lab's shell used
to give it, and it reads through the app's own `TrackSource`, the walk's: a
`locus` payload is a few kilobytes, and its record is the one the walk holds.

It is reached from the walk's gene page, which offers "Zoom ›" on its strip
for a protein whose `locus` track is `ready`: the twenty curated ones today,
by their rows and by no list, so a protein built on demand gets it the day it
gets a locus. The walk opens it by route (`RoutePaths.zoomFor(target,
overWalk: true)`, `?over=walk`), never by import. At the DNA, "Walk ›" unzips
the helix and goes back to the gene page it left; opened any other way, with
no walk under it, it opens the walk at `/gene/<slug>`. `ZoomRoute` resolves
its slug with a loader of its own: a shared loader would have to read
`ProteinCatalogRepository` from core or shared, which the layering test
forbids.

The dive is eight stops on one depth (`ZoomDepth`): body, organ, tissue,
cell, nucleus, chromosome, band, DNA. The card's ‹ › step from one to
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
- the organ as the same outline, grown to its real size and sculpted, the
  figure's parts faint round it, and inside it the gene's place;
- the tissue as a section under an eyepiece (`TissueSlide`: one engine, a
  recipe a tissue architecture, the zoom's cell laid where it lives);
- the cell, the protein glowing where the Atlas finds it, and the nucleus
  with its chromosome territories; the nucleolus, lobed, is one shape at
  both (`scenes/nucleolus.dart`), and the one landmark the canvas names,
  its line in the quiet ink and its plate off the nucleus;
- a metaphase chromosome drawn as a scanning micrograph shows one
  (`presentation/scenes/chromosome/`): two knobbly sisters, its G-bands
  soft changes of tone, the gene two FISH spots in the accent. It condenses
  out of its territory, and on the way out turns into a smooth tube that
  is, by the time it lies along the genome, the band map's strip pixel for
  pixel;
- a genome map of the band opened out of the whole chromosome, and the
  gene's own DNA, its stop (the gene and the DNA are one, the user's choice
  of 2026-10-14): on the way in, the gene's mark on the band's strip opens
  into the record's exons at their real lengths, then into chromatin, then
  into the home screen's own double helix (`DnaHelixPainter`, from
  `lib/shared/helix/`), lying 5′ to 3′ with the record's first bases, whole:
  unlike the home screen's, nothing transcribes it (`transcription: null`),
  so no strand peels away. The zoom goes into the mark at its left end,
  where the 5′ end is drawn whatever the strand, so nothing turns.

The organ and the cell are one path the bake chose, a cell that lives in
the organ (`path` in the `locus` track's schema 2, `pipeline/locus` in the
backend). Where that cell has no nucleus (red cells, platelets), the zoom
lands in the precursor that has one. The band is marked and named, never
the gene. The card says the place and one line of data, nothing that
explains: there is no About sheet, no source tag and no player. Its
colours are the app's own (`ZoomInks`): one ground at every stop, the
accent for the gene and what it makes (the organs its RNA is raised in, its
cell, its protein, its chromosome, its band) and nothing else, and every
other form sculpted in the warm neutrals; `zoom_inks_test` holds that no
colour in the zoom is written out as a number. `docs/design/zoom.md` has
the design and its checks.

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
  page's `sentence` and `semantics` are the only exception (see R4.5), and
  only for the twenty: a protein built on demand has its two templated by the
  backend from its model's own numbers.
- **Every claim traceable to the record.** Numbers come from data, never from
  a literal: no hard-coded lengths and no count of the catalog (R4.1).
  Captions agree with their own numbers via `grouped`, `spelled` and
  `spelledLeading` (R4.2). Formats follow R4.4.
- ClinVar (§9): clinical words appear only inside `ClinVarSourced`, hue belongs
  to ClinVar alone, and absence is never called benign.

## The compressed-intron genes: DMD, APP, CFTR

These three genes exceed the gene page's 24,000-base budget, so their introns
arrive shortened and their exons whole (R2.4). `GeneRecord.isIntronCompressed`
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
- `SHOT_DIR=<dir> flutter test test/goldens` writes PNGs (the catalog walk,
  ClinVar, constraint and impact tests do too). Also:
  `TRANSLATION_SHOT_DIR`, `SELECTION_SHOT_DIR`, `HELIX_OUT`, `HELIX_MOTION=1`.

**Render baseline: `tool/goldens/goldens.sh`** (Git Bash, with Docker running).
It runs `flutter test` in the one environment the goldens are made and checked
in: `tool/goldens/Dockerfile`, Ubuntu 24.04 pinned by digest, Flutter 3.47.5,
x86-64. The zero-diff proof is `tool/goldens/goldens.sh test/goldens`; the
whole suite, as CI runs it, is `tool/goldens/goldens.sh`. A native
`flutter test` skips the 32 golden tests with that reason, because text is
rasterised by the host and a native Windows run differs at every glyph edge.
A failed golden leaves its diff in `test/goldens/failures/`. Regenerating is
session 99's job alone: `docs/goldens.md` has the environment, the commands
and the rules.

Natively on Windows, `protein_catalog_test.dart`'s "every track is fetched,
and none of them ships" fails before any session touches it: it compares
`File.path` against `/`-separated literals, and Windows lists
`assets\animations\process.json`. It passes in the container.
