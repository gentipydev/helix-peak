# Helix Peek

Molecular biology and DNA sequence analysis, built with Flutter.

The app reads stored gene records baked from NCBI GenBank by the
[backend pipeline](../helix-peek-backend/pipeline/README.md), and draws a grid
of squares that morphs through the
stages of expression — for insulin, 1,431 → 465 → 110 → 82 cells — and then as
the fold those cells end up in.

The curated list contains twenty proteins: insulin, oxytocin, ubiquitin, lysozyme, haemoglobin,
myoglobin, relaxin, growth hormone, p53 and dystrophin, and the ten added after
them — vasopressin, glucagon, amyloid precursor protein, CFTR, erythropoietin,
leptin, TNF-alpha, SOD1, amylase and prion protein. Each has five stored tracks: a gene record, an ESM-2 constraint track, an AlphaGenome Variant Impact
(AVI) track, a ClinVar snapshot and a 3D model. The walk remains available offline once its tracks have been fetched;
[`helix-peek-backend/pipeline/`](../helix-peek-backend/pipeline/README.md) is what bakes them, and
[docs/protein-verification.md](docs/protein-verification.md) is what the second
ten were checked against before they were added.

The search screen filters the cached list locally. Searching beyond that list
is planned in the on-demand pipeline handoff.

## Running

Copy `.env.example` to `.env`, then run `flutter run`. `API_BASE_URL` selects
our deployed backend or a local service. Release builds use the same path.

The app ships no protein data. Its catalog comes from `/catalog`; records,
ESM-2, AVI, ClinVar, folds and contribution details come from Supabase Storage.
Catalog rows and fetched tracks are cached on device, so proteins already
walked remain available offline after a restart. A first launch needs a
connection. Mock mode has been retired; test data lives in `test/fixtures/`.

The conventions every protein has to follow for the walk to draw and describe
it like the others — and what a search over any protein still needs — are in
[docs/protein-pipeline-rules.md](docs/protein-pipeline-rules.md).

### Genes too large to draw

The gene page is one screen, and `AnatomyLayout.fit` gives a cell a two-point
floor, so past about 24,000 bases there is no picture left. Seventeen of the
twenty records are drawn at full length. Dystrophin (2.1 Mb, 79 exons), APP
(290 kb, 18 exons) and CFTR (189 kb, 27 exons) arrive with their introns
shortened and their exons whole, so the transcript and protein pages are the
real molecule and only the gene page's proportions are scaled. That page says
so: "Introns are 99.3% of the gene, drawn shortened; exons are to scale".

## Mask & Reveal

On the protein page, tap a residue to mask it and reveal
the saved ESM-2 scores. The context dims for 300 ms before the panel rises.
Tap another residue to compare in place; the grid remains scrollable above
the panel. Drag the sheet between medium and expanded heights, then scroll
its content to read all scores. The handle and close button remain accessible.
Pull down, use Close/Back/Escape, or tap the masked residue or empty grid to
restore the resting view. Comparisons preserve the sheet height and expanded
ranking preference. [The UI/UX rationale](docs/residue-sheet-ux.md) explains
the gesture handoff, dismissal behavior, and adaptations for larger text.
The conservation switch changes the tile fills and keeps the letters visible.
The information button explains masking and the score scale on demand.

All 20 canonical amino acids are ranked, including the native residue at zero.
Six appear initially, with the rest expandable; a change ClinVar has a record
for is always shown, marked with its class, however low it ranks. Every bar uses the same
−10-to-0 scale; values beyond either endpoint are clamped visually and retain
their signed numerical scores. Badges use inverse min-max entropy: high ≥0.8,
moderate ≥0.4, otherwise tolerant. Reduced motion skips the mask delay and slide.

The constraint asset is bundled and matched against the stage's own letters
before any of it is drawn, so a track can only ever colour the protein it
describes. There are no inference requests or model dependencies at runtime.
Each track carries its own region table — insulin's signal peptide, B chain,
C-peptide and A chain; dystrophin's twenty-four spectrin repeats — which is
what names a residue's domain and its bonding partner without the code knowing
which protein it is looking at.

