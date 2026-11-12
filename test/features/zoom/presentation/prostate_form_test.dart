import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/features/zoom/domain/anatomy_figure.dart';
import 'package:helixpeek/features/zoom/domain/anatomy_tables.dart';
import 'package:helixpeek/features/zoom/domain/zoom_depth.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/organs/prostate/prostate_anatomy.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/organs/prostate/prostate_form.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/organs/prostate/prostate_style.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/tube_course.dart';

final TissueAnatomy _anatomy = tissueAnatomy['prostate']!;
final double _view =
    _anatomy.metres * ZoomDepth.organMargin / ZoomDepth.prostateUpright;
final AnatomyPart _part = AnatomyFigure.male.parts[_anatomy.uberon]!;

ProstateForm _form([ProstateHome home = ProstateHome.glands]) =>
    ProstateForm.place(part: _part, anatomy: _anatomy, view: _view, home: home);

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

double _toLine(List<Offset> line, Offset p) {
  double best = double.infinity;
  for (int i = 0; i + 1 < line.length; i++) {
    final Offset a = line[i];
    final Offset ab = line[i + 1] - a;
    final double length = ab.distanceSquared;
    final double t = length <= 0
        ? 0
        : (((p - a).dx * ab.dx + (p - a).dy * ab.dy) / length).clamp(0.0, 1.0);
    best = math.min(best, (p - (a + ab * t)).distance);
  }
  return best;
}

