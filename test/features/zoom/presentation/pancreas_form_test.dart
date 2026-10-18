import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/features/zoom/domain/anatomy_figure.dart';
import 'package:helixpeek/features/zoom/domain/anatomy_tables.dart';
import 'package:helixpeek/features/zoom/domain/zoom_depth.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/contour.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/pancreas/pancreas_anatomy.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/pancreas/pancreas_form.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/pancreas/pancreas_style.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/tube_course.dart';

final TissueAnatomy _anatomy = tissueAnatomy['pancreas']!;
final double _view = _anatomy.metres * ZoomDepth.organMargin;

/// Both figures: the curated proteins that reach the pancreas are all shown
/// on the female one, and a protein built on demand may be shown on either.
final List<AnatomyFigure> _figures = <AnatomyFigure>[
  AnatomyFigure.female,
  AnatomyFigure.male,
];

PancreasForm _form(AnatomyFigure figure) => PancreasForm.place(
  part: figure.parts[_anatomy.uberon]!,
  anatomy: _anatomy,
  view: _view,
);

/// The anatomogram's outline of the pancreas in the organ's scene, as the
/// body hands it over.
List<Offset> _diagram(AnatomyFigure figure) {
  final AnatomyPart part = figure.parts[_anatomy.uberon]!;
  final double real = _anatomy.metres / part.extent;
  return <Offset>[
    for (final Offset p in part.followed) (p - part.centre) * (real / _view),
  ];
}

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

