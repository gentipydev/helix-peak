import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/core/biology/gene_record.dart';
import 'package:helixpeek/features/gene_lookup/data/models/gene_record_dto.dart';
import 'package:helixpeek/features/lab/crispr/domain/base_editor.dart';
import 'package:helixpeek/features/lab/crispr/domain/guide_finder.dart';
import 'package:helixpeek/features/lab/crispr/domain/repair.dart';
import 'package:helixpeek/features/lab/mutate/domain/apply_edit.dart';

GeneRecord _gene(String gene) => GeneRecordDto.fromJson(
  jsonDecode(File('test/fixtures/mock/gene_$gene.json').readAsStringSync())
      as Map<String, dynamic>,
).toEntity();

String _baseAt(GeneRecord record, int position) =>
    record.sequence[record.strand == -1
        ? record.end - position
        : position - record.start];

Guide _guideFrom(GeneRecord record, int from, GuideStrand strand) =>
    GuideFinder.find(record)
        .firstWhere((Guide g) => g.from == from && g.strand == strand);

void main() {
  final GeneRecord insulin = _gene('ins');

  // TACCTAGTGTGCGGGGAACG, PAM AGG, bases 5341 to 5360, cutting before 5358.
  final Guide sense = _guideFrom(insulin, 5341, GuideStrand.sense);

  // CTGATGCAGCCTGTCCTGGA, PAM GGG, reading down from 5010 to 4991, cutting
  // before 4994.
  final Guide antisense = _guideFrom(insulin, 4991, GuideStrand.antisense);

  group('end joining offers several outcomes, not one', () {
    final List<Repair> outcomes = endJoiningOutcomes(insulin, sense);

    test('four of them, each an edit at the cut', () {
      expect(outcomes, hasLength(4));
      expect(
        outcomes.map((Repair r) => r.path),
        everyElement(RepairPath.endJoining),
      );
      expect(outcomes.map((Repair r) => r.guide), everyElement(sense));
      expect(
        outcomes.map((Repair r) => r.editor),
        everyElement(isNull),
        reason: 'no editor wrote these',
      );
    });

    test('the base 5\' of the break, copied into it', () {
      final Insertion gained = outcomes.first.edit as Insertion;
      expect(gained.position, sense.cutPosition);
      expect(gained.bases, _baseAt(insulin, 5357));
      expect(gained.bases, 'A');
    });

    test('one base lost, a codon lost, and a deletion across the cut', () {
      expect(
        <(int, int)>[
          for (final Repair repair in outcomes.skip(1))
            (
              (repair.edit as Deletion).position,
              (repair.edit as Deletion).length,
            ),
        ],
        <(int, int)>[(5358, 1), (5358, 3), (5356, 5)],
      );
    });

    test('every base they touch is one the guide itself binds', () {
      for (final Repair repair in outcomes) {
        final SequenceEdit edit = repair.edit;
        final int last = switch (edit) {
          Deletion(:final int position, :final int length) =>
            position + (length - 1) * sense.step,
          _ => edit.position,
        };
        for (final int position in <int>[edit.position, last]) {
          expect(
            (position - sense.siteFrom) * sense.step,
            greaterThanOrEqualTo(0),
            reason: '$repair',
          );
          expect(
            (sense.siteTo - position) * sense.step,
            greaterThanOrEqualTo(0),
            reason: '$repair',
          );
        }
      }
    });

    test('the engine makes each of them, and says what each does', () {
      for (final Repair repair in outcomes) {
        final GeneRecord edited = applyEdit(insulin, repair.edit);
        expect(edited.sequence, isNot(insulin.sequence), reason: '$repair');
        expect(classify(insulin, repair.edit).kind, isNotNull);
      }
      // The cut sits in the coding sequence, so a base either way leaves the
      // frame and three keep it.
      expect(
        classify(insulin, outcomes[1].edit).kind,
        EditOutcomeKind.frameshift,
      );
      expect(
        classify(insulin, outcomes[2].edit).kind,
        EditOutcomeKind.inFrameIndel,
      );
    });

    test('and on an antisense guide, where the record reads the other way', () {
      final List<Repair> outcomes = endJoiningOutcomes(insulin, antisense);
      final Insertion gained = outcomes.first.edit as Insertion;
      expect(gained.position, 4994);
      expect(gained.bases, _baseAt(insulin, 4993));
      expect((outcomes.last.edit as Deletion).position, 4992);
      for (final Repair repair in outcomes) {
        expect(() => applyEdit(insulin, repair.edit), returnsNormally);
      }
    });
  });

  group('homology-directed repair takes the change it is given', () {
    test('a change at the cut, and one at the edge of its reach', () {
      for (final int away in <int>[0, hdrReach, -hdrReach]) {
        final int position = sense.positionFromCut(away);
        final Repair? repair = homologyDirected(
          sense,
          Substitution(position, 'A'),
        );
        expect(repair?.path, RepairPath.homologyDirected, reason: '$away');
        expect(repair?.edit.position, position);
      }
    });

    test('a change further off is not this cut’s to make', () {
      final int tooFar = sense.positionFromCut(hdrReach + 1);
      expect(homologyDirected(sense, Substitution(tooFar, 'A')), isNull);
      expect(
        homologyDirected(sense, Insertion(sense.positionFromCut(-11), 'A')),
        isNull,
      );
    });

    test('it takes an insertion or a deletion as readily as a base', () {
      expect(
        homologyDirected(sense, const Insertion(5358, 'GAT'))?.edit,
        isA<Insertion>(),
      );
      expect(
        homologyDirected(sense, const Deletion(5358, 6))?.edit,
        isA<Deletion>(),
      );
    });

    test('the positions offered are the ones either side of the cut', () {
      final List<int> positions = hdrPositions(insulin, sense);
      expect(positions, hasLength(2 * hdrReach + 1));
      expect(positions.first, sense.positionFromCut(-hdrReach));
      expect(positions.last, sense.positionFromCut(hdrReach));
      expect(positions, contains(sense.cutPosition));
      // In the order the record reads them.
      for (int i = 1; i < positions.length; i++) {
        expect(positions[i] - positions[i - 1], sense.step);
      }
    });

    test('and on a minus-strand record they run down the coordinates', () {
      final GeneRecord relaxin = _gene('rln2');
      final Guide guide = GuideFinder.find(relaxin).first;
      final List<int> positions = hdrPositions(relaxin, guide);
      expect(positions, hasLength(2 * hdrReach + 1));
      expect(positions.first, greaterThan(positions.last));
    });

    test('a position the record does not really hold is not offered', () {
      final GeneRecord cftr = _gene('cftr');
      final List<Guide> guides = GuideFinder.find(cftr);
      // Seven of CFTR's 496 guides cut within ten bases of an intron drawn
      // shortened, and reach into it.
      final List<Guide> trimmed = guides
          .where((Guide g) => hdrPositions(cftr, g).length < 2 * hdrReach + 1)
          .toList();
      expect(trimmed, hasLength(7));

      for (final Guide guide in trimmed) {
        final List<int> offered = hdrPositions(cftr, guide);
        expect(offered, isNotEmpty);
        for (int away = -hdrReach; away <= hdrReach; away++) {
          final int position = guide.positionFromCut(away);
          final bool inside =
              position >= cftr.start &&
              position <= cftr.end &&
              EditEligibility.of(cftr, position) is Eligible;
          expect(
            offered.contains(position),
            inside,
            reason: 'base $position, $guide',
          );
        }
      }
    });
  });

  group('a base editor rewrites inside its guide’s window', () {
    test('a sense guide: the editor’s own bases, where the window holds '
        'them', () {
      // Bases four to eight of TACCTAGTGTGCGGGGAACG read C, T, A, G, T.
      expect(
        baseEdits(sense, const AdenineBaseEditor()).map(
          (Repair r) =>
              (r.place, r.edit.position, (r.edit as Substitution).newBase),
        ),
        <(int?, int, String)>[(6, 5346, 'G')],
      );
      expect(
        baseEdits(sense, const CytosineBaseEditor()).map(
          (Repair r) =>
              (r.place, r.edit.position, (r.edit as Substitution).newBase),
        ),
        <(int?, int, String)>[(4, 5344, 'T')],
      );
      expect(
        baseEdits(sense, const CytosineToGuanineBaseEditor()).single.edit,
        isA<Substitution>()
            .having((Substitution s) => s.position, 'position', 5344)
            .having((Substitution s) => s.newBase, 'newBase', 'G'),
      );
      // Each one rewrites the base the page draws there.
      expect(_baseAt(insulin, 5346), 'A');
      expect(_baseAt(insulin, 5344), 'C');
    });

    test('an antisense guide: written as the page draws it', () {
      // The editor still deaminates an A on its own strand; the page draws the
      // T that pairs with it, and reads a C once it is done.
      final List<Repair> edits = baseEdits(
        antisense,
        const AdenineBaseEditor(),
      );
      expect(
        edits.map(
          (Repair r) =>
              (r.place, r.edit.position, (r.edit as Substitution).newBase),
        ),
        <(int?, int, String)>[(4, 5007, 'C'), (8, 5003, 'C')],
      );
      expect(_baseAt(insulin, 5007), 'T');
      expect(_baseAt(insulin, 5003), 'T');
      expect(antisense.protospacer[3], 'A');
    });

    test('a window with two of its substrate is two bases written, not a '
        'choice of one', () {
      expect(baseEdits(antisense, const AdenineBaseEditor()), hasLength(2));
      // Which is the whole reason the screen has to say so: both are inside
      // one window, and one deaminase reaches both.
      for (final Repair repair in baseEdits(
        antisense,
        const AdenineBaseEditor(),
      )) {
        expect(
          repair.place,
          inInclusiveRange(BaseEditor.windowFrom, BaseEditor.windowTo),
        );
      }
    });

    test('nothing is offered where the window holds no substrate', () {
      final Guide guide = GuideFinder.find(insulin).firstWhere(
        (Guide g) => !g.protospacer
            .substring(BaseEditor.windowFrom - 1, BaseEditor.windowTo)
            .contains('A'),
      );
      expect(baseEdits(guide, const AdenineBaseEditor()), isEmpty);
    });

    test('the editor and the place it wrote are carried with the edit', () {
      final Repair repair = baseEdits(sense, const AdenineBaseEditor()).single;
      expect(repair.path, RepairPath.baseEditing);
      expect(repair.editor, isA<AdenineBaseEditor>());
      expect(repair.guide, sense);
      expect(repair.place, 6);
      expect(classify(insulin, repair.edit).kind, isNotNull);
    });
  });

  group('every repair is an edit the engine will make', () {
    test('over the first forty guides insulin offers', () {
      // Every base a repair touches lies inside the guide's own twenty-three,
      // so an outcome the finder offers is never one applyEdit refuses.
      for (final Guide guide in GuideFinder.find(insulin).take(40)) {
        final List<Repair> repairs = <Repair>[
          ...endJoiningOutcomes(insulin, guide),
          for (final BaseEditor editor in BaseEditor.all)
            ...baseEdits(guide, editor),
          if (homologyDirected(guide, Substitution(guide.cutPosition, 'A'))
              case final Repair written)
            written,
        ];
        expect(repairs, hasLength(greaterThan(4)), reason: '$guide');
        for (final Repair repair in repairs) {
          expect(
            () => applyEdit(insulin, repair.edit),
            returnsNormally,
            reason: '$repair',
          );
          expect(
            () => classify(insulin, repair.edit),
            returnsNormally,
            reason: '$repair',
          );
        }
      }
    });
  });
}
