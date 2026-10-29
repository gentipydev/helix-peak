// The peptide language model's recorded run, read from a running backend the
// way the page reads it, and held to what the page assumes of it.
//
// Opt-in: skipped unless LIVE_BACKEND is set, so `flutter test` stays offline.
//
//   LIVE_BACKEND=https://helix-peak-backend.onrender.com \
//     flutter test test/peptide_lm_live_check.dart
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/core/network/dio_api_client.dart';
import 'package:helixpeek/core/network/track_client.dart';
import 'package:helixpeek/features/peptide_lm/data/training_run_repository.dart';
import 'package:helixpeek/features/peptide_lm/domain/training_trace.dart';

void main() {
  final String baseUrl = Platform.environment['LIVE_BACKEND'] ?? '';

  test('the curated run loads from storage and holds together', () async {
    if (baseUrl.isEmpty) {
      markTestSkipped('set LIVE_BACKEND to run against a live backend');
      return;
    }
    final Directory root = Directory.systemTemp.createTempSync('helixpeek-lm');
    addTearDown(() => root.deleteSync(recursive: true));
    final TrackClient client = TrackClient(
      DioApiClient(baseUrl: baseUrl, timeout: const Duration(seconds: 90)),
      cache: Directory('${root.path}/peptide_lm')..createSync(),
      folder: 'peptide_lm',
    );
    final TrainingTrace trace = await TrainingRunRepository(client.readRow).load();

    expect(trace.name, TrainingRunRepository.curated);
    expect(trace.peptides, isNotEmpty);
    expect(trace.checkpoints.first.step, 1);
    expect(trace.checkpoints.last.step, trace.steps.count);
    expect(trace.groupSizes.reduce((int a, int b) => a + b), trace.model.parameters);
    for (int step = 1; step <= trace.steps.count; step++) {
      expect(trace.loss(step), greaterThanOrEqualTo(trace.floor - 1e-4));
    }
    for (final TraceCheckpoint c in trace.checkpoints) {
      for (int p = 0; p < trace.peptides.length; p++) {
        for (int i = 0; i < trace.peptides[p].inputs; i++) {
          double probabilities = 0;
          for (int column = 0; column < trace.allowed.length; column++) {
            probabilities += trace.probability(c, p, i, column);
          }
          expect(probabilities, closeTo(1, trace.allowed.length / 255));
          for (int layer = 0; layer < trace.model.layers; layer++) {
            double read = 0;
            for (int k = 0; k <= i; k++) {
              read += trace.meanAttention(c, layer, p, i, k);
            }
            expect(read, closeTo(1, (i + 1) / 255 + 1e-3));
          }
        }
      }
    }
    // Learned by heart but the first residue: the last step sits by the floor.
    expect(trace.loss(trace.steps.count) - trace.floor, lessThan(0.05));
    expect(trace.loss(1), greaterThan(math.log(trace.allowed.length) - 0.5));
  });
}
