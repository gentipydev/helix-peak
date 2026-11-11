import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/features/zoom/domain/anatomy_figure.dart';
import 'package:helixpeek/features/zoom/domain/anatomy_tables.dart';
import 'package:helixpeek/features/zoom/domain/zoom_depth.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/organs/ovary/ovary_anatomy.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/organs/ovary/ovary_form.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/tube_course.dart';

final TissueAnatomy _anatomy = tissueAnatomy['ovary']!;
final double _view = _anatomy.metres * ZoomDepth.organMargin;
final AnatomyPart _part = AnatomyFigure.female.parts[_anatomy.uberon]!;

OvaryForm _form([OvaryHome home = OvaryHome.follicles]) =>
    OvaryForm.place(part: _part, anatomy: _anatomy, view: _view, home: home);

Rect _bounds(List<Offset> points) {
  Rect box = Rect.fromLTRB(
    points.first.dx,
    points.first.dy,
    points.first.dx,
    points.first.dy,
  );
  for (final Offset p in points) {
    box = box.expandToInclude(Rect.fromLTRB(p.dx, p.dy, p.dx, p.dy));
  }
  return box;
}

bool _inside(List<Offset> polygon, Offset p) {
  bool odd = false;
  for (int i = 0; i < polygon.length; i++) {
    final Offset a = polygon[i];
    final Offset b = polygon[(i + 1) % polygon.length];
    if ((a.dy > p.dy) != (b.dy > p.dy) &&
        p.dx < a.dx + (p.dy - a.dy) * (b.dx - a.dx) / (b.dy - a.dy)) {
      odd = !odd;
    }
  }
  return odd;
}

/// Every follicle and corpus the anatomy lays: its middle and its radius.
final List<(String, OvaryBody)> _bodies = <(String, OvaryBody)>[
  ('ripe', OvaryAnatomy.ripe),
  for (final OvaryBody b in OvaryAnatomy.antral) ('antral', b),
  ('luteum', OvaryAnatomy.luteum),
  for (final OvaryBody b in OvaryAnatomy.albicantia) ('albicans', b),
];

