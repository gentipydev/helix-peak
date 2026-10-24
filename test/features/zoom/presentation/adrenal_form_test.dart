import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/features/zoom/domain/anatomy_figure.dart';
import 'package:helixpeek/features/zoom/domain/anatomy_tables.dart';
import 'package:helixpeek/features/zoom/domain/zoom_depth.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/organs/adrenal/adrenal_anatomy.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/organs/adrenal/adrenal_form.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/tube_course.dart';

final TissueAnatomy _anatomy = tissueAnatomy['adrenal gland']!;

/// The organ's view, framed by its width: the form is the same at any.
final double _view = _anatomy.metres * ZoomDepth.organMargin;

final List<AnatomyFigure> _figures = <AnatomyFigure>[
  AnatomyFigure.female,
  AnatomyFigure.male,
];

AnatomyPart _part(AnatomyFigure figure) => figure.parts[_anatomy.uberon]!;

AdrenalForm _form(
  AnatomyFigure figure, [
  AdrenalHome home = AdrenalHome.cortex,
]) => AdrenalForm.place(
  part: _part(figure),
  anatomy: _anatomy,
  view: _view,
  figure: figure,
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

void main() {
  test('the gland is drawn at its real size, laid on the body’s outline of '
      'it on either figure, moved a few millimetres at most to lay the '
      'place it is gone into on the place the body goes in', () {
    for (final AnatomyFigure figure in _figures) {
      final String what = figure.name;
      final AnatomyPart part = _part(figure);
      final AdrenalForm form = _form(figure);
      expect(form.mm(1), closeTo(1e-3 / _view, 1e-15), reason: what);
      expect(form.anchorShift, lessThan(8), reason: what);
      final double real = _anatomy.metres / part.extent;
      final Offset site = (part.site - part.centre) * (real / _view);
      expect((form.site - site).distance, lessThan(1e-9), reason: what);
      expect(form.contains(form.site), isTrue, reason: what);
      // In the cortex, clear of the medulla and of the capsule.
      expect(_inside(form.medulla, form.site), isFalse, reason: what);
      expect(
        _distanceTo(form.medulla, form.site) / form.scale,
        greaterThan(2),
        reason: what,
      );
      expect(
        _distanceTo(form.outlinePoints, form.site) / form.scale,
        greaterThan(2),
        reason: what,
      );
    }
  });

  test('the body’s right gland is the right one, its medial side toward the '
      'midline; its left, on the male figure, the left one turned over', () {
    final AdrenalForm right = _form(AnatomyFigure.female);
    final AdrenalForm left = _form(AnatomyFigure.male);
    expect(right.right, isTrue);
    expect(left.right, isFalse);
    // The right gland's vein runs toward the midline; the left's down.
    final TubeCourse rv = right.vein;
    expect(
      (rv.centres.last.dx - rv.centres.first.dx) * right.side,
      greaterThan(right.mm(8)),
    );
    final TubeCourse lv = left.vein;
    expect(lv.centres.last.dy - lv.centres.first.dy, greaterThan(left.mm(8)));
  });

  test('its parts are the sizes they are measured at, the medulla inside '
      'the cortex, the zona reticularis’s edge between them', () {
    // 3 to 5 cm long, rather less wide (Gray 1918).
    for (final List<Offset> outline in <List<Offset>>[
      AdrenalAnatomy.rightOutline,
      AdrenalAnatomy.leftOutline,
    ]) {
      final Rect box = _bounds(outline);
      expect(box.longestSide, inInclusiveRange(30, 50.5));
      expect(box.shortestSide, lessThan(box.longestSide));
    }
    expect(
      _bounds(AdrenalAnatomy.rightOutline).width,
      closeTo(AdrenalAnatomy.rightWidth, 0.5),
    );
    expect(
      _bounds(AdrenalAnatomy.leftOutline).height,
      closeTo(AdrenalAnatomy.leftHeight, 0.5),
    );
    for (final AnatomyFigure figure in _figures) {
      final AdrenalForm form = _form(figure);
      for (final Offset p in form.medulla) {
        expect(form.contains(p), isTrue, reason: figure.name);
        expect(
          _distanceTo(form.outlinePoints, p) / form.scale,
          greaterThan(1.5),
          reason: figure.name,
        );
      }
      for (final Offset p in form.reticularis) {
        expect(form.contains(p), isTrue, reason: figure.name);
        expect(_inside(form.medulla, p), isFalse, reason: figure.name);
      }
    }
  });

  test('the central vein runs from the medulla through the cut to its '
      'hilum and on out of it, cut short; each artery comes in to its edge, '
      'fading out toward where it comes from', () {
    for (final AnatomyFigure figure in _figures) {
      final String what = figure.name;
      final AdrenalForm form = _form(figure);
      expect(
        _inside(form.medulla, form.channel.centres.first) ||
            _distanceTo(form.medulla, form.channel.centres.first) < form.mm(1),
        isTrue,
        reason: what,
      );
      expect(
        _distanceTo(form.outlinePoints, form.channel.centres.last) / form.scale,
        lessThan(1.5),
        reason: what,
      );
      expect(
        (form.vein.centres.first - form.channel.centres.last).distance /
            form.scale,
        lessThan(1.5),
        reason: what,
      );
      expect(form.contains(form.vein.centres.last), isFalse, reason: what);
      expect(form.vein.cutEnd, isTrue, reason: what);
      for (final TubeCourse a in form.arteries) {
        expect(
          _distanceTo(form.outlinePoints, a.centres.last) / form.scale,
          lessThan(1.5),
          reason: what,
        );
        expect(form.contains(a.centres.first), isFalse, reason: what);
        expect(a.shown.first, lessThan(0.01), reason: what);
      }
    }
  });

  test('under it lies the body’s own kidney, its upper pole whole, fading '
      'out below; and it is named there', () {
    for (final AnatomyFigure figure in _figures) {
      final String what = figure.name;
      final AdrenalForm form = _form(figure);
      final List<Offset> kidney = form.kidney!;
      final Rect k = _bounds(kidney);
      expect(k.center.dy, greaterThan(form.box.center.dy), reason: what);
      expect(k.top, lessThan(form.box.bottom), reason: what);
      expect(form.kidneyShownAt(k.top), 1, reason: what);
      expect(
        form.kidneyShownAt(
          k.top + form.mm(AdrenalAnatomy.poleShown + AdrenalAnatomy.poleFade),
        ),
        0,
        reason: what,
      );
      expect(_inside(kidney, form.kidneyName!), isTrue, reason: what);
      expect(form.contains(form.kidneyName!), isFalse, reason: what);
    }
  });

  test('the step from the body ends on the gland’s outline, on either '
      'figure', () {
    for (final AnatomyFigure figure in _figures) {
      final AdrenalForm form = _form(figure);
      final List<Offset> gland = form.outlineAt(1);
      expect(gland.length, form.outlineAt(0).length, reason: figure.name);
      for (final Offset p in gland) {
        expect(
          _distanceTo(form.outlinePoints, p),
          lessThan(form.mm(0.2)),
          reason: figure.name,
        );
      }
    }
  });

  test('the home is told by the Atlas’s name for the cell', () {
    expect(AdrenalHome.of('Adrenal cortex cells'), AdrenalHome.cortex);
    expect(AdrenalHome.of('Chromaffin cells'), AdrenalHome.medulla);
    expect(AdrenalHome.of('Adrenal medulla cells'), AdrenalHome.medulla);
    expect(AdrenalHome.of('Fibroblasts'), AdrenalHome.cortex);
    expect(AdrenalHome.of(null), AdrenalHome.cortex);
  });
}
