import 'package:flutter/material.dart';

import '../../../../core/theme/anatomy_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/entities/gene_clinvar.dart';
import '../../domain/entities/protein_constraint.dart';
import '../clinvar/clinvar_colors.dart';
import '../format.dart';
import '../inspector/inspector_sheet.dart';
import '../inspector/level_pips.dart';
import '../inspector/score_bar.dart';

/// A nonmodal sheet: the exposed grid remains interactive at every height.
///
/// The sheet itself — its resting heights, the handoff between resizing and
/// scrolling, the handle, pull-down to dismiss — is [InspectorSheet]. What is
/// here is only what a residue has to say.
class ConstraintPanel extends StatefulWidget {
  const ConstraintPanel({
    required this.residue,
    required this.length,
    required this.controller,
    required this.slide,
    required this.pinIdentity,
    required this.onDismiss,
    this.observedEvidence,
    this.reported = const <String, ClinVarGroup>{},
    super.key,
  });

  static const double minimumSize = InspectorSheet.minimumSize;
  static const double initialSize = InspectorSheet.initialSize;
  static const double maximumSize = InspectorSheet.maximumSize;

  final ResidueConstraint residue;

  /// Residues in the precursor [residue] is numbered against.
  final int length;
  final DraggableScrollableController controller;
  final Animation<Offset> slide;
  final bool pinIdentity;
  final VoidCallback onDismiss;

  /// The ClinVar records at this residue, or null for a gene without them.
  final Widget? observedEvidence;

  /// Amino acids ClinVar has a record for here, each with its most severe
  /// group. Those rows are always shown and carry the group's mark, so the
  /// ranking and the observed changes are read off the same bars.
  final Map<String, ClinVarGroup> reported;

  @override
  State<ConstraintPanel> createState() => _ConstraintPanelState();
}

class _ConstraintPanelState extends State<ConstraintPanel> {
  final InspectorSheetController _inspector = InspectorSheetController();
  bool _expanded = false;
  bool _explanation = false;

  void _toggleExplanation() {
    setState(() => _explanation = !_explanation);
    if (_explanation) {
      // Opening the note while scrolled down brings it into view, and grows the
      // sheet first if there is not room to read it.
      _inspector.reveal(grow: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final Duration crossfade = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 160);
    return InspectorSheet(
      sheet: widget.controller,
      controller: _inspector,
      slide: widget.slide,
      onDismiss: widget.onDismiss,
      pinIdentity: widget.pinIdentity,
      subject: widget.residue.index,
      resizeLabel: 'Resize residue details',
      surfaceKey: const ValueKey<String>('constraint-sheet-surface'),
      scrollKey: const ValueKey<String>('constraint-panel-scroll'),
      handleKey: const ValueKey<String>('constraint-sheet-handle'),
      closeKey: const ValueKey<String>('constraint-sheet-close'),
      identity: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
        child: AnimatedSwitcher(
          duration: crossfade,
          child: _ResidueIdentity(
            key: ValueKey<int>(widget.residue.index),
            residue: widget.residue,
            length: widget.length,
            explanation: _explanation,
            onExplain: _toggleExplanation,
          ),
        ),
      ),
      details: AnimatedSwitcher(
        duration: crossfade,
        child: _Details(
          key: ValueKey<int>(widget.residue.index),
          residue: widget.residue,
          length: widget.length,
          expanded: _expanded,
          explanation: _explanation,
          onExpand: () => setState(() => _expanded = !_expanded),
          observedEvidence: widget.observedEvidence,
          reported: widget.reported,
        ),
      ),
    );
  }
}

class _ResidueIdentity extends StatelessWidget {
  const _ResidueIdentity({
    required this.residue,
    required this.length,
    required this.explanation,
    required this.onExplain,
    super.key,
  });
  final ResidueConstraint residue;
  final int length;
  final bool explanation;
  final VoidCallback onExplain;

