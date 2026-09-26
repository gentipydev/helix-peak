import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import 'anatomy_stages.dart';

/// All pieces of one feature, kept in the gene's existing 5′ to 3′ order.
/// This is a DNA inspection, so neither transcription nor a second reverse
/// complement is applied. Shortened introns expose only the available bases.
///
/// A coding feature is read in threes here as well, in the frame the
/// transcript page draws; anything never translated is not.
@immutable
final class AnatomySelection {
  const AnatomySelection._(
    this.stage,
    this.pieces,
    this.lengthBp,
    this.junctions,
  );

  factory AnatomySelection.of(AnatomyModel model, int position) {
    final AnatomyStage gene = model.stages.first;
    final int cell = gene.cellAt(position);
    assert(gene.kind == StageKind.gene && cell >= 0);
    final StageRun selected = gene.runAt(cell);
    final List<StageRun> pieces = gene.runs
        .where((StageRun run) => run.feature == selected.feature)
        .toList(growable: false);
    final List<int> positions = <int>[];
    final List<int> junctions = <int>[];
    final StringBuffer letters = StringBuffer();
    for (final StageRun run in pieces) {
      if (positions.isNotEmpty) {
        junctions.add(positions.length);
      }
      for (int i = run.start; i < run.start + run.count; i++) {
        positions.add(gene.positionAt(i));
        letters.write(gene.letters[i]);
      }
    }
    final Int32List lookup = Int32List(gene.cellForPosition.length)
      ..fillRange(0, gene.cellForPosition.length, -1);
    for (int i = 0; i < positions.length; i++) {
      lookup[positions[i] - gene.geneStart] = i;
    }
    final int? frame = _frameOf(model, positions);
    return AnatomySelection._(
      AnatomyStage(
        kind: StageKind.dna,
        label: selected.labelForms.first,
        sentence: 'Selected DNA bases, in sequence order.',
        unit: 'bases',
        blocks: <StageBlock>[
          StageBlock(
            start: 0,
            count: positions.length,
            framed: frame != null,
            frame: frame ?? 0,
          ),
        ],
        positions: Int32List.fromList(positions),
        positionsPerCell: 1,
        letters: letters.toString(),
        cellForPosition: lookup,
        geneStart: gene.geneStart,
        runs: <StageRun>[
          StageRun(
            label: selected.label,
            kind: selected.kind,
            start: 0,
            count: positions.length,
            lengthBp: selected.lengthBp,
            index: selected.index,
            feature: selected.feature,
          ),
        ],
        runOfCell: Uint16List(positions.length),
      ),
      pieces.length,
      selected.lengthBp,
      List<int>.unmodifiable(junctions),
    );
  }

  /// Where in its codon the first of [positions] falls, if [positions] run
  /// unbroken through the reading frame, and null otherwise.
  ///
  /// Asked of the transcript's coding sequence, the one block the frame is
  /// drawn on: base `i` of the selection has to sit `i` places after the first
  /// there. Every coding feature passes, however an intron splits it — and so
  /// does one exon's share of an uncut coding sequence, which can open part of
  /// the way into a codon. Nothing that is never translated can.
  static int? _frameOf(AnatomyModel model, List<int> positions) {
    if (positions.isEmpty) {
      return null;
    }
    for (final AnatomyStage stage in model.stages) {
      if (stage.kind != StageKind.mrna) {
        continue;
      }
      for (final StageBlock block in stage.blocks) {
        if (!block.framed || block.count == 0) {
          continue;
        }
        final int first = stage.cellAt(positions.first) - block.start;
        for (int i = 0; i < positions.length; i++) {
          final int within = stage.cellAt(positions[i]) - block.start;
          if (within < 0 || within >= block.count || within != first + i) {
            return null;
          }
        }
        return first % 3;
      }
    }
    return null;
  }

  final AnatomyStage stage;
  final int pieces;
  final int lengthBp;

  /// The first cell of every piece after the first: where the gene put an
  /// intron that this view has joined across.
  final List<int> junctions;
  bool get shortened => stage.count < lengthBp;
}
