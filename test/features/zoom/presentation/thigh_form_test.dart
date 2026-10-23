import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/features/zoom/domain/anatomy_figure.dart';
import 'package:helixpeek/features/zoom/domain/anatomy_tables.dart';
import 'package:helixpeek/features/zoom/domain/zoom_depth.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/contour.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/organs/bone_marrow/marrow_anatomy.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/organs/skeletal_muscle/thigh_form.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/tube_course.dart';

final TissueAnatomy _anatomy = tissueAnatomy['skeletal muscle']!;

/// The organ's view, framed by its width: the form is the same at any.
final double _view = _anatomy.metres * ZoomDepth.organMargin;

final List<AnatomyFigure> _figures = <AnatomyFigure>[
  AnatomyFigure.female,
  AnatomyFigure.male,
];

AnatomyPart _part(AnatomyFigure figure) => figure.parts[_anatomy.uberon]!;

ThighForm _form([AnatomyFigure? figure]) => ThighForm.place(
  part: _part(figure ?? AnatomyFigure.female),
  figure: figure ?? AnatomyFigure.female,
  view: _view,
);

bool _inside(List<Offset> polygon, Offset p) =>
    (Path()..addPolygon(polygon, true)).contains(p);

double _dot(Offset a, Offset b) => a.dx * b.dx + a.dy * b.dy;

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

/// A tube's outline, both its sides.
List<Offset> _sides(TubeCourse tube) => <Offset>[
  for (int i = 0; i < tube.length; i++) tube.at(i, 1),
  for (int i = tube.length - 1; i >= 0; i--) tube.at(i, -1),
];

/// A fascicle's angle from the vertical, in degrees.
double _slant(List<Offset> fascicle) {
  final Offset run = fascicle.last - fascicle.first;
  return math.atan2(run.dx.abs(), run.dy.abs()) * 180 / math.pi;
}

