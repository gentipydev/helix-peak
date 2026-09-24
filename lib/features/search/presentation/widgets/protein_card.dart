import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../gene_lookup/domain/entities/protein_target.dart';
import '../../../gene_lookup/presentation/format.dart';

/// One protein on the search list: what it is called, its gene symbol, the
/// figures a reader weighs it by, and up to two lines on why they might open it.
///
/// The symbol is set in the mono face and given the accent, because it is the
/// thing the reader will have typed to get here and the thing the walk's first
/// page is titled with. The spec line comes before the summary: a reader who
/// knows what insulin is decides between twenty proteins on their sizes.
class ProteinCard extends StatelessWidget {
  const ProteinCard({required this.target, required this.onTap, super.key});

  final ProteinTarget target;
  final VoidCallback onTap;

  /// `P01308 · 110 aa · 3 exons · 3 chains · 3 S–S`, leaving out a count of
  /// one chain or no bridges, which say nothing.
  static String specOf(ProteinTarget target) {
    final ProteinFacts facts = target.facts;
    return <String>[
      target.uniprot,
      '${grouped(facts.residues)} aa',
      '${facts.exons} ${facts.exons == 1 ? 'exon' : 'exons'}',
      if (facts.chains > 1) '${facts.chains} chains',
      if (facts.bridges > 0) '${facts.bridges} S\u2013S',
    ].join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;

    return Semantics(
      button: true,
      label:
          '${target.display}, gene ${target.gene}. ${specOf(target)}. '
          '${target.summary}',
      excludeSemantics: true,
      // Ink paints on the nearest Material. Without one here that is the
      // Scaffold's, which the list does not clip, so cards scrolled up would
      // draw over the search field.
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Ink(
            decoration: BoxDecoration(
              color: colors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: colors.outline, width: 0.5),
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Flexible(
                            child: Text(
                              target.display,
                              style: theme.textTheme.titleSmall,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Text(
                            target.gene,
                            style: AppTypography.sequenceSmall(colors.primary),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        specOf(target),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.sequenceSmall(
                          colors.onSurfaceVariant,
                        ).copyWith(fontSize: 11, letterSpacing: 0),
                      ),
                      const SizedBox(height: 2),
                      // Two lines: at one, every summary was cut about forty
                      // characters in, which was most of what told one
                      // protein from the next.
                      Text(
                        target.summary,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontSize: 13,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 24,
                  color: colors.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
