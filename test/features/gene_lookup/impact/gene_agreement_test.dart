import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/core/catalog/protein_target.dart';
import 'package:helixpeek/core/evidence/gene_impact.dart';
import 'package:helixpeek/core/evidence/protein_constraint.dart';
import 'package:helixpeek/core/evidence/variant_evidence.dart';
import 'package:helixpeek/features/gene_lookup/data/models/gene_record_dto.dart';
import 'package:helixpeek/features/gene_lookup/presentation/inspector/coding_evidence.dart';
import 'package:helixpeek/features/gene_lookup/presentation/inspector/gene_agreement.dart';
import 'package:helixpeek/shared/anatomy/anatomy_stages.dart';

import '../../../support/test_catalog.dart';

/// The gene-wide agreement of AVI and ESM-2. The pinned numbers were worked
/// out from the same fixtures by a script apart from the app, which joins
/// each coding base to its codon from the record's own CDS segments.

Map<String, dynamic> _json(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

AnatomyModel _model(ProteinTarget target) => AnatomyModel.derive(
  GeneRecordDto.fromJson(_json(target.mockAsset)).toEntity(),
  chain: target.chain,
);

GeneImpact _impact(ProteinTarget target, {String? without}) {
  final Map<String, dynamic> json = _json(target.impactAsset);
  if (without != null) {
    (json['positions'] as Map<String, dynamic>).remove(without);
  }
  return GeneImpact.fromJson(json, target);
}

ProteinConstraint _constraint(ProteinTarget target) =>
    ProteinConstraint.fromJson(_json(target.constraintAsset), target);

GeneAgreement _agreement(ProteinTarget target) => GeneAgreement.of(
  model: _model(target),
  impact: _impact(target),
  constraint: _constraint(target),
)!;

void main() {
  test('insulin: 687 missense substitutions, ρ 0.79, 345 of 540 pairs '
      'in the same order', () {
    final GeneAgreement agreement = _agreement(TestCatalog.insulin);
    expect(agreement.gene, 'INS');
    expect(agreement.count, 687);
    expect(agreement.rho, closeTo(0.793479, 0.000001));
    expect(agreement.pairs, 540);
    expect(agreement.alike, 345);
    expect(
      agreement.changes.map((ScoredChange c) => c.position).toSet(),
      hasLength(259),
    );
  });

  test('a minus-strand record reads as the sheet reads it', () {
    final GeneAgreement agreement = _agreement(TestCatalog.glucagon);
    expect(agreement.count, 1213);
    expect(agreement.rho, closeTo(0.614740, 0.000001));
    expect(agreement.pairs, 898);
    expect(agreement.alike, 597);
  });

  test('c.268: each substitution ranked by both models', () {
    final AnatomyModel model = _model(TestCatalog.insulin);
    final GeneImpact impact = _impact(TestCatalog.insulin);
    final ProteinConstraint constraint = _constraint(TestCatalog.insulin);
    final GeneAgreement agreement = GeneAgreement.of(
      model: model,
      impact: impact,
      constraint: constraint,
    )!;
    final List<AgreementRow> rows = AgreementRow.at(
      impact.at(6278)!,
      CodingEvidence.at(model: model, position: 6278, track: constraint)!,
      agreement,
    );
    expect(
      <String>[for (final AgreementRow r in rows) r.score.base],
      <String>['A', 'C', 'T'],
    );
    expect(
      <String>[for (final AgreementRow r in rows) r.tag],
      <String>['Ser', 'Arg', 'Cys'],
    );
    expect(
      <double?>[for (final AgreementRow r in rows) r.esm],
      <double>[-7.162, -8.431, -10.367],
    );
    // Shares counted as the script counts them: at least as high by AVI, at
    // least as low by ESM-2.
    const List<(int, int)> counts = <(int, int)>[
      (12, 198),
      (25, 130),
      (35, 48),
    ];
    for (final (int i, AgreementRow row) in rows.indexed) {
      expect(row.aviRank!.top, counts[i].$1 / 687, reason: row.tag);
      expect(row.esmRank!.top, counts[i].$2 / 687, reason: row.tag);
      expect(row.reading, isNull);
    }
    expect(
      <String>[
        for (final AgreementRow r in rows)
          '${r.aviRank!.label} ${r.esmRank!.label}',
      ],
      <String>['top 1.7% top 29%', 'top 3.6% top 19%', 'top 5.1% top 7.0%'],
    );
  });

  test('a change that is not missense is read, not ranked', () {
    final AnatomyModel model = _model(TestCatalog.insulin);
    final GeneImpact impact = _impact(TestCatalog.insulin);
    final ProteinConstraint constraint = _constraint(TestCatalog.insulin);
    final GeneAgreement agreement = GeneAgreement.of(
      model: model,
      impact: impact,
      constraint: constraint,
    )!;
    List<AgreementRow> at(int position) => AgreementRow.at(
      impact.at(position)!,
      CodingEvidence.at(model: model, position: position, track: constraint)!,
      agreement,
    );
    // c.270, Gly90's third base: all three keep glycine.
    for (final AgreementRow row in at(6280)) {
      expect(row.tag, '=');
      expect(row.reading, EvidenceReading.synonymous);
      expect(row.esm, isNull);
      expect(row.aviRank, isNull);
    }
    // c.11 G>A makes Trp4 a stop; its other two are missense.
    final List<AgreementRow> trp = at(5234);
    expect(trp.first.score.base, 'A');
    expect(trp.first.tag, 'Ter');
    expect(trp.first.reading, EvidenceReading.stop);
    expect(trp.first.esmRank, isNull);
    expect(trp.skip(1).every((AgreementRow r) => r.esmRank != null), isTrue);
    // The start codon: every change is p.Met1?, and ESM-2's numbers there are
    // not offered as its effect.
    for (final int position in <int>[5224, 5225, 5226]) {
      for (final AgreementRow row in at(position)) {
        expect(row.tag, '?');
        expect(row.reading, EvidenceReading.start);
        expect(row.esm, isNull);
      }
    }
  });

  test('only a base with a change to another amino acid is compared', () {
    final AnatomyModel model = _model(TestCatalog.insulin);
    final GeneImpact impact = _impact(TestCatalog.insulin);
    final ProteinConstraint constraint = _constraint(TestCatalog.insulin);
    bool compared(int position, {bool scored = true}) => AgreementRow.anyAt(
      impact.at(position)!,
      CodingEvidence.at(
        model: model,
        position: position,
        track: scored ? constraint : null,
      )!,
    );
    // c.268, Gly90's first base: three missense changes.
    expect(compared(6278), isTrue);
    // c.11, Trp4's middle base: a stop and two missense changes.
    expect(compared(5234), isTrue);
    // c.270, Gly90's third base: all three silent.
    expect(compared(6280), isFalse);
    // c.2, the start codon: p.Met1? whatever is made.
    expect(compared(5225), isFalse);
    // Without ESM-2's track at the residue, nothing is compared.
    expect(compared(6278, scored: false), isFalse);
  });

  test('a ranked share reads from the top, and from the bottom past half', () {
    expect(const GeneRank(top: 12 / 687, bottom: 1).label, 'top 1.7%');
    expect(const GeneRank(top: 0.5, bottom: 0.51).label, 'top 50%');
    expect(const GeneRank(top: 0.92, bottom: 0.0801).label, 'bottom 8.0%');
    expect(const GeneRank(top: 1, bottom: 1 / 687).label, 'bottom 0.15%');
    expect(const GeneRank(top: 0.0996, bottom: 1).label, 'top 10%');
    expect(const GeneRank(top: 0.999, bottom: 0.996).label, 'bottom 100%');
    expect(const GeneRank(top: 0.25, bottom: 0.8).place, 0.75);
  });

  test('a base whose AVI is borrowed gives no number', () {
    final GeneAgreement whole = _agreement(TestCatalog.insulin);
    final GeneAgreement without = GeneAgreement.of(
      model: _model(TestCatalog.insulin),
      impact: _impact(TestCatalog.insulin, without: '6278'),
      constraint: _constraint(TestCatalog.insulin),
    )!;
    expect(without.count, whole.count - 3);
    expect(
      without.changes.where((ScoredChange c) => c.position == 6278),
      isEmpty,
    );
  });

  test('another protein\'s ESM-2 track gives nothing', () {
    expect(
      GeneAgreement.of(
        model: _model(TestCatalog.glucagon),
        impact: _impact(TestCatalog.glucagon),
        constraint: _constraint(TestCatalog.insulin),
      ),
      isNull,
    );
  });

  test('worked out once per track, again for another', () {
    final AnatomyModel model = _model(TestCatalog.insulin);
    final GeneImpact impact = _impact(TestCatalog.insulin);
    final ProteinConstraint constraint = _constraint(TestCatalog.insulin);
    final GeneAgreement first = GeneAgreement.of(
      model: model,
      impact: impact,
      constraint: constraint,
    )!;
    expect(
      GeneAgreement.of(model: model, impact: impact, constraint: constraint),
      same(first),
    );
    final GeneAgreement other = GeneAgreement.of(
      model: model,
      impact: impact,
      constraint: _constraint(TestCatalog.insulin),
    )!;
    expect(other, isNot(same(first)));
    expect(other.count, first.count);
  });

  test('every scored curated protein: each change is a missense change both '
      'models score', () {
    int proteins = 0;
    for (final ProteinTarget target in TestCatalog.all) {
      if (!File(target.constraintAsset).existsSync()) continue;
      proteins++;
      final AnatomyModel model = _model(target);
      final GeneImpact impact = _impact(target);
      final ProteinConstraint constraint = _constraint(target);
      final GeneAgreement agreement = GeneAgreement.of(
        model: model,
        impact: impact,
        constraint: constraint,
      )!;
      final String letters = model.stages
          .firstWhere((AnatomyStage s) => s.kind == StageKind.protein)
          .letters;
      expect(agreement.count, greaterThan(100), reason: target.slug);
      expect(agreement.rho, inInclusiveRange(-1, 1), reason: target.slug);
      expect(agreement.alike, lessThanOrEqualTo(agreement.pairs));
      for (final ScoredChange change in agreement.changes) {
        final CodingEvidence coding = CodingEvidence.at(
          model: model,
          position: change.position,
          track: constraint,
        )!;
        final String? made = coding.madeBy(change.alt);
        final String reason = '${target.slug} ${change.position}${change.alt}';
        expect(coding.codon, greaterThan(1), reason: reason);
        expect(
          made,
          isNot(anyOf(isNull, '*', letters[coding.codon - 1])),
          reason: reason,
        );
        expect(impact.at(change.position)!.estimated, isFalse, reason: reason);
        expect(
          change.esm,
          coding.constraint!.ranked
              .firstWhere((SubstitutionScore s) => s.aminoAcid == made)
              .score,
          reason: reason,
        );
      }
    }
    expect(proteins, greaterThanOrEqualTo(37));
  });
}
