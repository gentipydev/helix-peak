import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../../features/gene_lookup/domain/entities/protein_track.dart';
import 'api_client.dart';
import 'api_exception.dart';
import 'dio_api_client.dart';
import 'track_source.dart';

/// Fetches track payloads from storage and keeps their rows and bytes.
///
/// Not an [ApiClient] call. [DioApiClient] is JSON-only and rejects a non-`Map`
/// body, and these payloads are bytes: a 9.5 MB ClinVar snapshot that must
/// never be decoded to a string on the way past. So this holds its own [Dio],
/// asks for [ResponseType.bytes], and lets the CDN's `content-encoding: gzip`
/// be undone by the transport with no Dart code — dystrophin's snapshot crosses
/// the wire in 572 KB and arrives here as the 9.5 MB it was stored as.
///
/// Where the object is comes from `/protein/{slug}/tracks`, once per protein
/// and remembered. A catalog page carries each family's *state* and no URL, so
/// the walk cannot fetch anything off the row it was routed with; this is the
/// second call that turns a state into an address. A failure is forgotten
/// rather than remembered, the way `ImpactExplanationRepository` forgets one:
/// the service cold-starts in about forty-four seconds, and a reader who comes
/// back to the page deserves a second attempt rather than the first failure for
/// the life of the process.
final class TrackClient implements TrackSource {
  TrackClient(
    this._api, {
    Dio? dio,
    Directory? cache,
    this.budget = _defaultBudget,
  }) : _dio = dio ?? Dio(_options),
       _given = cache;

  /// Roughly two hundred megabytes: five times the 41 MB the twenty proteins
  /// come to, so a reader who walks all of them keeps all of them, and a
  /// catalog that grows past that loses the oldest rather than the device.
  static const int _defaultBudget = 200 * 1024 * 1024;

  static BaseOptions get _options => BaseOptions(
    // Connecting is held to the patience a JSON call gets. Receiving is not:
    // dystrophin's snapshot is the one payload most worth waiting for, and a
    // reader on a slow connection is watching a page that says it is loading.
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(minutes: 2),
    responseType: ResponseType.bytes,
  );

  final ApiClient _api;
  final Dio _dio;

  /// Where to cache, for a caller that knows — a test with a temp directory.
  /// Null asks the platform, which is what the app does.
  final Directory? _given;

  /// How much of the disk the cache may hold before the least recently read
  /// files start going.
  final int budget;

  final Map<String, Future<Map<TrackKind, TrackRef>>> _rows =
      <String, Future<Map<TrackKind, TrackRef>>>{};

  Future<Directory?>? _cacheDirectory;

  /// What the service says about every family of one protein.
  Future<Map<TrackKind, TrackRef>> tracksOf(String slug) =>
      _rows[slug] ??= _fetchRows(slug).catchError((
        Object error,
        StackTrace stack,
      ) {
        _rows.remove(slug);
        Error.throwWithStackTrace(error, stack);
      });

  @override
  Future<Uint8List> read(String slug, TrackKind kind) async {
    final TrackRef ref =
        (await tracksOf(slug))[kind] ?? const TrackRef(state: TrackState.absent);
    final String? url = ref.url;
    if (ref.state != TrackState.ready || url == null) {
      throw TrackApiException(
        slug: slug,
        kind: kind.wire,
        state: ref.state.wire,
        reason: ref.reason,
      );
    }
    return _fetch(url, ref.sha256);
  }

  /// Read by the same function the catalog rows are read with, so a family this
  /// calls ready and a family the catalog called ready cannot come to mean two
  /// different things.
  Future<Map<TrackKind, TrackRef>> _fetchRows(String slug) async {
    Map<String, dynamic> body;
    try {
      body = await _api.getJson('/protein/${Uri.encodeComponent(slug)}/tracks');
    } on Object catch (error) {
      // An authoritative client error (including a removed protein) must not
      // be hidden by yesterday's rows. Only service/transport failures fall back.
      if (error is ServerApiException &&
          error.statusCode != null && error.statusCode! < 500) {
        rethrow;
      }
      final File? file = await _rowFile(slug);
      try {
        if (file != null && await file.exists()) {
          final Map<TrackKind, TrackRef> cached = tracksFromJson(
            jsonDecode(await file.readAsString()) as Map<String, dynamic>,
          );
          // Do not memoise an offline answer: the next read tries the service.
          unawaited(_rows.remove(slug));
          return cached;
        }
      } on Object catch (cacheError) {
        _note('could not read track rows', cacheError);
      }
      rethrow;
    }
    final Map<TrackKind, TrackRef> parsed = tracksFromJson(body);
    final File? file = await _rowFile(slug);
    if (file != null) {
      try {
        await file.parent.create(recursive: true);
        final File pending = File('${file.path}.part');
        await pending.writeAsString(jsonEncode(body), flush: true);
        await pending.rename(file.path);
      } on Object catch (error) {
        _note('could not cache track rows', error);
      }
    }
    return parsed;
  }

