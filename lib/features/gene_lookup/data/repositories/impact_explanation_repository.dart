import 'package:flutter/foundation.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/network/mock_api_client.dart';
import '../../domain/entities/gene_impact.dart';
import '../../domain/entities/impact_explanations.dart';

/// The same versioned response and parser for bundled and backend evidence.
/// Failures are evicted so retry can recover; a live failure never silently
/// switches to a different local snapshot.
final class ImpactExplanationRepository {
  ImpactExplanationRepository(this._client);
  final ApiClient _client;
  final Map<GeneImpact, Future<GeneImpactExplanations>> _loads = {};

  /// Standalone walk previews also work offline, without app-level providers.
  static final ImpactExplanationRepository bundled =
      ImpactExplanationRepository(MockApiClient(latency: Duration.zero));

  Future<GeneImpactExplanations> load(GeneImpact track) =>
      _loads[track] ??= _load(track)
          .catchError((Object error, StackTrace stack) {
            _loads.remove(track);
            Error.throwWithStackTrace(error, stack);
          });

  Future<GeneImpactExplanations> _load(GeneImpact track) async {
    final json = await _client.getJson(
      '/gene/${track.target.accession}/${track.gene}/impact-explanations',
    );
    return compute(_parse, (json, track));
  }

  static GeneImpactExplanations _parse(
    (Map<String, dynamic>, GeneImpact) input,
  ) => GeneImpactExplanations.fromJson(input.$1, input.$2);
}
