import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/features/peptide_lm/data/training_run_repository.dart';
import 'package:helixpeek/features/peptide_lm/domain/training_trace.dart';

import 'support/toy_trace.dart';

void main() {
  test('the run is asked for by name, and read whole', () async {
    final List<String> asked = <String>[];
    final TrainingTrace trace = await TrainingRunRepository(
      (String path) async {
        asked.add(path);
        return toyBytes();
      },
      run: 'toy',
    ).load();
    expect(asked, <String>['/peptide-lm/runs/toy']);
    expect(trace.name, 'toy');
    expect(trace.steps.count, 20);
  });

  test('the page asks for the curated proteins’ run', () async {
    final List<String> asked = <String>[];
    await expectLater(
      TrainingRunRepository((String path) async {
        asked.add(path);
        return toyBytes();
      }).load(),
      // The toy's bytes name another run, and are refused.
      throwsA(isA<FormatException>()),
    );
    expect(asked, <String>['/peptide-lm/runs/${TrainingRunRepository.curated}']);
  });

  test('bytes that are no run are refused', () async {
    await expectLater(
      TrainingRunRepository(
        (String path) async => Uint8List.fromList('{"schema":1}'.codeUnits),
        run: 'toy',
      ).load(),
      throwsA(isA<FormatException>()),
    );
  });
}
