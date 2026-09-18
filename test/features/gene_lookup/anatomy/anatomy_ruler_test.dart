import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeak/features/gene_lookup/presentation/anatomy/anatomy_ruler.dart';
import 'package:helixpeak/features/gene_lookup/presentation/anatomy/anatomy_selection.dart';
import 'package:helixpeak/features/gene_lookup/presentation/anatomy/anatomy_stages.dart';

import 'anatomy_fixture.dart';

void main() {
  final AnatomyModel model = AnatomyModel.derive(insulin());
  final AnatomyStage gene = model.stages[0];
  final AnatomyStage mrna = model.stages[1];
  final AnatomyStage protein = model.stages[2];
  final AnatomyStage mature = model.stages[3];

  test('the gene carries no ruler', () {
    expect(AnatomyRuler.rules(gene), isFalse);
    expect(AnatomyRuler.labelAt(gene, 0), isNull);
    expect(AnatomyRuler.gutterFor(gene), 0);
  });

  test('the transcript is numbered the way a coding DNA reference is', () {
    // 59 bases of 5' UTR, 333 of coding sequence, 73 of 3' UTR.
    expect(AnatomyRuler.labelAt(mrna, 0), '−59');
    expect(AnatomyRuler.labelAt(mrna, 58), '−1');
    expect(AnatomyRuler.labelAt(mrna, 59), '1');
    expect(AnatomyRuler.labelAt(mrna, 59 + 332), '333');
    expect(AnatomyRuler.labelAt(mrna, 59 + 333), '*1');
    expect(AnatomyRuler.labelAt(mrna, 464), '*73');
    expect(AnatomyRuler.widest(mrna), 3);
  });

  test('a precursor counts from its methionine, a chain from its own start', () {
    expect(AnatomyRuler.labelAt(protein, 0), '1');
    expect(AnatomyRuler.labelAt(protein, 109), '110');
    for (final StageBlock chain in mature.blocks) {
      expect(AnatomyRuler.labelAt(mature, chain.start), '1');
    }
    // The C-peptide's 31 is the longest of the three.
    expect(AnatomyRuler.widest(mature), 2);
  });

  test('a region opened into its DNA counts from its own first base', () {
    final AnatomyStage intron = AnatomySelection.of(model, 6000).stage;
    expect(AnatomyRuler.labelAt(intron, 0), '1');
    expect(AnatomyRuler.labelAt(intron, 786), '787');
    expect(AnatomyRuler.widest(intron), 3);
    expect(AnatomyRuler.gutterFor(intron), greaterThan(AnatomyRuler.gutterFor(mature)));
  });
}
