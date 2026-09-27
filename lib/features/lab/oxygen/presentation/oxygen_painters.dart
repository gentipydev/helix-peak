import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

import '../../../../core/catalog/protein_target.dart';
import '../../../../core/theme/anatomy_colors.dart';
import '../../../../shared/structure/structure_model.dart';
import '../domain/binding_timeline.dart';
import '../domain/mwc.dart';
import '../domain/oxygen_morph.dart';

/// The colours the tetramer is drawn in, from the theme: the mature-chain tints
/// for its chains, one per gene, as the fold page gives a chain its tint.
@immutable
final class TetramerInks {
  const TetramerInks({
    required this.tints,
    required this.background,
    required this.haem,
    required this.oxygen,
  });

  factory TetramerInks.of(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AnatomyColors anatomy = context.anatomyColors;
    return TetramerInks(
      tints: <Color>[
        ChainTint.mature1.of(anatomy),
        ChainTint.mature2.of(anatomy),
        ChainTint.mature3.of(anatomy),
      ],
      background: theme.colorScheme.surface,
      haem: theme.colorScheme.tertiary,
      oxygen: theme.colorScheme.primary,
    );
  }

  final List<Color> tints;
  final Color background;
  final Color haem;
  final Color oxygen;
}

/// The tetramer between its two states: each chain as the line through its CA
/// atoms, tense and relaxed blended by the frame's R share, seen through the
/// fold page's own camera on the morph's box. Chains of one gene share a
/// colour; each haem is a disc, and each bound oxygen two dots on it.
class TetramerPainter extends CustomPainter {
  TetramerPainter({
    required this.morph,
    required this.timeline,
    required this.at,
    required this.rotation,
    required this.inks,
    super.repaint,
  });

  final TetramerInks inks;
  final OxygenMorph morph;
  final BindingTimeline timeline;
  final double Function() at;
  final vm.Quaternion Function() rotation;

  static String describe(OxygenMorph morph, BindingFrame frame) {
    final int relaxed = (frame.relaxed * 100).round();
    return '${morph.display}: ${frame.bound} of ${morph.chains.length} '
        'oxygen bound, drawn $relaxed% of the way from tense to relaxed.';
  }

  @override
  void paint(Canvas canvas, Size size) {
    final BindingFrame frame = timeline.stateAt(at());
    final PerspectiveCamera camera = structureCamera(
      vm.Aabb3.minMax(_vector(morph.boundsMin), _vector(morph.boundsMax)),
    );
    final vm.Quaternion turn = rotation();
    final List<String> genes = <String>[];
    for (final MorphChain chain in morph.chains) {
      if (!genes.contains(chain.gene)) {
        genes.add(chain.gene);
      }
    }
    final List<Color> tints = inks.tints;
    double blend(double t, double r) => t + (r - t) * frame.relaxed;
    vm.Vector3 blended(MorphPoint t, MorphPoint r) =>
        vm.Vector3(blend(t.$1, r.$1), blend(t.$2, r.$2), blend(t.$3, r.$3));

    // Every segment of every chain, the far ones first.
    final List<(double, Offset, Offset, Color)> segments =
        <(double, Offset, Offset, Color)>[];
    for (final MorphChain chain in morph.chains) {
      final Color tint = tints[genes.indexOf(chain.gene) % tints.length];
      Offset? previous;
      double previousDepth = 0;
      for (int i = 0; i < chain.tense.length; i++) {
        final vm.Vector3 world = turn.rotated(
          blended(chain.tense[i], chain.relaxed[i]),
        );
        final Offset? point = camera.worldToScreen(world, size);
        final double depth = (world - camera.position).length;
        if (point != null && previous != null) {
          segments.add(((depth + previousDepth) / 2, previous, point, tint));
        }
        previous = point;
        previousDepth = depth;
      }
    }
    segments.sort(
      ((double, Offset, Offset, Color) a, (double, Offset, Offset, Color) b) =>
          b.$1.compareTo(a.$1),
    );
    final double near = segments.isEmpty ? 0 : segments.last.$1;
    final double far = segments.isEmpty ? 1 : segments.first.$1;
    final Paint stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = math.max(1.5, size.shortestSide / 160);
    for (final (double depth, Offset a, Offset b, Color tint) in segments) {
      final double fog = 0.45 * (depth - near) / math.max(far - near, 1e-9);
      stroke.color = Color.lerp(tint, inks.background, fog)!;
      canvas.drawLine(a, b, stroke);
    }

    // The haems, the oxygen bound to them, and the one on its way.
    final double dot = math.max(2, size.shortestSide / 110);
    final Paint haem = Paint()..color = inks.haem;
    final Paint oxygen = Paint()..color = inks.oxygen;
    for (int k = 0; k < morph.chains.length; k++) {
      final MorphChain chain = morph.chains[k];
      final vm.Vector3 iron = blended(chain.haemTense, chain.haemRelaxed);
      final Offset? at = camera.worldToScreen(turn.rotated(iron), size);
      if (at == null) {
        continue;
      }
      canvas.drawCircle(at, dot * 1.6, haem);
      final bool bound = k < frame.bound;
      final bool arriving = k == frame.bound && frame.arriving > 0;
      if (!bound && !arriving) {
        continue;
      }
      final vm.Vector3 out = (iron - vm.Vector3.zero())..normalize();
      for (final MorphPoint atom in chain.oxygen) {
        final vm.Vector3 offset = _vector(atom) - _vector(chain.haemRelaxed);
        final vm.Vector3 place = iron + offset;
        final vm.Vector3 there = bound
            ? place
            : place + out * (0.6 * (1 - frame.arriving));
        final Offset? o = camera.worldToScreen(turn.rotated(there), size);
        if (o != null) {
          canvas.drawCircle(o, dot, oxygen);
        }
      }
    }
  }

