import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/features/gene_lookup/domain/entities/gene_clinvar.dart';
import 'package:helixpeek/features/gene_lookup/domain/entities/gene_impact.dart';
import 'package:helixpeek/features/gene_lookup/domain/entities/protein_constraint.dart';
import 'package:helixpeek/features/gene_lookup/domain/entities/variant_evidence.dart';

import '../../../support/test_catalog.dart';
import '../anatomy/anatomy_fixture.dart';

Map<String, dynamic> readJson(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;
Map<String, dynamic> snapshotJson() =>
    readJson(TestCatalog.insulin.clinvarAsset);
GeneClinVar snapshot() =>
    GeneClinVar.fromJson(snapshotJson(), TestCatalog.insulin);

void main() {
  test(
    'INS snapshot accounts for every source record and matches the transcript',
    () {
      final GeneClinVar data = snapshot();
      expect(data.variants.length + data.excludedCount, data.searchedRecords);
      expect(data.matchesRecord(insulin()), isTrue);
      expect(data.at(6297).map((v) => v.id), contains('13387'));
      final ClinVarVariant c96y = data.variants.firstWhere(
        (v) => v.id == '13387',
      );
      expect(c96y.ref, 'G');
      expect(c96y.alt, 'A');
      expect(c96y.genomic, 2159898);
      expect(c96y.residue, 96);
      expect(c96y.proteinChange, 'p.C96Y');
      expect(c96y.group, ClinVarGroup.conflicting);
      expect(
        c96y.conditions.map((c) => c.classification),
        contains('Pathogenic'),
      );
      expect(data.atResidue(96).length, greaterThan(data.at(6297).length));
      expect(data.at(data.start - 1), isEmpty);
    },
  );

  test(
    'exact allele uses its own AVI score, rejects neighboring estimates',
    () {
      final ClinVarVariant v = snapshot().variants.firstWhere(
        (v) => v.id == '13387',
      );
      BaseImpact base({
        int? estimated,
        String ref = 'G',
        int genomic = 2159898,
      }) => BaseImpact(
        position: v.position,
        genomic: genomic,
        wildtype: ref,
        ranked: const <AltScore>[
          AltScore('T', 35),
          AltScore('C', 20),
          AltScore('A', 3),
        ],
        estimatedFrom: estimated,
      );
      expect(v.aviScore(base()), 3);
      expect(v.aviScore(base(estimated: 6298)), isNull);
      expect(v.aviScore(base(ref: 'C')), isNull);
      expect(v.aviScore(base(genomic: 2159899)), isNull);
    },
  );

  test(
    'evidence reads exact alleles only, and only against matching tracks',
    () {
      final GeneClinVar data = snapshot();
      final GeneImpact avi = GeneImpact.fromJson(
        readJson(TestCatalog.insulin.impactAsset),
        TestCatalog.insulin,
      );
      final ProteinConstraint esm = ProteinConstraint.fromJson(
        readJson(TestCatalog.insulin.constraintAsset),
        TestCatalog.insulin,
      );
      ({String label, int order}) gene(int position) =>
          (label: 'gene', order: position);
      final List<VariantEvidence> all = VariantEvidence.build(
        data,
        impact: avi,
        constraint: esm,
        nonCoding: gene,
      );
      expect(all.where((e) => e.esm != null).length, 89);
      for (final VariantEvidence e in all) {
        expect(e.avi, e.variant.aviScore(avi.at(e.variant.position)));
      }
      final Map<String, dynamic> changed = readJson(
        TestCatalog.insulin.impactAsset,
      );
      ((changed['runs'] as List<dynamic>).first
              as Map<String, dynamic>)['genomic'] =
          2161210;
      expect(
        VariantEvidence.build(
          data,
          impact: GeneImpact.fromJson(changed, TestCatalog.insulin),
          constraint: esm,
          nonCoding: gene,
        ).every((e) => e.avi == null),
        isTrue,
      );
    },
  );

  test(
    'missing score empties only that base; never substitutes its neighbor',
    () {
      final GeneClinVar data = snapshot();
      final Map<String, dynamic> raw = readJson(
        TestCatalog.insulin.impactAsset,
      );
      (raw['positions'] as Map<String, dynamic>).remove('6297');
      final GeneImpact avi = GeneImpact.fromJson(raw, TestCatalog.insulin);
      final List<VariantEvidence> all = VariantEvidence.build(
        data,
        impact: avi,
        nonCoding: (int position) => (label: 'gene', order: position),
      );
      expect(
        all.where((e) => e.variant.position == 6297).every((e) => e.avi == null),
        isTrue,
      );
      expect(
        all.where((e) => e.variant.position != 6297).every((e) => e.avi != null),
        isTrue,
      );
      expect(data.at(6297), isNotEmpty);
    },
  );

  test('conditions carry the identifiers ClinVar gives them, and only those', () {
    final ClinVarVariant met1 = snapshot().variants.firstWhere(
      (v) => v.id == '1455986',
    );
    final List<(String, List<ClinVarTrait>)> groups = met1.conditionsByClass;
    expect(<String>[for (final (String c, _) in groups) c], <String>[
      'Pathogenic',
      'Likely pathogenic',
    ]);
    final List<ClinVarTrait> likely = groups[1].$2;
    expect(
      <String>[for (final ClinVarTrait t in likely) t.name],
      <String>[
        'Diabetes mellitus, permanent neonatal 4',
        'Hyperproinsulinemia',
        'Maturity-onset diabetes of the young type 10',
        'Type 1 diabetes mellitus 2',
      ],
    );
    expect(
      <(String?, String?)>[for (final ClinVarTrait t in likely) (t.symbol, t.mim)],
      <(String?, String?)>[
        ('PNDM4', 'MIM 618858'),
        (null, 'MIM 616214'),
        ('MODY10', 'MIM 613370'),
        ('IDDM2', 'MIM 125852'),
      ],
    );
    expect(likely[2].mondo, 'MONDO:0013240');
    expect(likely[2].medgen, 'C3150617');
    // ClinVar's placeholder names no condition, and so has nothing to cite.
    final ClinVarTrait unnamed = groups[0].$2.single;
    expect(unnamed.placeholder, isTrue);
    expect(<Object?>[unnamed.medgen, unnamed.symbol, unnamed.mim], <Object?>[
      null,
      null,
      null,
    ]);

    // A snapshot baked before conditions carried identifiers still names them.
    final Map<String, dynamic> older = snapshotJson()..remove('traits');
    final ClinVarVariant bare = GeneClinVar.fromJson(
      older,
      TestCatalog.insulin,
    ).variants.firstWhere((v) => v.id == '1455986');
    expect(
      bare.conditionsByClass[1].$2.map((ClinVarTrait t) => t.name),
      likely.map((ClinVarTrait t) => t.name),
    );
    expect(bare.conditionsByClass[1].$2.every((t) => t.mim == null), isTrue);
  });

  test('combined wordings group by their Mendelian terms', () {
    expect(
      ClinVarGroup.of('Pathogenic/Likely pathogenic'),
      ClinVarGroup.pathogenic,
    );
    expect(ClinVarGroup.of('Benign/Likely benign'), ClinVarGroup.benign);
    expect(
      ClinVarGroup.of('Conflicting classifications of pathogenicity'),
      ClinVarGroup.conflicting,
    );
    // A risk allele for one condition does not undo a pathogenic call for
    // another, and never makes one.
    expect(
      ClinVarGroup.of('Likely pathogenic/Likely risk allele'),
      ClinVarGroup.pathogenic,
    );
    expect(
      ClinVarGroup.of('Pathogenic/Likely pathogenic/Likely risk allele'),
      ClinVarGroup.pathogenic,
    );
    expect(
      ClinVarGroup.of('Uncertain significance/Uncertain risk allele'),
      ClinVarGroup.uncertain,
    );
    expect(ClinVarGroup.of('Likely risk allele'), ClinVarGroup.other);
    expect(ClinVarGroup.of('not provided'), ClinVarGroup.other);
    expect(ClinVarGroup.of('Pathogenic/Benign'), ClinVarGroup.conflicting);
    expect(ClinVarGroup.of('new classification'), ClinVarGroup.other);
    // Terms off the Mendelian axis follow a semicolon, as in CFTR's records,
    // and move a record no more than they do after a slash.
    expect(
      ClinVarGroup.of('Pathogenic; drug response'),
      ClinVarGroup.pathogenic,
    );
    expect(
      ClinVarGroup.of('Pathogenic/Likely pathogenic; risk factor'),
      ClinVarGroup.pathogenic,
    );
    expect(
      ClinVarGroup.of('Uncertain significance; drug response'),
      ClinVarGroup.uncertain,
    );
    expect(ClinVarGroup.of('Benign; other'), ClinVarGroup.benign);
    expect(
      ClinVarGroup.of('Conflicting classifications of pathogenicity; other'),
      ClinVarGroup.conflicting,
    );
    expect(ClinVarGroup.of('drug response'), ClinVarGroup.other);
    expect(ClinVarGroup.of('risk factor; association'), ClinVarGroup.other);
    expect(
      ClinVarGroup.mostSevere(<ClinVarGroup>[
        ClinVarGroup.benign,
        ClinVarGroup.uncertain,
        ClinVarGroup.conflicting,
      ]),
      ClinVarGroup.conflicting,
    );
  });

  for (final String defect in <String>[
    'assembly',
    'allele',
    'genomic',
    'strand',
    'duplicate',
    'count',
    'run',
    'gene',
  ]) {
    test('rejects $defect mismatch', () {
      final Map<String, dynamic> json = snapshotJson();
      final List<dynamic> variants = json['variants'] as List<dynamic>;
      final Map<String, dynamic> first = variants.first as Map<String, dynamic>;
      switch (defect) {
        case 'assembly':
          json['assembly'] = 'GRCh37';
        case 'allele':
          first['ref'] = first['alt'];
        case 'genomic':
          first['genomic'] = 1;
        case 'strand':
          first['genomic_alt'] = first['alt'];
        case 'duplicate':
          variants.add(variants.first);
          json['searched_records'] = (json['searched_records'] as int) + 1;
        case 'count':
          json['searched_records'] = 1;
        case 'run':
          ((json['runs'] as List<dynamic>).first
                  as Map<String, dynamic>)['step'] =
              0;
        case 'gene':
          json['gene'] = 'INS-IGF2';
      }
      expect(
        () => GeneClinVar.fromJson(json, TestCatalog.insulin),
        throwsFormatException,
      );
    });
  }

  test('residue mapping is rechecked against the current coding sequence', () {
    final Map<String, dynamic> json = snapshotJson();
    final Map<String, dynamic> v = (json['variants'] as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .firstWhere((v) => v['residue'] == 96);
    v['residue'] = 95;
    expect(
      GeneClinVar.fromJson(
        json,
        TestCatalog.insulin,
      ).matchesRecord(insulin()),
      isFalse,
    );
  });
}
