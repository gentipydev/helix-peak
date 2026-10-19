import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/features/zoom/domain/anatomy_tables.dart';
import 'package:helixpeek/features/zoom/domain/zoom_depth.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/brain/brain_anatomy.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/brain/brain_form.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/contour.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/tube_course.dart';

final TissueAnatomy _anatomy = tissueAnatomy['brain']!;
final double _view = _anatomy.metres * ZoomDepth.organMargin;

BrainForm _form() => BrainForm(length: _anatomy.metres / _view, view: _view);

/// The anatomical fiducials raters placed on the MNI152 2009c average
/// brain (Lau et al. 2019, Hum Brain Mapp 40:4163; the AFIDs data, CC BY
/// 4.0), in the drawing's frame: millimetres from the anterior commissure,
/// x back, y down.
const Offset _pc = Offset(28.0, -2.9);
const Offset _genu = Offset(-30.4, -6.8);
const Offset _splenium = Offset(40.5, -10.9);
const Offset _pineal = Offset(34.5, -5.3);
const Offset _infracollicular = Offset(40.8, 7.4);
const Offset _interpeduncular = Offset(16.5, 6.5);
const Offset _intermammillary = Offset(11.2, 11.4);
const Offset _pontomesencephalic = Offset(26.5, 16.6);
const Offset _culmen = Offset(55.6, -6.7);

/// An outline of the anatomy, as the form follows it, in millimetres.
List<Offset> _dense(List<Offset> points) => Contour(points).sampled(6).points;

/// Points along [path] every [step] of the scene's units.
List<Offset> _along(Path path, double step) => <Offset>[
  for (final PathMetric metric in path.computeMetrics())
    for (double d = 0; d < metric.length; d += step)
      metric.getTangentForOffset(d)!.position,
];

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

/// Where a closed outline crosses the line at [at] across or down, sorted.
List<double> _crossings(List<Offset> points, double at, {bool down = false}) {
  final List<double> out = <double>[];
  final int n = points.length;
  for (int i = 0; i < n; i++) {
    final Offset a = points[i];
    final Offset b = points[(i + 1) % n];
    final double ua = down ? a.dx : a.dy;
    final double ub = down ? b.dx : b.dy;
    if ((ua <= at) != (ub <= at)) {
      final double t = (at - ua) / (ub - ua);
      out.add(down ? a.dy + (b.dy - a.dy) * t : a.dx + (b.dx - a.dx) * t);
    }
  }
  return out..sort();
}

