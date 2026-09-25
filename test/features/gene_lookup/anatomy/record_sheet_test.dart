import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/core/theme/app_theme.dart';
import 'package:helixpeek/features/gene_lookup/data/models/gene_record_dto.dart';
import 'package:helixpeek/features/gene_lookup/domain/entities/protein_constraint.dart';
import 'package:helixpeek/features/gene_lookup/domain/entities/protein_target.dart';
import 'package:helixpeek/features/gene_lookup/presentation/anatomy/anatomy_canvas.dart';
import 'package:helixpeek/features/gene_lookup/presentation/anatomy/anatomy_fasta.dart';
import 'package:helixpeek/features/gene_lookup/presentation/anatomy/anatomy_painter.dart';
import 'package:helixpeek/features/gene_lookup/presentation/anatomy/anatomy_screen.dart';
import 'package:helixpeek/features/gene_lookup/presentation/anatomy/anatomy_stages.dart';
import 'package:helixpeek/features/gene_lookup/presentation/constraint/constraint_panel.dart';

import '../../../support/test_catalog.dart';
import 'anatomy_fixture.dart';

AnatomyPainter _painter(WidgetTester tester) =>
    tester
            .widget<CustomPaint>(
              find.byWidgetPredicate(
                (Widget w) => w is CustomPaint && w.painter is AnatomyPainter,
              ),
            )
            .painter!
        as AnatomyPainter;

/// What the app last put on the clipboard.
String? _clipboard;

