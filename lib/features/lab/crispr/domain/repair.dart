import 'package:flutter/foundation.dart';

import '../../../../core/biology/gene_record.dart';
import '../../mutate/domain/apply_edit.dart';
import 'base_editor.dart';
import 'guide_finder.dart';

/// How a change was made: which path the cell took to a break, or what wrote
/// it where there was no break at all.
enum RepairPath {
  /// Non-homologous end joining. The cell pushes the two ends back together,
  /// and often loses or gains a few bases in doing it.
  endJoining,

  /// Homology-directed repair. A template is supplied whose two arms match
  /// either side of the break, and the cell copies what lies between them in.
  homologyDirected,

  /// No double-strand break at all: a base editor rewrites one base inside
  /// the window its guide holds open.
  baseEditing,
}

/// One change a guide can bring about, as an edit the engine makes.
///
/// Every path ends in a [SequenceEdit], so an outcome here is read the way
/// every other edit is: [applyEdit] makes it and [classify] says what it does
/// to the protein. Nothing in this file decides what a change means.
@immutable
final class Repair {
  const Repair({
    required this.path,
    required this.guide,
    required this.edit,
    this.editor,
    this.place,
  });

  final RepairPath path;

  /// The guide this repair follows from: the cut for the two repair paths,
  /// and the window for a base edit.
  final Guide guide;

  final SequenceEdit edit;

  /// Which editor wrote it, for [RepairPath.baseEditing].
  final BaseEditor? editor;

  /// Which base of the protospacer it rewrote, counted from 1 at the guide's
  /// own 5' end, for [RepairPath.baseEditing].
  final int? place;

  @override
  String toString() => 'Repair(${path.name}, $edit at ${edit.position})';
}

/// Representative outcomes of end joining at [guide]'s cut.
///
/// End joining does not have an outcome. It has a distribution: the ends are
/// chewed back and pushed together, and what comes out is a spread over many
/// small insertions and deletions, in proportions that depend on the sequence
/// and the cell. These are four shapes that spread is mostly made of — the
/// base at the break copied, one base lost, a codon's worth lost, and a short
/// deletion across the cut — offered as four outcomes to try, not as a
/// prediction of which one a cell would give. The screen says so.
///
/// Every one of them falls inside the twenty-three bases the guide binds, so
/// every one is a base the record really holds ([GuideFinder.find]).
List<Repair> endJoiningOutcomes(GeneRecord record, Guide guide) {
  Repair made(SequenceEdit edit) =>
      Repair(path: RepairPath.endJoining, guide: guide, edit: edit);
  return <Repair>[
    // The commonest single outcome: the base 5' of the break copied into it.
    made(
      Insertion(guide.cutPosition, _baseAt(record, guide.positionFromCut(-1))),
    ),
    made(Deletion(guide.cutPosition, 1)),
    made(Deletion(guide.cutPosition, 3)),
    made(Deletion(guide.positionFromCut(-2), 5)),
  ];
}

/// How far from the cut a change is offered for homology-directed repair.
///
/// A convention, not a measurement. The template's two arms meet at the break,
/// and the further the change sits from it the more often what the cell
/// finishes with is the strand that was never changed; ten bases is about
/// where published templates keep it.
const int hdrReach = 10;

/// The record positions homology-directed repair is offered at from [guide]'s
/// cut, in the order the record reads them.
///
/// [hdrReach] either side of the cut, less anything that runs off the record
/// or that the record does not really hold ([EditEligibility]).
List<int> hdrPositions(GeneRecord record, Guide guide) => <int>[
  for (int away = -hdrReach; away <= hdrReach; away++)
    if (guide.positionFromCut(away) case final int position
        when position >= record.start &&
            position <= record.end &&
            EditEligibility.of(record, position) is Eligible)
      position,
];

/// [change] copied in by homology-directed repair at [guide]'s cut, or null
/// where it sits further than [hdrReach] bases from it.
///
/// The change is the reader's, exactly as they write it: this path does not
/// offer outcomes, it takes one.
Repair? homologyDirected(Guide guide, SequenceEdit change) =>
    (change.position - guide.cutPosition).abs() > hdrReach
    ? null
    : Repair(path: RepairPath.homologyDirected, guide: guide, edit: change);

/// Every base inside [guide]'s window that [editor] rewrites.
///
/// One [Repair] each — and where there is more than one, the editor is not
/// choosing between them. A deaminase reaching a window with two of its
/// substrate in it writes both; the screen says so rather than letting a list
/// of one-base changes imply that a reader picks one.
///
/// A base an editor writes on an antisense guide's strand is written here as
/// the base the page draws, because that is what an edit is
/// ([Guide.asRecordWrites]): an adenine editor aimed at an antisense guide
/// turns a drawn T into a drawn C.
List<Repair> baseEdits(Guide guide, BaseEditor editor) => <Repair>[
  for (int place = BaseEditor.windowFrom; place <= BaseEditor.windowTo; place++)
    if (guide.protospacer[place - 1] == editor.from)
      Repair(
        path: RepairPath.baseEditing,
        guide: guide,
        edit: Substitution(
          guide.positionAt(place),
          guide.asRecordWrites(editor.to),
        ),
        editor: editor,
        place: place,
      ),
];

/// R2.1: a minus-strand record's sequence is read from the far end, and is
/// never complemented.
String _baseAt(GeneRecord record, int position) =>
    record.sequence[record.strand == -1
        ? record.end - position
        : position - record.start];
