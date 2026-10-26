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

/// The zoom's chromosome, in the colours the zoom's organs are drawn in (the
/// user's choice of 2026-10-26, after the soft blue it had been read as
/// louder than every stop round it): its arms a warm stone, the organs' lit
/// neutral warmed a little toward the home helix's honey, as the specimens
/// warm their tissue; the centromere's neck half way to the helix's clay
/// and the telomeres' caps over a third of the way to its honey, clear
/// where they lie (the user's ask the same day) but never as saturated as
/// the gene's band; and the chromatin of the gene's band in the organs' own
/// home tone, the mark over a lit neutral, from the accent's deep teal in
/// its shade toward the accent where it is lit, so it is the strongest
/// colour on the chromosome, as the mark is at every other stop.
/// Every colour is a mix of the app's own; its ground, its plates and its
/// deepest shadow are the app's, and are not repeated here.
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

  /// The chromatin of the gene's band.
  final ChromatinRamp gene;

  static final ChromosomeColors zoom = _zoom();

  static ChromosomeColors _zoom() {
    const AppColorTokens tokens = AppColorTokens.warm;
    final Color honey = NucleotideColors.helix.guanine;
    final Color clay = NucleotideColors.helix.thymine;
    // Light on a form, as the zoom's inks have it: the outline lifted
    // toward the bright ink.
    Color lit(double t) => Color.lerp(tokens.outline, tokens.onSurface, t)!;
    Color mix(Color a, Color b, double t) => Color.lerp(a, b, t)!;
    // The arms' stone, warmed most in its shade and least in its sheen.
    final ChromatinRamp stone = ChromatinRamp(
      crevice: mix(tokens.surfaceRaised, honey, 0.03),
      shadow: mix(lit(0.06), honey, 0.12),
      base: mix(lit(0.38), honey, 0.12),
      highlight: mix(lit(0.58), honey, 0.096),
      specular: mix(lit(0.8), honey, 0.048),
    );
    // The stone, [share] of the way toward [ink] in its shade, its own
    // colour and its light, and less in its crevice and its sheen.
    ChromatinRamp toward(Color ink, double share) => ChromatinRamp(
      crevice: mix(stone.crevice, ink, share * 0.4),
      shadow: mix(stone.shadow, ink, share),
      base: mix(stone.base, ink, share),
      highlight: mix(stone.highlight, ink, share * 0.8),
      specular: mix(stone.specular, ink, share * 0.4),
    );
    // Where an organ's cell lives: the mark over a lit neutral, one tone.
    final Color home = Color.alphaBlend(
      tokens.accent.withValues(alpha: 0.42),
      lit(0.2),
    );
    return ChromosomeColors(
      body: stone,
      // At most as saturated as half the mark in their shade, and less than
      // the band in their own colour: a fifth of the way, which they were
      // drawn at first, read as too faint.
      centromere: toward(clay, 0.5),
      telomere: toward(honey, 0.38),
      gene: ChromatinRamp(
        crevice: mix(tokens.accentContainer, tokens.surfaceBase, 0.45),
        shadow: mix(tokens.accentContainer, home, 0.45),
        base: home,
        highlight: mix(home, tokens.accent, 0.4),
        specular: mix(home, tokens.onSurface, 0.5),
      ),
    );
  }
}
