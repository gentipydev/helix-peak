// Temporary visual check — renders the helix painter across a transcription
// cycle, in both themes, so the geometry can be inspected. Not part of the
// test suite.
//
//   HELIX_OUT=<path>.png flutter test test/helix_render_check.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeak/core/theme/app_colors.dart';
import 'package:helixpeak/core/theme/nucleotide_colors.dart';
import 'package:helixpeak/features/home/presentation/widgets/dna_helix_painter.dart';
import 'package:helixpeak/features/home/presentation/widgets/helix_geometry.dart';

/// Loads a bundled family into the test engine.
///
/// Without this the bases render as filled boxes: `flutter test` does not read
/// the asset manifest, so a requested family falls through to the test font,
/// and every glyph in it is a rectangle. A harness that silently substitutes
/// boxes for letters is worse than no harness.
Future<void> _loadFont(String family, List<String> paths) async {
  final FontLoader loader = FontLoader(family);
  for (final String path in paths) {
    loader.addFont(
      Future<ByteData>.value(
        ByteData.view(File(path).readAsBytesSync().buffer),
      ),
    );
  }
  await loader.load();
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await _loadFont('JetBrainsMono', <String>[
      'assets/fonts/JetBrainsMono-Regular.ttf',
      'assets/fonts/JetBrainsMono-Medium.ttf',
    ]);
  });

  test('render helix frames', () async {
    // This file lives under test/, so `flutter test` picks it up with
    // everything else. It is a rendering tool, not an assertion, so without an
    // output path it skips rather than failing the suite.
    final String? outputPath = Platform.environment['HELIX_OUT'];
    if (outputPath == null || outputPath.isEmpty) {
      markTestSkipped('set HELIX_OUT to render the helix frames');
      return;
    }

    // The helix box on a phone: a 340 wide viewport less nothing, and what is
    // left of a tall one after the wordmark and the button. Judging the render
    // at any other size judges something that does not ship.
    const Size frame = Size(340, 620);

    // Walk a polymerase down the frame. The rotation advances only slightly
    // across the strip so that what changes between columns is the process,
    // not the spin.
    const List<double> progress = <double>[
      0.34,
      0.40,
      0.46,
      0.52,
      0.58,
      0.64,
      HelixModel.staticTranscriptionTurns,
    ];

    const List<(AppColorTokens, NucleotideColors)> themes =
        <(AppColorTokens, NucleotideColors)>[
      (AppColorTokens.dark, NucleotideColors.dark),
      (AppColorTokens.light, NucleotideColors.light),
    ];

    final Size total = Size(
      frame.width * progress.length,
      frame.height * themes.length,
    );

    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder);
    final HelixModel model = HelixModel();

    for (int row = 0; row < themes.length; row++) {
      final (AppColorTokens tokens, NucleotideColors bases) = themes[row];

      canvas.drawRect(
        Rect.fromLTWH(0, frame.height * row, total.width, frame.height),
        Paint()..color = tokens.surfaceBase,
      );

      for (int col = 0; col < progress.length; col++) {
        // The last column is the reduced-motion still, so it uses the composed
        // angle rather than the sweep.
        final bool isStill = col == progress.length - 1;

        canvas.save();
        canvas.translate(frame.width * col, frame.height * row);
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
