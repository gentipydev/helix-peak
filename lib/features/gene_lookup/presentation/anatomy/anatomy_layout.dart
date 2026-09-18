import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';

import 'anatomy_motion.dart';
import 'anatomy_ruler.dart';
import 'anatomy_stages.dart';

/// Where every cell of one stage sits inside the canvas.
///
/// There are three ways a stage gets laid out. Two of them are decided by
/// whether the stage has a reading frame to show; the third is for a region of
/// the gene opened into its DNA.
///
/// **[fit]** — the default. On the gene it is **serpentine**: rows alternate
/// direction, so base N and base N+1 are always physically adjacent, including
/// across a row boundary. A raster grid there would break intron 2's 787 bases
/// into twenty-odd disconnected stripes with a jump at the end of each row, and
/// the gene carries no letters for a reversed row to garble. [connectors] draws
/// the turn at each row end. Every residue page is fitted as a raster instead:
/// a protein is read residue by residue, and a row read right to left turns
/// `GIVEQCC` into `CCQEVIG` under a reader counting positions. It fits one
/// screen where it can; a gene too long for 14pt rows, or a protein too long
/// for 28pt tiles, keeps that size and scrolls instead.
///
/// **[intrinsic]** — the transcript page, which is the one stage drawn in
/// codons. There serpentine is not a cost worth paying: a codon on an odd row
/// would read `GTA` where the sequence says `ATG`, and the whole point of that
/// page is that the frame is legible. So it reads left to right like text, at a
/// fixed 21pt pitch, and is taller than the screen — the screen scrolls it.
/// Every base on it is 20pt across, which is the smallest a letter stays
/// legible at, and shrinking the page to fit would have cost exactly the thing
/// the page exists for.
///
/// **[inspection]** — a region of the gene opened into its DNA. It reads left
/// to right like the transcript, but every base on it is also a tap target, so
/// its tiles are about [inspectionSide] across and stretch to fill the row
/// between two gutters. A coding region is laid out in whole codons, which
/// form once it has landed.
@immutable
final class AnatomyLayout {
  const AnatomyLayout({
    required this.blocks,
    required this.columns,
    required this.cell,
    required this.gap,
    required this.rowHeight,
    required this.rowGap,
    required this.rows,
    required this.blockRow,
    required this.origin,
    this.serpentine = true,
    this.codonGap = 0,
    this.codonRow = 0,
    this.codonOpen = 1,
    this.codonRowOpens = false,
    this.radius = 0,
    this.labelRows = 0,
    this.foldFrom = const <int>[],
    this.foldTo = const <int>[],
  });

  final List<StageBlock> blocks;

  /// Cells across. Shared by every block so the chains stay comparable — and so
  /// the untranslated ends line up under the coding sequence rather than
  /// arriving at their own width.
  final int columns;

  /// Pitch of one cell across, gap included.
  final double cell;

  /// The mortar between two cells across. Stored rather than derived, because
  /// the two constructors reach it by different routes: [fit] scales it with
  /// the pitch, [intrinsic] fixes it at one point.
  final double gap;

  /// Pitch of one cell down, gap included. Equal to [cell] everywhere but the
  /// gene — see [geneRow].
  final double rowHeight;

  final double rowGap;

  /// Rows in every block, plus the gaps and label bands between them.
  final double rows;

  /// The first *cell* row of each block, in rows. A block's label band sits in
  /// the [labelRows] immediately above this.
  final List<double> blockRow;

  /// Top-left of the grid. Centred in the canvas by [fit], unless the grid
  /// outgrows it; centred across and pinned to the top by [intrinsic], and by
  /// [fit] for a gene too long for one screen, both taller than their canvas.
  final Offset origin;

  /// Whether rows alternate direction. False on the transcript page — see the
  /// class doc.
  final bool serpentine;

  /// Extra pixels inserted after every third cell of a framed block, so the
  /// reading frame is a gap the eye can see rather than a tick it has to read.
  ///
  /// A few points is the whole budget: enough to group a triplet, not enough to
  /// read as a break in the sequence.
  final double codonGap;

  /// Extra points under every row of a framed block, so a codon is a block of
  /// three and not just a triplet in its row.
  ///
  /// Zero on a fitted layout, and not because it was forgotten: [codonGap] is a
  /// fixed number of points because [intrinsic] has a fixed pitch to set it
  /// against, and so is this. A fitted stage solves its pitch out of the room
  /// it is given, and three points of air means nothing until that is known.
  /// No fitted stage has a reading frame to space out either — see [forStage].
  ///
  /// Unlike [codonGap] it does not animate, except where [codonRowOpens]. It is
  /// charged in the rows the page reserves, so opening it would resize the box
  /// the screen scrolls.
  final double codonRow;

  /// Whether [codonRow] opens with [codonOpen] rather than being there from
  /// the start.
  ///
  /// Only on a region's DNA, where the codons form after the region has
  /// landed, across and down together. The rows are still reserved open, so
  /// they spread into room that is already theirs and the page never resizes
  /// under the reader.
  final bool codonRowOpens;

  /// How much of [codonGap] is currently spent, from 0 (flush) to 1 (open).
  ///
  /// The reading frame is not there when the page arrives — it grooves itself
  /// open once the splice has settled, which is a thing that happens to the
  /// sequence rather than a fact about how it is drawn. Holding the progress
  /// here rather than in the painter is what keeps [hitTest] honest: the two
  /// walk the same [_lead], so a tap lands on the square under the finger at
  /// every frame of the animation and not only at the end of it.
  ///
  /// [gridWidth] deliberately ignores it. The page the screen scrolls must not
  /// resize while the grooves open.
  final double codonOpen;

