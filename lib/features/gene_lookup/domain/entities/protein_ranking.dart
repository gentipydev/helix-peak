/// How the search screen orders what it found.
///
/// Lifted out of `ProteinCatalog` unchanged when the catalog stopped being a
/// const list and became a list the repository holds. The ranking is the same
/// ranking; it just takes the proteins to rank as an argument now, so the
/// bundled seed and the network-backed repository cannot drift apart by being
/// two copies of it.
library;

import 'protein_target.dart';

/// Everything in [targets] whose name, gene symbol, UniProt accession, RefSeq
/// accession or summary contains [query], the closest matches first.
///
/// A blank query is every protein rather than none, so the screen opens on the
/// list instead of on an empty state the reader has to type their way out of —
/// and it returns [targets] itself, not a copy, because the caller may be
/// comparing the two.
///
/// Ordered by how the query matched: a protein it names outright, then one
/// whose name or identifiers begin with it, then one whose name or identifiers
/// contain it, and last one only its summary mentions — so "hormone" leads with
/// growth hormone rather than with insulin, whose summary happens to say the
/// word. The order of [targets] breaks ties, which is why the repository sorts
/// into reading order before it ranks.
List<ProteinTarget> rank(List<ProteinTarget> targets, String query) {
  final String needle = query.trim().toLowerCase();
  if (needle.isEmpty) {
    return targets;
  }
  final List<(int, int, ProteinTarget)> found = <(int, int, ProteinTarget)>[
    for (final (int order, ProteinTarget target) in targets.indexed)
      if (_closeness(target, needle) case final int closeness)
        (closeness, order, target),
  ];
  found.sort(
    ((int, int, ProteinTarget) a, (int, int, ProteinTarget) b) =>
        a.$1 != b.$1 ? a.$1.compareTo(b.$1) : a.$2.compareTo(b.$2),
  );
  return <ProteinTarget>[
    for (final (int _, int _, ProteinTarget target) in found) target,
  ];
}

int? _closeness(ProteinTarget target, String needle) {
  final List<String> names = <String>[
    target.display.toLowerCase(),
    target.gene.toLowerCase(),
    target.slug,
    target.uniprot.toLowerCase(),
    target.accession.toLowerCase(),
  ];
  if (names.contains(needle)) {
    return 0;
  }
  if (names.any((String name) => name.startsWith(needle)) ||
      names.first
          .split(RegExp(r'[\s()-]+'))
          .any((String word) => word.startsWith(needle))) {
    return 1;
  }
  if (names.any((String name) => name.contains(needle))) {
    return 2;
  }
  if (target.summary.toLowerCase().contains(needle)) {
    return 3;
  }
  return null;
}
