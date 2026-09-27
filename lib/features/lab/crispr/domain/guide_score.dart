import 'package:flutter/foundation.dart';

/// What a protospacer's own twenty bases measure.
///
/// Two properties, both read straight off the bases, and a plain combination
/// of the two for putting a list in an order:
///
/// - [gcFraction]: how much of the protospacer is G or C.
/// - [longestPolyT]: the longest run of T bases in it. Four or more
///   ([polyTTerminator]) is a terminator for RNA polymerase III, which is what
///   transcribes a U6-driven guide, so a run that long can cut the guide's own
///   transcript short before it is ever made.
///
/// **On-target efficiency prediction is out of scope.** Nothing here is a
/// model of how well a guide cuts. Published predictors are trained on
/// libraries of measured cutting, and this is not one: it is the two
/// properties above, measured, and a composite that is nothing but those two
/// put together by the formula written in [composite]. A guide is never called
/// good, effective or safe anywhere in this feature — [GuideScore] does not
/// know, and neither does the screen that shows it.
@immutable
final class GuideScore {
  const GuideScore({required this.gcFraction, required this.longestPolyT});

  /// Measures [protospacer], which must hold at least one base.
  factory GuideScore.of(String protospacer) {
    if (protospacer.isEmpty) {
      throw ArgumentError.value(protospacer, 'protospacer', 'has no bases');
    }
    int gc = 0;
    int run = 0;
    int longest = 0;
    for (int i = 0; i < protospacer.length; i++) {
      final String base = protospacer[i];
      if (base == 'G' || base == 'C') {
        gc++;
      }
      run = base == 'T' ? run + 1 : 0;
      if (run > longest) {
        longest = run;
      }
    }
    return GuideScore(
      gcFraction: gc / protospacer.length,
      longestPolyT: longest,
    );
  }

  /// G and C as a fraction of the protospacer's bases, 0 to 1.
  final double gcFraction;

  /// The longest run of consecutive T bases in the protospacer.
  final int longestPolyT;

  /// Where a run of T bases becomes a polymerase III terminator.
  static const int polyTTerminator = 4;

  /// Whether the protospacer holds a run of [polyTTerminator] T bases or more.
  bool get hasPolyT => longestPolyT >= polyTTerminator;

  /// The band of [gcFraction] that guide-design convention picks from.
  ///
  /// A convention for choosing between guides, not a measurement of any of
  /// them: very GC-poor and very GC-rich protospacers are the ones usually
  /// passed over, and the band is where the rest sit.
  static const double gcFloor = 0.4;
  static const double gcCeiling = 0.6;

  /// What [composite] keeps of a guide carrying a terminator run.
  static const double polyTFactor = 0.5;

  /// The two properties as one number from 0 to 1, for ordering a list.
  ///
  /// Exactly this and nothing else: 1 inside the [gcFloor]–[gcCeiling] band,
  /// falling away in a straight line to 0 at no GC and at all GC, and halved
  /// ([polyTFactor]) where [hasPolyT]. It is an ordering, not a prediction —
  /// see the note on [GuideScore] — and two guides with the same composite are
  /// not two guides that will behave the same way.
  double get composite {
    final double band = gcFraction < gcFloor
        ? gcFraction / gcFloor
        : gcFraction > gcCeiling
        ? (1 - gcFraction) / (1 - gcCeiling)
        : 1;
    final double value = hasPolyT ? band * polyTFactor : band;
    return value.clamp(0.0, 1.0);
  }

  @override
  String toString() =>
      'GuideScore(GC ${(gcFraction * 100).round()}%, '
      'longest T run $longestPolyT, composite ${composite.toStringAsFixed(2)})';
}
