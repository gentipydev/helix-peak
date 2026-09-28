import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../core/biology/gene_record.dart';
import '../../core/biology/nmd.dart';
import '../anatomy/anatomy_stages.dart';
import '../format.dart';
import '../motion/animation_timeline.dart';

/// What happens during one stretch of translation.
enum TranslationPhase {
  /// The small subunit, carrying the initiator tRNA, scans the 5′ UTR from the
  /// cap to the start codon.
  scanning,

  /// The large subunit joins at the start codon, with the initiator in P.
  joining,

  /// An aminoacyl-tRNA pairs with the codon in the A site.
  decoding,

  /// The chain moves from the P-site tRNA onto the A-site one, one residue
  /// longer.
  peptideBond,

  /// The ribosome moves one codon along the mRNA: A to P, P to E.
  translocation,

  /// The emptied tRNA leaves from E.
  trnaExit,

  /// The stop codon reaches the A site, and a release factor reads it.
  releaseFactor,

  /// The finished chain is cut from the last tRNA and leaves the tunnel.
  release,

  /// The two subunits part and let go of the mRNA.
  dissociation,
}

/// One tRNA on the ribosome.
@immutable
final class TrnaSlot {
  const TrnaSlot({
    required this.codon,
    required this.charged,
    this.presence = 1,
  });

  /// The codon it pairs with, counted from 1 at the start codon.
  final int codon;

  /// Whether it still carries its amino acid, or the chain: an emptied tRNA
  /// is on its way out.
  final bool charged;

  /// 0 to 1: arriving in the A site, leaving from E, or simply there.
  final double presence;

  @override
  bool operator ==(Object other) =>
      other is TrnaSlot &&
      other.codon == codon &&
      other.charged == charged &&
      other.presence == presence;

  @override
  int get hashCode => Object.hash(codon, charged, presence);

  @override
  String toString() =>
      'tRNA(codon $codon${charged ? ', charged' : ''}, $presence)';
}

/// Everything on screen at one `t` of translation.
///
/// Residue positions are not stored: residue `r`, counted from 0 at the N
/// terminus, sits [depthOf] residues from the peptidyl transferase centre, so
/// the newest is at 0 and the N terminus is deepest and leaves the tunnel
/// first. That keeps a state a handful of numbers whatever the protein's
/// length.
@immutable
final class TranslationState {
  const TranslationState({
    required this.phase,
    required this.phaseProgress,
    required this.codon,
    required this.ribosome,
    required this.smallSubunit,
    required this.largeSubunit,
    required this.residues,
    required this.chainShift,
    this.e,
    this.p,
    this.a,
    this.releaseFactor = 0,
  });

  final TranslationPhase phase;

  /// How far through [phase] this is, 0 to 1.
  final double phaseProgress;

  /// The codon being read, counted from 1 at the start codon; the stop codon
  /// during termination.
  final int codon;

  /// Where the ribosome is, in mRNA coordinates: the index of the first base
  /// under its P site. It slides three bases per translocation.
  final double ribosome;

  /// How much of each subunit is there, 0 to 1: the small subunit scans alone,
  /// the large one joins at the start codon, and both part at the end.
  final double smallSubunit;
  final double largeSubunit;

  final TrnaSlot? e;
  final TrnaSlot? p;
  final TrnaSlot? a;

  /// A release factor in the A site, 0 to 1.
  final double releaseFactor;

  /// How many residues the chain has: never fewer than a moment before.
  final int residues;

  /// How far the whole chain has been pushed along the tunnel beyond where its
  /// length alone puts it: the next bond forming, or the release.
  final double chainShift;

  /// How many residues the exit tunnel holds at most.
  static const int tunnelCapacity = TranslationTimeline.tunnelCapacity;

  /// Residue [r]'s distance from the peptidyl transferase centre, in residues.
  /// At [tunnelCapacity] or more it is out of the tunnel.
  double depthOf(int r) => residues - 1 - r + chainShift;

  bool inTunnel(int r) => depthOf(r) < tunnelCapacity;

  /// How many residues are inside the tunnel.
  int get inTunnelCount {
    // depthOf(r) < capacity  <=>  r > residues - 1 - capacity + chainShift.
    final double beyond = residues - 1 - tunnelCapacity + chainShift;
    final int first = math.max(0, beyond.floor() + 1);
    return math.max(0, residues - first);
  }

