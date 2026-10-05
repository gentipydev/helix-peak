import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/anatomy_figure.dart';
import '../../domain/anatomy_tables.dart';
import '../../domain/zoom_depth.dart';
import '../zoom_inks.dart';
import 'contour.dart';
import 'zoom_subject.dart';

/// An organ as its own scene draws it: in the scene's units, at its real
/// size, its middle at the origin, and where in it its tissue is sampled
/// ([site]).
///
/// Most organs are the anatomogram's own outline for them, the one the body
/// drew, given a surface for the kind of organ it is. The anatomogram is a
/// diagram and draws many of them smaller than they are, so each knows how
/// many times its drawn size it really is ([real]): the scene grows it to
/// that on the way in. A few have no outline of their own there, or none
/// that shows the tissue (a lymph node, a vessel, the skin, a parathyroid
/// gland, the retina), and are drawn from general anatomy. The brain is the
/// anatomogram's brain cut down its middle.
abstract class OrganArt {
  OrganArt();

  factory OrganArt.of(ZoomSubject subject) => OrganArt.forTissue(
    subject.anatomy,
    subject.bodyPart,
    subject.depth.widthOf(ZoomStop.organ),
  );

  /// The organ a tissue drawn as [anatomy] is in, where the body draws it
  /// as [part] and the scene's unit is [view] metres.
  factory OrganArt.forTissue(
    TissueAnatomy? anatomy,
    AnatomyPart? part,
    double view,
  ) {
    if (anatomy == null) {
      return _AnyOrgan();
    }
    final double size = anatomy.metres / view;
    return switch (anatomy.organ) {
      OrganKind.brain => _BrainOrgan(anatomy, view),
      OrganKind.lymphNode => _NodeOrgan(size),
      OrganKind.vessel => _VesselOrgan(size),
      OrganKind.skin => _SkinOrgan(size),
      OrganKind.parathyroid => _ParathyroidOrgan(size),
      OrganKind.eye => _EyeOrgan(size),
      _ => part == null ? _AnyOrgan() : _DrawnOrgan(part, anatomy, view),
    };
  }

  /// How many times the size the body draws it at the organ really is.
  double get real => 1;

  /// Whether this is the body's own outline of the organ, seen closer: the
  /// two then coincide as the organ's scene takes over from the body's.
  bool get followsBody => false;

  /// Where in the organ its tissue is sampled, at its real size.
  Offset get site => Offset.zero;

  /// A point on the organ for its name's line to land on, at its real
  /// size.
  Offset get named;

  /// Draws the organ at [scale] times its real size; [pixel] is one screen
  /// pixel in the scene's units.
  void paint(Canvas canvas, ZoomInks inks, double pixel, double scale);

  static Color _mix(Color a, Color b, double t) => Color.lerp(a, b, t)!;

  /// A fill lit from the upper left, for a shape in [box].
  static Paint _lit(ZoomInks inks, Rect box) => Paint()
    ..shader =
        RadialGradient(
          colors: <Color>[
            _mix(inks.scale.organ, inks.scale.organEdge, 0.42),
            inks.scale.organ,
            _mix(inks.scale.organ, inks.scale.bodyFill, 0.4),
          ],
          stops: const <double>[0, 0.55, 1],
        ).createShader(
          Rect.fromCircle(
            center: box.topLeft + Offset(box.width * 0.34, box.height * 0.3),
            radius: box.longestSide * 0.85,
          ),
        );

  static Path _closed(List<Offset> points) {
    final Path path = Path();
    for (int i = 0; i < points.length; i++) {
      if (i == 0) {
        path.moveTo(points[i].dx, points[i].dy);
      } else {
        path.lineTo(points[i].dx, points[i].dy);
      }
    }
    return path..close();
  }

  static Offset _unit(double angle) => Offset(math.cos(angle), math.sin(angle));
}

/// The surface an organ's outline is given.
enum _Look { lobules, hollow, fibres, airways, kidney, bone, fat, coils }

