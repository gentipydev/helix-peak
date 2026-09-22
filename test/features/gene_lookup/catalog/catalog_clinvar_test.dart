import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeak/features/gene_lookup/data/models/gene_record_dto.dart';
import 'package:helixpeak/features/gene_lookup/domain/entities/gene_clinvar.dart';
import 'package:helixpeak/features/gene_lookup/domain/entities/gene_impact.dart';
import 'package:helixpeak/features/gene_lookup/domain/entities/gene_record.dart';
import 'package:helixpeak/features/gene_lookup/domain/entities/protein_catalog.dart';
import 'package:helixpeak/features/gene_lookup/domain/entities/protein_constraint.dart';
import 'package:helixpeak/features/gene_lookup/domain/entities/protein_target.dart';
import 'package:helixpeak/features/gene_lookup/domain/entities/variant_evidence.dart';
import 'package:helixpeak/features/gene_lookup/presentation/anatomy/anatomy_stages.dart';
import 'package:helixpeak/features/gene_lookup/presentation/clinvar/evidence_sections.dart';

Map<String, dynamic> _json(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

GeneRecord _record(ProteinTarget target) =>
    GeneRecordDto.fromJson(_json(target.mockAsset)).toEntity();

/// The Mendelian terms ClinVar's classifications are grouped by.
const Set<String> _mendelian = <String>{
  'pathogenic',
  'likely pathogenic',
  'pathogenic, low penetrance',
  'likely pathogenic, low penetrance',
  'benign',
  'likely benign',
};

/// Every protein's ClinVar snapshot, read the way the walk reads it.
///
/// A widget test never sees a snapshot load — the files are too large to
/// finish under fake async — so this is where each one is shown to reach the
/// screen. A snapshot that fails any of these is not drawn in part: the walk
/// shows it as unavailable, whole, with nothing on screen to say why.
void main() {
  for (final ProteinTarget target in ProteinCatalog.all) {
    group(target.slug, () {
      test('ships a snapshot exactly where the row says it does', () {
        expect(
          File(target.clinvarAsset).existsSync(),
          target.clinvarAvailable,
          reason: target.clinvarAsset,
        );
      });

      // The AVI track is indexed by record position from its first drawn base.
      // A minus-strand record stores its letters from the far end (R2.1), so a
      // track that copied them as stored read RLN2's and GCG's pages the wrong
      // letter at three bases in four.
      if (target.impactScored) {
        test('the AVI track reads the letters the page draws', () {
          final GeneRecord record = _record(target);
          final GeneImpact impact = GeneImpact.fromJson(
            _json(target.impactAsset),
            target,
          );
          final AnatomyModel model = AnatomyModel.derive(
            record,
            chain: target.chain,
          );
          final List<int> differ = <int>[
            for (int p = record.start; p <= record.end; p++)
              if (impact.baseAt(p) != model.baseAt(p)) p,
          ];
          expect(differ, isEmpty, reason: 'first at ${differ.take(3)}');
        });
      }

      if (!target.clinvarAvailable) {
        return;
      }

      test('the snapshot matches its record, AVI track and protein', () {
        final GeneRecord record = _record(target);
        final GeneClinVar snapshot = GeneClinVar.fromJson(
          _json(target.clinvarAsset),
          target,
        );
        final GeneImpact impact = GeneImpact.fromJson(
          _json(target.impactAsset),
          target,
        );
        final ProteinConstraint constraint = ProteinConstraint.fromJson(
          _json(target.constraintAsset),
          target,
        );
        expect(snapshot.matchesRecord(record), isTrue);
        expect(snapshot.matchesImpact(impact), isTrue);
        expect(snapshot.proteinSequence, constraint.sequence);

        final List<VariantEvidence> evidence = VariantEvidence.build(
          snapshot,
          impact: impact,
          constraint: constraint,
          nonCoding: nonCodingSections(
            AnatomyModel.derive(record, chain: target.chain),
          ),
        );
        expect(evidence, hasLength(snapshot.variants.length));
        expect(evidence.every((VariantEvidence e) => e.section.isNotEmpty), isTrue);
        // Every record reads its own allele's AVI, but at a base the track
        // could not score exactly (dystrophin's three assembly differences).
        final int exact = evidence.where((VariantEvidence e) => e.avi != null).length;
        expect(exact, greaterThanOrEqualTo(evidence.length * 0.99));
        for (final VariantEvidence e in evidence) {
          // A missense record reads its own amino acid's ESM score.
          if (e.variant.consequence == 'missense') {
            expect(e.esm, isNotNull, reason: e.variant.id);
          }
          // And every record with its model numbers has its one-line reading.
          if (e.avi != null &&
              (e.variant.consequence != 'missense' || e.esm != null)) {
            expect(e.reading, isNotNull, reason: e.variant.id);
          }
        }
      });

      test('no Mendelian call is filed under Other', () {
        final GeneClinVar snapshot = GeneClinVar.fromJson(
          _json(target.clinvarAsset),
          target,
        );
        final Set<String> wordings = <String>{
          for (final ClinVarVariant v in snapshot.variants) ...<String>[
            v.classification,
            for (final ClinVarCondition c in v.conditions) c.classification,
          ],
        };
        for (final String text in wordings) {
          final Iterable<String> terms = text
              .toLowerCase()
              .split(RegExp('[/;]'))
              .map((String term) => term.trim());
          if (terms.any(_mendelian.contains)) {
            expect(ClinVarGroup.of(text), isNot(ClinVarGroup.other), reason: text);
          }
        }
      });
    });
  }
}
