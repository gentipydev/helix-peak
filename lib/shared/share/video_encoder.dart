import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'nv12_packer.dart';

/// The clip the lab exports: portrait full HD at 30 fps, 5 to 15 seconds.
abstract final class ClipFormat {
  static const int width = 1080;
  static const int height = 1920;
  static const int fps = 30;
  static const Duration shortest = Duration(seconds: 5);
  static const Duration longest = Duration(seconds: 15);
}

/// Why a clip was not made.
enum EncodeFailureReason {
  /// This platform makes no clips: only Android and iOS do.
  unsupported,

  /// The device has no encoder that takes the format.
  noEncoder,

  /// The app left the foreground mid-export, so the export was stopped and
  /// its partial file deleted. A retry starts over.
  interrupted,

  /// The reader stopped the export. Its partial file is deleted.
  cancelled,

  /// Frames no clip can be made of: none, an odd size, or a size that changes
  /// part way through.
  invalidFrames,

  /// The encoder or the muxer failed.
  encoderError,
}

/// What becomes of a clip when the reader leaves the app.
enum ClipAway {
  /// It is stopped, its partial file deleted, and
  /// [EncodeFailureReason.interrupted] returned: nothing keeps the app
  /// working in the background.
  stops,

  /// It goes on: the platform keeps the app working (on Android a foreground
  /// service, `ClipExportService.kt`), so a pause changes nothing.
  goesOn,
}

/// What [VideoEncoder.encode] made of a clip. It never throws.
sealed class EncodeResult {
  const EncodeResult();
}

final class EncodeSuccess extends EncodeResult {
  const EncodeSuccess(this.file, {this.timing});

  /// The MP4, in the app's cache.
  final File file;

  /// Where the clip's time went, step by step, in a build made with
  /// `--dart-define=CLIP_TIMING=true`; null in any other.
  final String? timing;
}

final class EncodeFailure extends EncodeResult {
  const EncodeFailure(this.reason, this.message);

  final EncodeFailureReason reason;

  /// One sentence the UI can show as it is.
  final String message;

  @override
  String toString() => 'EncodeFailure(${reason.name}: $message)';
}

/// Whether each clip is timed: built with `--dart-define=CLIP_TIMING=true`, a
/// finished clip prints where its time went, step by step, per frame.
const bool _timed = bool.fromEnvironment('CLIP_TIMING');

/// Encodes a stream of frames to MP4 through the platform, one frame per
/// call.
///
/// Android and iOS: MediaCodec and MediaMuxer in `VideoEncoderChannel.kt`, the
/// recipe `docs/video-encoding-spike.md` measured, and AVAssetWriter in
/// `ios/Runner/VideoEncoderChannel.swift`, on the same channel. No ffmpeg: ffmpeg-kit was
/// retired in January 2025 and its Flutter packages are discontinued.
///
/// The clip is never held. Each frame is read back, sent and disposed. The
/// next is drawn and read back while the platform encodes the one before, but
/// it is not sent until that one has been taken, so no more than two are ever
/// alive, and the renderer behind the stream draws each only when asked (see
/// `FrameRenderer`). At 1080x1920 one frame is 8.3 MB as RGBA.
///
/// Where [nv12] gives a packer, frames are packed as NV12 on the GPU
/// (`Nv12Packer`) and cross as 3.1 MB, and the platform side only copies
/// rows. Otherwise they cross as RGBA and the platform converts them.
///
/// Left alone, export is a foreground job. The spike found that with the phone
/// locked it made no progress at all, and sent Home it crawled at a fifth of
/// the speed. So unless the platform keeps the app working ([ClipAway]), when
/// the app is paused the export is cancelled, its partial file deleted, and
/// [EncodeFailureReason.interrupted] returned for the UI to offer a retry.
final class VideoEncoder {
  VideoEncoder({MethodChannel? channel, this.platform, this.nv12})
    : _channel = channel ?? defaultChannel;

  /// Namespaced to the app and the feature.
  static const MethodChannel defaultChannel = MethodChannel(
    'helixpeak/share/video_encoder',
  );

  final MethodChannel _channel;

  /// The platform to answer for, or null for the one this is running on.
  final TargetPlatform? platform;

  /// What packs frames as NV12, asked once a clip's first frame is in and its
  /// width is a multiple of four. Null, or a null answer, sends RGBA.
  final Future<Nv12Pack?> Function()? nv12;

