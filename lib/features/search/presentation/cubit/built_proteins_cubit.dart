import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/catalog/protein_builds.dart';
import '../../../../core/catalog/protein_resolver.dart';
import '../../../../core/catalog/protein_suggestion.dart';
import '../../../../core/network/api_exception.dart';

sealed class BuiltState {
  const BuiltState();
}

/// Nothing asked: the list has not been looked at yet.
final class BuiltIdle extends BuiltState {
  const BuiltIdle();
}

/// Asking. [previous] stays on screen meanwhile, so the list does not empty
/// and refill each time it is looked at.
final class BuiltLoading extends BuiltState {
  const BuiltLoading({this.previous});

  final BuiltPage? previous;
}

final class BuiltShown extends BuiltState {
  const BuiltShown(this.page);

  final BuiltPage page;
}

final class BuiltFailed extends BuiltState {
  const BuiltFailed(this.message);

  final String message;
}

/// The service is older than the list: it answered 404.
final class BuiltNotListed extends BuiltState {
  const BuiltNotListed();
}

/// The proteins built on demand, every install's, asked of the service each
/// time they are looked at, and again whenever a build of this phone's ends
/// with a protein to open, so one built just now is among them.
class BuiltProteinsCubit extends Cubit<BuiltState> {
  BuiltProteinsCubit(this._resolver, {Stream<ProteinBuild>? ended})
    : super(const BuiltIdle()) {
    _ended = ended?.listen(_endedOne);
  }

  final ProteinResolver _resolver;

  StreamSubscription<ProteinBuild>? _ended;

  /// Counts asks, so an older answer arriving last is dropped.
  int _asked = 0;

  /// Ask for the list, keeping what is on screen until it answers.
  void load() {
    final int asked = ++_asked;
    final BuiltState now = state;
    emit(
      BuiltLoading(
        previous: switch (now) {
          BuiltShown(:final BuiltPage page) => page,
          BuiltLoading(:final BuiltPage? previous) => previous,
          _ => null,
        },
      ),
    );
    unawaited(_fetch(asked));
  }

  /// A list never looked at is asked for when it is; one looked at is asked
  /// again now.
  void _endedOne(ProteinBuild build) {
    if (build.opens && state is! BuiltIdle) {
      load();
    }
  }

  Future<void> _fetch(int asked) async {
    try {
      final BuiltPage page = await _resolver.built();
      if (!isClosed && asked == _asked) {
        emit(BuiltShown(page));
      }
    } on ServerApiException catch (error) {
      if (!isClosed && asked == _asked) {
        emit(
          error.statusCode == 404
              ? const BuiltNotListed()
              : BuiltFailed(error.userMessage),
        );
      }
    } on ApiException catch (error) {
      if (!isClosed && asked == _asked) {
        emit(BuiltFailed(error.userMessage));
      }
    } on Object {
      if (!isClosed && asked == _asked) {
        emit(BuiltFailed(const UnknownApiException().userMessage));
      }
    }
  }

  @override
  Future<void> close() {
    unawaited(_ended?.cancel());
    return super.close();
  }
}
