import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/features/zoom/domain/anatomy_figure.dart';
import 'package:helixpeek/features/zoom/domain/anatomy_tables.dart';
import 'package:helixpeek/features/zoom/domain/zoom_depth.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/contour.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/organs/thyroid/thyroid_anatomy.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/organs/thyroid/thyroid_form.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/tube_course.dart';

final TissueAnatomy _anatomy = tissueAnatomy['thyroid gland']!;

/// The organ's view, framed by its width: the form is the same at any.
final double _view = _anatomy.metres * ZoomDepth.organMargin;

final List<AnatomyFigure> _figures = <AnatomyFigure>[
  AnatomyFigure.female,
  AnatomyFigure.male,
];

AnatomyPart _part(AnatomyFigure figure) => figure.parts[_anatomy.uberon]!;

ThyroidForm _form([
  AnatomyFigure? figure,
  ThyroidHome home = ThyroidHome.follicles,
]) => ThyroidForm.place(
  part: _part(figure ?? AnatomyFigure.female),
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

/// The x at which the course [tube] runs at the height [y], in its knots'
/// millimetres.
double _xAt(AnatomyTube tube, double y) {
  final List<Offset> k = tube.points;
  for (int i = 0; i + 1 < k.length; i++) {
    final Offset a = k[i];
    final Offset b = k[i + 1];
    if ((a.dy - y) * (b.dy - y) <= 0 && a.dy != b.dy) {
      return a.dx + (b.dx - a.dx) * (y - a.dy) / (b.dy - a.dy);
    }
  }
  return double.nan;
}

void main() {
  test('the gland is drawn at its real size, laid on the body’s outline of '
      'it on either figure, moved a few millimetres at most to lay the '
      'place it is gone into on the place the body goes in', () {
    for (final AnatomyFigure figure in _figures) {
      final String what = figure.name;
      final AnatomyPart part = _part(figure);
      final ThyroidForm form = _form(figure);
      expect(form.mm(1), closeTo(1e-3 / _view, 1e-15), reason: what);
      expect(
        form.box.width / form.scale,
        closeTo(ThyroidAnatomy.width, 1),
        reason: what,
      );
      expect(form.anchorShift, lessThan(4), reason: what);
      final Rect body = _bounds(form.outlineAt(0));
      for (final double edge in <double>[
        body.left - form.box.left,
        body.right - form.box.right,
        body.top - form.box.top,
        body.bottom - form.box.bottom,
      ]) {
        expect((edge / form.scale).abs(), lessThan(14), reason: what);
      }
      // Where the body goes in, which a gland that follows the body keeps,
      // in the lobe it cuts open.
      final double real = _anatomy.metres / part.extent;
      final Offset site = (part.site - part.centre) * (real / _view);
      expect((form.site - site).distance, lessThan(1e-9), reason: what);
      expect(form.contains(form.site), isTrue, reason: what);
      expect(_inside(form.face, form.site), isTrue, reason: what);
    }
  });

  test('the lobe cut open is the one the body goes into, its right one on '
      'either figure, on the left as the body shows it', () {
    for (final AnatomyFigure figure in _figures) {
      final ThyroidForm form = _form(figure);
      expect(form.flip, 1, reason: figure.name);
      final Rect face = _bounds(form.face);
      expect(face.right, lessThan(form.box.center.dx), reason: figure.name);
    }
  });

  test('its parts are the sizes they are measured at, where Gray 1918 '
      'places them', () {
    final Rect lobe = _bounds(ThyroidAnatomy.cutRun);
    // Each lobe about 5 cm long (Gray 1918); 20 mm across, so that two of
    // them hold Hegedüs et al.'s 17.5 ± 4.2 ml as ellipsoids.
    expect(lobe.height, inInclusiveRange(48, 56));
    expect(ThyroidAnatomy.lobeLength, closeTo(lobe.height, 0.5));
    final double across = -lobe.left - 6;
    expect(across, inInclusiveRange(20, 24));
    const double ml = 2 * math.pi / 6 * 50 * 20 * 17 / 1000;
    expect(ml, inInclusiveRange(17.5 - 4.2, 17.5 + 4.2));
    // The isthmus 1.25 cm across, over the second and third rings.
    final double isthmus =
        ThyroidAnatomy.isthmusFoot[1].dy - ThyroidAnatomy.isthmusTop[1].dy;
    expect(isthmus, closeTo(12.5, 0.5));
    double ringTop(int k) =>
        ThyroidAnatomy.ringTop + (k - 1) * ThyroidAnatomy.ringPitch;
    expect(ThyroidAnatomy.isthmusTop[1].dy, lessThanOrEqualTo(ringTop(2)));
    expect(
      ThyroidAnatomy.isthmusFoot[1].dy,
      greaterThanOrEqualTo(ringTop(3) + ThyroidAnatomy.ringDepth),
    );
    // The lobes' apices as high as the junction of the middle and lower
    // thirds of the thyroid cartilage; their bases level with the fifth or
    // sixth ring.
    final double cartilageTop = ThyroidAnatomy.cartilageHalf
        .map((Offset p) => p.dy)
        .reduce(math.min);
    final double cartilageFoot = ThyroidAnatomy.cartilageHalf
        .map((Offset p) => p.dy)
        .reduce(math.max);
    final double third = cartilageTop + (cartilageFoot - cartilageTop) * 2 / 3;
    expect(lobe.top, closeTo(third, 3));
    expect(lobe.bottom, inInclusiveRange(ringTop(5), ringTop(7)));
    // The laminae 27 ± 1.4 mm tall (Vadgaonkar et al. 2024), from the
    // superior tubercle down to the inferior.
    expect(
      ThyroidAnatomy.cartilageHalf[17].dy - ThyroidAnatomy.cartilageHalf[5].dy,
      inInclusiveRange(27 - 1.4, 27 + 1.4),
    );
    // The rings about 4 mm deep, sixteen to twenty in 11 cm (Gray 1918).
    expect(ThyroidAnatomy.ringDepth, 4);
    expect(110 / ThyroidAnatomy.ringPitch, inInclusiveRange(16, 20));
    // The trachea's lumen 14.8 ± 2.0 mm across in women (Zahedi-Nejad et
    // al. 2011), inside walls of 1.8 mm.
    expect(
      2 * ThyroidAnatomy.trachea.radii.first - 2 * 1.8,
      inInclusiveRange(14.8 - 2, 14.8 + 2),
    );
    // The common carotid 6.10 ± 0.80 mm, the internal 4.66 ± 0.78 mm, in
    // women (Krejza et al. 2006).
    for (final double r in ThyroidAnatomy.carotid.radii) {
      expect(2 * r, inInclusiveRange(6.1 - 0.8, 6.1 + 0.8));
    }
    expect(
      2 * ThyroidAnatomy.internalCarotid.radii.last,
      inInclusiveRange(4.66 - 0.78, 4.66 + 0.78),
    );
  });

  test('the carotid divides opposite the thyroid cartilage’s upper border, '
      'the jugular lateral to it, under the lobe’s lateral border; the '
      'middle thyroid vein runs from the lobe across it into the jugular; '
      'the superior thyroid artery leaves the external carotid for the '
      'apex', () {
    final double border = ThyroidAnatomy.cartilageHalf[5].dy;
    expect(ThyroidAnatomy.carotid.points.first.dy, closeTo(border, 1.5));
    for (final double y in <double>[0, 20, 40, 60]) {
      final double artery = _xAt(ThyroidAnatomy.carotid, y);
      final double vein = _xAt(ThyroidAnatomy.jugular, y);
      expect(vein, lessThan(artery - 4), reason: 'at $y');
    }
    // The lobe's lateral border overlaps the artery's medial side.
    final Rect lobe = _bounds(ThyroidAnatomy.cutRun);
    final double artery = _xAt(ThyroidAnatomy.carotid, 50);
    expect(lobe.left, lessThan(artery + ThyroidAnatomy.carotid.radii.first));
    expect(lobe.left, greaterThan(artery - ThyroidAnatomy.carotid.radii.first));
    // The middle vein, from the lobe's border to inside the jugular.
    const AnatomyTube middle = ThyroidAnatomy.middleVein;
    expect(
      _distanceTo(ThyroidAnatomy.cutRun, middle.points.first, closed: false),
      lessThan(1.5),
    );
    final double jugular = _xAt(ThyroidAnatomy.jugular, middle.points.last.dy);
    expect(
      (middle.points.last.dx - jugular).abs(),
      lessThan(ThyroidAnatomy.jugular.radii.first),
    );
    // The superior thyroid artery off the external carotid, ending at the
    // apex the cut takes.
    expect(
      _distanceTo(
        ThyroidAnatomy.externalCarotid.points,
        ThyroidAnatomy.superiorArtery.points.first,
        closed: false,
      ),
      lessThan(ThyroidAnatomy.externalCarotid.radii.first),
    );
    expect(
      (ThyroidAnatomy.superiorArtery.points.last - const Offset(-16, 14))
          .distance,
      lessThan(1.5),
    );
    // The branch across the isthmus's upper border, and the inferior veins
    // leaving its lower.
    expect(
      ThyroidAnatomy.anteriorBranch.points[7].dy -
          ThyroidAnatomy.isthmusTop[1].dy,
      inInclusiveRange(0, 2.5),
    );
    expect(
      (ThyroidAnatomy.inferiorVein.points.first.dy -
              ThyroidAnatomy.isthmusFoot[1].dy)
          .abs(),
      lessThan(1.5),
    );
  });

  test('the cut face is the lobe’s alone, its lobules cover it, and the C '
      'cells lie in its middle thirds, clear of its edge', () {
    final ThyroidForm form = _form();
    for (final Offset p in ThyroidForm.faceMm) {
      expect(p.dx, lessThan(-5), reason: '$p');
    }
    // Every point of the face lies in a lobule.
    final Rect face = _bounds(form.face);
    for (int i = 1; i < 10; i++) {
      for (int j = 1; j < 20; j++) {
        final Offset p = Offset(
          face.left + face.width * i / 10,
          face.top + face.height * j / 20,
        );
        if (!_inside(form.face, p)) {
          continue;
        }
        expect(
          form.lobules.any((List<Offset> cell) => _inside(cell, p)),
          isTrue,
          reason: '$p',
        );
      }
    }
    final double apex = _bounds(ThyroidForm.faceMm).top;
    expect(ThyroidForm.cCellsMm, isNotEmpty);
    for (final Offset c in ThyroidForm.cCellsMm) {
      final double along = (c.dy - apex) / ThyroidAnatomy.lobeLength;
      expect(
        along,
        inInclusiveRange(
          ThyroidAnatomy.cFrom - 0.05,
          ThyroidAnatomy.cTo + 0.05,
        ),
      );
      expect(_inside(ThyroidForm.faceMm, c), isTrue, reason: '$c');
    }
  });

  test('the trunks and the trachea are cut short, the arteries above and '
      'everything below; its names lie on what they name', () {
    final ThyroidForm form = _form();
    for (final TubeCourse t in <TubeCourse>[
      ...form.carotids,
      ...form.internalCarotids,
      ...form.externalCarotids,
      ...form.jugulars,
      ...form.jugularTops,
      ...form.inferiorVeins,
      form.trachea,
      form.superiorArteries.first,
      form.anteriorBranch,
    ]) {
      expect(t.cutEnd, isTrue);
    }
    expect(form.superiorArteries.last.cutEnd, isFalse);
    expect(form.contains(form.isthmusName), isTrue);
    expect(_inside(form.cartilage, form.larynxName), isTrue);
    expect(form.contains(form.tracheaName), isFalse);
    expect(
      (form.tracheaName - form.trachea.centres.first).dx.abs(),
      lessThan(form.mm(1)),
    );
  });

  test('the step from the body meets each lobe’s apex with its own, the lobe '
      'cut open first, on either figure, and ends on the gland’s outline', () {
    for (final AnatomyFigure figure in _figures) {
      final ThyroidForm form = _form(figure);
      final List<Offset> body = form.outlineAt(0);
      final List<Offset> gland = form.outlineAt(1);
      expect(gland.length, body.length, reason: figure.name);
      final List<Offset> ours = form.marksOf(form.outlinePoints);
      final List<Offset> theirs = form.marksOf(
        Contour(<Offset>[
          for (final Offset p in _part(figure).followed)
            (p - _part(figure).centre) *
                (_anatomy.metres / _part(figure).extent / _view),
        ]).sampled(8).points,
      );
      // The lobe cut open's apex, then the other's: each on the same side
      // in either outline.
      for (int k = 0; k < 2; k++) {
        final double side = k == 0 ? -1 : 1;
        expect(
          (ours[k].dx - form.box.center.dx) * side,
          greaterThan(0),
          reason: '${figure.name}: mark $k',
        );
        expect(
          (theirs[k].dx - _bounds(body).center.dx) * side,
          greaterThan(0),
          reason: '${figure.name}: mark $k',
        );
      }
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
    expect(ThyroidHome.of('Thyroid glandular cells'), ThyroidHome.follicles);
    expect(ThyroidHome.of('Parafollicular cells'), ThyroidHome.cCells);
    expect(ThyroidHome.of('C cells'), ThyroidHome.cCells);
    expect(ThyroidHome.of('Fibroblasts'), ThyroidHome.follicles);
    expect(ThyroidHome.of(null), ThyroidHome.follicles);
    expect(_form(null, ThyroidHome.cCells).homeName, isNot(_form().site));
  });
}
