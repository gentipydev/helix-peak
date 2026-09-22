import 'package:flutter/material.dart';

import '../../../../core/theme/app_typography.dart';
import '../../domain/entities/variant_evidence.dart';
import '../format.dart';
import 'evidence_row.dart';

/// Whether a sheet has ClinVar records to show, or why not.
enum ClinVarStatus { ready, loading, unavailable }

/// What a residue or base sheet says about ClinVar: the records at this place,
/// and nothing about ClinVar in general.
///
/// The snapshot date, its coverage and what a record is and is not all live
/// once, in the overview and the About sheet. Here there is one header line,
/// the rows, and the way to everything else. A gene with no snapshot builds no
/// block at all; the About sheet says it is not yet included.
class ClinVarBlock extends StatefulWidget {
  const ClinVarBlock({
    required this.status,
    required this.records,
    required this.scope,
    required this.total,
    required this.column,
    this.allele = false,
    this.place = true,
    this.onOpenAll,
    this.onResidue,
    this.onBase,
    super.key,
  });

  final ClinVarStatus status;

  /// The records at this residue or base, in transcript order.
  final List<VariantEvidence> records;

  /// How the sheet names where it is: `Cys96`, `c.287`.
  final String scope;

  /// Records in the whole snapshot, for the way out to all of them.
  final int total;
  final EvidenceColumn column;
  final bool allele;
  final bool place;
  final VoidCallback? onOpenAll;
  final ValueChanged<int>? onResidue;
  final ValueChanged<int>? onBase;

  @override
  State<ClinVarBlock> createState() => _ClinVarBlockState();
}

class _ClinVarBlockState extends State<ClinVarBlock> {
  /// One record open at a time: the detail is for reading one, and two open
  /// ones would put the same labels on screen twice.
  String? _open;

  @override
  void didUpdateWidget(ClinVarBlock old) {
    super.didUpdateWidget(old);
    if (old.scope != widget.scope) {
      _open = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData base = Theme.of(context);
    // The rows read the theme's small styles, which name no family of their
    // own; the sheets around them apply the sans the same way.
    final ThemeData theme = base.copyWith(
      textTheme: base.textTheme.apply(fontFamily: AppTypography.sansFamily),
    );
    final Color muted = theme.colorScheme.onSurfaceVariant;
    final int count = widget.records.length;
    final String headline = switch (widget.status) {
      ClinVarStatus.loading => 'ClinVar · loading…',
      ClinVarStatus.unavailable => 'ClinVar · unavailable',
      ClinVarStatus.ready when count == 0 =>
        'ClinVar · none at ${widget.scope} in this snapshot',
      ClinVarStatus.ready =>
        'ClinVar · $count record${count == 1 ? '' : 's'} here',
    };
    return Theme(
      data: theme,
      child: Column(
      key: const ValueKey<String>('clinvar-block'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Divider(height: 24, color: theme.colorScheme.outlineVariant),
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                headline,
                key: const ValueKey<String>('clinvar-headline'),
                style: theme.textTheme.titleSmall?.copyWith(
                  color: widget.status == ClinVarStatus.ready && count > 0
                      ? theme.colorScheme.onSurface
                      : muted,
                ),
              ),
            ),
            if (widget.onOpenAll != null &&
                widget.status == ClinVarStatus.ready)
              TextButton(
                key: const ValueKey<String>('clinvar-open-all'),
                onPressed: widget.onOpenAll,
                style: TextButton.styleFrom(
                  minimumSize: const Size(0, 40),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  foregroundColor: theme.colorScheme.onSurface,
                ),
                child: Text(
                  'All ${grouped(widget.total)} ›',
                  style: const TextStyle(
                    fontFamily: AppTypography.sansFamily,
                  ),
                ),
              ),
          ],
        ),
        for (final VariantEvidence record in widget.records)
          EvidenceRow(
            evidence: record,
            column: widget.column,
            allele: widget.allele,
            place: widget.place,
            expanded: _open == record.variant.id,
            onToggle: () => setState(
              () => _open = _open == record.variant.id
                  ? null
                  : record.variant.id,
            ),
            onResidue: widget.onResidue,
            onBase: widget.onBase,
          ),
      ],
      ),
    );
  }
}
