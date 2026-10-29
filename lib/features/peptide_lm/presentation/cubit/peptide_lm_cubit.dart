import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/training_run_repository.dart';
import '../../domain/training_trace.dart';

sealed class PeptideLmState {
  const PeptideLmState();
}

final class PeptideLmLoading extends PeptideLmState {
  const PeptideLmLoading();
}

final class PeptideLmReady extends PeptideLmState {
  const PeptideLmReady(this.trace);

  final TrainingTrace trace;
}

final class PeptideLmFailed extends PeptideLmState {
  const PeptideLmFailed(this.error);

  final Object error;
}

/// The recorded run, asked for once a visit, and again on Retry.
class PeptideLmCubit extends Cubit<PeptideLmState> {
  PeptideLmCubit(this._repository) : super(const PeptideLmLoading());

  final TrainingRunRepository _repository;

  Future<void> load() async {
    emit(const PeptideLmLoading());
    try {
      final TrainingTrace trace = await _repository.load();
      if (!isClosed) {
        emit(PeptideLmReady(trace));
      }
    } on Object catch (error) {
      if (!isClosed) {
        emit(PeptideLmFailed(error));
      }
    }
  }
}
