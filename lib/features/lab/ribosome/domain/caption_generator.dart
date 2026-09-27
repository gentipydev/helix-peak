import '../../../../core/biology/amino_acids.dart';
import '../../../../core/biology/gene_record.dart';
import '../../../../shared/format.dart';
import 'translation_timeline.dart';

/// One sentence for each moment of a translation, built from the record.
///
/// Every sentence is made of the record's own numbers and letters: the 5′
/// UTR's length, the start codon's context at −3 and +4, where the signal
/// peptide ends, where the exons meet, where each mature chain begins and
/// ends, and the stop codon. Nothing here names a gene or a protein, and
/// nothing branches on one. Where a sentence cannot be built from the record
/// (a 5′ UTR too short to have a −3), [captionFor] returns null and nothing is
/// drawn.
final class CaptionGenerator {
  CaptionGenerator(this.timeline, GeneRecord record)
    : _chains = _chainsOf(record, timeline.protein.length);

  final TranslationTimeline timeline;

  /// The mature chains, as residue ranges (1-based, inclusive), in order.
  final List<(int, int)> _chains;

  /// The sentence for [state], or null where none can be built.
  String? captionFor(TranslationState state) => switch (state.phase) {
    TranslationPhase.scanning => _scanning(),
    TranslationPhase.joining => _joining(),
    TranslationPhase.releaseFactor => _stopCodon(),
    TranslationPhase.release =>
      'The chain, ${grouped(timeline.protein.length)} residues, is cut '
          'free of the last tRNA and leaves the tunnel.',
    TranslationPhase.dissociation => _parting(),
    _ => _event(state) ?? _cycle(state),
  };

  String? _scanning() {
    final int utr = timeline.cdsStart;
    if (utr == 0) {
      return null;
    }
    return 'The small subunit scans the 5′ UTR, ${grouped(utr)} '
        '${utr == 1 ? 'base' : 'bases'}, from the cap to the start codon.';
  }

  String _joining() {
    final int start = timeline.cdsStart;
    final String? minus3 = start >= 3 ? timeline.mrna[start - 3] : null;
    final String plus4 = timeline.mrna[start + 3];
    return minus3 == null
        ? 'The large subunit joins at the start codon, with $plus4 at +4.'
        : 'The large subunit joins at the start codon. Around it, the Kozak '
              'context reads $minus3 at −3 and $plus4 at +4.';
  }

  String _stopCodon() {
    final int stop = timeline.stopCodonStart;
    final String codon = timeline.mrna.substring(stop, stop + 3);
    return 'The stop codon $codon reaches the A site. No tRNA reads it; a '
        'release factor does.';
  }

  String _parting() {
    final String second = timeline.protein.length >= 2
        ? AminoAcids.nameOf(timeline.protein[1]).toLowerCase()
        : '';
    final String clipping = timeline.protein.length < 2
        ? ''
        : timeline.initiatorMetClipped
        ? ' Residue 2 is $second, small enough for methionine '
              'aminopeptidase to clip the first methionine off.'
        : ' Residue 2 is $second, so the first methionine stays.';
    return 'The two subunits part and let go of the mRNA.$clipping';
  }

  /// What happens in this codon's beat that happens only once.
  String? _event(TranslationState state) {
    final int codon = state.codon;
    final double from = timeline.beatStart(timeline.beatOfCodon(codon));
    final double to = timeline.beatStart(timeline.beatOfCodon(codon) + 1);
    bool within(double? t) => t != null && t >= from && t < to;

    final (double, double)? srp = timeline.srpWindow;
    if (srp != null && within(srp.$1)) {
      return 'All ${grouped(timeline.signalPeptideLength)} residues of the '
          'signal peptide are out of the tunnel: signal recognition particle '
          'can bind them now.';
    }
    if (within(timeline.firstExit)) {
      return 'The first residue leaves the tunnel, which now holds '
          '${TranslationTimeline.tunnelCapacity} residues.';
    }
    for (int i = 0; i < timeline.ejcKnockoff.length; i++) {
      final ({int junction, double t}) passed = timeline.ejcKnockoff[i];
      if (within(passed.t)) {
        final int exon = timeline.junctions.indexOf(passed.junction) + 1;
        return 'The ribosome passes the junction of exons ${spelled(exon)} '
            'and ${spelled(exon + 1)}, at base ${grouped(passed.junction)} of '
            'the mRNA, and knocks off its exon junction complex.';
      }
    }
    if (timeline.signalPeptideLength > 0 &&
        codon == timeline.signalPeptideLength) {
      return 'Residue ${grouped(codon)} ends the signal peptide.';
    }
    for (int i = 0; i < _chains.length; i++) {
      final (int first, int last) = _chains[i];
      final String which = _chains.length == 1
          ? 'the mature chain'
          : 'mature chain ${spelled(i + 1)} of ${spelled(_chains.length)}';
      if (codon == first) {
        return 'Residue ${grouped(codon)} begins $which.';
      }
      if (codon == last) {
        return 'Residue ${grouped(codon)} ends $which.';
      }
    }
    return null;
  }

  /// What every cycle does, said for this one.
  String? _cycle(TranslationState state) {
    final int codon = state.codon;
    if (codon < 2 || codon > timeline.protein.length) {
      return null;
    }
    final int start = timeline.cdsStart + 3 * (codon - 1);
    final String triplet = timeline.mrna.substring(start, start + 3);
    final String residue = AminoAcids.nameOf(timeline.protein[codon - 1])
        .toLowerCase();
    return switch (state.phase) {
      TranslationPhase.decoding =>
        'Codon ${grouped(codon)} reads $triplet, and the tRNA that pairs with '
            'it brings $residue.',
      TranslationPhase.peptideBond =>
        'The chain moves onto $residue, and is ${grouped(codon)} residues '
            'long.',
      TranslationPhase.translocation =>
        'The ribosome moves one codon along the mRNA.',
      TranslationPhase.trnaExit => 'The emptied tRNA leaves from the E site.',
      _ => null,
    };
  }

  /// Each mature chain's first and last residue on the precursor, read off
  /// where its bases sit in the coding sequence.
  static List<(int, int)> _chainsOf(GeneRecord record, int length) {
    final Protein? protein = record.protein;
    if (protein == null || record.peptides.isEmpty) {
      return const <(int, int)>[];
    }
    final List<int> coding = <int>[
      for (final Segment s in protein.segments)
        for (int p = s.start; p <= s.end; p++) p,
    ];
    if (record.strand == -1) {
      coding.sort((int a, int b) => b.compareTo(a));
    } else {
      coding.sort();
    }
    final Map<int, int> residueOf = <int, int>{
      for (int i = 0; i < coding.length; i++) coding[i]: i ~/ 3 + 1,
    };
    final List<(int, int)> chains = <(int, int)>[];
    for (final Peptide peptide in record.peptides) {
      final List<int> residues = <int>[
        for (final Segment s in peptide.segments)
          for (final int p in <int>[s.start, s.end])
            if (residueOf[p] case final int r) r,
      ]..sort();
      if (residues.isNotEmpty &&
          residues.first >= 1 &&
          residues.last <= length) {
        chains.add((residues.first, residues.last));
      }
    }
    return chains;
  }
}