_Look _lookOf(OrganKind kind) => switch (kind) {
  OrganKind.adipose => _Look.fat,
  OrganKind.boneMarrow => _Look.bone,
  OrganKind.lung => _Look.airways,
  OrganKind.kidney => _Look.kidney,
  OrganKind.intestine ||
  OrganKind.epididymis ||
  OrganKind.seminalVesicle => _Look.coils,
  OrganKind.skeletalMuscle ||
  OrganKind.heart ||
  OrganKind.smoothMuscle ||
  OrganKind.tongue => _Look.fibres,
  OrganKind.stomach ||
  OrganKind.bladder ||
  OrganKind.gallbladder ||
  OrganKind.uterus ||
  OrganKind.cervix ||
  OrganKind.vagina ||
  OrganKind.fallopianTube ||
  OrganKind.esophagus => _Look.hollow,
  _ => _Look.lobules,
};

/// An organ the anatomogram outlines: its own outline, and beside it the
/// others of its part (the other lung, the other kidney), fainter.
final class _DrawnOrgan extends OrganArt {
  _DrawnOrgan(AnatomyPart part, TissueAnatomy anatomy, double view)
    : real = anatomy.metres / part.extent,
      _look = _lookOf(anatomy.organ) {
    Offset placed(Offset p) => (p - part.centre) * (real / view);
    _points = <Offset>[for (final Offset p in part.followed) placed(p)];
    // The outline's corners are the simplifying's, not the organ's: drawn
    // as a curve through them.
    _shape = Contour(_points).toPath();
    _site = placed(part.site);
    _others = Path();
    for (final List<Offset> other in part.contours.skip(1)) {
      _others.addPath(
        OrganArt._closed(<Offset>[for (final Offset p in other) placed(p)]),
        Offset.zero,
      );
    }
    _box = _shape.getBounds();
    // The body's midline, in the scene: an organ's hilum faces it.
    _midline = placed(Offset(0, part.site.dy)).dx;
    _detail = _surface();
  }

  @override
  final double real;

  @override
  bool get followsBody => true;

  final _Look _look;
  late final Offset _site;

  @override
  Offset get site => _site;

  late final Path _shape;
  late final List<Offset> _points;
  late final Path _others;
  late final Rect _box;
  late final double _midline;

  /// What is stroked over the organ, and what is filled darker in it.
  late final (Path, Path) _detail;

  @override
  Offset get named {
    Offset top = _points.first;
    for (final Offset p in _points) {
      if (p.dy - p.dx * 0.4 < top.dy - top.dx * 0.4) {
        top = p;
      }
    }
    return top;
  }

  Offset get _middle {
    Offset sum = Offset.zero;
    for (final Offset p in _points) {
      sum += p;
    }
    return sum / _points.length.toDouble();
  }

  Path _inset(double share, {Offset? about, double across = 1}) {
    final Offset c = about ?? _middle;
    final bool tall = _box.height >= _box.width;
    return OrganArt._closed(<Offset>[
      for (final Offset p in _points)
        c +
            Offset(
              (p.dx - c.dx) * share * (tall ? across : 1),
              (p.dy - c.dy) * share * (tall ? 1 : across),
            ),
    ]);
  }

