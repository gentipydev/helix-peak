import 'package:flutter/foundation.dart';

import '../../../../core/biology/gene_record.dart';
import '../../../../core/biology/genetic_code.dart';
import '../../crispr/domain/base_editor.dart';
import '../../crispr/domain/guide_finder.dart';
import '../../crispr/domain/repair.dart';
import '../../mutate/domain/apply_edit.dart';

/// The gene this story is about.
///
/// A story names its own subject, the way the structure page's sentence does
/// (R4.5). Nothing generic branches on it: the catalog is asked for the row
/// whose gene this is, and where there is none the story is not told. No other
/// flow reads this.
const String sickleGene = 'HBB';

/// The codon the whole story turns on, counted from 1 at the start codon.
const int sickleCodon = 7;

/// What that codon reads in the record, and what the two changes make of it.
const String referenceCodon = 'GAG';
const String sickleCodonReads = 'GTG';
const String makassarCodon = 'GCG';

/// One guide that covers the base the story turns on, and where in its own
/// twenty bases that base falls.
@immutable
final class GuideReach {
  const GuideReach({required this.guide, required this.place});

  final Guide guide;

  /// Which base of the protospacer it is, counted from 1 at the guide's own
  /// 5' end.
  final int place;

  bool get inWindow =>
      place >= BaseEditor.windowFrom && place <= BaseEditor.windowTo;

  @override
  String toString() => 'GuideReach(place $place of ${guide.protospacer})';
}

/// The three chapters, worked out on one record rather than written down.
///
/// Everything here comes from the record and from the machinery the earlier
/// sessions built: the codon's positions from the coding sequence, the two
/// changes from [applyEdit] and [classify], what an editor can and cannot
/// write from [BaseEditor], and which guides could carry one from
/// [GuideFinder]. Nothing states an outcome for a person, and nothing here
/// says a variant causes anything: the clinical words in this story are
/// ClinVar's, quoted in its own rows, and the mechanisms carry source links.
@immutable
final class SickleStory {
  const SickleStory._({
    required this.reference,
    required this.sickle,
    required this.makassar,
    required this.codon,
    required this.sickleEdit,
    required this.makassarEdit,
    required this.sickleOutcome,
    required this.makassarOutcome,
    required this.reach,
  });

  /// The story as [record] tells it, or null where this record cannot tell it:
  /// no coding sequence, too few codons, or a codon [sickleCodon] that does
  /// not read [referenceCodon].
  static SickleStory? of(GeneRecord record) {
    final List<int> coding = _codingPositions(record);
    const int first = 3 * (sickleCodon - 1);
    if (coding.length < first + 3) {
      return null;
    }
    final List<int> codon = coding.sublist(first, first + 3);
    if (_read(record, codon) != referenceCodon) {
      return null;
    }

    // The sickle change is the middle base of the codon: A to T as the page
    // draws it. The Makassar change is made on top of it, on the record the
    // first one leaves behind.
    final Substitution sickleEdit = Substitution(
      codon[1],
      sickleCodonReads.substring(1, 2),
    );
    final GeneRecord sickle = applyEdit(record, sickleEdit);
    if (_read(sickle, codon) != sickleCodonReads) {
      return null;
    }
    final Substitution makassarEdit = Substitution(codon[1], makassarCodon[1]);
    final GeneRecord makassar = applyEdit(sickle, makassarEdit);

    return SickleStory._(
      reference: record,
      sickle: sickle,
      makassar: makassar,
      codon: List<int>.unmodifiable(codon),
      sickleEdit: sickleEdit,
      makassarEdit: makassarEdit,
      sickleOutcome: classify(record, sickleEdit),
      makassarOutcome: classify(sickle, makassarEdit),
      reach: _reach(sickle, codon[1]),
    );
  }

  /// The record as the catalog has it.
  final GeneRecord reference;

  /// The same record with the sickle change made.
  final GeneRecord sickle;

  /// And with the Makassar change made on top of that.
  final GeneRecord makassar;

  /// The codon's three record positions, as the record reads them.
  final List<int> codon;

  final Substitution sickleEdit;
  final Substitution makassarEdit;
  final EditOutcome sickleOutcome;
  final EditOutcome makassarOutcome;

  /// Every NGG guide on the sickle record whose twenty bases cover the base
  /// the story turns on.
  final List<GuideReach> reach;

  /// The base all three chapters are about: the middle of the codon.
  int get position => codon[1];

  /// What the codon reads in [record].
  String codonIn(GeneRecord record) => _read(record, codon);

  /// The residue that codon codes for in [record].
  String residueIn(GeneRecord record) =>
      GeneticCode.translate(codonIn(record)) ?? 'X';

  /// The editor that writes the Makassar change, and the strand its guide has
  /// to be aimed at. Never null in practice: it is an adenine editor reaching
  /// the A that pairs with the drawn T.
  ({BaseEditor editor, GuideStrand strand})? get makassarEditor =>
      BaseEditor.forChange(from: sickleCodonReads[1], to: makassarCodon[1]);

  /// The editor that would put the sickle change back — which is to say, none
  /// of them. Chapter two is this being null.
  ({BaseEditor editor, GuideStrand strand})? get correction =>
      BaseEditor.forChange(from: sickleCodonReads[1], to: referenceCodon[1]);

  /// The guides that could actually carry [makassarEditor] to the base: in
  /// the window, on the strand the editor needs, over the base it rewrites.
  ///
  /// Asked of the repair machinery itself rather than worked out again here,
  /// so what the story says and what the CRISPR screen would offer cannot
  /// drift apart.
  List<GuideReach> get carriers {
    final BaseEditor? editor = makassarEditor?.editor;
    if (editor == null) {
      return const <GuideReach>[];
    }
    return <GuideReach>[
      for (final GuideReach found in reach)
        if (baseEdits(
          found.guide,
          editor,
        ).any((Repair repair) => repair.edit.position == position))
          found,
    ];
  }

  /// Whether an NGG guide can put the base inside an editor's window at all.
  bool get carried => carriers.isNotEmpty;
}

/// The coding sequence's positions, in the order the record reads them.
List<int> _codingPositions(GeneRecord record) {
  final Protein? protein = record.protein;
  if (protein == null) {
    return const <int>[];
  }
  final bool minus = record.strand == -1;
  final List<Segment> ordered = List<Segment>.of(protein.segments)
    ..sort(
      (Segment a, Segment b) =>
          minus ? b.start.compareTo(a.start) : a.start.compareTo(b.start),
    );
  return <int>[
    for (final Segment segment in ordered)
      if (minus)
        for (int p = segment.end; p >= segment.start; p--) p
      else
        for (int p = segment.start; p <= segment.end; p++) p,
  ];
}

/// R2.1: a minus-strand record's sequence is read from the far end, and is
/// never complemented.
String _read(GeneRecord record, List<int> positions) => <String>[
  for (final int position in positions)
    record.sequence[record.strand == -1
        ? record.end - position
        : position - record.start],
].join();

List<GuideReach> _reach(GeneRecord record, int position) => <GuideReach>[
  for (final Guide guide in GuideFinder.find(record))
    for (int place = 1; place <= guide.protospacer.length; place++)
      if (guide.positionAt(place) == position)
        GuideReach(guide: guide, place: place),
];
