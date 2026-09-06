import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/nucleotide_colors.dart';
import '../../domain/entities/nucleotide_counts.dart';

/// Base composition as a proportional bar with a legend.
///
/// The legend is not optional decoration: colour is never the sole carrier of
/// meaning here, so every segment is also named by its letter and its count.
class CompositionBar extends StatelessWidget {
  const CompositionBar({required this.counts, super.key});

  final NucleotideCounts counts;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final NucleotideColors palette = context.nucleotideColors;
    final int total = counts.total;

    final List<(String, int, Color)> segments = <(String, int, Color)>[
      ('A', counts.adenine, palette.adenine),
      ('T', counts.thymine, palette.thymine),
      ('G', counts.guanine, palette.guanine),
      ('C', counts.cytosine, palette.cytosine),
      if (counts.other > 0) ('N', counts.other, palette.unknown),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          child: SizedBox(
            height: 10,
            child: Row(
              children: <Widget>[
                for (final (String _, int count, Color color) in segments)
                  if (count > 0)
                    Expanded(
                      flex: count,
                      child: ColoredBox(color: color),
                    ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Wrap(
          spacing: AppSpacing.xl,
          runSpacing: AppSpacing.md,
          children: <Widget>[
            for (final (String label, int count, Color color) in segments)
              _LegendEntry(
                label: label,
                count: count,
                percent: total == 0 ? 0 : count / total * 100,
                color: color,
              ),
          ],
        ),
        if (total == 0) ...<Widget>[
          const SizedBox(height: AppSpacing.sm),
          Text('No bases to display.', style: theme.textTheme.labelSmall),
        ],
      ],
    );
  }
}

class _LegendEntry extends StatelessWidget {
  const _LegendEntry({
    required this.label,
    required this.count,
    required this.percent,
    required this.color,
  });

  final String label;
  final int count;
  final double percent;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(
          label,
          style: AppTypography.sequenceSmall(color).copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(
          '$count · ${percent.toStringAsFixed(1)}%',
          style: theme.textTheme.labelSmall,
        ),
      ],
    );
  }
}
