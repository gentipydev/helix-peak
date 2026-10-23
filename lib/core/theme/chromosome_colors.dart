import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'kaleido.dart';
import 'nucleotide_colors.dart';

/// One material of chromatin, from where no light reaches it to where the
/// light shines back off it: in a crevice, in shade, its own colour, lit,
/// and its sheen. Every step keeps the material's hue, so it darkens and
/// lightens without going to mud, as a mix toward a neutral would.
@immutable
final class ChromatinRamp {
  const ChromatinRamp({
    required this.crevice,
    required this.shadow,
    required this.base,
    required this.highlight,
    required this.specular,
  });

  final Color crevice;
  final Color shadow;
  final Color base;
  final Color highlight;
  final Color specular;

  /// Its five colours, darkest first.
  List<Color> get stops => <Color>[crevice, shadow, base, highlight, specular];
}

/// The zoom's chromosome: its arms a soft blue in the hue of the app's inks,
/// the centromere's neck in the home helix's clay and the telomeres' caps in
/// its honey, all at half the chroma they were first drawn in, through the
/// app's Kaleido filter as the walk's residues are (lightness and hue kept);
/// and the chromatin round the gene in the mark, from the accent's deep teal
/// in its shade to the accent itself where it is lit (the user's choice of
/// 2026-10-23, after a study of the zoom's colours: the chromosome as quiet
/// as the organs keep their tissues, and the gene the strongest colour on
/// it, as the mark is at every other stop). Its ground, its plates and its
/// deepest shadow are the app's own, and are not repeated here.
@immutable
final class ChromosomeColors {
  const ChromosomeColors({
    required this.body,
    required this.centromere,
    required this.telomere,
    required this.gene,
  });

  /// The arms' chromatin.
  final ChromatinRamp body;

  /// The centromere's chromatin, and the telomeres'.
  final ChromatinRamp centromere;
  final ChromatinRamp telomere;

  /// The chromatin round the gene.
  final ChromatinRamp gene;

  static final ChromosomeColors zoom = ChromosomeColors(
    body: const ChromatinRamp(
      crevice: Color(0xFF12161E),
      shadow: Color(0xFF2E3847),
      base: Color(0xFF607495),
      highlight: Color(0xFF92A5C4),
      specular: Color(0xFFD2DAE7),
    ),
    centromere: ChromatinRamp(
      crevice: const Color(0xFF231817),
      shadow: const Color(0xFF55423E),
      base: Kaleido.filter(NucleotideColors.helix.thymine),
      highlight: const Color(0xFFBA9D98),
      specular: const Color(0xFFE5D5D2),
    ),
    telomere: ChromatinRamp(
      crevice: const Color(0xFF28231C),
      shadow: const Color(0xFF5F5343),
      base: Kaleido.filter(NucleotideColors.helix.guanine),
      highlight: const Color(0xFFCAB8A0),
      specular: const Color(0xFFEBE3D4),
    ),
    gene: ChromatinRamp(
      crevice: const Color(0xFF06201C),
      shadow: AppColorTokens.warm.accentContainer,
      base: const Color(0xFF6AA098),
      highlight: AppColorTokens.warm.accent,
      specular: Color.lerp(
        AppColorTokens.warm.accent,
        AppColorTokens.warm.onSurface,
        0.6,
      )!,
    ),
  );
}
