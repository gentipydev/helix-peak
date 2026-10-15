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

/// One RNA polymerase II on the gene at a moment.
@immutable
final class Polymerase {
  const Polymerase({
    required this.lane,
    required this.at,
    required this.shown,
    required this.rna,
  });

  /// Which of the polymerases it is.
  final int lane;

  /// Where it is, in base pairs from the gene's 5′ end: past the 3′ end
  /// while it runs on before it lets go.
  final double at;

  /// How much of it shows: it comes up as it loads at the start and goes
  /// as it runs on past the end.
  final double shown;

  /// Its nascent RNA, 5′ to 3′, the 3′ end at the polymerase: empty once
  /// the RNA has been cut free.
  final List<RnaStretch> rna;
}

/// An intron cut out as a lariat, drifting away.
@immutable
final class Lariat {
  const Lariat({
    required this.lane,
    required this.length,
    required this.age,
    required this.from,
    required this.along,
  });

  final int lane;

  /// Its bases.
  final double length;

  /// Seconds since it was cut free.
  final double age;

  /// Where its polymerase was when it was cut free, in base pairs from the
  /// gene's 5′ end.
  final double from;

  /// How far along its RNA from the polymerase it was cut out, in bases in
  /// line.
  final double along;
}

/// A finished mRNA, cut free at the poly(A) site, drifting away.
@immutable
final class Release {
  const Release({
    required this.lane,
    required this.rna,
    required this.age,
    required this.from,
  });

  final int lane;

  /// Where its polymerase was when it was cut free, in base pairs from the
  /// gene's 5′ end: at the 3′ end, or past it where its last intron was
  /// still coming out.
  final double from;

  /// Its exons, 5′ to 3′: every intron has been spliced out.
  final List<RnaStretch> rna;

  /// Seconds since it was cut free.
  final double age;
}

/// What the gene's transcription shows at a moment.
@immutable
final class TranscriptionFrame {
  const TranscriptionFrame(this.polymerases, this.lariats, this.releases);

  final List<Polymerase> polymerases;
  final List<Lariat> lariats;
  final List<Release> releases;
}

/// RNA polymerase II reading a gene, 5′ to 3′, one polymerase after
/// another, as a function of the clock alone.
///
/// Each polymerase loads at the gene's 5′ end and carries its nascent RNA
/// behind it: the exons it has passed, and the introns not yet spliced out.
/// Soon after an intron's 3′ end is read its two ends come together (it
/// loops out of line as its stretch of the RNA shortens) and it is cut free
/// as a lariat, its exons either side joined. The RNA is cut free at the
/// poly(A) site once its last intron is out, exons only, and leaves; the
/// polymerase runs on past the 3′ end meanwhile, and lets go. Splicing as
/// each intron is passed is what most introns do (Beyer and Osheim 1988;
/// dystrophin's, Tennyson et al. 1995).
///
/// The times are not the gene's own: every gene is read in [readSeconds],
/// where a polymerase takes about a minute over insulin and sixteen hours
/// over dystrophin, and every intron takes [spliceSeconds] to come out.
/// Nothing is cut at the clock's wrap: what a polymerase's last pass left
/// behind is still drawn as its next begins.
@immutable
final class Transcription {
  Transcription(this.layout) {
    final List<(double, double, double)> splices = <(double, double, double)>[];
    for (final GenePiece piece in layout.pieces) {
      if (piece.kind == GenePieceKind.intron) {
        final double start = piece.end / speed + spliceDelay;
        splices.add((start, start + spliceSeconds, piece.length));
      }
    }
    this.splices = List<(double, double, double)>.unmodifiable(splices);
    double cut = readSeconds;
    for (final (double _, double end, double _) in splices) {
      cut = math.max(cut, end);
    }
    this.cut = cut;
    _lariatAlong = List<double>.unmodifiable(<double>[
      for (int j = 0; j < splices.length; j++) _behind(j, splices[j].$2),
    ]);
    _mature = List<RnaStretch>.unmodifiable(_rnaAt(cut, mature: true));
    longest = _longest();
  }

  final GeneLayout layout;

  /// How many polymerases read the gene at once.
  static const int polymerases = 10;

  /// How long a polymerase's pass is, from loading at the 5′ end to letting
  /// go past the 3′ end, and so how often the gene's reading comes round.
  static const double passSeconds = 15;

  /// How long a polymerase takes from the gene's 5′ end to its 3′ end.
  static const double readSeconds = 13;

  /// How long a polymerase takes to come up as it loads at the 5′ end.
  static const double loadSeconds = 0.6;

  /// How long after an intron's 3′ end is read its splicing starts, and how
  /// long the intron takes to loop out of line and be cut free.
  static const double spliceDelay = 0.3;
  static const double spliceSeconds = 0.7;

  /// How long a polymerase takes to let go once its RNA is cut free.
  static const double letGoSeconds = 0.6;

  /// How long a lariat drifts before it is gone.
  static const double lariatSeconds = 1.4;

  /// How long a finished mRNA drifts before it is gone.
  static const double releaseSeconds = 2.2;

  /// Each intron's splicing: the seconds into a pass it starts and ends,
  /// and the intron's bases.
  @visibleForTesting
  late final List<(double, double, double)> splices;

