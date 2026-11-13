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

  /// The proteins built on demand, every install's, newest first.
  ///
  /// One page of up to [limit]. Its `next` is not followed: that waits until
  /// there are nearly that many builds.
  Future<BuiltPage> built({int limit = 200}) async => BuiltPage.fromJson(
    await _api.getJson(
      '/proteins/built',
      query: <String, dynamic>{'limit': limit},
    ),
  );

  /// The builds [asker] stopped and has not resumed, kept or discarded since:
  /// what this phone pins again when the app starts. Asked by POST, so the
  /// install's id is never in a URL.
  Future<BuiltPage> stopped(String asker) async => BuiltPage.fromJson(
    await _api.postJson(
      '/proteins/stopped',
      body: <String, dynamic>{'asker': asker},
    ),
  );

  /// Keep [gene]'s stopped build as it is, without its ESM-2 scores, for
  /// [asker], which stopped it.
  Future<ResolveStatus> keep(String gene, String asker) async =>
      ResolveStatus.fromJson(
        await _api.postJson(
          '/proteins/resolve/${Uri.encodeComponent(gene)}/keep',
          body: <String, dynamic>{'asker': asker},
        ),
      );

  /// Delete everything built for [gene]'s stopped build, for [asker], which
  /// stopped it: the gene then reads as never asked for.
  Future<ResolveStatus> discard(String gene, String asker) async =>
      ResolveStatus.fromJson(
        await _api.postJson(
          '/proteins/resolve/${Uri.encodeComponent(gene)}/discard',
          body: <String, dynamic>{'asker': asker},
        ),
      );

  /// Ask for the protein [gene] makes, built where it is not one yet, or
  /// scored afresh where its scoring was stopped. [asker] is this install's
  /// own id: only it may stop what the ask starts.
  Future<ResolveStatus> request(String gene, {String? asker}) async =>
      ResolveStatus.fromJson(
        await _api.postJson(
          '/proteins/resolve',
          body: <String, dynamic>{'gene': gene, 'asker': ?asker},
        ),
      );

  /// Stop the build of [gene]'s protein, which [asker] asked for.
  Future<ResolveStatus> stop(String gene, String asker) async =>
      ResolveStatus.fromJson(
        await _api.postJson(
          '/proteins/resolve/${Uri.encodeComponent(gene)}/stop',
          body: <String, dynamic>{'asker': asker},
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
