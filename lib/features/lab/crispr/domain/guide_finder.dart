import 'package:flutter/foundation.dart';

import '../../../../core/biology/gene_record.dart';
import '../../mutate/domain/apply_edit.dart';
import 'guide_score.dart';

/// Which strand of the record a protospacer lies on.
///
/// Neither value says anything about the gene's strand on the chromosome: the
/// record's `sequence` is already the gene's own strand (R2.1), and these two
/// are the two strands of the double helix as the gene page draws it.
enum GuideStrand {
  /// The protospacer reads along the record's own sequence.
  sense,

  /// The protospacer reads along the strand complementary to it, which is to
  /// say backwards down the record, complemented.
  antisense,
}

/// One place an SpCas9 nuclease can be aimed: twenty bases and their PAM.
///
/// Positions are record positions, the numbers the record's own segments use,
/// and the record is read 5' to 3' on the gene's own strand — which on a
/// minus-strand record is down the coordinates (R2.1). [step] is the one place
/// that direction is written down: every position here is [from] plus some
/// number of steps.
///
/// An antisense guide reads the other way along the record, so its
/// [protospacer] is the complement of the letters the page draws, reversed,
/// and a base it writes has to be turned back before it can be written as an
/// edit — [asRecordWrites] does that.
@immutable
final class Guide {
  const Guide({
    required this.protospacer,
    required this.pam,
    required this.strand,
    required this.from,
    required this.step,
    required this.score,
  });

  /// The twenty bases the nuclease is aimed with, 5' to 3' on [strand].
  final String protospacer;

  /// The three bases immediately 3' of [protospacer] on [strand]: N, then G,
  /// then G.
  final String pam;

  final GuideStrand strand;

  /// The first of the twenty bases as the record reads them.
  ///
  /// For a sense guide that is the protospacer's own 5' end; for an antisense
  /// guide the record runs the other way through it, so it is base twenty.
  final int from;

  /// How a record position changes with each base read 3': 1, or -1 on a
  /// minus-strand record.
  final int step;

  final GuideScore score;

  /// Where the blunt cut falls: between bases [cutBetween] and the one after
  /// it, which leaves three bases between the cut and the PAM.
  static const int cutBetween = 17;

  /// The last of the twenty bases as the record reads them.
  int get to => from + (protospacer.length - 1) * step;

  /// The first base of the whole site — the twenty bases and their PAM, which
  /// the nuclease reads as one run of twenty-three — as the record reads it.
  int get siteFrom =>
      strand == GuideStrand.sense ? from : from - pam.length * step;

  /// The last base of that run, as the record reads it.
  int get siteTo => strand == GuideStrand.sense ? to + pam.length * step : to;

  /// The base immediately 3' of the blunt cut, as the record reads it.
  ///
  /// The cut is a break in both strands at one place, so it is written the way
  /// the record is read rather than the way the guide is: an [Insertion] here
  /// goes in exactly at the cut, and a [Deletion] here takes the bases 3' of
  /// it. Reading along the guide instead, what follows the cut is bases
  /// eighteen, nineteen and twenty, and then the PAM.
  int get cutPosition =>
      positionAt(strand == GuideStrand.sense ? cutBetween + 1 : cutBetween);

  /// The record position of base [place] of the protospacer, counted from 1 at
  /// the guide's own 5' end.
  int positionAt(int place) {
    RangeError.checkValueInInterval(place, 1, protospacer.length, 'place');
    return strand == GuideStrand.sense
        ? from + (place - 1) * step
        : to - (place - 1) * step;
  }

  /// The record position [bases] bases 3' of the cut, as the record reads it.
  /// Negative for a base 5' of it; 0 is [cutPosition] itself.
  int positionFromCut(int bases) => cutPosition + bases * step;

  /// [base], written on this guide's strand, as the record's own strand writes
  /// it.
  ///
  /// An edit is always written the way the gene page draws it, on the gene's
  /// own strand (see [SequenceEdit]), so a base an editor writes on an
  /// antisense guide's strand is written here as the base that pairs with it.
  String asRecordWrites(String base) =>
      strand == GuideStrand.sense ? base : complementOf(base);

  @override
  String toString() =>
      'Guide($protospacer $pam, ${strand.name}, $from to $to, '
      'cut before $cutPosition)';
}

