import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

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
  /// This platform makes no clips: only Android and iOS do, and the poster
  /// is offered everywhere else instead.
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

/// What [VideoEncoder.encode] made of a clip. It never throws.
sealed class EncodeResult {
  const EncodeResult();
}

final class EncodeSuccess extends EncodeResult {
  const EncodeSuccess(this.file);

  /// The MP4, in the app's cache.
  final File file;
}

final class EncodeFailure extends EncodeResult {
  const EncodeFailure(this.reason, this.message);

  final EncodeFailureReason reason;

  /// One sentence the UI can show as it is.
  final String message;

  @override
  String toString() => 'EncodeFailure(${reason.name}: $message)';
}

/// Encodes a stream of frames to MP4 through the platform, one frame at a
/// time.
///
/// Android and iOS: MediaCodec and MediaMuxer in `VideoEncoderChannel.kt`, the
/// recipe `docs/video-encoding-spike.md` measured, and AVAssetWriter in
/// `ios/Runner/VideoEncoderChannel.swift`, on the same channel. No ffmpeg: ffmpeg-kit was
/// retired in January 2025 and its Flutter packages are discontinued.
///
/// The clip is never held. Each frame is read back, sent, disposed, and only
/// then is the next one taken, so the renderer behind the stream draws it
/// only then too (see `FrameRenderer`). At 1080x1920 one frame is 8.3 MB.
///
/// Export is a foreground job. The spike found that with the phone locked it
/// made no progress at all, and sent Home it crawled at a fifth of the speed.
/// So the native side keeps the screen on for the length of a session, and
/// when the app is paused the export is cancelled, its partial file deleted,
/// and [EncodeFailureReason.interrupted] returned for the UI to offer a retry.
final class VideoEncoder {
  VideoEncoder({MethodChannel? channel, this.platform})
    : _channel = channel ?? defaultChannel;

  /// Namespaced to the app and the feature.
  static const MethodChannel defaultChannel = MethodChannel(
    'helixpeak/share/video_encoder',
  );

  final MethodChannel _channel;

  /// The platform to answer for, or null for the one this is running on.
  final TargetPlatform? platform;

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
  /// back as [EncodeFailureReason.cancelled].
  Future<EncodeResult> encode(
    Stream<ui.Image> frames,
    int fps, {
    String fileName = 'clip.mp4',
    ValueChanged<int>? onFrame,
    Future<void>? cancel,
  }) async {
    if (!isSupported) {
      return const EncodeFailure(
        EncodeFailureReason.unsupported,
        'Clips can only be made on Android and iOS. Share a poster instead.',
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
      onPause: () => paused = true,
    );
    unawaited(cancel?.then((_) => cancelled = true));
    int? session;
    String? path;
    int? width;
    int? height;
    int encoded = 0;

    Future<EncodeFailure> abandon(EncodeFailure failure) async {
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
        final Uint8List rgba;
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
            final Map<Object?, Object?>? begun = await _channel
                .invokeMapMethod<Object?, Object?>('begin', <String, Object>{
                  'width': width,
                  'height': height,
                  'fps': fps,
                  'fileName': fileName,
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
          } else if (frame.width != width || frame.height != height) {
            return await abandon(
              const EncodeFailure(
                EncodeFailureReason.invalidFrames,
                'The frames changed size part way through the clip.',
              ),
            );
          }
          final ByteData? bytes = await frame.toByteData();
          if (bytes == null) {
            return await abandon(
              const EncodeFailure(
                EncodeFailureReason.encoderError,
                'A frame could not be read back.',
              ),
            );
          }
          rgba = bytes.buffer.asUint8List(
            bytes.offsetInBytes,
            bytes.lengthInBytes,
          );
        } finally {
          frame.dispose();
        }
        await _channel.invokeMethod<void>('addFrame', <String, Object>{
          'session': session!,
          'rgba': rgba,
        });
        onFrame?.call(++encoded);
        if (stopped() case final EncodeFailure why) {
          return await abandon(why);
        }
      }

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
      return EncodeSuccess(File(finished));
    } on MissingPluginException {
      return abandon(
        const EncodeFailure(
          EncodeFailureReason.unsupported,
          'This build cannot make clips. Share a poster instead.',
        ),
      );
    } on PlatformException catch (error) {
      return abandon(
        error.code == 'unsupported'
            ? const EncodeFailure(
                EncodeFailureReason.noEncoder,
                'This phone has no video encoder for a clip this size. '
                'Share a poster instead.',
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
