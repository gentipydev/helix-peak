import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

/// Where a peptide came from: a curated protein, and its record's name for it.
@immutable
final class TraceSource {
  const TraceSource({
    required this.slug,
    required this.gene,
    required this.label,
  });

  final String slug;
  final String gene;

  /// As the record writes it: "insulin A chain", "Copeptin".
  final String label;
}

@immutable
final class TracePeptide {
  const TracePeptide({required this.sequence, required this.sources});

  final String sequence;
  final List<TraceSource> sources;

  /// The positions that predict: `<bos>` and each residue. Each one's target
  /// is the token after it, the last one's `<eos>`.
  int get inputs => sequence.length + 1;

  TraceSource get source => sources.first;
}

/// The model's shape, as the run built it.
@immutable
final class TraceModel {
  const TraceModel({
    required this.width,
    required this.heads,
    required this.layers,
    required this.feedForward,
    required this.context,
    required this.parameters,
  });

  /// `d_model`: how many numbers carry each position.
  final int width;
  final int heads;
  final int layers;
  final int feedForward;

  /// The longest input the model holds, `<bos>` and fifty residues.
  final int context;
  final int parameters;
}

/// What the run was trained with: the engine's own `train.Config`.
@immutable
final class TraceConfig {
  const TraceConfig({
    required this.learningRate,
    required this.weightDecay,
    required this.etaMin,
    required this.warmupSteps,
    required this.gradClip,
    required this.dropout,
    required this.seed,
  });

  final double learningRate;
  final double weightDecay;
  final double etaMin;
  final int warmupSteps;
  final double gradClip;
  final double dropout;
  final int seed;
}

/// What every step kept: its losses and learning rate, its gradients' norms,
/// each target's loss, and the output layer's weights as the step found them.
@immutable
final class TraceSteps {
  const TraceSteps({
    required this.count,
    required this.loss,
    required this.residueLoss,
    required this.eosLoss,
    required this.learningRate,
    required this.gradNorm,
    required this.clip,
    required this.groupGrad,
    required this.groupUpdate,
    required this.targetLoss,
    required this.targetLossScale,
    required this.headWeight,
    required this.headWeightScales,
    required this.headBias,
  });

  final int count;
  final Float32List loss;
  final Float32List residueLoss;
  final Float32List eosLoss;

  /// The rate the step was taken at.
  final Float32List learningRate;

  /// The gradients' norm before clipping, and the factor clipping applied.
  final Float32List gradNorm;
  final Float32List clip;

  /// Each parameter group's gradient norm before clipping, and how far it
  /// moved: `count` × groups.
  final Float32List groupGrad;
  final Float32List groupUpdate;

  /// Each target's loss: `count` × targets, in [targetLossScale] nats.
  final Uint16List targetLoss;
  final double targetLossScale;

  /// The output layer's weights at the start of each step: `count` × vocab ×
  /// width, each step in its own scale.
  final Int8List headWeight;
  final Float64List headWeightScales;
  final Float32List headBias;
}

/// One checkpoint: everything the step computed, kept whole.
@immutable
final class TraceCheckpoint {
  const TraceCheckpoint({
    required this.step,
    required this.why,
    required this.tokenEmbedding,
    required this.positionEmbedding,
    required this.stream,
    required this.streamScales,
    required this.pointGrad,
    required this.attention,
    required this.attentionScale,
    required this.logits,
    required this.logitScale,
    required this.probs,
    required this.probScale,
    required this.headGrad,
    required this.headGradScale,
    required this.headUpdate,
    required this.headUpdateScale,
  });

  final int step;

  /// Why the step was kept whole: `first`, `uniform`, `unigram`, `bigram`,
  /// `one_nat`, `tenth_nat`, `last`.
  final List<String> why;

  /// The embedding tables as the step found them, whole, the ones its `x0`
  /// was made from: a row a token, vocab × width, its padding row zero; and a
  /// row a place, context × width.
  final Float32List tokenEmbedding;
  final Float32List positionEmbedding;

