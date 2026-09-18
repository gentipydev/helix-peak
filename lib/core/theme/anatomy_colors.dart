import 'package:flutter/material.dart';

import '../biology/amino_acids.dart';
import 'kaleido.dart';

/// Colours the anatomy canvas needs and the rest of the app does not.
///
/// Shaped like [NucleotideColors]: a `ThemeExtension` with a const instance, so
/// the canvas never reaches for a raw hex and the palette is declared in one
/// place. There are two instances: [dark], the palette as it was searched, and
/// [kaleido], which the Protein Analyses flow is drawn in — see [AppTheme], and
/// the note on the filter at the end of this one.
///
/// ## The role colours
///
/// Twelve colours that must all be told apart on a near-black ground is more
/// than the eye has room for, so they are not twelve independent choices. They
/// are six families of shared hue, and lightness separates the members inside
/// each one. That is the same economy Ensembl practises: it gives a whole
/// transcript a single biotype colour and separates CDS from UTR by *shape* —
/// a solid full-height box against a hollow, shrunken outline — rather than
/// spending a second hue on it.
///
///     discarded     intron, untranscribed   dark teal, all but colourless
///     noncoding     3' UTR, 5' UTR          copper
///     coding        exon, CDS               blue
///     cleaved       C-peptide, signal       violet
///     retained      B chain, A chain        green
///     instruction   start codon             green
///     instruction   stop codon              red
///
/// Each family's hue is anchored to something real. Ensembl's sequence view —
/// the closest thing to this page, being sequence rather than a schematic —
/// draws introns achromatic (`SEQ_INTRON = aaaaaa`), UTRs a warm copper
/// (`SEQ_EXONUTR = cd6839`) and exons blue (`SEQ_EXON1 = 1044ee`); the cleaved
/// violet is kin to its `plum4` RNA-gene tint, and red for a stop is the one
/// convention every codon table agrees on. What does *not* survive the move is
/// lightness: `aaaaaa` is an intron that recedes on paper and would blaze here,
/// so every hue was re-placed against this ground rather than copied.
///
/// The family a colour belongs to is itself the message. A reader who has not
/// read a single label can still see that the two green runs are the parts that
/// survive into the finished molecule, and that the violet ones are cut away.
///
/// [roleIntron] carries an extra duty: it is two thirds of every pixel of this
/// gene, and a field that large reads as a colour choice however quiet the hue
/// is. It is the darkest thing on the page on purpose.
///
/// These are free to be saturated because the page draws no letters: at ten
/// pixels a cell is far too small to hold one. What each run carries is its
/// *name*, and the painter picks that ink per run from whichever of the ground
/// and its opposite the run can be seen against — a choice that clears 4.3:1
/// for any colour whatsoever, which is what buys this palette its freedom.
///
/// [dibasic] is the exception and is not free, because it is the one role that
/// outlives the gene stage. See its note below.
///
/// ## Dimming
///
/// Derived, not tabulated. Muting drains a colour to the grey of its own
/// lightness and steps it toward the ground (`_stepBack`), and a selected run
/// is lifted toward [tracer]. Between them that leaves twenty points of L\*
/// between the dimmest thing that can be selected and the brightest thing that
/// is not, so a selection always wins and no second table has to be kept in
/// step with this one.
///
/// ## The amino acid colours
///
/// Seven hues, and four of them are borrowed. [aminoPolar] is adenine's green,
/// [aminoNegative] is thymine's red, [aminoSpecial] is guanine's amber and
/// [aminoPositive] is cytosine's blue — so the four colours a reader spent two
/// pages learning as the letters of the gene come back as the four chemistries
/// those letters build. They never share a page, so the rhyme cannot be read as
/// a claim; what it buys is that these pages belong to the same app as the ones
/// before them, which the palette this replaced did not.
///
/// The rhyme costs nothing in accuracy, because it *is* the convention. Polar
/// is green in Zappo, in Clustal and in RasMol; negative is red in Zappo and
/// RasMol; positive is blue in both; Clustal draws glycine orange. The palette
/// this replaced followed a convention on two of its seven groups.
///
/// [aminoCysteine] keeps the yellow every scheme agrees on. [aminoAromatic] is
/// the app's own violet: Zappo's orange for it is spent on [aminoSpecial] and
/// Clustal's blue on [aminoPositive], and violet is the one hue left with no
/// competitor on a residue page. [aminoAliphatic] is a deliberate departure —
/// Zappo draws it rose, and A, I, L, M and V are together some two fifths of
/// any protein, so a hue there stops being a category and becomes the page. It
/// takes the app's own neutral ramp instead and is the darkest of the seven,
/// which is what lets it read as the field the other six sit in.
///
/// Within those hues, lightness and chroma were searched: they maximise the
/// smallest perceptual distance across normal vision, deuteranopia and
/// protanopia at once. That spread is load-bearing and is why these are not one
/// tidy band — a palette at a single lightness collapses to ΔE00 1 for a
/// deuteranope however far apart its hues are. These reach **9.3**, against
/// **1.8** for the palette they replace and **10.2** for the four bases, which
/// is the bar: seven colours separating as well as four.
///
/// The cut sites and the name chips are held to a floor rather than counted in
/// that number. Both carry a second signal — [dibasic] is outlined into its own
/// mortar, a chip is a pill with a word in it — so neither has to win on colour
/// alone, and a deuteranope sees magenta as very nearly the grey the aliphatic
/// field must be.
///
/// [aminoUnknown] is not one of the seven — it is the fallback for a residue
/// that is not a residue, and it is quiet on purpose.
///
/// The 4.5:1 floor against the ground is not cosmetic, and it is why none of
/// these may be darkened toward the bases they rhyme with. The painter knocks a
/// residue's letter out of its square *in the ground colour*, so a residue cell
/// too close to the ground erases its own letter; white would need the opposite
/// half of the lightness axis, and the two inks meet at about L\* 50 with no
/// overlap. What corresponds to a base here is the hue and the tile, never the
/// lightness. The role colours above are exempt only because no role but
/// [dibasic] is ever drawn at a stage large enough to letter.
///
/// ## Through the Kaleido filter
///
/// What the Protein Analyses flow draws is [kaleido]: these colours as the
/// colour filter of an E Ink Kaleido 3 panel would show them — see [Kaleido] —
/// which keeps their lightness and hue and lets half their chroma through. A
/// residue square is a large, filled, lettered tile, so its colour is the
/// loudest thing on its page, and that is where the filter is spent: on the
/// seven chemistries, on [aminoUnknown], and on [dibasic], which is one colour
/// for both readings of a cut site and so goes through on the gene page too.
///
/// Everything argued above for the searched colours survives the filter,
/// because it was argued in lightness and hue: the letter floor, the field
/// receding and cysteine leading, the rhyme with the bases. What it spends is
/// the chroma the search bought its distances with — the seven stay at least
/// 14 ΔE00 apart for normal vision, and the dichromat figures above are the
/// searched palette's, not this one's.
///
/// The roles are left as they were searched. The gene page draws them, and it
/// is not what the filter is for; a residue page only carries a role as a chip
/// already stepped most of the way back to the ground.
@immutable
final class AnatomyColors extends ThemeExtension<AnatomyColors> {
  const AnatomyColors({
    required this.aminoAliphatic,
    required this.aminoAromatic,
    required this.aminoPositive,
    required this.aminoNegative,
    required this.aminoPolar,
    required this.aminoSpecial,
    required this.aminoCysteine,
    required this.aminoUnknown,
    required this.roleIntron,
    required this.roleUntranscribed,
    required this.roleUtr5,
    required this.roleUtr3,
    required this.roleExon,
    required this.roleCds,
    required this.roleStartCodon,
    required this.roleStopCodon,
    required this.roleSignal,
    required this.roleMature1,
    required this.roleMature2,
    required this.roleMature3,
    required this.dibasic,
    required this.tracer,
    required this.tracerSibling,
    required this.connector,
    required this.pending,
    required this.baseTile,
  });

