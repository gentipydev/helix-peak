import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/core/theme/app_colors.dart';
import 'package:helixpeek/core/theme/nucleotide_colors.dart';
import 'package:helixpeek/features/home/presentation/widgets/dna_helix_painter.dart';
import 'package:helixpeek/features/home/presentation/widgets/helix_geometry.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('render helix frames', () async {
    final String? outputPath = Platform.environment['HELIX_OUT'];
    if (outputPath == null || outputPath.isEmpty) {
      markTestSkipped('set HELIX_OUT to render the helix frames');
      return;
    }

    const Size frame = Size(342, 523);

    // A polymerase is on screen, bubble or trail, for progress in roughly
    // 0.40 to 0.84 — the heads now run a transcript span past each model end.
    const List<double> progress = <double>[
      0.42,
      0.50,
      0.58,
      0.66,
      0.74,
      0.82,
      HelixModel.staticTranscriptionTurns,
    ];

    const List<(AppColorTokens, NucleotideColors)> themes =
        <(AppColorTokens, NucleotideColors)>[
      (AppColorTokens.dark, NucleotideColors.dark),
    ];

    // The painter deliberately draws _cullMargin past the frame, so packed
    // cells bleed into one another. A gutter keeps each cell honest.
    const double gutter = 40;

    final Size total = Size(
      frame.width * progress.length,
      frame.height * themes.length + gutter * (themes.length - 1),
    );

    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder);
    final HelixModel model = HelixModel();

    for (int row = 0; row < themes.length; row++) {
      final (AppColorTokens tokens, NucleotideColors bases) = themes[row];

      final double rowY = (frame.height + gutter) * row;

      canvas.drawRect(
        Rect.fromLTWH(0, rowY, total.width, frame.height),
        Paint()..color = tokens.surfaceBase,
      );

      for (int col = 0; col < progress.length; col++) {
        final bool isStill = col == progress.length - 1;

        canvas.save();
        canvas.translate(frame.width * col, rowY);
        canvas.clipRect(Offset.zero & frame);
        DnaHelixPainter(
          repaint: const AlwaysStoppedAnimation<double>(0),
          rotation: AlwaysStoppedAnimation<double>(
            isStill ? HelixModel.staticRotationTurns : 0.08 + col * 0.02,
          ),
          drift: const AlwaysStoppedAnimation<double>(0.5),
          transcription: AlwaysStoppedAnimation<double>(progress[col]),
          model: model,
          backbone: tokens.onSurfaceVariant,
          adenine: bases.adenine,
          thymine: bases.thymine,
          guanine: bases.guanine,
          cytosine: bases.cytosine,
          transcript: tokens.accent,
          background: tokens.surfaceBase,
        ).paint(canvas, frame);
        canvas.restore();
      }
    }

    final ui.Image image = await recorder.endRecording().toImage(
          total.width.round(),
          total.height.round(),
        );
    final ByteData? bytes =
        await image.toByteData(format: ui.ImageByteFormat.png);

    File(outputPath).writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}