  /// Corner radius of one cell. Zero wherever cells are drawn edge to edge and
  /// meant to fuse into runs, which is the gene.
  final double radius;

  /// Rows reserved above a labelled block for its name. Zero for a layout whose
  /// blocks are not named on the canvas.
  final double labelRows;

  /// The rows of each block folded out of view, from [foldFrom] up to but not
  /// including [foldTo], counted within the block. Empty for a layout that
  /// folds nothing, and equal for a block that is drawn whole — see
  /// [foldAbove].
  final List<int> foldFrom;
  final List<int> foldTo;

  /// Below this the squares are drawn solid, with no gap to lose them in.
  static const double solidBelow = 6;

  /// Above this each cell can carry its base or residue letter.
  static const double letteredAbove = 14;

  /// A hairline, and nothing more. Which run is an exon and which is an intron
  /// is carried by the cells themselves — an intron base is drawn quiet — so
  /// the gap is left with the one job it can actually do: stopping two squares
  /// from reading as one square twice the size.
  ///
  /// A tenth of the pitch is the figure the residue stages already arrive at
  /// through [_maxGap], so this is one rule where there were two. [_minGap]
  /// binds only between a 6 and a 10 point cell, which on a phone is the gene
  /// stage and nothing else; at a fifth it never bound at all, because
  /// `solidBelow * 0.2` was exactly 1.2.
  static const double _gapRatio = 0.1;
  static const double _minGap = 1.0;
  static const double _maxGap = 3.5;

  /// The proportions of a lettered tile, taken from the transcript page.
  ///
  /// That page is where a cell carrying a letter was actually designed — a 20pt
  /// square with a 5pt corner and a point of mortar — and it is the only stage
  /// whose pitch is fixed, so it is the only one that could hold a measurement
  /// rather than a ratio. Every other lettered stage is fitted to whatever room
  /// it is given, so what it inherits is the *shape*: a quarter of the side as
  /// a corner, and a twenty-first of the pitch as mortar.
  ///
  /// Before this, a residue was a hard-cornered square with twice the mortar,
  /// which put two different objects on two adjacent pages of the same grid.
  /// The gene keeps neither: its cells are drawn edge to edge so a run fuses
  /// into one shape, and a corner is exactly what would stop that.
  static const double tileRadiusRatio = baseRadius / baseSide;
  static const double tileGapRatio = baseGap / basePitch;

  /// Blank rows between one block and the next.
  static const double blockGapRows = 0.6;

  /// How far a row-end connector bows past the grid, in cells. The fit reserves
  /// this on both sides: a grid sized to the full width would have its turns
  /// clipped away at exactly the two columns where they carry the most meaning.
  static const double bulgeCells = 0.45;

  static const double _minCell = 2;

  // ------------------------------------------------- the transcript page only

  /// Pitch, side and mortar of a base on the transcript page.
  ///
  /// Twenty points is the floor, not a preference: below it a 12pt letter stops
  /// being legible, and a page of bases nobody can read is a page of coloured
  /// squares. One point of mortar is all that is needed to stop two squares
  /// reading as one square twice the size.
  static const double basePitch = 21;
  static const double baseSide = 20;
  static const double baseGap = basePitch - baseSide;

  /// The smallest a residue tile may be, on every page after the transcript —
  /// see [fit]'s `minCell`.
  ///
  /// Larger than [basePitch], though a base's twenty points are enough to read
  /// a letter. A residue page is read by eye in a way the transcript is not:
  /// the transcript is scanned in threes for its frame, a protein residue by
  /// residue for its chemistry, and at 21pt dystrophin's page read as a dense
  /// field of type. Twenty-eight is about where the short proteins' fitted
  /// tiles already sit (ubiquitin 29, growth hormone 29), so a long protein
  /// looks like the same page with more of it, rather than a smaller one.
  static const double residuePitch = 28;

  /// How large a base is drawn once a region of the gene is opened into its
  /// DNA — see [inspection].
  ///
  /// Larger than [baseSide], because a base there is a tap target as well as a
  /// letter, and at twenty points one is too small to hit reliably. It is the
  /// floor for a region that is never translated. A coding region has to fit
  /// whole codons and the grooves between them across, so there it is the
  /// size a base is brought nearest to.
  ///
  /// The tiles stretch to fill the row, so this moves in columns rather than in
  /// points: a region that is never translated fits one fewer of them across a
  /// phone at twenty-five than it did at twenty-four, and its bases come out
  /// about two points larger for it.
  static const double inspectionSide = 25;

  /// The air kept either side of that page's grid, so a base lifted out of it
  /// never runs off the screen.
  static const double inspectionGutter = 8;

  /// A transcript region longer than this is folded to its two ends.
  ///
  /// Dystrophin's coding sequence is 11,058 bases, which at [basePitch] is
  /// more than six hundred rows, and every one of them past the first few says
  /// the same thing: more of the reading frame. What the page is for is where
  /// each region begins and ends — the untranslated ends giving way, the start
  /// codon, the stop codon — so a long region keeps its opening rows and its
  /// closing ones, and the middle is a pill that says how much is not drawn.
  ///
  /// Folded in the layout and nowhere else. Every base is still a cell of the
  /// stage, so the splice, the translation and the tracer still find it; it is
  /// drawn at the fold, which is where the motion carries it in and out.
  static const int foldAbove = 1000;

  /// About how much of a folded region is kept at each end, in bases, rounded
  /// up to whole rows so a codon is never cut in half.
  static const int foldHeadBases = 300;
  static const int foldTailBases = 90;

  /// A quarter of the side. Enough that a cell reads as a tile rather than a
  /// table dell, not so much that a row of them reads as beads.
  static const double baseRadius = 5;

