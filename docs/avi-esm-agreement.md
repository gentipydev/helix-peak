**AVI and ESM-2, side by side**

A coding base's sheet names its codon and residue in one line,
`codon 90 · GGC · Gly90 · highly constrained ›`. Since 2026-10-22 that line
opens a page of its own, rising over the walk as the Contributions page does:
the base's three substitutions as AVI and ESM-2 each read them, ranked in the
gene. × closes it back onto the sheet.

Before, the line moved the walk to the protein page with the residue picked,
and nothing brought the reader back to the base (the user's report,
2026-10-22). The residue is still reached from a ClinVar record's
"Residue ›" and from the About sheet.

Every protein with both tracks has the page, curated or built on demand. It
is drawn from the tracks the walk already holds: nothing is baked for it.

**The page**

```
×   c.268 · AVI and ESM-2                            ⓘ
[G] insulin A chain
    codon 90 · GGC · Gly90 · highly constrained
    chr11:2,159,917
╭──────────────────────────────────────────────────╮
│ Rank among INS missense substitutions            │
│                    ● AVI Phred          ○ ESM-2  │
│    lowest                               highest  │
│ A  Ser          33.2 · top 1.7%    −7.2 · top 29% │
│    ────────────────────────○━━━━━━━━━━━━━━━━━●─  │
│ C  Arg          31.8 · top 3.6%    −8.4 · top 19% │
│    ─────────────────────────────○━━━━━━━━━━━●─   │
│ T  Cys          31.2 · top 5.1%   −10.4 · top 7.0%│
│    ──────────────────────────────────────○●──    │
╰──────────────────────────────────────────────────╯
Across INS · 687 missense substitutions
ESM-2
−15 ┼────────┼────────┼────────┼────────┐
    │                    ·  ·· ·:·::·   │
−10 ┼────────┼────────┼──·:·:::● Cys ···┤
    │                · ·:::::Arg ●  ● Ser
 −5 ┼────────┼──────·:·:::::::·:·:───────┤
    │  · ·  · ··:·::::::·::·:·  ·       │
  0 ┼·:·:·:·:·::·:::·::·:··:· ··────────┤
 +5 ┴────────┴────────┴────────┴────────┘
    0       10       20       30       40
                                  AVI Phred
Spearman ρ                                      0.79
Same order within a base            64% of 540 pairs

AlphaGenome Atlas · Google DeepMind · ESM-2 650M
Provided under and subject to the AlphaGenome Output Terms of Use. This page
ranks the Atlas’s Phred scores within the gene, beside ESM-2’s.
```

**The header**
- It is the Contributions page's (`BaseIdentity`).
- Under the region stands the sheet's own whole line, the constraint band
  included: this page is both models'.

**The rows**
- They are the sheet's, in its order (Phred highest first), each tagged as
  the sheet tags it (`Ser`, `=`, `Ter`, `?`).
- A missense substitution is ranked twice among the gene's single-base
  missense substitutions: by AVI's Phred and by ESM-2's score.
  - Each number stands in its own column with its rank: "top x%" is the share
    scoring at least as high; past half, "bottom x%" is the share scoring at
    most as high. Shares are given to two figures.
  - Under the numbers, one track runs from the gene's lowest to its highest.
    AVI is a dot, ESM-2 a ring, and a heavier rule joins the two: the gap is
    how far the two models part on that change.
  - A dot inside its ring is a change the two rank alike.
  - The marks set off from the lowest end and travel to their places, a row
    after the row above, as the Contributions bars grow in. Under reduced
    motion they are drawn in place.
- A change ESM-2 cannot score has no track. Its row carries its Phred and the
  app's own reading of a ClinVar record, word for word (`EvidenceReading`):
  - "Same amino acid: only AVI applies.";
  - "Premature stop: only AVI applies.";
  - "Start codon change: only AVI applies." (anywhere in codon 1, HGVS
    p.Met1?).
- A base whose every change is silent (a third base of Gly, Val, …) shows
  three such rows. It has no heading, legend or ends, and no ESM-2 column, so
  its numbers name their unit ("14.8 Phred").

**Look and layout**
- Inks are neutral (R9.1). There is no hue on the page, and nothing of
  ClinVar's.
- Type turned up past what a phone holds (`stackScoreLabels`), or two columns
  that do not fit beside the base, puts each number on a line of its own
  after its mark. A gene-wide line's value then goes under its name.
- The scroll stops at its ends (`ClampingScrollPhysics`), as the walk's does.

**Under the card, and the source**
- The gene's scatter and its two numbers stand under the card, the count
  said once, in their heading.
- The ρ is set in the mono face: the sans face has no Greek.
- The page ends on its source, text only, with the notice AlphaGenome's terms
  ask of anything that shows its output, and what was done to it.