  /// The residual stream at each point: points × targets × width.
  final Int8List stream;
  final Float64List streamScales;

  /// The norm of the loss's gradient reaching each point: points × targets.
  final Float32List pointGrad;

  /// Every head's attention, layers × heads × each peptide's lower triangle.
  final Uint8List attention;
  final double attentionScale;

  /// targets × vocab.
  final Int8List logits;
  final double logitScale;

  /// targets × the tokens that can come next.
  final Uint8List probs;
  final double probScale;

  /// The output layer's gradient, clipped, and the update the step made.
  final Int8List headGrad;
  final double headGradScale;
  final Int8List headUpdate;
  final double headUpdateScale;
}

/// One recorded training run of HelixPeekLM, as `pipeline/denovo/trace.py`
/// wrote it and the service names it (`/peptide-lm/runs/{name}`).
///
/// Every number is the engine's own, kept as the run made it; nothing here is
/// computed but the reading of it. Positions are the run's targets in a row:
/// each peptide's, shortest peptide first, `<bos>` and its residues
/// ([flat]).
@immutable
final class TrainingTrace {
  TrainingTrace._({
    required this.name,
    required this.vocab,
    required this.allowed,
    required this.model,
    required this.config,
    required this.peptides,
    required this.inputs,
    required this.targets,
    required this.uniform,
    required this.unigram,
    required this.bigram,
    required this.floor,
    required this.points,
    required this.groups,
    required this.groupSizes,
    required this.steps,
    required this.checkpoints,
    required this.provenance,
  }) : offsets = _starts(<int>[for (final TracePeptide p in peptides) p.inputs]),
       triangleOffsets = _starts(<int>[
         for (final TracePeptide p in peptides) p.inputs * (p.inputs + 1) ~/ 2,
       ]);

  static const int schema = 2;

  final String name;

  /// The 23 tokens, by id: `<pad>`, `<bos>`, `<eos>` and the twenty.
  final List<String> vocab;

  /// The ids that can come next: every one but `<pad>` and `<bos>`.
  final List<int> allowed;
  final TraceModel model;
  final TraceConfig config;
  final List<TracePeptide> peptides;

  /// The batch as it was trained: each peptide's ids, and the ids it was
  /// trained to predict, padded to the longest.
  final List<List<int>> inputs;
  final List<List<int>> targets;

  /// The loss to beat on these peptides: evenly, by residue counts, and by
  /// the residue before.
  final double uniform;
  final double unigram;
  final double bigram;

  /// The least loss a model reading whole prefixes can reach here.
  final double floor;

  /// The residual stream's points: `x0`, then `m` and `h` for each block, and
  /// `hf` after the final norm.
  final List<String> points;
  final List<String> groups;

  /// How many weights each group holds: its norm over the root of that is
  /// the typical weight's.
  final List<int> groupSizes;
  final TraceSteps steps;
  final List<TraceCheckpoint> checkpoints;
  final Map<String, Object?> provenance;

  final List<int> offsets;
  final List<int> triangleOffsets;

  static List<int> _starts(List<int> sizes) {
    final List<int> starts = <int>[];
    int at = 0;
    for (final int size in sizes) {
      starts.add(at);
      at += size;
    }
    return starts;
  }

  int get targetCount => offsets.last + peptides.last.inputs;

  int get triangle => triangleOffsets.last +
      peptides.last.inputs * (peptides.last.inputs + 1) ~/ 2;

  int get residues => peptides.fold<int>(
    0,
    (int sum, TracePeptide p) => sum + p.sequence.length,
  );

  /// The batch's width: the longest peptide, framed and cut once.
  int get width => inputs.first.length;

  int get pads => peptides.length * (width + 1) - (residues + 2 * peptides.length);

  int flat(int peptide, int position) => offsets[peptide] + position;

  int inputAt(int peptide, int position) => inputs[peptide][position];

  int targetAt(int peptide, int position) => targets[peptide][position];

  /// [token]'s column among [allowed], or -1 for one that cannot come next.
  int allowedIndex(int token) => allowed.indexOf(token);

