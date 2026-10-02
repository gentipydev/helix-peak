# Helix Peek — app

Helix Peek is a Flutter app that walks one protein from its gene to its fold:
a grid of squares morphs through gene, mRNA, protein and mature chains, then
ends on the 3D structure. Each of the twenty curated proteins is drawn from a
stored GenBank record plus its evidence tracks (ESM-2 constraint, AlphaGenome
variant impact, ClinVar, fold). All of it is served by `../helix-peak-backend`;
the app ships no protein data.

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
  replication flow. The home screen's widget and painter stay in home.
- `lib/features/gene_lookup/`: **the walk**. It has `data/`, `domain/` and
  `presentation/` (`anatomy/`, `clinvar/`, `constraint/`, `inspector/`,
  `structure/`, `cubit/`, `screens/`).
- `lib/features/lab/`: new flows, built only with the lab flag on (see "The
  lab" below). `home/` and `search/` hold the home screen and the search:
  the curated list, and below it every reviewed human protein, which can be
  built on demand (its own cubits, `ProteinSuggestionsCubit` and
  `ProteinBuildCubit`). Search is not the walk; it reaches the walk only by
  opening `/gene/<slug>`.

`test/architecture_test.dart` holds that layering to the import lines: `lab/`
never imports the walk's screens or cubit, `core/` and `shared/` import no
feature, and no feature imports another's `presentation/` (domain entities are
the crossing point). The imports that already broke it are listed in its
`knownBreaches`. The list may only shrink: close an entry by moving code,
never by adding one.

Domain code must not import `package:flutter/material.dart`; `@immutable`
comes from `flutter/foundation.dart`. There is one existing violation:
`lib/core/catalog/protein_target.dart` imports material so that `ChainTint` can
name a colour. Don't copy it. Colours come from the theme (`AppColorTokens`,
`context.nucleotideColors`, `context.anatomyColors`), never from a raw hex.
The walk is drawn in `AppTheme.analysis`; home uses `AppTheme.dark`.

## The lab (`LAB_ENABLED`)

Everything under `lib/features/lab/` sits behind one build-time switch:
`LAB_ENABLED=true` in `.env`, read as `Env.labEnabled`. The file is bundled
when the app is built, so a build without the line ships none of the lab: no
`/lab` route and no Lab row on the home screen. Off is the default, and
`.env.example` says so. A lab flow merges early behind the flag instead of
rotting on a branch, which is what keeps the shared layer from diverging.

- `lib/app.dart` hands `labRoutes` to `buildAppRouter(extra: ...)`, so core
  names no lab file. With the flag off the app uses `appRouter` itself.
- One `ShellRoute` holds every lab route under `LabScope`
  (`lab_scope.dart`), which gives the lab its own `TrackClient` (folder
  `lab/tracks`, 100 MB budget) so exploring can never evict a walk track.
  Below it, `TrackSource` and `FetchGene` read through that client, and the
  lab wears `AppTheme.analysis`. The walk's routes are not below it.
- The index at `/lab` lists `labFeatures` in `lab_routes.dart`, one entry per
  flow as it arrives.
- `share/` draws a flow's frames offscreen, one at a time (`FrameRenderer`),
  and makes a poster (`PosterBuilder`) whose link,
  `helixpeek://open/gene/<slug>`, is the scheme `AndroidManifest.xml` and
  `Info.plist` register. Flutter hands the path to the router.
- Clips (`VideoEncoder`) are Android only: MediaCodec and MediaMuxer in
  `android/.../VideoEncoderChannel.kt`, on channel
  `helixpeak/share/video_encoder`, one frame per call. iOS shares posters
  only until the AVAssetWriter half is written and run on a Mac
  (`docs/video-encoding-spike.md`). An export keeps the screen on and is
  cancelled, its file deleted, if the app is paused.
- `ar/` embeds `StructureView` and, on Android, opens Scene Viewer on the
  `structure_ar` track's `.glb`: the fold at 1 Å to 1 cm, its size read from
  the row's provenance (`pipeline/structure_ar` in the backend). iOS says
  room view is Android only until its AR Quick Look half is built on a Mac.
- `trafficking/` derives a protein's route through the cell
  (`TraffickingRoute`) from its constraint track's region table and, where
  the `trafficking` track is ready, UniProt's transmembrane spans
  (`pipeline/trafficking` in the backend). Without them the route stops at
  unknown and the screen says why. One `CustomPainter` cell draws every
  protein on the shared transport bar, with captions built from the regions
  and events. No Rive asset exists, so there is no Rive dependency. The route
  is inferred and the screen says so. Nothing names a tissue, and nothing
  reaches the nucleus yet.
- `folding/` plays a chain folding in four staged steps (hydrophobic
  collapse, helices coil, strands pair, bridges snap shut) from the `folding`
  track: each chain's CA trace and secondary structure, residue by residue,
  in the stored structure model's frame (`pipeline/folding` in the backend).
  It paints, through the fold page's own camera (`structureCamera` on the
  model's bounds, which the track carries), so its last frame lands on the
  fold that page draws; `docs/folding-renderer.md` says why it paints though
  flutter_scene can build meshes at runtime. Every step says it is an
  illustration, not a simulation. Residues the track calls disordered hang
  loose and never settle; absent ones are not drawn. The bridges are the
  catalog's pairs, read from the constraint track, in the `bonds` colour.
