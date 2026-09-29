import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../core/catalog/protein_target.dart';
import 'clip_keep_alive.dart';
import 'frame_renderer.dart';
import 'gene_link.dart';
import 'nv12_packer.dart';
import 'share_action.dart';
import 'video_encoder.dart';

/// Where a clip is.
enum ClipStatus {
  /// Its frames are being drawn and encoded.
  making,

  /// Stopped while the app is away, to go on when it comes back.
  paused,

  /// Made: [ClipJob.file] is the MP4, waiting to be shared.
  ready,

  /// Not made: [ClipJob.failure] says why.
  failed,
}

/// One clip, as the sheet and the button show it.
@immutable
final class ClipJob {
  const ClipJob({
    required this.target,
    required this.total,
    this.done = 0,
    this.status = ClipStatus.making,
    this.file,
    this.failure,
    this.timing,
    this.away = ClipAway.stops,
  });

  final ProteinTarget target;

  /// The clip's frames, and how many of them are encoded.
  final int total;
  final int done;
  final ClipStatus status;

  /// The MP4, once [status] is [ClipStatus.ready].
  final File? file;

  /// Why it was not made, once [status] is [ClipStatus.failed].
  final EncodeFailure? failure;

  /// Where its time went, in a build made to time clips
  /// ([EncodeSuccess.timing]); null in any other.
  final String? timing;

  /// What becomes of it if the reader leaves the app while it is made.
  final ClipAway away;

  /// Whether frames are still to come.
  bool get underway =>
      status == ClipStatus.making || status == ClipStatus.paused;

  double get progress => total == 0 ? 0 : done / total;

  ClipJob _with({
    int? done,
    ClipStatus? status,
    File? file,
    EncodeFailure? failure,
    String? timing,
    ClipAway? away,
  }) => ClipJob(
    target: target,
    total: total,
    done: done ?? this.done,
    status: status ?? this.status,
    file: file ?? this.file,
    failure: failure ?? this.failure,
    timing: timing ?? this.timing,
    away: away ?? this.away,
  );
}

/// Makes one clip at a time for the whole app, so it goes on while the
/// reader does something else: the page that asked for it can close, and
/// the sheet that shows it can be put away.
///
/// A clip is a flow's painter drawn offscreen at every frame of its length
/// ([FrameRenderer]), each frame carrying the protein's name and its link, and
/// encoded to MP4 ([VideoEncoder]). It is shared only when the reader asks
/// ([share]).
///
/// Before each frame it gives way to the app's own ([giveWayToFrames]), so a
/// clip in the making does not stutter the page the reader is on.
///
/// Where the platform can keep the app working while it is away
/// ([ClipKeepAlive]: Android), the clip goes on behind other apps and a locked
/// screen, with its progress in a notification. On iOS it pauses with the app
/// and goes on when the app is back; elsewhere leaving the app stops it.
class ClipExporter {
  ClipExporter({
    VideoEncoder? encoder,
    this.shareFile = systemShareFile,
    Future<void> Function()? pace,
    ClipKeepAlive? keepAlive,
  }) : encoder = encoder ?? VideoEncoder(nv12: Nv12Packer.forPlatform),
       keepAlive = keepAlive ?? ClipKeepAlive(),
       _pace = pace ?? giveWayToFrames;

  final VideoEncoder encoder;
  final FileShare shareFile;
  final ClipKeepAlive keepAlive;
  final Future<void> Function() _pace;

  final ValueNotifier<ClipJob?> _job = ValueNotifier<ClipJob?>(null);

  /// The clip being made, or made and not yet put away; null when there is
  /// none.
  ValueListenable<ClipJob?> get job => _job;

  /// Whether this platform makes clips at all.
  bool get isSupported => encoder.isSupported;

  _ClipRequest? _request;
  Completer<void>? _cancel;
  int _watchers = 0;
  bool _disposed = false;

  /// Whether the platform, not the reader, stopped the clip being made.
  bool _stoppedByPlatform = false;

  /// Whether a sheet is showing the clip, so its end needs no other word.
  bool get watched => _watchers > 0;

