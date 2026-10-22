import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/features/zoom/domain/anatomy_figure.dart';
import 'package:helixpeek/features/zoom/domain/anatomy_tables.dart';
import 'package:helixpeek/features/zoom/domain/zoom_depth.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/contour.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/organs/heart/heart_anatomy.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/organs/heart/heart_form.dart';

final TissueAnatomy _anatomy = tissueAnatomy['heart muscle']!;

/// The organ's view, framed as a heart's by its width: the form is the same
/// at any.
final double _view = _anatomy.metres * ZoomDepth.organMargin;

final List<AnatomyFigure> _figures = <AnatomyFigure>[
  AnatomyFigure.female,
  AnatomyFigure.male,
];

AnatomyPart _part(AnatomyFigure figure) => figure.parts[_anatomy.uberon]!;

HeartForm _form([AnatomyFigure? figure]) =>
    HeartForm.place(part: _part(figure ?? AnatomyFigure.female), view: _view);

/// Down the left ventricle's axis, and across it toward its free wall.
const double _tilt = HeartAnatomy.tilt * math.pi / 180;
final Offset _ax = Offset(math.sin(_tilt), math.cos(_tilt));
final Offset _nx = Offset(math.cos(_tilt), -math.sin(_tilt));

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

/// Where [line] crosses the height [y] furthest to the right.
double _crossing(List<Offset> line, double y) {
  double best = double.negativeInfinity;
  for (int i = 1; i < line.length; i++) {
    final Offset a = line[i - 1];
    final Offset b = line[i];
    if ((a.dy - y) * (b.dy - y) <= 0 && a.dy != b.dy) {
      best = math.max(best, a.dx + (b.dx - a.dx) * (y - a.dy) / (b.dy - a.dy));
    }
  }
  return best;
}

Rect _bounds(List<Offset> points) => points.fold<Rect>(
  Rect.fromPoints(points.first, points.first),
  (Rect r, Offset p) => r.expandToInclude(Rect.fromPoints(p, p)),
);

