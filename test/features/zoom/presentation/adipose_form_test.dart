import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/features/zoom/domain/zoom_depth.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/organs/adipose/adipose_anatomy.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/organs/adipose/adipose_form.dart';

/// The block's view, framed by its width: the form is the same at any.
const double _width = AdiposeAnatomy.width * 1e-3;
const double _view = _width * ZoomDepth.organMargin;

AdiposeForm _form() => AdiposeForm(width: _width / _view, view: _view);

/// Each cell's outline in the face's millimetres, those whose middle lies
/// in the band from [from] to [to] down the face and inside it across.
List<List<Offset>> _cellsIn(
  AdiposeForm form,
  List<List<Offset>> cells,
  double from,
  double to,
) =>
    <List<Offset>>[
      for (final List<Offset> cell in cells)
        if (cell.length > 2)
          () {
            final List<Offset> mm = <Offset>[
              for (final Offset p in cell) form.toMm(p),
            ];
            return mm;
          }(),
    ].where((List<Offset> mm) {
      final Offset c =
          mm.reduce((Offset a, Offset b) => a + b) / mm.length.toDouble();
      return c.dy > from &&
          c.dy < to &&
          c.dx > 3 &&
          c.dx < AdiposeAnatomy.width - 3;
    }).toList();

double _area(List<Offset> p) {
  double sum = 0;
  for (int i = 0; i < p.length; i++) {
    final Offset a = p[i];
    final Offset b = p[(i + 1) % p.length];
    sum += a.dx * b.dy - b.dx * a.dy;
  }
  return sum.abs() / 2;
}

double _perimeter(List<Offset> p) {
  double sum = 0;
  for (int i = 0; i < p.length; i++) {
    sum += (p[(i + 1) % p.length] - p[i]).distance;
  }
  return sum;
}

/// How round a cell is: 1 for a circle.
double _circularity(List<Offset> p) =>
    4 * math.pi * _area(p) / math.pow(_perimeter(p), 2);

/// How far a cell's edges run up and down rather than across, their
/// lengths weighed.
double _upright(List<Offset> p) {
  double up = 0;
  double all = 0;
  for (int i = 0; i < p.length; i++) {
    final Offset d = p[(i + 1) % p.length] - p[i];
    up += d.dy.abs();
    all += d.distance;
  }
  return up / all;
}

double _mean(Iterable<double> values) =>
    values.reduce((double a, double b) => a + b) / values.length;

void main() {
  test('the block is drawn at its real size: its front face 4 cm across, '
      'the skin and the fat as thick as they are measured, the rectus cut '
      'short', () {
    final AdiposeForm form = _form();
    expect(form.mm(1), closeTo(1e-3 / _view, 1e-15));
    expect(
      (form.at(AdiposeAnatomy.width, 0) - form.at(0, 0)).distance,
      closeTo(form.mm(40), 1e-9),
    );
    // Sim et al. 2014; Annunziata et al. 2025.
    expect(AdiposeAnatomy.skin, 2.29);
    expect(AdiposeAnatomy.fat, 17.48);
    expect(AdiposeAnatomy.superficial, 8.18);
    expect(
      AdiposeAnatomy.deepEnd - AdiposeAnatomy.skin,
      closeTo(AdiposeAnatomy.fat, 1e-9),
    );
    // Between the two measures of the membranous layer, 391 and 847 µm.
    expect(AdiposeAnatomy.membranous, inInclusiveRange(0.391, 0.847));
    // Under half the rectus, 14.75 to 16.06 mm thick.
    expect(AdiposeAnatomy.rectus, lessThan(14.75 / 2));
    for (double x = 0; x <= AdiposeAnatomy.width; x += 0.5) {
      expect(AdiposeForm.skinAt(x), lessThan(AdiposeForm.superficialAt(x)));
      expect(
        AdiposeForm.superficialAt(x),
        lessThan(AdiposeForm.membranousAt(x)),
      );
      expect(AdiposeForm.membranousAt(x), lessThan(AdiposeForm.deepAt(x)));
      expect(AdiposeForm.rectusAt(x), lessThan(AdiposeAnatomy.faceDepth));
    }
  });

  test('the superficial fat’s lobes are small, round and parted by upright '
      'septa; the deep fat’s wide and flat, parted by septa that run '
      'across and lean (Lancerotto et al. 2011)', () {
    final AdiposeForm form = _form();
    final List<List<Offset>> superficial = _cellsIn(
      form,
      form.superficialLobes,
      AdiposeAnatomy.skin,
      AdiposeAnatomy.superficialEnd,
    );
    final List<List<Offset>> deep = _cellsIn(
      form,
      form.deepLobes,
      AdiposeAnatomy.membranousEnd,
      AdiposeAnatomy.deepEnd,
    );
    expect(superficial.length, greaterThan(10));
    expect(deep.length, greaterThan(3));
    final double round = _mean(superficial.map(_circularity));
    final double flat = _mean(deep.map(_circularity));
    // Lancerotto's 0.856 and 0.473.
    expect(round, greaterThan(0.75));
    expect(flat, lessThan(0.65));
    expect(round - flat, greaterThan(0.15));
    expect(
      _mean(superficial.map(_upright)),
      greaterThan(_mean(deep.map(_upright)) + 0.15),
    );
    for (final List<Offset> lobe in deep) {
      final Rect box = (Path()..addPolygon(lobe, true)).getBounds();
      expect(box.width, greaterThan(1.8 * box.height));
    }
  });

  test('the superficial epigastric artery and vein lie in the superficial '
      'fat, the vein the wider; a perforator rises from the rectus through '
      'its sheath and both layers of fat to the skin', () {
    final AdiposeForm form = _form();
    for (final (Offset c, double r) in <(Offset, double)>[
      form.epigastricArtery,
      form.epigastricVein,
    ]) {
      final Offset mm = form.toMm(c);
      final double radius = r / form.scale;
      expect(mm.dy - radius, greaterThan(AdiposeForm.skinAt(mm.dx)));
      expect(mm.dy + radius, lessThan(AdiposeForm.superficialAt(mm.dx)));
    }
    expect(form.epigastricVein.$2, greaterThan(form.epigastricArtery.$2));
    for (final List<Offset> vessel in <List<Offset>>[
      form.perforatorArtery,
      form.perforatorVein,
    ]) {
      final Offset from = form.toMm(vessel.first);
      final Offset to = form.toMm(vessel.last);
      expect(from.dy, greaterThan(AdiposeForm.rectusAt(from.dx)));
      expect(to.dy, lessThan(AdiposeForm.skinAt(to.dx) + 0.5));
      expect(to.dy, greaterThan(AdiposeForm.skinAt(to.dx)));
    }
  });

  test('the zoom goes into the superficial fat, inside the block', () {
    final AdiposeForm form = _form();
    expect(form.outline.contains(form.site), isTrue);
    final Offset site = form.toMm(form.site);
    expect(site.dy, greaterThan(AdiposeForm.skinAt(site.dx)));
    expect(site.dy, lessThan(AdiposeForm.superficialAt(site.dx)));
  });

  test('a name’s column stands clear of all that is drawn at its height', () {
    final AdiposeForm form = _form();
    for (final Offset p in form.outlinePoints) {
      final double y = form.toMm(p).dy;
      final (Offset left, Offset right) = form.edgesAt(y);
      expect(p.dx, greaterThanOrEqualTo(left.dx - 1e-9), reason: '$y');
      expect(p.dx, lessThanOrEqualTo(right.dx + 1e-9), reason: '$y');
    }
  });
}
