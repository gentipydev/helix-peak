import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/core/catalog/protein_track.dart';
import 'package:helixpeek/features/lab/folding/presentation/fold_cubit.dart';

import '../../../../shared/folding/folding_fixtures.dart';
import '../../../../support/test_catalog.dart';

void main() {
  test('a ready track is the fold, with the catalog’s bridges', () async {
    final FoldCubit cubit = FoldCubit(
      withFolding(TestCatalog.insulin, TrackState.ready),
      FoldTrackSource(),
    );
    addTearDown(cubit.close);
    await cubit.load();
    final FoldState state = cubit.state;
    expect(state, isA<FoldReady>());
    expect((state as FoldReady).geometry.bridgeNumbers, hasLength(3));
  });

  test(
    'a track the row does not call ready is a state, in its own words',
    () async {
      for (final (TrackState state, String? reason) in <(TrackState, String?)>[
        (TrackState.absent, null),
        (TrackState.pending, null),
        (TrackState.refused, 'no structure covers it'),
      ]) {
        final FoldCubit cubit = FoldCubit(
          withFolding(target('prion'), state, reason: reason),
          FoldTrackSource(),
        );
        await cubit.load();
        final FoldState now = cubit.state;
        expect(now, isA<FoldUnavailable>(), reason: '$state');
        expect((now as FoldUnavailable).state, state);
        expect(now.reason, reason);
        await cubit.close();
      }
    },
  );

  test('a ready track that cannot be read is a failure', () async {
    final FoldCubit cubit = FoldCubit(
      withFolding(target('prion'), TrackState.ready),
      FoldTrackSource(failing: <TrackKind>{TrackKind.folding}),
    );
    addTearDown(cubit.close);
    await cubit.load();
    expect(cubit.state, isA<FoldFailed>());
  });
}
