import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/anatomy_colors.dart';
import '../../../core/theme/nucleotide_colors.dart';

/// The training run's colours, each the theme's own.
///
/// One hue a role, so a reader learns them once across the eight stages:
/// - [signal], the accent, is what flows forward: activations, the model's
///   marks, the position in focus;
/// - [truth], the tracer, outlines what actually came next;
/// - [error], the helix's honey, is the loss and what flows back from it;
/// - a signed number (an activation, a weight, a gradient, an update) is
///   drawn on one ramp, the helix's denim below zero and its clay above, from
///   the base tile at zero: the pair the AVI and ESM-2 page already parts for
///   every dichromat (`AgreementColors`);
/// - residues wear the walk's own colours, letters knocked out in the ground.
@immutable
final class LmInks {
  const LmInks({
    required this.ground,
    required this.card,
    required this.raised,
    required this.rule,
    required this.ink,
    required this.quiet,
    required this.signal,
    required this.truth,
    required this.error,
    required this.negative,
    required this.zero,
    required this.positive,
    required this.residues,
  });

  factory LmInks.of(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final AnatomyColors anatomy = context.anatomyColors;
    const NucleotideColors earth = NucleotideColors.helix;
    return LmInks(
      ground: scheme.surface,
      card: scheme.surfaceContainer,
      raised: scheme.surfaceContainerLow,
      rule: scheme.outlineVariant,
      ink: scheme.onSurface,
      quiet: scheme.onSurfaceVariant,
      signal: scheme.primary,
      truth: anatomy.tracer,
      error: earth.guanine,
      negative: earth.cytosine,
      zero: anatomy.baseTile,
      positive: earth.thymine,
      residues: anatomy,
    );
  }

  final Color ground;
  final Color card;

  /// A tag's plate (`drawTag`): the zoom's, so a part is named as it names
  /// one.
  final Color raised;
  final Color rule;
  final Color ink;
  final Color quiet;
  final Color signal;
  final Color truth;
  final Color error;
  final Color negative;
  final Color zero;
  final Color positive;
  final AnatomyColors residues;

  Color residue(String code) => residues.forResidue(code);

  /// A signed value from -1 to 1 on the ramp, in proportion: most of any
  /// layer is small and stays near the tile, so what is large stands out.
  Color signed(double value) {
    final double v = value.clamp(-1.0, 1.0);
    return Color.lerp(zero, v < 0 ? negative : positive, v.abs())!;
  }

  /// How far a written number's tile goes towards its [signed] colour: soft
  /// enough that the number on it reads.
  static const double soft = 0.55;

  /// The tile under a number written out, -1 to 1: [signed], softened.
  Color cell(double value) => Color.lerp(zero, signed(value), soft)!;

  /// How far the card under the peptide the reader follows goes towards the
  /// accent.
  static const double follow = 0.06;

  /// The card under the peptide the reader follows: [card], a little towards
  /// [signal], the ink of what is followed.
  Color get followed => Color.lerp(card, signal, follow)!;

  /// [value], 0 to 1, from the tile to [ink], lifted at the low end so a small
  /// weight still shows: an attention weight, a probability.
  Color share(double value, Color ink) =>
      Color.lerp(zero, ink, math.sqrt(value.clamp(0.0, 1.0)))!;

  List<Color> get _all => <Color>[
    ground,
    card,
    raised,
    rule,
    ink,
    quiet,
    signal,
    truth,
    error,
    negative,
    zero,
    positive,
  ];

  @override
  bool operator ==(Object other) =>
      other is LmInks && listEquals(other._all, _all) && other.residues == residues;

  @override
  int get hashCode => Object.hash(Object.hashAll(_all), residues);
}
