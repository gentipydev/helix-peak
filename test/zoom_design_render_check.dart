import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/core/catalog/protein_target.dart';
import 'package:helixpeek/core/theme/app_theme.dart';
import 'package:helixpeek/features/zoom/domain/anatomy_figure.dart';
import 'package:helixpeek/features/zoom/domain/anatomy_tables.dart';
import 'package:helixpeek/features/zoom/domain/cell_archetypes.dart';
import 'package:helixpeek/features/zoom/domain/zoom_depth.dart';
import 'package:helixpeek/features/zoom/domain/zoom_path.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/contour.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/organ_art.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/organs/kidney/kidney_form.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/organs/liver/liver_form.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/organs/stomach/stomach_form.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/sculpt.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/tissue/tissue_slide.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/tissue_scene.dart';
import 'package:helixpeek/features/zoom/presentation/zoom_inks.dart';
import 'package:helixpeek/features/zoom/presentation/zoom_screen.dart';

import 'features/gene_lookup/anatomy/anatomy_fixture.dart';
import 'features/zoom/record_fixtures.dart';
import 'features/zoom/zoom_fixtures.dart';
import 'support/test_catalog.dart';

/// Every stop of the zoom, and moments between them, as PNGs to look at.
///
/// ZOOM_DESIGN_SHOTS=/tmp/zoom flutter test test/zoom_design_render_check.dart
///
/// ZOOM_GENES=hemoglobin,p53 narrows the proteins; ZOOM_BETWEEN=0 leaves out
/// the moments between stops. ZOOM_MOMENTS=nucleus+2,nucleus+10,chromosome
/// draws those moments and no others: a stop, or the share of the step that
/// leaves it, in percent. Without ZOOM_DESIGN_SHOTS it draws each frame and
/// checks nothing threw.
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
  final List<String> asked = <String>[
    for (final String name in (Platform.environment['ZOOM_MOMENTS'] ?? '').split(','))
      if (name.trim().isNotEmpty) name.trim(),
  ];
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
        final Map<String, double> moments = asked.isNotEmpty
            ? <String, double>{
                for (final String name in asked)
                  if (_moment(name) case (final ZoomStop stop, final double s))
                    '${stop.index}-$name':
                        depth.depthOf(stop) + s * depth.travelOf(stop.index),
              }
            : <String, double>{
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
    // Every tissue on the figure it is shown on, about its own kind of cell;
    // then the pancreas on both figures about each kind of cell that lights
    // a part of it of its own, the testis about each kind of cell that lives
    // in it, the salivary gland on both figures about each, the eye about
    // each kind of cell its retina has, the bone marrow on both figures
    // about each kind of cell of the marrow, the heart on both figures
    // about each kind of cell that lives in it, skeletal muscle, the
    // thigh, on both figures, the kidney on both figures about a cell of
    // each part of it the Atlas's names light, and the liver and the
    // stomach likewise.
    final TissueAnatomy pancreas = tissueAnatomy['pancreas']!;
    final TissueAnatomy testis = tissueAnatomy['testis']!;
    final TissueAnatomy salivary = tissueAnatomy['salivary gland']!;
    final TissueAnatomy eye = tissueAnatomy['retina']!;
    final TissueAnatomy marrow = tissueAnatomy['bone marrow']!;
    final TissueAnatomy heart = tissueAnatomy['heart muscle']!;
    final TissueAnatomy muscle = tissueAnatomy['skeletal muscle']!;
    final TissueAnatomy kidney = tissueAnatomy['kidney']!;
    final TissueAnatomy liver = tissueAnatomy['liver']!;
    final TissueAnatomy stomach = tissueAnatomy['stomach']!;
    final List<(String, TissueAnatomy, AnatomyFigure, CellShape)> organs =
        <(String, TissueAnatomy, AnatomyFigure, CellShape)>[
          for (final MapEntry<String, TissueAnatomy> tissue
              in tissueAnatomy.entries)
            (
              tissue.key,
              tissue.value,
              AnatomyFigure.bodyFor(tissue.key, const <String>[]),
              shapeOfTissue(tissue.value.recipe),
            ),
          for (final AnatomyFigure body in <AnatomyFigure>[
            AnatomyFigure.female,
            AnatomyFigure.male,
          ])
            for (final CellShape shape in <CellShape>[
              CellShape.endocrine,
              CellShape.epithelial,
              CellShape.acinar,
            ])
              ('pancreas-${body.name}-${shape.name}', pancreas, body, shape),
          for (final CellShape shape in <CellShape>[
            CellShape.germ,
            CellShape.epithelial,
            CellShape.endocrine,
            CellShape.spindle,
          ])
            ('testis-${shape.name}', testis, AnatomyFigure.male, shape),
          for (final AnatomyFigure body in <AnatomyFigure>[
            AnatomyFigure.female,
            AnatomyFigure.male,
          ])
            for (final CellShape shape in <CellShape>[
              CellShape.acinar,
              CellShape.epithelial,
              CellShape.endocrine,
              CellShape.spindle,
            ])
              (
                'salivary-${body.name}-${shape.name}',
                salivary,
                body,
                shape,
              ),
          for (final CellShape shape in <CellShape>[
            CellShape.neuron,
            CellShape.glial,
            CellShape.epithelial,
          ])
            ('eye-${shape.name}', eye, AnatomyFigure.female, shape),
          for (final AnatomyFigure body in <AnatomyFigure>[
            AnatomyFigure.female,
            AnatomyFigure.male,
          ])
            for (final CellShape shape in <CellShape>[
              CellShape.erythroid,
              CellShape.megakaryocyte,
              CellShape.leukocyte,
            ])
              ('marrow-${body.name}-${shape.name}', marrow, body, shape),
          for (final AnatomyFigure body in <AnatomyFigure>[
            AnatomyFigure.female,
            AnatomyFigure.male,
          ])
            for (final CellShape shape in <CellShape>[
              CellShape.cardiomyocyte,
              CellShape.epithelial,
              CellShape.dividing,
            ])
              ('heart-${body.name}-${shape.name}', heart, body, shape),
          for (final AnatomyFigure body in <AnatomyFigure>[
            AnatomyFigure.female,
            AnatomyFigure.male,
          ])
            ('muscle-${body.name}', muscle, body, CellShape.myofibre),
        ];
    // The kidney's cells are all drawn as one shape, and so are the
    // liver's but its hepatocytes, and the stomach's smooth muscle and
    // fibroblasts: the Atlas's names for them tell where each lives.
    final List<(String, TissueAnatomy, AnatomyFigure, CellShape, String?)>
    named = <(String, TissueAnatomy, AnatomyFigure, CellShape, String?)>[
      for (final (
            String name,
            TissueAnatomy tissue,
            AnatomyFigure body,
            CellShape shape,
          )
          in organs)
        (name, tissue, body, shape, null),
      for (final AnatomyFigure body in <AnatomyFigure>[
        AnatomyFigure.female,
        AnatomyFigure.male,
      ])
        for (final String cell in <String>[
          'Proximal tubular cells',
          'Ascending Loop of Henle cells',
          'Renal collecting duct principal cells',
          'Papillary tip epithelial cells',
          'Podocytes',
        ])
          (
            'kidney-${body.name}-${KidneyHome.of(cell).name}',
            kidney,
            body,
            CellShape.epithelial,
            cell,
          ),
      for (final AnatomyFigure body in <AnatomyFigure>[
        AnatomyFigure.female,
        AnatomyFigure.male,
      ])
        for (final (String cell, CellShape shape) in <(String, CellShape)>[
          ('Hepatocytes', CellShape.hepatocyte),
          ('Cholangiocytes', CellShape.epithelial),
        ])
          (
            'liver-${body.name}-${LiverHome.of(cell).name}',
            liver,
            body,
            shape,
            cell,
          ),
      for (final AnatomyFigure body in <AnatomyFigure>[
        AnatomyFigure.female,
        AnatomyFigure.male,
      ])
        for (final (String cell, CellShape shape) in <(String, CellShape)>[
          ('Mitotic cells (Stomach)', CellShape.dividing),
          ('Smooth muscle cells', CellShape.spindle),
        ])
          (
            'stomach-${body.name}-${StomachHome.of(cell).name}',
            stomach,
            body,
            shape,
            cell,
          ),
    ];
    for (final (
          String name,
          TissueAnatomy tissue,
          AnatomyFigure body,
          CellShape shape,
          String? cell,
        )
        in named) {
      final OrganArt art = OrganArt.forTissue(
        tissue,
        body.parts[tissue.uberon],
        tissue.metres * ZoomDepth.organMargin,
        figure: body,
        shape: shape,
        cellName: cell,
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
      expect(tester.takeException(), isNull, reason: name);
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
          File('$atlas/${name.replaceAll(' ', '_')}.png')
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
            painter: _SlidePainter(slide, target, inks),
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

/// A moment named `stop` or `stop+percent`: the stop, or that share of the
/// step that leaves it.
(ZoomStop, double) _moment(String name) {
  final List<String> parts = name.split('+');
  final ZoomStop stop = ZoomStop.values.byName(parts.first);
  return (stop, parts.length > 1 ? double.parse(parts[1]) / 100 : 0);
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
    Sculpt.beacon(canvas, art.site, 1 / size.width, inks);
  }

  @override
  bool shouldRepaint(covariant _OrganPainter old) => old.art != art;
}

/// One slide on its own, its field filling the square.
class _SlidePainter extends CustomPainter {
  _SlidePainter(this.slide, this.target, this.inks);

  final TissueSlide slide;
  final Contour target;
  final ZoomInks inks;

  @override
  void paint(Canvas canvas, Size size) {
    const double field = ZoomDepth.tissueField * 1e6 / 2;
    final double perMicron = size.width / 2 / (field + 4);
    canvas.drawRect(Offset.zero & size, Paint()..color = inks.ground);
    final Path lens = Path()
      ..addOval(
        Rect.fromCircle(
          center: size.center(Offset.zero),
          radius: field * perMicron,
        ),
      );
    canvas.clipPath(lens);
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(perMicron);
    paintTissueSlide(canvas, slide, inks, pixel: 1 / perMicron);
    Sculpt.glowingStroke(
      canvas,
      target.toPath(),
      inks,
      width: 1.8 / perMicron,
    );
  }

  @override
  bool shouldRepaint(covariant _SlidePainter old) => old.slide != slide;
}
