import 'package:flutter/material.dart';

import '../../../core/evidence/protein_constraint.dart';
import '../../../core/theme/anatomy_colors.dart';
import '../../../core/theme/nucleotide_colors.dart';
import '../../../shared/anatomy/anatomy_layout.dart';
import '../../../shared/anatomy/anatomy_painter.dart';
import '../../../shared/anatomy/anatomy_scene.dart';
import '../../../shared/anatomy/anatomy_stages.dart';
import '../../../shared/clinvar/clinvar_colors.dart';

/// One scene of the shared anatomy, drawn by the walk's own painter.
///
/// The lab's flows draw genes and proteins with exactly the machinery the
/// walk draws them with: the scene says where every cell is at every `t`, the
/// shared [AnatomyPainter] draws it, and the layout answers taps. What this
/// adds is only what a lab screen needs around them: a clock that plays a
/// transition scene once when it arrives, a mask for the one cell a sheet is
/// about, and taps reported as cells of the page at rest.
///
/// Reduced motion lands every transition on its last frame.
class LabAnatomyView extends StatefulWidget {
  const LabAnatomyView({
    required this.scene,
    this.duration = const Duration(milliseconds: 1400),
    this.onTap,
    this.maskedIndex,
    this.constraint,
    this.conservation = false,
    this.marks = const <int, ClinVarMark>{},
    this.bridges = const <int, int>{},
    this.junctions = const <int>[],
    this.breaks = const <int>[],
    this.onSettled,
    super.key,
  });

  /// What to draw. A transition plays from its start whenever a new one
  /// arrives; a resting scene simply stands.
  final AnatomyScene scene;

  /// How long a transition takes.
  final Duration duration;

  /// A tap on a cell of the page at rest, as its index in the stage shown.
  /// Taps during a transition are not taken: a cell in flight has no address.
  final ValueChanged<int>? onTap;

  /// The cell a sheet is open on, shown through a scrim over the rest.
  final int? maskedIndex;

  final ProteinConstraint? constraint;
  final bool conservation;
  final Map<int, ClinVarMark> marks;
  final Map<int, int> bridges;
  final List<int> junctions;

  /// Cells with the helix cut immediately 5' of them.
  final List<int> breaks;

  /// Told when a transition has landed (or at once, for a resting scene).
  final VoidCallback? onSettled;

  @override
  State<LabAnatomyView> createState() => _LabAnatomyViewState();
}

class _LabAnatomyViewState extends State<LabAnatomyView>
    with TickerProviderStateMixin {
  late final AnimationController _progress = AnimationController(
    vsync: this,
    duration: widget.duration,
    value: 1,
  );

  /// The reading frame stays open: a lab page is never mid-groove.
  late final AnimationController _groove = AnimationController(
    vsync: this,
    value: 1,
  );

  late final AnimationController _mask = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
    value: widget.maskedIndex == null ? 0 : 1,
  );

  late final Listenable _repaint = Listenable.merge(<Listenable>[
    _progress,
    _groove,
    _mask,
  ]);

  bool _started = false;

  /// Bumped with every scene, so a transition cut short by the next one
  /// cannot report the next one settled.
  int _generation = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      _play();
    }
  }

  @override
  void didUpdateWidget(LabAnatomyView old) {
    super.didUpdateWidget(old);
    _progress.duration = widget.duration;
    if (!identical(old.scene, widget.scene)) {
      _play();
    }
    if ((old.maskedIndex == null) != (widget.maskedIndex == null)) {
      if (MediaQuery.disableAnimationsOf(context)) {
        _mask.value = widget.maskedIndex == null ? 0 : 1;
      } else if (widget.maskedIndex == null) {
        _mask.reverse();
      } else {
        _mask.forward();
      }
    }
  }

  void _play() {
    final int generation = ++_generation;
    if (!widget.scene.isTransition || MediaQuery.disableAnimationsOf(context)) {
      _progress.value = 1;
      _settle();
      return;
    }
    _progress
      ..value = 0
      ..forward().whenCompleteOrCancel(() {
        if (mounted && generation == _generation) {
          _settle();
        }
      });
  }

  void _settle() {
    final VoidCallback? settled = widget.onSettled;
    if (settled != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          settled();
        }
      });
    }
  }

  @override
  void dispose() {
    _progress.dispose();
    _groove.dispose();
    _mask.dispose();
    super.dispose();
  }

  void _tapped(TapUpDetails details) {
    final ValueChanged<int>? onTap = widget.onTap;
    if (onTap == null || _progress.isAnimating) {
      return;
    }
    final AnatomyScene scene = widget.scene;
    final AnatomyLayout layout = scene.isTransition
        ? scene.toLayout
        : scene.fromLayout;
    final int cell = layout.hitTest(details.localPosition);
    if (cell >= 0) {
      onTap(cell);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AnatomyScene scene = widget.scene;
    final AnatomyStage shown = scene.isTransition ? scene.to : scene.from;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapUp: _tapped,
      child: Semantics(
        label:
            '${shown.label}, ${shown.count} ${shown.unit}, '
            'drawn 5 prime to 3 prime',
        child: RepaintBoundary(
          child: CustomPaint(
            size: scene.canvas,
            willChange: true,
            painter: AnatomyPainter(
              repaint: _repaint,
              scene: scene,
              progress: _progress,
              groove: _groove,
              reverse: false,
              tracer: null,
              status: null,
              inertTracer: null,
              background: theme.colorScheme.surface,
              nucleotides: context.nucleotideColors,
              anatomy: context.anatomyColors,
              constraint: widget.constraint,
              conservation: widget.conservation,
              maskedIndex: widget.maskedIndex,
              masking: _mask,
              maskAccent: theme.colorScheme.primary,
              rulerInk: theme.colorScheme.onSurfaceVariant,
              junctions: widget.junctions,
              breaks: widget.breaks,
              bridges: widget.bridges,
              marks: widget.marks,
            ),
          ),
        ),
      ),
    );
  }
}
