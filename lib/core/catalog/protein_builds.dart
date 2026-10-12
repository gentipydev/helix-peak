import 'dart:async';

import 'package:flutter/foundation.dart';

import '../network/api_exception.dart';
import 'protein_resolver.dart';
import 'protein_suggestion.dart';
import 'protein_track.dart';

/// Where one build stands, as the app tells it.
enum BuildStage {
  /// The ask is on its way to the service.
  asking,

  /// Queued or being built: [ProteinBuild.report] says how far.
  building,

  /// Built, and it opens. Its ESM-2 scores may have been declined, which the
  /// report's reason says; the walk is drawn without them.
  ready,

  /// The resolver declined it, or the index cannot build it.
  refused,

  /// It broke, or the service did not answer the ask. Asking again may work.
  failed,

  /// Today's builds are taken.
  capped,

  /// Stopped by this phone. Stopped while ESM-2 scored, it opens without its
  /// scores ([ProteinBuild.slug] says where); either way asking again builds
  /// what is missing.
  stopped;

  bool get underway => this == asking || this == building;
}

/// One protein asked to be built, and how far it has got.
@immutable
final class ProteinBuild {
  const ProteinBuild({
    required this.protein,
    required this.stage,
    this.report,
    this.slug,
    this.message,
    this.unchangedFor,
    this.unheard = false,
    this.pinned = true,
    this.mine = false,
    this.stopping = false,
  });

  /// The protein as search named it: what its card is headed with.
  final ProteinSuggestion protein;

  final BuildStage stage;

  /// The service's last word on how far it has got. Null while it is asked
  /// for, and from a service that predates the report.
  final BuildReport? report;

  /// Where it opens, once the service has said.
  final String? slug;

  /// What the service said, where it declined, broke or is capped.
  final String? message;

  /// How long nothing in the report has moved, by the service's clock, once
  /// that is longer than [ProteinBuilds.stall]. Null while it moves.
  final Duration? unchangedFor;

  /// Whether the service has stopped answering about it, for now.
  final bool unheard;

  /// Shown at the top of search: from the ask until it is opened, or, where
  /// it ended without anything to open, until search is left.
  final bool pinned;

  /// Whether this phone asked for it, and so may stop it.
  final bool mine;

  /// Whether a stop is on its way to the service.
  final bool stopping;

  /// Whether Stop is offered now: this phone's, under way, and at a step a
  /// stop can end (not while its record is written, nor in the moments of
  /// the check).
  bool get stoppable =>
      mine &&
      stage == BuildStage.building &&
      !stopping &&
      (report?.step == BuildStep.queued || report?.step == BuildStep.scoring);

  /// Whether it can be opened: built, or stopped once its record was.
  bool get opens =>
      slug != null && (stage == BuildStage.ready || stage == BuildStage.stopped);

  String get gene => protein.gene!;

  ProteinBuild _with({
    BuildStage? stage,
    BuildReport? report,
    String? slug,
    String? message,
    Duration? unchangedFor,
    bool? unheard,
    bool? pinned,
    bool? mine,
    bool? stopping,
  }) => ProteinBuild(
    protein: protein,
    stage: stage ?? this.stage,
    report: report ?? this.report,
    slug: slug ?? this.slug,
    message: message ?? this.message,
    unchangedFor: unchangedFor,
    unheard: unheard ?? false,
    pinned: pinned ?? this.pinned,
    mine: mine ?? this.mine,
    stopping: stopping ?? this.stopping,
  );
}

/// The proteins this run of the app has asked to be built, and how far each
/// has got: one job of the whole app, like a clip, so a build outlives the
/// search that asked for it and the reader can walk something else while
/// ESM-2 scores it.
///
/// A build is asked for once, then watched through `/proteins/resolve`, whose
/// report names the step and, while ESM-2 runs, the residues scored and the
/// time left. Only once it is scored, or declined, does it open: the walk
/// reads a protein's tracks once and keeps them, so a protein opened while its
/// scores are pending would stay unscored until the app restarts.
///
/// Nothing is given up on by the app. A build whose report has not moved for
/// [stall] says so and is asked about less often; one the service has stopped
/// answering about says that. Either carries on as soon as there is something
/// new. The reader who asked may stop it ([stop]): there are no accounts, so
/// an ask carries this install's own id ([asker]), and only it may stop what
/// the ask started.
class ProteinBuilds {
  ProteinBuilds(
    this._resolver, {
    this.asker,
    this.interval = const Duration(seconds: 3),
    this.stall = const Duration(minutes: 10),
  });

