import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/features/zoom/domain/zoom_depth.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/organs/placenta/placenta_anatomy.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/organs/placenta/placenta_form.dart';

/// The block's view, framed by its width: the form is the same at any.
const double _width = PlacentaAnatomy.width * 1e-3;
const double _view = _width * ZoomDepth.organMargin;

PlacentaForm _form() => PlacentaForm(width: _width / _view, view: _view);

/// How far [p], a point of the front face, lies from the middle of the
/// central cavity of the lobule round [x], in the cavity's own half-width
/// and half-height: under 1 inside it.
double _inCavity(Offset p, double x) {
  final Offset c = PlacentaForm.cavityOf(x);
  return Offset(
    (p.dx - c.dx) / (PlacentaAnatomy.cavityWidth / 2),
    (p.dy - c.dy) / (PlacentaAnatomy.cavityHeight / 2),
  ).distance;
}

double _nearestCavity(Offset p) =>
    PlacentaAnatomy.lobules.map((double x) => _inCavity(p, x)).reduce(math.min);

bool _crosses(Offset a, Offset b, Offset c, Offset d) {
  double side(Offset p, Offset q, Offset r) =>
      (q.dx - p.dx) * (r.dy - p.dy) - (q.dy - p.dy) * (r.dx - p.dx);
  return side(a, b, c) * side(a, b, d) < 0 && side(c, d, a) * side(c, d, b) < 0;
}

