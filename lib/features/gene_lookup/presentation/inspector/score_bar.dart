import 'dart:math' as math;

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

  /// The columns either side of the bar, which [ScoreScale] keeps clear so
  /// its ends stand over the bar's: the letter before it, and the tag and the
  /// number after it.
  static const double letterColumn = 28;
  static const double tagColumn = 44;
  static const double numberColumn = 64;

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
      style: theme.textTheme.labelSmall?.copyWith(fontSize: 11, height: 1),
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
                  SizedBox(width: letterColumn, child: letter),
                  Expanded(child: bar),
                  SizedBox(
                    width: tagColumn,
                    child: native
                        ? nativeLabel
                        : tag == null
                        ? null
                        : Align(
                            alignment: AlignmentDirectional.centerEnd,
                            child: tag,
                          ),
                  ),
                  SizedBox(width: numberColumn, child: number),
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

/// The scale over a list of [ScoreBar]s: what an empty bar stands for at the
/// bars' start, and what a full one does at their end.
///
/// One row for both sheets, as the bars under it are one row. Its ends are
/// words — "−10 or lower", "40 or higher" — and on a narrow phone with type
/// turned up the two can be wider together than the bars they label. They are
/// then drawn a little smaller, rather than run off the edge or cut short.
class ScoreScale extends StatelessWidget {
  const ScoreScale({
    required this.low,
    required this.high,
    required this.style,
    this.trailing = 0,
    this.highKey,
    super.key,
  });

  /// What an empty bar stands for, and what a full one does.
  final String low;
  final String high;
  final TextStyle? style;

  /// Room the rows below keep after their number — a chevron's — which the
  /// scale keeps too, so that its ends stay over the bars' ends.
  final double trailing;
  final Key? highKey;

  /// The least room between the two ends: enough that they read as two
  /// ends, not as one phrase, when they are drawn close.
  static const double _gap = 16;

  @override
  Widget build(BuildContext context) {
    final bool stacked = stackScoreLabels(context);
    final TextStyle effective = DefaultTextStyle.of(context).style.merge(style);
    final TextScaler scaler = MediaQuery.textScalerOf(context);
    double width(String text) {
      final TextPainter painter = TextPainter(
        text: TextSpan(text: text, style: effective),
        textDirection: TextDirection.ltr,
        textScaler: scaler,
        maxLines: 1,
      )..layout();
      final double width = painter.width;
      painter.dispose();
      return width;
    }

    return Row(
      children: <Widget>[
        if (!stacked) const SizedBox(width: ScoreBar.letterColumn),
        Expanded(
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints box) {
              // The ends at their own size with the room between them, or at
              // the least room and scaled to fit. A measure a hair out is a
              // hair of scaling, never an overflow.
              final double spare = box.maxWidth - width(low) - width(high);
              return FittedBox(
                fit: BoxFit.scaleDown,
                alignment: AlignmentDirectional.centerStart,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(low, style: style, maxLines: 1),
                    SizedBox(width: math.max(_gap, spare)),
                    Text(high, key: highKey, style: style, maxLines: 1),
                  ],
                ),
              );
            },
          ),
        ),
        SizedBox(
          width:
              (stacked ? 0 : ScoreBar.tagColumn + ScoreBar.numberColumn) +
              trailing,
        ),
      ],
    );
  }
}
