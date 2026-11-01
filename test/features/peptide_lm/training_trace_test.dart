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

  test("each logit is the last row times its token's weights, plus its bias, whole", () {
    final int last = trace.points.length - 1;
    for (final TraceCheckpoint c in trace.checkpoints) {
      for (int r = 0; r < trace.vocab.length; r++) {
        for (int d = 0; d < trace.model.width; d++) {
          // The step's own int8 copy of the output layer rounds the whole one.
          final double step = trace.steps.headWeightScales[c.step - 1];
          expect(trace.outputWeight(c, r, d), closeTo(trace.headWeight(c.step, r, d), step / 2 + 1e-7));
        }
      }
      for (int p = 0; p < trace.peptides.length; p++) {
        for (int i = 0; i < trace.peptides[p].inputs; i++) {
          for (int r = 0; r < trace.vocab.length; r++) {
            double sum = trace.outputBias(c, r);
            for (int d = 0; d < trace.model.width; d++) {
              sum += trace.stream(c, last, p, i, d) * trace.outputWeight(c, r, d);
            }
            expect(trace.logit(c, p, i, r), closeTo(sum, 1e-5));
          }
          // Softmax of the logits over what can come next is the model's own
          // probabilities, as the run kept them to the nearest 255th.
          double top = double.negativeInfinity;
          for (final int id in trace.allowed) {
            top = math.max(top, trace.logit(c, p, i, id));
          }
          double total = 0;
          for (final int id in trace.allowed) {
            total += math.exp(trace.logit(c, p, i, id) - top);
          }
          for (int column = 0; column < trace.allowed.length; column++) {
            final double share = math.exp(trace.logit(c, p, i, trace.allowed[column]) - top) / total;
            expect(trace.probability(c, p, i, column), closeTo(share, 0.5 / 255 + 1e-6));
          }
        }
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
      // The tables and the stream are whole: x0 is their sum, float for float.
      const double tolerance = 1e-5;
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

  test("each block's scores softmax to its map, and each mix is the shares of the values", () {
    for (final TraceCheckpoint c in trace.checkpoints) {
      for (int b = 0; b < trace.model.layers; b++) {
        for (int head = 0; head < trace.model.heads; head++) {
          for (int p = 0; p < trace.peptides.length; p++) {
            for (int q = 0; q < trace.peptides[p].inputs; q++) {
              double top = -double.infinity;
              for (int k = 0; k <= q; k++) {
                top = math.max(top, trace.score(c, b, head, p, q, k));
              }
              final List<double> shares = <double>[
                for (int k = 0; k <= q; k++) math.exp(trace.score(c, b, head, p, q, k) - top),
              ];
              final double sum = shares.reduce((double a, double x) => a + x);
              for (int k = 0; k <= q; k++) {
                expect(shares[k] / sum, closeTo(trace.attention(c, b, head, p, q, k), 0.5 / 255 + 1e-6));
              }
              for (int d = 0; d < trace.headSize; d++) {
                double mix = 0;
                for (int k = 0; k <= q; k++) {
                  mix += shares[k] / sum * trace.value(c, b, head, p, k, d);
                }
                // Whole: the shares of the values, to float32's own rounding.
                expect(trace.mixed(c, b, head, p, q, d), closeTo(mix, 1e-5));
              }
            }
          }
        }
      }
    }
  });

  test("each block's evened row, its queries, keys and values, and each score, add up", () {
    final int width = trace.model.width;
    final int size = trace.headSize;
    for (final TraceCheckpoint c in trace.checkpoints) {
      for (int b = 0; b < trace.model.layers; b++) {
        for (int p = 0; p < trace.peptides.length; p++) {
          for (int i = 0; i < trace.peptides[p].inputs; i++) {
            // The stream before the block, less its mean, over its spread,
            // scaled and shifted: what attention reads.
            final List<double> row = <double>[for (int d = 0; d < width; d++) trace.stream(c, 2 * b, p, i, d)];
            final double mean = row.reduce((double a, double x) => a + x) / width;
            final double spread = math.sqrt(
              row.map((double x) => (x - mean) * (x - mean)).reduce((double a, double x) => a + x) / width + 1e-5,
            );
            for (int d = 0; d < width; d++) {
              expect(
                (row[d] - mean) / spread * trace.normScale(c, b, d) + trace.normShift(c, b, d),
                closeTo(trace.attnInput(c, b, p, i, d), 1e-5),
              );
            }
            // Each query, key and value number: its weights' sum of that row.
            for (int part = 0; part < 3; part++) {
              for (int out = 0; out < width; out++) {
                double sum = trace.projectionBias(c, b, part, out);
                for (int d = 0; d < width; d++) {
                  sum += trace.projection(c, b, part, out, d) * trace.attnInput(c, b, p, i, d);
                }
                final int head = out ~/ size;
                final double kept = <double>[
                  trace.query(c, b, head, p, i, out % size),
                  trace.key(c, b, head, p, i, out % size),
                  trace.value(c, b, head, p, i, out % size),
                ][part];
                expect(sum, closeTo(kept, 1e-5));
              }
            }
            // Each score: the query times a key, number by number, over the
            // root of a head's size.
            for (int head = 0; head < trace.model.heads; head++) {
              for (int k = 0; k <= i; k++) {
                double dot = 0;
                for (int d = 0; d < size; d++) {
                  dot += trace.query(c, b, head, p, i, d) * trace.key(c, b, head, p, k, d);
                }
                expect(dot / math.sqrt(size), closeTo(trace.score(c, b, head, p, i, k), 1e-5));
              }
            }
          }
        }
      }
    }
  });

  test("what attention adds is its output weights' sum of the heads' answers: what the stream gained", () {
    final int width = trace.model.width;
    final int size = trace.headSize;
    for (final TraceCheckpoint c in trace.checkpoints) {
      for (int b = 0; b < trace.model.layers; b++) {
        for (int p = 0; p < trace.peptides.length; p++) {
          for (int i = 0; i < trace.peptides[p].inputs; i++) {
            for (int out = 0; out < width; out++) {
              // The heads' answers side by side, each number times its weight.
              double added = trace.outBias(c, b, out);
              for (int d = 0; d < width; d++) {
                added += trace.outWeight(c, b, out, d) * trace.mixed(c, b, d ~/ size, p, i, d % size);
              }
              final double gained = trace.stream(c, 2 * b + 1, p, i, out) - trace.stream(c, 2 * b, p, i, out);
              expect(added, closeTo(gained, 1e-4));
            }
          }
        }
      }
    }
  });

  test('every neuron is GELU of its input, and the feed-forward adds what the stream gained', () {
    // GELU as torch makes it: x Φ(x). An erf to 1.5e-7 (Abramowitz and Stegun 7.1.26).
    double erf(double x) {
      final double t = 1 / (1 + 0.3275911 * x.abs());
      final double y = 1 -
          (((((1.061405429 * t - 1.453152027) * t) + 1.421413741) * t - 0.284496736) * t + 0.254829592) *
              t *
              math.exp(-x * x);
      return x < 0 ? -y : y;
    }

    double gelu(double x) => 0.5 * x * (1 + erf(x / math.sqrt2));
    final int width = trace.model.width;
    final int ff = trace.model.feedForward;
    for (final TraceCheckpoint c in trace.checkpoints) {
      for (int b = 0; b < trace.model.layers; b++) {
        for (int p = 0; p < trace.peptides.length; p++) {
          for (int i = 0; i < trace.peptides[p].inputs; i++) {
            final List<double> neurons = <double>[
              for (int u = 0; u < ff; u++)
                gelu(
                  <double>[
                        for (int d = 0; d < width; d++) trace.ffIn(c, b, u, d) * trace.ffInput(c, b, p, i, d),
                      ].reduce((double a, double x) => a + x) +
                      trace.ffInBias(c, b, u),
                ),
            ];
            for (int u = 0; u < ff; u++) {
              expect(trace.hidden(c, b, p, i, u), closeTo(neurons[u], c.blocks[b].hiddenScale / 2 + 1e-5));
            }
            for (int d = 0; d < width; d++) {
              double added = trace.ffOutBias(c, b, d);
              for (int u = 0; u < ff; u++) {
                added += trace.ffOut(c, b, d, u) * neurons[u];
              }
              final double gained = trace.stream(c, 2 * b + 2, p, i, d) - trace.stream(c, 2 * b + 1, p, i, d);
              expect(added, closeTo(gained, 1e-4));
            }
          }
        }
      }
    }
  });

  test("the stream read out early sums to one, and at its last point is the model's own", () {
    expect(trace.readouts, trace.points.length - 1);
    for (final TraceCheckpoint c in trace.checkpoints) {
      for (int point = 0; point < trace.readouts; point++) {
        for (int p = 0; p < trace.peptides.length; p++) {
          for (int i = 0; i < trace.peptides[p].inputs; i++) {
            double sum = 0;
            for (int column = 0; column < trace.allowed.length; column++) {
              sum += trace.readout(c, point, p, i, column);
              if (point == trace.readouts - 1) {
                expect(trace.readout(c, point, p, i, column), trace.probability(c, p, i, column));
              }
            }
            expect(sum, closeTo(1, 21 / 255));
          }
        }
      }
    }
  });

  test('a run without its blocks or its readout is refused', () {
    for (final String key in <String>['blocks', 'readout']) {
      final Uint8List bytes = _edited((Map<String, dynamic> json) {
        ((json['checkpoints'] as List<dynamic>).last as Map<String, dynamic>).remove(key);
      });
      expect(() => TrainingTrace.parse(bytes), throwsA(isA<FormatException>()), reason: key);
    }
  });

  test("a run without its attention's output weights is refused", () {
    for (final String key in <String>['attn_out', 'attn_out_bias']) {
      final Uint8List bytes = _edited((Map<String, dynamic> json) {
        final Map<String, dynamic> first = (json['checkpoints'] as List<dynamic>).first as Map<String, dynamic>;
        ((first['blocks'] as List<dynamic>).last as Map<String, dynamic>).remove(key);
      });
      expect(() => TrainingTrace.parse(bytes), throwsA(isA<FormatException>()), reason: key);
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
    for (final int schema in <int>[1, 2, 3, 4, 5]) {
      expect(
        () => TrainingTrace.parse(_edited((Map<String, dynamic> json) => json['schema'] = schema)),
        throwsA(isA<FormatException>()),
      );
    }
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