  (Path, Path) _surface() {
    final math.Random random = math.Random(_look.index + 11);
    final Path lines = Path();
    final Path dark = Path();
    final double size = _box.longestSide;
    final Offset middle = _middle;
    switch (_look) {
      case _Look.lobules || _Look.fat:
        // Lobules, or lobes of fat: a cobble of rounded shapes.
        final double step = size * (_look == _Look.fat ? 0.1 : 0.15);
        int row = 0;
        for (double y = _box.top; y < _box.bottom + step; y += step * 0.866) {
          for (
            double x = _box.left - (row.isOdd ? step / 2 : 0);
            x < _box.right + step;
            x += step
          ) {
            lines.addOval(
              Rect.fromCircle(
                center:
                    Offset(x, y) +
                    Offset(
                          random.nextDouble() - 0.5,
                          random.nextDouble() - 0.5,
                        ) *
                        (step * 0.3),
                radius: step * (0.4 + 0.1 * random.nextDouble()),
              ),
            );
          }
          row++;
        }
      case _Look.hollow:
        // A wall round a lumen: drawn in [paint], along the outline.
        break;
      case _Look.fibres:
        // Fibres running the organ's length, gathered at its ends.
        final bool tall = _box.height >= _box.width;
        for (double t = 0.04; t < 1; t += 0.045) {
          if (tall) {
            final double x = _box.left + _box.width * t;
            final double pinch = middle.dx + (x - middle.dx) * 0.5;
            lines
              ..moveTo(pinch, _box.top)
              ..quadraticBezierTo(x, middle.dy, pinch, _box.bottom);
          } else {
            final double y = _box.top + _box.height * t;
            final double pinch = middle.dy + (y - middle.dy) * 0.5;
            lines
              ..moveTo(_box.left, pinch)
              ..quadraticBezierTo(middle.dx, y, _box.right, pinch);
          }
        }
      case _Look.airways:
        // The bronchial tree, in from the hilum on the side of the midline.
        final bool hilumLeft = _midline < _box.center.dx;
        final Offset hilum = Offset(
          hilumLeft
              ? _box.left + _box.width * 0.16
              : _box.right - _box.width * 0.16,
          _box.top + _box.height * 0.4,
        );
        void branch(Offset from, double angle, double length, int left) {
          final Offset to = from + OrganArt._unit(angle) * length;
          lines
            ..moveTo(from.dx, from.dy)
            ..lineTo(to.dx, to.dy);
          if (left > 0) {
            final double spread = 0.42 + 0.2 * random.nextDouble();
            branch(to, angle - spread, length * 0.74, left - 1);
            branch(to, angle + spread, length * 0.74, left - 1);
          }
        }

        branch(hilum, hilumLeft ? 0.45 : math.pi - 0.45, size * 0.2, 5);
      case _Look.kidney:
        // The cortex, and the pyramids of the medulla pointing in.
        lines.addPath(_inset(0.8), Offset.zero);
        for (int k = 0; k < 9; k++) {
          final Offset p = _points[_points.length * k ~/ 9];
          final Offset out = Offset.lerp(middle, p, 0.72)!;
          final Offset tip = Offset.lerp(middle, p, 0.36)!;
          final Offset way = (p - middle) / (p - middle).distance;
          final Offset side = Offset(-way.dy, way.dx) * (size * 0.055);
          dark
            ..moveTo(out.dx + side.dx, out.dy + side.dy)
            ..lineTo(out.dx - side.dx, out.dy - side.dy)
            ..lineTo(tip.dx, tip.dy)
            ..close();
        }
      case _Look.bone:
        // The marrow in its cavity, down the middle of the bone.
        dark.addPath(_inset(0.9, across: 0.5), Offset.zero);
      case _Look.coils:
        // Loops lying on one another.
        final double step = size * 0.085;
        int row = 0;
        for (double y = _box.top + step / 2; y < _box.bottom; y += step) {
          lines.moveTo(_box.left, y);
          for (double x = _box.left; x <= _box.right; x += size * 0.02) {
            lines.lineTo(
              x,
              y + math.sin(x / (size * 0.027) + row * 1.7) * step * 0.3,
            );
          }
          row++;
        }
    }
    return (lines, dark);
  }

