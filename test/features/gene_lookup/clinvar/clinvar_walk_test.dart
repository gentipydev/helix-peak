import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/core/theme/app_theme.dart';
import 'package:helixpeek/features/gene_lookup/domain/entities/gene_clinvar.dart';
import 'package:helixpeek/features/gene_lookup/presentation/anatomy/anatomy_painter.dart';
import 'package:helixpeek/features/gene_lookup/presentation/anatomy/anatomy_screen.dart';
import 'package:helixpeek/features/gene_lookup/presentation/anatomy/anatomy_selection_canvas.dart';
import 'package:helixpeek/features/gene_lookup/presentation/anatomy/stage_bar.dart';
import 'package:helixpeek/features/gene_lookup/presentation/clinvar/clinvar_block.dart';
import 'package:helixpeek/features/gene_lookup/presentation/clinvar/clinvar_colors.dart';
import 'package:helixpeek/features/gene_lookup/presentation/clinvar/evidence_strip.dart';
import 'package:helixpeek/features/gene_lookup/presentation/clinvar/variants_overview.dart';
import 'package:helixpeek/features/gene_lookup/presentation/constraint/constraint_panel.dart';
import 'package:helixpeek/features/gene_lookup/presentation/inspector/impact_panel.dart';

import '../../../support/test_catalog.dart';
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
///
/// On a [phone] the view itself is a phone's, for a page that turns the
/// screen: it goes by the media query and the display, which a surface size
/// reaches neither of.
Future<void> _walk(
  WidgetTester tester, {
  int pages = 2,
  bool motion = false,
  bool phone = false,
}) async {
  if (phone) {
    tester.view.devicePixelRatio = 3;
    tester.view.display.size = const Size(1170, 2532);
    tester.view.physicalSize = const Size(1170, 2532);
    addTearDown(tester.view.reset);
    addTearDown(tester.view.display.reset);
  } else {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
  }
  await tester.pumpWidget(
    RepaintBoundary(
      key: const ValueKey<String>('capture'),
      child: MaterialApp(
        theme: AppTheme.dark,
        debugShowCheckedModeBanner: false,
        builder: (BuildContext context, Widget? child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: !motion),
          child: child!,
        ),
        home: Theme(
          data: AppTheme.analysis,
          child: AnatomyScreen(
            record: insulin(),
            target: TestCatalog.insulin,
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

/// Taps the cell for record position [position] on the page on screen: the
/// region it is in on the gene page, the base in an open region.
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
      tester.getRect(_paint.first).topLeft +
      (selection ? painter.scene.toLayout : painter.scene.fromLayout).centreOf(
        index,
      );
  await tester.tapAt(point);
  await tester.pumpAndSettle();
}

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

  testWidgets('a record’s residue opens above the list; Back returns to it', (
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

    // A page of its own above the list, which is still there under it.
    expect(find.byType(VariantsOverview), findsNothing);
    expect(find.byType(VariantsOverview, skipOffstage: false), findsOneWidget);
    expect(find.byType(AnatomyScreen, skipOffstage: false), findsNWidgets(2));
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
    expect(find.byType(AnatomyScreen, skipOffstage: false), findsOneWidget);
    expect(_overviewScroll(tester).pixels, offset);
    expect(_key('evidence-detail-$id'), findsOneWidget);

    // Closed, the list leaves the walk exactly where the reader opened it:
    // the protein page, with no sheet and no way back to a list.
    await tester.tap(find.byType(CloseButton));
    await tester.pumpAndSettle();
    expect(find.byType(VariantsOverview), findsNothing);
    expect(find.byType(ConstraintPanel), findsNothing);
    expect(_key('walk-return-clinvar'), findsNothing);
    expect(tester.widget<StageBar>(find.byType(StageBar)).index, 2);
  });

  testWidgets('a panel on the whole screen turns the phone, and hands the '
      'list and the walk back as they were', (tester) async {
    await _walk(tester, motion: true, phone: true);
    await tester.tap(_key('conservation-toggle'));
    await tester.pumpAndSettle();
    await tester.tap(_key('clinvar-key'));
    await tester.pumpAndSettle();
    // Scrolled a little way down, which the list keeps.
    await _bringUp(tester, 'evidence-expand-protein');
    final double offset = _overviewScroll(tester).pixels;
    expect(offset, greaterThan(0));
    await tester.tap(_key('evidence-expand-protein'));
    await tester.pumpAndSettle();
    // A plain page while the screen turns, then the panel, in the walk's own
    // theme.
    expect(find.byType(VariantsOverview), findsNothing);
    expect(find.byType(EvidenceStrip), findsNothing);
    tester.view.physicalSize = const Size(2532, 1170);
    await tester.pumpAndSettle();
    expect(find.byType(EvidenceStrip), findsOneWidget);
    expect(
      Theme.of(tester.element(find.byType(EvidenceStrip))).colorScheme.surface,
      AppTheme.analysis.colorScheme.surface,
    );
    await _capture(tester, 'walk-panel-page');

    await tester.tap(_key('evidence-close-protein'));
    await tester.pumpAndSettle();
    expect(find.byType(VariantsOverview), findsNothing);
    tester.view.physicalSize = const Size(1170, 2532);
    await tester.pumpAndSettle();
    expect(find.byType(VariantsOverview), findsOneWidget);
    expect(_overviewScroll(tester).pixels, offset);

    // Closed, the list still leaves the walk where the reader opened it.
    await tester.tap(find.byType(CloseButton));
    await tester.pumpAndSettle();
    expect(find.byType(VariantsOverview), findsNothing);
    expect(tester.widget<StageBar>(find.byType(StageBar)).index, 2);
  });

  testWidgets('in a landing, Back closes what the reader opened there first', (
    tester,
  ) async {
    await _walk(tester);
    await tester.tap(_key('conservation-toggle'));
    await tester.pumpAndSettle();
    await tester.tap(_key('clinvar-key'));
    await tester.pumpAndSettle();
    await _tapKey(tester, 'evidence-row-13387');
    await _tapKey(tester, 'evidence-residue-13387');
    // Another residue compared in the sheet the landing arrived with — one in
    // the row the landing scrolled into view — is still that sheet: one Back
    // leaves.
    await _tapResidue(tester, 92);
    expect(
      tester.widget<ConstraintPanel>(find.byType(ConstraintPanel)).residue.number,
      92,
    );
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(VariantsOverview), findsOneWidget);

    // Back in; closed, and a sheet of the reader's own opened instead.
    await _tapKey(tester, 'evidence-residue-13387');
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(find.byType(ConstraintPanel), findsNothing);
    await _tapResidue(tester, 92);
    expect(find.byType(ConstraintPanel), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    // That sheet went first, and the landing is still up.
    expect(find.byType(ConstraintPanel), findsNothing);
    expect(_key('walk-return-clinvar'), findsOneWidget);

    // The header goes straight to the list, whatever is open.
    await _tapResidue(tester, 92);
    await tester.tap(_key('walk-return-clinvar'));
    await tester.pumpAndSettle();
    expect(find.byType(VariantsOverview), findsOneWidget);
    expect(find.byType(AnatomyScreen, skipOffstage: false), findsOneWidget);
  });

  testWidgets('an intronic record opens its region above the list', (
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
    expect(
      tester.widget<ImpactPanel>(find.byType(ImpactPanel)).impact.position,
      6167,
    );
    expect(_key('walk-return-clinvar'), findsOneWidget);
    expect(find.text('Whole gene'), findsNothing);

    await tester.tap(_key('walk-return-clinvar'));
    await tester.pumpAndSettle();
    expect(find.byType(VariantsOverview), findsOneWidget);
    expect(_key('evidence-detail-211186'), findsOneWidget);
    await tester.tap(find.byType(CloseButton));
    await tester.pumpAndSettle();
    // The walk never left the protein page.
    expect(find.byType(AnatomySelectionCanvas), findsNothing);
    expect(tester.widget<StageBar>(find.byType(StageBar)).index, 2);
  });

  testWidgets('from a landing, the list’s own ways lead back to the same list', (
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
    // The residue's own sheet has the way to every record too. It goes back to
    // the list under the landing, opened on the residue's three records.
    await _tapKey(tester, 'clinvar-open-all');
    expect(find.byType(VariantsOverview), findsOneWidget);
    expect(find.byType(VariantsOverview, skipOffstage: false), findsOneWidget);
    expect(find.byType(AnatomyScreen, skipOffstage: false), findsOneWidget);
    expect(
      tester
          .widget<EvidenceStrip>(
            find.byType(EvidenceStrip, skipOffstage: false),
          )
          .selected,
      hasLength(3),
    );
    await tester.tap(find.byType(CloseButton));
    await tester.pumpAndSettle();
    expect(_key('walk-return-clinvar'), findsNothing);
    expect(find.byType(ConstraintPanel), findsNothing);
  });

  testWidgets('a landing arrives standing still, its sheet already up', (
    tester,
  ) async {
    await _walk(tester, motion: true);
    await tester.tap(_key('conservation-toggle'));
    await tester.pumpAndSettle();
    await tester.tap(_key('clinvar-key'));
    await tester.pumpAndSettle();
    await _tapKey(tester, 'evidence-row-13387');
    await _bringUp(tester, 'evidence-base-13387');
    await tester.tap(_key('evidence-base-13387'));
    // The route's slide is the only motion: by the time it has slid in, the
    // mRNA page is at rest — no translation played backwards to reach it —
    // and the base's sheet is up.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 450));
    expect(_painter(tester).scene.isTransition, isFalse);
    expect(
      tester.widget<ImpactPanel>(find.byType(ImpactPanel)).impact.position,
      6297,
    );
    await tester.pumpAndSettle();
  });

  testWidgets('Back while a landing slides in returns to the list', (
    tester,
  ) async {
    await _walk(tester, motion: true);
    await tester.tap(_key('conservation-toggle'));
    await tester.pumpAndSettle();
    await tester.tap(_key('clinvar-key'));
    await tester.pumpAndSettle();
    await _tapKey(tester, 'evidence-row-13387');
    await _bringUp(tester, 'evidence-residue-13387');
    await tester.tap(_key('evidence-residue-13387'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(VariantsOverview), findsOneWidget);
    expect(find.byType(AnatomyScreen, skipOffstage: false), findsOneWidget);
    await tester.tap(find.byType(CloseButton));
    await tester.pumpAndSettle();
    // Nothing landed underneath while the reader was not looking.
    expect(find.byType(ConstraintPanel), findsNothing);
    expect(tester.widget<StageBar>(find.byType(StageBar)).index, 2);
  });

  testWidgets('a link tapped twice opens one landing', (tester) async {
    await _walk(tester, motion: true);
    await tester.tap(_key('conservation-toggle'));
    await tester.pumpAndSettle();
    await tester.tap(_key('clinvar-key'));
    await tester.pumpAndSettle();
    await _tapKey(tester, 'evidence-row-13387');
    await _bringUp(tester, 'evidence-residue-13387');
    await tester.tap(_key('evidence-residue-13387'));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(_key('evidence-residue-13387'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.byType(AnatomyScreen, skipOffstage: false), findsNWidgets(2));
  });

  testWidgets('a region open in the walk is still open after a landing', (
    tester,
  ) async {
    await _walk(tester, pages: 0);
    await _tapPosition(tester, 5301);
    await tester.tap(_key('open-dna'));
    await tester.pumpAndSettle();
    await _tapPosition(tester, 5301);
    expect(
      tester.widget<ImpactPanel>(find.byType(ImpactPanel)).impact.position,
      5301,
    );
    await _tapKey(tester, 'clinvar-open-all');
    await _tapKey(tester, 'evidence-row-13387');
    await _tapKey(tester, 'evidence-base-13387');
    expect(
      tester.widget<ImpactPanel>(find.byType(ImpactPanel)).impact.position,
      6297,
    );
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.tap(find.byType(CloseButton));
    await tester.pumpAndSettle();
    expect(find.byType(AnatomySelectionCanvas), findsOneWidget);
    expect(
      tester.widget<ImpactPanel>(find.byType(ImpactPanel)).impact.position,
      5301,
    );
    expect(find.text('Whole gene'), findsOneWidget);
  });

  testWidgets('a region the reader opens in a landing is closed first', (
    tester,
  ) async {
    await _walk(tester);
    await tester.tap(_key('conservation-toggle'));
    await tester.pumpAndSettle();
    await tester.tap(_key('clinvar-key'));
    await tester.pumpAndSettle();
    await _tapKey(tester, 'evidence-row-13387');
    await _tapKey(tester, 'evidence-residue-13387');
    // Back to the landing's gene page, and a region opened there.
    await tester.tap(_key('stage-Gene'));
    await tester.pumpAndSettle();
    await _tapPosition(tester, 5301);
    await tester.tap(_key('open-dna'));
    await tester.pumpAndSettle();
    // The header names where Back goes: the gene, then the list.
    expect(find.text('Whole gene'), findsOneWidget);
    expect(_key('walk-return-clinvar'), findsNothing);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(AnatomySelectionCanvas), findsNothing);
    expect(_key('walk-return-clinvar'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(VariantsOverview), findsOneWidget);
  });

  testWidgets('a page says what a tap on it opens, until something is picked', (
    tester,
  ) async {
    await _walk(tester, pages: 0);
    expect(find.text('Tap a region for its DNA'), findsOneWidget);

    await _walk(tester, pages: 1);
    expect(find.text('Tap a base for its AVI scores'), findsOneWidget);
    await _tapPosition(tester, 5301);
    expect(find.byType(ImpactPanel), findsOneWidget);
    expect(find.text('Tap a base for its AVI scores'), findsNothing);

    await _walk(tester);
    expect(find.text('Tap a residue for its ESM-2 scores'), findsOneWidget);
    await _tapResidue(tester, 96);
    expect(find.text('Tap a residue for its ESM-2 scores'), findsNothing);
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

  testWidgets('the list rises over the About sheet, which then goes from under '
      'it', (tester) async {
    await _walk(tester, pages: 0, motion: true);
    await tester.tap(find.text('INS'));
    await tester.pumpAndSettle();
    final Offset sheet = tester.getTopLeft(_key('about-sources'));
    await tester.tap(_key('open-variants'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    // On its way up: the sheet has not moved, and the list comes up over it
    // from the bottom rather than in from the side.
    expect(tester.getTopLeft(_key('about-sources')), sheet);
    final Offset rising = tester.getTopLeft(find.byType(VariantsOverview));
    expect(rising.dx, 0);
    expect(rising.dy, inExclusiveRange(0, 844));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.byType(VariantsOverview)), Offset.zero);
    expect(
      find.byKey(const ValueKey<String>('about-sources'), skipOffstage: false),
      findsNothing,
    );

    // So closing the list goes back to the walk, as from anywhere else.
    await tester.tap(find.byType(CloseButton));
    await tester.pumpAndSettle();
    expect(find.byType(VariantsOverview), findsNothing);
    expect(_key('about-sources'), findsNothing);
    expect(find.byType(AnatomyScreen), findsOneWidget);
  });
}
