import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/foundation.dart';

import '../../../../core/biology/amino_acids.dart';
import '../../../../core/theme/anatomy_colors.dart';
import 'anatomy_layout.dart';
import 'anatomy_motion.dart';
import 'anatomy_stages.dart';
import 'anatomy_translation.dart';

// The motion constants moved out so the layout could reach them too, but
// this is still where the scene's readers expect to find them.
export 'anatomy_motion.dart';

/// Colour slots the painter mixes toward the background.
///
/// A gene cell takes the colour of the *piece of the gene* it belongs to; a
/// residue cell takes the colour of what it chemically is. A transcript cell's
/// tile says only whether the base is read: all four bases sit on one neutral,
/// and which of them a cell is rides on its letter. They share one table so a
/// cell can blend from one stage's colour into the next as the stages change.
abstract final class CellSlot {
  static const int intron = 0;
  static const int untranscribed = 1;
  static const int utr5 = 2;
  static const int utr3 = 3;
  static const int exon = 4;
  static const int cds = 5;
  static const int signalPeptide = 6;
  static const int stopCodon = 7;
  static const int mature1 = 8;
  static const int mature2 = 9;
  static const int mature3 = 10;
  static const int adenine = 11;
  static const int thymine = 12;
  static const int guanine = 13;
  static const int cytosine = 14;
  static const int baseUnknown = 15;
  static const int aliphatic = 16;
  static const int aromatic = 17;
  static const int positive = 18;
  static const int negative = 19;
  static const int polar = 20;
  static const int special = 21;
  static const int cysteine = 22;
  static const int aminoUnknown = 23;
  static const int dibasic = 24;
  static const int pending = 25;

  /// The four bases again, washed back toward the ground.
  ///
  /// This is the untranslated end of the transcript, and it is a *colour*, not
  /// an alpha. The painter mixes toward an opaque background precisely so that
  /// it can batch (see `AnatomyPainter`), and the one knob that already does
  /// that — a cell's shade level — is spoken for by the departure fade, which
  /// also fixes the batch's stroke width. Borrowing it here would draw the
  /// UTRs narrower than the coding sequence rather than quieter than it.
  ///
  /// Five more slots is the cheap answer, and the honest one: over an opaque
  /// ground, 45% of a tile *is* another tile.
  ///
  /// They must stay contiguous with [adenine]..[baseUnknown] and in the same
  /// order — [dimOffset] is the whole mapping.
  static const int adenineDim = 26;
  static const int thymineDim = 27;
  static const int guanineDim = 28;
  static const int cytosineDim = 29;
  static const int baseUnknownDim = 30;

  static const int dimOffset = adenineDim - adenine;

  /// The two ends of the reading frame, on the page that draws one.
  ///
  /// Their own slots rather than [stopCodon], which is the *gene* page's role
  /// colour and has to stay a flat red while the transcript's frame is still
  /// closed — the two pages are on screen together for the whole of the splice.
  static const int frameStart = 31;
  static const int frameStop = 32;

  /// How many chains get their own colour before the ordinals wrap. Three is
  /// not a limit on peptides, only on hues: a fourth distinct product reuses
  /// the first. Copies of one product share an ordinal, and so a colour.
  /// [mature1] through [mature3] must stay contiguous for the wrap to work.
  static const int matureCycle = 3;

  static const int count = 33;

  /// A nucleotide cell's colour: which piece of the gene it belongs to.
  ///
  /// Every role answers for itself. [exon] and [cds] cannot both occur — a gene
  /// either has a coding sequence or it does not, and `exon` only survives as a
  /// cell's most specific role in a gene that has none — but they are still two
  /// colours, because which of the two a reader is looking at is the difference
  /// between a gene that makes a protein and one that does not.
  static int forRole(RoleKind? kind, int index) => switch (kind) {
    RoleKind.intron => intron,
    RoleKind.untranscribed => untranscribed,
    RoleKind.utr5 => utr5,
    RoleKind.utr3 => utr3,
    RoleKind.exon => exon,
    RoleKind.coding => cds,
    RoleKind.signalPeptide => signalPeptide,
    RoleKind.stopCodon => stopCodon,
    RoleKind.maturePeptide => mature1 + index % matureCycle,
    RoleKind.dibasic => dibasic,
    // Still read by the ribosome, so still the coding sequence's colour: what
    // sets it apart is its name, and that it is gone from the next page.
    RoleKind.trimmed => cds,
    // Never reached: the role is never set — see [CodonMark]. The frame's two
    // ends are answered from the transcript's own block, in [_slotOf].
    RoleKind.startCodon => frameStart,
    null => cds,
  };

