import 'package:helixpeek/core/network/api_client.dart';

/// The answers [ProteinResolver] asks the service for, each a callback a test
/// can replace, and every call recorded in the order it was made.
///
/// By default every protein search finds nothing, which is what the curated
/// list's own tests need: the screen with no service behind its Build on
/// demand tab; nothing is built (`/proteins/built`), and this phone stopped
/// nothing (`/proteins/stopped`).
final class ResolverApi implements ApiClient {
  ResolverApi({
    Future<Map<String, dynamic>> Function(String query)? suggest,
    this.resolve,
    this.status,
    this.tracks,
    this.stop,
    this.keep,
    this.discard,
    Future<Map<String, dynamic>> Function(int limit)? built,
    Future<Map<String, dynamic>> Function(String asker)? stopped,
  }) : suggest = suggest ?? _nothing,
       built = built ?? ((int limit) => _noneBuilt()),
       stopped = stopped ?? ((String asker) => _noneBuilt());

  Future<Map<String, dynamic>> Function(String query) suggest;
  Future<Map<String, dynamic>> Function(String gene)? resolve;
  Future<Map<String, dynamic>> Function(String gene)? status;
  Future<Map<String, dynamic>> Function(String slug)? tracks;
  Future<Map<String, dynamic>> Function(String gene)? stop;
  Future<Map<String, dynamic>> Function(String gene)? keep;
  Future<Map<String, dynamic>> Function(String gene)? discard;
  /// `GET /proteins/built`, answered with the limit it was asked for.
  Future<Map<String, dynamic>> Function(int limit) built;
  Future<Map<String, dynamic>> Function(String asker) stopped;

  /// `GET /proteins/suggest?q=ins`, `POST /proteins/resolve BRCA1`, ...
  final List<String> calls = <String>[];

  /// Every body posted, in order.
  final List<Map<String, dynamic>> posted = <Map<String, dynamic>>[];

  static Future<Map<String, dynamic>> _noneBuilt() async =>
      <String, dynamic>{'proteins': <Object?>[], 'next': null};

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
    if (path == '/proteins/built') {
      return built(query?['limit'] as int? ?? 0);
    }
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
    posted.add(body);
    if (path.startsWith('/proteins/resolve/') && path.endsWith('/stop')) {
      calls.add('POST $path');
      return _answer(stop, Uri.decodeComponent(path.split('/')[3]), path);
    }
    if (path.startsWith('/proteins/resolve/') && path.endsWith('/keep')) {
      calls.add('POST $path');
      return _answer(keep, Uri.decodeComponent(path.split('/')[3]), path);
    }
    if (path.startsWith('/proteins/resolve/') && path.endsWith('/discard')) {
      calls.add('POST $path');
      return _answer(discard, Uri.decodeComponent(path.split('/')[3]), path);
    }
    if (path == '/proteins/stopped') {
      calls.add('POST $path');
      return stopped(body['asker'] as String);
    }
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