void main() {
  test('the brain is 17 cm from pole to pole, its middle at the origin', () {
    final BrainForm form = _form();
    expect(
      form.hemisphere.getBounds().width,
      closeTo(_anatomy.metres / _view, form.mm(0.3)),
    );
    expect(form.outline.getBounds().center.distance, lessThan(form.mm(1)));
  });

  test('the measured landmarks land on what the drawing names them by', () {
    final BrainForm form = _form();
    final List<Offset> callosum = <Offset>[
      for (final Offset p in _along(form.callosum, form.mm(0.2))) form.toMm(p),
    ];
    // The genu's most anterior point, and the splenium's lowest.
    final Offset front = callosum.reduce(
      (Offset a, Offset b) => a.dx <= b.dx ? a : b,
    );
    expect((front - _genu).distance, lessThan(1.5));
    final Offset foot = callosum
        .where((Offset p) => p.dx > 30)
        .reduce((Offset a, Offset b) => a.dy >= b.dy ? a : b);
    expect((foot - _splenium).distance, lessThan(1.5));
    // The culmen, the vermis's top.
    final Offset top = <Offset>[
      for (final Offset p in _along(form.vermis, form.mm(0.2))) form.toMm(p),
    ].reduce((Offset a, Offset b) => a.dy <= b.dy ? a : b);
    expect((top - _culmen).distance, lessThan(1.5));
    // The pineal in the pineal; the commissures in theirs.
    expect(form.pineal.contains(form.place(_pineal)), isTrue);
    expect(form.posteriorCommissure.contains(form.place(_pc)), isTrue);
    expect(form.anteriorCommissure.contains(form.place(Offset.zero)), isTrue);
    // The brainstem's edge by the colliculi's foot, the interpeduncular
    // fossa and the pontomesencephalic junction.
    final List<Offset> brainstem = _dense(BrainAnatomy.brainstem);
    for (final Offset fiducial in <Offset>[
      _infracollicular,
      _interpeduncular,
      _pontomesencephalic,
    ]) {
      expect(
        _toLine(brainstem, fiducial, closed: true),
        lessThan(1.5),
        reason: '$fiducial',
      );
    }
    // The intermammillary sulcus at the mammillary body's foot.
    const Rect mammillary = BrainAnatomy.mammillary;
    final List<Offset> rim = <Offset>[
      for (int k = 0; k < 64; k++)
        mammillary.center +
            Offset(
              math.cos(2 * math.pi * k / 64) * mammillary.width / 2,
              math.sin(2 * math.pi * k / 64) * mammillary.height / 2,
            ),
    ];
    expect(_toLine(rim, _intermammillary, closed: true), lessThan(1.5));
  });

  test('its parts are the sizes MRI measures', () {
    final List<Offset> callosum = _dense(BrainAnatomy.callosum);
    double extent(List<double> crossings) => crossings.last - crossings.first;
    // The corpus callosum: 72-76 mm long, its genu and splenium about
    // 11 mm thick and its body about 6.
    final double length =
        callosum.map((Offset p) => p.dx).reduce(math.max) -
        callosum.map((Offset p) => p.dx).reduce(math.min);
    expect(length, inInclusiveRange(70, 80));
    expect(extent(_crossings(callosum, 8, down: true)), inInclusiveRange(4, 8));
    final List<double> genu = _crossings(
      callosum,
      -11,
    ).where((double x) => x < 0).toList();
    expect(genu[1] - genu[0], inInclusiveRange(8, 14));
    final List<double> splenium = _crossings(
      callosum,
      -20,
    ).where((double x) => x > 30).toList();
    expect(splenium.last - splenium.first, inInclusiveRange(8, 14));
    // The pons about 23 mm deep, the medulla about 13 (Singh et al.
    // 2019).
    final List<Offset> brainstem = _dense(BrainAnatomy.brainstem);
    expect(extent(_crossings(brainstem, 30)), inInclusiveRange(20, 26));
    expect(extent(_crossings(brainstem, 55)), inInclusiveRange(11, 15));
    // The pituitary some 6-8 mm tall and 9-11 long.
    final List<Offset> pituitary = <Offset>[
      ..._dense(BrainAnatomy.pituitaryAnterior),
      ..._dense(BrainAnatomy.pituitaryPosterior),
    ];
    final double tall =
        pituitary.map((Offset p) => p.dy).reduce(math.max) -
        pituitary.map((Offset p) => p.dy).reduce(math.min);
    final double long =
        pituitary.map((Offset p) => p.dx).reduce(math.max) -
        pituitary.map((Offset p) => p.dx).reduce(math.min);
    expect(tall, inInclusiveRange(5, 8.5));
    expect(long, inInclusiveRange(8, 12.5));
  });

  test('the core lies in the hemisphere, and the sulci on its face clear of '
      'the core', () {
    final List<Offset> hemisphere = _dense(BrainAnatomy.hemisphere);
    for (final List<Offset> part in <List<Offset>>[
      BrainAnatomy.callosum,
      BrainAnatomy.septum,
      BrainAnatomy.thalamus,
      BrainAnatomy.hypothalamus,
      BrainAnatomy.pineal,
      BrainAnatomy.fornix,
    ]) {
      for (final Offset p in part) {
        expect(_inside(hemisphere, p), isTrue, reason: '$p');
      }
    }
    final List<List<Offset>> core = <List<Offset>>[
      _dense(BrainAnatomy.deep),
      _dense(BrainAnatomy.callosum),
      _dense(BrainAnatomy.brainstem),
      _dense(BrainAnatomy.vermis),
    ];
    for (final BrainSulcus sulcus in BrainAnatomy.sulci) {
      for (final Offset p in sulcus.points) {
        final String where = '${sulcus.name} at $p';
        expect(_inside(hemisphere, p), isTrue, reason: where);
        for (final List<Offset> part in core) {
          expect(_inside(part, p), isFalse, reason: where);
        }
      }
    }
  });

  test('the cortex is sampled on a gyrus, clear of every sulcus; the choroid '
      'plexus on the plexus, in the window onto the ventricle', () {
    final List<Offset> hemisphere = _dense(BrainAnatomy.hemisphere);
    const Offset cortex = BrainAnatomy.cortexSite;
    expect(_inside(hemisphere, cortex), isTrue);
    expect(_inside(_dense(BrainAnatomy.deep), cortex), isFalse);
    for (final BrainSulcus sulcus in BrainAnatomy.sulci) {
      expect(
        _toLine(sulcus.points, cortex),
        greaterThan(3),
        reason: sulcus.name,
      );
    }
    final BrainForm form = _form();
    expect(form.window.contains(form.place(BrainAnatomy.plexusSite)), isTrue);
    expect(
      _toLine(BrainAnatomy.lateralPlexus, BrainAnatomy.plexusSite),
      lessThan(1.5),
    );
  });

  test('the arteries run in their sulci and on the pons', () {
    List<Offset> sulcus(String name) =>
        BrainAnatomy.sulci.firstWhere((BrainSulcus s) => s.name == name).points;
    void runs(
      AnatomyTube artery,
      List<Offset> along,
      double within, {
      int from = 0,
      int? to,
    }) {
      final List<Offset> course = artery.points.sublist(
        from,
        to ?? artery.points.length,
      );
      for (final Offset p in course) {
        expect(_toLine(_dense(along), p), lessThan(within), reason: '$p');
      }
    }

    runs(BrainAnatomy.pericallosal, sulcus('callosal'), 2.5, to: 13);
    runs(BrainAnatomy.callosomarginal, sulcus('cingulate'), 2.5, from: 3);
    runs(BrainAnatomy.calcarine, sulcus('calcarine'), 2.5, from: 1);
    runs(
      BrainAnatomy.parietoOccipital,
      sulcus('parieto-occipital'),
      2.5,
      from: 1,
    );
    // The basilar artery along the front of the pons, outside it.
    final List<Offset> brainstem = _dense(BrainAnatomy.brainstem);
    for (final Offset p in BrainAnatomy.basilar.points.skip(1)) {
      expect(_inside(brainstem, p), isFalse, reason: '$p');
      expect(_toLine(brainstem, p, closed: true), lessThan(3.5), reason: '$p');
    }
  });

  test('each landmark is named on what it names', () {
    for (final (Offset at, List<Offset> part) in <(Offset, List<Offset>)>[
      (BrainAnatomy.callosumName, BrainAnatomy.callosum),
      (BrainAnatomy.thalamusName, BrainAnatomy.thalamus),
      (BrainAnatomy.hypothalamusName, BrainAnatomy.hypothalamus),
      (BrainAnatomy.cerebellumName, BrainAnatomy.vermis),
      (BrainAnatomy.brainstemName, BrainAnatomy.brainstem),
    ]) {
      expect(_inside(_dense(part), at), isTrue, reason: '$at');
    }
  });

  test('the brain is laid the same every time', () {
    final BrainForm a = _form();
    final BrainForm b = _form();
    expect(a.outlinePoints, b.outlinePoints);
    expect(a.creases.$1.getBounds(), b.creases.$1.getBounds());
    expect(a.creases.$2.getBounds(), b.creases.$2.getBounds());
    for (final BrainPart part in BrainForm.meshed) {
      expect(a.surfaceOf(part).normals, b.surfaceOf(part).normals);
    }
    expect(a.arbor.white.getBounds(), b.arbor.white.getBounds());
    expect(a.vermis.getBounds(), b.vermis.getBounds());
    expect(a.lateralPlexus, b.lateralPlexus);
  });
}
