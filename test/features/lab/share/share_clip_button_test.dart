import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/core/theme/app_theme.dart';
import 'package:helixpeek/features/lab/share/share_clip_button.dart';
import 'package:helixpeek/features/lab/share/video_encoder.dart';

import '../../../support/test_catalog.dart';

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
  const MethodChannel channel = VideoEncoder.defaultChannel;
  late Directory directory;
  late List<String> calls;
  PlatformException? beginFails;

  setUp(() {
    directory = Directory.systemTemp.createTempSync('helixpeek-clip');
    calls = <String>[];
    beginFails = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
          calls.add(call.method);
          switch (call.method) {
            case 'begin':
              if (beginFails case final PlatformException failure) {
                throw failure;
              }
              final File file = File('${directory.path}/clip.mp4')
                ..writeAsBytesSync(<int>[0]);
              return <String, Object>{'session': 1, 'path': file.path};
            case 'finish':
              return '${directory.path}/clip.mp4';
          }
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    directory.deleteSync(recursive: true);
  });

  Future<Completer<(File, String, String)>> host(
    WidgetTester tester,
    TargetPlatform platform,
  ) async {
    final Completer<(File, String, String)> shared =
        Completer<(File, String, String)>();
    final Widget flow = Scaffold(
      appBar: AppBar(
        actions: <Widget>[
          ShareClipButton(
            target: TestCatalog.insulin,
            painter: _Solid.new,
            duration: const Duration(seconds: 5),
            encoder: VideoEncoder(platform: platform),
            size: const Size(16, 32),
            pixelRatio: 1,
            fps: 2,
            shareFile:
                ({
                  required File file,
                  required String mimeType,
                  required String text,
                  Rect? origin,
                }) async {
                  shared.complete((file, mimeType, text));
                },
          ),
        ],
      ),
    );
    // As the lab has it: a shell with a navigator of its own, the flow's page
    // over the picker's.
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.analysis,
        home: Navigator(
          onGenerateInitialRoutes: (NavigatorState _, String _) =>
              <Route<void>>[
                MaterialPageRoute<void>(
                  builder: (BuildContext context) =>
                      const Scaffold(body: Text('picker')),
                ),
                MaterialPageRoute<void>(
                  builder: (BuildContext context) => flow,
                ),
              ],
        ),
      ),
    );
    return shared;
  }

  /// Lets the real rendering run, a slice of real time per pump.
  Future<void> settle(WidgetTester tester, bool Function() done) async {
    for (int i = 0; i < 400 && !done(); i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }
    await tester.pump();
  }

  testWidgets('on iOS there is no clip to offer, only the poster', (
    WidgetTester tester,
  ) async {
    await host(tester, TargetPlatform.iOS);
    expect(find.byTooltip('Share a clip'), findsNothing);
  });

  testWidgets('on Android it makes the clip and shares the MP4', (
    WidgetTester tester,
  ) async {
    final Completer<(File, String, String)> shared = await host(
      tester,
      TargetPlatform.android,
    );
    await tester.tap(find.byTooltip('Share a clip'));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('Making a clip'), findsOneWidget);
    await settle(tester, () => shared.isCompleted);

    final (File file, String type, String text) = await shared.future;
    expect(file.path, endsWith('clip.mp4'));
    expect(type, 'video/mp4');
    expect(text, 'Insulin in Helix Peek: helixpeek://open/gene/insulin');
    // Five seconds at two frames a second.
    expect(calls.where((String c) => c == 'addFrame'), hasLength(10));
    expect(calls.last, 'finish');
    expect(find.text('Making a clip'), findsNothing);
    // The dialog is what closed, not the flow's page under it.
    expect(find.byTooltip('Share a clip'), findsOneWidget);
    expect(find.text('picker'), findsNothing);
  });

  testWidgets('a failure is said in a line, and no dialog is left', (
    WidgetTester tester,
  ) async {
    beginFails = PlatformException(code: 'unsupported');
    await host(tester, TargetPlatform.android);
    await tester.tap(find.byTooltip('Share a clip'));
    await tester.pump(const Duration(milliseconds: 50));
    await settle(
      tester,
      () => find.textContaining('no video encoder').evaluate().isNotEmpty,
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Making a clip'), findsNothing);
    expect(find.textContaining('no video encoder'), findsOneWidget);
  });
}