  /// A nucleotide cell's slot: which of the four letters it is.
  ///
  /// All four draw the same tile and the letter carries the colour, so what the
  /// painter reads off the slot is whether the base is [dim]. That is set for a
  /// base in an untranslated end, which is drawn washed back rather than in a
  /// colour of its own — it is still an A, and saying so is what makes the
  /// coding sequence stand out as the part that is *read*.
  static int forBase(String base, {bool dim = false}) {
    final int slot = switch (base.toUpperCase()) {
      'A' => adenine,
      'T' || 'U' => thymine,
      'G' => guanine,
      'C' => cytosine,
      _ => baseUnknown,
    };
    return dim ? slot + dimOffset : slot;
  }

  static int forResidue(String code) => switch (AminoAcids.propertyOf(code)) {
    AminoAcidProperty.aliphatic => aliphatic,
    AminoAcidProperty.aromatic => aromatic,
    AminoAcidProperty.positive => positive,
    AminoAcidProperty.negative => negative,
    AminoAcidProperty.polar => polar,
    AminoAcidProperty.special => special,
    AminoAcidProperty.cysteine => cysteine,
    AminoAcidProperty.unknown => aminoUnknown,
  };
}

/// The colour of a slot, in one place.
///
/// An extension rather than a method on [AnatomyColors] because the slot table
/// lives here, with the screen that uses it, and the theme has no business
/// knowing what an intron is. The grid and the strip beneath it both read this,
/// so the two can never disagree about what a colour means.
extension CellSlotColours on AnatomyColors {
  Color? forSlot(int slot) => switch (slot) {
    CellSlot.intron => roleIntron,
    CellSlot.untranscribed => roleUntranscribed,
    CellSlot.utr5 => roleUtr5,
    CellSlot.utr3 => roleUtr3,
    CellSlot.exon => roleExon,
    CellSlot.cds => roleCds,
    CellSlot.signalPeptide => roleSignal,
    CellSlot.stopCodon => roleStopCodon,
    CellSlot.frameStart => roleStartCodon,
    CellSlot.frameStop => roleStopCodon,
    CellSlot.mature1 => roleMature1,
    CellSlot.mature2 => roleMature2,
    CellSlot.mature3 => roleMature3,
    CellSlot.aliphatic => aminoAliphatic,
    CellSlot.aromatic => aminoAromatic,
    CellSlot.positive => aminoPositive,
    CellSlot.negative => aminoNegative,
    CellSlot.polar => aminoPolar,
    CellSlot.special => aminoSpecial,
    CellSlot.cysteine => aminoCysteine,
    CellSlot.aminoUnknown => aminoUnknown,
    CellSlot.dibasic => dibasic,
    _ => null,
  };

  /// The colour of a whole run, for the strip.
  Color forRun(StageRun run) =>
      forSlot(CellSlot.forRole(run.kind, run.index)) ?? pending;
}

/// One stage, or one transition between two, resolved against a canvas size.
///
/// The pairing is the whole animation. Every cell of [from] asks [to] which
/// cell now owns its first genomic position; a cell that gets an answer travels
/// there, and one that does not is leaving. Translation groups three source
/// bases by their shared destination, folds them together, and only then moves
/// the residue. Backwards uses the same grouping and timeline.
///
/// Forward is always subtractive: each stage's positions are a subset of the one
/// before it, so nothing ever has to appear out of nowhere.
@immutable
final class AnatomyScene {
  const AnatomyScene({
    required this.model,
    required this.fromIndex,
    required this.toIndex,
    required this.from,
    required this.to,
    required this.fromLayout,
    required this.toLayout,
    required this.target,
    required this.carriesLetter,
    required this.slotPair,
    required this.usedPairs,
    required this.canvas,
    required this.viewport,
    this.translation,
  });

  final AnatomyModel model;

  final int fromIndex;
  final int toIndex;

  final AnatomyStage from;
  final AnatomyStage to;

  final AnatomyLayout fromLayout;
  final AnatomyLayout toLayout;

  /// For each cell of [from]: the cell of [to] that absorbed it, or -1.
  final Int32List target;

  /// Which of a merging group draws the arriving letter, so three converging
  /// bases do not stack three glyphs on one residue.
  final Uint8List carriesLetter;

  /// `fromSlot * CellSlot.count + toSlot` per cell, so the painter can blend a
  /// role colour into a residue colour with one lookup.
  final Uint16List slotPair;

  /// The distinct values in [slotPair] — a handful, so the per-frame colour
  /// table only ever rebuilds the pairs this scene actually uses.
  final List<int> usedPairs;

  /// The box the painter draws into. Taller than [viewport] whenever either
  /// end of this scene is the transcript page, which does not fit on a screen.
  final Size canvas;

  /// What the reader can see without scrolling. A fitted stage is fitted to
  /// this, so it lands at the top of the box rather than halfway down it.
  final Size viewport;

