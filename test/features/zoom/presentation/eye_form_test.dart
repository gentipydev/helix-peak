import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/features/zoom/domain/anatomy_tables.dart';
import 'package:helixpeek/features/zoom/domain/zoom_depth.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/organs/eye/eye_anatomy.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/organs/eye/eye_form.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/organs/eye/eye_style.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/tube_course.dart';

final TissueAnatomy _anatomy = tissueAnatomy['retina']!;
final double _view =
    _anatomy.metres * ZoomDepth.organMargin / ZoomDepth.eyeUpright;

EyeForm _form() => EyeForm(length: _anatomy.metres / _view, view: _view);

bool _inside(List<Offset> points, Offset p) {
  bool inside = false;
  for (int i = 0, j = points.length - 1; i < points.length; j = i++) {
    final Offset a = points[i];
    final Offset b = points[j];
    if ((a.dy > p.dy) != (b.dy > p.dy) &&
        p.dx < (b.dx - a.dx) * (p.dy - a.dy) / (b.dy - a.dy) + a.dx) {
      inside = !inside;
    }
  }
  return inside;
}

/// How far [p] lies from the line through [points], open or [closed].
double _toLine(List<Offset> points, Offset p, {bool closed = false}) {
  double least = double.infinity;
  final int n = points.length;
  for (int i = 0; i < (closed ? n : n - 1); i++) {
    final Offset a = points[i];
    final Offset b = points[(i + 1) % n];
    final Offset ab = b - a;
    final double length = ab.distanceSquared;
    final double t = length == 0
        ? 0
        : (((p - a).dx * ab.dx + (p - a).dy * ab.dy) / length).clamp(0.0, 1.0);
    least = math.min(least, (a + ab * t - p).distance);
  }
  return least;
}

/// Whether the segments from [a] to [b] and from [c] to [d] cross.
bool _cross(Offset a, Offset b, Offset c, Offset d) {
  double side(Offset p, Offset q, Offset r) =>
      (q.dx - p.dx) * (r.dy - p.dy) - (q.dy - p.dy) * (r.dx - p.dx);
  final double d1 = side(c, d, a);
  final double d2 = side(c, d, b);
  final double d3 = side(a, b, c);
  final double d4 = side(a, b, d);
  return d1 * d2 < 0 && d3 * d4 < 0;
}

/// Whether any segment of [one] crosses any of [other].
bool _crosses(List<Offset> one, List<Offset> other) {
  for (int i = 0; i + 1 < one.length; i++) {
    for (int j = 0; j + 1 < other.length; j++) {
      if (_cross(one[i], one[i + 1], other[j], other[j + 1])) {
        return true;
      }
    }
  }
  return false;
}

Rect _bounds(List<Offset> points) {
  double left = double.infinity;
  double top = double.infinity;
  double right = double.negativeInfinity;
  double bottom = double.negativeInfinity;
  for (final Offset p in points) {
    left = math.min(left, p.dx);
    right = math.max(right, p.dx);
    top = math.min(top, p.dy);
    bottom = math.max(bottom, p.dy);
  }
  return Rect.fromLTRB(left, top, right, bottom);
}

/// The radius of the circle through three points.
double _radius(Offset a, Offset b, Offset c) {
  final double ab = (a - b).distance;
  final double bc = (b - c).distance;
  final double ca = (c - a).distance;
  final double area2 =
      ((b.dx - a.dx) * (c.dy - a.dy) - (b.dy - a.dy) * (c.dx - a.dx)).abs();
  return ab * bc * ca / (2 * area2);
}

