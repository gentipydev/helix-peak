import 'package:flutter/foundation.dart';

/// What kind of residue this is — the property that decides how it behaves in
/// a folded chain.
///
/// Seven groups rather than twenty colours. Twenty distinct hues on a grid of
/// squares is noise, and no reader holds that legend; every square already
/// carries its letter, so the colour is free to say the thing the letter
/// cannot. The grouping is Zappo's, the one Jalview uses for sequence views,
/// which is what this screen is.
///
/// Seven rather than four because four hid two real distinctions. Glycine and
/// proline are not hydrophobes — they are the two residues that decide where a
/// chain can bend — and the aromatics are a family in their own right, so
/// filing tyrosine away from phenylalanine and tryptophan split a group that
/// stacks together. Separating [positive] from [negative] is what lets the
/// dibasic cut sites stand apart from an ordinary acidic residue.
///
/// Cysteine keeps a group of its own because it is the only residue that bonds
/// to another copy of itself, and those bonds are what hold the two insulin
/// chains together.
enum AminoAcidProperty {
  aliphatic,
  aromatic,
  positive,
  negative,
  polar,
  special,
  cysteine,
  unknown,
}

@immutable
final class AminoAcid {
  const AminoAcid({
    required this.code,
    required this.abbreviation,
    required this.name,
    required this.property,
  });

  /// The one-letter code, as it appears in a `/translation` qualifier.
  final String code;

  /// The three-letter code a residue is cited by: `Cys179`, `Arg175`.
  final String abbreviation;

  final String name;

  final AminoAcidProperty property;
}

/// The twenty proteinogenic residues.
///
/// This is the only table in the anatomy feature that does not come from the
/// parsed record, and it is deliberately not a coordinate: the genetic code is
/// the same in every GenBank entry, while every position, length and boundary
/// still has to be read off the record itself.
abstract final class AminoAcids {
  static const Map<String, AminoAcid> _byCode = <String, AminoAcid>{
    'A': AminoAcid(
      code: 'A',
      abbreviation: 'Ala',
      name: 'alanine',
      property: AminoAcidProperty.aliphatic,
    ),
    'R': AminoAcid(
      code: 'R',
      abbreviation: 'Arg',
      name: 'arginine',
      property: AminoAcidProperty.positive,
    ),
    'N': AminoAcid(
      code: 'N',
      abbreviation: 'Asn',
      name: 'asparagine',
      property: AminoAcidProperty.polar,
    ),
    'D': AminoAcid(
      code: 'D',
      abbreviation: 'Asp',
      name: 'aspartate',
      property: AminoAcidProperty.negative,
    ),
    'C': AminoAcid(
      code: 'C',
      abbreviation: 'Cys',
      name: 'cysteine',
      property: AminoAcidProperty.cysteine,
    ),
    'Q': AminoAcid(
      code: 'Q',
      abbreviation: 'Gln',
      name: 'glutamine',
      property: AminoAcidProperty.polar,
    ),
    'E': AminoAcid(
      code: 'E',
      abbreviation: 'Glu',
      name: 'glutamate',
      property: AminoAcidProperty.negative,
    ),
    'G': AminoAcid(
      code: 'G',
      abbreviation: 'Gly',
      name: 'glycine',
      property: AminoAcidProperty.special,
    ),
    'H': AminoAcid(
      code: 'H',
      abbreviation: 'His',
      name: 'histidine',
      property: AminoAcidProperty.positive,
    ),
    'I': AminoAcid(
      code: 'I',
      abbreviation: 'Ile',
      name: 'isoleucine',
      property: AminoAcidProperty.aliphatic,
    ),
    'L': AminoAcid(
      code: 'L',
      abbreviation: 'Leu',
      name: 'leucine',
      property: AminoAcidProperty.aliphatic,
    ),
    'K': AminoAcid(
      code: 'K',
      abbreviation: 'Lys',
      name: 'lysine',
      property: AminoAcidProperty.positive,
    ),
    'M': AminoAcid(
      code: 'M',
      abbreviation: 'Met',
      name: 'methionine',
      property: AminoAcidProperty.aliphatic,
    ),
    'F': AminoAcid(
      code: 'F',
      abbreviation: 'Phe',
      name: 'phenylalanine',
      property: AminoAcidProperty.aromatic,
    ),
    'P': AminoAcid(
      code: 'P',
      abbreviation: 'Pro',
      name: 'proline',
      property: AminoAcidProperty.special,
    ),
    'S': AminoAcid(
      code: 'S',
      abbreviation: 'Ser',
      name: 'serine',
      property: AminoAcidProperty.polar,
    ),
    'T': AminoAcid(
      code: 'T',
      abbreviation: 'Thr',
      name: 'threonine',
      property: AminoAcidProperty.polar,
    ),
    'W': AminoAcid(
      code: 'W',
      abbreviation: 'Trp',
      name: 'tryptophan',
      property: AminoAcidProperty.aromatic,
    ),
    'Y': AminoAcid(
      code: 'Y',
      abbreviation: 'Tyr',
      name: 'tyrosine',
      property: AminoAcidProperty.aromatic,
    ),
    'V': AminoAcid(
      code: 'V',
      abbreviation: 'Val',
      name: 'valine',
      property: AminoAcidProperty.aliphatic,
    ),
  };

  static AminoAcid? of(String code) {
    if (code.isEmpty) {
      return null;
    }
    return _byCode[code[0].toUpperCase()];
  }

  /// The three-letter code, falling back to the code itself for a residue that
  /// is not one of the twenty (`X`).
  static String abbreviationOf(String code) => of(code)?.abbreviation ?? code;

  /// The residue's full name, for the tracer's status line.
  ///
  /// Falls back to the code itself rather than to a word: a `/translation` can
  /// carry `X` for an unresolved residue, and "X" is more honest there than
  /// inventing a name for it.
  static String nameOf(String code) => of(code)?.name ?? code;

  static AminoAcidProperty propertyOf(String code) =>
      of(code)?.property ?? AminoAcidProperty.unknown;
}
