import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/anatomy_tables.dart';
import '../../domain/cell_archetypes.dart';
import '../zoom_inks.dart';
import 'sculpt.dart';

/// An organ's outline as a study reads it: its shape, its points, the box
/// round it, where its tissue is sampled, and where the body's midline is,
/// all in the organ scene's units at the organ's real size.
final class OrganForm {
  OrganForm(this.shape, this.points, this.site, {required this.midline})
    : box = shape.getBounds();

  final Path shape;
  final List<Offset> points;
  final Offset site;

  /// The body's midline, across: an organ's hilum faces it.
  final double midline;
  final Rect box;

  double get size => box.longestSide;

  /// Whether the organ lies along its height rather than its width.
  bool get tall => box.height >= box.width;

  late final Offset middle = () {
    Offset sum = Offset.zero;
    for (final Offset p in points) {
      sum += p;
    }
    return sum / points.length.toDouble();
  }();

  /// The organ cut across its length in [count] slices: each slice's two
  /// edges, from one end to the other, where a slice crosses the outline.
  late final List<(Offset, Offset)> slices = _slices(60);

  List<(Offset, Offset)> _slices(int count) {
    final List<(Offset, Offset)> out = <(Offset, Offset)>[];
    for (int i = 1; i < count; i++) {
      final double at = tall
          ? box.top + box.height * i / count
          : box.left + box.width * i / count;
      double low = double.infinity;
      double high = double.negativeInfinity;
      for (int j = 0; j < points.length; j++) {
        final Offset a = points[j];
        final Offset b = points[(j + 1) % points.length];
        final double ua = tall ? a.dy : a.dx;
        final double ub = tall ? b.dy : b.dx;
        if ((ua - at) * (ub - at) > 0 || ua == ub) {
          continue;
        }
        final double va = tall ? a.dx : a.dy;
        final double vb = tall ? b.dx : b.dy;
        final double v = va + (vb - va) * (at - ua) / (ub - ua);
        low = math.min(low, v);
        high = math.max(high, v);
      }
      if (low.isFinite && high.isFinite && high > low) {
        out.add(
          tall
              ? (Offset(low, at), Offset(high, at))
              : (Offset(at, low), Offset(at, high)),
        );
      }
    }
    return out;
  }

  /// The organ's middle line along its length, smoothed.
  late final List<Offset> spine = () {
    final List<Offset> raw = <Offset>[
      for (final (Offset a, Offset b) in slices) Offset.lerp(a, b, 0.5)!,
    ];
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
  }();

  /// A line through the slices at [share] of the way from one edge to the
  /// other: a fibre, a fold, running the organ's length.
  Path lengthwise(double share, {double wave = 0, double phase = 0}) {
    final Path path = Path();
    for (int i = 0; i < slices.length; i++) {
      final (Offset a, Offset b) = slices[i];
      final double wobble = wave == 0
          ? 0
          : wave * math.sin(i * 0.9 + phase) * (b - a).distance;
      final double t = (share + wobble).clamp(0.02, 0.98);
      final Offset p = Offset.lerp(a, b, t)!;
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    return path;
  }

  /// The point [t] of the way along the spine.
  Offset along(double t) {
    final double x = t.clamp(0.0, 1.0) * (spine.length - 1);
    final int i = x.floor().clamp(0, spine.length - 2);
    return Offset.lerp(spine[i], spine[i + 1], x - i)!;
  }

  /// The outline drawn in toward its middle to [share] of its size, and
  /// to [across] of that across its length.
  Path inset(
    double share, {
    double across = 1,
    double wobble = 0,
    int seed = 0,
  }) {
    final math.Random random = math.Random(seed);
    final double phase = random.nextDouble() * 6;
    final Path path = Path();
    for (int i = 0; i < points.length; i++) {
      final Offset p = points[i];
      final double w = 1 + wobble * math.sin(i * 0.55 + phase);
      final Offset d = (p - middle) * share * w;
      final Offset q =
          middle +
          (tall ? Offset(d.dx * across, d.dy) : Offset(d.dx, d.dy * across));
      if (i == 0) {
        path.moveTo(q.dx, q.dy);
      } else {
        path.lineTo(q.dx, q.dy);
      }
    }
    return path..close();
  }

  /// [count] points inside the organ, at least [apart] from one another,
  /// each kept with [chance] of its place.
  List<Offset> scatter(
    int count,
    math.Random random, {
    required double apart,
    double Function(Offset p)? chance,
    Path? within,
  }) {
    final List<Offset> out = <Offset>[];
    int tries = 0;
    while (out.length < count && tries < count * 80) {
      tries++;
      final Offset p = Offset(
        box.left + random.nextDouble() * box.width,
        box.top + random.nextDouble() * box.height,
      );
      if (!(within ?? shape).contains(p)) {
        continue;
      }
      if (chance != null && random.nextDouble() > chance(p)) {
        continue;
      }
      if (out.any((Offset q) => (q - p).distance < apart)) {
        continue;
      }
      out.add(p);
    }
    return out;
  }

  /// The point of the outline nearest [p].
  Offset nearestEdge(Offset p) {
    Offset best = points.first;
    for (final Offset q in points) {
      if ((q - p).distance < (best - p).distance) {
        best = q;
      }
    }
    return best;
  }
}

/// What lies inside an organ of one kind, and the part of it the zoom's
/// cell lives in, in the mark: the red marrow of a femur, the lobules of a
/// liver. By the kind of organ and of cell, never by gene. (The pancreas,
/// the testis and the salivary gland are drawn from anatomy instead, among
/// their neighbours: `PancreasArt`, `TestisArt`, `SalivaryArt`.)
abstract class OrganStudy {
  const OrganStudy();

