import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../../../core/biology/amino_acids.dart';
import 'protein_target.dart';

enum ConstraintLevel {
  high('highly constrained'),
  middle('moderately constrained'),
  low('tolerant');

  const ConstraintLevel(this.label);
  final String label;
}

@immutable
final class SubstitutionScore {
  const SubstitutionScore(this.aminoAcid, this.score);
  final String aminoAcid;
  final double score;

  /// One scale for every residue. Positive scores saturate at the zero end;
  /// their signed numbers still show the model's preference over wildtype.
  double get barFraction => (score.clamp(-10.0, 0.0) + 10) / 10;
}

/// One named stretch of the precursor, as the asset records it.
///
/// The regions tile the whole protein with no gaps, so asking which one a
/// residue is in is a lookup rather than a chain of comparisons — which is
/// what this used to be, six `switch` arms of insulin's own boundaries.
@immutable
final class ConstraintRegion {
  const ConstraintRegion({
    required this.label,
    required this.short,
    required this.start,
    required this.end,
    required this.origin,
    required this.kept,
  });

  /// 'Signal peptide', 'B chain', 'Spectrin repeat 7'.
  final String label;

  /// What a position in here is prefixed with when it is numbered on its own:
  /// insulin's A chain is 'A', so residue 96 of the precursor is also 'A7'.
  /// Empty for a region whose own numbering is simply the mature chain's.
  final String short;

  final int start;
  final int end;

  /// What a position's second number is counted from, or 1 where it has none.
  /// The bake decides — see `partition` in `tool/targets.py`: each piece of a
  /// precursor cut into several counts from its own start, one chain counts
  /// from its first residue after a removed leader, and nothing else does.
  final int origin;

  /// Whether this stretch survives into the mature product.
  final bool kept;

  bool contains(int number) => number >= start && number <= end;

  int positionOf(int number) => number - origin + 1;

  /// The number the field cites a precursor position [number] in this region
  /// by, where that is not the precursor number itself: 'A7', 'U2 48',
  /// 'mature 157'. Null where the precursor number is the only one.
  String? citationOf(int number) {
    if (origin <= 1) {
      return null;
    }
    final int own = positionOf(number);
    if (short.isEmpty) {
      return 'mature $own';
    }
    return short.length == 1 ? '$short$own' : '$short $own';
  }

  /// The name as it reads inside a sentence: 'the A chain', 'the signal
  /// peptide', but 'C-peptide', 'Lysozyme C' and 'Neurophysin 1'.
  ///
  /// The test is the last word. A common noun — chain, peptide, site, repeat 7
  /// — takes an article; a name or a number is already definite and does not.
  /// Nothing here touches the label's own capitals, which is the whole reason
  /// it is a rule rather than a `toLowerCase()`: that turned 'C-peptide' into
  /// 'c-peptide', which is a different thing, and one that does not exist.
  String get inSentence {
    final String last = label.split(' ').last;
    return last.toLowerCase() == last ? 'the $label' : label;
  }
}

@immutable
final class ResidueConstraint {
  const ResidueConstraint({
    required this.index,
    required this.wildtype,
    required this.conservation,
    required this.ranked,
    required this.region,
    this.rank = 0,
    this.bondPartner,
    this.bondPartnerNumber,
    this.bondPartnerRegion,
  });

  final int index;
  final String wildtype;
  final double conservation;
  final List<SubstitutionScore> ranked;

  /// Where this residue's constraint places it in its protein, 1 being the most
  /// constrained. Ties go to the earlier position.
  final int rank;

  /// The piece of the precursor this residue belongs to.
  final ConstraintRegion region;

  /// The residue on the other end of this one's disulfide, cited the way this
  /// residue is — `Cys96 (A7)`, `Cys214 (mature 192)` — or null for a residue
  /// in no bridge.
  final String? bondPartner;

  /// The precursor number of the residue at the other end of the bridge.
  final int? bondPartnerNumber;

  /// Which piece of the molecule the other end of that bridge is in. The same
  /// one closes a loop; a different one holds two pieces together, which is
  /// what keeps insulin working after the C-peptide between its chains is cut
  /// out and thrown away.
  final ConstraintRegion? bondPartnerRegion;

  ConstraintLevel get level => conservation >= 0.8
      ? ConstraintLevel.high
      : conservation >= 0.4
      ? ConstraintLevel.middle
      : ConstraintLevel.low;

  String get name => AminoAcids.of(wildtype)!.name;

  /// The precursor number, which is UniProt's and HGVS's.
  int get number => index + 1;

  /// The second number the field cites this residue by, or null.
  String? get citation => region.citationOf(number);

  /// How the residue is cited: `Cys179 · mature 157`, `Cys96 · A7`, `Arg175`.
  /// The precursor number leads, because it is the one every database agrees
  /// on; a chain's own numbering follows where the field uses one.
  String get title => cite(wildtype, number, region);

