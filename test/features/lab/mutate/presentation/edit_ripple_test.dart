import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/core/biology/gene_record.dart';
import 'package:helixpeek/features/gene_lookup/data/models/gene_record_dto.dart';
import 'package:helixpeek/features/lab/mutate/domain/apply_edit.dart';
import 'package:helixpeek/features/lab/mutate/presentation/edit_ripple.dart';
import 'package:helixpeek/features/lab/mutate/presentation/outcome_sentence.dart';
import 'package:helixpeek/shared/anatomy/anatomy_scene.dart';
import 'package:helixpeek/shared/anatomy/anatomy_stages.dart';

GeneRecord _gene(String gene) => GeneRecordDto.fromJson(
  jsonDecode(File('test/fixtures/mock/gene_$gene.json').readAsStringSync())
      as Map<String, dynamic>,
).toEntity();

/// The insulin edits the engine's own tests name, one per outcome.
const Map<EditOutcomeKind, SequenceEdit> _insulinEdits =
    <EditOutcomeKind, SequenceEdit>{
      EditOutcomeKind.synonymous: Substitution(5229, 'T'),
      EditOutcomeKind.missense: Substitution(5368, 'C'),
      EditOutcomeKind.nonsense: Substitution(6334, 'A'),
      EditOutcomeKind.mrnaDegraded: Substitution(5352, 'A'),
      EditOutcomeKind.frameshift: Insertion(6308, 'A'),
      EditOutcomeKind.inFrameIndel: Deletion(5401, 3),
      EditOutcomeKind.stopLoss: Substitution(6341, 'C'),
      EditOutcomeKind.spliceSite: Substitution(5411, 'A'),
      EditOutcomeKind.intronic: Substitution(5800, 'A'),
      EditOutcomeKind.utr: Substitution(5000, 'A'),
    };

