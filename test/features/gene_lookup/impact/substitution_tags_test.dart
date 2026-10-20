import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/core/evidence/gene_impact.dart';
import 'package:helixpeek/core/theme/app_theme.dart';
import 'package:helixpeek/features/gene_lookup/presentation/anatomy/anatomy_canvas.dart';
import 'package:helixpeek/features/gene_lookup/presentation/anatomy/anatomy_screen.dart';

import '../../../support/test_catalog.dart';
import '../anatomy/anatomy_fixture.dart';

/// The base sheet's rows on the real insulin track: each tag says what its
/// change makes of the codon. Every amino acid here was read off the codons
/// apart from the app.

final GeneImpact _track = GeneImpact.fromJson(
  jsonDecode(File(TestCatalog.insulin.impactAsset).readAsStringSync())
      as Map<String, dynamic>,
  TestCatalog.insulin,
);

Finder _key(String value) => find.byKey(ValueKey<String>(value));

/// Opens insulin's mRNA page, which is one swipe from the gene.
Future<void> _openTranscript(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(390, 844));
  await tester.pumpWidget(
    RepaintBoundary(
      key: const ValueKey<String>('tags-capture'),
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
  );
  await tester.pumpAndSettle();
  final Rect screen = tester.getRect(find.byType(AnatomyScreen));
  await tester.dragFrom(
    Offset(screen.center.dx, screen.bottom - 40),
    const Offset(-160, 0),
  );
  await tester.pumpAndSettle();
}

/// Opens a base's sheet through the canvas's own callback, as the sheet that
/// is already open covers most of the page a finger would have to reach it on.
Future<void> _pick(WidgetTester tester, int position) async {
  tester.widget<AnatomyCanvas>(find.byType(AnatomyCanvas)).onTapped(position);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 320));
  await tester.pumpAndSettle();
}

Future<void> _capture(WidgetTester tester, String name) async {
  final String? directory = Platform.environment['SHOT_DIR'];
  if (directory == null) return;
  final RenderRepaintBoundary boundary = tester.renderObject(
    _key('tags-capture'),
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

String _plain(WidgetTester tester, String key) {
  final Text text = tester.widget<Text>(_key(key));
  return text.data ?? text.textSpan!.toPlainText();
}

/// What a row's tag says, without its ClinVar dot.
String _tag(WidgetTester tester, String base) => tester
    .widgetList<Text>(
      find.descendant(
        of: _key('impact-tag-$base'),
        matching: find.byType(Text),
      ),
    )
    .map((Text text) => text.data!)
    .join();

Finder _spoken(String label) =>
    find.bySemanticsLabel(RegExp(RegExp.escape(label)));

void main() {
  setUpAll(() async {
    await loadAppFonts();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  setUp(() => WidgetController.hitTestWarningShouldBeFatal = true);
  tearDown(() => WidgetController.hitTestWarningShouldBeFatal = false);

  testWidgets('a coding base says what each change makes of its codon', (
    tester,
  ) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    await _openTranscript(tester);
    // c.20, the middle of Leu7's CTC: every change makes another amino acid.
    // The level line keeps its reading against the genome.
    await _pick(tester, 5243);
    expect(
      _plain(tester, 'impact-level'),
      'high impact · top 0.479% genome-wide',
    );
    expect(_tag(tester, 'A'), 'His');
    expect(_tag(tester, 'G'), 'Arg');
    expect(_tag(tester, 'C'), 'Pro');
    expect(_spoken('A, Phred 23.2, histidine'), findsOneWidget);
    await _capture(tester, 'tags-c20');

    // c.11, the middle of Trp4's TGG: one change is a stop.
    await _pick(tester, 5234);
    expect(_tag(tester, 'A'), 'Ter');
    expect(_tag(tester, 'C'), 'Ser');
    expect(_tag(tester, 'T'), 'Leu');
    expect(_spoken('A, Phred 54.7, stop codon'), findsOneWidget);
    await _capture(tester, 'tags-c11');

    // c.78, the third base of Val26's GTG: every change keeps it.
    await _pick(tester, 5301);
    for (final String base in <String>['A', 'C', 'T']) {
      expect(_tag(tester, base), '=', reason: base);
    }
    expect(_spoken('T, Phred 10.4, same amino acid'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('a change anywhere in the start codon is a lost start, ?', (
    tester,
  ) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    await _openTranscript(tester);
    for (final (int position, List<String> bases) in <(int, List<String>)>[
      (5224, <String>['C', 'G', 'T']),
      (5225, <String>['A', 'C', 'G']),
      (5226, <String>['A', 'C', 'T']),
    ]) {
      await _pick(tester, position);
      for (final String base in bases) {
        expect(_tag(tester, base), '?', reason: '$position $base');
      }
    }
    expect(_spoken('A, Phred 36.3, start codon lost'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('an untranslated base has no tags', (tester) async {
    await _openTranscript(tester);
    await _pick(tester, 5000);
    for (final String base in <String>['A', 'C', 'T']) {
      expect(_key('impact-tag-$base'), findsNothing, reason: base);
    }
  });
}
