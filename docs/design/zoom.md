# Zoom: from a body down to one gene's DNA

## Experience

The Lab's zoom (`/lab/zoom/<slug>`) dives from a whole body to the first bases
of one protein's gene, through nine stops: body, organ, tissue, cell,
nucleus, chromosome, band, gene and DNA. It is one continuous depth.

- **Moving through it.**
  - A pinch moves the depth 2.5 for each tenfold spread of the fingers, and a
    flick coasts to the stop it would reach, settled by a critically damped
    spring.
  - A double tap goes one stop deeper.
  - The depth rail down the right edge is the walk's own `SequenceScrubber`,
    one landmark a stop. Dragging it scrubs the depth; letting go settles on
    the nearest stop.
  - The card's ‹ and › fly to the stop either side, in 350 ms plus 260 ms for
    each decade crossed, held between 450 and 2,600 ms and eased in depth.
- **Play.** ▶ plays the dive: 1.5 s at each stop and 0.9 s for each decade
  between, about 25 s from the body to the DNA. A touch on the canvas pauses
  it.
- **Reduced motion.** Steps and settles cut, and Play holds each stop for 3 s.
- **The card** names the stop and the place, gives one line of what is known
  of it, and tags where that comes from: `HPA 25.1`, `UCSC hg38`,
  `MANE v1.5`, `RefSeq record`, or `drawn` where the stop is illustration.
  Its height is the tallest stop's at the reader's text size, so the canvas
  keeps its size.
- **About (ⓘ)** says, once, what is drawn and what is data, and names every
  source with its licence.
- **At the DNA**, "Walk ›" opens the walk at the gene page.

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
centre shrinks to nothing over the first 35% of a segment (a smootherstep),
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

## The molecular end

**Chromosome.** At its stop the chromosome is a metaphase chromosome:
- two sister chromatids, pinched together at the centromere where its `acen`
  bands meet;
- stalks drawn thin, and `gvar` hatched as ideograms draw it;
- the G-bands lit from the upper left across each chromatid;
- an ISCN bracket beside the band the gene lies in, and the band's name on
  the callout.

It is never the gene: the band is millions of base pairs, a stain pattern
seen at low resolution, and the About sheet says the gene is far too small
to see in it.

**Condensing.** On the way in, the chromosome condenses out of its territory.
The nucleus hands its followed territory to the chromosome's scene at the
first frame of the segment, where the two coincide. The territory's outline
blends into the chromosome's, resampled to 128 points from the top. The
chromosome paint gives way to Giemsa's grey, the bands come up, and the two
chromatids resolve out of one shape at the end. The step from the nucleus to
a long chromosome is a beat in time more than a change of scale (0.07
decades for chromosome 1), and the minimum travel gives it its room.

**Into the map.**
- On the way out, the chromosome turns about its band to lie along the
  genome, short arm to the left as genome browsers draw it. Its chromatids
  merge and it thins to the band strip's 18 px, all over the first 35% of
  the segment.
- The band's strip appears exactly where the turned chromosome lies: at
  that moment the chromosome's length on screen and the strip's length of
  genome are the same number of pixels, by the camera's own arithmetic. The
  two cross-fade over half the segment.
- The strip then rises, a ruler in base pairs comes up, and the whole
  chromosome docks above with the view boxed on it. The scale bar changes
  from µm to Mb half way.

**Gene.**
- The record's exons and introns are at their real lengths (`GeneLayout`
  uses `realIntronBp` for the three genes whose record shortens its
  introns), placed along the span MANE gives.
- Coding exons are thick and numbered once they are 16 px wide. Their
  untranslated ends are thin. Introns are a line with chevrons in the
  direction the gene is read.
- A ruler counts from the 5′ end.
- The gene reads 5′→3′ left to right, as the walk does, from the moment it
  appears.
- A turn of reverse-strand genes was planned and dropped. The band draws
  the gene as a featureless bar, so there is nothing to see turn, and the
  turn swung dystrophin's 5′ end across the view by up to 3 px a frame,
  past the smoothness bound.

**DNA.**
- Past a few thousand base pairs, the gene's line is a fibre of
  nucleosomes: a core of 147 bp seen side on, its DNA passing behind and in
  front of it, one every 200 bp. The first sits 40 bp into the gene and the
  stretch before it is bare, as the start of a gene that is read usually is.
  It is drawn as the textbook packs a gene, not measured for this one.
- Beads come up once they read as beads and give way before one fills the
  view.
- Under 400 bp the bare 5′ end resolves into the double helix with the
  record's own first 33 bases, which turns once in 16 s while the DNA is
  near.
- "Walk ›" unzips it into the walk's rows (`HelixModel(unzip:)`) over
  450 ms before the walk opens.

**Still to come.** The scenes above the chromosome are still the earlier
illustrations on the new camera:
- the cell and nucleus in immunofluorescence and chromosome paint;
- the tissue in H&E under a loupe;
- the body and organs from the anatomogram.

## Smooth motion

Every value on screen is a function of depth, and the staging each scene
reports is what `zoom_smoothness_test` walks:
- every protein's dive at 6,000 steps of depth;
- Play at 60 fps for three of them.

It fails on:
- anything that appears, vanishes or changes by more than 0.08 opacity in a
  step;
- anything near the focus whose position's second difference passes
  1.5 px. Further out, things fly outward faster the further they are as
  the view narrows, and the test checks for a break rather than a bound.

What it found, and what was changed:
- **Play's legs.** A 0.6-decade segment once took 0.54 s of Play, so its
  crossfade ran in six frames. Every leg is now at least 1.4 s.
- **Fade windows.** Every scene's fade now spans at least 45% of its
  segment.
- **Callouts** show around their own stop, over the last and first 35% of
  the segments either side. They run on segment progress, not on how big
  the scene is drawn, because across a six-hundredfold segment the scene's
  size races while the depth eases in and out.
- **The lesser of two fades.** Where a callout's fade meets its scene's,
  the lesser of the two is taken, not their product, which compounded into
  a snap.
- **The portal's glide** to the centre takes half the segment rather than
  35%, so it stays gentle inside Play's own ease.

`zoom_smoothness_test` also places every stop's callouts at 390 and 320
wide and fails if two plates overlap or one lies under the rail.
`placePlate` tries the corners round the target in turn.

## Implementation and checks

- `domain/zoom_depth.dart`: the stops, travel, widths and units.
- `domain/zoom_camera.dart`: the nested views.
- `domain/zoom_motion.dart`: flights, the flick and Play.
- `domain/zoom_facts.dart`: the card and About.
- `domain/gene_layout.dart`: the gene's parts at real length.
- `domain/anatomy_tables.dart`: tissues to organs, recipes, sizes and
  territories.
- `presentation/scenes/`: one scene a stop.
- `presentation/zoom_painter.dart`: the visible scenes, the callouts and the
  scale bar.
- `presentation/zoom_rail.dart`, `zoom_card.dart`, `zoom_about.dart`,
  `zoom_screen.dart`.
- Colours: `ScaleColors` in `lib/core/theme/scale_colors.dart`, read through
  `context.scaleColors`. `AppTheme.analysis` is unchanged.
- Render check:
  `ZOOM_DESIGN_SHOTS=/tmp/zoom flutter test test/zoom_design_render_check.dart`
  writes every stop and two moments in each segment, at 390 and 320 pixels.
  `ZOOM_GENES` narrows the proteins.
