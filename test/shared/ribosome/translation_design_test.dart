import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/shared/ribosome/translation_painter.dart';
import 'package:helixpeek/shared/ribosome/translation_timeline.dart';

import '../../features/gene_lookup/anatomy/anatomy_fixture.dart';

void main() {
  final TranslationTimeline timeline = TranslationTimeline(insulin());

  test(
    'RNA display and anticodons use uracil without changing coordinates',
    () {
      expect(timeline.rna.length, timeline.mrna.length);
      expect(timeline.rna.contains('T'), isFalse);
      expect(
        timeline.rna.substring(timeline.cdsStart, timeline.cdsStart + 3),
        'AUG',
      );
      expect(
        timeline.rna.substring(
          timeline.stopCodonStart,
          timeline.stopCodonStart + 3,
        ),
        'UAG',
      );
      expect(
        'AUG'.split('').map(TranslationPainter.anticodonBase).join(),
        'UAC',
      );
      expect(
        'GAC'.split('').map(TranslationPainter.anticodonBase).join(),
        'CUG',
      );
      expect(
        timeline.mrna.substring(timeline.cdsStart, timeline.cdsStart + 3),
        'ATG',
      );
    },
  );

  for (final Size size in <Size>[
    const Size(390, 560),
    const Size(366, 418),
    const Size(296, 360),
    const Size(600, 280),
  ]) {
    test(
      'chain stays within $size, including release and the flight origin',
      () {
        for (int i = 0; i <= 240; i++) {
          final TranslationState state = timeline.stateAt(i / 240);
          final List<Offset?> points = TranslationPainter.chainPositions(
            size,
            state,
          );
          expect(points.length, state.residues);
          expect(
            points.whereType<Offset>().length,
            lessThanOrEqualTo(TranslationTimeline.tunnelCapacity + 49),
          );
          for (final Offset point in points.whereType<Offset>()) {
            expect(point.dx.isFinite && point.dy.isFinite, isTrue);
            expect(point.dx, inInclusiveRange(8, size.width - 8));
            expect(point.dy, inInclusiveRange(8, size.height - 8));
          }
        }
        expect(
          TranslationPainter.chainPositions(size, timeline.stateAt(1)).last,
          isNotNull,
        );
      },
    );

    test('chain is continuous across each phase boundary at $size', () {
      for (final double t in timeline.boundaries.where(
        (double t) => t > 0 && t < 1,
      )) {
        final List<Offset?> before = TranslationPainter.chainPositions(
          size,
          timeline.stateAt(t - 1e-8),
        );
        final List<Offset?> after = TranslationPainter.chainPositions(
          size,
          timeline.stateAt(t + 1e-8),
        );
        for (int i = 0; i < math.min(before.length, after.length); i++) {
          if (before[i] != null && after[i] != null) {
            expect(
              (before[i]! - after[i]!).distance,
              lessThan(0.1),
              reason: 't=$t, residue=$i',
            );
          }
        }
      }
    });
  }

  test(
    'floating chain is deterministic and moves while a codon is decoded',
    () {
      final double beat = timeline.beatOfCodon(75).toDouble();
      final TranslationState first = timeline.stateAt(
        timeline.beatStart(beat + 0.05),
      );
      final TranslationState later = timeline.stateAt(
        timeline.beatStart(beat + 0.3),
      );
      const Size size = Size(390, 560);
      final List<Offset?> a = TranslationPainter.chainPositions(size, first);
      final List<Offset?> b = TranslationPainter.chainPositions(size, later);
      expect(a, TranslationPainter.chainPositions(size, first));
      final int external =
          first.residues - TranslationTimeline.tunnelCapacity - 8;
      expect((a[external]! - b[external]!).distance, greaterThan(0.02));
      expect((a.last! - b.last!).distance, lessThan(0.001));
    },
  );
}
