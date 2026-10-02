import 'package:helixpeek/core/network/api_client.dart';

/// The four answers [ProteinResolver] asks the service for, each a callback a
/// test can replace, and every call recorded in the order it was made.
///
/// By default every protein search finds nothing, which is what the curated
/// list's own tests need: the screen as it was, with no service behind the
/// second half of it.
final class ResolverApi implements ApiClient {
  ResolverApi({
    Future<Map<String, dynamic>> Function(String query)? suggest,
    this.resolve,
    this.status,
    this.tracks,
  }) : suggest = suggest ?? _nothing;

  Future<Map<String, dynamic>> Function(String query) suggest;
  Future<Map<String, dynamic>> Function(String gene)? resolve;
  Future<Map<String, dynamic>> Function(String gene)? status;
  Future<Map<String, dynamic>> Function(String slug)? tracks;

  /// `GET /proteins/suggest?q=ins`, `POST /proteins/resolve BRCA1`, ...
  final List<String> calls = <String>[];

  static Future<Map<String, dynamic>> _nothing(String query) async =>
      <String, dynamic>{
        'q': query,
        'release': null,
        'suggestions': <Object?>[],
      };

  @override
  Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, dynamic>? query,
  }) async {
    if (path == '/proteins/suggest') {
      final String q = query?['q'] as String? ?? '';
      calls.add('GET $path?q=$q');
      return suggest(q);
    }
    calls.add('GET $path');
    final List<String> parts = path.split('/');
    if (path.startsWith('/proteins/resolve/')) {
      return _answer(status, Uri.decodeComponent(parts.last), path);
    }
    if (path.startsWith('/protein/') && path.endsWith('/tracks')) {
      return _answer(tracks, Uri.decodeComponent(parts[2]), path);
    }
    throw StateError('Nothing answers GET $path');
  }

  @override
  Future<Map<String, dynamic>> postJson(
    String path, {
    required Map<String, dynamic> body,
  }) async {
    final String gene = body['gene'] as String;
    calls.add('POST $path $gene');
    if (path != '/proteins/resolve') {
      throw StateError('Nothing answers POST $path');
    }
    return _answer(resolve, gene, path);
  }

  Future<Map<String, dynamic>> _answer(
    Future<Map<String, dynamic>> Function(String)? answer,
    String key,
    String path,
  ) {
    if (answer == null) {
      throw StateError('Nothing answers $path');
    }
    return answer(key);
  }
}
