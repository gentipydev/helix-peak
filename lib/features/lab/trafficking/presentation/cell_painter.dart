import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/anatomy_colors.dart';
import '../../../../shared/anatomy/anatomy_motion.dart';
import '../../../../shared/motion/animation_timeline.dart';
import '../domain/route_timeline.dart';
import '../domain/trafficking_route.dart';

/// The colours the cell is drawn in, every one of them the theme's.
@immutable
final class CellInks {
  const CellInks({
    required this.background,
    required this.cytosol,
    required this.organelle,
    required this.membrane,
    required this.lit,
    required this.ink,
    required this.quiet,
    required this.chain,
    required this.signal,
    required this.bridge,
    required this.label,
  });

  factory CellInks.of(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final AnatomyColors anatomy = context.anatomyColors;
    return CellInks(
      background: scheme.surface,
      cytosol: scheme.surfaceContainerLow,
      organelle: scheme.surfaceContainerHighest,
      membrane: scheme.outline,
      lit: scheme.primary,
      ink: scheme.onSurface,
      quiet: scheme.onSurfaceVariant,
      chain: anatomy.roleMature1,
      signal: anatomy.roleSignal,
      bridge: anatomy.aminoCysteine,
      label: theme.textTheme.labelSmall ?? const TextStyle(fontSize: 11),
    );
  }

  final Color background;
  final Color cytosol;
  final Color organelle;
  final Color membrane;

  /// A compartment the chain is in, or has been through.
  final Color lit;
  final Color ink;
  final Color quiet;

  /// The chain itself, its signal peptide, and its bridges: the walk's own
  /// colours for a mature chain, a signal peptide and a cysteine.
  final Color chain;
  final Color signal;
  final Color bridge;

  /// The compartments' names.
  final TextStyle label;

  @override
  bool operator ==(Object other) =>
      other is CellInks &&
      other.background == background &&
      other.cytosol == cytosol &&
      other.organelle == organelle &&
      other.membrane == membrane &&
      other.lit == lit &&
      other.ink == ink &&
      other.quiet == quiet &&
      other.chain == chain &&
      other.signal == signal &&
      other.bridge == bridge &&
      other.label == label;

  @override
  int get hashCode => Object.hash(
    background,
    cytosol,
    organelle,
    membrane,
    lit,
    ink,
    quiet,
    chain,
    signal,
    bridge,
    label,
  );
}

/// Where each part of the one cell sits, for a canvas of [size].
///
/// Every protein is drawn in this same cell. Nothing in it is a particular
/// kind of cell: a membrane, a nucleus, the ER beside it, a Golgi stack and
/// its vesicles, the way a textbook draws any cell that secretes.
@immutable
final class CellLayout {
  CellLayout(this.size)
    : unit = math.min(size.width, size.height),
      cell = RRect.fromLTRBR(
        size.width * 0.05,
        size.height * 0.2,
        size.width * 0.95,
        size.height * 0.97,
        Radius.circular(math.min(size.width, size.height) * 0.12),
      );

  final Size size;

  /// The shorter side, which every organelle is sized by.
  final double unit;

  /// The plasma membrane, as the outline of the cell.
  final RRect cell;

  Offset get nucleus => Offset(size.width * 0.3, size.height * 0.77);
  double get nucleusRadius => unit * 0.15;

  /// The ER's sheets, as arcs around the nucleus: each radius, and the sweep
  /// they share.
  List<double> get erRadii => <double>[
    for (final double f in <double>[1.3, 1.55, 1.8]) nucleusRadius * f,
  ];
  static const double erFrom = -math.pi * 0.72;
  static const double erSweep = math.pi * 0.78;

  Offset get golgi => Offset(size.width * 0.68, size.height * 0.62);

  /// The Golgi's cisternae, as widths, top to bottom.
  List<double> get golgiWidths => <double>[
    for (final double f in <double>[0.3, 0.26, 0.22, 0.18]) size.width * f,
  ];
  double get golgiSpacing => unit * 0.04;

  List<Offset> get vesicles => <Offset>[
    Offset(size.width * 0.74, size.height * 0.42),
    Offset(size.width * 0.63, size.height * 0.38),
    Offset(size.width * 0.8, size.height * 0.33),
  ];
  double get vesicleRadius => unit * 0.028;

  /// Where the chain sits in [compartment]. An unknown step sits just past
  /// the step before it, [after].
  Offset anchorOf(Compartment compartment, {Compartment? after}) =>
      switch (compartment) {
        Compartment.cytosol => Offset(size.width * 0.2, size.height * 0.42),
        Compartment.er =>
          nucleus + Offset.fromDirection(-math.pi * 0.3, erRadii[1]),
        Compartment.golgi => golgi,
        Compartment.vesicle => vesicles.first,
        Compartment.extracellular => Offset(
          size.width * 0.84,
          size.height * 0.08,
        ),
        Compartment.membrane => Offset(size.width * 0.84, cell.top),
        Compartment.nucleus => nucleus,
        Compartment.gpiAnchored => Offset(
          size.width * 0.84,
          cell.top - unit * 0.05,
        ),
        Compartment.unknown =>
          after == Compartment.vesicle
              ? Offset(size.width * 0.84, cell.top + unit * 0.07)
              : Offset(size.width * 0.34, size.height * 0.5),
      };
}

