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

- `lib/core/`: biology tables, `.env` config, DI, network, router, theme. It is
  not feature-free yet: `di/`, `router/` and `network/` import `gene_lookup`.
- `lib/shared/widgets/`: the shared layer (`AppLogo`, `ErrorView`,
  `LoadingView`). Promoted widgets go here.
- `lib/features/gene_lookup/`: **the walk**. It has `data/`, `domain/` and
  `presentation/` (`anatomy/`, `clinvar/`, `constraint/`, `inspector/`,
  `structure/`, `cubit/`, `screens/`).
- `lib/features/lab/`: new flows (not created yet). `home/` and `search/`
  hold the home screen and the catalog list.

Domain code must not import `package:flutter/material.dart`; `@immutable`
comes from `flutter/foundation.dart`. There is one existing violation:
`domain/entities/protein_target.dart` imports material so that `ChainTint` can
name a colour. Don't copy it. Colours come from the theme (`AppColorTokens`,
`context.nucleotideColors`, `context.anatomyColors`), never from a raw hex.
The walk is drawn in `AppTheme.analysis`; home uses `AppTheme.dark`.

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
- `SHOT_DIR=<dir> flutter test test/screen_render_check.dart` writes PNGs (the
  catalog walk, ClinVar, constraint and impact tests do too). Also:
  `TRANSLATION_SHOT_DIR`, `SELECTION_SHOT_DIR`, `HELIX_OUT`, `HELIX_MOTION=1`.

**Render baseline: not built yet.** Nothing calls `matchesGoldenFile`; the
`SHOT_DIR` writers save PNGs and compare nothing. Until goldens are committed,
the zero-diff proof can't be run and no session can claim it. When they land,
put their command and the environment they must be generated in here.
