import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/theme/app_spacing.dart';
import 'clip_exporter.dart';
import 'video_encoder.dart';

/// Shows [exporter]'s clip in a bottom sheet: how far it has got and, once it
/// is made, a way to share it.
///
/// The sheet can be put away at any point, and the clip goes on without it
/// ([ClipExporter]). It goes on the root navigator, so it closes itself and
/// nothing under it.
Future<void> showClipSheet(BuildContext context, ClipExporter exporter) =>
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
      builder: (BuildContext context) => ClipSheet(exporter: exporter),
    );

/// A clip's progress, and what can be done with it.
class ClipSheet extends StatefulWidget {
  const ClipSheet({required this.exporter, super.key});

  final ClipExporter exporter;

  @override
  State<ClipSheet> createState() => _ClipSheetState();
}

class _ClipSheetState extends State<ClipSheet> {
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    widget.exporter.watch();
    widget.exporter.job.addListener(_changed);
  }

  @override
  void dispose() {
    widget.exporter.job.removeListener(_changed);
    widget.exporter.unwatch();
    super.dispose();
  }

  /// A clip that is gone (stopped, or put away) takes its sheet with it.
  void _changed() {
    if (widget.exporter.job.value == null) {
      _close();
    }
  }

  void _close() {
    if (_closing || !mounted) {
      return;
    }
    _closing = true;
    Navigator.of(context).pop();
  }

  Future<void> _share(BuildContext button) async {
    final RenderBox? box = button.findRenderObject() as RenderBox?;
    final ScaffoldMessengerState? messenger = ScaffoldMessenger.maybeOf(
      context,
    );
    try {
      await widget.exporter.share(
        origin: box == null ? null : box.localToGlobal(Offset.zero) & box.size,
      );
    } on Object catch (error) {
      debugPrint('helixpeek: could not share a clip ($error)');
      messenger?.showSnackBar(
        const SnackBar(content: Text('The clip could not be shared.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    // The theme's filled buttons stretch to the width they are given; in a
    // row they take their own, as the record sheet's Go does.
    final ButtonStyle filled = FilledButton.styleFrom(
      minimumSize: const Size(64, 48),
    );
    final ButtonStyle text = TextButton.styleFrom(
      minimumSize: const Size(64, 48),
    );
    return ValueListenableBuilder<ClipJob?>(
      valueListenable: widget.exporter.job,
      builder: (BuildContext context, ClipJob? job, _) {
        if (job == null) {
          return const SizedBox.shrink();
        }
        final (String title, String line) = switch (job.status) {
          ClipStatus.making => (
            'Making a clip',
            'Frame ${job.done} of ${job.total}',
          ),
          ClipStatus.paused => (
            'Clip paused',
            'Frame ${job.done} of ${job.total}',
          ),
          ClipStatus.ready => ('Clip ready', '${job.total} frames'),
          ClipStatus.failed => (
            'Clip not made',
            job.failure?.message ?? 'The clip could not be made.',
          ),
        };
        final String? where = switch (job.status) {
          ClipStatus.making when job.away == ClipAway.goesOn =>
            'It goes on while you use the app, or another one.',
          ClipStatus.making when job.away == ClipAway.pauses =>
            'It goes on while you use the app, and waits while you are '
                'away from it.',
          ClipStatus.making =>
            'It goes on while you use the app. Leaving Helix Peek stops it.',
          ClipStatus.paused => 'It goes on when you come back.',
          ClipStatus.ready || ClipStatus.failed => null,
        };
        return Padding(
          padding: EdgeInsets.only(
            left: AppSpacing.xl,
            right: AppSpacing.xl,
            bottom: MediaQuery.paddingOf(context).bottom + AppSpacing.xl,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Semantics(
                  liveRegion: true,
                  child: Text(title, style: theme.textTheme.titleLarge),
                ),
                Text(
                  '${job.target.gene} · ${job.target.display}',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.lg),
                if (job.status != ClipStatus.failed) ...<Widget>[
                  LinearProgressIndicator(value: job.progress),
                  const SizedBox(height: AppSpacing.sm),
                ],
                Text(
                  line,
                  key: const ValueKey<String>('clip-progress'),
                  style: theme.textTheme.bodySmall,
                ),
                if (where != null)
                  Text(where, style: theme.textTheme.bodySmall),
                if (job.timing case final String timing) ...<Widget>[
                  const SizedBox(height: AppSpacing.sm),
                  SelectableText(timing, style: theme.textTheme.labelSmall),
                ],
                const SizedBox(height: AppSpacing.lg),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: <Widget>[
                    ...switch (job.status) {
                      ClipStatus.making || ClipStatus.paused => <Widget>[
                        TextButton(
                          key: const ValueKey<String>('clip-cancel'),
                          style: text,
                          onPressed: () {
                            widget.exporter.cancel();
                            _close();
                          },
                          child: const Text('Cancel'),
                        ),
                      ],
                      ClipStatus.ready => <Widget>[
                        TextButton(
                          key: const ValueKey<String>('clip-done'),
                          style: text,
                          onPressed: widget.exporter.clear,
                          child: const Text('Done'),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Builder(
                          builder: (BuildContext button) => FilledButton(
                            key: const ValueKey<String>('clip-share'),
                            style: filled,
                            onPressed: () => unawaited(_share(button)),
                            child: const Text('Share'),
                          ),
                        ),
                      ],
                      ClipStatus.failed => <Widget>[
                        TextButton(
                          key: const ValueKey<String>('clip-close'),
                          style: text,
                          onPressed: widget.exporter.clear,
                          child: const Text('Close'),
                        ),
                        if (job.failure?.reason ==
                            EncodeFailureReason.interrupted) ...<Widget>[
                          const SizedBox(width: AppSpacing.sm),
                          FilledButton(
                            key: const ValueKey<String>('clip-retry'),
                            style: filled,
                            onPressed: widget.exporter.retry,
                            child: const Text('Try again'),
                          ),
                        ],
                      ],
                    },
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

/// Says when a clip has ended while no sheet was showing it: a snackbar on
/// whatever screen is open, with a way to share it, or why it was not made.
/// A clip that ended while the app was away is said when it comes back.
///
/// It sits under the app's root `ScaffoldMessenger` (`MaterialApp.builder`)
/// and reads the app's [ClipExporter]; without one it says nothing.
class ClipReadyListener extends StatefulWidget {
  const ClipReadyListener({required this.child, super.key});

  final Widget child;

  @override
  State<ClipReadyListener> createState() => _ClipReadyListenerState();
}

class _ClipReadyListenerState extends State<ClipReadyListener>
    with WidgetsBindingObserver {
  ClipExporter? _exporter;
  ClipStatus? _was;

  /// A clip that ended while the app was away, to be said when it is back.
  ClipJob? _unsaid;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final ClipExporter? exporter = context.read<ClipExporter?>();
    if (!identical(exporter, _exporter)) {
      _exporter?.job.removeListener(_changed);
      _exporter = exporter;
      _was = exporter?.job.value?.status;
      exporter?.job.addListener(_changed);
    }
  }

  @override
  void dispose() {
    _exporter?.job.removeListener(_changed);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  bool get _inFront {
    final AppLifecycleState? state = WidgetsBinding.instance.lifecycleState;
    return state == null || state == AppLifecycleState.resumed;
  }

  void _changed() {
    final ClipExporter? exporter = _exporter;
    final ClipJob? job = exporter?.job.value;
    final ClipStatus? now = job?.status;
    if (now == _was) {
      return;
    }
    _was = now;
    if (exporter == null || job == null || job.underway || exporter.watched) {
      return;
    }
    if (_inFront) {
      _say(exporter, job);
    } else {
      _unsaid = job;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final ClipJob? unsaid = _unsaid;
    final ClipExporter? exporter = _exporter;
    if (state != AppLifecycleState.resumed ||
        unsaid == null ||
        exporter == null) {
      return;
    }
    _unsaid = null;
    // Only if it is still the clip there is, and nothing is showing it.
    if (identical(exporter.job.value, unsaid) && !exporter.watched) {
      _say(exporter, unsaid);
    }
  }

  void _say(ClipExporter exporter, ClipJob job) {
    final ScaffoldMessengerState? messenger = ScaffoldMessenger.maybeOf(
      context,
    );
    if (messenger == null || !mounted) {
      return;
    }
    // The snackbar's surface is the theme's dark one; Material's own action
    // and close colours are made for a light one and all but vanish on it.
    final ColorScheme scheme = Theme.of(context).colorScheme;
    if (job.status == ClipStatus.ready) {
      final Size screen = MediaQuery.sizeOf(context);
      messenger.showSnackBar(
        SnackBar(
          content: Text('Clip ready · ${job.target.gene}'),
          showCloseIcon: true,
          closeIconColor: scheme.onSurfaceVariant,
          action: SnackBarAction(
            label: 'Share',
            textColor: scheme.primary,
            onPressed: () => unawaited(
              _share(
                exporter,
                messenger,
                // The snackbar is gone by the time the sheet opens; an iPad
                // needs somewhere to hang it, so the bottom of the screen.
                Rect.fromCenter(
                  center: Offset(screen.width / 2, screen.height - 48),
                  width: 1,
                  height: 1,
                ),
              ),
            ),
          ),
        ),
      );
    } else if (job.failure case final EncodeFailure failure) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(failure.message),
          action: failure.reason == EncodeFailureReason.interrupted
              ? SnackBarAction(
                  label: 'Try again',
                  textColor: scheme.primary,
                  onPressed: exporter.retry,
                )
              : null,
        ),
      );
    }
  }

  Future<void> _share(
    ClipExporter exporter,
    ScaffoldMessengerState messenger,
    Rect origin,
  ) async {
    try {
      await exporter.share(origin: origin);
    } on Object catch (error) {
      debugPrint('helixpeek: could not share a clip ($error)');
      messenger.showSnackBar(
        const SnackBar(content: Text('The clip could not be shared.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
