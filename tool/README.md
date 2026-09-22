# Baking the proteins

Everything under `tool/` is offline. It runs by hand, its output is committed,
and the app never touches any of it at runtime.

One table drives all of it: [`targets.py`](targets.py), twenty rows, one per
protein. A row says where the gene comes from, which regions and disulfides
the precursor has, which chains of which PDB entry the fold is cut from, and
whether the protein is scored. Each row produces five assets:

| asset | baker | what it is |
|---|---|---|
| `assets/mock/gene_<gene>.json` | [`mock/build_gene_record.py`](mock/build_gene_record.py) | exactly what `GET /gene/{id}/{gene}` answers |
| `assets/constraint/<slug>_esm_constraint.json` | [`constraint/score_protein.py`](constraint/score_protein.py) | ESM-2 masked marginals, per residue |
| `assets/impact/<slug>_avi.json` | [`impact/bake_impact.py`](impact/bake_impact.py) | AlphaGenome Variant Impact, per base |
| `assets/clinvar/<slug>_clinvar.json` | [`clinvar/bake_clinvar.py`](clinvar/bake_clinvar.py) | ClinVar observed single-base variants, mapped onto the drawn gene |
| `assets/models/<slug>.glb` | [`structure/bake.py`](structure/bake.py) | the fold, as named meshes |

The Dart side holds its own copy of the parts it needs, in
`lib/features/gene_lookup/domain/entities/protein_catalog.dart`: the screen's
own prose belongs with the screen, not in a Python file. Nothing keeps the two
in step by construction, so [`check_assets.py`](check_assets.py) checks them
against each other and against the bytes on disk.

## In order

The constraint scorer reads the protein out of the gene record rather than
taking it as an argument, and the impact baker reads the record's own exons and
letters, so both come after it. The ClinVar baker places records through the
impact track's coordinate map, so it comes after that. Structures are
independent.

```sh
NCBI_EMAIL=you@example.com \
  ../helix-peak-backend/.venv/bin/python tool/mock/build_gene_record.py --all
tool/.esm-venv/bin/python -u tool/constraint/score_protein.py --all   # scored rows only
ALPHAGENOME_API_KEY=... \
  tool/impact/venv/bin/python -u tool/impact/bake_impact.py --all
NCBI_EMAIL=you@example.com \
  ../helix-peak-backend/.venv/bin/python -u tool/clinvar/bake_clinvar.py --all
tool/structure/venv/bin/python tool/structure/bake.py --all
python3 tool/check_assets.py
```

`--all` re-fetches every record from NCBI as it is today. To add or change one
protein, pass `--target <slug>` instead, and the rest stay byte for byte.

Each directory's own README has the detail, the environments they need, and
what a correct result looks like. Rough costs on an M-series laptop: records
under a minute, structures about a minute, scores about eighty-five minutes for
all twenty — of which dystrophin is forty-five and CFTR twenty-one. The impact
tracks are fifteen to thirty minutes, set by the Atlas's per-minute quota rather
than by the machine. ClinVar is about seventeen minutes for all twenty, most of
it dystrophin's 12,000 records and CFTR's 6,500.

## Adding a protein

Read [the pipeline rules](../docs/protein-pipeline-rules.md) first: they are
what the first ten had to be corrected to agree on. Then check the gene against
its record before writing anything —
[protein-verification.md](../docs/protein-verification.md) is how the second
ten were checked: span, exons, neighbouring genes, what the record says is cut,
and which structure is honest to draw. Then add a row to `targets.py` and a row
to `protein_catalog.dart`, run the bakers for `--target <slug>`, build the app
once, then `flutter test` and `check_assets.py` — the tests in
`test/features/gene_lookup/catalog/` derive the whole walk for every catalog
entry and will say which of the assets is wrong. A protein with no track yet
sets `scored=False` on both rows, and one with no ClinVar snapshot yet
`clinvar_available=False` / `clinvarAvailable: false`.

Two things to check before committing to a protein:

- **The gene has to fit one screen.** `AnatomyLayout.fit` sizes the gene page
  to a single screen with a two-point floor on a cell, so past about 24,000
  bases there is no picture left. `build_gene_record.py` shortens introns past
  that and records the scale, but a gene whose *exons* alone exceed the budget
  has no honest page and the script says so rather than guessing.
- **The structure has to exist.** Nine of the first ten are experimental. Where
  the full length has never been solved in one piece — p53's disordered
  stretches, the other 3,447 residues of dystrophin, all but APP's E1 domain —
  the row names the span that has, and the catalog's sentence for that page says
  what is missing.

ClinVar snapshots follow the record and the verified GRCh38 mapping. See
[`clinvar/README.md`](clinvar/README.md) for what each of the twenty holds,
coverage exclusions, source provenance and the limits of model comparisons.
Availability is declared separately as `clinvar_available` /
`clinvarAvailable`; it is never a score.