  @override
  void paint(Canvas canvas, ZoomInks inks, double pixel, double scale) {
    canvas.save();
    canvas.scale(scale);
    final double line = pixel / scale;
    final Color organ = inks.scale.organ;
    final Color edge = inks.scale.organEdge;
    canvas.drawPath(_others, Paint()..color = organ.withValues(alpha: 0.42));
    canvas.drawPath(
      _others,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1 * line
        ..color = edge.withValues(alpha: 0.4),
    );
    final bool bone = _look == _Look.bone;
    if (_look == _Look.hollow) {
      // The lumen, dark, and the wall as a band inside the outline.
      canvas.drawPath(
        _shape,
        Paint()..color = OrganArt._mix(organ, inks.scale.bodyFill, 0.6),
      );
      canvas.save();
      canvas.clipPath(_shape);
      canvas.drawPath(
        _shape,
        OrganArt._lit(inks, _box)
          ..style = PaintingStyle.stroke
          ..strokeJoin = StrokeJoin.round
          ..strokeWidth =
              2 * math.min(_box.shortestSide * 0.2, _box.longestSide * 0.075),
      );
      canvas.restore();
    } else {
      canvas.drawPath(
        _shape,
        bone
            ? (Paint()..color = OrganArt._mix(edge, organ, 0.25))
            : OrganArt._lit(inks, _box),
      );
    }
    canvas.save();
    canvas.clipPath(_shape);
    canvas.drawPath(
      _detail.$2,
      Paint()
        ..color = bone
            ? organ
            : OrganArt._mix(organ, inks.scale.bodyFill, 0.55),
    );
    canvas.drawPath(
      _detail.$1,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1 * line
        ..color = edge.withValues(alpha: 0.34),
    );
    canvas.restore();
    canvas.drawPath(
      _shape,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6 * line
        ..strokeJoin = StrokeJoin.round
        ..color = edge,
    );
    canvas.restore();
  }
}

/// The brain cut down its middle, as the anatomogram draws it, with the
/// part the tissue is lit: the cortex, or the lateral ventricle the choroid
/// plexus lies in.
final class _BrainOrgan extends OrganArt {
  _BrainOrgan(TissueAnatomy anatomy, double view) {
    final AnatomyFigure figure = AnatomyFigure.brain;
    final AnatomyPart lit = figure.parts[anatomy.inBrain]!;
    Offset placed(Offset p) => p / view;
    _site = placed(lit.site);
    Path all(List<List<Offset>> outlines) {
      final Path path = Path();
      for (final List<Offset> outline in outlines) {
        path.addPath(
          OrganArt._closed(<Offset>[for (final Offset p in outline) placed(p)]),
          Offset.zero,
        );
      }
      return path;
    }

    _silhouette = all(<List<Offset>>[figure.silhouette]);
    _lines = all(figure.lines)..fillType = PathFillType.evenOdd;
    _lit = all(lit.contours);
    _rest = <Path>[
      for (final MapEntry<String, AnatomyPart> part in figure.parts.entries)
        if (part.key != anatomy.inBrain) all(part.value.contours),
    ];
    Offset top = placed(lit.followed.first);
    for (final Offset p in lit.followed) {
      if (placed(p).dy < top.dy) {
        top = placed(p);
      }
    }
    _named = top;
  }

  late final Path _silhouette;
  late final Path _lines;
  late final Path _lit;
  late final List<Path> _rest;
  late final Offset _named;
  late final Offset _site;

  @override
  Offset get named => _named;

  @override
  Offset get site => _site;

  @override
  void paint(Canvas canvas, ZoomInks inks, double pixel, double scale) {
    canvas.save();
    canvas.scale(scale);
    final double line = pixel / scale;
    canvas.drawPath(_silhouette, Paint()..color = inks.scale.bodyFill);
    for (final Path part in _rest) {
      canvas.drawPath(
        part,
        Paint()..color = inks.scale.organ.withValues(alpha: 0.34),
      );
    }
    canvas.drawPath(_lit, OrganArt._lit(inks, _lit.getBounds()));
    canvas.drawPath(
      _lines,
      Paint()..color = inks.scale.bodyEdge.withValues(alpha: 0.75),
    );
    canvas.drawPath(
      _lit,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6 * line
        ..strokeJoin = StrokeJoin.round
        ..color = inks.scale.organEdge,
    );
    canvas.restore();
  }
}

/// A lymph node: a bean in its capsule, follicles round its cortex, the
/// cords of its medulla at the hilum, vessels in and out. The tissue is
/// sampled under the capsule, at the top.
final class _NodeOrgan extends OrganArt {
  _NodeOrgan(this.size);

  /// How long the node is, in the scene's units.
  final double size;

  Offset get _centre => Offset.zero;

  @override
  Offset get site => Offset(0, -size * 0.34);

