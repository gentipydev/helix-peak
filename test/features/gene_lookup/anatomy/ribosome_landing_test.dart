import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/core/biology/gene_record.dart';
import 'package:helixpeek/core/catalog/protein_target.dart';
import 'package:helixpeek/core/evidence/protein_constraint.dart';
import 'package:helixpeek/core/theme/app_theme.dart';
import 'package:helixpeek/features/gene_lookup/data/models/gene_record_dto.dart';
import 'package:helixpeek/features/gene_lookup/presentation/anatomy/anatomy_screen.dart';
import 'package:helixpeek/features/gene_lookup/presentation/constraint/constraint_toolbar.dart';
import 'package:helixpeek/shared/anatomy/anatomy_painter.dart';
import 'package:helixpeek/shared/anatomy/anatomy_stages.dart';
import 'package:helixpeek/shared/anatomy/stage_bar.dart';
import 'package:helixpeek/shared/ribosome/translation_player.dart';

import '../../../support/catalog_api.dart';
import '../../../support/test_catalog.dart';

GeneRecord _gene(String gene) => GeneRecordDto.fromJson(
  jsonDecode(File('test/fixtures/mock/gene_$gene.json').readAsStringSync())
      as Map<String, dynamic>,
).toEntity();

ProteinConstraint _constraintOf(ProteinTarget target) =>
    ProteinConstraint.fromJson(
      jsonDecode(File(target.constraintAsset).readAsStringSync())
          as Map<String, dynamic>,
      target,
    );

/// Insulin's own catalog row with its constraint track absent: an unscored
/// protein, as the walk's own "unscored" golden draws one.
ProteinTarget _unscoredInsulin() {
  final Map<String, dynamic> row = Map<String, dynamic>.from(
    (catalogFixture()['proteins'] as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .firstWhere((Map<String, dynamic> p) => p['slug'] == 'insulin'),
  );
  final Map<String, dynamic> tracks = Map<String, dynamic>.from(
    row['tracks'] as Map<String, dynamic>,
  )..['constraint'] = 'absent';
  row['tracks'] = tracks;
  return ProteinTarget.fromJson(row);
}

final Finder _grid = find.byWidgetPredicate(
  (Widget w) => w is CustomPaint && w.painter is AnatomyPainter,
);

/// Opens [target]'s walk, plays its ribosome from the transcript page and
/// lets the chain land.
Future<void> _land(
  WidgetTester tester, {
  required ProteinTarget target,
  required GeneRecord record,
  ProteinConstraint? constraint,
}) async {
  await tester.binding.setSurfaceSize(const Size(390, 844));
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.analysis,
      home: AnatomyScreen(
        target: target,
        record: record,
        constraint: constraint,
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
  tester
      .widget<TranslationPlayer>(find.byType(TranslationPlayer))
      .controller
      .seek(1);
  await tester.pumpAndSettle();
}

int _proteinPage(GeneRecord record, ProteinTarget target) => AnatomyModel.derive(
  record,
  chain: target.chain,
).stages.indexWhere((AnatomyStage s) => s.kind == StageKind.protein);

void main() {
  testWidgets('a protein with no signal peptide lands the same way: p53', (
    WidgetTester tester,
  ) async {
    final ProteinTarget target = TestCatalog.p53;
    final GeneRecord p53 = _gene('tp53');
    expect(p53.signalPeptide, isNull);
    await _land(
      tester,
      target: target,
      record: p53,
      constraint: _constraintOf(target),
    );

    final AnatomyPainter painter =
        tester.widget<CustomPaint>(_grid).painter! as AnatomyPainter;
    expect(painter.scene.toIndex, _proteinPage(p53, target));
    expect(painter.scene.isTransition, isFalse);
    expect(painter.scene.to.letters, p53.protein!.translation);
    expect(
      tester.widget<StageBar>(find.byType(StageBar)).index,
      _proteinPage(p53, target),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('an unscored protein lands on its page, with no toolbar', (
    WidgetTester tester,
  ) async {
    final ProteinTarget unscored = _unscoredInsulin();
    expect(unscored.scored, isFalse);
    final GeneRecord record = _gene('ins');
    await _land(tester, target: unscored, record: record);

    final AnatomyPainter painter =
        tester.widget<CustomPaint>(_grid).painter! as AnatomyPainter;
    expect(painter.scene.toIndex, _proteinPage(record, unscored));
    expect(painter.scene.isTransition, isFalse);
    expect(find.byType(ConstraintToolbar), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