  /// The groove between one codon and the next.
  static const double codonSplit = 4;

  /// Extra points between two rows of a framed block.
  ///
  /// The horizontal groove alone made a codon a triplet in its own row and
  /// nothing in the column: three squares with air either side of them, stacked
  /// flush against the three above. This is what turns each one into a block of
  /// its own — and it is set at three rather than four so the vertical air
  /// stays a little under the horizontal, which keeps a row reading as a row.
  /// The reading frame runs along the sequence, not down the page.
  ///
  /// Unlike [codonSplit] it does not animate. It is charged in the rows the
  /// page reserves, so opening it would resize the box the screen scrolls.
  static const double codonRise = 3;

  /// The name band above a labelled block: the pill itself, and the air either
  /// side of it that keeps it off the grid above and the grid below.
  ///
  /// Twenty and six, where it was twenty-six and ten. This is the one page that
  /// scrolls, so a point spent on chrome is a point of sequence the reader has
  /// to travel to reach, and at the old figures three names cost 138 of them —
  /// better than six rows of bases, to say three things. Twenty still clears a
  /// 13pt name with enough left over to read as a pill rather than a box, and
  /// six is air enough to hold the chip off the row above now that the block
  /// gap no longer stacks on top of it — see [intrinsic].
  static const double labelPill = 20;
  static const double labelGap = 6;

  /// The row pitch the gene page aims for, and the one place a cell is allowed
  /// to stop being a square.
  ///
  /// A square cell packs 1,431 bases into a phone at about eleven points, and
  /// eleven points is too small for the one page that carries a *name* on every
  /// run rather than a letter on every cell: a name is capped at
  /// `rowHeight * 0.8`, and the six-base `RR` and `KR` sites are one-row runs.
  ///
  /// The gene can pay for the extra height out of its width because it is the
  /// one page where a single cell is never visible. Everywhere else a square is
  /// a base or a residue you are meant to be able to count, and its shape is
  /// the promise that they are all one thing; here the cells are drawn edge to
  /// edge and fuse into runs, so the only edges left are the boundaries between
  /// pieces — and a boundary does not care what shape the cells behind it were.
  /// Spending width the reader cannot see on height they can is the whole
  /// trade, and it is why [fit] stretches before it scrolls: a gene that fits
  /// stays one screen, because what the page is *for* is showing exons inside
  /// introns at a glance.
  ///
  /// It is a floor, not a target. Width runs out at about 9,400 bases, where
  /// the columns reach two points each, and below fourteen points the painter
  /// has no room for a single name: myoglobin's 10,566 bases lost every exon's.
  /// A longer gene keeps the fourteen-point row and scrolls instead.
  ///
  /// Fourteen rather than sixteen because the columns are what pay: taller rows
  /// mean more of them, and past about fourteen points a six-base cut site is
  /// too narrow to hold the word `RR site` at all.
  static const double geneRow = 14;

  static double _gapFor(double pitch, double ratio) =>
      pitch < solidBelow ? 0 : (pitch * ratio).clamp(_minGap, _maxGap);

  /// The drawn width of a cell, gap excluded.
  double get side => cell - gap;

  /// The drawn height of a cell. The same as [side] wherever cells are square,
  /// which is every stage but the gene.
  double get rowSide => rowHeight - rowGap;

  bool get isLettered => cell >= letteredAbove;

  /// The width of an unframed row — and the cap on how wide a name may be
  /// drawn.
  ///
  /// A name is a label on a region, not a measure of it, so a pill must never
  /// be read as an extent. Drawing them all this width was one answer to that,
  /// and the wrong one: it set "coding sequence" on a 377pt chip for 105pt of
  /// type, and three bars that width, stacked with the grid, read as three more
  /// regions. The answer that costs no room is the anchor. The painter hugs
  /// each name to its own type and pins it to the left of the grid, which is
  /// where this page's raster order puts the region's first base — and a marker
  /// on a starting position makes no claim about how far the region runs,
  /// whatever width it happens to be.
  double get bandWidth => columns * cell - gap;

  /// The width of the widest row: a framed one wherever there is one.
  double get gridWidth {
    double widest = bandWidth;
    for (final StageBlock block in blocks) {
      if (block.framed && block.count > 0) {
        widest = math.max(widest, bandWidth + grooves(columns, block.frame) * codonGap);
      }
    }
    return widest;
  }

  Size get size => Size(gridWidth, rows * rowHeight);

  /// How many codon grooves a full row of [columns] cells crosses when its
  /// first cell sits [frame] bases into a codon.
  static int grooves(int columns, int frame) => (columns - 1 + frame) ~/ 3;

  /// The height of one row of block [b], gap included.
  ///
  /// [rowHeight] for every block but a framed one, which buys [codonRow] of air
  /// under each of its rows. Charged in the rows [intrinsic] reserves, so every
  /// reader of [blockRow], [rows] and [size] goes on counting in plain rows and
  /// only this, [centreOf] and [hitTest] have to know the difference.
  ///
  /// Where [codonRowOpens], the air comes in on the groove's clock, eased as a
  /// whole rather than row by row, so the rows below spread evenly as it does.
  double rowPitchOf(int b) {
    if (!blocks[b].framed) {
      return rowHeight;
    }
    final double open = codonRowOpens ? AnatomyMotion.ease(codonOpen) : 1;
    return rowHeight + codonRow * open;
  }

  /// Rows of *cells* in every block at [columns], plus the gaps between them.
  ///
  /// [present] is the blocks that actually have cells; an empty one occupies no
  /// rows and earns no gap either side of it. A named block earns no gap
  /// either: it is separated by its own name band, which is charged in points
  /// rather than in rows — see [fit].
  static double _rowsAt(List<StageBlock> present, int columns) {
    double rows = 0;
    bool first = true;
    for (final StageBlock block in present) {
      if (block.label == null && !first) {
        rows += blockGapRows;
      }
      rows += (block.count / columns).ceil();
      first = false;
    }
    return rows;
  }

