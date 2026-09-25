import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../../../core/network/track_source.dart';
import 'gene_record.dart';
import 'protein_target.dart';
import 'protein_track.dart';

/// How a base's strongest substitution reads against every other SNV in the
/// genome. The boundaries are AlphaGenome's own calibration, not this app's
/// taste: Phred 20 is the top 1% of genome-wide SNVs and 10 the top 10%, so a
/// bucket here means the same thing it means on the Atlas.
enum ImpactLevel {
  high('high impact'),
  middle('moderate impact'),
  low('low impact');

  const ImpactLevel(this.label);
  final String label;
}

@immutable
final class AltScore {
  const AltScore(this.base, this.phred);

  /// The alternative base, read on the transcript's strand — the strand whose
  /// letters the page draws, which for a gene on the minus strand is not the
  /// strand the Atlas filed the score against. The bake did that complement.
  final String base;

  /// Calibrated Phred: `-10 log10(1 - quantile)`. Higher is more impact.
  final double phred;

  /// One scale for every base, and a fixed one, so two positions can be
  /// compared by eye. 40 is the top 0.01% of genome-wide SNVs; past that the
  /// bar is full and the number carries the rest.
  double get barFraction =>
      phred.clamp(0.0, GeneImpact.barCeiling) / GeneImpact.barCeiling;
}

/// What one base of the gene record answers with.
@immutable
final class BaseImpact {
  const BaseImpact({
    required this.position,
    required this.genomic,
    required this.wildtype,
    required this.ranked,
    this.estimatedFrom,
    this.distance = 0,
  });

  /// The record-local position, which is what every page taps with.
  final int position;

  /// The GRCh38 coordinate the score was measured at.
  final int genomic;

  final String wildtype;

  /// The three substitutions, strongest first; a tie goes to the earlier base.
  final List<AltScore> ranked;

  /// Where the score actually came from, where this base has none of its own,
  /// or null for an exact hit. Every shipped track scores every drawn base, so
  /// this is the state for a gap in the model's coverage rather than a routine
  /// one — but it is drawn differently rather than hidden, because a number
  /// borrowed from a neighbour is not the same claim as a measured one.
  final int? estimatedFrom;

  /// How far away that neighbour was, in record bases. Zero for an exact hit.
  final int distance;

  bool get estimated => estimatedFrom != null;

  /// The strongest of the three, which is what the bucket reads.
  double get peak => ranked.first.phred;

  ImpactLevel get level => peak >= GeneImpact.highPhred
      ? ImpactLevel.high
      : peak >= GeneImpact.middlePhred
      ? ImpactLevel.middle
      : ImpactLevel.low;

  /// The share of genome-wide SNVs scoring at least this high, as a percentage:
  /// the Atlas's own `10^(-Phred/10) x 100%`. Phred 30 reads as 0.1%.
  double get topPercentile => math.pow(10, -peak / 10) * 100;
}

/// What a whole feature — an exon, an intron — scores, for the gene page, where
/// a cell is two points wide and a tap means the run rather than the base.
@immutable
final class ImpactSummary {
  const ImpactSummary({
    required this.median,
    required this.peak,
    required this.peakPosition,
    required this.scored,
  });

  final double median;
  final double peak;

  /// The record-local position the peak sits at.
  final int peakPosition;

  /// How many of the run's bases carried a score.
  final int scored;
}

/// A baked AlphaGenome Variant Impact track, one gene's worth.
///
/// Filed under the record-local coordinate every page already holds, so the
/// gene, mRNA and opened-DNA pages all read it without converting anything. The
/// GRCh38 coordinate each score was measured at is carried alongside, in [runs],
/// because it is the only place the app can say where on the chromosome it is.
@immutable
final class GeneImpact {
  const GeneImpact._(
    this.target,
    this.gene,
    this.chromosome,
    this.transcript,
    this.orientation,
    this.complemented,
    this.start,
    this.sequence,
    this._keys,
    this._scores,
    this._runs,
  );

  /// The top 0.01% of genome-wide SNVs, and the top of every bar.
  static const double barCeiling = 40;

  /// The top 1% and the top 10%. The bake writes the same two numbers into the
  /// asset header and `fromJson` refuses a track that disagrees, so a retuned
  /// bucket cannot be half-applied.
  static const double highPhred = 20;
  static const double middlePhred = 10;

  static const String bases = 'ACGT';

  final String gene;
  final ProteinTarget target;

  bool matchesRecord(GeneRecord record) {
    if (gene != record.gene ||
        start != record.start ||
        sequence.length != record.sequence.length) {
      return false;
    }
    if (record.strand != -1) return sequence == record.sequence;
    // Avoid allocating a reversed sequence on every sheet animation frame.
    for (int i = 0; i < sequence.length; i++) {
      if (sequence.codeUnitAt(i) !=
          record.sequence.codeUnitAt(sequence.length - 1 - i)) {
        return false;
      }
    }
    return true;
  }

  final String chromosome;
  final String transcript;