- The ⓘ sheet holds:
  - the two scores;
  - how a rank reads;
  - why silent, stop and start-codon changes are not ranked;
  - how the scatter is drawn;
  - the two gene numbers, and that ρ turns ESM-2's score over so that
    agreeing reads as positive, as the scatter's rise does;
  - that AVI integrates AlphaMissense, so on a missense change it overlaps
    ESM-2 rather than confirming it (R9.4, the sources note's own words);
  - the terms' address, and the two papers.
- The papers:
  - Avsec et al., Nature 649, 1206–1218 (2026),
    doi:10.1038/s41586-025-10014-0;
  - Lin et al., Science 379, 1123–1130 (2023), doi:10.1126/science.ade2574.

**The scatter**

Added at the user's ask, 2026-10-22 (`_ScatterPainter`), under the heading
and over ρ.
- **What it holds.** Every substitution in the gene's set is one dot: AVI's
  Phred across, ESM-2's score up.
- **Its scales are fixed, the same for every gene:**
  - Phred runs from 0 to the sheet's own ceiling, 40;
  - ESM-2's score runs from +5 at the foot to −15 at the top;
  - a change past an end stands on it: 0.17% of the curated genes' Phreds
    and 0.08% of their ESM-2 scores.
- **Its direction.** ESM-2's axis is turned over, so that each model's larger
  effect lies up and to the right. The two agreeing then reads as a rise, as
  their positive ρ and the tracks' "highest" at the right do. Read with
  ESM-2's score falling down the page, the same agreement would read as a
  fall beside a positive ρ.
- **The cloud.** It is set in the quiet ink, and the more dots it holds the
  fainter each is (24/√n, between 0.12 and 0.5). Insulin's 687 stand apart;
  dystrophin's 24,439 show where they gather.
- **This base's changes.** Its missense changes are drawn in full ink and
  named by what they make.
  - Changes that make the same amino acid share a name: Met5's third base
    makes Ile three times.
  - A name goes to the first place, beside its marks then above, below, at a
    corner or further off, where it covers no mark and no other name; failing
    that, where it covers least.
  - A name set off from its marks is led to the nearest of them by a
    hairline, which only type at twice its size on a narrow phone has
    needed.
- **The rest.**
  - It is painted once, behind a repaint boundary, as a single draw of
    points.
  - A screen reader hears what it holds and which amino acids are marked,
    each once.

**What the numbers are**

`GeneAgreement` (`presentation/inspector/gene_agreement.dart`), built once per
track and kept with it.

- **The gene's set.** It starts from every base of the coding sequence but
  the start codon and the stop, and leaves out a base whose AVI is borrowed
  from a neighbour. Each base is joined to its codon by the walk's own
  `CodingEvidence`, so a reverse-strand record reads as the sheet reads it.
  Each alternative that makes another amino acid, not a stop, is kept, with
  its AVI Phred and ESM-2's ln p(alt)/p(WT) for that amino acid. Insulin has
  687, at 259 bases.
- **Ranks.** By AVI, the share whose Phred is at least as high. By ESM-2, the
  share whose score is at least as low. A mark stands at 1 − that share.
- **ρ.** Spearman's, between the Phred and the ESM-2 score negated, ties at
  their mean rank.
- **Same order.** Of the pairs of missense substitutions at one base, with
  neither score tied, the share both models put in the same order.

The set, ρ and the pairs were checked against a script apart from the app,
which joins each base to its codon from the record's own CDS segments. They
agree on all 37 genes to the sixth decimal. Insulin and glucagon (a
reverse-strand record) are pinned in `gene_agreement_test.dart`.

**Why ranks, and why these two numbers**

The user asked to see "on which level" the two models say the same thing.
Their scales share no calibration: AVI's Phred is genome-wide, and ESM-2's is
a log ratio at one residue. The app's own "strong end" lines (Phred 20,
ESM −7.5) sit at different depths:
- in insulin they mark 59% and 26% of the missense substitutions;
- across the 37 ESM-scored curated genes, 64% and 16%;
- so "only AVI" (230 in insulin) swamps "only ESM" (1).

Ranked in the gene, the two can be read on one scale.

The two numbers say where the models agree: on which positions matter, far
more than on which change at a position.
- Across a gene, ρ runs from 0.40 to 0.82 (median 0.60).
- Within a base the two order its changes alike in a median 67% of pairs,
  where half would be chance.
- AVI's conservation is the same for a base's three changes, which is why its
  differences lie mostly between bases.

Gly90's first base shows it: the two put Cys alike (top 5.1% and 7.0%) and
part on Ser (1.7% and 29%).