  /// The kinds of organ outlined by the anatomogram that have a study of
  /// their own; the rest are sculpted with a surface for their kind.
  static const Set<OrganKind> studied = <OrganKind>{
    OrganKind.boneMarrow,
    OrganKind.liver,
    OrganKind.adipose,
    OrganKind.skeletalMuscle,
    OrganKind.fallopianTube,
    OrganKind.stomach,
    OrganKind.pituitary,
  };

  /// The study for an organ of [kind] outlined as [form], about a cell of
  /// [cell], or none where the organ has no study of its own.
  static OrganStudy? of(OrganKind kind, OrganForm form, CellShape cell) =>
      switch (kind) {
        OrganKind.boneMarrow => _Femur(form),
        OrganKind.liver => _Liver(form),
        OrganKind.adipose => _Fat(form),
        OrganKind.skeletalMuscle => _Muscle(form),
        OrganKind.fallopianTube => _Tube(form),
        OrganKind.stomach => _Stomach(form),
        OrganKind.pituitary => _Pituitary(form),
        _ => null,
      };

  /// Draws inside the organ, clipped to its outline, [detail] of the way to
  /// the organ from the body's drawing of it; [line] is a screen pixel.
  void inside(Canvas canvas, ZoomInks inks, double line, double detail);

  /// Draws what lies outside the outline (a duct leaving it, a stalk), over
  /// what is round it and under the organ.
  void behind(Canvas canvas, ZoomInks inks, double line, double detail) {}
}

Paint _stroke(Color colour, double width) => Paint()
  ..style = PaintingStyle.stroke
  ..strokeWidth = width
  ..strokeCap = StrokeCap.round
  ..strokeJoin = StrokeJoin.round
  ..color = colour;

/// A femur, the anatomogram's bone for marrow, cut along its length: the
/// cortex bright, the spongy bone of its ends a lattice of trabeculae, the
/// shaft's cavity in shade, and the red marrow in the spongy ends, where
/// blood is made, glowing.
final class _Femur extends OrganStudy {
  _Femur(this.form) {
    final math.Random random = math.Random(19);
    final Rect box = form.box;
    final double size = form.size;
    _cavity = form.inset(0.9, across: 0.42);
    // The spongy ends: the top fifth, round the head, and the bottom sixth,
    // round the condyles.
    _ends = Path()
      ..addRect(
        Rect.fromLTRB(
          box.left,
          box.top,
          box.right,
          box.top + box.height * 0.22,
        ),
      )
      ..addRect(
        Rect.fromLTRB(
          box.left,
          box.bottom - box.height * 0.18,
          box.right,
          box.bottom,
        ),
      );
    _lattice = Path();
    for (final Offset p in form.scatter(
      260,
      random,
      apart: size * 0.006,
      within: Path.combine(PathOperation.intersect, form.inset(0.94), _ends),
    )) {
      final double a = random.nextDouble() * math.pi;
      final double l = size * (0.012 + 0.016 * random.nextDouble());
      final Offset d = Offset(math.cos(a), math.sin(a)) * l;
      _lattice
        ..moveTo(p.dx - d.dx, p.dy - d.dy)
        ..lineTo(p.dx + d.dx, p.dy + d.dy);
    }
    _marrow = <Offset>[
      form.site,
      ...form.scatter(
        90,
        random,
        apart: size * 0.011,
        within: Path.combine(PathOperation.intersect, form.inset(0.9), _ends),
      ),
    ];
    _shaft = form.inset(0.86, across: 0.36);
  }

