import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeak/core/theme/app_theme.dart';
import 'package:helixpeak/features/gene_lookup/domain/entities/gene_clinvar.dart';
import 'package:helixpeak/features/gene_lookup/domain/entities/protein_catalog.dart';
import 'package:helixpeak/features/gene_lookup/presentation/anatomy/anatomy_painter.dart';
import 'package:helixpeak/features/gene_lookup/presentation/anatomy/anatomy_screen.dart';
import 'package:helixpeak/features/gene_lookup/presentation/anatomy/anatomy_selection_canvas.dart';
import 'package:helixpeak/features/gene_lookup/presentation/clinvar/clinvar_block.dart';
import 'package:helixpeak/features/gene_lookup/presentation/clinvar/clinvar_colors.dart';
import 'package:helixpeak/features/gene_lookup/presentation/clinvar/evidence_strip.dart';
import 'package:helixpeak/features/gene_lookup/presentation/clinvar/variants_overview.dart';
import 'package:helixpeak/features/gene_lookup/presentation/constraint/constraint_panel.dart';
import 'package:helixpeak/features/gene_lookup/presentation/inspector/impact_panel.dart';

import '../anatomy/anatomy_fixture.dart';
import 'gene_clinvar_test.dart' show snapshot;
import 'variant_evidence_test.dart' show insulinConstraint, insulinImpact;

Finder _key(String value) => find.byKey(ValueKey<String>(value));
Finder get _paint => find.byWidgetPredicate(
  (Widget widget) => widget is CustomPaint && widget.painter is AnatomyPainter,
);
AnatomyPainter _painter(WidgetTester tester) =>
    tester.widget<CustomPaint>(_paint.first).painter! as AnatomyPainter;

