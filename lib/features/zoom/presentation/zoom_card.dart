import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../domain/zoom_depth.dart';
import '../domain/zoom_facts.dart';

/// The card under the canvas: the stop's place, one line of what is known
/// of it (at the cell, what its drawing shows), and a step either way,
/// `Walk ›` at the last.
///
/// Its height is the tallest stop's words at the reader's text size, so the
/// canvas above it keeps its size as the zoom moves from stop to stop. As
/// the zoom passes from one stop to the next the words slide a few points
/// the way it travels and fade, and under reduced motion they change in
/// place.
class ZoomCard extends StatelessWidget {
  const ZoomCard({
    required this.facts,
    required this.stop,
    required this.nameOf,
    required this.forward,
    required this.onPrevious,
    required this.onNext,
    required this.onWalk,
    super.key,
  });

  final ZoomFacts facts;
  final ZoomStop stop;
  final String Function(ZoomStop stop) nameOf;

  /// Whether the zoom reached [stop] going deeper: the words then come in
  /// from the side its next step lies on.
  final bool forward;

  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onWalk;

  /// How long the words take to change, and how far they slide.
  static const Duration change = Duration(milliseconds: 220);
  static const double slide = 6;

  /// The gap between the title and its line.
  static const double gap = 2;

  static TextStyle titleOf(ThemeData theme) =>
      (theme.textTheme.titleSmall ?? const TextStyle(fontSize: 15)).copyWith(
        color: theme.colorScheme.onSurface,
      );

  /// The line's style: the DNA's bases in the sequence face, the cell's
  /// sentences as prose on a card, and every other line's data with figures
  /// of one width.
  static TextStyle lineOf(ThemeData theme, ZoomStop stop) {
    final TextStyle base =
        theme.textTheme.bodyMedium ?? const TextStyle(fontSize: 14);
    return switch (stop) {
      ZoomStop.dna => AppTypography.sequenceSmall(
        theme.colorScheme.onSurfaceVariant,
      ).copyWith(letterSpacing: 0.5),
      ZoomStop.cell => (theme.cardBody ?? base).copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
      _ => base.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
        fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
      ),
    };
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
            (fact.line.isEmpty
                ? 0
                : gap + measure(fact.line, lineOf(theme, stop))),
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
    final bool reduced = MediaQuery.disableAnimationsOf(context);
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints box) {
        final double inner = box.maxWidth - 2 * AppSpacing.lg;
        final double height = wordsHeight(context, facts, inner);
        final Widget words = _Words(
          key: ValueKey<String>('zoom-card-at-${stop.name}'),
          fact: fact,
          name: nameOf(stop),
          title: titleOf(theme),
          line: lineOf(theme, stop),
        );
        final double shift = (forward ? 1 : -1) * slide / math.max(inner, 1);
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
                SizedBox(
                  height: height,
                  child: reduced
                      ? words
                      : AnimatedSwitcher(
                          duration: change,
                          switchInCurve: Curves.easeOutCubic,
                          switchOutCurve: Curves.easeInCubic,
                          layoutBuilder:
                              (Widget? current, List<Widget> previous) => Stack(
                                alignment: AlignmentDirectional.topStart,
                                children: <Widget>[...previous, ?current],
                              ),
                          transitionBuilder:
                              (Widget child, Animation<double> animation) {
                                // The words coming in arrive from the side
                                // the zoom travels to; those going leave
                                // toward the other.
                                final bool incoming = child.key == words.key;
                                return FadeTransition(
                                  opacity: animation,
                                  child: SlideTransition(
                                    position: Tween<Offset>(
                                      begin: Offset(
                                        incoming ? shift : -shift,
                                        0,
                                      ),
                                      end: Offset.zero,
                                    ).animate(animation),
                                    child: child,
                                  ),
                                );
                              },
                          child: words,
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
                            : ConstrainedBox(
                                constraints: const BoxConstraints(
                                  minHeight: 48,
                                  minWidth: 48,
                                ),
                                child: TextButton(
                                  key: const ValueKey<String>('zoom-walk'),
                                  onPressed: onWalk,
                                  child: const Text(
                                    'Walk ›',
                                    maxLines: 1,
                                    semanticsLabel:
                                        'Open the walk, from its gene',
                                  ),
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

/// A stop's title and line, read aloud under the stop's name.
class _Words extends StatelessWidget {
  const _Words({
    required this.fact,
    required this.name,
    required this.title,
    required this.line,
    super.key,
  });

  final ZoomFact fact;
  final String name;
  final TextStyle title;
  final TextStyle line;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    liveRegion: true,
    label: name,
    child: Column(
      key: const ValueKey<String>('zoom-card-words'),
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          fact.title,
          key: const ValueKey<String>('zoom-card-title'),
          style: title,
        ),
        if (fact.line.isNotEmpty) ...<Widget>[
          const SizedBox(height: ZoomCard.gap),
          Text(
            fact.line,
            key: const ValueKey<String>('zoom-card-line'),
            style: line,
          ),
        ],
      ],
    ),
  );
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
