import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../../../core/biology/gene_record.dart';

/// What a stretch of a gene is.
enum GenePieceKind { utr, cds, intron }

/// One stretch of a gene, in base pairs from its 5′ end, half-open.
@immutable
final class GenePiece {
  const GenePiece({required this.start, required this.end, required this.kind});

  final double start;
  final double end;
  final GenePieceKind kind;

  double get length => end - start;
}

/// A gene's exons and introns laid along it from its 5′ end, at their real
/// lengths: the record's own coordinates where it holds the gene whole, and
/// where its introns are shortened (dystrophin, APP, CFTR), each intron at
/// the real length the record keeps for it, so the drawing is to scale even
/// where the record is not. An exon is split into its coding part (the
/// CDS's segments) and its untranslated ends.
@immutable
final class GeneLayout {
  const GeneLayout({required this.pieces, required this.length});

  factory GeneLayout.of(GeneRecord record) {
    final int strand = (record.strand ?? 1) < 0 ? -1 : 1;
    // A record position as base pairs from the gene's 5′ end, in the record.
    double from5(int position) => strand < 0
        ? (record.end - position).toDouble()
        : (position - record.start).toDouble();
    (double, double) span(int a, int b) {
      final double x = from5(a);
      final double y = from5(b);
      return (math.min(x, y), math.max(x, y) + 1);
    }

    final List<(double, double)> exons = <(double, double)>[
      for (final Exon exon in record.exons) span(exon.start, exon.end),
    ]..sort(((double, double) a, (double, double) b) => a.$1.compareTo(b.$1));
    final List<(double, double)> coding = <(double, double)>[
      for (final Segment segment in record.protein?.segments ?? <Segment>[])
        span(segment.start, segment.end),
    ];
    final List<int>? real = record.realIntronBp;
    final bool shortened =
        record.isIntronCompressed &&
        real != null &&
        real.length == exons.length - 1;

    final List<GenePiece> pieces = <GenePiece>[];
    double cursor = exons.isEmpty ? 0 : exons.first.$1;
    for (int i = 0; i < exons.length; i++) {
      final (double a, double b) = exons[i];
      // Where this exon starts at the gene's real scale.
      final double at = shortened ? cursor : a;
      final double shift = at - a;
      // Its coding part, then the untranslated ends round it.
      final List<(double, double)> parts = <(double, double)>[
        for (final (double c, double d) in coding)
          if (d > a && c < b) (math.max(a, c), math.min(b, d)),
      ]..sort(((double, double) x, (double, double) y) => x.$1.compareTo(y.$1));
      double edge = a;
      for (final (double c, double d) in parts) {
        if (c > edge) {
          pieces.add(
            GenePiece(start: edge + shift, end: c + shift, kind: GenePieceKind.utr),
          );
        }
        pieces.add(
          GenePiece(start: c + shift, end: d + shift, kind: GenePieceKind.cds),
        );
        edge = d;
      }
      if (b > edge) {
        pieces.add(
          GenePiece(start: edge + shift, end: b + shift, kind: GenePieceKind.utr),
        );
      }
      final double exonEnd = at + (b - a);
      if (i + 1 < exons.length) {
        final double intron = shortened
            ? real[i].toDouble()
            : exons[i + 1].$1 - b;
        pieces.add(
          GenePiece(
            start: exonEnd,
            end: exonEnd + intron,
            kind: GenePieceKind.intron,
          ),
        );
        cursor = exonEnd + intron;
      } else {
        cursor = exonEnd;
      }
    }
    final double whole = (record.realSpanBp ?? record.lengthBp).toDouble();
    return GeneLayout(
      pieces: List<GenePiece>.unmodifiable(pieces),
      length: math.max(whole, cursor),
    );
  }

  final List<GenePiece> pieces;

  /// The gene's real length, in base pairs.
  final double length;

  /// How many exons it has.
  int get exonCount {
    int count = 0;
    GenePieceKind? last;
    for (final GenePiece piece in pieces) {
      if (piece.kind != GenePieceKind.intron && last == GenePieceKind.intron) {
        count++;
      }
      last = piece.kind;
    }
    return pieces.isEmpty ? 0 : count + 1;
  }
}
