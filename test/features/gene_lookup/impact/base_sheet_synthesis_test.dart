import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/core/biology/gene_record.dart';
import 'package:helixpeek/core/catalog/protein_target.dart';
import 'package:helixpeek/core/evidence/gene_impact.dart';
import 'package:helixpeek/core/theme/app_theme.dart';
import 'package:helixpeek/features/gene_lookup/data/models/gene_record_dto.dart';
import 'package:helixpeek/features/gene_lookup/presentation/anatomy/anatomy_canvas.dart';
import 'package:helixpeek/features/gene_lookup/presentation/anatomy/anatomy_screen.dart';
import 'package:helixpeek/features/gene_lookup/presentation/anatomy/anatomy_selection_canvas.dart';
import 'package:helixpeek/shared/anatomy/anatomy_painter.dart';
import 'package:helixpeek/shared/inspector/score_bar.dart';

import '../../../support/test_catalog.dart';
import '../anatomy/anatomy_fixture.dart';

/// The base sheet's level line, its scale and its rows, read off the real
/// insulin track: what each change makes of the codon, and where the base
/// ranks among the gene's bases of its own part. Every number here was worked
/// out from the fixtures apart from the app, by counting.

Map<String, dynamic> _json(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

GeneImpact _track(
  ProteinTarget target, {
  List<String> without = const <String>[],
}) {
  final Map<String, dynamic> json = _json(target.impactAsset);
  final Map<String, dynamic> positions =
      json['positions'] as Map<String, dynamic>;
  without.forEach(positions.remove);
  return GeneImpact.fromJson(json, target);
}

GeneRecord _record(String gene) =>
    GeneRecordDto.fromJson(_json('test/fixtures/mock/gene_$gene.json'))
        .toEntity();

Finder _key(String value) => find.byKey(ValueKey<String>(value));
Finder get _paint => find.byWidgetPredicate(
  (Widget widget) => widget is CustomPaint && widget.painter is AnatomyPainter,
);
AnatomyPainter _painter(WidgetTester tester) =>
    tester.widget<CustomPaint>(_paint).painter! as AnatomyPainter;

Future<void> _open(
  WidgetTester tester, {
  ProteinTarget? target,
  GeneRecord? record,
  GeneImpact? impact,
  Size size = const Size(390, 844),
  double textScale = 1,
  bool transcript = true,
}) async {
  final ProteinTarget protein = target ?? TestCatalog.insulin;
  await tester.binding.setSurfaceSize(size);
  await tester.pumpWidget(
    RepaintBoundary(
      key: const ValueKey<String>('synthesis-capture'),
      child: MaterialApp(
        theme: AppTheme.analysis,
        debugShowCheckedModeBanner: false,
        home: MediaQuery(
          data: MediaQueryData(
            size: size,
            disableAnimations: true,
            textScaler: TextScaler.linear(textScale),
          ),
          child: AnatomyScreen(
            record: record ?? insulin(),
            target: protein,
            impact: impact ?? _track(protein),
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

/// Opens the sheet of a base on the page through the canvas's own callback, as
/// the sheet that is already open covers most of the page a finger would have
/// to reach it on.
Future<void> _pick(WidgetTester tester, int position) async {
  tester.widget<AnatomyCanvas>(find.byType(AnatomyCanvas)).onTapped(position);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 320));
  await tester.pumpAndSettle();
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

/// Opens the region a gene-page [position] lies in as its DNA, and that base's
/// sheet in it.
Future<void> _openBaseInDna(WidgetTester tester, int position) async {
  // The region is chosen through the canvas, not by hunting for its cell,
  // which on a gene of 24,000 bases is two points wide.
  tester
      .widget<AnatomyCanvas>(find.byType(AnatomyCanvas))
      .onTapped(position, asRun: true);
  await tester.pump();
  await tester.tap(_key('open-dna'));
  await tester.pumpAndSettle();
  expect(find.byType(AnatomySelectionCanvas), findsOneWidget);
  await _tapPosition(tester, position);
}

Future<void> _capture(WidgetTester tester, String name) async {
  final String? directory = Platform.environment['SHOT_DIR'];
  if (directory == null) return;
  final RenderRepaintBoundary boundary = tester.renderObject(
    _key('synthesis-capture'),
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

/// The bars' track, which every row of the sheet draws on the one scale.
Rect _barTrack(WidgetTester tester) => tester.getRect(
  find
      .descendant(of: find.byType(ScoreBar), matching: find.byType(Stack))
      .first,
);

/// Every label the scale draws, by its text.
Map<String, Rect> _scaleLabels(WidgetTester tester) => <String, Rect>{
  for (final Element element
      in find
          .descendant(of: find.byType(ScoreScale), matching: find.byType(Text))
          .evaluate())
    (element.widget as Text).data!: tester.getRect(
      find.byElementPredicate((Element e) => e == element),
    ),
};

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
    await _open(tester);
    // c.20, the middle of Leu7's CTC: every change makes another amino acid.
    await _pick(tester, 5243);
    expect(
      _plain(tester, 'impact-level'),
      'high impact · rank 153 of 333 in the CDS',
    );
    expect(_tag(tester, 'A'), 'His');
    expect(_tag(tester, 'G'), 'Arg');
    expect(_tag(tester, 'C'), 'Pro');
    expect(
      find.bySemanticsLabel(RegExp(RegExp.escape('A, Phred 23.2, histidine'))),
      findsOneWidget,
    );
    await _capture(tester, 'synthesis-c20');

    // c.11, the middle of Trp4's TGG: one change is a stop, and it leads the
    // gene's coding bases.
    await _pick(tester, 5234);
    expect(
      _plain(tester, 'impact-level'),
      'high impact · rank 1 of 333 in the CDS',
    );
    expect(_tag(tester, 'A'), 'Ter');
    expect(_tag(tester, 'C'), 'Ser');
    expect(_tag(tester, 'T'), 'Leu');
    expect(
      find.bySemanticsLabel(RegExp(RegExp.escape('A, Phred 54.7, stop codon'))),
      findsOneWidget,
    );
    await _capture(tester, 'synthesis-c11');

    // c.78, the third base of Val26's GTG: every change keeps it.
    await _pick(tester, 5301);
    expect(
      _plain(tester, 'impact-level'),
      'moderate impact · rank 283 of 333 in the CDS',
    );
    for (final String base in <String>['A', 'C', 'T']) {
      expect(_tag(tester, base), '=', reason: base);
    }
    expect(
      find.bySemanticsLabel(
        RegExp(RegExp.escape('T, Phred 10.4, same amino acid')),
      ),
      findsOneWidget,
    );
    await _capture(tester, 'synthesis-c78');
    semantics.dispose();
  });

  testWidgets('a change anywhere in the start codon is a lost start, ?', (
    tester,
  ) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    await _open(tester);
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
    expect(
      find.bySemanticsLabel(
        RegExp(RegExp.escape('A, Phred 36.3, start codon lost')),
      ),
      findsOneWidget,
    );
    await _capture(tester, 'synthesis-c3');
    semantics.dispose();
  });

  testWidgets('an untranslated base ranks in its own UTR, with no tags', (
    tester,
  ) async {
    await _open(tester);
    await _pick(tester, 5000);
    expect(
      _plain(tester, 'impact-level'),
      'low impact · rank 55 of 59 in the 5′ UTR',
    );
    for (final String base in <String>['A', 'C', 'T']) {
      expect(_key('impact-tag-$base'), findsNothing, reason: base);
    }
    await _capture(tester, 'synthesis-utr5');
    await _pick(tester, 6380);
    expect(
      _plain(tester, 'impact-level'),
      'low impact · rank 43 of 73 in the 3′ UTR',
    );
  });

  testWidgets('an intronic base ranks among every intron of the gene', (
    tester,
  ) async {
    await _open(tester, transcript: false);
    // The second base of intron 2, the T of its GT.
    await _openBaseInDna(tester, 5412);
    expect(
      _plain(tester, 'impact-level'),
      'high impact · rank 1 of 966 in the introns',
    );
    await _capture(tester, 'synthesis-intron');
  });

  testWidgets('a borrowed score says its band alone', (tester) async {
    await _open(
      tester,
      impact: _track(TestCatalog.insulin, without: <String>['5301']),
    );
    await _pick(tester, 5301);
    expect(_key('impact-estimated'), findsOneWidget);
    expect(_plain(tester, 'impact-level'), isNot(contains('·')));
  });

  testWidgets('a shortened intron says its band alone', (tester) async {
    // CFTR's introns are drawn with their middles cut, so their drawn bases
    // are not all their bases, and no rank among them is said.
    await _open(
      tester,
      target: TestCatalog.cftr,
      record: _record('cftr'),
      transcript: false,
    );
    await _openBaseInDna(tester, 19370);
    expect(_plain(tester, 'impact-level'), 'moderate impact');
  });

  testWidgets('the scale marks the genome\'s shares, each ending at its '
      'point', (tester) async {
    await _open(tester);
    await _pick(tester, 5243);
    final Rect track = _barTrack(tester);
    final Map<String, Rect> labels = _scaleLabels(tester);
    expect(
      labels.keys,
      unorderedEquals(<String>['top 10%', '1%', '0.1%', '0.01%']),
    );
    for (final (String label, double phred) in <(String, double)>[
      ('top 10%', 10),
      ('1%', 20),
      ('0.1%', 30),
    ]) {
      final Rect rect = labels[label]!;
      final double point =
          track.left + track.width * phred / GeneImpact.barCeiling;
      // A mark ends at its point, or, wider than the room before its point,
      // starts where the bars do.
      expect(
        rect.right,
        closeTo(math.max(point, track.left + rect.width), 1),
        reason: label,
      );
      expect(rect.left, greaterThanOrEqualTo(track.left - 0.5), reason: label);
    }
    expect(
      tester.getRect(_key('impact-scale-end')).right,
      closeTo(track.right, 1),
    );
  });

  testWidgets('no two of the scale\'s labels meet, and the end is always '
      'said', (tester) async {
    for (final Size size in <Size>[
      const Size(320, 640),
      const Size(375, 667),
      const Size(390, 844),
    ]) {
      for (final double scale in <double>[1, 1.5, 2]) {
        await _open(tester, size: size, textScale: scale);
        await _pick(tester, 5243);
        final Rect bounds = tester.getRect(find.byType(ScoreScale));
        final List<MapEntry<String, Rect>> labels = _scaleLabels(tester).entries
            .toList();
        final String at = '${size.width}×${size.height} at ${scale}x';
        expect(labels.map((e) => e.key), contains('0.01%'), reason: at);
        for (final MapEntry<String, Rect> label in labels) {
          expect(label.value.left, greaterThanOrEqualTo(bounds.left - 0.5));
          expect(label.value.right, lessThanOrEqualTo(bounds.right + 0.5));
        }
        for (int i = 0; i < labels.length; i++) {
          for (int j = i + 1; j < labels.length; j++) {
            final Rect a = labels[i].value;
            final Rect b = labels[j].value;
            expect(
              a.right <= b.left || b.right <= a.left,
              isTrue,
              reason: '$at: ${labels[i].key} meets ${labels[j].key}',
            );
          }
        }
        // On a phone of today's width at the size it ships with, every mark
        // has its room.
        if (size.width >= 375 && scale == 1) {
          expect(
            labels.map((e) => e.key),
            containsAll(<String>['top 10%', '1%', '0.1%']),
            reason: at,
          );
        }
        if (size.width == 390 && scale == 2) {
          await _capture(tester, 'synthesis-c20-2x');
        }
      }
    }
  });

  testWidgets('a scale with no marks draws its two ends as it always has', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ScoreScale(
            low: '−10 or lower',
            high: '0 or higher',
            style: null,
          ),
        ),
      ),
    );
    expect(tester.widget<ScoreScale>(find.byType(ScoreScale)).marks, isEmpty);
    expect(find.text('−10 or lower'), findsOneWidget);
    expect(find.text('0 or higher'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(ScoreScale),
        matching: find.byType(FittedBox),
      ),
      findsOneWidget,
    );
  });
}
