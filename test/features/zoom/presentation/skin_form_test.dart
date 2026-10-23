import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/organs/skin/skin_anatomy.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/organs/skin/skin_form.dart';

/// The scene's unit, in metres: about the organ stop's.
const double _view = 0.01;

SkinForm _form() =>
    SkinForm(width: SkinAnatomy.width * 1e-3 / _view, view: _view);

/// How far [p] lies from the segment from [a] to [b].
double _toSegment(Offset p, Offset a, Offset b) {
  final Offset ab = b - a;
  final double length = ab.dx * ab.dx + ab.dy * ab.dy;
  final double t = length == 0
      ? 0
      : (((p - a).dx * ab.dx + (p - a).dy * ab.dy) / length).clamp(0.0, 1.0);
  return (p - (a + ab * t)).distance;
}

/// Points along a path's outline, every [step] of its length.
List<Offset> _along(Path path, double step) => <Offset>[
  for (final PathMetric m in path.computeMetrics())
    for (double s = 0; s < m.length; s += step)
      m.getTangentForOffset(s)!.position,
];

void main() {
  test('the block is cut 3 mm across, its front face as deep as the skin '
      'and the fat it keeps; the skin 1.83 mm thick, as on the left calf', () {
    final SkinForm form = _form();
    expect(form.mm(1), closeTo(1e-3 / _view, 1e-12));
    expect(SkinAnatomy.width, 3);
    expect(SkinAnatomy.skin, 1.83);
    expect(SkinAnatomy.faceDepth, SkinAnatomy.skin + SkinAnatomy.fat);
    final Rect front = form.front.getBounds();
    expect(front.width, closeTo(form.mm(SkinAnatomy.width), 1e-6));
    expect(front.height, closeTo(form.mm(SkinAnatomy.faceDepth), 1e-6));
  });

  test('the epidermis lies on its ridges over the papillary dermis, the '
      'reticular dermis under that, and the fat under the dermis, all the '
      'way across', () {
    for (double x = 0; x <= SkinAnatomy.width; x += 0.01) {
      final double floor = SkinForm.floorAt(x);
      expect(
        (floor - SkinAnatomy.epidermis).abs(),
        lessThanOrEqualTo(SkinAnatomy.ridgeDepth),
        reason: 'at $x',
      );
      expect(floor, greaterThan(SkinAnatomy.corneum), reason: 'at $x');
      expect(SkinForm.papillaryAt(x), greaterThan(floor + 0.1), reason: '$x');
      expect(
        SkinForm.dermisAt(x),
        greaterThan(SkinForm.papillaryAt(x) + 1),
        reason: 'at $x',
      );
      expect(
        (SkinForm.dermisAt(x) - SkinAnatomy.skin).abs(),
        lessThan(0.08),
        reason: 'at $x',
      );
    }
  });

  test('the follicle slants down from its opening to its bulb, which lies '
      'just into the fat, its papilla under it', () {
    final Offset bulb = SkinForm.follicleAt(SkinForm.bulbAlong);
    expect(bulb.dy, closeTo(SkinAnatomy.bulbDepth, 1e-9));
    expect(bulb.dy, greaterThan(SkinForm.dermisAt(bulb.dx)));
    expect(
      math.atan2(SkinForm.down.dy, -SkinForm.down.dx) * 180 / math.pi,
      closeTo(SkinAnatomy.slope, 1e-9),
    );
    expect(bulb.dx, greaterThan(0));
    expect(bulb.dx, lessThan(SkinAnatomy.opening));
    // Widest at its bulb, as broad as it is down its length, and wider
    // again in the funnel it opens by.
    expect(
      SkinForm.follicleHalf(SkinForm.bulbAlong),
      closeTo(SkinAnatomy.bulbBreadth / 2, 1e-9),
    );
    expect(
      SkinForm.follicleHalf(1),
      closeTo(SkinAnatomy.follicleBreadth / 2, 1e-9),
    );
    expect(
      SkinForm.follicleHalf(0),
      closeTo(SkinAnatomy.funnelWidth / 2, 1e-9),
    );
    expect(SkinForm.follicleHalf(SkinForm.follicleEnd + 0.01), 0);
  });

  test('the arrector pili arises in the papillary dermis on the side the '
      'hair slopes toward and is inserted below the sebaceous duct, the '
      'gland in the angle between it and the follicle (Gray)', () {
    const Offset o = SkinAnatomy.origin;
    expect(o.dy, greaterThan(SkinForm.floorAt(o.dx)));
    expect(o.dy, lessThan(SkinForm.papillaryAt(o.dx)));
    // On the slope's side of the follicle.
    final Offset fromOpening = o - const Offset(SkinAnatomy.opening, 0);
    expect(
      fromOpening.dx * SkinForm.toward.dx + fromOpening.dy * SkinForm.toward.dy,
      greaterThan(0),
    );
    expect(SkinAnatomy.insertionAlong, greaterThan(SkinAnatomy.ductAlong));
    for (final (double along, double _) in SkinAnatomy.alveoli) {
      expect(SkinAnatomy.insertionAlong, greaterThan(along));
    }
    for (final (Offset c, double r) in SkinForm.alveoli) {
      expect(r, greaterThan(0.05));
      // Clear of the muscle and of the follicle's sheaths.
      expect(
        _toSegment(c, o, SkinForm.insertion),
        greaterThan(r + SkinAnatomy.muscleInsertion / 2),
        reason: '$c',
      );
      final Offset fromAxis = c - const Offset(SkinAnatomy.opening, 0);
      final double across =
          fromAxis.dx * SkinForm.toward.dx + fromAxis.dy * SkinForm.toward.dy;
      expect(across, greaterThan(SkinAnatomy.follicleBreadth / 2 + r));
      // Above the muscle: between it and the follicle's superficial part.
      final double side =
          (SkinForm.insertion - o).dx * (c - o).dy -
          (SkinForm.insertion - o).dy * (c - o).dx;
      expect(side, greaterThan(0), reason: '$c');
    }
  });

  test('one sweat gland coils under the dermis and one in the fat, each '
      'duct rising to its pore on the surface, neither crossing the '
      'follicle', () {
    final SkinForm form = _form();
    final (Offset deep, double _, double _, double _) = SkinAnatomy.coils[0];
    final (Offset fat, double _, double _, double _) = SkinAnatomy.coils[1];
    expect(deep.dy, lessThan(SkinForm.dermisAt(deep.dx)));
    expect(deep.dy, greaterThan(SkinAnatomy.upperPlexus));
    expect(fat.dy, greaterThan(SkinForm.dermisAt(fat.dx)));
    for (int k = 0; k < form.coils.length; k++) {
      final SkinCoil coil = form.coils[k];
      final (Offset c, double _, double h, double pore) = SkinAnatomy.coils[k];
      final Offset top = form.toMm(coil.duct.first);
      final Offset end = form.toMm(coil.duct.last);
      expect(top.dy, closeTo(c.dy - h / 2, 1e-6));
      expect(end.dy, closeTo(0, 1e-6));
      expect(end.dx, closeTo(pore, 1e-6));
      for (final Offset p in coil.duct) {
        expect(form.follicle.contains(p), isFalse, reason: 'coil $k at $p');
      }
    }
  });

  test('the vessels lie in two plexuses, the upper 1 to 1.5 mm under the '
      'surface and the lower where the dermis meets the fat (Braverman)', () {
    expect(SkinAnatomy.upperPlexus, inInclusiveRange(1, 1.5));
    final SkinForm form = _form();
    final int upper = SkinAnatomy.upperVessels.length;
    final int lower = SkinAnatomy.lowerVessels.length;
    for (int i = 0; i < upper + lower; i++) {
      final Offset p = form.toMm(form.vessels[i].$1);
      expect(
        p.dy,
        closeTo(
          i < upper ? SkinAnatomy.upperPlexus : SkinForm.dermisAt(p.dx),
          1e-6,
        ),
        reason: '$i',
      );
      expect(form.follicle.contains(form.vessels[i].$1), isFalse);
    }
  });

  test('its tissue is sampled in the epidermis of the front face, clear of '
      'the follicle, inside the block', () {
    final SkinForm form = _form();
    final Offset site = form.toMm(form.site);
    expect(site.dy, greaterThan(SkinAnatomy.corneum));
    expect(site.dy, lessThan(SkinForm.floorAt(site.dx)));
    expect(form.front.contains(form.site), isTrue);
    expect(form.outline.contains(form.site), isTrue);
    double nearest = double.infinity;
    for (final Offset p in form.folliclePoints) {
      nearest = math.min(nearest, (p - form.site).distance);
    }
    expect(nearest, greaterThan(form.mm(0.5)));
  });

  test('everything on the cut lies in its front face, the hairs leave the '
      'surface at the follicles\' openings, and every name points into the '
      'block', () {
    final SkinForm form = _form();
    final Path front = form.front;
    final Rect face = front.getBounds().inflate(form.mm(0.002));
    for (final Path part in <Path>[
      form.gland,
      form.muscle,
      form.other,
      form.arteriole,
      form.venule,
      for (final SkinCoil coil in form.coils) coil.ball,
    ]) {
      for (final Offset p in _along(part, form.mm(0.02))) {
        expect(face.contains(p), isTrue, reason: '$p');
      }
    }
    for (int i = 0; i < form.hairs.length; i++) {
      expect(
        (form.hairs[i].points.first - form.openings[i]).distance,
        lessThan(form.mm(1e-6)),
      );
    }
    for (final Offset name in <Offset>[
      form.basalName,
      form.epidermisSiteName,
      form.epidermisName,
      form.dermisName,
      form.dermisSiteName,
      form.fatName,
      form.muscleName,
      form.glandName,
      form.follicleName,
      form.sweatName,
    ]) {
      expect(form.outline.contains(name), isTrue, reason: '$name');
    }
  });

  test('the block\'s outermost points at a height are where its outline '
      'crosses that height', () {
    final SkinForm form = _form();
    final List<Offset> outline = form.outlinePoints;
    for (double y = -0.8; y < SkinAnatomy.faceDepth; y += 0.1) {
      final double at = form.place(Offset(0, y)).dy;
      final List<double> crossings = <double>[
        for (int i = 0; i < outline.length; i++)
          if ((outline[i].dy > at) !=
              (outline[(i + 1) % outline.length].dy > at))
            outline[i].dx +
                (at - outline[i].dy) *
                    (outline[(i + 1) % outline.length].dx - outline[i].dx) /
                    (outline[(i + 1) % outline.length].dy - outline[i].dy),
      ]..sort();
      final (Offset left, Offset right) = form.edgesAt(y);
      expect(left.dx, closeTo(crossings.first, 1e-9), reason: 'at $y');
      expect(right.dx, closeTo(crossings.last, 1e-9), reason: 'at $y');
    }
  });

  test('a cell is homed by the name the Atlas gives it', () {
    const Map<String?, SkinHome> homes = <String?, SkinHome>{
      'Melanocytes': SkinHome.melanocytes,
      'Basal keratinocytes': SkinHome.basalLayer,
      'Suprabasal keratinocytes': SkinHome.epidermis,
      'Keratinocyte': SkinHome.epidermis,
      'Langerhans cells': SkinHome.epidermis,
      'Hair cortex cells': SkinHome.follicle,
      'Inner root sheath cells': SkinHome.follicle,
      'Outer root sheath cells': SkinHome.follicle,
      'Sebaceous gland cells': SkinHome.sebaceousGland,
      'Eccrine sweat gland cells': SkinHome.sweatGland,
      'Fibroblasts': SkinHome.dermis,
      'Endothelial cells': SkinHome.dermis,
      null: SkinHome.dermis,
    };
    for (final MapEntry<String?, SkinHome> e in homes.entries) {
      expect(SkinHome.of(e.key), e.value, reason: '${e.key}');
    }
  });
}