  /// The token's one-letter name: the residue, or `<bos>`, `<eos>`, `<pad>`.
  String token(int id) => vocab[id];

  bool isResidue(int id) => vocab[id].length == 1;

  // Every step.

  double loss(int step) => steps.loss[step - 1];

  double targetLoss(int step, int peptide, int position) =>
      steps.targetLoss[(step - 1) * targetCount + flat(peptide, position)] *
      steps.targetLossScale;

  double headWeight(int step, int row, int dim) =>
      steps.headWeight[((step - 1) * vocab.length + row) * model.width + dim] *
      steps.headWeightScales[step - 1];

  double headBias(int step, int row) =>
      steps.headBias[(step - 1) * vocab.length + row];

  double groupGrad(int step, int group) =>
      steps.groupGrad[(step - 1) * groups.length + group];

  double groupUpdate(int step, int group) =>
      steps.groupUpdate[(step - 1) * groups.length + group];

  // At a checkpoint.

  /// Token [id]'s embedding row, at [dim].
  double tokenEmbedding(TraceCheckpoint at, int id, int dim) => at.tokenEmbedding[id * model.width + dim];

  /// Place [place]'s row of the position embedding, at [dim].
  double positionEmbedding(TraceCheckpoint at, int place, int dim) =>
      at.positionEmbedding[place * model.width + dim];

  double stream(TraceCheckpoint at, int point, int peptide, int position, int dim) =>
      at.stream[(point * targetCount + flat(peptide, position)) * model.width + dim] *
      at.streamScales[point];

  double pointGrad(TraceCheckpoint at, int point, int peptide, int position) =>
      at.pointGrad[point * targetCount + flat(peptide, position)];

  double attention(
    TraceCheckpoint at,
    int layer,
    int head,
    int peptide,
    int query,
    int key,
  ) =>
      at.attention[(layer * model.heads + head) * triangle +
              triangleOffsets[peptide] +
              query * (query + 1) ~/ 2 +
              key] *
      at.attentionScale;

  /// Attention averaged over the layer's heads.
  double meanAttention(TraceCheckpoint at, int layer, int peptide, int query, int key) {
    double sum = 0;
    for (int head = 0; head < model.heads; head++) {
      sum += attention(at, layer, head, peptide, query, key);
    }
    return sum / model.heads;
  }

  double logit(TraceCheckpoint at, int peptide, int position, int token) =>
      at.logits[flat(peptide, position) * vocab.length + token] * at.logitScale;

  /// The probability given to the [column]th token of [allowed].
  double probability(TraceCheckpoint at, int peptide, int position, int column) =>
      at.probs[flat(peptide, position) * allowed.length + column] * at.probScale;

  double headGrad(TraceCheckpoint at, int row, int dim) =>
      at.headGrad[row * model.width + dim] * at.headGradScale;

  double headUpdate(TraceCheckpoint at, int row, int dim) =>
      at.headUpdate[row * model.width + dim] * at.headUpdateScale;

