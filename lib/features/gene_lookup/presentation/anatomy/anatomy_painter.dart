import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../../../../core/theme/anatomy_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/nucleotide_colors.dart';
import '../../domain/entities/protein_constraint.dart';
import '../clinvar/clinvar_colors.dart';
import '../constraint/constraint_colors.dart';
import '../format.dart';
import 'anatomy_layout.dart';
import 'anatomy_ruler.dart';
import 'anatomy_run_labels.dart';
import 'anatomy_scene.dart';
import 'anatomy_stages.dart';
import 'anatomy_tracer.dart';
import 'anatomy_translation.dart';

/// Draws one stage, or one transition between two, as a single grid of squares.
///
/// 1,431 squares cannot be 1,431 widgets, and at 60fps they cannot be 1,431
/// draw calls either. Every square is a point in one `drawRawPoints` batch per
/// colour, which puts a whole stage on screen in a handful of calls.
///
/// The trick that makes the batching survive a transition is taken from
/// [DnaHelixPainter]: nothing fades by alpha. A cell leaving is mixed *toward*
/// the background instead, quantised to [_shadeSteps], so cells at different
/// stages of leaving still share a colour and still batch. Over an opaque ground
/// the composite is identical, and opaque draws never accumulate at their edges.
class AnatomyPainter extends CustomPainter {
  AnatomyPainter({
    required Listenable repaint,
    required this.scene,
    required this.progress,
    required this.groove,
    required this.reverse,
    required this.tracer,
    required this.status,
    required this.inertTracer,
    required this.background,
    required this.nucleotides,
    required this.anatomy,
    this.constraint,
    this.conservation = false,
    this.maskedIndex,
    this.masking,
    this.maskAccent,
    this.onConstraintTapped,
    this.rulerInk,
    this.junctions = const <int>[],
    this.bridges = const <int, int>{},
    this.marks = const <int, ClinVarMark>{},
  }) : super(repaint: repaint);

  final AnatomyScene scene;

  final Animation<double> progress;

  /// How far the reading frame has grooved itself open, 0 to 1.
  ///
  /// A second clock, and the only one on this screen that is not a page
  /// turn: it runs *after* a transition has settled, on the page that is
  /// drawn in threes. Everything it drives — where the codons sit, the two
  /// fills at the ends of the frame, and the white those six letters turn —
  /// moves together, because they are one event.
  final Animation<double> groove;

  /// True while the user is running the sequence backwards. The animation is
  /// the same one either way — only the direction it is read differs — but the
  /// stagger has to ripple 5'->3' in both, so it is flipped here.
  final bool reverse;

  final Tracer? tracer;
  final TracerStatus? status;

  /// Where to pin a ring for a base that was already gone before this scene.
  final Offset? inertTracer;

  final Color background;
  final NucleotideColors nucleotides;
  final AnatomyColors anatomy;
  final ProteinConstraint? constraint;
  final bool conservation;
  final int? maskedIndex;
  final Animation<double>? masking;
  final Color? maskAccent;
  final ValueChanged<int>? onConstraintTapped;

  /// The ink row numbers are set in, or null for a canvas with no ruler.
  final Color? rulerInk;

  /// Cells of a region's DNA that open a new piece: an intron was cut out of
  /// the gene just before each, and a bar in the mortar says so.
  final List<int> junctions;

  /// Cysteines in a disulfide on this page, as cell to bridge number: the two
  /// ends of a bridge carry the same number.
  final Map<int, int> bridges;

  /// Residues ClinVar has records at, as cell to the mark drawn there. Drawn
  /// only over the constraint fills: in ESM mode the page is a map of
  /// evidence, and the observed records belong on it; the chemistry page stays
  /// a page about chemistry.
  final Map<int, ClinVarMark> marks;

  bool get _constraintAtRest =>
      constraint != null &&
      !scene.isTransition &&
      scene.from.kind == StageKind.protein &&
      scene.from.letters == constraint!.sequence;

  /// Whether the masking scrim should be drawn.
  ///
  /// Wider than [_constraintAtRest], which also gates the conservation fills
  /// and the per-residue semantics and so has to know it is on the protein
  /// page. The mask is about a selection, not about a track: the screen only
  /// ever sets [maskedIndex] on a page whose taps mean one cell, and the mRNA
  /// page is now one of those.
  bool get _maskAtRest => !scene.isTransition && maskedIndex != null;

  /// Enough to make the mix toward the background read as continuous; the
  /// framebuffer holds 8 bits a channel, so more steps would not survive.
  static const int _shadeSteps = 24;

  /// How finely the colour blend during translation is resampled. Rebuilding
  /// the table at every step of this would be wasteful and invisible.
  static const int _blendSteps = 20;

  static const int _glyphAlphaSteps = 8;

  /// Overlap between abutting nucleotide cells, in logical pixels. Enough to
  /// bury the antialiased seam, small enough that a run boundary stays put.
  static const double _seam = 0.7;

  /// Below this a corner is not worth a path batch: half a pixel of rounding is
  /// invisible, and the gene's 1,431 cells are drawn square by design.
  static const double _minRadius = 0.5;

  /// How much of itself an untranslated base keeps: its tile, and its letter.
  ///
  /// It is still an A, and still lettered green — saying so is what makes the
  /// coding sequence read as the part that is *read* rather than as the only
  /// part that is there. The tile goes furthest, to within a hair of the
  /// ground, so the two ends read as sequence laid on the page rather than set
  /// in squares, and the eye takes the three regions in before it takes in any
  /// single base.
  ///
  /// The letter keeps more, because it is all that is left to read — and a
  /// reader does read it: the Kozak context around the start codon, an
  /// upstream ATG, the polyadenylation signal. At these it holds 3:1 against
  /// the coding sequence's 4.7, so the reading frame still leads; at the 1.7:1
  /// it used to be stepped back to, those were not legible at all.
  ///
  /// Over an opaque ground both are mixes, not alphas — see [CellSlot].
  static const double _utrTile = 0.2;
  static const double _utrInk = 0.67;

  /// How far a region's name band is lifted off the ground toward that
  /// region's own colour. The stronger is for the block a residue page is
  /// about; the transcript's three chips all take the quieter one.
  static const double _bandFillRead = 0.34;
  static const double _bandFillQuiet = 0.16;

  /// What is left of a name on a quiet chip.
  static const double _bandInkQuiet = 0.7;

  /// The type a region's name is set in.
  ///
  /// Thirteen, against the twelve a single base carries, and the one point
  /// between them is the whole of the hierarchy: a name that ranks a region
  /// level with one of its own bases has stopped being a heading. So this is
  /// the one measurement on the band that does not get spent when the page is
  /// tightened.
  static const double _bandType = 13;

  /// The air either side of a name inside its pill — a little under the pill's
  /// own height, which is what keeps a fully rounded end off the first letter.
  static const double _bandPad = 14;

  /// How much of the mortar a cut site's halo fills, and the least of it that
  /// may show however thin the mortar comes out.
  ///
  /// The ring straddles the square's own edge, so half of it is buried under a
  /// fill of its own colour and only the outer half is ever seen — it is drawn
  /// at twice this and shows at exactly this. Both numbers are what a residue's
  /// tile proportions cost: the mortar on a residue page used to be a tenth of
  /// the pitch and is now a twenty-first of it (see
  /// [AnatomyLayout.tileGapRatio]), and the seven tenths that read as a halo
  /// against the old gap read as nothing at all against this one.
  ///
  /// Eight tenths rather than the whole gap, so a marked square can never reach
  /// an unmarked neighbour. It does reach a marked one — two halos of eight
  /// tenths meeting in a gap of one overlap — and that is the right way round:
  /// a dibasic site is two residues spelling one instruction, so `RR` fusing
  /// into a single shape with two letters in it says what it is. The gap it may
  /// not close is the one to the residue next door, which is not part of the
  /// site and must not look as though it were.
  static const double _cutHalo = 0.8;
  static const double _minCutHalo = 1.0;

  static const double _highlightWidth = 2;

  /// The smallest a highlight may be, as a side rather than a radius. A traced
  /// cell has to stay findable at the gene stage, where a square is eight
  /// pixels across.
  static const double _minHighlight = 15;

  /// Butt, not square: a cell is drawn as a line one cell tall, and a square
  /// cap would add half a stroke width to each end of it. See [_drawBatches].
  final Paint _cellPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.butt;

  /// The rounded cells. A batch is one colour and one width, so a whole batch
  /// is one filled path — see [_drawBatches].
  final Paint _fillPaint = Paint()..style = PaintingStyle.fill;

  final Paint _linePaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;

  final Paint _highlightPaint = Paint()..style = PaintingStyle.stroke;

  late final int _count = scene.from.count;

  /// Two points per cell — the top and bottom of a one-cell line. See
  /// [_drawBatches].
  late final Float32List _points = Float32List(_count * 4);
  late final Float32List _x = Float32List(_count);
  late final Float32List _y = Float32List(_count);

  /// Half the height each cell is drawn at, shrink already applied.
  late final Float32List _halfRow = Float32List(_count);
  late final Uint8List _level = Uint8List(_count);
  late final Uint8List _onCanvas = Uint8List(_count);

  /// 1 for a cell that is folded out of view at either end of this scene —
  /// see [AnatomyLayout.foldAbove]. Its tile fades into or out of the fold on
  /// its own shade; its letter is not drawn at all, because a few thousand of
  /// them converging on one pill would print a blot.
  late final Uint8List _folded = Uint8List(_count);
  late final Int32List _bucket = Int32List(_count);
  late final Int32List _order = Int32List(_count);

  static const int _pairSlots = CellSlot.count * CellSlot.count;

  /// Every pair is held twice, as in and out of the selected run.
  ///
  /// This is a second *colour*, not a second shade, and the distinction is
  /// load-bearing: [_level] already drives the departure fade, and a batch's
  /// shade also fixes its width, so borrowing it to mark a cell would shrink
  /// that cell and tear the seamless runs back into a grid of squares.
  static const int _selectSlots = _pairSlots * 2;

