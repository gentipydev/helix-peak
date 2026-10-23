import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/features/zoom/domain/anatomy_figure.dart';
import 'package:helixpeek/features/zoom/domain/anatomy_tables.dart';
import 'package:helixpeek/features/zoom/domain/zoom_depth.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/contour.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/organs/esophagus/esophagus_anatomy.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/organs/esophagus/esophagus_form.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/tube_course.dart';

final TissueAnatomy _anatomy = tissueAnatomy['esophagus']!;

/// The organ's view, framed by its width: the form is the same at any.
final double _view = _anatomy.metres * ZoomDepth.organMargin;

final List<AnatomyFigure> _figures = <AnatomyFigure>[
  AnatomyFigure.female,
  AnatomyFigure.male,
];

AnatomyPart _part(AnatomyFigure figure) => figure.parts[_anatomy.uberon]!;

EsophagusForm _form([
  AnatomyFigure? figure,
  EsophagusHome home = EsophagusHome.mucosa,
]) => EsophagusForm.place(
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
  test('the esophagus is drawn at its real size, 250 mm from the cricoid to '
      'the cardia, laid on the body’s outline of it on either figure, the '
      'place it is gone into on the place the body goes in', () {
    for (final AnatomyFigure figure in _figures) {
      final String what = figure.name;
      final AnatomyPart part = _part(figure);
      final EsophagusForm form = _form(figure);
      expect(form.mm(1), closeTo(1e-3 / _view, 1e-15), reason: what);
      // Gray's 23 to 25 cm, followed on into the cardia where it is cut.
      expect(
        EsophagusForm.alongOf(EsophagusAnatomy.course[21]),
        closeTo(EsophagusAnatomy.length, 1),
        reason: what,
      );
      expect(
        EsophagusForm.courseLength,
        closeTo(EsophagusAnatomy.opened, 1),
        reason: what,
      );
      expect(form.box.height / form.scale, closeTo(270, 10), reason: what);
      expect(form.anchorShift, lessThan(15), reason: what);
      final Rect body = _bounds(form.outlineAt(0));
      for (final double edge in <double>[
        body.left - form.box.left,
        body.right - form.box.right,
        body.top - form.box.top,
        body.bottom - form.box.bottom,
      ]) {
        // The cut runs on 12 mm into the cardia past the body's outline,
        // its base wider.
        expect((edge / form.scale).abs(), lessThan(25), reason: what);
      }
      // Where the body goes in, which an esophagus that follows the body
      // keeps.
      final double real = _anatomy.metres / part.extent;
      final Offset site = (part.site - part.centre) * (real / _view);
      expect((form.site - site).distance, lessThan(1e-9), reason: what);
      expect(form.contains(form.site), isTrue, reason: what);
    }
  });

  test('the zoom goes into its lower third, at least 4 cm above the '
      'gastroesophageal junction, where GTEx takes its mucosa, on its '
      'lining, between its folds and clear of its wall, on either figure', () {
    final double along = EsophagusForm.alongOf(EsophagusForm.siteMm);
    expect(along, closeTo(EsophagusAnatomy.siteAlong, 1));
    expect(along, greaterThan(EsophagusAnatomy.length * 2 / 3));
    expect(EsophagusAnatomy.length - along, greaterThanOrEqualTo(40));
    expect(EsophagusForm.clearOfFolds(EsophagusForm.siteMm), greaterThan(1.5));
    expect(EsophagusForm.clearOfWall(EsophagusForm.siteMm), greaterThan(4));
    for (final AnatomyFigure figure in _figures) {
      final EsophagusForm form = _form(figure);
      expect(_inside(form.lining, form.site), isTrue, reason: figure.name);
      // The body's site is gone into three quarters of the way down its
      // outline, and the drawing laid on it there.
      final Rect body = _bounds(form.outlineAt(0));
      expect(
        (form.site.dy - body.top) / body.height,
        closeTo(0.75, 0.02),
        reason: figure.name,
      );
    }
  });

  test('its wall is as thick as CT measures it, between distended and '
      'contracted, and thickest at its two sphincters, the lower thickening '
      'over 31 mm above the gastroesophageal ring', () {
    // Xia et al. 2009: at most 2.11 mm distended, 4.70 contracted.
    for (double s = 20; s <= 210; s += 5) {
      expect(EsophagusForm.wallAt(s), inInclusiveRange(2.11, 4.70));
    }
    double most(double from, double to) {
      double best = 0;
      for (double s = from; s <= to; s += 1) {
        best = math.max(best, EsophagusForm.wallAt(s));
      }
      return best;
    }

    final double between = most(20, 215);
    expect(EsophagusForm.wallAt(0), greaterThan(between));
    expect(EsophagusForm.wallAt(EsophagusAnatomy.length), greaterThan(between));
    // Thickest at the junction, tapering from 31 mm above it (Liebermann-
    // Meffert et al. 1979), and no thicker there than the most the
    // abdominal esophagus is measured at, contracted, and a little more.
    expect(
      most(0, EsophagusAnatomy.opened),
      EsophagusForm.wallAt(EsophagusAnatomy.length),
    );
    expect(
      EsophagusForm.wallAt(EsophagusAnatomy.length - 31),
      closeTo(EsophagusForm.wallAt(150), 0.11),
    );
    expect(EsophagusForm.wallAt(EsophagusAnatomy.length), lessThan(5.68 + 1));
    // Most contracted at its beginning and where it goes through the
    // diaphragm, distinctly dilated just above it (Gray 1918).
    final double body = EsophagusForm.halfAt(100);
    expect(EsophagusForm.halfAt(0), lessThan(body));
    expect(EsophagusForm.halfAt(EsophagusAnatomy.hiatus), lessThan(body));
    expect(EsophagusForm.halfAt(222), greaterThan(body));
    expect(
      EsophagusForm.halfAt(EsophagusAnatomy.length),
      greaterThan(EsophagusForm.halfAt(EsophagusAnatomy.hiatus)),
    );
    expect(2 * body, closeTo(22, 1e-9));
  });

  test('its wall’s coats lie one inside another from its fibrous coat in, '
      'the lining inside them all, and it is its muscle that thickens into '
      'the sphincters', () {
    final EsophagusForm form = _form();
    final List<List<Offset>> rings = <List<Offset>>[
      form.outlinePoints,
      form.fibrousInner,
      form.muscleInner,
      form.submucosaInner,
      form.lining,
    ];
    for (int k = 1; k < rings.length; k++) {
      expect(
        _area(rings[k]).abs(),
        lessThan(_area(rings[k - 1]).abs()),
        reason: 'coat $k',
      );
    }
    // The lining's middle lies inside every coat.
    final Offset middle = form.place(EsophagusForm.siteMm);
    for (final List<Offset> ring in rings) {
      expect(_inside(ring, middle), isTrue);
    }
    double share(double s) {
      final double w = EsophagusForm.wallAt(s);
      final double others =
          math.min(
            w * EsophagusAnatomy.fibrousShare,
            EsophagusAnatomy.fibrousMost,
          ) +
          math.min(
            w * EsophagusAnatomy.submucosaShare,
            EsophagusAnatomy.submucosaMost,
          ) +
          math.min(
            w * EsophagusAnatomy.mucosaShare,
            EsophagusAnatomy.mucosaMost,
          );
      return (w - others) / w;
    }

    expect(share(EsophagusAnatomy.length), greaterThan(share(100)));
    expect(share(0), greaterThan(share(100)));
    expect(form.planes, hasLength(2));
    expect(form.rims, hasLength(2));
  });

  test('its folds run its length in its lining, never meeting, gathered '
      'where it is narrow', () {
    final EsophagusForm form = _form();
    for (int i = 0; i < form.folds.length; i++) {
      final List<Offset> fold = form.folds[i];
      expect(
        EsophagusForm.alongOf(form.toMm(fold.last)) -
            EsophagusForm.alongOf(form.toMm(fold.first)),
        greaterThan(30),
        reason: 'fold $i',
      );
      for (final Offset p in fold) {
        expect(
          EsophagusForm.clearOfWall(form.toMm(p)),
          greaterThan(0.3),
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
        expect(nearest / form.scale, greaterThan(0.5), reason: 'folds $i, $j');
      }
    }
    // Gathered where it is narrow: its outermost two folds lie closer
    // together just below the cricopharyngeus than in the thorax.
    Offset at(List<Offset> fold, double s) => fold.reduce(
      (Offset a, Offset b) =>
          (EsophagusForm.alongOf(form.toMm(a)) - s).abs() <=
              (EsophagusForm.alongOf(form.toMm(b)) - s).abs()
          ? a
          : b,
    );
    final List<Offset> right = form.folds[0];
    final List<Offset> left = form.folds[6];
    expect(
      (at(right, 12) - at(left, 12)).distance,
      lessThan((at(right, 100) - at(left, 100)).distance),
    );
  });

  test('its lining meets the stomach’s at the Z-line, at the junction, its '
      'tongues of the stomach’s mucosa reaching up into the esophagus, the '
      'stomach’s mucosa below it', () {
    final EsophagusForm form = _form();
    final List<Offset> z = form.zLine;
    // Up, the way back along it, is the right hand of the Z-line's way
    // across from the body's right to its left.
    final Offset across = z.last - z.first;
    final Offset toward = Offset(across.dy, -across.dx);
    double rise(Offset p) =>
        _dot(p - z.first, toward) / toward.distance / form.scale;
    int tips = 0;
    for (int i = 1; i + 1 < z.length; i++) {
      if (rise(z[i]) > rise(z[i - 1]) && rise(z[i]) >= rise(z[i + 1])) {
        tips++;
      }
    }
    expect(tips, EsophagusAnatomy.tongues);
    for (final Offset p in z) {
      expect(rise(p), inInclusiveRange(-1e-6, EsophagusAnatomy.tongue + 1e-6));
    }
    // At the junction.
    for (final Offset p in <Offset>[z.first, z.last]) {
      expect(
        EsophagusForm.alongOf(form.toMm(p)),
        closeTo(EsophagusAnatomy.length, 3),
      );
    }
    // The stomach's mucosa below it, on to where the cut ends.
    final Rect gastric = _bounds(form.gastric);
    expect(
      EsophagusForm.alongOf(form.toMm(gastric.center)),
      greaterThan(EsophagusAnatomy.length),
    );
  });

  test('its glands lie in its submucosa down either side', () {
    final EsophagusForm form = _form();
    expect(
      form.glands.length,
      inInclusiveRange(
        (2 * EsophagusAnatomy.length / 12).round(),
        (2 * EsophagusAnatomy.opened / 5).round(),
      ),
    );
    for (final Offset gland in form.glands) {
      expect(_inside(form.muscleInner, gland), isTrue);
      expect(_inside(form.submucosaInner, gland), isFalse);
    }
    expect(
      form.glandRadius / form.scale,
      closeTo(EsophagusAnatomy.gland, 1e-9),
    );
    expect(
      (form.glandNear(form.site) - form.site).distance / form.scale,
      lessThan(20),
    );
  });

  test('the pharynx above it and the stomach below run on, cut short; the '
      'aorta its measured size passes to its left and behind it, cut where '
      'its arch crosses; the diaphragm reaches out either side of the '
      'hiatus, cut short', () {
    final EsophagusForm form = _form();
    expect(form.pharynx.cutEnd, isTrue);
    expect(form.pharynx.centres.last.dy, lessThan(form.box.top));
    expect(form.stomach.cutEnd, isTrue);
    expect(
      EsophagusForm.alongOf(form.toMm(form.stomach.centres.last)),
      greaterThan(EsophagusAnatomy.opened - 1),
    );
    expect(form.contains(form.stomach.centres.last), isFalse);
    // Hager et al. 2002: 2.61 ± 0.41 cm at the end of the arch, 2.43 ± 0.35
    // at the diaphragm.
    const AnatomyTube aorta = EsophagusAnatomy.aorta;
    expect(2 * aorta.radii.last, inInclusiveRange(26.1 - 4.1, 26.1 + 4.1));
    expect(2 * aorta.radii.first, inInclusiveRange(24.3 - 3.5, 24.3 + 3.5));
    expect(form.aorta.cutEnd, isTrue);
    // Its arch's cut end beside the esophagus on the body's left, then
    // behind it lower down, in its lower third.
    final Offset arch = form.aorta.centres.last;
    expect(form.contains(arch), isFalse);
    expect(arch.dx, greaterThan(form.place(_middle(90)).dx));
    final List<double> behind = <double>[
      for (int i = 0; i < form.aorta.length; i++)
        if (form.contains(form.aorta.centres[i]))
          EsophagusForm.alongOf(form.toMm(form.aorta.centres[i])),
    ];
    expect(behind, isNotEmpty);
    expect(behind.reduce(math.min), greaterThan(EsophagusAnatomy.length / 2));
    // Its lower end comes up out of nothing, behind the diaphragm.
    expect(form.aorta.shown.first, 0);
    for (final TubeCourse half in form.diaphragm) {
      expect(half.cutEnd, isTrue);
      expect(form.contains(half.centres.last), isFalse);
      expect(
        (EsophagusForm.alongOf(form.toMm(half.centres.first)) -
                EsophagusAnatomy.hiatus)
            .abs(),
        lessThan(8),
      );
    }
    // Its right half, the body's, rising toward its higher dome.
    expect(
      form.diaphragm.first.centres.last.dy,
      lessThan(form.diaphragm.last.centres.last.dy),
    );
  });

  test('the step from the body meets the esophagus’s outline and the '
      'body’s at the same places, in the same order round them from the '
      'top', () {
    for (final AnatomyFigure figure in _figures) {
      final AnatomyPart part = _part(figure);
      final EsophagusForm form = _form(figure);
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
        hasLength(6),
        reason: figure.name,
      );
      // The topmost point of its own lies across its top, where it is cut
      // through, not at a corner.
      final List<Offset> own = form.outlinePoints;
      final Offset top = own.reduce(
        (Offset a, Offset b) => a.dy <= b.dy ? a : b,
      );
      final Rect whole = _bounds(own);
      final Rect band = _bounds(<Offset>[
        for (final Offset p in own)
          if (p.dy < whole.top + whole.height * 0.04) p,
      ]);
      expect(
        (top.dx - band.left) / band.width,
        inInclusiveRange(0.15, 0.85),
        reason: figure.name,
      );
      // The body's outline at the hand-over, the esophagus's own once
      // settled.
      final List<Offset> settled = form.outlineAt(1);
      expect(
        _bounds(settled).height,
        closeTo(form.box.height, form.mm(1)),
        reason: figure.name,
      );
    }
  });

  test('where the zoom’s cell lives in the esophagus is told by the Atlas’s '
      'name for the cell', () {
    const Map<String?, EsophagusHome> homes = <String?, EsophagusHome>{
      'Esophageal apical cells': EsophagusHome.mucosa,
      'Esophageal suprabasal cells': EsophagusHome.mucosa,
      'Esophageal basal cells': EsophagusHome.mucosa,
      'Fibroblasts': EsophagusHome.mucosa,
      'Macrophages': EsophagusHome.mucosa,
      'Mast cells': EsophagusHome.mucosa,
      'Submucosal glandular cells': EsophagusHome.glands,
      null: EsophagusHome.mucosa,
    };
    for (final MapEntry<String?, EsophagusHome> cell in homes.entries) {
      expect(EsophagusHome.of(cell.key), cell.value, reason: '${cell.key}');
    }
  });

  test('it is the same esophagus every time', () {
    final EsophagusForm a = _form(AnatomyFigure.male, EsophagusHome.glands);
    final EsophagusForm b = _form(AnatomyFigure.male, EsophagusHome.glands);
    expect(a.outlinePoints, b.outlinePoints);
    expect(a.folds, b.folds);
    expect(a.glands, b.glands);
    expect(a.zLine, b.zLine);
    expect(a.site, b.site);
  });
}

/// The point of the course of the anatomy nearest [s] millimetres along it,
/// near enough for a test.
Offset _middle(double s) {
  const List<Offset> course = EsophagusAnatomy.course;
  double along = 0;
  for (int i = 1; i < course.length; i++) {
    final double step = (course[i] - course[i - 1]).distance;
    if (along + step >= s) {
      return Offset.lerp(course[i - 1], course[i], (s - along) / step)!;
    }
    along += step;
  }
  return course.last;
}
