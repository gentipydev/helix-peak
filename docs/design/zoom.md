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

## Status

This is the engine and the screen. The scenes are still today's
illustrations ported onto the new camera and crossfaded: the body, organ,
tissue, cell and nucleus, the chromosome's bar and the helix. The band and the
gene are new. The rest of the design comes in later phases, each recorded here
as it lands:

- each scale seen the way science sees it (anatomogram, H&E, immunofluorescence,
  chromosome paint, G-banding, a genome browser);
- each transition's own animation;
- the anatomogram's outlines.

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
