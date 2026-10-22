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
×   c.73 · Contributions                             ⓘ
[T] insulin B chain
    codon 25 · TTT · Phe25
    chr11:2,160,899
╭──────────────────────────────────────────────────╮
│ C (p.Phe25Leu) scores highest; Coding sets it    │
│ apart.                                           │
│                                                  │
│ C Leu                   25.1 Phred · top 0.309%  │
│   ███████████████ ▓▓▓▓▓▓▓▓▓ ▒ ░         +1.192   │
│ A Ile                   22.1 Phred · top 0.617%  │
│   ██████ ▓▓▓▓▓▓▓▓ ▒ ░                   +0.759   │
│ G Val …                                          │
╰──────────────────────────────────────────────────╯
By group                   C Leu   A Ile   G Val
■ Coding                  +0.706  +0.296  +0.235  ›
                          ▬▬▬▬▬▬   ▬▬▬     ▬▬
■ Conservation  …
■ Expression & chromatin  +0.031  +0.039  +0.041  ⌄
   RNA-seq                +0.007  +0.009  +0.009  ⌄
   ▏C  WTC11 · INS · −0.069
AlphaGenome Atlas
```

One page for a base, not one per substitution: across insulin's 4,293
substitutions, 92% of the Phred's variance lies between bases and 8% within
one (a base's three differ by a median 1.9). Conservation's attribution is
the same for all three at a base, and what sets one apart is what that change
does: a stop (local 5234, 54.7 against 23.4 for both missense) or a splice
site (local 6158, 24.8 against 0.2 and 0.1). Only the three side by side
show which is which (the user's question, 2026-10-22).

- The header is the sheet's own: the base's letter on its region's tint,
  the region, the base in its own terms (its codon and the residue it
  encodes, or an intron's splice sites; not the constraint band, which is
  ESM's) and the coordinate.
- The card opens on what the numbers say, by rule and with no prose of its
  own: the substitution with the highest Phred, named by its protein change
  in HGVS where it has one (`p.Phe25Leu`, `p.Phe25=`, `p.Met1?`), and the
  group whose total leads the others' most (only where that substitution is
  in the genome's top 10%, Phred 10 or more, `GeneImpact.middlePhred`, and
  half a point or more ahead, and the lead is over 0.02); and a group that
  could differ between the substitutions but is level across them all (a
  mean over 0.05, one sign, a spread within 15% of its largest), named
  without its values, which the table gives. Conservation describes the
  base, not the change (`ContributionGroup.ofBase`), so it is level by its
  nature and never said. Where the numbers say neither, the card says
  nothing. Both gates came on 2026-10-22, at the user's word: before them,
  654 of insulin's 1,431 bases said conservation was level, and 285
  headlines named a winner among three changes all in the bottom 90%. Now
  425 bases lead and 167 name a level group (`Splicing is level across all
  three.` at local 5027, where every change scores Phred 27 to 29).
- Each substitution is a line, its base and what it makes, its Phred and
  genome-wide share, over one bar 8 points tall: its four groups end to end
  on one scale, positive to the right of zero and negative to the left, two
  points of the card between them, square at zero and round at the outer
  ends, with a hairline at zero wherever any bar runs below it. Nothing is
  written in a segment and there is no legend on the card: the table under
  it keys the colours (no legend twice on a screen). The sums stand in one
  column measured from the widest, so every bar ends on the same line. The
  bars grow in, one after another, unless motion is reduced. Until
  2026-10-22, when the user asked for a thinner graph, the bars were 22
  points with names inside, under a legend, with each one's two heaviest
  features below it, repeating numbers the table gives.
- The groups wear the app's own earth (`ContributionColors`): the home
  helix's honey for Coding, moss for Conservation, denim for Splicing and
  clay for Expression & chromatin, the one exception to R9.1, at the user's
  ask. Of the 24 ways to give the four to the groups, four keep every pair
  that touches in a bar at least 12.2 apart for any dichromat and 17.9 in
  normal vision (the dataviz skill's validator, on the card); this one gives
  Conservation the moss. The closest pair, clay against moss, never touch,
  and the table names every group.
- Under the card the groups are rows and the substitutions columns, in the
  sheet's order, each headed by its base and what it makes of the codon
  (`Leu`, `=`, `Ter`, `?`). Each number sits over a bar of its size in its
  group's colour, on one scale for the whole table, filled where it raises
  the score and outlined where it lowers it. A group opens onto its
  features, those that give nothing to any substitution named together on
  one line; an assay opens onto the track behind it, one line per column,
  ruled in the group's colour, ending on what the model predicts at that
  track, alternative against reference (`WTC11 · INS · −0.069`,
  `junction · body of pancreas · INS-IGF2 · 0.646`). That number is signed
  for the Atlas's signed scorers, log ratios for RNA-seq, CAGE, PRO-cap,
  DNase, ATAC and ChIP, and a size alone for its unsigned ones, splice sites,
  their usage, junctions, polyadenylation and 3D contacts
  (`TrackWinner.signed`, after `is_signed` in AlphaGenome's
  `variant_scorers.py`): a plus there would read as a rise. Splicing is one
  feature, so it opens straight onto its tracks.
- Values are signed to three places, a fourth where three would read as a
  signed zero, an exponent below that; an exact zero is `0`. Type turned up
  past what a phone holds scrolls the table sideways rather than squeezing a
  number; the names wrap between words, never inside.
- What the values are, how the first lines are made, how the bars and the
  table draw them, what each group holds and what a track is, is a sheet
  over the page behind ⓘ: nothing on the page moves, and the bars do not
  grow again.
- The page ends on its source and links nowhere (the Atlas links and the
  snapshot's date went at the user's ask, 2026-10-21): "AlphaGenome Atlas ·
  Google DeepMind", then the notice AlphaGenome's terms ask of anything that
  shows its output (the Model Terms of Use, §3: that it is "provided under
  and subject to AlphaGenome Output Terms of Use", and what was done to it):
  "Provided under and subject to the AlphaGenome Output Terms of Use. This
  page groups, sums and rounds the Atlas's values and picks each assay's
  strongest track." The ⓘ sheet's last section, Source, repeats it, writes
  out the terms' address (text only, at the user's choice, 2026-10-22) and
  cites the paper: Avsec et al., Nature 649, 1206–1218 (2026),
  doi:10.1038/s41586-025-10014-0. No logo: AlphaGenome's and DeepMind's are
  Google brand features, used only with Google's written permission, and the
  terms forbid misrepresenting one's relationship with Google. The user
  wants the official logo once that permission is granted. The same notice
  is owed wherever else the app shows AVI values (About these sources).
- The page's scroll stops at its ends on every platform, as the walk's own
  does (`ClampingScrollPhysics`): no bounce on iOS (the user's ask,
  2026-10-22).

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
largest of splice sites, site usage and junctions at a fifth. The page shows
that effect as the scorer gives it (a junction's unscaled). The model
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
