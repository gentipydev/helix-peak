import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../../../core/catalog/protein_target.dart';
import '../../../../core/catalog/protein_track.dart';
import '../../../../core/network/track_source.dart';

/// The `trafficking` track: what UniProt says crosses a membrane, for the one
/// input no record carries.
///
/// Baked by `pipeline/trafficking/` in the backend, one per protein. The route
/// reads [transmembrane] from it and nothing else. The GPI-anchor signal is
/// already a region of the precursor (the backend's check holds the two to
/// each other), and the track's subcellular locations are UniProt's curation,
/// not sequence features, so the scene does not draw them.
@immutable
final class TraffickingTrack {
  const TraffickingTrack({
    required this.residues,
    required this.transmembrane,
    required this.release,
    required this.releaseDate,
    required this.retrieved,
  });

  /// Parses one payload, refusing one that names another protein or places a
  /// span off the chain.
  factory TraffickingTrack.fromJson(
    Map<String, dynamic> json,
    ProteinTarget target,
  ) {
    if (json['gene'] != target.gene || json['uniprot'] != target.uniprot) {
      throw FormatException(
        'A trafficking track for another protein, not '
        '${target.slug}',
      );
    }
    final Object? residues = json['residues'];
    if (residues is! int || residues != target.facts.residues) {
      throw FormatException(
        'A trafficking track for ${target.slug} of '
        '$residues residues, not ${target.facts.residues}',
      );
    }
    final List<(int, int)> spans = <(int, int)>[];
    for (final dynamic entry
        in json['transmembrane'] as List<dynamic>? ?? <dynamic>[]) {
      final Map<String, dynamic> span = entry as Map<String, dynamic>;
      final Object? start = span['start'];
      final Object? end = span['end'];
      if (start is! int ||
          end is! int ||
          start < 1 ||
          start > end ||
          end > residues) {
        throw FormatException('A span of ${target.slug} off its chain: $span');
      }
      spans.add((start, end));
    }
    final String? release = json['release'] as String?;
    final String? releaseDate = json['release_date'] as String?;
    final String? retrieved = json['retrieved'] as String?;
    if (release == null || releaseDate == null || retrieved == null) {
      throw FormatException(
        'A trafficking track for ${target.slug} that '
        'does not say where it came from',
      );
    }
    return TraffickingTrack(
      residues: residues,
      transmembrane: List<(int, int)>.unmodifiable(spans),
      release: release,
      releaseDate: releaseDate,
      retrieved: retrieved,
    );
  }

  /// [target]'s track, read through [tracks]. Only asked for where the row
  /// says it is ready: a track that is not is a state the scene draws.
  static Future<TraffickingTrack> load(
    ProteinTarget target, {
    required TrackSource tracks,
  }) async {
    final Uint8List bytes = await tracks.read(
      target.slug,
      TrackKind.trafficking,
    );
    final Object? json = jsonDecode(utf8.decode(bytes));
    if (json is! Map<String, dynamic>) {
      throw FormatException('Malformed trafficking track for ${target.slug}');
    }
    return TraffickingTrack.fromJson(json, target);
  }

  final int residues;

  /// Every stretch that crosses a membrane, in precursor numbering, in order.
  /// Empty where UniProt annotates none.
  final List<(int, int)> transmembrane;

  /// The UniProt release that served the entry, as `2026_03`.
  final String release;

  /// That release's date, and the day the entry was fetched, both ISO.
  final String releaseDate;
  final String retrieved;
}