void main() {
  test('it is the size the card gives it, the left ovary the body draws, '
      'laid where the body goes in, over the body’s outline of it', () {
    final OvaryForm form = _form();
    expect(form.mm(1), closeTo(1e-3 / _view, 1e-12));
    // Its length along its own axis, as the anatomy measures it.
    final List<Offset> mm = <Offset>[
      for (final Offset p in form.outlinePoints) form.toMm(p),
    ];
    final Rect along = _bounds(mm);
    expect(along.width, closeTo(OvaryAnatomy.length, 0.3));
    expect(along.height, inInclusiveRange(19, 21));
    // The left ovary, on the page's right of the figure's middle; the
    // other the right one.
    expect(_bounds(_part.followed).center.dx, greaterThan(0));
    expect(_bounds(_part.others.single).center.dx, lessThan(0));
    expect(AnatomyFigure.male.parts[_anatomy.uberon], isNull);
    // The site where the body's is, and inside the ovary.
    final double real = _anatomy.metres / _part.extent;
    expect(
      (form.site - (_part.site - _part.centre) * (real / _view)).distance,
      lessThan(1e-9),
    );
    expect(form.contains(form.site), isTrue);
    expect((form.toMm(form.site) - OvaryAnatomy.site).distance, lessThan(1e-9));
    // Laid over the body's disc.
    expect(form.anchorShift, lessThan(2));
    // Its tubal pole the higher, as it lies.
    final Offset tubal = form.place(const Offset(OvaryAnatomy.length / 2, 0));
    final Offset uterine = form.place(
      const Offset(-OvaryAnatomy.length / 2, 0),
    );
    expect(tubal.dx, greaterThan(uterine.dx));
    expect(tubal.dy, lessThan(uterine.dy));
  });

  test('the anatomogram’s ovaries are pies closed through their middle: the '
      'step draws in from each disc’s rim, the slit dropped', () {
    // The body's outline has a point deep inside the rest of it, its
    // middle, where the slit ends.
    final Rect box = _bounds(_part.followed);
    final int deep = _part.followed.indexWhere(
      (Offset p) => (p - box.center).distance < 0.2 * box.shortestSide,
    );
    expect(deep, isNot(-1));
    for (final List<Offset> outline in <List<Offset>>[
      _part.followed,
      ..._part.others,
    ]) {
      final List<Offset> rim = OvaryForm.rimOf(outline);
      final Rect ring = _bounds(rim);
      expect(rim.length, lessThan(outline.length));
      expect(ring, _bounds(outline));
      for (final Offset p in rim) {
        expect(
          (p - ring.center).distance,
          greaterThan(0.35 * ring.shortestSide),
          reason: '$p',
        );
      }
    }
    final OvaryForm form = _form();
    for (final Offset p in form.diagramPoints) {
      expect(
        (p -
                form.diagramPoints.reduce((Offset a, Offset b) => a + b) /
                    form.diagramPoints.length.toDouble())
            .distance,
        greaterThan(0.3 * _bounds(form.diagramPoints).shortestSide),
      );
    }
    for (final List<Offset> other in form.others) {
      expect(other.length, lessThan(_part.others.single.length));
    }
  });

  test('it is gone into where GTEx samples it, the left ovary’s most normal '
      'cortex: 1 mm under its free border, in no follicle or corpus, out of '
      'the medulla', () {
    const Offset site = OvaryAnatomy.site;
    expect(OvaryForm.depth(site), inInclusiveRange(0.6, 1.4));
    expect(OvaryForm.inMedulla(site), isFalse);
    for (final (String what, OvaryBody b) in _bodies) {
      expect(
        (site - b.centre).distance,
        greaterThan(b.radius + 1.5),
        reason: what,
      );
    }
    // On the free border, below the axis.
    expect(site.dy, greaterThan(0));
  });

  test('the Atlas’s names take the cell to its follicles or its stroma', () {
    expect(OvaryHome.of('Oocytes'), OvaryHome.follicles);
    expect(OvaryHome.of('Granulosa cells'), OvaryHome.follicles);
    expect(OvaryHome.of('Ovarian stromal cells'), OvaryHome.stroma);
    expect(OvaryHome.of(null), OvaryHome.stroma);
    expect(OvaryHome.of('Smooth muscle cells'), OvaryHome.stroma);
    expect(OvaryHome.follicles.word, 'follicles');
    expect(OvaryHome.stroma.word, 'stroma');
  });

  test('its parts lie where they belong: the follicles and corpora inside '
      'it and apart, the near-ripe follicle under its free border; the '
      'medulla reaching the surface only at the hilum; the dust under the '
      'surface; the helicine vessels in the medulla', () {
    final List<Offset> outline = OvaryForm.outlineMm;
    for (final (String what, OvaryBody b) in _bodies) {
      expect(_inside(outline, b.centre), isTrue, reason: what);
      final double clear = OvaryForm.depth(b.centre) - b.radius;
      expect(clear, greaterThan(0.3), reason: '$what at ${b.centre}');
    }
    for (int i = 0; i < _bodies.length; i++) {
      for (int j = i + 1; j < _bodies.length; j++) {
        final OvaryBody a = _bodies[i].$2;
        final OvaryBody b = _bodies[j].$2;
        expect(
          (a.centre - b.centre).distance - a.radius - b.radius,
          greaterThan(0.8),
          reason: '${_bodies[i].$1} ${a.centre}, ${_bodies[j].$1} ${b.centre}',
        );
      }
    }
    // The near-ripe follicle lies under the free border, a thin cortex
    // over it.
    expect(
      OvaryForm.depth(OvaryAnatomy.ripe.centre) - OvaryAnatomy.ripe.radius,
      lessThan(1),
    );
    expect(OvaryAnatomy.ripe.centre.dy, greaterThan(0));
    // The hilum: one stretch of the mesovarian border, 10 to 18 mm long.
    final (Offset from, Offset to) = OvaryForm.hilumMm;
    expect(from.dy, lessThan(-6));
    expect(to.dy, lessThan(-6));
    expect((from - to).distance, inInclusiveRange(10, 18));
    expect(OvaryForm.inMedulla(const Offset(0, 9)), isFalse);
    // The dust: under the surface, out of the medulla, many of each.
    expect(OvaryForm.primordialMm.length, greaterThan(80));
    expect(OvaryForm.growingMm.length, greaterThan(25));
    for (final Offset p in <Offset>[
      ...OvaryForm.primordialMm,
      ...OvaryForm.growingMm,
    ]) {
      expect(OvaryForm.depth(p), inInclusiveRange(0, OvaryAnatomy.growingTo));
      expect(OvaryForm.inMedulla(p), isFalse);
    }
    expect(OvaryForm.profilesMm.length, greaterThan(15));
    for (final Offset p in OvaryForm.profilesMm) {
      expect(OvaryForm.inMedulla(p), isTrue);
      expect(OvaryForm.depth(p), greaterThan(0));
    }
  });

  test('round it its tube arches over its mesovarian border to the tubal '
      'pole, its fimbriae the fallopian tube’s own; the ligament of the '
      'ovary leaves its uterine pole; the ovarian vessels come up out of its '
      'hilum; each cut short where it leaves', () {
    final OvaryForm form = _form();
    final List<Offset> outline = OvaryForm.outlineMm;
    // The tube runs above the mesovarian border, clear of it, until it
    // turns down past the tubal pole.
    for (final Offset p in OvaryAnatomy.tube.take(6)) {
      expect(_inside(outline, p), isFalse, reason: '$p');
      expect(p.dy, lessThan(-12), reason: '$p');
    }
    final TubeCourse tube = form.tube;
    for (int i = 0; i < tube.length; i++) {
      final Offset mm = form.toMm(tube.centres[i]);
      if (mm.dx < 15) {
        // Its lower side clear of the ovary.
        expect(
          OvaryForm.depth(mm + Offset(0, tube.radius[i] / form.scale)),
          lessThan(0),
          reason: 'row $i at $mm',
        );
      }
    }
    expect(tube.cutEnd, isTrue);
    // Its ostium behind the tubal pole.
    expect(_inside(outline, OvaryAnatomy.tube.last), isTrue);
    expect(OvaryAnatomy.tube.last.dx, greaterThan(15));
    expect(form.fimbriae, hasLength(7));
    // The ligament from the uterine pole, the vessels from the hilum.
    expect(OvaryForm.depth(OvaryAnatomy.ligament.first).abs(), lessThan(1));
    expect(OvaryAnatomy.ligament.last.dx, lessThan(-OvaryAnatomy.length / 2));
    final (Offset hilumFrom, Offset hilumTo) = OvaryForm.hilumMm;
    for (final List<Offset> vessel in <List<Offset>>[
      OvaryAnatomy.vein,
      OvaryAnatomy.artery,
    ]) {
      final Offset start = vessel.first;
      expect(start.dx, inInclusiveRange(hilumTo.dx, hilumFrom.dx));
      expect(OvaryForm.depth(start).abs(), lessThan(2));
    }
    expect(
      form.vein.cutEnd && form.artery.cutEnd && form.ligament.cutEnd,
      isTrue,
    );
    // Nothing drawn more than 24 mm above the ovary's middle as it lies,
    // so its names have room above it on the squattest phones (the names
    // test sets them there).
    final Offset middle = form.box.center;
    for (final TubeCourse t in form.beside) {
      for (int i = 0; i < t.length; i++) {
        final double above =
            (middle.dy - (t.centres[i].dy - t.radius[i])) / form.scale;
        expect(above, lessThan(24), reason: 'row $i');
      }
    }
  });

  test('the step from the body meets the two outlines at their tops’ '
      'middles, their poles and their lowest points, in the same order', () {
    final OvaryForm form = _form();
    final List<Offset> body = form.outlineAt(0);
    final List<Offset> own = form.outlineAt(1);
    final List<Offset> a = form.marksOf(body);
    final List<Offset> b = form.marksOf(own);
    expect(a, hasLength(4));
    expect(b, hasLength(4));
    // Each mark of either outline lies where its name says in its box.
    for (final (List<Offset> marks, List<Offset> outline)
        in <(List<Offset>, List<Offset>)>[(a, body), (b, own)]) {
      final Rect box = _bounds(outline);
      expect(marks[0].dy - box.top, lessThan(0.25 * box.height));
      expect(box.right - marks[1].dx, lessThan(form.mm(0.5)));
      expect(box.bottom - marks[2].dy, lessThan(form.mm(0.5)));
      expect(marks[3].dx - box.left, lessThan(form.mm(0.5)));
    }
    // Drawn in, it is the ovary's own outline.
    expect(
      (_bounds(own).center - form.box.center).distance,
      lessThan(form.mm(0.5)),
    );
    expect((_bounds(own).width - form.box.width).abs(), lessThan(form.mm(1)));
  });

  test('it is the same ovary every time', () {
    final OvaryForm a = _form();
    final OvaryForm b = _form();
    expect(a.outlinePoints, b.outlinePoints);
    expect(a.primordial, b.primordial);
    expect(a.growing, b.growing);
    expect(
      <Offset>[for (final OvaryProfile p in a.profiles) p.centre],
      <Offset>[for (final OvaryProfile p in b.profiles) p.centre],
    );
    expect(a.luteum, b.luteum);
    expect(a.site, b.site);
    expect(math.max(a.primordial.length, 1), greaterThan(80));
  });
}
