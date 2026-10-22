import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../../../core/evidence/gene_impact.dart';
import '../../../../core/evidence/protein_constraint.dart';
import '../../../../core/evidence/variant_evidence.dart';
import '../../../../shared/anatomy/anatomy_address.dart';
import '../../../../shared/anatomy/anatomy_stages.dart';
import 'coding_evidence.dart';

/// One single-base missense substitution of the coding sequence, as both
/// models score it.
@immutable
final class ScoredChange {
  const ScoredChange({
    required this.position,
    required this.alt,
    required this.phred,
    required this.esm,
  });

  /// The record-local base, which is what every page taps with.
  final int position;

  /// The alternative base, on the transcript's strand.
  final String alt;

  /// AVI's calibrated Phred.
  final double phred;

  /// ESM-2's ln p(alt)/p(WT) for the amino acid the change makes.
  final double esm;
}

/// Where one score stands among a gene's missense substitutions.
@immutable
final class GeneRank {
  const GeneRank({required this.top, required this.bottom});

  /// The share scoring at least as high, from 0 to 1.
  final double top;

  /// The share scoring at most as high.
  final double bottom;

  /// Where a mark stands on a track from the lowest, 0, to the highest, 1.
  double get place => 1 - top;

  /// `top 1.7%`, and past the middle `bottom 8.0%`, to two figures.
  String get label =>
      top <= 0.5 ? 'top ${_percent(top)}' : 'bottom ${_percent(bottom)}';

  static String _percent(double share) {
    final double value = share * 100;
    final String digits = value >= 99.5
        ? '100'
        : value >= 9.95
        ? value.toStringAsFixed(0)
        : value >= 0.995
        ? value.toStringAsFixed(1)
        : value.toStringAsPrecision(2);
    return '$digits%';
  }
}

/// Every single-base missense substitution of one gene's coding sequence,
/// scored by AVI and by ESM-2, and how far the two agree across them.
///
/// Missense only: ESM-2 scores one amino acid in place of another, so a
/// silent change, a stop and any change in the start codon (HGVS p.Met1?)
/// are AVI's alone. A base whose AVI is borrowed from a neighbour gives no
/// number. Each base is joined to its codon by [CodingEvidence], the walk's
/// own join, so a reverse-strand record reads as the sheet reads it.
@immutable
final class GeneAgreement {
  const GeneAgreement._(
    this._phreds,
    this._esms, {
    required this.gene,
    required this.changes,
    required this.rho,
    required this.pairs,
    required this.alike,
  });

  /// The gene's symbol, as the AVI track names it: `INS`.
  final String gene;

  final List<ScoredChange> changes;

  /// Spearman's ρ between AVI's Phred and ESM-2's score negated, so that both
  /// rise with the predicted effect; null where either is flat.
  final double? rho;

  /// Pairs of missense substitutions at one base, neither score tied.
  final int pairs;

  /// Of [pairs], those both models put in the same order.
  final int alike;

  /// Every Phred and every ESM-2 score, each sorted from the lowest.
  final Float64List _phreds;
  final Float64List _esms;

  int get count => changes.length;

  /// [alike] as a share of [pairs], or null without a pair.
  double? get sameOrder => pairs == 0 ? null : alike / pairs;

  /// Where [phred] stands by AVI: the higher, the nearer the top.
  GeneRank aviRank(double phred) => GeneRank(
    top: (count - _lowerBound(_phreds, phred)) / count,
    bottom: _upperBound(_phreds, phred) / count,
  );

  /// Where [score] stands by ESM-2: the lower, the nearer the top.
  GeneRank esmRank(double score) => GeneRank(
    top: _upperBound(_esms, score) / count,
    bottom: (count - _lowerBound(_esms, score)) / count,
  );

  static final Expando<_Built> _built = Expando<_Built>('gene agreement');

  /// The gene's agreement, worked out once per track and kept with it; null
  /// where the ESM-2 track does not match the protein, or where no
  /// substitution is scored by both.
  static GeneAgreement? of({
    required AnatomyModel model,
    required GeneImpact impact,
    required ProteinConstraint constraint,
  }) {
    final _Built? kept = _built[impact];
    if (kept != null &&
        identical(kept.model, model) &&
        identical(kept.constraint, constraint)) {
      return kept.agreement;
    }
    final GeneAgreement? agreement = _build(model, impact, constraint);
    _built[impact] = _Built(model, constraint, agreement);
    return agreement;
  }