  final Color aminoAliphatic;
  final Color aminoAromatic;
  final Color aminoPositive;
  final Color aminoNegative;
  final Color aminoPolar;
  final Color aminoSpecial;
  final Color aminoCysteine;
  final Color aminoUnknown;

  /// What a stretch of the gene *is*, which is the whole of what a nucleotide
  /// stage has to say. A base is one of four letters and there are 1,431 of
  /// them; which piece of the gene it belongs to is the thing worth a colour.
  ///
  /// Lightness carries fate. [roleIntron] and [roleUntranscribed] are material
  /// that will be thrown away and sit nearest the ground; the chains that
  /// survive are the brightest things on the page.
  ///
  /// Both are cool and all but colourless on purpose. Between them they are two
  /// thirds of this gene, and a field that large reads as a colour choice
  /// however quiet the hue is — so they are given none, and what little they
  /// have leans away from every warm run they surround.
  final Color roleIntron;

  /// Outside the transcript. Scaffold rather than content: it says where the
  /// gene is, not what it makes, so it sits a step above the introns and well
  /// below everything that gets transcribed.
  final Color roleUntranscribed;

  /// The two untranslated ends. They were one colour when the caption was the
  /// only thing telling them apart; they are two now, a step apart on the
  /// ladder, because the 5' end is read first and reached first.
  final Color roleUtr5;
  final Color roleUtr3;

