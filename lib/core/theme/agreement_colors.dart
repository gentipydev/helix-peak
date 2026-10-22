import 'package:flutter/material.dart';

import 'nucleotide_colors.dart';

/// The two models of a base's AVI and ESM-2 page, one hue each.
///
/// After the contributions page, the second place on the walk a model's
/// numbers wear hue, and like it at the user's ask (2026-10-22), on a page
/// that carries no ClinVar mark, so R9.1's hues stay ClinVar's everywhere
/// they could be read as clinical. The hues are the app's own earth
/// ([NucleotideColors.helix]): denim for AVI, clay for ESM-2.
///
/// The pair was settled by the dataviz skill's validator, on both grounds the
/// page draws on: the card (`surfaceRaised`, `#23201E`) and the page
/// (`surfaceBase`, `#1C1A18`). Of the earth's six pairs, it is the one that
/// keeps both inside the dark lightness band while parting 12.2 for any
/// dichromat (OKLab ×100; 8 is the target) and 17.9 in normal vision (15 the
/// floor); each clears 3:1. Honey parts further from either but is lighter
/// than the band. Like every earth hue it is softer than the validator's
/// chroma floor, as the app's palette is by design. The marks differ in
/// shape as well, AVI a dot and ESM-2 a ring, so no reader needs the hue
/// alone.
@immutable
final class AgreementColors extends ThemeExtension<AgreementColors> {
  const AgreementColors({required this.avi, required this.esm});

  /// Denim: AlphaGenome's AVI.
  final Color avi;

  /// Clay: ESM-2.
  final Color esm;

  static final AgreementColors earth = AgreementColors(
    avi: NucleotideColors.helix.cytosine,
    esm: NucleotideColors.helix.thymine,
  );

  @override
  AgreementColors copyWith({Color? avi, Color? esm}) =>
      AgreementColors(avi: avi ?? this.avi, esm: esm ?? this.esm);

  @override
  AgreementColors lerp(covariant AgreementColors? other, double t) {
    if (other == null) {
      return this;
    }
    return AgreementColors(
      avi: Color.lerp(avi, other.avi, t)!,
      esm: Color.lerp(esm, other.esm, t)!,
    );
  }
}

extension AgreementColorsContext on BuildContext {
  AgreementColors get agreementColors =>
      Theme.of(this).extension<AgreementColors>() ?? AgreementColors.earth;
}