  @override
  bool operator ==(Object other) =>
      other is TranslationState &&
      other.phase == phase &&
      other.phaseProgress == phaseProgress &&
      other.codon == codon &&
      other.ribosome == ribosome &&
      other.smallSubunit == smallSubunit &&
      other.largeSubunit == largeSubunit &&
      other.e == e &&
      other.p == p &&
      other.a == a &&
      other.releaseFactor == releaseFactor &&
      other.residues == residues &&
      other.chainShift == chainShift;

  @override
  int get hashCode => Object.hash(
    phase,
    phaseProgress,
    codon,
    ribosome,
    smallSubunit,
    largeSubunit,
    e,
    p,
    a,
    releaseFactor,
    residues,
    chainShift,
  );

  @override
  String toString() =>
      'TranslationState(${phase.name} $phaseProgress, codon $codon, '
      'at $ribosome, $residues residues, shift $chainShift)';
}

/// Translation of one record, as a pure function of `t`.
///
/// The beats: [scanBeats] scanning the 5′ UTR, [joinBeats] for the large
/// subunit joining, one for every codon the A site reads, and
/// [terminationBeats] for termination. The start codon has no beat of its
/// own: it is read by the initiator tRNA during scanning, and the large
/// subunit joins on it. Every other codon of the coding sequence gets exactly
/// one, split into the four slices [decodingEnd], [bondEnd] and
/// [translocationEnd] mark: decoding, peptide bond, translocation and tRNA
/// exit.
///
/// Everything is read off the record through the walk's own derivation, the
/// mRNA page of [AnatomyModel]: its letters, its coding block and where its
/// exons meet. Nothing here knows any protein by name.
final class TranslationTimeline extends AnimationTimeline<TranslationState> {
  TranslationTimeline._({
    required this.mrna,
    required this.cdsStart,
    required this.protein,
    required this.junctions,
    required this.signalPeptideLength,
  }) : assert(protein.isNotEmpty, 'a coding sequence to translate');

  /// A timeline over letters given directly, for a test that needs a shape
  /// no record in the catalog has.
  @visibleForTesting
  TranslationTimeline.raw({
    required String mrna,
    required int cdsStart,
    required String protein,
    List<int> junctions = const <int>[],
    int signalPeptideLength = 0,
  }) : this._(
         mrna: mrna,
         cdsStart: cdsStart,
         protein: protein,
         junctions: junctions,
         signalPeptideLength: signalPeptideLength,
       );

  /// [record] must make a protein and have an mRNA the walk draws.
  factory TranslationTimeline(GeneRecord record, {String? chain}) =>
      TranslationTimeline.of(AnatomyModel.derive(record, chain: chain));

  factory TranslationTimeline.of(AnatomyModel model) {
    final AnatomyStage? transcript = model.stages
        .where((AnatomyStage s) => s.kind == StageKind.mrna)
        .firstOrNull;
    final String? protein = model.record.protein?.translation;
    if (transcript == null || protein == null || protein.isEmpty) {
      throw ArgumentError.value(
        model.record.gene,
        'record',
        'has no mRNA and coding sequence to translate',
      );
    }
    final StageBlock coding = transcript.blocks.firstWhere(
      (StageBlock b) => b.framed,
    );
    return TranslationTimeline._(
      mrna: transcript.letters,
      cdsStart: coding.start,
      protein: protein,
      junctions: List<int>.unmodifiable(<int>[
        for (int i = 1; i < transcript.count; i++)
          if ((transcript.positions[i] - transcript.positions[i - 1]).abs() !=
              1)
            i,
      ]),
      signalPeptideLength: model.record.signalPeptide?.translation.length ?? 0,
    );
  }

  static const int scanBeats = 3;
  static const int joinBeats = 1;
  static const int terminationBeats = 3;

  /// How many residues the exit tunnel holds.
  static const int tunnelCapacity = 35;

  /// Where each slice of a codon's beat ends: decoding, then the peptide
  /// bond, then translocation; tRNA exit takes the rest.
  static const double decodingEnd = 0.35;
  static const double bondEnd = 0.55;
  static const double translocationEnd = 0.85;

  /// Residues that let methionine aminopeptidase clip the initiator Met: the
  /// small side chains at position 2.
  static const String clippingResidues = 'GASCTPV';