/// The one cell scene: every compartment drawn, the route's lit in order as
/// the chain reaches it, at the `t` [at] reads.
///
/// The route decides everything that differs between proteins: which
/// compartments light, in what order, what happens to the chain on the way,
/// and where it stops. Nothing here reads which protein it is.
class CellPainter extends CustomPainter {
  CellPainter({
    required this.timeline,
    required this.at,
    required this.inks,
    super.repaint,
  });

  final RouteTimeline timeline;
  final double Function() at;
  final CellInks inks;

  TraffickingRoute get route => timeline.route;

  /// What a screen reader is told, in place of the picture: the route, and
  /// where the chain is on it.
  static String describe(RouteTimeline timeline, RouteMoment moment) {
    final List<String> names = <String>[
      for (final RouteStep step in timeline.route.steps)
        RouteTimeline.nameOf(step.compartment),
    ];
    final String now = RouteTimeline.nameOf(
      timeline.route.steps[moment.step].compartment,
    );
    return 'A cell, and the route the chain takes through it: '
        '${names.join(', ')}. Now at: $now.';
  }

  @override
  void paint(Canvas canvas, Size size) {
    final CellLayout layout = CellLayout(size);
    final RouteMoment moment = timeline.stateAt(at());
    canvas.drawRect(Offset.zero & size, Paint()..color = inks.background);

    _cell(canvas, layout, moment);
    _nucleus(canvas, layout, moment);
    _er(canvas, layout, moment);
    _golgi(canvas, layout, moment);
    _vesicles(canvas, layout, moment);
    _destination(canvas, layout, moment);
    _path(canvas, layout, moment);
    _chain(canvas, layout, moment);
  }

  /// How lit [compartment] is at [moment]: fully while the chain is there,
  /// half once it has moved on, and not at all before it arrives.
  double _lit(Compartment compartment, RouteMoment moment) {
    double level = 0;
    for (int i = 0; i <= moment.step; i++) {
      if (route.steps[i].compartment != compartment) {
        continue;
      }
      level = i < moment.step
          ? 0.45
          : i == 0
          ? 1
          : AnimationTimeline.slice(moment.progress, 0.3, 0.5);
    }
    return level;
  }

  Color _tone(Color base, double lit) => Color.lerp(base, inks.lit, lit)!;

