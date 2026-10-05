import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/core/catalog/protein_target.dart';
import 'package:helixpeek/core/theme/app_theme.dart';
import 'package:helixpeek/features/lab/zoom/domain/zoom_depth.dart';
import 'package:helixpeek/features/lab/zoom/domain/zoom_path.dart';
import 'package:helixpeek/features/lab/zoom/presentation/zoom_screen.dart';

import 'features/gene_lookup/anatomy/anatomy_fixture.dart';
import 'features/lab/replication/replication_fixtures.dart';
import 'features/lab/zoom/zoom_fixtures.dart';
import 'support/test_catalog.dart';

/// Every stop of the zoom, and moments between them, as PNGs to look at.
///
/// ZOOM_DESIGN_SHOTS=/tmp/zoom flutter test test/zoom_design_render_check.dart
///
/// ZOOM_GENES=hemoglobin,p53 narrows the proteins; ZOOM_BETWEEN=0 leaves out
/// the moments between stops. Without ZOOM_DESIGN_SHOTS it draws each frame
/// and checks nothing threw.
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
  final String directory = Platform.environment['ZOOM_DESIGN_SHOTS'] ?? '';
  final String genes = Platform.environment['ZOOM_GENES'] ?? '';
  final bool between = Platform.environment['ZOOM_BETWEEN'] != '0';
  final List<ProteinTarget> targets = genes.isEmpty
      ? <ProteinTarget>[
          TestCatalog.hemoglobin,
          TestCatalog.insulin,
          TestCatalog.dystrophin,
          TestCatalog.p53,
          TestCatalog.prion,
        ]
      : <ProteinTarget>[
          for (final String slug in genes.split(','))
            TestCatalog.bySlug(slug.trim())!,
        ];
  for (final double width in <double>[390, 320]) {
    for (final ProteinTarget target in targets) {
      testWidgets('the zoom of ${target.slug} at ${width.toInt()}px', (
        WidgetTester tester,
      ) async {
        await tester.binding.setSurfaceSize(Size(width, 844));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final ZoomDepth depth = ZoomDepth(
          locusOf(target),
          path: ZoomPath.of(locusOf(target)),
        );
        final Map<String, double> moments = <String, double>{
          for (final ZoomStop stop in ZoomStop.values) ...<String, double>{
            '${stop.index}-${stop.name}': depth.depthOf(stop),
            if (between && stop != ZoomStop.dna)
              for (final double s in <double>[0.3, 0.6])
                '${stop.index}-${stop.name}-${(s * 10).round()}':
                    depth.depthOf(stop) + s * depth.travelOf(stop.index),
          },
        };
        const Key key = ValueKey<String>('zoom-design-capture');
        for (final MapEntry<String, double> moment in moments.entries) {
          await tester.pumpWidget(
            RepaintBoundary(
              key: key,
              child: MaterialApp(
                theme: AppTheme.analysis,
                debugShowCheckedModeBanner: false,
                home: MediaQuery(
                  data: MediaQueryData(
                    size: Size(width, 844),
                    disableAnimations: true,
                  ),
                  child: ZoomScreen(
                    key: ValueKey<String>('${target.slug}-${moment.key}'),
                    target: target,
                    track: locusOf(target),
                    record: recordOf(target),
                    initialDepth: moment.value,
                  ),
                ),
              ),
            ),
          );
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
              File(
                '$directory/${target.slug}-${width.toInt()}-${moment.key}.png',
              ).writeAsBytesSync(data.buffer.asUint8List());
            });
          }
        }
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }
}
