import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/core/catalog/protein_target.dart';
import 'package:helixpeek/features/lab/folding/domain/folding_track.dart';

import '../../../../support/test_catalog.dart';
import '../folding_fixtures.dart';

void main() {
  test('every protein’s track parses, one chain per node of its fold', () {
    for (final ProteinTarget protein in TestCatalog.all) {
      final FoldingTrack track = foldingOf(protein);
      expect(track.chains.map((FoldChain c) => c.node).toList(), <String>[
        for (final StructureChain chain in protein.chains)
          if (chain.node != 'bonds') chain.node,
      ], reason: protein.slug);
      expect(track.pdb, protein.structure!.pdb, reason: protein.slug);
    }
  });

  test(
    'the prion protein is its mature chain, most of its first half loose',
    () {
      final FoldingTrack track = foldingOf(target('prion'));
      final List<FoldResidue> chain = track.chains.single.residues;
      expect(chain.first.number, 23);
      expect(chain.last.number, 230);
      expect(chain, hasLength(208));
      int count(FoldPlace place) =>
          chain.where((FoldResidue r) => r.place == place).length;
      expect(count(FoldPlace.ordered), 109);
      expect(count(FoldPlace.disordered), 98);
      expect(count(FoldPlace.absent), 1);
      expect(
        chain
            .where((FoldResidue r) => r.number < 117)
            .every((FoldResidue r) => !r.isOrdered),
        isTrue,
      );
    },
  );

  test(
    'an ordered residue carries its place and shape, a loose one neither',
    () {
      for (final FoldResidue residue in foldingOf(
        target('prion'),
      ).chains.single.residues) {
        expect(residue.ca != null, residue.isOrdered);
        expect(residue.shape != null, residue.isOrdered);
      }
    },
  );

  test('the frame is the stored model’s: centred, its longest side one', () {
    for (final ProteinTarget protein in TestCatalog.all) {
      final FoldingTrack track = foldingOf(protein);
      final List<double> side = <double>[
        track.boundsMax.$1 - track.boundsMin.$1,
        track.boundsMax.$2 - track.boundsMin.$2,
        track.boundsMax.$3 - track.boundsMin.$3,
      ];
      expect(
        side.reduce((double a, double b) => a > b ? a : b),
        closeTo(1, 1e-5),
      );
      expect(track.angstromsPerUnit, greaterThan(1), reason: protein.slug);
    }
  });

  test('a payload for another protein is refused', () {
    expect(
      () => FoldingTrack.fromJson(
        readJson(foldingAsset(target('prion'))),
        target('insulin'),
      ),
      throwsFormatException,
    );
  });

  test('a chain the fold has no node for is refused', () {
    final Map<String, dynamic> json = readJson(foldingAsset(target('prion')));
    ((json['chains'] as List<dynamic>).single as Map<String, dynamic>)['node'] =
        'chainB';
    expect(
      () => FoldingTrack.fromJson(json, target('prion')),
      throwsFormatException,
    );
  });

  test('a chain with a gap in it is refused', () {
    final Map<String, dynamic> json = readJson(foldingAsset(target('prion')));
    final Map<String, dynamic> chain =
        (json['chains'] as List<dynamic>).single as Map<String, dynamic>;
    (chain['residues'] as List<dynamic>).removeAt(100);
    expect(
      () => FoldingTrack.fromJson(json, target('prion')),
      throwsFormatException,
    );
  });

  test('a track with no frame to draw it in is refused', () {
    final Map<String, dynamic> json = readJson(foldingAsset(target('prion')));
    (json['frame'] as Map<String, dynamic>).remove('bounds');
    expect(
      () => FoldingTrack.fromJson(json, target('prion')),
      throwsFormatException,
    );
  });
}
