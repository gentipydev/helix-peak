import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/anatomy_figure.dart';
import '../../domain/anatomy_tables.dart';
import '../../domain/cell_archetypes.dart';
import '../../domain/zoom_depth.dart';
import '../zoom_inks.dart';
import 'contour.dart';
import 'sculpt.dart';
import 'zoom_subject.dart';

/// An organ as its own scene draws it: in the scene's units, at its real
/// size, its middle at the origin, and where in it its tissue is sampled
/// ([site]).
///
/// Most organs are the anatomogram's own outline for them, the one the body
/// drew, sculpted in the app's neutrals and given what lies inside them for
/// the kind of organ each is. The anatomogram is a diagram and draws many
/// of them smaller than they are, so each knows how many times its drawn
/// size it really is ([real]): the scene grows it to that on the way in. A
/// few have no outline of their own there, or none that shows the tissue (a
/// lymph node, a vessel, the skin, a parathyroid gland, the retina), and are
/// drawn from general anatomy. The brain is the anatomogram's brain cut down
/// its middle.
///
/// Where the gene is, the organ glows in the mark: the part of it the
/// zoom's cell lives in (the islets of a pancreas for an endocrine cell, its
/// ducts for a duct cell), by the kind of organ and of cell, never by gene.
abstract class OrganArt {
  OrganArt();

  factory OrganArt.of(ZoomSubject subject) => OrganArt.forTissue(
    subject.anatomy,
    subject.bodyPart,
    subject.depth.widthOf(ZoomStop.organ),
    figure: subject.body,
    shape: subject.depth.archetype.shape,
    level: subject.followedLevel,
  );

  /// The organ a tissue drawn as [anatomy] is in, where the body draws it
  /// as [part] of [figure] and the scene's unit is [view] metres, about a
  /// cell of [shape]. [level] is how strongly the body lit it.
  factory OrganArt.forTissue(
    TissueAnatomy? anatomy,
    AnatomyPart? part,
    double view, {
    AnatomyFigure? figure,
    CellShape shape = CellShape.epithelial,
    double level = 1,
  }) {
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
      _ =>
        part == null
            ? _AnyOrgan()
            : _DrawnOrgan(
                part,
                anatomy,
                view,
                figure: figure,
                shape: shape,
                level: level,
              ),
    };
  }

  /// How many times the size the body draws it at the organ really is.
  double get real => 1;

  /// Whether this is the body's own outline of the organ, seen closer: the
  /// two then coincide as the organ's scene takes over from the body's.
  bool get followsBody => false;

  /// Where in the organ its tissue is sampled, at its real size.
  Offset get site => Offset.zero;

  /// Draws the organ at [scale] times its real size; [pixel] is one screen
  /// pixel in the scene's units. [detail], from 0 to 1, is how far it has
  /// become the organ from the body's drawing of it: at 0 the flat shape,
  /// lit in the mark, that the body hands over; at 1 the organ sculpted,
  /// with what lies inside it.
  void paint(
    Canvas canvas,
    ZoomInks inks,
    double pixel,
    double scale, {
    double detail = 1,
  });

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

  /// A shape sculpted: its shadow on the ground, its body lit from the
  /// upper left, its edge and the light on it, at [detail] of the way from
  /// the flat shape the body drew.
  static void _sculpted(
    Canvas canvas,
    Path shape,
    Rect box,
    ZoomInks inks,
    double line,
    double detail, {
    double light = 0.3,
  }) {
    if (detail > 0) {
      Sculpt.shadowUnder(canvas, box, inks, strength: 0.55 * detail);
    }
    canvas.drawPath(shape, Paint()..color = inks.lit(0.14));
    if (detail > 0) {
      canvas.drawPath(
        shape,
        Paint()..shader = Sculpt.body(box, inks, light: light, opacity: detail),
      );
    }
  }

  static void _edged(
    Canvas canvas,
    Path shape,
    Rect box,
    ZoomInks inks,
    double line,
    double detail,
  ) {
    canvas.drawPath(
      shape,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1 * line
        ..strokeJoin = StrokeJoin.round
        ..color = inks.lit(0.42).withValues(alpha: 0.55 + 0.4 * detail),
    );
    if (detail > 0) {
      Sculpt.rim(
        canvas,
        shape,
        box,
        inks,
        width: 1.8 * line,
        strength: 0.5 * detail,
      );
    }
  }
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