  final ProteinResolver _resolver;

  /// This install's own id (`InstallId.read`). Without it, an ask names no
  /// one and nothing it starts can be stopped.
  final Future<String> Function()? asker;

  /// How often a build under way is asked about.
  final Duration interval;

  /// How long a report may stand still before the build is said to have.
  final Duration stall;

  /// A stalled build is asked about every this many ticks.
  static const int _stalledEvery = 10;

  /// Ticks without an answer before a build is said to be unheard.
  static const int _patience = 10;

  final ValueNotifier<Map<String, ProteinBuild>> _builds =
      ValueNotifier<Map<String, ProteinBuild>>(const <String, ProteinBuild>{});

  final StreamController<ProteinBuild> _ended =
      StreamController<ProteinBuild>.broadcast();

  /// Per gene: the report's position when it last moved, and the service's
  /// seconds then; and the polls in a row that went unanswered.
  final Map<String, (Object?, Duration)> _moved = <String, (Object?, Duration)>{};
  final Map<String, int> _missed = <String, int>{};

  Timer? _next;
  int _ticks = 0;
  bool _closed = false;

  /// Keyed by gene symbol, in the order the builds were asked for.
  ValueListenable<Map<String, ProteinBuild>> get builds => _builds;

  /// Each build as it ends: built, declined or broken.
  Stream<ProteinBuild> get ended => _ended.stream;

  ProteinBuild? of(String gene) => _builds.value[gene];

  /// Ask for [protein] to be built, and watch it.
  Future<void> build(ProteinSuggestion protein) async {
    final String? gene = protein.gene;
    if (gene == null || (of(gene)?.stage.underway ?? false)) {
      return;
    }
    _moved.remove(gene);
    _missed.remove(gene);
    _put(ProteinBuild(
      protein: protein,
      stage: BuildStage.asking,
      mine: asker != null,
    ));
    ProteinBuild next;
    try {
      final String? id = await _id();
      next = await _settled(of(gene)!, await _resolver.request(gene, asker: id));
    } on ServerApiException catch (error) {
      next = ProteinBuild(
        protein: protein,
        stage: error.statusCode == 429 ? BuildStage.capped : BuildStage.failed,
        message: error.userMessage,
      );
    } on ApiException catch (error) {
      next = ProteinBuild(
        protein: protein,
        stage: BuildStage.failed,
        message: error.userMessage,
      );
    } on Object {
      next = ProteinBuild(
        protein: protein,
        stage: BuildStage.failed,
        message: const UnknownApiException().userMessage,
      );
    }
    _land(next);
    _schedule();
  }

  /// Watch a build search found under way that this run did not ask for:
  /// asked for elsewhere, or before the app was last started.
  void watch(ProteinSuggestion protein) {
    final String? gene = protein.gene;
    if (gene == null || of(gene) != null || _closed) {
      return;
    }
    _put(ProteinBuild(protein: protein, stage: BuildStage.building));
    _next?.cancel();
    unawaited(_poll());
  }

  /// Stop [gene]'s build, which this phone asked for. Null once it is
  /// stopped; otherwise why it was not, in the service's words: its record
  /// being written, its track made a moment ago, or another phone's.
  Future<String?> stop(String gene) async {
    final ProteinBuild? build = of(gene);
    final String? id = await _id();
    if (build == null || !build.stoppable || id == null) {
      return null;
    }
    _put(build._with(stopping: true, unchangedFor: build.unchangedFor));
    String? said;
    try {
      final ResolveStatus status = await _resolver.stop(gene, id);
      final ProteinBuild now = of(gene) ?? build;
      // The answer's slug is where it opens: none where nothing was built.
      _land(ProteinBuild(
        protein: now.protein,
        stage: BuildStage.stopped,
        report: status.build ?? now.report,
        slug: status.slug,
        pinned: now.pinned,
        mine: now.mine,
      ));
    } on ApiException catch (error) {
      said = error.userMessage;
    } on Object {
      said = const UnknownApiException().userMessage;
    }
    if (said != null) {
      final ProteinBuild? now = of(gene);
      if (now != null) {
        _put(now._with(stopping: false, unchangedFor: now.unchangedFor));
      }
    }
    _schedule();
    return said;
  }

  Future<String?> _id() async {
    final Future<String> Function()? read = asker;
    if (read == null) {
      return null;
    }
    try {
      return await read();
    } on Object {
      return null;
    }
  }

