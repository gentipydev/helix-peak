import 'package:flutter/material.dart';

import '../../../../shared/anatomy/sequence_scrubber.dart';
import '../domain/zoom_depth.dart';

/// The zoom's depth rail: the walk's own [SequenceScrubber] down the right
/// edge of the canvas, its stops evenly spaced along it from the body at the
/// top to the DNA at the bottom.
///
/// The scrubber reads a scroll position, so this keeps one, as
/// `TimelineScrubber` does: an unpainted, untouchable scroll view laid out at
/// the rail's own height, whose offset is the depth's place on the rail.
/// Dragging the thumb scrubs the depth; letting go settles on the nearest
/// stop. To a screen reader the rail is one slider whose steps are the stops.
class ZoomRail extends StatefulWidget {
  const ZoomRail({
    required this.depth,
    required this.value,
    required this.nameOf,
    required this.onScrub,
    required this.onRelease,
    required this.onStep,
    super.key,
  });

  final ZoomDepth depth;

  /// The zoom's depth, which the thumb follows.
  final ValueNotifier<double> value;

  /// What a stop is called: `Cell`.
  final String Function(ZoomStop stop) nameOf;

  /// The reader dragged the thumb to this depth.
  final ValueChanged<double> onScrub;

  /// The reader let the thumb go.
  final VoidCallback onRelease;

  /// A screen reader stepped one stop deeper (+1) or shallower (-1).
  final ValueChanged<int> onStep;

  @override
  State<ZoomRail> createState() => _ZoomRailState();
}

class _ZoomRailState extends State<ZoomRail> {
  /// How many of its own heights the unpainted page is: tall, so the
  /// landmarks (drawn against the whole extent) and the thumb (drawn against
  /// the scrollable part) agree.
  static const double _screens = 200;

  final ScrollController _scroll = ScrollController();
  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    widget.value.addListener(_follow);
    _scroll.addListener(_scrubbed);
    WidgetsBinding.instance.addPostFrameCallback((_) => _follow());
  }

  @override
  void didUpdateWidget(ZoomRail old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value) {
      old.value.removeListener(_follow);
      widget.value.addListener(_follow);
    }
  }

  @override
  void dispose() {
    widget.value.removeListener(_follow);
    _scroll.dispose();
    super.dispose();
  }

  double get _max => _scroll.hasClients ? _scroll.position.maxScrollExtent : 0;

  void _follow() {
    if (!mounted || !_scroll.hasClients || _max <= 0) {
      return;
    }
    _syncing = true;
    _scroll.jumpTo(widget.depth.railOf(widget.value.value) * _max);
    _syncing = false;
  }

  void _scrubbed() {
    if (_syncing || _max <= 0) {
      return;
    }
    widget.onScrub(widget.depth.depthAtRail(_scroll.offset / _max));
  }

  String _label(double offset) {
    final double max = _max;
    final double rail = max <= 0 ? 0 : (offset / max).clamp(0.0, 1.0);
    return widget.depth.widthLabel(widget.depth.depthAtRail(rail));
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints box) {
        final double height = box.maxHeight;
        final double extent = height * (_screens - 1);
        final int last = ZoomStop.values.length - 1;
        return ValueListenableBuilder<double>(
          valueListenable: widget.value,
          builder: (BuildContext context, double d, Widget? rail) {
            final ZoomStop here = widget.depth.nearest(d);
            String? named(int k) => k < 0 || k > last
                ? null
                : widget.nameOf(ZoomStop.values[k]);
            return Semantics(
              key: const ValueKey<String>('zoom-rail'),
              slider: true,
              label: 'Depth',
              value: '${widget.nameOf(here)}, ${widget.depth.widthLabel(d)}',
              increasedValue: named(here.index + 1),
              decreasedValue: named(here.index - 1),
              onIncrease: here.index < last ? () => widget.onStep(1) : null,
              onDecrease: here.index > 0 ? () => widget.onStep(-1) : null,
              child: ExcludeSemantics(child: rail),
            );
          },
          child: Listener(
            onPointerUp: (_) => widget.onRelease(),
            onPointerCancel: (_) => widget.onRelease(),
            child: SizedBox(
              width: SequenceScrubber.width,
              height: height,
              child: Stack(
                children: <Widget>[
                  Offstage(
                    child: SingleChildScrollView(
                      controller: _scroll,
                      physics: const NeverScrollableScrollPhysics(),
                      child: SizedBox(
                        width: SequenceScrubber.width,
                        height: height * _screens,
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: SequenceScrubber(
                      controller: _scroll,
                      labelAt: _label,
                      landmarks: <(double, String)>[
                        for (final ZoomStop stop in ZoomStop.values)
                          (stop.index / last * extent, widget.nameOf(stop)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