/// What lies inside an organ of one kind, and the part of it the zoom's
/// cell lives in, in the mark.
abstract class _Study {
  /// Draws inside the organ's outline, already clipped to it.
  void inside(Canvas canvas, ZoomInks inks, double line, double detail);
}

/// Parts of the figure never drawn round an organ: the skin is the figure
/// itself, and fat lies over everything.
const Set<String> _notAround = <String>{'UBERON_0000014', 'UBERON_0001013'};

/// An organ the anatomogram outlines: its own outline, sculpted, the others
/// of its part beside it (the other lung, the other kidney), and the
/// figure's parts round it, faint, as the body drew them.
final class _DrawnOrgan extends OrganArt {
  _DrawnOrgan(
    AnatomyPart part,
    TissueAnatomy anatomy,
    double view, {
    AnatomyFigure? figure,
    CellShape shape = CellShape.epithelial,
    this.level = 1,
  }) : real = anatomy.metres / part.extent,
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
    _study = anatomy.organ == OrganKind.pancreas
        ? _Pancreas(_shape, _points, _box, _site, shape)
        : null;
    _detail = _surface();
    // Round it, what the figure draws there: as far out as the view
    // reaches, and a little beyond for the way in.
    _around = Path();
    if (figure != null) {
      final Rect reach = Rect.fromCenter(
        center: Offset.zero,
        width: 1.6,
        height: 2.6,
      );
      for (final MapEntry<String, AnatomyPart> other in figure.parts.entries) {
        if (_notAround.contains(other.key) || identical(other.value, part)) {
          continue;
        }
        for (final List<Offset> contour in other.value.contours) {
          final Path path = OrganArt._closed(<Offset>[
            for (final Offset p in contour) placed(p),
          ]);
          if (path.getBounds().overlaps(reach)) {
            _around.addPath(path, Offset.zero);
          }
        }
      }
    }
  }

  @override
  final double real;

  /// How strongly the body lit the organ: the mark it is handed over in.
  final double level;

  @override
  bool get followsBody => true;

  final _Look _look;
  late final Offset _site;

  @override
  Offset get site => _site;

  late final Path _shape;
  late final List<Offset> _points;
  late final Path _others;
  late final Path _around;
  late final Rect _box;
  late final double _midline;
  late final _Study? _study;

  /// What is stroked over the organ, and what is filled darker in it.
  late final (Path, Path) _detail;

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
        // Lobules, or lobes of fat: a cobble of rounded shapes. A study of
        // its own draws them as domes.
        if (_study == null) {
          for (final Rect lobule in Sculpt.cobble(
            _box,
            size * (_look == _Look.fat ? 0.1 : 0.15),
            random,
          )) {
            lines.addOval(lobule);
          }
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
        for (final Path generation in Sculpt.tree(
          hilum,
          hilumLeft ? 0.45 : math.pi - 0.45,
          size * 0.2,
          5,
          random,
          spread: 0.5,
          shrink: 0.74,
        )) {
          lines.addPath(generation, Offset.zero);
        }
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
  void paint(
    Canvas canvas,
    ZoomInks inks,
    double pixel,
    double scale, {
    double detail = 1,
  }) {
    canvas.save();
    canvas.scale(scale);
    final double line = pixel / scale;
    // Round it, the figure's parts, as the body drew them, fading out with
    // their distance from the organ once it is its own: the organ in its
    // place, not a map.
    final double near = _box.longestSide * (1.6 - 0.75 * detail);
    final Rect fade = Rect.fromCircle(center: _box.center, radius: near);
    Paint around(Color colour, double alpha) =>
        Paint()
          ..shader = RadialGradient(
            colors: <Color>[
              colour.withValues(alpha: alpha),
              colour.withValues(alpha: alpha * 0.5),
              colour.withValues(alpha: 0),
            ],
            stops: const <double>[0, 0.55, 1],
          ).createShader(fade);
    canvas.drawPath(_around, around(inks.lit(0.14), 0.42 * (1 - 0.6 * detail)));
    canvas.drawPath(
      _around,
      around(inks.lit(0.32), 0.45 * (1 - 0.3 * detail))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8 * line,
    );
    canvas.drawPath(_others, Paint()..color = inks.lit(0.16));
    canvas.drawPath(
      _others,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.9 * line
        ..color = inks.lit(0.36).withValues(alpha: 0.6),
    );
    final bool hollow = _look == _Look.hollow;
    final bool bone = _look == _Look.bone;
    OrganArt._sculpted(
      canvas,
      _shape,
      _box,
      inks,
      line,
      detail,
      light: bone ? 0.42 : 0.3,
    );
    // The mark the body handed it over in, giving way as it becomes the
    // organ and the gene's place in it comes up.
    final double handed = (1 - detail) * (0.2 + 0.55 * level);
    if (handed > 0.002) {
      canvas.drawPath(_shape, Paint()..color = inks.glow(handed));
    }
    canvas.save();
    canvas.clipPath(_shape);
    if (hollow && detail > 0) {
      // The lumen in shade, and the wall as a lit band inside the outline.
      canvas.drawPath(
        _inset(0.72, across: 0.55),
        Paint()..color = inks.shade(0.45).withValues(alpha: detail),
      );
    }
    if (detail > 0) {
      canvas.drawPath(
        _detail.$2,
        Paint()
          ..color = (bone ? inks.shade(0.6) : inks.shade(0.5)).withValues(
            alpha: 0.8 * detail,
          ),
      );
      canvas.drawPath(
        _detail.$1,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1 * line
          ..color = inks.lit(0.5).withValues(alpha: 0.22 * detail),
      );
      _study?.inside(canvas, inks, line, detail);
    }
    canvas.restore();
    OrganArt._edged(canvas, _shape, _box, inks, line, detail);
    if (handed > 0.002) {
      canvas.drawPath(
        _shape,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.1 * line
          ..strokeJoin = StrokeJoin.round
          ..color = inks.glow((1 - detail) * (0.5 + 0.5 * level)),
      );
    }
    canvas.restore();
  }
}