  /// The run read from [bytes], or a [FormatException] saying why it cannot
  /// be: another run than [name], another schema, or an array whose shape is
  /// not the run's.
  static TrainingTrace parse(Uint8List bytes, {String? name}) {
    final Object? decoded = jsonDecode(utf8.decode(bytes));
    final Map<String, Object?> json = _object(decoded, 'the run');
    if (json['schema'] != schema) {
      throw const FormatException('Not a schema $schema training run');
    }
    final String run = _string(json, 'name');
    if (name != null && run != name) {
      throw FormatException('The run is "$run", not "$name"');
    }
    final List<String> vocab = <String>[
      for (final Object? token in _list(json, 'vocab')) token is String
          ? token
          : throw const FormatException('A token is not a string'),
    ];
    final List<int> allowed = _ints(json['allowed'], 'allowed');

    final Map<String, Object?> shape = _object(json['model'], 'the model');
    final TraceModel model = TraceModel(
      width: _int(shape, 'd_model'),
      heads: _int(shape, 'nhead'),
      layers: _int(shape, 'num_layers'),
      feedForward: _int(shape, 'dim_feedforward'),
      context: _int(shape, 'max_len'),
      parameters: _int(shape, 'parameters'),
    );
    final Map<String, Object?> settings = _object(json['config'], 'the config');
    final TraceConfig config = TraceConfig(
      learningRate: _double(settings, 'learning_rate'),
      weightDecay: _double(settings, 'weight_decay'),
      etaMin: _double(settings, 'eta_min'),
      warmupSteps: _int(settings, 'warmup_steps'),
      gradClip: _double(settings, 'grad_clip'),
      dropout: _double(settings, 'dropout'),
      seed: _int(settings, 'seed'),
    );

    final List<TracePeptide> peptides = <TracePeptide>[
      for (final Object? entry in _list(json, 'peptides'))
        _peptide(_object(entry, 'a peptide')),
    ];
    if (peptides.isEmpty) {
      throw const FormatException('The run names no peptide');
    }
    final Map<String, Object?> batch = _object(json['batch'], 'the batch');
    final List<List<int>> inputs = <List<int>>[
      for (final Object? row in _list(batch, 'x')) _ints(row, 'an input row'),
    ];
    final List<List<int>> targets = <List<int>>[
      for (final Object? row in _list(batch, 'y')) _ints(row, 'a target row'),
    ];
    final int longest = peptides.last.inputs;
    if (inputs.length != peptides.length ||
        targets.length != peptides.length ||
        inputs.any((List<int> row) => row.length < longest) ||
        targets.any((List<int> row) => row.length != inputs.first.length)) {
      throw const FormatException('The batch does not hold one row a peptide');
    }

    final Map<String, Object?> reference = _object(json['baselines'], 'baselines');
    final List<String> points = _strings(json['points'], 'points');
    final List<String> groups = _strings(json['groups'], 'groups');
    if (points.length != 2 * model.layers + 2) {
      throw const FormatException('The stream points do not fit the layers');
    }
    final List<int> groupSizes = _ints(json['group_sizes'], 'group_sizes');
    if (groupSizes.length != groups.length) {
      throw const FormatException('Not one size a parameter group');
    }

    final int targetCount = peptides.fold<int>(
      0,
      (int sum, TracePeptide p) => sum + p.inputs,
    );
    if (_int(json, 'targets') != targetCount) {
      throw const FormatException('The run counts another number of targets');
    }
    final int triangle = peptides.fold<int>(
      0,
      (int sum, TracePeptide p) => sum + p.inputs * (p.inputs + 1) ~/ 2,
    );

    final Map<String, Object?> stepJson = _object(json['steps'], 'the steps');
    final int count = _int(stepJson, 'count');
    if (count < 1) {
      throw const FormatException('The run took no step');
    }
    final Map<String, Object?> headSpec = _object(stepJson['head_weight'], 'head_weight');
    final TraceSteps steps = TraceSteps(
      count: count,
      loss: _float32(stepJson['loss'], <int>[count], 'loss'),
      residueLoss: _float32(stepJson['residue_loss'], <int>[count], 'residue_loss'),
      eosLoss: _float32(stepJson['eos_loss'], <int>[count], 'eos_loss'),
      learningRate: _float32(stepJson['lr'], <int>[count], 'lr'),
      gradNorm: _float32(stepJson['grad_norm'], <int>[count], 'grad_norm'),
      clip: _float32(stepJson['clip'], <int>[count], 'clip'),
      groupGrad: _float32(stepJson['group_grad'], <int>[count, groups.length], 'group_grad'),
      groupUpdate: _float32(
        stepJson['group_update'],
        <int>[count, groups.length],
        'group_update',
      ),
      targetLoss: _uint16(
        stepJson['token_loss'],
        <int>[count, targetCount],
        'token_loss',
      ),
      targetLossScale: _scale(stepJson['token_loss'], 'token_loss'),
      headWeight: _int8(headSpec, <int>[count, vocab.length, model.width], 'head_weight'),
      headWeightScales: _scales(headSpec, count, 'head_weight'),
      headBias: _float32(stepJson['head_bias'], <int>[count, vocab.length], 'head_bias'),
    );

    final List<TraceCheckpoint> checkpoints = <TraceCheckpoint>[];
    for (final Object? entry in _list(json, 'checkpoints')) {
      final Map<String, Object?> c = _object(entry, 'a checkpoint');
      final int step = _int(c, 'step');
      if (step < 1 || step > count ||
          (checkpoints.isNotEmpty && step <= checkpoints.last.step)) {
        throw FormatException('Checkpoint $step is out of order');
      }
      final String what = 'step $step';
      final Map<String, Object?> stream = _object(c['points'], '$what points');
      checkpoints.add(
        TraceCheckpoint(
          step: step,
          why: _strings(c['why'], '$what why'),
          tokenEmbedding: _float32(
            c['token_embedding'],
            <int>[vocab.length, model.width],
            '$what token_embedding',
          ),
          positionEmbedding: _float32(
            c['position_embedding'],
            <int>[model.context, model.width],
            '$what position_embedding',
          ),
          stream: _int8(stream, <int>[points.length, targetCount, model.width], '$what points'),
          streamScales: _scales(stream, points.length, '$what points'),
          pointGrad: _float32(c['point_grad'], <int>[points.length, targetCount], '$what grad'),
          attention: _uint8(
            c['attention'],
            <int>[model.layers, model.heads, triangle],
            '$what attention',
          ),
          attentionScale: _scale(c['attention'], '$what attention'),
          logits: _int8(c['logits'], <int>[targetCount, vocab.length], '$what logits'),
          logitScale: _scale(c['logits'], '$what logits'),
          probs: _uint8(c['probs'], <int>[targetCount, allowed.length], '$what probs'),
          probScale: _scale(c['probs'], '$what probs'),
          headGrad: _int8(c['head_grad'], <int>[vocab.length, model.width], '$what head_grad'),
          headGradScale: _scale(c['head_grad'], '$what head_grad'),
          headUpdate: _int8(
            c['head_update'],
            <int>[vocab.length, model.width],
            '$what head_update',
          ),
          headUpdateScale: _scale(c['head_update'], '$what head_update'),
        ),
      );
    }
    if (checkpoints.isEmpty || checkpoints.first.step != 1 || checkpoints.last.step != count) {
      throw const FormatException('The checkpoints do not run from the first step to the last');
    }

    return TrainingTrace._(
      name: run,
      vocab: List<String>.unmodifiable(vocab),
      allowed: List<int>.unmodifiable(allowed),
      model: model,
      config: config,
      peptides: List<TracePeptide>.unmodifiable(peptides),
      inputs: List<List<int>>.unmodifiable(inputs),
      targets: List<List<int>>.unmodifiable(targets),
      uniform: _double(reference, 'uniform'),
      unigram: _double(reference, 'unigram'),
      bigram: _double(reference, 'bigram'),
      floor: _double(json, 'floor'),
      points: List<String>.unmodifiable(points),
      groups: List<String>.unmodifiable(groups),
      groupSizes: List<int>.unmodifiable(groupSizes),
      steps: steps,
      checkpoints: List<TraceCheckpoint>.unmodifiable(checkpoints),
      provenance: Map<String, Object?>.unmodifiable(
        _object(json['provenance'], 'provenance'),
      ),
    );
  }

