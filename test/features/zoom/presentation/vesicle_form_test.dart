import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/features/zoom/domain/anatomy_figure.dart';
import 'package:helixpeek/features/zoom/domain/anatomy_tables.dart';
import 'package:helixpeek/features/zoom/domain/zoom_depth.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/organs/seminal_vesicle/vesicle_anatomy.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/organs/seminal_vesicle/vesicle_form.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/tube_course.dart';

final TissueAnatomy _anatomy = tissueAnatomy['seminal vesicle']!;
final double _view =
    _anatomy.metres * ZoomDepth.organMargin / ZoomDepth.seminalVesicleUpright;
final AnatomyPart _part = AnatomyFigure.male.parts[_anatomy.uberon]!;

SeminalVesicleForm _form() =>
    SeminalVesicleForm.place(part: _part, anatomy: _anatomy, view: _view);

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

bool _inside(List<Offset> polygon, Offset p) {
  bool odd = false;
  final int n = polygon.length;
  for (int i = 0; i < n; i++) {
    final Offset a = polygon[i];
    final Offset b = polygon[(i + 1) % n];
    if ((a.dy > p.dy) != (b.dy > p.dy) &&
        p.dx < a.dx + (p.dy - a.dy) * (b.dx - a.dx) / (b.dy - a.dy)) {
      odd = !odd;
    }
  }
  return odd;
}

double _length(List<Offset> line) {
  double sum = 0;
  for (int i = 1; i < line.length; i++) {
    sum += (line[i] - line[i - 1]).distance;
  }
  return sum;
}

/// How far [p] lies from [tube]'s middle line, and that row's radius.
(double, double) _nearestRow(TubeCourse tube, Offset p) {
  int best = 0;
  for (int i = 1; i < tube.length; i++) {
    if ((tube.centres[i] - p).distanceSquared <
        (tube.centres[best] - p).distanceSquared) {
      best = i;
    }
  }
  return ((tube.centres[best] - p).distance, tube.radius[best]);
}

