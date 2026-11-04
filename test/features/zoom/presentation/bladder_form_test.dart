import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/features/zoom/domain/anatomy_figure.dart';
import 'package:helixpeek/features/zoom/domain/anatomy_tables.dart';
import 'package:helixpeek/features/zoom/domain/zoom_depth.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/contour.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/organs/bladder/bladder_anatomy.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/organs/bladder/bladder_form.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/tube_course.dart';

final TissueAnatomy _anatomy = tissueAnatomy['urinary bladder']!;

/// The organ's view, framed by its width: the form is the same at any.
final double _view = _anatomy.metres * ZoomDepth.organMargin;

final List<AnatomyFigure> _figures = <AnatomyFigure>[
  AnatomyFigure.female,
  AnatomyFigure.male,
];

AnatomyPart _part(AnatomyFigure figure) => figure.parts[_anatomy.uberon]!;

BladderForm _form([AnatomyFigure? figure, bool withFigure = true]) =>
    BladderForm.place(
      part: _part(figure ?? AnatomyFigure.female),
      anatomy: _anatomy,
      view: _view,
      figure: withFigure ? (figure ?? AnatomyFigure.female) : null,
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

void main() {
  test('the bladder is drawn at its real size, laid on the body’s outline '
      'of it on either figure, moved a few millimetres at most to lay the '
      'place it is gone into on the place the body goes in', () {
    for (final AnatomyFigure figure in _figures) {
      final String what = figure.name;
      final AnatomyPart part = _part(figure);
      final BladderForm form = _form(figure);
      expect(form.mm(1), closeTo(1e-3 / _view, 1e-15), reason: what);
      // The card's 10 cm across, at the female anatomogram's proportions.
      expect(form.box.width / form.scale, closeTo(100, 1), reason: what);
      expect(form.box.height / form.scale, closeTo(74.6, 1), reason: what);
      expect(form.anchorShift, lessThan(3), reason: what);
      final Rect body = _bounds(form.outlineAt(0));
      for (final double edge in <double>[
        body.left - form.box.left,
        body.right - form.box.right,
        body.top - form.box.top,
        body.bottom - form.box.bottom,
      ]) {
        expect((edge / form.scale).abs(), lessThan(6), reason: what);
      }
      // Where the body goes in, which a bladder that follows the body
      // keeps.
      final double real = _anatomy.metres / part.extent;
      final Offset site = (part.site - part.centre) * (real / _view);
      expect((form.site - site).distance, lessThan(1e-9), reason: what);
      expect(form.contains(form.site), isTrue, reason: what);
    }
  });

  test('the zoom goes into the middle of its back wall, where GTEx samples '
      'it, above the trigone, between its folds, well clear of its wall, on '
      'either figure', () {
    for (final AnatomyFigure figure in _figures) {
      final String what = figure.name;
      final BladderForm form = _form(figure);
      final Offset site = form.toMm(form.site);
      expect(site.dx.abs(), lessThan(5), reason: what);
      final double down = (form.site.dy - form.box.top) / form.box.height;
      expect(down, inInclusiveRange(0.35, 0.55), reason: what);
      expect(BladderForm.clearOfTrigone(site), greaterThan(8), reason: what);
      expect(site.dy, lessThan(BladderAnatomy.rightOrifice.dy), reason: what);
      expect(BladderForm.clearOfFolds(site), greaterThan(4), reason: what);
      expect(BladderForm.clearOfWall(site), greaterThan(25), reason: what);
    }
  });

  test('its wall is as thick as it is measured, thickest in the sphincter '
      'round its neck, its detrusor and its lamina propria as deep as they '
      'are measured', () {
    const List<double> wall = BladderAnatomy.wall;
    // Over the dome and down the sides, part-filled: 2.0 ± 0.4 mm at
    // 338 mL (Kanyilmaz et al. 2013), 1.9 mm in a bladder 9 cm long or more
    // (Feinberg et al. 2026).
    for (int i = 0; i <= 17; i++) {
      expect(wall[i], inInclusiveRange(2.0 - 0.4, 2.0 + 0.4), reason: '$i');
    }
    // Thicker round the base, thickest round the neck, none at its lumen.
    final double sphincter = wall.reduce(math.max);
    for (int i = 0; i < wall.length; i++) {
      if (i < 21 || i > 23) {
        expect(wall[i], lessThan(sphincter), reason: '$i');
      }
    }
    expect(wall.last, 0);
    // Its detrusor on the sides 1.2 mm in women, 1.4 in men (Oelke et al.
    // 2006); its lamina propria within what Paner et al. (2007) measured,
    // 0.46 at the least and 3.07 at the most.
    final double side = BladderForm.wallAt(const Offset(50, -1.8));
    final double serosa = math.min(
      side * BladderAnatomy.serosaShare,
      BladderAnatomy.serosaMost,
    );
    final double lamina = math.min(
      side * BladderAnatomy.laminaShare,
      BladderAnatomy.laminaMost,
    );
    final double urothelium = math.min(
      side * BladderAnatomy.urotheliumShare,
      BladderAnatomy.urotheliumMost,
    );
    expect(side - serosa - lamina - urothelium, inInclusiveRange(1.0, 1.4));
    for (final double w in wall.where((double w) => w > 0)) {
      expect(
        math.min(w * BladderAnatomy.laminaShare, BladderAnatomy.laminaMost),
        inInclusiveRange(0.46, 3.07),
      );
    }
  });

  test('its wall’s coats lie one inside another from the serosa in, the '
      'urothelium’s surface inside them all, its detrusor in one run round '
      'it from the neck to the neck', () {
    final BladderForm form = _form();
    final List<List<Offset>> coats = form.coats;
    expect(coats, hasLength(4));
    final int n = form.serosa.length;
    for (final List<Offset> edge in coats) {
      expect(edge, hasLength(n));
    }
    for (int i = 0; i < n; i++) {
      double last = 0;
      for (final List<Offset> edge in coats) {
        final double depth = (edge[i] - form.serosa[i]).distance;
        expect(depth, greaterThanOrEqualTo(last - 1e-9));
        last = depth;
      }
      expect(
        last / form.scale,
        closeTo(BladderForm.wallAt(form.toMm(form.serosa[i])), 1e-6),
      );
    }
    expect(_area(form.inner).abs(), lessThan(_area(form.serosa).abs()));
    expect(form.muscleMiddle, hasLength(1));
  });

  test('its trigone lies between the ureters’ orifices and the urethra’s, as '
      'far apart as Gray measured them, the torus bowed up from the neck, '
      'the plicae running up and out, the urethral orifice at the lowest of '
      'it, and no fold crosses it', () {
    final BladderForm form = _form();
    double mm(Offset a, Offset b) => (a - b).distance / form.scale;
    // About 2.5 cm apart contracted, up to about 5 distended (Gray 1918).
    expect(mm(form.leftOrifice, form.rightOrifice), inInclusiveRange(25, 50));
    for (final Offset orifice in <Offset>[
      form.leftOrifice,
      form.rightOrifice,
    ]) {
      expect(mm(orifice, form.urethralOrifice), inInclusiveRange(25, 50));
      expect(form.contains(orifice), isTrue);
    }
    // Symmetric about the urethra.
    expect(
      (form.leftOrifice.dx + form.rightOrifice.dx) / 2,
      closeTo(form.urethralOrifice.dx, form.mm(0.01)),
    );
    // The torus bows up, away from the neck.
    final Offset torusMiddle = form.torus[form.torus.length ~/ 2];
    expect(torusMiddle.dy, lessThan(form.leftOrifice.dy));
    // Each plica runs up and out from its orifice.
    expect(form.plicae.first.last.dx, lessThan(form.leftOrifice.dx));
    expect(form.plicae.first.last.dy, lessThan(form.leftOrifice.dy));
    expect(form.plicae.last.last.dx, greaterThan(form.rightOrifice.dx));
    expect(form.plicae.last.last.dy, lessThan(form.rightOrifice.dy));
    // Each slit lies on its orifice, laid along its plica.
    for (int k = 0; k < 2; k++) {
      final Rect slit = _bounds(form.slits[k]);
      final Offset orifice = k == 0 ? form.leftOrifice : form.rightOrifice;
      expect((slit.center - orifice).distance, lessThan(form.mm(0.05)));
    }
    // The urethral orifice in the most dependent part, above the neck's
    // lowest point, inside the urothelium; its crescent round it.
    final Offset neck = form.serosa.reduce(
      (Offset a, Offset b) => a.dy >= b.dy ? a : b,
    );
    expect((form.urethralOrifice.dx - neck.dx).abs(), lessThan(form.mm(0.5)));
    expect(form.urethralOrifice.dy, lessThan(neck.dy));
    expect(_inside(form.inner, form.urethralOrifice), isTrue);
    for (final Offset p in form.crescent) {
      expect(_inside(form.inner, p), isTrue);
    }
    for (final List<Offset> fold in form.folds) {
      for (final Offset p in fold) {
        expect(BladderForm.clearOfTrigone(form.toMm(p)), greaterThan(1.5));
      }
    }
  });

  test('its low folds lie round its base and its lower sides, none in its '
      'upper third, inside its urothelium, never crossing', () {
    final BladderForm form = _form();
    final double upperThird = form.box.top + form.box.height / 3;
    for (int i = 0; i < form.folds.length; i++) {
      final List<Offset> fold = form.folds[i];
      for (final Offset p in fold) {
        expect(p.dy, greaterThan(upperThird), reason: 'fold $i');
        expect(
          BladderForm.clearOfWall(form.toMm(p)),
          greaterThan(1),
          reason: 'fold $i',
        );
      }
      for (int j = i + 1; j < form.folds.length; j++) {
        double nearest = double.infinity;
        for (final Offset p in fold) {
          nearest = math.min(
            nearest,
            _distanceTo(form.folds[j], p, closed: false),
          );
        }
        expect(nearest / form.scale, greaterThan(1), reason: 'folds $i, $j');
      }
    }
    expect(form.folds.length, greaterThanOrEqualTo(12));
    expect(BladderForm.foldsMm, hasLength(form.folds.length));
  });

  test('the ureters come down to it from above and to the side, and the '
      'urethra leaves its neck, each cut short; its arteries run outside it, '
      'cut short at their origins, their branches running in under its '
      'wall', () {
    final BladderForm form = _form();
    for (int k = 0; k < 2; k++) {
      final TubeCourse ureter = form.ureters[k];
      final double side = k == 0 ? -1 : 1;
      expect(form.contains(ureter.centres.first), isTrue, reason: '$k');
      expect(form.contains(ureter.centres.last), isFalse, reason: '$k');
      expect(ureter.centres.last.dy, lessThan(form.box.center.dy));
      expect(
        (ureter.centres.last.dx - form.box.center.dx) * side,
        greaterThan(form.box.width / 2),
        reason: '$k',
      );
      expect(ureter.cutEnd, isTrue);
    }
    expect(form.contains(form.urethra.centres.first), isTrue);
    expect(form.urethra.centres.last.dy, greaterThan(form.box.bottom));
    expect(form.urethra.cutEnd, isTrue);
    // About 6 mm across (Gray 1918).
    expect(2 * form.urethra.radius.first / form.scale, closeTo(6, 1e-9));
    for (int k = 0; k < form.arteries.length; k++) {
      final TubeCourse artery = form.arteries[k];
      expect(artery.cutEnd, isTrue, reason: 'artery $k');
      for (int i = 0; i < artery.length; i++) {
        expect(
          form.contains(artery.centres[i]),
          isFalse,
          reason: 'artery $k, row $i',
        );
      }
    }
    expect(form.branches.length, inInclusiveRange(6, 40));
    for (final TubeCourse branch in form.branches) {
      expect(form.contains(branch.centres.first), isFalse);
      expect(form.contains(branch.centres.last), isTrue);
    }
  });

  test('the step from the body meets the bladder’s outline and the body’s at '
      'the same places, in the same order round them from the middle of the '
      'dome', () {
    for (final AnatomyFigure figure in _figures) {
      final AnatomyPart part = _part(figure);
      final BladderForm form = _form(figure);
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

      // Both the same way round, as the morph lays them.
      final double way = _area(form.outlinePoints).sign;
      final List<Offset> bodyWay = _area(body).sign == way
          ? body
          : body.reversed.toList();
      expect(order(form.outlinePoints), order(bodyWay), reason: figure.name);
      expect(
        form.marksOf(form.outlinePoints).toSet(),
        hasLength(4),
        reason: figure.name,
      );
      // The dome's middle on the bladder's middle, on either outline.
      for (final List<Offset> points in <List<Offset>>[
        form.outlinePoints,
        bodyWay,
      ]) {
        final Offset top = form.marksOf(points).first;
        final Rect box = _bounds(points);
        expect(
          (top.dx - box.center.dx).abs(),
          lessThan(box.width * 0.04),
          reason: figure.name,
        );
        expect(top.dy - box.top, lessThan(box.height * 0.05));
      }
      // The body's outline at the hand-over, the bladder's own once
      // settled.
      final List<Offset> settled = form.outlineAt(1);
      expect(
        _bounds(settled).width,
        closeTo(form.box.width, form.mm(1)),
        reason: figure.name,
      );
    }
  });

  test('the figure’s uterus is named below it on the female figure and its '
      'prostate on the male, inside each and out from the bladder and off '
      'the urethra; nothing without a figure', () {
    for (final (AnatomyFigure figure, String word) in <(AnatomyFigure, String)>[
      (AnatomyFigure.female, 'uterus'),
      (AnatomyFigure.male, 'prostate'),
    ]) {
      final String what = figure.name;
      final BladderForm form = _form(figure);
      expect(form.neighbourWord, word, reason: what);
      final Offset at = form.neighbourName!;
      final List<Offset> shape = (form.uterusOutline ?? form.prostateOutline)!;
      expect(_inside(shape, at), isTrue, reason: what);
      expect(form.contains(at), isFalse, reason: what);
      expect(
        _distanceTo(form.outlinePoints, at) / form.scale,
        greaterThan(2),
        reason: what,
      );
      final TubeCourse urethra = form.urethra;
      expect(
        (_distanceTo(
                  <Offset>[urethra.centres.first, urethra.centres.last],
                  at,
                  closed: false,
                ) -
                urethra.radius.first) /
            form.scale,
        greaterThan(2),
        reason: what,
      );
      expect(at.dy, greaterThan(form.box.center.dy), reason: what);
    }
    final BladderForm bare = _form(AnatomyFigure.female, false);
    expect(bare.neighbourWord, isNull);
    expect(bare.neighbourName, isNull);
  });

  test('it is the same bladder every time', () {
    final BladderForm a = _form(AnatomyFigure.male);
    final BladderForm b = _form(AnatomyFigure.male);
    expect(a.outlinePoints, b.outlinePoints);
    expect(a.folds, b.folds);
    expect(a.site, b.site);
    expect(a.branches.length, b.branches.length);
    expect(a.neighbourName, b.neighbourName);
    expect(
      (a.detrusorName - a.site).distance / a.scale,
      inInclusiveRange(30, 60),
    );
    expect(a.contains(a.detrusorName), isTrue);
    expect(BladderForm.clearOfWall(a.toMm(a.detrusorName)), lessThan(0));
  });
}
