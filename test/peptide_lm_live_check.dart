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
import 'package:helixpeek/features/peptide_lm/presentation/lm_format.dart';

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

    expectTheWorkedExample(trace);
    expectTheWorkedAnswer(trace);
  });
}

/// The worked example Attention draws (docs/design/peptide-lm.md): insulin A
/// chain's C11 at step 1, block 1. Its heads' answers, side by side, through
/// the output weights' first row, plus its bias, make the first number
/// attention adds, 0.11; and the 16 the page writes are what the stream gained
/// across attention.
void expectTheWorkedExample(TrainingTrace trace) {
  final TraceCheckpoint first = trace.checkpoints.first;
  expect(first.step, 1);
  expect(trace.peptides.first.sequence, 'GIVEQCCTSICSLYQLENYCN');
  const int c11 = 11;
  final List<double> answers = <double>[
    for (int h = 0; h < trace.model.heads; h++)
      for (int d = 0; d < trace.headSize; d++) trace.mixed(first, 0, h, 0, c11, d),
  ];
  expect(
    answers.map((double v) => v.toStringAsFixed(3)),
    <String>[
      '0.301', '-0.415', '0.451', '-0.604', '0.464', '0.112', '0.297', '0.352', //
      '0.018', '0.222', '-0.222', '-0.079', '0.051', '-0.231', '-0.344', '-0.709',
    ],
  );
  expect(trace.outBias(first, 0, 0), 0);
  double number1 = trace.outBias(first, 0, 0);
  for (int d = 0; d < trace.model.width; d++) {
    number1 += trace.outWeight(first, 0, 0, d) * answers[d];
  }
  expect(number1, closeTo(0.1135, 5e-5));
  expect(
    <String>[
      for (int d = 0; d < trace.model.width; d++)
        fixed(trace.stream(first, 1, 0, c11, d) - trace.stream(first, 0, 0, c11, d), 2),
    ],
    <String>[
      '0.11', '0.44', '−0.19', '0.40', '0.04', '−0.17', '0.16', '0.38', //
      '0.01', '−0.06', '0.29', '−0.13', '−0.17', '0.21', '0.46', '−0.23',
    ],
  );
}

/// Number 1 of head 1's answer, worked out as Attention draws it: insulin A
/// chain's C11 at step 1, block 1. Each place's value 1, up to C11; its
/// share, softmax of the scores as kept; what each brings, their product,
/// summed: the answer's number 1, 0.30. `<bos>`'s value 1, 0.108, only rounds
/// like the output's number 1, 0.1135.
void expectTheWorkedAnswer(TrainingTrace trace) {
  final TraceCheckpoint first = trace.checkpoints.first;
  expect(first.step, 1);
  const int c11 = 11;
  final List<double> scores = <double>[for (int j = 0; j <= c11; j++) trace.score(first, 0, 0, 0, c11, j)];
  final double top = scores.reduce(math.max);
  final List<double> e = <double>[for (final double s in scores) math.exp(s - top)];
  final double total = e.reduce((double a, double b) => a + b);
  final List<double> shares = <double>[for (final double x in e) x / total];
  final List<double> values = <double>[for (int j = 0; j <= c11; j++) trace.value(first, 0, 0, 0, j, 0)];
  expect(
    values.map((double v) => v.toStringAsFixed(3)),
    <String>['0.108', '1.089', '0.455', '0.598', '-0.363', '1.859', '-1.221', '-1.208', '0.180', '-0.114', '0.464', '-1.221'],
  );
  expect(
    shares.map((double s) => (s * 100).toStringAsFixed(1)),
    <String>['6.8', '5.3', '11.3', '7.7', '6.0', '11.2', '2.5', '2.5', '9.7', '23.4', '11.2', '2.5'],
  );
  double answer = 0;
  for (int j = 0; j <= c11; j++) {
    answer += shares[j] * values[j];
  }
  expect(answer, closeTo(0.3011, 5e-5));
  expect(trace.mixed(first, 0, 0, 0, c11, 0), closeTo(answer, 1e-5));
  expect(fixed(values.first, 2), '0.11');
  expect((values.first - 0.1135).abs(), greaterThan(0.004));
}
