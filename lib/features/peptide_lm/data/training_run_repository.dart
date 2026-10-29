import 'package:flutter/foundation.dart';

import '../domain/training_trace.dart';

/// Reads the bytes a service row names (`TrackClient.readRow`).
typedef RowReader = Future<Uint8List> Function(String path);

/// The recorded training run the page plays: its row from the service, its
/// bytes from storage (kept by digest, as a track's are), read off the main
/// isolate.
final class TrainingRunRepository {
  TrainingRunRepository(this._readRow, {this.run = curated});

  /// The run of the curated proteins' peptides.
  static const String curated = 'curated';

  final RowReader _readRow;

  /// Which run to read; a payload naming another is refused.
  final String run;

  Future<TrainingTrace> load() async {
    final Uint8List bytes = await _readRow('/peptide-lm/runs/$run');
    return compute(_parse, (bytes, run));
  }
}

TrainingTrace _parse((Uint8List, String) asked) =>
    TrainingTrace.parse(asked.$1, name: asked.$2);
