import 'package:flutter/foundation.dart';

/// What the app can do with a protein `/proteins/suggest` names.
///
/// Mirrors `Suggestion.status` in the backend's `app/schemas.py`.
enum SuggestionStatus {
  /// One of the curated proteins, opened from the list.
  listed('listed'),

  /// Built on demand earlier, and opened at once.
  ready('ready'),

  /// Not built yet; asking builds it.
  buildable('buildable'),

  /// Cannot be built, and the suggestion's reason says why.
  unavailable('unavailable');

  const SuggestionStatus(this.wire);

  final String wire;

  /// A status this build does not know is one it cannot act on, so it reads
  /// as [unavailable] rather than as something to offer.
  static SuggestionStatus fromWire(String? wire) {
    for (final SuggestionStatus status in SuggestionStatus.values) {
      if (status.wire == wire) {
        return status;
      }
    }
    return SuggestionStatus.unavailable;
  }
}

/// One protein a reader might mean, from every reviewed human protein.
@immutable
final class ProteinSuggestion {
  const ProteinSuggestion({
    required this.uniprot,
    required this.gene,
    required this.name,
    required this.display,
    required this.length,
    required this.slug,
    required this.status,
    required this.reason,
    this.building = false,
    this.stopped = false,
  });

  factory ProteinSuggestion.fromJson(Map<String, dynamic> json) =>
      ProteinSuggestion(
        uniprot: json['uniprot'] as String,
        gene: json['gene'] as String?,
        name: json['name'] as String,
        display: json['display'] as String?,
        length: json['length'] as int,
        slug: json['slug'] as String?,
        status: SuggestionStatus.fromWire(json['status'] as String?),
        reason: json['reason'] as String?,
        building: json['building'] as bool? ?? false,
        stopped: json['stopped'] as bool? ?? false,
      );

  final String uniprot;

  /// The gene symbol, which is what a build is asked for by. Null where
  /// UniProt names no gene.
  final String? gene;

  /// UniProt's recommended name.
  final String name;

  /// The app's own name for a listed protein ("Hemoglobin (beta chain)").
  final String? display;

  /// Residues in UniProt's canonical sequence.
  final int length;

  /// Where a listed or ready protein opens, and the slug a build would give
  /// a buildable one.
  final String? slug;

  final SuggestionStatus status;

  /// Why an unavailable protein cannot be built.
  final String? reason;

  /// Whether a build of it is under way: asked for and not yet resolved, or
  /// resolved and still being scored. A protein is [SuggestionStatus.ready]
  /// minutes before its ESM-2 track is, so one being built is watched, never
  /// opened. A service that predates the field says nothing, read as false.
  final bool building;

  /// Whether the reader who asked stopped its scoring: it opens without its
  /// ESM-2 scores, and asking for it again scores it.
  final bool stopped;

  /// What the row is called: the app's name where it has one, UniProt's
  /// otherwise.
  String get title => display ?? name;
}

/// One answer from `/proteins/suggest`.
@immutable
final class SuggestionPage {
  const SuggestionPage({
    required this.query,
    required this.release,
    required this.suggestions,
  });

  factory SuggestionPage.fromJson(Map<String, dynamic> json) => SuggestionPage(
    query: json['q'] as String? ?? '',
    release: json['release'] as String?,
    suggestions: <ProteinSuggestion>[
      for (final Object? row
          in json['suggestions'] as List<dynamic>? ?? const <dynamic>[])
        ProteinSuggestion.fromJson(row! as Map<String, dynamic>),
    ],
  );

  final String query;

  /// What the index was built from: "UniProt 2026_03 · MANE v1.5".
  final String? release;

  final List<ProteinSuggestion> suggestions;
}

/// One answer from `/proteins/built`: the proteins built on demand, every
/// install's, newest first.
@immutable
final class BuiltPage {
  const BuiltPage({required this.proteins, required this.next});

  factory BuiltPage.fromJson(Map<String, dynamic> json) => BuiltPage(
    proteins: <ProteinSuggestion>[
      for (final Object? row
          in json['proteins'] as List<dynamic>? ?? const <dynamic>[])
        ProteinSuggestion.fromJson(row! as Map<String, dynamic>),
    ],
    next: json['next'] as String?,
  );

  /// Each [SuggestionStatus.ready]. One still being built is left out until
  /// it is done; one whose scoring was stopped is here, and says so.
  final List<ProteinSuggestion> proteins;

  /// What to pass back for the page after this one; null on the last.
  final String? next;
}

/// What a gene's protein is now, as `/proteins/resolve` says it.
///
/// Mirrors `ResolveResponse.state` in the backend's `app/schemas.py`.
enum ResolveState {
  /// It has a row: [ResolveStatus.slug] opens it.
  ready('ready'),

  /// Asked for, and being built.
  pending('pending'),