  /// [roleExon] survives as a cell's most specific role only in a gene with no
  /// coding sequence at all; where there is one, [roleCds] is what the reader
  /// came for and tops the ladder.
  final Color roleExon;
  final Color roleCds;

  /// The frame's two ends, on the page that draws a reading frame.
  ///
  /// Green for go and red for stop is the one convention a reader arrives
  /// already holding, and these two cells are the only place on this screen
  /// where it is the right one: everywhere else green means *kept* — see
  /// [roleMature1] — and borrowing it for a start codon three squares wide, on
  /// a page where nothing is kept or cut, costs that family nothing.
  ///
  /// Both are set a good deal darker than the rest of the palette, and by
  /// something other than taste: they are the only fills on this screen that
  /// carry a letter in white rather than a letter knocked out of the ground,
  /// and 4.5:1 against white is what that costs. They are set to the *same*
  /// L* and the same ratio as each other, so the pair reads as one
  /// instruction in two states rather than as two unrelated marks.
  ///
  /// [roleStopCodon] is drawn on the gene page too, where it is an instruction
  /// among regions — the same reasoning as [dibasic], one rung lower because
  /// stopping is the end of the story and cutting is a step in it.
  final Color roleStartCodon;
  final Color roleStopCodon;

  /// The leader that gets cleaved, so it sits below both chains that do not.
  final Color roleSignal;

  /// The mature chains, cycled by distinct product in record order, so copies
  /// of one product — polyubiquitin's three — share a colour. In insulin
  /// [roleMature1] and [roleMature3] are the B and A chains, which are kept,
  /// and [roleMature2] is the C-peptide between them, which leaves — so the two
  /// that are kept are the two that are brighter, and the one that goes is
  /// muted and recedes. That ranking holds where a precursor is laid out as
  /// insulin's is; elsewhere the order is the record's, not the fate's
  /// (vasopressin's copeptin takes the bright third colour), and settling that
  /// needs these three searched again rather than nudged.
  ///
  /// Their hues are three rather than one family: these three runs stack
  /// directly on top of each other, and telling them apart is worth more here
  /// than making the kept pair look related, which the ladder already says.
  final Color roleMature1;
  final Color roleMature2;
  final Color roleMature3;

  /// `RR` and `KR` in the protein stages. Warning-adjacent on purpose — these
  /// two pairs are the protease's instruction, and their meaning is *cut here*.
  ///
  /// One colour for both readings of the site — the six bases at the gene stage
  /// and the two residues at the protein stage are the same feature.
  ///
  /// It is the only colour answering to two palettes, so it is the only one not
  /// free to be as loud as the gene page would allow: it has to clear 4.5:1 for
  /// the letter it carries among the residues, and stay clear of all eight
  /// amino colours as well as its neighbours here. Its hue is pinned to the
  /// warning band regardless — a violet cut site would read as kin to the
  /// signal peptide, and what these sites mean is *cut here*.
  ///
  /// Its *saturation* is load-bearing too, in the other direction. At full
  /// chroma these twelve cells were the loudest thing on a page of 1,431, which
  /// bought the two smallest runs an emphasis the gene's actual shape had to
  /// compete with; and the name written across them, knocked out in the ground
  /// colour, had to sit on it. So it is held near half chroma. What it may not
  /// do to get there is drift toward red: [roleStopCodon] is the neighbour a
  /// few rows below, also small and also pink, and a rose cut site would merge
  /// with it. It stays magenta.
  ///
  /// At the residue stages it also carries a shape: the painter outlines those
  /// squares into their own mortar, so the instruction never rests on hue
  /// alone.
  final Color dibasic;

  /// The tracer highlight. The one element on this screen that must never be
  /// ambiguous, so it is a near-maximal contrast against the ground rather than
  /// a hue that could collide with a base colour or a role tint.
  final Color tracer;

