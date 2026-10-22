import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/core/catalog/protein_track.dart';
import 'package:helixpeek/core/evidence/gene_impact.dart';
import 'package:helixpeek/core/evidence/impact_explanation_repository.dart';
import 'package:helixpeek/core/network/track_source.dart';
import 'package:helixpeek/core/theme/app_theme.dart';
import 'package:helixpeek/features/gene_lookup/presentation/inspector/contributions_page.dart';

import '../../../support/test_catalog.dart';
import '../anatomy/anatomy_fixture.dart' show loadAppFonts;

/// The contributions card's thin bars, and what the page names under them,
/// on insulin's stored payload: c.73 (a missense codon), a base no change
/// scores at, and a base where one change meets a splice site.

final GeneImpact _track = GeneImpact.fromJson(
  jsonDecode(File(TestCatalog.insulin.impactAsset).readAsStringSync())
      as Map<String, dynamic>,
  TestCatalog.insulin,
);

/// c.73, the first base of codon 25 (TTT, Phe25).
const int _c73 = 5296;

/// A base whose three changes all score Phred 0, held down by conservation.
const int _unconserved = 5406;

/// A base where A alone scores (Phred 24.8), by splicing.
const int _splice = 6158;

class _Source implements TrackSource {
  @override
  Future<Uint8List> read(String slug, TrackKind kind) async {
    expect(kind, TrackKind.impactExplanations);
    return File(TestCatalog.insulin.impactExplanationsAsset).readAsBytes();
  }
}

Finder _key(String value) => find.byKey(ValueKey<String>(value));

/// The texts of a row, in reading order.
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

  /// The page for the base at [position], on a phone, still.
  Future<BaseImpact> pumpPage(
    WidgetTester tester,
    int position,
    String address,
  ) async {
    final BaseImpact base = _track.at(position)!;
    await tester.runAsync(() => repository.load(_track));
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      RepaintBoundary(
        key: const ValueKey<String>('contributions-capture'),
        child: MaterialApp(
          theme: AppTheme.analysis,
          debugShowCheckedModeBanner: false,
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(390, 844),
              disableAnimations: true,
            ),
            child: ContributionsPage(
              track: _track,
              impact: base,
              address: address,
              repository: repository,
            ),
          ),
        ),
      ),
    );
    await tester.runAsync(() async {});
    await tester.pumpAndSettle();
    return base;
  }

  Future<void> open(WidgetTester tester, String key) async {
    await tester.ensureVisible(_key(key));
    await tester.pumpAndSettle();
    await tester.tap(_key(key));
    await tester.pumpAndSettle();
  }

  testWidgets('each bar is a thin mark with nothing written in it', (
    WidgetTester tester,
  ) async {
    final BaseImpact base = await pumpPage(tester, _c73, 'c.73');
    for (final AltScore score in base.ranked) {
      expect(tester.getSize(_key('contributions-stack-${score.base}')).height, 8);
    }
    // The table under the card keys the colours; the card names no group
    // and no feature of its own.
    final Finder card = _key('contributions-composition');
    for (final String name in <String>[
      'Coding',
      'Conservation',
      'Splicing',
      'Expression & chromatin',
    ]) {
      expect(find.descendant(of: card, matching: find.text(name)), findsNothing);
    }
    expect(find.textContaining('AlphaMissense'), findsNothing);
    expect(find.textContaining('PhastCons'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the three bars and their sums end on one line', (
    WidgetTester tester,
  ) async {
    await pumpPage(tester, _c73, 'c.73');
    final List<double> bars = <double>[
      for (final String alt in <String>['C', 'A', 'G'])
        tester.getTopRight(_key('contributions-stack-$alt')).dx,
    ];
    expect(bars.toSet(), hasLength(1));
    final List<double> sums = <double>[
      for (final String sum in <String>['+1.192', '+0.759', '+0.678'])
        tester.getTopRight(find.text(sum)).dx,
    ];
    expect(sums.toSet(), hasLength(1));
  });

  testWidgets('at twice the text size on a narrow phone each sum stays whole', (
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
          debugShowCheckedModeBanner: false,
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
    expect(tester.takeException(), isNull);
    for (final String sum in <String>['+1.192', '+0.759', '+0.678']) {
      final RenderParagraph text = tester.renderObject(find.text(sum));
      expect(
        text.getMaxIntrinsicWidth(double.infinity),
        lessThanOrEqualTo(text.size.width),
        reason: '$sum fits its column',
      );
    }
    await _capture(tester, 'contributions-large-bars');
  });

  testWidgets('a base no change scores at draws its bars left of zero', (
    WidgetTester tester,
  ) async {
    final BaseImpact base = await pumpPage(tester, _unconserved, 'c.?');
    expect(tester.takeException(), isNull);
    // All three score alike, so nothing leads; conservation holds them down.
    expect(_key('contributions-lead'), findsNothing);
    expect(
      find.text('Conservation is level across all three.'),
      findsOneWidget,
    );
    for (final AltScore score in base.ranked) {
      final List<String> row = _row(tester, 'contributions-bar-${score.base}');
      expect(row.last, startsWith('−'), reason: 'the sum of ${score.base}');
    }
    await _capture(tester, 'contributions-negative');
  });

  testWidgets('a change that meets a splice site is set apart by splicing', (
    WidgetTester tester,
  ) async {
    final BaseImpact base = await pumpPage(tester, _splice, 'c.?');
    expect(base.ranked.first.base, 'A');
    expect(
      find.text('A scores highest; Splicing sets it apart.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await _capture(tester, 'contributions-splice');
  });

  testWidgets('a track gives what the model predicts there, signed where '
      'the assay has a direction', (WidgetTester tester) async {
    await pumpPage(tester, _c73, 'c.73');
    // A splice site's score is a size: no sign.
    await open(tester, 'contributions-group-splicing');
    expect(_row(tester, 'contributions-track-MERGED_SPLICING-G'), <String>[
      'G',
      'splice site · acceptor · INS-IGF2 · 0.086',
    ]);
    // RNA-seq's is a log ratio: a rise keeps its plus.
    await open(tester, 'contributions-group-expression');
    await open(tester, 'contributions-feature-MAX_ABS_RNA_SEQ');
    expect(_row(tester, 'contributions-track-MAX_ABS_RNA_SEQ-A'), <String>[
      'A',
      'small intestine · INS-IGF2 · +0.090',
    ]);
    await tester.tap(_key('contributions-info'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('alternative against reference'),
      findsOneWidget,
    );
  });
}
