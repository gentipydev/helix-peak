import 'anatomy_stages.dart';

/// The number written at the start of each row of a lettered page.
///
/// Every sequence view a reader already knows puts a position in the margin,
/// and without one the only way to find residue 175 on a page of 393 was to
/// count squares. The numbering is the field's, not the grid's:
///
/// - the transcript in coding-DNA numbering: the 5′ UTR counts back from the
///   start codon (−59 … −1), the coding sequence from its A (1 …), and the
///   3′ UTR after the stop (*1 …);
/// - a precursor from its initiator methionine;
/// - each released chain from its own first residue;
/// - a region opened into its DNA from its own first base.
///
/// Pure, so the layout can reserve a gutter as wide as the widest label without
/// holding a font metric: the ruler is set in a monospace face, where a label's
/// width is its length.
abstract final class AnatomyRuler {
  /// Point size of a label.
  static const double fontSize = 9;

  /// A monospace advance, as a fraction of [fontSize]. JetBrains Mono's is 600
  /// units to the em.
  static const double advance = 0.6;

  /// Air between a label and the first square of its row.
  static const double pad = 5;

  /// Air between the screen edge and the widest label.
  static const double lead = 3;

  /// Whether [stage] carries a ruler at all. The gene is drawn as regions, and
  /// a base position in its margin would number cells nobody can see.
  static bool rules(AnatomyStage stage) => stage.kind != StageKind.gene;

  /// The label for the row that starts at [cell].
  static String? labelAt(AnatomyStage stage, int cell) {
    if (!rules(stage) || cell < 0 || cell >= stage.count) {
      return null;
    }
    final StageBlock block = stage.blocks[stage.blockOf(cell)];
    return switch (stage.kind) {
      StageKind.gene => null,
      StageKind.mrna => _transcript(stage, cell),
      StageKind.maturePeptides => '${cell - block.start + 1}',
      StageKind.protein ||
      StageKind.proprotein ||
      StageKind.dna => '${cell + 1}',
    };
  }

  static String _transcript(AnatomyStage stage, int cell) {
    // A coding transcript is always three blocks — see `_transcriptBlocks` —
    // and a non-coding one is one block numbered from its first base.
    if (stage.blocks.length != 3 || !stage.blocks[1].framed) {
      return '${cell + 1}';
    }
    final StageBlock utr5 = stage.blocks[0];
    final StageBlock cds = stage.blocks[1];
    if (cell < cds.start) {
      return '−${utr5.count - (cell - utr5.start)}';
    }
    if (cell < cds.start + cds.count) {
      return '${cell - cds.start + 1}';
    }
    return '*${cell - (cds.start + cds.count) + 1}';
  }

  /// The longest label [stage] can ever write, in characters.
  ///
  /// An upper bound rather than a walk of the row starts: every numbering here
  /// grows in magnitude away from its zero, so the widest label is the one at
  /// the far end of each block.
  static int widest(AnatomyStage stage) {
    if (!rules(stage)) {
      return 0;
    }
    int digits(int value) => '$value'.length;
    if (stage.kind == StageKind.mrna &&
        stage.blocks.length == 3 &&
        stage.blocks[1].framed) {
      return <int>[
        1 + digits(stage.blocks[0].count),
        digits(stage.blocks[1].count),
        1 + digits(stage.blocks[2].count),
      ].reduce((int a, int b) => a > b ? a : b);
    }
    if (stage.kind == StageKind.maturePeptides) {
      return stage.blocks
          .map((StageBlock b) => digits(b.count))
          .fold(1, (int a, int b) => a > b ? a : b);
    }
    return digits(stage.count);
  }

  /// The gutter a layout keeps on its left for [stage]'s ruler, or 0.
  static double gutterFor(AnatomyStage stage) {
    final int chars = widest(stage);
    return chars == 0 ? 0 : lead + chars * fontSize * advance + pad;
  }
}
