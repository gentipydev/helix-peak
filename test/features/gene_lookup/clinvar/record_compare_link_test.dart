import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/core/theme/agreement_colors.dart';
import 'package:helixpeek/core/theme/app_theme.dart';
import 'package:helixpeek/features/gene_lookup/presentation/anatomy/anatomy_canvas.dart';
import 'package:helixpeek/features/gene_lookup/presentation/anatomy/anatomy_screen.dart';
import 'package:helixpeek/features/gene_lookup/presentation/clinvar/variants_overview.dart';
import 'package:helixpeek/features/gene_lookup/presentation/constraint/constraint_panel.dart';
import 'package:helixpeek/features/gene_lookup/presentation/inspector/agreement_page.dart';
import 'package:helixpeek/features/gene_lookup/presentation/inspector/impact_panel.dart';
import 'package:helixpeek/shared/anatomy/anatomy_painter.dart';
import 'package:helixpeek/shared/clinvar/evidence_row.dart';

import '../../../support/test_catalog.dart';
import '../anatomy/anatomy_fixture.dart';
import 'gene_clinvar_test.dart' show snapshot;
import 'variant_evidence_test.dart' show insulinConstraint, insulinImpact;

/// An opened ClinVar record says ClinVar's part alone; both models' reading
/// of its change is the page its base's codon line opens, which the record
/// links to on the residue sheet and in the list (the user's ask,
/// 2026-10-25). That page stays the two models' own, with nothing of
/// ClinVar on it, wherever ClinVar has a record.

Finder _key(String value) => find.byKey(ValueKey<String>(value));

/// The walk with every track injected, ClinVar's too, under the app's own
/// theme with the walk's inside it, turned [pages] pages on.
Future<void> _walk(WidgetTester tester, {required int pages}) async {
  await tester.binding.setSurfaceSize(const Size(390, 844));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
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
          target: TestCatalog.insulin,
          constraint: insulinConstraint(),
          impact: insulinImpact(),
          clinvar: snapshot(),
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

/// Brings a keyed widget on screen, scrolling the ClinVar list to a row it
/// has not built yet.
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

Future<void> _tapKey(WidgetTester tester, String key) async {
  await _bringUp(tester, key);
  await tester.tap(_key(key));
  await tester.pumpAndSettle();
}

Future<void> _close(WidgetTester tester) async {
  await tester.tap(
    find.descendant(
      of: find.byType(AgreementPage),
      matching: find.byType(CloseButton),
    ),
  );
  await tester.pumpAndSettle();
}

/// c.268, Gly90's first base, where ClinVar has G90C.
const int _c268 = 6278;

void main() {
  setUpAll(() async {
    await loadAppFonts();
    final FontLoader icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  });

  testWidgets('the codon line opens the two models\' page where ClinVar has a '
      'record, with nothing of ClinVar on it; the record repeats neither', (
    WidgetTester tester,
  ) async {
    await _walk(tester, pages: 1);
    tester.widget<AnatomyCanvas>(find.byType(AnatomyCanvas)).onTapped(_c268);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 320));
    await tester.pumpAndSettle();
    await tester.tap(_key('impact-note-link'));
    await tester.pumpAndSettle();
    expect(find.text('c.268 · AVI and ESM-2'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(AgreementPage),
        matching: find.byType(ClinVarSourced),
      ),
      findsNothing,
    );
    expect(
      Theme.of(tester.element(_key('agreement-card')))
          .extension<AgreementColors>(),
      same(AgreementColors.earth),
    );
    await _close(tester);
    expect(find.byType(AgreementPage), findsNothing);
    expect(find.byType(ImpactPanel), findsOneWidget);

    await tester.drag(_key('impact-panel-scroll'), const Offset(0, -300));
    await tester.pumpAndSettle();
    await tester.ensureVisible(_key('evidence-row-21118'));
    await tester.pumpAndSettle();
    await tester.tap(_key('evidence-row-21118'));
    await tester.pumpAndSettle();
    expect(_key('evidence-detail-21118'), findsOneWidget);
    for (final String gone in <String>[
      'evidence-esm-21118',
      'evidence-avi-21118',
      'evidence-reading-21118',
      'evidence-contributions-21118',
      'evidence-compare-21118',
    ]) {
      expect(_key(gone), findsNothing, reason: gone);
    }
    expect(find.text('Show contributions'), findsNothing);
    expect(_key('evidence-residue-21118'), findsOneWidget);
  });

  testWidgets('a residue sheet\'s record opens its base\'s page, and × returns '
      'to the sheet as it was', (WidgetTester tester) async {
    await _walk(tester, pages: 2);
    final Finder canvas = find
        .byWidgetPredicate(
          (Widget w) => w is CustomPaint && w.painter is AnatomyPainter,
        )
        .first;
    final AnatomyPainter painter =
        tester.widget<CustomPaint>(canvas).painter! as AnatomyPainter;
    await tester.tapAt(
      tester.getRect(canvas).topLeft + painter.scene.fromLayout.centreOf(95),
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<ConstraintPanel>(find.byType(ConstraintPanel))
          .residue
          .number,
      96,
    );
    await tester.ensureVisible(_key('evidence-row-13387'));
    await tester.pumpAndSettle();
    await tester.tap(_key('evidence-row-13387'));
    await tester.pumpAndSettle();
    final Finder link = _key('evidence-compare-13387');
    await tester.ensureVisible(link);
    await tester.pumpAndSettle();
    expect(find.text('AVI and ESM-2 ›'), findsOneWidget);
    expect(tester.getSize(link).height, greaterThanOrEqualTo(44));
    await tester.tap(link);
    await tester.pumpAndSettle();
    expect(find.text('c.287 · AVI and ESM-2'), findsOneWidget);
    await _close(tester);
    expect(find.byType(AgreementPage), findsNothing);
    expect(
      tester
          .widget<ConstraintPanel>(find.byType(ConstraintPanel))
          .residue
          .number,
      96,
    );
    expect(_key('evidence-detail-13387'), findsOneWidget);
  });

  testWidgets('a record in the ClinVar list opens its base\'s page above the '
      'list; one off the protein has none', (WidgetTester tester) async {
    await _walk(tester, pages: 2);
    await tester.tap(_key('conservation-toggle'));
    await tester.pumpAndSettle();
    await tester.tap(_key('clinvar-key'));
    await tester.pumpAndSettle();
    expect(find.byType(VariantsOverview), findsOneWidget);
    await _tapKey(tester, 'evidence-row-21118');
    await _tapKey(tester, 'evidence-compare-21118');
    expect(find.text('c.268 · AVI and ESM-2'), findsOneWidget);
    await _close(tester);
    expect(find.byType(AgreementPage), findsNothing);
    expect(find.byType(VariantsOverview), findsOneWidget);
    expect(_key('evidence-detail-21118'), findsOneWidget);
    // An intronic record: AVI alone applies, and says so; no page to open.
    await _tapKey(tester, 'evidence-row-211186');
    expect(_key('evidence-compare-211186'), findsNothing);
    expect(find.text('Outside the protein: only AVI applies.'), findsOneWidget);
  });
}
