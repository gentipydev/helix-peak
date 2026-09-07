import 'package:bloc/bloc.dart';

import '../../../../core/network/api_exception.dart';
import '../../domain/entities/analysis_result.dart';
import '../../domain/entities/sequence_input.dart';
import '../../domain/usecases/analyse_sequence.dart';
import 'analysis_event.dart';
import 'analysis_state.dart';

final class AnalysisBloc extends Bloc<AnalysisEvent, AnalysisState> {
  AnalysisBloc(this._analyseSequence) : super(const AnalysisState.initial()) {
    on<AnalysisRequested>(_onRequested);
    on<AnalysisRetried>(_onRetried);
    on<AnalysisCleared>(_onCleared);
  }

  final AnalyseSequence _analyseSequence;

  SequenceInput? _lastInput;

  Future<void> _onRequested(
    AnalysisRequested event,
    Emitter<AnalysisState> emit,
  ) async {
    if (state is AnalysisLoading) {
      return;
    }

    final SequenceInput input = SequenceInput(rawText: event.rawText);
    _lastInput = input;
    await _run(input, emit);
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
      final AnalysisResult result = await _analyseSequence(input);
      emit(AnalysisState.success(result));
    } on ApiException catch (error) {
      emit(AnalysisState.failure(error.userMessage));
    } catch (_) {
      emit(
        const AnalysisState.failure(
          'Something went wrong during analysis. Try again.',
        ),
      );
    }
  }
}
