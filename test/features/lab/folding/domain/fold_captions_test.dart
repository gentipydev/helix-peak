import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/core/catalog/protein_target.dart';
import 'package:helixpeek/features/lab/folding/domain/fold_captions.dart';
import 'package:helixpeek/features/lab/folding/domain/fold_timeline.dart';

import '../../../../support/test_catalog.dart';
import '../../trafficking/trafficking_fixtures.dart' show namesAProtein;
import '../folding_fixtures.dart';

void main() {
  FoldCaptions captionsOf(String slug) =>
      FoldCaptions(geometryOf(target(slug)));

  test(
    'it says it is an illustration, not a simulation, and what is measured',
    () {
      final String note = captionsOf('prion').illustration;
      expect(note, startsWith('An illustration, not a simulation.'));
      expect(note, contains('4KML'));
    },
  );

  test('the prion’s loose residues are counted, not named', () {
    expect(
      captionsOf('prion').looseNote,
      '98 residues have no fixed shape and stay loose throughout: the '
      'experiment that solved this structure never placed them.',
    );
    expect(captionsOf('lysozyme').looseNote, isNull);
  });

  test('each step says what moves, counted off the track', () {
    final FoldCaptions prion = captionsOf('prion');
    expect(
      prion.captionOf(FoldStep.bridges),
      startsWith('One disulfide bridge snaps shut: Cys179–Cys214.'),
    );
    expect(prion.captionOf(FoldStep.helices), contains('71 residues'));
    final FoldCaptions insulin = captionsOf('insulin');
    expect(
      insulin.captionOf(FoldStep.bridges),
      startsWith('Three disulfide bridges snap shut:'),
    );
    expect(
      insulin.captionOf(FoldStep.strands),
      startsWith('No residue of this fold sits in a strand'),
    );
  });

  test('a fold with nothing to pair, or to bridge, says so', () {
    final FoldCaptions hemoglobin = captionsOf('hemoglobin');
    expect(
      hemoglobin.captionOf(FoldStep.bridges),
      startsWith('No disulfide bridge holds this fold'),
    );
    expect(
      captionsOf('oxytocin').captionOf(FoldStep.helices),
      'No residue of this fold sits in a helix, so nothing coils.',
    );
  });

  test('no caption names a protein', () {
    for (final ProteinTarget protein in TestCatalog.all) {
      final FoldCaptions captions = captionsOf(protein.slug);
      for (final String text in <String>[
        for (final FoldStep step in FoldStep.values) captions.captionOf(step),
        captions.illustration,
        ?captions.looseNote,
      ]) {
        expect(namesAProtein(text), isFalse, reason: '${protein.slug}: $text');
      }
    }
  });
}