  late final List<Color> _pairColour = List<Color>.filled(
    _selectSlots * _shadeSteps,
    background,
  );

  late final Int32List _cellBucketStart = Int32List(
    _selectSlots * _shadeSteps + 1,
  );

  /// Selecting a run drains the colour out of every other one and steps them
  /// back toward the ground. Nothing at all is done to the run itself.
  ///
  /// That is the point, and it is why these two numbers are as large as they
  /// are. A selected run keeps its exact colour — same hue, same lightness,
  /// same saturation, no overlay and no lift — so what a reader sees under
  /// their finger is the thing they were already looking at, and the *page* is
  /// what changed. There is no highlight to reconcile it with either:
  /// [_drawTracer] returns early for a run, because a box around one of intron
  /// 2's 787 cells would be a lie about what was picked.
  ///
  /// Both halves of the mute are needed. Draining alone leaves the greys at
  /// their original lightness, so a bright run muted still outshines a dark one
  /// selected; stepping back alone can only bring the others *down to* an
  /// intron that sits at 1.3:1 by design, never below it. Together at these
  /// values the brightest thing on the page muted — the A chain, at a luminance
  /// of 0.48 — lands under 0.02, below [AnatomyColors.roleIntron] at 0.025,
  /// which is the dimmest thing that can be selected. So a selection wins on
  /// the ladder rather than on a highlight, whatever was picked.
  ///
  /// It wins by a hair when what was picked is an intron, and that is honest:
  /// an intron is drawn to recede and cannot be made to blaze without becoming
  /// a different colour. What reads there is the *field* — two thirds of the
  /// page holding while the other third drops away — and its name, which is
  /// left at full ink while every other name falls to a whisper.
  static const double _muteDrain = 0.85;
  static const double _muteToward = 0.88;

  /// What is left of a name outside the selection. Enough to keep the map
  /// legible — at a fifth it fell to about 2:1 and the map stopped being one —
  /// not enough to compete with the name of the run that was picked.
  static const double _mutedInk = 0.4;

  /// The grey of the same lightness, so draining a colour changes what it is
  /// without changing how bright it looks.
  Color _drained(Color colour) {
    final int v = (255 * math.pow(colour.computeLuminance(), 1 / 2.2))
        .round()
        .clamp(0, 255);
    return Color.lerp(colour, Color.fromARGB(255, v, v, v), _muteDrain)!;
  }

  Color _stepBack(Color colour) =>
      Color.lerp(_drained(colour), background, _muteToward)!;

  /// 1 for a cell inside the selected feature. Meaningless, and everywhere 0,
  /// when nothing is selected.
  late final Uint8List _selected = Uint8List(_count);

  /// The feature the tracer is sitting in, in [scene]'s `from` stage, or -1
  /// when nothing is selected or the selection is a single base rather than a
  /// run.
  late final int _selectedFeature = _resolveSelectedFeature();

  /// 1 for a run belonging to the selected feature, so the per-cell loop stays
  /// one array read rather than a walk through [StageRun] objects.
  ///
  /// A feature is often more than one run — the 5' UTR is two, split by intron
  /// 1 — and every piece of it lights, because the caption states the size of
  /// the whole feature.
  late final Uint8List _selectedRuns = _resolveSelectedRuns();

  int _resolveSelectedFeature() {
    final Tracer? pin = tracer;
    if (pin == null || !pin.asRun || scene.from.kind != StageKind.gene) {
      return -1;
    }
    final int cell = scene.from.cellAt(pin.genomicPosition);
    return cell < 0 ? -1 : scene.from.featureAt(cell);
  }

  Uint8List _resolveSelectedRuns() {
    final List<StageRun> runs = scene.from.runs;
    final Uint8List mask = Uint8List(runs.length);
    if (_selectedFeature < 0) {
      return mask;
    }
    for (int i = 0; i < runs.length; i++) {
      mask[i] = runs[i].feature == _selectedFeature ? 1 : 0;
    }
    return mask;
  }

  final Map<int, ui.Paragraph> _glyphs = <int, ui.Paragraph>{};
  final Map<(String, int, int, bool), ui.Paragraph> _translationGlyphs =
      <(String, int, int, bool), ui.Paragraph>{};
  double _glyphSize = -1;
  double _glyphOpen = -1;

  /// Keyed by the whole string, unlike [_glyphs], which can key on one code
  /// unit because a cell only ever holds one letter.
  final Map<String, ui.Paragraph> _labels = <String, ui.Paragraph>{};
  double _labelCell = -1;

  // Built once per painter: a layout's connectors do not move while its cells
  // do, and rebuilding a Path of eighty curves every frame is pure waste.
  late final Path _fromConnectors = scene.fromLayout.connectors();
  late final Path _toConnectors = scene.toLayout.connectors();

  int _blendStep = -1;
  int _grooveStep = -1;

  /// [groove] as this frame sees it, quantised the way the blend is.
  /// Read by [_slotColour] and [_inkColour], which are called from inside
  /// the caches and have no argument to take it on.
  double _open = 1;

