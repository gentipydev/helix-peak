import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/features/lab/crispr/domain/guide_score.dart';

void main() {
  group('what the bases measure', () {
    test('GC is counted, not estimated', () {
      expect(GuideScore.of('GGGGGGGGGGGGGGGGGGGG').gcFraction, 1);
      expect(GuideScore.of('AAAAAAAAAAAAAAAAAAAA').gcFraction, 0);
      expect(
        GuideScore.of('TACCTAGTGTGCGGGGAACG').gcFraction,
        closeTo(0.6, 1e-9),
      );
      expect(GuideScore.of('GC').gcFraction, 1);
      expect(GuideScore.of('GATC').gcFraction, 0.5);
    });

    test('the longest run of T bases is the one reported', () {
      expect(GuideScore.of('ACGACGACGACGACGACGAC').longestPolyT, 0);
      expect(GuideScore.of('TTAGTTTAGTTAGTTAGTTA').longestPolyT, 3);
      expect(GuideScore.of('TTTTTAAAAAGAAGTTCTCT').longestPolyT, 5);
      expect(GuideScore.of('ACAGGGAGCTGGTCACTTTT').longestPolyT, 4);
    });

    test('four in a row is where a run becomes a terminator', () {
      expect(GuideScore.polyTTerminator, 4);
      expect(GuideScore.of('ACGTTTACGACGACGACGAC').hasPolyT, isFalse);
      expect(GuideScore.of('ACGTTTTCGACGACGACGAC').hasPolyT, isTrue);
      // At the end of the protospacer as readily as in the middle.
      expect(GuideScore.of('ACGACGACGACGACGATTTT').hasPolyT, isTrue);
    });

    test('a protospacer with no bases is not a measurement', () {
      expect(() => GuideScore.of(''), throwsArgumentError);
    });
  });

  group('the composite is the two properties and nothing else', () {
    test('inside the band it is one, and outside it falls away', () {
      double compositeAt(double gc) =>
          GuideScore(gcFraction: gc, longestPolyT: 0).composite;
      expect(compositeAt(GuideScore.gcFloor), 1);
      expect(compositeAt(0.5), 1);
      expect(compositeAt(GuideScore.gcCeiling), 1);
      expect(compositeAt(0), 0);
      expect(compositeAt(1), 0);
      expect(compositeAt(0.2), closeTo(0.5, 1e-9));
      expect(compositeAt(0.8), closeTo(0.5, 1e-9));
    });

    test('it never leaves 0 to 1', () {
      for (int step = 0; step <= 100; step++) {
        final double gc = step / 100;
        for (final int run in <int>[0, 3, 4, 9]) {
          final double composite = GuideScore(
            gcFraction: gc,
            longestPolyT: run,
          ).composite;
          expect(composite, inInclusiveRange(0, 1), reason: 'GC $gc, run $run');
        }
      }
    });

    test('a terminator run keeps half of it', () {
      const GuideScore clean = GuideScore(gcFraction: 0.5, longestPolyT: 3);
      const GuideScore terminated = GuideScore(
        gcFraction: 0.5,
        longestPolyT: 4,
      );
      expect(clean.composite, 1);
      expect(terminated.composite, closeTo(GuideScore.polyTFactor, 1e-9));
      expect(terminated.composite, lessThan(clean.composite));
    });

    test('a real protospacer, measured end to end', () {
      // Five T bases and a fifth of it GC: a terminator run, and well under
      // the band.
      final GuideScore score = GuideScore.of('TTTTTAAAAAGAAGTTCTCT');
      expect(score.gcFraction, closeTo(0.2, 1e-9));
      expect(score.hasPolyT, isTrue);
      expect(score.composite, closeTo(0.25, 1e-9));
      expect(score.toString(), contains('GC 20%'));
    });
  });
}