  void watch() => _watchers++;

  void unwatch() => _watchers = math.max(0, _watchers - 1);

  /// The frames in a clip of [duration] at [fps], its length held to
  /// [ClipFormat.shortest] to [ClipFormat.longest].
  static int frameCount(Duration duration, int fps) {
    final Duration held = duration < ClipFormat.shortest
        ? ClipFormat.shortest
        : duration > ClipFormat.longest
        ? ClipFormat.longest
        : duration;
    return (held.inMilliseconds * fps / 1000).round();
  }

  /// Starts a clip of [target]'s [painter], drawn at [size] × [pixelRatio];
  /// false, with nothing started, while another clip is underway.
  ///
  /// [painter] is given how far through the clip a frame is, 0 to 1.
  bool start({
    required ProteinTarget target,
    required FramePainter painter,
    required Duration duration,
    required ThemeData theme,
    Size size = const Size(360, 640),
    double pixelRatio = 3,
    int fps = ClipFormat.fps,
  }) {
    if (_disposed || (_job.value?.underway ?? false)) {
      return false;
    }
    final _ClipRequest request = _ClipRequest(
      target: target,
      painter: painter,
      duration: duration,
      theme: theme,
      size: size,
      pixelRatio: pixelRatio,
      fps: fps,
    );
    _request = request;
    unawaited(_make(request));
    return true;
  }

  /// Starts the clip that failed again; false if the clip did not fail.
  bool retry() {
    final _ClipRequest? request = _request;
    if (_disposed ||
        request == null ||
        _job.value?.status != ClipStatus.failed) {
      return false;
    }
    unawaited(_make(request));
    return true;
  }

  /// Stops the clip being made; its partial file is deleted and the job
  /// goes.
  void cancel() {
    final Completer<void>? cancel = _cancel;
    if (cancel != null && !cancel.isCompleted) {
      cancel.complete();
    }
  }

  /// Puts away a clip that is made or failed.
  void clear() {
    final ClipJob? job = _job.value;
    if (!_disposed && job != null && !job.underway) {
      _job.value = null;
    }
  }

  /// Hands the made clip to [shareFile], from [origin] where the platform
  /// wants one (an iPad does).
  Future<void> share({Rect? origin}) async {
    final ClipJob? job = _job.value;
    final File? file = job?.file;
    if (job == null || file == null) {
      return;
    }
    await shareFile(
      file: file,
      mimeType: 'video/mp4',
      text: posterText(job.target),
      origin: origin,
    );
  }

  Future<void> _make(_ClipRequest request) async {
    final int total = frameCount(request.duration, request.fps);
    final String title = request.target.gene;
    final Completer<void> cancel = Completer<void>();
    _cancel = cancel;
    _stoppedByPlatform = false;
    _job.value = ClipJob(target: request.target, total: total);
    final ClipAway away = await keepAlive.begin(
      title: title,
      total: total,
      onCancel: this.cancel,
      onStopped: () {
        _stoppedByPlatform = true;
        this.cancel();
      },
    );
    if (_disposed) {
      unawaited(keepAlive.end(title: title, ready: false));
      return;
    }
    if (_job.value case final ClipJob job) {
      _job.value = job._with(away: away);
    }
    final FrameRenderer renderer = FrameRenderer(
      painter: (double t) =>
          _Titled(request.painter(t), request.target, request.theme),
      count: total,
      size: request.size,
      pixelRatio: request.pixelRatio,
      background: request.theme.colorScheme.surface,
      pace: _pace,
    );
    final EncodeResult result = await encoder.encode(
      renderer.frames(),
      request.fps,
      fileName: '${request.target.slug}-helix-peek.mp4',
      onFrame: (int done) {
        final ClipJob? job = _job.value;
        if (!_disposed && job != null && job.underway) {
          _job.value = job._with(done: done);
        }
        keepAlive.progress(title: title, done: done, total: total);
      },
      cancel: cancel.future,
      away: away,
      redraw: (int from) => renderer.frames(from: from),
      onAway: (bool isAway) {
        final ClipJob? job = _job.value;
        if (!_disposed && job != null && job.underway) {
          _job.value = job._with(
            status: isAway ? ClipStatus.paused : ClipStatus.making,
          );
        }
      },
    );
    if (identical(_cancel, cancel)) {
      _cancel = null;
    }
    unawaited(keepAlive.end(title: title, ready: result is EncodeSuccess));
    if (_disposed) {
      return;
    }
    final ClipJob job =
        _job.value ?? ClipJob(target: request.target, total: total);
    switch (result) {
      case EncodeSuccess(:final File file, :final String? timing):
        _job.value = job._with(
          status: ClipStatus.ready,
          done: total,
          file: file,
          timing: timing,
        );
      case EncodeFailure(reason: EncodeFailureReason.cancelled)
          when _stoppedByPlatform:
        _job.value = job._with(
          status: ClipStatus.failed,
          failure: const EncodeFailure(
            EncodeFailureReason.interrupted,
            'The phone stopped the clip while the app was away. Try again '
            'with the app open.',
          ),
        );
      case EncodeFailure(reason: EncodeFailureReason.cancelled):
        _job.value = null;
      case final EncodeFailure failure:
        _job.value = job._with(status: ClipStatus.failed, failure: failure);
    }
  }

