import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/core/biology/gene_record.dart';
import 'package:helixpeek/core/theme/app_theme.dart';
import 'package:helixpeek/features/gene_lookup/data/models/gene_record_dto.dart';
import 'package:helixpeek/shared/ribosome/translation_painter.dart';
import 'package:helixpeek/shared/ribosome/translation_timeline.dart';

GeneRecord _gene(String gene) => GeneRecordDto.fromJson(
  jsonDecode(File('test/fixtures/mock/gene_$gene.json').readAsStringSync())
      as Map<String, dynamic>,
).toEntity();

void main() {
  final GeneRecord insulin = _gene('ins');
  final TranslationTimeline translation = TranslationTimeline(insulin);

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
      // Late in the beat that reads codon 2.
      final TranslationState codon2 = translation.stateAt(
        translation.beatStart(translation.beatOfCodon(2) + 0.99),
      );
      expect(
        TranslationPainter.describe(translation, codon2),
        'Codon 2, alanine. 2 of 110 residues made.',
      );
    });
  });
}
