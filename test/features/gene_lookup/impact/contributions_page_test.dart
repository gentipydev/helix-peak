import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/core/catalog/protein_track.dart';
import 'package:helixpeek/core/evidence/gene_impact.dart';
import 'package:helixpeek/core/evidence/impact_explanation_repository.dart';
import 'package:helixpeek/core/network/track_source.dart';
import 'package:helixpeek/core/theme/app_theme.dart';
import 'package:helixpeek/features/gene_lookup/presentation/anatomy/anatomy_canvas.dart';
import 'package:helixpeek/features/gene_lookup/presentation/anatomy/anatomy_screen.dart';
import 'package:helixpeek/features/gene_lookup/presentation/inspector/contributions_page.dart';

import '../../../support/test_catalog.dart';
import '../anatomy/anatomy_fixture.dart';

/// Insulin's contributions page, opened from c.73's base sheet: every value
/// here was read off the stored payload apart from the app.

final GeneImpact _track = GeneImpact.fromJson(
  jsonDecode(File(TestCatalog.insulin.impactAsset).readAsStringSync())
      as Map<String, dynamic>,
  TestCatalog.insulin,
);

/// c.73, the first base of codon 25 (TTT, Phe25), exon 2.
const int _c73 = 5296;

class _Source implements TrackSource {
  @override
  Future<Uint8List> read(String slug, TrackKind kind) async {
    expect(kind, TrackKind.impactExplanations);
    return File(TestCatalog.insulin.impactExplanationsAsset).readAsBytes();
  }
}

Finder _key(String value) => find.byKey(ValueKey<String>(value));

/// The texts of a table row, in reading order.
List<String> _row(WidgetTester tester, String key) => <String>[
  for (final Text text in tester.widgetList<Text>(
    find.descendant(of: _key(key), matching: find.byType(Text)),
  ))
    text.data ?? text.textSpan!.toPlainText(includePlaceholders: false),
];

