# Verifying the second ten proteins

Before any row, bake or line of code for them, each of the ten genes added after
the first ten was checked against its real GenBank record, NCBI Gene, UniProt
and the PDB. This is what was checked, what was found, and what each finding
changed. The rules the checks come from are in
[protein-pipeline-rules.md](protein-pipeline-rules.md).

Checked 2026-09-17, live: NCBI `efetch` (`gbwithparts`) and `esummary` for
Gene, `rest.uniprot.org`, and RCSB coordinate files. Versions below are the
ones fetched that day. `targets.py` names RefSeqGenes without a version, as the
first ten do, so a later NCBI revision is caught by the bake's gates rather
than by this page.

## What was checked

1. **Span and exons.** The flag for a long gene was five times insulin's record,
   NG_007114.1 at 8,416 bp, so 42,080 bp. Exon counts were compared with
   dystrophin's 79, the most the gene page is tested with.
2. **Neighbouring genes.** Every `gene` feature in the record was listed. The
   backend's own `extract_gene`, which matches `/gene` exactly and
   case-sensitively, was run on each fetched record, insulin included as the
   baseline. The check was whether anything of a neighbour's came back.
3. **The protein.** The record's translation against the UniProt canonical
   sequence, and the record's transcript against MANE Select.
4. **Processing.** Every `sig_peptide`, `proprotein` and `mat_peptide`, mapped
   to residue numbers and set against UniProt's Signal, Chain, Peptide and
   Propeptide features.
5. **Splice sites** of every intron in the transcript.
6. **Assembly.** UniProt's SUBUNIT note.
7. **Structure.** Candidate chains were compared with UniProt residue by residue,
   not only through `SEQADV`, which mis-numbers 1TNF's one deviation.

## Summary

| gene | record | record bp | gene span (× INS record) | exons | neighbours in the record | processing in the record | walk |
|---|---|---:|---:|---:|---|---|---|
| INS (baseline) | NG_007114.1 | 8,416 | 1,431 (0.2×) | 3 | TH, INS-IGF2 | signal, proinsulin, 3 chains | unchanged |
| AVP | NG_008663.1 | 9,169 | 2,169 (0.3×) | 3 | none | signal, 3 chains | cut |
| GCG | NC_000002.12 slice | 10,366 | 9,366 (1.1×) | 6 | LOC101929532 | signal, proprotein, 8 overlapping peptides | stops at the precursor |
| APP | NG_007376.2 | 297,579 | **290,221 (34.5×)** | 18 | APP-DT, RNU6-123P | signal, 15 overlapping peptides | shortened; stops at the precursor |
| CFTR | NG_016465.4 | 257,188 | **188,703 (22.4×)** | 27 | CFTR-AS1, CFTR-AS2, CTTNBP2 | none | shortened; uncut |
| EPO | NG_021471.2 | 9,901 | 3,233 (0.4×) | 5 | none | signal only | cut (chain filled) |
| LEP | NG_007450.1 | 23,351 | 16,352 (1.9×) | 3 | none | signal, 1 chain | cut |
| TNF | NG_007462.1 | 9,763 | 2,772 (0.3×) | 4 | **LTA**, LOC100287329 | none | cut (chains filled) |
| SOD1 | NG_008689.1 | 16,310 | 9,310 (1.1×) | 5 | SOD1-DT | 1 fragment peptide | uncut |
| AMY1A | NC_000001.11 slice | 10,036 | 9,036 (1.1×) | 11 | none | signal, 1 chain (twice) | cut |
| PRNP | NG_009087.1 | 22,438 | 15,133 (1.8×) | 2 | none | signal, 1 chain | cut |

Across all ten:

- **The record's protein equals UniProt's**, residue for residue, so no row
  declares `uniprot_variants`.
- **Splice sites are all GT-AG**, except one GC-AG intron in SOD1. That is a
  real minor class, which R2.3 accepts.
- **No gene has more than 27 exons.**
- **Exact `/gene` matching held on every record.** `extract_gene` returned
  nothing belonging to a neighbour, including TNF's LTA, which carries a signal
  peptide and a mature peptide of its own.
- **The two chromosome slices** follow OXT and RLN2: NCBI Gene's coordinates,
  500 bases either side, fetched on the plus strand.

## Per gene

### AVP · vasopressin

- **Record.** NG_008663.1 (LRG_715). Its transcript is NM_000490.4; MANE Select
  is NM_000490.5, with the same CDS. UniProt P01185.
- **Neighbours.** None, and the one expected is absent. OXT lies about 10 kb
  away on 20p13, tail to tail with AVP, beyond the record's 2 kb downstream
  flank. Nor does OXT's own ±500 bp slice reach AVP.
