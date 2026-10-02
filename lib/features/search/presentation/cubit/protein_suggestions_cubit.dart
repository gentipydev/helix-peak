import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/catalog/protein_resolver.dart';
import '../../../../core/catalog/protein_suggestion.dart';
import '../../../../core/network/api_exception.dart';

sealed class SuggestionsState {
  const SuggestionsState();
}

/// Nothing asked: the query is too short to mean anything yet.
final class SuggestionsIdle extends SuggestionsState {
  const SuggestionsIdle();
}

/// Asking about [query]. [previous] stays on screen meanwhile, so the list
/// does not empty and refill under the reader at every key.
final class SuggestionsLoading extends SuggestionsState {
  const SuggestionsLoading(this.query, {this.previous});

  final String query;
  final SuggestionPage? previous;
}

final class SuggestionsShown extends SuggestionsState {
  const SuggestionsShown(this.page);

  final SuggestionPage page;
}

final class SuggestionsFailed extends SuggestionsState {
  const SuggestionsFailed(this.query, this.message);

  final String query;
  final String message;
}

/// Every reviewed human protein a query might mean, asked of the service as
/// the reader types: once they pause, and never answered out of order.
class ProteinSuggestionsCubit extends Cubit<SuggestionsState> {
  ProteinSuggestionsCubit(
    this._resolver, {
    this.pause = const Duration(milliseconds: 300),
  }) : super(const SuggestionsIdle());

  /// Shorter than this, a query names too much of the index to be worth
  /// asking about.
  static const int shortest = 2;

  final ProteinResolver _resolver;

  /// How long typing has to stop before the service is asked.
  final Duration pause;

  Timer? _pending;

  /// Counts asks, so an answer to an older one is dropped: "ins" answered
  /// after "insulin" must not replace it.
  int _asked = 0;

  void query(String text) {
    _pending?.cancel();
    final String needle = text.trim();
    final int asked = ++_asked;
    if (needle.length < shortest) {
      emit(const SuggestionsIdle());
      return;
    }
    _loading(needle);
    _pending = Timer(pause, () => unawaited(_fetch(needle, asked)));
  }

  /// Ask again, at once, about the query that failed.
  void retry() {
    final SuggestionsState now = state;
    if (now is! SuggestionsFailed) {
      return;
    }
    _pending?.cancel();
    final int asked = ++_asked;
    _loading(now.query);
    unawaited(_fetch(now.query, asked));
  }

  void _loading(String needle) {
    final SuggestionsState now = state;
    emit(
      SuggestionsLoading(
        needle,
        previous: switch (now) {
          SuggestionsShown(:final SuggestionPage page) => page,
          SuggestionsLoading(:final SuggestionPage? previous) => previous,
          _ => null,
        },
      ),
    );
  }

  Future<void> _fetch(String needle, int asked) async {
    try {
      final SuggestionPage page = await _resolver.suggest(needle);
      if (!isClosed && asked == _asked) {
        emit(SuggestionsShown(page));
      }
    } on ApiException catch (error) {
      if (!isClosed && asked == _asked) {
        emit(SuggestionsFailed(needle, error.userMessage));
      }
    } on Object {
      if (!isClosed && asked == _asked) {
        emit(
          SuggestionsFailed(needle, const UnknownApiException().userMessage),
        );
      }
    }
  }

  @override
  Future<void> close() {
    _pending?.cancel();
    return super.close();
  }
}
