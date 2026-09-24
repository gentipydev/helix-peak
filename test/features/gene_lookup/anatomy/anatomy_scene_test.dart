import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/features/gene_lookup/presentation/anatomy/anatomy_scene.dart';
import 'package:helixpeek/features/gene_lookup/presentation/anatomy/anatomy_stages.dart';

import 'anatomy_fixture.dart';

const Size _canvas = Size(342, 410);

void main() {
  final AnatomyModel model = AnatomyModel.derive(insulin());

  AnatomyScene forward(int from) => AnatomyScene.between(
    model: model,
    fromIndex: from,
    toIndex: from + 1,
    canvas: _canvas,
    viewport: _canvas,
  );

  group('the pairing', () {
    test('forward is always subtractive — nothing appears from nowhere', () {
      for (int i = 0; i < model.stages.length - 1; i++) {
        final AnatomyScene scene = forward(i);
        final Set<int> landed = <int>{
          for (final int t in scene.target)
            if (t >= 0) t,
        };
        expect(
          landed.length,
          scene.to.count,
          reason:
              'every cell of ${scene.to.label} must be accounted for by '
              '${scene.from.label}',
        );
      }
    });

    test('exactly one cell of a merging group carries the letter', () {
      for (int i = 0; i < model.stages.length - 1; i++) {
        final AnatomyScene scene = forward(i);
        int carriers = 0;
        for (int c = 0; c < scene.from.count; c++) {
          if (scene.carriesLetter[c] == 1) {
            carriers++;
            expect(scene.target[c], isNot(-1));
          }
        }
        expect(carriers, scene.to.count);
      }
    });

    test('splicing drops the 966 intron bases and moves the other 465', () {
      final AnatomyScene scene = forward(0);
      final int leaving = scene.target.where((int t) => t < 0).length;
      expect(leaving, 966);
      expect(scene.from.count - leaving, 465);
    });

    test('translation drops the two UTRs and the stop codon together', () {
      // One transition now, where there used to be two. The 132 untranslated
      // bases and the three of the stop codon leave on the same beat, which is
      // exactly what the page above it draws: the ends are already quiet, so
      // what leaves is what was already marked as leaving.
      final AnatomyScene scene = forward(1);
      final List<int> leaving = <int>[
        for (int c = 0; c < scene.from.count; c++)
          if (scene.target[c] < 0) scene.from.positionAt(c),
      ];
      expect(leaving, hasLength(135));

      final int untranslated = leaving
          .where(
            (int p) => <RoleKind>{
              RoleKind.utr5,
              RoleKind.utr3,
            }.contains(model.codingRoleAt(p)?.kind),
          )
          .length;
      expect(untranslated, 132);
      expect(
        leaving.where(
          (int p) => model.codingRoleAt(p)?.kind == RoleKind.stopCodon,
        ),
        hasLength(3),
      );
    });

    test('translation merges three cells into one, 110 times over', () {
      final AnatomyScene scene = forward(1);
      final Map<int, int> sources = <int, int>{};
      for (final int t in scene.target) {
        if (t >= 0) {
          sources[t] = (sources[t] ?? 0) + 1;
        }
      }
      expect(sources.length, 110);
      expect(sources.values.every((int n) => n == 3), isTrue);
    });

    test('cleavage removes the signal peptide and the two cut sites at once', () {
      // 24 + 4, in one swipe. They used to be two, and the first of them was a
      // page that showed nothing happening: the precursor arrived already
      // twenty-four residues shorter than the page before it. Both cuts leave
      // in front of the reader now, and the pairing needed no change to do it —
      // a cell leaves when the next stage has no cell for its position, and
      // that was already true of every one of these twenty-eight.
      expect(forward(2).target.where((int t) => t < 0).length, 28);
    });
  });

  group('colour', () {
    test('a cell changes colour only where the page changes its subject', () {
      // Twice, and only twice, and now they are the first two: splicing hands
      // the reader from a map of regions to a sequence, and translation hands
      // them from a sequence to a chain of residues. Every transition after
      // that is the same subject, fewer of it, and a cell that changed colour
      // there would be claiming something happened.
      final List<int> changing = <int>[
        for (int i = 0; i < model.stages.length - 1; i++)
          if (forward(i).usedPairs.any(
            (int pair) => pair ~/ CellSlot.count != pair % CellSlot.count,
          ))
            i,
      ];
      expect(changing, <int>[0, 1]);
    });

    test('the cut sites are coloured by meaning, not by letter', () {
      final AnatomyScene protein = AnatomyScene.resting(
        model: model,
        index: 2,
        canvas: _canvas,
        viewport: _canvas,
      );
      final AnatomyStage stage = model.stages[2];

      // Residues 55 and 56 are the RR pair. Both are arginine; neither is
      // coloured as an ordinary basic residue.
      for (final int cell in <int>[54, 55, 87, 88]) {
        expect(stage.letters[cell], anyOf('R', 'K'));
        expect(protein.slotPair[cell] % CellSlot.count, CellSlot.dibasic);
      }
      // ...while an arginine that is not a cut site is positive as usual.
      final int plainArginine = <int>[
        for (int c = 0; c < stage.count; c++)
          if (stage.letters[c] == 'R' &&
              model.codingRoleAt(stage.positionAt(c))?.kind !=
                  RoleKind.dibasic)
            c,
      ].first;
      expect(
        protein.slotPair[plainArginine] % CellSlot.count,
        CellSlot.positive,
      );
    });

    test('an untranslated base keeps its own colour, washed back', () {
      final AnatomyScene mrna = AnatomyScene.resting(
        model: model,
        index: 1,
        canvas: _canvas,
        viewport: _canvas,
      );
      final AnatomyStage stage = model.stages[1];

      for (int cell = 0; cell < stage.count; cell++) {
        final bool framed = stage.blocks[stage.blockOf(cell)].framed;
        final int slot = mrna.slotPair[cell] % CellSlot.count;
        // The frame's own two ends are the exception, and the only one: those
        // six give their letter's colour up to a fill that says what they are
        // for. Everything between them is still an A or a G.
        if (stage.codonMarkAt(cell) != CodonMark.none) {
          expect(
            slot,
            anyOf(CellSlot.frameStart, CellSlot.frameStop),
            reason: 'cell $cell is an end of the reading frame',
          );
          continue;
        }
        expect(
          slot >= CellSlot.adenineDim,
          !framed,
          reason: 'cell $cell is ${framed ? 'coding' : 'untranslated'}',
        );
        // Dim is the same four colours, not a fifth one: an A in the 5' UTR is
        // still drawn as an A, which is what makes the coding sequence read as
        // the part that is *read* rather than the only part that is there.
        expect(
          framed ? slot : slot - CellSlot.dimOffset,
          CellSlot.forBase(stage.letters[cell]),
          reason: 'cell $cell reads ${stage.letters[cell]}',
        );
      }
    });

    test('a nucleotide cell is coloured by which piece of the gene it is', () {
      final AnatomyScene gene = forward(0);
      final AnatomyStage stage = model.stages[0];

      int slotAt(int position) =>
          gene.slotPair[stage.cellAt(position)] ~/ CellSlot.count;

      expect(slotAt(6000), CellSlot.intron, reason: 'intron 2');
      expect(slotAt(4986), CellSlot.utr5, reason: 'the 5′ UTR');
      expect(slotAt(5224), CellSlot.signalPeptide);
      expect(slotAt(5301), CellSlot.mature1, reason: 'insulin B chain');
      expect(slotAt(5392), CellSlot.mature2, reason: 'C-peptide');
      expect(slotAt(6278), CellSlot.mature3, reason: 'insulin A chain');
      expect(slotAt(5386), CellSlot.dibasic, reason: 'the RR site');
      expect(slotAt(6341), CellSlot.stopCodon);
    });

    test('the 966 intron cells are the 966 that leave at the splice', () {
      final AnatomyScene gene = forward(0);
      final int introns = <int>[
        for (int c = 0; c < gene.from.count; c++)
          if (gene.slotPair[c] ~/ CellSlot.count == CellSlot.intron) c,
      ].length;
      expect(introns, 966);
      expect(
        introns,
        gene.target.where((int t) => t < 0).length,
        reason: 'the cells drawn as intron are exactly the cells about to go',
      );
    });

    test('no intron colour survives the splice', () {
      final AnatomyScene mrna = forward(1);
      for (int c = 0; c < mrna.from.count; c++) {
        expect(mrna.slotPair[c] ~/ CellSlot.count, isNot(CellSlot.intron));
      }
    });

    test('the three mature chains are told apart, not merged', () {
      final AnatomyScene gene = forward(0);
      final AnatomyStage stage = model.stages[0];
      int slotAt(int p) => gene.slotPair[stage.cellAt(p)] ~/ CellSlot.count;
      // B and A chain are one molecule; what sits between them is discarded.
      expect(slotAt(5301), isNot(slotAt(5392)));
      expect(slotAt(6278), isNot(slotAt(5392)));
      expect(slotAt(5301), isNot(slotAt(6278)));
    });
  });

  group('resting', () {
    test('a resting scene is the identity, so there is one code path', () {
      for (int i = 0; i < model.stages.length; i++) {
        final AnatomyScene scene = AnatomyScene.resting(
          model: model,
          index: i,
          canvas: _canvas,
          viewport: _canvas,
        );
        expect(scene.isTransition, isFalse);
        expect(scene.fromLayout, scene.toLayout);
        for (int c = 0; c < scene.from.count; c++) {
          expect(scene.target[c], c);
          expect(scene.carriesLetter[c], 1);
        }
      }
    });
  });

  group('a page left mid-scroll', () {
    // The screen puts the scroll back to zero as a swipe starts, so whichever
    // page is being left has to be drawn where the reader had scrolled it, or a
    // long protein would set off from its own top.
    const double offset = 240;

    AnatomyScene between(int from, {double source = 0, double target = 0}) =>
        AnatomyScene.between(
          model: model,
          fromIndex: from,
          toIndex: from + 1,
          canvas: _canvas,
          viewport: _canvas,
          sourceScrollOffset: source,
          targetScrollOffset: target,
        );

    test('forward, the page being left is raised by its offset', () {
      for (final int from in <int>[0, 2]) {
        final AnatomyScene still = between(from);
        final AnatomyScene raised = between(from, source: offset);
        for (final int i in <int>[0, still.from.count ~/ 2, still.from.count - 1]) {
          expect(
            raised.fromLayout.centreOf(i),
            still.fromLayout.centreOf(i) - const Offset(0, offset),
            reason: '${still.from.label} cell $i',
          );
        }
        expect(raised.toLayout.origin, still.toLayout.origin);
      }
    });

    test('back, the page being left is the later one', () {
      final AnatomyScene still = between(2);
      final AnatomyScene raised = between(2, target: offset);
      expect(
        raised.toLayout.centreOf(0),
        still.toLayout.centreOf(0) - const Offset(0, offset),
      );
      expect(raised.fromLayout.origin, still.fromLayout.origin);
    });

    test('translation carries its own offset rather than a raised layout', () {
      final AnatomyScene still = between(1);
      final AnatomyScene raised = between(1, source: offset);
      expect(raised.translation, isNotNull);
      expect(raised.translation!.sourceScrollOffset, offset);
      expect(raised.fromLayout.origin, still.fromLayout.origin);
    });
  });
}
