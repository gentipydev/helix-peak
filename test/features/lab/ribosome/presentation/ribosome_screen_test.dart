import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/core/biology/gene_record.dart';
import 'package:helixpeek/core/theme/app_theme.dart';
import 'package:helixpeek/features/gene_lookup/data/models/gene_record_dto.dart';
import 'package:helixpeek/features/lab/ribosome/presentation/ribosome_screen.dart';
import 'package:helixpeek/shared/anatomy/sequence_scrubber.dart';
import 'package:helixpeek/shared/motion/transport_bar.dart';

import '../../../../support/test_catalog.dart';

GeneRecord _gene(String gene) => GeneRecordDto.fromJson(
  jsonDecode(File('test/fixtures/mock/gene_$gene.json').readAsStringSync())
      as Map<String, dynamic>,
).toEntity();

Future<void> _host(WidgetTester tester, String slug, String gene) async {
  await tester.binding.setSurfaceSize(const Size(390, 844));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.analysis,
      home: RibosomeScreen(
        target: TestCatalog.bySlug(slug)!,
        record: _gene(gene),
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
    expect(_text(tester, 'ribosome-caption'), contains('59 bases'));
    expect(
      _text(tester, 'ribosome-cell-time'),
      'In a cell: 0.0 s of 19.5 s, at 5.6 residues a second',
    );

    await tester.tap(find.byTooltip('Step forward'));
    await tester.pump();
    expect(find.text('The large subunit joins'), findsOneWidget);
    expect(_text(tester, 'ribosome-caption'), contains('Kozak'));

    await tester.tap(find.byTooltip('Play'));
    await tester.pump();
    for (int i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('Pause'));
    await tester.pump();
    expect(
      _text(tester, 'ribosome-cell-time'),
      isNot(startsWith('In a cell: 0.0')),
    );
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
