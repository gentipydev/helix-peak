import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';

/// What to draw at [t], from 0 at the start of a flow to 1 at its end.
typedef FramePainter = CustomPainter Function(double t);

/// A flow's frames, drawn offscreen and handed out one at a time.
///
/// Every lab timeline is a pure function of `t` (`AnimationTimeline`), so a
/// clip is not recorded off the screen in real time: frame `i` of `n` is the
/// painter at `t = i / (n - 1)`, drawn into a picture and rasterised, however
/// long that takes and whatever the clock says. The same painter, count and
/// size give the same pixels every time.
///
/// The clip is never held. At 1080×1920 one frame is 8.3 MB, so fifteen
/// seconds at 30 fps would be 3.7 GB; [frames] renders frame `i + 1` only
/// once frame `i` has been taken and the consumer has asked for more. The
/// consumer owns each frame it takes and disposes it.
@immutable
final class FrameRenderer {
  const FrameRenderer({
    required this.painter,
    required this.count,
    required this.size,
    this.pixelRatio = 1,
    this.background,
  });

  final FramePainter painter;

  /// How many frames: the first at `t = 0` and, past one, the last at 1.
  final int count;

  /// The logical size the painter draws in.
  final Size size;

  /// Pixels per logical pixel, so a frame is [width] by [height].
  final double pixelRatio;

  /// What each frame is filled with before the painter draws, or nothing,
  /// which leaves it transparent.
  final Color? background;

  int get width => (size.width * pixelRatio).round();

  int get height => (size.height * pixelRatio).round();

  /// Where frame [frame] of [count] falls.
  static double tOf(int frame, int count) =>
      count <= 1 ? 0 : frame / (count - 1);

  /// Every frame in order, rendered on demand.
  ///
  /// The stream is single-subscription. A consumer that pauses — an
  /// `await for` does, for as long as its body runs — holds the next frame
  /// back until it resumes. One that cancels stops the rendering, and no
  /// frame is left undisposed.
  Stream<ui.Image> frames() {
    if (count < 1) {
      throw ArgumentError.value(count, 'count', 'must be at least 1');
    }
    if (width < 1 || height < 1) {
      throw ArgumentError.value(size, 'size', 'must be at least one pixel');
    }
    // Synchronous, so that a frame is in the consumer's hands the moment it
    // is added, and the consumer's pause (if it pauses) is already in force
    // when the loop looks for it.
    final StreamController<ui.Image> out = StreamController<ui.Image>(
      sync: true,
    );
    Completer<void>? resumed;
    bool cancelled = false;
    void wake() {
      resumed?.complete();
      resumed = null;
    }

    Future<void> run() async {
      try {
        for (int i = 0; i < count; i++) {
          while (out.isPaused && !cancelled) {
            await (resumed ??= Completer<void>()).future;
          }
          if (cancelled) {
            return;
          }
          final ui.Image frame = await render(tOf(i, count));
          if (cancelled) {
            frame.dispose();
            return;
          }
          out.add(frame);
        }
      } on Object catch (error, stack) {
        if (!cancelled) {
          out.addError(error, stack);
        }
      } finally {
        if (!cancelled) {
          await out.close();
        }
      }
    }

    out.onListen = () {
      unawaited(run());
    };
    out.onResume = wake;
    out.onCancel = () {
      cancelled = true;
      wake();
    };
    return out.stream;
  }

  /// One frame at [t], outside any stream. The caller disposes it.
  Future<ui.Image> render(double t) async {
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder)..scale(pixelRatio);
    final Color? fill = background;
    if (fill != null) {
      canvas.drawColor(fill, BlendMode.src);
    }
    painter(t).paint(canvas, size);
    final ui.Picture picture = recorder.endRecording();
    try {
      return await picture.toImage(width, height);
    } finally {
      picture.dispose();
    }
  }
}
