import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/core/biology/gene_record.dart';
import 'package:helixpeek/core/theme/app_theme.dart';
import 'package:helixpeek/features/gene_lookup/data/models/gene_record_dto.dart';
import 'package:helixpeek/shared/anatomy/sequence_scrubber.dart';
import 'package:helixpeek/shared/motion/timeline_controller.dart';
import 'package:helixpeek/shared/motion/transport_bar.dart';
import 'package:helixpeek/shared/ribosome/director.dart';
import 'package:helixpeek/shared/ribosome/translation_player.dart';
import 'package:helixpeek/shared/ribosome/translation_timeline.dart';

import '../../support/test_catalog.dart';

GeneRecord _gene(String gene) => GeneRecordDto.fromJson(
  jsonDecode(File('test/fixtures/mock/gene_$gene.json').readAsStringSync())
      as Map<String, dynamic>,
).toEntity();

/// The player on its own, with the clock a caller would give it.
Future<void> _host(WidgetTester tester, String slug, String gene) async {
  await tester.binding.setSurfaceSize(const Size(390, 844));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final GeneRecord record = _gene(gene);
  final TranslationTimeline translation = TranslationTimeline(
    record,
    chain: TestCatalog.bySlug(slug)!.chain,
  );
  final TranslationDirector director = TranslationDirector(translation);
  final TimelineController controller = TimelineController(
    vsync: tester,
    timeline: translation,
    beat: TranslationPlayer.beat,
    speedCurve: director.curve,
  );
  addTearDown(controller.dispose);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.analysis,
      home: Scaffold(
        body: SafeArea(
          child: TranslationPlayer(
            translation: translation,
            controller: controller,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

String _text(WidgetTester tester, String key) =>
    tester.widget<Text>(find.byKey(ValueKey<String>(key))).data!;

void main() {
  testWidgets('the whole sequence plays under the transport bar and minimap', (
    WidgetTester tester,
  ) async {
    await _host(tester, 'insulin', 'ins');
    expect(find.byType(TransportBar), findsOneWidget);
    expect(find.byType(SequenceScrubber), findsOneWidget);
    expect(find.text('Scanning the 5′ UTR'), findsOneWidget);
    // Only the phase's name is written under the canvas: no sentence, no
    // cell clock.
    expect(
      find.byKey(const ValueKey<String>('ribosome-caption')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey<String>('ribosome-cell-time')),
      findsNothing,
    );

    await tester.tap(find.byTooltip('Step forward'));
    await tester.pump();
    expect(find.text('The large subunit joins'), findsOneWidget);

    // A codon is named by its number alone, through all four of its stops.
    for (int stop = 0; stop < 4; stop++) {
      await tester.tap(find.byTooltip('Step forward'));
      await tester.pump();
      expect(_text(tester, 'transport-phase'), 'Codon 2', reason: 'stop $stop');
    }
    await tester.tap(find.byTooltip('Step forward'));
    await tester.pump();
    expect(_text(tester, 'transport-phase'), 'Codon 3');
    expect(find.textContaining('·'), findsNothing);

    await tester.tap(find.byTooltip('Play'));
    await tester.pump();
    for (int i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('Pause'));
    await tester.pump();
    expect(_text(tester, 'transport-phase'), startsWith('Codon '));
  });

  testWidgets('a long protein plays too: dystrophin', (
    WidgetTester tester,
  ) async {
    await _host(tester, 'dystrophin', 'dmd');
    await tester.tap(find.byTooltip('Play'));
    await tester.pump();
    for (int i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 500));
    }
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('Pause'));
    await tester.pump();
  });
}
