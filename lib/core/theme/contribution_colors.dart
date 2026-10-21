import 'package:flutter/material.dart';

import '../evidence/impact_explanations.dart';

/// The four groups of an AVI contributions page, one hue each.
///
/// The one place on the walk a model's numbers wear hue, at the user's ask
/// (2026-10-21): R9.1 keeps hue for ClinVar, so these were searched outside
/// its hues — no red or rose (pathogenic), no blue-violet (benign,
/// conflicting) — and away from the accent's teal, and the page carries no
/// ClinVar mark. Four OKLCH steps in the dark band (L 0.50–0.62, chroma
/// 0.10–0.13), ordered as the bars stack them, checked against the card they
/// are drawn on (`surfaceRaised`, `#23201E`) by the dataviz skill's validator
/// over every pair: colour-blind separation ΔE 16.3 at worst (protan, deutan
/// and tritan; 8 is the target), normal vision 17.3 (15 the floor), each at
/// least 3:1 against the card. A legend and the groups' names carry identity
/// as well, so no reader needs the hue alone.
@immutable
final class ContributionColors extends ThemeExtension<ContributionColors> {
  const ContributionColors({
    required this.coding,
    required this.conservation,
    required this.splicing,
    required this.expression,
  });

  /// Rust: what the change does to the protein.
  final Color coding;

  /// Olive: how conserved the base is.
  final Color conservation;

  /// Cyan: splice sites, their usage and junctions.
  final Color splicing;

  /// Steel blue: the expression and chromatin tracks.
  final Color expression;

  static const ContributionColors dark = ContributionColors(
    coding: Color(0xFF98492C),
    conservation: Color(0xFF8E9C16),
    splicing: Color(0xFF30A4AE),
    expression: Color(0xFF14689F),
  );

  Color of(ContributionGroup group) => switch (group) {
    ContributionGroup.coding => coding,
    ContributionGroup.conservation => conservation,
    ContributionGroup.splicing => splicing,
    ContributionGroup.expression => expression,
  };

  @override
  ContributionColors copyWith({
    Color? coding,
    Color? conservation,
    Color? splicing,
    Color? expression,
  }) => ContributionColors(
    coding: coding ?? this.coding,
    conservation: conservation ?? this.conservation,
    splicing: splicing ?? this.splicing,
    expression: expression ?? this.expression,
  );

  @override
  ContributionColors lerp(covariant ContributionColors? other, double t) {
    if (other == null) {
      return this;
    }
    return ContributionColors(
      coding: Color.lerp(coding, other.coding, t)!,
      conservation: Color.lerp(conservation, other.conservation, t)!,
      splicing: Color.lerp(splicing, other.splicing, t)!,
      expression: Color.lerp(expression, other.expression, t)!,
    );
  }
}

extension ContributionColorsContext on BuildContext {
  ContributionColors get contributionColors =>
      Theme.of(this).extension<ContributionColors>() ?? ContributionColors.dark;
}
