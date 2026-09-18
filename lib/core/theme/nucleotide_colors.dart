import 'package:flutter/material.dart';

/// The four bases, in the colours a sequence reader already knows.
///
/// This is the IGV/UCSC convention — A green, T red, G orange, C blue — and it
/// is a convention rather than a preference: anyone who has opened a genome
/// browser reads these four without a legend, and a set chosen for its looks
/// costs them that for nothing.
///
/// There are two sets, and they are one set of hues. [dark] is the convention
/// at full strength, and it is what the helix on the home screen is drawn in.
/// [muted] is what the sequence is lettered in — see its note.
///
/// The one departure from IGV is [guanine]'s. IGV's orange is `#E0932E`; this
/// one was darkened to `#A36913` when a base was a solid tile with a white
/// letter knocked out of it, and it is the hue [muted] keeps. It must not drift
/// any redder: `AnatomyColors.roleStopCodon` and `roleSignal` are neighbours on
/// the residue pages, and an orange that leans red would read as kin to a stop.
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

  final Color thymine;

  final Color guanine;
  final Color cytosine;

  final Color unknown;

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
    adenine: Color(0xFF2E8B3D),
    thymine: Color(0xFFD13B3B),
    guanine: Color(0xFFA36913),
    cytosine: Color(0xFF2F5FA8),
    unknown: Color(0xFF7C8798),
  );

  /// The transcript page's four, in the manner of a colour e-paper panel.
  ///
  /// [dark]'s hues, held to 40% saturation and set at one lightness. A base on
  /// that page is not a solid tile: every tile is the same neutral
  /// (`AnatomyColors.baseTile`), and the letter carries the colour. Four hundred
  /// and sixty-five saturated squares were the loudest thing in the app, on the
  /// one page that exists to be read.
  ///
  /// One lightness means the eye's — CIE L\* 60 for all four — not HSL's. At an
  /// HSL lightness of 50% apiece A sits at L\* 65 and T at 46, the brightest
  /// letter on the page and the dimmest, which is the ranking this set is here
  /// to remove. So the saturation is what is held and the HSL lightness gives:
  /// 46% for A, 50% for G, 61% for C and 63% for T. [unknown] is a warm grey at
  /// the same lightness, so an N reads as a base rather than as a mark.
  ///
  /// Sixty is where a letter still reads: every one of these clears 4.5:1 on
  /// the tile. What a level set costs is the second cue a dichromat had — with
  /// only hue between them, A and G draw closer for a protanope — and on this
  /// page that is paid for in advance, because no base is shown without its
  /// letter.
  static const NucleotideColors muted = NucleotideColors(
    adenine: Color(0xFF46A355),
    thymine: Color(0xFFC77C7C),
    guanine: Color(0xFFB38A4D),
    cytosine: Color(0xFF7292C3),
    unknown: Color(0xFF969089),
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

extension NucleotideColorsContext on BuildContext {
  NucleotideColors get nucleotideColors =>
      Theme.of(this).extension<NucleotideColors>() ?? NucleotideColors.dark;
}
