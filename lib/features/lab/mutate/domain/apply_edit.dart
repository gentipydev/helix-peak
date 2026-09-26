import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../../../core/biology/gene_record.dart';
import '../../../../core/biology/genetic_code.dart';

// ------------------------------------------------------------------- edits

/// One change to a record's bases.
///
/// [position] is a record position: the numbers the record's own segments
/// use, 1-based and inclusive. Bases are written as the gene page draws them,
/// on the gene's own strand. A minus-strand record's `sequence` is already
/// that strand (R2.1), so an edit is never complemented, here or by a caller.
///
/// An edit that covers more than one base runs the way the gene is read,
/// 5' to 3'. On a minus-strand record that is down the coordinates.
sealed class SequenceEdit {
  const SequenceEdit(this.position);

  final int position;
}

/// The base at [position] becomes [newBase].
final class Substitution extends SequenceEdit {
  const Substitution(super.position, this.newBase);

  final String newBase;
}

/// [bases] go in immediately 5' of the base at [position]: reading the gene,
/// they come just before it.
final class Insertion extends SequenceEdit {
  const Insertion(super.position, this.bases);

  final String bases;
}

/// [length] bases go, from [position] itself onwards, 5' to 3'.
final class Deletion extends SequenceEdit {
  const Deletion(super.position, this.length);

  final int length;
}

// ---------------------------------------------------------------- outcomes

/// How far upstream of the last exon-exon junction a premature stop has to
/// sit for nonsense-mediated decay to destroy the mRNA, in bases, counted
/// from the stop codon's first base.
///
/// The junction itself is never a constant: it is read off each record's own
/// exon table, after the edit.
const int nmdThresholdBp = 55;

/// What an edit does to the gene's product.
enum EditOutcomeKind {
  /// Every residue is what it was.
  synonymous,

  /// One residue becomes another. The start codon counts: the reading starts
  /// where the record's coding sequence starts, and no other start is sought.
  missense,

  /// A stop codon arrives early, and the protein ends there.
  nonsense,

  /// An indel that is not a whole number of codons, so every codon after it
  /// is read in a new frame.
  frameshift,

  /// Whole codons gained or lost without leaving the frame. Not a missense:
  /// residues are added or taken away, not swapped for others.
  inFrameIndel,

  /// The stop codon is lost, and translation reads on into the 3' UTR.
  stopLoss,

  /// An intron no longer starts and ends with a pair R2.3 accepts.
  spliceSite,

  /// Inside an intron, leaving its splice sites as they were.
  intronic,

  /// In an exon, outside the coding sequence.
  utr,

  /// A premature stop more than [nmdThresholdBp] bases upstream of the last
  /// exon-exon junction. Nonsense-mediated decay destroys the mRNA, so the
  /// short protein is never made.
  mrnaDegraded,
}

@immutable
final class EditOutcome {
  const EditOutcome(
    this.kind, {
    this.codonIndex,
    this.oldResidue,
    this.newResidue,
    this.newStopPosition,
  });

  final EditOutcomeKind kind;

  /// The codon the edit changes, counted from 1 at the start codon.
  ///
  /// It is the first residue that differs, so a frameshift names where the
  /// protein first goes wrong rather than where the edit sits. For a
  /// synonymous edit it is the codon the edit falls in. Null where the edit
  /// misses the coding sequence, and at a splice site, where the whole
  /// transcript is in question rather than one codon.
  final int? codonIndex;

  /// The residue at [codonIndex] before the edit: one letter, `*` for a stop.
  final String? oldResidue;

  /// The residue at [codonIndex] after the edit, or null where the edited
  /// reading has already run off the end of the mRNA.
  final String? newResidue;

  /// The first base of the stop codon the edit brings in, as a position in
  /// the edited record.
  ///
  /// Set for a nonsense, frameshift, stop-loss or degraded outcome. Null for
  /// a frameshift or stop loss whose reading runs off the end of the mRNA
  /// without meeting a stop.
  final int? newStopPosition;

  @override
  String toString() =>
      'EditOutcome(${kind.name}, codon $codonIndex, '
      '$oldResidue>$newResidue, stop at $newStopPosition)';
}

