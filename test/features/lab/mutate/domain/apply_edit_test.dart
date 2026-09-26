import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/core/biology/gene_record.dart';
import 'package:helixpeek/core/biology/genetic_code.dart';
import 'package:helixpeek/features/gene_lookup/data/models/gene_record_dto.dart';
import 'package:helixpeek/features/lab/mutate/domain/apply_edit.dart';

GeneRecord _record(String file) => GeneRecordDto.fromJson(
  jsonDecode(File(file).readAsStringSync()) as Map<String, dynamic>,
).toEntity();

GeneRecord _gene(String gene) => _record('test/fixtures/mock/gene_$gene.json');

// The test's own reading of a record, written separately from the engine's so
// that the two can be held against each other.

/// A feature's record positions, 5' to 3' on the gene's own strand.
List<int> _positions(GeneRecord record, List<Segment> segments) {
  final bool minus = record.strand == -1;
  final List<Segment> ordered = List<Segment>.of(segments)
    ..sort(
      (Segment a, Segment b) =>
          minus ? b.start.compareTo(a.start) : a.start.compareTo(b.start),
    );
  return <int>[
    for (final Segment s in ordered)
      if (minus)
        for (int p = s.end; p >= s.start; p--) p
      else
        for (int p = s.start; p <= s.end; p++) p,
  ];
}

/// R2.1: a minus-strand sequence is read from the far end, never complemented.
String _baseAt(GeneRecord record, int position) =>
    record.sequence[record.strand == -1
        ? record.end - position
        : position - record.start];

String _codon(GeneRecord record, List<int> positions) =>
    positions.map((int p) => _baseAt(record, p)).join();

String _translated(GeneRecord record, List<Segment> segments) {
  final List<int> positions = _positions(record, segments);
  final StringBuffer residues = StringBuffer();
  for (int i = 0; i + 2 < positions.length; i += 3) {
    residues.write(
      GeneticCode.translate(_codon(record, positions.sublist(i, i + 3))) ?? 'X',
    );
  }
  return residues.toString();
}

List<(int, int)> _spans(List<Segment>? segments) => <(int, int)>[
  for (final Segment s in segments ?? const <Segment>[]) (s.start, s.end),
];

/// R2.2 on the edited record: its coding sequence translates to its protein
/// exactly, and every peptide to its own translation.
void _expectReadsBack(GeneRecord record) {
  final Protein protein = record.protein!;
  final String coded = _translated(record, protein.segments);
  expect(
    coded.endsWith('*') ? coded.substring(0, coded.length - 1) : coded,
    protein.translation,
  );
  expect(protein.translation, isNot(contains('*')));
  for (final Peptide peptide in <Peptide>[
    if (record.signalPeptide != null) record.signalPeptide!,
    if (record.proprotein != null) record.proprotein!,
    ...record.peptides,
  ]) {
    expect(
      _translated(record, peptide.segments),
      peptide.translation,
      reason: peptide.product,
    );
  }
}

