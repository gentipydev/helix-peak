import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/core/evidence/gene_impact.dart';
import 'package:helixpeek/core/evidence/protein_constraint.dart';
import 'package:helixpeek/core/theme/app_theme.dart';
import 'package:helixpeek/features/gene_lookup/presentation/anatomy/anatomy_canvas.dart';
import 'package:helixpeek/features/gene_lookup/presentation/anatomy/anatomy_screen.dart';
import 'package:helixpeek/features/gene_lookup/presentation/inspector/agreement_page.dart';
import 'package:helixpeek/features/gene_lookup/presentation/inspector/coding_evidence.dart';
import 'package:helixpeek/features/gene_lookup/presentation/inspector/gene_agreement.dart';
import 'package:helixpeek/features/gene_lookup/presentation/inspector/impact_panel.dart';
import 'package:helixpeek/shared/anatomy/anatomy_stages.dart';

import '../../../support/test_catalog.dart';
import '../anatomy/anatomy_fixture.dart';

/// Insulin's AVI and ESM-2 page, opened from c.268's codon line: every
/// number here was read off the stored tracks apart from the app.

Map<String, dynamic> _json(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

final GeneImpact _track = GeneImpact.fromJson(
  _json(TestCatalog.insulin.impactAsset),
  TestCatalog.insulin,
);
final ProteinConstraint _constraint = ProteinConstraint.fromJson(
  _json(TestCatalog.insulin.constraintAsset),
  TestCatalog.insulin,
);
final AnatomyModel _model = AnatomyModel.derive(
  insulin(),
  chain: TestCatalog.insulin.chain,
);

/// c.268, the first base of codon 90 (GGC, Gly90), the A chain's first.
const int _c268 = 6278;

/// c.270, the codon's third base: all three changes keep glycine.
const int _c270 = 6280;

/// c.11, Trp4's middle base: G>A makes a stop.
const int _c11 = 5234;

/// c.2, the start codon's middle base.
const int _c2 = 5225;

/// c.15, Met5's third base: all three changes make isoleucine.
const int _c15 = 5238;

Finder _key(String value) => find.byKey(ValueKey<String>(value));

/// The texts under [key], in reading order.
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
    _key('agreement-capture'),
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
  setUpAll(() async {
    await loadAppFonts();
    final FontLoader icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  });

  /// The walk on insulin's mRNA page with c.268's sheet open. The app's own
  /// theme is the cool one, the walk's set inside it, so a page that forgot
  /// the walk's would be drawn in the wrong one.
  Future<void> openSheet(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      RepaintBoundary(
        key: const ValueKey<String>('agreement-capture'),
        child: MaterialApp(
          theme: AppTheme.dark,
          debugShowCheckedModeBanner: false,
          builder: (BuildContext context, Widget? child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(size: const Size(390, 844), disableAnimations: true),
            child: child!,
          ),
          home: Theme(
            data: AppTheme.analysis,
            child: AnatomyScreen(
              record: insulin(),
              target: TestCatalog.insulin,
              impact: _track,
              constraint: _constraint,
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
    tester.widget<AnatomyCanvas>(find.byType(AnatomyCanvas)).onTapped(_c268);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 320));
    await tester.pumpAndSettle();
  }

  /// The page for the base at [position] on its own, still unless [motion].
  Future<void> pumpPage(
    WidgetTester tester,
    int position,
    String address, {
    Size size = const Size(390, 844),
    double text = 1,
    bool motion = false,
    TargetPlatform? platform,
  }) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      RepaintBoundary(
        key: const ValueKey<String>('agreement-capture'),
        child: MaterialApp(
          theme: AppTheme.analysis.copyWith(platform: platform),
          debugShowCheckedModeBanner: false,
          home: MediaQuery(
            data: MediaQueryData(
              size: size,
              textScaler: TextScaler.linear(text),
              disableAnimations: !motion,
            ),
            child: AgreementPage(
              track: _track,
              impact: _track.at(position)!,
              coding: CodingEvidence.at(
                model: _model,
                position: position,
                track: _constraint,
              )!,
              agreement: GeneAgreement.of(
                model: _model,
                impact: _track,
                constraint: _constraint,
              ),
              address: address,
              region: 'insulin',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('c.268\'s codon line opens AVI and ESM-2 side by side, in the '
      'walk\'s own theme, and closes back onto the sheet', (
    WidgetTester tester,
  ) async {
    await openSheet(tester);
    expect(
      tester.widget<Text>(_key('impact-note')).data,
      'codon 90 · GGC · Gly90 · highly constrained ›',
    );
    await tester.ensureVisible(_key('impact-note-link'));
    await tester.pumpAndSettle();
    await tester.tap(_key('impact-note-link'));
    await tester.pumpAndSettle();
    expect(find.text('c.268 · AVI and ESM-2'), findsOneWidget);
    expect(
      Theme.of(tester.element(find.byType(AgreementPage))).colorScheme.surface,
      AppTheme.analysis.colorScheme.surface,
    );
    expect(_row(tester, 'agreement-identity'), <String>[
      'G',
      'insulin A chain',
      'codon 90 · GGC · Gly90 · highly constrained',
      'chr11:2,159,917',
    ]);
    expect(find.text('Rank among INS missense substitutions'), findsOneWidget);
    // The sheet's rows, in the sheet's order: Phred highest first.
    expect(_row(tester, 'agreement-row-A'), <String>[
      'A',
      'Ser',
      '33.2 · top 1.7%',
      '−7.2 · top 29%',
    ]);
    expect(_row(tester, 'agreement-row-C'), <String>[
      'C',
      'Arg',
      '31.8 · top 3.6%',
      '−8.4 · top 19%',
    ]);
    expect(_row(tester, 'agreement-row-T'), <String>[
      'T',
      'Cys',
      '31.2 · top 5.1%',
      '−10.4 · top 7.0%',
    ]);
    expect(
      tester.getTopLeft(_key('agreement-row-A')).dy,
      lessThan(tester.getTopLeft(_key('agreement-row-C')).dy),
    );
    for (final String base in <String>['A', 'C', 'T']) {
      expect(_key('agreement-track-$base'), findsOneWidget, reason: base);
      expect(_key('agreement-reading-$base'), findsNothing, reason: base);
    }
    // The numbers stand under one another.
    expect(
      tester.getTopRight(_key('agreement-avi-A')).dx,
      tester.getTopRight(_key('agreement-avi-T')).dx,
    );
    expect(
      tester.getTopRight(_key('agreement-esm-A')).dx,
      tester.getTopRight(_key('agreement-esm-T')).dx,
    );
    expect(
      find.text('Across INS · 687 missense substitutions'),
      findsOneWidget,
    );
    // The gene's dots under the heading, its two numbers under them.
    expect(
      tester.getTopLeft(_key('agreement-scatter')).dy,
      greaterThan(
        tester
            .getTopLeft(find.text('Across INS · 687 missense substitutions'))
            .dy,
      ),
    );
    expect(
      tester.getTopLeft(_key('agreement-rho')).dy,
      greaterThan(tester.getBottomLeft(_key('agreement-scatter')).dy),
    );
    expect(_row(tester, 'agreement-rho'), <String>['Spearman ρ', '0.79']);
    expect(_row(tester, 'agreement-order'), <String>[
      'Same order within a base',
      '64% of 540 pairs',
    ]);
    await _capture(tester, 'agreement-page');

    await tester.tap(
      find.descendant(
        of: find.byType(AgreementPage),
        matching: find.byType(CloseButton),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(AgreementPage), findsNothing);
    expect(find.byType(ImpactPanel), findsOneWidget);
  });

  testWidgets('each row says itself whole to a screen reader', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    await pumpPage(tester, _c268, 'c.268');
    expect(
      tester.getSemantics(_key('agreement-row-A')).label,
      'A, serine. AVI Phred 33.2, top 1.7% in INS. ESM-2 −7.2, top 29%',
    );
    await pumpPage(tester, _c270, 'c.270');
    expect(
      tester.getSemantics(_key('agreement-row-A')).label,
      'A, same amino acid. AVI Phred 14.3. Same amino acid: only AVI '
      'applies.',
    );
    semantics.dispose();
  });

  testWidgets('the scatter holds every change in the gene and names this '
      'base\'s own, each amino acid once', (WidgetTester tester) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    String said() => tester.getSemantics(_key('agreement-scatter')).label;
    await pumpPage(tester, _c268, 'c.268');
    expect(
      said(),
      'Every missense substitution in INS, AVI Phred across and ESM-2 up; '
      'marked: serine, arginine and cysteine',
    );
    // Met5's third base: three changes, one amino acid.
    await pumpPage(tester, _c15, 'c.15');
    expect(_row(tester, 'agreement-row-A')[1], 'Ile');
    expect(
      said(),
      'Every missense substitution in INS, AVI Phred across and ESM-2 up; '
      'marked: isoleucine',
    );
    await _capture(tester, 'agreement-one-name');
    // A silent base marks nothing, and the gene is still drawn.
    await pumpPage(tester, _c270, 'c.270');
    expect(
      said(),
      'Every missense substitution in INS, AVI Phred across and ESM-2 up',
    );
    semantics.dispose();
  });

  testWidgets('a silent base: three changes only AVI applies to', (
    WidgetTester tester,
  ) async {
    await pumpPage(tester, _c270, 'c.270');
    for (final String base in <String>['A', 'G', 'T']) {
      final double phred = _track
          .at(_c270)!
          .ranked
          .firstWhere((AltScore s) => s.base == base)
          .phred;
      // No column is headed, so the number names its unit.
      expect(_row(tester, 'agreement-row-$base').take(3), <String>[
        base,
        '=',
        '${phred.toStringAsFixed(1)} Phred',
      ]);
      expect(
        tester.widget<Text>(_key('agreement-reading-$base')).data,
        'Same amino acid: only AVI applies.',
      );
      expect(_key('agreement-track-$base'), findsNothing);
      expect(_key('agreement-esm-$base'), findsNothing);
    }
    // Nothing is ranked, so there is no rank to head; the gene still is.
    expect(_key('agreement-heading'), findsNothing);
    expect(_key('agreement-legend'), findsNothing);
    expect(_key('agreement-across'), findsOneWidget);
    await _capture(tester, 'agreement-silent');
  });

  testWidgets('a stop among missense changes is read, the others ranked', (
    WidgetTester tester,
  ) async {
    await pumpPage(tester, _c11, 'c.11');
    expect(_row(tester, 'agreement-row-A').take(3), <String>[
      'A',
      'Ter',
      '54.7',
    ]);
    expect(
      tester.widget<Text>(_key('agreement-reading-A')).data,
      'Premature stop: only AVI applies.',
    );
    expect(_key('agreement-track-A'), findsNothing);
    expect(_key('agreement-track-C'), findsOneWidget);
    expect(_key('agreement-track-T'), findsOneWidget);
    await _capture(tester, 'agreement-stop');
  });

  testWidgets('the start codon: every change is p.Met1?, read not ranked', (
    WidgetTester tester,
  ) async {
    await pumpPage(tester, _c2, 'c.2');
    for (final String base in <String>['A', 'C', 'G']) {
      expect(_row(tester, 'agreement-row-$base')[1], '?');
      expect(
        tester.widget<Text>(_key('agreement-reading-$base')).data,
        'Start codon change: only AVI applies.',
      );
    }
    expect(_key('agreement-heading'), findsNothing);
  });

  testWidgets('large text on a narrow phone puts each number on its own line', (
    WidgetTester tester,
  ) async {
    await pumpPage(tester, _c268, 'c.268', size: const Size(320, 740), text: 2);
    expect(tester.takeException(), isNull);
    // Under the base and its tag, AVI's line over ESM-2's.
    final Rect avi = tester.getRect(_key('agreement-avi-A'));
    final Rect esm = tester.getRect(_key('agreement-esm-A'));
    expect(esm.top, greaterThanOrEqualTo(avi.bottom));
    expect(avi.top, greaterThan(tester.getRect(find.text('Ser')).top));
    await _capture(tester, 'agreement-large-text');
    // The list builds its rows as they come on screen.
    await tester.scrollUntilVisible(
      _key('agreement-scatter'),
      200,
      scrollable: find
          .descendant(
            of: _key('agreement-scroll'),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await _capture(tester, 'agreement-large-text-scatter');
    await tester.scrollUntilVisible(
      _key('agreement-order'),
      200,
      scrollable: find
          .descendant(
            of: _key('agreement-scroll'),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    // Its name is set whole, on as few lines as a phone allows, its value
    // under it: never a column one letter wide.
    expect(
      tester
          .getSize(find.text('Same order within a base', findRichText: true))
          .width,
      greaterThan(200),
    );
    await _capture(tester, 'agreement-large-text-end');
  });

  testWidgets('with motion the marks travel in and come to rest', (
    WidgetTester tester,
  ) async {
    await pumpPage(tester, _c268, 'c.268', motion: true);
    expect(_key('agreement-track-A'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('on an iPhone the page stops at its ends, with no bounce', (
    WidgetTester tester,
  ) async {
    await pumpPage(
      tester,
      _c11,
      'c.11',
      size: const Size(360, 480),
      platform: TargetPlatform.iOS,
    );
    final ScrollPosition position = tester
        .state<ScrollableState>(
          find
              .descendant(
                of: _key('agreement-scroll'),
                matching: find.byType(Scrollable),
              )
              .first,
        )
        .position;
    expect(position.maxScrollExtent, greaterThan(0));

    /// Holds a drag of [dy] past an end and reads where the page stands.
    Future<double> pull(double dy) async {
      final TestGesture gesture = await tester.startGesture(
        tester.getCenter(_key('agreement-scroll')),
      );
      await gesture.moveBy(Offset(0, dy));
      await tester.pump();
      final double held = position.pixels;
      await gesture.up();
      await tester.pumpAndSettle();
      return held;
    }

    expect(await pull(200), 0);
    // The list measures what it has not yet laid out as it goes, so its end
    // is where a jump to it stays put.
    double end = -1;
    while (end != position.maxScrollExtent) {
      end = position.maxScrollExtent;
      position.jumpTo(end);
      await tester.pump();
    }
    expect(await pull(-200), end);
    expect(position.pixels, end);
  });

  testWidgets('the ⓘ sheet says what the values are and credits both '
      'sources; nothing is said in clinical terms', (
    WidgetTester tester,
  ) async {
    await pumpPage(tester, _c268, 'c.268');
    final String credit = _row(tester, 'agreement-source').join(' ');
    expect(credit, contains('AlphaGenome Atlas · Google DeepMind'));
    expect(credit, contains('ESM-2 650M'));
    expect(
      credit,
      contains('Provided under and subject to the AlphaGenome Output Terms'),
    );
    // Text only: the page links nowhere.
    for (final Type type in <Type>[InkWell, GestureDetector]) {
      expect(
        find.descendant(
          of: _key('agreement-source'),
          matching: find.byType(type),
        ),
        findsNothing,
      );
    }
    final Offset card = tester.getTopLeft(_key('agreement-card'));
    await tester.tap(_key('agreement-info'));
    await tester.pumpAndSettle();
    expect(_key('agreement-about'), findsOneWidget);
    // The sheet lies over the page: nothing under it moved.
    expect(tester.getTopLeft(_key('agreement-card')), card);
    final String source = _row(tester, 'agreement-about-source').join(' ');
    expect(source, contains('deepmind.google.com/science/alphagenome/'));
    expect(source, contains('doi:10.1038/s41586-025-10014-0'));
    expect(source, contains('doi:10.1126/science.ade2574'));
    expect(
      _row(tester, 'agreement-about').join(' '),
      contains('overlaps ESM-2 rather than confirming it'),
    );
    await _capture(tester, 'agreement-about');
    final RegExp clinical = RegExp(
      r'\b(pathogenic|dangerous|harmful|disease|safe|diagnosis|clinical)\b',
      caseSensitive: false,
    );
    for (final Text text in tester.widgetList<Text>(find.byType(Text))) {
      final String said =
          text.data ?? text.textSpan!.toPlainText(includePlaceholders: false);
      expect(clinical.hasMatch(said), isFalse, reason: said);
    }
  });
}
