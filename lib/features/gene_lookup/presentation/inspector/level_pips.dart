import 'package:flutter/material.dart';

import '../../../../core/theme/app_typography.dart';

/// Three pips and a word: how far up its own three bands a model's reading is.
///
/// One meter for both models, drawn in ink rather than colour. Hue on these
/// screens belongs to ClinVar; a model's band is a reading on that model's
/// scale, and giving it a colour of its own made "highly constrained" and
/// "pathogenic" the same amber. The word is the model's own band name, so the
/// meter never needs a legend.
class LevelPips extends StatelessWidget {
  const LevelPips({
    required this.filled,
    required this.label,
    this.trailing,
    this.labelKey,
    super.key,
  }) : assert(filled >= 1 && filled <= 3);

  /// 1, 2 or 3.
  final int filled;
  final String label;

  /// What follows the band on the same line, quieter: where the reading sits
  /// against the genome, say.
  final String? trailing;
  final Key? labelKey;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color ink = theme.colorScheme.onSurface;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        for (int i = 0; i < 3; i++)
          Container(
            width: 15,
            height: 5,
            margin: const EdgeInsets.only(right: 3),
            decoration: BoxDecoration(
              color: i < filled ? ink.withValues(alpha: 0.85) : ink.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        const SizedBox(width: 6),
        Flexible(
          child: Text.rich(
            TextSpan(
              children: <InlineSpan>[
                TextSpan(
                  text: label,
                  style: TextStyle(color: theme.colorScheme.onSurface),
                ),
                if (trailing case final String rest)
                  TextSpan(
                    text: ' · $rest',
                    style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                  ),
              ],
            ),
            key: labelKey,
            style: theme.textTheme.bodySmall?.copyWith(
              fontFamily: AppTypography.sansFamily,
            ),
          ),
        ),
      ],
    );
  }
}
