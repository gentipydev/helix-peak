import 'package:flutter/material.dart';

/// The four bases, in the colours a sequence reader already knows.
///
/// This is the IGV/UCSC convention — A green, T red, G orange, C blue — and it
/// is a convention rather than a preference: anyone who has opened a genome
/// browser reads these four without a legend, and a set chosen for its looks
/// costs them that for nothing.
///
/// There are three sets. [dark] is the convention at full strength. No screen
/// draws it now; it is the reference the other two are measured from, and the
/// one the residue colours that rhyme with the bases are held to. [muted] is
/// what the sequence is lettered in, in [dark]'s own hues, and [helix] is what
/// the helix is drawn in, its hues leaned warm — see each one's note.
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

  /// The helix's four, on the home screen and at the zoom's DNA.
  ///
  /// The helix is a drawing of DNA rather than a sequence to read: the home
  /// screen's is not lettered, and where the zoom's DNA letters its bases each
  /// letter is cut from its ball in the ground, which every ball clears (see
  /// below), so the colour is never a letter's and the set is free of
  /// [muted]'s one lightness. It was drawn in
  /// [dark], and at full strength those were the loudest colours in the app —
  /// thymine's red at a chroma of 68 against the accent's 43, on a screen that
  /// is otherwise the accent on the warm ground. These are the convention as
  /// the rest of the app paints its data, among the gene parts, the residues
  /// and the constraint ramp.
  ///
  /// The hues are [dark]'s, leaned toward yellow: adenine furthest, 13° to a
  /// moss, thymine 3° to a clay and guanine 6° to a honey, while cytosine
  /// comes 10° back from violet onto its residue's blue. Each stays within the
  /// 10° its residue rhymes in, the bound the other two sets are held to. None
  /// is more saturated than the accent: adenine's chroma of 41 is the most.
  ///
  /// Lightness carries what the hues cannot. Three of [dark]'s four sit at
  /// L\* 48 to 51, so for a deuteranope adenine, thymine and guanine are one
  /// olive, 2.3 apart at the closest (OKLab ×100, Machado et al. 2009). These
  /// run from L\* 48 to 67, and no two come closer than 6.2 for any dichromat.
  /// Where colour is the only cue, between the two purines and between the
  /// two pyrimidines, which the painter draws at one size, they stay at least
  /// 12 apart in every kind of vision; every closer pair is a purine against
  /// a pyrimidine, a size apart.
  ///
  /// Each clears 3.5:1 on the ground, where [dark]'s cytosine was 2.75, and
  /// keeps clear of the helix's other two colours, the transcript's accent and
  /// the backbone's quiet ink. [unknown] is [muted]'s warm grey; the helix
  /// never draws one.
  static const NucleotideColors helix = NucleotideColors(
    adenine: Color(0xFF557C39),
    thymine: Color(0xFFBE7367),
    guanine: Color(0xFFC89D5C),
    cytosine: Color(0xFF5981B6),
    unknown: Color(0xFF969089),
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