  late final List<Offset> _bean = <Offset>[
    for (int i = 0; i < 96; i++)
      () {
        final double a = 2 * math.pi * i / 96;
        // Drawn in at the hilum, below.
        final double from = math.atan2(
          math.sin(a - math.pi / 2),
          math.cos(a - math.pi / 2),
        );
        final double r = 1 - 0.26 * math.exp(-from * from / 0.16);
        return _centre +
            Offset(math.cos(a) * size * 0.5 * r, math.sin(a) * size * 0.4 * r);
      }(),
  ];

  @override
  Offset get named => _centre + Offset(size * 0.3, -size * 0.3);

  @override
  void paint(Canvas canvas, ZoomInks inks, double pixel, double scale) {
    canvas.save();
    canvas.scale(scale);
    final double line = pixel / scale;
    final Color organ = inks.scale.organ;
    final Color edge = inks.scale.organEdge;
    final Path bean = OrganArt._closed(_bean);
    final Paint vessel = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2 * line
      ..strokeCap = StrokeCap.round
      ..color = edge.withValues(alpha: 0.7);
    // Lymph comes in through the capsule all round, and leaves at the hilum.
    for (final double a in <double>[-2.6, -2.0, -1.2, -0.5, 0.3, 3.4]) {
      final Offset at =
          _centre + Offset(math.cos(a) * size * 0.5, math.sin(a) * size * 0.4);
      canvas.drawLine(at, at + OrganArt._unit(a) * (size * 0.16), vessel);
    }
    canvas.drawLine(
      _centre + Offset(0, size * 0.28),
      _centre + Offset(size * 0.04, size * 0.52),
      vessel..strokeWidth = 3.4 * line,
    );
    canvas.drawPath(bean, OrganArt._lit(inks, bean.getBounds()));
    canvas.save();
    canvas.clipPath(bean);
    // The medulla, darker, and its cords.
    canvas.drawOval(
      Rect.fromCenter(
        center: _centre + Offset(0, size * 0.14),
        width: size * 0.5,
        height: size * 0.36,
      ),
      Paint()..color = OrganArt._mix(organ, inks.scale.bodyFill, 0.4),
    );
    final Paint cord = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1 * line
      ..color = edge.withValues(alpha: 0.4);
    for (int k = 0; k < 7; k++) {
      final double a = math.pi * (1.15 + 0.12 * k);
      final Offset from = _centre + Offset(0, size * 0.24);
      final Offset to =
          _centre +
          Offset(math.cos(a) * size * 0.22, math.sin(a) * size * 0.16);
      canvas.drawLine(from, to, cord);
    }
    // Follicles in the cortex, each with its pale centre.
    for (int k = 0; k < 9; k++) {
      final double a = math.pi * (0.92 + 0.145 * k);
      final Offset at =
          _centre +
          Offset(math.cos(a) * size * 0.37, math.sin(a) * size * 0.28);
      canvas.drawCircle(
        at,
        size * 0.062,
        Paint()..color = OrganArt._mix(organ, inks.scale.bodyFill, 0.35),
      );
      canvas.drawCircle(
        at,
        size * 0.034,
        Paint()..color = OrganArt._mix(organ, edge, 0.55),
      );
    }
    canvas.restore();
    canvas.drawPath(
      bean,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2 * line
        ..color = edge,
    );
    canvas.restore();
  }
}

/// A length of artery with a branch: its wall, and the blood in its lumen.
/// The tissue is sampled in the wall.
final class _VesselOrgan extends OrganArt {
  _VesselOrgan(this.size);

  final double size;

  @override
  Offset get named => Offset(size * 0.3, -size * 0.02);

  Path _tube(List<Offset> spine, double half) {
    final List<Offset> left = <Offset>[];
    final List<Offset> right = <Offset>[];
    for (int i = 0; i < spine.length; i++) {
      final Offset run =
          spine[math.min(i + 1, spine.length - 1)] - spine[math.max(i - 1, 0)];
      final Offset side = Offset(-run.dy, run.dx) / run.distance * half;
      left.add(spine[i] + side);
      right.add(spine[i] - side);
    }
    return OrganArt._closed(<Offset>[...left, ...right.reversed]);
  }

