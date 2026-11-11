import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/features/zoom/domain/anatomy_figure.dart';
import 'package:helixpeek/features/zoom/domain/anatomy_tables.dart';
import 'package:helixpeek/features/zoom/domain/zoom_depth.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/contour.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/organs/intestine/intestine_anatomy.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/organs/intestine/intestine_form.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/tube_course.dart';

final TissueAnatomy _anatomy = tissueAnatomy['intestine']!;

/// The organ's view, framed by its width: the form is the same at any.
final double _view = _anatomy.metres * ZoomDepth.organMargin;

final List<AnatomyFigure> _figures = <AnatomyFigure>[
  AnatomyFigure.female,
  AnatomyFigure.male,
];

AnatomyPart _part(AnatomyFigure figure) => figure.parts[_anatomy.uberon]!;

IntestineForm _form([
  AnatomyFigure? figure,
  IntestineHome home = IntestineHome.colon,
]) => IntestineForm.place(
  part: _part(figure ?? AnatomyFigure.female),
  anatomy: _anatomy,
  view: _view,
  home: home,
);

bool _inside(List<Offset> polygon, Offset p) =>
    (Path()..addPolygon(polygon, true)).contains(p);

/// How far [p] is from the closed polygon [points]' edge.
double _toEdge(List<Offset> points, Offset p) {
  double best = double.infinity;
  final int n = points.length;
  for (int i = 0; i < n; i++) {
    final Offset a = points[i];
    final Offset ab = points[(i + 1) % n] - a;
    final double length = ab.dx * ab.dx + ab.dy * ab.dy;
    final double t = length == 0
        ? 0
        : (((p - a).dx * ab.dx + (p - a).dy * ab.dy) / length).clamp(0.0, 1.0);
    best = math.min(best, (p - (a + ab * t)).distance);
  }
  return best;
}

Rect _bounds(List<Offset> points) => points.fold<Rect>(
  Rect.fromPoints(points.first, points.first),
  (Rect r, Offset p) => r.expandToInclude(Rect.fromPoints(p, p)),
);

double _area(List<Offset> points) {
  double sum = 0;
  for (int i = 0; i < points.length; i++) {
    final Offset a = points[i];
    final Offset b = points[(i + 1) % points.length];
    sum += a.dx * b.dy - b.dx * a.dy;
  }
  return sum / 2;
}

double _length(List<Offset> line) {
  double sum = 0;
  for (int i = 1; i < line.length; i++) {
    sum += (line[i] - line[i - 1]).distance;
  }
  return sum;
}

/// The points a path's outline is followed by: its contours, sampled.
List<Offset> _pathPoints(Path path) => <Offset>[
  for (final PathMetric m in path.computeMetrics())
    for (double d = 0; d < m.length; d += 0.002)
      m.getTangentForOffset(d)!.position,
];

