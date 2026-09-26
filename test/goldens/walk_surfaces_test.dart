import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/core/catalog/protein_target.dart';
import 'package:helixpeek/core/catalog/protein_track.dart';
import 'package:helixpeek/core/evidence/gene_clinvar.dart';
import 'package:helixpeek/core/evidence/gene_impact.dart';
import 'package:helixpeek/core/evidence/protein_constraint.dart';
import 'package:helixpeek/core/theme/app_theme.dart';
import 'package:helixpeek/features/gene_lookup/presentation/anatomy/anatomy_screen.dart';
import 'package:helixpeek/features/gene_lookup/presentation/anatomy/anatomy_selection_canvas.dart';
import 'package:helixpeek/features/gene_lookup/presentation/clinvar/variants_overview.dart';
import 'package:helixpeek/features/gene_lookup/presentation/constraint/constraint_panel.dart';
import 'package:helixpeek/features/gene_lookup/presentation/constraint/constraint_toolbar.dart';
import 'package:helixpeek/features/gene_lookup/presentation/inspector/impact_panel.dart';
import 'package:helixpeek/shared/anatomy/anatomy_layout.dart';
import 'package:helixpeek/shared/anatomy/anatomy_painter.dart';
import 'package:helixpeek/shared/anatomy/anatomy_scene.dart';
import 'package:helixpeek/shared/anatomy/anatomy_stages.dart';
import 'package:helixpeek/shared/structure/structure_view.dart';

import '../features/gene_lookup/anatomy/anatomy_fixture.dart';
import '../support/test_catalog.dart';
import 'golden.dart';

/// The walk's surfaces that no assertion pins, pinned as pictures.
///
/// The widget tests next door prove what each of these pages *says*: its
/// counts, its keys, what a tap opens. None of them proves what it looks like,
/// and a refactor that moves a widget can keep every one of those answers and
/// still draw the page differently. These are the pages a reader actually sees
/// on the way from the gene to the fold, each settled, in insulin, with every
/// track the walk can carry.

const Size _phone = Size(390, 844);

