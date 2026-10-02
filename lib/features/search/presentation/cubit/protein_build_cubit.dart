import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/catalog/protein_resolver.dart';
import '../../../../core/catalog/protein_suggestion.dart';
import '../../../../core/catalog/protein_track.dart';
import '../../../../core/network/api_exception.dart';

/// How far one protein's build has got.
enum BuildStage {
  /// The ask is on its way to the service.
  asking,

  /// Queued or running: its row and gene record are being made.
  resolving,

  /// Its row and record are written, and its ESM-2 track is being scored.
  scoring,

  /// Everything it was built with has landed, or been declined: it opens.
  ready,

  /// The resolver declined it, or the index cannot build it.
  refused,

  /// It broke, or the service did not answer. Asking again may work.
  failed,

  /// Today's builds are taken.
  capped;

  bool get busy => this == asking || this == resolving || this == scoring;

  /// Whether the service is asked about it again at the next tick.
  bool get watched => this == resolving || this == scoring;
}

@immutable
final class BuildProgress {
  const BuildProgress(this.stage, {this.slug, this.message});

  final BuildStage stage;

  /// Where it opens, once the service has said.
  final String? slug;

  /// What the service said, where a stage has something to say.
  final String? message;
}

@immutable
final class BuildsState {
  const BuildsState(this.builds);

  /// Keyed by gene symbol, as the builds were asked for.
  final Map<String, BuildProgress> builds;

  BuildProgress? of(String gene) => builds[gene];

  bool get watching => builds.values.any((BuildProgress b) => b.stage.watched);
}

/// The proteins this visit to search has asked to be built, and how far each
/// has got.
///
/// A build is asked for once, then watched: its resolve state until its row
/// and record are written, then its constraint track until ESM-2 has scored
/// it or declined to. Only then does it open, because the walk reads a
/// protein's tracks once and keeps them: a protein opened while its scores are
/// pending would stay unscored until the app restarts.
class ProteinBuildCubit extends Cubit<BuildsState> {
  ProteinBuildCubit(
    this._resolver, {
    this.interval = const Duration(seconds: 3),
    this.patience = 300,
  }) : super(const BuildsState(<String, BuildProgress>{}));

  final ProteinResolver _resolver;

  /// How often a build in progress is asked about.
  final Duration interval;

  /// How many times a build is asked about before the screen stops waiting
  /// for it: fifteen minutes, at the default interval.
  final int patience;

  final Map<String, int> _asked = <String, int>{};

  Timer? _next;

  Future<void> build(String gene) async {
    if (state.of(gene)?.stage.busy ?? false) {
      return;
    }
    _asked[gene] = 0;
    _set(gene, const BuildProgress(BuildStage.asking));
    try {
      await _settle(gene, await _resolver.request(gene));
    } on ServerApiException catch (error) {
      _set(
        gene,
        BuildProgress(
          error.statusCode == 429 ? BuildStage.capped : BuildStage.failed,
          message: error.userMessage,
        ),
      );
    } on ApiException catch (error) {
      _set(gene, BuildProgress(BuildStage.failed, message: error.userMessage));
    } on Object {
      _set(
        gene,
        BuildProgress(
          BuildStage.failed,
          message: const UnknownApiException().userMessage,
        ),
      );
    }
    _schedule();
  }

  Future<void> _settle(String gene, ResolveStatus status) async {
    final String? slug = status.slug;
    switch (status.state) {
      case ResolveState.pending || ResolveState.buildable:
        _set(gene, BuildProgress(BuildStage.resolving, slug: slug));
      case ResolveState.ready when slug != null:
        // Its row is there; whether its ESM-2 track is, is another question.
        await _scored(gene, slug);
      case ResolveState.refused || ResolveState.unavailable:
        _set(gene, BuildProgress(BuildStage.refused, message: status.reason));
      case ResolveState.ready || ResolveState.failed:
        _set(gene, BuildProgress(BuildStage.failed, message: status.reason));
    }
  }

  Future<void> _scored(String gene, String slug) async {
    final TrackState constraint = await _resolver.trackState(
      slug,
      TrackKind.constraint,
    );
    _set(
      gene,
      BuildProgress(
        constraint == TrackState.pending
            ? BuildStage.scoring
            : BuildStage.ready,
        slug: slug,
      ),
    );
  }

  Future<void> _poll() async {
    for (final MapEntry<String, BuildProgress> entry
        in state.builds.entries.toList()) {
      final String gene = entry.key;
      final BuildProgress progress = entry.value;
      if (!progress.stage.watched) {
        continue;
      }
      final int asked = (_asked[gene] ?? 0) + 1;
      _asked[gene] = asked;
      try {
        final String? slug = progress.slug;
        if (progress.stage == BuildStage.scoring && slug != null) {
          await _scored(gene, slug);
        } else {
          await _settle(gene, await _resolver.status(gene));
        }
      } on Object {
        // An answer missed is asked for again at the next tick.
      }
      if (isClosed) {
        return;
      }
      final BuildProgress now = state.of(gene)!;
      if (now.stage.watched && asked >= patience) {
        _set(
          gene,
          now.stage == BuildStage.scoring
              ? BuildProgress(
                  BuildStage.ready,
                  slug: now.slug,
                  message: 'Its ESM-2 scores are still on their way.',
                )
              : const BuildProgress(
                  BuildStage.failed,
                  message:
                      'The build is taking longer than it should. Ask again '
                      'later.',
                ),
        );
      }
    }
    _schedule();
  }

  void _schedule() {
    _next?.cancel();
    if (!isClosed && state.watching) {
      _next = Timer(interval, () => unawaited(_poll()));
    }
  }

  void _set(String gene, BuildProgress progress) {
    if (!isClosed) {
      emit(
        BuildsState(<String, BuildProgress>{...state.builds, gene: progress}),
      );
    }
  }

  @override
  Future<void> close() {
    _next?.cancel();
    return super.close();
  }
}