  /// The points a stage spends on name bands before a single cell is placed.
  static double _bandsFor(List<StageBlock> present) =>
      present.where((StageBlock b) => b.label != null).length *
      (labelPill + 2 * labelGap);

  /// Whether this stage is drawn in codons, and so gets [intrinsic].
  static bool _isFramed(AnatomyStage stage) =>
      stage.blocks.any((StageBlock b) => b.framed && b.count > 0);

  /// The layout one stage is drawn in. The one place that decides which stages
  /// get square cells, which one gets a fixed pitch, which one gets tiles large
  /// enough to tap, and which does not.
  ///
  /// [box] is what the painter has to draw into, which during a transition into
  /// or out of the transcript page is taller than the screen. [viewport] is what
  /// the reader can actually see without scrolling, and it is what a fitted
  /// stage is fitted to — fitting one to the box would push the gene halfway
  /// down a page the reader has to scroll to find it on.
  static AnatomyLayout forStage(AnatomyStage stage, Size box, Size viewport) =>
      stage.kind == StageKind.dna
      ? inspection(
          blocks: stage.blocks,
          width: box.width,
          gutter: AnatomyRuler.gutterFor(stage),
        )
      : _isFramed(stage)
      ? intrinsic(
          blocks: stage.blocks,
          width: box.width,
          gutter: AnatomyRuler.gutterFor(stage),
        )
      : fit(
          blocks: stage.blocks,
          canvas: viewport,
          minRow: stage.kind == StageKind.gene ? geneRow : 0,
          minCell: stage.kind == StageKind.gene ? 0 : residuePitch,
          // Every fitted stage but the gene draws a cell large enough to letter,
          // so every one of them is a tile. The gene is the exception for the
          // reason it is the exception everywhere else on this screen: its cells
          // are meant to fuse into runs rather than to be counted.
          tile: stage.kind != StageKind.gene,
          // Lettered rows read like text; only the unlettered gene snakes.
          serpentine: stage.kind == StageKind.gene,
          gutter: AnatomyRuler.gutterFor(stage),
        );

  /// How tall [stage] insists on being in [viewport], or 0 for a stage that will
  /// take whatever height it is given.
  ///
  /// The screen asks this to size the box it scrolls: a fitted stage fills the
  /// viewport, the transcript page is about twice it, and a gene too long for
  /// [geneRow] rows on one screen is as tall as those rows.
  static double heightFor(AnatomyStage stage, Size viewport) {
    if (_isFramed(stage) || stage.kind == StageKind.dna) {
      return forStage(stage, viewport, viewport).size.height;
    }
    // A fitted grid fills its viewport exactly, and exactly can come back a
    // hair over in floating point. A page that really outgrows it does so by
    // at least a row.
    final double height = forStage(stage, viewport, viewport).size.height;
    return height > viewport.height + 1e-6 ? height : 0;
  }

  /// The transcript page: fixed pitch, read like text, as tall as it needs.
  ///
  /// Columns are held to a multiple of three so a codon never straddles a row —
  /// which is also what lets the untranslated ends share the column count and
  /// still sit at a uniform pitch, since three is a factor of any of them.
  ///
  /// [gutter] is kept clear on the left for the ruler: the rows are chosen to
  /// fit beside it, and the grid stays centred wherever centring already leaves
  /// that much room.
  static AnatomyLayout intrinsic({
    required List<StageBlock> blocks,
    required double width,
    double gutter = 0,
  }) {
    const double cell = basePitch;
    const double gap = baseGap;

    double framedWidth(int codons) =>
        codons * 3 * cell - gap + (codons - 1) * codonSplit;

    int codons = 1;
    while (framedWidth(codons + 1) <= width - gutter) {
      codons++;
    }
    final int columns = codons * 3;

    const double labelRows = (labelPill + 2 * labelGap) / cell;

    final List<double> blockRow = List<double>.filled(blocks.length, 0);
    final List<int> foldFrom = List<int>.filled(blocks.length, 0);
    final List<int> foldTo = List<int>.filled(blocks.length, 0);
    double row = 0;
    bool first = true;
    for (int i = 0; i < blocks.length; i++) {
      if (blocks[i].count == 0) {
        blockRow[i] = row;
        continue;
      }
      final int height = (blocks[i].count / columns).ceil();
      final int head = (foldHeadBases / columns).ceil();
      final int tail = (foldTailBases / columns).ceil();
      if (blocks[i].count > foldAbove && height > head + tail + 1) {
        foldFrom[i] = head;
        foldTo[i] = height - tail;
      }
      // Whichever separator applies, and never both. A name band already
      // carries [labelGap] of air on each side of itself; charging the block
      // gap on top of that put a named region the better part of three rows of
      // bases below the one above it — air paid for twice, and wide enough to
      // read as a break in a molecule that has none. A block with no name has
      // nothing but the gap to hold it off its neighbour, so that is where the
      // gap is still spent.
      if (blocks[i].label != null) {
        row += labelRows;
      } else if (!first) {
        row += blockGapRows;
      }
      blockRow[i] = row;
      final int hidden = foldTo[i] - foldFrom[i];
      row +=
          (height - hidden) *
              (blocks[i].framed ? (cell + codonRise) / cell : 1) +
          (hidden > 0 ? labelRows : 0);
      first = false;
    }
    final double rows = row;
    final bool folds = foldTo.any((int t) => t > 0);

    final bool framed = blocks.any((StageBlock b) => b.framed && b.count > 0);
    final double widest = framed ? framedWidth(codons) : columns * cell - gap;

    return AnatomyLayout(
      blocks: blocks,
      columns: columns,
      cell: cell,
      gap: gap,
      rowHeight: cell,
      rowGap: gap,
      rows: rows,
      blockRow: blockRow,
      // Across, but never down: this page is taller than what it is given, and
      // centring it vertically would push its first row off the top.
      origin: Offset(math.max(gutter, (width - widest) / 2), 0),
      serpentine: false,
      codonGap: codonSplit,
      codonRow: codonRise,
      radius: baseRadius,
      labelRows: labelRows,
      foldFrom: folds ? foldFrom : const <int>[],
      foldTo: folds ? foldTo : const <int>[],
    );
  }

