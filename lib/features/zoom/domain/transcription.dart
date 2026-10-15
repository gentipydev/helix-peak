import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'gene_layout.dart';

/// A stretch of an RNA, read 5′ to 3′: a piece of the gene as it was
/// transcribed, and, for an intron being spliced, how much of it has looped
/// out of line as its two ends come together.
@immutable
final class RnaStretch {
  const RnaStretch(this.kind, this.length, {this.looped = 0});

  final GenePieceKind kind;

  /// Bases of it in line along the RNA.
  final double length;

  /// Bases of it looped out at its place.
  final double looped;
}

/// One RNA polymerase II on the gene, and the RNA it has made.
@immutable
final class Polymerase {
  const Polymerase({required this.at, required this.rna});

  /// Where it is, in base pairs from the gene's 5′ end.
  final double at;

  /// Its nascent RNA, 5′ to 3′, the 3′ end at the polymerase.
  final List<RnaStretch> rna;

  /// The bases of its RNA in line.
  double get inLine =>
      rna.fold<double>(0, (double sum, RnaStretch s) => sum + s.length);
}

/// A gene being read, as one still: RNA polymerase II at three places on
/// it, each a stage of one reading, and the mRNA a reading makes (the
/// user's choice of 2026-10-16, over the loop of ten polymerases they had
/// found too busy).
///
/// On a gene being read, a place is a time: a polymerase near the 5′ end
/// has just begun, one near the 3′ end is nearly done, so one still tells
/// the whole reading from left to right, as an electron micrograph of a gene
/// being read does (Miller and Beatty 1969). One polymerase has just begun;
/// one has just read the 3′ end of the gene's longest intron, which is
/// looping out of its RNA, half spliced; the third stands in the widest
/// stretch left between them and the 3′ end. Each carries what it has read:
/// its exons, and its introns only until each is spliced out, soon after
/// its 3′ end is read, as most introns are (Beyer and Osheim 1988;
/// dystrophin's, Tennyson et al. 1995). The finished mRNA is the exons
/// alone, joined.
@immutable
final class Transcription {
  Transcription(this.layout) {
    final double length = layout.length;
    GenePiece? longestIntron;
    for (final GenePiece piece in layout.pieces) {
      // Of two as long, the later.
      if (piece.kind == GenePieceKind.intron &&
          (longestIntron == null || piece.length >= longestIntron.length)) {
        longestIntron = piece;
      }
    }
    _looping = longestIntron;
    // Where the one splicing stands: where its intron is half out, held at
    // the gene's 3′ end. A gene with no intron splices nothing, and its
    // last polymerase stands as far from the 3′ end as the first does from
    // the 5′.
    final double splicingAt = longestIntron == null
        ? (1 - begun) * length
        : math.min(
            longestIntron.end + (spliceAfter + spliceOver / 2) * length,
            length,
          );
    final List<double> at = <double>[
      if (splicingAt - begun * length >= apart * length) begun * length,
      splicingAt,
    ];
    // The third in the middle of the widest stretch left: between those
    // two, or from the last of them to the 3′ end.
    double from = at.last;
    double to = length;
    for (int i = 0; i + 1 < at.length; i++) {
      if (at[i + 1] - at[i] > to - from) {
        from = at[i];
        to = at[i + 1];
      }
    }
    at
      ..add((from + to) / 2)
      ..sort();
    polymerases = List<Polymerase>.unmodifiable(<Polymerase>[
      for (final double place in at)
        Polymerase(
          at: place,
          rna: List<RnaStretch>.unmodifiable(_rnaAt(place)),
        ),
    ]);
    splicing = at.indexOf(splicingAt);
    final List<RnaStretch> mrna = <RnaStretch>[];
    final List<double> junctions = <double>[];
    double made = 0;
    GenePieceKind? last;
    for (final GenePiece piece in layout.pieces) {
      if (piece.kind != GenePieceKind.intron) {
        if (last == GenePieceKind.intron) {
          junctions.add(made);
        }
        mrna.add(RnaStretch(piece.kind, piece.length));
        made += piece.length;
      }
      last = piece.kind;
    }
    this.mrna = List<RnaStretch>.unmodifiable(mrna);
    this.junctions = List<double>.unmodifiable(junctions);
    longest = polymerases.map((Polymerase p) => p.inLine).reduce(math.max);
  }

  final GeneLayout layout;

  /// How far past an intron's 3′ end a polymerase has read when the intron
  /// starts to loop out of its RNA, and how much further when it is out, as
  /// shares of the gene's length: the 0.3 s and the 0.7 s of the 13 s each
  /// polymerase took over the gene when its reading moved.
  static const double spliceAfter = 0.3 / 13;
  static const double spliceOver = 0.7 / 13;

  /// Where the polymerase that has just begun stands, as a share of the
  /// gene from its 5′ end.
  static const double begun = 0.12;

  /// The least room between two polymerases, as a share of the gene: the
  /// one that has just begun is left out where it would stand nearer.
  static const double apart = 0.12;

  /// The intron being spliced: the gene's longest, its loop the biggest
  /// there is to see.
  late final GenePiece? _looping;

  /// The polymerases, 5′ to 3′.
  late final List<Polymerase> polymerases;

  /// Which of [polymerases] is splicing out the gene's longest intron.
  late final int splicing;

  /// The finished mRNA: the exons, 5′ to 3′, every intron spliced out.
  late final List<RnaStretch> mrna;

  /// Where one exon meets the next along [mrna], in bases from its 5′ end.
  late final List<double> junctions;

  /// The most bases in line any polymerase carries.
  late final double longest;

  /// How far [intron] is spliced out of the RNA of a polymerase at [at]:
  /// from none to all of it, smoothly, over its stretch of the reading.
  double splicedAt(GenePiece intron, double at) {
    final double past = at - intron.end - spliceAfter * layout.length;
    final double x = (past / (spliceOver * layout.length)).clamp(0.0, 1.0);
    return x * x * (3 - 2 * x);
  }

  /// The RNA of a polymerase at [at], 5′ to 3′: the exons it has read, and
  /// each intron in line until it is half spliced out; but the intron being
  /// spliced, which loops out as it goes.
  List<RnaStretch> _rnaAt(double at) {
    final List<RnaStretch> out = <RnaStretch>[];
    for (final GenePiece piece in layout.pieces) {
      if (piece.start >= at) {
        break;
      }
      final double made = math.min(piece.end, at) - piece.start;
      if (piece.kind != GenePieceKind.intron) {
        out.add(RnaStretch(piece.kind, made));
        continue;
      }
      final double spliced = splicedAt(piece, at);
      if (identical(piece, _looping) && spliced > 0 && spliced < 1) {
        out.add(
          RnaStretch(piece.kind, made * (1 - spliced), looped: made * spliced),
        );
      } else if (spliced < 0.5) {
        out.add(RnaStretch(piece.kind, made));
      }
    }
    return out;
  }
}
