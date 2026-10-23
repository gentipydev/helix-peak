import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/features/zoom/domain/anatomy_figure.dart';
import 'package:helixpeek/features/zoom/domain/anatomy_tables.dart';
import 'package:helixpeek/features/zoom/domain/zoom_depth.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/contour.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/organs/stomach/stomach_anatomy.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/organs/stomach/stomach_form.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/tube_course.dart';

final TissueAnatomy _anatomy = tissueAnatomy['stomach']!;

/// The organ's view, framed by its width: the form is the same at any.
final double _view = _anatomy.metres * ZoomDepth.organMargin;

final List<AnatomyFigure> _figures = <AnatomyFigure>[
  AnatomyFigure.female,
  AnatomyFigure.male,
];

AnatomyPart _part(AnatomyFigure figure) => figure.parts[_anatomy.uberon]!;

StomachForm _form([
  AnatomyFigure? figure,
  StomachHome home = StomachHome.mucosa,
]) => StomachForm.place(
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
  test('the stomach is drawn at its real size, laid on the body’s outline '
      'of it on either figure, moved a few millimetres at most to lay the '
      'place it is gone into on the place the body goes in', () {
    for (final AnatomyFigure figure in _figures) {
      final String what = figure.name;
      final AnatomyPart part = _part(figure);
      final StomachForm form = _form(figure);
      expect(form.mm(1), closeTo(1e-3 / _view, 1e-15), reason: what);
      expect(form.box.width / form.scale, closeTo(250, 5), reason: what);
      expect(form.box.height / form.scale, closeTo(223, 5), reason: what);
      expect(form.anchorShift, lessThan(8), reason: what);
      final Rect body = _bounds(form.outlineAt(0));
      for (final double edge in <double>[
        body.left - form.box.left,
        body.right - form.box.right,
        body.top - form.box.top,
        body.bottom - form.box.bottom,
      ]) {
        expect((edge / form.scale).abs(), lessThan(16), reason: what);
      }
      // Where the body goes in, which a stomach that follows the body
      // keeps.
      final double real = _anatomy.metres / part.extent;
      final Offset site = (part.site - part.centre) * (real / _view);
      expect((form.site - site).distance, lessThan(1e-9), reason: what);
      expect(form.contains(form.site), isTrue, reason: what);
    }
  });

  test('the zoom goes into its body, in the mucosa, between two rugae, well '
      'clear of its wall and below its esophagus, on either figure', () {
    for (final AnatomyFigure figure in _figures) {
      final String what = figure.name;
      final StomachForm form = _form(figure);
      final Offset site = form.toMm(form.site);
      // Above the incisura angularis and right of the lesser curvature:
      // the body, where the fundus glands are.
      expect(site.dy, lessThan(StomachAnatomy.outline[34].dy), reason: what);
      expect(site.dx, greaterThan(StomachAnatomy.outline[37].dx), reason: what);
      final double down = (form.site.dy - form.box.top) / form.box.height;
      expect(down, inInclusiveRange(0.3, 0.5), reason: what);
      expect(StomachForm.clearOfRugae(site), greaterThan(4), reason: what);
      expect(StomachForm.clearOfWall(site), greaterThan(15), reason: what);
      expect(_inside(form.lining, form.site), isFalse, reason: what);
      expect(
        (form.rugaNear(form.site) - form.site).distance / form.scale,
        lessThan(12),
        reason: what,
      );
    }
  });

  test(
    'its wall is as thick as it is measured, thinnest round the fundus '
    'and thickest at the pyloric ring, its muscle about two fifths of it',
    () {
      final List<double> walls = <double>[
        for (int i = 0; i < StomachAnatomy.wall.length; i++)
          if (i != StomachAnatomy.lowerLip && i != StomachAnatomy.upperLip)
            StomachAnatomy.wall[i],
      ].where((double w) => w > 0).toList();
      // Between endoscopic ultrasound's 3.27 ± 0.42 mm (Larsen et al. 2011)
      // and the most ultrasound found in a healthy stomach, 7 (Rapaccini et
      // al. 1988).
      for (final double w in walls) {
        expect(w, inInclusiveRange(3.27 - 0.42, 7));
      }
      final double ring = math.min(
        StomachAnatomy.wall[StomachAnatomy.lowerLip],
        StomachAnatomy.wall[StomachAnatomy.upperLip],
      );
      expect(ring, greaterThan(walls.reduce(math.max)));
      // Thickest in the antrum, thinnest in the fundus (Endo et al. 2025).
      final double fundus = StomachForm.wallAt(StomachAnatomy.fundusName);
      final double body = StomachForm.wallAt(StomachAnatomy.bodyName);
      final double antrum = StomachForm.wallAt(StomachAnatomy.antrumName);
      expect(fundus, lessThan(body));
      expect(body, lessThan(antrum));
      // Its muscle 1.0 of 2.6 mm in the body (Endo et al. 2025).
      final double w = body;
      final double others =
          math.min(w * StomachAnatomy.mucosaShare, StomachAnatomy.mucosaMost) +
          math.min(
            w * StomachAnatomy.submucosaShare,
            StomachAnatomy.submucosaMost,
          ) +
          math.min(w * StomachAnatomy.serosaShare, StomachAnatomy.serosaMost);
      expect((w - others) / w, inInclusiveRange(0.35, 0.5));
    },
  );

  test('its arteries are the sizes they are measured at', () {
    double across(AnatomyTube t) => 2 * t.radii.reduce(math.max);
    // The left gastric 2.7 ± 0.3 mm, the right 1.6 ± 0.2 (Tuan et al.
    // 2026); the right gastroepiploic 2.49 ± 0.66 at its origin (Howell et
    // al. 2018).
    expect(
      across(StomachAnatomy.arteries[0]),
      inInclusiveRange(2.7 - 0.3, 2.7 + 0.3),
    );
    expect(
      across(StomachAnatomy.arteries[1]),
      inInclusiveRange(1.6 - 0.2, 1.6 + 0.2),
    );
    expect(
      2 * StomachAnatomy.arteries[3].radii.last,
      inInclusiveRange(2.49 - 0.66, 2.49 + 0.66),
    );
  });

  test('its wall’s coats lie one inside another from the serosa in, and the '
      'mucosa’s surface inside them all', () {
    final StomachForm form = _form();
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
        closeTo(StomachForm.wallAt(form.toMm(form.serosa[i])), 1e-6),
      );
    }
    expect(_area(form.inner).abs(), lessThan(_area(form.serosa).abs()));
    // The muscle shows in two runs, either side of the esophagus's cut end
    // and the pyloric orifice.
    expect(form.muscleMiddle, hasLength(2));
  });

  test('its rugae run its length in the mucosa, never crossing, and gather '
      'toward the pylorus', () {
    final StomachForm form = _form();
    final Offset pylorus = form.place(StomachAnatomy.outline[28]);
    for (int i = 0; i < form.rugae.length; i++) {
      final List<Offset> ruga = form.rugae[i];
      for (final Offset p in ruga) {
        expect(
          StomachForm.clearOfWall(form.toMm(p)),
          greaterThan(0.5),
          reason: 'ruga $i',
        );
      }
      expect(
        (ruga.last - pylorus).distance,
        lessThan((ruga.first - pylorus).distance),
        reason: 'ruga $i',
      );
      for (int j = i + 1; j < form.rugae.length; j++) {
        double nearest = double.infinity;
        for (final Offset p in ruga) {
          nearest = math.min(
            nearest,
            _distanceTo(form.rugae[j], p, closed: false),
          );
        }
        expect(nearest / form.scale, greaterThan(0.5), reason: 'rugae $i, $j');
      }
    }
    // Further apart in the body than at the pyloric canal.
    double gap(Offset at) {
      final List<double> d = <double>[
        for (final List<Offset> ruga in form.rugae)
          _distanceTo(ruga, at, closed: false),
      ]..sort();
      return d[1];
    }

    expect(
      gap(form.place(StomachAnatomy.bodyName)),
      greaterThan(gap(form.place(const Offset(-112, 60)))),
    );
    final (double greater, double lesser) = StomachForm.curvatures;
    expect(greater, greaterThan(2 * lesser));
  });

  test('the esophagus’s lining meets the stomach’s at the Z-line, at the '
      'cardia, its tongues reaching up into the esophagus', () {
    final StomachForm form = _form();
    final List<Offset> z = form.zLine;
    expect(z.length, 2 * StomachAnatomy.tongues + 1);
    final double mean =
        z.map((Offset p) => p.dy).reduce((double a, double b) => a + b) /
        z.length;
    // Its tongues reach up, into the esophagus.
    for (int k = 1; k < z.length; k += 2) {
      expect(z[k].dy, lessThan(math.min(z[k - 1].dy, z[k + 1].dy)));
    }
    // The lining lies above it, in the esophagus, its cut end its top.
    final Rect lining = _bounds(form.lining);
    expect(lining.center.dy, lessThan(mean));
    expect(lining.top, closeTo(form.box.top, form.mm(1)));
    // At the cardia, level with the incisura cardiaca.
    final Offset notch = form.place(
      StomachAnatomy.outline[StomachAnatomy.notch],
    );
    expect((mean - notch.dy).abs() / form.scale, lessThan(6));
  });

  test('the esophagus leaves it above, the duodenum past the pylorus, both '
      'cut short; its arteries run outside it, cut short at their origins, '
      'their branches running in under its wall', () {
    final StomachForm form = _form();
    bool leaves(TubeCourse tube) =>
        form.contains(tube.centres.first) && !form.contains(tube.centres.last);
    expect(leaves(form.esophagus), isTrue);
    expect(form.esophagus.centres.last.dy, lessThan(form.box.top));
    expect(leaves(form.duodenum), isTrue);
    expect(form.duodenum.centres.last.dx, lessThan(form.box.left));
    expect(form.esophagus.cutEnd, isTrue);
    expect(form.duodenum.cutEnd, isTrue);
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
    expect(form.branches.length, inInclusiveRange(20, 80));
    for (final TubeCourse branch in form.branches) {
      expect(form.contains(branch.centres.first), isFalse);
      expect(form.contains(branch.centres.last), isTrue);
    }
  });

  test('the step from the body meets the stomach’s outline and the body’s at '
      'the same places, in the same order round them from the top', () {
    for (final AnatomyFigure figure in _figures) {
      final AnatomyPart part = _part(figure);
      final StomachForm form = _form(figure);
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
      final double way = _area(form.outlinePoints).sign;
      final List<Offset> bodyWay = _area(body).sign == way
          ? body
          : body.reversed.toList();
      expect(order(form.outlinePoints), order(bodyWay), reason: figure.name);
      expect(
        form.marksOf(form.outlinePoints).toSet(),
        hasLength(3),
        reason: figure.name,
      );
      // The topmost point of each is its esophagus's cut end.
      Offset top(List<Offset> points) =>
          points.reduce((Offset a, Offset b) => a.dy <= b.dy ? a : b);
      expect(
        (top(form.outlinePoints) - form.place(StomachAnatomy.outline[2]))
                .distance /
            form.scale,
        lessThan(8),
        reason: figure.name,
      );
      expect(top(bodyWay).dx, lessThan(form.site.dx), reason: figure.name);
      // The body's outline at the hand-over, the stomach's own once
      // settled.
      final List<Offset> settled = form.outlineAt(1);
      expect(
        _bounds(settled).width,
        closeTo(form.box.width, form.mm(1)),
        reason: figure.name,
      );
    }
  });

  test('where the zoom’s cell lives in the stomach is told by the Atlas’s '
      'name for the cell', () {
    const Map<String?, StomachHome> homes = <String?, StomachHome>{
      'Mitotic cells (Stomach)': StomachHome.mucosa,
      'Gastric progenitor cells': StomachHome.mucosa,
      'Foveolar cells': StomachHome.mucosa,
      'Mucous neck cells': StomachHome.mucosa,
      'Parietal cells': StomachHome.mucosa,
      'Gastric chief cells': StomachHome.mucosa,
      'Chief cells': StomachHome.mucosa,
      'Gastric enteroendocrine cells': StomachHome.mucosa,
      'Tuft cells': StomachHome.mucosa,
      'Fibroblasts': StomachHome.mucosa,
      'T-cells': StomachHome.mucosa,
      'Smooth muscle cells': StomachHome.muscularis,
      'Interstitial cells of Cajal': StomachHome.muscularis,
      null: StomachHome.mucosa,
    };
    for (final MapEntry<String?, StomachHome> cell in homes.entries) {
      expect(StomachHome.of(cell.key), cell.value, reason: '${cell.key}');
    }
  });

  test('it is the same stomach every time', () {
    final StomachForm a = _form(AnatomyFigure.male, StomachHome.muscularis);
    final StomachForm b = _form(AnatomyFigure.male, StomachHome.muscularis);
    expect(a.outlinePoints, b.outlinePoints);
    expect(a.rugae, b.rugae);
    expect(a.site, b.site);
    expect(a.branches.length, b.branches.length);
    expect((a.wallNear(a.site) - a.site).distance / a.scale, lessThan(80));
  });
}
