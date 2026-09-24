import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/core/biology/genetic_code.dart';
import 'package:helixpeek/features/gene_lookup/data/models/gene_record_dto.dart';
import 'package:helixpeek/features/gene_lookup/domain/entities/protein_catalog.dart';
import 'package:helixpeek/features/gene_lookup/domain/entities/protein_constraint.dart';
import 'package:helixpeek/features/gene_lookup/domain/entities/protein_target.dart';
import 'package:helixpeek/features/gene_lookup/presentation/anatomy/anatomy_stages.dart';
import 'package:helixpeek/features/gene_lookup/presentation/inspector/coding_evidence.dart';

import '../anatomy/anatomy_fixture.dart';

Map<String, dynamic> _json(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

void main() {
  final AnatomyModel model = AnatomyModel.derive(insulin());
  final ProteinConstraint track = ProteinConstraint.fromJson(
    _json(ProteinCatalog.insulin.constraintAsset),
    ProteinCatalog.insulin,
  );

  test(
    'all three bases map to their residue, even across a splice junction',
    () {
      for (final int position in <int>[5410, 6198, 6199]) {
        final CodingEvidence evidence = CodingEvidence.at(
          model: model,
          position: position,
          track: track,
        )!;
        expect(evidence.constraint, same(track.positions[62]));
        expect(evidence.offset, <int>[5410, 6198, 6199].indexOf(position));
      }
    },
  );

  test(
    'a fourfold-degenerate base explicitly names all silent alternatives',
    () {
      final CodingEvidence evidence = CodingEvidence.at(
        model: model,
        position: 5301,
        track: track,
      )!;
      expect(evidence.residueName, 'Val26');
      expect(evidence.offset, 2);
      expect(evidence.synonymousAlternatives.length, 3);
      final CodingEvidence first = CodingEvidence.at(
        model: model,
        position: 5299,
        track: track,
      )!;
      expect(first.synonymousAlternatives, isEmpty);
    },
  );

  test('the standard code handles stops and rejects unknown triplets', () {
    for (final String stop in <String>['TAA', 'TAG', 'TGA']) {
      expect(GeneticCode.translate(stop), '*');
    }
    expect(GeneticCode.translate('ATG'), 'M');
    expect(GeneticCode.translate('TGG'), 'W');
    expect(GeneticCode.translate('NNN'), isNull);
    expect(GeneticCode.translate('AT'), isNull);
  });

  test('every catalog coding base maps through its actual transcript', () {
    for (final ProteinTarget target in ProteinCatalog.all) {
      final AnatomyModel gene = AnatomyModel.derive(
        GeneRecordDto.fromJson(_json(target.mockAsset)).toEntity(),
        chain: target.chain,
      );
      final ProteinConstraint scores = ProteinConstraint.fromJson(
        _json(target.constraintAsset),
        target,
      );
      final AnatomyStage protein = gene.stages.firstWhere(
        (AnatomyStage stage) => stage.kind == StageKind.protein,
      );
      final AnatomyStage mrna = gene.stages.firstWhere(
        (AnatomyStage stage) => stage.kind == StageKind.mrna,
      );
      final StageBlock cds = mrna.blocks[1];
      for (int i = 0; i < mrna.count; i++) {
        final int offset = i - cds.start;
        final CodingEvidence? evidence = CodingEvidence.at(
          model: gene,
          position: mrna.positionAt(i),
          track: scores,
        );
        if (offset < 0 || offset >= protein.count * 3) {
          expect(evidence, isNull, reason: '${target.slug} UTR/stop $i');
        } else {
          expect(evidence, isNotNull, reason: '${target.slug} coding $offset');
          expect(evidence!.constraint, same(scores.positions[offset ~/ 3]));
          expect(evidence.offset, offset % 3);
        }
      }
      final AnatomyStage dna = gene.stages.first;
      for (int i = 0; i < dna.count; i++) {
        final int position = dna.positionAt(i);
        if (mrna.cellAt(position) < 0) {
          expect(
            CodingEvidence.at(model: gene, position: position, track: scores),
            isNull,
            reason: '${target.slug} intron/flank $position',
          );
        }
      }
    }
  });

  test('missing and mismatched tracks never substitute another residue', () {
    final ProteinConstraint other = ProteinConstraint.fromJson(
      _json(
        ProteinCatalog.all
            .firstWhere((ProteinTarget p) => p.gene != 'INS')
            .constraintAsset,
      ),
      ProteinCatalog.all.firstWhere((ProteinTarget p) => p.gene != 'INS'),
    );
    for (final ProteinConstraint? scores in <ProteinConstraint?>[null, other]) {
      final CodingEvidence evidence = CodingEvidence.at(
        model: model,
        position: 5301,
        track: scores,
      )!;
      expect(evidence.constraint, isNull);
    }
  });
}