- `oxygen/` is a story of its own subject, `/lab/oxygen`: the hemoglobin
  tetramer, an assembly the backend keeps outside the catalog
  (`/assembly/{slug}/tracks`, `pipeline/assemblies`), tense and relaxed in
  one frame. The MWC model (`domain/mwc.dart`, tested before any widget:
  sigmoid for four sites, a hyperbola for one) drives it: each oxygen binds,
  and the molecule settles to the R share MWC gives that many bound. The
  curve draws itself with its point marked; a Hill curve is only a fitted,
  labelled reference. pH (through L, the Bohr effect), fetal hemoglobin (a
  lower L) and the one-site contrast (myoglobin's own structure track) each
  change the model, curve and animation together.
- `replication/` copies a protein's record from a bubble at its middle
  (`ReplicationPlan`): each fork's leading strand in one piece from a primer
  at the origin, and its lagging strand backwards in Okazaki fragments of 100
  to 200 bases, each from a ten-base primer, extended until it meets the piece
  before, replaces its primer and is sealed. Lengths are drawn from a
  generator seeded with the record's letters; records whose introns arrive
  shortened are refused. It plays in three views: the fork base by base on the
  record's own helix, unzipped by the shared geometry (`lib/shared/helix/`,
  `HelixModel.unzip` and `bases`); the fork at the scale of fragments, where
  the lagging template's loop, the trombone, fits whole; and the record as one
  bar. A proofreading set piece (a wobble transition on the leading strand)
  plays out as the fidelity toggle says: polymerase alone, plus proofreading,
  plus mismatch repair, at the orders of magnitude given for each.
  `ErrorTally` draws a thousand copies' errors at the polymerase's rate; each
  level's survivors are among the level before's, and each opens on the
  mutate screen as a `Substitution` (`MutateCubit.applying`).
- `zoom/` pinches from a body down to one protein's gene. Body, organ,
  tissue, cell, nucleus, chromosome and gene sit on one value whose
  logarithm is the view's width (`ZoomScale`), with a snap point and a chip
  for each and a scale bar from metres to nanometres. Each level is a layer
  drawn in metres, crossfaded into the next as the view zooms about the
  place the next one lies. The chromosome is the `locus` track's
  (`pipeline/locus` in the backend): its cytoBand bands, with the gene's band
  marked and named, never the gene, and a caption that says the gene is too
  small to see there. The organ and the cell are the Human Protein Atlas's
  reading, carried in the same track. Where the Atlas's cell type has no
  nucleus (`anucleateCellTypes`: red cells, platelets), the zoom lands in the
  precursor that has one and the caption says so. Every other level is
  illustration. At the gene, the record's first bases on the shared helix,
  and a button that opens the walk at `/gene/<slug>`.
- `listen/` plays a protein as sound over the walk's own grid. The protein is
  the `audio` track (`pipeline/audio` in the backend): an `.m4a`, one note a
  residue (pitch hydropathy, timbre the fold's secondary structure, loudness
  conservation, a tick at a residue with a ClinVar record), whose timing map
  rides in a `uuid` box after the audio (`AudioTrack.mapOf`); the file's edit
  list skips the AAC priming, so position zero is the first note. DNA mode is
  made on the phone from the record (`DnaScore`, `DnaVoice`): a three-note
  chord a codon (A plays A, C C, G G, T E; first base lowest) and a 5 ms
  grain an intron base, from start codon to stop, over the gene page; spliced,
  the codons alone over the transcript page, reached by the walk's own
  splicing. The playhead is the walk's tracer ring (`LabAnatomyView.tracer`),
  moved only by the position the player reports (`ListenPlayer.positions`,
  `noteAt`): nothing in Listen keeps time. Playback is just_audio behind
  `ListenPlayer`; tests use a fake that reports positions by hand. The mapping
  is announced (`SemanticsService.sendAnnouncement`), the piece is described
  in words, a paused note is a live region, and the about sheet
  (`ListenAbout`, on `SourcesNote`) says the mapping is arbitrary, channel by
  channel. Without a ready `audio` row the protein is off and the gene plays.
- `challenges/` is the daily puzzle at `/lab/challenges`, whose subject is
  the day. `PuzzleGenerator` makes four rounds on the phone from the date and
  the catalog, never the backend: each round draws from its own `SeededDraw`
  (seeded with the day and the round's name, the catalog sorted by slug), so
  every phone makes the same puzzle, and one day's is pinned in a test. Whose
  fold is this (the shared `StructureView`); which residue differs (two
  stretches in the walk's residue colours, the change a held ClinVar missense
  record quoted inside `ClinVarSourced`, or one made for the puzzle and said
  to be); put a walk in order; eight codons against a 45 s clock, twice that
  with a screen reader on. A round picks its protein by the date first and
  only then asks what the lab's cache holds of it (`TrackClient.held`, which
  reads the cache alone); where the fold or the sequence is not held, the same
  protein is asked about from its catalog row (`IdentifyRound`). No text says
  a variant causes anything. Days and streaks stay on the phone
  (`lab/challenges/days.json`), a day is played once, and the share card is
  a square a round and a square a codon with `helixpeek://open/lab/challenges`,
  drawn the poster's way and shared through `systemShareSheet`.
- Tests switch it on with `dotenv.loadFromString(envString: 'LAB_ENABLED=true')`
  and off with `dotenv.clean()`.

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
   resolver on Modal writes its row (`catalog_order` null, so never in
   `/catalog`) and its record, then scores ESM-2 650M, the twenty's model.
   Search watches the constraint track with `ProteinResolver.trackState`, read
   fresh each time, and opens the walk only once it is no longer `pending`:
   `TrackClient` and `ProteinCatalogRepository` each remember a protein once
   read, so a protein opened mid-bake stays unscored until a restart. Tests use
   `test/features/search/support/resolver_api.dart`.

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
fails to fetch is a real failure. Keep the two cases apart.

## House rules (`docs/protein-pipeline-rules.md`: read it first)

- **No per-protein code.** Nothing branches on a slug, gene or accession.
- **No per-protein prose.** Captions are built from the record. The structure
  page's `sentence` and `semantics` are the only exception (see R4.5).
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