Map<String, dynamic> _json(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

/// Insulin as the catalog carries it, less every track: the state a protein
/// is in before its bake, drawn without the conservation toolbar. The slug
/// stays insulin's, as it does in the constraint tests, so a page that ignored
/// the missing track would find the real one.
ProteinTarget _unscored() {
  final ProteinTarget scored = TestCatalog.insulin;
  return ProteinTarget(
    slug: scored.slug,
    display: scored.display,
    gene: scored.gene,
    uniprot: scored.uniprot,
    accession: scored.accession,
    summary: scored.summary,
    facts: scored.facts,
    chains: scored.chains,
    structure: scored.structure,
    tracks: const <TrackKind, TrackRef>{},
  );
}

Finder get _paint => find.byWidgetPredicate(
  (Widget widget) => widget is CustomPaint && widget.painter is AnatomyPainter,
);

AnatomyPainter _painter(WidgetTester tester) =>
    tester.widget<CustomPaint>(_paint.first).painter! as AnatomyPainter;

/// Opens insulin's walk [pages] pages in, as the gene screen draws it: the
/// analysis theme inside the app's own. Every track is handed over, as the
/// widget tests hand them, because a widget test never sees the larger ones
/// finish loading. [scored] false opens it with none.
Future<void> _walk(
  WidgetTester tester, {
  int pages = 0,
  bool scored = true,
}) async {
  final ProteinTarget target = scored ? TestCatalog.insulin : _unscored();
  await tester.binding.setSurfaceSize(_phone);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    RepaintBoundary(
      child: MaterialApp(
        theme: AppTheme.dark,
        debugShowCheckedModeBanner: false,
        home: Theme(
          data: AppTheme.analysis,
          child: AnatomyScreen(
            record: insulin(),
            target: target,
            constraint: scored
                ? ProteinConstraint.fromJson(
                    _json(target.constraintAsset),
                    target,
                  )
                : null,
            impact: scored
                ? GeneImpact.fromJson(_json(target.impactAsset), target)
                : null,
            clinvar: scored
                ? GeneClinVar.fromJson(_json(target.clinvarAsset), target)
                : null,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  for (int i = 0; i < pages; i++) {
    await _swipe(tester);
  }
}

/// The screen's own swipe, taken low, below the turn zone the fold claims.
Future<void> _swipe(WidgetTester tester) async {
  final Rect screen = tester.getRect(find.byType(AnatomyScreen));
  await tester.dragFrom(
    Offset(screen.center.dx, screen.bottom - 40),
    const Offset(-160, 0),
  );
  await tester.pumpAndSettle();
}

/// Taps the cell holding record position [position] on the page on screen:
/// its region on the gene page, its base on an opened region or the mRNA.
Future<void> _tapPosition(WidgetTester tester, int position) async {
  final AnatomyScene scene = _painter(tester).scene;
  final bool opened = find
      .byType(AnatomySelectionCanvas)
      .evaluate()
      .isNotEmpty;
  final AnatomyStage stage = opened ? scene.to : scene.from;
  final AnatomyLayout layout = opened ? scene.toLayout : scene.fromLayout;
  await tester.tapAt(
    tester.getRect(_paint.first).topLeft +
        layout.centreOf(stage.cellAt(position)),
  );
  await tester.pumpAndSettle();
}

Future<void> _tapResidue(WidgetTester tester, int number) async {
  await tester.tapAt(
    tester.getRect(_paint.first).topLeft +
        _painter(tester).scene.fromLayout.centreOf(number - 1),
  );
  await tester.pumpAndSettle();
}

Future<void> _tapKey(WidgetTester tester, String key) async {
  await tester.tap(find.byKey(ValueKey<String>(key)));
  await tester.pumpAndSettle();
}

void main() {
  group('walk surfaces', () {
    setUpAll(() async {
      WidgetController.hitTestWarningShouldBeFatal = true;
      await loadAppFonts();
      await (FontLoader(
        'MaterialIcons',
      )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    });

    testWidgets('the gene page', (WidgetTester tester) async {
      await _walk(tester);
      expect(_painter(tester).scene.from.kind, StageKind.gene);
      await expectScreen(tester, 'surfaces/gene.png');
    });

    testWidgets('a region opened into its DNA', (WidgetTester tester) async {
      await _walk(tester);
      await _tapPosition(tester, 5301);
      await _tapKey(tester, 'open-dna');
      expect(find.byType(AnatomySelectionCanvas), findsOneWidget);
      await expectScreen(tester, 'surfaces/gene-open-dna.png');
    });

    testWidgets('the mRNA page', (WidgetTester tester) async {
      await _walk(tester, pages: 1);
      expect(_painter(tester).scene.from.kind, StageKind.mrna);
      await expectScreen(tester, 'surfaces/mrna.png');
    });

    testWidgets('a base sheet open on the mRNA', (WidgetTester tester) async {
      await _walk(tester, pages: 1);
      await _tapPosition(tester, 5301);
      expect(find.byType(ImpactPanel), findsOneWidget);
      await expectScreen(tester, 'surfaces/mrna-base-sheet.png');
    });

    testWidgets('the protein page with its conservation toolbar', (
      WidgetTester tester,
    ) async {
      await _walk(tester, pages: 2);
      expect(find.byType(ConstraintToolbar), findsOneWidget);
      await expectScreen(tester, 'surfaces/protein.png');
    });

    testWidgets('the protein page in conservation colours', (
      WidgetTester tester,
    ) async {
      await _walk(tester, pages: 2);
      await _tapKey(tester, 'conservation-toggle');
      expect(_painter(tester).conservation, isTrue);
      await expectScreen(tester, 'surfaces/protein-conservation.png');
    });

    testWidgets('the protein page of an unscored protein, with no toolbar', (
      WidgetTester tester,
    ) async {
      await _walk(tester, pages: 2, scored: false);
      expect(find.byType(ConstraintToolbar), findsNothing);
      await expectScreen(tester, 'surfaces/protein-unscored.png');
    });

    testWidgets('a residue sheet open on the protein', (
      WidgetTester tester,
    ) async {
      await _walk(tester, pages: 2);
      await _tapResidue(tester, 96);
      expect(find.byType(ConstraintPanel), findsOneWidget);
      await expectScreen(tester, 'surfaces/protein-residue-sheet.png');
    });

    testWidgets('the ClinVar overview', (WidgetTester tester) async {
      await _walk(tester, pages: 2);
      await _tapKey(tester, 'conservation-toggle');
      await _tapKey(tester, 'clinvar-key');
      expect(find.byType(VariantsOverview), findsOneWidget);
      await expectScreen(tester, 'surfaces/clinvar-overview.png');
    });

    testWidgets('the fold page', (WidgetTester tester) async {
      await _walk(tester);
      // The fold follows the last grid stage, however many the record has.
      final int stages = AnatomyModel.derive(insulin()).stages.length;
      for (int i = 0; i < stages; i++) {
        await _swipe(tester);
      }
      // Headless, with no Flutter GPU: what is pinned is the page around the
      // model and the way it says the model cannot be drawn here.
      expect(find.byType(StructureView), findsOneWidget);
      await expectScreen(tester, 'surfaces/fold.png');
    });
  }, skip: goldenSkip);
}
