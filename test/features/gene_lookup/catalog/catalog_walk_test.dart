import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/core/theme/app_theme.dart';
import 'package:helixpeek/features/gene_lookup/data/models/gene_record_dto.dart';
import 'package:helixpeek/features/gene_lookup/domain/entities/gene_record.dart';
import 'package:helixpeek/features/gene_lookup/domain/entities/protein_constraint.dart';
import 'package:helixpeek/features/gene_lookup/domain/entities/protein_target.dart';
import 'package:helixpeek/features/gene_lookup/presentation/anatomy/anatomy_canvas.dart';
import 'package:helixpeek/features/gene_lookup/presentation/anatomy/anatomy_screen.dart';
import 'package:helixpeek/features/gene_lookup/presentation/anatomy/anatomy_stages.dart';
import 'package:helixpeek/features/gene_lookup/presentation/constraint/constraint_toolbar.dart';

import '../../../support/test_catalog.dart';
import '../anatomy/anatomy_fixture.dart';

const Size _phone = Size(390, 844);

/// Writes a PNG of the current page when `SHOT_DIR` is set, and nothing
/// otherwise.
///
/// Twenty proteins is more than anyone will page through on a phone before
/// shipping, and the pages that break are the ones nobody thought to look at:
/// dystrophin's 79 exons, p53's 19 kb, the nine squares oxytocin ends on.
///
///     SHOT_DIR=/tmp/shots flutter test test/features/gene_lookup/catalog/
Future<void> _shot(WidgetTester tester, String name) async {
  final String directory = Platform.environment['SHOT_DIR'] ?? '';
  if (directory.isEmpty) {
    return;
  }
  final RenderRepaintBoundary boundary =
      tester.firstRenderObject(find.byType(RepaintBoundary))
          as RenderRepaintBoundary;
  // Both of these resolve on the real event loop, which the fake clock inside
  // testWidgets never pumps; awaited directly they hang until the test times
  // out. runAsync hands them a loop that actually turns.
  final ByteData? bytes = await tester.runAsync<ByteData>(() async {
    final ui.Image image = await boundary.toImage(pixelRatio: 2);
    final ByteData? data = await image.toByteData(
      format: ui.ImageByteFormat.png,
    );
    image.dispose();
    return data!;
  });
  final File file = File('$directory/$name.png')
    ..parent.createSync(recursive: true);
  file.writeAsBytesSync(bytes!.buffer.asUint8List());
}

/// Walks every protein through the real screen, page by page.
///
/// The derivation tests next door prove the numbers; this proves the painter
/// survives them. `AnatomyPainter` is two thousand lines of layout that was
/// written against one 1,431-base gene with three exons and a 110-residue
/// protein, and the catalog now hands it a 79-exon gene page, a 13,993-base
/// transcript, a 3,685-residue protein and a nine-residue hormone. A stage that
/// throws is a blank page on a phone and nothing else notices.
///
/// The structure page is the last of them and needs Flutter GPU, which a
/// headless test never has. `StructureView` reports that in place rather than
/// throwing, which is exactly what is being checked: the walk survives it.
Future<void> _walk(WidgetTester tester, ProteinTarget target) async {
  final GeneRecord record = GeneRecordDto.fromJson(
    jsonDecode(File(target.mockAsset).readAsStringSync())
        as Map<String, dynamic>,
  ).toEntity();
  // Only a scored protein has a track to hand the screen. An unscored one is
  // walked as the app walks it, with none, and the screen must not go looking.
  final ProteinConstraint? constraint = target.scored
      ? ProteinConstraint.fromJson(
          jsonDecode(File(target.constraintAsset).readAsStringSync())
              as Map<String, dynamic>,
          target,
        )
      : null;

  await tester.binding.setSurfaceSize(_phone);
  await tester.pumpWidget(
    RepaintBoundary(
      child: MaterialApp(
        theme: AppTheme.analysis,
        debugShowCheckedModeBanner: false,
        home: MediaQuery(
          // Reduced motion, so a page is settled the moment it is reached and
          // twenty proteins do not cost twenty times the animation budget.
          data: const MediaQueryData(disableAnimations: true),
          child: AnatomyScreen(
            target: target,
            record: record,
            constraint: constraint,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  expect(find.byType(AnatomyCanvas), findsOneWidget, reason: target.slug);

  // Forwards to the last page, then all the way back: a transition is derived
  // from the pair of stages either side of it, so the two directions are not
  // the same code. The screen counts its own stages and adds the fold, and the
  // swipe is the screen's own — taken low, below the turn zone the structure
  // page claims, so the last page can be reached and left again.
  final List<AnatomyStage> stages = AnatomyModel.derive(record).stages;
  final int pages = stages.length + 1;
  final int proteinPage = stages.indexWhere(
    (AnatomyStage s) => s.kind == StageKind.protein,
  );
  expect(pages, greaterThanOrEqualTo(2), reason: target.slug);
  await _shot(tester, '${target.slug}-1-gene');
  for (final bool forward in <bool>[true, false]) {
    for (int i = 1; i < pages; i++) {
      final Rect screen = tester.getRect(find.byType(AnatomyScreen));
      await tester.dragFrom(
        Offset(screen.center.dx, screen.bottom - 40),
        Offset(forward ? -160 : 160, 0),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: '${target.slug} page $i');
      if (forward && i == proteinPage) {
        // The page a track would colour. Scored, it carries the conservation
        // toolbar; unscored, it is drawn without one and says nothing about a
        // track that was never there to fail.
        expect(
          find.byType(ConstraintToolbar),
          target.scored ? findsOneWidget : findsNothing,
          reason: target.slug,
        );
        expect(
          find.text('ESM-2 scores unavailable'),
          findsNothing,
          reason: target.slug,
        );
      }
      if (forward) {
        await _shot(tester, '${target.slug}-${i + 1}');
      }
    }
  }
}

void main() {
  // Real fonts, because the shots are for looking at: in the test font every
  // glyph is a square of the point size, which makes every label three times
  // too wide and every judgement about whether one fits worthless.
  setUpAll(loadAppFonts);

  for (final ProteinTarget target in TestCatalog.all) {
    testWidgets('${target.slug} walks every page without throwing', (
      WidgetTester tester,
    ) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await _walk(tester, target);
      expect(tester.takeException(), isNull, reason: target.slug);
    });
  }
}
