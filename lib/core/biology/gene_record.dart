import 'package:flutter/foundation.dart';

/// One contiguous stretch of a feature — one part of a GenBank `join(...)`.
///
/// Coordinates are 1-based inclusive, as GenBank prints them.
@immutable
final class Segment {
  const Segment({required this.start, required this.end});

  final int start;
  final int end;

  int get lengthBp => end - start + 1;
}

@immutable
final class Exon {
  const Exon({required this.start, required this.end, this.number});

  final int? number;
  final int start;
  final int end;
}

@immutable
final class Peptide {
  const Peptide({
    required this.segments,
    required this.translation,
    this.product,
  });

  final String? product;
  final List<Segment> segments;
  final String translation;

  int get lengthAa => translation.length;
}

@immutable
final class Transcript {
  const Transcript({required this.segments});

  final List<Segment> segments;
}

@immutable
final class Protein {
  const Protein({
    required this.translation,
    required this.segments,
    this.product,
  });

  final String? product;
  final String translation;
  final List<Segment> segments;
}

/// One gene lifted out of a GenBank record.
///
/// Every field here is something the anatomy screen draws. Lengths are getters
/// rather than fields: the backend does not send a number it would only be
/// restating, so there is no second copy to fall out of step with the first.
@immutable
final class GeneRecord {
  const GeneRecord({
    required this.gene,
    required this.start,
    required this.end,
    required this.sequence,
    required this.exons,
    required this.peptides,
    this.strand,
    this.transcript,
    this.protein,
    this.signalPeptide,
    this.proprotein,
    this.intronScale,
    this.realSpanBp,
    this.realIntronBp,
  });

  final String gene;

  final int start;
  final int end;
  final int? strand;
  final String sequence;

  final Transcript? transcript;
  final Protein? protein;
  final List<Exon> exons;
  final Peptide? signalPeptide;
  final Peptide? proprotein;
  final List<Peptide> peptides;

  /// How much of each intron [sequence] holds, where it does not hold all of
  /// it. Null for a record that is a verbatim slice of its source.
  ///
  /// The gene page scrolls past about 9,400 bases, one row of fourteen points
  /// for every 195: past about 24,000 there is more page than picture. One of
  /// the genes here is past it — dystrophin, at 2.1 Mb — so its introns are
  /// shortened, its exons are not, and the page says so rather than letting
  /// the picture imply a scale it is not drawn at.
  final double? intronScale;

  /// What the gene really spans, when [intronScale] says this is not all of it.
  final int? realSpanBp;

  /// Each intron's real length, in transcript order, when [intronScale] says
  /// they were shortened. Not recoverable from the scale: an intron shortened
  /// to the bake's floor was shortened by less than the scale says.
  final List<int>? realIntronBp;

  bool get isIntronCompressed => intronScale != null && intronScale! < 1;

  int get lengthBp => end - start + 1;
}