  Future<File?> _rowFile(String slug) async {
    final Directory? directory = await (_cacheDirectory ??= _open());
    return directory == null ? null : File(
      '${directory.parent.path}/track_rows/${Uri.encodeComponent(slug)}.json',
    );
  }

  /// The cached bytes if they are there, and the network's if they are not.
  ///
  /// [digest] names the file, so a re-baked track is a different name and there
  /// is no invalidation to get wrong. It is not recomputed over the payload:
  /// hashing 9.5 MB costs a frame, and every one of these parsers already
  /// refuses a payload whose header does not match the protein it was asked
  /// for, which is the check that matters.
  Future<Uint8List> _fetch(String url, String? digest) async {
    final File? file = await _cacheFile(digest);
    if (file != null) {
      final Uint8List? held = await _readCached(file);
      if (held != null) {
        return held;
      }
    }
    final Uint8List bytes = await _download(url);
    if (file != null) {
      // Awaited. A 9.5 MB write is tens of milliseconds against a fetch that
      // took seconds and a parse that takes hundreds, and the alternative is a
      // cache whose contents nothing can wait for — including the next read.
      await _store(file, bytes);
    }
    return bytes;
  }

  Future<Uint8List> _download(String url) async {
    try {
      final Response<List<int>> response = await _dio.get<List<int>>(
        url,
        // Stated per request rather than trusted from the Dio's defaults, so a
        // client handed in from outside cannot quietly decode a track as JSON.
        options: Options(responseType: ResponseType.bytes),
      );
      final List<int>? data = response.data;
      if (data == null) {
        throw const UnknownApiException();
      }
      return data is Uint8List ? data : Uint8List.fromList(data);
    } on DioException catch (error) {
      throw apiExceptionFrom(error);
    }
  }

  /// Every filesystem call below answers null or does nothing when there is no
  /// filesystem to call, and none of them throws — the convention
  /// `CatalogLocalDataSource` set, for the same reason: there is no documents
  /// directory under `flutter test`, and a cache is a head start rather than a
  /// dependency. A track loads without one; it just loads again next time.
  Future<File?> _cacheFile(String? digest) async {
    if (digest == null || digest.isEmpty) {
      return null;
    }
    final Directory? directory = await (_cacheDirectory ??= _open());
    return directory == null ? null : File('${directory.path}/$digest');
  }

  Future<Directory?> _open() async {
    try {
      final Directory directory =
          _given ??
          Directory('${(await getApplicationCacheDirectory()).path}/tracks');
      return await directory.create(recursive: true);
    } on Object catch (error) {
      _note('has nowhere to cache', error);
      return null;
    }
  }

  Future<Uint8List?> _readCached(File file) async {
    try {
      if (!file.existsSync()) {
        return null;
      }
      final Uint8List bytes = await file.readAsBytes();
      // Touched on the way out, so the eviction order is what was last *read*
      // rather than what was last written. `accessed` would say the same thing
      // where the filesystem keeps it, and these do not.
      unawaited(_touch(file));
      return bytes;
    } on Object catch (error) {
      _note('could not read a cached track', error);
      return null;
    }
  }

  Future<void> _store(File file, Uint8List bytes) async {
    try {
      // Written beside and renamed, so a process killed mid-write leaves a
      // partial file under a name nothing looks for. A truncated payload at the
      // digest's own path would be served as if it were the payload.
      final File pending = File('${file.path}.part');
      await pending.writeAsBytes(bytes, flush: true);
      await pending.rename(file.path);
      await _evict(file.parent);
    } on Object catch (error) {
      _note('could not cache a track', error);
    }
  }

  Future<void> _touch(File file) async {
    try {
      await file.setLastModified(DateTime.now());
    } on Object catch (error) {
      _note('could not touch a cached track', error);
    }
  }

  /// Drops the least recently read files until the cache is back under
  /// [budget]. After a write rather than before a read: a reader waiting on a
  /// track should not also be waiting on a directory listing.
  Future<void> _evict(Directory directory) async {
    try {
      final List<(File, FileStat)> held = <(File, FileStat)>[];
      int total = 0;
      for (final FileSystemEntity entity in directory.listSync()) {
        if (entity is File) {
          final FileStat stat = entity.statSync();
          total += stat.size;
          held.add((entity, stat));
        }
      }
      if (total <= budget) {
        return;
      }
      held.sort(
        ((File, FileStat) a, (File, FileStat) b) =>
            a.$2.modified.compareTo(b.$2.modified),
      );
      for (final (File file, FileStat stat) in held) {
        if (total <= budget) {
          return;
        }
        file.deleteSync();
        total -= stat.size;
      }
    } on Object catch (error) {
      _note('could not trim the cache', error);
    }
  }

  void _note(String what, Object error) {
    assert(() {
      // The first line only. A missing plugin reports itself in six lines of
      // advice about binding initialisation, which is the ordinary condition
      // under `flutter test` rather than news.
      debugPrint('TrackClient: $what — ${error.toString().split('\n').first}');
      return true;
    }(), 'debug-only diagnostic');
  }
}
