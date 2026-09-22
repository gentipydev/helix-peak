# Protein pipeline rules

The rules a protein has to satisfy for the walk (gene, mRNA, protein, mature
chains, structure) to be drawn and described the same way as every other one.
They were extracted from one review of the first ten shipped proteins, in which
every problem found in one protein turned out to be a rule the others were
breaking too, and extended when ten more were added — each checked against its
record first, in [protein-verification.md](protein-verification.md). The goal is
a pipeline that takes a protein name typed into search and produces the walk
with no per-protein code and no per-protein prose.

Each rule says what to do, why (the case that broke), and where it lives now.
**Status** is one of: *enforced* (code or a test fails without it), *baked*
(the bake does it, but only from a hand-written table entry), or *open* (not
handled; a generic pipeline must solve it).

---

## 1. Resolving the name to one molecule

**R1.1 One isoform, chosen explicitly.** A chromosome slice holds every
transcript at a locus: RLN2 has six CDS features, four of them predicted `XP_`
models, and `extract_gene` takes the first. Pick the isoform by `protein_id`
and drop the others before parsing. For arbitrary input, the choice should be
the MANE Select transcript, falling back to UniProt's canonical isoform.
The CDS does not always settle the transcript: AMY1A's slice holds two mRNAs
around identical CDS coordinates, differing only in an untranslated first exon,
and the shorter one — which the picker took — is not MANE Select. Name the
transcript too where two hold the same CDS. *Status: baked*
(`Source.protein_id`, `Source.transcript_id`, `select_isoform`). *Open:*
choosing both automatically.

**R1.2 Prefer RefSeqGene, else a chromosome slice.** `NG_` records annotate one
gene cleanly. OXT, RLN2, GCG and AMY1A have none and come from `NC_` slices,
which lack `exon` features and carry every variant. Every slice is NCBI Gene's
coordinates with 500 bases either side. *Status: baked.* *Open:* reading the
coordinates from NCBI Gene rather than the table.

**R1.3 The record's protein must be UniProt's, except for declared variants.**
NG_012232 and P11532 differ at three of dystrophin's residues; the bake fails
on any difference not listed in `uniprot_variants`. *Status: enforced.*

**R1.4 Clip the gene to its transcript.** A `gene` feature spans every variant:
RLN2's is 39,463 bases around a 4,853-base transcript, which made 88% of its
gene page "outside the transcript". *Status: enforced*
(`clip_to_transcript`).

## 2. Sequence and coordinates

**R2.1 A minus-strand record's `sequence` is already reverse-complemented.**
Index it from the far end (`end - position`); never complement it again. A
second complement once turned relaxin's residue 1 from M into Y, and an
independent check script made the same mistake in this review. *Status:
enforced* (`check_frame` after every remap).

A baked track's `sequence` is not the record's own string. The AVI and ClinVar
assets list the drawn letters in increasing record position, because every
reader indexes them `sequence[position - start]`; on a minus-strand record that
is the record's `sequence` reversed. The AVI bake once copied the record's
string as stored, and RLN2's and GCG's base sheets read the wrong letter at 74%
and 73% of bases while every score was still filed correctly; the ClinVar bake
refused both genes. *Status: enforced* (`check_assets.py`, the catalog ClinVar
test over every drawn base).

**R2.2 The CDS translates to the record's protein, exactly.** Re-proved after
clipping and after compression, since both rebuild coordinates. *Status:
enforced.*

**R2.3 Splice sites.** Every intron in the first ten starts `GT` and ends `AG`,
except one dystrophin intron that is `GC…AG`, a real minor class; the second
ten add one more, in SOD1. Accept `GT-AG`, `GC-AG` and `AT-AC`; flag anything
else as a coordinate error. *Status: enforced* (`check_assets.py`, over every
baked record, shortened introns included).

