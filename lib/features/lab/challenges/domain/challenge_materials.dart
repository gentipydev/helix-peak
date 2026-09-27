import 'package:flutter/foundation.dart';

/// A single-residue change ClinVar has a record of, as the puzzle can use it.
@immutable
final class ReportedChange {
  const ReportedChange({
    required this.residue,
    required this.from,
    required this.to,
    required this.classification,
  });

  /// The residue, numbered from 1 in the precursor.
  final int residue;

  /// One-letter codes: what the protein has there, and what the record
  /// reports in its place.
  final String from;
  final String to;

  /// The record's classification, as ClinVar words it.
  final String classification;

  /// A record's change from its own `p.E7V`, or null for anything that is not
  /// one residue for another at [residue]: a stop, a start codon, a
  /// synonymous change, or a record placed at no residue.
  static ReportedChange? of({
    required int? residue,
    required String? proteinChange,
    required String classification,
  }) {
    final RegExpMatch? match = _missense.firstMatch(proteinChange ?? '');
    if (residue == null ||
        match == null ||
        int.parse(match.group(2)!) != residue ||
        match.group(1) == match.group(3)) {
      return null;
    }
    return ReportedChange(
      residue: residue,
      from: match.group(1)!,
      to: match.group(3)!,
      classification: classification,
    );
  }

  static final RegExp _missense = RegExp(r'^p\.([A-Z])(\d+)([A-Z])$');
}

/// What this phone already holds of one protein's tracks: what a round can be
/// made from without asking the network for anything.
@immutable
final class ProteinMaterials {
  const ProteinMaterials({
    this.fold = false,
    this.sequence,
    this.reported = const <ReportedChange>[],
  });

  /// Nothing held: every round about this protein falls back to its catalog
  /// row.
  static const ProteinMaterials none = ProteinMaterials();

  /// Whether the fold's model is held, so the fold can be drawn.
  final bool fold;

  /// The precursor's residues, where a track that carries them is held.
  final String? sequence;

  /// Its ClinVar missense records, where the snapshot is held. Empty where it
  /// is not, or where it has none.
  final List<ReportedChange> reported;
}
