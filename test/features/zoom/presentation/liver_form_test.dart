import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/features/zoom/domain/anatomy_figure.dart';
import 'package:helixpeek/features/zoom/domain/anatomy_tables.dart';
import 'package:helixpeek/features/zoom/domain/zoom_depth.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/contour.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/organs/liver/liver_anatomy.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/organs/liver/liver_form.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/organs/liver/liver_style.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/tube_course.dart';

final TissueAnatomy _anatomy = tissueAnatomy['liver']!;

/// The organ's view, framed by its width: the form is the same at any.
final double _view = _anatomy.metres * ZoomDepth.organMargin;

final List<AnatomyFigure> _figures = <AnatomyFigure>[
  AnatomyFigure.female,
  AnatomyFigure.male,
];

AnatomyPart _part(AnatomyFigure figure) => figure.parts[_anatomy.uberon]!;

LiverForm _form([
  AnatomyFigure? figure,
  LiverHome home = LiverHome.parenchyma,
]) => LiverForm.place(
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
  test('the liver is drawn at its real size, laid on the body’s outline of '
      'it on either figure, moved a few millimetres at most to lay the '
      'place it is gone into on the place the body goes in', () {
    for (final AnatomyFigure figure in _figures) {
      final String what = figure.name;
      final AnatomyPart part = _part(figure);
      final LiverForm form = _form(figure);
      expect(form.mm(1), closeTo(1e-3 / _view, 1e-15), reason: what);
      expect(form.box.width / form.scale, closeTo(220, 1), reason: what);
      expect(form.box.height / form.scale, closeTo(155, 1), reason: what);
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
      // Where the body goes in, which a liver that follows the body keeps.
      final double real = _anatomy.metres / part.extent;
      final Offset site = (part.site - part.centre) * (real / _view);
      expect((form.site - site).distance, lessThan(1e-9), reason: what);
      expect(form.contains(form.site), isTrue, reason: what);
    }
  });

  test('the zoom goes into its right lobe, in the parenchyma, well clear of '
      'every large vessel and its sheath, of the capsule and of the '
      'gallbladder, on either figure', () {
    for (final AnatomyFigure figure in _figures) {
      final String what = figure.name;
      final LiverForm form = _form(figure);
      expect(form.site.dx, lessThan(form.box.center.dx), reason: what);
      final double down = (form.site.dy - form.box.top) / form.box.height;
      expect(down, inInclusiveRange(0.3, 0.5), reason: what);
      expect(
        LiverForm.clearOfVessels(form.toMm(form.site)),
        greaterThan(8),
        reason: what,
      );
      expect(
        _distanceTo(form.outlinePoints, form.site) / form.scale,
        greaterThan(15),
        reason: what,
      );
      expect(_inside(form.gallbladderWall, form.site), isFalse, reason: what);
      for (final LiverVessel v in form.small) {
        expect(
          (v.centre - form.site).distance / form.scale,
          greaterThan(LiverStyle.siteClear),
          reason: what,
        );
      }
    }
  });

  test('its parts are the sizes they are measured at', () {
    // Gray 1918 and Gupta et al. 2008: 20 to 22.5 cm across, 149.5 ± 18.7
    // mm tall.
    expect(LiverAnatomy.length, inInclusiveRange(200, 225));
    final Rect box = _bounds(LiverAnatomy.outline);
    expect(box.height, inInclusiveRange(149.5 - 18.7, 149.5 + 18.7));
    // The main portal vein, 10.79 ± 1.27 mm (Ayele et al. 2022).
    expect(
      2 * LiverAnatomy.portalVein.radii.first,
      inInclusiveRange(10.79 - 1.27, 10.79 + 1.27),
    );
    // The right hepatic vein where it meets the cava, 8.97 ± 2.29 mm
    // (Gündoğdu 2023).
    expect(
      2 * LiverAnatomy.hepaticVeins.first.radii.first,
      inInclusiveRange(8.97 - 2.29, 8.97 + 2.29),
    );
    // The vena cava, at most 21 mm (Rudski et al. 2010).
    expect(
      LiverAnatomy.cava.radii.map((double r) => 2 * r).reduce(math.max),
      lessThanOrEqualTo(21),
    );
    // The bile duct, 3.1 to 4.4 mm (Hela and Maitra 2025).
    for (final double r in LiverAnatomy.bileDuct.radii) {
      expect(2 * r, inInclusiveRange(3.1, 4.4));
    }
    // The gallbladder, 2.5 cm broad at its widest (Gray 1918).
    expect(
      2 * LiverAnatomy.gallbladderHalf.reduce(math.max),
      lessThanOrEqualTo(25),
    );
  });

  test('its hepatic veins open into the vena cava, and every portal branch '
      'leaves the portal vein or another branch', () {
    double toCourse(AnatomyTube tube, Offset p) =>
        _distanceTo(tube.points, p, closed: false);
    for (final int i in <int>[0, 3, 5]) {
      final AnatomyTube vein = LiverAnatomy.hepaticVeins[i];
      expect(
        toCourse(LiverAnatomy.cava, vein.points.first),
        lessThan(LiverAnatomy.cava.radii.reduce(math.max)),
        reason: 'hepatic vein $i',
      );
    }
    // The tributaries join their veins.
    for (final int i in <int>[1, 2, 4, 6]) {
      final Offset start = LiverAnatomy.hepaticVeins[i].points.first;
      expect(
        <AnatomyTube>[
          for (int j = 0; j < LiverAnatomy.hepaticVeins.length; j++)
            if (j != i) LiverAnatomy.hepaticVeins[j],
        ].any(
          (AnatomyTube t) =>
              toCourse(t, start) < t.radii.reduce(math.max) + 1e-9,
        ),
        isTrue,
        reason: 'hepatic tributary $i',
      );
    }
    final List<AnatomyTube> portal = <AnatomyTube>[
      LiverAnatomy.portalVein,
      ...LiverAnatomy.portalBranches,
    ];
    for (int i = 1; i < portal.length; i++) {
      final Offset start = portal[i].points.first;
      expect(
        <AnatomyTube>[
          for (int j = 0; j < portal.length; j++)
            if (j != i) portal[j],
        ].any(
          (AnatomyTube t) =>
              toCourse(t, start) < t.radii.reduce(math.max) + 1e-9,
        ),
        isTrue,
        reason: 'portal branch $i',
      );
    }
  });

  test('its veins are cut by its outline: the vena cava leaves it above, the '
      'portal vein below, the hepatic artery and the bile duct beside it', () {
    final LiverForm form = _form();
    final Rect outline = form.outline.getBounds();
    for (final Path cavity in <Path>[form.veins, form.portal, form.sheaths]) {
      final Rect box = cavity.getBounds();
      expect(box.isEmpty, isFalse);
      expect(outline.inflate(1e-6).contains(box.topLeft), isTrue);
      expect(outline.inflate(1e-6).contains(box.bottomRight), isTrue);
    }
    bool leaves(TubeCourse tube) =>
        form.contains(tube.centres.first) && !form.contains(tube.centres.last);
    expect(leaves(form.cava), isTrue);
    expect(form.cava.centres.last.dy, lessThan(form.box.top));
    for (final TubeCourse tube in <TubeCourse>[
      form.portalVein,
      form.hepaticArtery,
      form.bileDuct,
    ]) {
      expect(leaves(tube), isTrue);
      expect(tube.centres.last.dy, greaterThan(form.site.dy));
    }
    expect(form.cava.cutEnd, isTrue);
    expect(form.portalVein.cutEnd, isTrue);
    expect(form.hepaticArtery.cutEnd, isTrue);
    expect(form.bileDuct.shown.last, lessThan(0.01));
    expect(form.roundLigament.shown.last, lessThan(0.01));
  });

  test('its gallbladder lies in its fossa under the right lobe, its neck in '
      'the liver and its fundus past the lower border', () {
    final LiverForm form = _form();
    final Offset neck = form.place(LiverAnatomy.gallbladder.first);
    final Offset fundus = form.place(
      LiverAnatomy.gallbladder.last +
          Offset(0, LiverAnatomy.gallbladderHalf.last),
    );
    expect(form.contains(neck), isTrue);
    expect(form.contains(fundus), isFalse);
    expect(
      neck.dx,
      lessThan(form.place(LiverAnatomy.portalVein.points.first).dx),
    );
    expect(
      _area(form.gallbladder).abs(),
      lessThan(_area(form.gallbladderWall).abs()),
    );
  });

  test('the small vessels the cut crosses lie in the parenchyma, apart, '
      'clear of the large vessels, half of them portal tracts', () {
    final LiverForm form = _form();
    expect(form.small.length, inInclusiveRange(30, 120));
    int portal = 0;
    for (int i = 0; i < form.small.length; i++) {
      final LiverVessel v = form.small[i];
      expect(form.contains(v.centre), isTrue);
      expect(
        LiverForm.clearOfVessels(form.toMm(v.centre)),
        greaterThan(LiverStyle.smallClear),
      );
      expect(_inside(form.gallbladderWall, v.centre), isFalse);
      for (int j = i + 1; j < form.small.length; j++) {
        expect(
          (v.centre - form.small[j].centre).distance / form.scale,
          greaterThan(LiverAnatomy.smallApart * 0.3),
        );
      }
      if (v.portal) {
        portal++;
      }
    }
    expect(portal / form.small.length, inInclusiveRange(0.3, 0.7));
  });

  test('a bile duct runs beside each larger portal branch, in its sheath, and '
      'one passes near where the zoom goes in', () {
    final LiverForm form = _form(AnatomyFigure.female, LiverHome.ducts);
    expect(form.ducts, hasLength(LiverAnatomy.ductBranches.length));
    for (int k = 0; k < form.ducts.length; k++) {
      final TubeCourse branch =
          form.portalBranches[LiverAnatomy.ductBranches[k]];
      for (int i = 0; i < branch.length; i++) {
        final double away = (form.ducts[k][i] - branch.centres[i]).distance;
        expect(away, greaterThan(branch.radius[i] * 0.5));
        expect(
          away,
          lessThan(
            math.max(branch.plus[i], branch.minus[i]) +
                form.mm(LiverAnatomy.sheath),
          ),
        );
      }
    }
    expect(
      (form.ductNear(form.site) - form.site).distance / form.scale,
      lessThan(25),
    );
  });

  test('the step from the body meets the liver’s outline and the body’s at '
      'the same places, in the same order round them from the top', () {
    for (final AnatomyFigure figure in _figures) {
      final AnatomyPart part = _part(figure);
      final LiverForm form = _form(figure);
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
      final double liverWay = _area(form.outlinePoints).sign;
      final List<Offset> bodyWay = _area(body).sign == liverWay
          ? body
          : body.reversed.toList();
      expect(order(form.outlinePoints), order(bodyWay), reason: figure.name);
      expect(
        form.marksOf(form.outlinePoints).toSet(),
        hasLength(3),
        reason: figure.name,
      );
      // The body's outline at the hand-over, the liver's own once settled.
      final List<Offset> settled = form.outlineAt(1);
      expect(
        _bounds(settled).width,
        closeTo(form.box.width, form.mm(1)),
        reason: figure.name,
      );
    }
  });

  test('where the zoom’s cell lives in the liver is told by the Atlas’s name '
      'for the cell', () {
    const Map<String?, LiverHome> homes = <String?, LiverHome>{
      'Hepatocytes': LiverHome.parenchyma,
      'Cholangiocytes': LiverHome.ducts,
      'Bile duct cells': LiverHome.ducts,
      'Kupffer cells': LiverHome.parenchyma,
      'Hepatic stellate cells': LiverHome.parenchyma,
      'Endothelial cells': LiverHome.parenchyma,
      'T-cells': LiverHome.parenchyma,
      null: LiverHome.parenchyma,
    };
    for (final MapEntry<String?, LiverHome> cell in homes.entries) {
      expect(LiverHome.of(cell.key), cell.value, reason: '${cell.key}');
    }
  });

  test('it is the same liver every time', () {
    final LiverForm a = _form(AnatomyFigure.male, LiverHome.ducts);
    final LiverForm b = _form(AnatomyFigure.male, LiverHome.ducts);
    expect(a.outlinePoints, b.outlinePoints);
    expect(
      <Offset>[for (final LiverVessel v in a.small) v.centre],
      <Offset>[for (final LiverVessel v in b.small) v.centre],
    );
    expect(a.site, b.site);
    expect(a.veinEdges.length, b.veinEdges.length);
  });
}