Future<void> _screen(
  WidgetTester tester, {
  ProteinTarget? target,
}) async {
  target ??= TestCatalog.insulin;
  await tester.binding.setSurfaceSize(const Size(390, 844));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (MethodCall call) async {
      if (call.method == 'Clipboard.setData') {
        _clipboard = (call.arguments as Map<Object?, Object?>)['text'] as String?;
      }
      return null;
    },
  );
  addTearDown(
    () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    ),
  );
  _clipboard = null;
  final record = GeneRecordDto.fromJson(
    jsonDecode(File(target.mockAsset).readAsStringSync())
        as Map<String, dynamic>,
  ).toEntity();
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.analysis,
      home: AnatomyScreen(
        target: target,
        record: record,
        constraint: ProteinConstraint.fromJson(
          jsonDecode(File(target.constraintAsset).readAsStringSync())
              as Map<String, dynamic>,
          target,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadAppFonts);

  group('FASTA', () {
    final AnatomyModel model = AnatomyModel.derive(insulin());
    final ProteinTarget insulinTarget = TestCatalog.insulin;

    test('the precursor, headed and wrapped at sixty', () {
      final String fasta = AnatomyFasta.protein(model, insulinTarget)!;
      final List<String> lines = fasta.trim().split('\n');
      expect(lines.first, '>INS P01308 precursor 1-110');
      expect(lines.skip(1).join(), model.stages[2].letters);
      expect(lines[1].length, 60);
      expect(lines.skip(1).join(), startsWith('MALWMRLLPLLALLALWGPDPAAA'));
    });

    test('the coding sequence runs from its ATG through its stop', () {
      final List<String> lines = AnatomyFasta.cds(model, insulinTarget)!
          .trim()
          .split('\n');
      expect(lines.first, '>INS NG_007114 CDS c.1-333');
      final String cds = lines.skip(1).join();
      expect(cds, startsWith('ATG'));
      expect(cds, endsWith('TAG'));
      expect(cds.length, 333);
    });

    test('each chain is its own entry, placed on the precursor', () {
      final String fasta = AnatomyFasta.chains(model, insulinTarget)!;
      expect(
        fasta.split('\n').where((String l) => l.startsWith('>')).toList(),
        <String>[
          '>INS insulin B chain precursor 25-54',
          '>INS C-peptide precursor 57-87',
          '>INS insulin A chain precursor 90-110',
        ],
      );
      expect(fasta, contains('GIVEQCCTSICSLYQLENYCN'));
    });

    test('a proprotein page copies the proprotein it draws', () {
      // A proprotein that is not one run of its precursor is the one that
      // keeps a page of its own; its copy is its own letters, not the
      // precursor's.
      final AnatomyModel split = AnatomyModel.derive(
        insulinWithout(splitProprotein: true),
      );
      final AnatomyStage page = split.stages.firstWhere(
        (AnatomyStage s) => s.kind == StageKind.proprotein,
      );
      final List<String> lines = AnatomyFasta.ofStage(
        split,
        insulinTarget,
        page,
      )!.trim().split('\n');
      expect(lines.first, contains(' proprotein'));
      expect(lines.skip(1).join(), page.letters);
      expect(AnatomyFasta.sizeOf(page), '${page.letters.length} aa');
    });

    test('a gene drawn shortened has no sequence to copy', () {
      final AnatomyModel dystrophin = AnatomyModel.derive(
        GeneRecordDto.fromJson(
          jsonDecode(
                File(TestCatalog.dystrophin.mockAsset).readAsStringSync(),
              )
              as Map<String, dynamic>,
        ).toEntity(),
      );
      expect(AnatomyFasta.gene(dystrophin, TestCatalog.dystrophin), isNull);
      expect(
        AnatomyFasta.gene(model, insulinTarget)!.split('\n').first,
        '>INS NG_007114:4986-6416(+) gene 1431 bp',
      );
    });
  });

  group('the About sheet', () {
    testWidgets('names every source, and copies what it names', (
      WidgetTester tester,
    ) async {
      await _screen(tester);
      await tester.tap(find.text('INS'));
      await tester.pumpAndSettle();

      expect(find.text('NG_007114 · 4,986–6,416 (+)'), findsOneWidget);
      expect(find.text('P01308 · 110 aa'), findsOneWidget);
      expect(find.text('PDB 3I40'), findsOneWidget);
      expect(find.text('1,431 bp · 3 exons'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey<String>('copy-Protein')));
      await tester.pumpAndSettle();
      expect(_clipboard, startsWith('>INS P01308 precursor 1-110\n'));
      expect(find.text('Protein copied'), findsOneWidget);
    });

    testWidgets('a partial structure says which residues it covers', (
      WidgetTester tester,
    ) async {
      await _screen(tester, target: TestCatalog.p53);
      await tester.tap(find.text('TP53'));
      await tester.pumpAndSettle();
      expect(find.text('PDB 2OCJ · residues 96–289'), findsOneWidget);
    });

    testWidgets('its last row clears the system navigation bar', (
      WidgetTester tester,
    ) async {
      // `useSafeArea` pays the top and the sides and leaves the bottom to the
      // sheet, so without this the Go button sat under the bar.
      tester.view.devicePixelRatio = 2;
      tester.view.padding = const FakeViewPadding(bottom: 68);
      tester.view.viewPadding = const FakeViewPadding(bottom: 68);
      addTearDown(tester.view.reset);

      await _screen(tester);
      await tester.tap(find.text('INS'));
      await tester.pumpAndSettle();

      final double screen = tester.getSize(find.byType(MaterialApp)).height;
      expect(
        tester
            .getRect(find.byKey(const ValueKey<String>('go-to-residue-go')))
            .bottom,
        lessThanOrEqualTo(screen - 34),
      );
    });

    testWidgets('the residue field takes focus without drawing a ring', (
      WidgetTester tester,
    ) async {
      await _screen(tester);
      await tester.tap(find.text('INS'));
      await tester.pumpAndSettle();

      final Finder field = find.byKey(const ValueKey<String>('go-to-residue'));
      await tester.tap(field);
      await tester.pumpAndSettle();

      expect(
        tester.widget<EditableText>(find.descendant(
          of: field,
          matching: find.byType(EditableText),
        )).focusNode.hasFocus,
        isTrue,
      );
      // The cursor already says where typing goes. The accent ring only drew
      // the eye off the sheet, so the border does not change when it arrives.
      expect(
        tester.widget<TextField>(field).decoration!.focusedBorder,
        AppTheme.analysis.inputDecorationTheme.enabledBorder,
      );
    });

    testWidgets('go to residue lands on it and opens its scores', (
      WidgetTester tester,
    ) async {
      await _screen(tester);
      await tester.tap(find.text('INS'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey<String>('go-to-residue')),
        '96',
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey<String>('go-to-residue-go')));
      await tester.pumpAndSettle();

      expect(find.text('110'), findsOneWidget);
      expect(_painter(tester).maskedIndex, 95);
      expect(find.byType(ConstraintPanel), findsOneWidget);
      expect(find.text('Cys96 · A7'), findsOneWidget);
    });
  });

  group('a long press', () {
    testWidgets('copies the page it is on', (WidgetTester tester) async {
      await _screen(tester);
      final Rect screen = tester.getRect(find.byType(AnatomyScreen));
      await tester.dragFrom(
        Offset(screen.center.dx, screen.bottom - 40),
        const Offset(-160, 0),
      );
      await tester.pumpAndSettle();
      await tester.longPress(find.byType(AnatomyCanvas));
      await tester.pumpAndSettle();
      expect(_clipboard, startsWith('>INS NG_007114 mRNA 465 nt\n'));
      expect(find.text('Copied 465 nt as FASTA'), findsOneWidget);
    });

    testWidgets('on a gene drawn shortened, says why there is nothing', (
      WidgetTester tester,
    ) async {
      await _screen(tester, target: TestCatalog.dystrophin);
      await tester.longPress(find.byType(AnatomyCanvas));
      await tester.pumpAndSettle();
      expect(_clipboard, isNull);
      expect(find.textContaining('drawn shortened'), findsWidgets);
    });
  });
}