  /// Present only for the triplet-to-residue transition.
  final AnatomyTranslation? translation;

  bool get isSelection =>
      from.kind == StageKind.gene && to.kind == StageKind.dna;

  /// Move directly into the readable layout, slowing gently on arrival.
  static double selectionTravelAt(double t) {
    final double remaining = 1 - t.clamp(0.0, 1.0);
    return 1 - remaining * remaining * remaining;
  }

  /// Shed the region colour early, while the bases are still moving. There is
  /// no solid-colour joined pose between the highlighted gene and its DNA.
  static double revealAt(double t) => selectionTravelAt(t / 0.6);

  bool get isTransition => fromIndex != toIndex;

  static AnatomyScene resting({
    required AnatomyModel model,
    required int index,
    required Size canvas,
    required Size viewport,
  }) => _build(
    model: model,
    fromIndex: index,
    toIndex: index,
    canvas: canvas,
    viewport: viewport,
  );

  /// [fromIndex] must be the earlier stage: a backwards swipe plays this same
  /// scene with its progress running from 1 to 0, so there is only ever one
  /// animation to get right.
  static AnatomyScene between({
    required AnatomyModel model,
    required int fromIndex,
    required int toIndex,
    required Size canvas,
    required Size viewport,
    double sourceScrollOffset = 0,
    double targetScrollOffset = 0,
  }) => _build(
    model: model,
    fromIndex: fromIndex,
    toIndex: toIndex,
    canvas: canvas,
    viewport: viewport,
    sourceScrollOffset: sourceScrollOffset,
    targetScrollOffset: targetScrollOffset,
  );

  /// [open] is how far a coding region's codons have formed. The bases land
  /// flush, at 0, and the groove opens from there once they have; a return
  /// leaves from wherever the groove got to.
  static AnatomyScene selection({
    required AnatomyModel model,
    required AnatomyStage selected,
    required Size canvas,
    required Size viewport,
    double sourceScrollOffset = 0,
    double targetScrollOffset = 0,
    bool resting = false,
    double open = 1,
  }) => _build(
    model: model,
    fromIndex: resting ? -1 : 0,
    toIndex: -1,
    fromStage: resting ? selected : null,
    toStage: selected,
    canvas: canvas,
    viewport: viewport,
    sourceScrollOffset: sourceScrollOffset,
    targetScrollOffset: targetScrollOffset,
    toOpen: open,
  );

  static AnatomyScene _build({
    required AnatomyModel model,
    required int fromIndex,
    required int toIndex,
    required Size canvas,
    required Size viewport,
    double sourceScrollOffset = 0,
    double targetScrollOffset = 0,
    AnatomyStage? fromStage,
    AnatomyStage? toStage,
    double toOpen = 1,
  }) {
    final AnatomyStage from = fromStage ?? model.stages[fromIndex];
    final AnatomyStage to = toStage ?? model.stages[toIndex];
    final int count = from.count;

    final Int32List target = Int32List(count);
    final Uint8List carriesLetter = Uint8List(count);
    // Uint16, not Uint8: with thirty-three slots a pair reaches 1,088, and a
    // byte would wrap it to another group's colour without ever failing.
    final Uint16List slotPair = Uint16List(count);
    final Set<int> pairs = <int>{};

    final Uint8List claimed = Uint8List(to.count);

    for (int cell = 0; cell < count; cell++) {
      final int position = from.positionAt(cell);
      final int landing = to.cellAt(position);
      target[cell] = landing;

      if (landing >= 0 && claimed[landing] == 0) {
        claimed[landing] = 1;
        carriesLetter[cell] = 1;
      }

      final int fromSlot = _slotOf(model, from, cell);
      final int toSlot = landing >= 0 ? _slotOf(model, to, landing) : fromSlot;
      final int pair = fromSlot * CellSlot.count + toSlot;
      slotPair[cell] = pair;
      pairs.add(pair);
    }

    final bool translating =
        from.kind == StageKind.mrna &&
        to.kind == StageKind.protein &&
        to.count > 0;
    // A page long enough to scroll leaves from where the reader left it: the
    // earlier one on a swipe forward, by [sourceScrollOffset], and the later
    // one on a swipe back, by [targetScrollOffset]. The translation carries a
    // forward offset itself, per base, so its source is not raised here.
    final AnatomyLayout fromLayout = AnatomyLayout.forStage(
      from,
      canvas,
      viewport,
    ).raisedBy(translating ? 0 : sourceScrollOffset);
    final AnatomyLayout toLayout = AnatomyLayout.forStage(
      to,
      canvas,
      viewport,
    ).raisedBy(targetScrollOffset).opened(toOpen);
    return AnatomyScene(
      model: model,
      fromIndex: fromIndex,
      toIndex: toIndex,
      from: from,
      to: to,
      fromLayout: fromLayout,
      toLayout: toLayout,
      target: target,
      carriesLetter: carriesLetter,
      slotPair: slotPair,
      usedPairs: pairs.toList(growable: false),
      canvas: canvas,
      viewport: viewport,
      translation: translating
          ? AnatomyTranslation(
              target: target,
              fromLayout: fromLayout,
              toLayout: toLayout,
              residueCount: to.count,
              sourceScrollOffset: sourceScrollOffset,
            )
          : null,
    );
  }

