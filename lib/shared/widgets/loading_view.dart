import 'package:flutter/material.dart';

import '../../core/theme/app_spacing.dart';

/// Loading treatment for content that is about to arrive.
///
/// Skeleton blocks in the shape of the eventual result, rather than a centred
/// spinner: the layout does not jump when data lands, and the user gets a
/// preview of what is coming. The pulse is slow enough to read as "working"
/// rather than "hurrying".
class LoadingView extends StatefulWidget {
  const LoadingView({required this.label, super.key});

  final String label;

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
    // MediaQuery is unavailable in initState, and the setting can change while
    // the app is running, so the check belongs here.
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

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.screenPadding),
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
              Text(widget.label, style: theme.textTheme.labelSmall),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          AnimatedBuilder(
            animation: _controller,
            builder: (BuildContext context, Widget? child) {
              return Opacity(
                opacity: 0.35 + 0.35 * _controller.value,
                child: child,
              );
            },
            // Built once and reused across every tick — the pulse only changes
            // opacity, so there is no reason to rebuild the skeleton itself.
            child: const _SkeletonBody(),
          ),
        ],
      ),
    );
  }
}

/// The shape of the results screen, drawn in blank surfaces.
class _SkeletonBody extends StatelessWidget {
  const _SkeletonBody();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _SkeletonBlock(width: 180, height: 26),
        SizedBox(height: AppSpacing.sm),
        _SkeletonBlock(width: 120, height: 14),
        SizedBox(height: AppSpacing.xl),
        Row(
          children: <Widget>[
            Expanded(child: _SkeletonBlock(height: 92)),
            SizedBox(width: AppSpacing.md),
            Expanded(child: _SkeletonBlock(height: 92)),
          ],
        ),
        SizedBox(height: AppSpacing.md),
        _SkeletonBlock(height: 56),
        SizedBox(height: AppSpacing.xl),
        _SkeletonBlock(height: 14),
        SizedBox(height: AppSpacing.sm),
        _SkeletonBlock(height: 14),
        SizedBox(height: AppSpacing.sm),
        _SkeletonBlock(width: 220, height: 14),
      ],
    );
  }
}

class _SkeletonBlock extends StatelessWidget {
  const _SkeletonBlock({required this.height, this.width});

  final double height;
  final double? width;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
    );
  }
}