void main() {
  test('the thigh is drawn at a person’s size in the figure’s own right '
      'thigh, inside its outline, on either figure', () {
    for (final AnatomyFigure figure in _figures) {
      final String what = figure.name;
      final AnatomyPart part = _part(figure);
      final ThighForm form = _form(figure);
      expect(form.mm(1), closeTo(1e-3 / _view, 1e-15), reason: what);
      expect(ThighForm.real, 1);
      // The step from the body starts from the very curve it draws.
      final Path body = Contour(<Offset>[
        for (final Offset p in part.followed) (p - part.centre) / _view,
      ]).toPath();
      expect(form.pathAt(0).getBounds(), body.getBounds(), reason: what);
      final List<Offset> silhouette = <Offset>[
        for (final Offset p in figure.silhouette) (p - part.centre) / _view,
      ];
      // Inside it, or within a millimetre of it where the outline is
      // followed across the crotch's apex.
      for (final Offset p in form.outlinePoints) {
        expect(
          _inside(silhouette, p) || _distanceTo(silhouette, p) < form.mm(1),
          isTrue,
          reason: '$what at $p',
        );
      }
      // About as long as the thigh is, from the iliac spines to below the
      // knee, and as wide.
      expect(
        form.box.height / form.scale,
        inInclusiveRange(440, 520),
        reason: what,
      );
      expect(
        form.box.width / form.scale,
        inInclusiveRange(130, 190),
        reason: what,
      );
      // The patella over the knee, in front of the femur's condyles.
      expect(
        _inside(form.patella, form.knee(Offset.zero)),
        isTrue,
        reason: what,
      );
      expect(
        form.downOf(form.knee(Offset.zero)),
        closeTo(0.92, 0.01),
        reason: what,
      );
    }
  });

  test('the zoom goes in where the body does, in the vastus lateralis, '
      'well clear of the muscles over it and in front of the iliotibial '
      'tract, five eighths of the way from the greater trochanter to the '
      'lateral epicondyle', () {
    // The femur's landmarks as shares of its length from its head's top.
    final double head = MarrowAnatomy.head.dy - MarrowAnatomy.headRadius;
    double trochanter = double.infinity;
    for (final Offset p in MarrowAnatomy.trochanter) {
      trochanter = math.min(trochanter, p.dy);
    }
    Offset epicondyle = MarrowAnatomy.condyles.first;
    for (final Offset p in <Offset>[
      ...MarrowAnatomy.lateralShaft,
      ...MarrowAnatomy.condyles,
    ]) {
      if (p.dx > epicondyle.dx) {
        epicondyle = p;
      }
    }
    final double from = (trochanter - head) / MarrowAnatomy.length;
    final double to = (epicondyle.dy - head) / MarrowAnatomy.length;
    for (final AnatomyFigure figure in _figures) {
      final String what = figure.name;
      final AnatomyPart part = _part(figure);
      final ThighForm form = _form(figure);
      expect(
        (form.site - (part.site - part.centre) / _view).distance,
        lessThan(1e-9),
        reason: what,
      );
      final List<Offset> lateralis = form.vastusLateralis.outline;
      expect(_inside(lateralis, form.site), isTrue, reason: what);
      expect(
        _distanceTo(lateralis, form.site) / form.scale,
        greaterThan(6),
        reason: what,
      );
      for (final List<Offset> over in <List<Offset>>[
        form.rectusFemoris.outline,
        form.tensor.outline,
        form.sartorius.outline,
        form.tractOutline,
      ]) {
        expect(_inside(over, form.site), isFalse, reason: what);
      }
      expect(
        _distanceTo(form.tractOutline, form.site) / form.scale,
        greaterThan(4),
        reason: what,
      );
      final double band = (form.downOf(form.site) - from) / (to - from);
      expect(band, closeTo(5 / 8, 0.03), reason: what);
    }
  });

  test('its muscles lie as the plates draw them', () {
    for (final AnatomyFigure figure in _figures) {
      final String what = figure.name;
      final ThighForm form = _form(figure);
      // Across the middle of the thigh, from lateral: the vastus lateralis,
      // the rectus femoris, the vastus medialis.
      double middleOf(List<Offset> outline, double down) {
        final List<double> xs = <double>[];
        for (int i = 0; i < outline.length; i++) {
          final Offset a = outline[i];
          final Offset b = outline[(i + 1) % outline.length];
          final double y = form.place(Offset(0.5, down)).dy;
          if ((a.dy > y) != (b.dy > y)) {
            xs.add(a.dx + (y - a.dy) * (b.dx - a.dx) / (b.dy - a.dy));
          }
        }
        return xs.reduce((double a, double b) => a + b) / xs.length;
      }

      expect(
        middleOf(form.vastusLateralis.outline, 0.6),
        lessThan(middleOf(form.rectusFemoris.outline, 0.6)),
        reason: what,
      );
      expect(
        middleOf(form.rectusFemoris.outline, 0.6),
        lessThan(middleOf(form.vastusMedialis.outline, 0.6)),
        reason: what,
      );
      // The sartorius crosses from the lateral side at the top to the medial
      // side at the bottom.
      final Rect sartorius = _bounds(form.sartorius.outline);
      final Offset top = form.sartorius.outline.reduce(
        (Offset a, Offset b) => a.dy < b.dy ? a : b,
      );
      expect(top.dx, lessThan(sartorius.center.dx), reason: what);
      expect(
        form.sartorius.outline
            .reduce((Offset a, Offset b) => a.dx > b.dx ? a : b)
            .dy,
        greaterThan(sartorius.center.dy),
        reason: what,
      );
      // Down the femoral triangle, nerve, artery and vein from lateral to
      // medial, each running under the sartorius at its lower end.
      expect(
        form.nerve.centres.first.dx,
        lessThan(form.artery.centres.first.dx),
        reason: what,
      );
      expect(
        form.artery.centres.first.dx,
        lessThan(form.vein.centres.first.dx),
        reason: what,
      );
      for (final TubeCourse tube in <TubeCourse>[
        form.artery,
        form.vein,
        form.nerveBranches.first,
      ]) {
        expect(
          _inside(form.sartorius.outline, tube.centres.last),
          isTrue,
          reason: what,
        );
        expect(tube.shown.last, lessThan(0.05), reason: what);
      }
      // Each name points into what it names, clear of what lies over it.
      for (final (Offset at, List<Offset> muscle) in <(Offset, List<Offset>)>[
        (form.rectusName, form.rectusFemoris.outline),
        (form.sartoriusName, form.sartorius.outline),
        (form.medialisName, form.vastusMedialis.outline),
      ]) {
        expect(_inside(muscle, at), isTrue, reason: what);
        expect(
          _distanceTo(muscle, at) / form.scale,
          greaterThan(3),
          reason: what,
        );
      }
      expect(
        _inside(form.sartorius.outline, form.rectusName),
        isFalse,
        reason: what,
      );
      expect(
        _inside(form.sartorius.outline, form.medialisName),
        isFalse,
        reason: what,
      );
    }
  });

  test('its muscles are as long as they are measured, and their fibres '
      'slant as they do', () {
    for (final AnatomyFigure figure in _figures) {
      final String what = figure.name;
      final ThighForm form = _form(figure);
      double longOf(List<Offset> outline) =>
          _bounds(outline).height / form.scale;
      // Ward et al. 2009: the rectus femoris 36.3 ± 4.7 cm long.
      expect(
        longOf(form.rectusFemoris.outline),
        closeTo(363, 47),
        reason: what,
      );
      // The vastus lateralis's fibres leave it down and in, turning across
      // at its lower end; the vastus medialis's more so; the rectus
      // femoris's slant a little either side of its tendon.
      final List<List<Offset>> lateralis = form.vastusLateralis.fascicles;
      expect(_slant(lateralis.first), inInclusiveRange(10, 35), reason: what);
      expect(_slant(lateralis.last), greaterThan(35), reason: what);
      final List<List<Offset>> medialis = form.vastusMedialis.fascicles;
      expect(_slant(medialis.last), greaterThan(40), reason: what);
      for (final List<Offset> f in form.rectusFemoris.fascicles) {
        expect(_slant(f), lessThan(35), reason: what);
      }
      for (final ThighMuscle muscle in form.muscles) {
        expect(muscle.fascicles.length, greaterThanOrEqualTo(2), reason: what);
      }
    }
  });

  test('its parts make one outline, with nothing between them', () {
    for (final AnatomyFigure figure in _figures) {
      final ThighForm form = _form(figure);
      Path union = Path();
      for (final List<Offset> p in <List<Offset>>[
        form.deep,
        for (final ThighMuscle m in form.muscles) m.outline,
        form.tractOutline,
        form.retinacula,
        form.quadricepsTendon,
        form.patella,
        form.patellarLigament,
      ]) {
        // In millimetres, as the form takes it.
        union = Path.combine(
          PathOperation.union,
          union,
          Path()..addPolygon(<Offset>[
            for (final Offset q in p) q / form.scale,
          ], true),
        );
      }
      expect(union.computeMetrics().length, 1, reason: figure.name);
      expect(_sides(form.tract).length, greaterThan(4));
    }
  });

  test('the step from the body meets the vastus lateralis’s outline and '
      'the body’s at the same places, in the same order', () {
    for (final AnatomyFigure figure in _figures) {
      final String what = figure.name;
      final AnatomyPart part = _part(figure);
      final ThighForm form = _form(figure);
      final List<Offset> diagram = Contour(<Offset>[
        for (final Offset p in part.followed) (p - part.centre) / _view,
      ]).sampled(8).points;
      List<int> order(List<Offset> points) {
        final List<Offset> marks = form.marksOf(points);
        int top = 0;
        for (int i = 1; i < points.length; i++) {
          if (points[i].dy < points[top].dy) {
            top = i;
          }
        }
        final List<int> at = <int>[
          for (final Offset m in marks) points.indexOf(m),
        ];
        expect(at.toSet().length, at.length, reason: '$what: marks distinct');
        final List<int> ranks = <int>[for (int k = 0; k < at.length; k++) k]
          ..sort(
            (int a, int b) => ((at[a] - top) % points.length).compareTo(
              (at[b] - top) % points.length,
            ),
          );
        return ranks;
      }

      List<Offset> lateralis = form.vastusLateralis.outline;
      double area(List<Offset> p) {
        double sum = 0;
        for (int i = 0; i < p.length; i++) {
          sum +=
              p[i].dx * p[(i + 1) % p.length].dy -
              p[(i + 1) % p.length].dx * p[i].dy;
        }
        return sum;
      }

      if (area(lateralis).sign != area(diagram).sign) {
        lateralis = lateralis.reversed.toList();
      }
      expect(order(lateralis), order(diagram), reason: what);
      // On the step, the flat shape draws in from the one to the other.
      expect(_bounds(form.outlineAt(1)), _bounds(form.outlineAt(1)));
    }
  });

  test('the form is the same every time', () {
    final ThighForm a = _form();
    final ThighForm b = _form();
    expect(a.outlinePoints, b.outlinePoints);
    expect(a.vastusLateralis.fascicles, b.vastusLateralis.fascicles);
    expect(a.site, b.site);
  });
}