Generation and independent CPU verification are documented in
[pipeline/constraint](../helix-peek-backend/pipeline/constraint/README.md). Insulin's six disulfide cysteines
rank 1–6 of 110. The measured C-peptide is less constrained than the signal
peptide; [verification.md](../helix-peek-backend/pipeline/constraint/verification.md) records that
difference from the originally proposed regional pattern, and what the other
nineteen proteins measured. No values are adjusted in the UI. A protein added to
the catalog before its track is baked is marked unscored; its protein page is
drawn without the conservation toolbar, and a tap there follows the tracer as it
does on every other page.

## Evidence: ESM-2, AVI and ClinVar

Insulin, hemoglobin beta and CFTR also include **AVI contribution details**.
Tap a substitution row in the base sheet, or expand a ClinVar record, to see
what contributes most to that exact change's score. “Show contributions” opens
the three largest signed values, their scope and date, and an Atlas source link.
The explanations work offline; only opening the external source needs a browser.
Other genes retain their existing AVI bars. [Data contract and baking](docs/avi-contributions.md).

Contribution details load on demand through the same stored-track client,
reject mismatched sequences/maps/scores, and offer retry without blocking the walk.

Each source has one job and one visual channel. ESM-2 is the protein's fit — the
residue sheet's bars and, in ESM mode, the grid's fill. AVI is each base's
predicted molecular impact — the base sheet's bars on the mRNA page and in an
opened region. ClinVar is what has been reported, and owns colour: a class dot
on a reported change's bar, on the grid in ESM mode, and on every record's row.

A sheet speaks only for its position: one ClinVar line, then one row per record
carrying the model its bars do not show. Opening a row is the one place both
numbers meet, with a single molecular line on where each model puts the change;
its links go to the record's residue or base. The ClinVar key in ESM mode (and
the About sheet) opens every record at once: a strip along the protein — each
record's own AVI as height, standing on ESM constraint, coloured by class — over
a drawing of the gene for records off the protein, then one list grouped by
region. The class chips choose which classes are drawn, one or several; the −
and + keys, a pinch or a tap on a region's name zoom a panel, and the list then
holds what the panels show. A tapped mark is named under the strip. A panel's
full-screen key opens it alone on the whole screen, turned to landscape on a
phone (the rest of the app stays upright there); × or Back returns to the list
with the window and mark chosen there. A record's
"Residue ›" or "Base ›" opens that residue or base as a page above the list:
Back returns to the list as it was, and closing the list returns to the walk as
it was before. Coverage, scales and caveats are written once, in "About these
sources". The rules are in [docs/protein-pipeline-rules.md](docs/protein-pipeline-rules.md) §9.

## Logo and app icons

The [branding kit](design/branding/README.md) contains the transparent master,
32–1024 px exports, Flutter density variants and platform launcher icons.
Use `AppLogo` for in-app branding. Regenerate everything with
`dart run tool/branding/generate.dart`, then rebuild/reinstall to update the
installed launcher icon.

## Tests

```bash
flutter analyze
flutter test
(cd ../helix-peek-backend && python3 pipeline/fetch_tracks.py && python3 pipeline/check_assets.py)
                                 # the stored tracks against each other
```

`test/features/gene_lookup/catalog/` derives the whole walk for every protein
from the test fixture records: every stage, every cell's run, and the one invariant
the feature rests on — that a scored protein's constraint track sequence is the
protein page's letters. Those two are baked by different tools, hours apart.
`check_assets.py` also re-proves every record from its own bytes: the CDS
translates to the protein, every peptide translates at its own offset (which is
what keeps a neighbouring gene's features out), and every intron is spliceable.

The opt-in live checks fetch every track through the production client:

```bash
# needs the backend running
LIVE_BACKEND=http://localhost:8000 flutter test test/live_backend_check.dart

# write PNGs of the rendered screens
SHOT_DIR=/tmp/shots flutter test test/screen_render_check.dart
```