void main() {
  test('it is the size the card gives it, Gray’s chestnut, 4 cm across its '
      'base and 3 tall, laid where the body goes in, over the body’s '
      'outline of it', () {
    final ProstateForm form = _form();
    expect(form.mm(1), closeTo(1e-3 / _view, 1e-12));
    final Rect mm = _bounds(ProstateForm.outlineMm);
    expect(mm.width, closeTo(ProstateAnatomy.width, 0.2));
    expect(mm.height, inInclusiveRange(30, 34));
    // Broadest toward its base, narrow at its apex.
    double across(double y) {
      final List<double> xs = <double>[
        for (final Offset p in ProstateForm.outlineMm)
          if ((p.dy - y).abs() < 0.4) p.dx,
      ];
      return xs.reduce(math.max) - xs.reduce(math.min);
    }

    expect(
      across(mm.top + 0.3 * mm.height),
      greaterThan(across(mm.bottom - 4)),
    );
    expect(across(mm.bottom - 2), lessThan(0.4 * mm.width));
    expect(AnatomyFigure.female.parts[_anatomy.uberon], isNull);
    // The site where the body's is, and inside the prostate.
    final double real = _anatomy.metres / _part.extent;
    expect(
      (form.site - (_part.site - _part.centre) * (real / _view)).distance,
      lessThan(1e-9),
    );
    expect(form.contains(form.site), isTrue);
    expect(
      (form.toMm(form.site) - ProstateAnatomy.site).distance,
      lessThan(1e-9),
    );
    // Laid over the body's oval.
    expect(form.anchorShift, lessThan(1));
  });

  test('it is gone into where GTEx samples it, a representative region of '
      'its glands: the peripheral zone, 3 to 4 mm in from the capsule, '
      'clear of every duct, pore, the urethra and the ejaculatory ducts', () {
    const Offset site = ProstateAnatomy.site;
    expect(ProstateForm.depth(site), inInclusiveRange(3, 4));
    expect(ProstateForm.inCentral(site), isFalse);
    expect(ProstateForm.inSleeve(site), isFalse);
    expect(ProstateForm.nearDucts(site, 2), isFalse);
    for (final List<Offset> duct in ProstateForm.glandDuctsMm) {
      expect(_toLine(duct, site), greaterThan(0.5));
    }
    for (final (Offset p, double r) in ProstateForm.poresMm) {
      expect((p - site).distance, greaterThan(1.6 + r - 1e-9));
    }
    // On the body's right, below the verumontanum's level.
    expect(site.dx, lessThan(0));
    expect(site.dy, greaterThan(ProstateAnatomy.colliculus.dy));
  });

  test('the Atlas’s names take the cell to its glands, its stroma or its '
      'urethra’s lining', () {
    expect(ProstateHome.of(null), ProstateHome.glands);
    expect(ProstateHome.of('Prostate glandular cells'), ProstateHome.glands);
    expect(ProstateHome.of('Prostatic glandular cells'), ProstateHome.glands);
    expect(ProstateHome.of('Basal prostatic cells'), ProstateHome.glands);
    expect(ProstateHome.of('Smooth muscle cells'), ProstateHome.stroma);
    expect(ProstateHome.of('Fibroblasts'), ProstateHome.stroma);
    expect(ProstateHome.of('Prostatic hillock cells'), ProstateHome.urethra);
    expect(ProstateHome.of('Prostatic club cells'), ProstateHome.urethra);
    expect(ProstateHome.of('Urothelial cells'), ProstateHome.urethra);
    expect(
      <String>[for (final ProstateHome h in ProstateHome.values) h.word],
      <String>['glands', 'stroma', 'urethra'],
    );
  });

  test('its zones lie as McNeal found them in the plane of the ejaculatory '
      'ducts: the central zone a cone round the ducts, its base the '
      'prostate’s, its apex at the verumontanum; the peripheral zone round '
      'it and down to the apex', () {
    // The central zone at the base's middle and round each duct's upper
    // reach; none below the verumontanum, nor at the base's corners.
    expect(ProstateForm.inCentral(const Offset(0, -12)), isTrue);
    expect(ProstateForm.inCentral(const Offset(6, -13)), isTrue);
    expect(ProstateForm.inCentral(const Offset(-6, -13)), isTrue);
    expect(ProstateForm.inCentral(const Offset(0, 6)), isFalse);
    expect(ProstateForm.inCentral(const Offset(17, -10)), isFalse);
    expect(ProstateForm.inCentral(const Offset(-17, -10)), isFalse);
    for (final Offset p in ProstateAnatomy.duct) {
      if (p.dy < -1) {
        expect(ProstateForm.inCentral(p), isTrue, reason: '$p');
        expect(ProstateForm.inCentral(Offset(-p.dx, p.dy)), isTrue);
      }
    }
    // The cone's width across the base, a little over half of it.
    final List<double> base = <double>[
      for (double x = -20; x <= 20; x += 0.1)
        if (ProstateForm.inCentral(Offset(x, -14))) x,
    ];
    expect(base.last - base.first, inInclusiveRange(18, 25));
    // The glands' ducts in the zones, none in the urethra or the muscle
    // round it, nor in the capsule's rim.
    for (final List<Offset> duct in ProstateForm.glandDuctsMm) {
      for (final Offset p in duct) {
        expect(ProstateForm.depth(p), greaterThan(ProstateStyle.rim));
        expect(ProstateForm.inSleeve(p), isFalse);
      }
    }
    // The pores denser toward the apex, for the room they have there.
    final Rect box = _bounds(ProstateForm.outlineMm);
    double room(bool upper) {
      int count = 0;
      for (double y = box.top; y <= box.bottom; y += 0.25) {
        if ((y < box.center.dy) != upper) {
          continue;
        }
        for (double x = box.left; x <= box.right; x += 0.25) {
          final Offset p = Offset(x, y);
          if (ProstateForm.depth(p) > ProstateStyle.rim &&
              !ProstateForm.inSleeve(p)) {
            count++;
          }
        }
      }
      return count * 0.0625;
    }

    double density(bool upper) =>
        ProstateForm.poresMm
            .where(((Offset, double) p) => (p.$1.dy < box.center.dy) == upper)
            .length /
        room(upper);
    expect(density(false), greaterThan(density(true)));
  });

  test('the ejaculatory ducts run from the base, each about 2 cm long, '
      'converging and narrowing along the utricle to their slits on the '
      'colliculus, the urethra laid open below it to the apex, wider in '
      'its middle than at its end, the crest down its floor', () {
    const List<Offset> duct = ProstateAnatomy.duct;
    double length = 0;
    for (int i = 0; i + 1 < duct.length; i++) {
      length += (duct[i + 1] - duct[i]).distance;
    }
    expect(length, inInclusiveRange(15, 20));
    expect(duct.first.dx, greaterThan(duct.last.dx));
    expect(ProstateAnatomy.ductBase, greaterThan(ProstateAnatomy.ductEnd));
    expect(duct.last, ProstateAnatomy.ductMouth);
    // The utricle Gray's 6 mm, between the ducts.
    expect(
      ProstateAnatomy.utricleMouth.dy - ProstateAnatomy.utricleTop,
      closeTo(6, 0.3),
    );
    // The colliculus on the urethra's floor, the urethra spindle-shaped,
    // narrowest at the apex.
    const Offset c = ProstateAnatomy.colliculus;
    expect(
      ProstateForm.urethraHalf(c.dy),
      greaterThan(ProstateAnatomy.colliculusAcross),
    );
    expect(
      ProstateForm.urethraHalf(3),
      greaterThan(ProstateForm.urethraHalf(15)),
    );
    expect(
      ProstateAnatomy.crestTo,
      greaterThan(c.dy + ProstateAnatomy.colliculusDown),
    );
    // The urethra's crest, from the colliculus down, 15 to 17 mm in all.
    expect(
      ProstateAnatomy.crestTo - (c.dy - ProstateAnatomy.colliculusDown),
      inInclusiveRange(10, 17),
    );
  });

  test('round it the seminal vesicles and the ampullae come down to its '
      'base, the vesicles lateral, fading out above; the arteries come in '
      'to the base’s corners, and the sphincter leaves the apex, cut '
      'short', () {
    final ProstateForm form = _form();
    for (int side = 0; side < 2; side++) {
      final TubeCourse vesicle = form.vesicles[side];
      final TubeCourse ampulla = form.ampullae[side];
      // Their lower ends under the base's top edge, inside the outline.
      expect(form.contains(vesicle.centres.first), isTrue);
      expect(form.contains(ampulla.centres.first), isTrue);
      // The vesicle lateral to its ampulla, and both above the base.
      final double sign = side == 0 ? 1 : -1;
      final Offset v = form.toMm(vesicle.centres[vesicle.length ~/ 2]);
      final Offset a = form.toMm(ampulla.centres[ampulla.length ~/ 2]);
      expect(v.dx * sign, greaterThan(a.dx * sign));
      expect(v.dy, lessThan(-16));
      expect(a.dy, lessThan(-16));
      expect(vesicle.shown.first, 1);
      expect(vesicle.shown.last, lessThan(0.05));
      expect(ampulla.shown.last, lessThan(0.05));
      // The artery comes in from the side to the base's corner.
      final TubeCourse artery = form.arteries[side];
      final Offset end = form.toMm(artery.centres.last);
      expect(end.dy, lessThan(-8));
      expect(end.dx.abs(), greaterThan(17));
      expect(artery.shown.first, lessThan(0.05));
    }
    // The sphincter leaves the apex below the prostate, cut short.
    final TubeCourse sphincter = form.sphincter;
    expect(sphincter.cutEnd, isTrue);
    expect(form.toMm(sphincter.centres.last).dy, greaterThan(17));
    expect(form.contains(sphincter.centres.first), isTrue);
  });

  test('the step from the body meets the two outlines at their tops’ '
      'middles, their sides and their lowest points, in the same order', () {
    final ProstateForm form = _form();
    final List<Offset> body = form.outlineAt(0);
    final List<Offset> own = form.outlineAt(1);
    final List<Offset> a = form.marksOf(body);
    final List<Offset> b = form.marksOf(own);
    expect(a, hasLength(4));
    expect(b, hasLength(4));
    for (final (List<Offset> marks, List<Offset> outline)
        in <(List<Offset>, List<Offset>)>[(a, body), (b, own)]) {
      final Rect box = _bounds(outline);
      expect(marks[0].dy - box.top, lessThan(0.25 * box.height));
      expect(box.right - marks[1].dx, lessThan(form.mm(0.5)));
      expect(box.bottom - marks[2].dy, lessThan(form.mm(0.5)));
      expect(marks[3].dx - box.left, lessThan(form.mm(0.5)));
    }
    expect(
      (_bounds(own).center - form.box.center).distance,
      lessThan(form.mm(0.5)),
    );
    expect((_bounds(own).width - form.box.width).abs(), lessThan(form.mm(1)));
  });

  test('its names point at what they name', () {
    final ProstateForm form = _form();
    expect(ProstateForm.inCentral(form.toMm(form.centralName)), isTrue);
    expect(ProstateForm.nearDucts(form.toMm(form.ductName), 0), isTrue);
    final Offset v = form.toMm(form.verumontanumName);
    expect(
      (v - ProstateAnatomy.colliculus).dx.abs(),
      lessThan(ProstateAnatomy.colliculusAcross),
    );
    expect(
      (v - ProstateAnatomy.colliculus).dy.abs(),
      lessThan(ProstateAnatomy.colliculusDown),
    );
    final Offset u = form.toMm(form.urethraName);
    expect(u.dx.abs(), lessThan(ProstateForm.urethraHalf(u.dy)));
    expect(u.dy, greaterThan(ProstateAnatomy.crestTo));
    expect(form.contains(form.vesicleName), isFalse);
    expect(form.homeName, form.site);
    expect(_form(ProstateHome.urethra).homeName, form.urethraName);
  });

  test('it is the same prostate every time', () {
    final ProstateForm a = _form();
    final ProstateForm b = _form();
    expect(a.outlinePoints, b.outlinePoints);
    expect(a.pores, b.pores);
    expect(a.glandDucts, b.glandDucts);
  });
}
