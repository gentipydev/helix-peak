# Zoom: from a body down to one gene's DNA

![Insulin's eight stops on the app's ground: a glass figure with the pancreas glowing, the pancreas sculpted with its islets in the accent, an islet under the eyepiece, a beta cell, its nucleus with chromosome 11's territory in the accent, a lit metaphase chromosome 11, the band 11p15.5 under a docked map, and the home screen's helix carrying the gene's first bases](zoom.png)

## Experience

The zoom (`/zoom/<slug>`) dives from a whole body to the first bases of one
protein's gene, through eight stops: body, organ, tissue, cell, nucleus,
chromosome, band and DNA. It is one continuous depth.

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
  the map, the gene's 5′ end. A scale bar is always at its lower left: a
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
| Cell | Beta cells | Tissue cell type enriched | none: the Atlas names no place in the cell for it, and its vesicles leave the cell |
| Nucleus | Chromosome 11 territory | none | none |
| Chromosome | Chromosome 11 | 135,086,622 bp · 36 bands | 11p15.5 |
| Band | 11p15.5 | 2.8 Mb · gene at 2,159,779–2,161,209 | INS |
| DNA | INS · 1,431 bases | 5′ AGCCCTCCAGGACAGGCTGCATCAGAAGAGGCC 3′ | 5′ |

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
- **Chromosome territories.** In interphase each chromosome keeps to a
  territory of its own, and territories are ordered from the centre of the
  nucleus to its edge by gene density: chromosome 19 toward the centre, 18 at
  the edge (Croft et al. 1999; Boyle et al. 2001). Painting each chromosome
  its own colour shows them (Speicher et al. 1996; Schröck et al. 1996).
  *Consequence:* 46 territories, sized by their DNA and placed in that
  order, each a step lighter or darker than its neighbour, the gene's
  chromosome in the accent.
- **Bands.** A chromosome is seen whole only when it condenses to divide,
  some ten-thousandfold. Giemsa stain then bands it, and a band's name
  (11p15.5) is the address cytogenetics gives a gene (ISCN 2020).
  *Consequence:* the chromosome is a metaphase chromosome at that length,
  its pale bands lit and its dark ones deep, the gene's band marked and
  named, and nothing claims the gene is seen there.
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

- Boyle S et al. The spatial organization of human chromosomes within the
  nuclei of normal and emerin-mutant cells. Hum Mol Genet 2001;10:211–219.
- Chasis JA, Mohandas N. Erythroblastic islands: niches for erythropoiesis.
  Blood 2008;112:470–478.
- Croft JA et al. Differences in the localization and morphology of
  chromosomes in the human nucleus. J Cell Biol 1999;145:1119–1131.
- Davey CA et al. Solvent mediated interactions in the structure of the
  nucleosome core particle at 1.9 Å resolution. J Mol Biol
  2002;319:1097–1113.
- Expression Atlas, EMBL-EBI: anatomograms, CC BY 4.0
  (<https://www.ebi.ac.uk/gxa/licence.html>), which asks to be cited as
  "Expression Atlas in 2026: enabling FAIR and open expression data through
  community collaboration and integration", Nucleic Acids Research, 2025.
- ISCN 2020: An International System for Human Cytogenomic Nomenclature.
  Karger, 2020.
- Karlsson M et al. A single-cell type transcriptomics map of human tissues.
  Sci Adv 2021;7:eabh2169.
- Luger K et al. Crystal structure of the nucleosome core particle at 2.8 Å
  resolution. Nature 1997;389:251–260.
- Morales J et al. A joint NCBI and EMBL-EBI transcript set for clinical
  genomics and research. Nature 2022;604:310–315.
- Schones DE et al. Dynamic regulation of nucleosome positioning in the
  human genome. Cell 2008;132:887–898.
- Schröck E et al. Multicolor spectral karyotyping of human chromosomes.
  Science 1996;273:494–497.
- Speicher MR, Ballard SG, Ward DC. Karyotyping human chromosomes by
  combinatorial multi-fluor FISH. Nat Genet 1996;12:368–375.
- Thul PJ et al. A subcellular map of the human proteome. Science
  2017;356:eaal3321.
- Uhlén M et al. Tissue-based map of the human proteome. Science
  2015;347:1260419.

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
  the bases the home helix's (`NucleotideColors.dark`), and blood the
  thymine red, the one red the app has.
- **Glows** are gradients and wide faint strokes, never a blur.
- **Names.** One plate a name, with a line to what it names, set clear of
  each other and 8 pt in from the edges. The card says the rest.
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
| `bases` | `NucleotideColors.dark` | the helix's bases |
| `cds`, `utr`, `intron` | `AnatomyColors`' roles | the gene's parts |

`zoom_inks_test` holds that no colour in `lib/features/zoom/` is written as
a number, and that every ink is the theme's own or a mix of its own.

**Arrival beats.** Each stop plays a beat once as the depth comes to rest
on it; the DNA moves for as long as it is shown. Nothing moves under
reduced motion.

| Stop | Beat |
|---|---|
| Body | a band of the accent passes from head to foot in 1.1 s, then the followed organ's marker pings (0.9 s) |
| Organ | a band of light passes over it (1.2 s), and the place it is sampled pings |
| Tissue, cell, nucleus, chromosome | the zoom's cell, its nucleus, the gene's territory, the gene's band ping once (1.1 s) |
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
  past it, then in base pairs. The band and the DNA are placed in base
  pairs, projected to the screen in doubles, so no canvas transform carries
  the 10⁸-fold narrowing.
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
ringed, and marked while it is too small to see. The marker is the one a
map uses for where you are: a dot of the accent in a thin ring of the
bright ink, in a soft glow (`Sculpt.beacon`). Skin is lit as the figure's
own edge.

**One outline, two scenes.** The organ's scene draws the very outline the
body drew for it (`OrganArt`), so the step is one shape seen closer. It
comes up over the body's own drawing of the organ early in the step, and
`zoom_anatomy_test` holds the two to the same point of the screen while both
show. On the way in, the body's line art and its unlit organs give way.

**Its real size.** The anatomogram is a diagram: it draws a stomach 11 cm
long and a pancreas 9. Each organ therefore knows how many times its drawn
size it really is, and grows to that over the second half of the step, as
the body fades round it, its sculpting and its inner anatomy coming up as
it grows. At the organ's stop the scale bar is true of it. The same marker
shows where in it the tissue is sampled, and gives way to the loupe as it
opens there.

**In place.** The figure's own parts near the organ are drawn faintly round
it, fading with their distance from it.

**Its anatomy.** The twenty's paths reach thirteen organs. Ten kinds have a
study of their own (`OrganStudy`), and in each the part the zoom's cell
lives in is in the accent, by the kind of organ and of cell, never by gene:

| Organ (proteins) | Drawn | In the accent |
|---|---|---|
| Pancreas (INS, GCG, CFTR) | lobules, the main duct along its length | the islets, more toward the tail (INS, GCG); the duct tree (CFTR) |
| Salivary gland (AMY1A, LYZ) | lobules, the duct out of its hilum | the acini |
| Bone marrow (HBB, TNF) | the anatomogram's femur cut along its length: cortex, spongy ends, the shaft's cavity | the red marrow in the spongy ends |
| Liver (EPO, SOD1) | two lobes either side of the falciform ligament, portal vessels from the hilum | the lobules, as a honeycomb |
| Adipose tissue (LEP) | lobes parted by septa, small vessels | the lobes |
| Skeletal muscle (MB, DMD) | fascicles along its length, tendon at its ends | the fibres |
| Fallopian tube (RLN2) | opened along its length: its wall, its lumen | the folds of its mucosa |
| Testis (UBB) | tunica, septa from the mediastinum | the coiled seminiferous tubules |
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
- the five acrocentrics round the nucleolus;
- in nine tones of one neutral, the gene's chromosome in the accent;
- pores in the envelope once there is room to see them.

The followed territory is the outline the chromosome condenses from. As it
condenses, the others drift out from it and fade.

## The molecular end

**Chromosome.** At its stop the chromosome is a metaphase chromosome, lit:
- two sister chromatids, each a tube as thick as a chromatid is, splayed a
  little and pinched together at the centromere where its `acen` bands meet,
  with its kinetochores;
- a fuzz of chromatin round their edge;
- the G-bands ringing each chromatid as bands ring a tube, pale bands lit
  and dark ones deep, `gvar` an even grey (an ideogram's hatching reads as a
  cut on a lit form), each edge bowed as far as the tube is thick there, so
  two bands meet however it narrows;
- on an acrocentric, the short arm's satellite a round knob on the thin
  thread of its `stalk`, the knob and the arm each rounded into the thread
  as a chromatid's end is;
- the gene's band in the accent on both chromatids, bracketed and named.

It is never the gene: the band is millions of base pairs, a stain pattern
seen at low resolution.

**Condensing.** On the way in, the chromosome condenses out of its territory.
The nucleus hands its followed territory to the chromosome's scene at the
first frame of the segment, where the two coincide. The territory's outline
blends into the chromosome's, resampled to 128 points from the top. The
bands come up, the accent draws in to the gene's band, and the two
chromatids resolve out of one shape at the end. The step from the nucleus
to a long chromosome is a beat in time more than a change of scale (0.07
decades for chromosome 1), and the minimum travel gives it its room.

**Into the map.**
- On the way out, the chromosome turns about its band to lie along the
  genome, short arm to the left as genome browsers draw it. Its chromatids
  merge and it thins to the band strip's 26 px, all over the first 35% of
  the segment.
- The band's strip appears exactly where the turned chromosome lies: at
  that moment the chromosome's length on screen and the strip's length of
  genome are the same number of pixels, by the camera's own arithmetic. The
  two cross-fade over half the segment.
- The strip stays where it appears, a ruler in base pairs comes up under
  it, the gene is marked on it, and the whole chromosome docks above with
  the view boxed on it. The scale bar changes from µm to Mb half way.

**Band.** As a genome browser shows it:
- the strip, 26 px, a lit tube of the bands laid along the genome, on the
  middle of the view, each band named over the part of it in view where
  that part has room for its name, and the gene's band ringed in the
  accent;
- the gene marked on the strip, where MANE puts it, and named: its stretch
  ringed in the accent, 8 px proud of the strip, at the least a tick
  1.5 px wide. Seventeen of the twenty are ticks; APP, CFTR and DMD are
  rings as wide as they are. It had a track of its own under the strip,
  with an arrow for its strand, until the user chose to mark it on the
  strip (2026-10-14); the walk's record sheet gives the strand;
- the whole chromosome docked at the top as a lit ideogram, the view boxed
  on it in the accent, and a funnel from the box down to the strip;
- a ruler in Mb, 40 px below the middle.

**Into the gene.** One step goes from the band down to the DNA, five to six
decades: the gene and the DNA are one stop, which looks like the DNA (the
user's choice of 2026-10-14; the gene had a stop of its own before, with a
polymerase passing along it).
- The zoom goes into the gene's mark at its left end, where the DNA's view
  lies. The DNA reads the gene 5′→3′ from its left, as the walk does,
  whatever its strand: on the strip the gene is a mark with nothing inside
  it to turn, and a mark turned over about its middle is the same mark. A
  turn of reverse-strand genes was planned once and dropped: it swung
  dystrophin's 5′ end across the view by up to 3 px a frame, past the
  smoothness bound.
- The band names the gene at the top of its mark, where the zoom goes in,
  so the name's dot stays put as the view closes on it. On a tick that is
  its middle; on APP's, CFTR's and DMD's rings it is the left end.
- The map gives way over the first half of the step, while the gene grows
  out of its mark.

**DNA.** The gene's own stop: the card names the gene and its length over
the first bases its helix carries.
- On the way in, the mark opens into the gene's exons and introns at their
  real lengths (`GeneLayout` uses `realIntronBp` for the three genes whose
  record shortens its introns), as a genome browser draws a transcript:
  lit, rounded blocks in the walk's role colours, coding exons tall and
  their untranslated ends short, and introns a lit hairline with chevrons
  the way the gene is read. They show whole while the view is wider than
  4 kb and are gone by 400 bp, evenly between, so none is seen at the stop.
- Past a few thousand base pairs, the gene's line is a fibre of
  nucleosomes: a core of 147 bp seen side on, its DNA passing behind and in
  front of it, one every 200 bp. The first sits 40 bp into the gene and the
  stretch before it is bare.
- Beads come up once they read as beads and give way before one fills the
  view. The fibre's line comes up with them, so it never runs across the
  band's map.
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
to the DNA crosses five to six decades and takes the 1.9 s cap: the helix
comes up about two thirds of the way through it and settles over the last
0.6 s. A step asked for
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
- As the step leaves the band, the gene's DNA lies on its mark on the
  strip, 5′ end at the mark's left, for all twenty; its exons show on the
  way in and not at the DNA.
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

**On a device.** On the iPhone 17 Pro simulator, in a debug build, stepping
all nine stops (before the gene and the DNA became one) and back for
insulin, hemoglobin, dystrophin and prion: each step's median frame took 1
to 2.6 ms to build and 0.7 to 3.3 ms to raster, with one or two frames a
protein up to 24 ms to build or 30 ms to raster. The step from the band to
the DNA and back, for insulin and dystrophin (2026-10-14): medians of 1.4
to 2.4 ms to build and 0.8 to 1.1 ms to raster, the worst frame 18.5 ms to
build, half way through the step, where the card changes stop. A release
build on a mid-range Android phone has not been measured.
`test/zoom_paint_timing_check.dart` (`ZOOM_PAINT_TIMING=1`) times each
scene's build and every moment's recording for five proteins: every moment
records in under a millisecond on a Mac.

## Deliberate simplifications

- **The figure is a diagram.** Organs lie and overlap as the anatomogram
  draws them, from the front. Bone marrow is its femur, sampled where the
  outline is widest; a biopsy is taken from the pelvis.
- **An organ's anatomy is its kind's.** Islets, red marrow and tubules are
  drawn where general anatomy puts them, by the kind of organ and cell,
  not measured for the gene.
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
- `presentation/scenes/organ_art.dart`: every organ's drawing, and
  `organ_studies.dart`, the ten studies.
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
  moments. `ZOOM_TISSUE_ATLAS=/tmp/atlas` writes every recipe's slide on
  its own and `ZOOM_ORGAN_ATLAS=/tmp/organs` every tissue's organ, the ones
  no catalog protein reaches included. The picture at the top of this page
  is insulin's eight stops from it.
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
- `zoom_routes_test` holds the route outside the lab, the redirects, and the
  whole trip from the walk and back under the app's own routes.
  `zoom_entry_test`, among the walk's tests, holds where the gene page
  offers it and that every gene's line stays whole beside the pill.