- **Processing.** Signal peptide 1–19; Arg-vasopressin 20–28; neurophysin 2
  32–124; copeptin 126–164. No `proprotein` feature.
  - Each `/product` carries UniProt qualifier text ("Arg-vasopressin.
    /evidence=…"), which `tidy` already cuts.
  - The gaps are `GKR` (29–31) and a single `R` (125). The second is a
    *mono*basic site, the first in the catalog.
- **Consequence.** The mature caption can no longer say "dibasic" for every
  precursor. The proprotein takes UniProt's name,
  'vasopressin-neurophysin 2-copeptin' (R3.3, table name), as oxytocin's does.
- **Assembly.** Neurophysin dimerises. The hormone is a nonapeptide, so no
  subunit caveat applies.

### GCG · glucagon

- **Record.** No RefSeqGene, so a slice: NC_000002.12:162,142,381–162,152,746.
  The gene sits on the minus strand, 9,366 bp. The slice has no `exon`
  features; exons are named from the mRNA's six segments. NM_002054.5 is MANE
  Select. UniProt P01275.
- **Neighbours.** LOC101929532, a plus-strand lncRNA across the whole slice. It
  is excluded by exact match.
- **Processing.** Signal peptide 1–20; proprotein 'pro-glucagon proprotein'
  21–180. Eight `mat_peptide` features overlap each other:
  - glicentin 21–89, which contains GRPP 21–50, oxyntomodulin 53–89 and
    glucagon 53–81;
  - GLP-1 92–128, which contains GLP-1(7–37) 98–128 and GLP-1(7–36) 98–127;
  - GLP-2 146–178.
  - These are the pancreatic and intestinal alternatives, not one cleavage
    series. UniProt marks the cleavage sites, and names intervening peptides
    84–89 and 131–145.
- **No disulfide bridges** anywhere in the precursor.
- **Consequence.** The bake refuses overlapping peptides. By decision (see
  Flags) the row declares `mature_peptides=False`, as haemoglobin's does. The
  walk ends at the precursor: signal peptide, then pro-glucagon. The fold page
  shows glucagon. Drawing the alternatives is a pattern the app does not have.

### APP · amyloid-beta precursor protein

- **Record.** NG_007376.2 with one transcript, NM_000484.4 (MANE Select),
  encoding the 770-residue isoform (NP_000475.1). UniProt P05067.
- **Span.** 290,221 bp: **34.5× insulin's record, over the threshold.** The
  exons total 3,583 bases, well inside the 24,000-base gene page.
- **Neighbours.**
  - APP-DT, a divergent transcript upstream on the other strand.
  - RNU6-123P, a U6 pseudogene inside an APP intron (232,984–233,085).
  - Both are excluded by exact match.
- **Processing.** Signal peptide 1–17, then fifteen overlapping `mat_peptide`
  features, all inside the chain 18–770: sAPPα 18–687, sAPPβ 18–671, N-APP
  18–286, C99 672–770, Aβ42 672–713, Aβ40 672–711, C83 688–770, P3(42),
  P3(40), C80, the γ-secretase C-terminal fragments 59, 57 and 50, and C31.
  - These are the α- and β-secretase pathways and their γ-secretase products:
    alternatives again, not a series. UniProt records the same set as
    overlapping Chain features.
- **Consequence.**
  - The dystrophin treatment: introns shortened to 1:14, and the caption reads
    "Introns are 98.8% of the gene, drawn shortened".
  - `mature_peptides=False` and a table name for what the signal peptide leaves
    ('amyloid-beta precursor protein'). The walk ends at the precursor.
  - The secretase cuts are flagged below as the future pattern.

### CFTR

- **Record.** NG_016465.4 (LRG_663). Its transcript is NM_000492.3; MANE Select
  is NM_000492.4, with the same CDS. UniProt P13569, 1,480 residues.
- **Span.** 188,703 bp: **22.4×, over the threshold.** The exons total 6,132
  bases.
- **Neighbours.**
  - CFTR-AS1 and CFTR-AS2, antisense genes whose spans hold 2 and 6 CFTR exons.
    Their own exons share no base with CFTR's.
  - CTTNBP2, partial, downstream.
  - All are excluded by exact match.
- **Processing.** None. No signal peptide, no chain features: uncut, like
  dystrophin.
- **Assembly.** UniProt calls it a monomer that may form oligomers, so no
  caveat.
- **Consequence.** The dystrophin treatment: introns at 1:10, "Introns are
  96.8% of the gene". The protein page scrolls at 28pt tiles.

### EPO · erythropoietin

- **Record.** NG_021471.2. NM_000799.4 is MANE Select. UniProt P01588.
- **Neighbours.** None.
- **Processing.** A signal peptide 1–27, joined across exons 1 and 2, and
  **no `mat_peptide`.** UniProt has Chain 28–193.
  - This is the one signal-peptide record in either ten with nothing to cut it
    into. Walked strictly, its protein page would label residues 28–193
    'proprotein', and its gene page would size that stretch with the signal
    peptide's bases included.
- **Consequence.** By decision, a generic bake rule fills the chain from the
  table's pinned UniProt region, so EPO walks like leptin and lysozyme. UniProt
  keeps Arg193 in the chain, although circulating EPO lacks it; the table
  follows UniProt.

### LEP · leptin

- **Record.** NG_007450.1. NM_000230.3 is MANE Select. UniProt P41159.
- **Neighbours.** None.
- **Processing.** Signal peptide 1–21; leptin 22–167. The shape of lysozyme's.
- **Span.** 16,352 bp is under both the threshold and the 24,000-base budget.
  Like myoglobin's and p53's, the gene page keeps 14pt rows and scrolls.

### TNF · tumour necrosis factor

- **Record.** NG_007462.1. NM_000594.4 is MANE Select. UniProt P01375.
- **Neighbours.** This was the check that mattered.
  - **LTA** (lymphotoxin alpha) sits upstream in the same record, with two
    mRNAs, two CDS, two `sig_peptide` and two `mat_peptide` features of its own.
    LTA's synonyms include TNFB and TNFSF1. A prefix or synonym match would have
    handed TNF a signal peptide and a chain.
  - Exact matching returned none of them.
  - LOC100287329, a partial ncRNA, is also present.
- **Processing in the record.** None. UniProt describes what GenBank does not
  annotate: a type II membrane chain 1–233, ADAM17 shedding the soluble form
  77–233 (`Site 76-77 Cleavage; by ADAM17`), and SPPL2A/SPPL2B cuts inside the
  membrane.
  - Since 2026-09-18 the cut comes from the table instead, by the same generic
    rule that fills erythropoietin's chain (R3.9) — the leader there is a signal
    peptide, and here there is none, so the table's chains tile the precursor
    from residue 1.
  - Written as the cut divides the precursor, not as UniProt writes it:
    UniProt's chains overlap (1–233, 77–233, and three more from SPPL2), and a
    page that cuts a precursor into pieces cannot draw one residue twice. The
    two ADAM17 leaves do divide it: `Membrane anchor` 1–76 and `Tumor necrosis
    factor` 77–233.
  - 1–76 is kept, not thrown away: it is the cytoplasmic domain and the
    signal-anchor helix, it stays in the membrane, and membrane TNF signals in
    both directions.
  - The walk now runs gene → mRNA → protein → chains → fold, the gene page
    reads the two pieces instead of its four exons, and the panel numbers the
    soluble chain from 1, so its one bridge reads Cys69–Cys101 rather than
    Cys145–Cys177.
  - The fold page draws the solved soluble part, and its text says so.
- **Assembly.** A homotrimer. The fold page carries the subunit caveat in
  haemoglobin's fields.

### SOD1 · superoxide dismutase 1

- **Record.** NG_008689.1 (LRG_652). Its transcript is NM_000454.4; MANE Select
  is NM_000454.5, with the same CDS. UniProt P00441.
- **Neighbours.** SOD1-DT, a divergent transcript whose exon overlaps SOD1's
  exon 1 on the other strand. It is excluded by exact match.
- **Processing.** One `mat_peptide`: residues 2–21, noted "SOD1 antimicrobial
  peptide 5". It is a fragment inside the finished chain, not a piece the
  precursor is divided into. It is the same class as haemoglobin's hemorphins,
  and without the flag it would be drawn as a 20-residue mature protein. UniProt
  has the initiator methionine removed and Chain 2–154.
- **Splice sites.** One intron is GC-AG.
- **Consequence.** `mature_peptides=False`: uncut, ending at the protein page.
- **Assembly.** A homodimer, so the subunit caveat.

### AMY1A · salivary amylase

- **Record.** No RefSeqGene, so a slice: NC_000001.11:103,655,018–103,665,053.
  The gene is on the plus strand. UniProt P0DUB6, 511 residues.
- **Two transcripts, one protein.**
  - NM_001008221.1 and NM_004038.4 differ only in their first, untranslated
    exon. Their CDS features (NP_001008222.1, NP_004029.2) have identical
    coordinates.
  - NM_004038.4 is MANE Select, but the isoform picker named no transcript. It
    took the mRNA with the fewest bases, NM_001008221.1, which is also the first
    in the file.
- **Consequence.**
  - `Source` gains a `transcript_id`, and the row names NM_004038.4 (R1.1).
    Clipped to that transcript the gene is 8,795 bp.
  - NCBI Gene's count of 12 exons is the union of both transcripts; the drawn
    transcript has 11.
- **Processing.** Signal peptide 1–15; alpha-amylase 1A 16–511, annotated once
  per transcript. `tidy` drops the identical duplicate.
- **Gene-cluster note.**
  - AMY1A, AMY1B and AMY1C are identical copies, a locus whose copy number
    varies between people, beside AMY2A and AMY2B.
  - The slice around AMY1A holds none of them: AMY2A ends about 30 kb before
    it, and AMY1B starts about 23 kb after.
  - The record is unambiguous, but the protein is made by three genes. This is
    the "one protein from several genes" case none of the first ten exercised.
    The page shows the AMY1A locus.
- **Precedent.** It is not the first enzyme: lysozyme already ships as 'the
  enzyme'.

### PRNP · prion protein

- **Record.** NG_009087.1. NM_000311.5 is MANE Select. UniProt P04156.
- **Neighbours.** None.
- **Exons.** Two, with the whole CDS in exon 2.
- **Processing.** Signal peptide 1–22; major prion protein 23–230. Residues
  231–253, UniProt's GPI-anchor propeptide, sit outside the chain.
- **Consequence.** PRNP is cut, so its walk has a mature page, and the gene page
  names 231–253 "the C-terminal extension" (R3.6). The brief expected no
  cleavage; the record disagrees, and the record wins.

## Structures

Each fold page draws one chain. The chains were compared with UniProt residue by
residue.

| protein | entry · chain | method | residues drawn | deviations from UniProt | why this one |
|---|---|---|---|---|---|
| AVP | 7KH0 · L | cryo-EM 2.8 Å | 20–28, bridge C20–C25 | none | the hormone bound to its receptor, as oxytocin's 7RYC is |
| GCG | 6LMK · E | cryo-EM 3.7 Å | 53–81 | none | human glucagon on its receptor; 1GCN is pig |
| APP | 4PWQ · A | X-ray 1.4 Å | 28–189, the E1 domain, 6 bridges | none | its first folded domain at 1.4 Å; no structure covers the whole protein |
| CFTR | 5UAK · A | cryo-EM 3.87 Å | 1,139 of 1,480; missing 1–4, 403–438, 646–843 (the R region), 884–908, 1173–1206, 1437–1480 | none | wild type; 6MSM, 7SVD and 8UBR carry E1371Q |
| EPO | 1EER · A | X-ray 1.9 Å | 28–193, 2 bridges | N51K, N65K, N110K, P148N, P149S | every EPO entry carries the glycosylation-site mutants; best resolution |
| LEP | 1AX8 · A | X-ray 2.4 Å | 24–167 less 46–59, 1 bridge | W121E | best resolution and coverage of leptin alone |
| TNF | 7JRA · A | X-ray 2.1 Å | 81–233, 1 bridge | none | best coverage of the wild-type entries checked; its bound compound is not drawn. Apo 1TNF has Leu at 219, where UniProt has Asp (its `SEQADV` numbers that residue 45) |
| SOD1 | 2C9V · A | X-ray 1.07 Å | 2–154, bridge C58–C147 | none | wild type, atomic resolution. The entry numbers from Ala2, so its C57–C146 is UniProt's 58–147 |
| AMY1A | 1SMD · A | X-ray 1.6 Å | 16–511, 5 bridges | none | wild type; 1Z32, 3BLP and 1JXJ are point mutants |
| PRNP | 4KML · A | X-ray 1.5 Å | 117–225, bridge C179–C214 | none | wild type and experimental; like the NMR entries (1QLX), it resolves only the folded C-terminal domain |

## Flags

1. **APP and CFTR are over the span threshold.** Decided: the dystrophin
   treatment, with introns shortened and exons whole. Both sets of exons fit
   the page (3,583 and 6,132 bases against 24,000), both genes have far fewer
   exons than dystrophin's 79, and the scale is said on the page. Nothing new
   was built.
2. **GCG and APP process their precursors into alternative products.**
   - Decided: the walk stops at the precursor (`mature_peptides=False`), and
     the fold page's text names what is not drawn.
   - A page that shows tissue-specific or pathway-specific cleavage is a new
     pattern. Glucagon versus GLP-1 and GLP-2; APP's α-, β- and γ-secretase
     products.
3. **EPO annotates a signal peptide and no chain.** Decided: the chain is
   filled from the pinned UniProt region by a generic bake rule, and the
   rule's gate is its translation.
4. **AMY1A is one protein from three identical genes**, and its record's two
   transcripts share one CDS. The transcript is now named in the row.
5. **SOD1's fragment is not processing the walk can show.** It is residues
   2–21, an antimicrobial fragment of the finished enzyme rather than a piece it
   is cut into, so its walk ends at the protein page. TNF's shedding was in the
   same paragraph until 2026-09-18: it is absent from the record but it is a
   real cut that divides the precursor, so it now comes from the table (R3.9).
6. **The record is newer than the RefSeqGene for AVP, CFTR and SOD1.** MANE
   Select is one version ahead of the transcript each RefSeqGene carries, with
   an identical CDS. The pages draw the RefSeqGene's.
7. **The live backend is further behind the fixtures.** It still cannot serve a
   chromosome slice (now GCG and AMY1A too). It does none of the fixture-only
   transforms, which grow from four to six: the chain fill and the named
   transcript join the other four.

## Where the brief and the data disagreed

- **Five states.** The walk has no separate CDS page. The coding sequence is
  the framed middle block of the mRNA page, with its codons grooved, and the
  fold is always the last page.
- **"Glucagon, TNF, SOD1 and PRNP likely have no `mat_peptide`."** Only TNF
  has none, and its two chains are pinned in the table instead.
  - GCG has eight and stops at the precursor by decision.
  - SOD1 has a fragment and stops at the protein page.
  - PRNP is genuinely cut.
  - "No cleavage" is still exercised by TNF, CFTR and SOD1, alongside
    haemoglobin, myoglobin, p53 and dystrophin.
- **"AMY1A is the first enzyme."** Lysozyme is. The search for hormone- or
  secretion-shaped assumptions still found three, each fixed for every
  protein:
  - "dibasic" said of every cut;
  - a start-codon note implying every chain is secreted;
  - "the other 109" hard-coded in the residue panel.
- **The same search found a fourth, left as it is.** The palette mutes a
  record's second chain by position, which suits a C-peptide. Vasopressin's
  neurophysin 2 is muted exactly as oxytocin's neurophysin 1 already is.
- **"A single-exon gene."** None of the ten has one. The single-exon mRNA page
  is covered by the synthetic cases in
  `test/features/gene_lookup/anatomy/anatomy_stages_test.dart`. PRNP, with its
  CDS inside exon 2, is the nearest.
- **"Only insulin is ESM-scored."** All of the first ten are. The second ten
  are not, by decision, and the app now treats "not scored" as a state rather
  than a missing file.

## After integration

The rows were added only once the checks above were written down. The ten were
then baked with `--target` (the first ten's records and tracks stayed byte for
byte), and every bake gate passed: the frame, UniProt, the overlap check. The
walk each one derives:

| protein | pages | protein page | mature page |
|---|---|---|---|
| vasopressin | gene, mRNA, protein, mature, fold | signal peptide 19 · vasopressin-neurophysin 2-copeptin 145 | Arg-vasopressin 9 · neurophysin 2 93 · copeptin 39: "Two cuts release three chains." |
| glucagon | gene, mRNA, protein, fold | signal peptide 20 · pro-glucagon proprotein 160 | — |
| APP | gene (shortened), mRNA, protein, fold | signal peptide 17 · amyloid-beta precursor protein 753 | — |
| CFTR | gene (shortened), mRNA, protein, fold | one block, 1,480 | — |
| erythropoietin | gene, mRNA, protein, mature, fold | signal peptide 27 · Erythropoietin 166 | "One chain, cut from the precursor." |
| leptin | gene, mRNA, protein, mature, fold | signal peptide 21 · leptin 146 | same |
| TNF | gene, mRNA, protein, fold | one block, 233 | — |
| SOD1 | gene, mRNA, protein, fold | one block, 154 | — |
| amylase | gene, mRNA, protein, mature, fold | signal peptide 15 · alpha-amylase 1A 496 | same |
| prion protein | gene, mRNA, protein, mature, fold | signal peptide 22 · proprotein 231 | Major prion protein 208; the gene page names 231-253 "the C-terminal extension" |

The gene pages' own captions: APP "18 exons, separated by 17 introns. Introns
are 98.8% of the gene, drawn shortened; exons are to scale."; CFTR "27 exons,
separated by 26 introns. Introns are 96.8% …"; amylase "Eleven exons, separated
by ten introns."; the prion protein "Two exons, separated by one intron."

Checked, and how:

- **`check_assets.py`**: twenty targets, ten scored. Every record re-proves its
  frame, its pieces at their own offsets and its splice sites from its own
  bytes.
- **`flutter analyze`** is clean. **`flutter test`** passes, and its catalog
  walk takes all twenty proteins through the real screen page by page. It
  expects the conservation toolbar on exactly the ten scored protein pages.
- **The simulator**: iPhone 17 Pro, iOS 26.2, Impeller, mock data. Each of the
  ten walks was opened and stepped to its fold, driven through the debug VM
  service rather than by touch, and every model rendered:
  - TNF and SOD1 read "the subunit" with their assembly sentence;
  - glucagon's helix has no bridge node;
  - CFTR is drawn at the lowest cartoon sampling, so its helices are visibly
    faceted — the price of keeping its compiled scene near half a megabyte;
  - leptin's protein page has no toolbar and no error.

Not checked on a device: taps and swipes by touch on the ten new walks. The
tracer, codon grooves and cut-site marks they use are the same code the widget
tests exercise on every protein's record. The residue panel exists only for
scored proteins, so none of the ten has one.

## Scored, 2026-09-17

Later the same day all ten were scored with ESM-2, so every protein page in the
catalog now carries the conservation toolbar and the residue panel. The checks
above describe the catalog as it stood before that: ten scored, and no panel on
any of these ten. Scoring changed three things, each by a rule rather than for
one protein:

- **TNF's row gained its disulfide.** UniProt annotates Cys145–Cys177, which
  its fold page already named and drew from 7JRA; the row had left it out. In
  the track the two rank first and second of 233.
- **The publish gate stopped reading offsets off cysteine ranks.** That rule
  refused SOD1, leptin and amylase, whose bridges are genuinely less constrained
  than their metal site, helix core, or other bridges. It now checks directly
  that each score sits on its own residue, on every protein.
- **A cut precursor's unnamed end is an extension.** Glucagon's trailing RK,
  179–180, was named for the chain in the track's region table, so the panel
  would have said "removed with Proglucagon". It now reads "C-terminal
  extension", as R3.6 names such residues on the gene page.

What each track measured, and why the gate changed, is in
[pipeline/constraint/verification.md](../../helix-peek-backend/pipeline/constraint/verification.md).

## Gene page labels, 2026-09-18

Every region of the gene page is named, and every name is written on the region
it names. `planRunLabels` (`anatomy_run_labels.dart`) sets a name across the run
itself and nowhere else: the type is cut to fit the run's width — as far as
`runLabelFloor`, eight points, against the eleven a run earns — and past that
the name is abbreviated, through the rungs `StageRun.writtenForms` offers.

Names used to go in a pill beside the run with a leader back to it when they
would not fit inside. The pill avoided other names and other pills but nothing
stopped it landing on another *run*, and on a phone it routinely did: p53's
`exon 3` was named over `exon 4`, myoglobin's `3' UTR` over its last exon. A
name on the wrong colour is that colour's name. Pills and leaders are gone.

Only the category word is ever abbreviated, so what tells two runs apart always
survives: `intron 10` goes to `int. 10` and then `I10`, `5' UTR` to `5'UTR` and
then `5'U`, `signal peptide` to `sig. peptide` and then `SP`, `Relaxin B chain`
to `B chain` and then `B`. A peptide's name is the record's own and is clipped
but never initialled — the first letters of `cystic fibrosis transmembrane
conductance regulator` read as CFTR and are not it. An exon inside an uncut
coding sequence is a `RoleKind.coding` role carrying its exon's name, so the
rungs are chosen off the ordinal rather than off the kind.

Punctuation is the exception, and is never abbreviated to get itself named: a
feature under `regionFloor` — fifteen bases, five codons — is the stop codon, a
protease's `RR`, `KR`, `GKR` or `RKKR` site, or the stray residue or two trimmed
off a cut precursor's ends. Each is read off the colours either side of it, and
each is still named on a tap. Where its own cells hold its whole name it is
written, as it always was — insulin's `KR site` on a phone, a stop codon on a
tablet. The floor is measured on the feature and not on the run, so a signal
peptide split across two exons is still a 72-base signal peptide and keeps its
name.

`anatomy_run_labels_test.dart` holds every catalog gene to that on the phone
viewport the screen really gives the canvas (390×844), on 360×480 and on
820×960, with the app's own fonts — including, for every name, that the box it
is set in lies inside its own run's cells on every row it crosses.

What the catalog actually needs, at 360×676, 360×480 and 820×960:

| rung | where |
|---|---|
| the name whole | every run of every gene but the four below |
| the category word clipped | APP's signal peptide (`sig. peptide`), PRNP's C-terminal extension (`C-ter. ext.`) |
| the shortest rung | p53's `exon 3` (`E3`), EPO's signal peptide on a 360×480 phone (`SP`) |
| unnamed, named on another piece of the same feature | GCG's 5' UTR (9 cells of 99), PRNP's 5' UTR (10 cells of 67) |

No region of any catalog gene goes unnamed at any of the three viewports without
another piece of it carrying the name. The smallest any name is set is 8.0pt —
EPO's signal peptide, thirteen cells of it, on a 360-point phone.

## The third ten, 2026-10-17

Ten more curated proteins, each landing in a cell type none of the twenty
reach (the zoom's path, Protein Atlas 25.1). Each was drafted from its gene by
the backend's `scripts/draft_curated.py`: the resolver's own reading of its
index row, UniProt and MANE (source, regions, disulfides), and its fold chosen
by policy 1, baked and passed by the app's own check of a fold
(`test/fold_bundle_check.dart`). The model is cut from the working copy that
bake was made from (`structure/structures/working/<slug>.pdb`), in the record's
numbering. Then each gene was checked against its record, as the second ten
were, with the same seven checks.

Checked 2026-10-17, live: NCBI `efetch`, UniProt release 2026_03, RCSB and
PDBe. As for the twenty, `targets.py` names a RefSeqGene without its version,
so a later revision is caught by the bake's gates; a chromosome slice keeps its
version and coordinates.

### Summary

| gene | record | record bp | gene span (× INS record) | exons | neighbours in the record | processing in the record | walk |
|---|---|---:|---:|---:|---|---|---|
| PLN | NG_009082.1 | 19,146 | 12,146 (1.4×) | 2 | CEP85L, around it | none | uncut |
| S100B | NC_000021.9 slice | 6,479 | 6,479 (0.8×) | 3 | none | none | uncut |
| CGB3 | NC_000019.10 slice | 1,465 | 1,465 (0.2×) | 3 | none | signal, 1 chain | cut |
| PPBP | NC_000004.12 slice | 1,752 | 1,752 (0.2×) | 3 | none | signal, proprotein, 4 nested products | stops at the precursor |
| PAPPA | NC_000009.12 slice | 248,531 | **248,531 (29.5×)** | 22 | PAPPA-AS1, PAPPA-AS2 | signal, 1 chain | shortened; cut |
| CSTB | NG_011545.1 | 9,429 | 2,711 (0.3×) | 3 | none | none | uncut |
| TYRP1 | NG_011705.1 | 23,881 | 16,901 (2.0×) | 8 | LURAP1L-AS1 | signal, 1 chain | cut |
| RCVRN | NC_000017.11 slice | 8,952 | 8,952 (1.1×) | 3 | none | none | uncut |
| TG | NG_015832.2 | 274,942 | **267,942 (31.8×)** | 48 | RPL21P78, SLA, MIR7848, PTCSC1 | signal, 1 chain | shortened; cut |
| UMOD | NG_008151.1 | 26,665 | 19,665 (2.3×) | 11 | none | signal, proprotein, 2 nested chains | stops at the precursor |

Across all ten:

- **The record's protein equals UniProt's**, residue for residue, so no row
  declares `uniprot_variants`.
- **Every intron is a class R2.3 accepts**: the record of each re-proves its
  splice sites as it is built (`check_assets.py`).
- **Exact `/gene` matching held on every record.** Nothing of a neighbour's
  came back, the genes lying inside the gene's own introns included (PLN inside
  CEP85L, four genes inside TG).
- **The slices are MANE's span**, the resolver's rule, not NCBI Gene's
  coordinates and 500 bases either side, which the twenty's four slices are. A
  record is clipped to its transcript either way (R1.4).
- **Two RefSeqGenes hold an older version of the MANE transcript**, with the
  same CDS: PLN's NM_002667.3 (MANE NM_002667.5) and CSTB's NM_000100.3
  (NM_000100.4). The pages draw the RefSeqGene's, as for AVP, CFTR and SOD1.
- **Two of the ten planned did not pass their bakes.** PLN's ESM-2 track fails
  the alignment gate, and PLN is drawn unscored; PF4's AVI track fails the
  biology check, and PPBP took its place. Both are the user's choices of
  2026-10-17 (Flags).

### Per gene

#### PLN · phospholamban

- **Record.** NG_009082.1. UniProt P26678. One CDS, NP_002658.1.
- **Neighbours.** CEP85L spans the whole record on the other strand: PLN lies
  in one of its introns. Excluded by exact match.
- **Processing.** None. UniProt's one chain is 1–52, with a cytoplasmic part
  (1–31) and one helix through the membrane (32–52).
- **Assembly.** A homopentamer; it also binds the calcium pump ATP2A2 as a
  monomer. The fold page draws one chain of the NMR pentamer, and says so.

#### S100B

- **Record.** No RefSeqGene, so a slice: NC_000021.9:46,598,604–46,605,082,
  minus strand, no `exon` features (exons named from the mRNA's three
  segments). NM_006272.3 is MANE Select. UniProt P04271.
- **Processing.** None in the record. UniProt removes the initiator
  methionine and names the chain 2–92: hemoglobin's and myoglobin's case,
  uncut, with the methionine its own region.
- **Assembly.** A dimer. Its entry, 5D7F, holds the calcium-bound pair with a
  peptide of RAGE; one chain is drawn.

#### CGB3 · hCG beta subunit

- **Record.** A slice: NC_000019.10:49,022,869–49,024,333, minus strand, 1,465
  bases, nothing else in it. NM_000737.5 is MANE Select. UniProt P0DN86.
- **One protein from three genes.** UniProt's entry names CGB3, CGB5 and CGB8:
  identical copies in the beta-subunit cluster on 19q13.33. The record is
  unambiguous and the page shows the CGB3 locus: amylase's case.
- **Processing.** Signal peptide 1–20; the beta chain 21–165. Its `/product`
  carries UniProt's `/id=` qualifier, which `tidy` already cuts.
- **Assembly.** hCG is a heterodimer of this chain and the alpha chain it
  shares with LH, FSH and TSH (CGA). Only this gene's chain is drawn (R5.1).

#### PPBP · pro-platelet basic protein (CXCL7)

- **In place of PF4.** Platelet factor 4 (NG_032897.1, P02776) was verified
  and baked first. Its AVI track fails the bake's biology check: its exons'
  median score equals its intron interiors' (7.4 and 7.4), though every one of
  its 1,217 reference bases agrees, so its map is right. Without AVI there is
  no ClinVar either. PPBP, the next gene of the chemokine cluster and the
  handoff's alternate, lands in the same platelets and passes.
- **Record.** No RefSeqGene, so a slice: NC_000004.12:73,986,439–73,988,190,
  minus strand, no `exon` features. NM_002704.3 is MANE Select. UniProt
  P02775.
- **Processing.** Signal peptide 1–34; the proprotein 35–128 ("pro-platelet
  basic protein"); and four products, one inside another: LA-PF4/CTAP-III and
  thrombocidin-2 (44–128), beta-thromboglobulin (48–128), thrombocidin-1
  (59–126). UniProt names eleven such forms, NAP-2 among them.
- **Consequence.** Alternatives, cut by different proteases:
  `mature_peptides=False` and the walk stops at the precursor, named by the
  record's own proprotein.
- **Structure.** 1F9P is CTAP-III (44–128), one chain, solved with
  polyvinylsulfonic acid.

#### PAPPA · pappalysin-1

- **Record.** A slice: NC_000009.12:116,153,791–116,402,321, 248,531 bases.
  NM_002581.5 is MANE Select. UniProt Q13219, 1,627 residues.
- **Span.** **29.5× insulin's record, over the threshold.** The exons total
  10,971 bases, inside the page: dystrophin's treatment, introns shortened.
- **Neighbours.** PAPPA-AS1 and PAPPA-AS2, antisense inside the gene. Excluded
  by exact match.
- **Processing.** Signal peptide 1–22; pappalysin-1, 82–1627. UniProt's
  propeptide between them, 23–81, is not in the record.
- **Consequence.** The gene and mature pages draw 23–81 as the N-terminal
  extension (R3.6), as the prion protein's GPI-anchor signal is drawn as the
  C-terminal one; the table names it "Propeptide" for the residue panel. What
  the signal peptide leaves is named "pro-PAPP-A" in the table (R3.3).
- **Assembly.** A disulfide-linked homodimer, and in pregnancy serum a 2:2
  complex with proMBP, which is the entry drawn (8HGG).

#### CSTB · cystatin B

- **Record.** NG_011545.1. Its transcript is NM_000100.3; MANE Select is
  NM_000100.4, with the same CDS. UniProt P04080.
- **Processing.** None: UniProt's chain is 1–98, the methionine kept.
- **Assembly.** Monomeric, able to dimerise. Its entry, 4N6V, holds ten chains;
  the one drawn is the compact cystatin fold, its helix packed on its own sheet
  (measured: radius of gyration 12.4 Å over 91 CA atoms), not a domain-swapped
  one.

#### TYRP1

- **Record.** NG_011705.1. NM_000550.3 is MANE Select. UniProt P17643.
- **Neighbours.** LURAP1L-AS1, antisense over the gene's 3′ part. Excluded by
  exact match.
- **Processing.** Signal peptide 1–24; the chain 25–537, which crosses the
  melanosome's membrane at 478–501.
- **Structure.** 9EY8 holds the part inside the melanosome, 25–471: the
  membrane helix and the tail were not in the crystal.

#### RCVRN · recoverin

- **Record.** A slice: NC_000017.11:9,896,320–9,905,271, minus strand.
  NM_002903.3 is MANE Select. UniProt P35243.
- **Processing.** None in the record; UniProt removes the methionine and
  myristoylates Gly2. Uncut, as S100B.
- **Structure.** 2D8N is a selenomethionine crystal: its four MSE residues are
  drawn as the methionines the gene makes. No calcium and no myristoyl group
  are in the entry.

#### TG · thyroglobulin

- **Record.** NG_015832.2. NM_003235.5 is MANE Select. UniProt P01266, 2,768
  residues.
- **Span.** **31.8×, over the threshold.** The exons total 8,455 bases:
  introns shortened.
- **Neighbours.** RPL21P78, SLA (with MIR7848 inside it) and PTCSC1, all inside
  TG's introns. Excluded by exact match.
- **Processing.** Signal peptide 1–19; thyroglobulin 20–2768.
- **Assembly.** A homodimer, stored in the follicle as disulfide-linked
  oligomers; 7B75 is the dimer, one chain drawn.

#### UMOD · uromodulin

- **Record.** NG_008151.1. NM_003361.4 is MANE Select. UniProt P07911.
- **Processing.** Signal peptide 1–24; the proprotein 25–640 ("uromodulin
  isoform a proprotein"); and two chains, uromodulin 25–614 and its secreted
  form 25–587, one inside the other. UniProt: GPI-anchored at Ser614 (615–640
  removed), and cut by hepsin at 587–588 to release the secreted form.
- **Consequence.** Alternatives, as glucagon's and APP's: `mature_peptides=False`
  and the walk stops at the precursor. The table names 615–640 the GPI-anchor
  signal, as the prion protein's.
- **Assembly.** Polymerises into filaments in urine. The fold page draws the
  ZP domain from those filaments.

### Structures

| protein | entry · chain | method | residues drawn | deviations from UniProt | why this one |
|---|---|---|---|---|---|
| PLN | 1ZLL · A | NMR, model 9 | 1–52 | none | the region drawn is measured residue by residue; 2HYN's is not |
| S100B | 5D7F · A | X-ray 1.3 Å | 2–91 | none | finer than 3CZT (1.4 Å) |
| CGB3 | 7FIG · Y | cryo-EM 3.9 Å | 22–131, 6 bridges | none | measured residue by residue; 1HCN is not |
| PPBP | 1F9P · A | X-ray 1.93 Å | 44–124 (CTAP-III), 2 bridges | none | policy 1's first |
| PAPPA | 8HGG · C | cryo-EM 3.64 Å | 93–1616, 36 bridges | none | 96% of it placed against 72%; chain D, its twin, narrowly fails the app's check |
| CSTB | 4N6V · 2 | X-ray 1.8 Å | 8–98 | none | the only one eligible; 1STF and 2OCT carry substitutions |
| TYRP1 | 9EY8 · AA | X-ray 2.2 Å | 25–471, 7 bridges | none | finer than 9EY6 (2.23 Å) |
| RCVRN | 2D8N · A | X-ray 2.2 Å | 2–197 | none; four selenomethionines drawn as Met | the only one eligible |
| TG | 7B75 · A | cryo-EM 3.2 Å | 30–2727, 57 bridges | none | finer than 6SCJ (3.6 Å) |
| UMOD | 9NU1 · A | cryo-EM 3.6 Å | 329–580 (the ZP domain), 4 bridges | none | 6TQL, ranked first (292–584), fails the app's check of its fold (a step of 1.16 where 1.1 is allowed); the user's choice |

### Flags

1. **PAPPA and TG are over the span threshold.** Their exons fit the page, so
   they take dystrophin's treatment, introns shortened, as APP and CFTR do.
2. **PPBP and UMOD stop at the precursor**, by R3.4: their records name
   products one inside another. PF4's would have too: its record names a short
   form inside its chain, a fragment of the finished chain rather than an
   alternative, which a rule dropping such fragments would have let through to
   a mature page; R3.4's generic rule is still open.
3. **PAPPA's N-terminal propeptide is drawn as an extension** (R3.6). Naming a
   propeptide between the leader and the chain on the walk, as R3.5 names a
   connecting one, is open, beside the C-terminal propeptides of §8.
4. **UMOD's entry is not the one first planned.** The handoff's 6TQL came from
   a dry run that chose without baking; baked, its fold fails the app's own
   check, and policy 1's next entry, 9NU1, passes.
5. **CGB3 is one protein from three genes**, the case AMY1A brought in.
6. **The zoom.** Six of the ten land in organs with no study: the heart (PLN),
   the placenta (CGB3, PAPPA), the esophagus (CSTB), the thyroid (TG) and the
   kidney (UMOD), each drawn as the body's own outline with its plain surface.
   PPBP's platelets have no nucleus, so the zoom lands in the megakaryocyte;
   recoverin's rod is drawn as a neuron, part by part.
7. **PLN is drawn unscored.** ESM-2 prefers the residue there over its
   neighbour 40.0% of the time (before) and 46.7% (after) across its 52
   residues, under the half the alignment gate asks: the short-protein case SLN
   met on demand. Its protein page has no conservation toolbar, a state the walk
   already draws; the gate is unchanged (the user's choice, 2026-10-17).
8. **PF4 gave way to PPBP** (above): AVI's biology check is a smoke alarm for a
   misplaced map, and is kept as it is.

### After integration

Baked 2026-10-17 by `pipeline/bake_curated.py`: every step for every row, in
its own environment, then `check_assets.py`, `check_folding.py` and
`check_locus.py` over all thirty rows. Each model is the `.glb` the draft's bake
made from the same working copy, and passed the app's check of its fold again
(`structure/check_bundle.py`). ESM-2 took 35 minutes for TG and 20 for PAPPA;
nine of the ten are scored.

| protein | pages | protein page | mature page |
|---|---|---|---|
| phospholamban | gene, mRNA, protein, fold | one block, 52 | — |
| S100B | gene, mRNA, protein, fold | one block, 92 | — |
| hCG beta | gene, mRNA, protein, mature, fold | signal peptide 1–20 · Choriogonadotropin subunit beta 3 21–165 | Choriogonadotropin subunit beta 3 (145) |
| PPBP | gene, mRNA, protein, fold | signal peptide 1–34 · pro-platelet basic protein 35–128 | — |
| PAPP-A | gene (shortened), mRNA, protein, mature, fold | signal peptide 1–22 · pro-PAPP-A 23–1,627 | Pappalysin-1 (1,546) |
| cystatin B | gene, mRNA, protein, fold | one block, 98 | — |
| TYRP1 | gene, mRNA, protein, mature, fold | signal peptide 1–24 · 5,6-dihydroxyindole-2-carboxylic acid oxidase 25–537 | the same chain (513) |
| recoverin | gene, mRNA, protein, fold | one block, 200 | — |
| thyroglobulin | gene (shortened), mRNA, protein, mature, fold | signal peptide 1–19 · thyroglobulin 20–2,768 | thyroglobulin (2,749) |
| uromodulin | gene, mRNA, protein, fold | signal peptide 1–24 · uromodulin isoform a proprotein 25–640 | — |

The two shortened genes' pages read "22 exons · 21 introns · introns 95.6% of
span, drawn shortened" (PAPP-A, 1:18) and "48 exons · 47 introns · introns
96.8% of span, drawn shortened" (thyroglobulin, 1:17).

Checked, and how:

- **Live.** Seeded, then every track uploaded (the seed first: a track row
  names its protein's). `seed_catalog.py --check`: 30 rows, 0 differences;
  `check_assets.py --against` the service: 30 rows agree with both tables,
  every record byte for byte, every scene by its digest; `/catalog` 30 rows in
  order; `live_backend_check.dart` reads every track of every row through the
  production client.
- **The app.** The ten's fixtures, written from the bakes before anything was
  live and compared with storage's after (`pipeline/sync_fixtures.py`, 70
  files the same); `flutter analyze` clean; `flutter test` 1,748 passed, the
  walk's tests running on all thirty.
- **What the tests met that the twenty never had.** An unscored curated
  protein (phospholamban): five walk tests read a constraint track only where a
  protein is scored (R6). A mature chain of over a thousand residues, whose
  caption groups its count (R4.4): the caption test reads "(1,546)". A protein
  the Atlas finds in the nucleoli (cystatin B): the zoom names the nucleolus by
  the protein's own name, and its tests now say so. Organs reached for the
  first time, the skin (TYRP1) and the eye (recoverin): their drawings had no
  outline, and now have the one they draw. Each was the user's call.

## The fourth batch: eight cell types, 2026-10-18

Eight more curated proteins, one for each of the eight cell types most human
proteins land in that no curated protein reached (the zoom's path over the
Protein Atlas; `zoom-cell-coverage` counts 204 cell types, of which the thirty
used 26). Picked by running the locus bake's own path rule over all 19,300
proteins, then the structure choice (`scripts/dry_fold.py`) over about ninety
candidates: 73 in the first pass and 18 more for oligodendrocytes. Drafted,
verified, worded and baked exactly as the third ten were.

Checked 2026-10-18, live: NCBI `efetch`, UniProt release 2026_03, RCSB and
PDBe.

### Summary

| cell type | gene | record | gene span (× INS record) | exons | neighbours in the record | processing in the record | walk |
|---|---|---|---:|---:|---|---|---|
| Early spermatids | IZUMO1 | NC_000019.10 slice | 6,058 (0.7×) | 10 | none | signal, 1 chain | cut |
| Late spermatids | GAPDHS | NG_046898.1 | 11,864 (1.4×) | 11 | TMEM147, TMEM147-AS1 | none | uncut |
| Neutrophils | FPR1 | NG_023426.1 | 6,125 (0.7×) | 2 | none | none | uncut |
| Adrenal cortex cells | CYP17A1 | NG_007955.1 | 6,883 (0.8×) | 8 | none | none | uncut |
| Oligodendrocytes | B3GAT1 | NC_000011.10 slice | **33,735 (4.0×)** | 6 | none | none | shortened; uncut |
| Spermatocytes | DMC1 | NG_017203.2 | **51,236 (6.1×)** | 14 | RPS29P31, LOC105373031 | none | shortened; uncut |
| Brain excitatory neurons | DNM1 | NG_029726.1 | **51,866 (6.2×)** | 22 | CIZ1, GOLGA2, MIR199B, MIR3154 | none | shortened; uncut |
| Choroid plexus epithelial cells | LGI1 | NG_011832.2 | **40,224 (4.8×)** | 8 | none | signal, 1 chain | shortened; cut |

Every translation equals its UniProt sequence exactly, and every record's
`/gene` match is exact: a neighbour sharing the record is excluded by name, as
CEP85L is for PLN.

### Structures

| protein | entry · chain | method | residues drawn | why this one |
|---|---|---|---|---|
| IZUMO1 | 5JK9 · A | X-ray 2.1 Å | 22–255, 5 bridges | policy 1's first; the crystal's other five copies are not drawn |
| GAPDHS | 3H9E · A | X-ray 1.72 Å | 74–407 | one chain of the tetramer, solved with NAD |
| FPR1 | 7VFX · A | cryo-EM 2.8 Å | 22–316, 1 bridge | the receptor alone, from its complex with fMIFL and a G protein |
| CYP17A1 | 6WW0 · A | X-ray 2.01 Å | 31–503 | solved with its heme and an abiraterone analogue |
| B3GAT1 | 1V84 · A | X-ray 1.82 Å | 83–334 | one chain of two, with UDP, manganese and its substrate sugar |
| DMC1 | 7C9C · A | cryo-EM 3.3 Å | 22–337 | one chain of the pre-synaptic filament on single-stranded DNA |
| DNM1 | 8SXZ · A | cryo-EM 3.3 Å | 693 of 864 placed | the polymer in its constricted state on a membrane neck |
| LGI1 | 9KZT · A | cryo-EM 3.8 Å | 35–557 | one LGI1 chain of the 3:3 complex with ADAM22 |

### Flags

1. **Four genes are over the span threshold** and take dystrophin's treatment,
   introns shortened (R2.4): B3GAT1, DMC1, DNM1 and LGI1. B3GAT1's 1:1.5 is the
   mildest shortening in the catalog.
2. **Two candidates were swapped after the app's own tests refused them**, and
   both refusals are limits of the pages, not of the data:
   - **Autotaxin (ENPP2)** for the choroid plexus. Its propeptide, which furin
     removes, is 8 residues: 24 bases on the gene page, too narrow to carry even
     "N-ter. ext.", and the feature appears nowhere else, so
     `anatomy_run_labels_test` found a region with no name. PAPP-A's extension
     is 59 residues and fits. LGI1 took its place. **Open:** a region above
     `regionFloor` but under about 30 bases, appearing once, cannot be named;
     any protein built on demand with a short propeptide meets it.
   - **Cerebellin-1 (CBLN1)** for excitatory neurons. The Atlas gives it six
     subcellular locations (cytosol, flagellar centriole, mid piece, principal
     piece, perinuclear theca, calyx), and the sixth name falls 336 px off the
     left of the canvas, which `cell_scene_test` caught. Recoverin's two fit.
     Dynamin-1, with none, took its place. **Open:** the names round the cell
     fit three or four, not six.
3. **IZUMO1's and LGI1's summaries were reworded** to keep "ins" out of them:
   `search_surface_test` pins how many rows the phone shows for that query, and
   "joins" and "against" both carry it. A fifth curated match pushed a
   suggestion below the fold.
4. **LGI1's bridges are the entry's, not the knowledgebase's.** 9KZT places
   five disulfide bridges; UniProt annotates none. The row lists none, so the
   facts say none and the fold draws none, and the screen-reader text says the
   entry's five are not drawn.
5. **Three cell types are germ cells** (early spermatids, late spermatids,
   spermatocytes), which the zoom draws with one recipe: the three pages name
   different Atlas cells and draw the same meiotic cell.
6. **The zoom needed no change.** Testis and bone marrow already have organ
   studies, the adrenal gland is outlined on the body figure, and the brain and
   choroid plexus are drawn as the brain.
7. **Cell types with no protein to pick.** Late spermatids had exactly one
   candidate with any experimental entry (GAPDHS): protamines 1 and 2, the
   genes most raised there, are drawn by no structure.

### After integration

Baked 2026-10-18 by `pipeline/bake_curated.py`, eleven steps each in its own
environment, then `check_assets.py`, `check_folding.py` and `check_locus.py`
over all thirty-eight rows. Every model is the one the draft's bake made and the
app's own fold check passed (`structure/check_bundle.py`); every ESM-2
alignment gate passed with room (78.2% at the lowest, LGI1's 91.6% at the
highest, against the 50% it asks).

| protein | pages | protein page | mature page |
|---|---|---|---|
| IZUMO1 | gene, mRNA, protein, mature, fold | signal peptide 1–21 · Izumo sperm-egg fusion protein 1 22–350 | the same chain (329) |
| GAPDHS | gene, mRNA, protein, fold | one block, 408 | — |
| FPR1 | gene, mRNA, protein, fold | one block, 350 | — |
| CYP17A1 | gene, mRNA, protein, fold | one block, 508 | — |
| B3GAT1 | gene (shortened), mRNA, protein, fold | one block, 334 | — |
| DMC1 | gene (shortened), mRNA, protein, fold | one block, 340 | — |
| Dynamin-1 | gene (shortened), mRNA, protein, fold | one block, 864 | — |
| LGI1 | gene (shortened), mRNA, protein, mature, fold | signal peptide 1–34 · Leucine-rich glioma-inactivated protein 1 35–557 | the same chain (523) |

Checked, and how:

- **Live.** Seeded first, then every kind uploaded (a track row names its
  protein's): 8 proteins, 43 aliases, 48 track rows, and 64 objects.
  `seed_catalog.py --check`: 38 rows, 0 differences; `check_assets.py --against`
  the service: 38 rows agree with both tables; `/catalog` is 38 rows, orders 0
  to 37 complete; `/proteins/resolve/DNM1` reads `ready` at `dynamin1`;
  `fetch_tracks.py --check` 268 files as stored; `live_backend_check.dart` reads
  every track of every row through the production client.
- **The app.** The eight's fixtures written from the bakes before anything was
  live, and compared with storage's afterwards (`sync_fixtures.py --check`: 57
  files, 0 differ). `flutter analyze` clean; `flutter test` 1,860 passed.
- **No walk test changed.** The guard prints nothing against the batch's start
  commit, `tool/fixtures_added_only.py` exits 0 (8 proteins added, 40 files,
  nothing else), and no golden PNG moved. The two proteins whose pages the walk
  tests refused were swapped instead (Flags 2).
- **The zoom** gained the eight in its own tables (the baked paths, the cell
  shapes, and the two cells drawn part by part: CYP17A1's adrenal cortex cell
  and dynamin-1's neuron) and needed no code change.

## The fifth batch: sixteen organs, 2026-10-25

Sixteen more curated proteins, one for each of the zoom's organs (`OrganKind`)
that had no specimen and no curated protein to reach it. Those organs are the
urinary bladder, the breast, the cervix, the epididymis, the gallbladder, the
intestine, the lung, the ovary, the parathyroid gland, the prostate, the
seminal vesicle, smooth muscle, the tongue, the endometrium (the uterus), the
vagina and the blood vessel.

They were picked by the locus bake's own path rule over the Atlas's bulk file
and by policy 1's dry run (`scripts/dry_fold.py`). Each was kept inside both
open page limits: every region at least 10 residues, at most two cell
locations. They were then drafted, verified, worded and baked as the third ten
were. The handoff that planned them is the backend's
`HANDOFF-CURATED-SIXTEEN.md`, whose sections record each phase.

Checked 2026-10-25, live: NCBI `efetch`, UniProt release 2026_03, RCSB (search
of 2026-10-21) and PDBe.

### Summary

| organ | gene | record | gene span (× INS record) | exons | neighbours in the record | processing in the record | walk |
|---|---|---|---:|---:|---|---|---|
| Urinary bladder | S100P | NC_000004.12 slice | 3,293 (0.4×) | 2 | none | none | uncut |
| Breast | LALBA | NC_000012.12 slice | 2,363 (0.3×) | 4 | none | signal, 1 chain (each twice) | cut |
| Cervix | SLPI | NG_028137.1 | 2,326 (0.3×) | 4 | none | signal, 1 chain | cut |
| Epididymis | NPC2 | NG_007117.1 | 13,366 (1.6×) | 5 | ISCA2, LTBP2, MIR4709, RAP1AP | signal, 1 chain | cut |
| Gallbladder | FGF19 | NC_000011.10 slice | 5,785 (0.7×) | 3 | none | signal 1–22, 1 chain | cut |
| Intestine | FABP6 | NG_029500.1 | 9,211 (1.1×) | 4 | none | none | uncut |
| Lung | SFTPD | NG_042218.1 | 11,366 (1.4×) | 8 | none | signal 1–17 only | cut (the chain from the table) |
| Ovary | PADI6 | NG_032943.2 | **29,504 (3.5×)** | 16 | none | none | shortened; uncut |
| Parathyroid gland | CASR | NG_009058.2 | **107,962 (12.8×)** | 7 | none | signal, 1 chain | shortened; cut |
| Prostate | ACP3 | NG_047032.1 | **41,435 (4.9×)** | 10 | none | signal, 1 chain | shortened; cut |
| Seminal vesicle | ANGPT1 | NG_029405.1 | **248,437 (29.5×)** | 9 | none | signal, 1 chain | shortened; cut |
| Smooth muscle | LOXL2 | NC_000008.11 slice | **107,224 (12.7×)** | 14 | LOXL2-AS1 | signal, 1 chain | shortened; cut |
| Tongue | CKMT2 | NC_000005.10 slice | **33,077 (3.9×)** | 10 | CKMT2-AS1 | transit peptide, 1 chain (each three times) | shortened; cut |
| Endometrium | PAEP | NC_000009.12 slice | 5,200 (0.6×) | 7 | none | signal, 1 chain, and isoform 2's chain | stops at the precursor |
| Vagina | ALOX12 | NC_000017.11 slice | 14,706 (1.7×) | 14 | ALOX12-AS1 | none | uncut |
| Blood vessel | GAS6 | NG_029703.1 | **43,528 (5.2×)** | 15 | GAS6-AS1, GAS6-DT | signal only | shortened; cut (the chain from the table) |

Across all sixteen:

- **The record's protein equals UniProt's**, residue for residue, so no row
  declares `uniprot_variants`.
- **Each RefSeqGene holds one coding sequence for its gene, at MANE's
  version**, so the rows name it unversioned, as the twenty's do. The slices
  are MANE's span, as the resolver reads it.
- **Exact `/gene` matching held on every record**: the antisense genes and
  NPC2's four neighbours are left out by name.
- **Every fold passed the app's own check on its planned entry**, at the draft
  and again at the bake (`structure/check_bundle.py`).
- **One protein planned did not pass its bakes.** PTGES (mPGES-1), planned for
  the seminal vesicle, fails AVI's biology check, and angiopoietin-1 took its
  place (Flags).

### Per gene

#### S100P

- **Record.** A slice: NC_000004.12:6,693,878–6,697,170, plus strand.
  NM_005980.3 is MANE Select. UniProt P25815.
- **Processing.** None: UniProt's chain is 1–95, the methionine kept.
- **Assembly.** A homodimer. 1J55 holds one calcium-bound chain and the pair by
  symmetry; one chain is drawn.

#### LALBA · α-lactalbumin

- **Record.** A slice: NC_000012.12:48,567,684–48,570,046, minus strand.
  NM_002289.3 is MANE Select. UniProt P00709.
- **Processing.** Signal peptide 1–19; α-lactalbumin 20–142.
- **Duplicated annotation.** The slice names both pieces twice, once with
  UniProt's `/id=`, which `tidy` cuts. The record keeps one of each, as it keeps
  one of RLN2's two B chains.
- **Assembly.** With β1,4-galactosyltransferase it is lactose synthase. 3B0O
  holds two copies of it alone, each with calcium.

#### SLPI · antileukoproteinase

- **Record.** NG_028137.1. NM_003064.4 is MANE Select. UniProt P03973.
- **Processing.** Signal peptide 1–25; the chain 26–132, two WAP domains.
- **Structure.** 4DOQ is the second WAP domain alone bound to porcine trypsin:
  the C-terminal half the entry was made of, 85–131, with its four bridges. The
  table carries UniProt's eight.

#### NPC2

- **Record.** NG_007117.1. NM_006432.5 is MANE Select. UniProt P61916.
- **Neighbours.** ISCA2, LTBP2, RAP1AP and MIR4709 share the record. Excluded
  by exact match.
- **Processing.** Signal peptide 1–19; the chain 20–151.
- **Assembly.** 5KWY holds two copies of NPC2, each with cholesterol sulfate,
  each bound to NPC1's middle lumenal domain. One NPC2 chain is drawn.

#### FGF19

- **Record.** A slice: NC_000011.10:69,698,238–69,704,022, minus strand.
  NM_005117.3 is MANE Select. UniProt O95750.
- **Processing.** The record's signal peptide is 1–22 and its chain 23–216;
  UniProt's Signal ends at 24.
- **Consequence.** In every curated row the table's signal peptide is the
  record's, which is what the walk draws. So the table says 1–22 (R3.2's source
  order), and the fold's count is the record's chain, 194.
- **Bridges.** UniProt annotates two, 58–70 and 102–120. 2P23 forms 102–120,
  but 58–70's sulfurs are 2.69 Å apart in it. The fold draws one; its words name
  the other.

#### FABP6 · gastrotropin

- **Record.** NG_029500.1. NM_001445.3 is MANE Select. UniProt P51161.
- **Processing.** None in the record. UniProt removes the methionine (Ala2 is
  acetylated) and names the chain 2–128. That is S100B's case: uncut, the
  methionine its own region (R3.7).
- **Structure.** 5L8O holds three chains; the one drawn is the one with
  cholate.

#### SFTPD · surfactant protein D

- **Record.** NG_042218.1. NM_003019.5 is MANE Select. UniProt P35247.
- **Processing.** The record names a signal peptide, 1–17, and no chain.
  UniProt's Signal is 1–20 and its chain 21–375.
- **Consequence.** The table follows the record and names the chain the signal
  peptide leaves, 18–375. The walk then cuts it (R3.9), as it cuts
  erythropoietin's.
- **Structure.** 1PWB is a trimeric fragment of the neck and the heads, solved
  with maltose. The fold draws one chain's C-type lectin domain and the ten
  residues before it, 250–375.
- **Display.** `SP-D`. "Surfactant protein D" would add it to what the frozen
  `protein_catalog_test` pins for the query "protein".

#### PADI6

- **Record.** NG_032943.2. NM_207421.4 is MANE Select. UniProt Q6TGC4.
- **Span.** **3.5× insulin's record, over the threshold.** Introns shortened.
- **Processing.** None.
- **Structure.** 25YL, a new entry not yet published: one chain of the dimer.

#### CASR · calcium-sensing receptor

- **Record.** NG_009058.2. NM_000388.4 is MANE Select. UniProt P41180, 1,078
  residues.
- **Span.** **12.8×, over the threshold**: seven exons over 107,962 bases.
  Introns shortened.
- **Processing.** Signal peptide 1–19; the receptor 20–1078.
- **Structure.** 7M3G, the active homodimer with calcium, L-Trp, evocalcet and
  etelcalcetide. Its chain B, ranked first, narrowly fails the app's check: a
  ring 1.518 from its own stretch of chain, where 1.5 is allowed (PAPP-A's chain
  D case). Chain A passes and places 821 residues to B's 804.
- **Bridges.** The table holds UniProt's eight; its Cys129 and Cys131 are bonds
  to the other chain, not pairs. It also holds 677–765, which 7M3G forms and
  UniProt does not annotate, as LGI1's five were added. In chain A, 437–449 is
  open (3.59 Å), though chain B forms it. The row lists nine; the fold draws
  eight and its words name the ninth.

#### ACP3 · prostatic acid phosphatase

- **Record.** NG_047032.1. NM_001099.5 is MANE Select, the secreted form, 386
  residues. UniProt P15309.
- **Span.** **4.9×, over the threshold.** Introns shortened.
- **Processing.** Signal peptide 1–32; the chain 33–386, which the record names
  "prostatic acid phosphatase isoform PAP". UniProt's PAPf39, 248–286, is a
  fragment cut back out of that chain (R3.4), and is not in the record.
- **Structure.** 8XJ4 is the enzyme purified from human semen, a homodimer.

#### ANGPT1 · angiopoietin-1

- **In place of PTGES.** mPGES-1 (NC_000009.12 slice, O14684) was verified and
  baked first. Its AVI track fails the bake's biology check: its exons' median
  score is 5.1 and its intron interiors' 5.3, though every one of its 14,694
  bases agrees with GRCh38, so its map is right. Without AVI there is no
  ClinVar either.
- **Choosing the replacement.** The handoff had no alternate for the seminal
  vesicle, so the Atlas scan's other candidates there were tried. ANGPT1, CHEK1
  and TES each have an entry that policy 1 passes, and AVI's gates pass all
  three. Angiopoietin-1 is the user's choice of 2026-10-25.
- **Record.** NG_029405.1. NM_001146.5 is MANE Select. UniProt Q15389.
- **Span.** **29.5×, over the threshold**: nine exons over 248,437 bases, its
  first intron 150,164 of them. Introns shortened, to the catalog's strongest
  scale after dystrophin's.
- **Processing.** Signal peptide 1–15; angiopoietin-1 16–498.
- **Structure.** 9IVT, its receptor-binding domain alone (283–498), the
  fibrinogen-like domain that binds TIE2. It forms UniProt's two bridges and
  435–437, which UniProt does not annotate; the row lists all three.

#### LOXL2

- **Record.** A slice: NC_000008.11:23,296,897–23,404,120, minus strand.
  NM_002318.3 is MANE Select. UniProt Q9Y4K0.
- **Neighbours.** LOXL2-AS1. Excluded by exact match.
- **Span.** **12.7×, over the threshold.** Introns shortened.
- **Processing.** Signal peptide 1–25; the chain 26–774.
- **Structure.** 5ZE3 is a crystal of the precursor. The fold draws the third
  and fourth SRCR domains, 322–554. The entry has Gln at 455, where the record
  has the Asn a sugar is joined to.
- **Bridges.** UniProt's seventeen. Of the six in the span drawn, 5ZE3 names
  five. 351–414's sulfurs are 1.76 Å apart in its coordinates, but the entry
  records no bond there, so the fold draws five and its words name the sixth.

#### CKMT2 · sarcomeric mitochondrial creatine kinase

- **Record.** A slice: NC_000005.10:81,233,322–81,266,398, plus strand.
  NM_001099735.2 is MANE Select. UniProt P17540.
- **Neighbours.** CKMT2-AS1. Excluded by exact match.
- **Span.** **3.9×, over the threshold.** Introns shortened.
- **Processing.** A transit peptide, 1–39, that takes it into mitochondria, and
  the chain 40–419. The slice names each three times; the record keeps one
  chain. It is the first curated leader that is neither a signal peptide nor a
  methionine.
- **Structure.** 4Z9M holds eight chains, each with ADP; one is drawn.

#### PAEP · glycodelin

- **Record.** A slice: NC_000009.12:135,561,756–135,566,955, plus strand.
  NM_002571.4 is MANE Select. UniProt P09466.
- **Processing.** Signal peptide 1–18; glycodelin 19–180; and isoform 2's
  chain, which the slice places inside this transcript's exons, over this
  one's.
- **Consequence.** One page of disjoint chains cannot draw two chains over one
  stretch. So `mature_peptides=False` and the walk stops at the precursor
  (R3.4), as uromodulin's does. What the signal peptide leaves is named
  "glycodelin" in the table (R3.3) and in the catalog.
- **Structure.** 4R0B is a dimer. The entry has Glu at 46, where the record has
  the Asn a glycan is joined to.

#### ALOX12 · platelet-type 12-lipoxygenase

- **Record.** A slice: NC_000017.11:6,996,049–7,010,754, plus strand.
  NM_000697.3 is MANE Select. UniProt P18054.
- **Neighbours.** ALOX12-AS1. Excluded by exact match.
- **Processing.** None.
- **Structure.** 8GHE is a tetramer, each chain with its iron; the chain drawn
  is the one holding oleoyl-CoA. The entry has Ser at 322, where the record has
  Asn.

#### GAS6

- **Record.** NG_029703.1. NM_000820.4 is MANE Select. UniProt Q14393.
- **Neighbours.** GAS6-AS1 and GAS6-DT. Excluded by exact match.
- **Span.** **5.2×, over the threshold.** Introns shortened.
- **Processing.** The record names the signal peptide, 1–30, and no chain.
- **Consequence.** The table names the chain it leaves, 31–678 (UniProt's),
  which the walk cuts (R3.9).
- **Structure.** 5VXZ holds its two laminin G-like domains bound to AXL: 288–675,
  369 placed. The table carries UniProt's sixteen bridges; the fold draws the
  two in that span.

### Structures

| protein | entry · chain | method | residues drawn | deviations from the record | why this one |
|---|---|---|---|---|---|
| S100P | 1J55 · A | X-ray 2.0 Å | 1–45, 52–94 | none | 2MJW, its runner-up, is NMR, with no resolution |
| LALBA | 3B0O · A | X-ray 1.61 Å | 21–139, 4 bridges | none | finer than 3B0I (1.8 Å) |
| SLPI | 4DOQ · B | X-ray 2.0 Å | 85–131 (WAP 2), 4 bridges | none | the only eligible |
| NPC2 | 5KWY · C | X-ray 2.4 Å | 20–151, 3 bridges | none | the only eligible |
| FGF19 | 2P23 · A | X-ray 1.8 Å | 40–175, 1 bridge | none | finer than its runner-up (2.6 Å) |
| FABP6 | 5L8O · B | X-ray 2.39 Å | 3–127 | none | its runner-up is NMR |
| SFTPD | 1PWB · A | X-ray 1.4 Å | 250–375, 2 bridges | none | finer than 1.6 Å |
| PADI6 | 25YL · B | cryo-EM 2.8 Å | 10–694 | none | finer than 3.03 Å |
| CASR | 7M3G · A | cryo-EM 2.5 Å | 20–887 (821 placed), 8 bridges | none | chain B, ranked first, narrowly fails the app's check |
| ACP3 | 8XJ4 · A (author's B) | cryo-EM 3.2 Å | 33–377, 2 bridges | none | measured residue by residue; its runner-up is not |
| ANGPT1 | 9IVT · A | X-ray 1.75 Å | 283–498 (the receptor-binding domain), 3 bridges | none | finer than 4EPU (2.10 Å) |
| LOXL2 | 5ZE3 · A | X-ray 2.4 Å | 322–554 (SRCR 3–4), 5 bridges | Gln at 455 | the only eligible |
| CKMT2 | 4Z9M · E | X-ray 2.1 Å | 47–415 | none | the only eligible |
| PAEP | 4R0B · A | X-ray 2.45 Å | 26–178, 2 bridges | Glu at 46 | the only eligible |
| ALOX12 | 8GHE · D (author's A) | cryo-EM 2.0 Å | 2–663 | Ser at 322 | finer than 2.2 Å |
| GAS6 | 5VXZ · B | X-ray 2.3 Å | 288–675 (369 placed), 2 bridges | none | the only eligible |

### Flags

1. **Sixteen organs, each reached for the first time.** Fourteen are drawn as
   the body figure's outline grown to size, with its plain surface, until each
   has a specimen.
   - **The vessel and the parathyroid.** These have drawings of their own, and
     neither had an outline: the place their tissue is sampled lay "outside"
     an empty path (`zoom_anatomy_test`), and the arrival's light had nothing
     to sweep. Each now has one: the gland's oval and the trunk's wall. No
     organ any curated protein reached before is touched.
2. **Five land in no cell.** SLPI (cervix), CASR (parathyroid gland), ANGPT1
   (seminal vesicle), ALOX12 (vagina) and GAS6 (blood vessel): the zoom draws
   each tissue's own cells, as for prion and TNF. CASR's parathyroid and
   FABP6's colon enteroendocrine cell are drawn part by part, as endocrine
   cells.
3. **FGF19's bridges.** The handoff took 102–120 for the entry's own and 58–70
   for UniProt's only, but UniProt annotates both. The row keeps both and the
   facts say two. The fold draws 102–120, and its words say why it does not
   draw 58–70.
4. **LOXL2's bridges.** 351–414 is placed, its sulfurs 1.76 Å apart, but 5ZE3
   records no bond there, and the bake draws the entry's own records. The row
   keeps UniProt's seventeen; the words name the one not drawn.
5. **Residues the entries differ on**, each within the fidelity gate:
   - 5ZE3's Gln455 and 4R0B's Glu46 stand where the record has an Asn that
     UniProt marks as glycosylated.
   - 8GHE's Ser322 stands where the record has Asn.
   - 5TL9's Cys59, mPGES-1's, was oxidised (CSO); that protein was not kept.
6. **Leaders.**
   - **CKMT2's transit peptide** is drawn on the gene page as "the N-terminal
     extension" (R3.6), the record builder reading no `transit_peptide`. Its
     protein page is one block, "creatine kinase S-type, mitochondrial
     precursor", and its mature page is the chain, 380 residues. The residue
     panel names residues 1–39 "Transit peptide (mitochondrion)", from the
     table. Naming a transit peptide on the walk is open, beside R3.2's
     UniProt fallback.
   - **FABP6's methionine** is a region of its own (R3.7), as SOD1's and
     S100B's are.
7. **Five folds draw a domain**: SLPI's second WAP domain, SP-D's C-type lectin
   domain, angiopoietin-1's receptor-binding domain, LOXL2's SRCR 3–4 and
   GAS6's two laminin G-like domains. Each fold sentence says what is not
   drawn.
8. **Introns shortened**: PADI6, CASR, ACP3, ANGPT1, LOXL2, CKMT2 and GAS6, by
   their records. Sixteen genes are now shortened.
9. **Tissue enhanced, not enriched**, for LOXL2 and ALOX12, and for PTGES. The
   locus bake reads the organ from the Atlas's tissue reading either way.
10. **ESM-2's longest** is CASR, 1,078 residues, scored in windows in 13 minutes.
    Every alignment passed, from 76.8% (PADI6) to 94.4% (NPC2).
11. **Two records end a leader where UniProt does not**: FGF19 at 22, not 24,
    and SFTPD at 17, not 20. Both tables follow their records; in every one of
    the 38 rows the table's signal peptide already was the record's.
12. **Glycodelin stops at the precursor**: its slice lays isoform 2's chain over
    this one's.
13. **CASR's chain** is 7M3G's A, not the B the dry run named, because B
    narrowly fails the app's check. A forms 677–765, which UniProt does not
    annotate, and leaves 437–449 open. The row adds the first, as it does
    LGI1's five, and keeps the second.
14. **The rule the rows follow for bridges** is UniProt's pairs, with any the
    fold draws that UniProt does not annotate: CASR's 677–765 and
    angiopoietin-1's 435–437. Thyroglobulin's and PAPP-A's rows keep UniProt's
    alone, though their entries pair a few cysteines otherwise. Their tracks
    are frozen, and they stay so.
15. **A correction to the fourth batch's Flag 4.** LGI1's row lists 9KZT's five
    bridges (`targets.py`), so its facts say five and its fold draws five. The
    flag's "the row lists none" was wrong.
16. **Displays and summaries keep to what the search tests pin.** SFTPD is
    displayed `SP-D`, and no summary says "protein", "hormone", "ins",
    "lysozyme" or "kinase".
17. **Chromosomes 13 and 14 met the zoom for the first time** (GAS6, NPC2).
    - **The problem.** Their short arms are 15–16% of the chromosome; 21's is
      26%. That is too short for the centromere's waist and the rounded end,
      whose sizes were fixed. The stalk at p12 was drawn at 0.75 of the arm's
      width, where 0.9 is asked (`chromosome_scene_test`), and the cleft was not
      yet open at the arm's top (`chromosome_look_test`).
    - **The fix.** On a short arm under 3.2 half-widths, the waist and that end's
      rounding are now drawn down in proportion. Of the chromosomes the
      curated proteins lie on, only 13's and 14's arms are that short; every
      chromosome of the thirty-eight is drawn exactly as before.
18. **A territory over the nucleolus** (LOXL2).
    - **The problem.** In a smooth muscle cell's flat nucleus, chromosome 8's
      territory lay over the nucleolus, and the gene's glow hid it
      (`nucleolus_test`).
    - **The fix.** A followed territory nearer the nucleolus than half their
      radii together is turned a quarter of the way round, away from it. No
      other protein's territory comes that close, and none of their layouts
      changes.

### After integration

Baked 2026-10-25 by `pipeline/bake_curated.py`, one protein at a time and each
step in its own environment, in 52 minutes for the sixteen, then
angiopoietin-1's own bake. The checks ran over all fifty-four rows:
`check_assets.py`, `check_folding.py` and `check_locus.py`. Every model is the
`.glb` the draft's bake made from the same working copy, and passed the app's
check of its fold again (`structure/check_bundle.py`). Every locus landed in
the organ and cell planned.

| protein | pages | protein page | mature page |
|---|---|---|---|
| S100P | gene, mRNA, protein, fold | one block, 95 | — |
| α-lactalbumin | gene, mRNA, protein, mature, fold | signal peptide 1–19 · Alpha-lactalbumin 20–142 | the same chain (123) |
| SLPI | gene, mRNA, protein, mature, fold | signal peptide 1–25 · Antileukoproteinase 26–132 | the same chain (107) |
| NPC2 | gene, mRNA, protein, mature, fold | signal peptide 1–19 · NPC intracellular cholesterol transporter 2 20–151 | the same chain (132) |
| FGF19 | gene, mRNA, protein, mature, fold | signal peptide 1–22 · fibroblast growth factor 19 23–216 | the same chain (194) |
| FABP6 | gene, mRNA, protein, fold | one block, 128 | — |
| SP-D | gene, mRNA, protein, mature, fold | signal peptide 1–17 · Pulmonary surfactant-associated protein D 18–375 | the same chain (358) |
| PADI6 | gene (shortened), mRNA, protein, fold | one block, 694 | — |
| CaSR | gene (shortened), mRNA, protein, mature, fold | signal peptide 1–19 · Extracellular calcium-sensing receptor 20–1,078 | the same chain (1,059) |
| prostatic acid phosphatase | gene (shortened), mRNA, protein, mature, fold | signal peptide 1–32 · prostatic acid phosphatase isoform PAP 33–386 | the same chain (354) |
| angiopoietin-1 | gene (shortened), mRNA, protein, mature, fold | signal peptide 1–15 · Angiopoietin-1 16–498 | the same chain (483) |
| LOXL2 | gene (shortened), mRNA, protein, mature, fold | signal peptide 1–25 · lysyl oxidase homolog 2 26–774 | the same chain (749) |
| CKMT2 | gene (shortened), mRNA, protein, mature, fold | one block, 419 (its N-terminal extension, 1–39, on the gene page) | creatine kinase S-type, mitochondrial (380) |
| glycodelin | gene, mRNA, protein, fold | signal peptide 1–18 · glycodelin 19–180 | — |
| ALOX12 | gene, mRNA, protein, fold | one block, 663 | — |
| GAS6 | gene (shortened), mRNA, protein, mature, fold | signal peptide 1–30 · Growth arrest-specific protein 6 31–678 | the same chain (648) |

The seven shortened genes' pages give the share of the span their introns
take, drawn at the scale shown:

| gene | introns' share of the span | scale |
|---|---:|---:|
| PADI6 | 91.9% | 1:1.3 |
| CASR | 90.7% | 1:7 |
| ACP3 | 92.3% | 1:1.8 |
| ANGPT1 | 98.3% | 1:12.4 |
| LOXL2 | 96.5% | 1:5.1 |
| CKMT2 | 95.5% | 1:1.4 |
| GAS6 | 94.2% | 1:1.9 |

Checked, and how:

- **Live.** Seeded first, then every kind uploaded, each after a dry run (a
  track row names its protein's).
  - The seed wrote 16 proteins, 92 aliases and 96 track rows.
  - Uploaded: 16 objects of each kind, and 32 for the structures. Each model
    and scene is, by its digest, the one the draft's app check passed.
  - `seed_catalog.py --check`: 54 rows, 0 differences.
  - `check_assets.py --against` the service: 54 rows agree.
  - `/catalog` is 54 rows, orders 0 to 53 complete.
  - `/proteins/resolve/<GENE>` reads `ready` at its slug for all sixteen.
  - `fetch_tracks.py --check`: 378 files as stored, 0 differ.
  - `live_backend_check.dart` reads every track of every row through the
    production client.
- **The app.**
  - The sixteen's fixtures were written from the bakes before anything was
    live and compared with storage's afterwards (`sync_fixtures.py --check`:
    113 files, 0 differ).
  - `flutter analyze` clean.
  - `flutter test`: 2,472 passed. The one failure is a git-excluded screenshot
    tool of an earlier session, `test/features/zoom/_scratch_shots_test.dart`,
    which loads only with `SHOTS` set.
- **No walk test changed.** The guard prints nothing against the batch's start
  commit; `tool/fixtures_added_only.py` exits 0 (16 proteins added, 80 files,
  nothing else); no golden PNG moved. The sixteen add 75 catalog golden pages,
  owed to the x86 host.
- **The zoom** gained the sixteen in its own tables: the baked paths, the cell
  shapes, and CaSR's and FABP6's endocrine cells drawn part by part. It also
  gained three changes to its code, each acting only where its case occurs
  (Flags 1, 17 and 18). Every chromatid width and cleft along each of the
  thirty-eight's chromosomes, and every territory and nucleolus in their
  nuclei, is the same to the float before and after (a dump compared both
  ways).