  /// A region of the gene opened into its DNA: read like text, as tall as it
  /// needs, and tapped base by base.
  ///
  /// The transcript's raster order without the rest of that page: the region
  /// is shown whole, so nothing folds. What it adds is size. As many tiles as
  /// fit between the gutters are stretched to fill the row, the way [fit]
  /// stretches a residue tile, so the grid meets the same margins on every
  /// phone.
  ///
  /// A coding region is read in threes, as the transcript's coding sequence
  /// is, and forms its codons once it has landed: the grooves open across and
  /// the rows part down, both reserved from the start. A region that is never
  /// translated has no frame, and every tile of it is at least
  /// [inspectionSide].
  static AnatomyLayout inspection({
    required List<StageBlock> blocks,
    required double width,
    double gutter = 0,
  }) {
    // The transcript tile's own proportions, so a base here is that tile
    // scaled up rather than a different object.
    const double least = inspectionSide * basePitch / baseSide;
    final double room = math.max(0, width - 2 * inspectionGutter - gutter);
    final bool framed = blocks.any((StageBlock b) => b.framed && b.count > 0);
    // Where the region's first base sits in its codon, for one that opens
    // part of the way into one.
    final int frame = blocks.fold(
      0,
      (int f, StageBlock b) => b.framed && b.count > 0 ? b.frame : f,
    );
    int columns = math.max(1, (room / least).floor());
    double cell = math.max(least, room / columns);
    if (framed) {
      // Whole codons across, so none straddles a row, with the grooves between
      // them paid for out of the tiles. How many codons is whichever count
      // brings a base nearest [inspectionSide] once they are: the grooves
      // should take a point from each tile, not a codon from each row.
      double pitchFor(int codons) =>
          (room - grooves(codons * 3, frame) * codonSplit) / (codons * 3);
      double missFor(int codons) =>
          (pitchFor(codons) * (1 - tileGapRatio) - inspectionSide).abs();
      int codons = math.max(1, columns ~/ 3);
      if (missFor(codons + 1) < missFor(codons)) {
        codons++;
      }
      columns = codons * 3;
      cell = math.max(basePitch, pitchFor(codons));
    }
    final double gap = cell * tileGapRatio;

    final List<double> blockRow = List<double>.filled(blocks.length, 0);
    double row = 0;
    bool first = true;
    for (int i = 0; i < blocks.length; i++) {
      if (blocks[i].count == 0) {
        blockRow[i] = row;
        continue;
      }
      if (!first) {
        row += blockGapRows;
      }
      blockRow[i] = row;
      row +=
          (blocks[i].count / columns).ceil() *
          (blocks[i].framed ? (cell + codonRise) / cell : 1);
      first = false;
    }
    final double widest =
        columns * cell - gap + (framed ? grooves(columns, frame) * codonSplit : 0);

    return AnatomyLayout(
      blocks: blocks,
      columns: columns,
      cell: cell,
      gap: gap,
      rowHeight: cell,
      rowGap: gap,
      rows: row,
      blockRow: blockRow,
      // Across, but never down, for the reason [intrinsic] gives. Centred on
      // the grooved row, as the transcript's is, in the room beside the ruler.
      origin: Offset(gutter + math.max(0, (width - gutter - widest) / 2), 0),
      serpentine: false,
      codonGap: framed ? codonSplit : 0,
      codonRow: framed ? codonRise : 0,
      codonRowOpens: framed,
      radius: (cell - gap) * tileRadiusRatio,
    );
  }

