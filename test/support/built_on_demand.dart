import 'dart:convert';
import 'dart:io';

import 'package:helixpeek/core/biology/gene_record.dart';
import 'package:helixpeek/core/catalog/protein_target.dart';
import 'package:helixpeek/features/gene_lookup/data/models/gene_record_dto.dart';

/// A protein built on demand, for the tests of what the walk does with one.
///
/// Beta-2-microglobulin, the first one the resolver built: its stored record,
/// byte for byte (`built_on_demand/gene_b2m.json`), and its row as the
/// service serves it. A signal peptide, one chain of 99 residues and one
/// disulfide, which is every case the fold page of such a protein has.
///
/// These are not under `test/fixtures/`, which holds the twenty's and is not
/// added to.
abstract final class BuiltOnDemand {
  /// The record the resolver stored for B2M.
  static GeneRecord record() => GeneRecordDto.fromJson(
    jsonDecode(
          File('test/support/built_on_demand/gene_b2m.json').readAsStringSync(),
        )
        as Map<String, dynamic>,
  ).toEntity();

  /// The row once its model is made: the fold page's words and chains as
  /// `pipeline/structure/alphafold.py` wrote them for AlphaFold DB's
  /// `AF-P61769-F1`, baked by hand on 2026-10-08.
  static ProteinTarget modelled() => ProteinTarget.fromJson(<String, dynamic>{
    ..._row,
    'chains': <Map<String, String>>[
      <String, String>{'node': 'plddtVeryHigh', 'tint': 'plddtVeryHigh'},
      <String, String>{'node': 'plddtConfident', 'tint': 'plddtConfident'},
      <String, String>{'node': 'plddtLow', 'tint': 'plddtLow'},
      <String, String>{'node': 'bonds', 'tint': 'cysteine'},
    ],
    'structure': <String, dynamic>{
      'pdb': 'AF-P61769-F1',
      'modelled': <int>[21, 119],
      'label': 'the predicted fold',
      'count': 99,
      'unit': 'residues',
      'sentence':
          'AlphaFold prediction, mean pLDDT 97.0. 99% of residues at 70 or '
          'over.',
      'semantics':
          "AlphaFold's predicted fold of Beta-2-microglobulin, residues 21 to "
          '119, coloured by confidence: 96% very high, 3% confident, 1% low. '
          'Its disulfide bridge is drawn. Drag to turn it.',
    },
    'tracks': <String, String>{..._tracks, 'structure': 'ready'},
  });

  /// The row of a protein with no model, its structure track in [state]:
  /// `refused`, `pending` or `absent`. No words and no chains for a fold,
  /// which is how the service serves B2M's row before its model is made.
  static ProteinTarget unmodelled(String state) =>
      ProteinTarget.fromJson(<String, dynamic>{
        ..._row,
        'chains': <dynamic>[],
        'structure': null,
        'tracks': <String, String>{..._tracks, 'structure': state},
      });

  static const Map<String, dynamic> _row = <String, dynamic>{
    'slug': 'b2m',
    'display': 'Beta-2-microglobulin',
    'gene': 'B2M',
    'uniprot': 'P61769',
    'accession': 'NG_012920.2',
    'summary':
        'Made by B2M on chromosome 15. Built on demand from UniProt P61769 '
        'and MANE Select NM_004048.4, not curated by hand.',
    'facts': <String, int>{
      'residues': 119,
      'exons': 4,
      'chains': 1,
      'bridges': 1,
    },
    'catalog_order': null,
    'chain': null,
  };

  static const Map<String, String> _tracks = <String, String>{
    'record': 'ready',
    'constraint': 'ready',
    'impact': 'absent',
    'clinvar': 'absent',
    'impact_explanations': 'absent',
  };
}
