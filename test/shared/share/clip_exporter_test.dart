import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/core/theme/app_theme.dart';
import 'package:helixpeek/shared/share/clip_exporter.dart';
import 'package:helixpeek/shared/share/clip_keep_alive.dart';
import 'package:helixpeek/shared/share/video_encoder.dart';

import '../../support/test_catalog.dart';

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

void main() {
  final TestWidgetsFlutterBinding binding =
      TestWidgetsFlutterBinding.ensureInitialized();
  const MethodChannel channel = VideoEncoder.defaultChannel;
  late Directory directory;
  late List<String> calls;
  late List<(File, String, String)> shared;
  PlatformException? beginFails;

  /// Called after each frame the platform takes, with how many it has.
  void Function(int frames)? afterFrame;

  setUp(() {
    directory = Directory.systemTemp.createTempSync('helixpeek-exporter');
    calls = <String>[];
    shared = <(File, String, String)>[];
    beginFails = null;
    afterFrame = null;
    int frames = 0;
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      MethodCall call,
    ) async {
      calls.add(call.method);
      switch (call.method) {
        case 'begin':
          if (beginFails case final PlatformException failure) {
            throw failure;
          }
          frames = 0;
          final File file = File('${directory.path}/clip.mp4')
            ..writeAsBytesSync(<int>[0]);
          return <String, Object>{'session': 1, 'path': file.path};
        case 'addFrame':
          afterFrame?.call(++frames);
          return null;
        case 'finish':
          return '${directory.path}/clip.mp4';
      }
      return null;
    });
  });

  tearDown(() {
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
    directory.deleteSync(recursive: true);
  });

  ClipExporter exporter() => ClipExporter(
    encoder: VideoEncoder(platform: TargetPlatform.android),
    shareFile:
        ({
          required File file,
          required String mimeType,
          required String text,
          Rect? origin,
        }) async {
          shared.add((file, mimeType, text));
        },
    pace: () async {},
  );

  /// Five seconds at two frames a second: ten frames.
  bool start(ClipExporter clips) => clips.start(
    target: TestCatalog.insulin,
    painter: _Solid.new,
    duration: const Duration(seconds: 5),
    theme: AppTheme.analysis,
    size: const Size(16, 32),
    pixelRatio: 1,
    fps: 2,
  );

  /// Until [done], or two seconds.
  Future<void> until(bool Function() done) async {
    for (int i = 0; i < 200 && !done(); i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
  }

  test('a clip is made, frame by frame, and waits to be shared', () async {
    final ClipExporter clips = exporter();
    final List<ClipJob?> seen = <ClipJob?>[];
    clips.job.addListener(() => seen.add(clips.job.value));

    expect(start(clips), isTrue);
    expect(clips.job.value!.status, ClipStatus.making);
    expect(clips.job.value!.total, 10);
    expect(clips.job.value!.target, TestCatalog.insulin);
    await until(() => clips.job.value?.status == ClipStatus.ready);

    final ClipJob job = clips.job.value!;
    expect(job.done, 10);
    expect(job.file!.path, endsWith('clip.mp4'));
    expect(calls.where((String c) => c == 'addFrame'), hasLength(10));
    final List<int> done = <int>[for (final ClipJob? j in seen) j!.done];
    expect(done, orderedEquals(<int>[...done]..sort()));
    expect(shared, isEmpty, reason: 'nothing is shared unasked');

    await clips.share();
    final (File file, String type, String text) = shared.single;
    expect(file.path, job.file!.path);
    expect(type, 'video/mp4');
    expect(text, 'Insulin in Helix Peek: helixpeek://open/gene/insulin');

    clips.clear();
    expect(clips.job.value, isNull);
    clips.dispose();
  });

  test('one clip at a time', () async {
    final ClipExporter clips = exporter();
    expect(start(clips), isTrue);
    expect(start(clips), isFalse);
    await until(() => clips.job.value?.status == ClipStatus.ready);
    // A made clip gives way to the next.
    expect(start(clips), isTrue);
    await until(() => clips.job.value?.status == ClipStatus.ready);
    clips.dispose();
  });

  test('a clip being made cannot be put away, only stopped', () async {
    final ClipExporter clips = exporter();
    afterFrame = (int frames) {
      if (frames == 3) {
        clips.clear();
        expect(clips.job.value, isNotNull);
        clips.cancel();
      }
    };
    start(clips);
    await until(() => clips.job.value == null);
    expect(clips.job.value, isNull);
    expect(calls, contains('cancel'));
    expect(calls, isNot(contains('finish')));
    expect(directory.listSync(), isEmpty, reason: 'no partial file is left');
    clips.dispose();
  });

  test('a clip that fails says why, and can be tried again', () async {
    final ClipExporter clips = exporter();
    beginFails = PlatformException(code: 'encode_failed', message: 'busy');
    start(clips);
    await until(() => clips.job.value?.status == ClipStatus.failed);
    final ClipJob failed = clips.job.value!;
    expect(failed.failure!.reason, EncodeFailureReason.encoderError);
    expect(failed.failure!.message, contains('busy'));
    expect(failed.underway, isFalse);

    beginFails = null;
    expect(clips.retry(), isTrue);
    await until(() => clips.job.value?.status == ClipStatus.ready);
    expect(clips.retry(), isFalse, reason: 'only a failed clip is retried');
    clips.dispose();
  });

  group('kept going outside the app', () {
    const MethodChannel keepAlive = ClipKeepAlive.defaultChannel;
    late List<MethodCall> kept;
    String answer = 'goes_on';

    setUp(() {
      kept = <MethodCall>[];
      answer = 'goes_on';
      binding.defaultBinaryMessenger.setMockMethodCallHandler(keepAlive, (
        MethodCall call,
      ) async {
        kept.add(call);
        return call.method == 'begin' ? answer : null;
      });
    });

    tearDown(
      () => binding.defaultBinaryMessenger.setMockMethodCallHandler(
        keepAlive,
        null,
      ),
    );

    /// What the platform says to the app, as the service would.
    Future<void> platformSays(String method) =>
        binding.defaultBinaryMessenger.handlePlatformMessage(
          keepAlive.name,
          keepAlive.codec.encodeMethodCall(MethodCall(method)),
          (ByteData? _) {},
        );

    test('the platform is asked to keep it going, told how far it has got, '
        'and told when it is made', () async {
      final ClipExporter clips = exporter();
      start(clips);
      await until(() => clips.job.value?.status == ClipStatus.ready);
      await until(() => kept.any((MethodCall c) => c.method == 'end'));

      expect(kept.first.method, 'begin');
      expect(kept.first.arguments, <String, Object>{
        'title': 'INS',
        'total': 10,
      });
      expect(clips.job.value!.away, ClipAway.goesOn);
      final List<MethodCall> progress = <MethodCall>[
        for (final MethodCall c in kept)
          if (c.method == 'progress') c,
      ];
      expect(progress, isNotEmpty);
      expect(
        (progress.last.arguments as Map<Object?, Object?>)['done'],
        10,
        reason: 'the last frame is always said',
      );
      expect(
        progress.length,
        lessThan(10),
        reason: 'not every frame: at most one in a quarter second',
      );
      final Map<Object?, Object?> end =
          kept.last.arguments as Map<Object?, Object?>;
      expect(kept.last.method, 'end');
      expect(end['ready'], isTrue);
      expect(end['title'], 'INS');
      clips.dispose();
    });

    test('where the platform will not, leaving the app stops it', () async {
      answer = 'stops';
      final ClipExporter clips = exporter();
      start(clips);
      await until(() => clips.job.value?.away == ClipAway.stops);
      expect(clips.job.value!.away, ClipAway.stops);
      await until(() => clips.job.value?.status == ClipStatus.ready);
      clips.dispose();
    });

    test('stopped from its notification, the clip goes', () async {
      final ClipExporter clips = exporter();
      afterFrame = (int frames) {
        if (frames == 2) {
          unawaited(platformSays('cancel'));
        }
      };
      start(clips);
      await until(() => clips.job.value == null);
      expect(clips.job.value, isNull);
      expect(calls, contains('cancel'));
      await until(() => kept.any((MethodCall c) => c.method == 'end'));
      expect((kept.last.arguments as Map<Object?, Object?>)['ready'], isFalse);
      clips.dispose();
    });

    test(
      'stopped by the platform, the clip fails and can be tried again',
      () async {
        final ClipExporter clips = exporter();
        afterFrame = (int frames) {
          if (frames == 2) {
            unawaited(platformSays('stopped'));
          }
        };
        start(clips);
        await until(() => clips.job.value?.status == ClipStatus.failed);
        final EncodeFailure failure = clips.job.value!.failure!;
        expect(failure.reason, EncodeFailureReason.interrupted);
        expect(failure.message, contains('Try again'));
        afterFrame = null;
        expect(clips.retry(), isTrue);
        await until(() => clips.job.value?.status == ClipStatus.ready);
        clips.dispose();
      },
    );
  });

  test('a sheet watching the clip is counted', () {
    final ClipExporter clips = exporter();
    expect(clips.watched, isFalse);
    clips
      ..watch()
      ..watch()
      ..unwatch();
    expect(clips.watched, isTrue);
    clips
      ..unwatch()
      ..unwatch();
    expect(clips.watched, isFalse);
    clips.dispose();
  });

  test('a clip is held to five to fifteen seconds', () {
    expect(ClipExporter.frameCount(const Duration(seconds: 1), 30), 150);
    expect(ClipExporter.frameCount(const Duration(seconds: 9), 30), 270);
    expect(ClipExporter.frameCount(const Duration(minutes: 1), 30), 450);
  });
}
