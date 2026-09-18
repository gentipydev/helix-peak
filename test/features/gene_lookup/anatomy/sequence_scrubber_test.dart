import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeak/core/theme/app_theme.dart';
import 'package:helixpeak/features/gene_lookup/data/models/gene_record_dto.dart';
import 'package:helixpeak/features/gene_lookup/domain/entities/protein_catalog.dart';
import 'package:helixpeak/features/gene_lookup/domain/entities/protein_constraint.dart';
import 'package:helixpeak/features/gene_lookup/domain/entities/protein_target.dart';
import 'package:helixpeak/features/gene_lookup/presentation/anatomy/anatomy_screen.dart';

import 'anatomy_fixture.dart';

Future<void> _walkTo(
  WidgetTester tester,
  ProteinTarget target, {
  required int stage,
}) async {
  await tester.binding.setSurfaceSize(const Size(390, 844));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.analysis,
      home: MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: AnatomyScreen(
          target: target,
          record: GeneRecordDto.fromJson(
            jsonDecode(File(target.mockAsset).readAsStringSync())
                as Map<String, dynamic>,
          ).toEntity(),
          constraint: ProteinConstraint.fromJson(
            jsonDecode(File(target.constraintAsset).readAsStringSync())
                as Map<String, dynamic>,
            target,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  for (int i = 0; i < stage; i++) {
    final Rect screen = tester.getRect(find.byType(AnatomyScreen));
    await tester.dragFrom(
      Offset(screen.center.dx, screen.bottom - 40),
      const Offset(-160, 0),
    );
    await tester.pumpAndSettle();
  }
}

ScrollPosition _scroll(WidgetTester tester) =>
    tester.state<ScrollableState>(find.byType(Scrollable).first).position;

void main() {
  setUpAll(loadAppFonts);

  final Finder scrubber = find.byKey(const ValueKey<String>('sequence-scrubber'));

  testWidgets('a page of thirteen screens gets a scrubber that names where it is', (
    WidgetTester tester,
  ) async {
    await _walkTo(tester, ProteinCatalog.dystrophin, stage: 2);
    expect(find.text('3,685'), findsOneWidget);
    expect(scrubber, findsOneWidget);

    final Rect strip = tester.getRect(scrubber);
    final TestGesture drag = await tester.startGesture(
      Offset(strip.center.dx, strip.top + 30),
    );
    await drag.moveTo(Offset(strip.center.dx, strip.top + strip.height * 0.5));
    await tester.pump();
    final double halfway = _scroll(tester).pixels;
    expect(
      halfway,
      closeTo(_scroll(tester).maxScrollExtent / 2, _scroll(tester).maxScrollExtent * 0.1),
    );
    // The bubble: the number of the row at the top, and the repeat it is in.
    expect(find.textContaining(RegExp(r'^\d+ · SR\d+$')), findsOneWidget);
    await drag.up();
    await tester.pump();
    expect(find.textContaining(RegExp(r'^\d+ · SR\d+$')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a page that fits a screen or two has none', (
    WidgetTester tester,
  ) async {
    await _walkTo(tester, ProteinCatalog.insulin, stage: 2);
    expect(find.text('110'), findsOneWidget);
    expect(scrubber, findsNothing);
  });
}