/// The pancreas: its lobules, and its main duct running from the tail to
/// the head. Where the zoom's cell lives glows: the islets scattered
/// through it, more of them toward the tail, for an endocrine cell; the
/// duct tree for a duct cell; the acini, the gland itself, for any other.
/// An islet, or a branch of the ducts, lies at the place it is sampled.
final class _Pancreas implements _Study {
  _Pancreas(this.shape, this.points, this.box, this.site, this.cell) {
    final math.Random random = math.Random(7);
    final double size = box.longestSide;
    _lobules = <Rect>[
      for (final Rect lobule in Sculpt.cobble(box, size * 0.055, random))
        if (shape.contains(lobule.center)) lobule,
    ];
    _duct = _centreline();
    _branches = Path();
    for (int k = 1; k < 9; k++) {
      final double t = k / 9;
      final Offset at = _along(t);
      final Offset ahead = _along(math.min(1, t + 0.02));
      final double heading = math.atan2(ahead.dy - at.dy, ahead.dx - at.dx);
      for (final double side in <double>[-1, 1]) {
        for (final Path generation in Sculpt.tree(
          at,
          heading + side * (1.0 + 0.3 * random.nextDouble()),
          size * 0.05,
          2,
          random,
          spread: 0.6,
          shrink: 0.7,
        )) {
          _branches.addPath(generation, Offset.zero);
        }
      }
    }
    // A branch reaching the place it is sampled.
    final Offset near = _nearestOnDuct(site);
    _branches
      ..moveTo(near.dx, near.dy)
      ..quadraticBezierTo(
        (near.dx + site.dx) / 2 + size * 0.01,
        (near.dy + site.dy) / 2,
        site.dx,
        site.dy,
      );
    // Islets: a million in a pancreas, drawn as a few dozen, more toward
    // the tail, where they are more.
    _islets = <(Offset, double)>[(site, size * 0.016)];
    int tries = 0;
    while (_islets.length < 46 && tries < 4000) {
      tries++;
      final Offset p = Offset(
        box.left + random.nextDouble() * box.width,
        box.top + random.nextDouble() * box.height,
      );
      final double tail = (p.dx - box.left) / box.width;
      if (!shape.contains(p) || random.nextDouble() > 0.45 + 0.55 * tail) {
        continue;
      }
      if (_islets.any(
        ((Offset, double) i) => (i.$1 - p).distance < size * 0.03,
      )) {
        continue;
      }
      _islets.add((p, size * (0.006 + 0.008 * random.nextDouble())));
    }
  }

  final Path shape;
  final List<Offset> points;
  final Rect box;
  final Offset site;
  final CellShape cell;

