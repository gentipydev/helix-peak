import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/features/gene_lookup/presentation/anatomy/anatomy_scene.dart';
import 'package:helixpeek/features/gene_lookup/presentation/anatomy/anatomy_stages.dart';
import 'package:helixpeek/features/gene_lookup/presentation/anatomy/anatomy_translation.dart';

import 'anatomy_fixture.dart';

void main() {
  final AnatomyModel model = AnatomyModel.derive(insulin());

  AnatomyScene scene(Size viewport, {double scroll = 0}) =>
      AnatomyScene.between(
        model: model,
        fromIndex: 1,
        toIndex: 2,
        canvas: Size(viewport.width, 1000),
        viewport: viewport,
        sourceScrollOffset: scroll,
      );

  test(
    'only translated bases join a codon, including across exon boundaries',
    () {
      final AnatomyScene transition = scene(const Size(390, 650));
      final AnatomyTranslation motion = transition.translation!;
      expect(motion.bases, hasLength(110));
      final Set<int> seen = <int>{};
      for (int residue = 0; residue < motion.bases.length; residue++) {
        expect(motion.bases[residue], hasLength(3));
        for (final int cell in motion.bases[residue]) {
          expect(seen.add(cell), isTrue);
          expect(
            transition.to.cellAt(transition.from.positionAt(cell)),
            residue,
          );
        }
      }
      expect(seen, hasLength(330));
      final List<int> removed = <int>[
        for (int cell = 0; cell < transition.from.count; cell++)
          if (!seen.contains(cell)) cell,
      ];
      expect(removed, hasLength(135));
      expect(removed.every((int cell) => transition.target[cell] < 0), isTrue);
    },
  );

  test('removal, letter swap and reflow never compete', () {
    final AnatomyTranslation motion = scene(const Size(390, 650)).translation!;
    for (int frame = 0; frame <= 300; frame++) {
      final double t = frame / 300;
      final double reflow = AnatomyTranslation.reflow(t);
      if (reflow > 0 && reflow < 1) {
        expect(
          AnatomyTranslation.residueInk(t),
          0,
          reason: 'letters must not overlap when row order changes',
        );
      }
      for (int residue = 0; residue < motion.bases.length; residue++) {
        final double swap = motion.swap(residue, t);
        if (swap > 0) {
          expect(
            AnatomyTranslation.removal(t),
            1,
            reason: 'UTRs must leave before codons fold',
          );
        }
        if (AnatomyTranslation.reveal(swap) > 0) {
          expect(AnatomyTranslation.baseInk(swap), 0);
          expect(
            AnatomyTranslation.baseOpacity(swap),
            0,
            reason: 'one amino acid must not sit on three visible bases',
          );
        }
        if (AnatomyTranslation.reflow(t) > 0) {
          expect(
            AnatomyTranslation.reveal(swap),
            1,
            reason: 'only completed residues travel into the protein grid',
          );
        }
      }
    }
  });

  for (final Size viewport in <Size>[
    const Size(320, 480),
    const Size(390, 650),
    const Size(768, 850),
  ]) {
    test('continuous endpoints and local folding at ${viewport.width}px', () {
      final AnatomyScene transition = scene(viewport, scroll: 180);
      final AnatomyTranslation motion = transition.translation!;
      for (int cell = 0; cell < transition.from.count; cell++) {
        expect(
          (transition.positionOf(cell, 0) -
                  (transition.fromLayout.centreOf(cell) - const Offset(0, 180)))
              .distance,
          lessThan(1e-8),
        );
        final int residue = transition.target[cell];
        if (residue < 0) {
          continue;
        }
        expect(
          (transition.positionOf(cell, 1) -
                  transition.toLayout.centreOf(residue))
              .distance,
          lessThan(1e-8),
        );
        // Once folded, all three bases share one centre, before any reflow.
        expect(
          (transition.positionOf(cell, 0.72) - motion.centreOf(residue, 0.72))
              .distance,
          lessThan(1e-8),
        );
        // During the swap, members stay on the same row. No diagonal flight
        // can mix a base with a neighbouring codon.
        expect(
          transition.positionOf(cell, 0.48).dy,
          closeTo(motion.centreOf(residue, 0.48).dy, 1e-8),
        );
      }
    });
  }
}
