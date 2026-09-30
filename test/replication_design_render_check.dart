import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/core/theme/app_theme.dart';
import 'package:helixpeek/features/lab/replication/domain/replication_tour.dart';
import 'package:helixpeek/features/lab/replication/presentation/replication_screen.dart';
import 'package:helixpeek/shared/motion/timeline_controller.dart';
import 'package:helixpeek/shared/motion/transport_bar.dart';

import 'features/gene_lookup/anatomy/anatomy_fixture.dart';

// REPLICATION_DESIGN_SHOTS=/tmp/replication flutter test test/replication_design_render_check.dart
void main() {
  setUpAll(() async {
    await loadAppFonts();
    final String sdkFonts =
        '${File(Platform.resolvedExecutable).parent.parent.parent.path}/material_fonts';
    for (final (String family, String filename) in <(String, String)>[
      ('Roboto', 'Roboto-Regular.ttf'),
      ('MaterialIcons', 'MaterialIcons-Regular.otf'),
    ]) {
      final File file = File('$sdkFonts/$filename');
      if (!file.existsSync()) continue;
      await (FontLoader(family)..addFont(
            Future<ByteData>.value(
              ByteData.sublistView(file.readAsBytesSync()),
            ),
          ))
          .load();
    }
  });
  final String directory =
      Platform.environment['REPLICATION_DESIGN_SHOTS'] ?? '';
  for (final double width in <double>[390, 320]) {
    testWidgets('replication phases at ${width.toInt()}px', (
      WidgetTester tester,
    ) async {
      await tester.binding.setSurfaceSize(Size(width, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      const Key key = ValueKey<String>('replication-design-capture');
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: MaterialApp(
            theme: AppTheme.analysis,
            debugShowCheckedModeBanner: false,
            home: const ReplicationScreen(),
          ),
        ),
      );
      final TimelineController c =
          tester.widget<TransportBar>(find.byType(TransportBar)).controller
            ..pause();
      for (final MapEntry<String, double> moment in <String, double>{
        for (final ReplicationChapter chapter in ReplicationChapter.values)
          chapter.name:
              chapter.second + (chapter == ReplicationChapter.overview ? 0 : 3),
        'handoff': 54,
        'joined': 149,
      }.entries) {
        c.seek(moment.value / ReplicationTimeline.durationSeconds);
        await tester.pump();
        expect(tester.takeException(), isNull, reason: moment.key);
        if (directory.isNotEmpty) {
          await tester.runAsync(() async {
            Directory(directory).createSync(recursive: true);
            final RenderRepaintBoundary boundary = tester.renderObject(
              find.byKey(key),
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
