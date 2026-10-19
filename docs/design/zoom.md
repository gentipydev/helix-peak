# Zoom: from a body down to one gene's DNA

![Insulin's nine stops on the app's ground: a glass figure with the pancreas glowing, the pancreas sculpted with its islets in the accent, an islet under the eyepiece, a beta cell, its nucleus with chromosome 11's territory in the accent, chromosome 11 as a micrograph with the gene's two FISH spots at its tip, the band 11p15.5 under a docked map, the gene as a genome browser draws it, and the home screen's helix carrying the gene's first bases](zoom.png)

## Experience

The zoom (`/zoom/<slug>`) dives from a whole body to the first bases of one
protein's gene, through nine stops: body, organ, tissue, cell, nucleus,
chromosome, band, gene and DNA. It is one continuous depth.

- **Getting there.** The walk's gene page offers "Zoom ›" beside its line,
  where the transcript offers "Ribosome ›", for a protein whose `locus`
  track is ready: the twenty curated ones today. It began as a Lab flow, and
  its links from then (`/lab/zoom/<slug>`) still open it.
- **Moving through it.**
  - The card's ‹ and › fly to the stop either side, and a double tap goes
    one stop deeper. A step asked for mid-flight carries straight on at the
    speed the depth has.
  - A pinch moves the depth 2.5 for each tenfold spread of the fingers. A
    flick settles on the stop it would coast to, on a critically damped
    spring.
  - There is no player and no depth rail: the buttons and the pinch are
    the whole of it.
- **The card** holds the stop's place, one line of data where there is one,
  and its two steps (`‹ Organ`, `Cell ›`; `Walk ›` at the DNA). Nothing on
  it explains. A new stop's words slide 6 pt the way the zoom travels and
  fade in, in 220 ms. The card is as tall as the tallest stop's words at the
  reader's text size, so the canvas keeps its size. A screen reader hears
  the stop's name, its place and its line.
- **The canvas** names only what the card does not say: the cell in the
  tissue, where the protein sits, the band on the chromosome, the gene on
  the map, the gene's 5′ end; and the landmarks a reader asked after: the
  nucleolus, at the nucleus (the user's ask, 2026-10-19; named at the cell
  from 2026-10-15 to 2026-10-18, and at the nucleus too until 2026-10-16),
  and the chromosome's parts, at the chromosome (the same day). A
  scale bar is always at its lower left: a
  round length at each stop, and between two stops a bar that glides from
  the one's length to the next, reading the length it spans as it goes, so
  it never springs back. At the body alone, its lower right carries the
  credit, "Anatomogram EMBL-EBI · HPA 25.1 · CC BY 4.0", built from the
  track's Atlas version and the figures' licence. It goes onto two lines
  where it would meet the scale bar, and fades as the body does.
- **Reduced motion.** Steps and settles cut, the cards cut, and every stop
  is drawn as its beats leave it, with nothing moving.
- **At the DNA**, "Walk ›" unzips the helix into the walk's rows and goes
  back to the walk's gene page it was opened from. A zoom opened by a link,
  with no walk under it, opens the walk there.

What each stop says, for insulin:

| Stop | Card title | Card line | On the canvas |
|---|---|---|---|
| Body | Pancreas | Tissue enriched · 12,197 nTPM | the credit |
| Organ | Pancreas | About 16 cm | a marker where the tissue is sampled |
| Tissue | Islet (the recipe's architecture) | none | beta cells |
| Cell | Beta cells | Tissue cell type enriched | nucleolus: the Atlas names no place in the cell for it, and its vesicles leave the cell |
| Nucleus | Chromosome 11 territory | none | nucleolus |
| Chromosome | Chromosome 11 | 135,086,622 bp · 36 bands | 11p15.5; p arm, centromere, q arm, chromatid, telomere |
| Band | 11p15.5 | 2.8 Mb · gene at 2,159,779–2,161,209 | INS |
| Gene | INS · 1,431 bases | Three exons · reverse strand | 5′, 3′, the exons' numbers |
| DNA | First 33 bases | 5′ AGCCCTCCAGGACAGGCTGCATCAGAAGAGGCC 3′ | 5′ |

A cell with no nucleus says so in its line: hemoglobin's is "Erythrocytes ·
521,403 nCPM · no nucleus", over the erythroblasts it lands in.

## Research and its consequences

Each stop is laid out in the convention of the instrument that shows its
scale, so a reader who knows the field reads it without a legend. What each
convention is, where it comes from, and what it decided:

- **Where a gene is read.** The Human Protein Atlas reads a gene's RNA
  tissue by tissue, cell type by cell type, and by cell type within a tissue,
  and finds its protein in the cell by immunofluorescence (Uhlén et al. 2015;
  Karlsson et al. 2021; Thul et al. 2017). The tissue reading and the single
  cell reading are separate analyses, so the top of one need not live in the
  top of the other. *Consequence:* the bake chooses one path, a cell that
  lives in the organ ("One path per gene").
- **Anatomy.** Expression Atlas shows expression on an anatomogram: a
  standing figure with a shape for each tissue, named by its UBERON id.
  *Consequence:* the body and the organ are those shapes, glowing by the
  Atlas's level.
- **The pancreas.** Anatomy plates show it from the front with the stomach
  taken away: its head in the C of the duodenum, the uncinate process
  hooked behind the superior mesenteric vessels, the neck over them, the
  body across the spine and the tail at the spleen's hilum; the splenic
  artery winding along its upper border from the coeliac trunk; the bile
  duct coming down behind the duodenum's first part and the head to the
  ampulla on the second part, where the main duct meets it, the accessory
  duct opening above (Standring 2020). Its surface is lobulated. Its
  islets, a million or more, are each some 150 µm across, the size islet
  isolation counts them by (Ricordi et al. 1990), and lie more than twice
  as densely in the tail as in the head or the body (Wang et al. 2013).
  Its main duct narrows from about 3 mm in the head to 1 mm in the tail
  (Sivak and Sullivan 1976). *Consequence:* the pancreas is drawn so, from
  anatomy rather than from the anatomogram's outline ("The pancreas"
  below).
- **The testis.** Anatomy plates show it from the side and cut down its
  length: 4–5 cm long, 2.5 cm broad and 3 cm from front to back, its 250
  to 400 lobules parted by septa that run from the mediastinum, the
  thickened back of its tunica albuginea, to the tunica round it; the rete
  testis in the mediastinum, drained at its upper end by twelve to fifteen
  or twenty efferent ductules into the head of the epididymis, which lies
  along the back down to its tail (Gray 1918). Each lobule holds one to
  four coiled seminiferous tubules 150–250 µm across (Junqueira's Basic
  Histology). From the tail the vas deferens turns up into the spermatic
  cord beside the testicular artery and the veins of the pampiniform
  plexus. Measured in men: the epididymis's head up to 12 mm across on
  ultrasound and its tail up to 6 (Lotti et al. 2021); the vas 1.5–2.7 mm
  thick (Middleton et al. 2009); the testicular artery about 1 mm across in
  the cord, 0.2–1.9 mm in 120 cords (Raman and Goldstein 2004); a vein of
  the plexus 3 mm across or more is read as a varicocele (Bertolotto et al.
  2020). *Consequence:* the testis is drawn so, from anatomy rather than
  from the anatomogram's outline, at those sizes ("The testis" below).