  @override
  void paint(Canvas canvas, ZoomInks inks, double pixel, double scale) {
    canvas.save();
    canvas.scale(scale);
    final double line = pixel / scale;
    final double wall = size * 0.115;
    // The upper edge of the wall passes just above the origin.
    final List<Offset> trunk = <Offset>[
      for (int i = 0; i <= 40; i++)
        Offset(
          size * (-1 + 2 * i / 40),
          wall * 0.72 + size * 0.05 * math.sin(i / 40 * math.pi * 1.2 + 0.6),
        ),
    ];
    final Offset fork = trunk[26];
    final List<Offset> branch = <Offset>[
      for (int i = 0; i <= 20; i++)
        fork +
            Offset(
              size * 0.9 * i / 20,
              size * (0.03 * i / 20 + 0.5 * math.pow(i / 20, 1.5)),
            ),
    ];
    final Paint flesh = Paint()..color = inks.scale.organ;
    final Paint blood = Paint()
      ..color = OrganArt._mix(inks.scale.redCell, inks.scale.bodyFill, 0.35);
    final Paint rim = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4 * line
      ..color = inks.scale.organEdge;
    canvas.drawPath(_tube(branch, wall * 0.62), flesh);
    canvas.drawPath(_tube(branch, wall * 0.62), rim);
    canvas.drawPath(_tube(trunk, wall), flesh);
    canvas.drawPath(_tube(trunk, wall), rim);
    canvas.drawPath(_tube(branch, wall * 0.36), blood);
    canvas.drawPath(_tube(trunk, wall * 0.62), blood);
    canvas.restore();
  }
}

/// A block cut from the skin: its surface with its creases and hairs, and
/// on the cut face the epidermis, the dermis and the fat beneath. The
/// tissue is sampled at the top of the cut face.
final class _SkinOrgan extends OrganArt {
  _SkinOrgan(this.size);

  final double size;

  // The block's middle is at the origin; it is drawn about the place it is
  // sampled.
  @override
  Offset get site => Offset(-size * 0.04, -size * 0.13);

  @override
  Offset get named => site + Offset(size * 0.36, size * 0.02);

  @override
  void paint(Canvas canvas, ZoomInks inks, double pixel, double scale) {
    canvas.save();
    canvas.scale(scale);
    canvas.translate(site.dx, site.dy);
    final double line = pixel / scale;
    final Color organ = inks.scale.organ;
    final Color edge = inks.scale.organEdge;
    final double s = size;
    // The cut face, its top edge just above the origin.
    final Rect face = Rect.fromLTRB(-s * 0.45, -s * 0.03, s * 0.55, s * 0.6);
    final Offset back = Offset(-s * 0.22, -s * 0.34);
    final Path top = OrganArt._closed(<Offset>[
      face.topLeft,
      face.topRight,
      face.topRight + back,
      face.topLeft + back,
    ]);
    final Path side = OrganArt._closed(<Offset>[
      face.topLeft,
      face.topLeft + back,
      face.bottomLeft + back,
      face.bottomLeft,
    ]);
    canvas.drawPath(
      side,
      Paint()..color = OrganArt._mix(organ, inks.scale.bodyFill, 0.5),
    );
    canvas.drawPath(top, Paint()..color = OrganArt._mix(organ, edge, 0.45));
    // Creases across the surface, and hairs out of it.
    final Paint fine = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1 * line
      ..color = edge.withValues(alpha: 0.5);
    for (int k = 1; k < 7; k++) {
      final Offset from = Offset.lerp(face.topLeft, face.topRight, k / 7)!;
      canvas.drawLine(from, from + back, fine);
    }
    for (final double t in <double>[0.18, 0.44, 0.7, 0.9]) {
      final Offset root =
          Offset.lerp(face.topLeft, face.topRight, t)! + back * 0.5;
      canvas.drawLine(
        root,
        root + Offset(-s * 0.05, -s * 0.2),
        fine
          ..strokeWidth = 1.6 * line
          ..color = edge,
      );
    }
    // The layers.
    final double epidermis = face.top + s * 0.035;
    final double dermis = face.top + s * 0.25;
    canvas.drawRect(face, Paint()..color = organ);
    canvas.drawRect(
      Rect.fromLTRB(face.left, dermis, face.right, face.bottom),
      Paint()..color = OrganArt._mix(organ, edge, 0.5),
    );
    final Path wavy = Path()..moveTo(face.left, face.top);
    for (int i = 0; i <= 60; i++) {
      wavy.lineTo(
        face.left + face.width * i / 60,
        epidermis + s * 0.012 * math.sin(i * 0.9),
      );
    }
    wavy
      ..lineTo(face.right, face.top)
      ..close();
    canvas.drawPath(
      wavy,
      Paint()..color = OrganArt._mix(organ, inks.scale.bodyFill, 0.45),
    );
    canvas.save();
    canvas.clipRect(Rect.fromLTRB(face.left, dermis, face.right, face.bottom));
    final double lobe = s * 0.085;
    int row = 0;
    for (
      double y = dermis + lobe * 0.3;
      y < face.bottom + lobe;
      y += lobe * 0.9
    ) {
      for (
        double x = face.left + (row.isOdd ? lobe / 2 : 0);
        x < face.right + lobe;
        x += lobe
      ) {
        canvas.drawCircle(Offset(x, y), lobe * 0.46, fine..strokeWidth = line);
      }
      row++;
    }
    canvas.restore();
    final Paint rim = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5 * line
      ..strokeJoin = StrokeJoin.round
      ..color = edge;
    canvas.drawRect(face, rim);
    canvas.drawPath(top, rim);
    canvas.drawPath(side, rim);
    canvas.restore();
  }
}

