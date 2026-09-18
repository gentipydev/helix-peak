import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeak/core/theme/app_theme.dart';
import 'package:helixpeak/features/gene_lookup/presentation/structure/structure_loading_view.dart';
import 'package:lottie/lottie.dart';

const Key _captureKey = ValueKey<String>('loading-capture');

Future<void> _pump(WidgetTester tester, {bool reducedMotion = false}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.analysis,
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reducedMotion),
        child: const Center(
          child: SizedBox.square(
            dimension: 160,
            child: RepaintBoundary(
              key: _captureKey,
              child: StructureLoadingView(),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

Future<Uint8List> _pixels(WidgetTester tester) async {
  final RenderRepaintBoundary boundary = tester.renderObject(
    find.byKey(_captureKey),
  );
  return (await tester.runAsync(() async {
    final ui.Image image = await boundary.toImage();
    final ByteData data = (await image.toByteData())!;
    image.dispose();
    return data.buffer.asUint8List();
  }))!;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(StructureLoadingView.preload);

  testWidgets('bundled green pulse renders and advances while loading', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    await _pump(tester);
    expect(find.bySemanticsLabel('Loading protein structure'), findsOneWidget);
    semantics.dispose();
    expect(tester.widget<Lottie>(find.byType(Lottie)).composition, isNotNull);
    await tester.pump(const Duration(milliseconds: 500));
    final Uint8List first = await _pixels(tester);
    expect(<int>[
      for (int i = 3; i < first.length; i += 4) first[i],
    ], contains(greaterThan(0)));
    await tester.pump(const Duration(milliseconds: 500));
    expect(await _pixels(tester), isNot(orderedEquals(first)));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(tester.binding.transientCallbackCount, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reduced motion keeps a visible pulse still', (
    WidgetTester tester,
  ) async {
    await _pump(tester, reducedMotion: true);
    final Uint8List first = await _pixels(tester);
    expect(<int>[
      for (int i = 3; i < first.length; i += 4) first[i],
    ], contains(greaterThan(0)));
    await tester.pump(const Duration(seconds: 1));
    expect(await _pixels(tester), orderedEquals(first));
    expect(tester.binding.transientCallbackCount, 0);
    expect(tester.takeException(), isNull);
  });
}
