import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/shared/share/frame_renderer.dart';
import 'package:helixpeek/shared/share/video_encoder.dart';

class _Solid extends CustomPainter {
  _Solid(this.t);

  final double t;

  @override
  void paint(Canvas canvas, Size size) => canvas.drawRect(
    Offset.zero & size,
    Paint()..color = Color.lerp(Colors.blue, Colors.red, t)!,
  );

  @override
  bool shouldRepaint(_Solid old) => old.t != t;
}

/// The platform side, faked: it keeps a real partial file on disk from
/// `begin` so that what happens to it can be checked.
class _FakeEncoder {
  _FakeEncoder(this.directory);

  final Directory directory;
  final List<String> calls = <String>[];
  final List<int> frameBytes = <int>[];
  File? partial;

  /// Runs after each `addFrame` the platform takes, with how many it has.
  FutureOr<void> Function(int frames)? afterFrame;

  /// What `begin`, `addFrame` or `finish` should throw, by call name.
  final Map<String, PlatformException> failures = <String, PlatformException>{};

  Future<Object?> handle(MethodCall call) async {
    calls.add(call.method);
    final PlatformException? failure = failures[call.method];
    if (failure != null) {
      throw failure;
    }
    final Map<Object?, Object?> args =
        (call.arguments as Map<Object?, Object?>?) ?? <Object?, Object?>{};
    switch (call.method) {
      case 'begin':
        partial = File('${directory.path}/${args['fileName']}')
          ..writeAsBytesSync(<int>[0, 0, 0, 24]);
        return <String, Object>{
          'session': 7,
          'path': partial!.path,
          'codec': 'fake.encoder',
        };
      case 'addFrame':
        expect(args['session'], 7);
        frameBytes.add((args['rgba']! as Uint8List).length);
        await afterFrame?.call(frameBytes.length);
        return null;
      case 'finish':
        return partial!.path;
      case 'cancel':
        // Left in place on purpose: the Dart side must not depend on the
        // platform to have deleted it.
        return null;
    }
    return null;
  }
}