/// How far [p] lies from the closed outline [points].
double _toOutline(List<Offset> points, Offset p) {
  double least = double.infinity;
  for (int i = 0; i < points.length; i++) {
    final Offset a = points[i];
    final Offset b = points[(i + 1) % points.length];
    final Offset ab = b - a;
    final double length = ab.distanceSquared;
    final double t = length == 0
        ? 0
        : (((p - a).dx * ab.dx + (p - a).dy * ab.dy) / length).clamp(0.0, 1.0);
    least = math.min(least, (a + ab * t - p).distance);
  }
  return least;
}

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
  test('the place its tissue is sampled stays the body’s, well inside the '
      'head, at every stage of the step from the body', () {
    for (final AnatomyFigure figure in _figures) {
      final PancreasForm form = _form(figure);
      final AnatomyPart part = figure.parts[_anatomy.uberon]!;
      final double real = _anatomy.metres / part.extent;
      final Offset placed = (part.site - part.centre) * (real / _view);
      expect((form.site - placed).distance, lessThan(1e-12));
      expect(form.contains(form.site), isTrue, reason: figure.name);
      expect(
        _toOutline(form.outlinePoints, form.site),
        greaterThan(form.mm(8)),
        reason: figure.name,
      );
      // In the head, to the reader's left of the neck.
      expect(form.toCm(form.site).dx, lessThan(-3.5), reason: figure.name);
      for (int i = 0; i <= 20; i++) {
        final List<Offset> outline = form.outlineAt(i / 20);
        expect(
          _inside(outline, form.site),
          isTrue,
          reason: '${figure.name} at ${i / 20}',
        );
        expect(
          _toOutline(outline, form.site),
          greaterThan(form.mm(5)),
          reason: '${figure.name} at ${i / 20}',
        );
      }
    }
  });

  test('the gland is its real size where the body drew it, about the same '
      'middle, drawn the same way round', () {
    for (final AnatomyFigure figure in _figures) {
      final PancreasForm form = _form(figure);
      expect(
        form.box.width,
        closeTo(_anatomy.metres / _view, 1e-9),
        reason: figure.name,
      );
      expect(form.box.center.distance, lessThan(1e-9), reason: figure.name);
      expect(
        _area(form.outlinePoints).sign,
        _area(Contour(_diagram(figure)).sampled(8).points).sign,
        reason: figure.name,
      );
      // About 16 cm long, and as tall as a gland is.
      expect(form.box.width / form.mm(1), closeTo(160, 1e-6));
      expect(form.box.height / form.mm(1), inInclusiveRange(70, 100));
    }
  });

  test('the step from the body draws the outline in from the very curve the '
      'body drew, to the gland’s, matching the top of the tail and the edge '
      'of the head', () {
    for (final AnatomyFigure figure in _figures) {
      final PancreasForm form = _form(figure);
      final List<Offset> body = Contour(_diagram(figure)).sampled(64).points;
      final List<Offset> gland = Contour(<Offset>[
        for (final Offset p in PancreasAnatomy.outline) form.place(p),
      ]).sampled(64).points;
      final List<Offset> from = form.outlineAt(0);
      final List<Offset> to = form.outlineAt(1);
      expect(from.length, to.length);
      for (final Offset p in from) {
        expect(_toOutline(body, p), lessThan(form.mm(0.05)));
      }
      for (final Offset p in to) {
        expect(_toOutline(gland, p), lessThan(form.mm(0.05)));
      }
      int topOf(List<Offset> points) {
        int best = 0;
        for (int i = 1; i < points.length; i++) {
          if (points[i].dy < points[best].dy) {
            best = i;
          }
        }
        return best;
      }

      int leftOf(List<Offset> points) {
        int best = 0;
        for (int i = 1; i < points.length; i++) {
          if (points[i].dx < points[best].dx) {
            best = i;
          }
        }
        return best;
      }

      expect(topOf(from), 0, reason: figure.name);
      expect(topOf(to), 0, reason: figure.name);
      expect(leftOf(from), leftOf(to), reason: figure.name);
      // Drawn in to the bed its lobules lie on, inside the outline.
      final List<Offset> bed = form.outlineAt(1, bed: 1);
      for (int i = 0; i < bed.length; i += 7) {
        expect(_inside(to, bed[i]), isTrue, reason: '${figure.name} at $i');
      }
    }
  });

  test('the lobules tile the gland, a crevice between each two, the edge '
      'knobbly with them', () {
    for (final AnatomyFigure figure in _figures) {
      final PancreasForm form = _form(figure);
      final List<Lobule> lobules = form.lobules;
      double across = 0;
      for (final Lobule lobule in lobules) {
        expect(form.contains(lobule.centre), isTrue, reason: figure.name);
        across += 2 * lobule.radius;
      }
      across /= lobules.length;
      expect(across / form.mm(1), inInclusiveRange(3.5, 6), reason: '$across');
      // Points inside the gland, clear of its edge: none in two lobules,
      // and few in none: the crevices, and the rounded corners where three
      // lobules meet, which the bed under them fills.
      final Rect box = form.box;
      int checked = 0;
      int bare = 0;
      for (int a = 0; a < 90; a++) {
        for (int b = 0; b < 50; b++) {
          final Offset p = Offset(
            box.left + box.width * (a + 0.5) / 90,
            box.top + box.height * (b + 0.5) / 50,
          );
          if (!form.contains(p) ||
              _toOutline(form.outlinePoints, p) < form.mm(2)) {
            continue;
          }
          checked++;
          int holding = 0;
          for (final Lobule lobule in lobules) {
            if ((lobule.centre - p).distance < form.mm(8) && lobule.holds(p)) {
              holding++;
            }
          }
          expect(holding, lessThanOrEqualTo(1), reason: '${figure.name} $p');
          if (holding == 0) {
            bare++;
          }
        }
      }
      expect(checked, greaterThan(1000));
      expect(bare / checked, lessThan(0.32), reason: figure.name);
      // Round the edge they bulge past the outline a little, at most half a
      // lobule: most where the outline curves back toward them, in the
      // notch the mesenteric vessels come through.
      double past = 0;
      for (final Lobule lobule in lobules) {
        for (int k = 0; k < lobule.reach.length; k++) {
          final Offset p = lobule.at(k, 1);
          if (!form.contains(p)) {
            past = math.max(past, _toOutline(form.outlinePoints, p));
          }
        }
      }
      expect(past, greaterThan(0), reason: figure.name);
      expect(
        past,
        lessThan(form.mm(PancreasStyle.lobule / 2)),
        reason: figure.name,
      );
    }
  });

  test('the uncinate process lies behind the mesenteric vessels, which come '
      'from under the neck', () {
    final PancreasForm form = _form(AnatomyFigure.female);
    final List<Lobule> uncinate = <Lobule>[
      for (final Lobule lobule in form.lobules)
        if (lobule.uncinate) lobule,
    ];
    expect(uncinate.length, greaterThan(10));
    for (final TubeCourse vessel in <TubeCourse>[
      form.mesentericVein,
      form.mesentericArtery,
    ]) {
      // Each crosses the uncinate process, in front of it...
      bool crosses = false;
      for (int i = 0; i < vessel.length && !crosses; i++) {
        for (final double u in <double>[-1, 0, 1]) {
          final Offset p = vessel.at(i, u);
          if (uncinate.any((Lobule l) => l.holds(p))) {
            crosses = true;
            break;
          }
        }
      }
      expect(crosses, isTrue);
      // ...from under the neck, in the gland but not in the uncinate.
      final Offset top = vessel.centres.first;
      expect(form.contains(top), isTrue);
      expect(PancreasAnatomy.inUncinate(form.toCm(top)), isFalse);
    }
  });

  test('the duodenum wraps the head, and the bile duct and the main duct '
      'meet at its wall', () {
    for (final AnatomyFigure figure in _figures) {
      final PancreasForm form = _form(figure);
      final TubeCourse duodenum = form.duodenum;
      // Its second part, down the head's outer edge.
      final Offset edge = form.outlinePoints.reduce(
        (Offset a, Offset b) => a.dx <= b.dx ? a : b,
      );
      double nearest = double.infinity;
      for (int i = duodenum.knotRows[4]; i <= duodenum.knotRows[8]; i++) {
        nearest = math.min(nearest, (duodenum.centres[i] - edge).distance);
      }
      expect(
        nearest / form.scale,
        inInclusiveRange(1.0, 1.7),
        reason: figure.name,
      );
      // The two ducts end together at the ampulla, on the duodenum's wall.
      final Offset ampulla = form.mainDuct.centres.last;
      expect(
        (form.bileDuct.centres.last - ampulla).distance,
        lessThan(form.mm(3)),
      );
      int closest = 0;
      for (int i = 1; i < duodenum.length; i++) {
        if ((duodenum.centres[i] - ampulla).distance <
            (duodenum.centres[closest] - ampulla).distance) {
          closest = i;
        }
      }
      expect(
        (duodenum.centres[closest] - ampulla).distance /
            duodenum.radius[closest],
        inInclusiveRange(0.75, 1.25),
        reason: figure.name,
      );
      // The main duct runs from the tail.
      expect(form.toCm(form.mainDuct.centres.first).dx, greaterThan(6));
    }
  });

  test('the islets lie in the gland, denser toward the tail, one where the '
      'tissue is sampled', () {
    for (final AnatomyFigure figure in _figures) {
      final PancreasForm form = _form(figure);
      final List<Islet> islets = form.islets;
      expect(islets.length, inInclusiveRange(300, 800), reason: figure.name);
      final Rect box = form.box;
      int head = 0;
      int tail = 0;
      for (final Islet islet in islets) {
        expect(form.contains(islet.at), isTrue, reason: figure.name);
        final double along = (islet.at.dx - box.left) / box.width;
        if (along < 1 / 3) {
          head++;
        } else if (along > 2 / 3) {
          tail++;
        }
      }
      double headArea = 0;
      double tailArea = 0;
      for (int a = 0; a < 150; a++) {
        for (int b = 0; b < 100; b++) {
          final Offset p = Offset(
            box.left + box.width * (a + 0.5) / 150,
            box.top + box.height * (b + 0.5) / 100,
          );
          if (!form.contains(p)) {
            continue;
          }
          if (a < 50) {
            headArea++;
          } else if (a >= 100) {
            tailArea++;
          }
        }
      }
      expect(
        (tail / tailArea) / (head / headArea),
        greaterThanOrEqualTo(1.5),
        reason: figure.name,
      );
      expect(form.siteIslet.at, form.site);
    }
  });

  test('for a duct cell the window holds the place the tissue is sampled '
      'and the main duct', () {
    for (final AnatomyFigure figure in _figures) {
      final PancreasForm form = _form(figure);
      expect(form.window.contains(form.site), isTrue, reason: figure.name);
      final TubeCourse duct = form.mainDuct;
      int inGland = 0;
      int inWindow = 0;
      for (int i = 0; i < duct.length; i++) {
        final Offset p = duct.centres[i];
        if (!form.contains(p) ||
            _toOutline(form.outlinePoints, p) < form.mm(1)) {
          continue;
        }
        inGland++;
        if (form.window.contains(p)) {
          inWindow++;
        }
      }
      expect(inWindow / inGland, greaterThan(0.95), reason: figure.name);
      // A branch reaches the place the tissue is sampled where the duct
      // does not pass it.
      double nearest = double.infinity;
      for (final Offset p in duct.centres) {
        nearest = math.min(nearest, (p - form.site).distance);
      }
      expect(
        form.siteBranch == null,
        nearest <= form.mm(1.5),
        reason: figure.name,
      );
    }
  });

  test('the gland is laid the same every time', () {
    final PancreasForm a = _form(AnatomyFigure.female);
    final PancreasForm b = _form(AnatomyFigure.female);
    expect(a.lobules.length, b.lobules.length);
    for (int i = 0; i < a.lobules.length; i++) {
      expect(a.lobules[i].centre, b.lobules[i].centre);
      expect(a.lobules[i].reach, b.lobules[i].reach);
    }
    expect(
      <Offset>[for (final Islet i in a.islets) i.at],
      <Offset>[for (final Islet i in b.islets) i.at],
    );
  });
}
