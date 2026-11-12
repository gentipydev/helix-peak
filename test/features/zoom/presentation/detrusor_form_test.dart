import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/features/zoom/domain/anatomy_figure.dart';
import 'package:helixpeek/features/zoom/domain/anatomy_tables.dart';
import 'package:helixpeek/features/zoom/domain/zoom_depth.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/organs/bladder/bladder_anatomy.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/organs/bladder/bladder_form.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/organs/bladder/bladder_style.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/organs/smooth_muscle/detrusor_anatomy.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/organs/smooth_muscle/detrusor_form.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/tube_course.dart';

final TissueAnatomy _anatomy = tissueAnatomy['smooth muscle']!;
final double _view =
    _anatomy.metres * ZoomDepth.organMargin / ZoomDepth.smoothMuscleUpright;

DetrusorForm _form(AnatomyFigure figure) => DetrusorForm.place(
  part: figure.parts[_anatomy.uberon]!,
  anatomy: _anatomy,
  view: _view,
);

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
  test('it is the bladder specimen’s bladder at the card’s 8 cm, laid where '
      'the body goes in, over the body’s outline of its wall, on either '
      'figure', () {
    expect(_bounds(DetrusorForm.outlineMm).width, closeTo(100, 0.5));
    expect(
      DetrusorForm.outlineMm.length,
      BladderForm.knotsMm.length * BladderStyle.outlineSpan,
    );
    for (final AnatomyFigure figure in <AnatomyFigure>[
      AnatomyFigure.female,
      AnatomyFigure.male,
    ]) {
      final AnatomyPart part = figure.parts[_anatomy.uberon]!;
      final DetrusorForm form = _form(figure);
      expect(form.mm(1), closeTo(0.8e-3 / _view, 1e-12), reason: figure.name);
      expect(
        form.mm(BladderAnatomy.length),
        closeTo(_anatomy.metres / _view, 1e-12),
      );
      final double real = _anatomy.metres / part.extent;
      expect(
        (form.site - (part.site - part.centre) * (real / _view)).distance,
        lessThan(1e-9),
        reason: figure.name,
      );
      expect(form.contains(form.site), isTrue, reason: figure.name);
      expect(
        (form.toMm(form.site) - BladderAnatomy.site).distance,
        lessThan(1e-9),
      );
      // The anatomogram's smooth muscle is the bladder's wall: the bladder
      // lies over it.
      expect(form.anchorShift, lessThan(6), reason: figure.name);
    }
  });

  test('the outer layer’s bundles run from the apex to the neck as the '
      'meridians of the bladder’s form, none under 2 mm apart, none through '
      'the patch, the site between two; oblique bundles cross at the sides, '
      'and three rings go round the neck', () {
    final List<List<Offset>> bundles = DetrusorForm.bundlesMm;
    // The outermost meridians lie too close to be drawn; those round the
    // patch run in two pieces.
    expect(
      bundles.length,
      inInclusiveRange(
        DetrusorAnatomy.bundles - 8,
        DetrusorAnatomy.bundles + 8,
      ),
    );
    final Rect box = _bounds(DetrusorForm.outlineMm);
    double top = double.infinity;
    double bottom = double.negativeInfinity;
    for (final List<Offset> b in bundles) {
      for (final Offset p in b) {
        expect(_inside(DetrusorForm.outlineMm, p), isTrue, reason: '$p');
        expect(DetrusorForm.inPatch(p), isFalse, reason: '$p');
        top = math.min(top, p.dy);
        bottom = math.max(bottom, p.dy);
      }
    }
    // Over most of the height, short of the apex and the neck.
    expect(top - box.top, inInclusiveRange(1, 12));
    expect(box.bottom - bottom, inInclusiveRange(1, 16));
    // No two bundles under 2 mm apart at any height, less only by what
    // two may wander toward each other.
    final List<Map<int, double>> byHeight = <Map<int, double>>[
      for (final List<Offset> b in bundles)
        <int, double>{for (final Offset p in b) (p.dy * 100).round(): p.dx},
    ];
    for (int i = 0; i < bundles.length; i++) {
      for (int j = i + 1; j < bundles.length; j++) {
        for (final MapEntry<int, double> row in byHeight[i].entries) {
          final double? other = byHeight[j][row.key];
          if (other == null) {
            continue;
          }
          expect(
            (other - row.value).abs(),
            greaterThan(
              DetrusorAnatomy.bundleLeast - 2 * DetrusorAnatomy.wander - 0.05,
            ),
            reason: 'bundles $i and $j at ${row.key / 100}',
          );
        }
      }
    }
    // The site between two bundles, clear of both.
    expect(DetrusorForm.clearOfBundles(BladderAnatomy.site), greaterThan(1.5));
    // Bunching toward the sides: the two outermost bundles lie nearer each
    // other than the two middle ones.
    final List<double> shares = <double>[
      for (int k = 0; k < DetrusorAnatomy.bundles; k++)
        DetrusorForm.bundleShare(k),
    ];
    expect(shares[1] - shares[0], lessThan(shares[16] - shares[15]));
    expect(shares.first, lessThan(0));
    expect(shares.last, greaterThan(0));
    expect(shares[DetrusorAnatomy.bundles ~/ 2], closeTo(0, 1e-9));
    // The oblique bundles at the sides, in the lateral thirds.
    final List<List<Offset>> obliques = DetrusorForm.obliquesMm;
    expect(obliques.length, greaterThanOrEqualTo(12));
    for (final List<Offset> o in obliques) {
      for (final Offset p in o) {
        expect(_inside(DetrusorForm.outlineMm, p), isTrue);
        expect(p.dx.abs(), greaterThan(0.5 * DetrusorForm.halfAt(p.dy)));
      }
    }
    // The rings round the neck.
    final List<List<Offset>> rings = DetrusorForm.ringsMm;
    expect(rings, hasLength(3));
    for (final List<Offset> r in rings) {
      expect(r.first.dy, greaterThan(box.bottom - 12));
      for (final Offset p in r) {
        expect(_inside(DetrusorForm.outlineMm, p), isTrue, reason: '$p');
      }
    }
  });

  test('the patch is cut from the outer layer low on the body’s right, '
      'between two bundles, the circular layer’s bundles across it, a little '
      'oblique, kept in from its edge', () {
    final List<Offset> patch = DetrusorForm.patchMm;
    final Rect box = _bounds(patch);
    expect(box.right, lessThan(-10));
    expect(box.top, closeTo(DetrusorAnatomy.patchTop, 0.01));
    expect(box.bottom, closeTo(DetrusorAnatomy.patchBottom, 0.01));
    expect(box.width, inInclusiveRange(12, 26));
    for (final Offset p in patch) {
      expect(_inside(DetrusorForm.outlineMm, p), isTrue, reason: '$p');
    }
    expect(DetrusorForm.inPatch(BladderAnatomy.site), isFalse);
    final List<List<Offset>> circular = DetrusorForm.circularMm;
    expect(
      circular.length,
      greaterThanOrEqualTo(DetrusorAnatomy.circular.length),
    );
    for (final List<Offset> c in circular) {
      expect(c.length, greaterThan(4));
      for (final Offset p in c) {
        expect(DetrusorForm.inPatch(p), isTrue, reason: '$p');
        expect(
          DetrusorForm.patchDepth(p),
          greaterThanOrEqualTo(DetrusorAnatomy.circularIn - 0.1),
        );
      }
      // Rising toward the body's side: the end further out is the higher.
      final Offset outer = c.first.dx.abs() > c.last.dx.abs()
          ? c.first
          : c.last;
      final Offset inner = identical(outer, c.first) ? c.last : c.first;
      expect(outer.dy, lessThan(inner.dy));
    }
  });

  test('the ureters come down behind it and the urethra leaves it below, '
      'each cut short; the urachus rises from the apex, fading out; the '
      'arteries’ branches run over the wall and fade into it', () {
    final DetrusorForm form = _form(AnatomyFigure.female);
    final Rect box = _bounds(DetrusorForm.outlineMm);
    for (final TubeCourse ureter in form.ureters) {
      expect(ureter.cutEnd, isTrue);
      // Its lower end under the bladder, its cut end above and beside.
      expect(form.contains(ureter.centres.first), isTrue);
      expect(form.contains(ureter.centres.last), isFalse);
      expect(form.toMm(ureter.centres.last).dy, lessThan(box.center.dy));
    }
    expect(form.urethra.cutEnd, isTrue);
    expect(form.toMm(form.urethra.centres.last).dy, greaterThan(box.bottom));
    final TubeCourse urachus = form.urachus;
    expect(form.contains(urachus.centres.first), isTrue);
    expect(form.toMm(urachus.centres.last).dy, lessThan(box.top - 15));
    expect(urachus.shown.first, 1);
    expect(urachus.shown.last, lessThan(0.05));
    expect(form.branches.length, greaterThan(6));
    for (final TubeCourse branch in form.branches) {
      expect(form.contains(branch.centres.last), isTrue);
      expect(branch.shown.first, 1);
      expect(branch.shown.last, lessThan(0.05));
    }
    expect(form.arteries, hasLength(4));
  });

  test('the step from the body meets the two outlines at the dome’s middle, '
      'the sides and the neck, in the same order, and lands on the '
      'bladder’s own outline', () {
    final DetrusorForm form = _form(AnatomyFigure.female);
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
  });

  test('its names point at what they name', () {
    final DetrusorForm female = _form(AnatomyFigure.female);
    expect(female.homeName, female.site);
    expect(DetrusorForm.inPatch(female.toMm(female.circularName)), isTrue);
    final (double toUrachus, double urachusRadius) = _nearestRow(
      female.urachus,
      female.urachusName,
    );
    expect(toUrachus, lessThan(urachusRadius + female.mm(0.3)));
    expect(female.contains(female.urachusName), isFalse);
    final (double toUreter, double ureterRadius) = _nearestRow(
      female.ureters.first,
      female.ureterName,
    );
    expect(toUreter, lessThan(ureterRadius + female.mm(0.3)));
    expect(female.contains(female.ureterName), isFalse);
    // The sphincter on one of its rings, inside the bladder, low down and
    // toward the body's right.
    bool onRing = false;
    for (final List<Offset> ring in female.rings) {
      for (final Offset p in ring) {
        onRing |= (p - female.sphincterName).distance < female.mm(0.3);
      }
    }
    expect(onRing, isTrue);
    expect(female.contains(female.sphincterName), isTrue);
    final Offset sphincter = female.toMm(female.sphincterName);
    expect(sphincter.dy, greaterThan(25));
    expect(sphincter.dx, greaterThan(10));
  });

  test('it is the same muscle every time', () {
    final DetrusorForm a = _form(AnatomyFigure.female);
    final DetrusorForm b = _form(AnatomyFigure.female);
    expect(a.outlinePoints, b.outlinePoints);
    expect(a.bundles, b.bundles);
    expect(a.circular, b.circular);
    expect(a.branches.length, b.branches.length);
  });
}