| Gene | Missense substitutions | ρ | Same order within a base |
|---|---|---|---|
| AVP | 1,060 | 0.82 | 68% of 852 |
| OXT | 801 | 0.79 | 65% of 668 |
| INS | 687 | 0.79 | 64% of 540 |
| UMOD | 4,206 | 0.76 | 67% of 3,314 |
| SOD1 | 1,008 | 0.74 | 72% of 771 |
| LYZ | 966 | 0.73 | 76% of 735 |
| LGI1 | 3,690 | 0.73 | 74% of 2,778 |
| IZUMO1 | 2,301 | 0.73 | 67% of 1,756 |
| PAPPA | 10,767 | 0.72 | 72% of 8,296 |
| FPR1 | 2,286 | 0.72 | 72% of 1,783 |
| RCVRN | 1,345 | 0.69 | 77% of 996 |
| CSTB | 649 | 0.68 | 69% of 495 |
| CYP17A1 | 3,367 | 0.66 | 69% of 2,567 |
| TNF | 1,498 | 0.62 | 70% of 1,177 |
| DMC1 | 2,240 | 0.62 | 70% of 1,664 |
| GCG | 1,213 | 0.61 | 66% of 898 |
| B3GAT1 | 2,141 | 0.61 | 67% of 1,693 |
| TYRP1 | 3,544 | 0.60 | 67% of 2,743 |
| S100B | 627 | 0.60 | 68% of 453 |
| CFTR | 9,721 | 0.60 | 68% of 7,138 |
| MB | 1,022 | 0.59 | 78% of 756 |
| GAPDHS | 2,648 | 0.59 | 70% of 2,113 |
| HBB | 957 | 0.57 | 72% of 751 |
| EPO | 1,214 | 0.57 | 70% of 964 |
| CGB3 | 1,048 | 0.57 | 58% of 785 |
| PRNP | 1,678 | 0.56 | 72% of 1,304 |
| TP53 | 2,569 | 0.55 | 64% of 1,986 |
| APP | 5,117 | 0.54 | 67% of 3,833 |
| GH1 | 1,421 | 0.53 | 63% of 1,101 |
| DMD | 24,439 | 0.53 | 67% of 17,270 |
| PPBP | 829 | 0.51 | 67% of 618 |
| TG | 18,094 | 0.46 | 64% of 13,839 |
| LEP | 1,083 | 0.44 | 61% of 818 |
| AMY1A | 3,419 | 0.44 | 50% of 2,190 |
| RLN2 | 1,212 | 0.43 | 61% of 859 |
| DNM1 | 5,690 | 0.43 | 67% of 4,345 |
| UBB | 1,501 | 0.40 | 62% of 1,138 |

PLN has no ESM-2 track, so its codon line opens nothing, as before.

**Cost**

The set is worked out when the line is tapped, before the page rises, and
kept with the track (an `Expando`), so a gene pays once a session. Its cost
in a warm `flutter test` run on the dev Mac:
- dystrophin's 24,439 substitutions take 25 ms;
- thyroglobulin's 18 ms;
- CFTR's 11 ms;
- insulin's under 1 ms.

The time lies in the bases' walk and the two sorts. Paying it before the rise
moves the delay to the tap, rather than putting a stutter in the motion. A
phone may take longer, and nothing was measured on one.

**The user's choices (2026-10-22, AskUserQuestion with previews)**
- This base's three substitutions, rather than the codon's nine. That meant
  accepting that a silent base's page shows nothing for ESM-2.
- Rank in the gene, rather than each score on its own scale or the
  strong-end lines.
- Which gene-wide numbers: left to me. ρ and same order were chosen; a
  scatter of every change and ρ by region were left as follow-ups.
  - Insulin by region: A chain 0.73, B chain 0.68, signal peptide 0.61,
    C-peptide 0.24.
- The scatter, asked for the same day.
  - My calls: its fixed scales, ESM-2's axis turned over, one name per
    amino acid, and the hairline leaders.

**My calls, which the user can change**
- The band in the header.
- The link everywhere it was, silent bases included, but not on an
  estimated base or where either track does not match. No test pinned those
  cases.
- The heading's and the ends' words.
- Working the set out before the rise.

**Rules**
- R9.5 records the page as the second place where AVI's and ESM's numbers
  meet, after an opened record. Its ⓘ explains both models' scales.
- No count of agreement with ClinVar is shown (R9.4), and ClinVar is not on
  the page.

**Tests**
- `test/features/gene_lookup/impact/gene_agreement_test.dart` pins the set:
  - insulin and glucagon against the script;
  - c.268's shares, and the silent, stop and start rows;
  - the borrowed base and the foreign track;
  - the cache;
  - every scored curated protein, each change re-derived.
- `test/features/gene_lookup/impact/agreement_page_test.dart` covers the page:
  - through the walk, in the walk's theme under an app in another;
  - the scatter between its heading and ρ, and what it says to a screen
    reader: Gly90's three, Met5's one name, a silent base's none;
  - the rows, the columns, the gene numbers and the semantics;
  - large text on a narrow phone;
  - motion, the clamped scroll, the ⓘ sheet and the source;
  - no clinical words.
- One walk test changed, at the user's ask:
  - `merged_impact_test.dart`'s "the residue line opens that residue on the
    protein page" is now "the residue line opens AVI and ESM-2 side by side";
  - it taps the line, finds the page, closes it, and finds the sheet as it
    was;
  - every other walk test is unedited.
