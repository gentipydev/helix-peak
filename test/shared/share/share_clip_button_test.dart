import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/core/catalog/protein_target.dart';
import 'package:helixpeek/core/theme/app_theme.dart';
import 'package:helixpeek/shared/share/clip_exporter.dart';
import 'package:helixpeek/shared/share/clip_sheet.dart';
import 'package:helixpeek/shared/share/share_clip_button.dart';
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

final Finder _button = find.byTooltip('Share a clip');
final Finder _ring = find.byKey(const ValueKey<String>('share-clip-progress'));

void main() {
  const MethodChannel channel = VideoEncoder.defaultChannel;
  late Directory directory;
  late List<String> calls;
  late List<(File, String, String)> shared;
  PlatformException? beginFails;

  setUp(() {
    directory = Directory.systemTemp.createTempSync('helixpeek-clip');
    calls = <String>[];
    shared = <(File, String, String)>[];
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

  Future<void> shareFile({
    required File file,
    required String mimeType,
    required String text,
    Rect? origin,
  }) async {
    shared.add((file, mimeType, text));
  }

  ClipExporter exporterFor(TargetPlatform platform) => ClipExporter(
    encoder: VideoEncoder(platform: platform),
    shareFile: shareFile,
    pace: () async {},
  );

  Widget button(ProteinTarget target) => ShareClipButton(
    target: target,
    painter: _Solid.new,
    duration: const Duration(seconds: 5),
    size: const Size(16, 32),
    pixelRatio: 1,
    fps: 2,
  );

  /// The app as it has it: one exporter above everything and the listener
  /// that says when a clip is ready, and, as the lab has it, a shell with a
  /// navigator of its own and the flow's page over the picker's.
  Future<ClipExporter> host(
    WidgetTester tester,
    TargetPlatform platform, {
    List<ProteinTarget>? targets,
  }) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final ClipExporter exporter = exporterFor(platform);
    addTearDown(exporter.dispose);
    final Widget flow = Scaffold(
      appBar: AppBar(
        actions: <Widget>[
          for (final ProteinTarget target
              in targets ?? <ProteinTarget>[TestCatalog.insulin])
            button(target),
        ],
      ),
    );
    await tester.pumpWidget(
      RepositoryProvider<ClipExporter>.value(
        value: exporter,
        child: MaterialApp(
          theme: AppTheme.analysis,
          builder: (BuildContext context, Widget? child) =>
              ClipReadyListener(child: child!),
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
      ),
    );
    return exporter;
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

  /// Puts the sheet away, as a tap above it does.
  Future<void> putAway(WidgetTester tester) async {
    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();
  }

  testWidgets('where clips cannot be made there is no clip to offer', (
    WidgetTester tester,
  ) async {
    await host(tester, TargetPlatform.windows);
    expect(_button, findsNothing);
  });

  testWidgets('on iOS there is a clip to offer', (WidgetTester tester) async {
    await host(tester, TargetPlatform.iOS);
    expect(_button, findsOneWidget);
  });

  testWidgets('it makes the clip in a sheet, and shares it only when asked', (
    WidgetTester tester,
  ) async {
    final ClipExporter exporter = await host(tester, TargetPlatform.android);
    await tester.tap(_button);
    // The sheet is pushed on this frame, and up by the next.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Making a clip'), findsOneWidget);
    expect(find.text('INS · Insulin'), findsOneWidget);
    await settle(tester, () => find.text('Clip ready').evaluate().isNotEmpty);

    expect(find.text('Clip ready'), findsOneWidget);
    // Five seconds at two frames a second.
    expect(calls.where((String c) => c == 'addFrame'), hasLength(10));
    expect(calls.last, 'finish');
    expect(shared, isEmpty, reason: 'the share sheet waits for a tap');
    // The sheet was watching, so no snackbar says it again.
    expect(find.textContaining('Clip ready ·'), findsNothing);

    await tester.tap(find.byKey(const ValueKey<String>('clip-share')));
    await settle(tester, () => shared.isNotEmpty);
    final (File file, String type, String text) = shared.single;
    expect(file.path, endsWith('clip.mp4'));
    expect(type, 'video/mp4');
    expect(text, 'Insulin in Helix Peek: helixpeek://open/gene/insulin');

    await tester.tap(find.byKey(const ValueKey<String>('clip-done')));
    await tester.pumpAndSettle();
    expect(find.text('Clip ready'), findsNothing);
    expect(exporter.job.value, isNull);
    // The sheet is what closed, not the flow's page under it.
    expect(_button, findsOneWidget);
    expect(find.text('picker'), findsNothing);
  });

  testWidgets(
    'put away, the clip goes on: the button wears its progress, and a '
    'snackbar says when it is ready',
    (WidgetTester tester) async {
      final ClipExporter exporter = await host(tester, TargetPlatform.android);
      await tester.tap(_button);
      // The sheet is up.
      await tester.pump(const Duration(milliseconds: 400));
      await putAway(tester);
      expect(find.text('Making a clip'), findsNothing);
      expect(exporter.job.value?.status, ClipStatus.making);
      expect(_ring, findsOneWidget);

      await settle(
        tester,
        () => find.text('Clip ready · INS').evaluate().isNotEmpty,
      );
      expect(find.text('Clip ready · INS'), findsOneWidget);
      expect(_ring, findsNothing);
      expect(shared, isEmpty);

      // The snackbar slides in before its action can be tapped.
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.text('Share'));
      await settle(tester, () => shared.isNotEmpty);
      expect(shared.single.$2, 'video/mp4');

      // The made clip is still there to share from the sheet.
      await tester.tap(_button);
      await tester.pumpAndSettle();
      expect(find.text('Clip ready'), findsOneWidget);
    },
  );

  testWidgets('the ring keeps the button its size', (
    WidgetTester tester,
  ) async {
    await host(tester, TargetPlatform.android);
    final Size before = tester.getSize(_button);
    await tester.tap(_button);
    // The sheet is pushed on this frame, and up by the next.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await putAway(tester);
    expect(_ring, findsOneWidget);
    expect(tester.getSize(_button), before);
    await settle(tester, () => find.byType(SnackBar).evaluate().isNotEmpty);
  });

  testWidgets('a clip of another protein being made is shown, not doubled', (
    WidgetTester tester,
  ) async {
    await host(
      tester,
      TargetPlatform.android,
      targets: <ProteinTarget>[TestCatalog.insulin, TestCatalog.hemoglobin],
    );
    await tester.tap(_button.first);
    // The sheet is pushed on this frame, and up by the next.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await putAway(tester);
    expect(_ring, findsOneWidget, reason: 'only on the protein it is of');

    await tester.tap(_button.last);
    // The sheet is pushed on this frame, and up by the next.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('INS · Insulin'), findsOneWidget);
    expect(calls.where((String c) => c == 'begin'), hasLength(1));
    await settle(tester, () => find.text('Clip ready').evaluate().isNotEmpty);
  });

  testWidgets('it can be stopped from the sheet', (WidgetTester tester) async {
    final ClipExporter exporter = await host(tester, TargetPlatform.android);
    await tester.tap(_button);
    // The sheet is pushed on this frame, and up by the next.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.byKey(const ValueKey<String>('clip-cancel')));
    await settle(tester, () => exporter.job.value == null);
    await tester.pumpAndSettle();
    expect(exporter.job.value, isNull);
    expect(find.text('Making a clip'), findsNothing);
    expect(calls, isNot(contains('finish')));
    expect(directory.listSync(), isEmpty);
  });

  testWidgets('a failure is said in the sheet', (WidgetTester tester) async {
    beginFails = PlatformException(code: 'unsupported');
    final ClipExporter exporter = await host(tester, TargetPlatform.android);
    await tester.tap(_button);
    // The sheet is pushed on this frame, and up by the next.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await settle(
      tester,
      () => find.textContaining('no video encoder').evaluate().isNotEmpty,
    );
    expect(find.text('Clip not made'), findsOneWidget);
    expect(find.textContaining('no video encoder'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey<String>('clip-close')));
    await tester.pumpAndSettle();
    expect(find.text('Clip not made'), findsNothing);
    expect(exporter.job.value, isNull);
  });

  testWidgets('with no exporter above it, the button makes its own', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.analysis,
        home: Scaffold(
          appBar: AppBar(
            actions: <Widget>[
              ShareClipButton(
                target: TestCatalog.insulin,
                painter: _Solid.new,
                duration: const Duration(seconds: 5),
                encoder: VideoEncoder(platform: TargetPlatform.android),
                shareFile: shareFile,
                size: const Size(16, 32),
                pixelRatio: 1,
                fps: 2,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.tap(_button);
    // The sheet is pushed on this frame, and up by the next.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Making a clip'), findsOneWidget);
    await settle(tester, () => find.text('Clip ready').evaluate().isNotEmpty);
    expect(find.text('Clip ready'), findsOneWidget);
  });
}
