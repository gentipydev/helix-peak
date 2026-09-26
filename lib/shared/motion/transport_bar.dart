import 'package:flutter/material.dart';

import '../../core/theme/app_spacing.dart';
import '../anatomy/sequence_scrubber.dart';
import 'animation_timeline.dart';
import 'timeline_controller.dart';

/// The reader's controls for any [TimelineController]: reset, step back,
/// play or pause, step forward and a speed, under the name of the phase on
/// screen.
///
/// Phases are named, never numbered: a reader is shown "Peptide bond", not
/// `t = 0.4133`. The name is a live region, so a screen reader hears each
/// change. Every button is at least 48 logical pixels square, every icon-only
/// one carries a label, and the row wraps rather than overflows at the largest
/// text scale.
///
/// It also carries the reader's reduced-motion setting to the controller:
/// with `MediaQuery.disableAnimations` on, playback shows one still frame per
/// phase.
///
/// Scrubbing is [TimelineScrubber], placed by the screen beside what it plays.
class TransportBar extends StatefulWidget {
  const TransportBar({
    required this.controller,
    this.speeds = defaultSpeeds,
    super.key,
  });

  final TimelineController controller;

  /// The speeds the selector offers, slowest first.
  final List<double> speeds;

  static const List<double> defaultSpeeds = <double>[0.5, 1, 2, 4];

  /// The smallest a control may be, in logical pixels, on either side.
  static const double target = 48;

  @override
  State<TransportBar> createState() => _TransportBarState();
}

class _TransportBarState extends State<TransportBar> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_changed);
  }

  @override
  void didUpdateWidget(TransportBar old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller.removeListener(_changed);
      widget.controller.addListener(_changed);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final bool reduced = MediaQuery.disableAnimationsOf(context);
    if (widget.controller.reducedMotion != reduced) {
      // Not during build: the controller notifies, and this rebuilds.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          widget.controller.reducedMotion = reduced;
        }
      });
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_changed);
    super.dispose();
  }

  void _changed() => setState(() {});

  static String _speedLabel(double speed) {
    final String number = speed == speed.roundToDouble()
        ? speed.toStringAsFixed(0)
        : speed.toString();
    return '$number×';
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final TimelineController c = widget.controller;
    final PhaseMark? phase = c.phase;
    final ButtonStyle square = IconButton.styleFrom(
      minimumSize: const Size.square(TransportBar.target),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Semantics(
            liveRegion: true,
            child: Text(
              phase?.name ?? '',
              key: const ValueKey<String>('transport-phase'),
              style: theme.textTheme.titleSmall,
              textAlign: TextAlign.center,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            IconButton(
              style: square,
              tooltip: 'Reset',
              onPressed: c.reset,
              icon: const Icon(Icons.replay_rounded),
            ),
            IconButton(
              style: square,
              tooltip: 'Step back',
              onPressed: c.stepToPreviousPhase,
              icon: const Icon(Icons.skip_previous_rounded),
            ),
            IconButton(
              style: square,
              tooltip: c.isPlaying ? 'Pause' : 'Play',
              onPressed: c.isPlaying ? c.pause : c.play,
              icon: Icon(
                c.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
              ),
            ),
            IconButton(
              style: square,
              tooltip: 'Step forward',
              onPressed: c.stepToNextPhase,
              icon: const Icon(Icons.skip_next_rounded),
            ),
            PopupMenuButton<double>(
              tooltip: 'Playback speed',
              initialValue: c.speed,
              onSelected: (double speed) => c.speed = speed,
              itemBuilder: (BuildContext context) => <PopupMenuEntry<double>>[
                for (final double speed in widget.speeds)
                  PopupMenuItem<double>(
                    value: speed,
                    child: Text(_speedLabel(speed)),
                  ),
              ],
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  minWidth: TransportBar.target,
                  minHeight: TransportBar.target,
                ),
                child: Center(
                  widthFactor: 1,
                  heightFactor: 1,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                    ),
                    child: Text(
                      _speedLabel(c.speed),
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                      semanticsLabel: 'Speed ${_speedLabel(c.speed)}',
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// The walk's [SequenceScrubber], scrubbing a timeline instead of a page.
///
/// The scrubber reads a scroll position, so this keeps one: an unpainted,
/// untouchable scroll view laid out at the scrubber's own height, whose offset
/// is the timeline's `t`. Dragging the thumb pauses and seeks; playing moves the
/// thumb. The scrubber itself is used exactly as the walk uses it, down the
/// right edge of what it scrubs, [SequenceScrubber.width] wide.
class TimelineScrubber extends StatefulWidget {
  const TimelineScrubber({
    required this.controller,
    this.landmarks = const <(double, String)>[],
    this.labelAt,
    super.key,
  });

  final TimelineController controller;

  /// Named places along the timeline, as `t` and name, in order.
  final List<(double, String)> landmarks;

  /// What the bubble calls the place at `t` while the thumb is dragged. By
  /// default, the name of the phase there.
  final String? Function(double t)? labelAt;

  @override
  State<TimelineScrubber> createState() => _TimelineScrubberState();
}

class _TimelineScrubberState extends State<TimelineScrubber> {
  /// How many of its own heights the unpainted page is. Tall, so that the
  /// scrubber's landmark ticks (drawn against the whole extent) and its thumb
  /// (drawn against the scrollable part) agree to within half a percent.
  static const double _screens = 200;

  final ScrollController _scroll = ScrollController();
  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_follow);
    _scroll.addListener(_scrubbed);
    WidgetsBinding.instance.addPostFrameCallback((_) => _follow());
  }

  @override
  void didUpdateWidget(TimelineScrubber old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller.removeListener(_follow);
      widget.controller.addListener(_follow);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_follow);
    _scroll.dispose();
    super.dispose();
  }

  double get _max =>
      _scroll.hasClients ? _scroll.position.maxScrollExtent : 0;

  /// The timeline moved: move the thumb to match.
  void _follow() {
    if (!mounted || !_scroll.hasClients || _max <= 0) {
      return;
    }
    _syncing = true;
    _scroll.jumpTo(widget.controller.t * _max);
    _syncing = false;
  }

  /// The thumb moved: take the timeline there.
  void _scrubbed() {
    if (_syncing || _max <= 0) {
      return;
    }
    final double t = (_scroll.offset / _max).clamp(0.0, 1.0);
    widget.controller.pause();
    widget.controller.seek(t);
  }

  String? _label(double offset) {
    final double max = _max;
    final double t = max <= 0 ? 0 : (offset / max).clamp(0.0, 1.0);
    final String? Function(double t)? labelAt = widget.labelAt;
    return labelAt != null
        ? labelAt(t)
        : widget.controller.timeline.phaseAt(t)?.name;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints box) {
        final double height = box.maxHeight;
        final double extent = height * (_screens - 1);
        return SizedBox(
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
                    for (final (double t, String name) in widget.landmarks)
                      (t * extent, name),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
