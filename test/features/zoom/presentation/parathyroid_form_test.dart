import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/features/zoom/domain/anatomy_tables.dart';
import 'package:helixpeek/features/zoom/domain/zoom_depth.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/organs/parathyroid/parathyroid_anatomy.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/organs/parathyroid/parathyroid_form.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/organs/parathyroid/parathyroid_style.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/tube_course.dart';

final TissueAnatomy _anatomy = tissueAnatomy['parathyroid gland']!;
final double _view =
    _anatomy.metres * ZoomDepth.organMargin / ZoomDepth.parathyroidUpright;

ParathyroidForm _form([ParathyroidHome home = ParathyroidHome.chief]) =>
    ParathyroidForm(view: _view, home: home);

double _area(List<Offset> points) {
  double sum = 0;
  for (int i = 0; i < points.length; i++) {
    final Offset a = points[i];
    final Offset b = points[(i + 1) % points.length];
    sum += a.dx * b.dy - b.dx * a.dy;
  }
  return sum.abs() / 2;
}

void main() {
  test('the gland is drawn at its real size, Gray’s flattened oval disc: '
      'about 6 mm long and 3 to 4 mm broad, as its card says', () {
    final ParathyroidForm form = _form();
    expect(form.mm(1), closeTo(1e-3 / _view, 1e-15));
    expect(_anatomy.metres, 0.006);
    final List<Offset> outline = ParathyroidForm.outlineMm;
    // Its length along its long axis, its breadth across it.
    final double c = math.cos(ParathyroidAnatomy.tilt);
    final double s = math.sin(ParathyroidAnatomy.tilt);
    double along = 0;
    double across = 0;
    for (final Offset p in outline) {
      final Offset d = p - ParathyroidAnatomy.gland;
      along = math.max(along, (d.dx * -s + d.dy * c).abs());
      across = math.max(across, (d.dx * c + d.dy * s).abs());
    }
    expect(2 * along, inInclusiveRange(5.6, 6.4));
    expect(2 * across, inInclusiveRange(3, 4.3));
    // A disc 6 by 4 mm and 1.5 mm thick holds a normal gland's median
    // weight, Dufour and Wilkerson's 25.7 mg, within their 95% range.
    final double mg = _area(outline) * 1.5;
    expect(mg, inInclusiveRange(8.2, 75));
  });

  test('its upper pole leans toward the body’s middle, along the lobe’s '
      'posterior border, and its hilum lies low on its medial side', () {
    final List<Offset> outline = ParathyroidForm.outlineMm;
    final Offset top = outline.reduce(
      (Offset a, Offset b) => a.dy < b.dy ? a : b,
    );
    final Offset bottom = outline.reduce(
      (Offset a, Offset b) => a.dy > b.dy ? a : b,
    );
    expect(top.dx, lessThan(bottom.dx));
    final Offset hilum = ParathyroidForm.hilumMm;
    expect(hilum.dy, greaterThan(ParathyroidAnatomy.gland.dy + 1.5));
    expect(hilum.dx, lessThan(ParathyroidAnatomy.gland.dx));
    // A notch: drawn in from the oval round it.
    expect(ParathyroidForm.depth(hilum), closeTo(0, 0.01));
  });

  test('it lies on the back of its lobe, its medial border between the gland '
      'and the nerve, just above where the artery crosses the nerve', () {
    final ParathyroidForm form = _form();
    // The whole gland on the lobe.
    final Path lobe = Path()..addPolygon(form.lobe, true);
    for (final Offset p in form.outlinePoints) {
      expect(lobe.contains(p), isTrue);
    }
    // The nerve medial to the lobe beside the gland, the gland lateral to
    // it.
    final TubeCourse nerve = form.nerve;
    final double nerveX =
        nerve.centres.map((Offset p) => p.dx).reduce(math.max) / form.scale;
    final double glandLeft = form.box.left / form.scale;
    expect(nerveX, lessThan(glandLeft));
    // The artery crosses the nerve below the gland, within a centimetre of
    // its lower pole.
    final TubeCourse artery = form.artery;
    Offset? crossing;
    for (int i = 0; i + 1 < artery.length; i++) {
      final Offset a = artery.centres[i];
      final Offset b = artery.centres[i + 1];
      for (int j = 0; j + 1 < nerve.length; j++) {
        final Offset c = nerve.centres[j];
        final Offset d = nerve.centres[j + 1];
        double turn(Offset p, Offset q, Offset r) =>
            (q.dx - p.dx) * (r.dy - p.dy) - (q.dy - p.dy) * (r.dx - p.dx);
        if (turn(c, d, a) * turn(c, d, b) < 0 &&
            turn(a, b, c) * turn(a, b, d) < 0) {
          crossing = (a + b) / 2;
        }
      }
    }
    expect(crossing, isNotNull);
    final double below = (crossing!.dy - form.box.bottom) / form.scale;
    expect(below, inInclusiveRange(0, 10));
    // Each shows where it crosses.
    expect(artery.shown.reduce(math.max), 1);
    expect(nerve.shown.reduce(math.max), 1);
  });

  test(
    'the gland’s own artery runs from the ascending branch to its hilum',
    () {
      final ParathyroidForm form = _form();
      final TubeCourse own = form.own;
      final TubeCourse ascending = form.ascending;
      final double fromBranch = ascending.centres
          .map((Offset p) => (p - own.centres.first).distance)
          .reduce(math.min);
      expect(fromBranch / form.scale, lessThan(0.6));
      final Offset hilum = form.place(ParathyroidForm.hilumMm);
      expect((own.centres.last - hilum).distance / form.scale, lessThan(0.3));
    },
  );

  test('its stromal fat is about a sixth of its cut face, as Dufour and '
      'Wilkerson found, none in a nodule, at the capsule or on the site', () {
    final List<Offset> fat = ParathyroidForm.fatMm;
    final double cells =
        fat.length * ParathyroidAnatomy.fatCell * ParathyroidAnatomy.fatCell;
    final double share = cells / _area(ParathyroidForm.outlineMm);
    expect(share, inInclusiveRange(0.12, 0.2));
    for (final Offset p in fat) {
      expect(ParathyroidForm.inGland(p), isTrue);
      expect(
        ParathyroidForm.depth(p),
        greaterThanOrEqualTo(ParathyroidStyle.rim),
      );
      expect(ParathyroidForm.inNodule(p), isFalse);
      expect((p - ParathyroidForm.siteMm).distance, greaterThan(0.25));
    }
  });

  test('the place the body goes in lies in the parenchyma, clear of the '
      'nodules, the fat and the capsule, and the names point at what they '
      'name', () {
    final ParathyroidForm form = _form();
    final Offset site = ParathyroidForm.siteMm;
    expect(ParathyroidForm.inGland(site), isTrue);
    expect(ParathyroidForm.depth(site), greaterThan(1));
    expect(ParathyroidForm.inNodule(site, margin: 0.3), isFalse);
    expect(form.contains(form.site), isTrue);
    expect(ParathyroidForm.inNodule(form.toMm(form.oxyphilName)), isTrue);
    expect(ParathyroidForm.inGland(form.toMm(form.fatName)), isTrue);
    final double nearestFat = ParathyroidForm.fatMm
        .map((Offset p) => (p - form.toMm(form.fatName)).distance)
        .reduce(math.min);
    expect(nearestFat, lessThan(0.2));
    expect(form.contains(form.thyroidName), isFalse);
    expect(form.lobeShown(form.thyroidName), greaterThan(0.8));
    expect(
      <ParathyroidHome, Offset>{
        for (final ParathyroidHome h in ParathyroidHome.values)
          h: _form(h).homeName,
      },
      <ParathyroidHome, Offset>{
        ParathyroidHome.chief: form.site,
        ParathyroidHome.oxyphil: form.oxyphilName,
        ParathyroidHome.fat: form.fatName,
      },
    );
  });

  test('the lobe shows whole about the gland and fades out above and below '
      'it and toward the view’s side', () {
    final ParathyroidForm form = _form();
    for (final Offset p in form.outlinePoints) {
      expect(form.lobeShown(p), greaterThan(0.99));
    }
    expect(ParathyroidForm.lobeShownAt(const Offset(0, -9)), 0);
    expect(ParathyroidForm.lobeShownAt(const Offset(0, 8)), 0);
    expect(ParathyroidForm.lobeShownAt(const Offset(9, 0)), 0);
  });

  test('where the zoom’s cell lives is by the Atlas’s name for it', () {
    expect(ParathyroidHome.of(null), ParathyroidHome.chief);
    expect(ParathyroidHome.of('Glandular cells'), ParathyroidHome.chief);
    expect(ParathyroidHome.of('Chief cells'), ParathyroidHome.chief);
    expect(ParathyroidHome.of('Oxyphil cells'), ParathyroidHome.oxyphil);
    expect(ParathyroidHome.of('Adipocytes'), ParathyroidHome.fat);
    expect(ParathyroidHome.chief.word, 'chief cells');
    expect(ParathyroidHome.oxyphil.word, 'oxyphil cells');
    expect(ParathyroidHome.fat.word, 'fat cells');
  });

  test('it is the same every time', () {
    final ParathyroidForm a = _form();
    final ParathyroidForm b = _form();
    expect(a.fat, b.fat);
    expect(a.outlinePoints, b.outlinePoints);
    expect(a.septa, b.septa);
    expect(a.vessels, b.vessels);
  });
}
