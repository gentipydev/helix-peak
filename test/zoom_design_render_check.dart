import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/core/catalog/protein_target.dart';
import 'package:helixpeek/core/theme/app_theme.dart';
import 'package:helixpeek/core/theme/scale_colors.dart';
import 'package:helixpeek/features/zoom/domain/anatomy_figure.dart';
import 'package:helixpeek/features/zoom/domain/anatomy_tables.dart';
import 'package:helixpeek/features/zoom/domain/cell_archetypes.dart';
import 'package:helixpeek/features/zoom/domain/zoom_depth.dart';
import 'package:helixpeek/features/zoom/domain/zoom_path.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/contour.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/organ_art.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/tissue/tissue_slide.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/tissue_scene.dart';
import 'package:helixpeek/features/zoom/presentation/zoom_inks.dart';
import 'package:helixpeek/features/zoom/presentation/zoom_screen.dart';

import 'features/gene_lookup/anatomy/anatomy_fixture.dart';
import 'features/lab/replication/replication_fixtures.dart';
import 'features/zoom/zoom_fixtures.dart';
import 'support/test_catalog.dart';

/// Every stop of the zoom, and moments between them, as PNGs to look at.
///
/// ZOOM_DESIGN_SHOTS=/tmp/zoom flutter test test/zoom_design_render_check.dart
///
/// ZOOM_GENES=hemoglobin,p53 narrows the proteins; ZOOM_BETWEEN=0 leaves out
/// the moments between stops. Without ZOOM_DESIGN_SHOTS it draws each frame
/// and checks nothing threw.
///
/// ZOOM_TISSUE_ATLAS=/tmp/atlas writes every tissue recipe's slide on its
/// own, and ZOOM_ORGAN_ATLAS=/tmp/organs every tissue's organ, whichever
/// proteins go there: the ones no catalog protein reaches are seen nowhere
/// else.
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

  testWidgets('every tissue has an organ to draw', (WidgetTester tester) async {
    final String atlas = Platform.environment['ZOOM_ORGAN_ATLAS'] ?? '';
    const double side = 360;
    await tester.binding.setSurfaceSize(const Size(side, side));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    const Key key = ValueKey<String>('zoom-organ-atlas');
    late ZoomInks inks;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.analysis,
        home: Builder(
          builder: (BuildContext context) {
            inks = ZoomInks.of(context);
            return const SizedBox();
          },
        ),
      ),
    );
    for (final MapEntry<String, TissueAnatomy> tissue
        in tissueAnatomy.entries) {
      final AnatomyFigure body = AnatomyFigure.bodyFor(
        tissue.key,
        const <String>[],
      );
      final OrganArt art = OrganArt.forTissue(
        tissue.value,
        body.parts[tissue.value.uberon],
        tissue.value.metres * ZoomDepth.organMargin,
      );
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: CustomPaint(
            size: const Size(side, side),
            painter: _OrganPainter(art, inks),
          ),
        ),
      );
      expect(tester.takeException(), isNull, reason: tissue.key);
      if (atlas.isNotEmpty) {
        await tester.runAsync(() async {
          Directory(atlas).createSync(recursive: true);
          final RenderRepaintBoundary boundary = tester.renderObject(
            find.byKey(key),
          );
          final ui.Image image = await boundary.toImage(pixelRatio: 2);
          final ByteData data = (await image.toByteData(
            format: ui.ImageByteFormat.png,
          ))!;
          image.dispose();
          File('$atlas/${tissue.key.replaceAll(' ', '_')}.png')
              .writeAsBytesSync(data.buffer.asUint8List());
        });
      }
    }
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('every tissue recipe lays a slide', (WidgetTester tester) async {
    final String atlas = Platform.environment['ZOOM_TISSUE_ATLAS'] ?? '';
    const double side = 440;
    await tester.binding.setSurfaceSize(const Size(side, side));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    const Key key = ValueKey<String>('zoom-tissue-atlas');
    final List<(String, TissueRecipe, CellShape)> slides =
        <(String, TissueRecipe, CellShape)>[
          for (final TissueRecipe recipe in TissueRecipe.values)
            (recipe.name, recipe, shapeOfTissue(recipe)),
          // The same tissue about another kind of cell.
          ('acinar-islet', TissueRecipe.acinar, CellShape.endocrine),
          ('acinar-duct', TissueRecipe.acinar, CellShape.epithelial),
          ('marrow-island', TissueRecipe.marrow, CellShape.erythroid),
          ('lymphoid-sinus', TissueRecipe.lymphoid, CellShape.endothelial),
          ('gastric-dividing', TissueRecipe.gastric, CellShape.dividing),
          ('glandular-ciliated', TissueRecipe.glandular, CellShape.ciliated),
          ('seminiferous-germ', TissueRecipe.seminiferous, CellShape.germ),
        ];
    for (final (String name, TissueRecipe recipe, CellShape shape) in slides) {
      final CellArchetype archetype = archetypeFor(shape);
      final (Contour target, Contour nucleus) = TissueScene.targetOf(
        archetype,
        archetype.viewMetres,
      );
      final Stopwatch watch = Stopwatch()..start();
      final TissueSlide slide = TissueSlide.of(
        recipe,
        field: ZoomDepth.tissueField * 1e6 / 2,
        shape: shape,
        target: target,
        targetNucleus: nucleus,
        seed: recipe.index + 3,
      );
      watch.stop();
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: CustomPaint(
            size: const Size(side, side),
            painter: _SlidePainter(slide, target),
          ),
        ),
      );
      expect(tester.takeException(), isNull, reason: name);
      if (atlas.isNotEmpty) {
        // ignore: avoid_print
        print('$name: laid in ${watch.elapsedMilliseconds} ms');
        await tester.runAsync(() async {
          Directory(atlas).createSync(recursive: true);
          final RenderRepaintBoundary boundary = tester.renderObject(
            find.byKey(key),
          );
          final ui.Image image = await boundary.toImage(pixelRatio: 2);
          final ByteData data = (await image.toByteData(
            format: ui.ImageByteFormat.png,
          ))!;
          image.dispose();
          File('$atlas/$name.png').writeAsBytesSync(data.buffer.asUint8List());
        });
      }
    }
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

