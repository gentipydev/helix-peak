import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/core/theme/app_theme.dart';
import 'package:helixpeek/features/gene_lookup/data/models/gene_record_dto.dart';
import 'package:helixpeek/features/gene_lookup/domain/entities/gene_record.dart';
import 'package:helixpeek/features/gene_lookup/domain/entities/protein_constraint.dart';
import 'package:helixpeek/features/gene_lookup/domain/entities/protein_target.dart';
import 'package:helixpeek/features/gene_lookup/presentation/anatomy/anatomy_screen.dart';
import 'package:helixpeek/features/gene_lookup/presentation/anatomy/anatomy_stages.dart';

import '../features/gene_lookup/anatomy/anatomy_fixture.dart';
import '../support/test_catalog.dart';
import 'golden.dart';

const Size _phone = Size(390, 844);

/// Every page of every protein, compared with the picture it was committed as.
///
/// This is the catalog walk's screenshot writer turned into a comparison. The
/// walk itself (`test/features/gene_lookup/catalog/catalog_walk_test.dart`)
/// is a walk test and is not edited: it still proves that no page throws, in
/// both directions, and still writes these same frames to `SHOT_DIR`. This
/// takes its forward pass page for page, in the same harness, and adds what
/// it never had: a check that each page still draws what it drew.
///
/// Dystrophin's 79 exons, p53's 19 kb, the nine squares oxytocin ends on: the
/// pages that break are the ones nobody thought to look at, and these are all
/// of them.
Future<void> _pages(WidgetTester tester, ProteinTarget target) async {
  final GeneRecord record = GeneRecordDto.fromJson(
    jsonDecode(File(target.mockAsset).readAsStringSync())
        as Map<String, dynamic>,
  ).toEntity();
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
          // Reduced motion, as the walk has it, so a page is settled the
          // moment it is reached.
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

  final int pages = AnatomyModel.derive(record).stages.length + 1;
  await expectScreen(tester, 'catalog/${target.slug}-1-gene.png');
  for (int i = 1; i < pages; i++) {
    final Rect screen = tester.getRect(find.byType(AnatomyScreen));
    await tester.dragFrom(
      Offset(screen.center.dx, screen.bottom - 40),
      const Offset(-160, 0),
    );
    await tester.pumpAndSettle();
    await expectScreen(tester, 'catalog/${target.slug}-${i + 1}.png');
  }
}

void main() {
  group('catalog pages', () {
    setUpAll(() async {
      await loadAppFonts();
      // Without it every icon is the same empty box, and a golden cannot tell
      // one icon from another.
      await (FontLoader('MaterialIcons')
            ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
          .load();
    });

    for (final ProteinTarget target in TestCatalog.all) {
      testWidgets('${target.slug} draws every page as committed', (
        WidgetTester tester,
      ) async {
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await _pages(tester, target);
      });
    }
  }, skip: goldenSkip);
}
