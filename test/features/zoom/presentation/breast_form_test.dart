import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/features/zoom/domain/anatomy_figure.dart';
import 'package:helixpeek/features/zoom/domain/anatomy_tables.dart';
import 'package:helixpeek/features/zoom/domain/zoom_depth.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/contour.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/lobules.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/organs/breast/breast_anatomy.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/organs/breast/breast_form.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/tube_course.dart';

final TissueAnatomy _anatomy = tissueAnatomy['breast']!;

/// The organ's view, framed by its width: the form is the same at any.
final double _view = _anatomy.metres * ZoomDepth.organMargin;

final List<AnatomyFigure> _figures = <AnatomyFigure>[
  AnatomyFigure.female,
  AnatomyFigure.male,
];

AnatomyPart _part(AnatomyFigure figure) => figure.parts[_anatomy.uberon]!;

BreastForm _form([AnatomyFigure? figure, bool withFigure = true]) =>
    BreastForm.place(
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
  test('the breast is drawn at its real size, the card’s 15 cm across at '
      'its nipple, laid on the body’s outline of it on either figure, its '
      'mound moved little more than a centimetre to lay the place it is '
      'gone into on the place the body goes in', () {
    for (final AnatomyFigure figure in _figures) {
      final String what = figure.name;
      final AnatomyPart part = _part(figure);
      final BreastForm form = _form(figure);
      expect(form.mm(1), closeTo(1e-3 / _view, 1e-15), reason: what);
      // Across at the nipple's height, from side to side.
      final List<double> across = <double>[];
      final int n = form.outlinePoints.length;
      for (int i = 0; i < n; i++) {
        final Offset a = form.toMm(form.outlinePoints[i]);
        final Offset b = form.toMm(form.outlinePoints[(i + 1) % n]);
        if ((a.dy <= 0) != (b.dy <= 0)) {
          across.add(a.dx + (0 - a.dy) * (b.dx - a.dx) / (b.dy - a.dy));
        }
      }
      expect(across, hasLength(2), reason: what);
      expect(
        (across.first - across.last).abs(),
        closeTo(BreastAnatomy.length, 1),
        reason: what,
      );
      // Its mound as tall as the female anatomogram's oval is for its
      // width, its tail reaching up and out past it.
      expect(form.box.height / form.scale, inInclusiveRange(125, 135));
      expect(form.moundShift, lessThan(14), reason: what);
      // Where the body goes in, which a breast that follows the body
      // keeps.
      final double real = _anatomy.metres / part.extent;
      final Offset site = (part.site - part.centre) * (real / _view);
      expect((form.site - site).distance, lessThan(1e-9), reason: what);
      expect(form.contains(form.site), isTrue, reason: what);
    }
  });

  test('the zoom goes in under the areola, on a duct below the skin’s cut, '
      'where GTEx samples it, on either figure', () {
    for (final AnatomyFigure figure in _figures) {
      final String what = figure.name;
      final BreastForm form = _form(figure);
      final Offset site = form.toMm(form.site);
      expect(site.distance, lessThan(BreastAnatomy.areola), reason: what);
      expect(BreastForm.clearOfCut(site), greaterThan(1.5), reason: what);
      expect(BreastForm.clearOfDucts(site), lessThan(0), reason: what);
      expect(_inside(form.dissection, form.site), isTrue, reason: what);
    }
  });

  test('the nipple stays whole above the cut, the areola’s upper half with '
      'it, each as wide as measured', () {
    final BreastForm form = _form();
    // The nipple 1.2 cm across (Archibong), the areola 4.5 (Al-Qattan).
    expect(2 * form.nippleRadius / form.scale, closeTo(12.3, 0.1));
    expect(2 * form.areolaRadius / form.scale, closeTo(45, 0.1));
    expect(BreastAnatomy.nipple, lessThan(BreastAnatomy.cut));
    for (final Offset p in BreastAnatomy.areolarGlands) {
      expect(p.dy, lessThan(0));
      expect(
        p.distance,
        inExclusiveRange(BreastAnatomy.nipple, BreastAnatomy.areola),
      );
    }
    for (final Offset p in BreastAnatomy.orifices) {
      expect(p.distance, lessThan(BreastAnatomy.nipple / 2));
    }
    // Above the cut its skin; below it the dissection, inside the cut
    // skin, which is as thick as the breast's is measured.
    for (final Offset p in form.upper) {
      expect(form.toMm(p).dy, lessThanOrEqualTo(BreastAnatomy.cut + 1e-9));
    }
    for (final Offset p in form.dissection) {
      expect(
        form.toMm(p).dy,
        greaterThanOrEqualTo(BreastAnatomy.cut + BreastAnatomy.skin - 1e-9),
      );
      expect(form.contains(p), isTrue);
    }
    for (final double skin in <double>[
      BreastAnatomy.skin,
      BreastAnatomy.skinBelow,
    ]) {
      expect(skin, inInclusiveRange(0.5, 2.7));
    }
  });

  test('its five duct systems in the lower half run in to the nipple from '
      'its lobes, each first branching under the areola about 8 mm from the '
      'nipple, none as wide as a lactating breast’s, and its lobules lie at '
      'their ends inside the lobes, each as small as a resting lobule', () {
    final List<List<BreastDuct>> ducts = BreastForm.ductsMm;
    expect(ducts, hasLength(5));
    for (int k = 0; k < ducts.length; k++) {
      final BreastDuct main = ducts[k].firstWhere(
        (BreastDuct d) => d.generation == 0,
      );
      // From under the nipple's edge.
      expect(main.course.first.distance, lessThan(BreastAnatomy.nipple));
      final double branch = main.course.last.distance - BreastAnatomy.nipple;
      expect(branch, inInclusiveRange(3, 13), reason: 'lobe $k');
      expect(main.course.last.distance, lessThan(BreastAnatomy.areola));
      for (final BreastDuct d in ducts[k]) {
        expect(d.width, lessThan(1.9), reason: 'lobe $k');
        // Each branch runs on out from the one it leaves.
        expect(
          d.course.last.distance,
          greaterThan(d.course.first.distance),
          reason: 'lobe $k, generation ${d.generation}',
        );
        expect(d.course.every((Offset p) => p.dy > 0), isTrue);
        // Outside the areola's radius, each runs in its lobe.
        for (final Offset p in d.course) {
          if (p.distance > BreastAnatomy.lobeFrom + 1) {
            expect(
              _inside(BreastForm.lobesMm[k], p),
              isTrue,
              reason: 'lobe $k, $p',
            );
          }
        }
      }
      // Each lobe's terminal ducts, eight, reach out toward its edge.
      expect(
        ducts[k].where((BreastDuct d) => d.generation == 3),
        hasLength(8),
        reason: 'lobe $k',
      );
    }
    // Every lobule inside a lobe, clear of its edge.
    expect(BreastForm.lobulesMm.length, greaterThan(200));
    for (final Offset p in BreastForm.lobulesMm) {
      expect(BreastForm.inLobe(p), isTrue, reason: '$p');
    }
    expect(BreastAnatomy.lobule, closeTo(0.74, 1e-9));
    // The lobes in the lower half, beyond the areola, inside the
    // dissection's outline but where the cut crosses them.
    for (final List<Offset> lobe in BreastForm.lobesMm) {
      for (final Offset p in lobe) {
        expect(p.distance, greaterThan(BreastAnatomy.areola), reason: '$p');
        expect(p.dy, greaterThan(0), reason: '$p');
      }
    }
  });

  test('the fat lies between the lobes and round them, none under the '
      'areola, and the ligaments run out through it from the gland to the '
      'cut skin', () {
    for (final AnatomyFigure figure in _figures) {
      final String what = figure.name;
      final BreastForm form = _form(figure);
      expect(form.fatLobules.length, greaterThan(40), reason: what);
      for (final Lobule lobule in form.fatLobules) {
        final Offset c = form.toMm(lobule.centre);
        expect(c.distance, greaterThan(BreastAnatomy.areola), reason: '$c');
        expect(BreastForm.inLobe(c), isFalse, reason: '$c');
        expect(_inside(form.dissection, lobule.centre), isTrue);
      }
    }
    expect(BreastForm.ligamentsMm, hasLength(BreastAnatomy.ligaments.length));
    for (final List<Offset> ligament in BreastForm.ligamentsMm) {
      // Out from the middle, ending at the dissection's edge.
      expect(ligament.last.distance, greaterThan(ligament.first.distance + 4));
      expect(
        _distanceTo(BreastForm.dissectionMm, ligament.last),
        lessThan(0.6),
      );
      for (final Offset p in ligament) {
        expect(_inside(BreastForm.dissectionMm, p), isTrue, reason: '$p');
      }
    }
  });

  test('its axillary tail runs up and out toward the figure’s axillary '
      'nodes, which are named where they show beside it, clear of the '
      'pectoralis over them, inside the view; nothing without a figure', () {
    expect(BreastAnatomy.tailTip.dx, lessThan(BreastAnatomy.tailRoot.dx));
    expect(BreastAnatomy.tailTip.dy, lessThan(BreastAnatomy.tailRoot.dy));
    for (final AnatomyFigure figure in _figures) {
      final String what = figure.name;
      final BreastForm form = _form(figure);
      expect(form.contains(form.tailName), isTrue, reason: what);
      final List<Offset> nodes = form.nodesOutline!;
      final Offset at = form.nodesName!;
      expect(_inside(nodes, at), isTrue, reason: what);
      expect(form.contains(at), isFalse, reason: what);
      expect(_inside(form.pectoralis, at), isFalse, reason: what);
      expect(at.dx.abs(), lessThanOrEqualTo(0.45), reason: what);
      expect(at.dy.abs(), lessThanOrEqualTo(0.45), reason: what);
      // Lateral to the breast and above its middle, toward the axilla.
      expect(at.dx, lessThan(form.box.left + form.box.width * 0.2));
      expect(at.dy, lessThan(form.box.center.dy));
      // The tail's tip nearer the nodes than the nipple is.
      final Offset tip = form.place(BreastAnatomy.tailTip);
      expect(
        _distanceTo(nodes, tip),
        lessThan(_distanceTo(nodes, form.nipple)),
        reason: what,
      );
    }
    final BreastForm bare = _form(AnatomyFigure.female, false);
    expect(bare.nodesOutline, isNull);
    expect(bare.nodesName, isNull);
  });

  test('the internal thoracic perforators come from beside the sternum in '
      'under its medial edge, the lateral thoracic artery down beside its '
      'lateral edge, each cut short, and the latter’s small branches run in '
      'under the edge', () {
    final BreastForm form = _form();
    for (final TubeCourse perforator in form.perforators) {
      expect(perforator.cutEnd, isTrue);
      expect(form.contains(perforator.centres.first), isTrue);
      expect(form.contains(perforator.centres.last), isFalse);
      expect(perforator.centres.last.dx, greaterThan(form.box.right));
    }
    // From the first, second and third intercostal spaces, the second the
    // widest (Thuy).
    final List<double> widths = <double>[
      for (final AnatomyTube t in BreastAnatomy.perforators) t.radii.first,
    ];
    expect(widths[1], greaterThan(widths[0]));
    expect(widths[1], greaterThan(widths[2]));
    final TubeCourse lateral = form.lateralThoracic;
    expect(lateral.cutEnd, isTrue);
    for (int i = 0; i < lateral.length; i++) {
      expect(form.contains(lateral.centres[i]), isFalse, reason: 'row $i');
      expect(lateral.centres[i].dx, lessThan(form.box.center.dx));
    }
    expect(form.branches.length, inInclusiveRange(2, 6));
    for (final TubeCourse branch in form.branches) {
      expect(form.contains(branch.centres.first), isFalse);
      expect(form.contains(branch.centres.last), isTrue);
    }
  });

  test('the pectoralis lies under it and round it, showing whole near it '
      'and fading out with its distance from it', () {
    final BreastForm form = _form();
    // Its lower border rises behind the breast: the breast's lower pole
    // lies below it, its upper half on it.
    expect(_inside(form.pectoralis, form.place(const Offset(0, -40))), isTrue);
    expect(_inside(form.pectoralis, form.place(const Offset(0, 50))), isFalse);
    expect(BreastForm.fadeAt(const Offset(0, 0)), 1);
    expect(BreastForm.fadeAt(const Offset(0, -64)), closeTo(1, 1e-9));
    expect(BreastForm.fadeAt(const Offset(0, -120)), 0);
    expect(BreastForm.fadeAt(const Offset(30, -80)), inExclusiveRange(0, 1));
    for (final (Offset a, Offset b, double shown) in form.fibres) {
      expect(shown, inInclusiveRange(0, 1));
      expect(form.contains(Offset.lerp(a, b, 0.5)!), isFalse);
    }
  });

  test('the step from the body meets the breast’s outline and the body’s at '
      'the same places, in the same order round them from the middle of its '
      'top', () {
    for (final AnatomyFigure figure in _figures) {
      final AnatomyPart part = _part(figure);
      final BreastForm form = _form(figure);
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
      // The top's middle on the mound's, not the tail's tip, on either
      // outline; the medial side's outermost point to the right, the
      // lateral's to the left, below the tail.
      for (final List<Offset> points in <List<Offset>>[
        form.outlinePoints,
        bodyWay,
      ]) {
        final List<Offset> marks = form.marksOf(points);
        final Rect box = _bounds(points);
        expect(marks[0].dy - box.top, lessThan(box.height * 0.12));
        expect(
          marks[0].dx,
          greaterThan(box.left + box.width * 0.35),
          reason: figure.name,
        );
        expect(marks[1].dx, greaterThan(box.center.dx));
        expect(marks[3].dx, lessThan(box.center.dx));
        expect(marks[3].dy, greaterThan(box.top + box.height * 0.45));
      }
      // The body's outline at the hand-over, the breast's own once
      // settled.
      final List<Offset> settled = form.outlineAt(1);
      expect(
        _bounds(settled).width,
        closeTo(form.box.width, form.mm(1)),
        reason: figure.name,
      );
    }
  });

  test(
    'a cell lives where the Atlas names it: in the fat for an adipocyte, '
    'in the nipple and areola for a smooth muscle cell, else in the gland',
    () {
      expect(BreastHome.of('Breast lactating cells'), BreastHome.gland);
      expect(BreastHome.of('Breast myoepithelial cells'), BreastHome.gland);
      expect(BreastHome.of('Breast glandular cells'), BreastHome.gland);
      expect(
        BreastHome.of('Breast hormone-responsive cells'),
        BreastHome.gland,
      );
      expect(BreastHome.of('T-cells'), BreastHome.gland);
      expect(BreastHome.of(null), BreastHome.gland);
      expect(BreastHome.of('Adipocytes (Breast)'), BreastHome.fat);
      expect(BreastHome.of('Adipocytes'), BreastHome.fat);
      expect(BreastHome.of('Smooth muscle cells'), BreastHome.nipple);
      expect(BreastHome.gland.word, 'ducts and lobules');
    },
  );

  test('it is the same breast every time', () {
    final BreastForm a = _form(AnatomyFigure.male);
    final BreastForm b = _form(AnatomyFigure.male);
    expect(a.outlinePoints, b.outlinePoints);
    expect(a.lobules, b.lobules);
    expect(a.site, b.site);
    expect(a.fatLobules.length, b.fatLobules.length);
    expect(a.branches.length, b.branches.length);
    expect(a.nodesName, b.nodesName);
    expect(a.ligamentName, b.ligamentName);
    expect(a.fatName, b.fatName);
  });
}
