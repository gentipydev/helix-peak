import 'package:flutter/material.dart';

import '../../core/theme/app_spacing.dart';

/// The wait for a record, laid out as the walk that replaces it.
///
/// It stands where the walk will: the strip of prose under the header, a
/// hair, the gene's map across the whole width, and the band the stage bar
/// floats in at the foot, left empty. What lands takes the places the wait
/// held for it rather than a different page arriving — the placeholder used
/// to be a report's title and cards, and the gene map replaced it outright.
///
/// No stubs for the stage names: how many pages a walk has is only known once
/// the record is in, and a wrong count would jump.
class LoadingView extends StatefulWidget {
  const LoadingView({required this.label, super.key});

  final String label;

  /// The walk's own measures, which it keeps private to its screen: the
  /// context strip under the header, the hair above the grid, and the band at
  /// the foot the stage bar floats in.
  static const double _strip = 52;
  static const double _inset = AppSpacing.xs;
  static const double _band = AppSpacing.sm + 48 + AppSpacing.lg;

  @override
  State<LoadingView> createState() => _LoadingViewState();
}

class _LoadingViewState extends State<LoadingView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
      _controller.value = 1;
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// [child], breathing while the fetch runs.
  Widget _pulsing(Widget child) => AnimatedBuilder(
    animation: _controller,
    builder: (BuildContext context, Widget? child) {
      return Opacity(opacity: 0.35 + 0.35 * _controller.value, child: child);
    },
    child: child,
  );

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    // The strip grows with type up to where the walk's stops growing.
    final double strip =
        LoadingView._strip *
        MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.2);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SizedBox(
          height: strip,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            // Clamped as the walk's strip is, so the label fits the height.
            child: MediaQuery.withClampedTextScaling(
              maxScaleFactor: 1.2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Flexible(
                        child: Text(
                          widget.label,
                          style: theme.textTheme.labelSmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _pulsing(const _SkeletonBlock(width: 140, height: 10)),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: LoadingView._inset),
        Expanded(
          child: _pulsing(
            const _SkeletonBlock(
              key: ValueKey<String>('loading-map'),
              radius: 0,
            ),
          ),
        ),
        const SizedBox(height: LoadingView._band),
      ],
    );
  }
}

class _SkeletonBlock extends StatelessWidget {
  const _SkeletonBlock({
    this.width,
    this.height,
    this.radius = AppRadius.sm,
    super.key,
  });

  /// Null for as much as the block is given.
  final double? width;
  final double? height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}