  static GeneAgreement? _build(
    AnatomyModel model,
    GeneImpact impact,
    ProteinConstraint constraint,
  ) {
    final AnatomyStage? transcript = model.stages
        .where((AnatomyStage s) => s.kind == StageKind.mrna)
        .firstOrNull;
    final AnatomyStage? protein = model.stages
        .where((AnatomyStage s) => s.kind == StageKind.protein)
        .firstOrNull;
    // The track's whole sequence is checked here once, rather than at every
    // base, as the sheet does for its one base.
    if (!AnatomyAddress.of(model).coding ||
        transcript == null ||
        protein == null ||
        constraint.sequence != protein.letters) {
      return null;
    }
    final StageBlock cds = transcript.blocks[1];
    final List<ScoredChange> changes = <ScoredChange>[];
    int pairs = 0;
    int alike = 0;
    for (int cell = cds.start; cell < cds.start + cds.count; cell++) {
      final int position = transcript.positionAt(cell);
      final CodingEvidence? coding = CodingEvidence.at(
        model: model,
        position: position,
        track: null,
      );
      if (coding == null || coding.codon == 1) continue;
      final BaseImpact? base = impact.at(position);
      if (base == null || base.estimated) continue;
      final String wildtype = protein.letters[coding.codon - 1];
      final ResidueConstraint residue = constraint.positions[coding.codon - 1];
      final int first = changes.length;
      for (final AltScore score in base.ranked) {
        final String? made = coding.madeBy(score.base);
        if (made == null || made == '*' || made == wildtype) continue;
        final double? esm = _scoreOf(residue, made);
        if (esm == null) continue;
        changes.add(
          ScoredChange(
            position: position,
            alt: score.base,
            phred: score.phred,
            esm: esm,
          ),
        );
      }
      // This base's changes, two by two.
      for (int i = first; i < changes.length; i++) {
        for (int j = i + 1; j < changes.length; j++) {
          final double avi = changes[i].phred - changes[j].phred;
          // The lower ESM-2 score is the larger effect.
          final double esm = changes[j].esm - changes[i].esm;
          if (avi == 0 || esm == 0) continue;
          pairs++;
          if ((avi > 0) == (esm > 0)) alike++;
        }
      }
    }
    final int n = changes.length;
    if (n == 0) return null;
    final Float64List phreds = Float64List(n);
    final Float64List esms = Float64List(n);
    for (int i = 0; i < n; i++) {
      phreds[i] = changes[i].phred;
      esms[i] = changes[i].esm;
    }
    final Float64List byPhred = Float64List.fromList(phreds)..sort();
    final Float64List byEsm = Float64List.fromList(esms)..sort();
    // Ranked from the lowest, ties at their mean rank. ESM-2's effect rises as
    // its score falls, so its ranks are turned over: ρ is negated.
    final double? r = _pearson(_ranks(phreds, byPhred), _ranks(esms, byEsm));
    return GeneAgreement._(
      byPhred,
      byEsm,
      gene: impact.gene,
      changes: List<ScoredChange>.unmodifiable(changes),
      rho: r == null ? null : -r,
      pairs: pairs,
      alike: alike,
    );
  }

  /// ESM-2's score for [aminoAcid] at [residue].
  static double? _scoreOf(ResidueConstraint residue, String aminoAcid) {
    for (final SubstitutionScore s in residue.ranked) {
      if (s.aminoAcid == aminoAcid) return s.score;
    }
    return null;
  }

  /// Each of [values]' rank from the lowest, 1-based, ties given their mean,
  /// read off [sorted], the same values in order.
  static Float64List _ranks(Float64List values, Float64List sorted) {
    final Float64List ranks = Float64List(values.length);
    for (int i = 0; i < values.length; i++) {
      final double v = values[i];
      ranks[i] = (_lowerBound(sorted, v) + _upperBound(sorted, v) + 1) / 2;
    }
    return ranks;
  }

