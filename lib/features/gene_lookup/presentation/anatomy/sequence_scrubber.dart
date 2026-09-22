import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';

/// A thumb down the right edge of a page too long to scroll through by hand.
///
/// Dystrophin's protein page is thirteen screens of residues with nothing to
/// say where a reader is. Dragging the thumb moves through the whole page at
/// once, and where the page names its rows, the bubble beside it names where
/// the drag has got to — the row's own number and, where the page has them,
/// the domain it is in.
class SequenceScrubber extends StatefulWidget {
  const SequenceScrubber({
    required this.controller,
    this.labelAt,
    this.landmarks = const <(double, String)>[],
    this.minScreens = 1,
    super.key,
  });

  /// The page's own scroll.
  final ScrollController controller;

  /// What the row at the top of the view is called at a scroll offset; null
  /// for a thumb with no bubble.
  final String? Function(double offset)? labelAt;

  /// Named places down the page, as scroll offset and name, in order.
  final List<(double, String)> landmarks;

  /// How many screens long the page has to be before the thumb shows. One is
  /// any page that scrolls at all.
  final double minScreens;

  /// The strip it takes on the right edge, which is also its hit area.
  static const double width = 28;

  static const double _thumb = 40;

  @override
  State<SequenceScrubber> createState() => _SequenceScrubberState();
}

class _SequenceScrubberState extends State<SequenceScrubber> {
  bool _dragging = false;

  @override
  void initState() {
    super.initState();
    // The scroll has no extent until the page under it has laid out once.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  void _scrubTo(double y, double height) {
    if (!widget.controller.hasClients) {
      return;
    }
    final ScrollPosition position = widget.controller.position;
    final double fraction =
        ((y - SequenceScrubber._thumb / 2) / (height - SequenceScrubber._thumb))
            .clamp(0.0, 1.0);
    widget.controller.jumpTo(fraction * position.maxScrollExtent);
  }

  String? _landmarkAt(double offset) {
    String? name;
    for (final (double at, String label) in widget.landmarks) {
      if (at > offset + 1) {
        break;
      }
      name = label;
    }
    return name;
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (BuildContext context, Widget? _) {
        if (!widget.controller.hasClients) {
          return const SizedBox.shrink();
        }
        final ScrollPosition position = widget.controller.position;
        if (!position.hasContentDimensions ||
            position.maxScrollExtent <= 0 ||
            position.maxScrollExtent <
                position.viewportDimension * (widget.minScreens - 1)) {
          return const SizedBox.shrink();
        }
        return LayoutBuilder(
          builder: (BuildContext context, BoxConstraints box) {
            final double height = box.maxHeight;
            final double travel = height - SequenceScrubber._thumb;
            final double top =
                (position.pixels / position.maxScrollExtent).clamp(0.0, 1.0) *
                travel;
            final double extent =
                position.maxScrollExtent + position.viewportDimension;
            final String? label = widget.labelAt?.call(position.pixels);
            final String? landmark = _landmarkAt(position.pixels);
            final String bubble = <String>[?label, ?landmark].join(' · ');
            return Semantics(
              container: true,
              label: 'Scrub through the page',
              value: bubble,
              child: GestureDetector(
                key: const ValueKey<String>('sequence-scrubber'),
                behavior: HitTestBehavior.translucent,
                onVerticalDragStart: (DragStartDetails d) {
                  setState(() => _dragging = true);
                  _scrubTo(d.localPosition.dy, height);
                },
                onVerticalDragUpdate: (DragUpdateDetails d) =>
                    _scrubTo(d.localPosition.dy, height),
                onVerticalDragEnd: (_) => setState(() => _dragging = false),
                onVerticalDragCancel: () => setState(() => _dragging = false),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: <Widget>[
                    Positioned(
                      right: 7,
                      top: 0,
                      bottom: 0,
                      width: 2,
                      child: ColoredBox(
                        color: theme.colorScheme.outline.withValues(alpha: 0.6),
                      ),
                    ),
                    for (final (double at, String _) in widget.landmarks)
                      Positioned(
                        right: 5,
                        top: at / extent * height,
                        width: 6,
                        height: 1,
                        child: ColoredBox(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    Positioned(
                      right: 4,
                      top: top,
                      width: 8,
                      height: SequenceScrubber._thumb,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: _dragging
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurfaceVariant,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    if (_dragging && bubble.isNotEmpty)
                      Positioned(
                        right: SequenceScrubber.width,
                        top: top + SequenceScrubber._thumb / 2 - 14,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHigh,
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.sm,
                              vertical: AppSpacing.xs,
                            ),
                            child: Text(
                              bubble,
                              style: AppTypography.sequenceSmall(
                                theme.colorScheme.onSurface,
                              ).copyWith(letterSpacing: 0),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
