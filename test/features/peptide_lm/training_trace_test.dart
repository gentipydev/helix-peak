import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/features/peptide_lm/domain/training_trace.dart';

import 'support/toy_trace.dart';

Uint8List _edited(void Function(Map<String, dynamic> json) edit) {
  final Map<String, dynamic> json =
      jsonDecode(utf8.decode(toyBytes())) as Map<String, dynamic>;
  edit(json);
  return Uint8List.fromList(utf8.encode(jsonEncode(json)));
}

void main() {
  final TrainingTrace trace = toyTrace();

  test('the run reads whole: the model, the data, every step and checkpoint', () {
    expect(trace.name, 'toy');
    expect(trace.vocab, hasLength(23));
    expect(trace.vocab.take(3), <String>['<pad>', '<bos>', '<eos>']);
    expect(trace.allowed, hasLength(21));
    expect(trace.allowed, isNot(contains(0)));
    expect(trace.allowed, isNot(contains(1)));
    expect(trace.model.layers, 2);
    expect(trace.points, <String>['x0', 'm1', 'h1', 'm2', 'h2', 'hf']);
    expect(trace.groupSizes.reduce((int a, int b) => a + b), trace.model.parameters);
    expect(trace.steps.count, 20);
    expect(
      trace.checkpoints.map((TraceCheckpoint c) => c.step),
      <int>[1, 2, 3, 9, 11, 20],
    );
    expect(trace.checkpoints.first.why, <String>['first']);
    expect(trace.checkpoints.last.why, <String>['last']);
  });

  test('peptides come shortest first, each with where it came from', () {
    expect(
      trace.peptides.map((TracePeptide p) => p.sequence),
      <String>['GIVEQCCTSIC', 'QLYSALANKCCH'],
    );
    expect(trace.peptides.first.source.label, 'toy A');
    expect(trace.targetCount, 12 + 13);
    expect(trace.residues, 23);
    expect(trace.offsets, <int>[0, 12]);
    // Framed and padded to the longest, cut as the batches are.
    expect(trace.inputAt(0, 0), 1);
    expect(trace.targetAt(0, 11), 2);
    expect(trace.inputs.first.length, trace.width);
    expect(trace.pads, 2 * (trace.width + 1) - (23 + 4));
  });

  test("each step's targets average to its loss", () {
    for (int step = 1; step <= trace.steps.count; step++) {
      double sum = 0;
      for (int p = 0; p < trace.peptides.length; p++) {
        for (int i = 0; i < trace.peptides[p].inputs; i++) {
          sum += trace.targetLoss(step, p, i);
        }
      }
      expect(sum / trace.targetCount, closeTo(trace.loss(step), 2e-3));
      expect(trace.loss(step), greaterThanOrEqualTo(trace.floor));
    }
  });

  test('every attention row is a share of what came before, and sums to one', () {
    for (final TraceCheckpoint c in trace.checkpoints) {
      for (int layer = 0; layer < trace.model.layers; layer++) {
        for (int head = 0; head < trace.model.heads; head++) {
          for (int p = 0; p < trace.peptides.length; p++) {
            for (int q = 0; q < trace.peptides[p].inputs; q++) {
              double sum = 0;
              for (int k = 0; k <= q; k++) {
                sum += trace.attention(c, layer, head, p, q, k);
              }
              expect(sum, closeTo(1, (q + 1) / 255 + 1e-3));
            }
          }
        }
      }
    }
  });

  test("the probabilities are over what can come next, and the targets' agree", () {
    final TraceCheckpoint last = trace.checkpoints.last;
    for (int p = 0; p < trace.peptides.length; p++) {
      for (int i = 0; i < trace.peptides[p].inputs; i++) {
        double sum = 0;
        for (int column = 0; column < trace.allowed.length; column++) {
          sum += trace.probability(last, p, i, column);
        }
        expect(sum, closeTo(1, 21 / 255));
        final int target = trace.allowedIndex(trace.targetAt(p, i));
        expect(
          trace.probability(last, p, i, target),
          closeTo(math.exp(-trace.targetLoss(last.step, p, i)), 0.01),
        );
      }
    }
  });

  test('the update a checkpoint kept is how far the output layer moved', () {
    for (final TraceCheckpoint c in trace.checkpoints) {
      if (c.step == trace.steps.count) {
        continue;
      }
      final double tolerance = trace.steps.headWeightScales[c.step - 1] +
          trace.steps.headWeightScales[c.step] +
          c.headUpdateScale;
      for (int r = 0; r < trace.vocab.length; r++) {
        for (int d = 0; d < trace.model.width; d++) {
          final double moved =
              trace.headWeight(c.step + 1, r, d) - trace.headWeight(c.step, r, d);
          expect(trace.headUpdate(c, r, d), closeTo(moved, tolerance));
        }
      }
    }
  });

  test("each place's x0 is its id's token row plus its place's row", () {
    for (final TraceCheckpoint c in trace.checkpoints) {
      final double tolerance =
          (c.streamScales[0] + c.tokenEmbeddingScale + c.positionEmbeddingScale) / 2 + 1e-6;
      for (int d = 0; d < trace.model.width; d++) {
        expect(trace.tokenEmbedding(c, 0, d), 0);
      }
      for (int p = 0; p < trace.peptides.length; p++) {
        for (int i = 0; i < trace.peptides[p].inputs; i++) {
          for (int d = 0; d < trace.model.width; d++) {
            expect(
              trace.tokenEmbedding(c, trace.inputAt(p, i), d) + trace.positionEmbedding(c, i, d),
              closeTo(trace.stream(c, 0, p, i, d), tolerance),
            );
          }
        }
      }
    }
  });

  test('a run without its embedding tables is refused', () {
    final Uint8List bytes = _edited((Map<String, dynamic> json) {
      ((json['checkpoints'] as List<dynamic>).first as Map<String, dynamic>)
          .remove('position_embedding');
    });
    expect(() => TrainingTrace.parse(bytes), throwsA(isA<FormatException>()));
  });

  test('another run than the one asked for is refused', () {
    expect(
      () => TrainingTrace.parse(toyBytes(), name: 'curated'),
      throwsA(isA<FormatException>()),
    );
  });

  test('a schema this does not read is refused', () {
    expect(
      () => TrainingTrace.parse(_edited((Map<String, dynamic> json) => json['schema'] = 2)),
      throwsA(isA<FormatException>()),
    );
  });

  test('an array cut short is refused', () {
    final Uint8List bytes = _edited((Map<String, dynamic> json) {
      final Map<String, dynamic> loss =
          (json['steps'] as Map<String, dynamic>)['loss'] as Map<String, dynamic>;
      final Uint8List raw = base64Decode(loss['data'] as String);
      loss['data'] = base64Encode(raw.sublist(0, raw.length - 4));
    });
    expect(() => TrainingTrace.parse(bytes), throwsA(isA<FormatException>()));
  });

  test('an array of another shape than the run is refused', () {
    final Uint8List bytes = _edited((Map<String, dynamic> json) {
      ((json['steps'] as Map<String, dynamic>)['loss'] as Map<String, dynamic>)['shape'] =
          <int>[19];
    });
    expect(() => TrainingTrace.parse(bytes), throwsA(isA<FormatException>()));
  });
}
