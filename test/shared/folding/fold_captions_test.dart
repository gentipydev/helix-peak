import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/core/catalog/protein_target.dart';
import 'package:helixpeek/shared/folding/fold_captions.dart';
import 'package:helixpeek/shared/folding/fold_timeline.dart';

import '../../features/lab/trafficking/trafficking_fixtures.dart'
    show namesAProtein;
import '../../support/test_catalog.dart';
import 'folding_fixtures.dart';

void main() {
  FoldCaptions captionsOf(String slug) =>
      FoldCaptions(geometryOf(target(slug)));

  test('each step is named with what it moves, counted off the track', () {
    final FoldCaptions insulin = captionsOf('insulin');
    expect(
      insulin.captionOf(FoldStep.collapse),
      'Hydrophobic collapse · 22 of 51 residues hydrophobic '
      '(Kyte\u2060–\u2060Doolittle\u00a0>\u00a00)',
    );
    expect(insulin.captionOf(FoldStep.helices), 'Helices · 3 (30 residues)');
    expect(insulin.captionOf(FoldStep.strands), 'Strands · none');
    expect(
      insulin.captionOf(FoldStep.bridges),
      'Disulfides · Cys31–Cys96, Cys43–Cys109, Cys95–Cys100',
    );
  });

  test('past three bridges, the rest are counted', () {
    expect(
      captionsOf('app').captionOf(FoldStep.bridges),
      'Disulfides · Cys38–Cys62, Cys73–Cys117, Cys98–Cys105 +3',
    );
  });

  test('a fold with nothing to coil, pair or bridge says none', () {
    expect(captionsOf('oxytocin').captionOf(FoldStep.helices), 'Helices · none');
    expect(
      captionsOf('hemoglobin').captionOf(FoldStep.bridges),
      'Disulfides · none',
    );
  });

  test('what the entry never placed is left to the header', () {
    // 98 of the prion's residues have no place; the header's range says so,
    // and no caption says it again.
    final FoldCaptions prion = captionsOf('prion');
    for (final FoldStep step in FoldStep.values) {
      expect(prion.captionOf(step), isNot(contains('98')));
    }
    expect(
      prion.captionOf(FoldStep.collapse),
      contains('of 109 residues'),
    );
  });

  test('no caption names a protein', () {
    for (final ProteinTarget protein in TestCatalog.all) {
      final FoldCaptions captions = captionsOf(protein.slug);
      for (final FoldStep step in FoldStep.values) {
        final String text = captions.captionOf(step);
        expect(namesAProtein(text), isFalse, reason: '${protein.slug}: $text');
      }
    }
  });
}