/// The walk with every track injected — the ClinVar and AVI assets are large
/// enough that a widget test never sees them finish loading — under the app's
/// own theme, with the walk's analysis theme inside it as the gene screen has.
Future<void> _walk(WidgetTester tester, {int pages = 2}) async {
  await tester.binding.setSurfaceSize(const Size(390, 844));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    RepaintBoundary(
      key: const ValueKey<String>('capture'),
      child: MaterialApp(
        theme: AppTheme.dark,
        debugShowCheckedModeBanner: false,
        builder: (BuildContext context, Widget? child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: Theme(
          data: AppTheme.analysis,
          child: AnatomyScreen(
            record: insulin(),
            target: ProteinCatalog.insulin,
            constraint: insulinConstraint(),
            impact: insulinImpact(),
            clinvar: snapshot(),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  for (int i = 0; i < pages; i++) {
    final Rect screen = tester.getRect(find.byType(AnatomyScreen));
    await tester.dragFrom(
      Offset(screen.center.dx, screen.bottom - 40),
      const Offset(-160, 0),
    );
    await tester.pumpAndSettle();
  }
}

Future<void> _tapKey(WidgetTester tester, String key) async {
  await _bringUp(tester, key);
  await tester.tap(_key(key));
  await tester.pumpAndSettle();
}

/// Brings a keyed widget on screen. The ClinVar list builds its rows only as
/// they come near the screen, so a row further down it is scrolled to.
Future<void> _bringUp(WidgetTester tester, String key) async {
  final Finder built = find.byKey(ValueKey<String>(key), skipOffstage: false);
  if (built.evaluate().isEmpty &&
      find.byType(VariantsOverview).evaluate().isNotEmpty) {
    await tester.scrollUntilVisible(
      _key(key),
      200,
      scrollable: find.descendant(
        of: _key('variants-overview-scroll'),
        matching: find.byType(Scrollable),
      ),
    );
  }
  await tester.ensureVisible(built);
  await tester.pumpAndSettle();
}

ScrollPosition _overviewScroll(WidgetTester tester) => tester
    .state<ScrollableState>(
      find.descendant(
        of: _key('variants-overview-scroll'),
        matching: find.byType(Scrollable),
      ),
    )
    .position;

Future<void> _tapResidue(WidgetTester tester, int number) async {
  final AnatomyPainter painter = _painter(tester);
  final Offset point =
      tester.getRect(_paint.first).topLeft +
      painter.scene.fromLayout.centreOf(number - 1);
  await tester.tapAt(point);
  await tester.pumpAndSettle();
}

Future<void> _capture(WidgetTester tester, String name) async {
  final String? folder = Platform.environment['SHOT_DIR'];
  if (folder == null) {
    return;
  }
  final RenderRepaintBoundary boundary = tester.renderObject(
    _key('capture'),
  );
  await tester.runAsync(() async {
    final ui.Image shot = await boundary.toImage(pixelRatio: 2);
    final ByteData bytes = (await shot.toByteData(
      format: ui.ImageByteFormat.png,
    ))!;
    Directory(folder).createSync(recursive: true);
    File('$folder/$name.png').writeAsBytesSync(bytes.buffer.asUint8List());
    shot.dispose();
  });
}

void main() {
  setUpAll(() async {
    await loadAppFonts();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });

  testWidgets('ESM mode marks the residues ClinVar has records at', (
    tester,
  ) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    // The residues' own nodes, which the painter builds; they belong to no
    // widget of their own, so they are read off the canvas's node.
    List<String> residueLabels() {
      final List<String> labels = <String>[];
      void visit(SemanticsNode node) {
        labels.add(node.label);
        node.visitChildren((SemanticsNode child) {
          visit(child);
          return true;
        });
      }

      visit(tester.getSemantics(_paint.first));
      return labels;
    }

    await _walk(tester);
    AnatomyPainter painter = _painter(tester);
    expect(painter.marks, hasLength(65));
    expect(painter.marks[95], const ClinVarMark(ClinVarGroup.pathogenic, 3));
    expect(painter.conservation, isFalse);
    expect(_key('clinvar-key'), findsNothing);
    expect(residueLabels().where((l) => l.contains('ClinVar')), isEmpty);

    await tester.tap(_key('conservation-toggle'));
    await tester.pumpAndSettle();
    painter = _painter(tester);
    expect(painter.conservation, isTrue);
    expect(_key('clinvar-key'), findsOneWidget);
    expect(
      residueLabels().where((l) => l.contains('ClinVar')),
      hasLength(65),
    );
    expect(
      residueLabels(),
      contains('cysteine 96, A7, A chain, highly constrained, ClinVar 3 records'),
    );
    await _capture(tester, 'walk-esm-dots');
    semantics.dispose();
  });

  testWidgets('the key opens every record, in the walk’s own theme', (
    tester,
  ) async {
    await _walk(tester);
    await tester.tap(_key('conservation-toggle'));
    await tester.pumpAndSettle();
    await tester.tap(_key('clinvar-key'));
    await tester.pumpAndSettle();
    expect(find.byType(VariantsOverview), findsOneWidget);
    expect(
      Theme.of(tester.element(find.byType(VariantsOverview))).colorScheme
          .surface,
      AppTheme.analysis.colorScheme.surface,
    );
    await _capture(tester, 'walk-overview');
  });

  testWidgets('a residue sheet shows its records with the AVI it lacks', (
    tester,
  ) async {
    await _walk(tester);
    await _tapResidue(tester, 96);
    final ConstraintPanel panel = tester.widget<ConstraintPanel>(
      find.byType(ConstraintPanel),
    );
    expect(panel.residue.number, 96);
    expect(panel.reported, <String, ClinVarGroup>{
      'Y': ClinVarGroup.conflicting,
      'R': ClinVarGroup.pathogenic,
      'S': ClinVarGroup.other,
    });
    // Arg ranks ninth here: pulled up past the gap rather than hidden.
    expect(_key('substitution-clinvar-R'), findsOneWidget);
    expect(find.text('ClinVar · 3 records here'), findsOneWidget);
    final Text numbers = tester.widget<Text>(_key('evidence-numbers-13387'));
    expect(numbers.textSpan!.toPlainText(), 'AVI 31.5');
    await _capture(tester, 'walk-residue-96');
  });

  testWidgets('a record’s base link lands on that base’s sheet', (tester) async {
    await _walk(tester);
    await _tapResidue(tester, 96);
    final Finder all = _key('clinvar-open-all');
    await tester.ensureVisible(all);
    await tester.pumpAndSettle();
    await tester.tap(all);
    await tester.pumpAndSettle();
    // Opened on the three records at the residue the reader came from.
    expect(
      tester.widget<VariantsOverview>(find.byType(VariantsOverview)).focus,
      hasLength(3),
    );
    final Finder row = _key('evidence-row-13387');
    await tester.ensureVisible(row);
    await tester.pumpAndSettle();
    await tester.tap(row);
    await tester.pumpAndSettle();
    final Finder base = _key('evidence-base-13387');
    await tester.ensureVisible(base);
    await tester.pumpAndSettle();
    await tester.tap(base);
    await tester.pumpAndSettle();
    expect(find.byType(VariantsOverview), findsNothing);
    final ImpactPanel sheet = tester.widget<ImpactPanel>(
      find.byType(ImpactPanel),
    );
    expect(sheet.impact.position, 6297);
    expect(sheet.address, 'c.287');
    expect(
      tester.widget<ClinVarBlock>(find.byType(ClinVarBlock)).records,
      hasLength(2),
    );
    await _capture(tester, 'walk-base-c287');

    // And back up from its row to the residue.
    final Finder back = _key('evidence-row-13387');
    await tester.ensureVisible(back);
    await tester.pumpAndSettle();
    await tester.tap(back);
    await tester.pumpAndSettle();
    final Finder residue = _key('evidence-residue-13387');
    await tester.ensureVisible(residue);
    await tester.pumpAndSettle();
    await tester.tap(residue);
    await tester.pumpAndSettle();
    expect(
      tester.widget<ConstraintPanel>(find.byType(ConstraintPanel)).residue.number,
      96,
    );
  });

  testWidgets('an intronic record opens its region and lifts the base', (
    tester,
  ) async {
    await _walk(tester);
    await tester.tap(_key('conservation-toggle'));
    await tester.pumpAndSettle();
    await tester.tap(_key('clinvar-key'));
    await tester.pumpAndSettle();
    await _tapKey(tester, 'evidence-row-211186');
    expect(
      find.text('Outside the protein: only AVI applies.'),
      findsOneWidget,
    );
    expect(_key('evidence-residue-211186'), findsNothing);
    final Finder base = _key('evidence-base-211186');
    await tester.ensureVisible(base);
    await tester.pumpAndSettle();
    await tester.tap(base);
    await tester.pumpAndSettle();
    expect(find.byType(AnatomySelectionCanvas), findsOneWidget);
    final ImpactPanel sheet = tester.widget<ImpactPanel>(
      find.byType(ImpactPanel),
    );
    expect(sheet.impact.position, 6167);
    expect(sheet.address, contains('intron'));
    await _capture(tester, 'walk-intron-base');
  });

  testWidgets('Back from a record’s residue brings the list back as it was', (
    tester,
  ) async {
    await _walk(tester);
    await tester.tap(_key('conservation-toggle'));
    await tester.pumpAndSettle();
    await tester.tap(_key('clinvar-key'));
    await tester.pumpAndSettle();
    final String id = snapshot().variants
        .firstWhere(
          (ClinVarVariant v) =>
              v.residue == 96 && v.group == ClinVarGroup.pathogenic,
        )
        .id;
    await tester.tap(_key('variants-chip-pathogenic'));
    await tester.pumpAndSettle();
    await _tapKey(tester, 'evidence-row-$id');
    await tester.ensureVisible(_key('evidence-residue-$id'));
    await tester.pumpAndSettle();
    final double offset = _overviewScroll(tester).pixels;
    await tester.tap(_key('evidence-residue-$id'));
    await tester.pumpAndSettle();

    // Sent to the residue, with the way back where the title was.
    expect(find.byType(VariantsOverview), findsNothing);
    expect(
      tester.widget<ConstraintPanel>(find.byType(ConstraintPanel)).residue.number,
      96,
    );
    expect(_key('walk-return-clinvar'), findsOneWidget);
    await _capture(tester, 'walk-return-residue');

    // One Back: the list, as it was left — not first the sheet.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(VariantsOverview), findsOneWidget);
    expect(_overviewScroll(tester).pixels, offset);
    expect(_key('evidence-detail-$id'), findsOneWidget);
    // The strip is above the restored scroll, built but off the screen.
    expect(
      tester
          .widget<EvidenceStrip>(
            find.byType(EvidenceStrip, skipOffstage: false),
          )
          .highlight,
      ClinVarGroup.pathogenic,
    );

    // Closed, the list leaves the walk where the record sent it.
    await tester.tap(find.byType(CloseButton));
    await tester.pumpAndSettle();
    expect(find.byType(VariantsOverview), findsNothing);
    expect(
      tester.widget<ConstraintPanel>(find.byType(ConstraintPanel)).residue.number,
      96,
    );
    expect(_key('walk-return-clinvar'), findsNothing);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(ConstraintPanel), findsNothing);
  });

  testWidgets('from an intron, the way back to the list comes before the gene', (
    tester,
  ) async {
    await _walk(tester);
    await tester.tap(_key('conservation-toggle'));
    await tester.pumpAndSettle();
    await tester.tap(_key('clinvar-key'));
    await tester.pumpAndSettle();
    await _tapKey(tester, 'evidence-row-211186');
    await _tapKey(tester, 'evidence-base-211186');
    expect(find.byType(AnatomySelectionCanvas), findsOneWidget);
    expect(_key('walk-return-clinvar'), findsOneWidget);
    expect(find.text('Whole gene'), findsNothing);

    await tester.tap(_key('walk-return-clinvar'));
    await tester.pumpAndSettle();
    expect(find.byType(VariantsOverview), findsOneWidget);
    expect(_key('evidence-detail-211186'), findsOneWidget);
    await tester.tap(find.byType(CloseButton));
    await tester.pumpAndSettle();
    // Back at the lifted base, whose region has its own way back again.
    expect(find.byType(AnatomySelectionCanvas), findsOneWidget);
    expect(find.text('Whole gene'), findsOneWidget);
    expect(_key('walk-return-clinvar'), findsNothing);
  });

  testWidgets('opening the list another way drops the way back to it', (
    tester,
  ) async {
    await _walk(tester);
    await tester.tap(_key('conservation-toggle'));
    await tester.pumpAndSettle();
    await tester.tap(_key('clinvar-key'));
    await tester.pumpAndSettle();
    await _tapKey(tester, 'evidence-row-13387');
    await _tapKey(tester, 'evidence-residue-13387');
    expect(_key('walk-return-clinvar'), findsOneWidget);
    // The residue's own sheet has the way to every record too.
    await _tapKey(tester, 'clinvar-open-all');
    expect(find.byType(VariantsOverview), findsOneWidget);
    await tester.tap(find.byType(CloseButton));
    await tester.pumpAndSettle();
    expect(_key('walk-return-clinvar'), findsNothing);
    expect(find.byType(ConstraintPanel), findsOneWidget);
  });

  testWidgets('About names every source once, and the way to the records', (
    tester,
  ) async {
    await _walk(tester, pages: 0);
    await tester.tap(find.text('INS'));
    await tester.pumpAndSettle();
    expect(find.text('ClinVar'), findsWidgets);
    expect(
      find.text('NCBI snapshot 2026-09-21 · 166 of 242 records mapped'),
      findsOneWidget,
    );
    expect(find.textContaining('AlphaGenome Variant Impact'), findsOneWidget);
    expect(_key('about-sources'), findsOneWidget);
    await tester.tap(_key('open-variants'));
    await tester.pumpAndSettle();
    expect(find.byType(VariantsOverview), findsOneWidget);
  });
}
