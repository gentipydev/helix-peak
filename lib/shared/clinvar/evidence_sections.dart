import '../anatomy/anatomy_stages.dart';

/// Names the piece of the gene a record off the protein sits in, the way the
/// gene page names it, and where that is along the transcript.
///
/// The labels are the model's own roles rather than anything read from ClinVar,
/// so a record is filed under the intron the page draws it in. Order follows
/// the transcript, which on a minus-strand record runs against the coordinates.
({String label, int order}) Function(int position) nonCodingSections(
  AnatomyModel model,
) => (int position) {
  final Role? coding = model.codingRoleAt(position);
  final Role? transcript = model.transcriptRoleAt(position);
  final int order = model.record.strand == -1 ? -position : position;
  final String label = switch ((coding?.kind, transcript?.kind)) {
    (RoleKind.utr5, _) => '5′ UTR',
    (RoleKind.utr3, _) => '3′ UTR',
    // 'intron 2' as the page says it, capitalised for a heading. The exon's
    // own number comes from the record, which is why it is read, not counted.
    (_, RoleKind.intron || RoleKind.exon) => _heading(transcript!.label),
    _ => 'Outside the transcript',
  };
  return (label: label, order: order);
};

String _heading(String label) =>
    label.isEmpty ? label : label[0].toUpperCase() + label.substring(1);

/// A stretch of the gene with one name, in record positions, and how long it
/// really is: an intron of a gene too long to draw to scale is drawn
/// shortened, and [lengthBp] is the intron's own length, as the gene page
/// gives it. Anything else is drawn whole.
typedef GeneRun = ({int start, int end, String label, int lengthBp});

/// The gene cut where [nonCodingSections] changes its name, in increasing
/// record position: the pieces the overview's gene drawing names and zooms to,
/// called what the list's headings call them.
List<GeneRun> geneRuns(AnatomyModel model) {
  final ({String label, int order}) Function(int) section = nonCodingSections(
    model,
  );
  GeneRun run(int from, int to, String label) {
    final Role? role = model.transcriptRoleAt(from);
    return (
      start: from,
      end: to,
      label: label,
      lengthBp: role != null && role.kind == RoleKind.intron
          ? role.lengthBp
          : to - from + 1,
    );
  }

  final int first = model.record.start;
  final int last = model.record.end;
  final List<GeneRun> runs = <GeneRun>[];
  int from = first;
  String current = section(first).label;
  for (int position = first + 1; position <= last; position++) {
    final String here = section(position).label;
    if (here != current) {
      runs.add(run(from, position - 1, current));
      from = position;
      current = here;
    }
  }
  runs.add(run(from, last, current));
  return runs;
}