  /// [title], as a screen reader should say it.
  String get spoken =>
      '$name $number${citation == null ? '' : ', $citation'}';

  String get domain => region.label;

  int get domainPosition => region.positionOf(number);

  /// A residue cited with its precursor number first — see [title].
  static String cite(String code, int number, ConstraintRegion region) {
    final String? second = region.citationOf(number);
    return '${AminoAcids.abbreviationOf(code)}$number'
        '${second == null ? '' : ' · $second'}';
  }

  String get note {
    if (level == ConstraintLevel.high) {
      final String favored = AminoAcids.of(ranked.first.aminoAcid)!.name;
      final String preference =
          'The model strongly favors $favored here. Most alternatives score much lower.';
      if (bondPartner case final String partner) {
        final ConstraintRegion other = bondPartnerRegion ?? region;
        return other == region
            ? '$preference This cysteine bonds to $partner, '
                  'closing a loop within ${region.inSentence}.'
            : '$preference This cysteine bonds to $partner, and the two of '
                  'them link ${region.inSentence} to ${other.inSentence}.';
      }
      return preference;
    }
    if (level == ConstraintLevel.middle) {
      return 'Some replacements fit this context better than others. '
          'The model has a preference, with room for variation.';
    }
    if (!region.kept) {
      return 'Many alternatives receive similar scores here. '
          'This part of the precursor is removed with ${region.inSentence}.';
    }
    return 'Several amino acids fit this context. '
        'The model is less specific about which residue belongs here.';
  }
}

@immutable
final class ProteinConstraint {
  const ProteinConstraint._(this.sequence, this.positions, this.regions);

  static const String aminoAcids = 'ACDEFGHIKLMNPQRSTVWY';

  final String sequence;
  final List<ResidueConstraint> positions;
  final List<ConstraintRegion> regions;

  /// Every disulfide once, lower precursor number first, in precursor order:
  /// the numbering a page's bridge badges use.
  List<(int, int)> get bridges => <(int, int)>[
    for (final ResidueConstraint p in positions)
      if (p.bondPartnerNumber case final int other when other > p.number)
        (p.number, other),
  ];

  static Future<ProteinConstraint> load(
    ProteinTarget target, {
    AssetBundle? bundle,
  }) async => ProteinConstraint.fromJson(
    jsonDecode(await (bundle ?? rootBundle).loadString(target.constraintAsset))
        as Map<String, dynamic>,
    target,
  );

  /// Parses one baked track, refusing anything it cannot vouch for.
  ///
  /// The provenance header is checked as strictly as it ever was — a track
  /// scored a different way is not comparable with one scored this way, and a
  /// screen that mixed them would be quietly lying. What changed is that the
  /// molecule it is checked against comes from [target] rather than from a
  /// constant in this file.
  ///
  /// The sequence itself is checked once more upstream, where it matters most:
  /// the protein page only colours itself when the stage's own letters are this
  /// sequence, so a track can never be drawn over a different molecule even if
  /// it got this far.
  factory ProteinConstraint.fromJson(
    Map<String, dynamic> json,
    ProteinTarget target,
  ) {
    if (json['gene'] != target.gene ||
        json['uniprot'] != target.uniprot ||
        json['model'] != 'facebook/esm2_t33_650M_UR50D' ||
        json['method'] != 'masked_marginals' ||
        json['normalization'] != 'minmax' ||
        json['entropy_vocabulary'] != 'full') {
      throw FormatException('Unsupported constraint asset for ${target.slug}');
    }
    final String sequence = json['sequence'] as String;
    final List<dynamic> raw = json['positions'] as List<dynamic>;
    if (sequence.isEmpty || raw.length != sequence.length) {
      throw FormatException('Incomplete scores for ${target.slug}');
    }

    final List<ConstraintRegion> regions = _regions(json, sequence.length, target);
    final Map<int, int> partners = _partners(json, sequence, target);

    ConstraintRegion regionAt(int number) =>
        regions.firstWhere((ConstraintRegion r) => r.contains(number));

    // Most constrained first; a tie keeps sequence order.
    final List<int> order = List<int>.generate(raw.length, (int i) => i)
      ..sort((int a, int b) {
        final num ca = (raw[a] as Map<String, dynamic>)['conservation'] as num;
        final num cb = (raw[b] as Map<String, dynamic>)['conservation'] as num;
        final int byValue = cb.compareTo(ca);
        return byValue == 0 ? a.compareTo(b) : byValue;
      });
    final List<int> rankOf = List<int>.filled(raw.length, 0);
    for (int r = 0; r < order.length; r++) {
      rankOf[order[r]] = r + 1;
    }

    final List<ResidueConstraint> positions = <ResidueConstraint>[];
    for (int i = 0; i < raw.length; i++) {
      final Map<String, dynamic> p = raw[i] as Map<String, dynamic>;
      final double conservation = (p['conservation'] as num).toDouble();
      final Map<String, dynamic> scores =
          p['substitutions'] as Map<String, dynamic>;
      if (p['index'] != i ||
          p['wildtype'] != sequence[i] ||
          !conservation.isFinite ||
          conservation < 0 ||
          conservation > 1 ||
          scores.length != 20 ||
          scores[sequence[i]] != 0) {
        throw FormatException('Invalid scores at precursor position ${i + 1}');
      }
      final List<SubstitutionScore> ranked = <SubstitutionScore>[];
      for (final String aa in aminoAcids.split('')) {
        final num? value = scores[aa] as num?;
        if (value == null || !value.isFinite) {
          throw FormatException('Missing or invalid substitution $aa at $i');
        }
        ranked.add(SubstitutionScore(aa, value.toDouble()));
      }
      ranked.sort((SubstitutionScore a, SubstitutionScore b) {
        final int byScore = b.score.compareTo(a.score);
        return byScore == 0 ? a.aminoAcid.compareTo(b.aminoAcid) : byScore;
      });

      final ConstraintRegion region = regionAt(i + 1);
      final int? partner = partners[i + 1];
      final ConstraintRegion? partnerRegion =
          partner == null ? null : regionAt(partner);
      positions.add(
        ResidueConstraint(
          index: i,
          wildtype: sequence[i],
          conservation: conservation,
          ranked: List<SubstitutionScore>.unmodifiable(ranked),
          region: region,
          rank: rankOf[i],
          bondPartner: partnerRegion == null ? null : _partner(partner!, partnerRegion),
          bondPartnerNumber: partner,
          bondPartnerRegion: partnerRegion,
        ),
      );
    }
    return ProteinConstraint._(
      sequence,
      List<ResidueConstraint>.unmodifiable(positions),
      List<ConstraintRegion>.unmodifiable(regions),
    );
  }

