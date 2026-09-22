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

import '../anatomy/anatomy_fixture.dart';
import 'gene_clinvar_test.dart' show readJson, snapshot;

GeneImpact insulinImpact() => GeneImpact.fromJson(
  readJson(ProteinCatalog.insulin.impactAsset),
  ProteinCatalog.insulin,
);

ProteinConstraint insulinConstraint() => ProteinConstraint.fromJson(
  readJson(ProteinCatalog.insulin.constraintAsset),
  ProteinCatalog.insulin,
);

List<VariantEvidence> insulinEvidence({
  bool impact = true,
  bool constraint = true,
}) => VariantEvidence.build(
  snapshot(),
  impact: impact ? insulinImpact() : null,
  constraint: constraint ? insulinConstraint() : null,
  nonCoding: nonCodingSections(
    AnatomyModel.derive(insulin(), chain: ProteinCatalog.insulin.chain),
  ),
);

VariantEvidence recordOf(List<VariantEvidence> all, String label) =>
    all.firstWhere((VariantEvidence e) => e.variant.shortLabel == label);

/// Any catalog gene's records, read against its own baked tracks.
List<VariantEvidence> evidenceOf(ProteinTarget target) {
  final GeneRecord record = GeneRecordDto.fromJson(
    readJson(target.mockAsset),
  ).toEntity();
  return VariantEvidence.build(
    GeneClinVar.fromJson(readJson(target.clinvarAsset), target),
    impact: GeneImpact.fromJson(readJson(target.impactAsset), target),
    constraint: ProteinConstraint.fromJson(
      readJson(target.constraintAsset),
      target,
    ),
    nonCoding: nonCodingSections(
      AnatomyModel.derive(record, chain: target.chain),
    ),
  );
}

