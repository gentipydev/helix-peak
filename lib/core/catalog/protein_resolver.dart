import '../network/api_client.dart';
import 'protein_suggestion.dart';
import 'protein_track.dart';

/// The service's answers about proteins beyond the curated list: what a typed
/// name might mean, from every reviewed human protein, and building one on
/// demand (Phase 6 in the backend).
///
/// The service builds nothing itself. Asking queues a request that the
/// resolver on Modal works: it writes the protein's row and record, then
/// scores its ESM-2 track on a GPU. This asks, and reads how far it has got.
final class ProteinResolver {
  const ProteinResolver(this._api);

  final ApiClient _api;

  /// Up to [limit] proteins [query] might mean, best first.
  Future<SuggestionPage> suggest(String query, {int limit = 12}) async =>
      SuggestionPage.fromJson(
        await _api.getJson(
          '/proteins/suggest',
          query: <String, dynamic>{'q': query, 'limit': limit},
        ),
      );

  /// Ask for the protein [gene] makes, built where it is not one yet.
  Future<ResolveStatus> request(String gene) async => ResolveStatus.fromJson(
    await _api.postJson(
      '/proteins/resolve',
      body: <String, dynamic>{'gene': gene},
    ),
  );

  /// What [gene]'s protein is now, without asking for it.
  Future<ResolveStatus> status(String gene) async => ResolveStatus.fromJson(
    await _api.getJson('/proteins/resolve/${Uri.encodeComponent(gene)}'),
  );

  /// The state of one of [slug]'s tracks, read from the service every time.
  ///
  /// Not through a `TrackClient`: that remembers a protein's rows for the
  /// whole run, which is right for a walk and wrong for a bake being watched
  /// land.
  Future<TrackState> trackState(String slug, TrackKind kind) async {
    final Map<TrackKind, TrackRef> rows = tracksFromJson(
      await _api.getJson('/protein/${Uri.encodeComponent(slug)}/tracks'),
    );
    return rows[kind]?.state ?? TrackState.absent;
  }
}
