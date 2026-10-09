import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/core/catalog/protein_target.dart';
import 'package:helixpeek/core/catalog/protein_track.dart';
import 'package:helixpeek/core/theme/anatomy_colors.dart';

import '../../support/built_on_demand.dart';
import '../../support/test_catalog.dart';

void main() {
  group('a predicted fold’s tints', () {
    test('are the four bands of pLDDT, by the names the service sends', () {
      // The names are the nodes the backend's bake cuts a model into
      // (`alphafold.BANDS`), and a tint the app does not know throws.
      expect(
        <String>[
          'plddtVeryHigh',
          'plddtConfident',
          'plddtLow',
          'plddtVeryLow',
        ].map(ChainTint.fromWire),
        <ChainTint>[
          ChainTint.plddtVeryHigh,
          ChainTint.plddtConfident,
          ChainTint.plddtLow,
          ChainTint.plddtVeryLow,
        ],
      );
      expect(() => ChainTint.fromWire('plddtUnheardOf'), throwsArgumentError);
    });

    test('are AlphaFold DB’s own colours, kept as they are', () {
      const List<Color> alphaFold = <Color>[
        Color(0xFF0053D6),
        Color(0xFF65CBF3),
        Color(0xFFFFDB13),
        Color(0xFFFF7D45),
      ];
      const List<ChainTint> bands = <ChainTint>[
        ChainTint.plddtVeryHigh,
        ChainTint.plddtConfident,
        ChainTint.plddtLow,
        ChainTint.plddtVeryLow,
      ];
      // In the palette the walk is drawn in too: the convention is the
      // point, so the filter that softens the residues leaves these alone.
      for (final AnatomyColors palette in <AnatomyColors>[
        AnatomyColors.dark,
        AnatomyColors.kaleido,
      ]) {
        expect(
          bands.map((ChainTint tint) => tint.of(palette)).toList(),
          alphaFold,
        );
      }
    });

    test('are named by their band, and a chain’s by its record', () {
      expect(
        ChainTint.values.map((ChainTint tint) => tint.confidence).toList(),
        <String?>[
          null,
          null,
          null,
          null,
          'pLDDT ≥ 90',
          'pLDDT 70–90',
          'pLDDT 50–70',
          'pLDDT < 50',
        ],
      );
    });

    test('lerp and copy with the rest of the palette', () {
      const AnatomyColors dark = AnatomyColors.dark;
      final AnatomyColors moved = dark.copyWith(
        plddtVeryLow: const Color(0xFF000000),
      );
      expect(moved.plddtVeryLow, const Color(0xFF000000));
      expect(moved.plddtVeryHigh, dark.plddtVeryHigh);
      expect(moved.roleMature1, dark.roleMature1);
      expect(dark.lerp(moved, 0).plddtVeryLow, dark.plddtVeryLow);
      expect(dark.lerp(moved, 1).plddtVeryLow, const Color(0xFF000000));
      expect(dark.lerp(moved, 1).plddtLow, dark.plddtLow);
    });
  });

  group('where a fold is from', () {
    test('an AlphaFold DB entry is a prediction, and is named as one', () {
      final StructureChrome chrome = BuiltOnDemand.modelled().structure!;
      expect(chrome.predicted, isTrue);
      expect(chrome.source, 'AlphaFold DB AF-P61769-F1');
      expect(chrome.modelled, (21, 119));
    });

    test('every curated fold is an experiment’s, named as it always was', () {
      for (final ProteinTarget target in TestCatalog.all) {
        final StructureChrome chrome = target.structure!;
        expect(chrome.predicted, isFalse, reason: target.slug);
        expect(chrome.source, 'PDB ${chrome.pdb}', reason: target.slug);
        expect(
          target.chains.every((StructureChain c) => c.tint.confidence == null),
          isTrue,
          reason: target.slug,
        );
      }
    });
  });

  group('a protein built on demand, as the service serves it', () {
    test('with its model: its bands and bridges, and its words', () {
      final ProteinTarget target = BuiltOnDemand.modelled();
      expect(target.state(TrackKind.structure), TrackState.ready);
      expect(
        target.chains.map((StructureChain c) => (c.node, c.tint)).toList(),
        <(String, ChainTint)>[
          ('plddtVeryHigh', ChainTint.plddtVeryHigh),
          ('plddtConfident', ChainTint.plddtConfident),
          ('plddtLow', ChainTint.plddtLow),
          ('bonds', ChainTint.cysteine),
        ],
      );
      expect(target.structure!.label, 'the predicted fold');
      expect(target.structure!.count, 99);
    });

    test('without one: no words, no chains, and the state its track is in', () {
      for (final (String wire, TrackState state) in <(String, TrackState)>[
        ('refused', TrackState.refused),
        ('pending', TrackState.pending),
        ('absent', TrackState.absent),
      ]) {
        final ProteinTarget target = BuiltOnDemand.unmodelled(wire);
        expect(target.structure, isNull);
        expect(target.chains, isEmpty);
        expect(target.state(TrackKind.structure), state);
        // The row carries bare states: a refusal's sentence is the track's.
        expect(target.reason(TrackKind.structure), isNull);
      }
    });
  });
}