void main() {
  test('the block is drawn at its real size: its front face 5 cm across, '
      'the placenta 4 cm thick in utero, on 7 mm of uterine muscle', () {
    final PlacentaForm form = _form();
    expect(form.mm(1), closeTo(1e-3 / _view, 1e-15));
    expect(
      (form.at(PlacentaAnatomy.width, 0) - form.at(0, 0)).distance,
      closeTo(form.mm(50), 1e-9),
    );
    // Ali et al. 2026: a median of 39.9 mm at 40 weeks.
    expect(PlacentaAnatomy.thickness, closeTo(39.9, 0.5));
    // Louwagie et al. 2021: about 6.3 to 6.9 mm at 34 weeks, thicker under
    // the placenta (Degani et al. 1998).
    expect(PlacentaAnatomy.myometrium, inInclusiveRange(6.3, 8));
    // Each layer under the one before, all the way across.
    for (double x = 0; x <= PlacentaAnatomy.width; x += 0.5) {
      expect(PlacentaForm.plateAt(x), lessThan(PlacentaForm.basalTopAt(x)));
      expect(
        PlacentaForm.basalTopAt(x),
        lessThan(PlacentaForm.basalFloorAt(x)),
      );
      expect(PlacentaForm.basalFloorAt(x), lessThan(PlacentaForm.deciduaAt(x)));
      expect(PlacentaForm.deciduaAt(x), lessThan(PlacentaAnatomy.faceDepth));
    }
  });

  test('the septa rise from the basal plate and never reach the chorionic '
      'plate, each to a point', () {
    final PlacentaForm form = _form();
    expect(form.septaPoints, hasLength(PlacentaAnatomy.septa.length));
    for (final List<Offset> septum in form.septaPoints) {
      final List<Offset> mm = <Offset>[
        for (final Offset p in septum) form.toMm(p),
      ];
      final double top = mm.map((Offset p) => p.dy).reduce(math.min);
      final double foot = mm.map((Offset p) => p.dy).reduce(math.max);
      final Offset tip = mm.firstWhere((Offset p) => p.dy == top);
      expect(foot, greaterThan(PlacentaForm.basalTopAt(mm.first.dx)));
      expect(top, greaterThan(PlacentaForm.plateAt(tip.dx) + 5));
      // A point: no breadth at its tip.
      final List<Offset> near = <Offset>[
        for (final Offset p in mm)
          if (p.dy < top + 0.2) p,
      ];
      final double breadth =
          near.map((Offset p) => p.dx).reduce(math.max) -
          near.map((Offset p) => p.dx).reduce(math.min);
      expect(breadth, lessThan(0.2));
    }
  });

  test('each lobule is a villous tree hung from the chorionic plate round '
      'a central cavity no villus enters, some of its branches anchored on '
      'the basal plate; its villi lie in the intervillous space', () {
    final PlacentaForm form = _form();
    final List<PlacentaBranch> stems = <PlacentaBranch>[
      for (final PlacentaBranch b in form.branches)
        if (b.order == 0) b,
    ];
    expect(stems, hasLength(PlacentaAnatomy.lobules.length));
    for (final PlacentaBranch stem in stems) {
      final Offset from = stem.points.first;
      expect(from.dy, closeTo(PlacentaForm.plateAt(from.dx), 1e-9));
      expect(stem.widths.first, PlacentaAnatomy.trunk);
    }
    // Every branch but the stems grows from the end of another.
    final Set<Offset> ends = <Offset>{
      for (final PlacentaBranch b in form.branches) b.points.last,
    };
    for (final PlacentaBranch b in form.branches) {
      if (b.order > 0) {
        expect(ends.contains(b.points.first), isTrue);
      }
      for (final Offset p in b.points) {
        expect(_nearestCavity(p), greaterThan(0.999), reason: '$p');
        expect(p.dy, lessThanOrEqualTo(PlacentaForm.basalTopAt(p.dx) + 1e-9));
      }
      for (final double w in b.widths) {
        expect(w, inInclusiveRange(PlacentaAnatomy.twig - 1e-9, 2.4));
      }
    }
    // Anchoring villi in both lobules.
    for (final double x in PlacentaAnatomy.lobules) {
      expect(
        form.branches.where((PlacentaBranch b) {
          final Offset end = b.points.last;
          return (end.dx - x).abs() < 12 &&
              end.dy >= PlacentaForm.basalTopAt(end.dx) - b.widths.last;
        }),
        isNotEmpty,
        reason: 'lobule at $x',
      );
    }
    int count = 0;
    for (final PlacentaClumps c in form.clumps) {
      final Float32List xy = c.points;
      for (int i = 0; i + 1 < xy.length; i += 2) {
        final Offset p = form.toMm(Offset(xy[i], xy[i + 1]));
        expect(_nearestCavity(p), greaterThanOrEqualTo(0.85), reason: '$p');
        expect(p.dy, greaterThan(PlacentaForm.plateAt(p.dx)));
        expect(p.dy, lessThan(PlacentaForm.basalTopAt(p.dx)));
        count++;
      }
    }
    expect(count, greaterThan(1000));
  });

  test('a spiral artery coils up through the decidua into each lobule, '
      'its funnel opening through the basal plate under the central cavity, '
      '0.45 mm wide below it and 2.4 mm at its mouth', () {
    final PlacentaForm form = _form();
    expect(PlacentaAnatomy.spiral, inInclusiveRange(0.4, 0.5));
    expect(PlacentaAnatomy.mouth, 2.4);
    for (int k = 0; k < PlacentaAnatomy.lobules.length; k++) {
      final double x = PlacentaAnatomy.lobules[k];
      final Rect funnel = form.funnels[k].getBounds();
      final Offset top = form.toMm(funnel.topCenter);
      expect(top.dx, closeTo(x, 0.05));
      expect(top.dy, closeTo(PlacentaForm.basalTopAt(x) - 0.15, 0.05));
      expect(funnel.width, closeTo(form.mm(PlacentaAnatomy.mouth), 1e-6));
      // It coils below its funnel, and reaches the face's foot.
      final List<Offset> line = <Offset>[
        for (final Offset p in form.spirals[k]) form.toMm(p),
      ];
      expect(line.first.dy, greaterThan(PlacentaAnatomy.faceDepth));
      expect(
        line.map((Offset p) => (p.dx - x).abs()).reduce(math.max),
        closeTo(PlacentaAnatomy.coilSwing, 0.1),
      );
    }
  });

  test('the chorionic vessels radiate from the cord, each artery crossing '
      'over its vein; the cord is 15.4 mm across, its vein and its two '
      'arteries in it', () {
    final List<List<Offset>> veins = <List<Offset>>[
      for (final (List<Offset> c, bool vein) in PlacentaAnatomy.chorionic)
        if (vein) c,
    ];
    final List<List<Offset>> arteries = <List<Offset>>[
      for (final (List<Offset> c, bool vein) in PlacentaAnatomy.chorionic)
        if (!vein) c,
    ];
    expect(veins, hasLength(arteries.length));
    for (int k = 0; k < veins.length; k++) {
      int crossings = 0;
      for (int i = 0; i + 1 < veins[k].length; i++) {
        for (int j = 0; j + 1 < arteries[k].length; j++) {
          if (_crosses(
            veins[k][i],
            veins[k][i + 1],
            arteries[k][j],
            arteries[k][j + 1],
          )) {
            crossings++;
          }
        }
      }
      expect(crossings, greaterThan(0), reason: 'pair $k');
      // From beside the cord's root, out to the block's edge.
      for (final List<Offset> c in <List<Offset>>[veins[k], arteries[k]]) {
        expect(
          (c.first - PlacentaAnatomy.cordRoot).distance,
          lessThan(PlacentaAnatomy.cord / 2),
        );
        expect(c.last.dy == 0 || c.last.dy == PlacentaAnatomy.depth, isTrue);
      }
    }
    expect(
      PlacentaAnatomy.chorionicVein,
      greaterThan(PlacentaAnatomy.chorionicArtery),
    );
    // Rostamzadeh et al. 2015: 186.4, 52.1 and 15.5 square millimetres.
    double across(double area) => 2 * math.sqrt(area / math.pi);
    expect(PlacentaAnatomy.cord, closeTo(across(186.4), 0.05));
    expect(PlacentaAnatomy.cordVein, closeTo(across(52.1), 0.05));
    expect(PlacentaAnatomy.cordArtery, closeTo(across(15.5), 0.05));
    final PlacentaForm form = _form();
    final Path end = form.cordEnd;
    final List<Path> vessels = form.cordVessels(1);
    expect(vessels, hasLength(3));
    for (final Path v in vessels) {
      for (final Offset p in <Offset>[
        v.getBounds().centerLeft,
        v.getBounds().centerRight,
      ]) {
        expect(end.contains(p), isTrue);
      }
    }
  });

  test('the zoom goes in through the villi of the left lobule, inside the '
      'block, clear of its central cavity', () {
    final PlacentaForm form = _form();
    expect(form.outline.contains(form.site), isTrue);
    final Offset site = form.toMm(form.site);
    expect(site.dy, greaterThan(PlacentaForm.plateAt(site.dx)));
    expect(site.dy, lessThan(PlacentaForm.basalTopAt(site.dx)));
    expect(site.dx, lessThan(PlacentaAnatomy.septa[1].$1));
    expect(_nearestCavity(site), greaterThan(1));
  });

  test('a name’s column stands clear of all that is drawn at its height', () {
    final PlacentaForm form = _form();
    for (final Offset p in form.outlinePoints) {
      final double y = form.toMm(p).dy;
      final (Offset left, Offset right) = form.edgesAt(y);
      expect(p.dx, greaterThanOrEqualTo(left.dx - form.mm(0.3)), reason: '$y');
      expect(p.dx, lessThanOrEqualTo(right.dx + form.mm(0.3)), reason: '$y');
    }
  });

  test('the home is told by the Atlas’s name for the cell', () {
    expect(PlacentaHome.of('Syncytiotrophoblasts'), PlacentaHome.villi);
    expect(PlacentaHome.of('Cytotrophoblasts'), PlacentaHome.villi);
    expect(PlacentaHome.of('Hofbauer cells'), PlacentaHome.villi);
    expect(PlacentaHome.of('Decidual stromal cells'), PlacentaHome.decidua);
    expect(PlacentaHome.of('Extravillous trophoblasts'), PlacentaHome.decidua);
    expect(PlacentaHome.of(null), PlacentaHome.villi);
  });
}