  final OrganForm form;
  late final Path _cavity;
  late final Path _ends;
  late final Path _lattice;
  late final Path _shaft;
  late final List<Offset> _marrow;

  @override
  void inside(Canvas canvas, ZoomInks inks, double line, double detail) {
    // The cavity down the shaft, yellow marrow, in shade.
    canvas.drawPath(
      _cavity,
      Paint()..color = inks.shade(0.62).withValues(alpha: 0.85 * detail),
    );
    canvas.drawPath(
      _shaft,
      Paint()..color = inks.shade(0.5).withValues(alpha: 0.5 * detail),
    );
    // The spongy ends: their lattice, and the red marrow in it.
    canvas.save();
    canvas.clipPath(_ends);
    canvas.drawPath(
      form.inset(0.94),
      Paint()..color = inks.shade(0.7).withValues(alpha: 0.7 * detail),
    );
    for (final Offset p in _marrow) {
      Sculpt.glow(canvas, p, form.size * 0.03, inks, 0.18 * detail);
    }
    canvas.drawPath(
      _lattice,
      _stroke(inks.lit(0.62).withValues(alpha: 0.55 * detail), 1.1 * line),
    );
    for (final Offset p in _marrow) {
      canvas.drawCircle(
        p,
        form.size * 0.0042,
        Paint()..color = inks.glow(0.85 * detail),
      );
    }
    canvas.restore();
    // The cortex: a bright band inside the outline.
    canvas.drawPath(
      form.shape,
      _stroke(inks.lit(0.58).withValues(alpha: 0.7 * detail), 3 * line),
    );
  }
}

/// The liver: its two lobes either side of the falciform ligament, its
/// lobules as a honeycomb in the mark (the hepatocytes are the whole of
/// it), and the portal vessels branching in from its hilum.
final class _Liver extends OrganStudy {
  _Liver(this.form) {
    final math.Random random = math.Random(23);
    final Rect box = form.box;
    final double size = form.size;
    // The falciform ligament: from the top border, a little to the body's
    // left of the middle, down to the lower border.
    final double x = box.left + box.width * 0.6;
    _falciform = Path()
      ..moveTo(x, box.top)
      ..quadraticBezierTo(
        x - box.width * 0.06,
        box.center.dy,
        x - box.width * 0.03,
        box.bottom,
      );
    final double step = size * 0.045;
    _lobules = <Offset>[];
    int row = 0;
    for (double y = box.top; y < box.bottom + step; y += step * 0.866) {
      for (
        double cx = box.left - (row.isOdd ? step / 2 : 0);
        cx < box.right + step;
        cx += step
      ) {
        final Offset at =
            Offset(cx, y) +
            Offset(random.nextDouble() - 0.5, random.nextDouble() - 0.5) *
                (step * 0.12);
        if (form.shape.contains(at)) {
          _lobules.add(at);
        }
      }
      row++;
    }
    _step = step;
    final Offset hilum = Offset(
      box.left + box.width * 0.45,
      box.bottom - box.height * 0.18,
    );
    _vessels = Sculpt.tree(
      hilum,
      -math.pi / 2 - 0.4,
      size * 0.16,
      4,
      random,
      spread: 0.55,
      shrink: 0.7,
    );
  }

  final OrganForm form;
  late final Path _falciform;
  late final List<Offset> _lobules;
  late final double _step;
  late final List<Path> _vessels;

