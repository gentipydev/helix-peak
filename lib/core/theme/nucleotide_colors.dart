import 'package:flutter/material.dart';

/// Colour coding for nucleotide bases, exposed as a [ThemeExtension] so the
/// palette resolves per-theme automatically instead of being switched by hand
/// at every call site.
///
/// ## Why these colours
///
/// The genome-browser convention (A green, T red) is built on the single worst
/// hue pair for deuteranopia and protanopia, the two most common forms of
/// colour vision deficiency. These four are drawn instead from the Okabe–Ito
/// qualitative palette, which is designed to stay distinguishable under all
/// common CVD types. Okabe–Ito's green is deliberately left out so the bases
/// never compete with the app's teal accent.
///
/// Bases appear adjacent to each other in dense monospace strings, so the set
/// also separates on lightness, not hue alone — which is what keeps it legible
/// when hue discrimination fails entirely.
///
/// Colour is never the only signal in the UI: every swatch is paired with its
/// letter label.
@immutable
final class NucleotideColors extends ThemeExtension<NucleotideColors> {
  const NucleotideColors({
    required this.adenine,
    required this.thymine,
    required this.guanine,
    required this.cytosine,
    required this.unknown,
  });

  final Color adenine;

  /// Also used for uracil — RNA's U occupies thymine's position.
  final Color thymine;

  final Color guanine;
  final Color cytosine;

  /// Ambiguity codes (N, R, Y…) and gap characters, which appear in real data
  /// often enough that a fallback is a correctness concern, not a nicety.
  final Color unknown;

  /// Maps a single base character to its colour.
  ///
  /// Case-insensitive; anything outside A/T/U/G/C resolves to [unknown].
  Color forBase(String base) {
    if (base.isEmpty) {
      return unknown;
    }
    return switch (base[0].toUpperCase()) {
      'A' => adenine,
      'T' || 'U' => thymine,
      'G' => guanine,
      'C' => cytosine,
      _ => unknown,
    };
  }

  static const NucleotideColors dark = NucleotideColors(
    adenine: Color(0xFFEDA92B), // amber
    thymine: Color(0xFF56B4E9), // sky blue
    guanine: Color(0xFFCC79A7), // reddish purple
    cytosine: Color(0xFFF2EA6B), // pale yellow
    unknown: Color(0xFF7C8798),
  );

  /// The dark values are far too light to read on paper, so each base keeps
  /// its hue identity — a user learns "A is amber" once — at a darker value.
  static const NucleotideColors light = NucleotideColors(
    adenine: Color(0xFFA96B00),
    thymine: Color(0xFF0B6FA4),
    guanine: Color(0xFF9C4F7C),
    cytosine: Color(0xFF7A6B00),
    unknown: Color(0xFF5A6169),
  );

  @override
  NucleotideColors copyWith({
    Color? adenine,
    Color? thymine,
    Color? guanine,
    Color? cytosine,
    Color? unknown,
  }) {
    return NucleotideColors(
      adenine: adenine ?? this.adenine,
      thymine: thymine ?? this.thymine,
      guanine: guanine ?? this.guanine,
      cytosine: cytosine ?? this.cytosine,
      unknown: unknown ?? this.unknown,
    );
  }

  @override
  NucleotideColors lerp(covariant NucleotideColors? other, double t) {
    if (other == null) {
      return this;
    }
    return NucleotideColors(
      adenine: Color.lerp(adenine, other.adenine, t)!,
      thymine: Color.lerp(thymine, other.thymine, t)!,
      guanine: Color.lerp(guanine, other.guanine, t)!,
      cytosine: Color.lerp(cytosine, other.cytosine, t)!,
      unknown: Color.lerp(unknown, other.unknown, t)!,
    );
  }
}

/// Convenience access to the nucleotide palette for the ambient theme.
extension NucleotideColorsContext on BuildContext {
  /// Falls back to the dark palette if the extension is somehow absent, so a
  /// misconfigured theme degrades to readable output rather than crashing.
  NucleotideColors get nucleotideColors =>
      Theme.of(this).extension<NucleotideColors>() ?? NucleotideColors.dark;
}
