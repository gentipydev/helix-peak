import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/core/theme/app_theme.dart';
import 'package:helixpeek/features/gene_lookup/presentation/anatomy/anatomy_screen.dart';
import 'package:helixpeek/shared/ribosome/translation_player.dart';
import 'package:helixpeek/shared/ribosome/translation_timeline.dart';

import 'features/gene_lookup/anatomy/anatomy_fixture.dart';
import 'support/test_catalog.dart';

// RIBOSOME_DESIGN_SHOTS=/tmp/ribosome flutter test test/ribosome_design_render_check.dart
// Review the real walk with its header, captions and controls at both widths.
void main() {
  setUpAll(() async {
    await loadAppFonts();
    // Widget tests do not install the SDK's fallback and icon fonts. Load
    // them for faithful review captures without changing the app theme.
    final String sdkFonts =
        '${File(Platform.resolvedExecutable).parent.parent.parent.path}/material_fonts';
    for (final (String family, String filename) in <(String, String)>[
      ('Roboto', 'Roboto-Regular.ttf'),
      ('MaterialIcons', 'MaterialIcons-Regular.otf'),
    ]) {
      final File file = File('$sdkFonts/$filename');
      if (file.existsSync()) {
        final FontLoader loader = FontLoader(family)
          ..addFont(
            Future<ByteData>.value(
              ByteData.sublistView(file.readAsBytesSync()),
            ),
          );
        await loader.load();
      }
    }
  });
  final String directory = Platform.environment['RIBOSOME_DESIGN_SHOTS'] ?? '';
  for (final double width in <double>[390, 320]) {
    testWidgets('ribosome cutaway in the walk at ${width.toInt()}px', (
      WidgetTester tester,
    ) async {
      await tester.binding.setSurfaceSize(Size(width, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      const Key captureKey = ValueKey<String>('ribosome-design-capture');
      await tester.pumpWidget(
        RepaintBoundary(
          key: captureKey,
          child: MaterialApp(
            theme: AppTheme.analysis,
            debugShowCheckedModeBanner: false,
            home: AnatomyScreen(target: TestCatalog.insulin, record: insulin()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final Rect screen = tester.getRect(find.byType(AnatomyScreen));
      await tester.dragFrom(
        Offset(screen.center.dx, screen.bottom - 40),
        const Offset(-160, 0),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey<String>('open-ribosome')));
      await tester.pump();
      final TranslationPlayer player = tester.widget(
        find.byType(TranslationPlayer),
      );
      player.controller.pause();
      final TranslationTimeline timeline = player.translation;
      final Map<String, double> moments = <String, double>{
        'scanning': 1.5,
        'joining': 3.6,
        'decoding': timeline.beatOfCodon(3) + 0.34,
        'bond': timeline.beatOfCodon(3) + 0.54,
        'translocation': timeline.beatOfCodon(3) + 0.7,
        'growing': timeline.beatOfCodon(60) + 0.34,
        'stop': timeline.firstTerminationBeat + 0.99,
        'release': timeline.firstTerminationBeat + 1.7,
        'dissociation': timeline.firstTerminationBeat + 2.65,
      };
      for (final MapEntry<String, double> moment in moments.entries) {
        player.controller.seek(timeline.beatStart(moment.value));
        await tester.pump();
        expect(tester.takeException(), isNull, reason: moment.key);
        if (directory.isNotEmpty) {
          await tester.runAsync(() async {
            Directory(directory).createSync(recursive: true);
            final RenderRepaintBoundary boundary = tester.renderObject(
              find.byKey(captureKey),
            );
            final ui.Image image = await boundary.toImage(pixelRatio: 2);
            final ByteData data = (await image.toByteData(
              format: ui.ImageByteFormat.png,
            ))!;
            image.dispose();
            File('$directory/${width.toInt()}-${moment.key}.png')
                .writeAsBytesSync(data.buffer.asUint8List());
          });
        }
      }
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