  /// The other two bases of a traced residue's codon: the same box, quieter.
  final Color tracerSibling;

  /// Row-end connectors — structural, low contrast. Visible enough to trace the
  /// serpentine by, quiet enough to ignore.
  final Color connector;

  /// An unfilled cell, before the record resolves.
  final Color pending;

  /// The tile every base on the transcript page sits on.
  ///
  /// One neutral for all four, because the letter on it carries the colour —
  /// see `NucleotideColors.muted`. Warm, to sit on the Protein Analyses ground,
  /// and a step above it at 1.17:1: enough that a base still reads as a square
  /// you could count and a codon as three of them, not so much that 465 squares
  /// become a surface competing with their own letters.
  final Color baseTile;

  Color forProperty(AminoAcidProperty property) => switch (property) {
    AminoAcidProperty.aliphatic => aminoAliphatic,
    AminoAcidProperty.aromatic => aminoAromatic,
    AminoAcidProperty.positive => aminoPositive,
    AminoAcidProperty.negative => aminoNegative,
    AminoAcidProperty.polar => aminoPolar,
    AminoAcidProperty.special => aminoSpecial,
    AminoAcidProperty.cysteine => aminoCysteine,
    AminoAcidProperty.unknown => aminoUnknown,
  };

  Color forResidue(String code) => forProperty(AminoAcids.propertyOf(code));

  static const AnatomyColors dark = AnatomyColors(
    aminoAliphatic: Color(0xFF7D8494),
    aminoAromatic: Color(0xFFC599D9),
    aminoPositive: Color(0xFF78B1FF),
    aminoNegative: Color(0xFFF07369),
    aminoPolar: Color(0xFF70B063),
    aminoSpecial: Color(0xFFD0934F),
    aminoCysteine: Color(0xFFE5D86B),
    aminoUnknown: Color(0xFF4E5766),
    roleIntron: Color(0xFF212F2D),
    roleUntranscribed: Color(0xFF475C60),
    roleUtr5: Color(0xFFA88661),
    roleUtr3: Color(0xFF784C36),
    roleExon: Color(0xFF5F869B),
    roleCds: Color(0xFF90AFD6),
    roleStartCodon: Color(0xFF26843E),
    roleStopCodon: Color(0xFFC44A52),
    roleSignal: Color(0xFFA594BE),
    roleMature1: Color(0xFF569150),
    roleMature2: Color(0xFF75597E),
    roleMature3: Color(0xFF6CCB9F),
    dibasic: Color(0xFFD97BB8),
    tracer: Color(0xFFFFFFFF),
    tracerSibling: Color(0x73FFFFFF),
    connector: Color(0xFF2E3849),
    pending: Color(0xFF171D27),
    baseTile: Color(0xFF2A2723),
  );

  /// [dark] through [Kaleido.filter]: the palette the Protein Analyses flow is
  /// drawn in. See the note on the filter above for what goes through it.
  static final AnatomyColors kaleido = dark.copyWith(
    aminoAliphatic: Kaleido.filter(dark.aminoAliphatic),
    aminoAromatic: Kaleido.filter(dark.aminoAromatic),
    aminoPositive: Kaleido.filter(dark.aminoPositive),
    aminoNegative: Kaleido.filter(dark.aminoNegative),
    aminoPolar: Kaleido.filter(dark.aminoPolar),
    aminoSpecial: Kaleido.filter(dark.aminoSpecial),
    aminoCysteine: Kaleido.filter(dark.aminoCysteine),
    aminoUnknown: Kaleido.filter(dark.aminoUnknown),
    dibasic: Kaleido.filter(dark.dibasic),
  );

