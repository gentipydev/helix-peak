import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeak/features/home/presentation/widgets/helix_geometry.dart';

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
      expect(HelixModel().modelHeight, greaterThan(620 * 1.2));
    });

    test('winds right-handed, the way B-DNA does', () {
      final HelixModel model = HelixModel();

      // The painter puts +y down the screen and +z away from the viewer, which
      // makes (x, y, z) a right-handed frame. Advancing down that frame while
      // the phase *decreases* is what winds a right-handed helix, and
      // `cos a * sin b - sin a * cos b` is `sin(b - a)`: negative exactly when
      // the phase decreased. A positive value here is the classic illustration
      // error — a left-handed, Z-DNA-shaped double helix.
      for (int i = 0; i < model.sampleCount - 1; i++) {
        expect(
          model.pointAxial[i + 1],
          greaterThan(model.pointAxial[i]),
          reason: 'strand A should run down the screen',
        );
        expect(
          model.pointCos[i] * model.pointSin[i + 1] -
              model.pointSin[i] * model.pointCos[i + 1],
          lessThan(0),
          reason: 'strand A winds left-handed between samples $i and ${i + 1}',
        );
      }
    });

    test('offsets the strands so the grooves come out unequal', () {
      // 22 A major to 12 A minor is a ratio of about 1.83; drawing the strands
      // exactly opposite would make both grooves the same and erase them.
      const double minor = HelixModel.grooveOffset;
      const double major = 2 * math.pi - minor;

      expect(minor, lessThan(math.pi));
      expect(major / minor, closeTo(22 / 12, 0.05));
    });

    test('splits every rung off-centre, with the bond gap between', () {
      final HelixModel model = HelixModel();
      final int rungBase = 2 * model.sampleCount;
      final Set<String> junctions = <String>{};

      for (int r = 0; r < model.rungCount; r++) {
        final int a = rungBase + HelixModel.rungPointStride * r;
        final int midA = a + HelixModel.rungSegments;
        final int midB = a + HelixModel.rungSegments + 1;
        final int b = a + 2 * HelixModel.rungSegments + 1;

        final double span = _gap(model, a, b);
        final double toMidA = _gap(model, a, midA);
        final double toMidB = _gap(model, a, midB);

        expect(toMidA, lessThan(toMidB));
        expect(toMidB, lessThan(span));
        expect(
          toMidB - toMidA,
          closeTo(span * HelixModel.bondGapFraction, 1e-4),
        );

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

      expect(junctions, hasLength(2));
    });

    test('tessellates each half-rung into equal collinear pieces', () {
      final HelixModel model = HelixModel();
      final int rungBase = 2 * model.sampleCount;

      for (int r = 0; r < model.rungCount; r++) {
        final int a = rungBase + HelixModel.rungPointStride * r;

        for (final int start in <int>[a, a + HelixModel.rungSegments + 1]) {
          final int end = start + HelixModel.rungSegments;
          final double whole = _gap(model, start, end);

          double walked = 0;
          for (int k = 0; k < HelixModel.rungSegments; k++) {
            final double piece = _gap(model, start + k, start + k + 1);
            expect(
              piece,
              closeTo(whole / HelixModel.rungSegments, 1e-5),
              reason: 'piece $k of the half starting at $start is uneven',
            );
            walked += piece;
          }

          // Equal pieces that sum to the whole can only be collinear.
          expect(walked, closeTo(whole, 1e-5));
        }
      }
    });

    test('sizes its tables to match the tessellation', () {
      for (final int rungs in <int>[24, 48, 72, 120]) {
        final HelixModel model = HelixModel(rungCount: rungs);
        expect(
          model.pointCount,
          3 * model.sampleCount + HelixModel.rungPointStride * rungs,
        );
        expect(
          model.primitiveCount,
          3 * (model.sampleCount - 1) +
              HelixModel.rungPrimitiveStride * rungs,
        );
      }
    });
  });

  group('HelixModel transcription profile', () {
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

        expect(
          model.trailReveal[freeAt],
          greaterThan(0.3),
          reason: 'the transcript has faded to '
              '${model.trailReveal[freeAt]} by the time it is free',
        );
      });
    }

    test('measures the hybrid against the transcript in bases', () {
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
