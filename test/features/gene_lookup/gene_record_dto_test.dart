import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/features/gene_lookup/data/models/gene_record_dto.dart';
import 'package:helixpeek/features/gene_lookup/domain/entities/gene_record.dart';

/// A real `GET /gene/NG_007114/INS` response, saved from the running backend.
GeneRecord _load() {
  final String raw = File('test/fixtures/mock/gene_ins.json').readAsStringSync();
  final Map<String, dynamic> json = jsonDecode(raw) as Map<String, dynamic>;
  return GeneRecordDto.fromJson(json).toEntity();
}

void main() {
  group('GeneRecordDto', () {
    late GeneRecord record;

    setUp(() => record = _load());

    test('maps the snake_case location onto the entity', () {
      expect(record.gene, 'INS');
      expect(record.start, 4986);
      expect(record.end, 6416);
      expect(record.strand, 1);
      expect(record.sequence.length, 1431);
    });

    test('derives the span length rather than reading it off the wire', () {
      expect(record.lengthBp, 1431);
    });

    test('keeps the exons numbered and in order', () {
      expect(record.exons.map((Exon e) => e.number).toList(), <int>[1, 2, 3]);
      expect(record.exons.map((Exon e) => e.start).toList(), <int>[
        4986,
        5207,
        6198,
      ]);
    });

    test('keeps compound locations as segments', () {
      final Protein protein = record.protein!;
      expect(protein.product, 'insulin preproprotein');
      expect(protein.segments.length, 2);
      expect(protein.segments.first.start, 5224);
      expect(protein.segments.last.end, 6343);
      expect(record.transcript!.segments.length, 3);
    });

    test('carries the three insulin chains', () {
      expect(
        record.peptides
            .map((Peptide p) => '${p.product}:${p.lengthAa}:${p.translation}')
            .toList(),
        <String>[
          'insulin B chain:30:FVNQHLCGSHLVEALYLVCGERGFFYTPKT',
          'C-peptide:31:EAEDLQVGQVELGGGPGAGSLQPLALEGSLQ',
          'insulin A chain:21:GIVEQCCTSICSLYQLENYCN',
        ],
      );
    });

    test('carries the precursor, with its length read off the translation', () {
      expect(record.signalPeptide!.lengthAa, 24);
      expect(record.proprotein!.product, 'proinsulin');
      expect(record.proprotein!.lengthAa, 86);
      expect(record.proprotein!.segments.length, 2);
    });
  });
}