**R2.4 Shorten introns only past the budget, never exons.** Past 24,000 bases
the gene page has no picture; introns are scaled, keep their own first and last
bases, and the page says so: the badge reads the real span (2,092,329), the
caption the real proportion ("Introns are 99.3% of the gene, drawn shortened;
exons are to scale"), and a tapped intron its real length (`real_intron_bp`)
and how much of it is drawn. A scale ratio was dropped from the caption: 42 of
dystrophin's 78 introns sit at the 60-base floor, so no single ratio is true.
A gene whose exons alone exceed the budget (titin) has no honest gene page, and
the bake refuses it. APP (290,221 bases, 18 exons) and CFTR (188,703, 27 exons)
take dystrophin's treatment: introns at 1:14 and 1:10, "Introns are 98.8%" and
"96.8% of the gene". *Status: enforced.*

**R2.5 A drawn base has to be findable on the chromosome.** The per-base
AlphaGenome track is indexed by GRCh38 `chr:pos`, and nothing in the app is:
every position it holds is an offset inside an `NG_` or `NC_` record, and three
genes have compressed introns on top of that. The map back is derived, not
tabulated — each exon is paired with GENCODE v46's MANE Select exon in
transcript order (by position and strand; TP53's record leaves four of its
eleven `number` fields null and skips 2, 4 and 9), anchored on the end it shares
with an intron, with a compressed intron's head running forward from the exon
before it and its tail back from the exon after it. R1.4 is what makes that
total: a record clipped to its transcript has no flank to place. R2.4 is what
makes it honest for a shortened intron: the drawn bases are the intron's own
first and last, not a middle slice, so every drawn cell is a real base.

The first and last exon's outer ends are left to float, because RefSeqGene and
GENCODE disagree there — CFTR's first exon is 185 bases to GENCODE's 124, and
TP53's second is 99 to GENCODE's 102.

*Two facts, not one:* whether the record's coordinates count the same way as the
chromosome's, and whether its letters are the other strand's. A minus-strand
record of a minus-strand gene counts up with the chromosome and still reads the
complement of it. Conflating them read RLN2 and GCG off the wrong strand.

The proof is the reference base the Atlas returns with every score: it must be
the base the app draws at that cell. INS agrees at 1,431 of 1,431, and at 402 of
1,431 with the orientation flipped by hand. A record may differ from the primary
assembly at a few bases — dystrophin does at three, which are exactly the three
`uniprot_variants` already declared for it — so differences are counted and
reported rather than forbidden, and a position that differs carries no exact
score. *Status: enforced* (`tool/impact/bake_impact.py`, `check_assets.py`).
*Open:* the four `NC_` slices could take their offset from `Source.seq_start`
directly, and do not, because deriving it the same way for all twenty is what
makes the derivation worth trusting.

## 3. What the precursor is cut into

GenBank annotation of processing is incomplete and inconsistent between
records. This section is where most of the review's fixes landed.

**R3.1 Every residue of the protein has exactly one role.** Signal peptide,
proprotein, mature chain, cut site, trimmed extension or stop codon. Nothing
may fall back to "the coding sequence" on a cut precursor: polyubiquitin's
trailing cysteine answered "the coding sequence · 690 bases" over a tap that lit
three bases. The size is the feature's own as well: glucagon's chain, behind a
signal peptide and cut no further, was sized with the signal peptide's 60 bases
still in it, so a tap said 540 bases and lit 480. *Status: enforced* (tests: no
base of a cut precursor answers as the whole CDS; every coding role is the size
of the bases that answer with it).

**R3.2 A signal peptide is always drawn.** On the protein page it is its own
block, and the sentence says "The first N are a signal peptide." This used to
happen only when the record also named a proprotein, so only insulin showed
it; lysozyme's 18, growth hormone's 26, oxytocin's 19 and relaxin's 24 were
unmarked, then silently gone. Source order: the record's `sig_peptide`, then
UniProt's `Signal` feature. *Status: enforced* for records that carry
`sig_peptide`. *Open:* the UniProt fallback.

**R3.3 The proprotein is named for what it is.** What the signal peptide leaves
is drawn as the second block. Name, in order of preference:

1. the record's `proprotein` feature ("proinsulin");
2. the single mature chain it is exactly, when it is exactly one ("lysozyme C",
   "Somatotropin");
3. the name UniProt gives it (a `Propeptide` or precursor `Chain` feature);
4. a table name ("oxytocin-neurophysin 1", "prorelaxin"), then the word
   "proprotein" as a last resort.

*Status:* 1, 2 and 4 *enforced/baked*. *Open:* 3.

**R3.4 Mature chains form a cleavage series.** They must be disjoint and each
must be a piece the precursor is divided into. Deduplicate identical duplicates
(RLN2 annotates its B chain twice). Exclude fragments cut back out of a
finished chain: HBB's `mat_peptide` features are hemorphins inside the beta
chain, not pieces of it, so HBB is treated as uncut. Generic rule: use UniProt
`Chain` features; use `Peptide` features only when they are not inside a
`Chain`. SOD1's one peptide, residues 2-21, is a fragment of the same kind.

Products that overlap each other are not a series either, but alternatives.
Glucagon's record names what the pancreas cuts proglucagon into and what the gut
cuts it into (glicentin holds glucagon; GLP-1 holds its two shorter forms), and
APP's names both secretase pathways and what gamma-secretase makes of each. One
page of disjoint chains can draw that only by choosing a tissue or a pathway as
if it were the only one. So such a walk stops at the precursor, and the fold
page's prose names what is cut. The `Chain` rule does not resolve it either:
APP's UniProt `Chain` features overlap too. *Status: baked*
(`mature_peptides=False`, overlap check). *Open:* the generic rule; a page for
alternative processing.

**R3.5 A gap between two chains is either a cut site or a named peptide.**
A short basic run (`KR`, `RR`, `RKKR`, oxytocin's `GKR`) is a cut site. A long
gap is a connecting peptide and must be named: RLN2's record omits the C-peptide,
so its 108 residues were counted as one cut and the page said "One dibasic cut
releases two chains" for a precursor cut twice. The bake fills an unannotated
gap from the table's removed regions. Generic rule: gaps of six residues or
fewer that are mostly K/R are cut sites; anything longer must match a UniProt
`Propeptide`, or the bake fails. *Status: baked* (`fill_removed_peptides`).
*Open:* failing on an unnamed long gap; the UniProt source.

A cut site need not be a pair. Vasopressin's copeptin comes off at a lone `R`,
and relaxin's `RKKR` is four. The caption says "dibasic" only where every site
has at least two basic residues ("Two cuts release three chains." for
vasopressin), and a tapped site is no longer "a pair of basic residues".
*Status: enforced* (a synthetic stage test and a catalog caption).

**R3.6 Leftover end residues are a trimmed extension.** Residues outside every
chain at either end get the role `trimmed`, named "the N-terminal extension" or
"the C-terminal extension" by which side of the chains they hang off, and sized
as themselves. *Status: enforced.*

**R3.7 The initiator methionine.** Methionine aminopeptidase removes it when
the second residue is small (G, A, S, C, T, P, V). HBB (V) goes 147 → 146 and MB
(G) goes 154 → 153; p53 (E), dystrophin (L) and ubiquitin (Q) keep it. The
structure page's count is the mature length, so the step exists but is not
drawn. Source: UniProt's `Initiator methionine` feature, with the size rule as
a cross-check. *Status: open.*

**R3.8 An uncut protein names its coding sequence as its chain.** A cut
precursor's gene page reads the chains it becomes; an uncut one read "coding
sequence". It now reads a short name ("hemoglobin beta chain", "myoglobin",
"p53", "dystrophin"), sized as the residues it codes, without the stop codon.
The record's `/product` is too long for a band ("cellular tumor antigen p53
isoform a"). *Status: enforced* (test: a name exactly where there is no chain).
*Open:* deriving the short name (UniProt `shortName`, else the recommended
name with "subunit" and "isoform …" dropped, else the gene symbol).

The same holds for a precursor that loses a signal peptide and is cut no further
(glucagon, APP): its record names no chain, so the catalog names what the
signal peptide leaves ('pro-glucagon', 'APP'), sized as the residues it keeps.

**R3.9 A cut a record misses comes from the table.** NG_021471 annotates
erythropoietin's 27-residue signal peptide and nothing after it. Walked as it
came, the protein page called the other 166 residues 'proprotein' and the walk
stopped there, where lysozyme's and leptin's go on to the chain they become.
Where a record has no peptide at all, the chains are filled from the table's
kept regions, which must tile what the leader leaves and translate to it.

The leader is the record's signal peptide where it has one — erythropoietin's
27, leaving UniProt's `Chain` 28-193 — and nothing at all where the table's
chains tile the precursor from residue 1. TNF is the second case: it is a type
II membrane protein with no leader to cleave, ADAM17 sheds the soluble form off
the part that stays in the membrane (P01375, `Site 76-77 Cleavage; by ADAM17`),
and NG_007462 annotates neither piece. UniProt's own chains overlap — membrane
form 1-233, soluble form 77-233, three more from SPPL2A and SPPL2B — so the
table writes the two the cut actually divides the precursor into, `Membrane
anchor` 1-76 and `Tumor necrosis factor` 77-233. The first is kept, not thrown
away: it is the cytoplasmic domain and the signal-anchor helix, and membrane TNF
signals in both directions.

Only a precursor the table calls `cleaved` is filled, which is what stops p53's
and dystrophin's tables of *domains* being read as chains, and a record
declaring its peptides are not a series (R3.4) is not filled either. *Status:
baked* (`fill_chain`). *Open:* reading UniProt's `Chain` directly.

## 4. Words and numbers on screen

**R4.1 Numbers come from the data, never from a literal.** The residue panel
read "Precursor 174 of 110" on every protein because insulin's length was
hard-coded. Any per-protein number in shared UI code is a bug, and so is a
count of the catalog: the search screen said "ten proteins" and the residue
panel "the other 109" for every protein; both now come from the data.
*Status: open* (fixed where found; no lint). A grep for bare integer literals
in `presentation/` strings is a cheap guard.

**R4.2 A caption agrees with its own numbers.** Cut counts are derived from the
actual gaps between chains, and verbs agree ("One dibasic cut releases",
"Two dibasic cuts release"); singular and plural come from `spelled`,
`spelledLeading` and `grouped`. *Status: enforced.*

**R4.3 Say what the page shows, and nothing it does not.** The mRNA page shows
splicing, so it says so first ("The intron is cut out." / "The introns are cut
out."; omitted for a single exon). UTRs are not removed, so they are "never
translated", not "fall away". *Status: enforced.*

**R4.4 Formats.**

| thing | form |
|---|---|
| name and size | `name · N bases` (middle dot, spaced) |
| CDS chip | `Coding sequence (CDS) · N bases` |
| mRNA letters | T, not U (kept consistent with insulin) |
| numbers ≥ 1,000 | grouped: `1,014` |
| proprotein / chain names | as the record or table writes them, lower case where the source is |

**R4.5 Hand-written prose is checked against the structure file.** The
structure page's `sentence` and `semantics` are the only per-protein prose, and
every scientific claim in them was wrong somewhere:

- *Disulfides are counted by kind.* Insulin's three are two between A and B and
  one inside A; "three hold A to B" was false. Count `SSBOND` records by
  whether the two chains differ.
- *A released peptide is not "discarded".* C-peptide is secreted with insulin
  in equal amounts.
- *"Disordered" and "never solved" are checkable.* p53's tetramerisation domain
  is folded; dystrophin has solved fragments. Check against UniProt `Region`
  and `Domain` features and the PDB.
- *The metaphor must not invert the function.* Lysozyme's bridges do not hold
  its cleft "shut"; the cleft is the open active site.
- *Captions fit two lines* (about 80 characters on a phone; a test enforces it
  for insulin's).

*Status: open.* For a generic pipeline this prose should be generated from
features (chain count, inter- and intra-chain disulfides, helix and strand
counts, ligands) by template, not written.

## 5. The structure

**R5.1 Draw only what the gene makes.** 2DN1 holds an alpha and a beta chain;
drawing both, in two chain colours, read as HBB making two chains. Only chains
whose sequence the gene encodes are exported. *Status: baked* (HBB's row now
lists one chain). *Open:* enforcing it (R5.2).

**R5.2 Each exported chain's sequence is a substring of a mature chain.** This
is the check that would have caught R5.1, and would catch a swapped A/B
mapping. *Status: open* (checked by hand).

**R5.3 One node per mature chain, coloured in mature-page order.** The first
chain is `mature1` (green), the second `mature2`, the third `mature3`, and
disulfides are `cysteine`. A single-chain protein is therefore all one colour.
Polyubiquitin's structure is one copy of three identical chains and takes the
first chain's green. Whether identical copies should instead take a neutral
colour is an *open* design decision.

**R5.4 Prefer wild-type, human, experimental; report every deviation.** Read
`SEQADV`: 3I40 has B30 Ala (not Thr), 3RGK carries K45R and C110A, 1DXX carries
C10S and C188S, and 1HGU conflicts with human GH at twelve positions. Compare
residue by residue as well: `SEQADV` can be wrong itself, and 1TNF files its one
deviation against residue 45 when it sits at 143 (UniProt's Asp219). A
generic picker should rank entries by coverage of the mature chain, then
resolution, then fewest `SEQADV` records, and refuse above a threshold.
AlphaFold is rejected for insulin because it predicts the 110-residue precursor
at a mean pLDDT of 52.9; if used at all, use it only over the mature span and
gate on pLDDT. *Status: open.*

**R5.5 The count is the mature length, not the modelled length.** HBB's chip
says 146 while the crystal resolves 145; ends that are not resolved are normal.
*Status: baked* (hand-written `count`). *Open:* deriving it.

**R5.6 Disulfides in the file must match the table.** `SSBOND` pairs, mapped to
precursor numbering, equal `disulfides`. *Status: open.*

**R5.7 Ligands are not drawn.** Haemoglobin's and myoglobin's hemes are in
their entries and are the point of both proteins; so are SOD1's copper and
zinc, and amylase's calcium and chloride. Where the page's prose would imply
them, the screen-reader text says they are not drawn. *Status: open* design
decision.

**R5.8 A rebaked model needs a full `flutter run`.** `hook/build.dart` compiles
`.glb` into `flutter_scene_generated/` only on a build; hot reload and hot
restart keep the old scene.

## 6. Rendering rules that apply to every protein

- **Snake layout on residue pages**, left-to-right rows on the transcript page
  (where a codon must read `ATG`). Alternate residue rows read right to left.
- **A label fits the band it actually gets.** A run that wraps over three rows
  but is full across only one is sized for that one row; it used to be sized for
  three and then dropped (lysozyme's exon 2).
- **A name is written on the region it names, or not at all.** Where the name
  is too wide for the run, the type is cut — as far as 8pt, against the 11pt a
  run earns — and then the name itself is abbreviated in its category word
  only: `intron 10` becomes `int. 10` and then `I10`, never `intron`. It is
  never set beside the run. It used to be, in a pill with a leader back to it,
  and a pill dodged other names but not other runs: p53's `exon 3` was named
  over `exon 4`, myoglobin's `3' UTR` over its last exon. A run that cannot
  hold even the shortest rung goes unnamed and is answered by a tap; across the
  catalog that is two short pieces of a 5' UTR whose other piece carries the
  name. *Status: enforced* (catalog test).
- **Gene rows are never under 14pt; a gene that does not fit scrolls.** Rows
  are bought out of the width first, but at two points a column the width runs
  out at about 9,400 bases on a phone. Past that, rows used to shrink instead
  (myoglobin 12.3pt, p53 6.8pt), and under 14pt no name fits, so myoglobin's
  exons and UTRs were unlabelled. Now the page keeps 14pt rows, grows past the
  screen and scrolls, and a swipe away starts from where the reader scrolled.
  *Status: enforced* (catalog test).
- **A transcript region over 1,000 bases is folded to its two ends.** Its
  first ~300 and last ~90 bases are drawn, in whole codon rows, around a quiet
  pill reading "· · · 10,386 bases not shown · · ·" (dystrophin's coding
  sequence on a 402pt phone). The start and stop codons stay visible; the chips
  and the header keep the full counts. Only the layout folds: every base is
  still a cell, the splice carries hidden bases into the fold, translation lets
  their residues emerge from it, and a traced hidden base rings the fold and
  says why. Dystrophin's page went from about 25 screens to under 3; p53's
  3' UTR folds too. *Status: enforced* (layout and catalog tests).
- **Residue tiles are never under 28pt; a protein that does not fit scrolls.**
  Dystrophin's 3,685 residues fitted a phone only as unlettered 8pt squares. A
  21pt floor (the transcript's base) was tried first and still read as a dense
  field of type; 28pt is about where ubiquitin's and growth hormone's fitted
  tiles already sit. Dystrophin's page is now about thirteen screens, and p53's
  (393 residues, 22pt fitted) scrolls about two. Any page left mid-scroll, forward or back, starts its transition from
  where the reader was. *Status: enforced* (catalog test).
- **UTR bases recede:** tile 20%, letter 35% of the way off the ground, a
  1.5:1 contrast floor (test in `nucleotide_colors_test.dart`).
- **Transcript chips are one quiet family:** all three use the quiet fill and the
  5′ UTR tint; the grooves and blue letters are what mark the reading frame.
- **An uncut coding sequence keeps the CDS blue** on the gene page.
- **A base is a tap target, so it is sized like one.** The transcript's bases
  went from 21pt pitch to 26 and the opened-DNA page's from 25 to 30 when a tap
  on one started answering with its scores. Twenty points was the floor for
  reading a 12pt letter; it is not a floor for hitting one square out of a row
  of identical squares. `hitTest` walks columns by pitch and gives the mortar to
  the cell before it, so the whole pitch is the target and the two move
  together. The gene page is the exception and stays as it was: at 24,000 bases
  `fit` puts its cells at the two-point floor, where no size of finger picks out
  one base, so a tap there means the run it lands in — which is what it has
  always meant. `baseRadius` moved with `baseSide`, because `tileRadiusRatio` is
  the two of them and every fitted tile in the app is rounded by it.
  *Status: enforced* (layout tests).
- **No impact track is a state, not a failure**, exactly as below: a gene
  without one draws its nucleotide pages as it always did — a tap moves the
  tracer, no sheet opens — rather than meeting a missing file. All twenty have
  one, so the state is held by a widget test of an untracked copy of insulin's
  row. *Status: enforced* (`impact_screen_test.dart`, `check_assets.py`).
- **No constraint track is a state, not a failure.** A protein that is not
  scored yet (`scored` on both rows) has no track to load; its protein page is
  drawn without the conservation toolbar, and a tap there follows the tracer as
  on every other page. A scored protein whose track fails to load says so in
  place. All twenty are scored now, so the state is held by a widget test of an
  unscored copy of insulin's row rather than by the catalog. *Status: enforced*
  (that test; the catalog walk expects the toolbar exactly where a protein is
  scored; `check_assets.py` expects a track exactly there).
- **One chain of an assembly says so in words, not a widget.** Haemoglobin, TNF
  and SOD1 each draw one chain in one colour. The fold label reads 'the
  subunit', and the sentence and the screen-reader text name the assembly: four
  chains, three, two. Where the gene makes a subunit of something else, the
  display name says which (haemoglobin's "(beta chain)").

## 7. Checks for every new protein

What this review did by hand, in the order it found problems. Items marked
✓ already fail a test or the bake; the rest should be automated before search
accepts arbitrary input.

| check | where |
|---|---|
| the record, before the row: span, exons, neighbouring genes, processing, structure | by hand; recorded in `protein-verification.md` |
| ✓ CDS translates to the protein, after every remap | `check_frame`, `check_assets.py` |
| ✓ record protein equals UniProt except declared variants | `check_uniprot` |
| ✓ mature chains are disjoint | `tidy` |
| ✓ constraint track sequence equals the protein page's letters | catalog test |
| ✓ no base of a cut precursor answers as the whole CDS | catalog test |
| ✓ every signal peptide is drawn as a block | catalog test |
| ✓ an uncut protein has a chain name, a cut one does not | catalog test |
| ✓ cut-count captions match the chains | catalog test |
| ✓ a record with no chain ends at its protein page | catalog test |
| ✓ every coding role is the size of the bases that answer with it | catalog test |
| ✓ a constraint track, and its toolbar, exactly where a protein is scored | catalog tests, `check_assets.py` |
| ✓ every drawn base maps to the chromosome, and the reference agrees | `check_sequence`, `check_assets.py` |
| ✓ splice boundaries and exons outscore intron interiors | `check_biology`, `check_assets.py`, `gene_impact_test.dart` |
| ✓ each score is filed under the residue it was measured for (the model prefers the residue that is there over its neighbour's) | `score_protein.py` gate, `verify_cpu.py`, `test_score_protein.py` over every shipped track |
| ✓ every intron is GT-AG, GC-AG or AT-AC | `check_assets.py` |
| ✓ a baked track's letters are the page's letters, base for base (R2.1) | `check_assets.py`, catalog ClinVar test |
| ✓ a ClinVar snapshot exactly where a gene has one, every record re-derived against the record, the AVI map and the CDS | `bake_clinvar.py`, `check_assets.py`, catalog ClinVar test |
| ✓ no pathogenic or benign wording is grouped as Other | catalog ClinVar test |
| ✓ every peptide, signal peptide and proprotein translates to its slice | `check_assets.py` |
| a gap between chains is a cut site or a named peptide | *add to the bake* |
| each structure chain is a substring of a mature chain | *add to `check_assets.py`* |
| `SSBOND` pairs match `disulfides` | *add to `check_assets.py`* |
| `SEQADV` deviations are listed and under a limit | *add to `check_assets.py`* |
| structure prose claims match features (R4.5) | *generate, then review* |
| ✓ gene rows are tall enough to label (14pt; long genes scroll) | catalog test |
| ✓ residue tiles are at least 28pt (long proteins scroll) | catalog test |
| ✓ transcript regions over 1,000 bases fold, ends always drawn | catalog test |
| ✓ every name on the gene page is written inside the region it names | catalog test |

A cheap way to review a new protein before looking at the phone: derive its
`AnatomyModel` in a throwaway test and print each stage's label, count,
sentence and blocks. That is how every caption error in this review was found.

## 8. What a search for any protein still needs

The twenty proteins work because a person wrote `targets.py` and the catalog rows.
For each hand-written field, the generic source:

| field today | generic source |
|---|---|
| `Source` accession, slice coordinates, `protein_id` | NCBI Gene + MANE Select |
| `regions` (signal, chains, propeptides) | UniProt features API |
| `disulfides` | UniProt `Disulfide bond` features |
| `uniprot_variants` | computed and reported rather than declared |
| `proprotein`, `chain` short names | UniProt names (R3.3, R3.8) |
| `mature_peptides` flag | R3.4's `Chain`-versus-`Peptide` rule |
| `Structure` entry and chains | PDB search by UniProt accession (R5.4) |
| structure `sentence`, `semantics`, `count` | templates over features (R4.5) |
| ESM-2 constraint track | a server job; about 85 minutes for all twenty offline (dystrophin 45, CFTR 21), windowed past 1,022 residues |
| AVI impact track | the Atlas's precomputed scores, already generic: GENCODE gives the exons and the reference gates the map, so nothing per-protein is written down (R2.5) |

The backend also has to learn the six things only the fixtures do today (see
`tool/mock/README.md`): the transcript where two share a CDS, exons from the
transcript, cleaning `/product`, unannotated connecting peptides, unannotated
proproteins, and a lone chain behind a signal peptide. It cannot yet fetch a
chromosome slice at all, which four records are.

Cases the second ten brought in, and what the walk does with each:

- **Alternative processing** (glucagon, APP): stops at the precursor (R3.4).
- **A GPI-anchor signal** (the prion protein's 231-253): drawn as the C-terminal
  extension it is (R3.6), not named as a propeptide.
- **Transmembrane processing** (TNF's shedding, and its and CFTR's membrane
  topology): not in their records, so not drawn; the fold page says which part
  is shown.
- **Homo-oligomers** (TNF, SOD1): one chain, with the assembly in words.
- **One protein from several genes** (AMY1A of three identical AMY1 copies):
  the locus is the one named.
- **A signal peptide and no chain** (erythropoietin): filled (R3.9).
- **A monobasic cut** (vasopressin): named as its residue, captioned without
  "dibasic" (R3.5).

Cases none of the twenty exercise, which a search will meet: non-human proteins;
one protein from two genes that differ (HBA1 and HBA2); selenocysteine (an
in-frame `TGA` that is not a stop); non-AUG starts; several internal
propeptides drawn as such, and C-terminal propeptides named as such; multimers
whose biological unit is not in one entry; a single-exon gene (tested only on a
modified record); and genes whose exons alone exceed the budget.


## 9. ClinVar observed evidence

**R9.1 Observations are separate from predictions.** ClinVar text is quoted
verbatim — classification, review status, conditions, accession/version,
snapshot date — and only there may clinical words appear; the copy tests find
that boundary by the `ClinVarSourced` wrapper. ESM and AVI keep their
molecular/evolutionary wording. Hue belongs to ClinVar alone: a class colour on
a dot, never on text, and the models' band meters are drawn in neutral ink. For
colour only, a record is grouped by its terms, which ClinVar separates with `/`
and puts after a `;` where they are off the Mendelian axis (CFTR's
`Pathogenic; drug response`): any pathogenic
or likely pathogenic term (low penetrance included) and no benign term is P/LP;
any benign term and no pathogenic one is B/LB; both, or a conflicting label, is
Conflicting; uncertain significance with neither is VUS; anything else — risk
alleles, not provided, unfamiliar wording — is Other, drawn as a ring. Risk and
association terms never promote or demote. Where one mark stands for several
records, it takes the most severe group: P/LP, Conflicting, VUS, Other, B/LB.
Conditions are quoted per RCV, under the classification that RCV gives them —
which is what a combined or conflicting label is made of — with the identifiers
ClinVar attaches to each (symbol and OMIM shown; MedGen and MONDO kept), baked
from the same XML. No definition is quoted: MedGen's text is not reliable
enough (type 2 diabetes carries the WFS1 GeneReviews summary, MODY10 only the
generic MODY sentence). The evaluation date stays in the snapshot as
provenance and is not shown.

**R9.2 Exact alleles and the chosen transcript.** ClinVar SNVs must match the
GRCh38 chromosome, coordinate and reference letter, then be converted to the
drawn strand. The selected CDS defines precursor residue numbering. At a tapped
base, only records at that base are shown; at a residue, the scope explicitly
includes its different DNA bases, each row cited by its own c. change. No
clinical record is borrowed from a neighbor. A record's AVI is its own exact
alternative, never the base peak, and its ESM is the score of its own amino
acid, never the residue's constraint; an estimated base gives no number. Records
at one residue are listed in transcript order, which on a minus-strand record
runs against the coordinates. A record in the middle of an intron drawn
shortened is excluded as intron sequence not drawn, a different fact from lying
outside the gene.

**R9.3 Coverage and missingness remain visible — once.** An unbaked gene, a
loading or failed snapshot, and a mapped position with no SNV are different
states. A sheet names only its position's state in one line ("ClinVar · none at
Val26 in this snapshot"). Coverage and exclusion counts live in the overview's
footer and the About sheet, and "not yet included" for a gene without a
snapshot is said in the About sheet alone — never while a snapshot is loading
or has failed. No count is described as a patient count or prevalence, and
absence is never called benign. All twenty genes carry a snapshot since
2026-09-22; the state stays for a row added without one.

**R9.4 The overview is an inspection, not a validation claim.** One mark per
record at its real position: along the protein, height is the record's own AVI,
the band under it is the residue's ESM constraint on the page's ramp, the head
is its class; records off the protein stand on a drawing of the gene, a second
titled panel on the same AVI scale. Filtering never moves a mark, and zooming a
panel to a region (a tap on the ground under it) changes its scale, never a
position; a zoomed intron drawn shortened is titled by its real length. The
list groups records by region, every region open, each closable to its heading
and count from that heading, and builds its rows as they come on screen, since
dystrophin has thousands. A record's link to its residue or base leaves a way back:
Back, or the walk header's "← ClinVar", reopens the overview as it was left —
scroll, open record, filter, regions and zoom. A record's detail may carry one
line on where each model
puts the change — against ESM −7.5 (the line published for ESM-1b, a reference
rather than a calibration) and AVI 20 (the top 1% genome-wide) — or which model
applies at all, in molecular words and never in a list. No count of agreement
with ClinVar is shown anywhere: AVI already integrates protein-level evidence,
AlphaMissense among it, so the two models are not independent votes, and
submitters may have used computational predictions themselves.

**R9.5 Each fact once.** A sheet shows its own model on its bars and carries
the other model's number in its ClinVar rows; the two numbers meet only in an
opened record. What a source is, its scale and its caveats are written once, in
"About these sources" (the overview's footer and the About sheet), and each
sheet's info button explains only its own model's scale. *Status: enforced*
(ClinVar pipeline, entity, widget and walk tests; `check_assets.py`).