  late final List<Rect> _lobules;
  late final List<Offset> _duct;
  late final Path _branches;
  late final List<(Offset, double)> _islets;

  /// The main duct: the organ's middle line from one end to the other, the
  /// middle of each slice across it, smoothed.
  List<Offset> _centreline() {
    const int slices = 40;
    final List<Offset> raw = <Offset>[];
    for (int i = 1; i < slices; i++) {
      final double x = box.left + box.width * i / slices;
      double top = double.infinity;
      double bottom = double.negativeInfinity;
      for (int j = 0; j < points.length; j++) {
        final Offset a = points[j];
        final Offset b = points[(j + 1) % points.length];
        if ((a.dx - x) * (b.dx - x) > 0 || a.dx == b.dx) {
          continue;
        }
        final double y = a.dy + (b.dy - a.dy) * (x - a.dx) / (b.dx - a.dx);
        top = math.min(top, y);
        bottom = math.max(bottom, y);
      }
      if (top.isFinite && bottom.isFinite) {
        raw.add(Offset(x, (top + bottom) / 2));
      }
    }
    return <Offset>[
      for (int i = 0; i < raw.length; i++)
        () {
          Offset sum = Offset.zero;
          int n = 0;
          for (
            int k = math.max(0, i - 2);
            k <= math.min(raw.length - 1, i + 2);
            k++
          ) {
            sum += raw[k];
            n++;
          }
          return sum / n.toDouble();
        }(),
    ];
  }

  Offset _along(double t) {
    final double x = t * (_duct.length - 1);
    final int i = x.floor().clamp(0, _duct.length - 2);
    return Offset.lerp(_duct[i], _duct[i + 1], x - i)!;
  }

  Offset _nearestOnDuct(Offset p) {
    Offset best = _duct.first;
    for (final Offset q in _duct) {
      if ((q - p).distance < (best - p).distance) {
        best = q;
      }
    }
    return best;
  }

  Path get _ductPath {
    final Path path = Path()..moveTo(_duct.first.dx, _duct.first.dy);
    for (final Offset p in _duct.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    return path;
  }

  @override
  void inside(Canvas canvas, ZoomInks inks, double line, double detail) {
    final bool acini =
        cell != CellShape.endocrine && cell != CellShape.epithelial;
    for (final Rect lobule in _lobules) {
      Sculpt.dome(canvas, lobule, inks, 0.38 * detail);
      if (acini) {
        canvas.drawOval(
          lobule.deflate(lobule.width * 0.12),
          Paint()..color = inks.glow(0.22 * detail),
        );
      }
    }
    final Path duct = _ductPath;
    if (cell == CellShape.epithelial) {
      Sculpt.glowingStroke(
        canvas,
        _branches,
        inks,
        width: 1.1 * line,
        alpha: detail,
      );
      Sculpt.glowingStroke(
        canvas,
        duct,
        inks,
        width: 2.4 * line,
        alpha: detail,
      );
      return;
    }
    final Paint ductPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(
      _branches,
      ductPaint
        ..strokeWidth = 1 * line
        ..color = inks.lit(0.55).withValues(alpha: 0.35 * detail),
    );
    canvas.drawPath(
      duct,
      ductPaint
        ..strokeWidth = 2.6 * line
        ..color = inks.lit(0.6).withValues(alpha: 0.55 * detail),
    );
    if (cell == CellShape.endocrine) {
      for (final (Offset at, double r) in _islets) {
        Sculpt.glow(canvas, at, r * 3.2, inks, 0.42 * detail);
        canvas.drawCircle(at, r, Paint()..color = inks.glow(0.95 * detail));
      }
    }
  }
}

/// The brain cut down its middle, as the anatomogram draws it, sculpted,
/// with the part the tissue is in glowing: the cortex, or the lateral
/// ventricle the choroid plexus lies in.
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
    _box = _silhouette.getBounds();
  }

  late final Path _silhouette;
  late final Path _lines;
  late final Path _lit;
  late final List<Path> _rest;
  late final Offset _site;
  late final Rect _box;

  @override
  Offset get site => _site;

  @override
  void paint(
    Canvas canvas,
    ZoomInks inks,
    double pixel,
    double scale, {
    double detail = 1,
  }) {
    canvas.save();
    canvas.scale(scale);
    final double line = pixel / scale;
    OrganArt._sculpted(canvas, _silhouette, _box, inks, line, 1);
    for (final Path part in _rest) {
      canvas.drawPath(
        part,
        Paint()..color = inks.shade(0.62).withValues(alpha: 0.55),
      );
      canvas.drawPath(
        part,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.9 * line
          ..color = inks.lit(0.34).withValues(alpha: 0.5),
      );
    }
    canvas.drawPath(
      _lines,
      Paint()..color = inks.label.withValues(alpha: 0.32),
    );
    final Rect litBox = _lit.getBounds();
    Sculpt.glow(canvas, litBox.center, litBox.longestSide * 0.8, inks, 0.22);
    canvas.drawPath(_lit, Paint()..color = inks.glow(0.42));
    Sculpt.glowingStroke(canvas, _lit, inks, width: 1.4 * line);
    OrganArt._edged(canvas, _silhouette, _box, inks, line, 1);
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
  void paint(
    Canvas canvas,
    ZoomInks inks,
    double pixel,
    double scale, {
    double detail = 1,
  }) {
    canvas.save();
    canvas.scale(scale);
    final double line = pixel / scale;
    final Path bean = OrganArt._closed(_bean);
    final Rect box = bean.getBounds();
    final Paint vessel = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2 * line
      ..strokeCap = StrokeCap.round
      ..color = inks.lit(0.42).withValues(alpha: 0.7);
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
    OrganArt._sculpted(canvas, bean, box, inks, line, 1);
    canvas.save();
    canvas.clipPath(bean);
    // The medulla, darker, and its cords.
    canvas.drawOval(
      Rect.fromCenter(
        center: _centre + Offset(0, size * 0.14),
        width: size * 0.5,
        height: size * 0.36,
      ),
      Paint()..color = inks.shade(0.55),
    );
    final Paint cord = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1 * line
      ..color = inks.lit(0.5).withValues(alpha: 0.3);
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
      Sculpt.dome(
        canvas,
        Rect.fromCircle(center: at, radius: size * 0.062),
        inks,
        0.4,
      );
      canvas.drawCircle(
        at,
        size * 0.03,
        Paint()..color = inks.lit(0.45).withValues(alpha: 0.6),
      );
    }
    canvas.restore();
    OrganArt._edged(canvas, bean, box, inks, line, 1);
    canvas.restore();
  }
}

