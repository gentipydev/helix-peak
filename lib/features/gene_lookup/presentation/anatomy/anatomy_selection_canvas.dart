import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../../../../core/theme/anatomy_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/nucleotide_colors.dart';
import 'anatomy_canvas.dart';
import 'anatomy_layout.dart';
import 'anatomy_painter.dart';
import 'anatomy_scene.dart';
import 'anatomy_selection.dart';
import 'anatomy_stages.dart';
import 'anatomy_tracer.dart';

/// Uses the same painter and glyphs as the transcript page, on tiles large
/// enough to tap — see [AnatomyLayout.inspection].
///
/// A coding region forms its codons once it has landed, on the same groove the
/// transcript page opens its reading frame with — across, and down as well.
///
/// A tapped base lifts out of the grid, and for now that is all a tap does. The
/// lift is drawn over the grid rather than in it, so it can be replaced without
/// touching the painter.
class AnatomySelectionCanvas extends StatefulWidget {
  const AnatomySelectionCanvas({
    required this.model,
    required this.selection,
    required this.viewport,
    required this.progress,
    required this.tracer,
    required this.resting,
    required this.returning,
    required this.sourceScrollOffset,
    required this.targetScrollOffset,
    this.lifted,
    this.onLongPress,
    this.onBaseTapped,
    super.key,
  });

  final AnatomyModel model;
  final AnatomySelection selection;
  final Size viewport;
  final Animation<double> progress;
  final Tracer tracer;
  final bool resting;
  final bool returning;
  final double sourceScrollOffset;
  final double targetScrollOffset;

  /// Which base the screen believes is lifted, or null.
  ///
  /// The tile is raised and lowered by a tap on the canvas itself, which then
  /// tells the screen through [onBaseTapped]. This is the other direction, and
  /// the only thing that uses it is the inspector closing: dismissing the sheet
  /// puts the base back down, the way dismissing the residue panel puts the
  /// mask back. A tap is still what raises one.
  final int? lifted;

  /// A long press on the open region: copy its DNA.
  final VoidCallback? onLongPress;

  /// The base now lifted, or null once it is set down, so the header can say
  /// where it is.
  final ValueChanged<int?>? onBaseTapped;

  @override
  State<AnatomySelectionCanvas> createState() => _AnatomySelectionCanvasState();
}

