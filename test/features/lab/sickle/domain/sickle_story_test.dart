import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/core/biology/gene_record.dart';
import 'package:helixpeek/features/gene_lookup/data/models/gene_record_dto.dart';
import 'package:helixpeek/features/lab/crispr/domain/base_editor.dart';
import 'package:helixpeek/features/lab/crispr/domain/guide_finder.dart';
import 'package:helixpeek/features/lab/mutate/domain/apply_edit.dart';
import 'package:helixpeek/features/lab/sickle/domain/sickle_story.dart';

GeneRecord _gene(String gene) => GeneRecordDto.fromJson(
  jsonDecode(File('test/fixtures/mock/gene_$gene.json').readAsStringSync())
      as Map<String, dynamic>,
).toEntity();

void main() {
  final GeneRecord hbb = _gene('hbb');
  final SickleStory story = SickleStory.of(hbb)!;

  group('the codon the story turns on comes off the record', () {
    test('it is the seventh, and it reads GAG', () {
      expect(hbb.gene, sickleGene);
      expect(story.codon, <int>[5069, 5070, 5071]);
      expect(story.position, 5070);
      expect(story.codonIn(story.reference), 'GAG');
      expect(story.residueIn(story.reference), 'E');
      expect(hbb.protein!.translation[sickleCodon - 1], 'E');
    });

    test('a record that cannot tell it says so instead of telling it', () {
      expect(SickleStory.of(_gene('ins')), isNull);
      final GeneRecord noProtein = GeneRecord(
        gene: sickleGene,
        start: hbb.start,
        end: hbb.end,
        sequence: hbb.sequence,
        exons: hbb.exons,
        peptides: const <Peptide>[],
      );
      expect(SickleStory.of(noProtein), isNull);
    });
  });

  group('chapter two: the change, and what no editor puts back', () {
    test('the sickle change is one base, and the engine reads it', () {
      expect(story.sickleEdit.position, 5070);
      expect(story.sickleEdit.newBase, 'T');
      expect(story.codonIn(story.sickle), 'GTG');
      expect(story.residueIn(story.sickle), 'V');
      expect(story.sickleOutcome.kind, EditOutcomeKind.missense);
      expect(
        (
          story.sickleOutcome.codonIndex,
          story.sickleOutcome.oldResidue,
          story.sickleOutcome.newResidue,
        ),
        (sickleCodon, 'E', 'V'),
      );
      expect(story.sickle.protein!.translation[sickleCodon - 1], 'V');
      // One residue of the chain, and the rest of it untouched.
      expect(
        story.sickle.protein!.translation.length,
        hbb.protein!.translation.length,
      );
    });

    test('no editor writes it back, on either strand', () {
      // T to A as the page draws it, which is A to T on the other strand.
      expect(story.correction, isNull);
      expect(BaseEditor.forChange(from: 'T', to: 'A'), isNull);
      expect(BaseEditor.forChange(from: 'A', to: 'T'), isNull);
    });
  });

  group('chapter three: the Makassar change', () {
    test('an adenine editor writes it, aimed at the other strand', () {
      final ({BaseEditor editor, GuideStrand strand})? editor =
          story.makassarEditor;
      expect(editor?.editor, isA<AdenineBaseEditor>());
      expect(
        editor?.strand,
        GuideStrand.antisense,
        reason: 'the A it deaminates is the one paired with the drawn T',
      );
    });

    test('it turns GTG into GCG, valine into alanine', () {
      expect(story.makassarEdit.position, 5070);
      expect(story.makassarEdit.newBase, 'C');
      expect(story.codonIn(story.makassar), 'GCG');
      expect(story.residueIn(story.makassar), 'A');
      expect(story.makassarOutcome.kind, EditOutcomeKind.missense);
      expect(
        (
          story.makassarOutcome.codonIndex,
          story.makassarOutcome.oldResidue,
          story.makassarOutcome.newResidue,
        ),
        (sickleCodon, 'V', 'A'),
      );
      expect(story.makassar.protein!.translation[sickleCodon - 1], 'A');
      // Made on the sickle record, not on the one the catalog holds.
      expect(story.reference.protein!.translation[sickleCodon - 1], 'E');
    });

    test('no NGG guide puts that base inside an editor’s window', () {
      // Two guides cover it at all, and both hold it outside four to eight:
      // one at place two, one at place nineteen.
      expect(story.reach, hasLength(2));
      expect(story.reach.map((GuideReach r) => r.place), <int>[
        2,
        19,
      ], reason: 'ordered as the finder found the guides');
      expect(story.reach.every((GuideReach r) => !r.inWindow), isTrue);
      expect(story.carriers, isEmpty);
      expect(story.carried, isFalse);
    });

    test('and the guides that reach it are on the strand the editor needs', () {
      // So it is the window that rules them out, not the strand: worth
      // knowing, because it is what a different PAM would fix.
      for (final GuideReach found in story.reach) {
        expect(found.guide.strand, GuideStrand.antisense);
        expect(
          found.guide.protospacer[found.place - 1],
          'A',
          reason: 'the adenine an editor would deaminate',
        );
      }
    });
  });
}