  /// The mRNA, 5′ to 3′, as the walk's mRNA page letters it.
  final String mrna;

  /// Where the start codon begins in [mrna].
  final int cdsStart;

  /// The residues the coding sequence makes, without the stop.
  final String protein;

  /// Where each exon-exon junction is in [mrna]: the index of the first base
  /// of the exon downstream of it.
  final List<int> junctions;

  /// The signal peptide's length in residues, or 0 where there is none.
  final int signalPeptideLength;

  /// Where the stop codon begins in [mrna].
  int get stopCodonStart => cdsStart + 3 * protein.length;

  /// Codons the A site reads during elongation: all but the start.
  int get elongationBeats => protein.length - 1;

  int get firstElongationBeat => scanBeats + joinBeats;
  int get firstTerminationBeat => firstElongationBeat + elongationBeats;

  /// The beat in which codon [codon] (2 up to the last sense codon) is read.
  int beatOfCodon(int codon) => firstElongationBeat + codon - 2;

  @override
  int get beats => firstTerminationBeat + terminationBeats;

  @override
  late final List<PhaseMark> phases = List<PhaseMark>.unmodifiable(<PhaseMark>[
    const PhaseMark(name: 'Scanning the 5′ UTR', t: 0, captionKey: 'scanning'),
    PhaseMark(
      name: 'The large subunit joins',
      t: beatStart(scanBeats),
      captionKey: 'joining',
    ),
    for (int codon = 2; codon <= protein.length; codon++) ...<PhaseMark>[
      PhaseMark(
        name: 'Codon ${grouped(codon)} · decoding',
        t: beatStart(beatOfCodon(codon)),
        captionKey: 'decoding',
      ),
      PhaseMark(
        name: 'Codon ${grouped(codon)} · peptide bond',
        t: beatStart(beatOfCodon(codon) + bondStart),
        captionKey: 'peptideBond',
      ),
      PhaseMark(
        name: 'Codon ${grouped(codon)} · translocation',
        t: beatStart(beatOfCodon(codon) + bondEnd),
        captionKey: 'translocation',
      ),
      PhaseMark(
        name: 'Codon ${grouped(codon)} · tRNA exit',
        t: beatStart(beatOfCodon(codon) + translocationEnd),
        captionKey: 'trnaExit',
      ),
    ],
    PhaseMark(
      name: 'Stop codon · release factor',
      t: beatStart(firstTerminationBeat),
      captionKey: 'releaseFactor',
    ),
    PhaseMark(
      name: 'The chain is released',
      t: beatStart(firstTerminationBeat + 1),
      captionKey: 'release',
    ),
    PhaseMark(
      name: 'The subunits part',
      t: beatStart(firstTerminationBeat + 2),
      captionKey: 'dissociation',
    ),
  ]);

  /// Where the peptide bond begins: decoding ends there.
  static const double bondStart = decodingEnd;

  @override
  TranslationState stateAt(double t) {
    final (int beat, double u) = beatAt(t);
    if (beat < scanBeats) {
      final double scanned = (beat + u) / scanBeats;
      return TranslationState(
        phase: TranslationPhase.scanning,
        phaseProgress: scanned,
        codon: 1,
        ribosome: cdsStart * scanned,
        smallSubunit: 1,
        largeSubunit: 0,
        residues: 0,
        chainShift: 0,
        p: const TrnaSlot(codon: 1, charged: true),
      );
    }
    if (beat < firstElongationBeat) {
      return TranslationState(
        phase: TranslationPhase.joining,
        phaseProgress: u,
        codon: 1,
        ribosome: cdsStart.toDouble(),
        smallSubunit: 1,
        largeSubunit: AnimationTimeline.slice(u, 0, 1),
        residues: 1,
        chainShift: 0,
        p: const TrnaSlot(codon: 1, charged: true),
      );
    }
    if (beat < firstTerminationBeat) {
      return _elongating(beat - firstElongationBeat + 2, u);
    }
    return _terminating(beat - firstTerminationBeat, u);
  }