/// A length of artery with a branch: its wall, and the blood in its lumen.
/// The tissue is sampled in the wall.
final class _VesselOrgan extends OrganArt {
  _VesselOrgan(this.size);

  final double size;

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
  void paint(
    Canvas canvas,
    ZoomInks inks,
    double pixel,
    double scale, {
    double detail = 1,
  }) {
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
    final Paint blood = Paint()
      ..color = Color.lerp(inks.blood, inks.ground, 0.35)!;
    for (final (List<Offset> spine, double half) in <(List<Offset>, double)>[
      (branch, wall * 0.62),
      (trunk, wall),
    ]) {
      final Path tube = _tube(spine, half);
      OrganArt._sculpted(canvas, tube, tube.getBounds(), inks, line, 1);
      OrganArt._edged(canvas, tube, tube.getBounds(), inks, line, 1);
    }
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
  void paint(
    Canvas canvas,
    ZoomInks inks,
    double pixel,
    double scale, {
    double detail = 1,
  }) {
    canvas.save();
    canvas.scale(scale);
    canvas.translate(site.dx, site.dy);
    final double line = pixel / scale;
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
    Sculpt.shadowUnder(canvas, face.inflate(s * 0.05), inks);
    canvas.drawPath(side, Paint()..color = inks.shade(0.62));
    canvas.drawPath(top, Paint()..color = inks.lit(0.32));
    // Creases across the surface, and hairs out of it.
    final Paint fine = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1 * line
      ..color = inks.lit(0.55).withValues(alpha: 0.4);
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
        Paint()
          ..strokeWidth = 1.6 * line
          ..strokeCap = StrokeCap.round
          ..color = inks.lit(0.5),
      );
    }
    // The layers.
    final double epidermis = face.top + s * 0.035;
    final double dermis = face.top + s * 0.25;
    canvas.drawRect(face, Paint()..color = inks.lit(0.2));
    canvas.drawRect(
      Rect.fromLTRB(face.left, dermis, face.right, face.bottom),
      Paint()..color = inks.shade(0.82),
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
    canvas.drawPath(wavy, Paint()..color = inks.lit(0.36));
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
        Sculpt.dome(
          canvas,
          Rect.fromCircle(center: Offset(x, y), radius: lobe * 0.46),
          inks,
          0.3,
        );
      }
      row++;
    }
    canvas.restore();
    final Paint rim = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2 * line
      ..strokeJoin = StrokeJoin.round
      ..color = inks.lit(0.45);
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
  void paint(
    Canvas canvas,
    ZoomInks inks,
    double pixel,
    double scale, {
    double detail = 1,
  }) {
    canvas.save();
    canvas.scale(scale);
    final double line = pixel / scale;
    // The thyroid behind it, ten times its size: only its surface shows.
    final Rect thyroid = Rect.fromCircle(
      center: Offset(-size * 2.6, size * 0.6),
      radius: size * 3.1,
    );
    canvas.drawOval(thyroid, Paint()..color = inks.shade(0.7));
    canvas.drawOval(
      thyroid,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2 * line
        ..color = inks.lit(0.3).withValues(alpha: 0.6),
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
        ..color = Color.lerp(inks.blood, inks.ground, 0.3)!,
    );
    final Path oval = Path()..addOval(gland);
    OrganArt._sculpted(canvas, oval, gland, inks, line, 1);
    canvas.save();
    canvas.clipPath(oval);
    for (final Rect lobule in Sculpt.cobble(
      gland,
      size * 0.15,
      math.Random(5),
    )) {
      Sculpt.dome(canvas, lobule, inks, 0.36);
    }
    canvas.restore();
    OrganArt._edged(canvas, oval, gland, inks, line, 1);
    canvas.restore();
  }
}

