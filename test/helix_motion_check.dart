import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/core/theme/app_colors.dart';
import 'package:helixpeek/core/theme/nucleotide_colors.dart';
import 'package:helixpeek/features/home/presentation/widgets/dna_helix_painter.dart';
import 'package:helixpeek/features/home/presentation/widgets/helix_geometry.dart';

/// Measures how evenly the helix moves, frame to frame.
///
/// Smooth motion changes a roughly constant amount of ink per frame. A pop —
/// a strand snapping across a base because the depth sort swapped them, or a
/// transcript point jumping because a profile table was read by nearest
/// neighbour — dumps far more change into one frame than its neighbours. So
/// the tell is not how much a frame differs from the last, but how *unevenly*
/// that differs across a sweep: divide the worst frame by the typical one.
Future<void> main() async {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('helix motion is even frame to frame', () async {
    if ((Platform.environment['HELIX_MOTION'] ?? '').isEmpty) {
      markTestSkipped('set HELIX_MOTION=1 to measure frame-to-frame motion');
      return;
    }

    const Size frame = Size(342, 523);
    const int frames = 180;
    const int fps = 60;

    // One real frame of each loop, so the sweep is what a device would show.
    const double dRotation = 1 / (24 * fps);
    const double dDrift = 1 / (140 * fps);
    const double dTranscription = 1 / (144 * fps);

    final HelixModel model = HelixModel();
    const AppColorTokens tokens = AppColorTokens.dark;
    const NucleotideColors bases = NucleotideColors.dark;

    Future<Uint8List> render(double start, int k) async {
      final ui.PictureRecorder recorder = ui.PictureRecorder();
      final Canvas canvas = Canvas(recorder);

      DnaHelixPainter(
        repaint: const AlwaysStoppedAnimation<double>(0),
        rotation: AlwaysStoppedAnimation<double>(0.08 + k * dRotation),
        drift: AlwaysStoppedAnimation<double>(0.20 + k * dDrift),
        transcription: AlwaysStoppedAnimation<double>(
          (start + k * dTranscription) % 1,
        ),
        model: model,
        backbone: tokens.onSurfaceVariant,
        adenine: bases.adenine,
        thymine: bases.thymine,
        guanine: bases.guanine,
        cytosine: bases.cytosine,
        transcript: tokens.accent,
        background: tokens.surfaceBase,
      ).paint(canvas, frame);

      final ui.Image image = await recorder.endRecording().toImage(
            frame.width.round(),
            frame.height.round(),
          );
      final ByteData? bytes =
          await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      image.dispose();
      return bytes!.buffer.asUint8List();
    }

    Future<void> sweep(String label, double start) async {
      final List<double> change = <double>[];
      Uint8List previous = await render(start, 0);

      for (int k = 1; k < frames; k++) {
        final Uint8List current = await render(start, k);

        int total = 0;
        for (int p = 0; p < current.length; p += 4) {
          total += (current[p] - previous[p]).abs();
          total += (current[p + 1] - previous[p + 1]).abs();
          total += (current[p + 2] - previous[p + 2]).abs();
        }
        change.add(total / (current.length / 4));
        previous = current;
      }

      final List<double> sorted = List<double>.of(change)..sort();
      final double median = sorted[sorted.length ~/ 2];
      final double worst = sorted.last;
      final double ratio = worst / median;

      int worstFrame = 0;
      for (int i = 0; i < change.length; i++) {
        if (change[i] == worst) {
          worstFrame = i + 1;
        }
      }

      // ignore: avoid_print
      print('$label  median=${median.toStringAsFixed(3)}  '
          'worst=${worst.toStringAsFixed(3)} (frame $worstFrame)  '
          'ratio=${ratio.toStringAsFixed(2)}x');

      // The painter this replaced scored 1.37 on the passage sweep and 1.59
      // across the wrap; this sits at about 1.15 with room to spare.
      expect(
        ratio,
        lessThan(1.35),
        reason: '$label: frame $worstFrame moved '
            '${ratio.toStringAsFixed(2)}x more ink than a typical frame, '
            'which is what a pop looks like',
      );
    }

    // Mid-passage: a polymerase crossing the frame with its transcript behind.
    await sweep('passage', 0.50);

    // Across the wrap, where a head leaves one end and the next enters the
    // other. The trail lags a whole span behind the head, so if the heads did
    // not run past the model ends this is where it would blink out.
    await sweep('wrap    ', 1 - frames * dTranscription / 2);
  });
}
