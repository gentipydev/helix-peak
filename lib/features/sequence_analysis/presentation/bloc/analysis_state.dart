import 'package:freezed_annotation/freezed_annotation.dart';

import '../../domain/entities/analysis_result.dart';

part 'analysis_state.freezed.dart';

/// The analysis feature's state, as a sealed union.
///
/// ## This is the project's loading/error/data convention
///
/// Riverpod's `AsyncValue` has no direct counterpart in bloc, so this union is
/// the established equivalent, and every feature added later should follow its
/// shape: `initial` / `loading` / `success` / `failure`, rendered with
/// `BlocBuilder` and an exhaustive `switch` expression.
///
/// The union is `sealed`, which buys something `AsyncValue.when` cannot: if a
/// fifth state is ever added, every `switch` that fails to handle it becomes a
/// **compile error** rather than a runtime surprise. Exhaustiveness is enforced
/// by the language, not by an API contract.
///
/// Note what is deliberately absent: no `isLoading` or `hasError` booleans.
/// Flags permit impossible combinations; a union does not.
@freezed
sealed class AnalysisState with _$AnalysisState {
  /// Nothing submitted yet — also where a cold deep-link to the results route
  /// lands, which is why it renders a real empty state rather than a blank.
  const factory AnalysisState.initial() = AnalysisInitial;

  const factory AnalysisState.loading() = AnalysisLoading;

  const factory AnalysisState.success(AnalysisResult result) = AnalysisSuccess;

  /// [message] is always user-facing copy, never an exception's `toString()`.
  const factory AnalysisState.failure(String message) = AnalysisFailure;
}