  /// The seconds into a pass at which the RNA is cut free: once it is read
  /// to the poly(A) site and its last intron is out.
  @visibleForTesting
  late final double cut;

  /// How far along the RNA from the polymerase each intron is cut free.
  late final List<double> _lariatAlong;

  /// The finished mRNA: the exons, 5′ to 3′.
  late final List<RnaStretch> _mature;

  /// The most bases in line any polymerase carries over its pass.
  late final double longest;

  /// How far a polymerase goes a second, in base pairs.
  double get speed => layout.length / readSeconds;

  /// The nascent RNA [seconds] into a pass, 5′ to 3′; with [mature], the
  /// finished mRNA, every intron spliced out.
  List<RnaStretch> _rnaAt(double seconds, {bool mature = false}) {
    final double at = math.min(seconds * speed, layout.length);
    final List<RnaStretch> out = <RnaStretch>[];
    int intron = 0;
    for (final GenePiece piece in layout.pieces) {
      if (piece.start >= at) {
        break;
      }
      final double made = math.min(piece.end, at) - piece.start;
      if (piece.kind != GenePieceKind.intron) {
        if (made > 0) {
          out.add(RnaStretch(piece.kind, made));
        }
        continue;
      }
      final double spliced = _splicedAt(intron, seconds);
      intron++;
      if (mature || spliced >= 1) {
        continue;
      }
      out.add(
        RnaStretch(
          piece.kind,
          made * (1 - spliced),
          looped: spliced > 0 ? made * spliced : 0,
        ),
      );
    }
    return out;
  }

  /// How far intron [j] is spliced out [seconds] into a pass.
  double _splicedAt(int j, double seconds) {
    final (double start, double end, double _) = splices[j];
    return _smoothstep((seconds - start) / (end - start));
  }

  /// The bases in line behind intron [j], from its place to the polymerase,
  /// [seconds] into a pass.
  double _behind(int j, double seconds) {
    final double at = math.min(seconds * speed, layout.length);
    // The pieces after the intron's, as far as the polymerase has read.
    double behind = 0;
    int intron = 0;
    bool past = false;
    for (final GenePiece piece in layout.pieces) {
      if (piece.start >= at) {
        break;
      }
      if (piece.kind == GenePieceKind.intron) {
        final int k = intron++;
        if (k == j) {
          past = true;
          continue;
        }
        if (past) {
          behind +=
              (math.min(piece.end, at) - piece.start) *
              (1 - _splicedAt(k, seconds));
        }
      } else if (past) {
        behind += math.min(piece.end, at) - piece.start;
      }
    }
    return behind;
  }

  /// The RNA in line grows as a polymerase reads and shrinks only as an
  /// intron is spliced, so its most is as a piece is read to its end or
  /// within a splicing: those moments are looked at, with a sweep between.
  double _longest() {
    final List<double> at = <double>[
      for (int i = 0; i <= 400; i++) cut * i / 400,
      for (final GenePiece piece in layout.pieces) piece.end / speed,
      for (final (double start, double end, double _) in splices)
        for (int i = 0; i <= 16; i++) start + (end - start) * i / 16,
    ];
    double most = 0;
    for (final double t in at) {
      if (t > cut) {
        continue;
      }
      double inLine = 0;
      for (final RnaStretch s in _rnaAt(t)) {
        inLine += s.length;
      }
      most = math.max(most, inLine);
    }
    return most;
  }

  /// What shows [seconds] into the clock.
  TranscriptionFrame at(double seconds) {
    const double period = passSeconds;
    final List<Polymerase> reading = <Polymerase>[];
    final List<Lariat> lariats = <Lariat>[];
    final List<Release> releases = <Release>[];
    for (int lane = 0; lane < polymerases; lane++) {
      final double phase =
          ((seconds + _lead(lane) * period) % period + period) % period;
      final double shown =
          _smoothstep(phase / loadSeconds) *
          (1 - _smoothstep((phase - cut) / letGoSeconds));
      reading.add(
        Polymerase(
          lane: lane,
          at: phase * speed,
          shown: shown,
          rna: phase < cut ? _rnaAt(phase) : const <RnaStretch>[],
        ),
      );
      // This pass, and what the last one left behind.
      for (final double pass in <double>[phase, phase + period]) {
        for (int j = 0; j < splices.length; j++) {
          final double free = splices[j].$2;
          final double age = pass - free;
          if (age >= 0 && age < lariatSeconds) {
            lariats.add(
              Lariat(
                lane: lane,
                length: splices[j].$3,
                age: age,
                from: free * speed,
                along: _lariatAlong[j],
              ),
            );
          }
        }
        final double age = pass - cut;
        if (age >= 0 && age < releaseSeconds) {
          releases.add(
            Release(lane: lane, rna: _mature, age: age, from: cut * speed),
          );
        }
      }
    }
    return TranscriptionFrame(reading, lariats, releases);
  }

  /// How far into its pass [lane] is when the clock reads 0, as a share of
  /// a pass: one after another, but not like clockwork, so the gene does not
  /// look the same every few seconds. No two come nearer than 0.4 of the
  /// even spacing.
  static double _lead(int lane) =>
      (lane + 0.5 + 0.3 * math.sin(2.39996 * lane)) / polymerases;

  static double _smoothstep(double t) {
    final double x = t.clamp(0.0, 1.0);
    return x * x * (3 - 2 * x);
  }
}
