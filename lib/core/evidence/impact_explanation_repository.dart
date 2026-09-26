import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../catalog/protein_track.dart';
import '../network/track_source.dart';
import 'gene_impact.dart';
import 'impact_explanations.dart';

/// Validates stored evidence in an isolate.
/// Failures are evicted so retry can recover; a live failure never silently
/// switches to a different local snapshot.
final class ImpactExplanationRepository {
  ImpactExplanationRepository(this._client);
  final TrackSource _client;
  final Map<GeneImpact, Future<GeneImpactExplanations>> _loads = {};

  Future<GeneImpactExplanations> load(GeneImpact track) =>
      _loads[track] ??= _load(track)
          .catchError((Object error, StackTrace stack) {
            _loads.remove(track);
            Error.throwWithStackTrace(error, stack);
          });

  Future<GeneImpactExplanations> _load(GeneImpact track) async {
    final bytes = await _client.read(
      track.target.slug, TrackKind.impactExplanations,
    );
    return compute(_parse, (bytes, track));
  }

  static GeneImpactExplanations _parse(
    (Uint8List, GeneImpact) input,
  ) => GeneImpactExplanations.fromJson(
    jsonDecode(utf8.decode(input.$1)) as Map<String, dynamic>, input.$2,
  );
}
