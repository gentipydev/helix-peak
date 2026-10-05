import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/core/catalog/protein_target.dart';
import 'package:helixpeek/core/theme/app_theme.dart';
import 'package:helixpeek/features/lab/zoom/domain/anatomy_tables.dart';
import 'package:helixpeek/features/lab/zoom/domain/cell_archetypes.dart';
import 'package:helixpeek/features/lab/zoom/domain/zoom_depth.dart';
import 'package:helixpeek/features/lab/zoom/presentation/scenes/contour.dart';
import 'package:helixpeek/features/lab/zoom/presentation/scenes/tissue/tissue_slide.dart';
import 'package:helixpeek/features/lab/zoom/presentation/scenes/tissue_scene.dart';
import 'package:helixpeek/features/lab/zoom/presentation/scenes/zoom_scene.dart';
import 'package:helixpeek/features/lab/zoom/presentation/scenes/zoom_subject.dart';
import 'package:helixpeek/features/lab/zoom/presentation/zoom_inks.dart';
import 'package:helixpeek/features/lab/zoom/presentation/zoom_painter.dart';

import '../../../../support/test_catalog.dart';
import '../../replication/replication_fixtures.dart';
import '../zoom_fixtures.dart';

const double _field = ZoomDepth.tissueField * 1e6 / 2;

TissueSlide _slide(TissueRecipe recipe, CellShape shape) {
  final CellArchetype archetype = archetypeFor(shape);
  final (Contour target, Contour nucleus) = TissueScene.targetOf(
    archetype,
    archetype.viewMetres,
  );
  return TissueSlide.of(
    recipe,
    field: _field,
    shape: shape,
    target: target,
    targetNucleus: nucleus,
    seed: recipe.index + 3,
  );
}

const List<SlideInk> _nuclei = <SlideInk>[
  SlideInk.nucleus0,
  SlideInk.nucleus1,
  SlideInk.nucleus2,
];

/// Where every ink of every layer of [slide] lies: enough to tell two
/// slides apart.
List<String> _print(TissueSlide slide) => <String>[
  for (int layer = 0; layer < slide.layers.length; layer++)
    for (final SlideInk ink in SlideInk.values)
      if (slide.layers[layer][ink] != null)
        '$layer ${ink.name} ${slide.layers[layer][ink]!.getBounds()}',
];

void main() {
  test('every tissue’s recipe lays a slide about every kind of cell, with the '
      'zoom’s own at the middle', () {
    for (final TissueRecipe recipe in TissueRecipe.values) {
      for (final CellShape shape in CellShape.values) {
        final String what = '${recipe.name} about a ${shape.name} cell';
        final TissueSlide slide = _slide(recipe, shape);
        final SlideLayer own = slide.layers[TissueSlide.own];
        // The zoom's cell: a nucleus at the origin, in its own layer.
        expect(
          _nuclei.any(
            (SlideInk ink) => own[ink]?.contains(Offset.zero) ?? false,
          ),
          isTrue,
          reason: '$what has no nucleus of its own at the middle',
        );
        // And no other cell's nucleus there under it.
        for (int layer = 0; layer < TissueSlide.own; layer++) {
          for (final SlideInk ink in _nuclei) {
            expect(
              slide.layers[layer][ink]?.contains(Offset.zero) ?? false,
              isFalse,
              reason: '$what lays another nucleus on the zoom’s cell',
            );
          }
        }
        // Something of the tissue itself is laid.
        expect(
          <int>[TissueSlide.ground, TissueSlide.tissue, TissueSlide.over].any(
            (int layer) => SlideInk.values.any(
              (SlideInk ink) => slide.layers[layer][ink] != null,
            ),
          ),
          isTrue,
          reason: '$what lays no tissue',
        );
      }
    }
  });

  test('a tissue is the same slide every time', () {
    for (final TissueRecipe recipe in TissueRecipe.values) {
      final CellShape shape = shapeOfTissue(recipe);
      expect(
        _print(_slide(recipe, shape)),
        _print(_slide(recipe, shape)),
        reason: recipe.name,
      );
    }
  });

  test('the same tissue is laid differently about a different kind of cell '
      'where its architecture has a place for each', () {
    // The pancreas: an acinus, an islet, a duct.
    final Set<String> pancreas = <String>{
      for (final CellShape shape in <CellShape>[
        CellShape.acinar,
        CellShape.endocrine,
        CellShape.epithelial,
      ])
        _print(_slide(TissueRecipe.acinar, shape)).join('\n'),
    };
    expect(pancreas, hasLength(3));
    // The marrow: with an erythroblast's island, and without.
    expect(
      _print(_slide(TissueRecipe.marrow, CellShape.erythroid)),
      isNot(_print(_slide(TissueRecipe.marrow, CellShape.leukocyte))),
    );
  });

  test('the eyepiece’s field stands clear of the rail on a phone', () {
    for (final double width in <double>[320, 360, 390, 430]) {
      expect(
        width / 2 - TissueScene.field * width,
        greaterThanOrEqualTo(ZoomPainter.railStrip - 2),
        reason: 'at $width px',
      );
    }
    // The slide is laid for the field the depth says the microscope has.
    expect(
      TissueScene.field * 2 * ZoomDepth.tissueMetres,
      closeTo(ZoomDepth.tissueField, 1e-12),
    );
  });

  testWidgets('at the tissue, every protein’s cell is named on its own '
      'outline, in the field', (WidgetTester tester) async {
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
    const Size canvas = Size(390, 560);
    for (final ProteinTarget t in TestCatalog.all) {
      final ZoomStage stage = ZoomStage(
        ZoomSubject(track: locusOf(t), record: recordOf(t)),
      );
      final ZoomStaging staging = stage.stage(
        stage.depth.depthOf(ZoomStop.tissue),
        canvas,
        inks,
      );
      final Offset centre = canvas.center(Offset.zero);
      expect(staging.items['tissue:target']!.$1, centre, reason: t.slug);
      final Offset named = staging.items['callout:tissue']!.$1;
      // On the cell: within the reach of the largest cell drawn, and well
      // inside the field.
      final double perMicron = canvas.width * TissueScene.micron;
      expect(
        (named - centre).distance,
        lessThanOrEqualTo(60 * perMicron),
        reason: t.slug,
      );
      expect(
        (named - centre).distance,
        lessThan(TissueScene.field * canvas.width * 0.5),
        reason: t.slug,
      );
    }
  });
}
