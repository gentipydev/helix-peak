import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/nucleotide_colors.dart';

/// Renders sequence data as colour-coded monospace text.
///
/// Two details matter here. Monospace is non-negotiable — column alignment is
/// meaningful in sequence data. And consecutive identical bases are merged
/// into a single span rather than one span per character, which keeps a long
/// sequence from becoming tens of thousands of `TextSpan` objects.
class SequenceView extends StatelessWidget {
  const SequenceView({
    required this.bases,
    this.maxBases = 600,
    super.key,
  });

  final String bases;

  /// Preview cap. Whole genomes are legitimate input; rendering all of one is
  /// not a legitimate use of a text widget.
  final int maxBases;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final NucleotideColors palette = context.nucleotideColors;
    final bool truncated = bases.length > maxBases;
    final String shown = truncated ? bases.substring(0, maxBases) : bases;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainer,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: theme.colorScheme.outline),
          ),
          child: SelectableText.rich(
            TextSpan(children: _buildSpans(shown, palette)),
            style: AppTypography.sequenceBody(theme.colorScheme.onSurface),
          ),
        ),
        if (truncated) ...<Widget>[
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Showing first $maxBases of ${bases.length} bases.',
            style: theme.textTheme.labelSmall,
          ),
        ],
      ],
    );
  }

  /// Collapses runs of the same base into one span each.
  List<TextSpan> _buildSpans(String sequence, NucleotideColors palette) {
    final List<TextSpan> spans = <TextSpan>[];
    if (sequence.isEmpty) {
      return spans;
    }

    int runStart = 0;
    for (int i = 1; i <= sequence.length; i++) {
      final bool atEnd = i == sequence.length;
      if (atEnd || sequence[i] != sequence[runStart]) {
        spans.add(
          TextSpan(
            text: sequence.substring(runStart, i),
            style: TextStyle(color: palette.forBase(sequence[runStart])),
          ),
        );
        runStart = i;
      }
    }
    return spans;
  }
}