  void dispose() {
    _disposed = true;
    cancel();
    _job.dispose();
  }

  /// Waits for a frame of the app that is already on its way, so a clip's
  /// frame is drawn between the app's rather than in the way of one. With
  /// none coming, or with frames off because the app is away, it goes
  /// straight on; it never waits more than a tenth of a second.
  static Future<void> giveWayToFrames() async {
    final SchedulerBinding scheduler = SchedulerBinding.instance;
    if (!scheduler.framesEnabled ||
        !(scheduler.hasScheduledFrame ||
            scheduler.schedulerPhase != SchedulerPhase.idle)) {
      return;
    }
    final Completer<void> drawn = Completer<void>();
    void done() {
      if (!drawn.isCompleted) {
        drawn.complete();
      }
    }

    final Timer patience = Timer(const Duration(milliseconds: 100), done);
    unawaited(scheduler.endOfFrame.then((_) => done()));
    await drawn.future;
    patience.cancel();
  }
}

/// What a clip was started with, kept to start it again.
@immutable
final class _ClipRequest {
  const _ClipRequest({
    required this.target,
    required this.painter,
    required this.duration,
    required this.theme,
    required this.size,
    required this.pixelRatio,
    required this.fps,
  });

  final ProteinTarget target;
  final FramePainter painter;
  final Duration duration;
  final ThemeData theme;
  final Size size;
  final double pixelRatio;
  final int fps;
}

/// One frame of a clip with the protein's name above it and its link below.
class _Titled extends CustomPainter {
  _Titled(this.inner, this.target, this.theme);

  final CustomPainter inner;
  final ProteinTarget target;
  final ThemeData theme;

  @override
  void paint(Canvas canvas, Size size) {
    inner.paint(canvas, size);
    final ColorScheme scheme = theme.colorScheme;
    _line(
      canvas,
      size,
      target.display,
      (theme.textTheme.titleLarge ?? const TextStyle()).copyWith(
        color: scheme.onSurface,
      ),
      top: 24,
    );
    _line(
      canvas,
      size,
      geneLink(target).toString(),
      (theme.textTheme.bodySmall ?? const TextStyle()).copyWith(
        fontFamily: 'JetBrainsMono',
        color: scheme.primary,
      ),
      bottom: 24,
    );
  }

  static void _line(
    Canvas canvas,
    Size size,
    String text,
    TextStyle style, {
    double? top,
    double? bottom,
  }) {
    final TextPainter painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: math.max(0, size.width - 48));
    final double y = top ?? size.height - bottom! - painter.height;
    painter
      ..paint(canvas, Offset((size.width - painter.width) / 2, y))
      ..dispose();
  }

  @override
  bool shouldRepaint(_Titled old) => true;
}