  @override
  Widget build(BuildContext context) {
    final ThemeData base = Theme.of(context);
    final ThemeData theme = base.copyWith(
      textTheme: base.textTheme.apply(fontFamily: AppTypography.sansFamily),
    );
    final String? partner = residue.bondPartner;
    return Row(
      children: <Widget>[
        Container(
          width: 42,
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: context.anatomyColors.forResidue(residue.wildtype),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Text(
            residue.wildtype,
            style: TextStyle(
              fontFamily: AppTypography.monoFamily,
              fontSize: 26,
              color: theme.colorScheme.surface,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(residue.title, style: theme.textTheme.titleSmall),
              Text(
                '${residue.domain}${partner == null ? '' : ' · S–S $partner'}',
                style: theme.textTheme.bodySmall,
              ),
              Text(
                'constraint ${residue.conservation.toStringAsFixed(2)} · '
                'rank ${grouped(residue.rank)} of ${grouped(length)}',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'About these scores',
          isSelected: explanation,
          onPressed: onExplain,
          icon: const Icon(Icons.info_outline, size: 20),
        ),
      ],
    );
  }
}

class _Details extends StatelessWidget {
  const _Details({
    required this.residue,
    required this.length,
    required this.expanded,
    required this.explanation,
    required this.onExpand,
    required this.reported,
    this.observedEvidence,
    super.key,
  });
  final ResidueConstraint residue;
  final int length;
  final bool expanded;
  final bool explanation;
  final VoidCallback onExpand;
  final Map<String, ClinVarGroup> reported;
  final Widget? observedEvidence;

  /// How many of the ranking lead the collapsed list.
  static const int _lead = 6;

  @override
  Widget build(BuildContext context) {
    final ThemeData base = Theme.of(context);
    final ThemeData theme = base.copyWith(
      textTheme: base.textTheme.apply(fontFamily: AppTypography.sansFamily),
    );
    final Color bar = theme.colorScheme.onSurfaceVariant;
    final List<SubstitutionScore> ranked = residue.ranked;
    // The top six, and every change ClinVar has a record for wherever it ranks:
    // an observed change hidden under "14 more" was the one row a reader came
    // to this residue to see.
    final List<int> visible = <int>[
      for (int i = 0; i < ranked.length; i++)
        if (expanded || i < _lead || reported.containsKey(ranked[i].aminoAcid))
          i,
    ];
    final List<int> hidden = <int>[
      for (int i = 0; i < ranked.length; i++)
        if (!visible.contains(i)) i,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const SizedBox(height: 12),
        LevelPips(
          filled: switch (residue.level) {
            ConstraintLevel.high => 3,
            ConstraintLevel.middle => 2,
            ConstraintLevel.low => 1,
          },
          label: residue.level.label,
        ),
        if (explanation) ...<Widget>[
          const SizedBox(height: 12),
          Text(
            // The count was insulin's 109 for every protein.
            'ESM-2 650M masked marginals, precomputed: this position masked, '
            'all 20 amino acids scored against the other '
            '${grouped(length - 1)}. Score = ln p(aa)/p(WT), so WT is 0. '
            'Constraint = 1 − entropy of that prediction, min–max scaled '
            'within this protein.',
            key: const ValueKey<String>('constraint-explanation'),
            style: theme.textTheme.bodySmall,
          ),
        ],
        const SizedBox(height: 16),
        Text(
          'Substitutions · ln p(aa)/p(WT)',
          style: theme.textTheme.titleSmall,
        ),
        const SizedBox(height: 6),
        // Clamped at both ends, and said at both: a residue where every change
        // scores below −10 draws every bar empty.
        ScoreScale(
          low: '−10 or lower',
          high: '0 or higher',
          style: theme.textTheme.labelSmall,
        ),
        const SizedBox(height: 4),
        for (int k = 0; k < visible.length; k++) ...<Widget>[
          // Rows skipped between two shown ones: the ranking is not contiguous
          // here, and a reader should not take the next row for the next rank.
          if (k > 0 && visible[k] != visible[k - 1] + 1)
            Padding(
              key: ValueKey<String>('substitution-gap-${visible[k]}'),
              padding: const EdgeInsets.only(left: 6, top: 1, bottom: 1),
              child: _Gap(colour: bar),
            ),
          SubstitutionBar(
            score: ranked[visible[k]],
            native: ranked[visible[k]].aminoAcid == residue.wildtype,
            color: bar,
            reported: reported[ranked[visible[k]].aminoAcid],
          ),
        ],
        if (expanded || hidden.isNotEmpty)
          TextButton(
            key: const ValueKey<String>('constraint-expand'),
            onPressed: onExpand,
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              alignment: Alignment.centerLeft,
              minimumSize: const Size(0, 40),
            ),
            child: Text(
              expanded
                  ? 'Show top six'
                  : '${hidden.length} more · all ≤ '
                        '${formatScore(ranked[hidden.first].score)}',
            ),
          ),
        Divider(height: 12, color: theme.colorScheme.outlineVariant),
        const SizedBox(height: 6),
        Text(residue.note, style: theme.textTheme.bodySmall),
        ?observedEvidence,
      ],
    );
  }
}

/// One amino acid's row in the residue panel.
class SubstitutionBar extends StatelessWidget {
  const SubstitutionBar({
    required this.score,
    required this.native,
    required this.color,
    this.reported,
    super.key,
  });
  final SubstitutionScore score;
  final bool native;
  final Color color;

  /// The most severe ClinVar group recorded for this change, if any.
  final ClinVarGroup? reported;

  @override
  Widget build(BuildContext context) => ScoreBar(
    label: score.aminoAcid,
    fraction: score.barFraction,
    value: formatScore(score.score),
    native: native,
    color: color,
    valueKey: ValueKey<String>('substitution-score-${score.aminoAcid}'),
    tag: reported == null
        ? null
        : ClinVarDot(
            key: ValueKey<String>('substitution-clinvar-${score.aminoAcid}'),
            group: reported!,
            size: 9,
          ),
    semanticsLabel:
        '${score.aminoAcid}${native ? ', wild type' : ''}, '
        'score ${score.score.toStringAsFixed(3)}'
        '${reported == null ? '' : ', ClinVar ${reported!.label}'}',
  );
}

/// A vertical ellipsis, drawn rather than typed: rows of the ranking skipped
/// between two shown ones. Three dots in the letter column, no taller than a
/// line of type.
class _Gap extends StatelessWidget {
  const _Gap({required this.colour});

  final Color colour;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (int i = 0; i < 3; i++)
          Container(
            width: 2.5,
            height: 2.5,
            margin: const EdgeInsets.symmetric(vertical: 1.25),
            decoration: BoxDecoration(color: colour, shape: BoxShape.circle),
          ),
      ],
    ),
  );
}