/// [record] with [edit] made, and everything read off its bases read again.
///
/// Segments move with the bases they hold. The coding sequence is then read
/// afresh from its start codon along the edited mRNA to the first stop, and
/// the protein and every peptide cut from it are taken from that reading,
/// never patched from the strings the record came with. A peptide keeps the
/// residues whose codons begin inside it; one the edited protein no longer
/// reaches is gone.
///
/// An edit that touches a base [EditEligibility] rules out is refused with an
/// [ArgumentError] carrying [Ineligible.reason], never made quietly.
GeneRecord applyEdit(GeneRecord record, SequenceEdit edit) =>
    _Edited(record, edit).record;

/// What [edit] does to [record]'s product. Refuses what [applyEdit] refuses.
EditOutcome classify(GeneRecord record, SequenceEdit edit) =>
    _Edited(record, edit).outcome;

// ------------------------------------------------------------- eligibility

/// Whether a record position can be edited at all.
///
/// DMD, APP and CFTR arrive with their introns shortened (R2.4): each keeps
/// its own first and last bases and loses its middle. A drawn base there is
/// real, but the record does not say where the middle was cut out, so its
/// neighbours cannot be taken as contiguous with it and no base of the intron
/// can be placed on the chromosome (R2.5). An edit there would be to no real
/// sequence. Exons are never shortened, so they stay editable in every record.
///
/// An edit touches the bases it replaces or removes; an insertion touches the
/// base it goes in front of.
sealed class EditEligibility {
  const EditEligibility();

  factory EditEligibility.of(GeneRecord record, int position) {
    RangeError.checkValueInInterval(
      position,
      record.start,
      record.end,
      'position',
    );
    final int offset = _Axis.of(record).offset(position);
    return _shortenedIntrons(record)
            .any((_Span intron) => intron.from <= offset && offset <= intron.to)
        ? const Ineligible(_shortenedReason)
        : const Eligible();
  }
}

final class Eligible extends EditEligibility {
  const Eligible();
}

final class Ineligible extends EditEligibility {
  const Ineligible(this.reason);

  /// One sentence, ready to show as it is, like a refused track's reason.
  final String reason;
}

// --------------------------------------------------------------- internals

/// An inclusive run of offsets into a record's `sequence`.
typedef _Span = ({int from, int to});

/// Accepted splice-site pairs, donor then acceptor (R2.3).
const Set<String> _spliceSites = <String>{'GT-AG', 'GC-AG', 'AT-AC'};

final RegExp _bases = RegExp(r'^[ACGT]+$');

/// Record positions against offsets into `sequence`.
///
/// Offsets count the way the gene is read, on either strand: a minus-strand
/// record's `sequence` runs from [end] down (R2.1). Everything past this class
/// works in offsets, where 5' to 3' is always upwards, so a minus-strand
/// record needs no case of its own.
final class _Axis {
  const _Axis(this.start, this.end, {required this.minus});

  _Axis.of(GeneRecord record)
    : this(record.start, record.end, minus: record.strand == -1);

  final int start;
  final int end;
  final bool minus;

  int offset(int position) => minus ? end - position : position - start;

  int position(int offset) => minus ? end - offset : start + offset;

  _Span span(Segment segment) => minus
      ? (from: end - segment.end, to: end - segment.start)
      : (from: segment.start - start, to: segment.end - start);

  Segment segment(_Span span) => minus
      ? Segment(start: end - span.to, end: end - span.from)
      : Segment(start: start + span.from, end: start + span.to);
}

/// An edit as offsets: [removed] bases go from [at], and [inserted] takes
/// their place.
final class _Change {
  const _Change(this.at, this.removed, this.inserted);

  factory _Change.of(GeneRecord record, SequenceEdit edit) {
    RangeError.checkValueInInterval(
      edit.position,
      record.start,
      record.end,
      'position',
    );
    final int at = _Axis.of(record).offset(edit.position);
    final _Change change = switch (edit) {
      Substitution(:final String newBase) => _Change(
        at,
        1,
        _checked(newBase, 'newBase', single: true),
      ),
      Insertion(:final String bases) => _Change(
        at,
        0,
        _checked(bases, 'bases'),
      ),
      Deletion(:final int length) => _Change(
        at,
        RangeError.checkValueInInterval(
          length,
          1,
          record.sequence.length - at,
          'length',
        ),
        '',
      ),
    };
    final int last = at + math.max<int>(change.removed, 1) - 1;
    if (_shortenedIntrons(record)
        .any((_Span intron) => intron.from <= last && at <= intron.to)) {
      throw ArgumentError.value(edit.position, 'position', _shortenedReason);
    }
    return change;
  }