/// One organ on its own, at the size its scene shows it at its stop.
class _OrganPainter extends CustomPainter {
  _OrganPainter(this.art, this.inks);

  final OrganArt art;
  final ZoomInks inks;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = inks.ground);
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(size.width);
    art.paint(canvas, inks, 1 / size.width, 1);
    canvas.drawCircle(
      art.site,
      0.03,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2 / size.width
        ..color = inks.mark,
    );
  }

  @override
  bool shouldRepaint(covariant _OrganPainter old) => old.art != art;
}

/// One slide on its own, its field filling the square.
class _SlidePainter extends CustomPainter {
  _SlidePainter(this.slide, this.target);

  final TissueSlide slide;
  final Contour target;

  @override
  void paint(Canvas canvas, Size size) {
    const ScaleColors colors = ScaleColors.analysis;
    const double field = ZoomDepth.tissueField * 1e6 / 2;
    final double perMicron = size.width / 2 / (field + 4);
    canvas.drawRect(Offset.zero & size, Paint()..color = colors.eyepiece);
    final Path lens = Path()
      ..addOval(
        Rect.fromCircle(
          center: size.center(Offset.zero),
          radius: field * perMicron,
        ),
      );
    canvas.clipPath(lens);
    canvas.drawPath(lens, Paint()..color = colors.brightfield);
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(perMicron);
    paintTissueSlide(canvas, slide, colors, pixel: 1 / perMicron);
    canvas.drawPath(
      target.toPath(),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2 / perMicron
        ..color = AppTheme.analysis.colorScheme.primary,
    );
  }

  @override
  bool shouldRepaint(covariant _SlidePainter old) => old.slide != slide;
}
