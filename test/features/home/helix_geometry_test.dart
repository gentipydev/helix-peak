import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeak/features/home/presentation/widgets/helix_geometry.dart';

/// Distance between two model points, in the unit-circle space the model is
/// defined in.
double _gap(HelixModel model, int i, int j) {
  final double dx = model.pointCos[i] - model.pointCos[j];
  final double dy = model.pointSin[i] - model.pointSin[j];
  return math.sqrt(dx * dx + dy * dy);
}

void main() {
  group('HelixPalette', () {
    test('pairs each base with its Watson-Crick partner', () {
      expect(
        HelixPalette.complementOf(HelixPalette.adenine),
        HelixPalette.thymine,
      );
      expect(
        HelixPalette.complementOf(HelixPalette.thymine),
        HelixPalette.adenine,
      );
      expect(
        HelixPalette.complementOf(HelixPalette.guanine),
        HelixPalette.cytosine,
      );
      expect(
        HelixPalette.complementOf(HelixPalette.cytosine),
        HelixPalette.guanine,
      );
    });

    test('identifies the two-ring bases', () {
      expect(HelixPalette.isPurine(HelixPalette.adenine), isTrue);
      expect(HelixPalette.isPurine(HelixPalette.guanine), isTrue);
      expect(HelixPalette.isPurine(HelixPalette.thymine), isFalse);
      expect(HelixPalette.isPurine(HelixPalette.cytosine), isFalse);
    });

    test('every pair is one purine and one pyrimidine', () {
      // The painter sizes both halves of a rung off this and never checks it,
      // so if the slot ordering ever stopped guaranteeing it the render would
      // go quietly wrong rather than fail.
      for (int base = 0; base < HelixPalette.firstLit; base++) {
        expect(
          HelixPalette.isPurine(base),
          isNot(HelixPalette.isPurine(HelixPalette.complementOf(base))),
          reason: 'base $base and its partner have the same ring count',
        );
      }
    });
  });

  group('HelixModel geometry', () {
    test('runs off both ends of a phone viewport', () {
      // The helix has to read as a section of something longer. Were the model
      // ever shorter than the frame the painter would stretch it to fit, and
      // the B-DNA proportions would stretch with it.
      expect(HelixModel().modelHeight, greaterThan(620 * 1.2));
    });

    test('splits every rung off-centre, with the bond gap between', () {
      final HelixModel model = HelixModel();
      final int rungBase = 2 * model.sampleCount;
      final Set<String> junctions = <String>{};

      for (int r = 0; r < model.rungCount; r++) {
        final int a = rungBase + 4 * r;
        final int midA = a + 1;
        final int midB = a + 2;
        final int b = a + 3;

        final double span = _gap(model, a, b);
        final double toMidA = _gap(model, a, midA);
        final double toMidB = _gap(model, a, midB);

        // Both junction points sit on the chord, in order, the gap apart.
        expect(toMidA, lessThan(toMidB));
        expect(toMidB, lessThan(span));
        expect(
          toMidB - toMidA,
          closeTo(span * HelixModel.bondGapFraction, 1e-4),
        );

        // And the junction itself is where the purine's reach puts it, on one
        // side or the other — never at the midpoint, which is the whole point.
        final double junction =
            toMidA / span + HelixModel.bondGapFraction / 2;
        final bool nearer = (junction - HelixModel.purineReach).abs() < 1e-4;
        final bool further =
            (junction - (1 - HelixModel.purineReach)).abs() < 1e-4;
        expect(
          nearer || further,
          isTrue,
          reason: 'rung $r splits at $junction',
        );
        junctions.add(nearer ? 'purine first' : 'pyrimidine first');
      }

      // Both orientations occur, so the check above is not passing on a
      // molecule that happens to be all one way round.
      expect(junctions, hasLength(2));
    });
  });

  group('HelixModel transcription profile', () {
    // The regression this guards: the peel ramp was once derived from lengths
    // measured against the model rather than in bases, so its two ends moved
    // apart as the rung count changed until the denominator went negative and
    // the ramp ran backwards. Both ends now come off a ratio of two counts in
    // bases, which cancels the rung count — these assertions are what says so.
    for (final int rungs in <int>[24, 48, 72, 120]) {
      test('holds its shape at $rungs base pairs', () {
        final HelixModel model = HelixModel(rungCount: rungs);

        expect(model.trailPeel.first, 0);
        expect(model.trailPeel.last, closeTo(1, 1e-5));

        int freeAt = HelixModel.profileSteps - 1;
        for (int i = 1; i < HelixModel.profileSteps; i++) {
          expect(
            model.trailPeel[i],
            greaterThanOrEqualTo(model.trailPeel[i - 1]),
            reason: 'the peel ramp reverses at step $i',
          );
          if (freeAt == HelixModel.profileSteps - 1 &&
              model.trailPeel[i] > 0.99) {
            freeAt = i;
          }
        }

        // The strand has to finish leaving the duplex while there is still
        // enough of it on screen to see it happen. A peel that completes
        // inside the fade-out is a peel nobody watches.
        expect(
          model.trailReveal[freeAt],
          greaterThan(0.3),
          reason: 'the transcript has faded to '
              '${model.trailReveal[freeAt]} by the time it is free',
        );
      });
    }

    test('measures the hybrid against the transcript in bases', () {
      // Both are counted the same way, so their ratio is a constant and the
      // rung count cannot get into it.
      for (final int rungs in <int>[24, 48, 72, 120]) {
        final HelixModel model = HelixModel(rungCount: rungs);
        expect(
          model.hybridLength / model.transcriptSpan,
          closeTo(
            HelixModel.hybridBases / HelixModel.transcriptSpanBases,
            1e-9,
          ),
        );
      }
    });
  });
}