Future<void> _capture(WidgetTester tester, String name) async {
  final String? directory = Platform.environment['SHOT_DIR'];
  if (directory == null) return;
  final RenderRepaintBoundary boundary = tester.renderObject(
    _key('contributions-capture'),
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

void main() {
  late ImpactExplanationRepository repository;

  setUpAll(() async {
    await loadAppFonts();
    final FontLoader icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  });

  setUp(() => repository = ImpactExplanationRepository(_Source()));

  /// The walk on insulin's mRNA page with c.73's sheet open, the payload
  /// already parsed: it is too large to finish loading under the test clock.
  Future<void> openSheet(WidgetTester tester) async {
    await tester.runAsync(() => repository.load(_track));
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      RepositoryProvider<ImpactExplanationRepository>.value(
        value: repository,
        child: RepaintBoundary(
          key: const ValueKey<String>('contributions-capture'),
          child: MaterialApp(
            theme: AppTheme.analysis,
            debugShowCheckedModeBanner: false,
            home: MediaQuery(
              data: const MediaQueryData(
                size: Size(390, 844),
                disableAnimations: true,
              ),
              child: AnatomyScreen(
                record: insulin(),
                target: TestCatalog.insulin,
                impact: _track,
              ),
            ),
          ),
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
    tester.widget<AnatomyCanvas>(find.byType(AnatomyCanvas)).onTapped(_c73);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 320));
    await tester.pumpAndSettle();
  }

  Future<void> openPage(WidgetTester tester) async {
    await openSheet(tester);
    await tester.ensureVisible(_key('impact-contributions-open'));
    await tester.pumpAndSettle();
    await tester.tap(_key('impact-contributions-open'));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {});
    await tester.pumpAndSettle();
  }

  testWidgets('the sheet has one Contributions row and no row expanders', (
    WidgetTester tester,
  ) async {
    await openSheet(tester);
    expect(_key('impact-contributions-open'), findsOneWidget);
    for (final String base in <String>['A', 'C', 'G', 'T']) {
      expect(_key('impact-explain-$base'), findsNothing);
    }
    await _capture(tester, 'contributions-sheet');
  });

  testWidgets('c.73\'s substitutions side by side, in the sheet\'s order', (
    WidgetTester tester,
  ) async {
    await openPage(tester);
    expect(find.text('c.73 · Contributions'), findsOneWidget);
    expect(_row(tester, 'contributions-identity'), <String>[
      'T',
      'insulin B chain',
      'codon 25 · TTT · Phe25',
      'chr11:2,160,899',
    ]);
    // Each substitution's bar: its base and what it makes, its Phred and
    // where that sits genome-wide, and the sum of its attributions.
    expect(_row(tester, 'contributions-bar-C'), <String>[
      'C',
      'Leu',
      '25.1 Phred · top 0.309%',
      '+1.192',
    ]);
    expect(_row(tester, 'contributions-bar-A'), <String>[
      'A',
      'Ile',
      '22.1 Phred · top 0.617%',
      '+0.759',
    ]);
    expect(_row(tester, 'contributions-bar-G'), <String>[
      'G',
      'Val',
      '20.9 Phred · top 0.813%',
      '+0.678',
    ]);
    expect(
      tester.getTopLeft(_key('contributions-bar-C')).dy,
      lessThan(tester.getTopLeft(_key('contributions-bar-A')).dy),
    );
    expect(
      tester.getTopLeft(_key('contributions-bar-A')).dy,
      lessThan(tester.getTopLeft(_key('contributions-bar-G')).dy),
    );
    expect(_row(tester, 'contributions-header'), <String>[
      'By group',
      'C Leu',
      'A Ile',
      'G Val',
    ]);
    expect(_row(tester, 'contributions-group-coding'), <String>[
      'Coding',
      '+0.706',
      '+0.296',
      '+0.235',
    ]);
    expect(_row(tester, 'contributions-group-conservation'), <String>[
      'Conservation',
      '+0.391',
      '+0.342',
      '+0.344',
    ]);
    expect(_row(tester, 'contributions-group-splicing'), <String>[
      'Splicing',
      '+0.064',
      '+0.082',
      '+0.058',
    ]);
    expect(_row(tester, 'contributions-group-expression'), <String>[
      'Expression & chromatin',
      '+0.031',
      '+0.039',
      '+0.041',
    ]);
    await _capture(tester, 'contributions-page');
  });

  testWidgets('a group opens onto its features, an assay onto its tracks', (
    WidgetTester tester,
  ) async {
    await openPage(tester);
    expect(_key('contributions-feature-ALPHAMISSENSE'), findsNothing);
    Future<void> open(String key) async {
      await tester.ensureVisible(_key(key));
      await tester.pumpAndSettle();
      await tester.tap(_key(key));
      await tester.pumpAndSettle();
    }

    await open('contributions-group-coding');
    expect(_row(tester, 'contributions-feature-ALPHAMISSENSE'), <String>[
      'AlphaMissense',
      '+0.706',
      '+0.296',
      '+0.235',
    ]);
    // What gives nothing to any of the three is said once, not as zeros.
    expect(_key('contributions-feature-START_LOST'), findsNothing);
    expect(_row(tester, 'contributions-zero-coding'), <String>[
      'No contribution: Termination, Start lost, Stop lost',
    ]);
    await open('contributions-group-expression');
    await open('contributions-feature-MAX_ABS_RNA_SEQ');
    expect(
      _row(tester, 'contributions-track-MAX_ABS_RNA_SEQ-C'),
      <String>['C', 'WTC11 · INS · −0.069'],
    );
    // Splicing is one feature: it opens straight onto its tracks.
    await open('contributions-group-splicing');
    expect(
      _row(tester, 'contributions-track-MERGED_SPLICING-C'),
      <String>['C', 'junction · body of pancreas · INS-IGF2 · 0.646'],
    );
    await _capture(tester, 'contributions-page-open');
  });

  testWidgets('the page wears the walk\'s theme and × returns to the walk', (
    WidgetTester tester,
  ) async {
    await openPage(tester);
    final ThemeData theme = Theme.of(
      tester.element(find.byType(ContributionsPage)),
    );
    expect(theme.colorScheme.surface, AppTheme.analysis.colorScheme.surface);
    await tester.tap(find.byType(CloseButton));
    await tester.pumpAndSettle();
    expect(find.byType(ContributionsPage), findsNothing);
    expect(_key('impact-contributions-open'), findsOneWidget);
  });

  testWidgets('the card says what the numbers say', (
    WidgetTester tester,
  ) async {
    await openPage(tester);
    expect(
      find.text('C (p.Phe25Leu) scores highest; Coding sets it apart.'),
      findsOneWidget,
    );
    // Conservation describes the base: level by its nature, so not said.
    expect(_key('contributions-level'), findsNothing);
    await tester.scrollUntilVisible(
      _key('contributions-source'),
      300,
      scrollable: find.byWidgetPredicate(
        (Widget w) => w is Scrollable && w.axisDirection == AxisDirection.down,
      ),
    );
    expect(find.text('AlphaGenome Atlas'), findsOneWidget);
    expect(find.textContaining('saved'), findsNothing);
    expect(find.textContaining('View in Atlas'), findsNothing);
  });

  testWidgets('what the values are is a sheet, and the page under it stays', (
    WidgetTester tester,
  ) async {
    await openPage(tester);
    final Offset card = tester.getTopLeft(_key('contributions-composition'));
    await tester.tap(_key('contributions-info'));
    await tester.pumpAndSettle();
    expect(_key('contributions-about'), findsOneWidget);
    expect(find.text('About these values'), findsOneWidget);
    // No baseline is stated for insulin: raw minus sum is not one number.
    expect(find.textContaining('baseline'), findsNothing);
    await _capture(tester, 'contributions-page-about');
    // The card did not move under the sheet.
    expect(tester.getTopLeft(_key('contributions-composition')), card);
  });

  testWidgets('a base outside the coding sequence names changes by base', (
    WidgetTester tester,
  ) async {
    // The 5′ UTR's first base: no codon, so no protein change to name.
    final BaseImpact base = _track.at(_track.start)!;
    await tester.runAsync(() => repository.load(_track));
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.analysis,
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(390, 844),
            disableAnimations: true,
          ),
          child: ContributionsPage(
            track: _track,
            impact: base,
            address: 'c.−59',
            repository: repository,
          ),
        ),
      ),
    );
    await tester.runAsync(() async {});
    await tester.pumpAndSettle();
    for (final AltScore score in base.ranked) {
      expect(_key('contributions-bar-${score.base}'), findsOneWidget);
    }
    expect(find.textContaining('p.'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('at its own text size the table fits an SE without scrolling', (
    WidgetTester tester,
  ) async {
    await tester.runAsync(() => repository.load(_track));
    await tester.binding.setSurfaceSize(const Size(375, 667));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.analysis,
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(375, 667),
            disableAnimations: true,
          ),
          child: ContributionsPage(
            track: _track,
            impact: _track.at(_c73)!,
            address: 'c.73',
            repository: repository,
          ),
        ),
      ),
    );
    await tester.runAsync(() async {});
    await tester.pumpAndSettle();
    expect(
      find.ancestor(
        of: _key('contributions-table'),
        matching: find.byWidgetPredicate(
          (Widget w) =>
              w is Scrollable && w.axisDirection == AxisDirection.right,
        ),
      ),
      findsNothing,
    );
  });

  testWidgets('large text on a narrow phone keeps every number whole', (
    WidgetTester tester,
  ) async {
    await tester.runAsync(() => repository.load(_track));
    await tester.binding.setSurfaceSize(const Size(320, 740));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      RepaintBoundary(
        key: const ValueKey<String>('contributions-capture'),
        child: MaterialApp(
          theme: AppTheme.analysis,
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 740),
              textScaler: TextScaler.linear(2),
              disableAnimations: true,
            ),
            child: ContributionsPage(
              track: _track,
              impact: _track.at(_c73)!,
              address: 'c.73',
              repository: repository,
            ),
          ),
        ),
      ),
    );
    await tester.runAsync(() async {});
    await tester.pumpAndSettle();
    // The row runs past the screen's edge, so it is opened by its name.
    expect(
      find.descendant(
        of: _key('contributions-bar-C'),
        matching: find.text('+1.192'),
      ),
      findsOneWidget,
    );
    final Finder down = find.byWidgetPredicate(
      (Widget w) => w is Scrollable && w.axisDirection == AxisDirection.down,
    );
    await tester.scrollUntilVisible(
      _key('contributions-group-expression'),
      200,
      scrollable: down,
    );
    final Finder name = find.descendant(
      of: _key('contributions-group-expression'),
      matching: find.text('Expression & chromatin'),
    );
    await tester.ensureVisible(name);
    await tester.pumpAndSettle();
    await tester.tap(name);
    await tester.pumpAndSettle();
    expect(_key('contributions-feature-MAX_ABS_RNA_SEQ'), findsOneWidget);
    expect(tester.takeException(), isNull);
    // The page's own scroll, not the table's sideways one.
    await tester.scrollUntilVisible(
      _key('contributions-source'),
      300,
      scrollable: down,
    );
    expect(tester.takeException(), isNull);
    await _capture(tester, 'contributions-large-text');
  });
}
