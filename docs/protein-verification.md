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
