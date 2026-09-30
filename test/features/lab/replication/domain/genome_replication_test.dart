import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/features/lab/replication/domain/genome_replication.dart';
import 'package:helixpeek/features/lab/replication/domain/replication_tour.dart';

void main() {
  const ReplicationTimeline timeline = ReplicationTimeline();
  test('a 200-bp illustrative sequence with complementary DNA and RNA', () {
    expect(GenomeReplication.sequence.length, 200);
    expect(GenomeReplication.sequence, matches(RegExp(r'^[ACGT]+$')));
    for (final String base in GenomeReplication.sequence.split('')) {
      expect(
        GenomeReplication.complement(GenomeReplication.complement(base)),
        base,
      );
    }
    expect(GenomeReplication.complement('A', rna: true), 'U');
    expect(GenomeReplication.templateAt(-1), GenomeReplication.sequence[199]);
  });

  test(
    'each fragment starts with RNA then a short Pol alpha DNA extension',
    () {
      for (final double start in <double>[8, 50]) {
        final int end = start == 8 ? 99 : 199;
        final ReplicationFrame before = ReplicationFrame(start);
        expect(before.laggingAt(end), DaughterBase.absent);
        final ReplicationFrame rna = ReplicationFrame(start + 4);
        expect(rna.laggingAt(end - 9), DaughterBase.rna);
        expect(rna.laggingAt(end - 10), DaughterBase.absent);
        final ReplicationFrame alpha = ReplicationFrame(start + 12);
        expect(alpha.laggingAt(end - 9), DaughterBase.rna);
        expect(alpha.laggingAt(end - 10), DaughterBase.dna);
        expect(alpha.laggingAt(end - 29), DaughterBase.dna);
        expect(alpha.laggingAt(end - 30), DaughterBase.absent);
      }
    },
  );

  test(
    'synthesis follows unwinding, leading and lagging 3-prime ends diverge',
    () {
      double lastFork = 0;
      double lastLeading = 0;
      double lastDelta = 100;
      for (double seconds = 0; seconds <= 120; seconds += 0.25) {
        final ReplicationFrame f = ReplicationFrame(seconds);
        expect(f.fork, greaterThanOrEqualTo(lastFork));
        expect(f.leadingTip, greaterThanOrEqualTo(lastLeading));
        expect(f.leadingTip, lessThan(f.fork));
        for (int i = 0; i < 200; i++) {
          if (f.leadingAt(i) != DaughterBase.absent ||
              f.laggingAt(i) != DaughterBase.absent) {
            expect(i, lessThan(f.fork));
          }
        }
        if (seconds >= 20 && seconds < 46) {
          expect(f.deltaTip, lessThanOrEqualTo(lastDelta));
          lastDelta = f.deltaTip;
        }
        lastFork = f.fork;
        lastLeading = f.leadingTip;
      }
    },
  );

  test(
    'replacement proceeds from the first primer 5-prime end before sealing',
    () {
      const ReplicationFrame before = ReplicationFrame(88);
      expect(before.laggingAt(99), DaughterBase.rna);
      const ReplicationFrame middle = ReplicationFrame(94);
      expect(middle.laggingAt(99), DaughterBase.dna);
      expect(middle.laggingAt(95), DaughterBase.dna);
      expect(middle.laggingAt(94), DaughterBase.rna);
      expect(middle.sealed, isFalse);
      const ReplicationFrame nick = ReplicationFrame(101);
      for (int i = 90; i < 100; i++) {
        expect(nick.laggingAt(i), DaughterBase.dna);
      }
      expect(nick.hasNick, isTrue);
      expect(nick.sealed, isFalse);
      expect(const ReplicationFrame(110).hasNick, isFalse);
      expect(const ReplicationFrame(110).sealed, isTrue);
    },
  );

  test(
    'the final view preserves the later primer for the next offscreen fragment',
    () {
      final ReplicationFrame f = timeline.stateAt(1).frame;
      for (int i = 0; i < 200; i++) {
        expect(f.leadingAt(i), DaughterBase.dna);
        expect(f.laggingAt(i), i < 190 ? DaughterBase.dna : DaughterBase.rna);
      }
      expect(f.laggingAt(200), DaughterBase.absent);
      expect(timeline.stateAt(1).chapter, ReplicationChapter.result);
    },
  );

  test(
    'seeking is deterministic, bounded, and each phase has a distinct state',
    () {
      expect(timeline.beats, 160);
      expect(timeline.stateAt(-1), timeline.stateAt(0));
      expect(timeline.stateAt(2), timeline.stateAt(1));
      for (final ReplicationChapter stage in ReplicationChapter.values) {
        final double t = stage.second / timeline.beats;
        final ReplicationMoment expected = timeline.stateAt(t);
        timeline.stateAt(1);
        timeline.stateAt(0.04);
        expect(timeline.stateAt(t), expected);
        expect(expected.chapter, stage);
        expect(expected.caption, isNotEmpty);
      }
    },
  );

  test(
    'topoisomerase II passes a duplex only through a cut, open gate, then '
    'the DNA ahead relaxes',
    () {
      double peak = 0;
      for (double seconds = 0; seconds <= 12; seconds += 0.01) {
        final ReplicationFrame f = ReplicationFrame(seconds);
        // Crossing the G-segment: halfway from the N-gate to the C-gate.
        if (f.transport > 1.3 && f.transport < 1.7) {
          expect(f.topoCut, greaterThan(0.95), reason: '$seconds');
          expect(f.topoGate, greaterThan(0.95), reason: '$seconds');
        }
        if (f.overwinding < peak - 1e-9) {
          expect(f.transport, greaterThanOrEqualTo(2), reason: '$seconds');
        }
        peak = f.overwinding > peak ? f.overwinding : peak;
      }
      expect(const ReplicationFrame(8.5).overwinding, 0);
      expect(const ReplicationFrame(8.5).topoCut, 0);
    },
  );
}