void main() {
  final TestWidgetsFlutterBinding binding =
      TestWidgetsFlutterBinding.ensureInitialized();
  const MethodChannel channel = VideoEncoder.defaultChannel;
  late Directory directory;
  late _FakeEncoder platform;

  setUp(() {
    directory = Directory.systemTemp.createTempSync('helixpeek-encode');
    platform = _FakeEncoder(directory);
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      platform.handle,
    );
  });

  tearDown(() {
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
    directory.deleteSync(recursive: true);
  });

  final VideoEncoder android = VideoEncoder(platform: TargetPlatform.android);
  int drawn = 0;
  Stream<ui.Image> frames(int count, {Size size = const Size(16, 16)}) {
    drawn = 0;
    return FrameRenderer(
      painter: (double t) {
        drawn++;
        return _Solid(t);
      },
      count: count,
      size: size,
    ).frames();
  }

  test('streams every frame, one call each, and finishes an MP4', () async {
    final List<int> progress = <int>[];
    final EncodeResult result = await android.encode(
      frames(6),
      30,
      fileName: 'insulin.mp4',
      onFrame: progress.add,
    );
    expect(result, isA<EncodeSuccess>());
    expect((result as EncodeSuccess).file.path, platform.partial!.path);
    expect(platform.calls, <String>[
      'begin',
      for (int i = 0; i < 6; i++) 'addFrame',
      'finish',
    ]);
    expect(platform.frameBytes, List<int>.filled(6, 16 * 16 * 4));
    expect(progress, <int>[1, 2, 3, 4, 5, 6]);
  });

  test('a pause mid-stream cancels and leaves no file', () async {
    // The engine walks through every state on its way to paused.
    platform.afterFrame = (int frames) {
      if (frames == 3) {
        for (final AppLifecycleState state in <AppLifecycleState>[
          AppLifecycleState.inactive,
          AppLifecycleState.hidden,
          AppLifecycleState.paused,
        ]) {
          binding.handleAppLifecycleStateChanged(state);
        }
      }
    };
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    addTearDown(() {
      for (final AppLifecycleState state in <AppLifecycleState>[
        AppLifecycleState.hidden,
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ]) {
        binding.handleAppLifecycleStateChanged(state);
      }
    });

    final EncodeResult result = await android.encode(frames(30), 30);

    expect(result, isA<EncodeFailure>());
    expect((result as EncodeFailure).reason, EncodeFailureReason.interrupted);
    expect(result.message, isNotEmpty);
    expect(platform.calls, contains('cancel'));
    expect(platform.calls, isNot(contains('finish')));
    expect(platform.partial!.existsSync(), isFalse);
    expect(directory.listSync(), isEmpty);
    expect(drawn, lessThanOrEqualTo(5), reason: 'the rest are never drawn');
  });

  test('the reader can stop it, and no file is left', () async {
    final Completer<void> cancel = Completer<void>();
    platform.afterFrame = (int frames) {
      if (frames == 2) {
        cancel.complete();
      }
    };
    final EncodeResult result = await android.encode(
      frames(30),
      30,
      cancel: cancel.future,
    );
    expect((result as EncodeFailure).reason, EncodeFailureReason.cancelled);
    expect(platform.calls, contains('cancel'));
    expect(directory.listSync(), isEmpty);
  });

  test('a desktop makes no clips: nothing is drawn and nothing is asked', () async {
    final EncodeResult result = await VideoEncoder(
      platform: TargetPlatform.windows,
    ).encode(frames(10), 30);
    expect((result as EncodeFailure).reason, EncodeFailureReason.unsupported);
    expect(result.message, contains('poster'));
    expect(VideoEncoder(platform: TargetPlatform.windows).isSupported, isFalse);
    expect(VideoEncoder(platform: TargetPlatform.iOS).isSupported, isTrue);
    expect(android.isSupported, isTrue);
    expect(platform.calls, isEmpty);
    expect(drawn, 0);
  });

  test('a device with no encoder for the format', () async {
    platform.failures['begin'] = PlatformException(
      code: 'unsupported',
      message: 'This device has no H.264 encoder for 16x16 at 30 fps.',
    );
    final EncodeResult result = await android.encode(frames(4), 30);
    expect((result as EncodeFailure).reason, EncodeFailureReason.noEncoder);
    expect(result.message, isNotEmpty);
    expect(directory.listSync(), isEmpty);
  });

  test('an encoder error mid-stream cancels and deletes', () async {
    platform.afterFrame = (int frames) {
      if (frames == 2) {
        platform.failures['addFrame'] = PlatformException(
          code: 'encode_failed',
          message: 'codec died',
        );
      }
    };
    final EncodeResult result = await android.encode(frames(10), 30);
    expect((result as EncodeFailure).reason, EncodeFailureReason.encoderError);
    expect(result.message, contains('codec died'));
    expect(platform.calls, contains('cancel'));
    expect(directory.listSync(), isEmpty);
  });

  test('a build with no platform side reads as unsupported', () async {
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
    final EncodeResult result = await android.encode(frames(3), 30);
    expect((result as EncodeFailure).reason, EncodeFailureReason.unsupported);
  });

  test('frames no clip can be made of', () async {
    final EncodeResult odd = await android.encode(
      frames(3, size: const Size(15, 16)),
      30,
    );
    expect((odd as EncodeFailure).reason, EncodeFailureReason.invalidFrames);
    expect(platform.calls, isEmpty);

    final EncodeResult none = await android.encode(
      const Stream<ui.Image>.empty(),
      30,
    );
    expect((none as EncodeFailure).reason, EncodeFailureReason.invalidFrames);

    final EncodeResult rate = await android.encode(frames(3), 0);
    expect((rate as EncodeFailure).reason, EncodeFailureReason.invalidFrames);
  });
}