class _AnatomySelectionCanvasState extends State<AnatomySelectionCanvas>
    with TickerProviderStateMixin {
  /// The lifted cell of the selected region, or null.
  ///
  /// A notifier rather than state: a tap repaints the lift and nothing else, so
  /// a long region's grid is never rebuilt or repainted to pick out one base.
  final ValueNotifier<int?> _lifted = ValueNotifier<int?>(null);

  late final AnimationController _lift = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 200),
  );

  /// Overshoots on the way up, which is what makes the lift read as a pop.
  late final Animation<double> _pop = CurvedAnimation(
    parent: _lift,
    curve: Curves.easeOutBack,
  );

  /// How far a coding region's codons have formed, 0 to 1.
  ///
  /// Flush while the bases travel in, so the reveal is the only thing the eye
  /// has to follow; it opens once they have landed. A canvas that arrives
  /// already at rest — reduced motion — is simply already formed.
  late final AnimationController _groove = AnimationController(
    vsync: this,
    duration: AnatomyCanvas.grooveDuration,
    value: widget.resting ? 1 : 0,
  );

  /// Both clocks the grid moves on, merged once so the painter is handed the
  /// same Listenable every frame.
  late final Listenable _repaint = Listenable.merge(<Listenable>[
    widget.progress,
    _groove,
  ]);

  bool get _framed =>
      widget.selection.stage.blocks.any((StageBlock block) => block.framed);

  @override
  void didUpdateWidget(AnatomySelectionCanvas old) {
    super.didUpdateWidget(old);
    if (!old.resting && widget.resting) {
      // Landed. Only a region read in threes has a frame to open; anything
      // else is already as it will stay, and nothing repaints for it.
      if (_framed && !MediaQuery.disableAnimationsOf(context)) {
        unawaited(_groove.forward(from: 0));
      } else {
        _groove.value = 1;
      }
    }
    if (widget.lifted != old.lifted && widget.lifted != _lifted.value) {
      _lifted.value = widget.lifted;
      if (widget.lifted == null) {
        _lift.value = 0;
      } else if (MediaQuery.disableAnimationsOf(context)) {
        // A base lifted by the screen — a ClinVar record's link asked for it
        // by name — rises the way a tapped one does.
        _lift.value = 1;
      } else {
        unawaited(_lift.forward(from: 0));
      }
    }
    if (old.resting && !widget.resting) {
      // Leaving for the whole gene. The frame goes as it is, mid-sweep
      // included, as the transcript's does, and a lifted base does not ride
      // the return at all.
      // The screen lets go of its own record of the lift as it starts the
      // return; this is mid-build, and may not tell it so.
      _groove.stop();
      _lifted.value = null;
      _lift.value = 0;
    }
  }

  @override
  void dispose() {
    _groove.dispose();
    _lift.dispose();
    _lifted.dispose();
    super.dispose();
  }

  /// Tapping a base lifts it, and tapping another moves the lift. Tapping it
  /// again, or empty space, sets it back down — the gesture is its own undo, as
  /// it is on the gene.
  void _tap(int cell) {
    if (cell < 0 || cell == _lifted.value) {
      _lifted.value = null;
      widget.onBaseTapped?.call(null);
      return;
    }
    _lifted.value = cell;
    widget.onBaseTapped?.call(cell);
    if (MediaQuery.disableAnimationsOf(context)) {
      _lift.value = 1;
    } else {
      unawaited(_lift.forward(from: 0));
    }
  }

  @override
  Widget build(BuildContext context) {
    final AnatomyStage stage = widget.selection.stage;
    final Size viewport = widget.viewport;
    final Color ground = Theme.of(context).colorScheme.surface;
    final double detailHeight = AnatomyLayout.heightFor(stage, viewport);
    final Size box = Size(
      viewport.width,
      math.max(
        viewport.height,
        widget.resting
            ? detailHeight
            : math.max(
                detailHeight,
                AnatomyLayout.heightFor(widget.model.stages.first, viewport),
              ),
      ),
    );
    final AnatomyScene scene = AnatomyScene.selection(
      model: widget.model,
      selected: stage,
      canvas: box,
      viewport: viewport,
      sourceScrollOffset: widget.sourceScrollOffset,
      targetScrollOffset: widget.targetScrollOffset,
      resting: widget.resting,
      // Flush on the way in and as far as it got on the way out. At rest the
      // painter opens it on the live clock instead.
      open: widget.resting ? 1 : _groove.value,
    );
    // Where the resting cells are drawn, once opened to wherever the groove
    // has got, and so where a tap is looked up.
    final AnatomyLayout layout = scene.toLayout;
    return Semantics(
      label:
          '${stage.label}, ${stage.count} DNA bases. '
          'Read left to right, 5 prime to 3 prime. '
          '${widget.selection.pieces} selected pieces in sequence order.',
      customSemanticsActions: widget.onLongPress == null
          ? null
          : <CustomSemanticsAction, VoidCallback>{
              const CustomSemanticsAction(label: 'Copy DNA as FASTA'):
                  widget.onLongPress!,
            },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onLongPress: widget.resting ? widget.onLongPress : null,
        // Only at rest. A tile cannot be found under the finger while it is
        // still travelling, which is the rule the gene page keeps too.
        onTapUp: widget.resting
            ? (TapUpDetails details) => _tap(
                layout.opened(_groove.value).hitTest(details.localPosition),
              )
            : null,
        child: Stack(
          // A lifted base in the first row stands a little proud of the box.
          clipBehavior: Clip.none,
          children: <Widget>[
            RepaintBoundary(
              child: CustomPaint(
                size: box,
                willChange: !widget.resting,
                painter: AnatomyPainter(
                  repaint: _repaint,
                  scene: scene,
                  progress: widget.progress,
                  groove: _groove,
                  reverse: widget.returning,
                  tracer: widget.resting ? null : widget.tracer,
                  status: null,
                  inertTracer: null,
                  background: ground,
                  nucleotides: context.nucleotideColors,
                  anatomy: context.anatomyColors,
                  rulerInk: Theme.of(context).colorScheme.onSurfaceVariant,
                  maskAccent: Theme.of(context).colorScheme.primary,
                  junctions: widget.selection.junctions,
                ),
              ),
            ),
            if (widget.resting)
              Positioned.fill(
                // Its own layer, so scrolling the page does not repaint it and
                // lifting a base repaints nothing else.
                child: RepaintBoundary(
                  child: CustomPaint(
                    painter: LiftedBasePainter(
                      layout: layout,
                      letters: stage.letters,
                      cell: _lifted,
                      lift: _pop,
                      open: _groove,
                      ground: ground,
                      tile: context.anatomyColors.baseTile,
                      nucleotides: context.nucleotideColors,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// One base of the selected region, lifted out of the grid under the finger.
///
/// Drawn over the grid rather than inside [AnatomyPainter], so the lift costs
/// one tile a frame however long the region is.
///
/// At a lift of zero it draws the tile exactly as the grid does. From there the
/// tile grows by [growth], fills with its own base's colour and has its letter
/// cut out of that fill, on a ring of ground that keeps it off the neighbours
/// it now overlaps.
class LiftedBasePainter extends CustomPainter {
  LiftedBasePainter({
    required this.layout,
    required this.letters,
    required this.cell,
    required this.lift,
    required this.open,
    required this.ground,
    required this.tile,
    required this.nucleotides,
  }) : super(repaint: Listenable.merge(<Listenable>[cell, lift, open]));

  final AnatomyLayout layout;
  final String letters;

  /// The lifted cell, or null for none.
  final ValueListenable<int?> cell;

  /// 0 where the base sits in the grid and 1 once it is lifted, overshooting
  /// on the way.
  final Animation<double> lift;

  /// How far the grid's codons have formed, so a base lifted while they are
  /// still parting moves with its own square.
  final Animation<double> open;

  final Color ground;
  final Color tile;
  final NucleotideColors nucleotides;

  /// How much larger a lifted base is drawn.
  static const double growth = 0.25;

  /// The ring of ground around a lifted base.
  static const double _halo = 2;

  @override
  void paint(Canvas canvas, Size size) {
    final int? index = cell.value;
    if (index == null || index < 0 || index >= letters.length) {
      return;
    }
    final double t = lift.value;
    final double amount = t.clamp(0.0, 1.0);
    final String letter = letters[index];
    final Color colour = nucleotides.forBase(letter);
    final Offset centre = layout
        .opened(open.value.clamp(0.0, 1.0))
        .centreOf(index);
    final double side = layout.side * (1 + growth * t);
    final RRect square = RRect.fromRectAndRadius(
      Rect.fromCenter(center: centre, width: side, height: side),
      Radius.circular(side * AnatomyLayout.tileRadiusRatio),
    );
    final Paint fill = Paint();
    canvas.drawRRect(square.inflate(_halo * amount), fill..color = ground);
    canvas.drawRRect(square, fill..color = Color.lerp(tile, colour, amount)!);

    // The grid's glyph: three fifths of the side, in the same face and weight.
    final TextPainter glyph = TextPainter(
      text: TextSpan(
        text: letter,
        style: TextStyle(
          fontFamily: AppTypography.monoFamily,
          fontSize: side * 0.6,
          fontWeight: FontWeight.w500,
          color: Color.lerp(colour, ground, amount),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    glyph.paint(canvas, centre - Offset(glyph.width / 2, glyph.height / 2));
    glyph.dispose();
  }

  @override
  bool shouldRepaint(covariant LiftedBasePainter old) =>
      old.layout != layout ||
      old.letters != letters ||
      old.cell != cell ||
      old.lift != lift ||
      old.open != open ||
      old.ground != ground ||
      old.tile != tile ||
      old.nucleotides != nucleotides;
}
