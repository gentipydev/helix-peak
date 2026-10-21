**AVI contributions**

A base sheet whose substitutions are explained ends its rows with one line,
“Contributions ›”. It opens a page of its own, rising over the walk as the
ClinVar list does, with every substitution at that base side by side and what
the AVI model's raw score is made of. × closes it back onto the sheet. Since
2026-10-21 no substitution row opens in place.

Insulin alone carries contributions: it is the showcase the flow is built on,
before it is adapted protein by protein (the user's decision of 2026-10-21).
Hemoglobin's and CFTR's top-three payloads were deleted then: their track
rows are `absent` and their objects gone. An expanded ClinVar record still
shows its own allele's three largest contributions, derived from the full set.

**The page**

```
×   c.73 · Contributions

               C Leu   A Ile   G Val
 Phred          25.1    22.1    20.9
 Coding       +0.706  +0.296  +0.235 ›
 Conservation +0.391  +0.342  +0.344 ›
 Splicing     +0.064  +0.082  +0.058 ›
 Expression & +0.031  +0.039  +0.041 ›
 chromatin
 ──────────────────────────────────
 Sum          +1.192  +0.759  +0.678
```

- Columns are the sheet's rows in the sheet's order (by Phred), each headed by
  its base and what it makes of the codon (`Leu`, `=`, `Ter`, `?`).
- Rows are four groups, each the sum of its features. A group opens onto its
  features; an assay opens onto the track behind it, one line per column
  (`WTC11 · INS`, `junction · body of pancreas · INS-IGF2`). Splicing is one
  feature, so it opens straight onto its tracks.
- Values are signed to three places, in neutral ink (R9.1); an exact zero is
  `0`. Type turned up past what a phone holds scrolls the table sideways
  rather than squeezing a number; the names wrap between words, never inside.
- Under the table: what these values are, said once, the snapshot's date, and
  one Atlas link per column (the genomic allele: insulin's T>C is `A>G`).

| Group | Features (as the Atlas names its assays) |
|---|---|
| Coding | AlphaMissense, Termination, Start lost, Stop lost |
| Conservation | PhastCons 470, Cactus 241 |
| Splicing | Splicing (sites, site usage, junctions/5) |
| Expression & chromatin | RNA-seq, CAGE, PRO-cap, Polyadenylation, DNase-seq, ATAC-seq, ChIP-TF, ChIP-histone, 3D contacts |

The insertion and deletion flags belong to no group: a substitution's are
zero, which the bake refuses to let pass otherwise.

**What the values are**

`AVI_SCORE_FEATURE_IMPORTANCE`: one signed attribution per feature to the AVI
model's raw score (`AVI_SCORE`'s `X`), across Atlas genes and biosamples. They
are not percentages and not parts of the Phred, and a sign is not a direction
of gene activity. Their sum ranks insulin's 4,293 substitutions as the Phred
does (Spearman 0.9998), but raw − sum is not one constant: median −0.049, from
−0.069 to −0.028. So no baseline is stated (`baseline: null`) and the page
does not claim a column adds up to its raw score; the offsets are recorded in
the payload (`raw_minus_sum`).

A track under an assay is the one with the largest absolute predicted effect
for that substitution, over every gene and track of the assay's scorer, as
the Atlas's AVI skill reconstructs it (`_find_adata_max`); for splicing, the
largest of splice sites, site usage and junctions at a fifth. The model
reports the assay's attribution, not which track drove it, and the page says
so.

**Persistence**

| Tier | What | Where | Insulin |
|---|---|---|---|
| Atlas window replies | raw score + 18 attributions per substitution | `pipeline/impact/attribution_raw/<impact sha256>/<low>-<high>.json`, ignored by git, resumable | 1.35 MB |
| Atlas track replies | genes × tracks for twelve scorers, one call per substitution | never stored: reduced on arrival to each assay's winner, checkpointed one line per substitution in `track_winners.jsonl` | ~130 KB each raw; 4.8 MB reduced |
| The track | schema 2 below | Storage `tracks/impact_explanations/insulin.<sha12>.json`, immutable, gzipped by the CDN | 1.41 MB, 409 KB on the wire |
| The phone | the track, by sha256 | `TrackClient`'s cache | offline after the first open |

A 24,000-base gene would be about 1.4 MB on the wire before winners. When one
is adapted, the same per-base records split into blocks of about 1,000 bases
on the CDN, fetched by the block holding the tapped base. A per-base API
route was set aside: the service names bytes and never carries them, and
Render's cold start has reached 25 s.

**Bake and validation**

```sh
pipeline/impact/venv/bin/python pipeline/impact/bake_explanations.py --target insulin
.venv/bin/python -m pytest pipeline/impact tests/test_impact_explanations.py
.venv/bin/python pipeline/check_assets.py
python3 pipeline/upload_tracks.py --kind impact_explanations --target insulin --dry-run
flutter test test/features/gene_lookup/impact/
```

The bake reads `ALPHAGENOME_API_KEY` from the environment or `~/.env`. It asks
the two windows for `AVI_SCORE` and its attributions, refuses a Phred that
differs from the stored AVI asset at its saved precision, then asks each
substitution's twelve assay scorers (three at a time, backing off while the
Atlas is busy): seven minutes for insulin. A rerun resumes from both
checkpoints; a window written before the raw score was kept is asked again.

**Contract (schema 2)**

`assets/impact_explanations/<slug>.json` carries the AVI asset's identity
(gene, accession, transcript, GRCh38, GENCODE v46, sequence, orientation,
complementation, coordinate runs) and the SHA-256 of its bytes, then:

- `scorer`, `scope: across_atlas_genes_and_biosamples`,
  `units: raw_score_attribution`, `selection: all`, `alt_order`;
- `generated_at`, `client_version`, `atlas_release: null`,
  `atlas_url_template`;
- `baseline` (null for insulin), `raw_minus_sum` (median, min, max),
  `track_scorers`;
- `features`: the 18 Atlas feature ids, in the Atlas's order;
- `tracks`: each winning track once, `[scorer, assay, biosample, ontology,
  gene, target]`, the target a ChIP factor or mark or a splice site's kind;
- `positions`: keyed by record-local position, three alternatives in
  `ACGT minus wildtype` order, each `[phred, raw, [18 values],
  [[feature, track, value], …]]`, the last the assay's own signed effect on
  its winning track.

`check_explanations.py` holds it to the AVI asset (digest, identity, coverage,
every Phred), 18 finite values with the indel flags zero, each raw − sum
within the recorded range, and every winner's indices; `upload_tracks.py`
runs it before any upload. `GeneImpactExplanations.fromJson` checks the
same identity and shape on the phone before any of it is shown. The service's
`/gene/{accession}/{gene}/impact-explanations` redirects to the stored object;
its local-directory fallback, for a checkout without a database, serves
schema 2 only.

Schema 2 replaced schema 1 in place under the same track kind, at the user's
decision (2026-10-21), as the folding track's schema 2 did: an app built
before it reads insulin's contributions as unavailable.
