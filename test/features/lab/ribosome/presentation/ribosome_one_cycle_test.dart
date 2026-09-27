import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/core/biology/gene_record.dart';
import 'package:helixpeek/core/theme/app_theme.dart';
import 'package:helixpeek/features/gene_lookup/data/models/gene_record_dto.dart';
import 'package:helixpeek/features/lab/ribosome/domain/one_cycle.dart';
import 'package:helixpeek/features/lab/ribosome/domain/translation_timeline.dart';
import 'package:helixpeek/features/lab/ribosome/presentation/ribosome_screen.dart';
import 'package:helixpeek/features/lab/ribosome/presentation/translation_painter.dart';
import 'package:helixpeek/shared/motion/animation_timeline.dart';
import 'package:helixpeek/shared/motion/transport_bar.dart';

import '../../../../support/test_catalog.dart';

GeneRecord _gene(String gene) => GeneRecordDto.fromJson(
  jsonDecode(File('test/fixtures/mock/gene_$gene.json').readAsStringSync())
      as Map<String, dynamic>,
).toEntity();

void main() {
  final GeneRecord insulin = _gene('ins');
  final TranslationTimeline translation = TranslationTimeline(insulin);

  group('one elongation cycle', () {
    final OneCycle cycle = OneCycle(translation, codon: 2);

    test('is the four slices of one codon’s beat', () {
      expect(cycle.phases.map((PhaseMark m) => m.captionKey), <String>[
        'decoding',
        'peptideBond',
        'translocation',
        'trnaExit',
      ]);
      expect(cycle.phases.map((PhaseMark m) => m.t), <Matcher>[
        closeTo(0, 1e-9),
        closeTo(0.35, 1e-9),
        closeTo(0.55, 1e-9),
        closeTo(0.85, 1e-9),
      ]);
    });

    test('shows the whole translation’s own state at each moment', () {
      for (final double t in <double>[0, 0.2, 0.4, 0.6, 0.9, 1]) {
        expect(cycle.stateAt(t), translation.stateAt(cycle.fullT(t)));
      }
      expect(cycle.stateAt(0).residues, 1);
      expect(cycle.stateAt(0.99).residues, 2);
      expect(cycle.stateAt(0.99).p!.codon, 2);
    });
  });

  group('the painter', () {
    void paintAt(TranslationTimeline timeline, double t, Size size) {
      final ui.PictureRecorder recorder = ui.PictureRecorder();
      final Canvas canvas = Canvas(recorder);
      TranslationPainter(
        timeline: timeline,
        at: () => t,
        inks: TranslationInks(
          background: AppTheme.analysis.colorScheme.surface,
          smallSubunit: AppTheme.analysis.colorScheme.surfaceContainerHighest,
          largeSubunit: AppTheme.analysis.colorScheme.surfaceContainerHigh,
          outline: AppTheme.analysis.colorScheme.outline,
          ink: AppTheme.analysis.colorScheme.onSurface,
          quiet: AppTheme.analysis.colorScheme.onSurfaceVariant,
          nucleotides: AppTheme.analysis.extension()!,
          anatomy: AppTheme.analysis.extension()!,
        ),
      ).paint(canvas, size);
      recorder.endRecording().dispose();
    }

    test('draws every phase boundary of a translation, at two widths', () {
      for (final Size size in <Size>[
        const Size(390, 560),
        const Size(320, 480),
      ]) {
        for (final double t in translation.boundaries) {
          paintAt(translation, t, size);
        }
      }
    });

    test('windows a long gene: dystrophin, anywhere along it', () {
      final TranslationTimeline long = TranslationTimeline(_gene('dmd'));
      for (final double t in <double>[0, 0.001, 0.25, 0.5, 0.75, 0.999, 1]) {
        paintAt(long, t, const Size(390, 560));
      }
    });

    test('describes each moment for a screen reader', () {
      expect(
        TranslationPainter.describe(translation, translation.stateAt(0)),
        'The small subunit is scanning the 5 prime UTR. 0 of 110 residues '
        'made.',
      );
      final OneCycle cycle = OneCycle(translation, codon: 2);
      expect(
        TranslationPainter.describe(translation, cycle.stateAt(0.99)),
        'Codon 2, alanine. 2 of 110 residues made.',
      );
    });
  });

  testWidgets('the screen steps through one cycle with the transport bar', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.analysis,
        home: RibosomeScreen(target: TestCatalog.insulin, record: insulin),
      ),
    );
    await tester.pump();
    expect(find.byType(TransportBar), findsOneWidget);
    expect(find.text('Codon 2 · decoding'), findsOneWidget);

    for (final String next in <String>[
      'Codon 2 · peptide bond',
      'Codon 2 · translocation',
      'Codon 2 · tRNA exit',
    ]) {
      await tester.tap(find.byTooltip('Step forward'));
      await tester.pump();
      expect(find.text(next), findsOneWidget);
      expect(tester.takeException(), isNull);
    }

    await tester.tap(find.byTooltip('Play'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 5));
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('Reset'));
    await tester.pump();
    expect(find.text('Codon 2 · decoding'), findsOneWidget);
  });
}