  void _cell(Canvas canvas, CellLayout layout, RouteMoment moment) {
    final double cytosol = _lit(Compartment.cytosol, moment);
    canvas.drawRRect(
      layout.cell,
      Paint()..color = Color.lerp(inks.cytosol, inks.lit, cytosol * 0.18)!,
    );
    final double membrane = _lit(Compartment.membrane, moment);
    final Paint bilayer = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.5, layout.unit * 0.008)
      ..color = _tone(inks.membrane, membrane);
    final double gap = layout.unit * 0.012;
    canvas
      ..drawRRect(layout.cell.inflate(gap / 2), bilayer)
      ..drawRRect(layout.cell.deflate(gap / 2), bilayer);
    _label(
      canvas,
      'Cytosol',
      layout.anchorOf(Compartment.cytosol) + Offset(0, layout.unit * 0.07),
      cytosol,
    );
    _label(
      canvas,
      'Outside the cell',
      Offset(layout.size.width * 0.3, layout.cell.top * 0.45),
      _lit(Compartment.extracellular, moment),
    );
  }

  void _nucleus(Canvas canvas, CellLayout layout, RouteMoment moment) {
    final double lit = _lit(Compartment.nucleus, moment);
    canvas.drawCircle(
      layout.nucleus,
      layout.nucleusRadius,
      Paint()..color = _tone(inks.organelle, lit * 0.5),
    );
    final Paint envelope = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1, layout.unit * 0.006)
      ..color = _tone(inks.membrane, lit);
    canvas
      ..drawCircle(layout.nucleus, layout.nucleusRadius, envelope)
      ..drawCircle(
        layout.nucleus,
        layout.nucleusRadius - layout.unit * 0.012,
        envelope,
      );
    _label(canvas, 'Nucleus', layout.nucleus, lit);
  }

  void _er(Canvas canvas, CellLayout layout, RouteMoment moment) {
    final double lit = _lit(Compartment.er, moment);
    final Paint sheet = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = math.max(3, layout.unit * 0.022)
      ..color = _tone(inks.organelle, lit);
    for (final double radius in layout.erRadii) {
      canvas.drawArc(
        Rect.fromCircle(center: layout.nucleus, radius: radius),
        CellLayout.erFrom,
        CellLayout.erSweep,
        false,
        sheet,
      );
    }
    _label(
      canvas,
      'ER',
      layout.nucleus +
          Offset.fromDirection(-math.pi * 0.62, layout.erRadii.last * 1.12),
      lit,
    );
  }

  void _golgi(Canvas canvas, CellLayout layout, RouteMoment moment) {
    final double lit = _lit(Compartment.golgi, moment);
    final Paint cisterna = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = math.max(3, layout.unit * 0.02)
      ..color = _tone(inks.organelle, lit);
    final List<double> widths = layout.golgiWidths;
    for (int i = 0; i < widths.length; i++) {
      final double y =
          layout.golgi.dy + (i - (widths.length - 1) / 2) * layout.golgiSpacing;
      final double half = widths[i] / 2;
      canvas.drawPath(
        Path()
          ..moveTo(layout.golgi.dx - half, y + layout.unit * 0.02)
          ..quadraticBezierTo(
            layout.golgi.dx,
            y - layout.unit * 0.03,
            layout.golgi.dx + half,
            y + layout.unit * 0.02,
          ),
        cisterna,
      );
    }
    _label(
      canvas,
      'Golgi',
      layout.golgi + Offset(0, layout.golgiSpacing * 2.6),
      lit,
    );
  }

  void _vesicles(Canvas canvas, CellLayout layout, RouteMoment moment) {
    final double lit = _lit(Compartment.vesicle, moment);
    final Paint wall = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.5, layout.unit * 0.008)
      ..color = _tone(inks.membrane, lit);
    final Paint lumen = Paint()..color = _tone(inks.organelle, lit * 0.6);
    for (final Offset centre in layout.vesicles) {
      canvas
        ..drawCircle(centre, layout.vesicleRadius, lumen)
        ..drawCircle(centre, layout.vesicleRadius, wall);
    }
  }

  /// The end of the route, drawn only once the chain reaches it: the marks
  /// of a chain let out, held in the membrane, or anchored to its face.
  void _destination(Canvas canvas, CellLayout layout, RouteMoment moment) {
    final int last = route.steps.length - 1;
    if (moment.step < last) {
      return;
    }
    final double shown = AnimationTimeline.slice(moment.progress, 0.3, 0.6);
    if (shown <= 0) {
      return;
    }
    final Compartment end = route.destination;
    final Compartment? before = last > 0
        ? route.steps[last - 1].compartment
        : null;
    final Offset spot = layout.anchorOf(end, after: before);
    final Paint mark = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.5, layout.unit * 0.008)
      ..color = inks.lit.withValues(alpha: shown);
    switch (end) {
      case Compartment.membrane:
        canvas.drawLine(
          spot.translate(0, -layout.unit * 0.04),
          spot.translate(0, layout.unit * 0.04),
          mark..strokeWidth = layout.unit * 0.02,
        );
      case Compartment.gpiAnchored:
        canvas.drawLine(Offset(spot.dx, layout.cell.top), spot, mark);
      case Compartment.unknown:
        _unknown(canvas, spot, layout, shown);
      case Compartment.cytosol ||
          Compartment.er ||
          Compartment.golgi ||
          Compartment.vesicle ||
          Compartment.extracellular ||
          Compartment.nucleus:
        break;
    }
  }

  /// A dashed ring and a question mark where the evidence stops.
  void _unknown(Canvas canvas, Offset spot, CellLayout layout, double shown) {
    final double radius = layout.unit * 0.055;
    final Paint ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.5, layout.unit * 0.007)
      ..color = inks.quiet.withValues(alpha: shown);
    const int dashes = 12;
    for (int i = 0; i < dashes; i++) {
      canvas.drawArc(
        Rect.fromCircle(center: spot, radius: radius),
        i * 2 * math.pi / dashes,
        math.pi / dashes,
        false,
        ring,
      );
    }
    final TextPainter mark = TextPainter(
      text: TextSpan(
        text: '?',
        style: inks.label.copyWith(
          color: inks.ink.withValues(alpha: shown),
          fontSize: radius * 1.2,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    mark.paint(canvas, spot - Offset(mark.width / 2, mark.height / 2));
    mark.dispose();
  }

  /// The way the chain has come, as a faint dotted line.
  void _path(Canvas canvas, CellLayout layout, RouteMoment moment) {
    final List<Offset> points = <Offset>[
      for (int i = 0; i <= moment.step; i++)
        if (route.steps[i].compartment != Compartment.unknown)
          _anchor(layout, i),
    ];
    if (points.length < 2) {
      return;
    }
    final Paint dot = Paint()..color = inks.quiet.withValues(alpha: 0.5);
    final double step = layout.unit * 0.025;
    for (int i = 0; i + 1 < points.length; i++) {
      final double reach =
          i + 1 < points.length - 1 || points.length - 1 < moment.step
          ? 1
          : AnatomyMotion.ease(
              AnimationTimeline.slice(moment.progress, 0, 0.5, eased: false),
            );
      final Offset from = points[i];
      final Offset to = Offset.lerp(from, points[i + 1], reach)!;
      final double length = (to - from).distance;
      for (double d = 0; d <= length; d += step) {
        canvas.drawCircle(
          Offset.lerp(from, to, length == 0 ? 0 : d / length)!,
          layout.unit * 0.004,
          dot,
        );
      }
    }
  }

  Offset _anchor(CellLayout layout, int step) => layout.anchorOf(
    route.steps[step].compartment,
    after: step > 0 ? route.steps[step - 1].compartment : null,
  );

  /// Whether [event] has happened by [moment]: at an earlier step, or at this
  /// one once the chain has arrived.
  bool _done(RouteEvent event, RouteMoment moment) {
    for (int i = 0; i <= moment.step; i++) {
      if (route.steps[i].events.contains(event) &&
          (i < moment.step || moment.progress >= 0.5)) {
        return true;
      }
    }
    return false;
  }

  /// The chain: carried from the step before in the first half of a beat,
  /// then still, with what has been done to it drawn on it. Where the route
  /// stops at unknown, it stays where it was.
  void _chain(Canvas canvas, CellLayout layout, RouteMoment moment) {
    final bool stopped =
        route.steps[moment.step].compartment == Compartment.unknown;
    final Offset here = _anchor(layout, moment.step);
    final Offset position = moment.step == 0
        ? here
        : stopped
        ? _anchor(layout, moment.step - 1)
        : Offset.lerp(
            _anchor(layout, moment.step - 1),
            here,
            AnimationTimeline.slice(moment.progress, 0, 0.5),
          )!;
    final double size = layout.unit * 0.022;
    final Paint body = Paint()..color = inks.chain;

    // A ribosome where every chain begins.
    if (moment.step == 0) {
      final Paint ribosome = Paint()..color = inks.quiet;
      canvas
        ..drawOval(
          Rect.fromCenter(
            center: here.translate(0, size * 1.2),
            width: size * 3.2,
            height: size * 1.8,
          ),
          ribosome,
        )
        ..drawOval(
          Rect.fromCenter(
            center: here.translate(0, -size * 0.4),
            width: size * 2.4,
            height: size * 1.4,
          ),
          ribosome,
        );
    }

    // Still carrying its signal peptide until it is cut off.
    if (route.evidence.signalPeptide != null &&
        !_done(RouteEvent.signalPeptideCleaved, moment)) {
      canvas.drawCircle(
        position.translate(-size * 1.6, 0),
        size * 0.6,
        Paint()..color = inks.signal,
      );
    }

    final bool cut = _done(RouteEvent.proproteinCut, moment);
    if (_done(RouteEvent.membraneInserted, moment)) {
      final Rect bar = Rect.fromCenter(
        center: position,
        width: size * 0.9,
        height: size * 3,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(bar, Radius.circular(size * 0.45)),
        body,
      );
    } else if (cut) {
      canvas
        ..drawCircle(position.translate(-size * 0.7, 0), size * 0.7, body)
        ..drawCircle(position.translate(size * 0.8, 0), size * 0.55, body);
    } else {
      canvas.drawCircle(position, size, body);
    }

    if (_done(RouteEvent.disulfidesFormed, moment)) {
      final Paint link = Paint()
        ..color = inks.bridge
        ..strokeWidth = math.max(1.5, size * 0.3);
      canvas.drawLine(
        position.translate(-size * 0.6, -size * 1.4),
        position.translate(size * 0.6, -size * 1.4),
        link,
      );
    }

    if (_done(RouteEvent.gpiAnchorAttached, moment)) {
      final Paint anchor = Paint()
        ..color = inks.lit
        ..strokeWidth = math.max(1.5, size * 0.25);
      canvas
        ..drawLine(position, position.translate(0, size * 2.2), anchor)
        ..drawCircle(position.translate(0, size * 2.4), size * 0.35, anchor);
    }
  }

  void _label(Canvas canvas, String text, Offset centre, double lit) {
    final TextPainter label = TextPainter(
      text: TextSpan(
        text: text,
        style: inks.label.copyWith(
          color: Color.lerp(inks.quiet, inks.lit, lit),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    label.paint(canvas, centre - Offset(label.width / 2, label.height / 2));
    label.dispose();
  }

  @override
  bool shouldRepaint(CellPainter old) =>
      old.timeline != timeline || old.inks != inks || old.at() != at();
}