void main() {
  test('the eye is 24 mm front to back and across, its middle at the '
      'origin, where the body’s circle of it has its middle', () {
    final EyeForm form = _form();
    final Rect box = _bounds(form.outlineMm);
    expect(box.height, closeTo(EyeAnatomy.length, 0.01));
    expect(box.width, closeTo(EyeAnatomy.breadth, 0.01));
    expect(box.center.distance, lessThan(0.01));
    expect(form.mm(EyeAnatomy.length), closeTo(_anatomy.metres / _view, 1e-12));
    // The cornea's apex at the front and the posterior pole at the back.
    expect(EyeForm.outer(0).dy, closeTo(EyeAnatomy.length / 2, 1e-9));
    expect(
      form.cornea.outer[form.cornea.length ~/ 2].dy,
      closeTo(-EyeAnatomy.length / 2, 0.01),
    );
  });

  test('its coats and parts are the sizes they are measured at', () {
    final EyeForm form = _form();
    // The cornea: 11.71 mm across at the limbus (Rüfer et al.), 0.52 thick
    // in its middle and 0.67 at its edge (Maurice).
    expect(
      (form.cornea.outer.first - form.cornea.outer.last).distance,
      closeTo(EyeAnatomy.corneaAcross, 0.01),
    );
    expect(
      form.cornea.thicknessAt(form.cornea.length ~/ 2),
      closeTo(EyeAnatomy.corneaMiddle, 0.01),
    );
    expect(
      EyeForm.corneaAt(EyeForm.junctionCorneaAngle),
      closeTo(EyeAnatomy.corneaEdge, 1e-9),
    );
    // The sclera: 0.53 at the limbus, 0.39 at the equator, 0.9 to 1.0 by
    // the nerve (Olsen et al.).
    expect(
      EyeForm.scleraAt(EyeForm.limbusAngle),
      closeTo(EyeAnatomy.scleraLimbus, 1e-9),
    );
    expect(
      EyeForm.scleraAt(math.pi / 2),
      closeTo(EyeAnatomy.scleraEquator, 1e-9),
    );
    expect(EyeForm.scleraAt(EyeForm.nerveAngle), inInclusiveRange(0.9, 1.0));
    // The choroid: 0.287 under the fovea, 0.145 at 3 mm nasal of it
    // (Margolis and Spaide).
    expect(
      EyeForm.choroidAt(EyeForm.foveaArc),
      closeTo(EyeAnatomy.choroidFovea, 1e-9),
    );
    expect(
      EyeForm.choroidAt(EyeForm.foveaArc - EyeAnatomy.choroidNasalAt),
      closeTo(EyeAnatomy.choroidNasal, 1e-9),
    );
    // The retina: 0.15 at the fovea's floor, 0.32 at its rim, 0.08 at the
    // ora serrata (Webvision); the fovea 1.5 mm from rim to rim, its rim
    // the retina's thickest.
    expect(
      EyeForm.retinaAt(EyeForm.foveaArc),
      closeTo(EyeAnatomy.retinaFloor, 1e-9),
    );
    for (final double side in <double>[-1, 1]) {
      expect(
        EyeForm.retinaAt(EyeForm.foveaArc + side * EyeAnatomy.fovea / 2),
        closeTo(EyeAnatomy.retinaRim, 1e-9),
      );
    }
    for (final double ora in <double>[EyeForm.oraNasal, EyeForm.oraTemporal]) {
      expect(
        EyeForm.retinaAt(EyeForm.innerArcAt(ora)),
        closeTo(EyeAnatomy.retinaOra, 1e-6),
      );
    }
    for (final EyeBand band in form.retina) {
      for (int i = 0; i < band.length; i++) {
        expect(
          band.thicknessAt(i),
          inInclusiveRange(
            EyeAnatomy.retinaOra - 1e-6,
            EyeAnatomy.retinaRim + 1e-6,
          ),
        );
      }
    }
    // The ora serrata 6 mm behind the limbus nasally and 7 temporally; the
    // ciliary body from 1 mm behind it.
    expect(
      EyeForm.limbusArc - EyeForm.outerArcAt(EyeForm.oraTemporal),
      closeTo(EyeAnatomy.oraTemporal, 0.01),
    );
    expect(
      EyeForm.outerArcAt(EyeForm.oraNasal) + EyeForm.limbusArc,
      closeTo(EyeAnatomy.oraNasal, 0.01),
    );
    // The lens 9.21 across and 4.18 thick (Xue and Zou), its front 1.7
    // times as flat as its back (Le Grand), 3.05 behind the cornea's back.
    final Rect lens = _bounds(form.lensMm);
    expect(lens.width, closeTo(EyeAnatomy.lensAcross, 0.01));
    expect(lens.height, closeTo(EyeAnatomy.lensThick, 0.01));
    double poleRadius(double t) => _radius(
      EyeForm.lensAt(t - 0.02),
      EyeForm.lensAt(t),
      EyeForm.lensAt(t + 0.02),
    );
    expect(
      poleRadius(0) / poleRadius(math.pi),
      closeTo(EyeAnatomy.lensFlatter, 0.01),
    );
    expect(
      EyeForm.lensFront - (EyeAnatomy.corneaMiddle - EyeAnatomy.length / 2),
      closeTo(EyeAnatomy.chamber, 1e-9),
    );
    // The iris 0.45 thick near its root and 0.60 at most (Wang et al.);
    // the pupil 4 mm across.
    for (final EyeBand iris in form.iris) {
      expect(iris.thicknessAt(0), closeTo(EyeAnatomy.irisRoot, 0.01));
      double most = 0;
      for (int i = 0; i < iris.length; i++) {
        most = math.max(most, iris.thicknessAt(i));
      }
      expect(most, closeTo(EyeAnatomy.irisMost, 0.01));
    }
    expect(
      (form.iris[0].inner.last - form.iris[1].inner.last).distance,
      closeTo(EyeAnatomy.pupil, 0.1),
    );
    // The disc 1.75 across, the fovea 3.4 mm temporal of its edge
    // (Webvision), the nerve entering 3 mm nasal of the posterior pole
    // (Gray).
    expect(
      EyeForm.innerArcAt(EyeForm.discMargins.$2) -
          EyeForm.innerArcAt(EyeForm.discMargins.$1),
      closeTo(EyeAnatomy.disc, 0.01),
    );
    expect(
      EyeForm.foveaArc - EyeForm.innerArcAt(EyeForm.discMargins.$2),
      closeTo(EyeAnatomy.foveaFromDisc, 0.01),
    );
    expect(
      EyeForm.outerArcAt(EyeForm.nerveAngle),
      closeTo(-EyeAnatomy.nerveNasal, 0.01),
    );
    // Behind the globe the nerve 2.76 across at 3 mm and 2.32 at 8, its
    // sheath 5.10 and 4.38 (Watcharakorn et al.).
    expect(
      EyeForm.nerveAcrossAt(EyeAnatomy.nerveNear),
      EyeAnatomy.nerveNearAcross,
    );
    expect(
      EyeForm.nerveAcrossAt(EyeAnatomy.nerveFar),
      EyeAnatomy.nerveFarAcross,
    );
    expect(
      EyeForm.sheathAcrossAt(EyeAnatomy.nerveNear),
      EyeAnatomy.sheathNearAcross,
    );
    expect(
      EyeForm.sheathAcrossAt(EyeAnatomy.nerveFar),
      EyeAnatomy.sheathFarAcross,
    );
    // The recti's bellies 3.4 and 4.1 mm thick (Rana et al.).
    expect(
      2 * EyeForm.rectusTubes[0].radii.reduce(math.max),
      closeTo(EyeAnatomy.lateralBelly, 0.01),
    );
    expect(
      2 * EyeForm.rectusTubes[1].radii.reduce(math.max),
      closeTo(EyeAnatomy.medialBelly, 0.01),
    );
  });

  test('the coats lie one inside the next, from the ora serrata back to '
      'the disc, none crossing another', () {
    final EyeForm form = _form();
    for (int side = 0; side < 2; side++) {
      final EyeBand sclera = form.sclera[side];
      final EyeBand choroid = form.choroid[side];
      final EyeBand retina = form.retina[side];
      // Each coat lies on the next out.
      for (int i = 0; i < choroid.length; i++) {
        expect(
          _toLine(sclera.inner, choroid.outer[i]),
          lessThan(0.01),
          reason: 'the choroid on the sclera, $side $i',
        );
        expect(retina.outer[i], choroid.inner[i]);
      }
      for (final EyeBand band in <EyeBand>[sclera, choroid, retina]) {
        expect(_crosses(band.outer, band.inner), isFalse);
        for (final Offset p in band.inner) {
          expect(_inside(form.outlineMm, p), isTrue);
        }
      }
      expect(_crosses(retina.inner, sclera.inner), isFalse);
      // The ciliary body on the sclera from the spur back to the ora
      // serrata, where the choroid takes over.
      final EyeBand ciliary = form.ciliary[side];
      expect(
        (ciliary.outer.last - choroid.outer.first).distance,
        lessThan(0.01),
      );
      for (final Offset p in ciliary.outer) {
        expect(_toLine(sclera.inner, p), lessThan(0.01));
      }
      // The ciliary muscle within the ciliary body.
      for (final Offset p in form.muscles[side].inner) {
        expect(
          _inside(ciliary.outline, p) ||
              _toLine(ciliary.outline, p, closed: true) < 0.01,
          isTrue,
        );
      }
    }
    // The sclera meets the cornea at the limbus, outside and inside.
    expect(
      (form.sclera[0].outer.first - form.cornea.outer.last).distance,
      lessThan(1e-9),
    );
    expect(
      (form.sclera[1].outer.first - form.cornea.outer.first).distance,
      lessThan(1e-9),
    );
    expect(
      (form.sclera[0].inner.first - form.cornea.inner.last).distance,
      lessThan(1e-9),
    );
    expect(
      (form.sclera[1].inner.first - form.cornea.inner.first).distance,
      lessThan(1e-9),
    );
  });

  test('the lens hangs behind the iris on its zonules, the pupil open, the '
      'iris resting on the lens at its margin', () {
    final EyeForm form = _form();
    for (final EyeBand iris in form.iris) {
      final Offset margin = iris.inner.last;
      expect(
        margin.dy,
        closeTo(EyeForm.lensFrontAt(margin.dx), 0.01),
        reason: 'the iris rests on the lens',
      );
      for (final Offset p in iris.inner) {
        expect(p.dy, lessThan(EyeForm.lensEquator));
      }
    }
    for (final (Offset from, Offset to) in form.zonules) {
      expect(
        <double>[
          _toLine(form.ciliary[0].inner, from),
          _toLine(form.ciliary[1].inner, from),
        ].reduce(math.min),
        lessThan(1e-9),
      );
      expect(_toLine(form.lensMm, to, closed: true), lessThan(0.05));
    }
    for (final Offset p in form.lensMm) {
      expect(_inside(form.interiorMm, p), isTrue);
    }
  });

  test('the optic nerve leaves through the scleral canal at the disc, nasal '
      'of the posterior pole and of the fovea, its vessels in it, and fades '
      'out behind the globe', () {
    final EyeForm form = _form();
    expect(EyeForm.nerveTube.points.first, EyeForm.discFace);
    expect(EyeForm.disc.dx, lessThan(0));
    expect(EyeForm.disc.dx, lessThan(EyeForm.fovea.dx));
    // The canal as wide as the disc on the sclera's inner face, and as the
    // nerve where it leaves the globe.
    expect(
      (form.sclera[0].inner.last - form.sclera[1].inner.last).distance,
      closeTo(EyeAnatomy.disc, 0.05),
    );
    expect(
      (form.sclera[0].outer.last - form.sclera[1].outer.last).distance,
      closeTo(EyeAnatomy.nerveNearAcross, 0.05),
    );
    // The central vessels in the nerve, from where they come into it to
    // the disc's face.
    final TubeCourse nerve = form.nerve;
    for (final TubeCourse vessel in form.central) {
      for (int i = 0; i < vessel.length; i++) {
        double nearest = double.infinity;
        int at = 0;
        for (int k = 0; k < nerve.length; k++) {
          final double d = (nerve.centres[k] - vessel.centres[i]).distance;
          if (d < nearest) {
            nearest = d;
            at = k;
          }
        }
        expect(
          nearest + vessel.radius[i],
          lessThan(nerve.radius[at]),
          reason: 'vessel row $i',
        );
      }
      expect(vessel.shown.first, 0);
    }
    // It fades out, its sheath with it.
    expect(nerve.shown.last, closeTo(0, 1e-9));
    expect(form.sheath.shown.last, closeTo(0, 1e-9));
  });

  test('the recti insert where they are measured, lie on the sclera round '
      'the globe and fade out toward the orbit’s apex, clear of the nerve', () {
    final EyeForm form = _form();
    for (final (int index, double insertion, int side) in <(int, double, int)>[
      (0, EyeAnatomy.lateralInsertion, 1),
      (1, EyeAnatomy.medialInsertion, -1),
    ]) {
      final AnatomyTube rectus = EyeForm.rectusTubes[index];
      // Its insertion on the globe, so far behind the limbus.
      final double angle = EyeForm.behindLimbus(insertion, side);
      final Offset on = EyeForm.outer(angle);
      expect(
        (rectus.points.first - on).distance,
        closeTo(rectus.radii.first, 1e-6),
      );
      // Round the globe it lies on the sclera, then leaves it.
      for (int k = 0; k < rectus.points.length; k++) {
        final double clear =
            _toLine(form.outlineMm, rectus.points[k], closed: true) -
            rectus.radii[k];
        expect(clear, greaterThan(-0.02), reason: 'rectus $index, knot $k');
        expect(_inside(form.outlineMm, rectus.points[k]), isFalse);
      }
      final TubeCourse course = form.recti[index];
      expect(course.shown.last, closeTo(0, 1e-9));
      // Clear of the nerve's sheath wherever both show.
      final TubeCourse sheath = form.sheath;
      for (int i = 0; i < course.length; i++) {
        if (course.shown[i] < 0.05) {
          continue;
        }
        for (int k = 0; k < sheath.length; k++) {
          if (sheath.shown[k] < 0.05) {
            continue;
          }
          expect(
            (course.centres[i] - sheath.centres[k]).distance,
            greaterThan(course.radius[i] + sheath.radius[k]),
          );
        }
      }
    }
  });

  test('the tissue is sampled in the retina’s middle at the posterior pole, '
      'between the disc and the fovea', () {
    final EyeForm form = _form();
    final Offset site = EyeForm.siteMm;
    expect(site.dx, 0);
    expect(site.dx, greaterThan(EyeForm.disc.dx));
    expect(site.dx, lessThan(EyeForm.fovea.dx));
    // Out of the fovea's pit, between the pigment epithelium and the
    // retina's inner face.
    expect(
      (EyeForm.innerArcAt(0) - EyeForm.foveaArc).abs(),
      greaterThan(EyeAnatomy.fovea / 2),
    );
    expect(site.dy, lessThan(EyeForm.pigmentAt(0).dy));
    expect(site.dy, greaterThan(EyeForm.retinaInner(0).dy));
    // At the posterior pole: the way out of the globe there is straight
    // back.
    expect(EyeForm.outward(0).dx, 0);
    expect(form.contains(form.site), isTrue);
  });

  test('it is drawn turned a quarter to the left: the cornea to the left of '
      'the globe’s middle, the nerve leaving to the right, the temporal side '
      'up', () {
    final EyeForm form = _form();
    final Offset apex = form.place(const Offset(0, -EyeAnatomy.length / 2));
    expect(apex.dx, closeTo(-form.mm(EyeAnatomy.length / 2), 1e-12));
    expect(apex.dy.abs(), lessThan(1e-12));
    expect(form.site.dx, greaterThan(0));
    expect(
      form.nerve.centres.last.dx,
      greaterThan(form.mm(EyeAnatomy.length / 2)),
    );
    // The lateral rectus above the globe, the medial below.
    expect(form.recti[0].centres.first.dy, lessThan(0));
    expect(form.recti[1].centres.first.dy, greaterThan(0));
    for (final Offset p in <Offset>[
      const Offset(3, -7),
      EyeForm.siteMm,
      EyeForm.discFace,
    ]) {
      expect((form.toMm(form.place(p)) - p).distance, lessThan(1e-9));
    }
  });

  test('each part is named on what it names', () {
    final EyeForm form = _form();
    expect(_inside(form.cornea.outline, form.toMm(form.corneaName)), isTrue);
    expect(_inside(form.lensMm, form.toMm(form.lensName)), isTrue);
    final TubeCourse nerve = form.nerve;
    double nearest = double.infinity;
    int at = 0;
    for (int k = 0; k < nerve.length; k++) {
      final double d = (nerve.centres[k] - form.nerveName).distance;
      if (d < nearest) {
        nearest = d;
        at = k;
      }
    }
    expect(nearest, lessThan(nerve.radius[at]));
    expect(nerve.shown[at], greaterThan(EyeStyle.nameShown));
  });

  test('the eye is laid the same every time', () {
    final EyeForm a = _form();
    final EyeForm b = _form();
    expect(a.outlineMm, b.outlineMm);
    expect(a.interiorMm, b.interiorMm);
    for (int side = 0; side < 2; side++) {
      for (final (EyeBand x, EyeBand y) in <(EyeBand, EyeBand)>[
        (a.sclera[side], b.sclera[side]),
        (a.choroid[side], b.choroid[side]),
        (a.retina[side], b.retina[side]),
        (a.ciliary[side], b.ciliary[side]),
        (a.iris[side], b.iris[side]),
      ]) {
        expect(x.outer, y.outer);
        expect(x.inner, y.inner);
      }
    }
    expect(a.nerve.centres, b.nerve.centres);
    expect(a.recti[0].centres, b.recti[0].centres);
    expect(a.zonules, b.zonules);
  });
}