  /// +1 where the record's coordinates count the same way as the chromosome's,
  /// -1 where they count against it. Provenance only: [genomicOf] carries the
  /// direction per run, because a gene with shortened introns has gaps rather
  /// than one slope.
  final int orientation;

  /// Whether the letters here are the complement of the chromosome's plus
  /// strand — true for a gene on the minus strand. A separate fact from
  /// [orientation], which is what makes it worth writing down: a minus-strand
  /// record of a minus-strand gene counts up with the chromosome and still
  /// reads the other strand. Provenance only; the bake already did the
  /// complement, so every score and letter here is on the transcript's strand.
  final bool complemented;

  /// The record-local position of the first drawn base.
  final int start;

  /// The gene record's drawn letters in increasing record position, which the
  /// scored bases are checked against the way a constraint track is checked
  /// against its protein. On a minus-strand record that is the record's own
  /// `sequence` reversed, since the record stores its letters from the far end.
  final String sequence;

  final Int32List _keys;
  final Float32List _scores;
  final List<ImpactRun> _runs;

  /// How many bases carry a score.
  int get length => _keys.length;

  /// Read as bytes and parsed off the UI isolate, the way a ClinVar snapshot
  /// already is.
  ///
  /// This parsed on the thread drawing the walk until Phase 4a. The small
  /// bundled tracks hid it; the family runs to 628 KB for dystrophin and builds
  /// three typed arrays and a run table on the way past, which is a stutter
  /// exactly where the reader is swiping between nucleotide pages.
  static Future<GeneImpact> load(
    ProteinTarget target, {
    required TrackSource tracks,
  }) async => compute(
    _decode,
    (await tracks.read(target.slug, TrackKind.impact), target),
  );

  static GeneImpact _decode((Uint8List, ProteinTarget) payload) {
    final (Uint8List bytes, ProteinTarget target) = payload;
    final Object? json = jsonDecode(utf8.decode(bytes));
    if (json is! Map<String, dynamic>) {
      throw FormatException('Malformed impact track for ${target.slug}');
    }
    return GeneImpact.fromJson(json, target);
  }

  /// Parses one baked track, refusing anything it cannot vouch for.
  ///
  /// The header is checked as strictly as the constraint track's is, and for the
  /// same reason: a score from a different scorer, a different assembly or a
  /// different annotation build is not comparable with one from this one, and a
  /// page that mixed them would be quietly lying.
  factory GeneImpact.fromJson(Map<String, dynamic> json, ProteinTarget target) {
    if (json['gene'] != target.gene ||
        json['uniprot'] != target.uniprot ||
        json['accession'] != target.accession ||
        json['assembly'] != 'GRCh38' ||
        json['annotation'] != 'GENCODE v46' ||
        json['scorer'] != 'AVI_SCORE' ||
        json['score_units'] != 'phred' ||
        json['alt_order'] != 'ACGT minus wildtype' ||
        (json['high_phred'] as num).toDouble() != highPhred ||
        (json['middle_phred'] as num).toDouble() != middlePhred) {
      throw FormatException('Unsupported impact asset for ${target.slug}');
    }

    final String sequence = json['sequence'] as String;
    final int start = (json['start'] as num).toInt();
    final int orientation = (json['orientation'] as num).toInt();
    final Object? complemented = json['complemented'];
    if (sequence.isEmpty ||
        (orientation != 1 && orientation != -1) ||
        complemented is! bool) {
      throw FormatException('Incomplete impact track for ${target.slug}');
    }

    final List<ImpactRun> runs = <ImpactRun>[
      for (final dynamic r in json['runs'] as List<dynamic>)
        ImpactRun(
          local: ((r as Map<String, dynamic>)['local'] as num).toInt(),
          genomic: (r['genomic'] as num).toInt(),
          step: (r['step'] as num).toInt(),
          length: (r['length'] as num).toInt(),
        ),
    ];
    final int covered = runs.fold(0, (int sum, ImpactRun r) => sum + r.length);
    if (runs.isEmpty || covered != sequence.length) {
      throw FormatException(
        'The coordinate map covers $covered of ${sequence.length} bases '
        'for ${target.slug}',
      );
    }

    final Map<String, dynamic> raw = json['positions'] as Map<String, dynamic>;
    final List<int> ordered = raw.keys.map(int.parse).toList()..sort();
    final Int32List keys = Int32List(ordered.length);
    final Float32List scores = Float32List(ordered.length * 3);
    for (int i = 0; i < ordered.length; i++) {
      final int local = ordered[i];
      final int offset = local - start;
      if (offset < 0 || offset >= sequence.length) {
        throw FormatException('Score outside the record at $local');
      }
      final List<dynamic> values = raw['$local'] as List<dynamic>;
      if (values.length != 3) {
        throw FormatException('Expected three substitutions at $local');
      }
      keys[i] = local;
      for (int a = 0; a < 3; a++) {
        final num value = values[a] as num;
        if (!value.isFinite || value < 0) {
          throw FormatException('Invalid score at $local');
        }
        scores[i * 3 + a] = value.toDouble();
      }
    }

    return GeneImpact._(
      target,
      target.gene,
      json['chromosome'] as String,
      json['transcript'] as String,
      orientation,
      complemented,
      start,
      sequence,
      keys,
      scores,
      List<ImpactRun>.unmodifiable(runs),
    );
  }