  /// The resolver declined, and the reason says why.
  refused('refused'),

  /// It broke more often than it is retried. Asking again starts over.
  failed('failed'),

  /// The index cannot build it, and the reason says why.
  unavailable('unavailable'),

  /// Nobody has asked yet. Only a read says this.
  buildable('buildable'),

  /// Stopped by the reader who asked. Only a stop's own answer says this.
  stopped('stopped');

  const ResolveState(this.wire);

  final String wire;

  /// A state this build does not know is treated as a failure, which offers
  /// to ask again rather than promising anything.
  static ResolveState fromWire(String? wire) {
    for (final ResolveState state in ResolveState.values) {
      if (state.wire == wire) {
        return state;
      }
    }
    return ResolveState.failed;
  }
}

@immutable
final class ResolveStatus {
  const ResolveStatus({
    required this.state,
    this.slug,
    this.reason,
    this.build,
  });

  factory ResolveStatus.fromJson(Map<String, dynamic> json) => ResolveStatus(
    state: ResolveState.fromWire(json['state'] as String?),
    slug: json['slug'] as String?,
    reason: json['reason'] as String?,
    build: switch (json['build']) {
      final Map<String, dynamic> build => BuildReport.fromJson(build),
      _ => null,
    },
  );

  final ResolveState state;
  final String? slug;
  final String? reason;

  /// How far its build has got. Null for a curated protein, one nobody has
  /// asked for, a step this build does not know, or a service that predates
  /// the field.
  final BuildReport? build;
}

/// The steps of a build, in the order a protein goes through them.
///
/// Mirrors `BuildReport.step` in the backend's `app/schemas.py`.
enum BuildStep {
  /// Asked for, and no worker has taken it yet.
  queued('queued'),

  /// Its row and gene record are being made, from its UniProt entry and its
  /// MANE Select transcript.
  record('record'),

  /// Its ESM-2 track: waiting for the scorer, the model loading, or residues
  /// being scored.
  scoring('scoring'),

  /// Every residue scored; the alignment gate and the upload are left.
  check('check'),

  /// Scored and stored.
  done('done');

  const BuildStep(this.wire);

  final String wire;

  /// Null for a step this build does not know, which it cannot place.
  static BuildStep? fromWire(String? wire) {
    for (final BuildStep step in BuildStep.values) {
      if (step.wire == wire) {
        return step;
      }
    }
    return null;
  }
}

/// How far a protein built on demand has got, as the service measures it.
///
/// Mirrors `BuildReport` in the backend's `app/schemas.py`. Every number is
/// the database's, so the phone's clock never enters one.
@immutable
final class BuildReport {
  const BuildReport({
    required this.step,
    required this.elapsed,
    this.ahead,
    this.scored,
    this.residues,
    this.left,
    this.transcript,
    this.reason,
    this.stopped = false,
    this.ran,
  });

  /// Null where the step is one this build does not know.
  static BuildReport? fromJson(Map<String, dynamic> json) {
    final BuildStep? step = BuildStep.fromWire(json['step'] as String?);
    if (step == null) {
      return null;
    }
    final double? left = (json['left'] as num?)?.toDouble();
    final double? ran = (json['ran'] as num?)?.toDouble();
    return BuildReport(
      step: step,
      elapsed: _seconds((json['elapsed'] as num?)?.toDouble() ?? 0),
      ahead: json['ahead'] as int?,
      scored: json['scored'] as int?,
      residues: json['residues'] as int?,
      left: left == null ? null : _seconds(left),
      transcript: json['transcript'] as String?,
      reason: json['reason'] as String?,
      stopped: json['stopped'] as bool? ?? false,
      ran: ran == null ? null : _seconds(ran),
    );
  }

  static Duration _seconds(double seconds) =>
      Duration(milliseconds: (seconds * 1000).round());

  /// The step it is at, or ended at.
  final BuildStep step;

  /// Since it was asked for, to now, or to when it ended.
  final Duration elapsed;

  /// Proteins the worker takes first, while this one waits its turn.
  final int? ahead;

  /// Residues ESM-2 has scored, and of how many: the scorer's last line.
  final int? scored;
  final int? residues;

  /// What the scorer estimates is left, as of the answer.
  final Duration? left;

  /// The MANE Select transcript its gene record was built from.
  final String? transcript;

  /// Why [step] ended without its result: the track's reason, or where it
  /// was stopped.
  final String? reason;

  /// Whether the reader who asked stopped it at [step].
  final bool stopped;

  /// How long the scoring under way has run: what stopping it gives up.
  final Duration? ran;

  /// The share of residues scored, where the scorer has said.
  double? get fraction {
    final int? done = scored;
    final int? total = residues;
    if (done == null || total == null || total <= 0) {
      return null;
    }
    return (done / total).clamp(0.0, 1.0);
  }
}