  static TracePeptide _peptide(Map<String, Object?> json) => TracePeptide(
    sequence: _string(json, 'sequence'),
    sources: <TraceSource>[
      for (final Object? entry in _list(json, 'sources'))
        TraceSource(
          slug: _string(_object(entry, 'a source'), 'slug'),
          gene: _string(_object(entry, 'a source'), 'gene'),
          label: _string(_object(entry, 'a source'), 'label'),
        ),
    ],
  );
}

Map<String, Object?> _object(Object? value, String what) {
  if (value is Map<String, Object?>) {
    return value;
  }
  throw FormatException('$what is not an object');
}

List<Object?> _list(Map<String, Object?> json, String key) {
  final Object? value = json[key];
  if (value is List<Object?>) {
    return value;
  }
  throw FormatException('$key is not a list');
}

String _string(Map<String, Object?> json, String key) {
  final Object? value = json[key];
  if (value is String) {
    return value;
  }
  throw FormatException('$key is not a string');
}

int _int(Map<String, Object?> json, String key) {
  final Object? value = json[key];
  if (value is int) {
    return value;
  }
  throw FormatException('$key is not a whole number');
}

double _double(Map<String, Object?> json, String key) {
  final Object? value = json[key];
  if (value is num) {
    return value.toDouble();
  }
  throw FormatException('$key is not a number');
}