  /// The letter drawn at a record-local position, or null outside the record.
  String? baseAt(int position) {
    final int offset = position - start;
    if (offset < 0 || offset >= sequence.length) {
      return null;
    }
    return sequence[offset];
  }

  /// The GRCh38 coordinate of a record-local position, or null outside the map.
  int? genomicOf(int position) {
    int low = 0;
    int high = _runs.length - 1;
    while (low <= high) {
      final int mid = (low + high) >> 1;
      final ImpactRun run = _runs[mid];
      if (position < run.local) {
        high = mid - 1;
      } else if (position >= run.local + run.length) {
        low = mid + 1;
      } else {
        return run.genomic + run.step * (position - run.local);
      }
    }
    return null;
  }

  /// What a base answers with: its own three scores, or the nearest scored
  /// base's, said so.
  ///
  /// Null only where the position is outside the record altogether, which is
  /// what a tap on empty canvas gives.
  BaseImpact? at(int position) {
    final String? wildtype = baseAt(position);
    final int? genomic = genomicOf(position);
    if (wildtype == null || genomic == null || _keys.isEmpty) {
      return null;
    }
    final int index = _nearest(position);
    final int found = _keys[index];
    if (found == position) {
      return BaseImpact(
        position: position,
        genomic: genomic,
        wildtype: wildtype,
        ranked: _rankedAt(index, wildtype),
      );
    }
    // Borrowed. The neighbour's own wildtype is what its three scores were
    // measured against, so they are read under that letter and not this one.
    final String borrowed = baseAt(found) ?? wildtype;
    return BaseImpact(
      position: position,
      genomic: genomic,
      wildtype: wildtype,
      ranked: _rankedAt(index, borrowed),
      estimatedFrom: found,
      distance: (found - position).abs(),
    );
  }

  /// Median, peak and where the peak is, over a closed run of record positions.
  /// Null where nothing in the run carries a score.
  ImpactSummary? summaryOf(int first, int last) {
    final int low = first <= last ? first : last;
    final int high = first <= last ? last : first;
    final List<double> peaks = <double>[];
    double best = -1;
    int bestAt = low;
    for (int i = _atLeast(low); i < _keys.length && _keys[i] <= high; i++) {
      double peak = _scores[i * 3];
      for (int a = 1; a < 3; a++) {
        final double value = _scores[i * 3 + a];
        if (value > peak) {
          peak = value;
        }
      }
      peaks.add(peak);
      if (peak > best) {
        best = peak;
        bestAt = _keys[i];
      }
    }
    if (peaks.isEmpty) {
      return null;
    }
    peaks.sort();
    final int middle = peaks.length ~/ 2;
    return ImpactSummary(
      median: peaks.length.isOdd
          ? peaks[middle]
          : (peaks[middle - 1] + peaks[middle]) / 2,
      peak: best,
      peakPosition: bestAt,
      scored: peaks.length,
    );
  }

  List<AltScore> _rankedAt(int index, String wildtype) {
    final List<AltScore> ranked = <AltScore>[];
    int slot = 0;
    for (int b = 0; b < bases.length; b++) {
      final String base = bases[b];
      if (base == wildtype) {
        continue;
      }
      // A borrowed row can run out of slots if the neighbour's wildtype is not
      // in ACGT, which an N would be; the row is three long either way.
      if (slot > 2) {
        break;
      }
      ranked.add(AltScore(base, _scores[index * 3 + slot]));
      slot++;
    }
    ranked.sort((AltScore a, AltScore b) {
      final int byScore = b.phred.compareTo(a.phred);
      return byScore == 0 ? a.base.compareTo(b.base) : byScore;
    });
    return List<AltScore>.unmodifiable(ranked);
  }

  /// The first index whose key is at least [position].
  int _atLeast(int position) {
    int low = 0;
    int high = _keys.length;
    while (low < high) {
      final int mid = (low + high) >> 1;
      if (_keys[mid] < position) {
        low = mid + 1;
      } else {
        high = mid;
      }
    }
    return low;
  }

  /// The index of the scored position closest to [position]. A tie goes to the
  /// earlier one, so the answer does not depend on which side it is asked from.
  int _nearest(int position) {
    final int at = _atLeast(position);
    if (at == 0) {
      return 0;
    }
    if (at >= _keys.length) {
      return _keys.length - 1;
    }
    final int before = position - _keys[at - 1];
    final int after = _keys[at] - position;
    return after < before ? at : at - 1;
  }
}

/// A stretch where the record's coordinate and the chromosome's both step by
/// one. An uncompressed gene is a single run; a gene whose introns were
/// shortened is one run per exon, because each shortened intron leaves a gap.
@immutable
final class ImpactRun {
  const ImpactRun({
    required this.local,
    required this.genomic,
    required this.step,
    required this.length,
  });

  final int local;
  final int genomic;

  /// +1 where the chromosome counts up with the record, -1 where it counts down.
  final int step;

  final int length;
}