  /// Pearson's r, or null where either is flat.
  static double? _pearson(Float64List x, Float64List y) {
    final int n = x.length;
    if (n < 3) return null;
    double mx = 0;
    double my = 0;
    for (int i = 0; i < n; i++) {
      mx += x[i];
      my += y[i];
    }
    mx /= n;
    my /= n;
    double xy = 0;
    double xx = 0;
    double yy = 0;
    for (int i = 0; i < n; i++) {
      final double a = x[i] - mx;
      final double b = y[i] - my;
      xy += a * b;
      xx += a * a;
      yy += b * b;
    }
    return xx == 0 || yy == 0 ? null : xy / math.sqrt(xx * yy);
  }

  /// The first index whose value is [value] or more.
  static int _lowerBound(Float64List sorted, double value) {
    int low = 0;
    int high = sorted.length;
    while (low < high) {
      final int middle = (low + high) >> 1;
      if (sorted[middle] < value) {
        low = middle + 1;
      } else {
        high = middle;
      }
    }
    return low;
  }

  /// The first index whose value is more than [value].
  static int _upperBound(Float64List sorted, double value) {
    int low = 0;
    int high = sorted.length;
    while (low < high) {
      final int middle = (low + high) >> 1;
      if (sorted[middle] <= value) {
        low = middle + 1;
      } else {
        high = middle;
      }
    }
    return low;
  }
}

final class _Built {
  const _Built(this.model, this.constraint, this.agreement);

  final AnatomyModel model;
  final ProteinConstraint constraint;
  final GeneAgreement? agreement;
}

/// One substitution at the base a page is opened on, as the two models read
/// it.
@immutable
final class AgreementRow {
  const AgreementRow({
    required this.score,
    required this.tag,
    required this.spoken,
    this.made,
    this.esm,
    this.aviRank,
    this.esmRank,
    this.reading,
  });

  /// The base and its Phred.
  final AltScore score;

  /// What the change makes, as the sheet tags it: `Ser`, `=`, `Ter`, `?`.
  final String tag;

  /// [tag] as a screen reader says it.
  final String spoken;

  /// The one-letter amino acid the change makes, `*` for a stop; null for a
  /// letter that is not a base.
  final String? made;

  /// ESM-2's score for a missense change; null for any other.
  final double? esm;

  final GeneRank? aviRank;
  final GeneRank? esmRank;

  /// Why only AVI applies, for a change that is not missense.
  final EvidenceReading? reading;

  /// Whether any of [base]'s substitutions is one both models score: a
  /// change to another amino acid, at a residue ESM-2's track holds. Only
  /// such a base's sheet offers the page (the user's ask, 2026-10-22).
  static bool anyAt(BaseImpact base, CodingEvidence coding) =>
      coding.constraint != null &&
      base.ranked.any(
        (AltScore score) => _missense(coding.changeTo(score.base)),
      );

  /// A change to another amino acid, as the sheet tags it: not silent, not a
  /// stop, not in the start codon, and a base at all.
  static bool _missense(String tag) =>
      tag.isNotEmpty && tag != '=' && tag != 'Ter' && tag != '?';

  /// The base's substitutions in the sheet's order, Phred highest first.
  static List<AgreementRow> at(
    BaseImpact base,
    CodingEvidence coding,
    GeneAgreement? gene,
  ) => <AgreementRow>[
    for (final AltScore score in base.ranked) _read(score, coding, gene),
  ];

  static AgreementRow _read(
    AltScore score,
    CodingEvidence coding,
    GeneAgreement? gene,
  ) {
    final String tag = coding.changeTo(score.base);
    final EvidenceReading? reading = switch (tag) {
      '?' => EvidenceReading.start,
      'Ter' => EvidenceReading.stop,
      '=' => EvidenceReading.synonymous,
      _ => null,
    };
    final String? made = coding.madeBy(score.base);
    final double? esm = !_missense(tag) || made == null
        ? null
        : coding.constraint?.ranked
              .where((SubstitutionScore s) => s.aminoAcid == made)
              .firstOrNull
              ?.score;
    return AgreementRow(
      score: score,
      tag: tag,
      spoken: coding.spokenChangeTo(score.base),
      made: made,
      esm: esm,
      aviRank: esm == null ? null : gene?.aviRank(score.phred),
      esmRank: esm == null ? null : gene?.esmRank(esm),
      reading: reading,
    );
  }
}