  @override
  AnatomyColors copyWith({
    Color? aminoAliphatic,
    Color? aminoAromatic,
    Color? aminoPositive,
    Color? aminoNegative,
    Color? aminoPolar,
    Color? aminoSpecial,
    Color? aminoCysteine,
    Color? aminoUnknown,
    Color? roleIntron,
    Color? roleUntranscribed,
    Color? roleUtr5,
    Color? roleUtr3,
    Color? roleExon,
    Color? roleCds,
    Color? roleStartCodon,
    Color? roleStopCodon,
    Color? roleSignal,
    Color? roleMature1,
    Color? roleMature2,
    Color? roleMature3,
    Color? dibasic,
    Color? tracer,
    Color? tracerSibling,
    Color? connector,
    Color? pending,
    Color? baseTile,
  }) {
    return AnatomyColors(
      aminoAliphatic: aminoAliphatic ?? this.aminoAliphatic,
      aminoAromatic: aminoAromatic ?? this.aminoAromatic,
      aminoPositive: aminoPositive ?? this.aminoPositive,
      aminoNegative: aminoNegative ?? this.aminoNegative,
      aminoPolar: aminoPolar ?? this.aminoPolar,
      aminoSpecial: aminoSpecial ?? this.aminoSpecial,
      aminoCysteine: aminoCysteine ?? this.aminoCysteine,
      aminoUnknown: aminoUnknown ?? this.aminoUnknown,
      roleIntron: roleIntron ?? this.roleIntron,
      roleUntranscribed: roleUntranscribed ?? this.roleUntranscribed,
      roleUtr5: roleUtr5 ?? this.roleUtr5,
      roleUtr3: roleUtr3 ?? this.roleUtr3,
      roleExon: roleExon ?? this.roleExon,
      roleCds: roleCds ?? this.roleCds,
      roleStartCodon: roleStartCodon ?? this.roleStartCodon,
      roleStopCodon: roleStopCodon ?? this.roleStopCodon,
      roleSignal: roleSignal ?? this.roleSignal,
      roleMature1: roleMature1 ?? this.roleMature1,
      roleMature2: roleMature2 ?? this.roleMature2,
      roleMature3: roleMature3 ?? this.roleMature3,
      dibasic: dibasic ?? this.dibasic,
      tracer: tracer ?? this.tracer,
      tracerSibling: tracerSibling ?? this.tracerSibling,
      connector: connector ?? this.connector,
      pending: pending ?? this.pending,
      baseTile: baseTile ?? this.baseTile,
    );
  }

  @override
  AnatomyColors lerp(covariant AnatomyColors? other, double t) {
    if (other == null) {
      return this;
    }
    return AnatomyColors(
      aminoAliphatic: Color.lerp(aminoAliphatic, other.aminoAliphatic, t)!,
      aminoAromatic: Color.lerp(aminoAromatic, other.aminoAromatic, t)!,
      aminoPositive: Color.lerp(aminoPositive, other.aminoPositive, t)!,
      aminoNegative: Color.lerp(aminoNegative, other.aminoNegative, t)!,
      aminoPolar: Color.lerp(aminoPolar, other.aminoPolar, t)!,
      aminoSpecial: Color.lerp(aminoSpecial, other.aminoSpecial, t)!,
      aminoCysteine: Color.lerp(aminoCysteine, other.aminoCysteine, t)!,
      aminoUnknown: Color.lerp(aminoUnknown, other.aminoUnknown, t)!,
      roleIntron: Color.lerp(roleIntron, other.roleIntron, t)!,
      roleUntranscribed:
          Color.lerp(roleUntranscribed, other.roleUntranscribed, t)!,
      roleUtr5: Color.lerp(roleUtr5, other.roleUtr5, t)!,
      roleUtr3: Color.lerp(roleUtr3, other.roleUtr3, t)!,
      roleExon: Color.lerp(roleExon, other.roleExon, t)!,
      roleCds: Color.lerp(roleCds, other.roleCds, t)!,
      roleStartCodon:
          Color.lerp(roleStartCodon, other.roleStartCodon, t)!,
      roleStopCodon: Color.lerp(roleStopCodon, other.roleStopCodon, t)!,
      roleSignal: Color.lerp(roleSignal, other.roleSignal, t)!,
      roleMature1: Color.lerp(roleMature1, other.roleMature1, t)!,
      roleMature2: Color.lerp(roleMature2, other.roleMature2, t)!,
      roleMature3: Color.lerp(roleMature3, other.roleMature3, t)!,
      dibasic: Color.lerp(dibasic, other.dibasic, t)!,
      tracer: Color.lerp(tracer, other.tracer, t)!,
      tracerSibling: Color.lerp(tracerSibling, other.tracerSibling, t)!,
      connector: Color.lerp(connector, other.connector, t)!,
      pending: Color.lerp(pending, other.pending, t)!,
      baseTile: Color.lerp(baseTile, other.baseTile, t)!,
    );
  }
}

extension AnatomyColorsContext on BuildContext {
  AnatomyColors get anatomyColors =>
      Theme.of(this).extension<AnatomyColors>() ?? AnatomyColors.dark;
}