  /// Whether this platform makes clips at all.
  bool get isSupported =>
      !kIsWeb &&
      switch (platform ?? defaultTargetPlatform) {
        TargetPlatform.android || TargetPlatform.iOS => true,
        _ => false,
      };

  /// [frames] at [fps] as an MP4 named [fileName] in the app's cache.
  ///
  /// [onFrame] is told how many frames have been encoded, after each one.
  /// When [cancel] completes, the export stops at the next frame and comes
  /// back as [EncodeFailureReason.cancelled]. [away] says what a pause of the
  /// app does to it.
  Future<EncodeResult> encode(
    Stream<ui.Image> frames,
    int fps, {
    String fileName = 'clip.mp4',
    ValueChanged<int>? onFrame,
    Future<void>? cancel,
    ClipAway away = ClipAway.stops,
  }) async {
    if (!isSupported) {
      return const EncodeFailure(
        EncodeFailureReason.unsupported,
        'Clips can only be made on Android and iOS.',
      );
    }
    if (fps < 1 || fps > 60) {
      return EncodeFailure(
        EncodeFailureReason.invalidFrames,
        'A clip cannot be made at $fps frames a second.',
      );
    }

    bool paused = false;
    bool cancelled = false;
    final AppLifecycleListener lifecycle = AppLifecycleListener(
      onPause: () {
        if (away == ClipAway.stops) {
          paused = true;
        }
      },
    );
    unawaited(cancel?.then((_) => cancelled = true));
    int? session;
    String? path;
    int? width;
    int? height;
    Nv12Pack? pack;
    // How frames cross: 'nv12' where [pack] packs them, otherwise 'rgba'.
    String format = 'rgba';
    int encoded = 0;
    // The frame the platform is encoding while the next one is drawn.
    Future<void>? sending;
    final _Timing? timing = _timed ? _Timing() : null;

    // Waits for the frame in flight to be taken, and counts it.
    Future<void> sent() async {
      final Future<void>? inFlight = sending;
      if (inFlight == null) {
        return;
      }
      sending = null;
      await inFlight;
      onFrame?.call(++encoded);
    }

    Future<EncodeFailure> abandon(EncodeFailure failure) async {
      // The platform finishes the frame it holds before it hears of this.
      final Future<void>? inFlight = sending;
      sending = null;
      if (inFlight != null) {
        try {
          await inFlight;
        } on Object catch (_) {
          // Whatever it was, the clip is being given up already.
        }
      }
      final int? open = session;
      session = null;
      if (open != null) {
        try {
          await _channel.invokeMethod<void>('cancel', <String, Object>{
            'session': open,
          });
        } on Object catch (error) {
          debugPrint('helixpeek: could not cancel an export ($error)');
        }
      }
      // The native side deletes its partial file on cancel; this makes sure
      // of it, and covers a session that failed before it could.
      final String? partial = path;
      if (partial != null) {
        try {
          final File file = File(partial);
          if (file.existsSync()) {
            file.deleteSync();
          }
        } on Object catch (error) {
          debugPrint('helixpeek: could not delete a partial clip ($error)');
        }
      }
      return failure;
    }

    const EncodeFailure interrupted = EncodeFailure(
      EncodeFailureReason.interrupted,
      'The clip was stopped when the app left the screen. Try again with '
      'the app open.',
    );
    EncodeFailure? stopped() => paused
        ? interrupted
        : cancelled
        ? const EncodeFailure(
            EncodeFailureReason.cancelled,
            'The clip was stopped.',
          )
        : null;

    try {
      await for (final ui.Image frame in frames) {
        timing?.lap('draw');
        final Uint8List bytes;
        try {
          if (stopped() case final EncodeFailure why) {
            return await abandon(why);
          }
          if (width == null) {
            width = frame.width;
            height = frame.height;
            if (width.isOdd || height.isOdd) {
              return await abandon(
                EncodeFailure(
                  EncodeFailureReason.invalidFrames,
                  'A clip cannot be ${frame.width}×${frame.height}: both '
                  'sides must be even.',
                ),
              );
            }
            pack = width % 4 == 0 ? await nv12?.call() : null;
            format = pack == null ? 'rgba' : 'nv12';
            final Map<Object?, Object?>? begun = await _channel
                .invokeMapMethod<Object?, Object?>('begin', <String, Object>{
                  'width': width,
                  'height': height,
                  'fps': fps,
                  'fileName': fileName,
                  'format': format,
                });
            session = begun?['session'] as int?;
            path = begun?['path'] as String?;
            if (session == null || path == null) {
              return await abandon(
                const EncodeFailure(
                  EncodeFailureReason.encoderError,
                  'The encoder did not start.',
                ),
              );
            }
            timing?.lap('begin');
          } else if (frame.width != width || frame.height != height) {
            return await abandon(
              const EncodeFailure(
                EncodeFailureReason.invalidFrames,
                'The frames changed size part way through the clip.',
              ),
            );
          }
          if (pack case final Nv12Pack packing) {
            bytes = await packing(frame);
          } else {
            final ByteData? rgba = await frame.toByteData();
            if (rgba == null) {
              return await abandon(
                const EncodeFailure(
                  EncodeFailureReason.encoderError,
                  'A frame could not be read back.',
                ),
              );
            }
            bytes = rgba.buffer.asUint8List(
              rgba.offsetInBytes,
              rgba.lengthInBytes,
            );
          }
          timing?.lap('read back');
        } finally {
          frame.dispose();
        }
        await sent();
        timing?.lap('wait for the encoder');
        if (stopped() case final EncodeFailure why) {
          return await abandon(why);
        }
        final Future<void> call = _channel.invokeMethod<void>(
          'addFrame',
          <String, Object>{
            'session': session!,
            format: bytes,
          },
        );
        // Handled from here on, so a failure while the next frame is drawn is
        // not reported as uncaught; `sent` still hears of it.
        unawaited(call.then<void>((_) {}, onError: (Object _) {}));
        sending = call;
        timing?.lap('send');
      }
      await sent();

      final int? open = session;
      if (open == null) {
        return const EncodeFailure(
          EncodeFailureReason.invalidFrames,
          'There were no frames to make a clip of.',
        );
      }
      if (stopped() case final EncodeFailure why) {
        return await abandon(why);
      }
      final String? finished = await _channel.invokeMethod<String>(
        'finish',
        <String, Object>{'session': open},
      );
      session = null;
      if (finished == null) {
        return await abandon(
          const EncodeFailure(
            EncodeFailureReason.encoderError,
            'The encoder did not finish the clip.',
          ),
        );
      }
      timing?.lap('finish');
      final String? report = timing?.report(encoded, format);
      if (report != null) {
        debugPrint('helixpeek: $report');
      }
      return EncodeSuccess(File(finished), timing: report);
    } on MissingPluginException {
      return abandon(
        const EncodeFailure(
          EncodeFailureReason.unsupported,
          'This build cannot make clips.',
        ),
      );
    } on PlatformException catch (error) {
      return abandon(
        error.code == 'unsupported'
            ? const EncodeFailure(
                EncodeFailureReason.noEncoder,
                'This phone has no video encoder for a clip this size.',
              )
            : EncodeFailure(
                EncodeFailureReason.encoderError,
                'The clip could not be made: ${error.message ?? error.code}',
              ),
      );
    } on Object catch (error) {
      return abandon(
        EncodeFailure(
          EncodeFailureReason.encoderError,
          'The clip could not be made: $error',
        ),
      );
    } finally {
      lifecycle.dispose();
    }
  }
}

/// Where one clip's time went, step by step, for `CLIP_TIMING`.
final class _Timing {
  final Stopwatch _clock = Stopwatch()..start();
  Duration _last = Duration.zero;
  final Map<String, Duration> _spent = <String, Duration>{};

  /// Books the time since the last lap to [step].
  void lap(String step) {
    final Duration now = _clock.elapsed;
    _spent[step] = (_spent[step] ?? Duration.zero) + (now - _last);
    _last = now;
  }

  String report(int frames, String format) {
    String perFrame(String step) => frames == 0
        ? '-'
        : ((_spent[step] ?? Duration.zero).inMicroseconds / frames / 1000)
              .toStringAsFixed(1);
    String once(String step) =>
        '${(_spent[step] ?? Duration.zero).inMilliseconds}';
    final int total = _clock.elapsedMilliseconds;
    return (
      '$frames frames as $format in $total ms, '
      '${frames == 0 ? '-' : (total / frames).toStringAsFixed(1)} ms a frame: '
      'draw ${perFrame('draw')}, read back ${perFrame('read back')}, '
      'wait for the encoder ${perFrame('wait for the encoder')}, '
      'send ${perFrame('send')}; begin ${once('begin')} ms, '
      'finish ${once('finish')} ms'
    );
  }
}