/// Finds the places an SpCas9 nuclease can be aimed at in a record.
///
/// A site is twenty bases followed by an NGG PAM, on either strand, and the
/// blunt cut falls three bases 5' of the PAM. Nothing else is claimed about
/// it: **off-target sites are not searched for anywhere in this feature**, so
/// a guide here has been matched against this one gene and against nothing
/// else in the genome, and no guide is ever described as specific or safe.
/// [GuideScore] measures two properties of the bases and predicts no
/// efficiency.
abstract final class GuideFinder {
  /// The bases a nuclease is aimed with.
  static const int protospacerLength = 20;

  /// The bases of the PAM that has to follow them.
  static const int pamLength = 3;

  /// The whole run a nuclease reads: the protospacer and its PAM.
  static const int siteLength = protospacerLength + pamLength;

  /// Every site [record] offers, ordered by the first base of the site as the
  /// record reads it, the sense strand first where both offer one there.
  ///
  /// Only sites the record really holds: every one of the twenty-three bases
  /// has to be a base ([EditEligibility]) that can be placed on the
  /// chromosome. In DMD, APP and CFTR the introns are drawn shortened (R2.4),
  /// so bases either side of a cut middle are neighbours on the page and not
  /// on the chromosome; a guide reading across one would be aimed at a
  /// sequence that does not exist. [eligibilityOf] says so for a given site.
  static List<Guide> find(GeneRecord record) {
    final String sequence = record.sequence;
    if (sequence.length < siteLength) {
      return const <Guide>[];
    }
    final int step = record.strand == -1 ? -1 : 1;
    final int origin = record.strand == -1 ? record.end : record.start;

    // How many of the first n bases the record really holds, so that asking it
    // of a whole site is one subtraction. Every base is asked of
    // [EditEligibility] once, and the rule about which ones are fiction stays
    // feature 5's alone.
    final Int32List held = Int32List(sequence.length + 1);
    for (int offset = 0; offset < sequence.length; offset++) {
      final bool real =
          _isBase(sequence[offset]) &&
          EditEligibility.of(record, origin + offset * step) is Eligible;
      held[offset + 1] = held[offset] + (real ? 1 : 0);
    }

    final List<Guide> guides = <Guide>[];
    for (int at = 0; at + siteLength <= sequence.length; at++) {
      // NGG on the record's own strand reads GG at the last two bases of the
      // site; on the other strand it reads CC at the first two, because the
      // PAM is then 3' of a protospacer that runs backwards down the record.
      final bool sense = sequence.startsWith('GG', at + protospacerLength + 1);
      final bool antisense = sequence.startsWith('CC', at);
      if (!sense && !antisense) {
        continue;
      }
      if (held[at + siteLength] - held[at] != siteLength) {
        continue;
      }
      if (sense) {
        final String protospacer = sequence.substring(
          at,
          at + protospacerLength,
        );
        guides.add(
          Guide(
            protospacer: protospacer,
            pam: sequence.substring(at + protospacerLength, at + siteLength),
            strand: GuideStrand.sense,
            from: origin + at * step,
            step: step,
            score: GuideScore.of(protospacer),
          ),
        );
      }
      if (antisense) {
        final String protospacer = _reverseComplement(
          sequence.substring(at + pamLength, at + siteLength),
        );
        guides.add(
          Guide(
            protospacer: protospacer,
            pam: _reverseComplement(sequence.substring(at, at + pamLength)),
            strand: GuideStrand.antisense,
            from: origin + (at + pamLength) * step,
            step: step,
            score: GuideScore.of(protospacer),
          ),
        );
      }
    }
    return List<Guide>.unmodifiable(guides);
  }

  /// Whether the record really holds every base of [guide]'s site.
  ///
  /// [find] returns only guides this answers [Eligible] for; it is here so
  /// that a site the reader can see on the page can be told why it is not
  /// offered, in [Ineligible.reason]'s own words.
  static EditEligibility eligibilityOf(GeneRecord record, Guide guide) {
    final int step = guide.step;
    for (
      int position = guide.siteFrom;
      position != guide.siteTo + step;
      position += step
    ) {
      final EditEligibility base = EditEligibility.of(record, position);
      if (base is Ineligible) {
        return base;
      }
    }
    return const Eligible();
  }
}

bool _isBase(String base) =>
    base == 'A' || base == 'C' || base == 'G' || base == 'T';

/// The base that pairs with [base] on the other strand.
String complementOf(String base) => switch (base) {
  'A' => 'T',
  'C' => 'G',
  'G' => 'C',
  'T' => 'A',
  _ => throw ArgumentError.value(base, 'base', 'must be one of A, C, G and T'),
};

String _reverseComplement(String bases) {
  final StringBuffer other = StringBuffer();
  for (int i = bases.length - 1; i >= 0; i--) {
    other.write(complementOf(bases[i]));
  }
  return other.toString();
}