void main() {
  final GeneRecord insulin = _gene('ins');
  final String protein = insulin.protein!.translation;
  const Size viewport = Size(390, 600);

  ({GeneRecord record, EditOutcome outcome}) made(SequenceEdit edit) => (
    record: applyEdit(insulin, edit),
    outcome: classify(insulin, edit),
  );

  test('the engine gives each named edit the outcome it is named for', () {
    for (final MapEntry<EditOutcomeKind, SequenceEdit> e
        in _insulinEdits.entries) {
      expect(classify(insulin, e.value).kind, e.key, reason: '${e.key}');
    }
  });

  group('where each residue goes', () {
    Int32List targets(SequenceEdit edit) {
      final (:GeneRecord record, :EditOutcome outcome) = made(edit);
      return rippleTargets(
        before: protein,
        after: record.protein!.translation,
        outcome: outcome,
      );
    }

    test('a missense keeps every residue in its place', () {
      final Int32List t = targets(_insulinEdits[EditOutcomeKind.missense]!);
      for (int i = 0; i < t.length; i++) {
        expect(t[i], i);
      }
    });

    test('a nonsense loses every residue past the new stop, and only those', () {
      final Int32List t = targets(_insulinEdits[EditOutcomeKind.nonsense]!);
      // Tyrosine 108 becomes the stop: 107 residues remain of 110.
      expect(t.length, 110);
      expect(t.take(107), <int>[for (int i = 0; i < 107; i++) i]);
      expect(t.skip(107), everyElement(-1));
    });

    test('an in-frame deletion loses one residue and closes the gap', () {
      final (:GeneRecord record, :EditOutcome outcome) = made(
        _insulinEdits[EditOutcomeKind.inFrameIndel]!,
      );
      final Int32List t = rippleTargets(
        before: protein,
        after: record.protein!.translation,
        outcome: outcome,
      );
      final int first = outcome.codonIndex! - 1;
      expect(t.where((int x) => x < 0), hasLength(1));
      expect(t[first], -1);
      for (int i = first + 1; i < t.length; i++) {
        expect(t[i], i - 1);
      }
    });

    test('no residue lands past the edited protein or twice', () {
      for (final SequenceEdit edit in _insulinEdits.values) {
        final (:GeneRecord record, :EditOutcome outcome) = made(edit);
        final String after = record.protein?.translation ?? '';
        final Int32List t = rippleTargets(
          before: protein,
          after: after,
          outcome: outcome,
        );
        final List<int> landed = <int>[
          for (final int x in t)
            if (x >= 0) x,
        ];
        expect(landed.every((int x) => x < after.length), isTrue);
        expect(landed.toSet().length, landed.length);
      }
    });
  });

  group('the ripple scene', () {
    final AnatomyModel before = AnatomyModel.derive(insulin);

    test('is the walk’s protein page turning into the edited one', () {
      final (:GeneRecord record, :EditOutcome outcome) = made(
        _insulinEdits[EditOutcomeKind.nonsense]!,
      );
      final AnatomyModel after = AnatomyModel.derive(record);
      final AnatomyScene scene = editRipple(
        before: before,
        after: after,
        target: rippleTargets(
          before: protein,
          after: record.protein!.translation,
          outcome: outcome,
        ),
        viewport: viewport,
      );
      expect(scene.isTransition, isTrue);
      expect(scene.translation, isNull);
      expect(scene.from.kind, StageKind.protein);
      expect(scene.to.kind, StageKind.protein);
      expect(scene.from.letters, protein);
      expect(scene.to.letters, record.protein!.translation);
      expect(scene.target.where((int x) => x < 0), hasLength(3));
    });

    test('lost residues drift and shrink away, the 5′ end first', () {
      final (:GeneRecord record, :EditOutcome outcome) = made(
        _insulinEdits[EditOutcomeKind.nonsense]!,
      );
      final AnatomyScene scene = editRipple(
        before: before,
        after: AnatomyModel.derive(record),
        target: rippleTargets(
          before: protein,
          after: record.protein!.translation,
          outcome: outcome,
        ),
        viewport: viewport,
      );
      // The three lost residues leave where they stood, and the one nearest
      // the 5′ end sets off first: at the same moment it has travelled
      // further than the last.
      double travelled(int cell, double t) =>
          (scene.positionOf(cell, t) - scene.positionOf(cell, 0)).distance;
      expect(travelled(107, 1), greaterThan(0));
      expect(travelled(107, 0.5), greaterThan(travelled(109, 0.5)));
    });

    test('takes every colour from the resting scenes, not a table of its own', () {
      final (:GeneRecord record, :EditOutcome outcome) = made(
        _insulinEdits[EditOutcomeKind.missense]!,
      );
      final AnatomyModel after = AnatomyModel.derive(record);
      final AnatomyScene scene = editRipple(
        before: before,
        after: after,
        target: rippleTargets(
          before: protein,
          after: record.protein!.translation,
          outcome: outcome,
        ),
        viewport: viewport,
      );
      final int proteinIndex = proteinStageOf(before);
      final AnatomyScene was = AnatomyScene.resting(
        model: before,
        index: proteinIndex,
        canvas: scene.canvas,
        viewport: viewport,
      );
      final AnatomyScene now = AnatomyScene.resting(
        model: after,
        index: proteinStageOf(after),
        canvas: scene.canvas,
        viewport: viewport,
      );
      final int changed = outcome.codonIndex! - 1;
      for (int cell = 0; cell < protein.length; cell++) {
        expect(
          scene.slotPair[cell] ~/ CellSlot.count,
          was.slotPair[cell] ~/ CellSlot.count,
        );
        expect(
          scene.slotPair[cell] % CellSlot.count,
          now.slotPair[cell] % CellSlot.count,
        );
      }
      expect(
        scene.slotPair[changed] ~/ CellSlot.count,
        isNot(scene.slotPair[changed] % CellSlot.count),
        reason: 'phenylalanine and leucine are coloured apart',
      );
    });
  });

  group('the sentence an edit gets', () {
    test('every outcome has one, built from the record', () {
      for (final MapEntry<EditOutcomeKind, SequenceEdit> e
          in _insulinEdits.entries) {
        final (:GeneRecord record, :EditOutcome outcome) = made(e.value);
        final String sentence = outcomeSentence(
          outcome,
          before: insulin,
          after: record,
        );
        expect(sentence, isNotEmpty, reason: '${e.key}');
        expect(sentence, endsWith('.'), reason: '${e.key}');
      }
    });

    test('says what the codons read, with the record’s own numbers', () {
      String of(EditOutcomeKind kind) {
        final (:GeneRecord record, :EditOutcome outcome) = made(
          _insulinEdits[kind]!,
        );
        return outcomeSentence(outcome, before: insulin, after: record);
      }

      expect(
        of(EditOutcomeKind.missense),
        'Codon 49 now reads leucine where it read phenylalanine: one residue '
        'of 110 changes.',
      );
      expect(
        of(EditOutcomeKind.nonsense),
        'Codon 108 is now a stop, so the protein ends after 107 of its 110 '
        'residues.',
      );
      expect(of(EditOutcomeKind.synonymous), contains('still reads alanine'));
      expect(of(EditOutcomeKind.mrnaDegraded), contains('nonsense-mediated'));
      expect(of(EditOutcomeKind.mrnaDegraded), contains('Codon 43'));
    });

    test('never names a gene or a protein, and never a condition', () {
      for (final SequenceEdit edit in _insulinEdits.values) {
        final (:GeneRecord record, :EditOutcome outcome) = made(edit);
        final String sentence = outcomeSentence(
          outcome,
          before: insulin,
          after: record,
        ).toLowerCase();
        for (final String word in <String>[
          'insulin',
          'ins ',
          'disease',
          'pathogenic',
          'benign',
          'causes',
          'diabetes',
        ]) {
          expect(sentence, isNot(contains(word)), reason: sentence);
        }
      }
    });
  });
}
