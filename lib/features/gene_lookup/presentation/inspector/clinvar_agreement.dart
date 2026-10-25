import 'package:flutter/foundation.dart';

import '../../../../core/evidence/gene_clinvar.dart';
import '../../../../core/evidence/variant_evidence.dart';
import 'gene_agreement.dart';

/// One ClinVar class among the gene's missense records: each record's score
/// on each model's own scale, and the middle of them.
@immutable
final class ClinVarClass {
  ClinVarClass({
    required this.group,
    required List<double> phreds,
    required List<double> esms,
  }) : phreds = List<double>.unmodifiable(List<double>.of(phreds)..sort()),
       esms = List<double>.unmodifiable(List<double>.of(esms)..sort());

  final ClinVarGroup group;

  /// Each record's AVI Phred, from the lowest.
  final List<double> phreds;

  /// Each record's ESM-2 score, from the lowest.
  final List<double> esms;

  /// Records, ClinVar's own unit: two records of one change count twice.
  int get records => phreds.length;

  /// The records' middle AVI Phred.
  double get phred => median(phreds);

  /// The records' middle ESM-2 score.
  double get esm => median(esms);

  /// The middle of [sorted], read between the two middle ones where their
  /// count is even, as [GeneAgreement.medianPhred] reads the gene's.
  static double median(List<double> sorted) {
    final int middle = sorted.length ~/ 2;
    return sorted.length.isOdd
        ? sorted[middle]
        : (sorted[middle - 1] + sorted[middle]) / 2;
  }
}

/// Where the gene's ClinVar missense records stand among its missense
/// substitutions, as both models score them.
///
/// It places records and makes no verdict on them: a record is kept where it
/// is missense and both models score its exact change, the change the gene's
/// own set holds ([GeneAgreement]), so every record stands where one of the
/// gene's changes does. ClinVar's classes are not an independent test of
/// either model: AVI draws on AlphaMissense, and submitters may have weighed
/// computational predictions.
@immutable
final class ClinVarAgreement {
  const ClinVarAgreement._({required this.classes, required this.records});

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
    final Map<ClinVarGroup, List<double>> phreds =
        <ClinVarGroup, List<double>>{};
    final Map<ClinVarGroup, List<double>> esms = <ClinVarGroup, List<double>>{};
    int records = 0;
    for (final VariantEvidence e in evidence) {
      final ClinVarVariant v = e.variant;
      if (v.consequence != 'missense' || e.avi == null || e.esm == null) {
        continue;
      }
      final ScoredChange? change = changes[(v.position, v.alt)];
      if (change == null) {
        continue;
      }
      records++;
      (phreds[v.group] ??= <double>[]).add(change.phred);
      (esms[v.group] ??= <double>[]).add(change.esm);
    }
    if (records == 0) {
      return null;
    }
    return ClinVarAgreement._(
      classes: List<ClinVarClass>.unmodifiable(<ClinVarClass>[
        for (final ClinVarGroup group in ClinVarGroup.values)
          if (phreds[group] case final List<double> scores)
            ClinVarClass(group: group, phreds: scores, esms: esms[group]!),
      ]),
      records: records,
    );
  }
}

final class _Built {
  const _Built(this.agreement, this.placed);

  final GeneAgreement agreement;
  final ClinVarAgreement? placed;
}
