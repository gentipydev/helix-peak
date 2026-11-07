import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/features/zoom/domain/anatomy_figure.dart';
import 'package:helixpeek/features/zoom/domain/anatomy_tables.dart';
import 'package:helixpeek/features/zoom/domain/zoom_depth.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/contour.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/organs/cervix/cervix_anatomy.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/organs/cervix/cervix_form.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/tube_course.dart';

final TissueAnatomy _anatomy = tissueAnatomy['cervix']!;

/// The organ's view, framed by its width: the form is the same at any.
final double _view = _anatomy.metres * ZoomDepth.organMargin;

AnatomyPart get _part => AnatomyFigure.female.parts[_anatomy.uberon]!;

CervixForm _form() =>
    CervixForm.place(part: _part, anatomy: _anatomy, view: _view);

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

void main() {
  test('the cervix is drawn at its real size, laid on the body’s outline of '
      'it, moved a few millimetres at most to lay the place it is gone into '
      'on the place the body goes in', () {
    final CervixForm form = _form();
    expect(form.mm(1), closeTo(1e-3 / _view, 1e-15));
    // The card's 4 cm from the isthmus to the vaginal part's end, give or
    // take its round end; the uterus and the vagina cut short either side.
    const double isthmus = CervixAnatomy.internalOs;
    final double end = CervixForm.outlineMm
        .map((Offset p) => p.dy)
        .reduce(math.max);
    expect(end - isthmus, inInclusiveRange(34, 40));
    expect(form.box.height / form.scale, closeTo(end + 28, 0.5));
    // About 28 mm across its middle, wider there than at the isthmus.
    double across(double y) {
      final List<double> xs = <double>[
        for (final Offset p in CervixForm.outlineMm)
          if ((p.dy - y).abs() < 0.6) p.dx,
      ];
      return xs.reduce(math.max) - xs.reduce(math.min);
    }

    expect(across(-3), closeTo(28.4, 1));
    expect(across(-3), greaterThan(across(isthmus) + 1));
    // Laid on the body's half it follows, its own half's middle a few
    // millimetres from the body's: what laying its site on the body's site
    // costs.
    expect(form.anchorShift, lessThan(9));
    expect(form.site, form.place(CervixAnatomy.site));
    expect(form.toMm(form.site), CervixAnatomy.site);
    final double real = _anatomy.metres / _part.extent;
    expect(form.site, (_part.site - _part.centre) * (real / _view));
  });

  test('the zoom goes into the ectocervix, on the vaginal part’s surface '
      'beyond the transformation zone, as GTEx samples it', () {
    final CervixForm form = _form();
    const Offset site = CervixAnatomy.site;
    expect(CervixForm.inHome(site), isTrue);
    expect(CervixForm.inZone(site), isFalse);
    expect(CervixForm.inGroove(site), isFalse);
    // Below the vagina's attachment, on the vaginal part, just under its
    // surface: within its epithelium.
    expect(site.dy, greaterThan(CervixForm.portioTopAt(site.dx)));
    expect(
      _distanceTo(CervixForm.surfaceMm, site, closed: false),
      lessThanOrEqualTo(CervixAnatomy.epithelium),
    );
    expect(form.contains(form.site), isTrue);
  });

  test('its canal runs from the internal orifice to the external, fusiform, '
      'widest at its middle, and the uterine cavity above it narrows down to '
      'the internal orifice', () {
    expect(CervixAnatomy.externalOs - CervixAnatomy.internalOs, closeTo(34, 1));
    double widest = 0;
    double at = 0;
    for (
      double y = CervixAnatomy.internalOs;
      y <= CervixAnatomy.externalOs;
      y += 0.25
    ) {
      final double w = 2 * CervixForm.grooveAt(y);
      if (w > widest) {
        widest = w;
        at = y;
      }
    }
    expect(widest, closeTo(8, 0.2));
    expect(at, inInclusiveRange(-4, 4));
    expect(
      2 * CervixForm.grooveAt(CervixAnatomy.internalOs),
      lessThan(widest / 2),
    );
    expect(
      2 * CervixForm.grooveAt(CervixAnatomy.externalOs),
      lessThan(widest * 0.7),
    );
    // The cavity widens up from the internal orifice to where the uterus
    // is cut.
    double last = 0;
    for (
      double y = CervixAnatomy.internalOs;
      y >= CervixAnatomy.uterusCut;
      y -= 0.5
    ) {
      final double w = CervixForm.grooveAt(y);
      expect(w, greaterThanOrEqualTo(last - 1e-9), reason: '$y');
      last = w;
    }
    // Inside the cervix all its length.
    for (final Offset p in CervixForm.canalMm) {
      expect(_inside(CervixForm.outlineMm, p), isTrue, reason: '$p');
    }
  });

  test('its back wall is thrown into palmate folds running up and out from '
      'its ridge, and crypts run from its sides into the stroma, short of '
      'the deepest measured, clear of the Nabothian cysts', () {
    final List<List<Offset>> folds = CervixForm.foldsMm;
    expect(folds.length, inInclusiveRange(12, 2 * CervixAnatomy.folds));
    for (final List<Offset> fold in folds) {
      final Offset from = fold.first;
      final Offset to = fold.last;
      // Up and out, inside the canal.
      expect(to.dy, lessThan(from.dy), reason: '$from');
      expect(to.dx.abs(), greaterThan(from.dx.abs()), reason: '$from');
      for (final Offset p in fold) {
        expect(CervixForm.inGroove(p), isTrue, reason: '$p');
      }
    }
    final List<List<Offset>> crypts = CervixForm.cryptsMm;
    expect(crypts.length, inInclusiveRange(10, 24));
    for (final List<Offset> crypt in crypts) {
      final Offset from = crypt.first;
      expect(
        (from.dx.abs() - CervixForm.grooveAt(from.dy)).abs(),
        lessThan(1e-6),
        reason: '$from',
      );
      expect(
        (crypt.last - from).distance,
        lessThanOrEqualTo(CervixAnatomy.cryptMost + 1e-6),
      );
      for (final Offset p in crypt.skip(1)) {
        expect(CervixForm.inGroove(p), isFalse, reason: '$p');
        expect(_inside(CervixForm.outlineMm, p), isTrue, reason: '$p');
        for (final (Offset c, double r) in CervixAnatomy.cysts) {
          expect((p - c).distance, greaterThan(r), reason: '$p');
        }
      }
    }
    // The cysts in the stroma, clear of the canal and inside the cervix.
    for (final (Offset c, double r) in CervixAnatomy.cysts) {
      expect(c.dx.abs() - r, greaterThan(CervixForm.grooveAt(c.dy)));
      expect(_distanceTo(CervixForm.outlineMm, c), greaterThan(r + 1));
      expect(_inside(CervixForm.outlineMm, c), isTrue);
    }
  });

  test('the transformation zone lies round the canal’s end, its outer edges '
      'on the surface a few millimetres out from the external orifice', () {
    final CervixForm form = _form();
    expect(
      CervixForm.inZone(const Offset(0, CervixAnatomy.externalOs + 1)),
      isTrue,
    );
    expect(CervixForm.inZone(const Offset(0, 0)), isFalse);
    for (final List<Offset> edge in form.zoneEdges) {
      final Offset end = form.toMm(edge.last);
      expect(
        _distanceTo(CervixForm.surfaceMm, end, closed: false),
        lessThan(0.05),
      );
      expect(end.dx.abs(), inInclusiveRange(5, 9));
      final Offset start = form.toMm(edge.first);
      expect(
        start.dy,
        closeTo(CervixAnatomy.externalOs - CervixAnatomy.zoneDepth, 1e-6),
      );
    }
    for (final Offset p in form.zone) {
      expect(form.contains(p) || form.outline.contains(p), isTrue);
    }
  });

  test('the vagina is attached round its vaginal part, its fornices beside '
      'it, its lumen as wide as it is measured just below the cervix', () {
    final CervixForm form = _form();
    // Its walls' inner surfaces begin where they are attached.
    expect(CervixAnatomy.vaginaInner.first, CervixAnatomy.attachment);
    // 32.5 mm across just below the cervix (Barnhart 2006).
    double widest = 0;
    for (final Offset p in CervixAnatomy.vaginaInner) {
      widest = math.max(widest, 2 * p.dx);
    }
    expect(widest, closeTo(32.5, 1));
    // The fornix lies between the vaginal part and the wall, open below the
    // attachment.
    const Offset fornix = Offset(14.4, 6.6);
    expect(CervixForm.inLumen(fornix), isTrue);
    expect(CervixForm.inLumen(Offset(-fornix.dx, fornix.dy)), isTrue);
    // Each wall about 3.2 mm thick.
    for (int i = 2; i < CervixAnatomy.vaginaInner.length; i++) {
      final Offset inner = CervixAnatomy.vaginaInner[i];
      expect(
        _distanceTo(CervixAnatomy.vaginaOuter, inner, closed: false),
        closeTo(3.2, 0.6),
        reason: '$inner',
      );
    }
    expect(form.walls, hasLength(2));
    expect(
      _inside(form.vaginaOutline, form.place(const Offset(0, 24))),
      isTrue,
    );
  });

  test('the uterine arteries come in to the cervix’s margin at the isthmus '
      'and run up beside the uterus and down beside the cervix and the '
      'vagina, outside them, each cut short; their small branches run in '
      'under the wall', () {
    final CervixForm form = _form();
    expect(form.arteries, hasLength(6));
    final Path vagina = Path()..addPolygon(form.vaginaOutline, true);
    for (final TubeCourse artery in form.arteries) {
      expect(artery.cutStart || artery.cutEnd, isTrue);
      for (int i = 0; i < artery.length; i++) {
        final Offset c = artery.centres[i];
        expect(form.contains(c), isFalse, reason: '$c');
        expect(vagina.contains(c), isFalse, reason: '$c');
      }
    }
    // The trunks meet the margin at the isthmus.
    for (final TubeCourse trunk in form.arteries.take(2)) {
      final Offset meets = form.toMm(trunk.centres.last);
      expect(meets.dy, closeTo(CervixAnatomy.internalOs, 1));
      expect(
        _distanceTo(CervixForm.outlineMm, meets),
        lessThan(CervixAnatomy.rightUterine.radii.last + 2.5),
      );
    }
    expect(form.branches.length, inInclusiveRange(4, 24));
    for (final TubeCourse branch in form.branches) {
      expect(form.contains(branch.centres.first), isFalse);
      expect(form.contains(branch.centres.last), isTrue);
    }
  });

  test('the step from the body meets the cervix’s half and the body’s '
      'outline at the same places, in the same order round them from the '
      'middle of the top', () {
    final CervixForm form = _form();
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

    final double way = _area(form.halfPoints).sign;
    final List<Offset> bodyWay = _area(body).sign == way
        ? body
        : body.reversed.toList();
    expect(order(form.halfPoints), order(bodyWay));
    expect(form.marksOf(form.halfPoints).toSet(), hasLength(4));
    // The top's middle on each outline's top.
    for (final List<Offset> points in <List<Offset>>[
      form.halfPoints,
      bodyWay,
    ]) {
      final Offset top = form.marksOf(points).first;
      final Rect box = _bounds(points);
      expect(top.dy - box.top, lessThan(box.height * 0.2));
    }
    // The body's outline at the hand-over, the cervix's half once settled:
    // its canal and the wall on the body's left.
    final Rect settled = _bounds(form.outlineAt(1));
    expect(settled.width, closeTo(_bounds(form.halfPoints).width, form.mm(1)));
    expect(form.outlineAt(0), isNotEmpty);
    expect(form.others, hasLength(1));
  });

  test('it is the same cervix every time', () {
    final CervixForm a = _form();
    final CervixForm b = _form();
    expect(a.outlinePoints, b.outlinePoints);
    expect(a.halfPoints, b.halfPoints);
    expect(a.crypts, b.crypts);
    expect(a.folds, b.folds);
    expect(a.site, b.site);
    expect(a.branches.length, b.branches.length);
    expect(a.homeName, b.homeName);
    // Its names point where they say.
    expect(CervixForm.inHome(a.toMm(a.homeName)), isTrue);
    expect(CervixForm.inGroove(a.toMm(a.canalName)), isTrue);
    expect(CervixForm.inZone(a.toMm(a.zoneName)), isTrue);
    expect(CervixForm.inLumen(a.toMm(a.vaginaName)), isTrue);
    expect(a.contains(a.uterusName), isTrue);
    expect(a.toMm(a.uterusName).dy, lessThan(CervixAnatomy.internalOs));
    expect(CervixForm.inGroove(a.toMm(a.uterusName)), isFalse);
  });
}
