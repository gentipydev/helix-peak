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
  buildable('buildable');

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
  const ResolveStatus({required this.state, this.slug, this.reason});

  factory ResolveStatus.fromJson(Map<String, dynamic> json) => ResolveStatus(
    state: ResolveState.fromWire(json['state'] as String?),
    slug: json['slug'] as String?,
    reason: json['reason'] as String?,
  );

  final ResolveState state;
  final String? slug;
  final String? reason;
}
