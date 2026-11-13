import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/features/zoom/domain/anatomy_figure.dart';
import 'package:helixpeek/features/zoom/domain/anatomy_tables.dart';
import 'package:helixpeek/features/zoom/domain/zoom_depth.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/contour.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/organs/cervix/cervix_anatomy.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/organs/cervix/cervix_form.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/organs/uterus/uterus_anatomy.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/organs/uterus/uterus_form.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/tube_course.dart';

final TissueAnatomy _anatomy = tissueAnatomy['endometrium']!;

/// The organ's view, framed by its width: the form is the same at any.
final double _view = _anatomy.metres * ZoomDepth.organMargin;

AnatomyPart get _part => AnatomyFigure.female.parts[_anatomy.uberon]!;

UterusForm _form({UterusHome home = UterusHome.glands}) =>
    UterusForm.place(part: _part, anatomy: _anatomy, view: _view, home: home);

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

double _across(List<Offset> points, double y) {
  final List<double> xs = <double>[
    for (final Offset p in points)
      if ((p.dy - y).abs() < 0.6) p.dx,
  ];
  return xs.reduce(math.max) - xs.reduce(math.min);
}

void main() {
  test('the uterus is drawn at its real size, laid on the body’s outline of '
      'the endometrium, moved a few millimetres at most to lay the place it '
      'is gone into on the place the body goes in', () {
    final UterusForm form = _form();
    expect(form.mm(1), closeTo(1e-3 / _view, 1e-15));
    // Gray's 7.5 cm, about the card's 8, from the fundus to the external
    // os, and 5 cm broad across its upper part.
    final Rect box = _bounds(UterusForm.outlineMm);
    expect(box.height, inInclusiveRange(75, 81));
    expect(box.width, closeTo(50, 1.5));
    expect(form.box.height / form.scale, closeTo(box.height, 0.5));
    // Pear-shaped: broadest at its cornua, narrowest at its isthmus, its
    // cervix a little wider again at its middle.
    expect(
      _across(UterusForm.outlineMm, -44),
      greaterThan(_across(UterusForm.outlineMm, -30) + 4),
    );
    expect(
      _across(UterusForm.outlineMm, -3),
      greaterThan(_across(UterusForm.outlineMm, UterusAnatomy.isthmus)),
    );
    // Below the isthmus it is the cervix specimen's own outline.
    for (final Offset p in UterusForm.outlineMm) {
      if (p.dy > 0) {
        expect(
          CervixForm.outlineMm.any((Offset q) => (q - p).distance < 0.05),
          isTrue,
          reason: '$p',
        );
      }
    }
    expect(form.anchorShift, lessThan(6));
    expect(form.site, form.place(UterusAnatomy.site));
    expect(form.toMm(form.site), UterusAnatomy.site);
    final double real = _anatomy.metres / _part.extent;
    expect(form.site, (_part.site - _part.centre) * (real / _view));
  });

  test('the zoom goes into the endometrium of the body, in its functional '
      'layer beside the cavity on the body’s right, where the cut crosses '
      'it', () {
    final UterusForm form = _form();
    const Offset site = UterusAnatomy.site;
    expect(UterusForm.inHome(site), isTrue);
    expect(UterusForm.inBand(site), isTrue);
    expect(UterusForm.inCavity(site), isFalse);
    expect(site.dx, lessThan(0));
    // Above the isthmus, in the body: GTEx's corpus.
    expect(site.dy, lessThan(UterusAnatomy.isthmus - 5));
    // In the functional layer: further from the muscle than the basal
    // layer is thick.
    final double out = UterusForm.widthAt(site.dy);
    final double thick = UterusForm.thicknessAt(site.dy);
    expect(-site.dx - out, greaterThan(0.5));
    expect(out + thick - -site.dx, greaterThan(UterusAnatomy.basal));
    expect(form.contains(form.site), isTrue);
  });

  test('its cavity is a triangle, its base between the tubes’ openings and '
      'its apex at the internal orifice, where the canal goes on; the '
      'endometrium lines it, thinning toward the isthmus', () {
    // The angles, 31 mm apart, and the apex 30 mm below the fundal border.
    expect(UterusForm.widthAt(UterusAnatomy.angle.dy), UterusAnatomy.angle.dx);
    expect(2 * UterusAnatomy.angle.dx, closeTo(31, 1));
    expect(
      UterusForm.fundusAt(0) - UterusAnatomy.isthmus,
      inInclusiveRange(-32, -28),
    );
    // Narrowing all the way down to the canal, which it meets at the
    // internal orifice.
    double last = double.infinity;
    for (double y = UterusAnatomy.angle.dy; y <= UterusAnatomy.isthmus; y++) {
      final double w = UterusForm.widthAt(y);
      expect(w, lessThanOrEqualTo(last + 1e-9), reason: '$y');
      last = w;
    }
    expect(
      UterusForm.widthAt(UterusAnatomy.isthmus),
      closeTo(CervixForm.grooveAt(CervixAnatomy.internalOs), 1e-9),
    );
    // The endometrium 5 mm thick in the body, 1.2 at the isthmus.
    expect(UterusForm.thicknessAt(-35), closeTo(5, 1e-9));
    expect(
      UterusForm.thicknessAt(UterusAnatomy.isthmus),
      closeTo(UterusAnatomy.endometriumIsthmus, 1e-9),
    );
    // The endometrium wraps the cavity: every point of the cavity's edge
    // inside it, and the edge of it outside the cavity.
    for (final Offset p in UterusForm.edgeMm) {
      expect(UterusForm.inHome(p + const Offset(0, -0.01)), isTrue);
    }
    for (final Offset p in UterusForm.homeMm) {
      if (p.dy < UterusAnatomy.isthmus - 1) {
        expect(UterusForm.inCavity(p), isFalse, reason: '$p');
      }
    }
  });

  test('its glands run out from the cavity through the functional layer, '
      'stopping short of the muscle, and open as pits on its back wall', () {
    expect(UterusForm.glandsMm.length, greaterThan(40));
    for (final List<Offset> gland in UterusForm.glandsMm) {
      for (final Offset p in gland.skip(1)) {
        expect(UterusForm.inHome(p), isTrue, reason: '$p');
      }
      expect(UterusForm.inCavity(gland.last), isFalse);
    }
    expect(UterusForm.pitsMm.length, greaterThan(150));
    for (final Offset p in UterusForm.pitsMm) {
      expect(UterusForm.inCavity(p), isTrue, reason: '$p');
    }
  });

  test('the vessels of the muscle’s middle layer lie in the muscle, clear '
      'of the endometrium, the serosa and the tubes', () {
    final List<(Offset, double, double, double)> vessels = UterusForm.vesselsMm;
    expect(vessels.length, greaterThan(15));
    final Path outline = Path()..addPolygon(UterusForm.outlineMm, true);
    for (final (Offset at, double rx, double ry, double _) in vessels) {
      expect(outline.contains(at), isTrue, reason: '$at');
      expect(UterusForm.inHome(at), isFalse, reason: '$at');
      expect(at.dy, lessThan(UterusAnatomy.isthmus));
      expect(ry, lessThanOrEqualTo(rx));
      expect(rx, inInclusiveRange(0.3, 1));
    }
  });

  test('the tubes run out from its cornua, through the wall from the '
      'cavity’s angles, and the arteries climb beside it', () {
    final UterusForm form = _form();
    for (final List<Offset> tube in UterusForm.intramuralMm) {
      expect(
        (tube.first - Offset(tube.first.dx.sign * 15.6, -47.2)).distance,
        lessThan(0.01),
      );
      final Path outline = Path()..addPolygon(UterusForm.outlineMm, true);
      expect(outline.contains(tube[tube.length ~/ 2]), isTrue);
    }
    expect(form.tubes, hasLength(2));
    expect(form.ligaments, hasLength(2));
    for (final TubeCourse t in <TubeCourse>[...form.tubes, ...form.ligaments]) {
      // Coming out of the cornu, fading out further off.
      expect(form.contains(t.centres.first), isTrue);
      expect(t.shown.last, lessThan(0.05));
    }
    // Pairs, one either side, mirrored.
    expect(form.arteries.length.isEven, isTrue);
    for (int i = 0; i < form.arteries.length; i += 2) {
      final Offset a = form.toMm(form.arteries[i].centres.first);
      final Offset b = form.toMm(form.arteries[i + 1].centres.first);
      expect(a.dx, closeTo(-b.dx, 1e-6));
      expect(a.dy, closeTo(b.dy, 1e-6));
    }
    // The ascending branches outside it, beside its body.
    for (final TubeCourse t in <TubeCourse>[
      form.arteries[2],
      form.arteries[3],
    ]) {
      for (int i = 0; i < t.length; i += 3) {
        expect(form.contains(t.centres[i]), isFalse);
      }
    }
    expect(form.branches, isNotEmpty);
  });

  test('the step from the body meets the uterus’s outline and the body’s '
      'band at the same places, in the same order round them from the '
      'middle of the top; the band’s cavity is filled', () {
    final UterusForm form = _form();
    final double real = _anatomy.metres / _part.extent;
    final List<Offset> band = <Offset>[
      for (final Offset p in _part.followed)
        (p - _part.centre) * (real / _view),
    ];
    final List<Offset> filled = UterusForm.silhouetteOf(band);
    // The band's box, and its cavity inside the filled shape.
    expect(_bounds(filled).width, closeTo(_bounds(band).width, form.mm(1.5)));
    expect(_bounds(filled).height, closeTo(_bounds(band).height, form.mm(1.5)));
    final Path inside = Path()..addPolygon(filled, true);
    expect(inside.contains(_bounds(band).center), isTrue);
    expect(
      (Path()..addPolygon(band, true)).contains(_bounds(band).center),
      isFalse,
    );
    final List<Offset> body = Contour(filled).sampled(8).points;
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

    final double way = _area(form.outlinePoints).sign;
    final List<Offset> bodyWay = _area(body).sign == way
        ? body
        : body.reversed.toList();
    expect(order(form.outlinePoints), order(bodyWay));
    expect(form.marksOf(form.outlinePoints).toSet(), hasLength(4));
    final Rect settled = _bounds(form.outlineAt(1));
    expect(settled.width, closeTo(form.box.width, form.mm(2)));
    expect(form.outlineAt(0), isNotEmpty);
  });

  test('its home is told by the Atlas’s name for the cell, and its names '
      'point where they say', () {
    expect(UterusHome.of('Endometrial glandular cells'), UterusHome.glands);
    expect(UterusHome.of('Endometrial secretory cells'), UterusHome.glands);
    expect(UterusHome.of('Endometrial luminal cells'), UterusHome.surface);
    expect(UterusHome.of('Endometrial ciliated cells'), UterusHome.surface);
    expect(UterusHome.of('Endometrial stromal cells'), UterusHome.stroma);
    expect(UterusHome.of(null), UterusHome.glands);
    final UterusForm glands = _form();
    expect(glands.homeName, glands.site);
    final UterusForm surface = _form(home: UterusHome.surface);
    expect(UterusForm.inCavity(surface.toMm(surface.homeName)), isTrue);
    expect(UterusForm.inHome(glands.toMm(glands.muscleName)), isFalse);
    expect(glands.contains(glands.muscleName), isTrue);
    expect(UterusForm.inCanal(glands.toMm(glands.canalName)), isTrue);
    expect(glands.contains(glands.tubeName), isFalse);
    expect(glands.contains(glands.arteryName), isFalse);
  });

  test('it is the same uterus every time', () {
    final UterusForm a = _form();
    final UterusForm b = _form();
    expect(a.outlinePoints, b.outlinePoints);
    expect(a.endometrium, b.endometrium);
    expect(a.pits, b.pits);
    expect(a.vessels, b.vessels);
    expect(a.site, b.site);
    expect(a.branches.length, b.branches.length);
  });
}
