import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeak/core/theme/app_theme.dart';
import 'package:helixpeak/features/gene_lookup/domain/entities/gene_clinvar.dart';
import 'package:helixpeak/features/gene_lookup/domain/entities/gene_impact.dart';
import 'package:helixpeak/features/gene_lookup/domain/entities/protein_catalog.dart';
import 'package:helixpeak/features/gene_lookup/domain/entities/protein_constraint.dart';
import 'package:helixpeak/features/gene_lookup/presentation/anatomy/anatomy_painter.dart';
import 'package:helixpeak/features/gene_lookup/presentation/anatomy/anatomy_screen.dart';
import 'package:helixpeak/features/gene_lookup/presentation/anatomy/anatomy_selection_canvas.dart';
import 'package:helixpeak/features/gene_lookup/presentation/clinvar/clinvar_block.dart';
import 'package:helixpeak/features/gene_lookup/presentation/clinvar/evidence_row.dart';
import 'package:helixpeak/features/gene_lookup/presentation/constraint/constraint_panel.dart';
import 'package:helixpeak/features/gene_lookup/presentation/inspector/impact_panel.dart';

import '../anatomy/anatomy_fixture.dart';

Map<String, dynamic> _json(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

ProteinConstraint _constraint(double value) {
  final Map<String, dynamic> json = _json(
    ProteinCatalog.insulin.constraintAsset,
  );
  ((json['positions'] as List<dynamic>)[25]
          as Map<String, dynamic>)['conservation'] =
      value;
  return ProteinConstraint.fromJson(json, ProteinCatalog.insulin);
}

GeneImpact _impact(double value, {bool borrowed = false}) {
  final Map<String, dynamic> json = _json(ProteinCatalog.insulin.impactAsset);
  final Map<String, dynamic> positions =
      json['positions'] as Map<String, dynamic>;
  positions['5299'] = <double>[25, 24, 23];
  positions['5300'] = <double>[12, 11, 10];
  positions['5301'] = <double>[value, value, value];
  if (borrowed) positions.remove('5301');
  return GeneImpact.fromJson(json, ProteinCatalog.insulin);
}

Finder get _panel => find.byType(ImpactPanel);
Finder _key(String value) => find.byKey(ValueKey<String>(value));
Finder get _paint => find.byWidgetPredicate(
  (Widget widget) => widget is CustomPaint && widget.painter is AnatomyPainter,
);
AnatomyPainter _painter(WidgetTester tester) =>
    tester.widget<CustomPaint>(_paint).painter! as AnatomyPainter;

Future<void> _open(
  WidgetTester tester, {
  double avi = 3,
  double esm = 0.95,
  Size size = const Size(390, 844),
  double textScale = 1,
  bool transcript = true,
  bool borrowed = false,
}) async {
  await tester.binding.setSurfaceSize(size);
  await tester.pumpWidget(
    RepaintBoundary(
      key: const ValueKey<String>('merged-capture'),
      child: MaterialApp(
        theme: AppTheme.analysis,
        debugShowCheckedModeBanner: false,
        home: MediaQuery(
          data: MediaQueryData(
            disableAnimations: true,
            textScaler: TextScaler.linear(textScale),
          ),
          child: AnatomyScreen(
            record: insulin(),
            target: ProteinCatalog.insulin,
            impact: _impact(avi, borrowed: borrowed),
            constraint: _constraint(esm),
            clinvar: GeneClinVar.fromJson(
              _json(ProteinCatalog.insulin.clinvarAsset),
              ProteinCatalog.insulin,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  if (transcript) {
    final Rect screen = tester.getRect(find.byType(AnatomyScreen));
    await tester.dragFrom(
      Offset(screen.center.dx, screen.bottom - 40),
      const Offset(-160, 0),
    );
    await tester.pumpAndSettle();
  }
}

Future<void> _tapPosition(WidgetTester tester, int position) async {
  final AnatomyPainter painter = _painter(tester);
  final bool selection = find
      .byType(AnatomySelectionCanvas)
      .evaluate()
      .isNotEmpty;
  final int index = (selection ? painter.scene.to : painter.scene.from).cellAt(
    position,
  );
  final Offset point =
      tester.getRect(_paint).topLeft +
      (selection ? painter.scene.toLayout : painter.scene.fromLayout).centreOf(
        index,
      );
  await tester.tapAt(point);
  await tester.pumpAndSettle();
}

Future<void> _capture(WidgetTester tester, String name) async {
  final String? directory = Platform.environment['SHOT_DIR'];
  if (directory == null) return;
  final RenderRepaintBoundary boundary = tester.renderObject(
    _key('merged-capture'),
  );
  final ByteData? bytes = await tester.runAsync<ByteData>(() async {
    final ui.Image image = await boundary.toImage(pixelRatio: 2);
    final ByteData? data = await image.toByteData(
      format: ui.ImageByteFormat.png,
    );
    image.dispose();
    return data!;
  });
  Directory(directory).createSync(recursive: true);
  File('$directory/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
}

void _noClinicalCopy(WidgetTester tester) {
  final String copy = tester
      .widgetList<Text>(
        find.byElementPredicate((element) {
          if (element.widget is! Text) return false;
          bool observed = false;
          bool panel = false;
          element.visitAncestorElements((ancestor) {
            // Only text quoted from ClinVar may use its words; the reading
            // line and every model number sit outside that boundary.
            observed = observed || ancestor.widget is ClinVarSourced;
            panel = panel || ancestor.widget is ImpactPanel;
            return true;
          });
          return panel && !observed;
        }),
      )
      .map((Text text) => text.data ?? text.textSpan?.toPlainText() ?? '')
      .join(' ');
  expect(
    copy,
    isNot(
      matches(
        RegExp(
          r'\b(pathogenic|dangerous|harmful|disease|safe|diagnosis|clinical)\b',
          caseSensitive: false,
        ),
      ),
    ),
  );
}

void main() {
  setUpAll(() async {
    await loadAppFonts();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  setUp(() => WidgetController.hitTestWarningShouldBeFatal = true);
  tearDown(() => WidgetController.hitTestWarningShouldBeFatal = false);

  String plain(WidgetTester tester, String key) {
    final Text text = tester.widget<Text>(_key(key));
    return text.data ?? text.textSpan!.toPlainText();
  }

  testWidgets(
    'ClinVar keeps two observed alleles distinct at one tapped base',
    (tester) async {
      await _open(tester);
      await _tapPosition(tester, 5294);
      expect(find.text('ClinVar · 2 records here'), findsOneWidget);
      expect(find.text('Ala24Val'), findsOneWidget);
      expect(find.text('Ala24Asp'), findsOneWidget);
      expect(find.text('Likely pathogenic'), findsOneWidget);
      expect(find.text('Pathogenic/Likely risk allele'), findsOneWidget);
      final ClinVarBlock block = tester.widget<ClinVarBlock>(
        find.byType(ClinVarBlock),
      );
      expect(block.records.map((e) => e.variant.alt).toSet(), <String>{
        'A',
        'T',
      });
      // Each reported allele is marked on its own bar, and its row carries
      // the model the bars do not: ESM.
      expect(_key('impact-tag-A'), findsOneWidget);
      expect(_key('impact-tag-T'), findsOneWidget);
      expect(plain(tester, 'evidence-numbers-13388'), 'ESM \u22127.9');
      expect(plain(tester, 'evidence-numbers-36401'), 'ESM \u22123.9');
      // Nothing about ClinVar in general is repeated in a sheet.
      expect(find.textContaining('snapshot'), findsNothing);
      expect(find.textContaining('patient'), findsNothing);
      _noClinicalCopy(tester);
      await tester.drag(_key('impact-panel-scroll'), const Offset(0, -300));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await _capture(tester, 'clinvar-observed');
      tester
          .widget<ImpactPanel>(_panel)
          .controller
          .jumpTo(ImpactPanel.initialSize);
      await tester.pumpAndSettle();
      await _tapPosition(tester, 5301);
      expect(find.text('ClinVar · none at c.78 in this snapshot'), findsOneWidget);
      expect(find.text('Ala24Val'), findsNothing);
    },
  );

  testWidgets('a record opens its evidence in place, one at a time', (
    tester,
  ) async {
    await _open(tester);
    await _tapPosition(tester, 5294);
    await tester.drag(_key('impact-panel-scroll'), const Offset(0, -300));
    await tester.pumpAndSettle();
    await tester.tap(_key('evidence-row-13388'));
    await tester.pumpAndSettle();
    expect(_key('evidence-detail-13388'), findsOneWidget);
    expect(
      plain(tester, 'evidence-reading-13388'),
      'Both models at their strong end.',
    );
    expect(plain(tester, 'evidence-esm-13388'), '\u22127.9');
    expect(plain(tester, 'evidence-avi-13388'), '23.1');
    expect(find.text('Asp in place of Ala'), findsOneWidget);
    _noClinicalCopy(tester);
    await tester.ensureVisible(_key('evidence-row-36401'));
    await tester.pumpAndSettle();
    await tester.tap(_key('evidence-row-36401'));
    await tester.pumpAndSettle();
    expect(_key('evidence-detail-13388'), findsNothing);
    expect(
      plain(tester, 'evidence-reading-36401'),
      'Only AVI at its strong end.',
    );
    // The base sheet already is this base; its detail offers the residue.
    expect(_key('evidence-base-36401'), findsNothing);
    expect(_key('evidence-residue-36401'), findsOneWidget);
    _noClinicalCopy(tester);
    await _capture(tester, 'clinvar-detail');
  });

  testWidgets(
    'a silent base shows its own model, its tags and one line to the residue',
    (tester) async {
      await _open(tester);
      await _tapPosition(tester, 5301);
      final ImpactPanel panel = tester.widget<ImpactPanel>(_panel);
      expect(panel.address, 'c.78');
      expect(panel.coding!.residueName, 'Val26');
      expect(
        plain(tester, 'impact-level'),
        'low impact · bottom 90% genome-wide',
      );
      expect(plain(tester, 'impact-note'), endsWith('Val26 · highly constrained ›'));
      for (final String base in <String>['A', 'C', 'T']) {
        expect(_key('impact-tag-$base'), findsOneWidget, reason: base);
      }
      for (final String gone in <String>[
        'AVI · Molecular mechanism',
        'ESM-2 · Evolution',
        'Agreement',
        'Divergent',
        'Model predictions, not a health assessment.',
      ]) {
        expect(find.text(gone), findsNothing, reason: gone);
      }
      final Rect sheet = tester.getRect(_key('impact-sheet-surface'));
      for (final String key in <String>['impact-level', 'impact-note']) {
        final Rect text = tester.getRect(_key(key));
        expect(sheet.contains(text.topLeft), isTrue, reason: key);
        expect(sheet.contains(text.bottomRight), isTrue, reason: key);
      }
      _noClinicalCopy(tester);
      await _capture(tester, 'merged-silent');

      await tester.tap(find.byTooltip('About these scores'));
      await tester.pumpAndSettle();
      // The sheet's own model, and nothing else.
      expect(_key('impact-explanation'), findsOneWidget);
      expect(find.textContaining('ESM'), findsNothing);
      expect(find.textContaining('health'), findsNothing);
      _noClinicalCopy(tester);
    },
  );

  testWidgets('the residue line opens that residue on the protein page', (
    tester,
  ) async {
    await _open(tester);
    await _tapPosition(tester, 5301);
    await tester.tap(_key('impact-note-link'));
    await tester.pumpAndSettle();
    expect(_panel, findsNothing);
    final ConstraintPanel residue = tester.widget<ConstraintPanel>(
      find.byType(ConstraintPanel),
    );
    expect(residue.residue.number, 26);
  });

  testWidgets(
    'successive bases keep the residue and change only what AVI says',
    (tester) async {
      await _open(tester);
      await _tapPosition(tester, 5301);
      final State<StatefulWidget> state = tester.state(_panel);
      final ResidueConstraint residue = tester
          .widget<ImpactPanel>(_panel)
          .coding!
          .constraint!;
      await _tapPosition(tester, 5299);
      expect(tester.state(_panel), same(state));
      expect(
        tester.widget<ImpactPanel>(_panel).coding!.constraint,
        same(residue),
      );
      expect(tester.widget<ImpactPanel>(_panel).impact.peak, 25);
      expect(plain(tester, 'impact-level'), startsWith('high impact'));
      expect(plain(tester, 'impact-note'), contains('Val26'));
      expect(find.text('='), findsNothing);
      await _capture(tester, 'merged-changing');

      // An untranslated base has no residue to name, and no line to follow.
      final int utr = _painter(tester).scene.from.positionAt(5);
      tester
          .state<ScrollableState>(
            find.ancestor(of: _paint, matching: find.byType(Scrollable)).first,
          )
          .position
          .jumpTo(0);
      await tester.pumpAndSettle();
      await _tapPosition(tester, utr);
      expect(tester.state(_panel), same(state));
      expect(tester.widget<ImpactPanel>(_panel).coding, isNull);
      expect(_key('impact-note-link'), findsNothing);
      expect(find.text('Substitutions · AVI Phred'), findsOneWidget);
    },
  );

  testWidgets('coding bases in an opened gene region show the same evidence', (
    tester,
  ) async {
    await _open(tester, transcript: false);
    await _tapPosition(tester, 5301);
    await tester.tap(_key('open-dna'));
    await tester.pumpAndSettle();
    expect(find.byType(AnatomySelectionCanvas), findsOneWidget);
    await _tapPosition(tester, 5301);
    expect(tester.widget<ImpactPanel>(_panel).coding!.residueName, 'Val26');
    expect(plain(tester, 'impact-note'), endsWith('Val26 · highly constrained ›'));
    await _capture(tester, 'merged-gene');
  });

  testWidgets('estimated AVI is explicit and draws quieter', (tester) async {
    await _open(tester, borrowed: true);
    await _tapPosition(tester, 5301);
    expect(_key('impact-estimated'), findsOneWidget);
    _noClinicalCopy(tester);
  });

  for (final double avi in <double>[3, 15, 25]) {
    for (final double esm in <double>[0.2, 0.6, 0.95]) {
      testWidgets(
        'AVI $avi / ESM $esm has neutral copy and accessible context',
        (tester) async {
          await _open(tester, avi: avi, esm: esm);
          await _tapPosition(tester, 5301);
          _noClinicalCopy(tester);
          await tester.tap(find.byTooltip('About these scores'));
          await tester.pumpAndSettle();
          expect(_key('impact-explanation'), findsOneWidget);
          _noClinicalCopy(tester);
        },
      );
    }
  }

  for (final (Size, double, String) config in <(Size, double, String)>[
    (const Size(320, 568), 1, 'small'),
    (const Size(390, 844), 2, 'large-text'),
    (const Size(844, 390), 1, 'landscape'),
  ]) {
    testWidgets('merged sheet scrolls and keeps info reachable: ${config.$3}', (
      tester,
    ) async {
      await _open(tester, size: config.$1, textScale: config.$2);
      // The small viewport may need scrolling to this coding base.
      final ScrollableState scroll = tester.state<ScrollableState>(
        find.ancestor(of: _paint, matching: find.byType(Scrollable)).first,
      );
      final int cell = _painter(tester).scene.from.cellAt(5294);
      final double top = _painter(tester).scene.fromLayout.centreOf(cell).dy;
      scroll.position.jumpTo(
        (top - 70).clamp(0, scroll.position.maxScrollExtent),
      );
      await tester.pumpAndSettle();
      await _tapPosition(tester, 5294);
      expect(_panel, findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('About these scores'));
      await tester.pumpAndSettle();
      expect(_key('impact-explanation'), findsOneWidget);
      await tester.drag(_key('impact-panel-scroll'), const Offset(0, -500));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final Finder row = _key('evidence-row-13388');
      await tester.ensureVisible(row);
      await tester.pumpAndSettle();
      await tester.tap(row);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await _capture(tester, 'merged-${config.$3}');
      await tester.tap(_key('impact-sheet-close'));
      await tester.pumpAndSettle();
      expect(_panel, findsNothing);
    });
  }
}