  final int at;
  final int removed;
  final String inserted;

  int get delta => inserted.length - removed;

  String apply(String sequence) =>
      sequence.replaceRange(at, at + removed, inserted);

  /// Where [span] ends up, or null when every base of it is removed.
  ///
  /// A substitution moves nothing. Inserted bases join a span only when they
  /// go in strictly inside it. At a boundary they fall outside, so bases
  /// inserted just before an exon's first base lengthen the intron, and its
  /// acceptor is then whatever they end in.
  _Span? move(_Span span) {
    if (removed == inserted.length) {
      return span;
    }
    if (removed == 0) {
      final int n = inserted.length;
      if (at <= span.from) {
        return (from: span.from + n, to: span.to + n);
      }
      return at <= span.to ? (from: span.from, to: span.to + n) : span;
    }
    final int last = at + removed - 1;
    final int from = span.from >= at && span.from <= last
        ? last + 1
        : span.from;
    final int to = span.to >= at && span.to <= last ? at - 1 : span.to;
    if (from > to) {
      return null;
    }
    int shift(int offset) => offset > last ? offset - removed : offset;
    return (from: shift(from), to: shift(to));
  }

  static String _checked(String bases, String name, {bool single = false}) {
    if (!_bases.hasMatch(bases) || (single && bases.length != 1)) {
      throw ArgumentError.value(
        bases,
        name,
        single ? 'must be one of A, C, G and T' : 'must be only A, C, G and T',
      );
    }
    return bases;
  }
}

/// A record's mRNA, and the protein read off it.
final class _Reading {
  const _Reading._(
    this.sequence,
    this.exons,
    this.bases,
    this.place,
    this.start,
    this.codons,
  );

  /// [cdsStart] is the offset of the coding sequence's first base. When an
  /// edit took that base away, the reading starts at the next one the mRNA
  /// still holds.
  factory _Reading(String sequence, List<_Span> exons, int? cdsStart) {
    final List<_Span> ordered = List<_Span>.of(exons)
      ..sort((_Span a, _Span b) => a.from.compareTo(b.from));
    final List<int> bases = <int>[
      for (final _Span exon in ordered)
        for (int offset = exon.from; offset <= exon.to; offset++) offset,
    ];
    final Int32List place = Int32List(sequence.length)
      ..fillRange(0, sequence.length, -1);
    for (int i = 0; i < bases.length; i++) {
      place[bases[i]] = i;
    }

    final int? first = cdsStart == null ? null : _lowerBound(bases, cdsStart);
    final int? start = first != null && first < bases.length ? first : null;
    final StringBuffer codons = StringBuffer();
    if (start != null) {
      for (int i = start; i + 2 < bases.length; i += 3) {
        final String residue =
            GeneticCode.translate(
              sequence[bases[i]] +
                  sequence[bases[i + 1]] +
                  sequence[bases[i + 2]],
            ) ??
            'X';
        codons.write(residue);
        if (residue == '*') {
          break;
        }
      }
    }
    return _Reading._(
      sequence,
      ordered,
      bases,
      place,
      start,
      codons.toString(),
    );
  }

  final String sequence;

  /// The exons as offsets, 5' to 3'.
  final List<_Span> exons;

  /// The mRNA: the `sequence` offset of each of its bases, 5' to 3'.
  final List<int> bases;

  /// Each offset's place in [bases], or -1 for a base no exon holds.
  final Int32List place;

  /// Where in [bases] the start codon begins; null with no coding sequence.
  final int? start;

  /// One letter per codon read, ending in `*` where a stop codon ended it.
  final String codons;

  bool get stopped => codons.endsWith('*');

  String get protein =>
      stopped ? codons.substring(0, codons.length - 1) : codons;

  /// Where in [bases] the stop codon begins, or null when the reading ran off
  /// the end of the mRNA.
  int? get stop => stopped ? start! + 3 * (codons.length - 1) : null;

  /// The last place in [bases] the reading covers, stop codon included.
  int get cdsEnd => start! + 3 * codons.length - 1;