  /// Largest cell size that fits every block into [canvas].
  ///
  /// Sweeping the integer column count rather than solving in closed form: the
  /// row count is a sum of ceilings, so the fit is a staircase and its maximum
  /// does not sit where the continuous approximation puts it. The sweep is at
  /// most a couple of hundred steps and runs once per stage, never per frame.
  ///
  /// [minRow] asks for rows at least that tall, which is granted by trading
  /// width for height first, and by growing the grid past [canvas] only once
  /// the columns have run out — see [geneRow]. It is ignored where the square
  /// fit is already that tall. A grid that grows is pinned to the top of
  /// [canvas], and [heightFor] reports its height so the screen can scroll it.
  ///
  /// [minCell] is the smallest square a tile may shrink to. A stage with more
  /// cells than one screen holds at that size keeps it, and runs past the
  /// bottom of [canvas] the way [minRow] lets the gene: dystrophin's 3,685
  /// residues fit a phone only as unlettered eight-point squares, which are
  /// neither readable nor tappable.
  ///
  /// [tile] draws the cells as the lettered tile the transcript page fixes —
  /// see [tileRadiusRatio].
  ///
  /// [serpentine] is for the gene alone; a lettered page is laid out as a
  /// raster. [gutter] is kept clear on the left for the ruler, and the grid is
  /// fitted and centred in what remains.
  ///
  /// A named block's band is charged in **points, off the canvas, before the
  /// sweep** — [labelPill] plus [labelGap] either side of it — and only then
  /// converted back into [labelRows]. That is the whole trick, and it is what
  /// [intrinsic] does not have to do: there a cell is a fixed 21 points, so a
  /// band is a known number of rows, while here the row height is the thing
  /// being solved for and a band expressed in rows would be defined in terms of
  /// its own answer.
  static AnatomyLayout fit({
    required List<StageBlock> blocks,
    required Size canvas,
    double minRow = 0,
    double minCell = 0,
    bool tile = false,
    bool serpentine = true,
    double gutter = 0,
  }) {
    final List<StageBlock> present = blocks
        .where((StageBlock b) => b.count > 0)
        .toList();
    if (present.isEmpty || canvas.isEmpty) {
      return AnatomyLayout(
        blocks: blocks,
        columns: 1,
        cell: 0,
        gap: 0,
        rowHeight: 0,
        rowGap: 0,
        rows: 0,
        blockRow: List<double>.filled(blocks.length, 0),
        origin: Offset.zero,
      );
    }

    final double bands = _bandsFor(present);
    final double room = math.max(1, canvas.height - bands);
    // What the cells may span across: the canvas, less the ruler's gutter on
    // the left.
    final double across = math.max(1, canvas.width - gutter);

    final int widest = present.map((StageBlock b) => b.count).reduce(math.max);
    final int limit = math.min(widest, math.max(1, across ~/ _minCell));

    int bestColumns = 1;
    double bestCell = 0;

    for (int columns = 1; columns <= limit; columns++) {
      final double rows = _rowsAt(present, columns);

      final double size = math.min(
        across / (columns + 2 * bulgeCells),
        room / rows,
      );
      if (size > bestCell) {
        bestCell = size;
        bestColumns = columns;
      }
    }

    // Squares too small to letter are bought back out of the height: as many
    // columns as the floor allows across, each stretched to fill the width as
    // a fitted cell does, and as many rows as that takes.
    if (bestCell < minCell) {
      bestColumns = (across / minCell - 2 * bulgeCells).floor().clamp(
        1,
        widest,
      );
      bestCell = across / (bestColumns + 2 * bulgeCells);
    }

    // Rows too short for what this page has to write on them are bought back
    // out of the width: more columns is fewer rows, and the height freed up is
    // handed to the rows that remain. Every cell narrows by exactly as much as
    // it grows, so the grid still fills the same box.
    double bestRowHeight = bestCell;
    if (minRow > bestCell) {
      final int wanted = math.max(1, room ~/ minRow);
      int columns = bestColumns;
      while (columns < limit && _rowsAt(present, columns) > wanted) {
        columns++;
      }
      final double rows = _rowsAt(present, columns);
      // Where even the last column leaves more rows than the box holds at
      // [minRow], the rows keep [minRow] and the grid runs past the bottom of
      // [canvas]. A row too short to write on costs every name on the page; a
      // page taller than the screen costs a scroll.
      final double stretched = math.max(room / rows, minRow);
      final double narrowed = across / (columns + 2 * bulgeCells);
      // Never the other way up. A cell wider than it is high is a row that has
      // been squashed, which is the opposite of what was asked for.
      if (stretched > narrowed) {
        bestColumns = columns;
        bestCell = narrowed;
        bestRowHeight = stretched;
      }
    }

    final double gap = _gapFor(bestCell, tile ? tileGapRatio : _gapRatio);
    // Zero for a stage whose blocks are not named, which is what the painter
    // reads to know there is no band pass to run at all.
    final double labelRows = bands > 0 && bestRowHeight > 0
        ? (labelPill + 2 * labelGap) / bestRowHeight
        : 0;

    // Whichever separator applies, and never both — the rule [intrinsic]
    // follows for the same reason: a band already carries [labelGap] of air on
    // each side of itself, and charging the block gap on top of that reads as a
    // break in a molecule that has none.
    final List<double> blockRow = List<double>.filled(blocks.length, 0);
    double row = 0;
    bool first = true;
    for (int i = 0; i < blocks.length; i++) {
      if (blocks[i].count == 0) {
        blockRow[i] = row;
        continue;
      }
      if (blocks[i].label != null) {
        row += labelRows;
      } else if (!first) {
        row += blockGapRows;
      }
      blockRow[i] = row;
      row += (blocks[i].count / bestColumns).ceil();
      first = false;
    }

    final Size grid = Size(bestColumns * bestCell, row * bestRowHeight);
    return AnatomyLayout(
      blocks: blocks,
      columns: bestColumns,
      cell: bestCell,
      gap: gap,
      rowHeight: bestRowHeight,
      rowGap: _gapFor(bestRowHeight, tile ? tileGapRatio : _gapRatio),
      rows: row,
      blockRow: blockRow,
      // Centred down as well as across, unless the grid is taller than the box:
      // then it is pinned to the top, as [intrinsic] is, so its first row is
      // where the scroll starts rather than above it.
      origin: Offset(
        gutter + (across - grid.width) / 2,
        math.max(0, (canvas.height - grid.height) / 2),
      ),
      radius: tile ? (bestCell - gap) * tileRadiusRatio : 0,
      labelRows: labelRows,
      serpentine: serpentine,
    );
  }

  /// This layout drawn [offset] points higher, where a scrolled page was on
  /// screen when the scroll was reset under it.
  ///
  /// A transition starts with the scroll at zero, so a long gene the reader had
  /// scrolled down would otherwise begin its departure from its own top.
  AnatomyLayout raisedBy(double offset) {
    if (offset == 0) {
      return this;
    }
    return AnatomyLayout(
      blocks: blocks,
      columns: columns,
      cell: cell,
      gap: gap,
      rowHeight: rowHeight,
      rowGap: rowGap,
      rows: rows,
      blockRow: blockRow,
      origin: origin.translate(0, -offset),
      serpentine: serpentine,
      codonGap: codonGap,
      codonRow: codonRow,
      codonOpen: codonOpen,
      codonRowOpens: codonRowOpens,
      radius: radius,
      labelRows: labelRows,
      foldFrom: foldFrom,
      foldTo: foldTo,
    );
  }

