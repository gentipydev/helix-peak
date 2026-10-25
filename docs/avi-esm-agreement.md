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

The line leads to the page only where the two models can be compared: a
coding base with at least one change to another amino acid, which ESM-2
scores too (`AgreementRow.anyAt`; the user's ask, 2026-10-22). Elsewhere in
the coding sequence the line names the codon and residue in the quiet ink, as
the line under a UTR base does, and leads nowhere:
- a base whose three changes are all silent;
- the start codon (any change there is p.Met1?);
- a base whose AVI is borrowed from a neighbour.

Introns, UTRs and the flanks have no codon line at all. In insulin, 259 of
the 327 coding bases from codon 2 on lead to the page; their changes are the
687 the page ranks.

Every protein with both tracks has the page, curated or built on demand. It
is drawn from the tracks the walk already holds: nothing is baked for it.

**The page**

```
×   c.268 · AVI and ESM-2
[G] insulin A chain
    codon 90 · GGC · Gly90 · highly constrained
    chr11:2,159,917
╭──────────────────────────────────────────────────╮
│ Ranked among INS missense substitutions          │
│                          ● AVI Phred   ○ ESM-2    │
│ A  Ser                         33.2      −7.2    │
│    ────────────────────────○━━━━━━━━━━━━━━━━━●─  │
│ C  Arg                         31.8      −8.4    │
│    ─────────────────────────────○━━━━━━━━━━━●─   │
│ T  Cys                         31.2     −10.4    │
│    ──────────────────────────────────────○●──    │
│    ← milder effect             stronger effect → │
╰──────────────────────────────────────────────────╯
● denim (AVI) · ○ clay (ESM-2) · the rule between shaded from one to the other
Across INS · 687 missense substitutions
○ ESM-2
−15 ┼────────┼────────┼────────┼────────┐
    │                    ·  ·· ·:·::·   │
−10 ┼────────┼────────┼──·:·:::● Cys ···┤
    │                · ·:::::Arg ●  ● Ser
 −5 ┼────────┼──────·:·:::::::·:·:───────┤
    │  · ·  · ··:·::::::·::·:·  ·       │
  0 ┼·:·:·:·:·::·:::·::·:··:· ··────────┤
 +5 ┴────────┴────────┴────────┴────────┘
    0       10       20       30       40
                                ● AVI Phred
Spearman ρ                                      0.79
Same order within a base            64% of 540 pairs

AlphaGenome Atlas · ESM-2
AVI (AlphaGenome Atlas) scores each change from the DNA, ESM-2 the amino acid
it makes from the protein sequence; both are ranked here among the gene’s
missense substitutions.
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
  - Its row shows the two numbers alone, each in its own column under its
    model's mark: no rank is written (the user's ask, 2026-10-22: "keep only
    the AVI Phred score and ESM-2 score for comparison").
  - Under the numbers, one track runs from the milder effect to the stronger.
    AVI is a denim dot, ESM-2 a clay ring, and a heavier rule shaded from the
    one to the other joins them: the gap is how far the two models part on
    that change.
  - The ranks the track draws are said in words to a screen reader ("Among
    INS missense substitutions, AVI places it in the top 1.7%, ESM-2 in the
    top 29%").
  - A dot inside its ring is a change the two rank alike.
  - Under the last track, "← milder effect" and "stronger effect →" say which
    way the tracks run, by what grows along them rather than by a value:
    ESM-2's stronger end holds its lowest numbers. Until the same day they
    were "lowest" and "highest", over the tracks, where "highest" stood under
    ESM-2's head and read as its column's word (the user found it "really
    confusing").
  - The marks set off from the milder end and travel to their places, a row
    after the row above, as the Contributions bars grow in. Under reduced
    motion they are drawn in place.
- A change ESM-2 cannot score has no track. Its row carries its Phred and the
  app's own reading of a ClinVar record, word for word (`EvidenceReading`):
  - "Same amino acid: only AVI applies.";
  - "Premature stop: only AVI applies.";
  - "Start codon change: only AVI applies." (anywhere in codon 1, HGVS
    p.Met1?).
- A base whose every change is silent (a third base of Gly, Val, …) is not
  offered the page. The page still draws one: three such rows, no heading,
  legend or ends, and no ESM-2 column, so its numbers name their unit
  ("14.8 Phred").

**Look and layout**
- The two models wear the app's own earth (`AgreementColors`, the home
  helix's denim for AVI and clay for ESM-2) at the user's ask (2026-10-22:
  "the same palette we are using across the app, even in the contributions
  screen"), the second exception to R9.1 after the Contributions page, on a
  page with nothing of ClinVar's.
  - The pair was chosen by the dataviz skill's validator on both grounds the
    page draws on (#23201E, #1C1A18): the one pair of the earth's six inside
    the dark lightness band, 12.2 apart for any dichromat (8 the target) and
    17.9 in normal vision (15 the floor), each clearing 3:1.
  - Honey parts further but is lighter than the band. Every earth hue is
    softer than the validator's chroma floor, by the palette's design.
  - The hue marks the marks, never the text: numbers and names stay in the
    page's inks, and the dot and the ring part by shape too.
- Type turned up past what a phone holds (`stackScoreLabels`), or two columns
  that do not fit beside the base, puts each number on a line of its own
  after its mark. A gene-wide line's value then goes under its name.
- The scroll stops at its ends (`ClampingScrollPhysics`), as the walk's does.

**Under the card, and the source**
- The gene's scatter and its two numbers stand under the card, the count
  said once, in their heading.
- The ρ is set in the mono face: the sans face has no Greek.
- The page ends on its two sources, "AlphaGenome Atlas · ESM-2", one line on
  what they are and how they are compared, text only (the user's ask,
  2026-10-22), and the notice AlphaGenome's terms ask of anything that shows
  its output, which the terms ask to be conspicuous.
- Until 2026-10-23 an ⓘ sheet over the page held the two scores, how the
  tracks, hues and scatter read, the two gene numbers, that AVI integrates
  AlphaMissense, the terms' address and the two papers (Avsec et al., Nature
  649, 1206–1218 (2026), doi:10.1038/s41586-025-10014-0; Lin et al., Science
  379, 1123–1130 (2023), doi:10.1126/science.ade2574), and the notice stood
  there alone. Another session took the sheet away and put the notice on the
  page; the change was committed as it stood on 2026-10-25, at the user's
  choice, before ClinVar joined the page.

**The scatter**

Added at the user's ask, 2026-10-22 (`_ScatterPainter`), under the heading
and over ρ.
- **What it holds.** Every substitution in the gene's set is one dot: AVI's
  Phred across, ESM-2's score up, each axis named after its model's mark
  (the denim dot under the Phred, the clay ring over ESM-2's score).
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
- **This base's changes.** Its missense changes are balls in the colours
  their amino acids have on the protein and chains pages
  (`AnatomyColors.forResidue`, the walk's own seven chemistries: Ser polar
  green, Arg positive blue, Cys yellow, Leu aliphatic grey). That was the
  user's ask, 2026-10-22. A ring of the ground keeps a grey ball clear of the
  grey cloud, and each ball is named by what it makes, the name in the page's
  ink.
  - Changes that make the same amino acid share a name: Met5's third base
    makes Ile three times.
  - A name goes to the first place, beside its marks then above, below, at a
    corner or further off, where it covers no mark and no other name; failing
    that, where it covers least.
  - A name set off from its marks is led to the nearest of them by a
    hairline, which only type at twice its size on a narrow phone has
    needed.
- **The line of equal rank (ρ = 1).** At the user's ask (2026-10-22: "a
  line that shows the perfect correlation"), a dashed line in the page's ink
  runs through the cloud, named "ρ = 1".
  - It is where every dot would stand if the two models ranked the gene's
    changes alike, which is what a rank correlation of 1 means: each Phred
    beside the ESM-2 score of the same rank, the gene's own quantiles paired
    from the mildest to the strongest (`GeneAgreement.equalRanks`, 101
    points).
  - A straight diagonal would mean nothing on two scales in different units
    (Phred 0 to 40, ESM-2 +5 to −15). This line is curved because the two
    spread their changes differently.
  - A dot under it is ranked stronger by AVI, one over it by ESM-2: the
    tracks' gap, drawn in the plane. Gly90's Ser and Arg lie under it, its
    Cys on it.
  - Its name goes, by the same cost as the bases' names, beside the line
    where it covers no mark and no name, from its strong end down.
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
  accepting that a silent base's page shows nothing for ESM-2. Later the
  same day the user had the page offered only where both models can be
  compared, so a silent base no longer leads to it.
- Rank in the gene, rather than each score on its own scale or the
  strong-end lines.
- Which gene-wide numbers: left to me. ρ and same order were chosen; a
  scatter of every change and ρ by region were left as follow-ups.
  - Insulin by region: A chain 0.73, B chain 0.68, signal peptide 0.61,
    C-peptide 0.24.
- The scatter, asked for the same day.
  - My calls: its fixed scales, ESM-2's axis turned over, one name per
    amino acid, and the hairline leaders.
- Then, the same day: no rank written in a row, only the two scores; the
  track's ends said clearly; the app's palette on the page; and the sources
  named with one line on what they are and how they are compared.
- Then: this base's balls in their amino acids' colours, and a line of
  perfect correlation. I drew that line as equal rank (ρ = 1), since the two
  scales share no units.
  - My calls: the effect words under the tracks, denim for AVI and clay for
    ESM-2 (by the validator), the hue on the marks alone, the shaded rule,
    and the terms' notice kept in the ⓘ sheet (since gone, see above).

**My calls, which the user can change**
- The band in the header.
- No link on an estimated base or where either track does not match. No
  test pinned those cases.
- The heading's and the ends' words.
- Working the set out before the rise.

**Rules**
- R9.5 records the page as the one place where AVI's and ESM's numbers meet,
  and, since 2026-10-25, ClinVar's classes beside them; an opened record no
  longer repeats them.
- R9.1 records its two hues as the second exception to "hue belongs to
  ClinVar alone", after the Contributions page's four, and only while the
  page carries no ClinVar mark.
- R9.4 records what the page shows of ClinVar and what it does not (see
  "With ClinVar" below).

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
  - the line of equal rank: its ends at the two models' mildest and strongest,
    its middle at the two medians, the Phred never falling and ESM-2's score
    never rising along it;
  - the rows' two numbers alone, the effect words under the last track, the
    two hues in every theme and clear of both grounds, and the page's two
    sources, its one line and the terms' notice;
  - the rows, the columns, the gene numbers and the semantics;
  - large text on a narrow phone;
  - motion, the clamped scroll, no info button, and the source;
  - no clinical words.
- `gene_agreement_test.dart` and `agreement_page_test.dart` also hold where
  the line leads: c.268 and c.11 open the page, and c.270 and c.2 do not.
- Walk tests changed at the user's ask, all in `merged_impact_test.dart`:
  - "the residue line opens that residue on the protein page" is now "the
    residue line opens AVI and ESM-2 side by side". It taps the line at c.76,
    a base with missense changes, finds the page, closes it, and finds the
    sheet as it was.
  - "a silent base shows its own model, its tags and one line to the
    residue" is now "… a plain line for its residue". c.78's line ends
    "Val26 · highly constrained", with no › and no link.
  - "coding bases in an opened gene region show the same evidence" expects
    the same plain line at c.78.
  - Every other walk test is unedited.
- The sheet golden `surfaces/mrna-base-sheet.png` opens c.78, so its line
  loses its › and its brighter ink. The PNG was already owed from the x86
  host for the Contributions row, and stays owed for both changes.

**With ClinVar (2026-10-25)**

The user's ask: a missense change always has AVI, and ESM-2 and ClinVar may
or may not be there. Where ClinVar has a record at the base, the page compares
all three; where it has none, the page is the two models' as above, unchanged.
It came after the base sheet's opened record was seen to repeat what the
sheet and its two pages hold: ESM and AVI again, "Both models at their strong
end.", and AVI's three largest contributions.

A record at the base, of any of its three changes and any consequence, makes
the page this:

```
×   c.268 · AVI, ESM-2 and ClinVar
[G] insulin A chain
    codon 90 · GGC · Gly90 · highly constrained
    chr11:2,159,917
╭──────────────────────────────────────────────────╮
│ Ranked among INS missense substitutions          │
│                          ● AVI Phred   ○ ESM-2    │
│ A    Ser                       33.2      −7.2    │
│    ────────────────────────○━━━━━━━━━━━━━━━━━●─  │
│ C    Arg                       31.8      −8.4    │
│    ─────────────────────────────○━━━━━━━━━━━●─   │
│ T  ● Cys                       31.2     −10.4    │
│    ──────────────────────────────────────○●──    │
│    ★ Uncertain significance                      │
│    ← milder effect             stronger effect → │
╰──────────────────────────────────────────────────╯
Across INS · 687 missense substitutions
  the cloud; ClinVar's 89 missense records in their class colours, P/LP
  on top; this base's three as ink rings, named; the line of equal rank
Spearman ρ                                      0.79
Same order within a base            64% of 540 pairs
ClinVar's missense records
                                 AVI Phred     ESM-2
● P/LP                    31          26.9      −8.6
● Conflicting             11          22.1      −5.9
● VUS                     39          21.3      −5.6
○ Other                    8          29.6      −8.6
  Every substitution     687          22.3      −3.9
                                             medians
AlphaGenome Atlas · ESM-2 · ClinVar
(the compared line, the line on ClinVar, the terms' notice)
```

- **The rows.** ClinVar's mark stands beside what a change makes, as the
  base sheet marks the change's bar: the most severe class of its records.
  Every row on such a page keeps the mark's room, so the tags stand in line.
  Under the track, or under the line saying why only AVI applies, stands each
  record of the change: its review stars and its classification, quoted
  inside `ClinVarSourced`. A change with no record has neither, and nothing
  is said of the absence (R9.3).
- **Hue is ClinVar's (R9.1).** The models' dot and ring take the page's ink,
  and the rule between them the quiet ink. On the scatter this base's changes
  are ink rings round their own ClinVar mark, or round an ink dot where they
  have none.
  - Denim stands 10.7 from ClinVar's benign blue and clay 10.5 from its
    pathogenic rose (OKLab ×100, normal vision).
  - The amino-acid balls' blue and red sit 9.4 and 8.7 from them.
  - ClinVar's own palette keeps its pairs at least 15 apart.
  - A page with no record keeps denim, clay and the amino-acid balls.
- **The scatter.** It marks every record of the gene that is missense and
  that both models score, at its own change, once, in the most severe class
  of its records (`ClinVarAgreement`). The most severe is drawn last; Other
  is a ring.
  - A name keeps clear of this base's marks and of other names first, and of
    ClinVar's records where it can.
  - On this page a name may stand further off, led back by its hairline. The
    two-model page places its names exactly as before.
- **The table.**
  - Each class present, in the order a reader scans them (P/LP, Conflicting,
    VUS, B/LB, Other), with its records counted and their median AVI Phred
    and ESM-2 score.
  - Then the gene's every missense substitution, which they are read against.
  - A median that falls halfway between two places is rounded away from zero,
    as the stored decimals would round. Insulin's Other Phreds give 29.55,
    which single precision would otherwise have tipped to 29.5.
  - Large type puts each class's medians on a line under its name.
- **Not shown, on purpose (R9.4).** No count of agreement and no
  P/LP-against-B/LB statistic. Insulin has no B/LB missense record, and only
  13 of the 38 curated genes have five or more of both. The footer says once
  why ClinVar's classes are not an independent test of either model.
- **The record.** An opened ClinVar record, on the base sheet, the residue
  sheet and in the list, keeps:
  - ClinVar's own words, the review status and the accession;
  - Residue › or Base ›;
  - where only AVI applies to its change, the one line that says so.

  It no longer carries the ESM and AVI lines, the strong-end lines ("Both
  models at their strong end." and its three siblings) or AVI's largest
  contributions. On the residue sheet and in the list it offers "AVI and
  ESM-2 ›" where its base has this page; the page rises over the sheet or
  the list, and × returns there as it was left. The base sheet's codon line
  is that link there. About these sources no longer names ESM-1b's −7.5 line,
  which nothing draws any more.
- **Every protein.** Like the two-model page, it is built from the tracks the
  walk holds: every protein with AVI, ESM-2 and ClinVar, curated or built on
  demand. Phospholamban has no ESM-2 track, so it has no page; a page of AVI
  and ClinVar alone is left as a follow-up.

**What the stored tracks say for insulin**

- **Records.** 89 missense records, all placed, on 89 changes:
  - P/LP 31, VUS 39, Conflicting 11;
  - Other 8: 5 risk alleles and 3 not provided;
  - no B/LB: insulin's 42 B/LB records are synonymous or off the CDS.
- **Pages.** 73 of the 259 bases the page is offered at carry a missense
  record, and 6 more only a synonymous or stop record: about 79 pages with
  ClinVar.
- **Where the classes stand.** P/LP sit in the gene's top fifth by both
  models (median top 21% by AVI, 17% by ESM-2); VUS and conflicting records
  sit mid-gene.
- **Where they part.**
  - G32S: AVI top 0.3%, ESM-2 31%.
  - C43W: AVI 48%, ESM-2 1.5%. A bridge cysteine's third base, whose
    conservation as a base is low.
  - The cleavage sites ClinVar calls P/LP, A24V and c.266's R89H, R89P and
    R89L: both models mid-gene.
- **VUS or conflicting records both models put in the gene's top 10%:**
  H29D, C96Y, C100Y, G90C, E106V, G47V.

**The user's choices (2026-10-25, AskUserQuestion with previews)**

- Every record body stops repeating the models, with a link to this page
  outside the base sheet.
- Class counts and medians as the page's numbers for ClinVar.
- ClinVar owns hue on a page that carries it.
- The other session's change to the page (ⓘ sheet removed, notice inline)
  committed first.

**My calls, which the user can change**

- "AVI and ESM-2 ›" as the link's words.
- The line saying why only AVI applies stays in a record of a change only AVI
  scores; the preview showed only the strong-end sentence going.
- The footer's line on ClinVar.
- The table's head on its own line, over its two columns.
- Names that may stand further off on a page with ClinVar.

**Tests**

- `clinvar_agreement_test.dart`: the model.
  - Insulin's classes and medians against the script.
  - p53's B/LB records, and glucagon's minus-strand record.
  - Every scored curated protein's records placed once.
  - The cache.
- `agreement_clinvar_page_test.dart`: the page.
  - c.268, c.266, c.94, c.129 and c.73; large type; motion; whole pages.
  - The codon line from the sheet, and the record links on the residue sheet
    and in the list.
- Three walk tests were changed at the user's ask, all for the record:
  - `merged_impact_test.dart`, "a record opens its evidence in place, one at
    a time": the model lines, the strong-end lines and a link to the page
    are now expected absent.
  - `clinvar_widgets_test.dart`, "a record's links open its residue or base
    above the list": the strong-end line is now expected absent.
  - `impact_explanation_widgets_test.dart`: "expanded ClinVar record uses the
    record allele" is deleted, with the two imports only it used.
- No golden opens a record or the page, so no PNG moves.