  TranslationState _elongating(int codon, double u) {
    final double base = (cdsStart + 3 * (codon - 2)).toDouble();
    if (_before(u, decodingEnd)) {
      return TranslationState(
        phase: TranslationPhase.decoding,
        phaseProgress: AnimationTimeline.slice(u, 0, decodingEnd, eased: false),
        codon: codon,
        ribosome: base,
        smallSubunit: 1,
        largeSubunit: 1,
        residues: codon - 1,
        chainShift: 0,
        p: TrnaSlot(codon: codon - 1, charged: true),
        a: TrnaSlot(
          codon: codon,
          charged: true,
          presence: AnimationTimeline.slice(u, 0, decodingEnd),
        ),
      );
    }
    if (_before(u, bondEnd)) {
      return TranslationState(
        phase: TranslationPhase.peptideBond,
        phaseProgress: AnimationTimeline.slice(
          u,
          bondStart,
          bondEnd,
          eased: false,
        ),
        codon: codon,
        ribosome: base,
        smallSubunit: 1,
        largeSubunit: 1,
        // The chain is still the P-site tRNA's until the bond has formed, and
        // it is pushed one residue along the tunnel as it forms.
        residues: codon - 1,
        chainShift: AnimationTimeline.slice(u, bondStart, bondEnd),
        p: TrnaSlot(codon: codon - 1, charged: true),
        a: TrnaSlot(codon: codon, charged: true),
      );
    }
    if (_before(u, translocationEnd)) {
      final double moved = AnimationTimeline.slice(
        u,
        bondEnd,
        translocationEnd,
      );
      final bool crossed = u >= (bondEnd + translocationEnd) / 2;
      return TranslationState(
        phase: TranslationPhase.translocation,
        phaseProgress: AnimationTimeline.slice(
          u,
          bondEnd,
          translocationEnd,
          eased: false,
        ),
        codon: codon,
        ribosome: base + 3 * moved,
        smallSubunit: 1,
        largeSubunit: 1,
        residues: codon,
        chainShift: 0,
        // The tRNAs stay on their codons and the ribosome slides under them;
        // which site each is in changes halfway.
        e: crossed ? TrnaSlot(codon: codon - 1, charged: false) : null,
        p: crossed
            ? TrnaSlot(codon: codon, charged: true)
            : TrnaSlot(codon: codon - 1, charged: false),
        a: crossed ? null : TrnaSlot(codon: codon, charged: true),
      );
    }
    return TranslationState(
      phase: TranslationPhase.trnaExit,
      phaseProgress: AnimationTimeline.slice(
        u,
        translocationEnd,
        1,
        eased: false,
      ),
      codon: codon,
      ribosome: base + 3,
      smallSubunit: 1,
      largeSubunit: 1,
      residues: codon,
      chainShift: 0,
      e: TrnaSlot(
        codon: codon - 1,
        charged: false,
        presence: 1 - AnimationTimeline.slice(u, translocationEnd, 1),
      ),
      p: TrnaSlot(codon: codon, charged: true),
    );
  }

  TranslationState _terminating(int step, double u) {
    final int last = protein.length;
    final double ribosome = (cdsStart + 3 * (last - 1)).toDouble();
    final int stop = last + 1;
    switch (step) {
      case 0:
        return TranslationState(
          phase: TranslationPhase.releaseFactor,
          phaseProgress: u,
          codon: stop,
          ribosome: ribosome,
          smallSubunit: 1,
          largeSubunit: 1,
          residues: last,
          chainShift: 0,
          p: TrnaSlot(codon: last, charged: true),
          releaseFactor: AnimationTimeline.slice(u, 0, 1),
        );
      case 1:
        return TranslationState(
          phase: TranslationPhase.release,
          phaseProgress: u,
          codon: stop,
          ribosome: ribosome,
          smallSubunit: 1,
          largeSubunit: 1,
          residues: last,
          // Cut free, the whole chain slides out: by the end even its newest
          // residue is past the tunnel's exit.
          chainShift: tunnelCapacity * AnimationTimeline.slice(u, 0, 1),
          p: TrnaSlot(codon: last, charged: false),
          releaseFactor: 1,
        );
      default:
        final double parting = AnimationTimeline.slice(u, 0, 1);
        return TranslationState(
          phase: TranslationPhase.dissociation,
          phaseProgress: u,
          codon: stop,
          ribosome: ribosome,
          smallSubunit: 1 - parting,
          largeSubunit: 1 - parting,
          residues: last,
          chainShift: tunnelCapacity.toDouble(),
          p: TrnaSlot(codon: last, charged: false, presence: 1 - parting),
          releaseFactor: 1 - parting,
        );
    }
  }

