import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/core/catalog/protein_target.dart';
import 'package:helixpeek/features/zoom/domain/locus_track.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/chromosome/chromosome_form.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/chromosome/chromosome_style.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/chromosome_scene.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/zoom_subject.dart';

import '../../../support/test_catalog.dart';
import '../record_fixtures.dart';
import '../zoom_fixtures.dart';

/// [t]'s chromosome as a form, freshly built, at the half-width its scene
/// draws it with.
ChromosomeForm _form(ProteinTarget t) {
  final ChromosomeScene scene = ChromosomeScene(
    ZoomSubject(track: locusOf(t), record: recordOf(t)),
  );
  return ChromosomeForm(
    locusOf(t),
    half: scene.half,
    look: ChromosomeLookSpec.zoom,
  );
}

/// Everything about [form] that is its chromosome's alone, as numbers: its
/// size, its knobs, its rows and its outlines.
List<double> _shape(ChromosomeForm form) => <double>[
  form.half,
  form.centromere,
  ...form.bodyRows,
  for (final double side in <double>[-1, 1]) ...<double>[
    ...form.knobs(side).y,
    ...form.knobs(side).phi,
    ...form.knobs(side).radius,
    for (final int kind in form.knobs(side).kind) kind.toDouble(),
    for (final Offset p in form.chromatid(side).points) ...<double>[p.dx, p.dy],
  ],
  for (final Offset p in form.outline().points) ...<double>[p.dx, p.dy],
];