/// A parathyroid gland: a small oval lying on the back of the thyroid.
final class _ParathyroidOrgan extends OrganArt {
  _ParathyroidOrgan(this.size);

  final double size;

  @override
  Offset get named => Offset(size * 0.3, -size * 0.26);

  @override
  void paint(Canvas canvas, ZoomInks inks, double pixel, double scale) {
    canvas.save();
    canvas.scale(scale);
    final double line = pixel / scale;
    final Color organ = inks.scale.organ;
    final Color edge = inks.scale.organEdge;
    // The thyroid behind it, ten times its size: only its surface shows.
    canvas.drawCircle(
      Offset(-size * 2.6, size * 0.6),
      size * 3.1,
      Paint()..color = OrganArt._mix(organ, inks.scale.bodyFill, 0.55),
    );
    canvas.drawCircle(
      Offset(-size * 2.6, size * 0.6),
      size * 3.1,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2 * line
        ..color = edge.withValues(alpha: 0.5),
    );
    final Rect gland = Rect.fromCenter(
      center: Offset.zero,
      width: size,
      height: size * 0.68,
    );
    // The artery that feeds it.
    canvas.drawLine(
      Offset(size * 0.3, size * 0.2),
      Offset(size * 1.1, size * 0.8),
      Paint()
        ..strokeWidth = 3 * line
        ..strokeCap = StrokeCap.round
        ..color = OrganArt._mix(inks.scale.redCell, inks.scale.bodyFill, 0.3),
    );
    final Path oval = Path()..addOval(gland);
    canvas.drawPath(oval, OrganArt._lit(inks, gland));
    canvas.save();
    canvas.clipPath(oval);
    final Paint fine = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = line
      ..color = edge.withValues(alpha: 0.34);
    final double step = size * 0.15;
    int row = 0;
    for (double y = gland.top; y < gland.bottom + step; y += step * 0.866) {
      for (
        double x = gland.left - (row.isOdd ? step / 2 : 0);
        x < gland.right + step;
        x += step
      ) {
        canvas.drawCircle(Offset(x, y), step * 0.45, fine);
      }
      row++;
    }
    canvas.restore();
    canvas.drawPath(
      oval,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6 * line
        ..color = edge,
    );
    canvas.restore();
  }
}

/// The eye cut level, the cornea to the left: the lens and iris, the
/// sclera, and lining the back of it the retina, lit. The tissue is sampled
/// at the back of the eye.
final class _EyeOrgan extends OrganArt {
  _EyeOrgan(this.size);

