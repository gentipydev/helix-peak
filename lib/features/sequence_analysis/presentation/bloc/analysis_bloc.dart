import 'package:bloc/bloc.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/utils/sequence_validator.dart';
import '../../domain/entities/analysis_result.dart';
import '../../domain/entities/sequence_input.dart';
import '../../domain/repositories/sequence_repository.dart';
import 'analysis_event.dart';
import 'analysis_state.dart';

/// Drives the sequence analysis flow.
///
/// Provided once per visit to the `/analyse` route subtree (see the router's
/// `ShellRoute`), so the input and results screens share one instance and the
/// results screen can read a request that was started before it mounted.
final class AnalysisBloc extends Bloc<AnalysisEvent, AnalysisState> {
  AnalysisBloc(this._repository) : super(const AnalysisState.initial()) {
    on<AnalysisRequested>(_onRequested);
    on<AnalysisRetried>(_onRetried);
    on<AnalysisCleared>(_onCleared);
  }

  final SequenceRepository _repository;

  /// The last successfully validated input, kept so [AnalysisRetried] can
  /// re-run without the user retyping and without the UI holding the payload.
  SequenceInput? _lastInput;

  Future<void> _onRequested(
    AnalysisRequested event,
    Emitter<AnalysisState> emit,
  ) async {
    // A double-tap on submit must not start two analyses.
    if (state is AnalysisLoading) {
      return;
    }

    final SequenceValidation validation =
        SequenceValidator.validate(event.rawText);

    switch (validation) {
      case InvalidSequence(:final String message):
        // Validation failures are ordinary results, not exceptions.
        emit(AnalysisState.failure(message));
      case ValidSequence():
        final SequenceInput input = SequenceInput.fromValidated(validation);
        _lastInput = input;
        await _run(input, emit);
    }
  }

  Future<void> _onRetried(
    AnalysisRetried event,
    Emitter<AnalysisState> emit,
  ) async {
    final SequenceInput? input = _lastInput;
    if (input == null || state is AnalysisLoading) {
      return;
    }
    await _run(input, emit);
  }

  void _onCleared(AnalysisCleared event, Emitter<AnalysisState> emit) {
    _lastInput = null;
    emit(const AnalysisState.initial());
  }

  Future<void> _run(SequenceInput input, Emitter<AnalysisState> emit) async {
    emit(const AnalysisState.loading());
    try {
      final AnalysisResult result = await _repository.analyse(input);
      emit(AnalysisState.success(result));
    } on ApiException catch (error) {
      // The exception already carries copy written for a human.
      emit(AnalysisState.failure(error.userMessage));
    } catch (_) {
      // Nothing below the repository is trusted to produce safe copy, and a
      // stack trace must never reach the UI.
      emit(
        const AnalysisState.failure(
          'Something went wrong during analysis. Try again.',
        ),
      );
    }
  }
}
