import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/core/catalog/protein_target.dart';
import 'package:helixpeek/shared/folding/fold_geometry.dart';
import 'package:helixpeek/shared/folding/fold_timeline.dart';
import 'package:helixpeek/shared/folding/folding_track.dart';
import 'package:helixpeek/shared/motion/animation_timeline.dart';

import '../../support/test_catalog.dart';
import 'folding_fixtures.dart';

void main() {
  FoldTimeline timelineOf(String slug) =>
      FoldTimeline(geometryOf(target(slug)));

  double distance3(ModelPoint a, ModelPoint b) => math.sqrt(
    (a.$1 - b.$1) * (a.$1 - b.$1) +
        (a.$2 - b.$2) * (a.$2 - b.$2) +
        (a.$3 - b.$3) * (a.$3 - b.$3),
  );

  double distance(List<double> p, int i, ModelPoint c) => math.sqrt(
    math.pow(p[3 * i] - c.$1, 2) +
        math.pow(p[3 * i + 1] - c.$2, 2) +
        math.pow(p[3 * i + 2] - c.$3, 2),
  );

  test('four named steps, in the order the textbook tells them', () {
    final FoldTimeline timeline = timelineOf('insulin');
    expect(timeline.phases.map((PhaseMark p) => p.name), <String>[
      'Hydrophobic collapse',
      'Helices coil',
      'Strands pair',
      'Bridges snap shut',
    ]);
    expect(timeline.phases.map((PhaseMark p) => p.t), <double>[
      0,
      0.25,
      0.5,
      0.75,
    ]);
    expect(timeline.beats, 12);
    expect(FoldTimeline.stepAt(0), FoldStep.collapse);
    expect(FoldTimeline.stepAt(0.3), FoldStep.helices);
    expect(FoldTimeline.stepAt(0.6), FoldStep.strands);
    expect(FoldTimeline.stepAt(1), FoldStep.bridges);
  });

  test(
    'the last frame is the fold, residue for residue, for every protein',
    () {
      for (final ProteinTarget protein in TestCatalog.all) {
        final FoldGeometry geometry = geometryOf(protein);
        final FoldFrame last = FoldTimeline(geometry).stateAt(1);
        for (int i = 0; i < geometry.length; i++) {
          final ModelPoint? ca = geometry.drawn[i].ca;
          if (ca == null) {
            continue;
          }
          // Exactly: the page draws these points, and so does this frame.
          expect(
            <double>[
              last.positions[3 * i],
              last.positions[3 * i + 1],
              last.positions[3 * i + 2],
            ],
            <double>[ca.$1, ca.$2, ca.$3],
            reason: '${protein.slug} ${geometry.drawn[i].number}',
          );
        }
        expect(
          last.closure.every((double c) => c == 1),
          isTrue,
          reason: protein.slug,
        );
      }
    },
  );

  test('it starts unfolded', () {
    for (final ProteinTarget protein in TestCatalog.all) {
      final FoldGeometry geometry = geometryOf(protein);
      final FoldFrame first = FoldTimeline(geometry).stateAt(0);
      double off = 0;
      int placed = 0;
      for (int i = 0; i < geometry.length; i++) {
        final ModelPoint? ca = geometry.drawn[i].ca;
        if (ca != null) {
          off += distance(first.positions, i, ca);
          placed++;
        }
      }
      // On average more than 2 A from its place in the fold.
      expect(
        off / placed / geometry.unit,
        greaterThan(2),
        reason: protein.slug,
      );
    }
  });

  test('the prion’s loose residues never resolve', () {
    final FoldTimeline timeline = timelineOf('prion');
    final FoldGeometry geometry = timeline.geometry;
    for (final double t in <double>[0.3, 0.6, 0.9, 1]) {
      final FoldFrame now = timeline.frameAt(t);
      final FoldFrame later = timeline.frameAt(t, idle: 0.7);
      for (int i = 0; i < geometry.length; i++) {
        final bool moved =
            now.positions[3 * i] != later.positions[3 * i] ||
            now.positions[3 * i + 1] != later.positions[3 * i + 1] ||
            now.positions[3 * i + 2] != later.positions[3 * i + 2];
        // The screen's clock moves every loose residue, and nothing else.
        expect(moved, !geometry.drawn[i].isOrdered, reason: 'residue $i at $t');
      }
    }
    // And the timeline itself never holds them still, to its last frame.
    final FoldFrame end = timeline.stateAt(1);
    final FoldFrame justBefore = timeline.stateAt(0.99);
    final int first = geometry.loose.first.start;
    expect(end.positions[3 * first], isNot(justBefore.positions[3 * first]));
  });

  test('loose residues stay in the frame the page draws', () {
    for (final String slug in <String>['prion', 'cftr', 'app', 'leptin']) {
      final FoldGeometry geometry = geometryOf(target(slug));
      for (double t = 0; t <= 1; t += 0.05) {
        final FoldFrame frame = FoldTimeline(geometry).stateAt(t);
        for (int i = 0; i < geometry.length; i++) {
          expect(
            distance(frame.positions, i, geometry.centre),
            lessThan(1.5 * geometry.reach),
            reason: '$slug residue $i at $t',
          );
        }
      }
    }
  });

  test('helices coil in their own step, and strands pair in theirs', () {
    final FoldTimeline timeline = timelineOf('ubiquitin');
    final FoldGeometry geometry = timeline.geometry;
    final FoldFrame coiled = timeline.stateAt(0.5);
    for (int i = 0; i < geometry.length; i++) {
      final FoldResidue residue = geometry.drawn[i];
      final ModelPoint ca = residue.ca!;
      final double off = distance(coiled.positions, i, ca);
      if (residue.shape == FoldShape.helix) {
        // In place, less any hold near a bridge (ubiquitin has none).
        expect(off, 0, reason: 'helix residue ${residue.number}');
      } else if (residue.shape == FoldShape.strand) {
        expect(off, greaterThan(0), reason: 'strand residue ${residue.number}');
      }
    }
    final FoldFrame paired = timeline.stateAt(0.75);
    for (int i = 0; i < geometry.length; i++) {
      expect(distance(paired.positions, i, geometry.drawn[i].ca!), 0);
    }
  });

  test('bridges stay open until their step, then snap shut', () {
    final FoldTimeline timeline = timelineOf('lysozyme');
    expect(timeline.geometry.bridges, hasLength(4));
    for (final double t in <double>[0, 0.3, 0.6, 0.75, 0.8]) {
      expect(
        timeline.stateAt(t).closure.every((double c) => c == 0),
        isTrue,
        reason: '$t',
      );
    }
    expect(timeline.stateAt(0.875).closure.first, inExclusiveRange(0, 1));
    expect(timeline.stateAt(0.95).closure.every((double c) => c == 1), isTrue);
    // Until they close, the cysteines are held a little apart from their places.
    final (int a, int b) = timeline.geometry.bridges.first;
    final FoldFrame held = timeline.stateAt(0.8);
    final ModelPoint ca = timeline.geometry.drawn[a].ca!;
    expect(
      distance(held.positions, a, ca) / timeline.geometry.unit,
      closeTo(2.5, 0.2),
    );
    expect(b, isNot(a));
  });

  test('bridges are the model’s, in precursor order', () {
    expect(geometryOf(target('insulin')).bridgeNumbers, <(int, int)>[
      (31, 96),
      (43, 109),
      (95, 100),
    ]);
    // APP's other bridges are in domains its entry does not hold: the six
    // are the E1 domain's, which its model draws.
    expect(geometryOf(target('app')).bridges, hasLength(6));
    expect(geometryOf(target('hemoglobin')).bridges, isEmpty);
    // A model that draws no bridges has none to close.
    expect(geometryOf(target('glucagon')).bridges, isEmpty);
  });

  test('each bridge runs through the atoms the model’s rods do', () {
    final FoldGeometry insulin = geometryOf(target('insulin'));
    for (int b = 0; b < insulin.bridges.length; b++) {
      final (int i, int j) = insulin.bridges[b];
      final List<ModelPoint> path = insulin.bridgePaths[b];
      expect(path, hasLength(6));
      expect(insulin.drawn[i].letter, 'C');
      expect(insulin.drawn[j].letter, 'C');
      // CA to CA, through each cysteine's CB and SG.
      expect(distance3(path.first, insulin.drawn[i].ca!), lessThan(1e-4));
      expect(distance3(path.last, insulin.drawn[j].ca!), lessThan(1e-4));
      final double sulfurs = distance3(path[2], path[3]) / insulin.unit;
      expect(sulfurs, closeTo(2.05, 0.1));
    }
  });

  test('the collapse brings the water-avoiding residues furthest in', () {
    for (final String slug in <String>[
      'myoglobin',
      'lysozyme',
      'amylase',
      'sod1',
    ]) {
      final FoldGeometry geometry = geometryOf(target(slug));
      final FoldFrame collapsed = FoldTimeline(geometry).stateAt(0.25);
      double inside = 0;
      double outside = 0;
      int nIn = 0;
      int nOut = 0;
      for (int i = 0; i < geometry.length; i++) {
        final FoldResidue residue = geometry.drawn[i];
        if (!residue.isOrdered) {
          continue;
        }
        final double r = distance(collapsed.positions, i, geometry.centre);
        if (isWaterAvoiding(residue.letter)) {
          inside += r;
          nIn++;
        } else {
          outside += r;
          nOut++;
        }
      }
      expect(inside / nIn, lessThan(outside / nOut), reason: slug);
    }
  });

  test(
    'nothing jumps: every residue moves a little from one frame to the next',
    () {
      for (final String slug in <String>['insulin', 'prion', 'sod1']) {
        final FoldTimeline timeline = timelineOf(slug);
        final FoldGeometry geometry = timeline.geometry;
        FoldFrame previous = timeline.stateAt(0);
        for (int step = 1; step <= 600; step++) {
          final FoldFrame frame = timeline.stateAt(step / 600);
          for (int i = 0; i < geometry.length; i++) {
            final double moved = math.sqrt(
              math.pow(frame.positions[3 * i] - previous.positions[3 * i], 2) +
                  math.pow(
                    frame.positions[3 * i + 1] - previous.positions[3 * i + 1],
                    2,
                  ) +
                  math.pow(
                    frame.positions[3 * i + 2] - previous.positions[3 * i + 2],
                    2,
                  ),
            );
            expect(
              moved,
              lessThan(0.05 * geometry.reach),
              reason: '$slug $i at $step',
            );
          }
          previous = frame;
        }
      }
    },
  );

  test('the fold finishes after the bridges close, gently at both ends', () {
    expect(FoldTimeline.finishAt(0), 0);
    expect(FoldTimeline.finishAt(FoldTimeline.bridgesClosedAt), 0);
    expect(FoldTimeline.finishAt(1), 1);
    expect(FoldTimeline.finishAt(2), 1);
    double previous = 0;
    for (int frame = 0; frame <= 540; frame++) {
      final double p = FoldTimeline.finishAt(frame / 540);
      expect(p, inInclusiveRange(previous, 1));
      previous = p;
    }
    // A frame at either end moves it by next to nothing.
    const double frame = 1 / 540;
    expect(
      FoldTimeline.finishAt(FoldTimeline.bridgesClosedAt + frame),
      lessThan(0.001),
    );
    expect(1 - FoldTimeline.finishAt(1 - frame), lessThan(0.001));
  });

  test('the same moment is the same frame', () {
    final FoldTimeline timeline = timelineOf('insulin');
    expect(timeline.stateAt(0.4).positions, timeline.stateAt(0.4).positions);
  });
}