  /// A bonded cysteine, cited as in [ResidueConstraint.title] with its second
  /// number in parentheses: `Cys96 (A7)`.
  static String _partner(int number, ConstraintRegion region) {
    final String? second = region.citationOf(number);
    return 'Cys$number${second == null ? '' : ' ($second)'}';
  }

  /// The region table, checked to be a gapless tiling of the whole precursor.
  ///
  /// Gapless is the invariant everything downstream leans on: `regionAt` is a
  /// `firstWhere` with no fallback, and a hole in the table would throw at the
  /// moment a reader tapped the residue that fell in it rather than here.
  static List<ConstraintRegion> _regions(
    Map<String, dynamic> json,
    int length,
    ProteinTarget target,
  ) {
    final List<dynamic> raw = json['regions'] as List<dynamic>? ?? <dynamic>[];
    final List<ConstraintRegion> regions = <ConstraintRegion>[];
    int expected = 1;
    for (final dynamic entry in raw) {
      final Map<String, dynamic> r = entry as Map<String, dynamic>;
      if (r['label'] is! String ||
          r['short'] is! String ||
          r['start'] is! int ||
          r['end'] is! int ||
          r['origin'] is! int ||
          r['kept'] is! bool) {
        // Checked rather than cast so a track baked before a field existed
        // says so, instead of throwing a type error from three frames down.
        throw FormatException(
          'Malformed region in ${target.slug}: $r. Re-run '
          'tool/constraint/score_protein.py --metadata-only.',
        );
      }
      final ConstraintRegion region = ConstraintRegion(
        label: r['label'] as String,
        short: r['short'] as String,
        start: r['start'] as int,
        end: r['end'] as int,
        origin: r['origin'] as int,
        kept: r['kept'] as bool,
      );
      if (region.start != expected || region.end < region.start) {
        throw FormatException(
          'Region table for ${target.slug} breaks at residue $expected',
        );
      }
      expected = region.end + 1;
      regions.add(region);
    }
    if (expected != length + 1) {
      throw FormatException(
        'Region table for ${target.slug} covers ${expected - 1} of $length residues',
      );
    }
    return regions;
  }

  /// Every bonded position mapped to the position it is bonded to.
  static Map<int, int> _partners(
    Map<String, dynamic> json,
    String sequence,
    ProteinTarget target,
  ) {
    final List<dynamic> raw = json['disulfides'] as List<dynamic>? ?? <dynamic>[];
    final Map<int, int> partners = <int, int>{};
    for (final dynamic entry in raw) {
      final List<dynamic> pair = entry as List<dynamic>;
      if (pair.length != 2) {
        throw FormatException('Malformed disulfide in ${target.slug}');
      }
      final int a = pair[0] as int;
      final int b = pair[1] as int;
      for (final int number in <int>[a, b]) {
        if (number < 1 ||
            number > sequence.length ||
            sequence[number - 1] != 'C' ||
            partners.containsKey(number)) {
          throw FormatException(
            'Disulfide at residue $number is not an unused cysteine in ${target.slug}',
          );
        }
      }
      partners[a] = b;
      partners[b] = a;
    }
    return partners;
  }
}