  /// How many introns do not start and end with a pair R2.3 accepts.
  int get unspliceable {
    int count = 0;
    for (int i = 0; i + 1 < exons.length; i++) {
      final int from = exons[i].to + 1;
      final int to = exons[i + 1].from - 1;
      if (to < from) {
        // The whole intron is gone, and the two exons simply meet.
        continue;
      }
      final bool spliceable =
          to - from >= 3 &&
          _spliceSites.contains(
            '${sequence.substring(from, from + 2)}-'
            '${sequence.substring(to - 1, to + 1)}',
          );
      if (!spliceable) {
        count++;
      }
    }
    return count;
  }

  /// Places [from] to [to] of the mRNA as offsets, one span per exon crossed.
  List<_Span> spansOf(int from, int to) {
    final List<_Span> spans = <_Span>[];
    int first = from;
    for (int i = from + 1; i <= to + 1; i++) {
      if (i > to || bases[i] != bases[i - 1] + 1) {
        spans.add((from: bases[first], to: bases[i - 1]));
        first = i;
      }
    }
    return spans;
  }

  /// The residues whose codons begin inside [spans], and those codons' bases.
  ({List<_Span> spans, String residues})? peptide(List<_Span> spans) {
    final int? start = this.start;
    if (start == null) {
      return null;
    }
    final String residues = protein;
    int? first;
    int last = -1;
    for (int c = 0; c < residues.length; c++) {
      final int offset = bases[start + 3 * c];
      if (spans.any((_Span s) => s.from <= offset && offset <= s.to)) {
        first ??= c;
        last = c;
      }
    }
    if (first == null) {
      return null;
    }
    return (
      spans: spansOf(start + 3 * first, start + 3 * last + 2),
      residues: residues.substring(first, last + 1),
    );
  }
}

/// One edit made to one record: the edited record, and the readings before
/// and after that [outcome] compares.
final class _Edited {
  const _Edited._(this.record, this.change, this.axis, this.old, this.now);

  factory _Edited(GeneRecord record, SequenceEdit edit) {
    final _Change change = _Change.of(record, edit);
    final _Axis from = _Axis.of(record);
    final String sequence = change.apply(record.sequence);
    final _Axis to = _Axis(
      record.start,
      record.start + sequence.length - 1,
      minus: from.minus,
    );

    List<_Span> moved(List<Segment> segments) => <_Span>[
      for (final Segment segment in segments)
        if (change.move(from.span(segment)) case final _Span span) span,
    ];
    List<Segment> placed(List<_Span> spans) => <Segment>[
      for (final _Span span in spans) to.segment(span),
    ];

    final _Reading old = _Reading(
      record.sequence,
      <_Span>[
        for (final Segment segment in _exonsOf(
          record.transcript,
          record.exons,
          Segment(start: record.start, end: record.end),
        ))
          from.span(segment),
      ],
      _firstOffset(<_Span>[
        for (final Segment segment
            in record.protein?.segments ?? const <Segment>[])
          from.span(segment),
      ]),
    );

    final Transcript? transcript = record.transcript == null
        ? null
        : Transcript(segments: placed(moved(record.transcript!.segments)));
    final List<Exon> exons = <Exon>[
      for (final Exon exon in record.exons)
        if (change.move(from.span(Segment(start: exon.start, end: exon.end)))
            case final _Span span)
          _renumbered(exon, to.segment(span)),
    ];
    final _Reading now = _Reading(sequence, <_Span>[
      for (final Segment segment in _exonsOf(
        transcript,
        exons,
        Segment(start: to.start, end: to.end),
      ))
        to.span(segment),
    ], _firstOffset(moved(record.protein?.segments ?? const <Segment>[])));

    final int? start = now.start;
    final Protein? protein = record.protein == null || start == null
        ? null
        : Protein(
            product: record.protein!.product,
            translation: now.protein,
            segments: placed(now.spansOf(start, now.cdsEnd)),
          );
    Peptide? reread(Peptide? peptide) {
      if (peptide == null) {
        return null;
      }
      final ({List<_Span> spans, String residues})? read = now.peptide(
        moved(peptide.segments),
      );
      return read == null
          ? null
          : Peptide(
              product: peptide.product,
              segments: placed(read.spans),
              translation: read.residues,
            );
    }

    final GeneRecord edited = GeneRecord(
      gene: record.gene,
      start: record.start,
      end: to.end,
      strand: record.strand,
      sequence: sequence,
      transcript: transcript,
      protein: protein,
      exons: exons,
      signalPeptide: reread(record.signalPeptide),
      proprotein: reread(record.proprotein),
      peptides: <Peptide>[
        for (final Peptide chain in record.peptides)
          if (reread(chain) case final Peptide kept) kept,
      ],
      intronScale: record.intronScale,
      realSpanBp: record.realSpanBp == null
          ? null
          : record.realSpanBp! + change.delta,
      realIntronBp: _realIntrons(record.realIntronBp, old.exons, change),
    );
    return _Edited._(edited, change, to, old, now);
  }