  /// The reader opened it: it leaves the top of search, and search still
  /// knows where it opens.
  void opened(String gene) {
    final ProteinBuild? build = of(gene);
    if (build != null && build.pinned) {
      _put(build._with(pinned: false, unchangedFor: build.unchangedFor));
    }
  }

  /// Search was left: a build that ended with nothing to open has been said,
  /// and leaves the top of it.
  void unpinEnded() {
    for (final ProteinBuild build in _builds.value.values.toList()) {
      if (build.pinned && !build.stage.underway && !build.opens) {
        _put(build._with(pinned: false));
      }
    }
  }

  Future<ProteinBuild> _settled(ProteinBuild build, ResolveStatus status) async {
    final BuildReport? report = status.build;
    final String? slug = status.slug;
    switch (status.state) {
      case ResolveState.pending:
        return build._with(stage: BuildStage.building, report: report, slug: slug);
      case ResolveState.buildable:
        // Search said it was building, and no request for it is left: there
        // is nothing to watch, and asking again starts one.
        return build._with(
          stage: BuildStage.failed,
          message: 'No build of it is under way.',
        );
      case ResolveState.ready when slug != null:
        if (report == null) {
          // A service that predates the report: the track says it instead.
          final TrackState constraint = await _resolver.trackState(
            slug,
            TrackKind.constraint,
          );
          return build._with(
            stage: constraint == TrackState.pending
                ? BuildStage.building
                : BuildStage.ready,
            slug: slug,
          );
        }
        final bool over =
            (report.step == BuildStep.done && !report.holding) ||
            report.reason != null;
        return build._with(
          // Stopped by the phone that asked, when this one only watched it.
          stage: report.stopped
              ? BuildStage.stopped
              : over
              ? BuildStage.ready
              : BuildStage.building,
          report: report,
          slug: slug,
        );
      case ResolveState.refused || ResolveState.unavailable:
        return build._with(
          stage: BuildStage.refused,
          report: report,
          message: status.reason,
        );
      case ResolveState.ready || ResolveState.failed:
        return build._with(
          stage: BuildStage.failed,
          report: report,
          message: status.reason,
        );
      case ResolveState.stopped:
        return build._with(stage: BuildStage.stopped, report: report, slug: slug);
    }
  }

  /// [next] in place of what was there, said where it ended, and with how
  /// long its report has stood still.
  void _land(ProteinBuild next) {
    if (_closed) {
      return;
    }
    final ProteinBuild? was = of(next.gene);
    _missed.remove(next.gene);
    _put(next._with(unchangedFor: _stillFor(next)));
    if (!next.stage.underway && (was == null || was.stage.underway)) {
      _ended.add(of(next.gene)!);
    }
  }

  Duration? _stillFor(ProteinBuild build) {
    final BuildReport? report = build.report;
    if (report == null || !build.stage.underway) {
      _moved.remove(build.gene);
      return null;
    }
    final Object position = (report.step, report.scored, report.ahead);
    final (Object?, Duration)? last = _moved[build.gene];
    if (last == null || last.$1 != position) {
      _moved[build.gene] = (position, report.elapsed);
      return null;
    }
    final Duration still = report.elapsed - last.$2;
    return still >= stall ? still : null;
  }

  Future<void> _poll() async {
    _ticks++;
    for (final ProteinBuild build in _builds.value.values.toList()) {
      if (_closed) {
        return;
      }
      if (build.stage != BuildStage.building) {
        continue;
      }
      if (build.unchangedFor != null && _ticks % _stalledEvery != 0) {
        continue;
      }
      try {
        _land(await _settled(build, await _resolver.status(build.gene)));
      } on Object {
        // Asked again at the next tick; said once it has gone on a while.
        final int missed = (_missed[build.gene] ?? 0) + 1;
        _missed[build.gene] = missed;
        final ProteinBuild? now = of(build.gene);
        if (now != null && missed >= _patience && !now.unheard) {
          _put(now._with(unchangedFor: now.unchangedFor, unheard: true));
        }
      }
    }
    _schedule();
  }

  void _schedule() {
    _next?.cancel();
    final bool watching = _builds.value.values.any(
      (ProteinBuild b) => b.stage == BuildStage.building,
    );
    if (!_closed && watching) {
      _next = Timer(interval, () => unawaited(_poll()));
    }
  }

  void _put(ProteinBuild build) {
    if (!_closed) {
      _builds.value = <String, ProteinBuild>{..._builds.value, build.gene: build};
    }
  }

  void dispose() {
    _closed = true;
    _next?.cancel();
    unawaited(_ended.close());
    _builds.dispose();
  }
}
