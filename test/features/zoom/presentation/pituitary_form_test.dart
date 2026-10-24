import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/features/zoom/domain/anatomy_figure.dart';
import 'package:helixpeek/features/zoom/domain/anatomy_tables.dart';
import 'package:helixpeek/features/zoom/domain/zoom_depth.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/organs/brain/brain_anatomy.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/organs/pituitary/pituitary_anatomy.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/organs/pituitary/pituitary_form.dart';

final TissueAnatomy _anatomy = tissueAnatomy['pituitary gland']!;

/// The organ's view, framed by its width: the form is the same at any.
final double _view = _anatomy.metres * ZoomDepth.organMargin;

final List<AnatomyFigure> _figures = <AnatomyFigure>[
  AnatomyFigure.female,
  AnatomyFigure.male,
];

AnatomyPart _part(AnatomyFigure figure) => figure.parts[_anatomy.uberon]!;

PituitaryForm _form([
  AnatomyFigure? figure,
  PituitaryHome home = PituitaryHome.anterior,
]) => PituitaryForm.place(
  part: _part(figure ?? AnatomyFigure.female),
  anatomy: _anatomy,
  view: _view,
  home: home,
);

double _dot(Offset a, Offset b) => a.dx * b.dx + a.dy * b.dy;

bool _inside(List<Offset> polygon, Offset p) =>
    (Path()..addPolygon(polygon, true)).contains(p);

/// How far [p] is from the closed polygon [points].
double _distanceTo(List<Offset> points, Offset p) {
  double best = double.infinity;
  final int n = points.length;
  for (int i = 0; i < n; i++) {
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
      'place it is gone into on the place the body goes in, in its '
      'anterior lobe', () {
    for (final AnatomyFigure figure in _figures) {
      final String what = figure.name;
      final AnatomyPart part = _part(figure);
      final PituitaryForm form = _form(figure);
      expect(form.mm(1), closeTo(1e-3 / _view, 1e-15), reason: what);
      expect(form.anchorShift, lessThan(4), reason: what);
      final double real = _anatomy.metres / part.extent;
      final Offset site = (part.site - part.centre) * (real / _view);
      expect((form.site - site).distance, lessThan(1e-9), reason: what);
      expect(_inside(form.anterior, form.site), isTrue, reason: what);
      expect(_inside(form.posterior, form.site), isFalse, reason: what);
    }
  });

  test('its lobes, its stalk, the chiasm and the hypothalamus are the '
      'brain’s own', () {
    final PituitaryForm form = _form();
    for (final (List<Offset> drawn, List<Offset> brain)
        in <(List<Offset>, List<Offset>)>[
          (form.anterior, BrainAnatomy.pituitaryAnterior),
          (form.posterior, BrainAnatomy.pituitaryPosterior),
          (form.chiasm, BrainAnatomy.chiasm),
          (form.hypothalamus, BrainAnatomy.hypothalamus),
        ]) {
      // Their knots, every eighth point of the curve through them.
      for (int k = 0; k < brain.length; k++) {
        expect((form.toMm(drawn[k * 8]) - brain[k]).distance, lessThan(1e-6));
      }
    }
    // The stalk from the tuber cinereum to the gland.
    final Rect stalk = _bounds(<Offset>[
      for (final Offset p in form.stalk) form.toMm(p),
    ]);
    expect(stalk.top, closeTo(BrainAnatomy.infundibulum.first.dy, 2.5));
    expect(stalk.bottom, closeTo(BrainAnatomy.infundibulum.last.dy, 1.5));
  });

  test('the gland is the size measured on MRI, and rests in its fossa, '
      'the sinus under it in the bone', () {
    // 5.78 ± 1.15 mm tall and 10.25 ± 1.41 mm front to back (Saba et al.
    // 2017), within twice that.
    final Rect gland = _bounds(PituitaryAnatomy.outline);
    expect(gland.height, inInclusiveRange(5.78 - 2.3, 5.78 + 2.3));
    expect(gland.width, inInclusiveRange(10.25 - 2.82, 10.25 + 2.82));
    // About 1 cm across (Gray 1918).
    expect(gland.longestSide, inInclusiveRange(8, 12));
    for (final Offset p in PituitaryAnatomy.outline) {
      expect(_inside(PituitaryAnatomy.bone, p), isFalse, reason: '$p');
    }
    // Its floor a little over the fossa's.
    final double floor = PituitaryAnatomy.bone
        .where((Offset p) => p.dx.abs() < 3)
        .map((Offset p) => p.dy)
        .reduce(math.max);
    expect(floor - gland.bottom, inInclusiveRange(0.5, 1.6));
    // The sinus in the bone, under the fossa's floor.
    final Rect sinus = _bounds(PituitaryAnatomy.sinus);
    expect(sinus.top, lessThan(floor));
    for (final Offset p in PituitaryAnatomy.sinus.where(
      (Offset p) => p.dx.abs() < 3,
    )) {
      expect(p.dy, greaterThan(floor + 1));
    }
  });

  test('what lies above the third ventricle’s floor fades in to the chiasm; '
      'the bone shows round the fossa and fades out below and in front', () {
    final PituitaryForm form = _form();
    expect(form.brainShownAt(form.place(const Offset(0, 0))), 0);
    expect(form.brainShownAt(form.place(BrainAnatomy.chiasm.first)), 1);
    expect(form.brainShownAt(form.site), 1);
    expect(form.boneShownAt(form.place(const Offset(0, 31.8))), 1);
    expect(form.boneShownAt(form.place(const Offset(0, 42))), 0);
    expect(form.boneShownAt(form.place(const Offset(-18, 26))), 0);
    // Every part drawn round the gland, where it shows, keeps the names
    // off it.
    expect(form.drawn, isNotEmpty);
    for (final Offset p in form.drawn) {
      expect(
        math.max(form.brainShownAt(p), form.boneShownAt(p)),
        greaterThan(0.1),
      );
    }
    expect(_distanceTo(form.outlinePoints, form.site), greaterThan(0));
  });

  test('the step from the body ends on the gland’s outline, on either '
      'figure', () {
    for (final AnatomyFigure figure in _figures) {
      final PituitaryForm form = _form(figure);
      final List<Offset> gland = form.outlineAt(1);
      expect(gland.length, form.outlineAt(0).length, reason: figure.name);
      for (final Offset p in gland) {
        expect(
          _distanceTo(form.outlinePoints, p),
          lessThan(form.mm(0.05)),
          reason: figure.name,
        );
      }
    }
  });

  test('the home is told by the Atlas’s name for the cell', () {
    expect(PituitaryHome.of('Somatotropes'), PituitaryHome.anterior);
    expect(PituitaryHome.of('Gonadotropes'), PituitaryHome.anterior);
    expect(PituitaryHome.of('Pituicytes'), PituitaryHome.posterior);
    expect(PituitaryHome.of(null), PituitaryHome.anterior);
    expect(
      _form(null, PituitaryHome.posterior).homeName,
      _form().posteriorName,
    );
  });
}
