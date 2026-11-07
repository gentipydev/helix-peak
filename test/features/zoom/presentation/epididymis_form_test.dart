import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/features/zoom/domain/anatomy_figure.dart';
import 'package:helixpeek/features/zoom/domain/anatomy_tables.dart';
import 'package:helixpeek/features/zoom/domain/zoom_depth.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/contour.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/organs/epididymis/epididymis_anatomy.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/organs/epididymis/epididymis_form.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/tube_course.dart';

final TissueAnatomy _anatomy = tissueAnatomy['epididymis']!;

/// The organ's view, framed by its width: the form is the same at any.
final double _view = _anatomy.metres * ZoomDepth.organMargin;

AnatomyPart get _part => AnatomyFigure.male.parts[_anatomy.uberon]!;

EpididymisForm _form([EpididymisHome home = EpididymisHome.duct]) =>
    EpididymisForm.place(
      part: _part,
      anatomy: _anatomy,
      view: _view,
      home: home,
    );

double _dot(Offset a, Offset b) => a.dx * b.dx + a.dy * b.dy;

bool _inside(List<Offset> polygon, Offset p) =>
    (Path()..addPolygon(polygon, true)).contains(p);

/// How far [p] is from the closed polygon or open line [points].
double _distanceTo(List<Offset> points, Offset p, {bool closed = true}) {
  double best = double.infinity;
  final int n = points.length;
  for (int i = 0; i < (closed ? n : n - 1); i++) {
    final Offset a = points[i];
    final Offset b = points[(i + 1) % n];
    final Offset ab = b - a;
    final double length = _dot(ab, ab);
    final double t = length == 0
        ? 0
        : (_dot(p - a, ab) / length).clamp(0.0, 1.0);
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

/// How thick the epididymis is where [where] holds: twice the furthest any
/// point there lies from its outline.
double _thickness(bool Function(Offset) where) {
  double deepest = 0;
  for (double y = -27; y <= 27; y += 0.1) {
    for (double x = -14; x <= 14; x += 0.1) {
      final Offset p = Offset(x, y);
      if (!where(p) || !_inside(EpididymisForm.outlineMm, p)) {
        continue;
      }
      deepest = math.max(deepest, _distanceTo(EpididymisForm.outlineMm, p));
    }
  }
  return 2 * deepest;
}

void main() {
  test('the epididymis is drawn at its real size, laid on the body’s '
      'outline of it, moved a few millimetres at most to lay the place it '
      'is gone into on the place the body goes in', () {
    final EpididymisForm form = _form();
    expect(form.mm(1), closeTo(1e-3 / _view, 1e-15));
    // About the card's 5 cm from its head's top to its tail's lowest point.
    final Rect box = _bounds(EpididymisForm.outlineMm);
    expect(box.height, inInclusiveRange(50, 55));
    expect(form.box.height / form.scale, closeTo(box.height, 1e-6));
    // Laid on the body's band, its middle a few millimetres from the band's:
    // the head it bulges forward over the testis with is not in the band.
    expect(form.anchorShift, lessThan(7.5));
    expect(form.site, form.place(EpididymisAnatomy.site));
    expect(form.toMm(form.site), EpididymisAnatomy.site);
    final double real = _anatomy.metres / _part.extent;
    expect(form.site, (_part.site - _part.centre) * (real / _view));
  });

  test('its head is at most 12 mm thick, its tail at most 6, its body '
      'narrow, as ultrasound measures them', () {
    final double head = _thickness(EpididymisForm.inHead);
    expect(head, inInclusiveRange(7, 12));
    final double body = _thickness(
      (Offset p) => p.dy > -5 && p.dy < 12 && EpididymisForm.inDuct(p),
    );
    expect(body, inInclusiveRange(4, 5.5));
    final double tail = _thickness(
      (Offset p) => p.dy > 19 && EpididymisForm.inDuct(p),
    );
    expect(tail, inInclusiveRange(4.5, 6.5));
    expect(head, greaterThan(body + 3));
  });

  test('it lies on the lateral edge of its testis’s back, the testis whole '
      'beside it, its upper pole forward, about 17 ml', () {
    final List<Offset> testis = EpididymisForm.testisMm;
    final Rect box = _bounds(testis);
    expect(2 * EpididymisAnatomy.testisHalfLength, inInclusiveRange(40, 50));
    expect(2 * EpididymisAnatomy.testisHalfDepth, closeTo(30, 0.5));
    // An ellipsoid of its length, its depth and Gray's 2.5 cm breadth.
    const double ml =
        math.pi /
        6 *
        (2 * EpididymisAnatomy.testisHalfLength) *
        (2 * EpididymisAnatomy.testisHalfDepth) *
        25 /
        1000;
    expect(ml, inInclusiveRange(15, 20));
    // Its upper pole forward of its lower.
    final Offset top = testis.reduce(
      (Offset a, Offset b) => a.dy < b.dy ? a : b,
    );
    final Offset bottom = testis.reduce(
      (Offset a, Offset b) => a.dy > b.dy ? a : b,
    );
    expect(top.dx, greaterThan(bottom.dx));
    // The epididymis's front edge over the testis, its back outside it;
    // the testis forward of it.
    for (final Offset p in <Offset>[
      for (int i = 8; i < 120; i += 8)
        EpididymisForm.outlineMm[EpididymisAnatomy.frontFrom * 8 + i],
    ]) {
      expect(_inside(testis, p), isTrue, reason: '$p');
    }
    expect(
      _inside(testis, Offset(_bounds(EpididymisForm.outlineMm).left + 0.5, 0)),
      isFalse,
    );
    expect(box.center.dx, greaterThan(0));
  });

  test('the zoom goes into its duct just below its head, where the '
      'efferent ductules have opened into it', () {
    final EpididymisForm form = _form();
    const Offset site = EpididymisAnatomy.site;
    expect(EpididymisForm.inDuct(site), isTrue);
    expect(EpididymisForm.inHead(site), isFalse);
    expect(form.contains(form.site), isTrue);
    // Within a few millimetres of where the head ends.
    const Offset toward = EpididymisAnatomy.towardHead;
    final double below =
        -_dot(site - EpididymisAnatomy.headEnd, toward) / toward.distance;
    expect(below, inInclusiveRange(1, 4));
  });

  test('the head is cones of coiled efferent ductules, each from the '
      'head’s underside, where the ductules come up out of the testis, to '
      'its top or back, each ductule in its own cone', () {
    expect(EpididymisAnatomy.cones, inInclusiveRange(8, 20));
    expect(EpididymisForm.conesMm, hasLength(EpididymisAnatomy.cones));
    expect(EpididymisForm.ductulesMm, hasLength(EpididymisAnatomy.cones));
    expect(EpididymisForm.coneSeptaMm, hasLength(EpididymisAnatomy.cones - 1));
    double coneArea = 0;
    for (int k = 0; k < EpididymisAnatomy.cones; k++) {
      final List<Offset> cone = EpididymisForm.conesMm[k];
      coneArea += _area(cone).abs();
      // Its apex, on the underside, over the testis.
      expect(_inside(EpididymisForm.testisMm, cone.first), isTrue);
      final List<Offset> ductule = EpididymisForm.ductulesMm[k];
      expect(ductule.length, greaterThan(20), reason: 'cone $k');
      for (final Offset p in ductule) {
        expect(EpididymisForm.inHead(p), isTrue, reason: 'cone $k: $p');
        expect(EpididymisForm.coneOf(p), k, reason: 'cone $k: $p');
        expect(
          _distanceTo(EpididymisForm.outlineMm, p),
          greaterThan(EpididymisAnatomy.tunica),
          reason: 'cone $k: $p',
        );
      }
      // It swings from side to side of its cone as it runs out.
      int turns = 0;
      for (int i = 2; i < ductule.length; i++) {
        final Offset a = ductule[i - 1] - ductule[i - 2];
        final Offset b = ductule[i] - ductule[i - 1];
        if ((a.dx * b.dy - a.dy * b.dx).abs() > 1e-6 &&
            i > 2 &&
            ((a.dx * b.dy - a.dy * b.dx) > 0) !=
                (((ductule[i - 2] - ductule[i - 3]).dx * a.dy -
                        (ductule[i - 2] - ductule[i - 3]).dy * a.dx) >
                    0)) {
          turns++;
        }
      }
      expect(turns, greaterThan(4), reason: 'cone $k');
    }
    // Together they are the head.
    final double headArea = _area(EpididymisForm.headMm).abs();
    expect(coneArea, closeTo(headArea, headArea * 1e-6));
    for (final List<Offset> septum in EpididymisForm.coneSeptaMm) {
      expect(septum, hasLength(2));
      expect(EpididymisForm.inHead(septum.first), isTrue);
      expect(EpididymisForm.inHead(septum.last), isTrue);
    }
  });

  test('the duct is cut across its coils in the body and the tail, in '
      'segments, its profiles clear of one another and of the edges, '
      'wider toward the tail', () {
    final List<DuctProfile> profiles = EpididymisForm.profilesMm;
    expect(profiles.length, inInclusiveRange(60, 200));
    expect(
      EpididymisForm.ductSeptaMm,
      hasLength(EpididymisAnatomy.septa.length),
    );
    for (final List<Offset> septum in EpididymisForm.ductSeptaMm) {
      // Each runs across the duct, from outside its front edge to outside
      // its back.
      expect(EpididymisForm.inDuct(septum.first), isFalse);
      expect(EpididymisForm.inDuct(septum.last), isFalse);
      expect(septum.any(EpididymisForm.inDuct), isTrue);
    }
    for (final DuctProfile p in profiles) {
      expect(EpididymisForm.inDuct(p.at), isTrue, reason: '${p.at}');
      expect(p.long, greaterThanOrEqualTo(p.short));
      expect(
        p.long,
        lessThanOrEqualTo(
          EpididymisAnatomy.profileTail * EpididymisAnatomy.profileLong + 1e-9,
        ),
      );
      expect(
        _distanceTo(EpididymisForm.outlineMm, p.at),
        greaterThan(p.long + EpididymisAnatomy.tunica),
        reason: '${p.at}',
      );
      for (final List<Offset> septum in EpididymisForm.ductSeptaMm) {
        expect(
          _distanceTo(septum, p.at, closed: false),
          greaterThan(p.long),
          reason: '${p.at}',
        );
      }
    }
    for (int i = 0; i < profiles.length; i++) {
      for (int j = i + 1; j < profiles.length; j++) {
        // No two overlap: each within the discs it was laid by.
        expect(
          (profiles[i].at - profiles[j].at).distance,
          greaterThan(profiles[i].short + profiles[j].short),
        );
      }
    }
    double mean(Iterable<DuctProfile> ps) =>
        ps
            .map((DuctProfile p) => p.short)
            .reduce((double a, double b) => a + b) /
        ps.length;
    expect(
      mean(profiles.where((DuctProfile p) => p.at.dy > 15)),
      greaterThan(mean(profiles.where((DuctProfile p) => p.at.dy < 0))),
    );
  });

  test('the tunica’s inner face lies just inside the outline all round', () {
    for (final Offset p in EpididymisForm.tunicaMm) {
      expect(_inside(EpididymisForm.outlineMm, p), isTrue, reason: '$p');
      expect(
        _distanceTo(EpididymisForm.outlineMm, p),
        closeTo(EpididymisAnatomy.tunica, 0.05),
      );
    }
  });

  test('the vas deferens begins under the tail and rises behind the body '
      'into the cord, with the testicular artery and the pampiniform '
      'plexus, which go in under the head; each fades out above', () {
    final EpididymisForm form = _form();
    final TubeCourse vas = form.vas;
    expect(form.contains(vas.centres.first), isTrue);
    expect(vas.shown.first, 1);
    expect(vas.shown.last, lessThan(0.05));
    // Behind the body: at the body's middle, further back than its back
    // edge's middle.
    final Rect box = _bounds(EpididymisForm.outlineMm);
    int at = 0;
    for (int i = 0; i < vas.length; i++) {
      if ((form.toMm(vas.centres[i]).dy - 5).abs() <
          (form.toMm(vas.centres[at]).dy - 5).abs()) {
        at = i;
      }
    }
    expect(form.toMm(vas.centres[at]).dx, lessThan(box.left + 1));
    // Above the head it fades out.
    expect(form.toMm(vas.centres.last).dy, lessThan(box.top));
    for (final TubeCourse vessel in <TubeCourse>[form.artery, ...form.veins]) {
      expect(vessel.shown.first, lessThan(0.05));
      expect(vessel.shown.last, 1);
      // Its end, where it goes in, under the head or over the testis.
      final Offset end = form.toMm(vessel.centres.last);
      expect(
        _inside(EpididymisForm.outlineMm, end) ||
            _inside(EpididymisForm.testisMm, end),
        isTrue,
        reason: '$end',
      );
    }
  });

  test('the step from the body meets the epididymis’s outline and the '
      'body’s at the same places, in the same order round them from the '
      'top', () {
    final EpididymisForm form = _form();
    final double real = _anatomy.metres / _part.extent;
    final List<Offset> body = Contour(<Offset>[
      for (final Offset p in _part.followed)
        (p - _part.centre) * (real / _view),
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
    expect(order(form.outlinePoints), order(bodyWay));
    expect(form.marksOf(form.outlinePoints).toSet(), hasLength(4));
    // The body's outline at the hand-over, the epididymis's once settled.
    final Rect settled = _bounds(form.outlineAt(1));
    expect(settled.width, closeTo(form.box.width, form.mm(1)));
    expect(form.outlineAt(0), isNotEmpty);
  });

  test('where the zoom’s cell lives is chosen by the Atlas’s name for it', () {
    for (final String cell in <String>[
      'Epididymal principal cells',
      'Epididymal clear cells',
      'Epididymal basal cells',
    ]) {
      expect(EpididymisHome.of(cell), EpididymisHome.duct, reason: cell);
    }
    for (final String cell in <String>[
      'Epididymal efferent duct ciliated cells',
      'Epididymal efferent duct absorptive cells',
    ]) {
      expect(EpididymisHome.of(cell), EpididymisHome.ductules, reason: cell);
    }
    expect(EpididymisHome.of(null), EpididymisHome.duct);
    expect(EpididymisHome.of('Macrophages'), EpididymisHome.duct);
  });

  test('it is the same epididymis every time, and its names point where '
      'they say', () {
    final EpididymisForm a = _form();
    final EpididymisForm b = _form();
    expect(a.outlinePoints, b.outlinePoints);
    expect(a.profiles, b.profiles);
    expect(a.ductules, b.ductules);
    expect(a.site, b.site);
    // The duct at the site, the ductules in the head's middle cone.
    expect(a.homeName, a.site);
    expect(EpididymisForm.inHead(a.toMm(a.otherName)), isTrue);
    // For a cell of the ductules, the cone nearest the site, and the duct in
    // the body's middle.
    final EpididymisForm c = _form(EpididymisHome.ductules);
    expect(EpididymisForm.inHead(c.toMm(c.homeName)), isTrue);
    expect((c.toMm(c.homeName) - EpididymisAnatomy.site).distance, lessThan(6));
    expect(EpididymisForm.inDuct(c.toMm(c.otherName)), isTrue);
    // The tail in the tail, the testis on the testis, the vas on the vas.
    expect(EpididymisForm.inDuct(a.toMm(a.tailName)), isTrue);
    expect(a.toMm(a.tailName).dy, greaterThan(18));
    expect(_inside(EpididymisForm.testisMm, a.toMm(a.testisName)), isTrue);
    expect(a.contains(a.testisName), isFalse);
    final TubeCourse vas = a.vas;
    double nearest = double.infinity;
    for (final Offset c in vas.centres) {
      nearest = math.min(nearest, (c - a.vasName).distance);
    }
    expect(nearest, lessThan(a.mm(0.5)));
  });
}