  /// Whether [u] has not yet reached [edge]. A mark's `t` is a beat start
  /// plus a slice edge divided by the beat count, and reading it back can land
  /// a rounding error short of the edge; a state asked for at a mark belongs
  /// to the slice the mark names.
  static bool _before(double u, double edge) => u < edge - 1e-9;

  // ------------------------------------------------------------ events

  /// Whether the initiator methionine is clipped off the finished chain:
  /// methionine aminopeptidase removes it only when residue 2 is small, one of
  /// [clippingResidues].
  bool get initiatorMetClipped =>
      protein.length >= 2 && clippingResidues.contains(protein[1]);

  /// From the moment the whole signal peptide has cleared the tunnel to the
  /// end of elongation, or null for a protein with no signal peptide.
  ///
  /// Signal recognition particle can bind the signal sequence only once it
  /// is out. A chain too short to push its whole signal peptide out before
  /// the stop codon clears it during release, and the window opens there and
  /// runs to the end.
  late final (double, double)? srpWindow = signalPeptideLength == 0
      ? null
      : _window(_clears(signalPeptideLength - 1));

  /// When residue [r] leaves the tunnel.
  ///
  /// During elongation that is exact: residue r is [tunnelCapacity] deep once
  /// the chain is r + 1 + capacity long, which is the end of that codon's
  /// peptide bond. A chain too short for that pushes it out during release.
  double? _clears(int r) {
    final int codon = r + 1 + tunnelCapacity;
    if (codon <= protein.length) {
      return beatStart(beatOfCodon(codon) + bondEnd);
    }
    return _firstT(
      (TranslationState s) => s.residues > r && s.depthOf(r) >= tunnelCapacity,
    );
  }

  (double, double)? _window(double? opens) {
    if (opens == null) {
      return null;
    }
    final double elongationEnds = beatStart(firstTerminationBeat);
    return (opens, opens < elongationEnds ? elongationEnds : 1);
  }

  /// The first residue out of the tunnel: when the N terminus leaves it.
  late final double? firstExit = _clears(0);

  /// The `t` at which the ribosome passes each exon-exon junction it reaches,
  /// in mRNA order: where the exon junction complex upstream of it is knocked
  /// off. A junction past the stop codon is never reached, and so never
  /// cleared, and is left out.
  late final List<({int junction, double t})> ejcKnockoff =
      List<({int junction, double t})>.unmodifiable(
        <({int junction, double t})>[
          for (final int junction in junctions)
            if (_firstT((TranslationState s) => s.ribosome >= junction)
                case final double at)
              (junction: junction, t: at),
        ],
      );

  /// The last codon at which a stop would sit more than [nmdThresholdBp]
  /// bases upstream of the final exon-exon junction, so that
  /// nonsense-mediated decay would destroy the mRNA; null with fewer than two
  /// exons, or where no codon is that far upstream. The same rule the edit
  /// engine classifies by, read off the same junction.
  late final int? nmdThresholdCodon = _nmdThresholdCodon();

  int? _nmdThresholdCodon() {
    if (junctions.isEmpty) {
      return null;
    }
    // A stop at codon c begins at cdsStart + 3(c - 1), and triggers decay when
    // the last junction is more than the threshold beyond that.
    final int limit = junctions.last - nmdThresholdBp - 1 - cdsStart;
    if (limit < 0) {
      return null;
    }
    return math.min(limit ~/ 3 + 1, protein.length);
  }

  /// The earliest `t` at which [holds] is true, or null if it never is.
  ///
  /// Everything asked of this is monotonic in `t` (residues only arrive, the
  /// chain only moves outwards, the ribosome only moves 3′), so a bisection
  /// finds the edge; 60 halvings take it below any beat of any protein.
  double? _firstT(bool Function(TranslationState state) holds) {
    if (!holds(stateAt(1))) {
      return null;
    }
    if (holds(stateAt(0))) {
      return 0;
    }
    double low = 0;
    double high = 1;
    for (int i = 0; i < 60; i++) {
      final double middle = (low + high) / 2;
      if (holds(stateAt(middle))) {
        high = middle;
      } else {
        low = middle;
      }
    }
    return high;
  }
}
