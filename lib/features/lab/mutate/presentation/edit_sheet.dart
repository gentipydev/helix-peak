import 'package:flutter/material.dart';

import '../../../../core/biology/amino_acids.dart';
import '../../../../core/evidence/variant_evidence.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/nucleotide_colors.dart';
import '../../../../shared/anatomy/anatomy_stages.dart';
import '../../../../shared/clinvar/evidence_row.dart';
import '../../../../shared/format.dart';
import '../../../../shared/inspector/inspector_sheet.dart';
import '../domain/apply_edit.dart';
import 'edit_ripple.dart';
import 'mutate_cubit.dart';

/// The edit control: the walk's own [InspectorSheet], about one base.
///
/// Before an edit it says what the base is and where, offers the three other
/// bases and a deletion, and lists ClinVar's records at that base. A base the
/// guard rules out says why, in its own sentence, and offers nothing. After
/// an edit it names the change, quotes ClinVar where ClinVar has exactly that
/// change, through [EvidenceRow] and nothing else, and offers the original
/// back.
class EditSheet extends StatefulWidget {
  const EditSheet({
    required this.state,
    required this.position,
    required this.refusal,
    required this.controller,
    required this.slide,
    required this.onDismiss,
    required this.onEdit,
    required this.onRevert,
    super.key,
  });

  final MutateReady state;

  /// The base the sheet is about, as a record position.
  final int position;

  /// Why the last edit was refused, where it was.
  final String? refusal;

  final DraggableScrollableController controller;
  final Animation<Offset> slide;
  final VoidCallback onDismiss;
  final ValueChanged<SequenceEdit> onEdit;
  final VoidCallback onRevert;

  static const List<String> bases = <String>['A', 'C', 'G', 'T'];

  @override
  State<EditSheet> createState() => _EditSheetState();
}

class _EditSheetState extends State<EditSheet> {
  final InspectorSheetController _inspector = InspectorSheetController();

  /// The records opened in place, by Variation ID.
  final Set<String> _open = <String>{};

  void _toggle(VariantEvidence evidence) => setState(() {
    final String id = evidence.variant.id;
    if (!_open.remove(id)) {
      _open.add(id);
    }
  });

  @override
  Widget build(BuildContext context) {
    final MutateReady state = widget.state;
    final AppliedEdit? applied = state.applied;
    return InspectorSheet(
      sheet: widget.controller,
      controller: _inspector,
      slide: widget.slide,
      onDismiss: widget.onDismiss,
      pinIdentity: true,
      subject: (widget.position, identityHashCode(applied)),
      resizeLabel: 'Resize the edit sheet',
      surfaceKey: const ValueKey<String>('mutate-sheet-surface'),
      scrollKey: const ValueKey<String>('mutate-sheet-scroll'),
      handleKey: const ValueKey<String>('mutate-sheet-handle'),
      closeKey: const ValueKey<String>('mutate-sheet-close'),
      identity: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
        child: _BaseIdentity(model: state.model, position: widget.position),
      ),
      details: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: applied == null
            ? _Choices(
                state: state,
                position: widget.position,
                refusal: widget.refusal,
                onEdit: widget.onEdit,
                records: _records(
                  state.recordsAt(widget.position),
                  heading: 'ClinVar records at this base',
                ),
              )
            : _Made(
                applied: applied,
                onRevert: widget.onRevert,
                records: _records(
                  state.recordsOfEdit,
                  heading: 'ClinVar has this exact change',
                  none: state.clinvar == ClinVarLoad.ready
                      ? 'ClinVar has no record of this exact change.'
                      : null,
                ),
              ),
      ),
    );
  }

  /// ClinVar's rows, each through the walk's [EvidenceRow], or a line saying
  /// where the snapshot has got to.
  Widget _records(
    List<VariantEvidence> records, {
    required String heading,
    String? none,
  }) {
    final ThemeData theme = Theme.of(context);
    final TextStyle? quiet = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final String? status = switch (widget.state.clinvar) {
      ClinVarLoad.absent => null,
      ClinVarLoad.loading => 'Reading ClinVar…',
      ClinVarLoad.failed => 'ClinVar could not be read.',
      ClinVarLoad.ready => records.isEmpty ? none : null,
    };
    if (records.isEmpty) {
      return status == null
          ? const SizedBox.shrink()
          : Padding(
              padding: const EdgeInsets.only(top: AppSpacing.md),
              child: Text(status, style: quiet),
            );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const SizedBox(height: AppSpacing.md),
        Text(heading, style: theme.textTheme.titleSmall),
        for (final VariantEvidence evidence in records)
          EvidenceRow(
            evidence: evidence,
            column: EvidenceColumn.both,
            expanded: _open.contains(evidence.variant.id),
            onToggle: () => _toggle(evidence),
            allele: true,
            place: false,
          ),
      ],
    );
  }
}

