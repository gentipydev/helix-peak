import 'package:flutter/material.dart';

import 'app_colors.dart';
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

/// The zoom's chromosome in its vivid look (the user's ask of 2026-10-23,
/// after a picture of chromosome 16 they sent): its chromatin a saturated
/// blue, the centromere's in the home helix's clay and the telomeres' in its
/// honey, as the stone look tints them, and the chromatin round the gene in
/// a cyan brighter than the accent, its crevices the accent's own deep teal.
/// Its ground, its plates and its deepest shadow are the app's own, and are
/// not repeated here.
@immutable
final class ChromosomeColors {
  const ChromosomeColors({
    required this.body,
    required this.centromere,
    required this.telomere,
    required this.gene,
    required this.glowCore,
    required this.leader,
  });

  /// The arms' chromatin.
  final ChromatinRamp body;

  /// The centromere's chromatin, and the telomeres'.
  final ChromatinRamp centromere;
  final ChromatinRamp telomere;

  /// The chromatin round the gene's FISH spots; its highlight is the spots'
  /// glow, and its line.
  final ChromatinRamp gene;

  /// A FISH spot's heart: the gene's cyan, all but white.
  final Color glowCore;

  /// The lines from the chromosome's names to what they name, and the
  /// hairline round their plates.
  final Color leader;

  static final ChromosomeColors vivid = ChromosomeColors(
    body: const ChromatinRamp(
      crevice: Color(0xFF0B1626),
      shadow: Color(0xFF1D3956),
      base: Color(0xFF3976B8),
      highlight: Color(0xFF78A6E5),
      specular: Color(0xFFC9DBF4),
    ),
    centromere: ChromatinRamp(
      crevice: const Color(0xFF2A1512),
      shadow: const Color(0xFF623D36),
      base: NucleotideColors.helix.thymine,
      highlight: const Color(0xFFCE968D),
      specular: const Color(0xFFF0D2CC),
    ),
    telomere: ChromatinRamp(
      crevice: const Color(0xFF2B2214),
      shadow: const Color(0xFF675131),
      base: NucleotideColors.helix.guanine,
      highlight: const Color(0xFFD6B685),
      specular: const Color(0xFFF2E2C4),
    ),
    gene: ChromatinRamp(
      crevice: const Color(0xFF06201C),
      shadow: AppColorTokens.warm.accentContainer,
      base: const Color(0xFF00A89B),
      highlight: const Color(0xFF00DCCB),
      specular: const Color(0xFFB8FFF8),
    ),
    glowCore: const Color(0xFFE6FFFC),
    leader: const Color(0xFFA6B9D5),
  );
}