  /// This layout with its reading frame [t] of the way open.
  ///
  /// [origin] is carried over rather than re-solved, and that is the point: it
  /// was centred on the fully grooved row, so the untranslated ends — which are
  /// pinned to the same left margin and never groove at all — do not shift
  /// under the reader while the coding sequence spreads out to the right of
  /// them.
  AnatomyLayout opened(double t) {
    if (t == codonOpen) {
      return this;
    }
    return AnatomyLayout(
      blocks: blocks,
      columns: columns,
      cell: cell,
      gap: gap,
      rowHeight: rowHeight,
      rowGap: rowGap,
      rows: rows,
      blockRow: blockRow,
      origin: origin,
      serpentine: serpentine,
      codonGap: codonGap,
      codonRow: codonRow,
      codonOpen: t,
      codonRowOpens: codonRowOpens,
      radius: radius,
      labelRows: labelRows,
      foldFrom: foldFrom,
      foldTo: foldTo,
    );
  }

  int blockOf(int index) {
    for (int b = blocks.length - 1; b >= 0; b--) {
      if (blocks[b].count > 0 && index >= blocks[b].start) {
        return b;
      }
    }
    return 0;
  }

  /// How far into the row the codon grooves have pushed column [column] of
  /// row [row] of block [block].
  ///
  /// The row is what makes the grooving a sweep rather than a switch. Every
  /// row of the coding sequence opens on the same curve, each a little after
  /// the one above it, so the frame arrives the way the ribosome reads — down
  /// the block, 5' to 3' — instead of the whole page clicking apart at once.
  double _lead(int block, int column, int row) {
    if (!blocks[block].framed) {
      return 0;
    }
    final double full = ((column + blocks[block].frame) ~/ 3) * codonGap;
    return codonOpen >= 1 ? full : full * _openInRow(block, row);
  }

  double _openInRow(int block, int row) {
    final int height = (blocks[block].count / columns).ceil();
    final double u = height > 1 ? row / (height - 1) : 0;
    return AnatomyMotion.ease(
      AnatomyMotion.staggered(codonOpen, u, lead: AnatomyMotion.codonStagger),
    );
  }

  /// How far the grooves have opened at the row cell [index] sits in.
  ///
  /// The painter reads this for the two fills at the ends of the frame, so the
  /// start codon colours in as the sweep sets off and the stop codon as it
  /// arrives — one event, not a movement with a colour change stapled to it.
  double openAt(int index) {
    final int block = blockOf(index);
    if (!blocks[block].framed || codonOpen >= 1) {
      return 1;
    }
    return _openInRow(block, (index - blocks[block].start) ~/ columns);
  }

  /// The serpentine flip, and the only place it happens.
  ///
  /// A partial final row needs no special case. An odd row is laid right to
  /// left, so it starts under the right-hand end of the even row above it and
  /// simply stops short on the left; an even row starts under the left-hand end
  /// of the odd row above. Both stay adjacent to the base before them.
  ///
  /// A raster layout skips the flip, and a partial final row simply stops short
  /// on the right, the way a last line of type does.
  Offset centreOf(int index) {
    final int block = blockOf(index);
    final int within = index - blocks[block].start;
    final int row = within ~/ columns;
    if (_hiddenRow(block, row)) {
      return foldBandOf(block)!.center;
    }
    int column = within % columns;
    if (serpentine && row.isOdd) {
      column = columns - 1 - column;
    }
    return Offset(
      origin.dx + (column + 0.5) * cell + _lead(block, column, row),
      // The block's top is in plain rows; the row inside it is in that block's
      // own pitch, which is taller wherever the reading frame is spaced out.
      origin.dy +
          blockRow[block] * rowHeight +
          (_shownRow(block, row) + 0.5) * rowPitchOf(block) +
          (_pastFold(block, row) ? _foldHeight : 0),
    );
  }

  bool _folds(int b) => foldTo.isNotEmpty && foldTo[b] > foldFrom[b];

  bool _hiddenRow(int b, int row) =>
      _folds(b) && row >= foldFrom[b] && row < foldTo[b];

  bool _pastFold(int b, int row) => _folds(b) && row >= foldTo[b];

  /// Which row down the block [row] is drawn in, once the fold has taken the
  /// rows before it out.
  int _shownRow(int b, int row) =>
      _pastFold(b, row) ? row - (foldTo[b] - foldFrom[b]) : row;

  /// The fold's own band, the height of a name band: a pill with air above
  /// and below it.
  double get _foldHeight => labelPill + 2 * labelGap;

  /// Whether the cell at [index] is folded out of view. It still has a centre
  /// — the fold's — so anything moving it in or out has somewhere to go.
  bool isHidden(int index) {
    if (foldTo.isEmpty) {
      return false;
    }
    final int block = blockOf(index);
    return _hiddenRow(block, (index - blocks[block].start) ~/ columns);
  }

  /// How many of block [b]'s cells the fold hides.
  int hiddenCount(int b) => _folds(b) ? (foldTo[b] - foldFrom[b]) * columns : 0;

