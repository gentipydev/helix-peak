import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/features/zoom/domain/anatomy_figure.dart';
import 'package:helixpeek/features/zoom/domain/anatomy_tables.dart';
import 'package:helixpeek/features/zoom/domain/zoom_depth.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/testis/testis_anatomy.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/testis/testis_form.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/testis/testis_style.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/tube_course.dart';

final TissueAnatomy _anatomy = tissueAnatomy['testis']!;
final AnatomyPart _part = AnatomyFigure.male.parts[_anatomy.uberon]!;
final double _view =
    _anatomy.metres * ZoomDepth.organMargin / ZoomDepth.testisUpright;

TestisForm _form() =>
    TestisForm.place(part: _part, anatomy: _anatomy, view: _view);

bool _inside(List<Offset> points, Offset p) {
  bool inside = false;
  for (int i = 0, j = points.length - 1; i < points.length; j = i++) {
    final Offset a = points[i];
    final Offset b = points[j];
    if ((a.dy > p.dy) != (b.dy > p.dy) &&
        p.dx < (b.dx - a.dx) * (p.dy - a.dy) / (b.dy - a.dy) + a.dx) {
      inside = !inside;
    }
  }
  return inside;
}

/// How far [p] lies from the line through [points], open or [closed].
double _toLine(List<Offset> points, Offset p, {bool closed = false}) {
  double least = double.infinity;
  final int n = points.length;
  for (int i = 0; i < (closed ? n : n - 1); i++) {
    final Offset a = points[i];
    final Offset b = points[(i + 1) % n];
    final Offset ab = b - a;
    final double length = ab.distanceSquared;
    final double t = length == 0
        ? 0
        : (((p - a).dx * ab.dx + (p - a).dy * ab.dy) / length).clamp(0.0, 1.0);
    least = math.min(least, (a + ab * t - p).distance);
  }
  return least;
}

/// Whether the segments from [a] to [b] and from [c] to [d] cross.
bool _cross(Offset a, Offset b, Offset c, Offset d) {
  double side(Offset p, Offset q, Offset r) =>
      (q.dx - p.dx) * (r.dy - p.dy) - (q.dy - p.dy) * (r.dx - p.dx);
  final double d1 = side(c, d, a);
  final double d2 = side(c, d, b);
  final double d3 = side(a, b, c);
  final double d4 = side(a, b, d);
  return d1 * d2 < 0 && d3 * d4 < 0;
}

Rect _bounds(List<Offset> points) {
  double left = double.infinity;
  double top = double.infinity;
  double right = double.negativeInfinity;
  double bottom = double.negativeInfinity;
  for (final Offset p in points) {
    left = math.min(left, p.dx);
    right = math.max(right, p.dx);
    top = math.min(top, p.dy);
    bottom = math.max(bottom, p.dy);
  }
  return Rect.fromLTRB(left, top, right, bottom);
}