void main() {
  test('the heart is drawn at its real size, laid on the body’s outline of '
      'it on either figure: as high as its middle, across so that its left '
      'ventricle’s free wall runs through the place the body goes in, within '
      'a few millimetres of the outline’s middle', () {
    for (final AnatomyFigure figure in _figures) {
      final String what = figure.name;
      final AnatomyPart part = _part(figure);
      final HeartForm form = _form(figure);
      expect(form.mm(1), closeTo(1e-3 / _view, 1e-15), reason: what);
      // The body's outline is grown to cover as much as the heart's own.
      final double real = HeartForm.realFor(part);
      final Rect heart = Rect.fromLTWH(
        0,
        0,
        form.box.width / form.scale,
        form.box.height / form.scale,
      );
      expect(
        real * real * part.box.width * part.box.height,
        closeTo(heart.width * heart.height * 1e-6, 1e-9),
        reason: what,
      );
      expect(form.box.center.dy, closeTo(0, 1e-9), reason: what);
      expect(form.anchorShift.abs(), lessThan(3), reason: what);
      final Rect body = _bounds(form.outlineAt(0));
      for (final double edge in <double>[
        body.left - form.box.left,
        body.right - form.box.right,
        body.top - form.box.top,
        body.bottom - form.box.bottom,
      ]) {
        expect((edge / form.scale).abs(), lessThan(12), reason: what);
      }
      // Where the body goes in, which a heart that follows the body keeps:
      // in its left ventricle's free wall, well in from both its faces, in
      // the upper two thirds of the wall.
      final Offset site = (part.site - part.centre) * (real / _view);
      expect((form.site - site).distance, lessThan(1e-9), reason: what);
      expect(form.outline.contains(form.site), isTrue, reason: what);
      final double inner = _crossing(form.freeEndo, form.site.dy);
      final double outer = _crossing(form.freeEpi, form.site.dy);
      expect((form.site.dx - inner) / form.scale, greaterThan(3), reason: what);
      expect((outer - form.site.dx) / form.scale, greaterThan(3), reason: what);
      final double down =
          (form.site.dy - form.freeEndo.first.dy) /
          (form.freeEndo.last.dy - form.freeEndo.first.dy);
      expect(down, inInclusiveRange(0.15, 0.67), reason: what);
    }
  });

  test('its parts are the sizes they are measured at', () {
    final HeartForm form = _form();
    double mm(double scene) => scene / form.scale;
    final Offset base = (form.freeEndo.first + form.septumLv.first) / 2;
    double u(Offset p) => mm(_dot(p - base, _ax));
    double v(Offset p) => mm(_dot(p - base, _nx));
    // The left ventricle: 52 mm across at its widest, 86 long.
    final double across =
        form.freeEndo.map(v).reduce(math.max) -
        form.septumLv.map(v).reduce(math.min);
    expect(across, closeTo(HeartAnatomy.lvWidth, 0.5));
    expect(form.freeEndo.map(u).reduce(math.max), closeTo(86, 0.5));
    // Its walls as thick as they are measured, at the base, the middle and
    // the apex; the septum's at the base and the middle.
    int at(List<Offset> line, double depth) {
      int best = 0;
      for (int i = 1; i < line.length; i++) {
        if ((u(line[i]) - depth).abs() < (u(line[best]) - depth).abs()) {
          best = i;
        }
      }
      return best;
    }

    double free(int i) => mm((form.freeEpi[i] - form.freeEndo[i]).distance);
    double septum(int i) => mm((form.septumRv[i] - form.septumLv[i]).distance);
    expect(free(0), closeTo(HeartAnatomy.freeWall[0], 0.05));
    expect(
      free(at(form.freeEndo, HeartAnatomy.wallMiddle)),
      closeTo(HeartAnatomy.freeWall[1], 0.15),
    );
    expect(
      free(form.freeEndo.length - 1),
      closeTo(HeartAnatomy.freeWall[2], 0.05),
    );
    expect(septum(0), closeTo(HeartAnatomy.septum[0], 0.05));
    expect(
      septum(at(form.septumLv, HeartAnatomy.wallMiddle)),
      closeTo(HeartAnatomy.septum[1], 0.15),
    );
    // The right ventricle's free wall, and the atria's walls.
    final int middle = form.rvEndo.length ~/ 2;
    expect(
      mm((form.rvEpi[middle] - form.rvEndo[middle]).distance),
      closeTo(HeartAnatomy.rvWall, 0.05),
    );
    for (final (List<Offset> a, List<Offset> b) in form.bands.skip(3)) {
      final int k = a.length ~/ 2;
      expect(
        mm((a[k] - b[k]).distance),
        closeTo(HeartAnatomy.atrialWall, 0.05),
      );
    }
    // The valves' annuli.
    expect(
      mm((form.mitral.$2 - form.mitral.$1).distance),
      inInclusiveRange(30, 35),
    );
    expect(
      mm((form.tricuspid.$2 - form.tricuspid.$1).distance),
      closeTo(HeartAnatomy.tricuspid, 1),
    );
    // The great vessels' calibres: the aortic root at its annulus, sinus and
    // sinotubular junction, the pulmonary trunk and its branches, the venae
    // cavae and the pulmonary veins.
    double width(HeartVessel vessel, int knot) =>
        2 * mm(vessel.course.radius[vessel.course.knotRows[knot]]);
    expect(width(form.aorta, 0), closeTo(23, 0.01));
    expect(width(form.aorta, 1), closeTo(32, 0.01));
    expect(width(form.aorta, 2), closeTo(25, 0.01));
    expect(width(form.pulmonary.last, 0), closeTo(23, 0.01));
    expect(width(form.pulmonary.first, 0), inInclusiveRange(16.6, 20.2));
    expect(width(form.behind.first, 0), inInclusiveRange(16.6, 20.2));
    for (final HeartVessel vein in form.behind.skip(1)) {
      expect(width(vein, 0), inInclusiveRange(9, 21));
    }
    // The coronary arteries' lumens.
    for (final HeartCoronary c in form.coronaries) {
      expect(2 * mm(c.lumen), inInclusiveRange(2.8, 4.2));
    }
  });

  test('each chamber is named inside its cavity, clear of every vessel drawn '
      'over it', () {
    for (final AnatomyFigure figure in _figures) {
      final HeartForm form = _form(figure);
      final List<List<Offset>> vessels = <List<Offset>>[
        for (final HeartVessel v in <HeartVessel>[
          ...form.behind,
          ...form.branches,
          form.aorta,
          form.infundibulum,
          ...form.pulmonary,
        ])
          v.outer,
      ];
      for (final (Offset name, HeartCavity cavity) in <(Offset, HeartCavity)>[
        (form.rightAtrium, form.raCavity),
        (form.leftAtrium, form.laCavity),
        (form.rightVentricle, form.rvCavity),
        (form.leftVentricle, form.lvCavity),
      ]) {
        expect(_inside(cavity.shape, name), isTrue, reason: '$name');
        for (final List<Offset> vessel in vessels) {
          expect(_inside(vessel, name), isFalse, reason: '$name');
        }
      }
    }
  });

  test('the epicardium is the heart’s own surface: on its outline, clear of '
      'the great vessels, broken where they leave it', () {
    final HeartForm form = _form();
    expect(form.epicardium.length, greaterThan(1));
    final List<List<Offset>> vessels = <List<Offset>>[
      for (final HeartVessel v in <HeartVessel>[
        ...form.behind,
        ...form.branches,
        form.aorta,
        ...form.pulmonary,
      ])
        v.outer,
    ];
    for (final List<Offset> run in form.epicardium) {
      for (final Offset p in run) {
        expect(_distanceTo(form.outlinePoints, p) / form.scale, lessThan(0.6));
        for (final List<Offset> vessel in vessels) {
          expect(_inside(vessel, p), isFalse);
        }
      }
    }
  });

  test('the coronary arteries lie in the fat of their grooves, the right '
      'coronary’s beside the tricuspid annulus, the circumflex’s beside the '
      'mitral', () {
    final HeartForm form = _form();
    expect(form.coronaries.length, 2);
    for (int i = 0; i < 2; i++) {
      final HeartCoronary c = form.coronaries[i];
      expect(_inside(form.fat[i], c.centre), isTrue);
      expect(_distanceTo(form.fat[i], c.centre), greaterThan(c.outer));
    }
    final (Offset _, Offset lateral) = form.tricuspid;
    final (Offset _, Offset free) = form.mitral;
    expect(
      (form.coronaries[0].centre - lateral).distance / form.scale,
      lessThan(12),
    );
    expect(
      (form.coronaries[1].centre - free).distance / form.scale,
      lessThan(16),
    );
  });

  test('the left ventricle has two papillary muscles and the right two, '
      'with its moderator band; each chorda runs from a papillary muscle’s '
      'tip to a leaflet', () {
    final HeartForm form = _form();
    expect(form.papillary.length, 4);
    expect(form.moderator.length, greaterThan(4));
    expect(form.leaflets.length, 4);
    expect(form.chordae.length, greaterThanOrEqualTo(12));
    for (final (Offset from, Offset to) in form.chordae) {
      expect(
        form.papillary
                .map((List<Offset> p) => _distanceTo(p, from))
                .reduce(math.min) /
            form.scale,
        lessThan(1),
      );
      expect(
        form.leaflets
                .map((List<Offset> l) => _distanceTo(l, to))
                .reduce(math.min) /
            form.scale,
        lessThan(0.8),
      );
    }
  });

  test('the step from the body meets the heart’s outline and the body’s at '
      'the same six places, in the same order round them from the top', () {
    for (final AnatomyFigure figure in _figures) {
      final AnatomyPart part = _part(figure);
      final HeartForm form = _form(figure);
      final double real = HeartForm.realFor(part);
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
      final double heartWay = _area(form.outlinePoints).sign;
      final List<Offset> bodyWay = _area(body).sign == heartWay
          ? body
          : body.reversed.toList();
      expect(order(form.outlinePoints), order(bodyWay), reason: figure.name);
    }
  });

  test('it is the same heart every time', () {
    final HeartForm a = _form();
    final HeartForm b = _form();
    expect(a.outlinePoints, b.outlinePoints);
    expect(a.lvCavity.shape, b.lvCavity.shape);
    expect(a.rvCavity.shape, b.rvCavity.shape);
    expect(a.chordae, b.chordae);
    expect(a.site, b.site);
  });
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
