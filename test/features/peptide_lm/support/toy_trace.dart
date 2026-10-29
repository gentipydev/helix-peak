import 'dart:io';
import 'dart:typed_data';

import 'package:helixpeek/features/peptide_lm/domain/training_trace.dart';

/// A run of `pipeline/denovo/trace.py --toy`: the recorder's own output, a
/// two-layer model of width eight on two short peptides, twenty steps.
Uint8List toyBytes() =>
    File('test/features/peptide_lm/support/toy_trace.json').readAsBytesSync();

TrainingTrace toyTrace() => TrainingTrace.parse(toyBytes(), name: 'toy');