void main() {
  test('each vesicle is the card’s 5 cm along its course, 16 mm at its '
      'broadest, its broad end up and out, laid where the body goes in, '
      'its midline at the view’s middle', () {
    final SeminalVesicleForm form = _form();
    expect(form.mm(1), closeTo(1e-3 / _view, 1e-12));
    expect(_length(SeminalVesicleForm.spineMm), inInclusiveRange(48, 54));
    double widest = 0;
    double widestAt = 0;
    final List<Offset> spine = SeminalVesicleForm.spineMm;
    double a = 0;
    for (int i = 1; i < spine.length; i++) {
      a += (spine[i] - spine[i - 1]).distance;
      final double half = SeminalVesicleForm.halfAt(a);
      if (half > widest) {
        widest = half;
        widestAt = a;
      }
    }
    expect(2 * widest, inInclusiveRange(15, 17));
    // Broadest in its upper half, and the broad end higher and further
    // out than the duct.
    expect(widestAt, greaterThan(_length(spine) / 2));
    expect(spine.last.dy, lessThan(spine.first.dy - 40));
    expect(spine.last.dx, greaterThan(spine.first.dx + 20));
    expect(AnatomyFigure.female.parts[_anatomy.uberon], isNull);
    // The site where the body's is, inside the opened vesicle's mucosa.
    final double real = _anatomy.metres / _part.extent;
    expect(
      (form.site - (_part.site - _part.centre) * (real / _view)).distance,
      lessThan(1e-9),
    );
    expect(form.contains(form.site), isTrue);
    expect(
      (form.toMm(form.site) - SeminalVesicleAnatomy.site).distance,
      lessThan(1e-9),
    );
    expect(SeminalVesicleForm.inLumen(SeminalVesicleAnatomy.site), isTrue);
    expect(
      SeminalVesicleForm.lumenDepth(SeminalVesicleAnatomy.site),
      greaterThan(2),
    );
    // Laid so that the anatomy's midline lies at the view's middle: the
    // body's site is as far from the midline as the anatomy's is.
    expect(form.place(Offset.zero).dx.abs(), lessThan(form.mm(0.3)));
    expect(form.anchorShift, lessThan(20));
  });

  test('it is gone into in the opened vesicle’s mucosa, clear of its septa '
      'and its pits', () {
    const Offset site = SeminalVesicleAnatomy.site;
    for (final List<Offset> septum in SeminalVesicleForm.septaMm) {
      expect(_toLine(septum, site), greaterThan(2));
    }
    for (final (Offset p, double r) in SeminalVesicleForm.pitsMm) {
      expect((p - site).distance, greaterThan(r + 2));
    }
  });

  test('the vesicle on the body’s right is the left’s mirror, whole; the '
      'left is laid open: its lumen inside its wall, six septa across it '
      'from either side in turn, three pits in its lateral wall, and a '
      'honeycomb over it', () {
    final TubeCourse left = SeminalVesicleForm.leftMm;
    final TubeCourse right = SeminalVesicleForm.rightMm;
    expect(right.length, left.length);
    for (int i = 0; i < left.length; i++) {
      expect(right.centres[i].dx, closeTo(-left.centres[i].dx, 1e-9));
      expect(right.centres[i].dy, closeTo(left.centres[i].dy, 1e-9));
      expect(right.radius[i], closeTo(left.radius[i], 1e-9));
    }
    final List<Offset> outline = SeminalVesicleForm.openedOutlineMm;
    final List<Offset> lumen = SeminalVesicleForm.lumenMm;
    double nearest = double.infinity;
    double sum = 0;
    for (final Offset p in lumen) {
      expect(_inside(outline, p), isTrue, reason: '$p');
      final double away = _toLine(<Offset>[...outline, outline.first], p);
      nearest = math.min(nearest, away);
      sum += away;
    }
    // The wall away, less only where the sac's sides slant toward each
    // other, at its swellings.
    expect(
      sum / lumen.length,
      greaterThanOrEqualTo(0.75 * SeminalVesicleAnatomy.wall),
    );
    expect(nearest, greaterThanOrEqualTo(0.5 * SeminalVesicleAnatomy.wall));
    final List<List<Offset>> septa = SeminalVesicleForm.septaMm;
    expect(septa, hasLength(6));
    for (int k = 0; k < septa.length; k++) {
      final List<Offset> s = septa[k];
      // Rooted at the wall, reaching part way across, not to the other
      // wall.
      expect(_toLine(<Offset>[...lumen, lumen.first], s.first), lessThan(0.5));
      expect(_toLine(<Offset>[...lumen, lumen.first], s.last), greaterThan(1));
      // From either side in turn: the roots alternate across the spine.
      final (double _, double _) = _nearestRow(left, s.first);
      int row = 0;
      for (int i = 1; i < left.length; i++) {
        if ((left.centres[i] - s.first).distanceSquared <
            (left.centres[row] - s.first).distanceSquared) {
          row = i;
        }
      }
      final Offset d = s.first - left.centres[row];
      final double side =
          d.dx * left.across[row].dx + d.dy * left.across[row].dy;
      expect(side > 0, k.isEven, reason: 'septum $k');
    }
    for (final (Offset p, double r) in SeminalVesicleForm.pitsMm) {
      expect(SeminalVesicleForm.inLumen(p), isTrue);
      expect(SeminalVesicleForm.lumenDepth(p), greaterThan(r));
      // On the lateral side of the spine.
      int row = 0;
      for (int i = 1; i < left.length; i++) {
        if ((left.centres[i] - p).distanceSquared <
            (left.centres[row] - p).distanceSquared) {
          row = i;
        }
      }
      expect(p.dx, greaterThan(left.centres[row].dx));
    }
    final List<(Offset, Offset)> edges = SeminalVesicleForm.meshEdgesMm;
    expect(edges.length, greaterThan(150));
    for (final (Offset a, Offset b) in edges) {
      final Offset middle = Offset.lerp(a, b, 0.5)!;
      expect(
        SeminalVesicleForm.inLumen(middle) ||
            _toLine(<Offset>[...lumen, lumen.first], middle) <
                2.5 * SeminalVesicleAnatomy.mesh,
        isTrue,
        reason: '$middle',
      );
    }
  });

  test('the deferent duct comes in from above the vesicle’s upper end, '
      'fading in, widens into its ampulla down the medial margin and '
      'narrows to meet the vesicle’s duct at the base; the ejaculatory duct '
      'goes on into the prostate; the artery comes in from the side under '
      'the vesicle', () {
    final SeminalVesicleForm form = _form();
    final TubeCourse deferens = SeminalVesicleForm.leftDeferensMm;
    expect(deferens.shown.first, lessThan(0.05));
    expect(deferens.shown.last, 1);
    final List<Offset> spine = SeminalVesicleForm.spineMm;
    expect(deferens.centres.first.dy, lessThan(spine.last.dy - 10));
    expect((deferens.centres.last - spine.first).distance, lessThan(0.6));
    double widest = 0;
    for (int i = 0; i < deferens.length; i++) {
      widest = math.max(widest, deferens.radius[i]);
    }
    expect(2 * widest, inInclusiveRange(6, 7.5));
    expect(2 * deferens.radius.first, closeTo(3, 0.2));
    // The opened stretch along the ampulla, its lining inside its wall.
    final List<Offset> opened = SeminalVesicleForm.openedAmpullaMm;
    expect(_bounds(opened).top, greaterThan(spine.last.dy));
    expect(_bounds(opened).bottom, lessThan(spine.first.dy));
    expect(form.ampullaFolds.length, greaterThanOrEqualTo(5));
    for (final Offset p in form.ampullaLining) {
      expect(_inside(form.openedAmpulla, p), isTrue);
    }
    // The ejaculatory duct from the junction into the base.
    final TubeCourse ejaculatory = form.ejaculatory.first;
    expect(
      (form.toMm(ejaculatory.centres.first) - spine.first).distance,
      lessThan(0.6),
    );
    expect(ejaculatory.shown.first, 1);
    expect(ejaculatory.shown.last, lessThan(0.05));
    expect(
      SeminalVesicleForm.inProstate(form.toMm(ejaculatory.centres.last)),
      isTrue,
    );
    // The artery from the side, fading in, ending under the sac.
    final TubeCourse artery = form.arteries.first;
    expect(artery.shown.first, lessThan(0.05));
    expect(
      _inside(
        SeminalVesicleForm.openedOutlineMm,
        form.toMm(artery.centres.last),
      ),
      isTrue,
    );
    expect(form.toMm(artery.centres.first).dx, greaterThan(40));
  });

  test('the prostate’s base lies under the vesicles’ lower ends, the top of '
      'its outline at the origin, whole for 8 mm and gone by 20', () {
    final List<Offset> prostate = SeminalVesicleForm.prostateMm;
    expect(_bounds(prostate).top, closeTo(0, 0.5));
    expect(_bounds(prostate).width, closeTo(40, 0.5));
    expect(SeminalVesicleForm.prostateShownAt(const Offset(0, 5)), 1);
    expect(SeminalVesicleForm.prostateShownAt(const Offset(0, 8)), 1);
    expect(
      SeminalVesicleForm.prostateShownAt(const Offset(0, 14)),
      closeTo(0.5, 0.01),
    );
    expect(SeminalVesicleForm.prostateShownAt(const Offset(0, 20)), 0);
    // The vesicles' ducts start in the base.
    expect(
      SeminalVesicleForm.inProstate(SeminalVesicleForm.spineMm.first),
      isTrue,
    );
  });

  test('the step from the body meets the two outlines at their tops, their '
      'sides and their lowest points, in the same order', () {
    final SeminalVesicleForm form = _form();
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
      expect(box.bottom - marks[2].dy, lessThan(form.mm(0.5)));
      // The side marks are the outermost of the points between a fifth
      // and four fifths of the way down: the opened vesicle's broad end,
      // above that, reaches further out, and its duct, below, further in.
      double leftmost = double.infinity;
      double rightmost = double.negativeInfinity;
      for (final Offset p in outline) {
        final double down = (p.dy - box.top) / box.height;
        if (down >= 0.2 && down <= 0.8) {
          leftmost = math.min(leftmost, p.dx);
          rightmost = math.max(rightmost, p.dx);
        }
      }
      expect(rightmost - marks[1].dx, lessThan(form.mm(0.5)));
      expect(marks[3].dx - leftmost, lessThan(form.mm(0.5)));
    }
    expect(
      (_bounds(own).center - form.box.center).distance,
      lessThan(form.mm(0.5)),
    );
  });

  test('its names point at what they name', () {
    final SeminalVesicleForm form = _form();
    expect(form.homeName, form.site);
    final (double toVesicle, double vesicleRadius) = _nearestRow(
      form.right,
      form.vesicleName,
    );
    expect(toVesicle, lessThan(vesicleRadius));
    final TubeCourse rightDeferens = form.deferens.last;
    final (double toAmpulla, double ampullaRadius) = _nearestRow(
      rightDeferens,
      form.ampullaName,
    );
    expect(toAmpulla, lessThan(ampullaRadius + form.mm(0.3)));
    expect(ampullaRadius, greaterThan(form.mm(2.5)));
    final (double toDeferens, double deferensRadius) = _nearestRow(
      rightDeferens,
      form.deferensName,
    );
    expect(toDeferens, lessThan(deferensRadius + form.mm(0.3)));
    int row = 0;
    for (int i = 1; i < rightDeferens.length; i++) {
      if ((rightDeferens.centres[i] - form.deferensName).distanceSquared <
          (rightDeferens.centres[row] - form.deferensName).distanceSquared) {
        row = i;
      }
    }
    expect(rightDeferens.shown[row], greaterThan(0.5));
    final (double toDuct, double ductRadius) = _nearestRow(
      form.ejaculatory.first,
      form.ejaculatoryName,
    );
    expect(toDuct, lessThan(ductRadius + form.mm(0.3)));
    final Offset prostate = form.toMm(form.prostateName);
    expect(SeminalVesicleForm.inProstate(prostate), isTrue);
    expect(SeminalVesicleForm.prostateShownAt(prostate), greaterThan(0.9));
    expect(form.contains(form.vesicleName), isFalse);
    expect(form.contains(form.prostateName), isFalse);
  });

  test('it is the same specimen every time', () {
    final SeminalVesicleForm a = _form();
    final SeminalVesicleForm b = _form();
    expect(a.outlinePoints, b.outlinePoints);
    expect(a.meshEdges, b.meshEdges);
    expect(a.septa, b.septa);
    expect(a.pits, b.pits);
  });
}
