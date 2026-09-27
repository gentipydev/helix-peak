import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/catalog/protein_target.dart';
import '../../../../core/catalog/protein_track.dart';
import '../../../../core/evidence/protein_constraint.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/network/track_source.dart';
import '../domain/fold_geometry.dart';
import '../domain/folding_track.dart';

sealed class FoldState {
  const FoldState();
}

final class FoldLoading extends FoldState {
  const FoldLoading();
}

/// The row does not say the `folding` track is ready: a state the screen
/// draws, in the row's own words, not a failure.
final class FoldUnavailable extends FoldState {
  const FoldUnavailable(this.state, {this.reason});

  final TrackState state;
  final String? reason;
}

final class FoldFailed extends FoldState {
  const FoldFailed(this.message);

  final String message;
}

final class FoldReady extends FoldState {
  const FoldReady(this.geometry);

  final FoldGeometry geometry;
}

/// One protein's fold, from its `folding` track, with the disulfide pairs
/// the catalog gives it (carried by the constraint track, as the walk reads
/// them). A track that is not ready is a state; a ready one that cannot be
/// read is a failure.
class FoldCubit extends Cubit<FoldState> {
  FoldCubit(this.target, this._tracks) : super(const FoldLoading());

  final ProteinTarget target;
  final TrackSource _tracks;

  Future<void> load() async {
    const TrackKind kind = TrackKind.folding;
    final TrackState state = target.state(kind);
    if (state != TrackState.ready) {
      emit(FoldUnavailable(state, reason: target.reason(kind)));
      return;
    }
    emit(const FoldLoading());
    try {
      final FoldingTrack track = await FoldingTrack.load(
        target,
        tracks: _tracks,
      );
      final List<(int, int)> bridges = target.scored
          ? (await ProteinConstraint.load(target, tracks: _tracks)).bridges
          : const <(int, int)>[];
      if (!isClosed) {
        emit(FoldReady(FoldGeometry.of(track, bridges: bridges)));
      }
    } on ApiException catch (error) {
      if (!isClosed) {
        emit(FoldFailed(error.userMessage));
      }
    } on Object {
      if (!isClosed) {
        emit(FoldFailed(const UnknownApiException().userMessage));
      }
    }
  }
}