- **Histology.** Haematoxylin stains nuclei and ribosome-rich cytoplasm;
  eosin stains protein; fat, mucus and lumens take neither. A ×40 objective
  under a standard eyepiece shows a field about half a millimetre across.
  *Consequence:* the tissue is that field, each tissue's architecture laid
  as the textbooks draw it (Junqueira's Basic Histology; Ross and Pawlina,
  Histology: A Text and Atlas), and each part by the stain it would take.
  It is drawn in the app's neutrals rather than in the stains' pink and
  purple (the user's choice of 2026-10-14): what takes stain lit, the
  denser the brighter, what takes none the ground.
- **A red cell has no nucleus.** It loses it as it matures in the marrow, in
  an island of erythroblasts round a macrophage (Chasis and Mohandas 2008).
  *Consequence:* where the Atlas's cell is a red cell, the zoom lands in an
  erythroblast of an island, and the card says "no nucleus".
- **The cell.** The Atlas images a cell in four channels: the nucleus blue,
  microtubules red, the endoplasmic reticulum yellow, the protein green
  (Thul et al. 2017). *Consequence:* the protein is placed where the Atlas
  finds it, brighter at its main locations. The channels' colours are not
  kept: the cell is sculpted in the neutrals, and the protein is its one
  accent.
- **The nucleolus.** The nucleus's densest body, where ribosomes are
  made, has no membrane: it is a condensate of three layers, pale fibrillar
  centres each in a rim of dense fibrillar component, in a granular bulk,
  round the ribosomal genes of the five acrocentrics (Lafontaine et al.
  2021; McStay 2016). *Consequence:* it is drawn lobed, not round, its edge
  soft, near black against the chromatin round it, and the acrocentrics'
  territories round it. Its layers are left out: it is one plain dark body
  (the user's choice of 2026-10-16, to keep the picture simple; its
  fibrillar centres showed once it was some 20 pixels across until then).
  A protein in the nucleoplasm glows round it, as immunofluorescence shows
  one.
- **Chromosome territories.** In interphase each chromosome keeps to a
  territory of its own, and territories are ordered from the centre of the
  nucleus to its edge by gene density: chromosome 19 toward the centre, 18 at
  the edge (Croft et al. 1999; Boyle et al. 2001). Painting each chromosome
  its own colour shows them (Speicher et al. 1996; Schröck et al. 1996).
  *Consequence:* 46 territories, sized by their DNA and placed in that
  order, each a step lighter or darker than its neighbour, the gene's
  chromosome in the accent and its homologue faintly in it: a nucleus holds
  two copies of every autosome, and of the X in a female cell, so the
  territory followed is one of two. A male cell's X has none, its second
  sex chromosome being the Y.
- **Bands.** A chromosome is seen whole only when it condenses to divide,
  some ten-thousandfold. Giemsa stain then bands it, and a band's name
  (11p15.5) is the address cytogenetics gives a gene (ISCN 2020). The bands
  follow the sequence itself, its GC-poor stretches staining dark (Niimura
  and Gojobori 2002). *Consequence:* the chromosome is a metaphase
  chromosome at that length, its band named, and nothing claims the gene is
  seen there.
- **A chromosome seen whole.** Its two sister chromatids lie side by side,
  joined at the centromere's primary constriction, each with a scaffold of
  its own (Paulson and Laemmli 1977; Poonperm et al. 2015). Each is
  chromatin folded into loops by condensins along its axis (Naumova et al.
  2013; Walther et al. 2018): in chicken cells, loops of about 80 kb nested
  in loops of about 400 kb, winding in a helix (Gibcus et al. 2018); in
  human cells, very large loops that overlap strongly (Beckwith et al.
  2025). The fibre itself is no regular coil but chromatin packed at varying
  density (Ou et al. 2017; Wako et al. 2020), and a good part of the
  chromosome's volume is a coat round the chromatin, not chromatin (Booth et
  al. 2016). A scanning micrograph shows the surface as knobs and globules
  (Sumner 1991; Shemilt et al. 2014), and atomic force microscopy shows
  G-bands as ridges and grooves of the relief, not of colour (Hoshi and
  Ushiki 2001; Ushiki and Hoshi 2008). The bands run across both sisters at
  the same heights, as stacked layers would (Daban 2015). On an
  acrocentric's short arm, the stalk holds the ribosomal genes, and a silent
  one is as condensed as the arm round it (McStay 2016). *Consequence:* the
  chromosome is drawn as a micrograph: two velvety sisters touching along a
  groove, knobbly with chromatin, in a soft coat, the bands soft changes of
  tone, an acrocentric's short arm whole.
- **A gene by FISH.** A probe hybridised to a metaphase chromosome shows as
  a spot on each sister chromatid, at the same height on both (Trask 1991;
  Baumgartner et al. 1991): it places a gene to within about a band, and is
  about as big whatever the gene's length. *Consequence:* the gene is two
  spots, one on each sister, over a faint wash of its band, in the accent;
  nothing else on the chromosome is.
