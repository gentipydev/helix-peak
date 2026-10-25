import 'package:flutter/foundation.dart';

import '../../../../core/evidence/gene_clinvar.dart';
import '../../../../core/evidence/variant_evidence.dart';
import 'gene_agreement.dart';

/// A missense substitution of the gene that ClinVar has a record of, as both
/// models score it: one mark on the scatter, in ClinVar's colour.
@immutable
final class ClinVarMarked {
  const ClinVarMarked({required this.change, required this.group});

  /// The substitution, as [GeneAgreement] scores it.
  final ScoredChange change;

  /// The most severe group among the change's records (R9.1).
  final ClinVarGroup group;
}

/// One ClinVar class among the gene's missense records: how many records it
/// holds, and the middle of each model's scores for them, in the models' own
/// units.
@immutable
final class ClinVarClass {
  const ClinVarClass({
    required this.group,
    required this.records,
    required this.phred,
    required this.esm,
  });

  final ClinVarGroup group;

  /// Records, ClinVar's own unit: two records of one change count twice.
  final int records;

  /// The records' middle AVI Phred.
  final double phred;

  /// The records' middle ESM-2 score.
  final double esm;
}

/// Where the gene's ClinVar missense records stand among its missense
/// substitutions, as both models score them.
///
/// It places records and makes no verdict on them: a record is kept where it
/// is missense and both models score its exact change, the change the gene's
/// own set holds ([GeneAgreement]), so every mark lies on the scatter's cloud.
/// ClinVar's classes are not an independent test of either model: AVI draws
/// on AlphaMissense, and submitters may have weighed computational
/// predictions.
@immutable
final class ClinVarAgreement {
  const ClinVarAgreement._({
    required this.marks,
    required this.classes,
    required this.records,
  });

  /// Each change ClinVar has a record of, once.
  final List<ClinVarMarked> marks;

  /// Each class present, in the order a reader scans them
  /// ([ClinVarGroup.values]).
  final List<ClinVarClass> classes;

  /// The records placed.
  final int records;

  static final Expando<_Built> _built = Expando<_Built>('clinvar agreement');

  /// The gene's records placed among [agreement]'s changes, worked out once
  /// per list of records and kept with it; null where none is placed.
  static ClinVarAgreement? of({
    required GeneAgreement agreement,
    required List<VariantEvidence> evidence,
  }) {
    final _Built? kept = _built[evidence];
    if (kept != null && identical(kept.agreement, agreement)) {
      return kept.placed;
    }
    final ClinVarAgreement? placed = _build(agreement, evidence);
    _built[evidence] = _Built(agreement, placed);
    return placed;
  }

  static ClinVarAgreement? _build(
    GeneAgreement agreement,
    List<VariantEvidence> evidence,
  ) {
    final Map<(int, String), ScoredChange> changes =
        <(int, String), ScoredChange>{
          for (final ScoredChange c in agreement.changes) (c.position, c.alt): c,
        };
    final Map<(int, String), List<ClinVarGroup>> byChange =
        <(int, String), List<ClinVarGroup>>{};
    final Map<ClinVarGroup, List<double>> phreds =
        <ClinVarGroup, List<double>>{};
    final Map<ClinVarGroup, List<double>> esms = <ClinVarGroup, List<double>>{};
    int records = 0;
    for (final VariantEvidence e in evidence) {
      final ClinVarVariant v = e.variant;
      if (v.consequence != 'missense' || e.avi == null || e.esm == null) {
        continue;
      }
      final (int, String) key = (v.position, v.alt);
      final ScoredChange? change = changes[key];
      if (change == null) {
        continue;
      }
      records++;
      (byChange[key] ??= <ClinVarGroup>[]).add(v.group);
      (phreds[v.group] ??= <double>[]).add(change.phred);
      (esms[v.group] ??= <double>[]).add(change.esm);
    }
    if (records == 0) {
      return null;
    }
    return ClinVarAgreement._(
      marks: List<ClinVarMarked>.unmodifiable(<ClinVarMarked>[
        for (final MapEntry<(int, String), List<ClinVarGroup>> entry
            in byChange.entries)
          ClinVarMarked(
            change: changes[entry.key]!,
            group: ClinVarGroup.mostSevere(entry.value),
          ),
      ]),
      classes: List<ClinVarClass>.unmodifiable(<ClinVarClass>[
        for (final ClinVarGroup group in ClinVarGroup.values)
          if (phreds[group] case final List<double> scores)
            ClinVarClass(
              group: group,
              records: scores.length,
              phred: _median(scores),
              esm: _median(esms[group]!),
            ),
      ]),
      records: records,
    );
  }

  /// The middle of [values], read between the two middle ones where their
  /// count is even, as [GeneAgreement.medianPhred] reads the gene's.
  static double _median(List<double> values) {
    final List<double> sorted = List<double>.of(values)..sort();
    final int middle = sorted.length ~/ 2;
    return sorted.length.isOdd
        ? sorted[middle]
        : (sorted[middle - 1] + sorted[middle]) / 2;
  }
}

final class _Built {
  const _Built(this.agreement, this.placed);

  final GeneAgreement agreement;
  final ClinVarAgreement? placed;
}