  /// The edited record.
  final GeneRecord record;
  final _Change change;

  /// The edited record's axis.
  final _Axis axis;
  final _Reading old;
  final _Reading now;

  /// Settled in order: splicing first, since a broken site puts the whole
  /// transcript in doubt; then whether the edit reaches the coding sequence;
  /// then what the codons read.
  EditOutcome get outcome {
    if (now.unspliceable > old.unspliceable) {
      return const EditOutcome(EditOutcomeKind.spliceSite);
    }
    final (int, int)? touched = _touched;
    if (touched == null) {
      return const EditOutcome(EditOutcomeKind.intronic);
    }
    final int? start = old.start;
    if (start == null || touched.$2 < start || touched.$1 > old.cdsEnd) {
      return const EditOutcome(EditOutcomeKind.utr);
    }

    final String was = old.codons;
    final String reads = now.codons;
    int k = 0;
    while (k < was.length && k < reads.length && was[k] == reads[k]) {
      k++;
    }
    if (k == was.length && k == reads.length) {
      final int codon = (math.max(touched.$1, start) - start) ~/ 3;
      return EditOutcome(
        EditOutcomeKind.synonymous,
        codonIndex: codon + 1,
        oldResidue: was[codon],
        newResidue: reads[codon],
      );
    }
    final String? oldResidue = k < was.length ? was[k] : null;
    final String? newResidue = k < reads.length ? reads[k] : null;

    if (k >= old.protein.length) {
      // Every residue survives: what changed is the stop codon itself.
      return EditOutcome(
        EditOutcomeKind.stopLoss,
        codonIndex: k + 1,
        oldResidue: oldResidue,
        newResidue: newResidue,
        newStopPosition: _stopPosition,
      );
    }

    final int delta = now.bases.length - old.bases.length;
    final int? stop = now.stop;
    final int? oldStop = old.stop;
    final bool premature =
        stop != null && (oldStop == null || stop < oldStop + delta);
    final EditOutcomeKind kind = delta % 3 != 0
        ? EditOutcomeKind.frameshift
        : premature
        ? EditOutcomeKind.nonsense
        : change.removed == change.inserted.length
        ? EditOutcomeKind.missense
        : EditOutcomeKind.inFrameIndel;
    final int? junction = _lastJunction;
    final bool degraded =
        premature && junction != null && junction - stop > nmdThresholdBp;
    final bool stopMoved =
        kind == EditOutcomeKind.frameshift || kind == EditOutcomeKind.nonsense;
    return EditOutcome(
      degraded ? EditOutcomeKind.mrnaDegraded : kind,
      codonIndex: k + 1,
      oldResidue: oldResidue,
      newResidue: newResidue,
      newStopPosition: stopMoved ? _stopPosition : null,
    );
  }

  /// The places in the old mRNA the edit touches, first and last, or null
  /// when it touches no exon.
  ///
  /// An insertion touches an exon only when it goes in strictly inside one.
  /// Between places p and p + 1 it is the empty run (p + 1, p), so one overlap
  /// test serves every kind of edit.
  (int, int)? get _touched {
    final Int32List place = old.place;
    if (change.removed == 0) {
      final int at = change.at;
      if (at == 0) {
        return null;
      }
      final int before = place[at - 1];
      return before >= 0 && place[at] == before + 1
          ? (before + 1, before)
          : null;
    }
    int? first;
    int last = -1;
    for (
      int offset = change.at;
      offset < change.at + change.removed;
      offset++
    ) {
      if (place[offset] >= 0) {
        first ??= place[offset];
        last = place[offset];
      }
    }
    return first == null ? null : (first, last);
  }

