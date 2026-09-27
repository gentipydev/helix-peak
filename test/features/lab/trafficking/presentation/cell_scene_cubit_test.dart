import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/core/catalog/protein_target.dart';
import 'package:helixpeek/core/catalog/protein_track.dart';
import 'package:helixpeek/features/lab/trafficking/domain/trafficking_route.dart';
import 'package:helixpeek/features/lab/trafficking/presentation/cell_scene_cubit.dart';

import '../../../../support/test_catalog.dart';
import '../trafficking_fixtures.dart';

Future<CellSceneState> _load(
  ProteinTarget target, {
  Set<TrackKind> failing = const <TrackKind>{},
}) async {
  final CellSceneCubit cubit = CellSceneCubit(
    target,
    SceneTrackSource(failing: failing),
  );
  await cubit.load();
  final CellSceneState state = cubit.state;
  await cubit.close();
  return state;
}

void main() {
  test(
    'with the trafficking track ready, the route has its topology',
    () async {
      final CellSceneState state = await _load(
        withTrafficking(TestCatalog.cftr, TrackState.ready),
      );
      expect(state, isA<CellSceneReady>());
      final CellSceneReady ready = state as CellSceneReady;
      expect(ready.topology?.release, '2026_03');
      expect(ready.route.resolved, isTrue);
      expect(ready.route.destination, Compartment.membrane);
    },
  );

  test('with no trafficking row, the route has none, and says so', () async {
    // The catalog fixture names no trafficking track: absent, as every
    // protein is until the track is uploaded.
    expect(TestCatalog.insulin.state(TrackKind.trafficking), TrackState.absent);
    final CellSceneState state = await _load(TestCatalog.insulin);
    final CellSceneReady ready = state as CellSceneReady;
    expect(ready.topology, isNull);
    expect(ready.route.unresolved, Unresolved.topology);
  });

  test('a pending track is waited for, not read', () async {
    final CellSceneState state = await _load(
      withTrafficking(TestCatalog.tnf, TrackState.pending),
      failing: <TrackKind>{TrackKind.trafficking},
    );
    expect((state as CellSceneReady).topology, isNull);
  });

  test('a ready track that cannot be read is a failure', () async {
    final CellSceneState state = await _load(
      withTrafficking(TestCatalog.tnf, TrackState.ready),
      failing: <TrackKind>{TrackKind.trafficking},
    );
    expect(state, isA<CellSceneFailed>());
  });

  test('a protein with no region table has no route to draw', () async {
    final CellSceneState state = await _load(
      withTrafficking(TestCatalog.sod1, TrackState.ready, scored: false),
    );
    expect(state, isA<CellSceneUnavailable>());
  });
}
