import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../domain/zoom_depth.dart';
import '../domain/zoom_facts.dart';

/// The level card under the canvas: the stop, the place, one line of what is
/// known of it and where that comes from, and the zoom's controls.
///
/// Its height is the tallest stop's content at the reader's text size, so the
/// canvas above it keeps its size as the zoom moves from stop to stop.
class ZoomCard extends StatelessWidget {
  const ZoomCard({
    required this.facts,
    required this.stop,
    required this.nameOf,
    required this.playing,
    required this.onPrevious,
    required this.onNext,
    required this.onPlay,
    required this.onAbout,
    required this.onWalk,
    super.key,
  });

  final ZoomFacts facts;
  final ZoomStop stop;
  final String Function(ZoomStop stop) nameOf;
  final bool playing;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onPlay;
  final VoidCallback onAbout;
  final VoidCallback onWalk;

  static TextStyle overlineOf(ThemeData theme) =>
      (theme.textTheme.labelSmall ?? const TextStyle(fontSize: 12)).copyWith(
        color: theme.colorScheme.onSurfaceVariant,
        letterSpacing: 1.2,
      );

  static TextStyle titleOf(ThemeData theme) =>
      (theme.textTheme.titleSmall ?? const TextStyle(fontSize: 15)).copyWith(
        color: theme.colorScheme.onSurface,
      );

  static TextStyle lineOf(ThemeData theme, ZoomStop stop) {
    final TextStyle base =
        theme.textTheme.bodyMedium ?? const TextStyle(fontSize: 14);
    return stop == ZoomStop.dna
        ? AppTypography.sequenceSmall(
            theme.colorScheme.onSurfaceVariant,
          ).copyWith(letterSpacing: 0.5)
        : base.copyWith(
            fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
          );
  }

  /// The height every stop's words take at [width], at the reader's text
  /// size: the card is given the tallest.
  static double wordsHeight(
    BuildContext context,
    ZoomFacts facts,
    double width,
  ) {
    final ThemeData theme = Theme.of(context);
    final TextScaler scaler = MediaQuery.textScalerOf(context);
    final TextDirection direction = Directionality.of(context);
    double measure(String text, TextStyle style) {
      final TextPainter painter = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: direction,
        textScaler: scaler,
      )..layout(maxWidth: width);
      final double h = painter.height;
      painter.dispose();
      return h;
    }

    double tallest = 0;
    for (final ZoomStop stop in ZoomStop.values) {
      final ZoomFact fact = facts.of(stop);
      tallest = math.max(
        tallest,
        measure(fact.title, titleOf(theme)) +
            measure(fact.line, lineOf(theme, stop)),
      );
    }
    return tallest.ceilToDouble();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ZoomFact fact = facts.of(stop);
    final int last = ZoomStop.values.length - 1;
    final ZoomStop? previous = stop.index > 0
        ? ZoomStop.values[stop.index - 1]
        : null;
    final ZoomStop? next = stop.index < last
        ? ZoomStop.values[stop.index + 1]
        : null;
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints box) {
        final double inner = box.maxWidth - 2 * AppSpacing.lg;
        final double words = wordsHeight(context, facts, inner);
        return DecoratedBox(
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerLow,
            border: Border(top: BorderSide(color: theme.colorScheme.outline)),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.xs,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        nameOf(stop).toUpperCase(),
                        key: const ValueKey<String>('zoom-card-stop'),
                        style: overlineOf(theme),
                      ),
                    ),
                    _SourceTag(fact: fact),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                SizedBox(
                  height: words,
                  child: Semantics(
                    liveRegion: true,
                    container: true,
                    child: Column(
                      key: const ValueKey<String>('zoom-card-words'),
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          fact.title,
                          key: const ValueKey<String>('zoom-card-title'),
                          style: titleOf(theme),
                        ),
                        Text(
                          fact.line,
                          key: const ValueKey<String>('zoom-card-line'),
                          style: lineOf(theme, stop),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: _StepButton(
                          key: const ValueKey<String>('zoom-previous'),
                          label: previous == null ? null : nameOf(previous),
                          back: true,
                          onPressed: previous == null ? null : onPrevious,
                        ),
                      ),
                    ),
                    IconButton(
                      key: const ValueKey<String>('zoom-play'),
                      tooltip: playing ? 'Pause the dive' : 'Play the dive',
                      onPressed: onPlay,
                      icon: Icon(
                        playing
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                      ),
                    ),
                    IconButton(
                      key: const ValueKey<String>('zoom-about'),
                      tooltip: 'About this zoom',
                      onPressed: onAbout,
                      icon: const Icon(Icons.info_outline_rounded),
                    ),
                    Expanded(
                      child: Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: next != null
                            ? _StepButton(
                                key: const ValueKey<String>('zoom-next'),
                                label: nameOf(next),
                                back: false,
                                onPressed: onNext,
                              )
                            : TextButton(
                                key: const ValueKey<String>('zoom-walk'),
                                onPressed: onWalk,
                                child: const Text(
                                  'Walk ›',
                                  maxLines: 1,
                                  semanticsLabel: 'Open the walk, from its gene',
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Where the card's line comes from: a source, or `drawn`.
class _SourceTag extends StatelessWidget {
  const _SourceTag({required this.fact});

  final ZoomFact fact;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color colour = fact.isDrawn
        ? theme.colorScheme.onSurfaceVariant
        : theme.colorScheme.primary;
    return DecoratedBox(
      key: const ValueKey<String>('zoom-card-source'),
      decoration: BoxDecoration(
        border: Border.all(color: colour.withValues(alpha: 0.6)),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: 2,
        ),
        child: Text(
          fact.source,
          style: (theme.textTheme.labelSmall ?? const TextStyle()).copyWith(
            color: colour,
          ),
        ),
      ),
    );
  }
}

/// ‹ Tissue, or Nucleus ›: a step to the stop either side, named.
class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.label,
    required this.back,
    required this.onPressed,
    super.key,
  });

  final String? label;
  final bool back;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final String? name = label;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
      child: TextButton(
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        ),
        onPressed: onPressed,
        child: Text(
          name == null ? '' : (back ? '‹ $name' : '$name ›'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          semanticsLabel: name == null
              ? null
              : (back ? 'Back to $name' : 'On to $name'),
        ),
      ),
    );
  }
}
