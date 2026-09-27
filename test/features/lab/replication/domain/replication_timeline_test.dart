import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/core/catalog/protein_target.dart';
import 'package:helixpeek/features/lab/replication/domain/replication_plan.dart';
import 'package:helixpeek/features/lab/replication/domain/replication_timeline.dart';
import 'package:helixpeek/shared/motion/animation_timeline.dart';

import '../../../../support/test_catalog.dart';
import '../replication_fixtures.dart';

void main() {
  test('thirty beats in six chapters, named, the first at the start', () {
    final ReplicationTimeline timeline = ReplicationTimeline(
      planOf(TestCatalog.insulin),
    );
    expect(timeline.beats, 30);
    expect(
      <String>[for (final PhaseMark m in timeline.phases) m.name],
      <String>[
        'The origin opens',
        'Leading strand',
        'Lagging strand',
        'Proofreading',
        'The rest of the record',
        'Two copies',
      ],
    );
    expect(timeline.phases.first.t, 0);
    for (int i = 1; i < timeline.phases.length; i++) {
      expect(timeline.phases[i].t, greaterThan(timeline.phases[i - 1].t));
    }
    // Each chapter's own still is its first frame.
    for (final PhaseMark mark in timeline.phases) {
      expect(
        timeline.stateAt(mark.t).phase.name,
        mark.captionKey,
        reason: mark.name,
      );
    }
  });

  for (final ProteinTarget t in copyable) {
    test('${t.slug}: the forks only move forward, from shut to finished', () {
      final ReplicationPlan plan = planOf(t);
      final ReplicationTimeline timeline = ReplicationTimeline(plan);
      expect(timeline.stateAt(0).travel, 0);
      expect(timeline.stateAt(1).travel, plan.travelEnd);
      double previous = 0;
      for (int i = 0; i <= 600; i++) {
        final ReplicationFrame frame = timeline.stateAt(i / 600);
        expect(frame.travel, greaterThanOrEqualTo(previous));
        previous = frame.travel;
      }
    });
  }

  test('each chapter starts where its story does', () {
    final ReplicationPlan plan = planOf(TestCatalog.insulin);
    final ReplicationTimeline timeline = ReplicationTimeline(plan);
    final List<NewPiece> right = plan.fragmentsOf(Fork.right);
    double at(String key) =>
        timeline.phases.firstWhere((PhaseMark m) => m.captionKey == key).t;

    // The bubble is open and both leading primers are down.
    expect(
      timeline.stateAt(at('leading')).travel,
      ReplicationPlan.bubble.toDouble(),
    );
    expect(
      plan.madeAt(
        NewStrand.sense,
        plan.origin,
        timeline.stateAt(at('leading')).travel,
      ),
      Made.rna,
    );
    // The first fragment's primer has just gone down.
    expect(timeline.stateAt(at('lagging')).travel, right[0].primedAt);
    // Just before the set piece the first fragment is let go and the second
    // primed: one loop at a time.
    final double before = timeline.stateAt(at('proofreading') - 1e-9).travel;
    expect(before, closeTo(plan.setPieceTravel, 1e-6));
    expect(before, greaterThanOrEqualTo(right[0].doneAt));
    expect(before, greaterThanOrEqualTo(right[1].primedAt));
  });

  test('the fork waits through the five steps of the set piece', () {
    final ReplicationPlan plan = planOf(TestCatalog.insulin);
    final ReplicationTimeline timeline = ReplicationTimeline(plan);
    final List<SetPieceStep> seen = <SetPieceStep>[];
    for (int i = 0; i <= 3000; i++) {
      final ReplicationFrame frame = timeline.stateAt(i / 3000);
      final SetPieceStep? step = frame.setPiece;
      if (step == null) {
        continue;
      }
      expect(frame.phase, ReplicationPhase.proofreading);
      expect(frame.travel, plan.setPieceTravel);
      expect(frame.setPieceProgress, inInclusiveRange(0, 1));
      expect(frame.setPiecePlayed, isFalse);
      if (seen.isEmpty || seen.last != step) {
        seen.add(step);
      }
    }
    expect(seen, SetPieceStep.values);
    expect(timeline.stateAt(0.7).setPiecePlayed, isTrue);
    expect(timeline.stateAt(0.4).setPiecePlayed, isFalse);
  });

  test('is a pure function of t', () {
    final ReplicationTimeline timeline = ReplicationTimeline(
      planOf(TestCatalog.hemoglobin),
    );
    for (final double t in <double>[0, 0.13, 0.5, 0.61, 0.97, 1]) {
      expect(timeline.stateAt(t), timeline.stateAt(t));
      expect(
        ReplicationTimeline(planOf(TestCatalog.hemoglobin)).stateAt(t),
        timeline.stateAt(t),
      );
    }
  });

  test('holds one fragment of each lagging strand in hand at a time', () {
    final ReplicationPlan plan = planOf(TestCatalog.insulin);
    final ReplicationTimeline timeline = ReplicationTimeline(plan);
    for (int i = 0; i <= 1000; i++) {
      final double travel = timeline.stateAt(i / 1000).travel;
      for (final Fork fork in Fork.values) {
        final int inHand = plan
            .fragmentsOf(fork)
            .where((NewPiece f) => travel >= f.primedAt && travel < f.doneAt)
            .length;
        expect(inHand, lessThanOrEqualTo(1), reason: '$fork at $travel');
      }
    }
  });
}
