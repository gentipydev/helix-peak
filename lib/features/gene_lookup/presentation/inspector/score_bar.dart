import 'package:flutter/material.dart';

import '../../../../core/theme/app_typography.dart';

/// One row of a score list: the thing being scored, a bar, and its number.
///
/// Shared by the two inspectors rather than copied, because they are the same
/// reading at two zoom levels — twenty amino acids against a residue, three
/// bases against a nucleotide — and a reader who learns the row once should not
/// have to learn it again. What differs is only what the row is measuring, so
/// the scale, the units and the wording stay with the caller.
class ScoreBar extends StatelessWidget {
  const ScoreBar({
    required this.label,
    required this.fraction,
    required this.value,
    required this.native,
    required this.color,
    required this.semanticsLabel,
    this.valueKey,
    this.tag,
    super.key,
  });

  /// The one-letter code this row is for.
  final String label;

  /// Where the bar fills to, 0 to 1, on whatever scale the caller named.
  final double fraction;

  /// The number, already formatted: this widget never decides how a score reads.
  final String value;

  /// Whether this row is the thing that is actually there — the wildtype
  /// residue, the reference base — which is drawn as an outline rather than a
  /// fill, so the bars carrying information are the filled ones.
  final bool native;

  final Color color;
  final String semanticsLabel;
  final ValueKey<String>? valueKey;

  /// What else is true of this row, in the column the wildtype's "WT" uses:
  /// a ClinVar mark for a reported change, `=` for a base that keeps its amino
  /// acid. One column, one question — what is special about this row — so a
  /// row never grows a second line to say it. The native row keeps its "WT".
  final Widget? tag;

  @override
  Widget build(BuildContext context) {
    final ThemeData base = Theme.of(context);
    final ThemeData theme = base.copyWith(
      textTheme: base.textTheme.apply(fontFamily: AppTypography.sansFamily),
    );
    final Widget letter = Text(
      label,
      style: const TextStyle(
        fontFamily: AppTypography.monoFamily,
        fontSize: 15,
        height: 1,
      ),
    );
    final Widget nativeLabel = Text(
      'WT',
      textAlign: TextAlign.right,
      style: theme.textTheme.labelSmall?.copyWith(fontSize: 10, height: 1),
    );
    final Widget number = Text(
      value,
      key: valueKey,
      textAlign: TextAlign.right,
      style: const TextStyle(
        fontFamily: AppTypography.monoFamily,
        fontSize: 13,
        height: 1,
      ),
    );
    final Widget bar = SizedBox(
      height: 17,
      child: Stack(
        alignment: Alignment.centerLeft,
        children: <Widget>[
          Container(
            height: 7,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          FractionallySizedBox(
            widthFactor: fraction.clamp(0.0, 1.0),
            child: Container(
              height: 7,
              decoration: BoxDecoration(
                color: native ? null : color,
                border: native ? Border.all(color: color) : null,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        ],
      ),
    );
    final bool stacked = stackScoreLabels(context);
    return Semantics(
      label: semanticsLabel,
      excludeSemantics: true,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: stacked ? 8 : 3),
        child: stacked
            ? Column(
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      letter,
                      const Spacer(),
                      if (native) ...<Widget>[
                        nativeLabel,
                        const SizedBox(width: 12),
                      ] else if (tag case final Widget mark) ...<Widget>[
                        mark,
                        const SizedBox(width: 12),
                      ],
                      number,
                    ],
                  ),
                  const SizedBox(height: 4),
                  bar,
                ],
              )
            : Row(
                children: <Widget>[
                  SizedBox(width: 28, child: letter),
                  Expanded(child: bar),
                  SizedBox(
                    width: 44,
                    child: native
                        ? nativeLabel
                        : tag == null
                        ? null
                        : Align(
                            alignment: AlignmentDirectional.centerEnd,
                            child: tag,
                          ),
                  ),
                  SizedBox(width: 64, child: number),
                ],
              ),
      ),
    );
  }
}

/// Large text gets a full-width bar below its labels, preserving both the
/// requested type size and the shared visual scale.
bool stackScoreLabels(BuildContext context) =>
    MediaQuery.textScalerOf(context).scale(13) > 19.5;