- **Illustration.** The pictures of chromosomes that read as current share
  one desaturated material, one glowing accent where the function is, and
  soft, knobbly surfaces lit from the side, without outlines or cut-away
  glass (for example EMBL's "Condensin shaping mitotic chromosomes by
  looping DNA", by Tobias Wüstefeld/Illustratoren.de). A zoom across scales
  reads best as one continuous travel, each level drawn in its own
  convention (Halladjian et al. 2020). *Consequence:* the chromosome's look,
  and the hand-overs either side of it.
- **The gene's place.** Its span is that of its MANE Select transcript on
  GRCh38 (Morales et al. 2022), and its bands the UCSC Genome Browser's
  cytoBand table.
- **Nucleosomes.** 147 base pairs wrap a core of eight histones (Luger et
  al. 1997; Davey et al. 2002), about one core every 200. At the start of a
  gene that is read there is a stretch free of them, with a positioned
  nucleosome just downstream (Schones et al. 2008). *Consequence:* the gene
  is a fibre of cores 200 bp apart, bare at its 5′ end.
- **The helix.** A base pair every 0.34 nm, about ten and a half to a turn.

Sources:

- Baumgartner M et al. Genes occupy a fixed and symmetrical position on
  sister chromatids. Cell 1991;64:761–766.
- Beckwith KS et al. Nanoscale DNA tracing reveals the self-organization
  mechanism of mitotic chromosomes. Cell 2025;188:2656–2669.
- Bertolotto M et al. Ultrasound evaluation of varicoceles: systematic
  literature review and rationale of the ESUR-SPIWG Guidelines and
  Recommendations. J Ultrasound 2020;23:487–507.
- Booth DG et al. 3D-CLEM reveals that a major portion of mitotic
  chromosomes is not chromatin. Mol Cell 2016;64:790–802.
- Boyle S et al. The spatial organization of human chromosomes within the
  nuclei of normal and emerin-mutant cells. Hum Mol Genet 2001;10:211–219.
- Chasis JA, Mohandas N. Erythroblastic islands: niches for erythropoiesis.
  Blood 2008;112:470–478.
- Croft JA et al. Differences in the localization and morphology of
  chromosomes in the human nucleus. J Cell Biol 1999;145:1119–1131.
- Daban JR. Stacked thin layers of metaphase chromatin explain the
  geometry of chromosome rearrangements and banding. Sci Rep 2015;5:14891.
- Davey CA et al. Solvent mediated interactions in the structure of the
  nucleosome core particle at 1.9 Å resolution. J Mol Biol
  2002;319:1097–1113.
- EMBL. Condensin shaping mitotic chromosomes by looping DNA. Illustration
  by Tobias Wüstefeld/Illustratoren.de, EurekAlert! multimedia 936863.
- Expression Atlas, EMBL-EBI: anatomograms, CC BY 4.0
  (<https://www.ebi.ac.uk/gxa/licence.html>), which asks to be cited as
  "Expression Atlas in 2026: enabling FAIR and open expression data through
  community collaboration and integration", Nucleic Acids Research, 2025.
- Gibcus JH et al. A pathway for mitotic chromosome formation. Science
  2018;359:eaao6135.
- Gray H. Anatomy of the Human Body, 20th edn. Lea & Febiger, 1918.
- Halladjian S et al. ScaleTrotter: illustrative visual travels across
  negative scales. IEEE Trans Vis Comput Graph 2020;26:654–664.
- Hoshi O, Ushiki T. Three-dimensional structure of G-banded human
  metaphase chromosomes observed by atomic force microscopy. Arch Histol
  Cytol 2001;64:475–482.
- ISCN 2020: An International System for Human Cytogenomic Nomenclature.
  Karger, 2020.
- Karlsson M et al. A single-cell type transcriptomics map of human tissues.
  Sci Adv 2021;7:eabh2169.
- Lafontaine DLJ, Riback JA, Bascetin R, Brangwynne CP. The nucleolus as a
  multiphase liquid condensate. Nat Rev Mol Cell Biol 2021;22:165–182.
- Lotti F et al. The European Academy of Andrology (EAA) ultrasound study
  on healthy, fertile men: scrotal ultrasound reference ranges and
  associations with clinical, seminal, and biochemical characteristics.
  Andrology 2021;9:559–576.
- Luger K et al. Crystal structure of the nucleosome core particle at 2.8 Å
  resolution. Nature 1997;389:251–260.
- McStay B. Nucleolar organizer regions: genomic 'dark matter' requiring
  illumination. Genes Dev 2016;30:1598–1610.
- Middleton WD et al. High-resolution sonography of the normal extrapelvic
  vas deferens. J Ultrasound Med 2009;28:839–846.
- Morales J et al. A joint NCBI and EMBL-EBI transcript set for clinical
  genomics and research. Nature 2022;604:310–315.
- Naumova N et al. Organization of the mitotic chromosome. Science
  2013;342:948–953.
- Niimura Y, Gojobori T. In silico chromosome staining: reconstruction of
  Giemsa bands from the whole human genome sequence. Proc Natl Acad Sci
  USA 2002;99:797–802.
- Ou HD et al. ChromEMT: visualizing 3D chromatin structure and compaction
  in interphase and mitotic cells. Science 2017;357:eaag0025.
- Paulson JR, Laemmli UK. The structure of histone-depleted metaphase
  chromosomes. Cell 1977;12:817–828.
- Poonperm R et al. Chromosome scaffold is a double-stranded assembly of
  scaffold proteins. Sci Rep 2015;5:11916.
- Raman JD, Goldstein M. Intraoperative characterization of arterial
  vasculature in spermatic cord. Urology 2004;64:561–564.
- Ricordi C et al. Islet isolation assessment in man and large animals.
  Acta Diabetol Lat 1990;27:185–195.
- Schones DE et al. Dynamic regulation of nucleosome positioning in the
  human genome. Cell 2008;132:887–898.
- Schröck E et al. Multicolor spectral karyotyping of human chromosomes.
  Science 1996;273:494–497.
- Shemilt LA et al. Scanning electron microscope studies of human
  metaphase chromosomes. Philos Trans A Math Phys Eng Sci
  2014;372:20130144.
- Sivak MV, Sullivan BH. Endoscopic retrograde pancreatography. Am J Dig
  Dis 1976;21:263–269.
- Speicher MR, Ballard SG, Ward DC. Karyotyping human chromosomes by
  combinatorial multi-fluor FISH. Nat Genet 1996;12:368–375.
- Standring S (ed.). Gray's Anatomy: The Anatomical Basis of Clinical
  Practice, 42nd edn. Elsevier, 2020.
- Sumner AT. Scanning electron microscopy of mammalian chromosomes from
  prophase to telophase. Chromosoma 1991;100:410–418.
- Thul PJ et al. A subcellular map of the human proteome. Science
  2017;356:eaal3321.
- Trask BJ. Fluorescence in situ hybridization: applications in
  cytogenetics and gene mapping. Trends Genet 1991;7:149–154.
- Uhlén M et al. Tissue-based map of the human proteome. Science
  2015;347:1260419.
- Ushiki T, Hoshi O. Atomic force microscopy for imaging human metaphase
  chromosomes. Chromosome Res 2008;16:383–396.
- Wako T et al. Human metaphase chromosome consists of randomly arranged
  chromatin fibres with up to 30-nm diameter. Sci Rep 2020;10:8948.
- Walther N et al. A quantitative map of human Condensins provides new
  insights into mitotic chromosome architecture. J Cell Biol
  2018;217:2309–2328.
- Wang X et al. Regional differences in islet distribution in the human
  pancreas: preferential beta-cell loss in the head region in patients
  with type 2 diabetes. PLoS One 2013;8:e67454.

## Visual language

- **One ground.** Every stop is on the app's own ground
  (`colorScheme.surface`), as every other screen is.
- **The accent follows the gene.** The theme's primary marks the gene and
  what it makes, at every scale: the organs its RNA is raised in (brighter
  where the level is higher), where its cell lives in the organ, its cell
  in the tissue, where its protein sits in the cell, its chromosome's
  territory, its band, and its gene on the map.
  Nothing else is in it.
- **Everything else is sculpted** in the app's warm neutrals, under one
  light from the upper left (`Sculpt`): a lit body from the surfaces up
  toward the bright ink, a rim where the light catches an edge, a soft
  shadow under the form, and fine line work in the quiet ink.
- **Data keeps its colours.** The gene's parts are the walk's role colours,
  the bases the home helix's (`NucleotideColors.helix`), and blood the
  thymine red, the one red the app has.
- **Glows** are gradients and wide faint strokes, never a blur.
- **Names.** One plate a name, with a line to what it names, set clear of
  each other and 8 pt in from the edges. The card says the rest. The
  line is in the accent, but for a landmark's (the nucleolus, a
  chromosome's parts), which is in the quiet ink. A landmark's plate is set
  off what holds it, so it hides none of it: round the nucleus as a cell's
  names are round the cell, in the band above or below it nearer the
  nucleolus, out at the canvas's edge on the nucleolus's side, which is the
  left, the nucleolus lying toward the light (the user's ask, 2026-10-19);
  beside the chromosome, level with each part (see "Chromosome" below).
  Each keeps the place it has at rest through the steps either side, so it
  never jumps: an anchored name its anchor, or, where none of its anchors
  had room at rest, the place of the painter's own it took there.
- **Lines** are set in screen pixels, so they keep their weight at any
  magnification.

Every colour comes from `ZoomInks`, built from the theme:

| Ink | From | Drawn as |
|---|---|---|
| `ground` | `surface` | the ground at every stop |
| `raised`, `overlay`, `high`, `outline` | the surface containers and the outline | form in shade (`shade(t)`) |
| `lit(t)` | the outline lerped toward `onSurface` | form in the light |
| `label` | `onSurfaceVariant` | fine lines, quiet words |
| `text` | `onSurface` | rims, bright words |
| `mark`, `markDeep` | `primary`, `primaryContainer` | the gene and what it makes (`glow(a)`) |
| `shadow` | the ground three quarters of the way to black | shadows under forms |
| `blood` | the walk's thymine | red cells |
| `bases` | `NucleotideColors.helix` | the helix's bases |
| `cds`, `utr`, `intron` | `AnatomyColors`' roles | the gene's parts |

`zoom_inks_test` holds that no colour in `lib/features/zoom/` is written as
a number, and that every ink is the theme's own or a mix of its own.

**Arrival beats.** Each stop plays a beat once as the depth comes to rest
on it; the DNA moves for as long as it is shown. Nothing moves under
reduced motion.

| Stop | Beat |
|---|---|
| Body | a band of the accent passes from head to foot in 1.1 s, then a ring pings from where the zoom goes into the followed organ (0.9 s) |
| Organ | a band of light passes over it (1.2 s), and the place it is sampled pings |
| Tissue, cell, nucleus | the zoom's cell, its nucleus, the gene's territory ping once (1.1 s) |
| Chromosome | the gene's two FISH spots flare once (1.1 s) |
| DNA | the helix turns once in 24 s |

## One path per gene

The organ and the cell are not chosen by the app. The `locus` track's schema 2
(`pipeline/locus/` in the backend) chooses them, by one rule from the Human
Protein Atlas's readings:

- the organ is the tissue the RNA is highest in;
- the cell is one that lives there: the Atlas's own tissue cell type pair
  for that tissue, else the highest single cell type whose home it is, else
  none, and the tissue's own cells are drawn and said to be;
- a gene specific to no tissue goes to its top cell type's home;
- a cell with no nucleus lands in the one that has one.

Schema 1 took the top tissue and the top cell type each on its own, and seven
of the twenty went down into a cell of another organ: TNF's bone marrow into
microglia, myoglobin's skeletal muscle into thymic myoid cells. The bake's
README tabulates all twenty paths. A schema 1 payload still reads, with the
old rule.

## The camera

Each stop is a scene drawn in its own units: the width of the view at its
stop is one unit, and its origin is the middle of that view. Between two
stops the view narrows by the segment's factor, logarithmically in depth.

Each scene says where the next stop lies in it (its portal). The camera is
worked out from where the portal is on screen: the portal's offset from the
centre shrinks to nothing over the first 60% of a segment (a smootherstep),
and the centre follows. So the target never leaves the view, and every value
is a continuous function of depth. `zoom_domain_test` holds the portal on
screen and the view smooth across every segment of four genes, and holds the
scene two segments share to the same place at the stop between them.

- **Travel.** A segment's depth is its decades, but at least 0.6. The step
  from the nucleus to a long chromosome is only 0.07 decades: chromosome 1
  condensed is almost as wide as the nucleus, so it would otherwise flash by.
- **Units.** The view reads in metres down to the chromosome and half way
  past it, then in base pairs. The band, the gene and the DNA are placed in
  base pairs, projected to the screen in doubles, so no canvas transform
  carries the 10⁸-fold narrowing.
- **Framing.** A phone's canvas is about 1.45 times as tall as it is wide,
  so an organ taller than it is wide is framed by its height, and the
  chromosome's view is 0.9 of its condensed length, so it stands about
  three quarters of the canvas tall.

## The body and the organ

**The figure.** The body is the Expression Atlas anatomogram's standing
figure (EMBL-EBI, CC BY 4.0): its line art, and inside it a shape for every
tissue, named by UBERON id. `tool/zoom/anatomogram.py` reads the three
drawings (female, male, and a brain in four views) at one pinned commit,
holds each to its digest, and writes
`lib/features/zoom/domain/anatomy_figures.g.dart`: every outline
simplified (Ramer-Douglas-Peucker) and measured in metres on a figure 1.70 m
tall, only the tissues `anatomy_tables.dart` names kept, of the brain only
its mid-sagittal view. About 95 KB of source for all three. `--check` fails
if the file is stale.

The outlines are compiled in rather than bundled: the app's asset list is
held to three files by a walk test, and the figures are code-sized.

**Which figure.** A tissue only one sex has is shown on that body: the
fallopian tube on the female figure, the testis on the male. Any other is
on both, and the figure is then the one that has more of the other tissues
the gene is raised in, the female where they tie
(`AnatomyFigure.bodyFor`). So a gene of the liver alone is shown the female
figure, and nothing is meant by it.

**A glass figure.** The silhouette is sculpted and lit with a rim, its line
art in the quiet ink, and every organ inside it a faint outline. Lit are
the tissues the Atlas reads the gene's RNA raised in, glowing in the accent,
each as bright as its level against the highest: myoglobin's skeletal
muscle fully, its heart and tongue less. The one the zoom goes into is
ringed, and its lit shape is the only mark on it, however small it is
drawn: no dot is set on it (the user's choice of 2026-10-18). Skin is lit
as the figure's own edge.

**One outline, two scenes.** The organ's scene draws the very outline the
body drew for it (`OrganArt`), so the step is one shape seen closer. It
comes up over the body's own drawing of the organ early in the step, and
`zoom_anatomy_test` holds the two to the same point of the screen while both
show. On the way in, the body's line art and its unlit organs give way. The
pancreas and the testis then draw in to outlines of their own ("The
pancreas" and "The testis" below).

**Its real size.** The anatomogram is a diagram: it draws a stomach 11 cm
long and a pancreas 9. Each organ therefore knows how many times its drawn
size it really is, and grows to that over the second half of the step, as
the body fades round it, its sculpting and its inner anatomy coming up as
it grows. At the organ's stop the scale bar is true of it. A marker shows
where in it the tissue is sampled, the one a map uses for where you are: a
dot of the accent in a thin ring of the bright ink, in a soft glow
(`Sculpt.beacon`). It gives way to the loupe as it opens there.

**In place.** The figure's own parts near the organ are drawn faintly round
it, fading with their distance from it. The pancreas and the testis have
their own neighbours instead, and the figure's parts go as those come up.

**Its anatomy.** The twenty's paths reach thirteen organs. Eight kinds have a
study of their own (`OrganStudy`), and the pancreas and the testis drawings
of their own (below); in each the part the zoom's cell lives in is in the
accent, by the kind of organ and of cell, never by gene:

| Organ (proteins) | Drawn | In the accent |
|---|---|---|
| Salivary gland (AMY1A, LYZ) | lobules, the duct out of its hilum | the acini |
| Bone marrow (HBB, TNF) | the anatomogram's femur cut along its length: cortex, spongy ends, the shaft's cavity | the red marrow in the spongy ends |
| Liver (EPO, SOD1) | two lobes either side of the falciform ligament, portal vessels from the hilum | the lobules, as a honeycomb |
| Adipose tissue (LEP) | lobes parted by septa, small vessels | the lobes |
| Skeletal muscle (MB, DMD) | fascicles along its length, tendon at its ends | the fibres |
| Fallopian tube (RLN2) | opened along its length: its wall, its lumen | the folds of its mucosa |
| Stomach (TP53) | opened: its wall, the rugae, arcades of vessels along its curvatures | the mucosa |
| Pituitary gland (GH1) | from the side: posterior lobe, stalk, hypothalamus, the sella turcica | the anterior lobe |

The brain (OXT, AVP) is the anatomogram's own brain cut down its middle,
with its sulci, the corpus callosum, the cerebellum's folia and arbor
vitae and the brainstem, the cortex in the accent; for the choroid plexus
(PRNP), the lateral ventricle opened, its fronds in the accent. The lymph
node (APP) is drawn from general anatomy: capsule, follicles, medulla and
the sinuses, which are in the accent for an endothelial cell, the follicles
for a leukocyte.

Every other outline is sculpted with a surface for its kind:

| Look | Organs |
|---|---|
| lobules | glands, ovary, prostate, breast, placenta |
| a wall round a lumen | bladder, gallbladder, uterus, gullet |
| fibres | heart, tongue |
| airways from the hilum | lung |
| cortex and pyramids | kidney |
| coils | intestine, epididymis, seminal vesicle |

Where the anatomogram has no outline that shows a tissue, the organ is
drawn from general anatomy: a length of artery, a block of skin, a
parathyroid gland on the back of the thyroid, the eye cut level with the
retina lining it.

**The pancreas.** It is drawn as a fresh specimen under the zoom's one lamp,
with the stomach taken away (`presentation/scenes/pancreas/`, the user's
choices of 2026-10-18), and in the neutrals but for its vessels and the
accent:

- *Its shape* is an anatomy plate's (`pancreas_anatomy.dart`, in
  centimetres on a gland 16 cm long): head, uncinate process, neck, body
  and tail. It is as wide as the anatomogram's outline grows to and about
  its middle, and the anatomogram's site stays its site, in the head on
  either figure.
- *Its surface.* The outline is inflated into a rounded relief (φ with
  ∇²φ = −1 inside and 0 outside, the height √(2φ): round in section, the
  head thicker). Some three hundred lobules of about 4.6 mm lie on it,
  their true size (the user's choice over an exaggerated 7 mm), gathered
  into lobes about a centimetre across with deeper clefts between them.
  Each lobule is a lit dome with a moist sheen, the gland darker toward its
  silhouette. They are meshes (`ColouredMesh`, which the chromosome's are
  laid with too), built once for a set of inks, ahead of the stop.
- *Round it,* dimmer than the gland: the duodenum's C, its first part in
  front of the head and its cut ends open; the spleen beyond the tail; the
  coeliac trunk, the splenic artery winding in and out along the upper
  border, the hepatic arteries; the superior mesenteric vein and artery
  coming from under the neck, over the uncinate process and the duodenum's
  third part; the bile duct, seen where it really shows from the front,
  above the duodenum and in the crease beside the head (the user's choice
  over a faint course through the head). The vessels are in the blood red,
  the veins darker. Nothing is named: the card names the organ.
- *In the accent,* by the zoom's cell: for an endocrine cell its islets, a
  few hundred drawn at their true size (80 to 240 µm across, never less
  than a pixel), more of them toward the tail and where the gland is
  thicker; for a duct cell the gland's front cut away along the main duct,
  its ducts in the accent over the cut face's septa, the accessory duct to
  its papilla and the bile duct joining at the ampulla, the cut's wall in
  shade on the side facing the light and lit on the other; for any other
  cell its lobules washed in the accent.
- *On the step from the body* the hand-over is the anatomogram's flat lit
  outline, drawn as every organ's is. It then draws in to the gland's
  outline, matched at the top of the tail and the outer edge of the head,
  and becomes the bed the lobules lie on, while the gland and its
  neighbours come up over it in one layer and the figure's parts go. Both
  follow the organ's detail itself (the gland as its 1.25th power), which
  rises at most 0.074 a frame: a fade over part of it would change faster
  than the 0.08 a frame the zoom allows.

**The testis.** It is drawn as a fresh specimen under the same lamp: the
right testis seen from its lateral side and cut down its length, as the
plate the user gave for reference shows it (`presentation/scenes/testis/`,
the user's choices of 2026-10-19), in the neutrals but for its vessels and
the accent:

- *Its shape* is a plate's (`testis_anatomy.dart`, in millimetres on a
  testis 50 mm long): an egg 29 mm across the cut, flatter at the back,
  its upper pole tilted 15° forward. Its middle is the anatomogram's oval's,
  and the oval's site, its middle, stays its site.
- *Its cut face.* The tunica albuginea is a rim half a millimetre thick, lit
  as it curves away. Sixteen septa fan from the mediastinum to it, every
  second one forking near it, and each lobule between them is a low
  cushion. In each lobule lie its tubules at their true size, 170 µm across
  and 270 µm apart: the outlines of a forest of trees grown at once, from
  cells by the lobule's apex, through a grid laid along the lobule, so that
  no tubule crosses another or itself, each turning where its tree
  branches or ends, and waved a little where it lies away from the
  lobule's edge. The tree rooted nearest the apex is opened there, its two
  ends running side by side into the mediastinum as the tubuli recti; the
  rest are the loops the cut shows. They are lit tubes on their lobule's
  cushion, the dark interstitium between them, the pale septa over the
  lobules' edges.
- *The mediastinum* is fibrous and pale along the upper back, wider above,
  and the rete testis in its upper part a sponge of dark spaces.
- *Round it,* dimmer than the testis: the epididymis along the back, its
  head lifted off the upper pole (the user's choice, as the plate lifts
  it), its body and tail below; knobbly, the head with its lobules and the
  body and tail with coils lying across them. Twelve efferent ductules wind
  up from the rete into the head, in step so that none runs into the next.
  The vas deferens turns up from the tail, convoluted at first; the
  testicular artery and five veins of the pampiniform plexus are braided
  round one another, three of the veins behind the artery, and the cord
  fades out above the head. The tunica vaginalis is a faint film round the
  testis and the epididymis. The vessels are in the blood red, the veins
  darker.
- *In the accent,* by the zoom's cell: the tubules washed in it for a germ
  cell, a Sertoli cell, a peritubular cell or any other; for a Leydig cell
  the tubules plain and a dust of Leydig clusters through the interstitium,
  at their true size (44 to 100 µm across, never less than a pixel), one at
  the site.
- *Its names,* the main parts and no more (the user's choice): where the
  cell lives, at the site, its line in the accent (`seminiferous tubules`,
  or `interstitium` for a Leydig cell), and the `epididymis`, the `rete
  testis` and the `vas deferens`, in the quiet ink. They are set round the
  testis and the epididymis; above the head the cord only fades, and a name
  may lie beside its end.
- *Its view* is framed 1.2 times as tall as wide (`ZoomDepth.testisUpright`),
  where the anatomogram's oval framed it at 1.45. With the head lifted above
  it and the tail below, the specimen is taller than the oval, and at 1.45
  its names had no room on a canvas 320 by 420. The testis is about 290
  points tall on a phone 390 wide.
- *On the step from the body* it comes up as the pancreas does, by the same
  code (`OutlineMorph`, `SpecimenStep`, `_SpecimenOrgan`): the oval, flat
  and lit in the mark, draws in to the testis's outline, matched at their
  tops and their backs, and becomes its bed, while the testis and its
  neighbours come up over it and the figure's parts go.

**The glide.** The camera carries the organ from where it lies in the body
to the middle of the view over the first three fifths of the step. From the
head or the thigh that is a long way, and `zoom_smoothness_test` plays every
step of every protein at 60 fps.

## The tissue

**The convention.** The tissue is a section as a pathologist reads one,
seen in the round field of an eyepiece 500 µm across (what a ×40 objective
shows), five sixths of the view wide. Each part is laid by the stain it
would take (`SlideInk`) and drawn in the zoom's inks, as though the section
were lit from the side on the app's ground (`paintTissueSlide`):

| Part (`SlideInk`) | Drawn |
|---|---|
| what takes no stain (`lamp`) | the ground |
| matrix and cytoplasm, palest to deepest (`eosin0` to `eosin3`) | the shade ramp, up into the light |
| ribosome-rich cytoplasm (`basophil`) | a cooled neutral |
| granules, striations (`granules`, `stria`) | lit, the striations as stripes 2.5 µm apart once they are wider than a pixel |
| cell borders (`border`) | the ground, stroked thin |
| fibres, cilia, tails (`fibre`) | the quiet ink, faint |
| lumens, fat, vessels (`clear`) | the ground, rimmed in light |
| nuclei, open to dense (`nucleus0` to `nucleus2`) | the quiet ink, brighter the denser |
| red cells | the thymine red |
| where the zoom's kind of cell lives (`home`) | the accent, faint |
| the zoom's cell | the accent: fill, glow and rim |

**One engine, a recipe an architecture.** `TissueSlide` lays a slide once,
in micrometres, from the tissue's recipe: each of the Atlas's 37 tissues has
one of 24 (`tissueAnatomy`). The engine (`SlideBuilder`) is seeds and the
Voronoi cells round them, relaxed so they pack as cells do, an epithelium set
cell by cell along a line, vessels, and fibres, all from one seeded
generator, so a tissue is the same slide every time. Sizes are the tissue's
own: a hepatocyte 24 µm, a fat cell 66, a seminiferous tubule 190 across.

| Recipe | Tissues | What is laid |
|---|---|---|
| acinar | pancreas, salivary gland | acini edge to edge, a pinpoint lumen; an islet among them, or a duct in its sheath, where the cell is of one |
| hepatic | liver | plates one or two cells thick running out from a central vein and branching, sinusoids with their lining cells and red cells |
| endocrine | pituitary, adrenal, parathyroid | nests of acidophils, basophils and chromophobes, sinusoids between the nests |
| follicular | thyroid | follicles of colloid walled by cuboidal cells |
| gastric, renal | stomach, kidney | glands or tubules cut across; the kidney's about a glomerulus |
| seminiferous | testis | tubules: spermatogonia and Sertoli cells, spermatocytes, round then elongating spermatids, tails in the lumen; Leydig cells between |
| choroidPlexus, placental | choroid plexus, placenta | fronds or villi cut every way, a capillary core in each; the mother's blood round the villi |
| glandular, intestinal | tube, uterus, prostate, breast…; intestine | a mucosa in folds, ciliated, more folds free in the lumen; or villi with goblet cells and crypts |
| squamous, urothelial | skin, gullet, cervix, vagina; bladder | layers on a wavy floor, flattening to the surface; or the bladder's, with large cells on top |
| alveolar | lung | air spaces, capillaries in their walls |
| lymphoid | lymphoid tissue | a node's edge: fat, capsule, the sinus under it, cortex and a follicle |
| vascular | blood vessel | an artery's wall along its length |
| marrow | bone marrow | blood-forming cells, fat cells, megakaryocytes, a sinusoid |
| skeletalMuscle, cardiac | muscle, tongue; heart | fibres along their length, striated |
| neural, retina | brain; retina | grey matter; the retina in its layers, vitreous to choroid |
| adipose | fat | fat cells edge to edge |
| smoothMuscle, ovarian | smooth muscle; ovary | spindle cells in sheets, or streaming in whorls |

**The zoom's cell belongs where it sits.** It is drawn at the middle in the
same outline the cell's scene draws (`cellOutline`), and the recipe lays
the tissue about it, the place its kind lives faint in the accent round it:

- an acinar cell is one of a ring, its apex on the lumen; a beta cell is in
  an islet; a duct cell in a duct's ring;
- a hepatocyte is in a plate, the lobule turned so that a file runs through
  it;
- an erythroblast is in its island, the one the cell's scene shows: the
  macrophage, the brood round it, the grown red cells leaving;
- a muscle fibre runs across the whole field, striated every 2.5 µm as it is
  in the cell's scene, its other nuclei where that scene has them;
- a ciliated cell stands on a fold with its apex to the lumen; a plexus
  cell on a frond;
- a spermatocyte is in the second layer of a tubule's wall; a lymphatic
  endothelial cell lines the sinus's floor; a dividing cell is in a gastric
  gland.

Where the path names no cell that lives in the tissue, the tissue's own
principal cell is drawn there.

**Layers.** A slide is five layers, each drawn whole over the one before:
what lies under the cells, the cells, two for what is laid over them, and the
zoom's own cell. In a layer the inks go down in one order: matrix and
cytoplasm, granules, striations, where the cell lives, borders, fibres,
lumens, nuclei, red cells.

**The loupe.** From the organ, the field opens as a loupe on the place the
organ is sampled: a circle that grows from 56 px to the eyepiece's field
while it shows 0.3 and then 0.83 of the scene, so the magnification barely
changes, the organ dimming to the ground round it. Its rim is lit, with an
arc of the accent along its upper left, and the field falls off toward its
edge as an eyepiece's does. It meets the camera's own scale at the tissue's
stop. A step of some hundredfold becomes a change of instrument.

**Into the cell.** The slide is paths, not a picture: as the view closes on
the cell it stays sharp, and a fibre's striations and an acinus's cells come
up to meet the cell's own scene, whose ground spreads out from the same
outline.

## The cell and its nucleus

**The cell** is sculpted: its body lit from the upper left with a rim, the
endoplasmic reticulum and the microtubules from the centrosome hairlines in
the quiet ink, a muscle fibre's striations lit, and its nucleus a lit sphere
ringed in the accent, the gene being in it. The protein glows in the
accent where the Atlas finds it, brighter at its main locations, fainter at
its additional ones: each of the Atlas's 49 subcellular words is drawn in a
compartment (`compartmentOf`). A protein the Atlas finds secreted leaves the
cell in vesicles from the Golgi, on the ambient clock. Where the Atlas
gives no location, nothing glows and nothing is named.

**Shapes.** The cell's shape is its kind's, chosen from the Atlas's class,
with refinements by name (`cell_archetypes.dart`):

| Shape | Look |
|---|---|
| hepatocyte | polygonal |
| acinar | pyramidal |
| endocrine | rounded |
| ciliated | columnar |
| endothelial | flat |
| neuron | dendrites and an axon |
| myofibre | striated, its nuclei along its rim |
| adipocyte | one lipid droplet, its nucleus pressed to the rim |
| erythroid | the erythroblastic island |
| megakaryocyte, leukocyte, germ cell, dividing cell, trophoblast | their own shapes |

Each has a real size, and so do their nuclei. The nucleus view is widened to
fit a long chromosome condensed, and the cell view to fit its nucleus, so the
dive never turns back: a metaphase chromosome 1 is longer than a small
nucleus is wide.

**No nucleus.** A cell type with no nucleus lands in its precursor's island,
in the marrow: a macrophage, erythroblasts round it at every stage (the last
pushing out its nucleus), and grown red cells leaving it, biconcave discs in
the thymine red.

**Transitions.** Coming in from the tissue, the ground spreads out from the
cell. The cell's nucleus and the nucleus's own share one outline
(`NucleusShape`): round, a lens, a crescent or lobed. So the step between
them changes no shape. On it, the nucleus's even tone resolves into its
territories, and the gene's comes up in the accent.

**The nucleus** holds 46 territories:
- each as large as its chromosome's DNA (hg38 lengths);
- gene-dense chromosomes toward the centre and gene-poor ones at the rim;
- the five acrocentrics round the nucleolus, which the cell drew and the
  nucleus draws again, the same shape in the same place and the same near
  black, over the nucleus's light (`Nucleolus`), named here, outside the
  nucleus on its left, in the quiet ink;
- in nine tones of one neutral, the gene's chromosome in the accent, and
  its other copy, where the body has one, drawn whole over the rest in a
  neutral 30% of the way to the accent with an edge in it, no glow and
  no ping;
- pores in the envelope once there is room to see them.

The followed territory is the outline the chromosome condenses from. As it
condenses, the others drift out from it and fade.

## The molecular end

**Chromosome.** At its stop the chromosome is drawn as a scanning
micrograph shows one (the user's choice of 2026-10-15). It is drawn from
its own track: its length, its centromere and its bands are its own, so
proteins on one chromosome share it and only their gene tells them apart.
- Two sister chromatids, each as thick as a chromatid is, touching along a
  groove and pinched together at the centromere, opening a little toward
  their ends, both arms bent a little the same way.
- Their surface knobbly with chromatin, lobes and granules laid by a seed
  of the chromosome's own, lit from the upper left as a micrograph sees
  it: bright at the edges toward the light, dark in the crevices and along
  the groove. A soft coat lies round them and a shadow under them.
- The G-bands as soft changes of tone through the relief, the same height
  on both sisters, `gvar` an even grey.
- Nothing narrower anywhere but the centromere and the two ends. On an
  acrocentric the short arm is whole, as thick as any arm: its satellite
  and `stalk` are bands like any other, since a stalk drawn thin, as a
  notch or as a satellite on a thread, read as a cut (the user,
  2026-10-15).
- The gene as FISH marks one: two soft spots in the accent, one on each
  sister at its height, over a faint wash of its band, which is bracketed
  and named. The spots flare once as the stop is reached.
- Its parts named in the quiet ink (the user's ask, 2026-10-19), each
  just off the chromosome's outer edge, level with what it names: the p
  arm (its middle), the centromere and the q arm (its middle) on the left;
  a chromatid and a telomere on the right, where the band's name is too.
  The telomere named is at the end further from the gene's band, and the
  chromatid at whichever of a quarter, 45% and 65% of the way down the q
  arm is furthest from both, so no name on the right crowds another. A
  name with no room level with its part is set a little below it or
  above, and only then on the other side. They come and go with the
  band's name.

It is never the gene: the band is millions of base pairs, a stain pattern
seen at low resolution, and the spots are a probe's. Each sister is a mesh
built once (`ChromosomeArt`): its body lit vertex by vertex, its lobes as
small domes over their crevices, the kinetochore's plate and its granules,
so a frame at rest only hands the meshes on.

**Condensing.** On the way in, the chromosome condenses out of its
territory.
- At the nucleus, the nucleus alone draws the gene's territory. Once the
  step is under way the chromosome draws it, through the same painter, so
  the two meet to half a pixel.
- The territory's outline draws in to the two sisters' own silhouette,
  into the cleft where they part toward their ends, while its accent gives
  way to the chromatin's mean tone and the nucleus's glow and edge fade.
- The micrograph comes up over that fill, which goes last, so nothing of
  the nucleus shows through it as it comes. The gene's spots and its
  band's bracket come up after.
- From 98% of the step every part is at rest and the stop itself is
  drawn, so the step's last frames are the stop's.

The step from the nucleus to a long chromosome is a beat in time more than
a change of scale (0.07 decades for chromosome 1), and the minimum travel
gives it its room.

**Into the map.**
- On the way out, the micrograph fades over the first 30% of the step.
  Under it the chromosome turns about its band to lie along the genome,
  short arm to the left as genome browsers draw it, as one smooth tube
  (`ChromosomeTube`, laid afresh each frame), all over the first 35%:
  - its sisters merge onto the axis and it thins to the band strip's 26 px;
  - its bands' softened edges harden, and its rounded ends shorten to the
    strip's;
  - the centromere's waist becomes the strip's pinch;
  - its colours ease from the micrograph's shading to the strip's stains
    under the strip's own light, which stays on the screen's upper left
    as it turns.
- The gene's band is ringed as the strip rings it, and the gene's two
  spots merge on the axis into one, in the glow the map marks the gene
  with, until the map's own mark of the gene takes over in its place.
- From 35% on the tube is the strip, pixel for pixel. The band's strip
  appears exactly where the turned chromosome lies: at every moment the
  chromosome's length on screen and the strip's length of genome are the
  same number of pixels, by the camera's own arithmetic, and the strip lies
  on its scene's own origin, which the camera brings to the middle of the
  view. The chromosome stays under the map until the map is all there.
- The strip stays where it appears, a ruler in base pairs comes up under
  it, the gene is marked on it, and the whole chromosome docks above with
  the view boxed on it. The scale bar changes from µm to Mb half way.

**Band.** As a genome browser shows it:
- the strip, 26 px, a lit tube of the bands laid along the genome, on the
  middle of the view, each band named over the part of it in view where
  that part has room for its name, and the gene's band ringed in the
  accent. Only the centromere is pinched, to 0.55 of the strip: a stalk is
  drawn as thick as any band, as on the chromosome (the user's choice of
  2026-10-15);
- the gene marked on the strip, where MANE puts it, and named: its stretch
  ringed in the accent, 8 px proud of the strip, at the least a tick
  1.5 px wide. Seventeen of the twenty are ticks; APP, CFTR and DMD are
  rings as wide as they are. It had a track of its own under the strip,
  with an arrow for its strand, until the user chose to mark it on the
  strip (2026-10-14); the gene's own card says its strand;
- the whole chromosome docked at the top as a lit ideogram, the view boxed
  on it in the accent, and a funnel from the box down to the strip;
- a ruler in Mb, 40 px below the middle.

**Into the gene.** The gene has a stop of its own between the band and the
DNA. On 2026-10-14 it became one stop with the DNA, which looked like the
DNA; on 2026-10-15 the user asked for it back, keeping the dive's look. The
step from the band opens the gene out of its mark, 0.7 decades for
dystrophin to 3.8 for oxytocin.
- The zoom goes into the gene's mark at its middle, where the gene's stop
  is centred. The gene reads 5′→3′ left to right from its first frame, as
  the walk does, whatever its strand: on the strip the gene is a mark with
  nothing inside it to turn, and a mark turned over about its middle is the
  same mark, so a gene on the reverse strand is drawn mirrored. A turn of
  reverse-strand genes was planned once and dropped: it swung dystrophin's
  5′ end across the view by up to 3 px a frame, past the smoothness bound.
- The band names the gene at the top of its mark, over its middle, so the
  name's dot stays put as the view closes on it.
- As on the dive that ran from the band to the DNA in one step, the gene
  comes up in its mark a little before the map gives way: the gene from a
  quarter of the step, the map from about a third, each over 45% of it.
  Both come later than on that dive, which was five to six decades deep,
  so the map goes while the mark opens past a few tens of pixels, as it
  did there.
- The gene's ruler, start, 3′ end and exons' numbers come up over the last
  45% of the step, as the map goes; an exon's number as its block grows
  from half its size at the stop to its size there.

**Gene.** As a genome browser draws a transcript, and still: nothing reads
it, as nothing reads the helix at the DNA (the user's choice of
2026-10-15; until 2026-10-14 a polymerase passed along it every 9 s, its
transcript trailing in the accent).
- The record's exons and introns are at their real lengths (`GeneLayout`
  uses `realIntronBp` for the three genes whose record shortens its
  introns), placed along the span MANE gives, in a view 1.3 times as wide.
- Exons are lit, rounded blocks in the walk's role colours: coding exons
  tall, and numbered where they are 16 px wide at the stop, their
  untranslated ends short. Introns are a lit hairline with chevrons the way
  the gene is read.
- A name, its line in the accent, marks where transcription starts (no bent
  arrow beside it: the user found the two heavy, 2026-10-16), and a ruler
  counts from the 5′ end.
- The card names the gene and its length, its exons and its strand:
  `INS · 1,431 bases`, `Three exons · reverse strand`.

**DNA.** The card says the first bases its helix carries, over them, 5′ to
3′: `First 33 bases`.
- On the way in from the gene, the view closes in on its 5′ end. The
  gene's ruler, numbers, start and 3′ end go over the first 45% of the
  step. Its exons and introns give way by the view's width and are gone by
  400 bp, before the helix comes up: over a tenfold narrowing (4 kb to
  400 bp), as on the dive from the band, or over 0.45 of the step where
  that is more. A deep step crosses a decade too fast for a fade at 60 fps:
  dystrophin's is 5.3 decades, so its exons give way from about 100 kb. A
  short gene's give way from its own stop. The gene's stop draws them all
  the way and the DNA's never does, so the two never draw them at once.
- Past a few thousand base pairs, the gene's line is a fibre of
  nucleosomes: a core of 147 bp seen side on, its DNA passing behind and in
  front of it, one every 200 bp. The first sits 40 bp into the gene and the
  stretch before it is bare.
- Beads come up once they read as beads and give way before one fills the
  view. The fibre's line comes up with them and as the gene's exons, which
  lie over it, give way.
- Under 420 bp across the view, the bare 5′ end resolves into the home
  screen's own double helix, drawn by its own painter (`DnaHelixPainter`, in
  `lib/shared/helix/`): lying along the gene with its 5′ end at the left,
  14 base pairs across the view, carrying the record's first 33 bases in
  the bases' colours, its backbone in the quiet ink, running off the canvas
  on its 3′ side. It turns once in 24 s. Unlike the home screen's, nothing
  transcribes it: no bubble opens and no strand peels away, so every base
  stays paired (the user's choice of 2026-10-14).
- "Walk ›" unzips it into the walk's rows (`HelixModel(unzip:)`) over
  450 ms before the walk opens, its turn easing to flat by the shortest way.

## Smooth motion

**Flights.** A step is a flight in depth, a quintic from the depth and the
speed it has to the stop, arriving with no speed and no change of speed.
It takes 1.3 s plus 0.15 s a decade, held between 1.45 and 1.9 s: the
shortest steps need 1.4 s to keep every fade under 0.08 a frame at 60 fps,
and a long chromosome's turn into its band about 1.6. The step from the band
to the gene crosses 0.7 to 3.8 decades (1.45 to 1.87 s), and the step from
the gene to the DNA 1.9 to 5.3 (1.59 to 1.9 s). A step asked for
mid-flight starts the next flight at the speed the depth has, so it carries
straight on. A flick coasts 0.35 s at its own speed to choose its stop, and
a critically damped spring (stiffness 140) takes it there.

**Two layers.** The scenes are drawn again only when the depth moves. What
moves at rest (a beat, a helix turning, vesicles leaving a cell) is drawn
on a layer of its own (`ZoomScene.paintAmbient`) on an ambient clock that
runs only while a scene on screen wants it (`wantsClock`). A stop's beats
run on its dwell, the seconds since the depth came to rest there; under
reduced motion the dwell is long past every beat.

**Built ahead.** Each scene builds what it caches (`ZoomScene.prepare`)
before its first frame: one scene after each frame while nothing on screen
moves, the nearest the stop first, and the stop the zoom opens on holds its
beats until they are built. A step builds the scenes it will pass before it
moves, a pinch the two stops either way of where it starts. The tissue's
slide is the costly one: up to 60 ms on a Mac for the fallopian tube's
folds, which once fell in the last frame of the step to the organ.

**What `zoom_smoothness_test` holds.**
- Every protein's dive at 6,000 steps of depth, and every step either way
  at 60 fps, for all twenty.
- It fails on anything that appears, vanishes or changes by more than 0.08
  opacity in a step, or near the focus whose position's second difference
  passes 1.5 px. Further out, things fly outward faster the further they
  are as the view narrows, and the test checks for a break rather than a
  bound.
- A step asked for mid-flight takes over at the speed the depth has, never
  passes its stop, and comes to rest still.
- No two names overlap, and each keeps 8 pt from the edges, at 390 and 320
  wide; the band never sets two of its words over each other.
- As the step leaves the band, the gene lies on its mark on the strip, its
  5′ end at the mark's left and its 3′ end at its right, to half a pixel,
  for all twenty. Across the step to the DNA, the gene's 5′ end and the
  DNA's are one, to half a pixel. The exons show whole at the gene and on
  the way in, and are gone once the view is 400 bp wide; nothing the gene
  draws changes by more than 0.08 a frame at 60 fps, on any step to it or
  from it.
- The scale bar reads its round length at every stop, and no frame of any
  step at 60 fps changes its length by 2 px or more.

What it found over the zoom's life, and what was changed:
- **Fade windows.** Every scene's fade spans at least 45% of its segment.
- **Callouts** show around their own stop, over the last and first 35% of
  the segments either side. They run on segment progress, not on how big
  the scene is drawn, because across a six-hundredfold segment the scene's
  size races while the depth eases in and out.
- **The lesser of two fades.** Where a callout's fade meets its scene's,
  the lesser of the two is taken, not their product, which compounded into
  a snap.
- **The portal's glide** to the centre takes three fifths of the segment,
  so it stays gentle from as far as the head is from the middle of a body.
- **The flight's floor.** Steps under 1.45 s ran a crossfade in too few
  frames.
- **The scale bar.** Held to round lengths all the way, it shrank with the
  view and sprang back long at every 1, 2 and 5 it passed: nine lengths in
  the step from the organ, up to nineteen in the step from the band. Now
  it glides between the stops' round lengths and its figures count (the
  user's ask, 2026-10-14).
- **The exons' fade.** Over a fixed tenfold narrowing (4 kb to 400 bp),
  the exons of dystrophin, APP and CFTR gave way by up to 0.13 a frame on
  their deep step from the gene to the DNA, as they had on the one step
  from the band. On a deep step the fade now spans 0.45 of it, which
  holds every gene under 0.08 (2026-10-15).
- **The territory drawn twice.** At the nucleus the chromosome, already
  the step's child, painted the territory over the nucleus's own, and as
  the step began the territory's glow and edge vanished in one frame. Now
  one scene draws it at a time, through one painter (2026-10-15).
- **The strip off the chromosome.** The band's strip was drawn on the
  middle of the view, which the turned chromosome reaches only 60% of the
  way into the step; until then it showed as a second bar, up to 74 px
  off. It now lies on its scene's own origin.
- **Crossfading one picture.** The chromosome turned into the strip faded
  out as the map faded in, so half way the ground showed through both and
  the strip dimmed by about a fifth. The chromosome now stays under the
  map until the map is all there. What both draw that lets the ground
  through (the ring, the light over the pinch) it draws only as faint as
  the two together should be.
- **The gene's accent.** The spots went with the chromosome before the
  map's mark of the gene came up, so the accent went out and came back;
  they now hold until the mark takes over.
- **The band's name on the turn.** Its target stays where the band lies at
  rest as it fades over the first third of the step: followed through the
  turn and the merge, its line jolted 2.2 px a frame near the middle of the
  view.

**On a device.** On the iPhone 17 Pro simulator, in a debug build, stepping
all nine stops and back for insulin, hemoglobin, dystrophin and prion
(2026-10-14, when a polymerase still passed along the gene): each step's
median frame took 1 to 2.6 ms to build and 0.7 to 3.3 ms to raster, with
one or two frames a protein up to 24 ms to build or 30 ms to raster. The
one step from the band to the DNA and back, for insulin and dystrophin
(2026-10-14, while the gene and the DNA were one stop): medians of 1.4 to
2.4 ms to build and 0.8 to 1.1 ms to raster, the worst frame 18.5 ms to
build, half way through the step, where the card changes stop. The gene's
two steps, both ways, for insulin and dystrophin (2026-10-15): medians of
2.1 to 2.6 ms to build and 0.8 to 1.2 ms to raster, the worst frames
15.7 ms to build and 6.1 ms to raster. The
chromosome's two steps (2026-10-15, debug, insulin, amylase and SOD1,
both ways): medians of 1.0 to 2.35 ms to build and 1.0 to 1.9 ms to
raster, the arrival beat's 1.0 to 1.5 and 1.1 to 1.9; the worst frame
4.9 ms to raster, and 10 to 12 ms to build half way through every step,
where the card changes stop, as before. One frame took 32 ms to build: the
first of the first step into the band, where a debug build compiles the
tube's code. Opening and closing the zoom five times leaves the Dart heap
where it was. Flutter has
no profile mode on a simulator: a profile build on a phone, and a release
build on a mid-range Android phone, have not been measured.
`test/zoom_paint_timing_check.dart` (`ZOOM_PAINT_TIMING=1`) times each
scene's build and every moment's recording for seven proteins: every
moment records in about a millisecond or less on a Mac, the dearest the
first third of the step out of the chromosome, which lays its tube every
frame (0.4 to 0.8 ms).

## Deliberate simplifications

- **The figure is a diagram.** Organs lie and overlap as the anatomogram
  draws them, from the front. Bone marrow is its femur, sampled where the
  outline is widest; a biopsy is taken from the pelvis.
- **An organ's anatomy is its kind's.** Islets, red marrow and tubules are
  drawn where general anatomy puts them, by the kind of organ and cell,
  not measured for the gene.
- **A pancreas from a plate.** Its shape is the same on every figure, only
  scaled to the outline the figure draws and sampled where the figure
  says. Its neighbours are those a plate shows with the stomach, the liver
  and the colon taken away. A million islets are a few hundred, at true
  size, placed by chance weighted to the tail; the ducts show only for a
  duct cell, through a cut cleaner than any dissection.
- **A testis from a plate.** One testis, the right, the same in every body,
  and seen from its side though the body is seen from the front. Its cut
  shows whole tubules coiling in their lobules, laid by rule, where a real
  cut would show their cut ends; the tissue stop shows those. The
  epididymis's head is lifted off it, as a plate lifts it, so the ductules
  show.
- **One field a tissue.** Wherever in the organ it is cut, and for every
  gene that goes there with the same kind of cell. "Lymphoid tissue" is a
  lymph node, and skin has no keratin layer of its own.
- **A section in the app's light.** Each part is laid by the stain it would
  take but drawn in the neutrals, with no chromatin texture and no
  variation in section thickness.
- **A cell of its kind.** The cell is its kind's shape and size, not a
  measured cell, and the accent fills the compartments the Atlas names
  rather than reproducing its image.
- **Territories are placed, not measured.** Their order from centre to edge
  is the literature's; their places are drawn. A male figure's nucleus holds
  an X and a Y, a female's two X.
- **A dividing chromosome in a resting nucleus.** The chromosome is seen
  condensed although the cell is not dividing: the territory condenses into
  it. Nothing on screen says so.
- **Textbook packing.** Nucleosomes are drawn every 200 bp from 40 bp into
  the gene, not where they sit on this gene.
- **One body.** A gene of tissues both sexes have is shown the female
  figure, unless more of its tissues are the male's alone.
- **A micrograph in the app's light.** A scanning micrograph shows relief,
  not stain: the bands are drawn as soft changes of tone through the
  relief, and the relief is laid by rule from the chromosome's own seed,
  not imaged.
- **A probe's spot.** The FISH spots are as big whatever the gene's length:
  they say where the gene is, to within its band, not how long it is.

## Implementation and checks

- `domain/zoom_depth.dart`: the stops, travel, widths, framing and units.
- `domain/zoom_camera.dart`: the nested views.
- `domain/zoom_motion.dart`: flights and the flick.
- `domain/zoom_facts.dart`: the card's words and the credit.
- `domain/gene_layout.dart`: the gene's parts at real length.
- `domain/anatomy_tables.dart`: tissues to organs, recipes, sizes and
  territories.
- `domain/anatomy_figure.dart`, `anatomy_figures.g.dart`: the anatomogram's
  figures, and `tool/zoom/anatomogram.py`, which makes them.
- `presentation/zoom_inks.dart`: every colour, from the theme.
- `presentation/scenes/`: one scene a stop, and `sculpt.dart`, the light
  and the glows they share.
- `presentation/scenes/chromosome/`: the chromosome's form from its track
  (`chromosome_form.dart`), every number its look is tuned by
  (`chromosome_style.dart`), the micrograph's meshes (`chromosome_art.dart`)
  and their light and palette (`chromosome_shading.dart`), and the tube it
  turns into the band's strip as (`chromosome_tube.dart`).
- `presentation/scenes/organ_art.dart`: every organ's drawing, and
  `organ_studies.dart`, the eight studies.
- `presentation/scenes/pancreas/`: the pancreas and its neighbours in
  centimetres (`pancreas_anatomy.dart`), every number its look is tuned by
  (`pancreas_style.dart`), its form in the organ's scene, with the relief,
  lobules, islets, tubes and window (`pancreas_form.dart`), the light and
  palette (`pancreas_shading.dart`) and the meshes and how the step comes
  up (`pancreas_art.dart`). `presentation/scenes/coloured_mesh.dart`: the
  coloured meshes it and the chromosome are laid with.
- `presentation/scenes/testis/`: the testis and what lies round it in
  millimetres (`testis_anatomy.dart`), every number its look is tuned by
  (`testis_style.dart`), its form, with the septa, lobules, tubules, rete,
  ductules, epididymis and cord (`testis_form.dart`), and its meshes and
  how it is drawn (`testis_art.dart`). The step from the body is the
  pancreas's: `outline_morph.dart`, `specimen_step.dart`, and
  `_SpecimenOrgan` in `organ_art.dart`.
- `presentation/scenes/tissue/`: the slide (`tissue_slide.dart`), the engine
  (`slide_builder.dart`) and the recipes (`recipes_glands.dart`,
  `recipes_linings.dart`, `recipes_bulk.dart`).
- `presentation/zoom_painter.dart`: the stage (the scenes, and building
  them ahead), the scenes' layer, and the layer over it: what moves at
  rest, the callouts, the scale bar and the credit.
- `presentation/zoom_card.dart`, `zoom_screen.dart`.
- `zoom_routes.dart`: its route, in every build, and the redirects from its
  Lab links. The walk opens it by that route (`RoutePaths.zoomFor`), with
  `?over=walk` so that "Walk ›" pops back.
- The DNA's helix is the home screen's painter, `DnaHelixPainter` in
  `lib/shared/helix/`, whose `topFade`, `bottomFade` and `overscan` default
  to the home screen's, and whose `transcription` the zoom leaves null, for
  a helix nothing reads; `helix_vertices_test` pins every call the home
  screen's helix makes.
- Render check:
  `ZOOM_DESIGN_SHOTS=/tmp/zoom flutter test test/zoom_design_render_check.dart`
  writes every stop and two moments in each segment, at 390 and 320 pixels.
  `ZOOM_GENES` narrows the proteins and `ZOOM_BETWEEN=0` leaves out the
  moments; `ZOOM_MOMENTS=nucleus+2,nucleus+10,chromosome` draws those
  moments and no others (a stop, or a share of the step that leaves it). `ZOOM_TISSUE_ATLAS=/tmp/atlas` writes every recipe's slide on
  its own and `ZOOM_ORGAN_ATLAS=/tmp/organs` every tissue's organ, the ones
  no catalog protein reaches included, the pancreas on both figures about
  each kind of cell that lights a part of it of its own, and the testis
  about each kind of cell that lives in it. The picture at the top of this page
  is insulin's nine stops from it.
- The chromosome's tests: `chromosome_scene_test` (nothing narrower than
  its arms but the centromere and the ends), `chromosome_form_test` (the
  same form every time and for every protein on one chromosome, the knobs
  on their sisters, the spots), `chromosome_art_test` (the tones in order,
  the accent only in the gene's band, at rest and turning, the meshes'
  sizes, a translucent vertex over the ground) and
  `chromosome_handover_test` (the territory handed over to half a pixel,
  the condensing step's last frames the stop's, every band edge of the
  turned chromosome on the strip's to half a pixel and its colours the
  strip's, nothing changing with the clock, and every moment drawn for all
  twenty). `test/zoom_paint_timing_check.dart` times closer moments through
  the chromosome's two steps. `chromosome_names_test` sets the parts'
  names in the app's own type for every curated protein, on a phone's
  canvas, an iPhone SE's and a 320 pt one: each on its own side, level with
  its part or a step off it, its point on the chromosome, its plate over
  none of it.
- `nucleolus_test` holds the nucleolus to one shape in one place across the
  step from the cell to the nucleus (to half a pixel), its name to the
  nucleus and no other stop (which names nothing else), landing on it, set
  outside the nucleus on its left at two widths, in the quiet ink, never
  jumping from the tissue to
  the chromosome, and said once where the Atlas puts the protein in it; and
  the body plain (no round shape drawn at any size), darker at the nucleus
  than everything round it for all twenty, and no lighter than the app's
  raised surface where the glow of the gene's territory does not reach it.
- `zoom_screen_test` holds the card (its words for all twenty, fitting at
  320 pt with type turned up, and nothing on it but its words and its
  steps), the steps and the pinch, a step mid-flight, the credit, the
  opening stop holding its beats while the scenes are built, and the way
  back to the walk. `zoom_inks_test` holds the colours to the theme.
- `tissue_slide_test` lays every recipe about every kind of cell (432
  slides) and holds the zoom's own nucleus to be the only one at the middle,
  a tissue to be the same slide every time, the field inside the canvas,
  and the cell's name to land on its outline.
- `zoom_anatomy_test` holds every protein's organ to a figure that has it,
  the lit organs to the Atlas's reading, the organ's scene to the outline
  the body drew, and every organ the twenty reach to a drawing of its own
  with its site and its accent inside its outline. `zoom_domain_test` holds
  the figures themselves: 1.70 m tall, every part inside its figure with its
  site inside it, and the generated file to its source, commit and licence.
- `pancreas_form_test` holds the pancreas's site to the anatomogram's, well
  inside the head at every stage of the step, the gland to its real size
  about the same middle, the step's outline to the very curve the body drew
  at its start, the lobules tiling the gland (none in two, few in none, the
  edge knobbly by at most half a lobule), the mesenteric vessels over the
  uncinate process from under the neck, the duodenum round the head with
  both ducts meeting at its wall, the islets denser in the tail third by
  at least half again, the window holding the site and the main duct, and
  the same gland every time. `pancreas_art_test` holds the hand-over to the
  body's own outline with no layer, mesh or islet drawn, the accent to
  where the cell lives and never round the gland, the meshes the same every
  time, and the steps to it and back to 0.08 a frame and 1.5 px.
- `testis_form_test` holds the testis to 50 mm about the anatomogram's
  middle with the anatomogram's site, its parts to their measured sizes,
  the septa running from the mediastinum to the tunica with none crossing
  another, the lobules tiling the cut face, every tubule inside its lobule
  half a tubule clear of its edge and never nearer another or itself than
  a tubule's width, the opened tubules running into the mediastinum, the
  ductules from the testis into the epididymis's head, the vas from its
  tail, the cord fading out above it, the Leydig clusters between the
  tubules, each name on what it names, and the same testis every time.
  `testis_art_test` holds the accent to where the cell lives (the tubules,
  or the Leydig clusters, never the tunica, the mediastinum, the epididymis
  or the cord), the hand-over to the body's own outline with no layer, mesh
  or point, the meshes the same every time, its four names, and the steps
  to it and back to 0.08 a frame and 1.5 px. `zoom_paint_timing_check`
  times it with ubiquitin's zoom.
- `zoom_routes_test` holds the route outside the lab, the redirects, and the
  whole trip from the walk and back under the app's own routes.
  `zoom_entry_test`, among the walk's tests, holds where the gene page
  offers it and that every gene's line stays whole beside the pill.
