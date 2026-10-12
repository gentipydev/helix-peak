// A protein built on demand in two generations of its fold, for the tests of
// a fold published again while the app runs. Made up to the service's shapes
// (`/protein/{slug}`, `/protein/{slug}/tracks`); no payload stands behind it.

/// Transthyretin as it was built (AlphaFold DB's model, drawn still) and as
/// a backfill publishes it (PDB 8C86, with its fold): each its row and its
/// track rows.
abstract final class BuiltFold {
  static Map<String, dynamic> row(String generation) => <String, dynamic>{
    'slug': 'ttr',
    'display': 'Transthyretin',
    'gene': 'TTR',
    'uniprot': 'P02766',
    'accession': 'NG_009490.1',
    'summary': 'Built on demand.',
    'facts': <String, int>{'residues': 147, 'exons': 4, 'chains': 1, 'bridges': 0},
    'catalog_order': null,
    'chain': null,
    'chains': generation == 'pdb'
        ? <Map<String, String>>[<String, String>{'node': 'chainA', 'tint': 'mature1'}]
        : <Map<String, String>>[
            <String, String>{'node': 'plddtVeryHigh', 'tint': 'plddtVeryHigh'},
            <String, String>{'node': 'plddtLow', 'tint': 'plddtLow'},
          ],
    'structure': <String, dynamic>{
      'pdb': generation == 'pdb' ? '8C86' : 'AF-P02766-F1',
      'modelled': null,
      'label': generation == 'pdb' ? 'the subunit' : 'the predicted fold',
      'count': 127,
      'unit': 'residues',
      'sentence': 'A sentence.',
      'semantics': 'Its semantics.',
    },
    'regions': <Map<String, dynamic>>[
      <String, dynamic>{'label': 'Signal peptide', 'short': 'S', 'start': 1, 'end': 20,
                        'origin': 1, 'kept': false},
      <String, dynamic>{'label': 'Transthyretin', 'short': 'T', 'start': 21, 'end': 147,
                        'origin': 21, 'kept': true},
    ],
    'tracks': <String, String>{
      'record': 'ready',
      'structure': 'ready',
      'folding': generation == 'pdb' ? 'ready' : 'absent',
    },
  };

  static Map<String, dynamic> tracks(String generation, {String? framedIn}) {
    final bool pdb = generation == 'pdb';
    final String glb = pdb ? 'b' * 64 : 'a' * 64;
    final String scene = pdb ? '2' * 64 : '1' * 64;
    return <String, dynamic>{
      'record': _ref('record/ttr.0123456789ab.json', '0' * 64),
      'structure': <String, dynamic>{
        ..._ref('structure/ttr.${scene.substring(0, 12)}.fsceneb', scene),
        'format': 'fsceneb',
        'provenance': <String, dynamic>{
          'pdb': pdb ? '8C86' : 'AF-P02766-F1',
          'nodes': pdb ? <String>['chainA'] : <String>['plddtVeryHigh', 'plddtLow'],
          'glb': <String, dynamic>{'path': 'structure/ttr.glb', 'sha256': glb},
        },
      },
      'folding': pdb
          ? <String, dynamic>{
              ..._ref('folding/ttr.${'3' * 12}.json', '3' * 64),
              'provenance': <String, dynamic>{
                'frame': <String, dynamic>{'glb_sha256': framedIn ?? glb},
              },
            }
          : <String, dynamic>{'state': 'absent', 'provenance': <String, dynamic>{}},
    };
  }

  static Map<String, dynamic> _ref(String path, String sha256) => <String, dynamic>{
    'state': 'ready',
    'reason': null,
    'url': 'https://cdn.example/$path',
    'format': 'json',
    'bytes': 4,
    'sha256': sha256,
    'content_encoding': null,
    'provenance': <String, dynamic>{},
  };
}