void main() {
  test('every record is read once, against its own allele', () {
    final List<VariantEvidence> all = insulinEvidence();
    final GeneImpact impact = insulinImpact();
    final ProteinConstraint constraint = insulinConstraint();
    expect(all, hasLength(166));
    for (final VariantEvidence e in all) {
      expect(e.avi, e.variant.aviScore(impact.at(e.variant.position)));
      expect(e.avi, isNotNull);
    }
    final List<VariantEvidence> missense = <VariantEvidence>[
      for (final VariantEvidence e in all)
        if (e.variant.consequence == 'missense') e,
    ];
    expect(missense, hasLength(89));
    for (final VariantEvidence e in missense) {
      final ResidueConstraint residue =
          constraint.positions[e.variant.residue! - 1];
      expect(
        e.esm!.score,
        residue.ranked
            .firstWhere((s) => s.aminoAcid == e.variant.altResidue)
            .score,
      );
    }
    // Everything that is not a substitution has no ESM score to give.
    expect(all.where((e) => e.esm != null), hasLength(89));
  });

  test('groups, stars and sections match the snapshot', () {
    final List<VariantEvidence> all = insulinEvidence();
    int count(ClinVarGroup g) => all.where((e) => e.variant.group == g).length;
    expect(count(ClinVarGroup.pathogenic), 37);
    expect(count(ClinVarGroup.conflicting), 24);
    expect(count(ClinVarGroup.uncertain), 54);
    expect(count(ClinVarGroup.benign), 42);
    expect(count(ClinVarGroup.other), 9);
    int stars(int n) => all.where((e) => e.variant.stars == n).length;
    expect(<int>[stars(0), stars(1), stars(2)], <int>[15, 119, 32]);

    final Map<String, int> sections = <String, int>{};
    for (final VariantEvidence e in all) {
      sections[e.section] = (sections[e.section] ?? 0) + 1;
    }
    expect(sections, <String, int>{
      'Signal peptide': 22,
      'B chain': 39,
      'B / C cleavage site': 2,
      'C-peptide': 21,
      'C / A cleavage site': 4,
      'A chain': 26,
      '5′ UTR': 4,
      'Intron 1': 8,
      'Intron 2': 32,
      '3′ UTR': 8,
    });
    final Iterable<VariantEvidence> cPeptide = all.where(
      (e) => e.section == 'C-peptide' && e.variant.consequence == 'missense',
    );
    expect(cPeptide, hasLength(16));
    expect(
      cPeptide.where((e) => e.variant.group == ClinVarGroup.pathogenic),
      isEmpty,
    );
  });

  test('the reading line follows both models and says which applies', () {
    final List<VariantEvidence> all = insulinEvidence();
    expect(recordOf(all, 'Cys96Tyr').reading, EvidenceReading.bothStrong);
    expect(recordOf(all, 'Val63Ala').reading, EvidenceReading.neither);
    expect(recordOf(all, 'Thr97Ser').reading, EvidenceReading.aviOnly);
    expect(recordOf(all, 'Cys43Ter').reading, EvidenceReading.stop);
    expect(recordOf(all, 'Cys31=').reading, EvidenceReading.synonymous);
    expect(recordOf(all, 'Met1Val').reading, EvidenceReading.start);
    expect(recordOf(all, 'c.188-31G>A').reading, EvidenceReading.outside);
    for (final VariantEvidence e in all) {
      expect(
        e.reading!.line,
        isNot(
          matches(
            RegExp(
              r'pathogenic|dangerous|harmful|disease|safe|diagnosis|clinical',
              caseSensitive: false,
            ),
          ),
        ),
      );
    }
  });

  test('a change to the stop codon reads as one, with only AVI to say', () {
    // SOD1's Ter155Ser: the stop codon read through, so no residue to score.
    final VariantEvidence stopLost = evidenceOf(
      ProteinCatalog.sod1,
    ).firstWhere((VariantEvidence e) => e.variant.id == '3335974');
    expect(stopLost.variant.consequence, 'stop lost');
    expect(stopLost.variant.residue, isNull);
    expect(stopLost.avi, isNotNull);
    expect(stopLost.reading, EvidenceReading.stopCodon);
    expect(stopLost.reading!.line, 'Stop codon change: only AVI applies.');
  });

  test('records at one residue follow the transcript on either strand', () {
    // RLN2's record runs against its coordinates, so Met105's first base is
    // its highest position: M105L (the codon's first base) reads before M105I
    // (its third).
    final List<VariantEvidence> met105 =
        evidenceOf(ProteinCatalog.relaxin)
            .where((VariantEvidence e) => e.variant.residue == 105)
            .toList()
          ..sort(VariantEvidence.transcriptOrder(reversed: true));
    expect(
      met105.map((VariantEvidence e) => e.variant.proteinChange),
      <String>['p.M105L', 'p.M105I'],
    );
    final List<VariantEvidence> cys96 =
        insulinEvidence()
            .where((VariantEvidence e) => e.variant.residue == 96)
            .toList()
          ..sort(VariantEvidence.transcriptOrder(reversed: false));
    final List<int> positions = <int>[
      for (final VariantEvidence e in cys96) e.variant.position,
    ];
    expect(positions, orderedEquals(List<int>.of(positions)..sort()));
  });

  test('a missing or mismatched track leaves its model silent', () {
    final List<VariantEvidence> noImpact = insulinEvidence(impact: false);
    expect(noImpact.every((e) => e.avi == null && e.reading == null), isTrue);
    final List<VariantEvidence> noEsm = insulinEvidence(constraint: false);
    expect(noEsm.every((e) => e.esm == null), isTrue);
    expect(recordOf(noEsm, 'Cys96Tyr').reading, isNull);
    expect(recordOf(noEsm, 'Cys96Tyr').section, 'Coding sequence');
    expect(recordOf(noEsm, 'Cys31=').reading, EvidenceReading.synonymous);
  });

  test('labels cite the record the way the field does', () {
    final List<VariantEvidence> all = insulinEvidence();
    final ClinVarVariant c96y = recordOf(all, 'Cys96Tyr').variant;
    expect(c96y.transcriptChange, 'c.287G>A');
    // What the conflict is split between, most severe first, each part with
    // the condition it is about.
    expect(
      <String>[
        for (final (String label, List<ClinVarTrait> traits)
            in c96y.conditionsByClass)
          '$label: ${traits.map((ClinVarTrait t) => t.name).join(', ')}',
      ],
      <String>[
        'Pathogenic: not provided',
        'Likely pathogenic: Neonatal diabetes mellitus',
        'Uncertain significance: Diabetes mellitus, permanent neonatal 4',
        'not provided: Permanent neonatal diabetes mellitus',
      ],
    );
    expect(c96y.stars, 1);
    expect(recordOf(all, 'c.*59A>G').variant.transcriptChange, 'c.*59A>G');
    expect(recordOf(all, 'Gly32Ser').variant.stars, 2);
  });
}
