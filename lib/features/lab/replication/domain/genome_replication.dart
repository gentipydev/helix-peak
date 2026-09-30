import 'package:flutter/foundation.dart';

/// One established human fork, with two 100-nt Okazaki fragments in view.
/// Coordinates increase in the direction of fork travel. A leading daughter
/// grows towards larger indices; a lagging daughter grows towards smaller ones.
/// This illustrative sequence is not a gene or a reference-genome locus.
abstract final class GenomeReplication {
  static const int windowBases = 200;
  static const int fragmentBases = 100;
  static const int rnaBases = 10;
  static const int alphaBases = 20;
  static const int leadingTrail = 36;

  // The leading template, read 3′ → 5′ as indices increase towards the fork.
  // A fixed teaching sequence; repeats outside the window provide context.
  static const String sequence =
      'ACGTTGCAAGTCGATCGTACGATTCGACCTAGGCTAACGTCAGTCGATGC'
      'TACCGATGCTAGTCGATCGAGCTTACGGTACAGCTAGCATGACCTGATCGA'
      'GCTAGTCAGATCGGATCATGCTAGCATCGATGGCATACGTAGCTTACGATCG'
      'ATGCATCGACTAGGCTACGATTCAGCTAGCATGGTACCTAGCATCGA';

  static String templateAt(int index) => sequence[index % sequence.length];

  static String complement(String base, {bool rna = false}) => switch (base) {
    'A' => rna ? 'U' : 'T',
    'T' || 'U' => 'A',
    'C' => 'G',
    'G' => 'C',
    _ => throw ArgumentError.value(base, 'base'),
  };
}

enum ReplicationStage {
  unwind('Unwinding', 0),
  prime('Priming', 8),
  extend('Elongation', 20),
  primeAgain('Next primer', 50),
  extendAgain('Next fragment', 62),
  replace('Primer removal', 88),
  seal('Ligation', 102),
  continueFork('Fork continues', 112);

  const ReplicationStage(this.title, this.second);
  final String title;
  final double second;
}

enum DaughterBase { absent, rna, dna }

@immutable
class ReplicationFrame {
  const ReplicationFrame(this.seconds);
  final double seconds;

  ReplicationStage get stage => ReplicationStage.values.lastWhere(
    (ReplicationStage stage) => seconds >= stage.second,
  );

  static double progress(double time, double start, double end) =>
      ((time - start) / (end - start)).clamp(0.0, 1.0);

  /// The camera begins at an already active fork; origin firing occurs outside
  /// this window. Travel continues while each lagging fragment is synthesized.
  double get fork => seconds < 50
      ? 110 + 100 * progress(seconds, 0, 50)
      : 210 + 30 * progress(seconds, 50, 120);

  double get leadingTip => fork - GenomeReplication.leadingTrail;

  /// RNA (10 nt), Pol alpha DNA (20 nt), then Pol delta (70 nt).
  double lengthOf(int fragment) {
    final double start = fragment == 0 ? 8 : 50;
    final double elapsed = seconds - start;
    return 10 * progress(elapsed, 0, 4) +
        20 * progress(elapsed, 4, 12) +
        70 * progress(elapsed, 12, 38);
  }

  double tipOf(int fragment) => (fragment + 1) * 100 - lengthOf(fragment);

  /// The later fragment extends across the earlier one's RNA-DNA primer.
  /// Pol delta displaces RNA as DNA is added, and FEN1 cleaves the flap.
  double get replacedBases => 10 * progress(seconds, 88, 100);
  double get sealing => progress(seconds, 102, 110);
  bool get sealed => sealing >= 1;

  DaughterBase laggingAt(int index) {
    if (index < 0) return DaughterBase.dna; // Earlier, offscreen fragment.
    if (index >= GenomeReplication.windowBases) return DaughterBase.absent;
    final int fragment = index ~/ 100;
    final int fromFivePrime = (fragment + 1) * 100 - 1 - index;
    if (fromFivePrime >= lengthOf(fragment).floor()) {
      return DaughterBase.absent;
    }
    if (fromFivePrime < GenomeReplication.rnaBases) {
      if (fragment == 0 && fromFivePrime < replacedBases.floor()) {
        return DaughterBase.dna;
      }
      return DaughterBase.rna;
    }
    return DaughterBase.dna;
  }

  DaughterBase leadingAt(int index) =>
      index < leadingTip.floor() ? DaughterBase.dna : DaughterBase.absent;

  /// The nick is between bases 89 and 90 after the first RNA primer is gone.
  bool get hasNick => replacedBases >= 10 && !sealed;

  bool get priming =>
      stage == ReplicationStage.prime || stage == ReplicationStage.primeAgain;
  int get activeFragment => seconds < 50 ? 0 : 1;
  bool get deltaActive =>
      (seconds >= 20 && seconds < 46) || (seconds >= 62 && seconds < 100);
  double get deltaTip =>
      seconds >= 88 ? 100 - replacedBases : tipOf(activeFragment);

  @override
  bool operator ==(Object other) =>
      other is ReplicationFrame && other.seconds == seconds;
  @override
  int get hashCode => seconds.hashCode;
}
