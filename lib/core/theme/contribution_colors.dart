import 'package:flutter/material.dart';

import '../evidence/impact_explanations.dart';
import 'nucleotide_colors.dart';

/// The four groups of an AVI contributions page, one hue each.
///
/// The one place on the walk a model's numbers wear hue, at the user's ask
/// (2026-10-21), on a page that carries no ClinVar mark, so R9.1's hues stay
/// ClinVar's everywhere they could be read as clinical. The hues are the
/// app's own earth, the home helix's moss, clay, honey and denim
/// ([NucleotideColors.helix], which the zoom's chromosome wears too), so the
/// page paints its data as the rest of the app does.
///
/// Which group wears which was settled by the dataviz skill's validator, on
/// the card the bars are drawn on (`surfaceRaised`, `#23201E`), over the
/// three pairs that touch in a bar. Of the 24 ways to give four colours to
/// four groups, four keep every touching pair at least 12.2 apart for any
/// dichromat (OKLab ×100; 8 is the target) and 17.9 in normal vision (15 the
/// floor); this is the one of them that gives conservation the moss. The
/// closest of all six pairs, clay against moss (6.2 for a protanope), never
/// touch in a bar, and the table under the card names every group, so no
/// reader needs the hue alone. Each clears 3:1 on the card.
@immutable
final class ContributionColors extends ThemeExtension<ContributionColors> {
  const ContributionColors({
    required this.coding,
    required this.conservation,
    required this.splicing,
    required this.expression,
  });

  /// Honey: what the change does to the protein.
  final Color coding;

  /// Moss: how conserved the base is.
  final Color conservation;

  /// Denim: splice sites, their usage and junctions.
  final Color splicing;

  /// Clay: the expression and chromatin tracks.
  final Color expression;

  static final ContributionColors earth = ContributionColors(
    coding: NucleotideColors.helix.guanine,
    conservation: NucleotideColors.helix.adenine,
    splicing: NucleotideColors.helix.cytosine,
    expression: NucleotideColors.helix.thymine,
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
      Theme.of(this).extension<ContributionColors>() ??
      ContributionColors.earth;
}
