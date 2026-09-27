import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:flutter/foundation.dart';

import '../../../../core/biology/gene_record.dart';
import '../../../../core/catalog/protein_target.dart';
import '../../../../core/evidence/gene_clinvar.dart';
import '../../../../core/evidence/variant_evidence.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/network/track_source.dart';
import '../../../../shared/anatomy/anatomy_stages.dart';
import '../../../../shared/clinvar/evidence_sections.dart';
import '../../../gene_lookup/domain/usecases/fetch_gene.dart';
import '../domain/apply_edit.dart';

/// Where the gene's ClinVar records have got to.
enum ClinVarLoad {
  /// The gene has no ClinVar snapshot, so there is nothing to show.
  absent,
  loading,
  ready,

  /// The snapshot could not be read. The screen says so and carries on.
  failed,
}

/// One edit made, and everything read off it.
@immutable
final class AppliedEdit {
  const AppliedEdit({
    required this.edit,
    required this.record,
    required this.model,
    required this.outcome,
    required this.oldBase,
  });

  final SequenceEdit edit;

  /// The edited record, and the anatomy derived from it afresh.
  final GeneRecord record;
  final AnatomyModel model;
  final EditOutcome outcome;

  /// The base the edit replaced or removed first, as the gene page draws it.
  final String oldBase;

  /// The base an edit puts in its place, for a substitution.
  String? get newBase => switch (edit) {
    Substitution(:final String newBase) => newBase,
    _ => null,
  };
}

sealed class MutateState {
  const MutateState();
}

final class MutateLoading extends MutateState {
  const MutateLoading();
}

final class MutateFailed extends MutateState {
  const MutateFailed(this.message);

  final String message;
}

/// The record, and the edit being tried on it, if any.
///
/// The original is never replaced: an edit is a try-it mode over it, and
/// reverting is dropping [applied].
final class MutateReady extends MutateState {
  const MutateReady({
    required this.original,
    required this.model,
    this.applied,
    this.evidence = const <VariantEvidence>[],
    this.clinvar = ClinVarLoad.absent,
  });

  final GeneRecord original;
  final AnatomyModel model;
  final AppliedEdit? applied;

  /// The gene's ClinVar records, read against the original record.
  final List<VariantEvidence> evidence;
  final ClinVarLoad clinvar;

  /// The record on screen: the edited one while an edit is being tried.
  AnatomyModel get shown => applied?.model ?? model;

  /// ClinVar's records at [position], in the snapshot's own order.
  List<VariantEvidence> recordsAt(int position) => <VariantEvidence>[
    for (final VariantEvidence e in evidence)
      if (e.variant.position == position) e,
  ];

  /// ClinVar's records of exactly the change [applied] made, or none.
  List<VariantEvidence> get recordsOfEdit {
    final AppliedEdit? edit = applied;
    final String? alt = edit?.newBase;
    if (edit == null || alt == null) {
      return const <VariantEvidence>[];
    }
    return <VariantEvidence>[
      for (final VariantEvidence e in recordsAt(edit.edit.position))
        if (e.variant.ref == edit.oldBase && e.variant.alt == alt) e,
    ];
  }

  MutateReady _with({
    AppliedEdit? applied,
    bool revert = false,
    List<VariantEvidence>? evidence,
    ClinVarLoad? clinvar,
  }) => MutateReady(
    original: original,
    model: model,
    applied: revert ? null : applied ?? this.applied,
    evidence: evidence ?? this.evidence,
    clinvar: clinvar ?? this.clinvar,
  );
}

/// The Mutate screen's state: one protein's record, fetched through the lab's
/// own tracks, and the edit tried on it.
class MutateCubit extends Cubit<MutateState> {
  MutateCubit({
    required this.target,
    required this._fetchGene,
    required this._tracks,
  }) : super(const MutateLoading());

  final ProteinTarget target;
  final FetchGene _fetchGene;
  final TrackSource _tracks;

  Future<void> load() async {
    emit(const MutateLoading());
    final GeneRecord record;
    try {
      record = await _fetchGene(target.query);
    } on ApiException catch (error) {
      emit(MutateFailed(error.userMessage));
      return;
    } on Object {
      emit(MutateFailed(const UnknownApiException().userMessage));
      return;
    }
    final AnatomyModel model = AnatomyModel.derive(record, chain: target.chain);
    emit(
      MutateReady(
        original: record,
        model: model,
        clinvar: target.clinvarAvailable
            ? ClinVarLoad.loading
            : ClinVarLoad.absent,
      ),
    );
    if (target.clinvarAvailable) {
      unawaited(_loadClinVar(model));
    }
  }

  Future<void> _loadClinVar(AnatomyModel model) async {
    try {
      final GeneClinVar snapshot = await GeneClinVar.load(
        target,
        tracks: _tracks,
      );
      if (!snapshot.matchesRecord(model.record)) {
        throw const FormatException('ClinVar snapshot names another record');
      }
      final List<VariantEvidence> evidence = VariantEvidence.build(
        snapshot,
        nonCoding: nonCodingSections(model),
      );
      if (state case final MutateReady ready when !isClosed) {
        emit(ready._with(evidence: evidence, clinvar: ClinVarLoad.ready));
      }
    } on Object {
      if (state case final MutateReady ready when !isClosed) {
        emit(ready._with(clinvar: ClinVarLoad.failed));
      }
    }
  }

  /// Whether [position] of the original record can be edited at all.
  EditEligibility eligibility(int position) {
    final MutateReady ready = state as MutateReady;
    return EditEligibility.of(ready.original, position);
  }

  /// Makes [edit] on the original record. Returns why not, for an edit the
  /// guard refuses, and makes nothing then.
  String? apply(SequenceEdit edit) {
    final MutateState current = state;
    if (current is! MutateReady) {
      return null;
    }
    final EditEligibility eligible = EditEligibility.of(
      current.original,
      edit.position,
    );
    if (eligible is Ineligible) {
      return eligible.reason;
    }
    final GeneRecord record = applyEdit(current.original, edit);
    final EditOutcome outcome = classify(current.original, edit);
    emit(
      current._with(
        applied: AppliedEdit(
          edit: edit,
          record: record,
          model: AnatomyModel.derive(record, chain: target.chain),
          outcome: outcome,
          oldBase: current.model.baseAt(edit.position),
        ),
      ),
    );
    return null;
  }

  /// Back to the record as it was.
  void revert() {
    if (state case final MutateReady ready when ready.applied != null) {
      emit(ready._with(revert: true));
    }
  }
}