  /// The slot the fold's pill sits in for block [b], or null where the block
  /// is drawn whole. Laid out like [labelBandOf]: the grid's width, a pill's
  /// height, [labelGap] of air above.
  Rect? foldBandOf(int b) {
    if (!_folds(b)) {
      return null;
    }
    final double top =
        origin.dy + blockRow[b] * rowHeight + foldFrom[b] * rowPitchOf(b);
    return Rect.fromLTWH(origin.dx, top + labelGap, gridWidth, labelPill);
  }

  Rect rectOf(int index) =>
      Rect.fromCenter(center: centreOf(index), width: side, height: rowSide);

  /// The slot reserved for the name of block [b], or null for a block that has
  /// no name or no cells.
  ///
  /// The slot, not the pill drawn in it: how wide a chip comes out depends on
  /// how wide its name sets, and type is the painter's business — this class
  /// holds no font metrics and is the better for it. What the grid promises is
  /// the height, the left edge and the room, read straight back out of the rows
  /// [intrinsic] reserved rather than measured again downstream. A band drawn
  /// anywhere but where the grid made room would overlap the sequence.
  Rect? labelBandOf(int b) {
    if (labelRows <= 0 || blocks[b].count == 0 || blocks[b].label == null) {
      return null;
    }
    final double top = origin.dy + (blockRow[b] - labelRows) * rowHeight;
    return Rect.fromLTWH(origin.dx, top + labelGap, bandWidth, labelPill);
  }

  /// The column whose cell contains [x], or -1 outside every column.
  ///
  /// Walked rather than divided for a framed row: the grooves make the pitch
  /// non-uniform, and this runs once per tap.
  int _columnAt(double x, int block, int row) {
    final double local = x - origin.dx;
    if (!blocks[block].framed) {
      final double column = local / cell;
      return column < 0 || column >= columns ? -1 : column.floor();
    }
    for (int c = 0; c < columns; c++) {
      final double start = c * cell + _lead(block, c, row);
      if (local >= start && local < start + cell) {
        return c;
      }
    }
    return -1;
  }

  /// The cell under a point, or -1 outside every block.
  int hitTest(Offset point) {
    if (cell <= 0) {
      return -1;
    }
    final double y = point.dy - origin.dy;

    for (int b = 0; b < blocks.length; b++) {
      final StageBlock block = blocks[b];
      if (block.count == 0) {
        continue;
      }
      final int height = (block.count / columns).ceil();
      // The inverse of [centreOf]: down to the block in plain rows, then into
      // it in the block's own pitch, stepping over the fold where there is one.
      double inBlock = y - blockRow[b] * rowHeight;
      if (_folds(b)) {
        final double foldTop = foldFrom[b] * rowPitchOf(b);
        if (inBlock >= foldTop && inBlock < foldTop + _foldHeight) {
          return -1;
        }
        if (inBlock >= foldTop + _foldHeight) {
          inBlock += (foldTo[b] - foldFrom[b]) * rowPitchOf(b) - _foldHeight;
        }
      }
      final double local = inBlock / rowPitchOf(b);
      if (local < 0 || local >= height) {
        continue;
      }

      final int r = local.floor();
      int c = _columnAt(point.dx, b, r);
      if (c < 0) {
        return -1;
      }
      if (serpentine && r.isOdd) {
        c = columns - 1 - c;
      }
      final int index = block.start + r * columns + c;
      if (index < block.start + block.count) {
        return index;
      }
      return -1;
    }
    return -1;
  }

  /// The turn at each row end, drawn so the path is never ambiguous.
  ///
  /// Empty for a raster layout, which has no turn to draw: the eye returns to
  /// the left margin the way it does at the end of a line of type, and a curve
  /// swept back across the page would be describing a motion the sequence does
  /// not make.
  Path connectors() {
    final Path path = Path();
    if (cell <= 0 || !serpentine) {
      return path;
    }
    final double bulge = cell * bulgeCells;

    for (int b = 0; b < blocks.length; b++) {
      final StageBlock block = blocks[b];
      if (block.count == 0) {
        continue;
      }
      final int height = (block.count / columns).ceil();
      for (int row = 0; row < height - 1; row++) {
        final int last = block.start + (row + 1) * columns - 1;
        if (last >= block.start + block.count) {
          continue;
        }
        final Offset from = centreOf(last);
        final Offset to = centreOf(last + 1);
        // Even rows end on the right, odd rows on the left, so the turn always
        // bows away from the grid rather than back across it.
        final double direction = row.isEven ? 1 : -1;
        path
          ..moveTo(from.dx + direction * side / 2, from.dy)
          ..quadraticBezierTo(
            from.dx + direction * bulge,
            (from.dy + to.dy) / 2,
            to.dx + direction * side / 2,
            to.dy,
          );
      }
    }
    return path;
  }

  @override
  bool operator ==(Object other) =>
      other is AnatomyLayout &&
      other.columns == columns &&
      other.cell == cell &&
      other.gap == gap &&
      other.rowHeight == rowHeight &&
      other.rowGap == rowGap &&
      other.rows == rows &&
      other.origin == origin &&
      other.serpentine == serpentine &&
      other.codonGap == codonGap &&
      other.codonRow == codonRow &&
      other.codonOpen == codonOpen &&
      other.codonRowOpens == codonRowOpens &&
      other.radius == radius &&
      other.labelRows == labelRows &&
      listEquals(other.blockRow, blockRow) &&
      listEquals(other.foldFrom, foldFrom) &&
      listEquals(other.foldTo, foldTo) &&
      other.blocks.length == blocks.length;

  @override
  int get hashCode => Object.hash(
    columns,
    cell,
    gap,
    rowHeight,
    rowGap,
    rows,
    origin,
    serpentine,
    codonGap,
    codonRow,
    codonOpen,
    codonRowOpens,
    radius,
    labelRows,
    Object.hashAll(foldTo),
    blocks.length,
  );
}
