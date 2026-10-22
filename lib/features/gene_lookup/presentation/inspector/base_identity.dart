import 'package:flutter/material.dart';

import '../../../../core/evidence/gene_impact.dart';
import '../../../../core/theme/anatomy_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/format.dart';
import 'impact_panel.dart' show inkOn;

/// The base as the sheet showed it: its letter on its region's tint, where it
/// sits, what it is in its own terms (its codon and residue), and its
/// coordinate.
class BaseIdentity extends StatelessWidget {
  const BaseIdentity({
    required this.base,
    required this.region,
    required this.detail,
    required this.chromosome,
    required this.tint,
    super.key,
  });

  final BaseImpact base;
  final String region;
  final String detail;
  final String chromosome;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color? fill = tint;
    return Row(
      children: <Widget>[
        if (fill != null) ...<Widget>[
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: fill,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Text(
              base.wildtype,
              style: TextStyle(
                fontFamily: AppTypography.monoFamily,
                fontSize: 21,
                color: inkOn(
                  fill,
                  dark: theme.colorScheme.surface,
                  light: context.anatomyColors.tracer,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (region.isNotEmpty)
                Text(region, style: theme.textTheme.bodyMedium),
              if (detail.isNotEmpty) Text(detail, style: theme.caption),
              Text(
                '$chromosome:${grouped(base.genomic)}',
                style: theme.caption?.copyWith(
                  fontFamily: AppTypography.monoFamily,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