  static int _slotOf(AnatomyModel model, AnatomyStage stage, int cell) {
    if (stage.kind == StageKind.gene) {
      // Only the gene is drawn as the pieces it is made of. It is the one page
      // where that is the only readable thing about a cell: 1,431 of them at
      // nine pixels, too small to letter, and the question it exists to answer
      // — what is kept and what is thrown away — is a fact about the region.
      // Every page after it is short enough to letter, so the letter carries
      // the base and the colour is free to go back to saying which one it is.
      final StageRun run = stage.runAt(cell);
      return CellSlot.forRole(run.kind, run.index);
    }
    if (stage.positionsPerCell == 1) {
      // Where the reading frame starts and stops is the one thing on this page
      // a letter cannot carry: an A is an A whether the ribosome begins on it
      // or not. Those six cells take a tile of their own and give their letter
      // up to it — see [CellSlot.frameStart].
      switch (stage.codonMarkAt(cell)) {
        case CodonMark.start:
          return CellSlot.frameStart;
        case CodonMark.stop:
          return CellSlot.frameStop;
        case CodonMark.none:
          break;
      }
      // The transcript page is drawn as three regions, and the two that are
      // never translated are washed back. Asked of the role table rather than
      // of the block, so a stage with no coding sequence at all — a non-coding
      // gene's mRNA — simply gets no dim cells and needs no special case.
      final RoleKind? role = model.codingRoleAt(stage.positionAt(cell))?.kind;
      return CellSlot.forBase(
        stage.letters[cell],
        dim:
            stage.kind != StageKind.dna &&
            (role == RoleKind.utr5 || role == RoleKind.utr3),
      );
    }
    // The dibasic pairs read as ordinary arginines and lysines by their letter
    // alone; they are the protease's instruction, so they are coloured by what
    // they mean rather than by what they are.
    if (model.codingRoleAt(stage.positionAt(cell))?.kind == RoleKind.dibasic) {
      return CellSlot.dibasic;
    }
    return CellSlot.forResidue(stage.letters[cell]);
  }
}

extension AnatomyScenePositions on AnatomyScene {
  /// Where cell [cell] of [from] sits at progress [t].
  Offset positionOf(int cell, double t) {
    if (translation case final AnatomyTranslation motion) {
      return motion.positionOf(cell, t);
    }
    final Offset origin = fromLayout.centreOf(cell);
    if (isSelection) {
      final int landing = target[cell];
      if (landing < 0) {
        final double fade = AnatomyMotion.ease((t / 0.35).clamp(0.0, 1.0));
        return origin +
            AnatomyMotion.driftDirection(origin, viewport) *
                fromLayout.cell *
                AnatomyMotion.driftCells *
                fade;
      }
      final double u = to.count > 1 ? landing / (to.count - 1) : 0;
      final double travel = AnatomyScene.selectionTravelAt(
        AnatomyMotion.staggered(t, u, lead: 0.08),
      );
      final Offset destination = toLayout.centreOf(landing);
      final Offset delta = destination - origin;
      final Offset control =
          (origin + destination) / 2 + Offset(-delta.dy, delta.dx) * 0.08;
      final double inverse = 1 - travel;
      return origin * (inverse * inverse) +
          control * (2 * inverse * travel) +
          destination * (travel * travel);
    }
    final double u = from.count > 1 ? cell / (from.count - 1) : 0;
    final double local = AnatomyMotion.ease(AnatomyMotion.staggered(t, u));

    final int landing = target[cell];
    if (landing < 0) {
      final Offset away = AnatomyMotion.driftDirection(origin, canvas);
      return origin + away * fromLayout.cell * AnatomyMotion.driftCells * local;
    }

    final Offset destination = toLayout.centreOf(landing);
    final Offset delta = destination - origin;
    final Offset control =
        (origin + destination) / 2 +
        Offset(-delta.dy, delta.dx) * AnatomyMotion.bow;
    final double inverse = 1 - local;
    return origin * (inverse * inverse) +
        control * (2 * inverse * local) +
        destination * (local * local);
  }

  /// Where a cell that leaves at this transition comes to rest, so the tracer
  /// ring can stay exactly where the base left the story.
  Offset departurePoint(int cell) => positionOf(cell, 1);
}