/// What the base is, and where it sits: its region, and its codon where it is
/// in one.
class _BaseIdentity extends StatelessWidget {
  const _BaseIdentity({required this.model, required this.position});

  final AnatomyModel model;
  final int position;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String base = model.baseAt(position);
    final String? region = model.transcriptRoleAt(position)?.label;
    final String? codon = _codon();
    return Row(
      children: <Widget>[
        Container(
          width: 42,
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Text(
            base,
            style: theme.textTheme.titleLarge?.copyWith(
              color: context.nucleotideColors.forBase(base),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Base ${grouped(position)}',
                style: theme.textTheme.titleMedium,
              ),
              Text(
                <String>[
                  if (region != null && region.isNotEmpty)
                    region[0].toUpperCase() + region.substring(1),
                  ?codon,
                ].join(' · '),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// `codon 23, alanine`, read off the protein page, or null outside it.
  String? _codon() {
    final int page = proteinStageOf(model);
    if (page < 0) {
      return null;
    }
    final AnatomyStage protein = model.stages[page];
    final int cell = protein.cellAt(position);
    if (cell < 0) {
      return null;
    }
    return 'codon ${grouped(cell + 1)}, '
        '${AminoAcids.nameOf(protein.letters[cell]).toLowerCase()}';
  }
}

/// The choices a base offers: the other three bases, or its removal.
class _Choices extends StatelessWidget {
  const _Choices({
    required this.state,
    required this.position,
    required this.refusal,
    required this.onEdit,
    required this.records,
  });

  final MutateReady state;
  final int position;
  final String? refusal;
  final ValueChanged<SequenceEdit> onEdit;
  final Widget records;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final EditEligibility eligibility = EditEligibility.of(
      state.original,
      position,
    );
    final String base = state.model.baseAt(position);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (eligibility case Ineligible(:final String reason))
          Text(
            reason,
            key: const ValueKey<String>('mutate-ineligible'),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          )
        else ...<Widget>[
          Text('Change it to', style: theme.textTheme.titleSmall),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: <Widget>[
              for (final String other in EditSheet.bases)
                if (other != base)
                  OutlinedButton(
                    key: ValueKey<String>('mutate-to-$other'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(56, 48),
                      foregroundColor: context.nucleotideColors.forBase(other),
                    ),
                    onPressed: () => onEdit(Substitution(position, other)),
                    child: Text(other, semanticsLabel: 'Change to $other'),
                  ),
              TextButton(
                key: const ValueKey<String>('mutate-delete'),
                style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                onPressed: () => onEdit(Deletion(position, 1)),
                child: const Text('Delete this base'),
              ),
            ],
          ),
        ],
        if (refusal case final String reason)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: Text(reason, style: theme.textTheme.bodySmall),
          ),
        records,
      ],
    );
  }
}

/// What the edit was, ClinVar's word on exactly it, and the way back.
class _Made extends StatelessWidget {
  const _Made({
    required this.applied,
    required this.onRevert,
    required this.records,
  });

  final AppliedEdit applied;
  final VoidCallback onRevert;
  final Widget records;

  String get _change => switch (applied.edit) {
    Substitution(:final int position, :final String newBase) =>
      '${applied.oldBase} to $newBase at base ${grouped(position)}',
    Deletion(:final int position, :final int length) =>
      length == 1
          ? '${applied.oldBase} deleted at base ${grouped(position)}'
          : '${grouped(length)} bases deleted from base ${grouped(position)}',
    Insertion(:final int position, :final String bases) =>
      '$bases inserted before base ${grouped(position)}',
  };

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          'Edited: $_change',
          key: const ValueKey<String>('mutate-change'),
          style: theme.textTheme.titleSmall,
        ),
        records,
        const SizedBox(height: AppSpacing.lg),
        OutlinedButton(
          key: const ValueKey<String>('mutate-revert'),
          onPressed: onRevert,
          child: const Text('Back to the original'),
        ),
      ],
    );
  }
}
