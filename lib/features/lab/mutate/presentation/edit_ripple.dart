import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/painting.dart';

import '../../../../shared/anatomy/anatomy_layout.dart';
import '../../../../shared/anatomy/anatomy_scene.dart';
import '../../../../shared/anatomy/anatomy_stages.dart';
import '../domain/apply_edit.dart';

/// The index of [model]'s protein page, or -1 for a record that makes none.
int proteinStageOf(AnatomyModel model) =>
    model.stages.indexWhere((AnatomyStage s) => s.kind == StageKind.protein);

/// Where each residue of the original protein goes in the edited one, or -1
/// where the edit loses it.
///
/// Up to the first residue the edit changes, every residue is where it was.
/// From there it depends on what the edit did to the frame: in place for a
/// substitution, a frameshift or a stop, where the residues that remain are
/// read at the same numbers; shifted by the codons gained or lost for an
/// in-frame indel. A residue past the edited protein's end is lost, and the
/// painter lets it drift away and shrink as it does every departing cell.
Int32List rippleTargets({
  required String before,
  required String after,
  required EditOutcome outcome,
}) {
  final Int32List target = Int32List(before.length);
  final int first = math.max(0, (outcome.codonIndex ?? 1) - 1);
  final int delta = after.length - before.length;
  for (int i = 0; i < before.length; i++) {
    int landing = i;
    if (i >= first && outcome.kind == EditOutcomeKind.inFrameIndel) {
      if (delta < 0 && i < first - delta) {
        landing = -1;
      } else if (delta != 0) {
        landing = i + delta;
      }
    }
    target[i] = landing >= 0 && landing < after.length ? landing : -1;
  }
  return target;
}

/// The size a scene of [stages] needs in [viewport]: the viewport, or taller
/// where a page insists on it.
Size canvasFor(Iterable<AnatomyStage> stages, Size viewport) {
  double height = viewport.height;
  for (final AnatomyStage stage in stages) {
    height = math.max(height, AnatomyLayout.heightFor(stage, viewport));
  }
  return Size(viewport.width, height);
}

/// The original protein page turning into the edited one.
///
/// A scene between two models rather than two stages of one: [before]'s
/// protein page is the source, [after]'s is the destination, and each residue
/// travels by [target]. Everything a scene carries is taken from the two
/// resting scenes the anatomy itself builds, so the colours are the ones the
/// walk gives each residue, and nothing about a slot is decided here. The
/// source is from another model, so, as for a selection, its index is -1.
///
/// Where [after] makes no protein at all, the original page is its own
/// destination and every residue leaves it.
AnatomyScene editRipple({
  required AnatomyModel before,
  required AnatomyModel after,
  required Int32List target,
  required Size viewport,
}) {
  final int from = proteinStageOf(before);
  final int to = proteinStageOf(after);
  assert(from >= 0, 'the original record makes a protein');
  final AnatomyStage source = before.stages[from];
  final AnatomyStage? destination = to < 0 ? null : after.stages[to];
  final Size canvas = canvasFor(<AnatomyStage>[source, ?destination], viewport);
  final AnatomyScene was = AnatomyScene.resting(
    model: before,
    index: from,
    canvas: canvas,
    viewport: viewport,
  );
  final AnatomyScene now = to < 0
      ? was
      : AnatomyScene.resting(
          model: after,
          index: to,
          canvas: canvas,
          viewport: viewport,
        );
  final Int32List landing = to < 0
      ? (Int32List(source.count)..fillRange(0, source.count, -1))
      : target;

  final int count = source.count;
  final Uint8List carriesLetter = Uint8List(count);
  final Uint16List slotPair = Uint16List(count);
  final Uint8List claimed = Uint8List(now.to.count);
  final Set<int> pairs = <int>{};
  for (int cell = 0; cell < count; cell++) {
    final int lands = landing[cell];
    // A resting scene pairs each cell's slot with itself.
    final int fromSlot = was.slotPair[cell] ~/ CellSlot.count;
    final int toSlot = lands >= 0
        ? now.slotPair[lands] % CellSlot.count
        : fromSlot;
    if (lands >= 0 && claimed[lands] == 0) {
      claimed[lands] = 1;
      carriesLetter[cell] = 1;
    }
    final int pair = fromSlot * CellSlot.count + toSlot;
    slotPair[cell] = pair;
    pairs.add(pair);
  }
  return AnatomyScene(
    model: after,
    fromIndex: -1,
    toIndex: to < 0 ? from : to,
    from: source,
    to: now.to,
    fromLayout: was.fromLayout,
    toLayout: now.toLayout,
    target: landing,
    carriesLetter: carriesLetter,
    slotPair: slotPair,
    usedPairs: pairs.toList(growable: false),
    canvas: canvas,
    viewport: viewport,
  );
}