/// The eye cut level, the cornea to the left: the lens and iris, the
/// sclera, and lining the back of it the retina. The tissue is sampled at
/// the back of the eye.
final class _EyeOrgan extends OrganArt {
  _EyeOrgan(this.size);

  /// The eye's diameter, in the scene's units.
  final double size;

  // The eye's middle is near the origin; it is drawn about the back of the
  // eye, where it is sampled.
  @override
  Offset get site => Offset(size * 0.42, 0);

  @override
  void paint(
    Canvas canvas,
    ZoomInks inks,
    double pixel,
    double scale, {
    double detail = 1,
  }) {
    canvas.save();
    canvas.scale(scale);
    canvas.translate(site.dx, site.dy);
    final double line = pixel / scale;
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
        ..color = inks.shade(0.85),
    );
    // The cornea, bulging forward of the globe.
    final Rect cornea = Rect.fromCircle(
      center: centre + Offset(-r * 0.56, 0),
      radius: r * 0.62,
    );
    canvas.drawOval(cornea, Paint()..color = inks.shade(0.5));
    canvas.drawOval(
      cornea,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5 * line
        ..color = inks.lit(0.5).withValues(alpha: 0.8),
    );
    final Path ball = Path()..addOval(globe);
    OrganArt._sculpted(canvas, ball, globe, inks, line, 1, light: 0.22);
    // The retina, lining the back two thirds.
    canvas.drawArc(
      Rect.fromCircle(center: centre, radius: r * 0.93),
      -2.15,
      4.3,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.085
        ..color = inks.lit(0.4),
    );
    // The lens, hung behind the iris.
    final Offset lens = centre + Offset(-r * 0.66, 0);
    canvas.drawOval(
      Rect.fromCenter(center: lens, width: r * 0.36, height: r * 0.8),
      Paint()..color = inks.lit(0.55).withValues(alpha: 0.5),
    );
    final Paint iris = Paint()
      ..strokeWidth = 2.6 * line
      ..strokeCap = StrokeCap.round
      ..color = inks.lit(0.5);
    for (final double side in <double>[-1, 1]) {
      canvas.drawLine(
        centre + Offset(-r * 0.74, side * r * 0.66),
        lens + Offset(-r * 0.12, side * r * 0.24),
        iris,
      );
    }
    OrganArt._edged(canvas, ball, globe, inks, line, 1);
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
  void paint(
    Canvas canvas,
    ZoomInks inks,
    double pixel,
    double scale, {
    double detail = 1,
  }) {
    canvas.save();
    canvas.scale(scale);
    final double line = pixel / scale;
    final Rect box = _shape.getBounds();
    OrganArt._sculpted(canvas, _shape, box, inks, line, 1);
    OrganArt._edged(canvas, _shape, box, inks, line, 1);
    canvas.restore();
  }
}