void main() {
  test('the intestines are drawn at their real size, laid on the body’s '
      'outline of the intestine on either figure, moved a few millimetres '
      'at most to lay the place they are gone into on the place the body '
      'goes in', () {
    for (final AnatomyFigure figure in _figures) {
      final String what = figure.name;
      final AnatomyPart part = _part(figure);
      final IntestineForm form = _form(figure);
      expect(form.mm(1), closeTo(1e-3 / _view, 1e-15), reason: what);
      // The card's 35 cm, the left colic flexure's top to the lowest coil,
      // and about 30 cm across.
      expect(form.box.height / form.scale, closeTo(350, 1), reason: what);
      expect(form.box.width / form.scale, closeTo(301, 2), reason: what);
      expect(form.anchorShift, lessThan(10), reason: what);
      // Where the body goes in, which intestines that follow the body keep.
      final double real = _anatomy.metres / part.extent;
      final Offset site = (part.site - part.centre) * (real / _view);
      expect((form.site - site).distance, lessThan(1e-9), reason: what);
      expect(form.contains(form.site), isTrue, reason: what);
    }
  });

  test('the zoom goes in where GTEx samples the small intestine: on the '
      'Peyer’s patch of the terminal ileum, laid open just short of the '
      'valve, inside its lining, on either figure', () {
    expect(
      (IntestineAnatomy.site - IntestineForm.patchMiddleMm).distance,
      lessThan(0.5),
    );
    for (final AnatomyFigure figure in _figures) {
      final String what = figure.name;
      final IntestineForm form = _form(figure);
      expect(_inside(form.patch, form.site), isTrue, reason: what);
      expect(_inside(form.strip.last, form.site), isTrue, reason: what);
      // Low on the body's right, a third of the way across from it.
      final double across = (form.site.dx - form.box.left) / form.box.width;
      final double down = (form.site.dy - form.box.top) / form.box.height;
      expect(across, inInclusiveRange(0.25, 0.4), reason: what);
      expect(down, inInclusiveRange(0.7, 0.85), reason: what);
    }
  });

  test('the colon, the coils, the appendix and the patch are as they are '
      'measured', () {
    // The cecum 7.5 cm broad (Gray 1918), and the colon narrowing on from
    // it to the sigmoid (Gray; Haraikawa et al. 2023).
    const List<double> half = IntestineAnatomy.colonHalf;
    expect(2 * half.reduce(math.max), closeTo(75, 2));
    expect(half.indexOf(half.reduce(math.max)), lessThan(3));
    for (int i = 3; i < half.length; i++) {
      expect(half[i], lessThanOrEqualTo(half[i - 1]), reason: '$i');
    }
    // Its bands about 12 mm wide (Gray).
    expect(IntestineAnatomy.band, 12);
    // The jejunum wider than the ileum, both under Gray's distended 4 and
    // 3.75 cm.
    expect(
      IntestineAnatomy.jejunumHalf,
      greaterThan(IntestineAnatomy.ileumHalf),
    );
    expect(2 * IntestineAnatomy.jejunumHalf, lessThanOrEqualTo(40));
    expect(2 * IntestineAnatomy.ileumHalf, lessThanOrEqualTo(37.5));
    // The appendix 2 to 20 cm, about 8.3 on average (Gray).
    expect(_length(IntestineAnatomy.appendix), inInclusiveRange(55, 100));
    // A Peyer's patch 2 to 10 cm long, oval and placed lengthwise (Gray).
    expect(IntestineAnatomy.patchLength, inInclusiveRange(20, 100));
    expect(IntestineAnatomy.patchWidth, lessThan(IntestineAnatomy.patchLength));
    // The wall under 3 mm.
    expect(IntestineAnatomy.colonWall, lessThanOrEqualTo(3));
    expect(IntestineAnatomy.ileumWall, lessThanOrEqualTo(3));
  });

  test('where the zoom’s cell lives is read from the Atlas’s name for it, '
      'never from the gene', () {
    const Map<String?, IntestineHome> homes = <String?, IntestineHome>{
      'Colon enteroendocrine cells': IntestineHome.colon,
      'Colon enterocytes': IntestineHome.colon,
      'Colonocytes': IntestineHome.colon,
      'Mitotic cells (Colon)': IntestineHome.colon,
      'Enterocytes': IntestineHome.ileum,
      'Paneth cells': IntestineHome.ileum,
      'Goblet cells': IntestineHome.both,
      'Tuft cells': IntestineHome.both,
      'Neuroendocrine cells': IntestineHome.both,
      'Enteric stem cells': IntestineHome.both,
      'Enteric transient amplifying cells': IntestineHome.both,
      'Smooth muscle cells': IntestineHome.muscle,
      'Interstitial cells of Cajal': IntestineHome.muscle,
      'Enteric glia cells': IntestineHome.muscle,
      'Fibroblasts': IntestineHome.colon,
      'Plasma cells': IntestineHome.colon,
      null: IntestineHome.both,
    };
    for (final MapEntry<String?, IntestineHome> e in homes.entries) {
      expect(IntestineHome.of(e.key), e.value, reason: '${e.key}');
    }
    expect(IntestineHome.colon.inColon, isTrue);
    expect(IntestineHome.colon.inIleum, isFalse);
    expect(IntestineHome.ileum.inIleum, isTrue);
    expect(IntestineHome.ileum.inColon, isFalse);
    expect(IntestineHome.both.inColon && IntestineHome.both.inIleum, isTrue);
    expect(
      IntestineHome.muscle.inColon || IntestineHome.muscle.inIleum,
      isFalse,
    );
  });

  test('round the window and the laid-open ileum the cut wall’s coats nest '
      'from the serosa in, each inside the one before', () {
    final IntestineForm form = _form();
    for (final (String what, List<List<Offset>> edges)
        in <(String, List<List<Offset>>)>[
          ('window', form.window),
          ('ileum', form.strip),
        ]) {
      expect(edges, hasLength(6), reason: what);
      for (int k = 1; k < edges.length; k++) {
        int outside = 0;
        for (final Offset p in edges[k]) {
          // Round the cecum's tip, a few tenths of a millimetre at most,
          // under a pixel: each coat is painted over the one before.
          if (!_inside(edges[k - 1], p) &&
              _toEdge(edges[k - 1], p) > form.mm(0.4)) {
            outside++;
          }
        }
        expect(outside, 0, reason: '$what: coat $k');
        expect(
          _area(edges[k]).abs(),
          lessThan(_area(edges[k - 1]).abs()),
          reason: '$what: coat $k',
        );
      }
    }
  });

  test('the semilunar fold, the valve and the appendix’s orifice lie in the '
      'colon’s lining in the window; the patch and its nodules in the '
      'ileum’s', () {
    final IntestineForm form = _form();
    final List<Offset> lining = form.window.last;
    final List<Offset> folds = _pathPoints(form.folds);
    final int inside = folds.where((Offset p) => _inside(lining, p)).length;
    // The frenula run on round the wall past the window's edge.
    expect(inside / folds.length, greaterThan(0.85));
    for (final Offset p in _pathPoints(form.slit)) {
      expect(_inside(lining, p), isTrue);
    }
    expect(_inside(lining, form.orifice), isTrue);
    // The valve on the cecum's medial side, the orifice below it.
    final Rect slit = form.slit.getBounds();
    expect(slit.center.dx, greaterThan(_bounds(lining).center.dx));
    expect(form.orifice.dy, greaterThan(slit.bottom));
    for (final Offset p in form.patch) {
      expect(_inside(form.strip.last, p), isTrue);
    }
    expect(form.nodules, hasLength(IntestineAnatomy.patchNodules));
    for (final Offset p in form.nodules) {
      expect(_inside(form.patch, p), isTrue);
    }
  });

  test('everything drawn lies inside the outline; every coil’s ends run '
      'back into the shade, and the sigmoid colon’s too', () {
    final IntestineForm form = _form();
    final List<Offset> outline = form.outlinePoints;
    for (final TubeCourse t in <TubeCourse>[
      ...form.coils,
      form.ileum,
      form.appendix,
    ]) {
      // The outline goes round each where at least half of it shows.
      for (int i = 0; i < t.length; i++) {
        if (t.shown[i] >= 0.6) {
          expect(_inside(outline, t.at(i, 0.9)), isTrue);
          expect(_inside(outline, t.at(i, -0.9)), isTrue);
        }
      }
    }
    // The colon's middle line, but its first point: the cecum's tip, on
    // the outline itself.
    for (final Offset p in form.colon.centres.skip(1)) {
      expect(_inside(outline, p), isTrue);
    }
    for (final TubeCourse t in form.coils) {
      expect(t.shown.first, 0);
      expect(t.shown.last, 0);
    }
    expect(form.ileum.shown.first, 0);
    expect(form.colon.shown.last, 0);
    expect(form.colon.shown[form.windowRow], 1);
    expect(IntestineForm.jejunal, hasLength(form.coils.length));
    expect(IntestineForm.jejunal.where((bool j) => j), isNotEmpty);
    expect(IntestineForm.jejunal.where((bool j) => !j), isNotEmpty);
  });

  test('the step from the body meets the intestines’ outline and the '
      'body’s at the same places, in the same order round them from the '
      'top', () {
    for (final AnatomyFigure figure in _figures) {
      final AnatomyPart part = _part(figure);
      final IntestineForm form = _form(figure);
      final double real = _anatomy.metres / part.extent;
      final List<Offset> body = Contour(<Offset>[
        for (final Offset p in part.followed)
          (p - part.centre) * (real / _view),
      ]).sampled(8).points;
      List<int> order(List<Offset> points) {
        final List<Offset> marks = form.marksOf(points);
        final int start = points.indexOf(marks.first);
        final List<int> round = <int>[
          for (final Offset m in marks)
            (points.indexOf(m) - start) % points.length,
        ];
        return <int>[
          for (int k = 0; k < round.length; k++)
            round.where((int r) => r < round[k]).length,
        ];
      }

      final double way = _area(form.outlinePoints).sign;
      final List<Offset> bodyWay = _area(body).sign == way
          ? body
          : body.reversed.toList();
      expect(order(form.outlinePoints), order(bodyWay), reason: figure.name);
      expect(
        form.marksOf(form.outlinePoints).toSet(),
        hasLength(5),
        reason: figure.name,
      );
      for (final List<Offset> points in <List<Offset>>[
        form.outlinePoints,
        bodyWay,
      ]) {
        final List<Offset> marks = form.marksOf(points);
        final Rect box = _bounds(points);
        // The top in the right half: the left colic flexure, and the body's
        // highest coil.
        expect(marks[0].dy, closeTo(box.top, 1e-9), reason: figure.name);
        expect(marks[0].dx, greaterThan(box.center.dx), reason: figure.name);
        // Outermost on the right and on the left in the middle three fifths
        // of their height, out at the box's sides; the lowest at its foot.
        expect(marks[1].dx, greaterThan(box.right - box.width * 0.05));
        expect(marks[2].dx, greaterThan(box.center.dx));
        expect(marks[3].dy, closeTo(box.bottom, 1e-9));
        expect(marks[3].dx, lessThan(box.center.dx));
        expect(marks[4].dx, lessThan(box.left + box.width * 0.05));
      }
      expect(
        _bounds(form.outlineAt(1)).width,
        closeTo(form.box.width, form.mm(1)),
        reason: figure.name,
      );
    }
  });

  test('its parts are named where they are: the home where the cell '
      'lives, the transverse and the descending colon, the jejunum, the ileum '
      'and the appendix on their courses', () {
    for (final IntestineHome home in IntestineHome.values) {
      final IntestineForm form = _form(AnatomyFigure.female, home);
      final Offset at = form.homeName;
      switch (home) {
        case IntestineHome.colon:
          expect(_inside(form.window.last, at), isTrue);
        case IntestineHome.ileum:
          expect(_inside(form.strip.last, at), isTrue);
        case IntestineHome.both:
          expect(_inside(form.window.last, at), isTrue);
          expect(
            form.slit.getBounds().inflate(form.mm(2)).contains(at),
            isTrue,
          );
        case IntestineHome.muscle:
          expect(form.colon.centres, contains(at));
      }
    }
    final IntestineForm form = _form();
    for (final Offset at in <Offset>[
      form.transverseName,
      form.descendingName,
    ]) {
      expect(
        form.colon.centres.sublist(form.windowRow, form.sigmoidRow),
        contains(at),
      );
    }
    expect(
      form.coils.first.centres.any(
        (Offset p) => (p - form.jejunumName).distance < form.mm(1),
      ),
      isTrue,
    );
    expect(
      form.appendix.centres.any(
        (Offset p) => (p - form.appendixName).distance < form.mm(1),
      ),
      isTrue,
    );
    // The transverse colon at the top, the descending at the right, the
    // ileum low in the pelvis, the appendix low on the right of the body.
    expect(
      form.transverseName.dy,
      lessThan(form.box.top + form.box.height * 0.25),
    );
    expect(
      form.descendingName.dx,
      greaterThan(form.box.right - form.box.width * 0.15),
    );
    expect(
      form.ileumName.dy,
      greaterThan(form.box.bottom - form.box.height * 0.15),
    );
    expect(form.appendixName.dx, lessThan(form.box.center.dx));
  });

  test('they are the same intestines every time', () {
    final IntestineForm a = _form(AnatomyFigure.male);
    final IntestineForm b = _form(AnatomyFigure.male);
    expect(a.outlinePoints, b.outlinePoints);
    expect(a.window, b.window);
    expect(a.strip, b.strip);
    expect(a.site, b.site);
    expect(a.nodules, b.nodules);
    expect(a.appendices, b.appendices);
  });
}
