import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/catalog/protein_target.dart';
import '../../../../core/catalog/protein_track.dart';
import '../../../../core/evidence/protein_constraint.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/network/track_source.dart';
import '../domain/route_evidence.dart';
import '../domain/trafficking_route.dart';
import '../domain/trafficking_track.dart';

sealed class CellSceneState {
  const CellSceneState();
}

final class CellSceneLoading extends CellSceneState {
  const CellSceneLoading();
}

/// No region table to read a route from: a protein with no constraint track.
/// A state the scene draws, not a failure.
final class CellSceneUnavailable extends CellSceneState {
  const CellSceneUnavailable();
}

final class CellSceneFailed extends CellSceneState {
  const CellSceneFailed(this.message);

  final String message;
}

final class CellSceneReady extends CellSceneState {
  const CellSceneReady(this.route, {this.topology});

  final TraffickingRoute route;

  /// The trafficking track the route's topology came from, or null where the
  /// row does not say it is ready. The route then has none.
  final TraffickingTrack? topology;
}

/// One protein's route, from the two tracks it is derived from: the region
/// table in the constraint track, and the trafficking track's topology where
/// it is ready. A track that is not ready is a state; a ready one that cannot
/// be read is a failure.
class CellSceneCubit extends Cubit<CellSceneState> {
  CellSceneCubit(this.target, this._tracks) : super(const CellSceneLoading());

  final ProteinTarget target;
  final TrackSource _tracks;

  Future<void> load() async {
    if (!target.scored) {
      emit(const CellSceneUnavailable());
      return;
    }
    emit(const CellSceneLoading());
    try {
      final ProteinConstraint constraint = await ProteinConstraint.load(
        target,
        tracks: _tracks,
      );
      final TraffickingTrack? topology =
          target.state(TrackKind.trafficking) == TrackState.ready
          ? await TraffickingTrack.load(target, tracks: _tracks)
          : null;
      final TraffickingRoute route = TraffickingRoute.derive(
        RouteEvidence.of(constraint, transmembrane: topology?.transmembrane),
      );
      if (!isClosed) {
        emit(CellSceneReady(route, topology: topology));
      }
    } on ApiException catch (error) {
      if (!isClosed) {
        emit(CellSceneFailed(error.userMessage));
      }
    } on Object {
      if (!isClosed) {
        emit(CellSceneFailed(const UnknownApiException().userMessage));
      }
    }
  }
}