  /// Where the edited mRNA enters the last exon of the edited record's own
  /// exon table, as a place in the mRNA; null with fewer than two exons.
  int? get _lastJunction {
    if (record.exons.length < 2) {
      return null;
    }
    final int last = record.exons
        .map((Exon e) => axis.span(Segment(start: e.start, end: e.end)).from)
        .reduce(math.max);
    return _lowerBound(now.bases, last);
  }

  int? get _stopPosition {
    final int? stop = now.stop;
    return stop == null ? null : axis.position(now.bases[stop]);
  }
}

/// The exon structure the walk draws: the mRNA feature, else the `exon`
/// features, else one exon over the whole record. The same order of
/// preference as `_transcriptSegments` in the shared anatomy stages.
List<Segment> _exonsOf(
  Transcript? transcript,
  List<Exon> exons,
  Segment whole,
) {
  final List<Segment>? segments = transcript?.segments;
  if (segments != null && segments.isNotEmpty) {
    return segments;
  }
  if (exons.isNotEmpty) {
    return <Segment>[
      for (final Exon exon in exons) Segment(start: exon.start, end: exon.end),
    ];
  }
  return <Segment>[whole];
}

Exon _renumbered(Exon exon, Segment segment) =>
    Exon(number: exon.number, start: segment.start, end: segment.end);

int? _firstOffset(List<_Span> spans) =>
    spans.isEmpty ? null : spans.map((_Span s) => s.from).reduce(math.min);

/// The first index of [sorted] holding [value] or more.
int _lowerBound(List<int> sorted, int value) {
  int low = 0;
  int high = sorted.length;
  while (low < high) {
    final int mid = (low + high) >> 1;
    if (sorted[mid] < value) {
      low = mid + 1;
    } else {
      high = mid;
    }
  }
  return low;
}

/// Each intron's real length after [change], in transcript order.
///
/// A shortened intron's missing middle is not in `sequence`, so no edit can
/// reach it. What the record does not draw of each intron is carried over as
/// it was and added to what the edited record draws, and an exon the edit
/// removed joins the introns either side of it into one.
List<int>? _realIntrons(List<int>? real, List<_Span> exons, _Change change) {
  if (real == null || real.length != exons.length - 1) {
    return real;
  }
  final List<int> hidden = <int>[
    for (int i = 0; i < real.length; i++)
      real[i] - (exons[i + 1].from - exons[i].to - 1),
  ];
  final List<(int, _Span)> kept = <(int, _Span)>[
    for (int i = 0; i < exons.length; i++)
      if (change.move(exons[i]) case final _Span span) (i, span),
  ];
  return <int>[
    for (int k = 0; k + 1 < kept.length; k++)
      kept[k + 1].$2.from -
          kept[k].$2.to -
          1 +
          hidden
              .sublist(kept[k].$1, kept[k + 1].$1)
              .fold<int>(0, (int sum, int bp) => sum + bp),
  ];
}

/// Why a base in a shortened intron cannot be edited, in the words the walk
/// uses when it will not copy one.
const String _shortenedReason =
    'This intron is drawn shortened, so an edit here cannot be placed on '
    'the chromosome.';

/// The introns [record] draws shortened, as offsets.
///
/// An intron is shortened where its real length is more than it draws. Where
/// the record says its introns were shortened but not by how much, every one
/// of them is taken to be.
List<_Span> _shortenedIntrons(GeneRecord record) {
  if (!record.isIntronCompressed) {
    return const <_Span>[];
  }
  final _Axis axis = _Axis.of(record);
  final List<_Span> exons = <_Span>[
    for (final Segment segment in _exonsOf(
      record.transcript,
      record.exons,
      Segment(start: record.start, end: record.end),
    ))
      axis.span(segment),
  ]..sort((_Span a, _Span b) => a.from.compareTo(b.from));
  final List<int>? real = record.realIntronBp;
  final bool measured = real != null && real.length == exons.length - 1;
  return <_Span>[
    for (int i = 0; i + 1 < exons.length; i++)
      if (exons[i + 1].from - exons[i].to - 1 case final int drawn
          when drawn > 0 && (!measured || real[i] > drawn))
        (from: exons[i].to + 1, to: exons[i + 1].from - 1),
  ];
}