  /// The eye's diameter, in the scene's units.
  final double size;

  // The eye's middle is near the origin; it is drawn about the back of the
  // eye, where it is sampled.
  @override
  Offset get site => Offset(size * 0.42, 0);

  @override
  Offset get named => site + Offset(-size * 0.12, -size * 0.34);

  @override
  void paint(Canvas canvas, ZoomInks inks, double pixel, double scale) {
    canvas.save();
    canvas.scale(scale);
    canvas.translate(site.dx, site.dy);
    final double line = pixel / scale;
    final Color organ = inks.scale.organ;
    final Color edge = inks.scale.organEdge;
    final double r = size / 2;
    // The retina at the back of the eye lies on the origin.
    final Offset centre = Offset(-r * 0.93, 0);
    final Rect globe = Rect.fromCircle(center: centre, radius: r);
    // The optic nerve, leaving the back of the eye.
    canvas.drawLine(
      centre + OrganArt._unit(0.22) * r,
      centre + OrganArt._unit(0.3) * (r * 1.7),
      Paint()
        ..strokeWidth = r * 0.24
        ..color = OrganArt._mix(organ, inks.scale.bodyFill, 0.3),
    );
    // The cornea, bulging forward of the globe.
    final Rect cornea = Rect.fromCircle(
      center: centre + Offset(-r * 0.56, 0),
      radius: r * 0.62,
    );
    canvas.drawOval(cornea, Paint()..color = inks.scale.bodyFill);
    canvas.drawOval(
      cornea,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5 * line
        ..color = edge.withValues(alpha: 0.8),
    );
    canvas.drawOval(globe, Paint()..color = inks.scale.bodyFill);
    // The retina, lining the back two thirds.
    canvas.drawArc(
      Rect.fromCircle(center: centre, radius: r * 0.93),
      -2.15,
      4.3,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.085
        ..color = OrganArt._mix(organ, edge, 0.3),
    );
    // The lens, hung behind the iris.
    final Offset lens = centre + Offset(-r * 0.66, 0);
    canvas.drawOval(
      Rect.fromCenter(center: lens, width: r * 0.36, height: r * 0.8),
      Paint()..color = OrganArt._mix(organ, edge, 0.75).withValues(alpha: 0.5),
    );
    final Paint iris = Paint()
      ..strokeWidth = 2.6 * line
      ..strokeCap = StrokeCap.round
      ..color = edge;
    for (final double side in <double>[-1, 1]) {
      canvas.drawLine(
        centre + Offset(-r * 0.74, side * r * 0.66),
        lens + Offset(-r * 0.12, side * r * 0.24),
        iris,
      );
    }
    canvas.drawOval(
      globe,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4 * line
        ..color = edge,
    );
    canvas.restore();
  }
}

/// No tissue stands out for the gene: an organ, any.
final class _AnyOrgan extends OrganArt {
  late final Path _shape = () {
    final Path shape = Path();
    const int points = 90;
    for (int i = 0; i <= points; i++) {
      final double a = 2 * math.pi * i / points;
      final double r =
          0.3 +
          0.035 * math.sin(3 * a + 0.4) +
          0.02 * math.sin(5 * a + 1.3) +
          0.012 * math.sin(9 * a);
      final Offset p = Offset(r * math.cos(a) * 1.15, r * math.sin(a) * 0.85);
      if (i == 0) {
        shape.moveTo(p.dx, p.dy);
      } else {
        shape.lineTo(p.dx, p.dy);
      }
    }
    return shape..close();
  }();

  @override
  Offset get named => const Offset(0, -0.27);

  @override
  void paint(Canvas canvas, ZoomInks inks, double pixel, double scale) {
    canvas.save();
    canvas.scale(scale);
    canvas.drawPath(_shape, OrganArt._lit(inks, _shape.getBounds()));
    canvas.drawPath(
      _shape,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6 * pixel / scale
        ..color = inks.scale.organEdge,
    );
    canvas.restore();
  }
}