void main() {
  test('the testis is 50 mm from pole to pole, about the middle of the '
      'body’s outline of it, and is sampled where the body is', () {
    final TestisForm form = _form();
    final List<Offset> outline = form.outlineMm;
    double longest = 0;
    for (final Offset p in outline) {
      for (final Offset q in outline) {
        longest = math.max(longest, (p - q).distance);
      }
    }
    expect(longest, closeTo(TestisAnatomy.length, 1));
    expect(
      form.mm(TestisAnatomy.length),
      closeTo(_anatomy.metres / _view, 1e-12),
    );
    expect(_bounds(outline).center.distance, lessThan(2));
    // Where the body goes into it, which an organ that follows the body
    // keeps.
    final double real = _anatomy.metres / _part.extent;
    final Offset site = (_part.site - _part.centre) * (real / _view);
    expect((form.site - site).distance, lessThan(1e-9));
    expect(form.contains(form.site), isTrue);
  });

  test('its parts are the sizes they are measured at', () {
    final TestisForm form = _form();
    // Its breadth across the cut, square to its length: 2–3.5 cm.
    final List<Offset> outline = form.outlineMm;
    Offset from = outline.first;
    Offset to = outline.first;
    for (final Offset p in outline) {
      for (final Offset q in outline) {
        if ((p - q).distance > (from - to).distance) {
          from = p;
          to = q;
        }
      }
    }
    final Offset along = (to - from) / (to - from).distance;
    final List<double> across = <double>[
      for (final Offset p in outline) p.dx * -along.dy + p.dy * along.dx,
    ];
    expect(
      across.reduce(math.max) - across.reduce(math.min),
      inInclusiveRange(25, 35),
    );
    // The tunica drawn about half a millimetre thick; the tubules 150–250
    // µm across (Junqueira), packed closer than twice their width.
    expect(TestisAnatomy.tunica, inInclusiveRange(0.4, 1));
    expect(TestisStyle.tubule, inInclusiveRange(0.15, 0.25));
    expect(TestisStyle.pitch, lessThan(2 * TestisStyle.tubule));
    // On ultrasound the epididymis's head is up to 12 mm across and its
    // tail up to 6 (Lotti et al. 2021); its body is the narrowest.
    final List<double> epididymis = TestisAnatomy.epididymis.radii;
    expect(
      epididymis.take(TestisAnatomy.epididymisHead).reduce(math.max) * 2,
      inInclusiveRange(5, 12),
    );
    for (final double r in epididymis.skip(TestisAnatomy.epididymisHead)) {
      expect(2 * r, inInclusiveRange(2, 6));
    }
    // The vas 1.5–2.7 mm thick; the artery 0.2–1.9 mm; a vein short of the
    // 3 mm a varicocele is read at.
    for (final double r in TestisAnatomy.vas.radii) {
      expect(2 * r, inInclusiveRange(1.5, 2.7));
    }
    for (final double r in TestisAnatomy.artery.radii) {
      expect(2 * r, inInclusiveRange(0.2, 1.9));
    }
    for (final AnatomyTube vein in TestisAnatomy.veins) {
      for (final double r in vein.radii) {
        expect(2 * r, lessThan(3));
      }
    }
    // Twelve to fifteen or twenty efferent ductules (Gray 1918).
    expect(form.ductules.length, inInclusiveRange(12, 20));
    // Every tube as wide at each of its points as it is given.
    for (final AnatomyTube tube in <AnatomyTube>[
      TestisAnatomy.epididymis,
      TestisAnatomy.vas,
      TestisAnatomy.artery,
      ...TestisAnatomy.veins,
    ]) {
      expect(tube.radii.length, tube.points.length);
    }
  });

  test('the septa run from the mediastinum’s edge to the tunica, none '
      'crossing another', () {
    final TestisForm form = _form();
    final List<List<Offset>> lines = <List<Offset>>[];
    for (final TestisSeptum septum in form.septa) {
      expect(_toLine(form.edgeMm, septum.course.first), lessThan(0.05));
      expect(
        _toLine(form.cutMm, septum.course.last, closed: true),
        lessThan(0.05),
      );
      lines.add(septum.course);
      final List<Offset>? branch = septum.branch;
      if (branch != null) {
        expect(_toLine(form.cutMm, branch.last, closed: true), lessThan(0.05));
        lines.add(branch);
      }
    }
    for (int a = 0; a < lines.length; a++) {
      for (int b = a + 1; b < lines.length; b++) {
        for (int i = 0; i + 1 < lines[a].length; i++) {
          for (int j = 0; j + 1 < lines[b].length; j++) {
            expect(
              _cross(
                lines[a][i],
                lines[a][i + 1],
                lines[b][j],
                lines[b][j + 1],
              ),
              isFalse,
              reason: 'septa $a and $b cross',
            );
          }
        }
      }
    }
  });

  test('the lobules tile the cut face between the septa', () {
    final TestisForm form = _form();
    final List<Rect> boxes = <Rect>[
      for (final TestisLobule lobule in form.lobules) _bounds(lobule.outline),
    ];
    final Rect box = _bounds(form.cutMm);
    int checked = 0;
    for (double y = box.top; y <= box.bottom; y += 0.37) {
      for (double x = box.left; x <= box.right; x += 0.37) {
        final Offset p = Offset(x, y);
        if (!_inside(form.cutMm, p) ||
            _inside(form.mediastinumMm, p) ||
            _toLine(form.edgeMm, p) < 0.3) {
          continue;
        }
        int holding = 0;
        for (int k = 0; k < form.lobules.length; k++) {
          if (boxes[k].contains(p) && form.lobules[k].contains(p)) {
            holding++;
          }
        }
        if (holding != 1) {
          // Only on a septum's line itself may a point fall to none or two.
          double nearest = double.infinity;
          for (final TestisSeptum septum in form.septa) {
            nearest = math.min(nearest, _toLine(septum.course, p));
            final List<Offset>? branch = septum.branch;
            if (branch != null) {
              nearest = math.min(nearest, _toLine(branch, p));
            }
          }
          expect(nearest, lessThan(0.05), reason: 'at $p, in $holding');
        }
        checked++;
      }
    }
    expect(checked, greaterThan(4000));
  });

  test('the tubules lie in their lobules and never across a septum, one '
      'another or themselves', () {
    final TestisForm form = _form();
    const double width = TestisStyle.tubule;
    // Every point of a tubule lies in its lobule, as far in as half a
    // tubule; but for the straight ends that run on by its apex into the
    // mediastinum.
    for (int t = 0; t < form.tubules.length; t++) {
      final TestisTubule tubule = form.tubules[t];
      final TestisLobule lobule = form.lobules[tubule.lobule];
      for (final Offset p in tubule.points) {
        if (!tubule.closed && (p - lobule.apex).distance < 1.5) {
          continue;
        }
        expect(lobule.contains(p), isTrue, reason: 'tubule $t at $p');
        expect(
          lobule.toEdge(p),
          greaterThanOrEqualTo(width / 2),
          reason: 'tubule $t at $p',
        );
      }
    }
    // No two tubules, nor two stretches of one, come nearer than a
    // tubule's width.
    const double cell = 0.2;
    final Map<(int, int), List<(int, int)>> near =
        <(int, int), List<(int, int)>>{};
    for (int t = 0; t < form.tubules.length; t++) {
      final List<Offset> points = form.tubules[t].points;
      for (int i = 0; i < points.length; i++) {
        if (_inside(form.mediastinumMm, points[i])) {
          continue;
        }
        near
            .putIfAbsent((
              (points[i].dx / cell).floor(),
              (points[i].dy / cell).floor(),
            ), () => <(int, int)>[])
            .add((t, i));
      }
    }
    for (final MapEntry<(int, int), List<(int, int)>> entry in near.entries) {
      final (int x, int y) = entry.key;
      for (final (int t, int i) in entry.value) {
        final TestisTubule tubule = form.tubules[t];
        final Offset p = tubule.points[i];
        for (int dx = -1; dx <= 1; dx++) {
          for (int dy = -1; dy <= 1; dy++) {
            for (final (int u, int j)
                in near[(x + dx, y + dy)] ?? const <(int, int)>[]) {
              if (u == t) {
                final int n = tubule.points.length;
                final int apart = tubule.closed
                    ? math.min((i - j).abs(), n - (i - j).abs())
                    : (i - j).abs();
                if (apart <= 8) {
                  continue;
                }
              }
              expect(
                (form.tubules[u].points[j] - p).distance,
                greaterThanOrEqualTo(width - 0.02),
                reason: 'tubules $t and $u at $p',
              );
            }
          }
        }
      }
    }
  });

  test('a lobule that reaches the mediastinum opens one of its tubules '
      'there, both its ends running on into the mediastinum, side by side', () {
    final TestisForm form = _form();
    int opened = 0;
    for (int k = 0; k < form.lobules.length; k++) {
      final List<TestisTubule> own = <TestisTubule>[
        for (final TestisTubule t in form.tubules)
          if (t.lobule == k) t,
      ];
      final List<TestisTubule> open = <TestisTubule>[
        for (final TestisTubule t in own)
          if (!t.closed) t,
      ];
      if (!form.lobules[k].reachesMediastinum || own.isEmpty) {
        expect(open, isEmpty, reason: 'lobule $k');
        continue;
      }
      // A lobule too small to have a cell square to its apex keeps it
      // shut.
      expect(open.length, lessThanOrEqualTo(1), reason: 'lobule $k');
      if (open.isEmpty) {
        continue;
      }
      expect(_inside(form.mediastinumMm, open.single.points.first), isTrue);
      expect(_inside(form.mediastinumMm, open.single.points.last), isTrue);
      opened++;
    }
    expect(opened, greaterThanOrEqualTo(TestisAnatomy.septa ~/ 2));
  });

  test('the efferent ductules run out of the testis into the head of the '
      'epididymis; the vas deferens runs on from its tail; the cord fades '
      'above it', () {
    final TestisForm form = _form();
    for (final TubeCourse ductule in form.ductules) {
      expect(form.contains(ductule.centres.first), isTrue);
      expect(form.epididymisPath.contains(ductule.centres.last), isTrue);
    }
    expect(
      (form.vas.centres.first - form.epididymis.centres.last).distance,
      lessThan(form.mm(0.01)),
    );
    final double head = form.epididymisPoints
        .map((Offset p) => p.dy)
        .reduce(math.min);
    for (final (TubeCourse tube, bool end) in <(TubeCourse, bool)>[
      (form.vas, true),
      (form.artery, false),
      for (final TubeCourse vein in form.veins) (vein, true),
    ]) {
      final int at = end ? tube.length - 1 : 0;
      expect(tube.shown[at], lessThan(0.05));
      expect(tube.centres[at].dy, lessThan(head));
    }
  });

  test('for a Leydig cell its clusters lie between the tubules, one at the '
      'place the tissue is sampled', () {
    final TestisForm form = _form();
    expect(form.leydig.length, greaterThan(TestisStyle.leydig ~/ 2));
    final List<Offset> tubules = <Offset>[
      for (final TestisTubule t in form.tubules) ...t.points,
    ];
    for (final (Offset at, double _) in form.leydig.take(60)) {
      final Offset p = form.toMm(at);
      expect(_inside(form.cutMm, p), isTrue);
      expect(_inside(form.mediastinumMm, p), isFalse);
      double nearest = double.infinity;
      for (final Offset q in tubules) {
        nearest = math.min(nearest, (q - p).distance);
      }
      expect(nearest, greaterThanOrEqualTo(TestisStyle.tubule / 2));
    }
    expect(form.siteLeydig.$1, form.site);
  });

  test('each part is named on what it names', () {
    final TestisForm form = _form();
    expect(
      form.epididymisPath.contains(form.place(TestisAnatomy.epididymisName)),
      isTrue,
    );
    expect(form.rete.contains(form.place(TestisAnatomy.reteName)), isTrue);
    final Offset vas = form.place(TestisAnatomy.vasName);
    double nearest = double.infinity;
    for (int i = 0; i < form.vas.length; i++) {
      nearest = math.min(
        nearest,
        (form.vas.centres[i] - vas).distance - form.vas.radius[i],
      );
    }
    expect(nearest, lessThanOrEqualTo(0));
  });

  test('the testis is laid the same every time', () {
    final TestisForm a = _form();
    final TestisForm b = _form();
    expect(a.tubules.length, b.tubules.length);
    for (int t = 0; t < a.tubules.length; t++) {
      expect(a.tubules[t].points, b.tubules[t].points);
    }
    for (int s = 0; s < a.septa.length; s++) {
      expect(a.septa[s].course, b.septa[s].course);
    }
    expect(a.knobs, b.knobs);
    expect(a.reteSpaces, b.reteSpaces);
    expect(a.leydig, b.leydig);
  });
}