List<int> _ints(Object? value, String what) {
  if (value is List<Object?> && value.every((Object? v) => v is int)) {
    return value.cast<int>().toList(growable: false);
  }
  throw FormatException('$what is not a list of whole numbers');
}

List<String> _strings(Object? value, String what) {
  if (value is List<Object?> && value.every((Object? v) => v is String)) {
    return value.cast<String>().toList(growable: false);
  }
  throw FormatException('$what is not a list of names');
}

double _scale(Object? spec, String what) {
  final Object? value = _object(spec, what)['scale'];
  if (value is num && value > 0) {
    return value.toDouble();
  }
  throw FormatException('$what has no scale');
}

Float64List _scales(Map<String, Object?> spec, int count, String what) {
  final Object? value = spec['scales'];
  if (value is List<Object?> &&
      value.length == count &&
      value.every((Object? v) => v is num && v > 0)) {
    return Float64List.fromList(<double>[
      for (final Object? v in value) (v! as num).toDouble(),
    ]);
  }
  throw FormatException('$what needs $count scales');
}

const Map<String, int> _sizes = <String, int>{'i1': 1, 'u1': 1, 'u2': 2, 'f4': 4};

/// An array's bytes, as stored: checked to be [dtype] and [shape], whole.
Uint8List _raw(Object? spec, String dtype, List<int> shape, String what) {
  final Map<String, Object?> json = _object(spec, what);
  if (json['dtype'] != dtype) {
    throw FormatException('$what is not $dtype');
  }
  final List<int> declared = _ints(json['shape'], '$what shape');
  if (!listEquals(declared, shape)) {
    throw FormatException('$what is shaped $declared, not $shape');
  }
  final Uint8List raw = base64Decode(_string(json, 'data'));
  final int count = shape.fold<int>(1, (int a, int b) => a * b);
  if (raw.length != count * _sizes[dtype]!) {
    throw FormatException('$what holds ${raw.length} bytes, not ${count * _sizes[dtype]!}');
  }
  return raw;
}

Uint8List _uint8(Object? spec, List<int> shape, String what) =>
    _raw(spec, 'u1', shape, what);

Int8List _int8(Object? spec, List<int> shape, String what) =>
    Int8List.sublistView(_raw(spec, 'i1', shape, what));

// Stored little-endian. A fresh decode starts at offset 0, so a view lines up.
Uint16List _uint16(Object? spec, List<int> shape, String what) {
  final Uint8List raw = _raw(spec, 'u2', shape, what);
  if (Endian.host == Endian.little) {
    return Uint16List.sublistView(raw);
  }
  final ByteData data = ByteData.sublistView(raw);
  return Uint16List.fromList(<int>[
    for (int i = 0; i < raw.length; i += 2) data.getUint16(i, Endian.little),
  ]);
}

Float32List _float32(Object? spec, List<int> shape, String what) {
  final Uint8List raw = _raw(spec, 'f4', shape, what);
  if (Endian.host == Endian.little) {
    return Float32List.sublistView(raw);
  }
  final ByteData data = ByteData.sublistView(raw);
  return Float32List.fromList(<double>[
    for (int i = 0; i < raw.length; i += 4) data.getFloat32(i, Endian.little),
  ]);
}
