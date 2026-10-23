import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/features/zoom/domain/anatomy_figure.dart';
import 'package:helixpeek/features/zoom/domain/anatomy_tables.dart';
import 'package:helixpeek/features/zoom/domain/zoom_depth.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/contour.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/organs/kidney/kidney_anatomy.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/organs/kidney/kidney_form.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/tube_course.dart';

final TissueAnatomy _anatomy = tissueAnatomy['kidney']!;

/// The organ's view, framed by its width: the form is the same at any.
final double _view = _anatomy.metres * ZoomDepth.organMargin;

final List<AnatomyFigure> _figures = <AnatomyFigure>[
  AnatomyFigure.female,
  AnatomyFigure.male,
];

AnatomyPart _part(AnatomyFigure figure) => figure.parts[_anatomy.uberon]!;

KidneyForm _form([
  AnatomyFigure? figure,
  KidneyHome home = KidneyHome.cortex,
]) => KidneyForm.place(
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
  test('the kidney is drawn at its real size, laid on the body’s outline of '
      'it on either figure, its hilum toward the figure’s midline, moved '
      'across a few millimetres at most to lay its cortex through the place '
      'the body goes in', () {
    for (final AnatomyFigure figure in _figures) {
      final String what = figure.name;
      final AnatomyPart part = _part(figure);
      final KidneyForm form = _form(figure);
      expect(form.mm(1), closeTo(1e-3 / _view, 1e-15), reason: what);
      expect(form.box.height / form.scale, closeTo(120, 1), reason: what);
      expect(
        form.box.width / form.scale,
        inInclusiveRange(52, 62),
        reason: what,
      );
      expect(form.anchorShift.abs(), lessThan(3), reason: what);
      final Rect body = _bounds(form.outlineAt(0));
      for (final double edge in <double>[
        body.left - form.box.left,
        body.right - form.box.right,
        body.top - form.box.top,
        body.bottom - form.box.bottom,
      ]) {
        expect((edge / form.scale).abs(), lessThan(6), reason: what);
      }
      // Where the body goes in, which a kidney that follows the body keeps.
      final double real = _anatomy.metres / part.extent;
      final Offset site = (part.site - part.centre) * (real / _view);
      expect((form.site - site).distance, lessThan(1e-9), reason: what);
      expect(form.contains(form.site), isTrue, reason: what);
      // The hilum faces the figure's midline: the body's right kidney's to
      // the right on the page, its left kidney's to the left.
      final double midline =
          ((Offset(0, part.site.dy) - part.centre) * (real / _view)).dx;
      expect(form.side, midline > 0 ? 1 : -1, reason: what);
      final Offset hilum = form.marksOf(form.outlinePoints)[2];
      expect(
        (hilum.dx - form.box.center.dx) * form.side,
        greaterThan(0),
        reason: what,
      );
    }
  });

  test('the zoom goes in at the lower pole, on its lateral side, in the '
      'middle of its cortex, well in from the capsule and the pyramids', () {
    for (final AnatomyFigure figure in _figures) {
      for (final KidneyHome home in KidneyHome.values) {
        final String what = '${figure.name} ${home.name}';
        final KidneyForm form = _form(figure, home);
        final double down = (form.site.dy - form.box.top) / form.box.height;
        expect(down, inInclusiveRange(0.7, 0.8), reason: what);
        expect(
          (form.site.dx - form.box.center.dx) * form.side,
          lessThan(0),
          reason: what,
        );
        expect(
          _distanceTo(form.run, form.site, closed: false) / form.scale,
          greaterThan(3),
          reason: what,
        );
        expect(
          _distanceTo(form.junction, form.site, closed: false) / form.scale,
          greaterThan(3),
          reason: what,
        );
        for (final KidneyPyramid pyramid in form.pyramids) {
          expect(_inside(pyramid.outline, form.site), isFalse, reason: what);
        }
        expect(_inside(form.sinus, form.site), isFalse, reason: what);
      }
    }
  });

  test('its parts are the sizes they are measured at', () {
    final KidneyForm form = _form();
    double mm(double units) => units / form.scale;
    // The cortex, from the capsule to the pyramids' bases, within what
    // ultrasound measures (0.6 to 1.6 cm).
    for (int i = 0; i < form.run.length; i += 20) {
      final double cortex = mm((form.run[i] - form.junction[i]).distance);
      expect(cortex, closeTo(KidneyAnatomy.cortex, 0.01));
      expect(cortex, inInclusiveRange(6, 16));
    }
    // Eight pyramids, each as tall as wide or so, the size a 1.56 cm³
    // pyramid's cut is.
    expect(form.pyramids, hasLength(KidneyAnatomy.pyramids));
    for (final KidneyPyramid p in form.pyramids) {
      final Offset middle = (p.left.first + p.right.first) / 2;
      expect(mm((p.tip - middle).distance), inInclusiveRange(12, 30));
      expect(
        mm((p.left.first - p.right.first).distance),
        inInclusiveRange(10, 26),
      );
    }
    // A glomerulus is as big as a Bowman's capsule of 6.1 ± 2.5 million
    // cubic micrometres.
    const double radius = KidneyAnatomy.glomerulus * 1000;
    expect(
      4 / 3 * math.pi * radius * radius * radius,
      inInclusiveRange(3.6e6, 8.6e6),
    );
    // The renal artery as wide as it is measured; the vein and the ureter
    // as drawn.
    expect(mm(form.renalArtery.radius.first) * 2, closeTo(5.5, 1.4));
    expect(mm(form.renalVein.radius.first) * 2, closeTo(10, 0.01));
    expect(mm(form.ureter.radius.first) * 2, closeTo(5, 0.01));
  });

  test('its pyramids lie in the parenchyma and apart, each its papilla '
      'standing into the cavity of the calyces', () {
    for (final AnatomyFigure figure in _figures) {
      final String what = figure.name;
      final KidneyForm form = _form(figure);
      final List<Offset> outline = form.outlinePoints;
      for (int i = 0; i < form.pyramids.length; i++) {
        final KidneyPyramid p = form.pyramids[i];
        for (final Offset q in p.outline) {
          expect(
            _inside(outline, q) || _distanceTo(outline, q) < form.mm(0.3),
            isTrue,
            reason: '$what pyramid $i at $q',
          );
        }
        expect(
          form.collecting.contains(p.tip),
          isTrue,
          reason: '$what pyramid $i',
        );
        expect(p.left.length, p.right.length, reason: '$what pyramid $i');
        for (int j = i + 1; j < form.pyramids.length; j++) {
          for (final Offset q in form.pyramids[j].outline) {
            expect(
              _inside(p.outline, q),
              isFalse,
              reason: '$what pyramids $i and $j at $q',
            );
          }
        }
      }
    }
  });

  test('its rays run up from the pyramids’ bases into the cortex and stop '
      'short of the capsule; one runs through the site where they are the '
      'cell’s home, and none where they are not', () {
    for (final AnatomyFigure figure in _figures) {
      for (final KidneyHome home in KidneyHome.values) {
        final String what = '${figure.name} ${home.name}';
        final KidneyForm form = _form(figure, home);
        double nearest = double.infinity;
        for (final KidneyPyramid p in form.pyramids) {
          expect(p.rays, isNotEmpty, reason: what);
          for (final (Offset a, Offset b) in p.rays) {
            expect(
              _distanceTo(form.junction, a, closed: false),
              lessThan(form.mm(0.01)),
              reason: what,
            );
            expect(form.contains(b), isTrue, reason: what);
            expect(
              _distanceTo(form.run, b, closed: false) / form.scale,
              closeTo(KidneyAnatomy.rayShort, 0.05),
              reason: what,
            );
            nearest = math.min(
              nearest,
              _distanceTo(<Offset>[a, b], form.site, closed: false),
            );
          }
        }
        if (home == KidneyHome.loops || home == KidneyHome.ducts) {
          expect(
            nearest / form.scale,
            lessThan(KidneyAnatomy.ray / 2),
            reason: what,
          );
        } else {
          expect(
            nearest / form.scale,
            greaterThan(KidneyAnatomy.ray),
            reason: what,
          );
        }
      }
    }
  });

  test('its glomeruli are a dust through the cortex and its columns, clear '
      'of the rays, the pyramids and the sinus, and one lies at the site '
      'where they are the cell’s home', () {
    for (final AnatomyFigure figure in _figures) {
      final String what = figure.name;
      final KidneyForm form = _form(figure);
      // A quarter of the two to a square millimetre a cut shows.
      double cortex = _area(form.outlinePoints).abs() - _area(form.sinus).abs();
      for (final KidneyPyramid p in form.pyramids) {
        cortex -= _area(p.outline).abs();
      }
      final double perMm2 =
          form.glomeruli.length / (cortex / (form.scale * form.scale));
      expect(perMm2, inInclusiveRange(0.25, 0.5), reason: what);
      for (final Offset g in form.glomeruli) {
        expect(form.contains(g), isTrue, reason: '$what at $g');
        expect(_inside(form.sinus, g), isFalse, reason: '$what at $g');
        for (final KidneyPyramid p in form.pyramids) {
          expect(_inside(p.outline, g), isFalse, reason: '$what at $g');
          for (final (Offset a, Offset b) in p.rays) {
            expect(
              _distanceTo(<Offset>[a, b], g, closed: false),
              greaterThan(form.mm(KidneyAnatomy.ray / 2)),
              reason: '$what at $g',
            );
          }
        }
      }
      expect(form.siteGlomerulus, isNull, reason: what);
      expect(
        _form(figure, KidneyHome.glomeruli).siteGlomerulus,
        form.site,
        reason: what,
      );
    }
  });

  test('its calyces and its pelvis are one cavity, which leaves the hilum as '
      'the ureter, running down beside the lower pole; the renal artery and '
      'vein leave the hilum toward the midline, cut short', () {
    for (final AnatomyFigure figure in _figures) {
      final String what = figure.name;
      final KidneyForm form = _form(figure);
      final TubeCourse ureter = form.ureter;
      expect(form.collecting.contains(ureter.centres[1]), isTrue, reason: what);
      expect(
        (ureter.centres.last.dy - ureter.centres.first.dy) / form.scale,
        greaterThan(40),
        reason: what,
      );
      expect(ureter.shown.last, lessThan(0.05), reason: what);
      for (final TubeCourse vessel in <TubeCourse>[
        form.renalArtery,
        form.renalVein,
      ]) {
        expect(vessel.cutEnd, isTrue, reason: what);
        final Offset end = vessel.centres.last;
        expect(
          (end.dx - form.box.center.dx) * form.side,
          greaterThan(form.box.width / 2),
          reason: what,
        );
      }
    }
  });

  test('it names its parts on what they name', () {
    for (final AnatomyFigure figure in _figures) {
      final String what = figure.name;
      final KidneyForm form = _form(figure);
      // The cortex in its band, the medulla in a pyramid, the pelvis in
      // the cavity, the ureter on its course.
      expect(form.contains(form.cortexName), isTrue, reason: what);
      expect(
        _distanceTo(form.run, form.cortexName, closed: false),
        greaterThan(form.mm(3)),
        reason: what,
      );
      expect(
        _distanceTo(form.junction, form.cortexName, closed: false),
        greaterThan(form.mm(3)),
        reason: what,
      );
      expect(
        form.pyramids.any(
          (KidneyPyramid p) => _inside(p.outline, form.medullaName),
        ),
        isTrue,
        reason: what,
      );
      expect(form.collecting.contains(form.pelvisName), isTrue, reason: what);
      expect(
        _distanceTo(form.ureter.centres, form.ureterName, closed: false),
        lessThan(form.mm(KidneyAnatomy.ureterRadius)),
        reason: what,
      );
      final Offset papilla = form.papillaNear(form.site);
      expect(
        form.pyramids.any((KidneyPyramid p) => _inside(p.papilla, papilla)),
        isTrue,
        reason: what,
      );
      // The lateral names on the lateral side, the hilum's on the medial.
      for (final Offset lateral in <Offset>[
        form.cortexName,
        form.medullaName,
      ]) {
        expect(
          (lateral.dx - form.box.center.dx) * form.side,
          lessThan(0),
          reason: what,
        );
      }
      for (final Offset medial in <Offset>[form.pelvisName, form.ureterName]) {
        expect(
          (medial.dx - form.box.center.dx) * form.side,
          greaterThan(0),
          reason: what,
        );
      }
    }
  });

  test('the step from the body meets the kidney’s outline and the body’s at '
      'the same places, in the same order round them from the top', () {
    for (final AnatomyFigure figure in _figures) {
      final AnatomyPart part = _part(figure);
      final KidneyForm form = _form(figure);
      final double real = _anatomy.metres / part.extent;
      final List<Offset> body = Contour(<Offset>[
        for (final Offset p in part.followed)
          (p - part.centre) * (real / _view),
      ]).sampled(8).points;
      List<int> order(List<Offset> points) {
        int top = 0;
        for (int i = 1; i < points.length; i++) {
          if (points[i].dy < points[top].dy) {
            top = i;
          }
        }
        final List<int> round = <int>[
          for (final Offset m in form.marksOf(points))
            (points.indexOf(m) - top) % points.length,
        ];
        return <int>[
          for (int k = 0; k < round.length; k++)
            round.where((int r) => r < round[k]).length,
        ];
      }

      // Both the same way round, as the morph lays them.
      final double kidneyWay = _area(form.outlinePoints).sign;
      final List<Offset> bodyWay = _area(body).sign == kidneyWay
          ? body
          : body.reversed.toList();
      expect(order(form.outlinePoints), order(bodyWay), reason: figure.name);
      expect(
        form.marksOf(form.outlinePoints).toSet(),
        hasLength(4),
        reason: figure.name,
      );
    }
  });

  test('where the zoom’s cell lives in the kidney is told by the Atlas’s '
      'name for the cell, every one of the kidney’s drawn as one shape', () {
    const Map<String?, KidneyHome> homes = <String?, KidneyHome>{
      'Ascending Loop of Henle cells': KidneyHome.loops,
      'Loop of henle epithelial cells': KidneyHome.loops,
      'Renal collecting duct principal cells': KidneyHome.ducts,
      'Renal collecting duct intercalated cells': KidneyHome.ducts,
      'Intercalated cells': KidneyHome.ducts,
      'Papillary tip epithelial cells': KidneyHome.papillae,
      'Podocytes': KidneyHome.glomeruli,
      'Proximal tubule cells': KidneyHome.cortex,
      'Proximal tubular cells': KidneyHome.cortex,
      'Distal convoluted tubule cells': KidneyHome.cortex,
      'Renal connecting tubule cells': KidneyHome.cortex,
      'Endothelial cells': KidneyHome.cortex,
      'Fibroblasts': KidneyHome.cortex,
      'Macrophages': KidneyHome.cortex,
      null: KidneyHome.cortex,
    };
    for (final MapEntry<String?, KidneyHome> cell in homes.entries) {
      expect(KidneyHome.of(cell.key), cell.value, reason: '${cell.key}');
    }
  });

  test('it is the same kidney every time', () {
    final KidneyForm a = _form(AnatomyFigure.female, KidneyHome.loops);
    final KidneyForm b = _form(AnatomyFigure.female, KidneyHome.loops);
    expect(a.outlinePoints, b.outlinePoints);
    expect(a.glomeruli, b.glomeruli);
    expect(
      <Offset>[for (final KidneyPyramid p in a.pyramids) ...p.outline],
      <Offset>[for (final KidneyPyramid p in b.pyramids) ...p.outline],
    );
    expect(a.site, b.site);
  });
}