void main() {
  test('a chromosome’s form is the same every time it is built', () {
    for (final ProteinTarget t in TestCatalog.all) {
      expect(_shape(_form(t)), _shape(_form(t)), reason: t.slug);
    }
  });

  test('proteins on one chromosome share its form, and only their gene '
      'tells them apart', () {
    for (final List<ProteinTarget> same in <List<ProteinTarget>>[
      <ProteinTarget>[TestCatalog.insulin, TestCatalog.hemoglobin],
      <ProteinTarget>[
        TestCatalog.cftr,
        TestCatalog.erythropoietin,
        TestCatalog.leptin,
      ],
      <ProteinTarget>[
        TestCatalog.p53,
        TestCatalog.somatotropin,
        TestCatalog.ubiquitin,
      ],
      <ProteinTarget>[
        TestCatalog.prion,
        TestCatalog.oxytocin,
        TestCatalog.vasopressin,
      ],
      <ProteinTarget>[TestCatalog.app, TestCatalog.sod1],
    ]) {
      final List<double> first = _shape(_form(same.first));
      for (final ProteinTarget t in same.skip(1)) {
        expect(
          locusOf(t).chromosome,
          locusOf(same.first).chromosome,
          reason: t.slug,
        );
        expect(
          _shape(_form(t)),
          first,
          reason:
              '${t.slug} against '
              '${same.first.slug}',
        );
      }
      final Set<double> genes = <double>{
        for (final ProteinTarget t in same) _form(t).geneY,
      };
      expect(genes, hasLength(same.length), reason: same.first.slug);
    }
  });

  test('every knob lies on its sister: its middle inside the sister’s '
      'outline, no further round the tube than the rim', () {
    for (final ProteinTarget t in TestCatalog.all) {
      final ChromosomeForm form = _form(t);
      final ChromosomeGlobules globules = form.look.globules;
      int laid = 0;
      for (final double side in <double>[-1, 1]) {
        final KnobField knobs = form.knobs(side);
        for (int k = 0; k < knobs.length; k++) {
          final double y = knobs.y[k];
          final double phi = knobs.phi[k];
          final double r = knobs.radius[k];
          final String where = '${t.slug}, side $side, knob $k';
          expect(y, inInclusiveRange(form.top, form.bottom), reason: where);
          expect(phi.abs(), lessThanOrEqualTo(globules.rim), reason: where);
          expect(r, greaterThan(0), reason: where);
          // Its middle is out on the tube, inside the sister's outline:
          // only round its edge and its ends does a globule stand out of it.
          final double x =
              form.centreAt(side, y) +
              globules.surface * form.widthAt(y) * math.sin(phi);
          expect(
            (x - form.centreAt(side, y)).abs(),
            lessThanOrEqualTo(form.widthAt(y) + 1e-12),
            reason: where,
          );
          if (knobs.kind[k] == KnobField.lobe) {
            laid++;
          }
        }
      }
      expect(laid, greaterThan(100), reason: t.slug);
    }
  });

  test('the gene’s place on each sister lies at one height, either side of '
      'the pair, on its sister and in the gene’s band, and its ping is as '
      'big whatever the gene’s length', () {
    for (final ProteinTarget t in TestCatalog.all) {
      final ChromosomeForm form = _form(t);
      final LocusTrack track = locusOf(t);
      final Offset left = form.geneOn(-1);
      final Offset right = form.geneOn(1);
      expect(left.dy, form.geneY, reason: t.slug);
      expect(right.dy, form.geneY, reason: t.slug);
      expect(
        (left.dx + right.dx) / 2,
        closeTo(form.bend(form.geneY), 1e-12),
        reason: t.slug,
      );
      expect(right.dx, greaterThan(left.dx), reason: t.slug);
      for (final (double side, Offset place) in <(double, Offset)>[
        (-1, left),
        (1, right),
      ]) {
        expect(
          (place.dx - form.centreAt(side, place.dy)).abs(),
          lessThanOrEqualTo(form.widthAt(place.dy)),
          reason: '${t.slug}, side $side',
        );
      }
      expect(
        form.geneY,
        inInclusiveRange(
          form.yOf(track.bandStart),
          form.yOf(track.bandEnd + 1),
        ),
        reason: t.slug,
      );
      // Its ping: about half a chromatid, never wider than the chromatid
      // where it lies, and nothing to do with how long the gene is.
      expect(
        form.pingRadius,
        math.min(
          form.look.ping * form.half,
          form.look.pingShare * form.widthAt(form.geneY),
        ),
        reason: t.slug,
      );
      expect(
        form.pingRadius,
        lessThanOrEqualTo(form.look.ping * form.half),
        reason: t.slug,
      );
    }
  });

  test('the centromere’s tint lies about it and the telomeres’ at the '
      'ends, and neither in the gene’s band', () {
    for (final ProteinTarget t in TestCatalog.all) {
      final ChromosomeForm form = _form(t);
      final double c = form.centromere;
      final double centromere = form.look.centromereReach * form.half;
      final double telomere = form.look.telomereReach * form.half;
      expect(
        form.centromereAt(c),
        closeTo(1 - form.geneAt(c), 1e-12),
        reason: t.slug,
      );
      for (final double end in <double>[form.top, form.bottom]) {
        expect(
          form.telomereAt(end),
          closeTo(1 - form.geneAt(end), 1e-12),
          reason: t.slug,
        );
      }
      for (int i = 0; i <= 2000; i++) {
        final double y = form.top + (form.bottom - form.top) * i / 2000;
        final double a = form.centromereAt(y);
        final double b = form.telomereAt(y);
        final String what = '${t.slug} at $y';
        expect(a, inInclusiveRange(0, 1), reason: what);
        expect(b, inInclusiveRange(0, 1), reason: what);
        if ((y - c).abs() >= centromere) {
          expect(a, 0, reason: what);
        }
        if (math.min(y - form.top, form.bottom - y) >= telomere) {
          expect(b, 0, reason: what);
        }
        if (form.geneAt(y) == 1) {
          expect(a, 0, reason: what);
          expect(b, 0, reason: what);
        }
      }
    }
  });

  test('nothing in a form is not a number', () {
    for (final ProteinTarget t in TestCatalog.all) {
      final ChromosomeForm form = _form(t);
      for (final double v in _shape(form)) {
        expect(v.isFinite, isTrue, reason: t.slug);
      }
      for (int i = 0; i <= 400; i++) {
        final double y = form.top + (form.bottom - form.top) * i / 400;
        for (final double v in <double>[
          form.widthAt(y),
          form.toneAt(y),
          form.geneAt(y),
          form.bowAt(y),
          form.slope(y),
          form.contact(y),
          form.centreAt(-1, y),
          form.centreAt(1, y),
        ]) {
          expect(v.isFinite, isTrue, reason: '${t.slug} at $y');
        }
      }
      expect(form.pingRadius.isFinite, isTrue, reason: t.slug);
    }
  });
}