  /// [_open] as each end of the frame experiences it.
  ///
  /// The two ends are rows apart — the start codon is the first row of the
  /// coding sequence and the stop codon the last — so the sweep down the block
  /// reaches them at different times, and their fills and their letters have to
  /// arrive with it rather than with each other.
  double _openStart = 1;
  double _openStop = 1;
  double _selectionStrength = 1;
  int _selectionBlendStep = -1;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || _count == 0) {
      return;
    }

    final double raw = progress.value.clamp(0.0, 1.0);
    final double t = scene.isTransition ? raw : 1;
    _selectionStrength = scene.isSelection && reverse
        ? (t / 0.2).clamp(0.0, 1.0)
        : 1;
    if (scene.translation case final AnatomyTranslation motion) {
      _drawTranslation(canvas, size, motion, t);
      return;
    }
    final double appearance = scene.isSelection ? AnatomyScene.revealAt(t) : t;
    final double eased = scene.isSelection
        ? AnatomyScene.selectionTravelAt(t)
        : AnatomyMotion.ease(t);

    final double side = _lerp(
      scene.fromLayout.side,
      scene.toLayout.side,
      eased,
    );
    final double pitch = _lerp(
      scene.fromLayout.cell,
      scene.toLayout.cell,
      eased,
    );

    // The gene is drawn edge to edge, so a run of one thing fuses into a single
    // shape and the only edges left are the boundaries between pieces. Every
    // other stage keeps its mortar, because there a square is a base or a
    // residue you are meant to be able to count.
    //
    // Edge to edge means a hair *past* it: two antialiased squares that share
    // an edge each cover it halfway and leave a seam, which at 1,431 cells
    // reads as a grid drawn over the very runs this is meant to fuse. The
    // overlap is under a pixel and always loses to the neighbour drawn after
    // it, so no boundary moves.
    final double fill = _lerp(
      _fillWidth(scene.from, scene.fromLayout),
      _fillWidth(scene.to, scene.toLayout),
      eased,
    );
    final double rowFill = _lerp(
      _fillHeight(scene.from, scene.fromLayout),
      _fillHeight(scene.to, scene.toLayout),
      eased,
    );

    // A cell is a square with a corner on every page that draws one large
    // enough to see it, and a hard rectangle on the gene, where the cells are
    // drawn edge to edge and meant to fuse into runs. Interpolated, so the
    // corner grows in as the bases arrive rather than appearing at the end.
    final double radius = _lerp(
      scene.fromLayout.radius,
      scene.toLayout.radius,
      eased,
    );

    // The groove is the layout's own clock — it staggers and eases per row
    // inside [AnatomyLayout.openAt], so what is handed around here is raw.
    final double open = groove.value.clamp(0.0, 1.0);

    _syncBlend(appearance, open);
    _project(size, t, open, rowFill / 2);

    canvas.save();
    canvas.clipRect(Offset.zero & size);

    _drawStructure(canvas, t);
    _drawCells(canvas, fill, radius);
    if (_constraintAtRest && conservation) {
      _drawConservation(canvas, side, radius);
    }
    _drawCutSites(canvas, side, pitch, radius, t);
    _drawRunLabels(canvas, size, t);
    _drawBlockLabels(canvas, t);
    _drawRulers(canvas, size, t, open);
    _drawJunctions(canvas, t, open);
    _drawLetters(canvas, side, appearance);
    _drawBridges(canvas, size, side, t);
    if (_constraintAtRest && conservation && marks.isNotEmpty) {
      _drawMarks(canvas, size, side);
    }
    _drawTracer(canvas, size, side, t);

    if (_maskAtRest) {
      _drawMask(canvas, size, side, radius);
    }

    canvas.restore();
  }

  void _drawConservation(Canvas canvas, double side, double radius) {
    for (final ResidueConstraint residue in constraint!.positions) {
      _fillPaint.color = ConstraintColors.heat(residue.conservation);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(_x[residue.index], _y[residue.index]),
            width: side,
            height: side,
          ),
          Radius.circular(radius),
        ),
        _fillPaint,
      );
    }
  }

  void _drawMask(Canvas canvas, Size size, double side, double radius) {
    final int index = maskedIndex!;
    if (index < 0 || index >= _count) {
      return;
    }
    final double amount = (masking?.value ?? 1).clamp(0.0, 1.0);
    // The context is the evidence: every neighbor retains 30% of its ink/fill.
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = background.withValues(alpha: 0.7 * amount),
    );
    final RRect hole = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(_x[index], _y[index]),
        width: side,
        height: side,
      ),
      Radius.circular(radius),
    );
    final double empty = (amount * 2).clamp(0.0, 1.0);
    canvas.drawRRect(
      hole,
      Paint()..color = background.withValues(alpha: empty),
    );
    final Path outline = Path()..addRRect(hole.deflate(1));
    final Paint dash = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..color = (maskAccent ?? anatomy.tracer).withValues(alpha: empty);
    for (final ui.PathMetric metric in outline.computeMetrics()) {
      for (double start = 0; start < metric.length; start += 7) {
        canvas.drawPath(
          metric.extractPath(start, math.min(start + 4, metric.length)),
          dash,
        );
      }
    }
  }

  // ------------------------------------------------------------- projection

  /// Translation owns its tile and glyph timing. Three independent paths and
  /// a page-wide crossfade would superimpose four letters on the same square.
  /// Here a whole codon folds on one clock; its residue appears only once the
  /// bases have closed. Reflow begins after every codon has finished swapping.
  void _drawTranslation(
    Canvas canvas,
    Size size,
    AnatomyTranslation motion,
    double t,
  ) {
    final double open = groove.value.clamp(0.0, 1.0);
    final double previousOpen = _open;
    _syncBlend(0, open);
    if (_open != previousOpen) {
      _translationGlyphs.clear();
    }
    final double removal = AnatomyTranslation.removal(t);
    final double baseSide = scene.fromLayout.side;
    final double side = motion.sideAt(t);
    final double radius = _lerp(
      scene.fromLayout.radius,
      scene.toLayout.radius,
      AnatomyTranslation.expand(t),
    );

    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.save();
    canvas.translate(0, -motion.sourceScrollOffset);
    _drawBands(canvas, scene.from, scene.fromLayout, 1 - removal);
    _drawFolds(canvas, scene.fromLayout, 1 - removal);
    _drawRuler(
      canvas,
      size,
      scene.from,
      scene.fromLayout.opened(open),
      1 - removal,
      scroll: motion.sourceScrollOffset,
    );
    _drawLayoutStructure(
      canvas,
      scene.fromLayout,
      _fromConnectors,
      1 - removal,
    );
    canvas.restore();
    final double labels = AnatomyMotion.ease(
      AnatomyTranslation.phase(t, 0.94, 1),
    );
    _drawBands(canvas, scene.to, scene.toLayout, labels);
    _drawRuler(canvas, size, scene.to, scene.toLayout, labels);

    // Retain projected base positions for the tracer, including hidden members
    // of a codon. They all arrive at the same residue without losing identity.
    for (int cell = 0; cell < _count; cell++) {
      final Offset point = motion.positionOf(cell, t, open: open);
      _x[cell] = point.dx;
      _y[cell] = point.dy;
      final int residue = scene.target[cell];
      final double swap = residue < 0 ? 0 : motion.swap(residue, t);
      final double opacity = residue < 0
          ? 1 - removal
          : AnatomyTranslation.baseOpacity(swap);
      _level[cell] = ((residue < 0 ? opacity : 1) * (_shadeSteps - 1)).round();
      _onCanvas[cell] = point.dy > -side && point.dy < size.height + side
          ? 1
          : 0;
      // A folded base has no square of its own to fold into a residue: its
      // residue comes out of the fold instead, below.
      if (opacity <= 0 ||
          _onCanvas[cell] == 0 ||
          scene.fromLayout.isHidden(cell)) {
        continue;
      }
      final int slot = scene.slotPair[cell] ~/ CellSlot.count;
      final double fold = AnatomyTranslation.fold(swap);
      final double scale = residue < 0 ? 1 - 0.18 * removal : 1;
      final double height = residue < 0 ? scale : 1 - 0.88 * fold;
      final Color source = _slotColour(slot);
      final Color colour = residue < 0
          ? source
          : Color.lerp(
              source,
              _slotColour(scene.slotPair[cell] % CellSlot.count),
              fold,
            )!;
      _fillPaint.color = colour.withValues(alpha: opacity);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: point,
            width: baseSide * scale,
            height: baseSide * height,
          ),
          Radius.circular(scene.fromLayout.radius),
        ),
        _fillPaint,
      );
      _translationLetter(
        canvas,
        scene.from.letters[cell],
        _inkFor(scene.from, slot),
        point,
        baseSide * scale,
        residue < 0 ? opacity : AnatomyTranslation.baseInk(swap),
        residue: false,
        height: height,
      );
    }

    for (int residue = 0; residue < motion.bases.length; residue++) {
      final double swap = motion.swap(residue, t);
      final double reveal = AnatomyTranslation.reveal(swap);
      if (swap < 0.56) {
        continue;
      }
      final int cell = motion.bases[residue].first;
      // A residue whose codon is folded away emerges from the fold as the
      // protein settles, rather than being printed a thousand times over on
      // one pill while the drawn codons fold.
      final double emerge = scene.fromLayout.isHidden(cell)
          ? AnatomyTranslation.reflow(t)
          : 1;
      if (emerge <= 0.01) {
        continue;
      }
      final Offset point = motion.centreOf(residue, t, open: open);
      if (point.dy < -side || point.dy > size.height + side) {
        continue;
      }
      final int slot = scene.slotPair[cell] % CellSlot.count;
      // A shallow fold opens into a single tile. The tile keeps the source's
      // size until reflow, so it cannot cover neighbouring codons in its row.
      final double height = 0.12 + 0.88 * reveal;
      _fillPaint.color = _slotColour(slot).withValues(alpha: emerge);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: point, width: side, height: side * height),
          Radius.circular(radius),
        ),
        _fillPaint,
      );
      _translationLetter(
        canvas,
        scene.to.letters[residue],
        _inkGround,
        point,
        side,
        reveal * AnatomyTranslation.residueInk(t) * emerge,
        residue: true,
        height: height,
      );
    }
    // The halo gets only the tile's actual mortar. Using the destination pitch
    // while a tile is still growing would inflate cut sites into large discs.
    final double pitch =
        side +
        _lerp(
          scene.fromLayout.gap,
          scene.toLayout.gap,
          AnatomyTranslation.expand(t),
        );
    _drawCutSites(canvas, side, pitch, radius, AnatomyTranslation.expand(t));
    _drawTracer(canvas, size, side, t);
    canvas.restore();
  }

  /// Cache type at the two endpoint sizes and transform it with the tile.
  /// This avoids laying out text at every intermediate size of every codon.
  void _translationLetter(
    Canvas canvas,
    String glyph,
    int ink,
    Offset point,
    double side,
    double strength, {
    required bool residue,
    required double height,
  }) {
    final int alpha = (strength * 31).round();
    if (alpha <= 0 ||
        side < AnatomyLayout.letteredAbove ||
        !(residue
            ? _lettered(scene.to, scene.toLayout)
            : _lettered(scene.from, scene.fromLayout))) {
      return;
    }
    final double native = residue ? scene.toLayout.side : scene.fromLayout.side;
    final ui.Paragraph paragraph = _translationGlyphs.putIfAbsent(
      (glyph, ink, alpha, residue),
      () =>
          _buildGlyph(glyph, ink, alpha / 31, native, (native / 2).round() * 2),
    );
    canvas.save();
    canvas.translate(point.dx, point.dy);
    canvas.scale(side / native, side / native * height);
    canvas.drawParagraph(paragraph, Offset(-native / 2, -paragraph.height / 2));
    canvas.restore();
  }

  /// Positions and shade for every cell, in one pass over typed arrays.
  ///
  /// This is [AnatomyScenePositions.positionOf] written out over `Float32List`
  /// rather than `Offset`: same constants, same result, no allocation.
  void _project(Size size, double t, double open, double halfRow) {
    final Int32List target = scene.target;
    final Uint16List runOf = scene.from.runOfCell;
    // Grooved here rather than in the scene, which is built once per swipe and
    // knows nothing of a clock that runs after it has settled. A layout with no
    // framed block returns itself, so every stage but the transcript pays
    // nothing for this.
    final AnatomyLayout from = scene.fromLayout.opened(open);
    final AnatomyLayout to = scene.toLayout.opened(open);

    final double centreX = size.width / 2;
    final double centreY = size.height / 2;
    final double reach = from.cell * AnatomyMotion.driftCells;
    final double margin = math.max(from.cell, to.cell) * 2;
    const int lastLevel = _shadeSteps - 1;
    final double span = _count > 1 ? (_count - 1).toDouble() : 1;

    for (int cell = 0; cell < _count; cell++) {
      // The ripple always runs 5'->3'; playing the scene backwards flips which
      // end of the sequence is already moving, not which end leads.
      final double u = reverse ? 1 - cell / span : cell / span;
      final double local = AnatomyMotion.ease(AnatomyMotion.staggered(t, u));

      final Offset origin = from.centreOf(cell);
      final int landing = target[cell];

      double x;
      double y;
      int level = lastLevel;

      if (scene.isSelection) {
        final Offset point = scene.positionOf(cell, t);
        x = point.dx;
        y = point.dy;
        if (landing < 0) {
          level = ((1 - (t / 0.35).clamp(0.0, 1.0)) * lastLevel).round();
        }
      } else if (landing < 0) {
        double awayX = origin.dx - centreX;
        double awayY = (origin.dy - centreY) * AnatomyMotion.driftFlatten;
        final double distance = math.sqrt(awayX * awayX + awayY * awayY);
        if (distance < 1e-6) {
          awayX = 0;
          awayY = -1;
        } else {
          awayX /= distance;
          awayY /= distance;
        }
        x = origin.dx + awayX * reach * local;
        y = origin.dy + awayY * reach * local;
        // Shade and size come off one number for a departing cell, which is
        // what lets it shrink without breaking the colour batching: a batch is
        // one shade, so a batch is also one width.
        level = ((1 - local) * lastLevel).round();
      } else {
        final Offset destination = to.centreOf(landing);
        final double dx = destination.dx - origin.dx;
        final double dy = destination.dy - origin.dy;
        final double controlX =
            (origin.dx + destination.dx) / 2 - dy * AnatomyMotion.bow;
        final double controlY =
            (origin.dy + destination.dy) / 2 + dx * AnatomyMotion.bow;
        final double inverse = 1 - local;
        final double a = inverse * inverse;
        final double b = 2 * inverse * local;
        final double c = local * local;
        x = origin.dx * a + controlX * b + destination.dx * c;
        y = origin.dy * a + controlY * b + destination.dy * c;
      }

      // A base the transcript folds away travels into the fold and fades as it
      // arrives, the way a departing cell fades as it drifts; one folded at
      // both ends of the scene is not drawn at all.
      final bool fromHidden = from.isHidden(cell);
      final bool toHidden = landing >= 0 && to.isHidden(landing);
      if (fromHidden && toHidden) {
        level = 0;
      } else if (toHidden) {
        // Squared, so they are mostly gone before they bunch up: thousands of
        // squares arriving at one pill at full shade read as a smear.
        level = ((1 - local) * (1 - local) * lastLevel).round();
      } else if (fromHidden) {
        level = (local * local * lastLevel).round();
      }
      _folded[cell] = fromHidden || toHidden ? 1 : 0;

      _x[cell] = x;
      _y[cell] = y;
      _level[cell] = level;
      // A cell's height shrinks with the same number its width does, so a
      // departing rectangle stays the shape it was. The width rides on the
      // batch's stroke; the height has to be written per cell, because it is
      // carried by the two points rather than by the paint.
      _halfRow[cell] = level == lastLevel
          ? halfRow
          : halfRow * (1 - AnatomyMotion.driftShrink * (1 - level / lastLevel));
      _selected[cell] = _selectedRuns[runOf[cell]];

      // Departing cells travel outside the frame, so culling has to be by
      // position rather than by index.
      final bool onCanvas =
          level > 0 &&
          x > -margin &&
          y > -margin &&
          x < size.width + margin &&
          y < size.height + margin;
      _onCanvas[cell] = onCanvas ? 1 : 0;
    }
  }

  /// Counting sort into `buckets`, exactly as `DnaHelixPainter` orders by
  /// depth: count, prefix-sum, place. Placing advances each bucket's own
  /// cursor in `starts`, so afterwards `starts[b]` holds the *end* of bucket b
  /// and no scratch array had to be allocated to get there.
  void _sort(Int32List starts, int buckets, int Function(int cell) bucketOf) {
    starts.fillRange(0, buckets + 1, 0);

    for (int cell = 0; cell < _count; cell++) {
      if (_onCanvas[cell] == 0) {
        continue;
      }
      final int bucket = bucketOf(cell);
      _bucket[cell] = bucket;
      starts[bucket + 1]++;
    }
    for (int b = 1; b <= buckets; b++) {
      starts[b] += starts[b - 1];
    }

    for (int cell = 0; cell < _count; cell++) {
      if (_onCanvas[cell] == 0) {
        continue;
      }
      final int slot = starts[_bucket[cell]]++;
      _order[slot] = cell;
      final double x = _x[cell];
      final double half = _halfRow[cell];
      _points[slot * 4] = x;
      _points[slot * 4 + 1] = _y[cell] - half;
      _points[slot * 4 + 2] = x;
      _points[slot * 4 + 3] = _y[cell] + half;
    }
  }

  /// One `drawRawPoints` per non-empty bucket. A bucket is one colour *and* one
  /// shade, and a departing cell's shade is a function of how far it has gone,
  /// so the bucket also fixes its width — a whole stage still costs a handful of
  /// calls even while a thousand cells are shrinking at a thousand rates.
  ///
  /// Lines rather than points, because on the gene page a cell is not a square:
  /// it is about half as wide as it is tall, so that the rows can be tall
  /// enough to write a name across (see [AnatomyLayout.geneRow]). A point can
  /// only ever be square — its stroke width is both of its sides — but a butt
  /// capped line of stroke width *w* between two points *h* apart is exactly a
  /// *w* by *h* rectangle, and it batches the same way. Where cells are square
  /// the two are identical, so this is one path and not two.
  void _drawBatches(
    Canvas canvas,
    Int32List ends,
    int buckets,
    List<Color> table,
    Paint paint,
    double width,
    double radius,
  ) {
    if (width <= 0) {
      return;
    }
    const int lastLevel = _shadeSteps - 1;
    final bool rounded = radius >= _minRadius;
    int start = 0;
    for (int bucket = 0; bucket < buckets; bucket++) {
      final int end = ends[bucket];
      if (end > start) {
        final int level = bucket % _shadeSteps;
        final double drawn = level == lastLevel
            ? width
            : width * (1 - AnatomyMotion.driftShrink * (1 - level / lastLevel));
        if (rounded) {
          _fillPaint.color = table[bucket];
          canvas.drawPath(_roundedBatch(start, end, drawn, radius), _fillPaint);
        } else {
          paint
            ..color = table[bucket]
            ..strokeWidth = drawn;
          canvas.drawRawPoints(
            ui.PointMode.lines,
            Float32List.sublistView(_points, start * 4, end * 4),
            paint,
          );
        }
        start = end;
      }
    }
  }

  /// One bucket's cells as a single path of rounded rectangles.
  ///
  /// `drawRawPoints` cannot round a corner, so a page that wants one trades the
  /// point batch for a path batch — still one draw call per colour, which is
  /// what the whole design rests on. The two points per cell that [_sort] laid
  /// down already carry the cell's top and bottom; the batch's own width
  /// carries its sides.
  ///
  /// The radius is clamped to half the smaller side, so a departing cell — which
  /// shrinks toward nothing — turns into a lozenge and then a dot rather than
  /// inverting its own corners.
  Path _roundedBatch(int start, int end, double width, double radius) {
    final Path path = Path();
    final double half = width / 2;
    for (int slot = start; slot < end; slot++) {
      final double x = _points[slot * 4];
      final double top = _points[slot * 4 + 1];
      final double bottom = _points[slot * 4 + 3];
      final double corner = math.min(
        radius,
        math.min(half, (bottom - top) / 2),
      );
      path.addRRect(
        RRect.fromLTRBR(
          x - half,
          top,
          x + half,
          bottom,
          Radius.circular(corner),
        ),
      );
    }
    return path;
  }

  // ------------------------------------------------------------------ passes

  static double _fillWidth(AnatomyStage stage, AnatomyLayout layout) =>
      stage.kind == StageKind.gene ? layout.cell + _seam : layout.side;

  static double _fillHeight(AnatomyStage stage, AnatomyLayout layout) =>
      stage.kind == StageKind.gene ? layout.rowHeight + _seam : layout.rowSide;

  void _drawCells(Canvas canvas, double fill, double radius) {
    final Uint16List pairs = scene.slotPair;
    const int buckets = _selectSlots * _shadeSteps;
    _sort(
      _cellBucketStart,
      buckets,
      (int cell) =>
          (pairs[cell] * 2 + _selected[cell]) * _shadeSteps + _level[cell],
    );
    _drawBatches(
      canvas,
      _cellBucketStart,
      buckets,
      _pairColour,
      _cellPaint,
      fill,
      radius,
    );
  }

  /// Every piece of the gene, named where it lies.
  ///
  /// A colour without a name is decoration, and thirteen of them is a puzzle.
  /// The name is written across the widest part of the run itself, shrunk and
  /// abbreviated as far as [runLabelFloor] and [StageRun.writtenForms] allow;
  /// where not even that reaches, the run goes unnamed rather than be named
  /// over one of its neighbours. Where each name goes is decided by
  /// [RunLabelPlan], off the canvas, so a test can hold every run of every gene
  /// to being named on itself.
  void _drawRunLabels(Canvas canvas, Size size, double t) {
    final AnatomyStage stage = scene.from;
    final AnatomyLayout layout = scene.fromLayout;
    if (stage.kind != StageKind.gene || layout.columns <= 0) {
      return;
    }
    // The gene is only ever the stage being left, so the labels go with it.
    final double strength = scene.isSelection
        ? 1 - (t / 0.2).clamp(0.0, 1.0)
        : (scene.isTransition ? 1 - t : 1);
    final int alpha = (strength * (_glyphAlphaSteps - 1)).round();
    if (alpha <= 0) {
      return;
    }
    _syncLabels(layout.cell);

    final RunLabelPlan plan = RunLabelPlan.of(stage, layout);
    final double mutedInk = _lerp(1, _mutedInk, _selectionStrength);
    for (final RunLabel label in plan.labels) {
      final StageRun run = stage.runs[label.run];
      // A label belongs to its run and goes wherever the run goes: it steps
      // back with the ones outside the selection, and it takes its ink from the
      // colour actually on screen rather than the one in the palette, or a
      // muted run would end up captioned in its own background.
      final bool within = _selectedFeature < 0 || _selectedRuns[label.run] == 1;
      final Color shown = within
          ? anatomy.forRun(run)
          : Color.lerp(
              anatomy.forRun(run),
              _stepBack(anatomy.forRun(run)),
              _selectionStrength,
            )!;
      final int ink = within ? alpha : (alpha * mutedInk).round();
      if (ink <= 0) {
        continue;
      }
      final ui.Paragraph? paragraph = _label(
        label.text,
        label.size,
        _readsDarker(shown),
        ink,
      );
      if (paragraph == null) {
        continue;
      }
      canvas.drawParagraph(
        paragraph,
        Offset(
          label.rect.center.dx - paragraph.maxIntrinsicWidth / 2,
          label.rect.center.dy - paragraph.height / 2,
        ),
      );
    }
  }

  /// Every named block, named where it lies.
  ///
  /// A colour without a name is decoration, and this page's whole argument —
  /// these two ends fall away, this middle is read in threes — cannot be made
  /// without saying which is which. The bands sit in rows the layout reserved
  /// for them (see [AnatomyLayout.labelBandOf]), so a name can never land on a
  /// base.
  ///
  /// Cross-faded on the same schedule as the row connectors: a band belongs to
  /// a layout rather than to a cell, so during the reflow it gets out of the
  /// way and lets the motion carry the continuity.
  void _drawBlockLabels(Canvas canvas, double t) {
    if (!scene.isTransition) {
      _drawBands(canvas, scene.to, scene.toLayout, 1);
      _drawFolds(canvas, scene.toLayout, 1);
      return;
    }
    final double leaving = (1 - 2 * t).clamp(0.0, 1.0);
    final double arriving = (2 * t - 1).clamp(0.0, 1.0);
    _drawBands(canvas, scene.from, scene.fromLayout, leaving);
    _drawBands(canvas, scene.to, scene.toLayout, arriving);
    _drawFolds(canvas, scene.fromLayout, leaving);
    _drawFolds(canvas, scene.toLayout, arriving);
  }

  /// Row numbers in the gutter, cross-faded with the bands: a number belongs to
  /// a row of a layout rather than to a cell, so it steps aside during a
  /// reflow the way a name does.
  void _drawRulers(Canvas canvas, Size size, double t, double open) {
    if (!scene.isTransition) {
      _drawRuler(canvas, size, scene.to, scene.toLayout.opened(open), 1);
      return;
    }
    _drawRuler(
      canvas,
      size,
      scene.from,
      scene.fromLayout.opened(open),
      (1 - 2 * t).clamp(0.0, 1.0),
    );
    _drawRuler(
      canvas,
      size,
      scene.to,
      scene.toLayout.opened(open),
      (2 * t - 1).clamp(0.0, 1.0),
    );
  }

  /// One stage's numbers, right-aligned against the first square of each row.
  ///
  /// [scroll] is how far the canvas has already been translated up, for a
  /// translation's source; it is read only to find the rows in view, so a page
  /// thirteen screens long costs the rows on screen.
  void _drawRuler(
    Canvas canvas,
    Size size,
    AnatomyStage stage,
    AnatomyLayout layout,
    double strength, {
    double scroll = 0,
  }) {
    final Color? ink = rulerInk;
    if (ink == null ||
        strength <= 0.01 ||
        layout.cell <= 0 ||
        !AnatomyRuler.rules(stage)) {
      return;
    }
    final int alpha = (strength * (_glyphAlphaSteps - 1)).round();
    if (alpha <= 0) {
      return;
    }
    for (int b = 0; b < stage.blocks.length; b++) {
      final StageBlock block = stage.blocks[b];
      if (block.count == 0) {
        continue;
      }
      final int rows = (block.count / layout.columns).ceil();
      for (int r = 0; r < rows; r++) {
        final int cell = block.start + r * layout.columns;
        if (layout.isHidden(cell)) {
          continue;
        }
        final Offset centre = layout.centreOf(cell);
        final double shown = centre.dy - scroll;
        if (shown < -layout.rowHeight ||
            shown > size.height + layout.rowHeight) {
          continue;
        }
        final String? label = AnatomyRuler.labelAt(stage, cell);
        if (label == null) {
          continue;
        }
        final ui.Paragraph paragraph = _rulerLabel(label, ink, alpha);
        canvas.drawParagraph(
          paragraph,
          Offset(
            layout.origin.dx +
                (layout.cell - layout.side) / 2 -
                AnatomyRuler.pad -
                paragraph.maxIntrinsicWidth,
            centre.dy - paragraph.height / 2,
          ),
        );
      }
    }
  }

  /// A numbered badge on the corner of each bonded cysteine, at rest.
  ///
  /// The fold page says "two disulfide bridges join A to B"; this is where a
  /// reader can see which cysteines, before the fold turns them into rods.
  void _drawBridges(Canvas canvas, Size size, double side, double t) {
    if (bridges.isEmpty || scene.isTransition || side < AnatomyLayout.letteredAbove) {
      return;
    }
    final AnatomyLayout layout = scene.toLayout;
    // Large enough for an eleven-point numeral, the app's smallest type — the
    // disc was sized to the tile and on a long protein its number came to
    // seven points — and larger again on a large tile.
    final double radius = math.max(11 / 1.25, side * 0.17);
    final Paint fill = Paint()..color = anatomy.aminoCysteine;
    final Paint ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = background;
    for (final MapEntry<int, int> bridge in bridges.entries) {
      final int cell = bridge.key;
      if (cell < 0 || cell >= _count || layout.isHidden(cell)) {
        continue;
      }
      final Rect tile = layout.rectOf(cell);
      // On the corner, so the disc grows out over the gap between tiles
      // rather than in over the letter: on the smallest tiles an inset disc
      // this size covered half a C.
      final Offset centre = Offset(
        tile.right - radius * 0.1,
        tile.top + radius * 0.1,
      );
      if (centre.dy < -radius || centre.dy > size.height + radius) {
        continue;
      }
      canvas.drawCircle(centre, radius + 0.75, ring);
      canvas.drawCircle(centre, radius, fill);
      final ui.Paragraph number = _bridgeLabels.putIfAbsent(
        (bridge.value, radius.round()),
        () =>
            (ui.ParagraphBuilder(
                    ui.ParagraphStyle(
                      fontFamily: AppTypography.monoFamily,
                      fontSize: radius * 1.25,
                      textAlign: TextAlign.center,
                    ),
                  )
                  ..pushStyle(
                    ui.TextStyle(
                      color: background,
                      fontWeight: FontWeight.w500,
                    ),
                  )
                  ..addText('${bridge.value}'))
                .build()
              ..layout(ui.ParagraphConstraints(width: radius * 3)),
      );
      canvas.drawParagraph(
        number,
        Offset(centre.dx - radius * 1.5, centre.dy - number.height / 2),
      );
    }
  }

  final Map<(int, int), ui.Paragraph> _bridgeLabels =
      <(int, int), ui.Paragraph>{};

  /// One dot per residue with ClinVar records, in its most severe group's
  /// colour, at the foot of the tile under its letter. The corners belong to
  /// the bridge badges, and a corner dot met the badge of the cell below it.
  /// The masked residue is left alone: it is the sheet's subject, and the mask
  /// would halve the dot.
  void _drawMarks(Canvas canvas, Size size, double side) {
    final AnatomyLayout layout = scene.toLayout;
    final double radius = math.max(2.5, side * 0.075);
    for (final MapEntry<int, ClinVarMark> mark in marks.entries) {
      final int cell = mark.key;
      if (cell < 0 ||
          cell >= _count ||
          cell == maskedIndex ||
          layout.isHidden(cell)) {
        continue;
      }
      final Rect tile = layout.rectOf(cell);
      final Offset centre = Offset(
        tile.center.dx,
        tile.bottom - radius - 1.5,
      );
      if (centre.dy < -radius || centre.dy > size.height + radius) {
        continue;
      }
      ClinVarColors.paintMark(
        canvas,
        centre,
        radius,
        mark.value.group,
        halo: background,
      );
    }
  }

  /// The joins in a region's DNA, at rest.
  void _drawJunctions(Canvas canvas, double t, double open) {
    if (junctions.isEmpty || scene.isTransition || maskAccent == null) {
      return;
    }
    final AnatomyLayout layout = scene.toLayout.opened(open);
    _linePaint
      ..color = maskAccent!
      ..strokeWidth = 2;
    for (final int cell in junctions) {
      if (cell <= 0 || cell >= scene.to.count) {
        continue;
      }
      final Rect tile = layout.rectOf(cell);
      final double x = tile.left - math.max(1.5, layout.gap / 2 + 1);
      canvas.drawLine(
        Offset(x, tile.top + 1),
        Offset(x, tile.bottom - 1),
        _linePaint,
      );
    }
  }

  final Map<(String, int), ui.Paragraph> _rulerLabels =
      <(String, int), ui.Paragraph>{};

  ui.Paragraph _rulerLabel(String text, Color ink, int alpha) =>
      _rulerLabels.putIfAbsent((text, alpha), () {
        final ui.ParagraphBuilder builder =
            ui.ParagraphBuilder(
                ui.ParagraphStyle(
                  fontFamily: AppTypography.monoFamily,
                  fontSize: AnatomyRuler.fontSize,
                ),
              )
              ..pushStyle(
                ui.TextStyle(
                  color: Color.lerp(
                    Colors.transparent,
                    ink,
                    alpha / (_glyphAlphaSteps - 1),
                  ),
                ),
              )
              ..addText(text);
        return builder.build()
          ..layout(const ui.ParagraphConstraints(width: double.infinity));
      });

  /// The pill standing in for the middle of a region too long to draw whole.
  ///
  /// Centred, where a name band is pinned left: a name marks where a region
  /// starts, and this marks a gap in the middle of one. Quiet, like the
  /// untranslated ends' chips, because it is the page saying how it is drawn
  /// rather than a part of the molecule. The count is the one number a reader
  /// needs to trust the rest: the chip above still reads the whole region.
  void _drawFolds(Canvas canvas, AnatomyLayout layout, double strength) {
    if (strength <= 0.01 || layout.foldTo.isEmpty) {
      return;
    }
    final int alpha = (strength * (_glyphAlphaSteps - 1)).round();
    if (alpha <= 0) {
      return;
    }
    final Color chip = Color.lerp(
      background,
      anatomy.roleUtr5,
      _bandFillQuiet,
    )!;
    final bool onLight = _readsDarker(chip);
    for (int b = 0; b < layout.blocks.length; b++) {
      final Rect? band = layout.foldBandOf(b);
      if (band == null) {
        continue;
      }
      final String text =
          '\u00B7 \u00B7 \u00B7   ${grouped(layout.hiddenCount(b))} nt not shown'
          '   \u00B7 \u00B7 \u00B7';
      final ui.Paragraph? measured = _label(
        text,
        _bandType,
        onLight,
        _glyphAlphaSteps - 1,
      );
      final double width = math.min(
        band.width,
        (measured?.maxIntrinsicWidth ?? 0) + 2 * _bandPad,
      );
      final Rect pill = Rect.fromCenter(
        center: band.center,
        width: width,
        height: band.height,
      );
      _fillPaint.color = Color.lerp(background, chip, strength)!;
      canvas.drawRRect(
        RRect.fromRectAndRadius(pill, Radius.circular(pill.height / 2)),
        _fillPaint,
      );
      final ui.Paragraph? paragraph = _label(
        text,
        _bandType,
        onLight,
        (alpha * _bandInkQuiet).round(),
      );
      if (paragraph == null) {
        continue;
      }
      canvas.drawParagraph(
        paragraph,
        Offset(
          pill.center.dx - paragraph.maxIntrinsicWidth / 2,
          pill.center.dy - paragraph.height / 2,
        ),
      );
    }
  }

  void _drawBands(
    Canvas canvas,
    AnatomyStage stage,
    AnatomyLayout layout,
    double strength,
  ) {
    if (strength <= 0.01 || layout.labelRows <= 0) {
      return;
    }
    final int alpha = (strength * (_glyphAlphaSteps - 1)).round();
    if (alpha <= 0) {
      return;
    }

    for (int b = 0; b < stage.blocks.length; b++) {
      final StageBlock block = stage.blocks[b];
      final Rect? band = layout.labelBandOf(b);
      final String? name = block.caption ?? block.label;
      if (band == null || name == null) {
        continue;
      }

      // The chip takes the region's own colour, stepped back until it is a
      // ground for type rather than a fourth region competing with the three.
      //
      // The transcript's three chips are one family: the coding sequence's is
      // set in the untranslated ends' tint rather than its own blue, so its
      // name reads as a heading beside theirs and the grooved bases under it
      // are what says this is the part that is read.
      final RoleKind? tint = block.role == RoleKind.coding
          ? RoleKind.utr5
          : block.role;
      final Color role =
          anatomy.forSlot(CellSlot.forRole(tint, block.roleIndex)) ??
          anatomy.pending;
      final Color chip = Color.lerp(
        background,
        role,
        block.prominent ? _bandFillRead : _bandFillQuiet,
      )!;

      final bool onLight = _readsDarker(chip);

      // The chip is cut to its name and pinned to the left of the slot, which
      // on this page is where the region's first base sits — see
      // [AnatomyLayout.bandWidth] for why a name is anchored rather than
      // centred, and why it is never allowed to span its region.
      //
      // Measured at full ink rather than at the ink it is about to be drawn in:
      // the name fades and the chip under it does not, so a width read off a
      // paragraph that had faded to nothing would snap the pill at each end of
      // every cross-fade.
      final ui.Paragraph? measured = _label(
        name,
        _bandType,
        onLight,
        _glyphAlphaSteps - 1,
      );
      final Rect pill = Rect.fromLTWH(
        band.left,
        band.top,
        math.min(band.width, (measured?.maxIntrinsicWidth ?? 0) + 2 * _bandPad),
        band.height,
      );

      _fillPaint.color = Color.lerp(background, chip, strength)!;
      canvas.drawRRect(
        RRect.fromRectAndRadius(pill, Radius.circular(pill.height / 2)),
        _fillPaint,
      );

      final int ink = block.prominent ? alpha : (alpha * _bandInkQuiet).round();
      if (ink <= 0) {
        continue;
      }
      final ui.Paragraph? paragraph = _label(name, _bandType, onLight, ink);
      if (paragraph == null) {
        continue;
      }
      canvas.drawParagraph(
        paragraph,
        Offset(
          pill.center.dx - paragraph.maxIntrinsicWidth / 2,
          pill.center.dy - paragraph.height / 2,
        ),
      );
    }
  }

  /// Whether this colour carries the ground better than the ground's opposite.
  ///
  /// Compared as contrast ratios, not as a midpoint in luminance: luminance is
  /// linear and contrast is not, so a mid-green sits *below* the halfway mark
  /// while still carrying dark type nearly twice as well as light. Taking the
  /// shortcut is what put white labels on the B chain.
  bool _readsDarker(Color colour) =>
      _contrast(colour, background) >= _contrast(colour, anatomy.tracer);

  static double _contrast(Color a, Color b) {
    final double x = a.computeLuminance();
    final double y = b.computeLuminance();
    return (math.max(x, y) + 0.05) / (math.min(x, y) + 0.05);
  }

  void _syncLabels(double cell) {
    final double quantised = (cell / 2).roundToDouble() * 2;
    if (quantised == _labelCell) {
      return;
    }
    _labelCell = quantised;
    _labels.clear();
  }

  ui.Paragraph? _label(String text, double size, bool onLight, int alpha) {
    if (text.isEmpty) {
      return null;
    }
    final String key = '$text|${size.toStringAsFixed(1)}|$onLight|$alpha';
    final ui.Paragraph? cached = _labels[key];
    if (cached != null) {
      return cached;
    }
    final Color ink = Color.lerp(
      Colors.transparent,
      onLight ? background : anatomy.tracer,
      alpha / (_glyphAlphaSteps - 1),
    )!;
    final ui.ParagraphBuilder builder = runLabelBuilder(size, ink)
      ..addText(text);
    final ui.Paragraph paragraph = builder.build()
      ..layout(const ui.ParagraphConstraints(width: double.infinity));
    _labels[key] = paragraph;
    return paragraph;
  }

  /// A shape on the cut sites, so the protease's instruction never rests on
  /// hue alone.
  ///
  /// The mark goes in the mortar rather than inside the square: an `RR` cell is
  /// already painted [AnatomyColors.dibasic], so an outline drawn on it would
  /// be invisible. Stroking a rect of exactly [side] straddles that edge
  /// instead, growing these four squares half a ring into their own gap. The
  /// ring is a fraction of that gap, so a marked square cannot reach its
  /// neighbour however the layout is sized.
  void _drawCutSites(
    Canvas canvas,
    double side,
    double pitch,
    double radius,
    double t,
  ) {
    // Only a residue stage has cut sites, so the gene's 1,431 cells are never
    // walked to find four of them — at most the transcript's 465, on the one
    // transition where they are becoming residues.
    if (scene.from.positionsPerCell != 3 && scene.to.positionsPerCell != 3) {
      return;
    }
    // Capped at the whole mortar, never merely floored: what shows is the outer
    // half of the stroke, so a halo wider than the gap would spill onto the
    // squares either side of the site.
    final double mortar = pitch - side;
    final double halo = math.min(
      math.max(mortar * _cutHalo, _minCutHalo),
      mortar,
    );
    final double ring = 2 * halo;
    if (ring <= 0) {
      return;
    }

    final Uint16List pairs = scene.slotPair;
    for (int cell = 0; cell < _count; cell++) {
      if (_onCanvas[cell] == 0) {
        continue;
      }
      final int pair = pairs[cell];
      // Cross-faded exactly as the letters are, and for the same reason: three
      // bases land on one residue, so `carriesLetter` picks the one that draws
      // it. A cut site that is itself being consumed has no landing, and fades
      // out with the square it belongs to.
      double strength = pair ~/ CellSlot.count == CellSlot.dibasic ? 1 - t : 0;
      if (pair % CellSlot.count == CellSlot.dibasic &&
          scene.carriesLetter[cell] == 1) {
        strength += t;
      }
      if (strength <= 0.02) {
        continue;
      }

      final RRect outline = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(_x[cell], _y[cell]),
          width: side,
          height: side,
        ),
        Radius.circular(math.min(radius, side / 2)),
      );
      if (_constraintAtRest && conservation) {
        // A dark separator keeps the bright cut-site mark distinct from
        // every heat-map fill, including the pale middle of the scale.
        _linePaint
          ..color = Colors.black.withValues(alpha: strength)
          ..strokeWidth = ring;
        canvas.drawRRect(outline, _linePaint);
        _linePaint
          ..color = Colors.white.withValues(alpha: strength)
          ..strokeWidth = ring * 0.5;
        canvas.drawRRect(outline, _linePaint);
      } else {
        _linePaint
          ..color = Color.lerp(background, anatomy.dibasic, strength)!
          ..strokeWidth = ring;
        canvas.drawRRect(outline, _linePaint);
      }
    }
  }

  /// Row connectors and the reading-frame ticks, cross-faded across a
  /// transition. They belong to a layout, not to a cell, so during the reflow
  /// they step aside and let the motion carry the continuity instead.
  void _drawStructure(Canvas canvas, double t) {
    final double leaving = (1 - 2 * t).clamp(0.0, 1.0);
    final double arriving = (2 * t - 1).clamp(0.0, 1.0);

    _drawLayoutStructure(canvas, scene.fromLayout, _fromConnectors, leaving);
    if (scene.isTransition) {
      _drawLayoutStructure(canvas, scene.toLayout, _toConnectors, arriving);
    }
  }

  /// The row-end turns. Nothing else: the reading frame used to be drawn here
  /// as a hairline between codons, and is now a gap in the grid itself, which
  /// is a thing the eye groups by rather than a thing it has to read.
  void _drawLayoutStructure(
    Canvas canvas,
    AnatomyLayout layout,
    Path connectors,
    double strength,
  ) {
    if (strength <= 0.01 || layout.cell < AnatomyLayout.solidBelow) {
      return;
    }
    _linePaint
      ..color = Color.lerp(background, anatomy.connector, strength)!
      ..strokeWidth = math.max(1, layout.cell * 0.06);
    canvas.drawPath(connectors, _linePaint);
  }

  /// Whether a stage carries letters at rest.
  ///
  /// Never the gene, however large a short one's cells come out: its bases are
  /// drawn edge to edge to fuse into exon and intron runs, and letters would cut
  /// them back into squares.
  static bool _lettered(AnatomyStage stage, AnatomyLayout layout) =>
      stage.kind != StageKind.gene && layout.isLettered;

  void _drawLetters(Canvas canvas, double side, double t) {
    if (side < AnatomyLayout.letteredAbove) {
      return;
    }
    // Each layer answers for its own stage, and a stage is lettered in motion
    // only if it is lettered at rest. Splicing's cells pass the lettered size
    // on their way up, but the gene never carries letters, so its bases do not
    // flash theirs as they go; the mRNA's still fade in on the way, instead of
    // arriving and then popping into focus. The page scrolls and only cells on
    // the canvas are lettered, so how long the stage is does not matter.
    final double leaving = !_lettered(scene.from, scene.fromLayout)
        ? 0
        : (scene.isTransition ? 1 - t : 1);
    final double arriving =
        !_lettered(scene.to, scene.toLayout) || !scene.isTransition ? 0 : t;
    if (leaving <= 0.02 && arriving <= 0.02) {
      return;
    }
    _syncGlyphs(side);

    final Uint16List pairs = scene.slotPair;
    for (int cell = 0; cell < _count; cell++) {
      if (_onCanvas[cell] == 0 || _folded[cell] == 1) {
        continue;
      }
      if (leaving > 0.02) {
        // A departing cell's letter goes with its own square, not with the
        // page's. A residue's glyph is a hole cut in the ground colour, so once
        // the square it was cut from has faded most of the way to the ground
        // the letter is all that is left — a dark mark on a dark field, and
        // twenty-four of them at the cleavage. `_level` is the tile's own fade
        // and is `lastLevel` for every cell that is going somewhere, so this
        // changes nothing for the cells that stay.
        const int lastLevel = _shadeSteps - 1;
        _drawGlyph(
          canvas,
          scene.from.letters[cell],
          _inkFor(scene.from, pairs[cell] ~/ CellSlot.count),
          cell,
          side,
          leaving * _level[cell] / lastLevel,
        );
      }
      final int landing = scene.target[cell];
      if (arriving > 0.02 && landing >= 0 && scene.carriesLetter[cell] == 1) {
        _drawGlyph(
          canvas,
          scene.to.letters[landing],
          _inkFor(scene.to, pairs[cell] % CellSlot.count),
          cell,
          side,
          arriving,
        );
      }
    }
  }

  /// Which of the three inks a letter is drawn in.
  ///
  /// A residue keeps the ground-colour knockout the amino palette was built
  /// for: every one of those colours clears 4.5:1 against the ground precisely
  /// so that a hole cut in it reads as a letter.
  ///
  /// A base is the other way round. Its tile is one neutral shared by all four
  /// (`AnatomyColors.baseTile`), so the letter is the only thing left to say
  /// which base it is, and it is drawn in that base's own colour — every one of
  /// which clears 4.5:1 on the tile. See [NucleotideColors.muted].
  static int _inkFor(AnatomyStage stage, int slot) {
    if (stage.positionsPerCell != 1) {
      return _inkGround;
    }
    if (slot == CellSlot.frameStart) {
      return _inkFrameStart;
    }
    if (slot == CellSlot.frameStop) {
      return _inkFrameStop;
    }
    return slot >= CellSlot.adenineDim ? _inkBaseWashed : _inkBase;
  }

  static const int _inkGround = 0;
  static const int _inkBase = 1;
  static const int _inkBaseWashed = 2;

  /// The letters on the frame's two ends. White, and the only white type on
  /// the grid.
  ///
  /// A base's letter carries its identity everywhere else on this page, which
  /// is why it is drawn in that base's own colour. In the start and stop codons
  /// it gives that up: what those six squares are *for* outranks which bases
  /// they happen to be, and the fill is now saying it. The letters travel from
  /// their own colour to white on the same groove that fills the tile, so they
  /// hand over rather than switch.
  ///
  /// Two inks and not one, because the two ends are rows apart and the sweep
  /// reaches them at different times. Sharing an ink drew the stop codon's
  /// letters most of the way to white while its tile was still the neutral
  /// every other base sits on — three pale letters on a dark square, lit for
  /// no reason the page had given yet.
  static const int _inkFrameStart = 3;
  static const int _inkFrameStop = 4;
  static const int _inkCount = 5;

  static const Color _frameInk = Color(0xFFFFFFFF);

  /// A base's ink is resolved from its letter rather than tabulated: the glyph
  /// cache already keys on the letter, so four more inks would only say again
  /// what the letter does.
  Color _inkColour(int ink, String glyph) => switch (ink) {
    _inkBase => nucleotides.forBase(glyph),
    _inkBaseWashed => Color.lerp(
      background,
      nucleotides.forBase(glyph),
      _utrInk,
    )!,
    // Each end on its own number, the one its tile is using: a letter and the
    // square under it are one thing arriving, not two.
    _inkFrameStart => Color.lerp(
      nucleotides.forBase(glyph),
      _frameInk,
      _openStart,
    )!,
    _inkFrameStop => Color.lerp(
      nucleotides.forBase(glyph),
      _frameInk,
      _openStop,
    )!,
    _ => background,
  };

  void _drawGlyph(
    Canvas canvas,
    String glyph,
    int ink,
    int cell,
    double side,
    double strength,
  ) {
    final int step = (strength * (_glyphAlphaSteps - 1)).round();
    if (step <= 0) {
      return;
    }
    final ui.Paragraph? paragraph = _glyph(glyph, ink, step, side);
    if (paragraph == null) {
      return;
    }
    canvas.drawParagraph(
      paragraph,
      Offset(_x[cell] - side / 2, _y[cell] - paragraph.height / 2),
    );
  }

  void _drawTracer(Canvas canvas, Size size, double side, double t) {
    final Tracer? pin = tracer;
    if (pin == null) {
      return;
    }
    // A selected run needs no marker: it is the only thing on the page still at
    // full strength, and a box around one of its 787 cells would be a lie about
    // what was picked.
    if (pin.asRun && _selectedFeature >= 0) {
      return;
    }

    final int cell = scene.from.cellAt(pin.genomicPosition);
    if (cell < 0) {
      // The base is gone. The ring stays — it must never silently disappear —
      // but it is struck through, because it now sits over a grid it is no
      // longer part of and a plain ring there would read as a live selection.
      // The slash is a shape, so the fate survives colour blindness, and the
      // caption states it in words as well.
      final Offset? inert = inertTracer;
      if (inert != null) {
        // Held on screen. A departing cell flees the centre of the canvas, so
        // one that left from the edge of the grid comes to rest past the edge
        // of the phone — and a ring that must never silently disappear may not
        // be half of a ring hanging off the side either. Since the merge this
        // is the ordinary case rather than a corner one: the `RR` site sits in
        // the precursor's left-hand column.
        _drawHighlight(
          canvas,
          _onScreen(inert, size, side),
          side,
          anatomy.tracer,
          0.5,
          struck: true,
        );
      }
      return;
    }

    // Translation's ring follows the same folded group as its three bases.
    // A separate straight path would detach it from the residue being traced.
    if (scene.translation case final AnatomyTranslation motion) {
      final int residue = scene.target[cell];
      final List<int> members = residue >= 0
          ? motion.bases[residue]
          : scene.from.frameCodon(scene.from.codonMarkAt(cell));
      final Iterable<int> marked = members.isEmpty ? <int>[cell] : members;
      Rect? bounds;
      for (final int member in marked) {
        final Rect tile = Rect.fromCenter(
          center: Offset(_x[member], _y[member]),
          width: side,
          height: side,
        );
        bounds = bounds?.expandToInclude(tile) ?? tile;
      }
      final double removed = residue < 0 ? AnatomyTranslation.removal(t) : 0;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          bounds!.inflate(2),
          Radius.circular(side * 0.24),
        ),
        _highlightPaint
          ..strokeWidth = 1
          ..color = anatomy.tracer.withValues(alpha: 0.7 * (1 - removed)),
      );
      return;
    }

    // A codon is selected whole, and marked whole: one quiet outline around the
    // three, rather than a ring on whichever of them the finger landed on and
    // two paler ones beside it. The frame's two ends have always been drawn
    // this way — every other codon is the same question.
    final List<int> codon = scene.from.codonCellsAt(cell);
    if (codon.isNotEmpty) {
      Rect bounds = Rect.fromCenter(
        center: Offset(_x[codon.first], _y[codon.first]),
        width: side,
        height: side,
      );
      for (final int member in codon.skip(1)) {
        bounds = bounds.expandToInclude(
          Rect.fromCenter(
            center: Offset(_x[member], _y[member]),
            width: side,
            height: side,
          ),
        );
      }
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          bounds.inflate(2),
          Radius.circular(side * 0.24),
        ),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.5
          ..color = anatomy.tracer.withValues(alpha: 0.7),
      );
      return;
    }

    // Codon siblings ride the same interpolation, so the three of them are
    // visibly one group before they become one square.
    final List<int> siblings = status?.siblings ?? const <int>[];
    for (final int sibling in siblings) {
      if (sibling >= 0 && sibling < _count) {
        _drawHighlight(
          canvas,
          Offset(_x[sibling], _y[sibling]),
          side,
          anatomy.tracerSibling,
          1,
        );
      }
    }

    // The tracer is exempt from the stagger: it has to be the clearest moving
    // thing on screen while everything around it reorganises, so it travels on
    // the raw progress rather than waiting its turn in the ripple. If the eye
    // loses it here, the whole interaction has failed.
    final Offset origin = scene.fromLayout.centreOf(cell);
    final int landing = scene.target[cell];
    final double eased = AnatomyMotion.ease(t);

    if (landing < 0) {
      // It is going out with the intron. It drifts and dims, but only part of
      // the way: it has to still be findable at the end, because that is where
      // it stays for every stage after this one.
      final Offset centre = Offset(
        scene.canvas.width / 2,
        scene.canvas.height / 2,
      );
      Offset away = origin - centre;
      away = away.distance < 1e-6 ? const Offset(0, -1) : away / away.distance;
      final Offset here =
          origin +
          away * scene.fromLayout.cell * AnatomyMotion.driftCells * eased;
      _drawHighlight(canvas, here, side, anatomy.tracer, 1 - 0.45 * eased);
      return;
    }

    final Offset destination = scene.toLayout.centreOf(landing);
    _drawHighlight(
      canvas,
      Offset.lerp(origin, destination, eased)!,
      side,
      anatomy.tracer,
      1,
    );
  }

  /// [point] pulled far enough inside [size] for a whole highlight to fit.
  static Offset _onScreen(Offset point, Size size, double side) {
    final double half = _highlightSide(side) / 2 + _highlightWidth * 1.3;
    if (size.width < 2 * half || size.height < 2 * half) {
      return point;
    }
    return Offset(
      point.dx.clamp(half, size.width - half),
      point.dy.clamp(half, size.height - half),
    );
  }

  /// A little larger than the cell it marks: a box drawn inside the square
  /// reads as a border it has grown, a box drawn around it reads as a square
  /// that has been picked out.
  static double _highlightSide(double side) =>
      math.max(side * 1.16, _minHighlight);

  void _drawHighlight(
    Canvas canvas,
    Offset centre,
    double side,
    Color colour,
    double strength, {
    bool struck = false,
  }) {
    final double size = _highlightSide(side);
    final RRect box = RRect.fromRectAndRadius(
      Rect.fromCenter(center: centre, width: size, height: size),
      Radius.circular(size * 0.22),
    );
    final Offset slash = Offset(size / 2, -size / 2);

    // A background-coloured box underneath, so the tracer reads against every
    // base colour, every role tint and every stage of fading out. This is the
    // one element that is never allowed to be ambiguous.
    _highlightPaint
      ..color = background
      ..strokeWidth = _highlightWidth * 2.6;
    canvas.drawRRect(box, _highlightPaint);
    if (struck) {
      canvas.drawLine(centre - slash, centre + slash, _highlightPaint);
    }

    _highlightPaint
      ..color = Color.lerp(background, colour, strength)!
      ..strokeWidth = _highlightWidth;
    canvas.drawRRect(box, _highlightPaint);
    if (struck) {
      canvas.drawLine(centre - slash, centre + slash, _highlightPaint);
    }
  }

  // ------------------------------------------------------------------- luts

  void _syncBlend(double t, double open) {
    final int step = (t * (_blendSteps - 1)).round();
    // The frame's two fills ride the groove, so the table has to rebuild when
    // either clock moves. Both are quantised, so a settled page rebuilds it
    // exactly once however many frames it is asked to paint.
    final int grooveStep = (open * (_blendSteps - 1)).round();
    final int selectionStep = (_selectionStrength * (_blendSteps - 1)).round();
    if (step == _blendStep &&
        grooveStep == _grooveStep &&
        selectionStep == _selectionBlendStep) {
      return;
    }
    _blendStep = step;
    _grooveStep = grooveStep;
    _selectionBlendStep = selectionStep;
    _open = grooveStep / (_blendSteps - 1);
    _openStart = _frameOpen(CodonMark.start);
    _openStop = _frameOpen(CodonMark.stop);

    final double blend = step / (_blendSteps - 1);
    for (final int pair in scene.usedPairs) {
      final Color mixed = Color.lerp(
        _slotColour(pair ~/ CellSlot.count),
        _slotColour(pair % CellSlot.count),
        blend,
      )!;
      final bool selecting = _selectedFeature >= 0;
      final Color outside = selecting
          ? Color.lerp(mixed, _stepBack(mixed), _selectionStrength)!
          : mixed;
      for (int within = 0; within < 2; within++) {
        // Untouched inside the selection: not lerped toward anything, not even
        // by zero, so the bytes that reach the framebuffer are the palette's
        // own and a selected run is pixel for pixel what it was.
        final Color colour = within == 1 ? mixed : outside;
        final int offset = (pair * 2 + within) * _shadeSteps;
        for (int level = 0; level < _shadeSteps; level++) {
          _pairColour[offset + level] = Color.lerp(
            background,
            colour,
            level / (_shadeSteps - 1),
          )!;
        }
      }
    }
  }

  /// Roles and residues come from the table the strip also reads; the bases
  /// are the painter's own business, because nothing else draws them.
  Color _slotColour(int slot) => switch (slot) {
    // The frame's two ends, mixed *from the tile they were* rather than from
    // the ground: these six squares are already on the page when the groove
    // starts, and a fill that came up out of the background would read as six
    // bases arriving late rather than as six that have just been named.
    CellSlot.frameStart => Color.lerp(
      anatomy.baseTile,
      anatomy.roleStartCodon,
      _openStart,
    )!,
    CellSlot.frameStop => Color.lerp(
      anatomy.baseTile,
      anatomy.roleStopCodon,
      _openStop,
    )!,
    // One tile under every base. Which base a cell is rides on its letter
    // instead — see [_inkFor].
    >= CellSlot.adenine && <= CellSlot.baseUnknown => anatomy.baseTile,
    // The untranslated ends: the same tile, stepped back toward the ground.
    // Resolved here rather than tabulated in the theme, because it is not a
    // colour anyone chose — it is the tile, quieter.
    >= CellSlot.adenineDim && <= CellSlot.baseUnknownDim => Color.lerp(
      background,
      _slotColour(slot - CellSlot.dimOffset),
      _utrTile,
    )!,
    _ => _shared(slot),
  };

  /// Where the sweep has got to at the [mark] end of the frame.
  ///
  /// Asks the layout where that end actually is rather than assuming the first
  /// row and the last, so a coding sequence short enough to fit on one row —
  /// where both ends share a row and open together — stays honest.
  double _frameOpen(CodonMark mark) {
    if (_open >= 1) {
      return 1;
    }
    final bool arriving = scene.to.frameCodon(mark).isNotEmpty;
    final List<int> codon = (arriving ? scene.to : scene.from).frameCodon(mark);
    if (codon.isEmpty) {
      return _open;
    }
    return (arriving ? scene.toLayout : scene.fromLayout)
        .opened(_open)
        .openAt(codon.first);
  }

  Color _shared(int slot) {
    final Color? colour = anatomy.forSlot(slot);
    if (colour != null) {
      return colour;
    }
    assert(slot == CellSlot.pending, 'unmapped cell slot $slot');
    return anatomy.pending;
  }

  void _syncGlyphs(double side) {
    // Quantised, so a size that creeps by a fraction of a pixel across a reflow
    // does not throw the whole cache away every frame.
    final double quantised = (side / 2).roundToDouble() * 2;
    // [_inkFrame]'s colour moves with the groove, so its paragraphs go stale
    // with it. Thrown away wholesale rather than keyed, because a settled page
    // holds a handful of them — one alpha step, four letters — and the groove
    // is quantised to twenty steps that run once per arrival.
    if (quantised == _glyphSize && _open == _glyphOpen) {
      return;
    }
    _glyphSize = quantised;
    _glyphOpen = _open;
    _glyphs.clear();
  }

  ui.Paragraph? _glyph(String glyph, int ink, int step, double side) {
    if (glyph.isEmpty) {
      return null;
    }
    final int key =
        (glyph.codeUnitAt(0) * _inkCount + ink) * _glyphAlphaSteps + step;
    final ui.Paragraph? cached = _glyphs[key];
    if (cached != null) {
      return cached;
    }

    final ui.Paragraph paragraph = _buildGlyph(
      glyph,
      ink,
      step / (_glyphAlphaSteps - 1),
      side,
      _glyphSize,
    );
    _glyphs[key] = paragraph;
    return paragraph;
  }

  ui.Paragraph _buildGlyph(
    String glyph,
    int ink,
    double opacity,
    double side,
    double fontSide,
  ) {
    // Three inks for every glyph, never one per cell colour: the cache stays a
    // few dozen paragraphs wide rather than a few dozen per fill.
    final Color colour = Color.lerp(
      Colors.transparent,
      _inkColour(ink, glyph),
      opacity,
    )!;

    // Three fifths of the cell — 12pt on the 20pt bases of the transcript page,
    // which is where this number was set. Medium rather than regular: at 12pt a
    // regular weight's thin strokes wash out, whether they are cut from a
    // saturated fill or are themselves what carries a base's colour.
    final ui.ParagraphBuilder builder =
        ui.ParagraphBuilder(
            ui.ParagraphStyle(
              fontFamily: AppTypography.monoFamily,
              fontSize: fontSide * 0.6,
              textAlign: TextAlign.center,
            ),
          )
          ..pushStyle(ui.TextStyle(color: colour, fontWeight: FontWeight.w500))
          ..addText(glyph);

    final ui.Paragraph paragraph = builder.build()
      ..layout(ui.ParagraphConstraints(width: side));
    return paragraph;
  }

  static double _lerp(double a, double b, double t) => a + (b - a) * t;

  @override
  SemanticsBuilderCallback? get semanticsBuilder => !_constraintAtRest
      ? null
      : (Size size) => <CustomPainterSemantics>[
          for (final ResidueConstraint p in constraint!.positions)
            CustomPainterSemantics(
              key: ValueKey<int>(p.index),
              rect: Rect.fromCenter(
                center: scene.fromLayout.centreOf(p.index),
                width: scene.fromLayout.side,
                height: scene.fromLayout.side,
              ),
              properties: SemanticsProperties(
                textDirection: TextDirection.ltr,
                label:
                    '${p.spoken}, ${p.domain}, ${p.level.label}'
                    '${switch (conservation ? marks[p.index] : null) {
                      final ClinVarMark mark =>
                        ', ClinVar ${mark.count} record${mark.count == 1 ? '' : 's'}',
                      null => '',
                    }}',
                button: true,
                selected: p.index == maskedIndex,
                onTap: () => onConstraintTapped?.call(p.index),
              ),
            ),
        ];

  @override
  bool shouldRebuildSemantics(covariant AnatomyPainter oldDelegate) =>
      oldDelegate.scene != scene ||
      oldDelegate.constraint != constraint ||
      oldDelegate.maskedIndex != maskedIndex ||
      oldDelegate.conservation != conservation ||
      !mapEquals(oldDelegate.marks, marks);

  @override
  bool shouldRepaint(covariant AnatomyPainter old) =>
      old.scene != scene ||
      old.progress != progress ||
      old.groove != groove ||
      old.reverse != reverse ||
      old.tracer != tracer ||
      old.status != status ||
      old.inertTracer != inertTracer ||
      old.background != background ||
      old.nucleotides != nucleotides ||
      old.anatomy != anatomy ||
      old.constraint != constraint ||
      old.conservation != conservation ||
      !mapEquals(old.marks, marks) ||
      old.maskedIndex != maskedIndex ||
      old.masking != masking ||
      old.maskAccent != maskAccent ||
      old.rulerInk != rulerInk ||
      !listEquals(old.junctions, junctions) ||
      !mapEquals(old.bridges, bridges);
}