void main() {
  final GeneRecord insulin = _gene('ins');
  final List<int> insulinCds = _positions(insulin, insulin.protein!.segments);

  group('an unedited record reads back as itself', () {
    // A substitution for the base already there is no edit at all, so every
    // segment, translation and real length the engine re-derives has to come
    // out as the record's own. Every catalog record, both strands, and the
    // three with shortened introns.
    final List<File> fixtures =
        Directory('test/fixtures/mock')
            .listSync()
            .whereType<File>()
            .where((File f) => f.path.endsWith('.json'))
            .toList()
          ..sort((File a, File b) => a.path.compareTo(b.path));

    test('there are records to read', () {
      expect(fixtures, isNotEmpty);
    });

    for (final File fixture in fixtures) {
      final GeneRecord record = _record(fixture.path);
      test(record.gene, () {
        final int position = record.protein!.segments.first.start;
        final SequenceEdit edit = Substitution(
          position,
          _baseAt(record, position),
        );
        final GeneRecord same = applyEdit(record, edit);

        expect(same.sequence, record.sequence);
        expect(
          (same.start, same.end, same.strand),
          (record.start, record.end, record.strand),
        );
        expect(
          _spans(same.transcript?.segments),
          _spans(record.transcript?.segments),
        );
        expect(
          <(int?, int, int)>[
            for (final Exon e in same.exons) (e.number, e.start, e.end),
          ],
          <(int?, int, int)>[
            for (final Exon e in record.exons) (e.number, e.start, e.end),
          ],
        );
        expect(same.protein!.translation, record.protein!.translation);
        expect(
          _spans(same.protein!.segments),
          _spans(record.protein!.segments),
        );
        final List<Peptide?> before = <Peptide?>[
          record.signalPeptide,
          record.proprotein,
          ...record.peptides,
        ];
        final List<Peptide?> after = <Peptide?>[
          same.signalPeptide,
          same.proprotein,
          ...same.peptides,
        ];
        expect(after, hasLength(before.length));
        for (int i = 0; i < before.length; i++) {
          expect(after[i]?.product, before[i]?.product);
          expect(after[i]?.translation, before[i]?.translation);
          expect(_spans(after[i]?.segments), _spans(before[i]?.segments));
        }
        expect(same.realSpanBp, record.realSpanBp);
        expect(same.realIntronBp, record.realIntronBp);
        expect(classify(record, edit).kind, EditOutcomeKind.synonymous);
      });
    }
  });

  group('property: a synonymous substitution never changes the protein', () {
    test('every substitution in the insulin coding sequence', () {
      int synonymous = 0;
      for (int c = 0; c * 3 < insulinCds.length; c++) {
        final List<int> codon = insulinCds.sublist(3 * c, 3 * c + 3);
        final String was = _codon(insulin, codon);
        for (int i = 0; i < 3; i++) {
          for (final String base in <String>['A', 'C', 'G', 'T']) {
            if (base == was[i]) {
              continue;
            }
            final String becomes = was.replaceRange(i, i + 1, base);
            final bool byTheCode =
                GeneticCode.translate(becomes) == GeneticCode.translate(was);
            final SequenceEdit edit = Substitution(codon[i], base);
            final EditOutcome outcome = classify(insulin, edit);
            expect(
              outcome.kind == EditOutcomeKind.synonymous,
              byTheCode,
              reason: 'codon ${c + 1} $was -> $becomes: $outcome',
            );
            if (outcome.kind == EditOutcomeKind.synonymous) {
              synonymous++;
              expect(outcome.codonIndex, c + 1);
              expect(
                applyEdit(insulin, edit).protein!.translation,
                insulin.protein!.translation,
                reason: 'codon ${c + 1} $was -> $becomes',
              );
            }
          }
        }
      }
      expect(synonymous, greaterThan(200));
    });
  });

  group('property: an indel not divisible by three changes every downstream '
      'codon', () {
    // Every coding base after the edit changes its place in its codon, so no
    // codon downstream is grouped from the bases it was. Checked up to the
    // edited reading's own stop, for every coding base before insulin's stop
    // codon. Indels are kept inside one exon's coding stretch: at an exon's
    // edge they reach the intron and are a splice question instead.
    final int stopPlace = insulinCds.length - 3;
    bool sameExon(int a, int b) => insulin.exons.any(
      (Exon e) => e.start <= a && a <= e.end && e.start <= b && b <= e.end,
    );

    // How many downstream bases were compared, so that a reading which
    // stopped at once everywhere cannot pass by comparing nothing.
    int checked = 0;
    tearDownAll(() => expect(checked, greaterThan(1000)));

    // [first] is where the downstream bases begin in the old coding sequence,
    // and [shift] how far the edit moved their record positions.
    void expectRegrouped(SequenceEdit edit, int first, int shift) {
      final EditOutcome outcome = classify(insulin, edit);
      expect(
        outcome.kind,
        isIn(<EditOutcomeKind>{
          EditOutcomeKind.frameshift,
          EditOutcomeKind.mrnaDegraded,
          EditOutcomeKind.stopLoss,
        }),
        reason: '$outcome',
      );
      final GeneRecord edited = applyEdit(insulin, edit);
      _expectReadsBack(edited);
      final List<int> newCds = _positions(edited, edited.protein!.segments);
      final Map<int, int> newPlace = <int, int>{
        for (int i = 0; i < newCds.length; i++) newCds[i]: i,
      };
      int compared = 0;
      for (int i = first; i < insulinCds.length; i++) {
        final int? now = newPlace[insulinCds[i] + shift];
        if (now == null) {
          continue;
        }
        compared++;
        expect(now % 3, isNot(i % 3), reason: 'base ${insulinCds[i]}');
      }
      checked += compared;
    }

    for (final int n in <int>[1, 2, 4, 5]) {
      test('insertions of $n', () {
        for (int i = 1; i < stopPlace; i++) {
          final int p = insulinCds[i];
          if (insulinCds[i - 1] != p - 1 || !sameExon(p - 1, p)) {
            continue;
          }
          expectRegrouped(Insertion(p, 'GATCA'.substring(0, n)), i, n);
        }
      });

      test('deletions of $n', () {
        for (int i = 0; i + n <= stopPlace; i++) {
          final int p = insulinCds[i];
          if (insulinCds[i + n - 1] != p + n - 1 || !sameExon(p, p + n - 1)) {
            continue;
          }
          expectRegrouped(Deletion(p, n), i + n, -n);
        }
      });
    }
  });

  group('one case per outcome, on insulin', () {
    // Insulin's CDS opens at 5224 in exon 2 (5207-5410) and closes with TAG at
    // 6341-6343 in exon 3 (6198-6416).

    test('synonymous: GCC to GCT still codes alanine 2', () {
      final EditOutcome outcome = classify(
        insulin,
        const Substitution(5229, 'T'),
      );
      expect(outcome.kind, EditOutcomeKind.synonymous);
      expect(
        (outcome.codonIndex, outcome.oldResidue, outcome.newResidue),
        (2, 'A', 'A'),
      );
      expect(outcome.newStopPosition, isNull);
    });

    test('missense: TTC to CTC turns phenylalanine 49 into leucine', () {
      const SequenceEdit edit = Substitution(5368, 'C');
      final EditOutcome outcome = classify(insulin, edit);
      expect(outcome.kind, EditOutcomeKind.missense);
      expect(
        (outcome.codonIndex, outcome.oldResidue, outcome.newResidue),
        (49, 'F', 'L'),
      );
      final GeneRecord edited = applyEdit(insulin, edit);
      _expectReadsBack(edited);
      expect(
        edited.protein!.translation,
        insulin.protein!.translation.replaceRange(48, 49, 'L'),
      );
      // The B chain is residues 25-54, and it is re-read, not left as it was.
      final Peptide chainB = edited.peptides.first;
      expect(chainB.product, 'insulin B chain');
      expect(chainB.translation[24], 'L');
    });

    test('nonsense: TAC to TAA at tyrosine 108, in the last exon', () {
      const SequenceEdit edit = Substitution(6334, 'A');
      final EditOutcome outcome = classify(insulin, edit);
      expect(outcome.kind, EditOutcomeKind.nonsense);
      expect(
        (outcome.codonIndex, outcome.oldResidue, outcome.newResidue),
        (108, 'Y', '*'),
      );
      expect(outcome.newStopPosition, 6332);
      final GeneRecord edited = applyEdit(insulin, edit);
      _expectReadsBack(edited);
      expect(
        edited.protein!.translation,
        insulin.protein!.translation.substring(0, 107),
      );
    });

    // The last exon-exon junction, from insulin's exon table: exon 1 is 42
    // bases and exon 2 is 204, so exon 3 starts 246 bases into the mRNA. The
    // CDS starts 17 bases into exon 2, at mRNA base 59, so codon k starts at
    // 59 + 3(k - 1). Codon 43 starts 61 bases before the junction and codon 45
    // exactly 55, which is not more than 55.
    test('mrnaDegraded: TGC to TGA at cysteine 43, 61 bases before the last '
        'junction', () {
      final EditOutcome outcome = classify(
        insulin,
        const Substitution(5352, 'A'),
      );
      expect(outcome.kind, EditOutcomeKind.mrnaDegraded);
      expect(
        (outcome.codonIndex, outcome.oldResidue, outcome.newResidue),
        (43, 'C', '*'),
      );
      expect(outcome.newStopPosition, 5350);
    });

    test('nonsense, not degraded: GAA to TAA at glutamate 45, 55 bases '
        'before it', () {
      final EditOutcome outcome = classify(
        insulin,
        const Substitution(5356, 'T'),
      );
      expect(outcome.kind, EditOutcomeKind.nonsense);
      expect(
        (outcome.codonIndex, outcome.oldResidue, outcome.newResidue),
        (45, 'E', '*'),
      );
      expect(outcome.newStopPosition, 5356);
    });

    test('the junction is the record\'s own: one exon, no decay', () {
      // The same bases with an exon table one exon long. Codon 43 is where it
      // was, since exon 2 ran on to 5410, but there is no junction for its
      // stop to be upstream of.
      final GeneRecord oneExon = GeneRecord(
        gene: insulin.gene,
        start: insulin.start,
        end: insulin.end,
        strand: insulin.strand,
        sequence: insulin.sequence,
        protein: insulin.protein,
        exons: <Exon>[Exon(start: insulin.start, end: insulin.end)],
        peptides: const <Peptide>[],
      );
      final EditOutcome outcome = classify(
        oneExon,
        const Substitution(5352, 'A'),
      );
      expect(outcome.kind, EditOutcomeKind.nonsense);
      expect(
        (outcome.codonIndex, outcome.oldResidue, outcome.newResidue),
        (43, 'C', '*'),
      );
    });

    test(
      'frameshift: an A before cysteine 100 reads off the end of the mRNA',
      () {
        const SequenceEdit edit = Insertion(6308, 'A');
        final EditOutcome outcome = classify(insulin, edit);
        expect(outcome.kind, EditOutcomeKind.frameshift);
        expect(
          (outcome.codonIndex, outcome.oldResidue, outcome.newResidue),
          (100, 'C', 'M'),
        );
        expect(outcome.newStopPosition, isNull);
        final GeneRecord edited = applyEdit(insulin, edit);
        _expectReadsBack(edited);
        expect(edited.protein!.translation, hasLength(135));
        expect(edited.end, insulin.end + 1);
      },
    );

    test('a frameshift that stops early in exon 2 degrades the mRNA', () {
      const SequenceEdit edit = Deletion(5233, 1);
      final EditOutcome outcome = classify(insulin, edit);
      expect(outcome.kind, EditOutcomeKind.mrnaDegraded);
      expect(
        (outcome.codonIndex, outcome.oldResidue, outcome.newResidue),
        (4, 'W', 'G'),
      );
      expect(outcome.newStopPosition, 5299);
      final GeneRecord edited = applyEdit(insulin, edit);
      _expectReadsBack(edited);
      expect(edited.protein!.translation, hasLength(25));
    });

    test(
      'inFrameIndel: losing GAC takes aspartate 60 out of the C-peptide',
      () {
        const SequenceEdit edit = Deletion(5401, 3);
        final EditOutcome outcome = classify(insulin, edit);
        expect(outcome.kind, EditOutcomeKind.inFrameIndel);
        expect(
          (outcome.codonIndex, outcome.oldResidue, outcome.newResidue),
          (60, 'D', 'L'),
        );
        expect(outcome.newStopPosition, isNull);

        final GeneRecord edited = applyEdit(insulin, edit);
        _expectReadsBack(edited);
        expect(
          edited.protein!.translation,
          insulin.protein!.translation.replaceRange(59, 60, ''),
        );
        // Everything after the deletion is three bases back.
        expect(_spans(edited.transcript!.segments), <(int, int)>[
          (4986, 5027),
          (5207, 5407),
          (6195, 6413),
        ]);
        expect(_spans(edited.protein!.segments), <(int, int)>[
          (5224, 5407),
          (6195, 6340),
        ]);
        final Peptide cPeptide = edited.peptides[1];
        expect(cPeptide.product, 'C-peptide');
        expect(cPeptide.translation, 'EAELQVGQVELGGGPGAGSLQPLALEGSLQ');
        expect(_spans(cPeptide.segments), <(int, int)>[
          (5392, 5407),
          (6195, 6268),
        ]);
        expect(_spans(edited.peptides[2].segments), <(int, int)>[(6275, 6337)]);
      },
    );

    test('stopLoss: TAG to CAG reads glutamine and on to the end of the '
        'mRNA', () {
      const SequenceEdit edit = Substitution(6341, 'C');
      final EditOutcome outcome = classify(insulin, edit);
      expect(outcome.kind, EditOutcomeKind.stopLoss);
      expect(
        (outcome.codonIndex, outcome.oldResidue, outcome.newResidue),
        (111, '*', 'Q'),
      );
      expect(outcome.newStopPosition, isNull);
      final GeneRecord edited = applyEdit(insulin, edit);
      _expectReadsBack(edited);
      expect(
        edited.protein!.translation,
        '${insulin.protein!.translation}QTQPAGSPTPAASCTERDGIKPLNQ',
      );
    });

    test('spliceSite: intron 2 starting AT-AG is not a pair R2.3 accepts', () {
      expect(_codon(insulin, <int>[5411, 5412]), 'GT');
      expect(
        classify(insulin, const Substitution(5411, 'A')).kind,
        EditOutcomeKind.spliceSite,
      );
      expect(_codon(insulin, <int>[6196, 6197]), 'AG');
      expect(
        classify(insulin, const Substitution(6197, 'C')).kind,
        EditOutcomeKind.spliceSite,
      );
    });

    test('GT to GC leaves a GC-AG intron, which R2.3 accepts', () {
      expect(
        classify(insulin, const Substitution(5412, 'C')).kind,
        EditOutcomeKind.intronic,
      );
    });

    test('intronic: the middle of intron 2 is not read', () {
      for (final SequenceEdit edit in const <SequenceEdit>[
        Substitution(5800, 'A'),
        Insertion(5800, 'GATTACA'),
        Deletion(5800, 10),
      ]) {
        final EditOutcome outcome = classify(insulin, edit);
        expect(outcome.kind, EditOutcomeKind.intronic);
        expect(outcome.codonIndex, isNull);
        expect(
          applyEdit(insulin, edit).protein!.translation,
          insulin.protein!.translation,
        );
      }
    });

    test('utr: exon 1 and the 3\' UTR are transcribed, not translated', () {
      for (final SequenceEdit edit in const <SequenceEdit>[
        Substitution(5000, 'A'),
        Insertion(6400, 'AAA'),
        // Just before the start codon, and just after the stop codon.
        Insertion(5224, 'T'),
        Insertion(6344, 'T'),
      ]) {
        final EditOutcome outcome = classify(insulin, edit);
        expect(
          outcome.kind,
          EditOutcomeKind.utr,
          reason: '${edit.runtimeType} at ${edit.position}',
        );
        expect(
          applyEdit(insulin, edit).protein!.translation,
          insulin.protein!.translation,
        );
      }
    });
  });

  group('real lengths, on CFTR, whose introns are drawn shortened', () {
    // Exon 2 is 21724-21834, between intron 1 (drawn 2,359 of 24,105 bases)
    // and intron 2 (drawn 457 of 4,670).
    final GeneRecord cftr = _gene('cftr');

    test('an edit inside an exon changes the span and no intron', () {
      final GeneRecord edited = applyEdit(cftr, const Insertion(21800, 'AAA'));
      expect(edited.realSpanBp, cftr.realSpanBp! + 3);
      expect(edited.realIntronBp, cftr.realIntronBp);
      expect(edited.intronScale, cftr.intronScale);
    });

    test('an exon taken out whole joins its two introns, at real length', () {
      final GeneRecord edited = applyEdit(cftr, const Deletion(21724, 111));
      expect(edited.exons, hasLength(cftr.exons.length - 1));
      expect(edited.realSpanBp, cftr.realSpanBp! - 111);
      expect(edited.realIntronBp, <int>[
        cftr.realIntronBp![0] + cftr.realIntronBp![1],
        ...cftr.realIntronBp!.skip(2),
      ]);
    });
  });

  group('a minus-strand record: RLN2', () {
    // RLN2's sequence is already the gene's strand (R2.1). Codon 10 is CTA,
    // read down the coordinates at 5191, 5190 and 5189.
    final GeneRecord relaxin = _gene('rln2');

    test('reads leucine 10 from the far end, uncomplemented', () {
      expect(relaxin.strand, -1);
      expect(_codon(relaxin, <int>[5191, 5190, 5189]), 'CTA');
      expect(relaxin.protein!.translation[9], 'L');
    });

    test('a substitution is written as the page draws the base', () {
      const SequenceEdit edit = Substitution(5190, 'C');
      final EditOutcome outcome = classify(relaxin, edit);
      expect(outcome.kind, EditOutcomeKind.missense);
      expect(
        (outcome.codonIndex, outcome.oldResidue, outcome.newResidue),
        (10, 'L', 'P'),
      );
      final GeneRecord edited = applyEdit(relaxin, edit);
      _expectReadsBack(edited);
      expect(
        edited.protein!.translation,
        relaxin.protein!.translation.replaceRange(9, 10, 'P'),
      );
    });

    test('a deletion runs 5\' to 3\', down the coordinates', () {
      const SequenceEdit edit = Deletion(5191, 3);
      final EditOutcome outcome = classify(relaxin, edit);
      expect(outcome.kind, EditOutcomeKind.inFrameIndel);
      expect(outcome.codonIndex, 10);
      final GeneRecord edited = applyEdit(relaxin, edit);
      _expectReadsBack(edited);
      expect(
        edited.protein!.translation,
        relaxin.protein!.translation.replaceRange(9, 10, ''),
      );
      // The record still starts at 502, so exon 2 stays where it was and exon
      // 1 closes three bases sooner.
      expect(edited.end, relaxin.end - 3);
      expect(_spans(edited.transcript!.segments), <(int, int)>[
        (5008, 5351),
        (502, 1082),
      ]);
    });

    test('an insertion goes in just 5\' of the base it names', () {
      const SequenceEdit edit = Insertion(5191, 'GGG');
      final EditOutcome outcome = classify(relaxin, edit);
      expect(outcome.kind, EditOutcomeKind.inFrameIndel);
      expect(
        (outcome.codonIndex, outcome.oldResidue, outcome.newResidue),
        (10, 'L', 'G'),
      );
      final GeneRecord edited = applyEdit(relaxin, edit);
      _expectReadsBack(edited);
      expect(
        edited.protein!.translation,
        relaxin.protein!.translation.replaceRange(9, 9, 'G'),
      );
    });
  });

  group('edits it cannot place', () {
    test('a position outside the record', () {
      expect(
        () => applyEdit(insulin, Substitution(insulin.start - 1, 'A')),
        throwsRangeError,
      );
      expect(
        () => applyEdit(insulin, Insertion(insulin.end + 1, 'A')),
        throwsRangeError,
      );
    });

    test('anything but A, C, G and T', () {
      for (final SequenceEdit edit in const <SequenceEdit>[
        Substitution(5229, 'N'),
        Substitution(5229, 'AC'),
        Substitution(5229, 't'),
        Insertion(5229, ''),
        Insertion(5229, 'acg'),
      ]) {
        expect(() => applyEdit(insulin, edit), throwsArgumentError);
      }
    });

    test('a deletion of nothing, or past the end', () {
      expect(
        () => applyEdit(insulin, const Deletion(5229, 0)),
        throwsRangeError,
      );
      expect(
        () => applyEdit(insulin, Deletion(insulin.end, 2)),
        throwsRangeError,
      );
    });
  });
}