  static vm.Vector3 _vector(MorphPoint p) => vm.Vector3(p.$1, p.$2, p.$3);

  @override
  bool shouldRepaint(TetramerPainter old) =>
      old.morph != morph ||
      old.timeline != timeline ||
      old.inks != inks ||
      old.at() != at();
}

/// The saturation curve, drawing itself up to the frame's pressure, with the
/// marked point, and the fitted Hill curve dashed beside it for reference.
class SaturationPainter extends CustomPainter {
  SaturationPainter({
    required this.model,
    required this.timeline,
    required this.at,
    required this.ink,
    required this.quiet,
    required this.accent,
    required this.label,
    this.baseline,
    super.repaint,
  }) : hill = HillFit.to(model);

  final Mwc model;
  final BindingTimeline timeline;
  final double Function() at;
  final HillFit hill;

  /// Adult hemoglobin at pH 7.4, faint, where the curve has moved from it.
  final Mwc? baseline;
  final Color ink;
  final Color quiet;
  final Color accent;
  final TextStyle label;

  static const double _left = 34;
  static const double _bottom = 22;

  @override
  void paint(Canvas canvas, Size size) {
    final BindingFrame frame = timeline.stateAt(at());
    final Rect plot = Rect.fromLTRB(
      _left,
      8,
      size.width - 8,
      size.height - _bottom,
    );
    Offset point(double p, double y) => Offset(
      plot.left + plot.width * p / BindingTimeline.ceiling,
      plot.bottom - plot.height * y,
    );
    final Paint axis = Paint()
      ..color = quiet
      ..strokeWidth = 1;
    canvas
      ..drawLine(plot.bottomLeft, plot.bottomRight, axis)
      ..drawLine(plot.bottomLeft, plot.topLeft, axis);
    _text(
      canvas,
      'pO₂ (mmHg)',
      Offset(plot.right, plot.bottom + 4),
      right: true,
    );
    _text(canvas, 'saturation', Offset(2, plot.top));

    Path curve(double Function(double) y, double upTo) {
      final Path path = Path()..moveTo(plot.left, plot.bottom);
      for (double p = 0; p <= upTo; p += 0.5) {
        final Offset o = point(p, y(p));
        path.lineTo(o.dx, o.dy);
      }
      return path;
    }

    if (baseline != null) {
      canvas.drawPath(
        curve(baseline!.saturation, BindingTimeline.ceiling),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = quiet.withValues(alpha: 0.5),
      );
    }
    // The fitted Hill curve: dashed, a reference and nothing more.
    final Paint dash = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = quiet;
    for (double p = 0; p < BindingTimeline.ceiling; p += 2) {
      canvas.drawLine(
        point(p, hill.saturation(p)),
        point(p + 1, hill.saturation(p + 1)),
        dash,
      );
    }
    if (model.sites > 1) {
      _text(
        canvas,
        'Hill fit, for reference: n = ${hill.n.toStringAsFixed(1)}',
        Offset(plot.right, plot.top + plot.height * 0.55),
        right: true,
      );
    }
    // The model's own curve: faint ahead of the point, drawn up to it.
    canvas
      ..drawPath(
        curve(model.saturation, BindingTimeline.ceiling),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = ink.withValues(alpha: 0.25),
      )
      ..drawPath(
        curve(model.saturation, frame.pressure),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4
          ..color = ink,
      )
      ..drawCircle(
        point(frame.pressure, frame.saturation),
        5,
        Paint()..color = accent,
      );
  }

  void _text(Canvas canvas, String text, Offset at, {bool right = false}) {
    final TextPainter painter = TextPainter(
      text: TextSpan(
        text: text,
        style: label.copyWith(color: quiet),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, right ? at - Offset(painter.width, 0) : at);
  }

  @override
  bool shouldRepaint(SaturationPainter old) =>
      old.model != model || old.at() != at() || old.baseline != baseline;
}
