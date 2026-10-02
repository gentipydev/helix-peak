import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/features/replication/domain/genome_replication.dart';
import 'package:helixpeek/features/replication/domain/replication_tour.dart';

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
      expect(timeline.beats, ReplicationTimeline.durationSeconds);
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

  test('an origin fires into two forks that mirror each other', () {
    const double origin = GenomeReplication.origin;
    // Until it fires, the origin is closed and nothing is copied.
    for (final double seconds in <double>[-60, -45, -36]) {
      final ReplicationFrame f = ReplicationFrame(seconds);
      expect(f.fork, origin, reason: '$seconds');
      expect(f.pieces(leading: true), isEmpty, reason: '$seconds');
      expect(f.pieces(leading: false), isEmpty, reason: '$seconds');
    }
    double last = origin;
    for (double seconds = -60; seconds <= 120; seconds += 0.25) {
      final ReplicationFrame f = ReplicationFrame(seconds);
      expect(f.fork, greaterThanOrEqualTo(last), reason: '$seconds');
      expect(f.lowerFork, origin * 2 - f.fork);
      last = f.fork;
      // Below the origin, each template carries the other fork's pieces
      // from the other template, turned about the origin.
      for (final bool leading in <bool>[true, false]) {
        for (final DaughterPiece piece in f.pieces(leading: leading)) {
          if (piece.to <= origin) {
            expect(
              f
                  .pieces(leading: !leading)
                  .any(
                    (DaughterPiece other) =>
                        (other.from - (origin * 2 - piece.to)).abs() < 1e-9 &&
                        (other.to - (origin * 2 - piece.from)).abs() < 1e-9,
                  ),
              isTrue,
              reason: '$seconds',
            );
          }
        }
      }
    }
  });

  test(
    'the bubble hands the tour its fork: fragment −1 done, primers placed',
    () {
      const ReplicationFrame start = ReplicationFrame(0);
      expect(start.fork, 110);
      expect(start.leadingTip, 74);
      // The leading strand is DNA from the origin up: the other fork's first
      // fragment has replaced its primer.
      for (int i = -95; i < 74; i += 7) {
        expect(start.leadingAt(i), DaughterBase.dna, reason: '$i');
      }
      // Fragment −1 reaches the origin and keeps its own primer until
      // fragment 0 comes back to it.
      expect(start.laggingAt(-5), DaughterBase.rna);
      expect(start.laggingAt(-20), DaughterBase.dna);
      expect(start.laggingAt(-90), DaughterBase.dna);
      expect(start.laggingAt(5), DaughterBase.absent);
      // Fragment 0 has replaced fragment −1's primer before the tour's
      // replacement chapter.
      const ReplicationFrame later = ReplicationFrame(60);
      for (int i = -10; i < 0; i++) {
        expect(later.laggingAt(i), DaughterBase.dna, reason: '$i');
      }
    },
  );

  test(
    'Pol α lets go of a whole primer, and its end rests until Pol δ takes it',
    () {
      for (final int k in <int>[0, 1]) {
        final double done = ReplicationFrame.primerDoneAt(k);
        final double handoff = ReplicationFrame.handoffAt(k);
        expect(handoff, greaterThan(done), reason: '$k');
        // 10 nt of RNA and 20 of Pol α DNA when it lets go.
        expect(ReplicationFrame(done).lengthOf(k), closeTo(30, 1e-9));
        // While RFC loads the clamp, nothing is made.
        final double end = ReplicationFrame(done).tipOf(k);
        for (double s = done; s <= handoff; s += 0.1) {
          expect(
            ReplicationFrame(s).tipOf(k),
            closeTo(end, 1e-9),
            reason: '$k at $s',
          );
        }
        expect(ReplicationFrame(handoff + 1).lengthOf(k), greaterThan(30));
      }
    },
  );

  test('an A/T-rich origin: two hydrogen bonds a pair, G/C flanks three', () {
    const int origin = -95;
    for (int i = origin - 12; i <= origin + 12; i++) {
      expect(GenomeReplication.hydrogenBonds(i), 2, reason: '$i');
    }
    expect(GenomeReplication.hydrogenBonds(origin + 20), 3);
    expect(GenomeReplication.hydrogenBonds(origin - 20), 3);
  });
}
