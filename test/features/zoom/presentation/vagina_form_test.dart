import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/features/zoom/domain/anatomy_figure.dart';
import 'package:helixpeek/features/zoom/domain/anatomy_tables.dart';
import 'package:helixpeek/features/zoom/domain/zoom_depth.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/contour.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/organs/vagina/vagina_anatomy.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/organs/vagina/vagina_form.dart';

final TissueAnatomy _anatomy = tissueAnatomy['vagina']!;

/// The organ's view, framed by its width: the form is the same at any.
final double _view = _anatomy.metres * ZoomDepth.organMargin;

AnatomyPart get _part => AnatomyFigure.female.parts[_anatomy.uberon]!;

VaginaForm _form() =>
    VaginaForm.place(part: _part, anatomy: _anatomy, view: _view);

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
  test('the vagina is drawn at its real size, laid on the body’s outline of '
      'it, moved a few millimetres at most to lay the place it is gone into '
      'on the place the body goes in', () {
    final VaginaForm form = _form();
    expect(form.mm(1), closeTo(1e-3 / _view, 1e-15));
    final Rect box = _bounds(VaginaForm.outlineMm);
    // Its back wall the card's 9 cm from below the cervix to the
    // fourchette, the posterior fornix above the cervix; opened, as wide
    // as twice the vagina is across below the cervix.
    expect(
      VaginaAnatomy.posteriorBottom - VaginaAnatomy.portio.dy,
      closeTo(83, 1),
    );
    expect(box.height, closeTo(103, 1));
    expect(box.width, inInclusiveRange(2 * 32.5, 2 * 34.5));
    // The back wall 32 mm wide below the cervix and narrower below, each
    // half of the front wall about 15 mm.
    expect(2 * VaginaForm.sulcusAt(10), closeTo(36, 2));
    expect(VaginaForm.sulcusAt(80), lessThan(VaginaForm.sulcusAt(10)));
    for (final double y in <double>[10, 40, 70]) {
      expect(
        VaginaForm.edgeAt(y) - VaginaForm.sulcusAt(y),
        inInclusiveRange(13, 18),
        reason: '$y',
      );
    }
    expect(form.anchorShift, lessThan(4));
    expect(form.site, form.place(VaginaAnatomy.site));
    expect(form.toMm(form.site), VaginaAnatomy.site);
    final double real = _anatomy.metres / _part.extent;
    expect(form.site, (_part.site - _part.centre) * (real / _view));
  });

  test('the zoom goes into the front wall, where GTEx samples it: its half '
      'on the body’s right, in its middle third, off the cervix', () {
    final VaginaForm form = _form();
    const Offset site = VaginaAnatomy.site;
    expect(VaginaForm.inHome(site), isTrue);
    expect(VaginaForm.inBack(site), isFalse);
    expect(VaginaForm.inPortio(site), isFalse);
    expect(site.dx, lessThan(0));
    // The front wall's middle third, from the anterior fornix to the
    // introitus.
    expect(site.dy, inInclusiveRange(28, 52));
    expect(form.contains(form.site), isTrue);
  });

  test('the front wall’s halves lie out beyond the sulci, the back wall '
      'between them, the cervix standing in the vault at the top', () {
    for (final List<Offset> half in VaginaForm.frontMm) {
      final Rect box = _bounds(half);
      // About 15 mm across, the sulcus slanting in toward the introitus.
      expect(box.width, inInclusiveRange(13, 21));
      expect(box.height, greaterThan(75));
      for (int i = 0; i < half.length; i += 5) {
        expect(
          half[i].dx.abs(),
          greaterThanOrEqualTo(VaginaForm.sulcusAt(half[i].dy) - 1e-6),
        );
      }
    }
    final Rect portio = _bounds(VaginaForm.portioMm);
    expect(portio.width, closeTo(2 * VaginaAnatomy.portioWide, 0.01));
    // Inside the vault, the posterior fornix above it, between the sulci.
    expect(portio.top, greaterThan(_bounds(VaginaForm.outlineMm).top + 3));
    expect(portio.right, lessThan(VaginaForm.sulcusAt(portio.center.dy)));
    expect(VaginaForm.inPortio(Offset.zero), isTrue);
  });

  test('its rugae run across the walls, none on the cervix, and its hymen’s '
      'caruncles lie along the introitus', () {
    expect(VaginaForm.rugaeMm.length, greaterThan(60));
    for (final List<Offset> ruga in VaginaForm.rugaeMm) {
      for (final Offset p in ruga) {
        expect(VaginaForm.inPortio(p), isFalse, reason: '$p');
        expect(
          (Path()..addPolygon(VaginaForm.outlineMm, true)).contains(p),
          isTrue,
        );
      }
      // Each stays on one wall.
      final bool back = VaginaForm.inBack(ruga[ruga.length ~/ 2]);
      expect(
        ruga.every(
          (Offset p) =>
              p.dx.abs() <= VaginaForm.sulcusAt(p.dy) + 0.5 == back ||
              (p.dx.abs() - VaginaForm.sulcusAt(p.dy)).abs() < 0.5,
        ),
        isTrue,
      );
    }
    expect(VaginaForm.caruncleMm, hasLength(VaginaAnatomy.caruncles));
    for (final (Offset at, double r) in VaginaForm.caruncleMm) {
      expect(at.dy, greaterThan(74));
      expect(r, inInclusiveRange(1, 2));
    }
  });

  test('the step from the body meets the vagina’s outline and the body’s at '
      'the same places, in the same order round them from the middle of '
      'the top', () {
    final VaginaForm form = _form();
    final double real = _anatomy.metres / _part.extent;
    final List<Offset> body = Contour(<Offset>[
      for (final Offset p in _part.followed)
        (p - _part.centre) * (real / _view),
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

    final double way = _area(form.outlinePoints).sign;
    final List<Offset> bodyWay = _area(body).sign == way
        ? body
        : body.reversed.toList();
    expect(order(form.outlinePoints), order(bodyWay));
    expect(form.marksOf(form.outlinePoints).toSet(), hasLength(4));
    final Rect settled = _bounds(form.outlineAt(1));
    expect(settled.width, closeTo(form.box.width, form.mm(2)));
  });

  test('its names point where they say, and it is the same vagina every '
      'time', () {
    final VaginaForm a = _form();
    final VaginaForm b = _form();
    expect(a.outlinePoints, b.outlinePoints);
    expect(a.front, b.front);
    expect(a.caruncles, b.caruncles);
    expect(a.homeName, a.site);
    expect(VaginaForm.inPortio(a.toMm(a.cervixName)), isTrue);
    final Offset fornix = a.toMm(a.fornixName);
    expect(VaginaForm.inBack(fornix), isTrue);
    expect(fornix.dy, lessThan(_bounds(VaginaForm.portioMm).top));
    expect(VaginaForm.inBack(a.toMm(a.rugaeName)), isTrue);
    expect(
      VaginaForm.caruncleMm
          .map(
            ((Offset, double) c) =>
                (c.$1 - a.toMm(a.hymenName)).distance - c.$2,
          )
          .reduce(math.min),
      lessThan(1.5),
    );
  });
}