  Path _hexagon(Offset c, double r) {
    final Path path = Path();
    for (int k = 0; k < 6; k++) {
      final double a = math.pi / 6 + k * math.pi / 3;
      final Offset p = c + Offset(math.cos(a), math.sin(a)) * r;
      if (k == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    return path..close();
  }

  @override
  void inside(Canvas canvas, ZoomInks inks, double line, double detail) {
    final double r = _step * 0.55;
    final Paint rim = _stroke(inks.glow(0.32 * detail), 1 * line);
    for (final Offset c in _lobules) {
      final Path hex = _hexagon(c, r);
      canvas.drawPath(
        hex,
        Paint()
          ..shader = RadialGradient(
            colors: <Color>[inks.glow(0.04 * detail), inks.glow(0.22 * detail)],
          ).createShader(Rect.fromCircle(center: c, radius: r)),
      );
      canvas.drawPath(hex, rim);
      // Its central vein.
      canvas.drawCircle(
        c,
        r * 0.14,
        Paint()..color = inks.shade(0.5).withValues(alpha: 0.8 * detail),
      );
    }
    for (int g = 0; g < _vessels.length; g++) {
      canvas.drawPath(
        _vessels[g],
        _stroke(
          inks.lit(0.6).withValues(alpha: 0.6 * detail),
          (4.2 - g * 0.8) * line,
        ),
      );
    }
    canvas.drawPath(
      _falciform,
      _stroke(inks.lit(0.65).withValues(alpha: 0.75 * detail), 1.8 * line),
    );
  }
}

/// Fat: lobes of it parted by fine septa, small vessels in the septa, and
/// the adipocytes, which are the lobes, in the mark.
final class _Fat extends OrganStudy {
  _Fat(this.form) {
    final math.Random random = math.Random(29);
    _lobes = <Rect>[
      for (final Rect lobe in Sculpt.cobble(
        form.box,
        form.size * 0.085,
        random,
      ))
        if (form.shape.contains(lobe.center)) lobe,
    ];
    _vessels = Path();
    for (int k = 0; k < 4; k++) {
      final Offset at = form.along(0.15 + 0.22 * k);
      for (final Path generation in Sculpt.tree(
        at,
        random.nextDouble() * math.pi * 2,
        form.size * 0.1,
        3,
        random,
        spread: 0.7,
        shrink: 0.7,
      )) {
        _vessels.addPath(generation, Offset.zero);
      }
    }
  }

  final OrganForm form;
  late final List<Rect> _lobes;
  late final Path _vessels;

  @override
  void inside(Canvas canvas, ZoomInks inks, double line, double detail) {
    for (final Rect lobe in _lobes) {
      Sculpt.dome(canvas, lobe, inks, 0.42 * detail);
      canvas.drawOval(
        lobe.deflate(lobe.width * 0.08),
        Paint()..color = inks.glow(0.2 * detail),
      );
      canvas.drawOval(
        lobe,
        _stroke(inks.lit(0.5).withValues(alpha: 0.3 * detail), 1 * line),
      );
    }
    canvas.drawPath(
      _vessels,
      _stroke(
        Color.lerp(
          inks.blood,
          inks.ground,
          0.25,
        )!.withValues(alpha: 0.7 * detail),
        1.2 * line,
      ),
    );
  }
}

/// A muscle: its fascicles running its length, gathered into tendon at
/// its ends, the fibres, which are the muscle's cells, in the mark.
final class _Muscle extends OrganStudy {
  _Muscle(this.form) {
    _fascicles = <Path>[
      for (int k = 1; k < 18; k++)
        form.lengthwise(k / 18, wave: 0.006, phase: k * 1.3),
    ];
    final Rect box = form.box;
    _tendons = Path()
      ..addRect(
        form.tall
            ? Rect.fromLTRB(
                box.left,
                box.top,
                box.right,
                box.top + box.height * 0.08,
              )
            : Rect.fromLTRB(
                box.left,
                box.top,
                box.left + box.width * 0.08,
                box.bottom,
              ),
      )
      ..addRect(
        form.tall
            ? Rect.fromLTRB(
                box.left,
                box.bottom - box.height * 0.07,
                box.right,
                box.bottom,
              )
            : Rect.fromLTRB(
                box.right - box.width * 0.07,
                box.top,
                box.right,
                box.bottom,
              ),
      );
  }

  final OrganForm form;
  late final List<Path> _fascicles;
  late final Path _tendons;

  @override
  void inside(Canvas canvas, ZoomInks inks, double line, double detail) {
    canvas.drawPath(
      form.inset(0.9, across: 0.7),
      Paint()..color = inks.glow(0.1 * detail),
    );
    for (int k = 0; k < _fascicles.length; k++) {
      canvas.drawPath(
        _fascicles[k],
        _stroke(
          k.isEven
              ? inks.glow(0.42 * detail)
              : inks.shade(0.55).withValues(alpha: 0.7 * detail),
          (k.isEven ? 1.3 : 1.8) * line,
        ),
      );
    }
    // The tendons, pale and glossy.
    canvas.drawPath(
      _tendons,
      Paint()..color = inks.lit(0.62).withValues(alpha: 0.75 * detail),
    );
  }
}

/// A fallopian tube opened along its length: its wall, the folds of its
/// mucosa lining it, where its ciliated cells are, in the mark, and its
/// lumen down the middle. Each runs parallel to the tube's walls, however
/// the tube curves: a band of the outline's own stroke, held inside it.
final class _Tube extends OrganStudy {
  _Tube(this.form) {
    // How thick the tube is: for a long thin shape, twice its area over its
    // perimeter.
    double area = 0;
    double perimeter = 0;
    final List<Offset> p = form.points;
    for (int i = 0; i < p.length; i++) {
      final Offset a = p[i];
      final Offset b = p[(i + 1) % p.length];
      area += a.dx * b.dy - b.dx * a.dy;
      perimeter += (b - a).distance;
    }
    _thick = perimeter == 0 ? form.size * 0.1 : (area.abs() / perimeter) * 2;
  }

  final OrganForm form;
  late final double _thick;

  @override
  void inside(Canvas canvas, ZoomInks inks, double line, double detail) {
    final double t = _thick;
    Paint band(Color colour, double width) => Paint()
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = width
      ..color = colour;
    // From the middle out: the lumen, the mucosa, a fold line in it, and
    // the wall at the edge. Each band is the outline stroked twice its
    // width, of which the clip keeps the inner half.
    canvas.drawPath(
      form.shape,
      Paint()..color = inks.shade(0.38).withValues(alpha: 0.9 * detail),
    );
    canvas.drawPath(form.shape, band(inks.glow(0.3 * detail), t * 0.62));
    for (final double at in <double>[0.52, 0.4]) {
      canvas.drawPath(
        form.shape,
        band(inks.glow(0.85 * detail), t * at + line),
      );
      canvas.drawPath(
        form.shape,
        band(
          Color.lerp(
            inks.shade(0.38),
            inks.mark,
            0.3,
          )!.withValues(alpha: detail),
          t * at - line,
        ),
      );
    }
    canvas.drawPath(
      form.shape,
      band(inks.lit(0.3).withValues(alpha: detail), t * 0.3),
    );
  }
}

/// A stomach opened: its wall, the rugae folding its lining along its
/// length, the arcades of vessels along its curvatures, and its mucosa,
/// where its glands' dividing cells are, in the mark.
final class _Stomach extends OrganStudy {
  _Stomach(this.form) {
    final math.Random random = math.Random(37);
    _rugae = <Path>[
      for (int k = 1; k < 9; k++)
        form.lengthwise(0.18 + 0.64 * k / 9, wave: 0.03, phase: k * 2.1),
    ];
    _lining = form.inset(0.82, across: 0.72);
    _arcades = Path();
    final int n = form.points.length;
    for (int i = 0; i < n; i += math.max(1, n ~/ 26)) {
      final Offset p = form.points[i];
      final Offset inward = form.middle - p;
      final double d = inward.distance;
      if (d == 0) {
        continue;
      }
      final Offset q =
          p + inward / d * (form.size * (0.04 + 0.03 * random.nextDouble()));
      _arcades
        ..moveTo(p.dx, p.dy)
        ..lineTo(q.dx, q.dy);
    }
  }

  final OrganForm form;
  late final List<Path> _rugae;
  late final Path _lining;
  late final Path _arcades;

  @override
  void inside(Canvas canvas, ZoomInks inks, double line, double detail) {
    canvas.drawPath(
      _lining,
      Paint()..color = inks.shade(0.42).withValues(alpha: 0.8 * detail),
    );
    canvas.drawPath(_lining, Paint()..color = inks.glow(0.12 * detail));
    canvas.save();
    canvas.clipPath(_lining);
    for (final Path ruga in _rugae) {
      Sculpt.glowingStroke(
        canvas,
        ruga,
        inks,
        width: 1.3 * line,
        alpha: 0.55 * detail,
      );
    }
    canvas.restore();
    canvas.drawPath(
      _arcades,
      _stroke(
        Color.lerp(
          inks.blood,
          inks.ground,
          0.3,
        )!.withValues(alpha: 0.6 * detail),
        1.2 * line,
      ),
    );
  }
}

/// The pituitary seen from the side: its anterior lobe, the gland that
/// makes the growth and other hormones, in the mark; its posterior lobe,
/// nerve, behind it; its stalk rising to the hypothalamus; and the bony cup
/// of the sella turcica it sits in.
final class _Pituitary extends OrganStudy {
  _Pituitary(this.form) {
    final Rect box = form.box;
    // The lobes part a little behind the place the tissue is sampled.
    final double cleft = math.min(
      box.right - box.width * 0.22,
      form.site.dx + box.width * 0.14,
    );
    _anterior = Path.combine(
      PathOperation.intersect,
      form.shape,
      Path()..addRect(
        Rect.fromLTRB(box.left - 1, box.top - 1, cleft, box.bottom + 1),
      ),
    );
    _posterior = Path.combine(
      PathOperation.intersect,
      form.shape,
      Path()..addRect(
        Rect.fromLTRB(cleft, box.top - 1, box.right + 1, box.bottom + 1),
      ),
    );
    final double w = box.width;
    final Offset foot = Offset(cleft + w * 0.08, box.top + box.height * 0.04);
    _stalk = Path()
      ..moveTo(foot.dx - w * 0.07, foot.dy)
      ..quadraticBezierTo(
        foot.dx - w * 0.02,
        foot.dy - box.height * 0.28,
        foot.dx + w * 0.02,
        foot.dy - box.height * 0.55,
      )
      ..lineTo(foot.dx + w * 0.1, foot.dy - box.height * 0.55)
      ..quadraticBezierTo(
        foot.dx + w * 0.06,
        foot.dy - box.height * 0.28,
        foot.dx + w * 0.06,
        foot.dy,
      )
      ..close();
    _hypothalamus = Path()
      ..moveTo(box.left - w * 0.3, foot.dy - box.height * 0.5)
      ..quadraticBezierTo(
        box.center.dx,
        foot.dy - box.height * 0.68,
        box.right + w * 0.3,
        foot.dy - box.height * 0.5,
      );
    _sella = Path()
      ..addArc(
        Rect.fromLTRB(
          box.left - w * 0.14,
          box.top + box.height * 0.1,
          box.right + w * 0.14,
          box.bottom + box.height * 0.2,
        ),
        math.pi * 0.05,
        math.pi * 0.9,
      );
    _cells = Sculpt.cobble(box, form.size * 0.08, math.Random(41));
    _fibres = <Path>[
      for (int k = 1; k < 7; k++)
        Path()
          ..moveTo(cleft, box.top + box.height * k / 7)
          ..quadraticBezierTo(
            (cleft + box.right) / 2,
            box.top + box.height * (k / 7 - 0.05),
            box.right,
            box.top + box.height * k / 7,
          ),
    ];
  }

  final OrganForm form;
  late final Path _anterior;
  late final Path _posterior;
  late final Path _stalk;
  late final Path _hypothalamus;
  late final Path _sella;
  late final List<Rect> _cells;
  late final List<Path> _fibres;

  @override
  void behind(Canvas canvas, ZoomInks inks, double line, double detail) {
    if (detail <= 0) {
      return;
    }
    // The bony cup it sits in, and the brain above.
    canvas.drawPath(
      _sella,
      _stroke(inks.lit(0.6).withValues(alpha: 0.8 * detail), 9 * line),
    );
    canvas.drawPath(
      _hypothalamus,
      _stroke(inks.lit(0.32).withValues(alpha: 0.7 * detail), 2 * line),
    );
    canvas.drawPath(
      _stalk,
      Paint()..color = inks.lit(0.28).withValues(alpha: 0.95 * detail),
    );
    canvas.drawPath(
      _stalk,
      _stroke(inks.lit(0.5).withValues(alpha: 0.7 * detail), 1 * line),
    );
  }

  @override
  void inside(Canvas canvas, ZoomInks inks, double line, double detail) {
    // The posterior lobe: nerve fibres down from the stalk.
    canvas.drawPath(
      _posterior,
      Paint()..color = inks.shade(0.82).withValues(alpha: 0.8 * detail),
    );
    canvas.save();
    canvas.clipPath(_posterior);
    for (final Path fibre in _fibres) {
      canvas.drawPath(
        fibre,
        _stroke(inks.lit(0.5).withValues(alpha: 0.35 * detail), 1 * line),
      );
    }
    canvas.restore();
    // The anterior lobe: a gland of cords, in the mark.
    canvas.save();
    canvas.clipPath(_anterior);
    canvas.drawPath(_anterior, Paint()..color = inks.glow(0.2 * detail));
    for (final Rect cell in _cells) {
      Sculpt.dome(canvas, cell, inks, 0.3 * detail);
      canvas.drawOval(
        cell.deflate(cell.width * 0.2),
        Paint()..color = inks.glow(0.18 * detail),
      );
    }
    canvas.restore();
    canvas.drawPath(_anterior, _stroke(inks.glow(0.7 * detail), 1.4 * line));
  }
}
