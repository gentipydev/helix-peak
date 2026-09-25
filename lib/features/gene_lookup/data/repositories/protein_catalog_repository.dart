import 'package:flutter/foundation.dart';

import '../../../../core/network/api_client.dart';
import '../../domain/entities/protein_ranking.dart';
import '../../domain/entities/protein_target.dart';
import '../datasources/catalog_local_data_source.dart';

enum CatalogStatus { loading, ready, failed }

/// The served catalog, cached on device. Rows and status notify independently;
/// the repository itself stays a plain object for RepositoryProvider.
final class ProteinCatalogRepository {
  ProteinCatalogRepository(
    this._api, [
    this._cache = const CatalogLocalDataSource(),
  ]);

  /// One page is 200 and the catalog is twenty, so this is a ceiling rather
  /// than a page size anyone will reach today.
  static const int _pageSize = 200;

  /// A cursor that stops advancing would page forever. It cannot happen while
  /// the server keys on slug, which is unique — so this is a guard against a
  /// future server bug, not against the present one.
  static const int _maxPages = 50;

  final ApiClient _api;

  /// Null where there is nowhere to cache — a test, or a platform with no
  /// documents directory. The rows still load; only the head start is gone.
  final CatalogLocalDataSource? _cache;

  final ValueNotifier<List<ProteinTarget>> _rows =
      ValueNotifier<List<ProteinTarget>>(<ProteinTarget>[]);
  final ValueNotifier<CatalogStatus> _status =
      ValueNotifier<CatalogStatus>(CatalogStatus.loading);
  final Map<String, ProteinTarget> _details = <String, ProteinTarget>{};

  static const String fallbackSlug = 'insulin';
  ValueListenable<CatalogStatus> get status => _status;

  /// Every protein, in reading order.
  List<ProteinTarget> get all => _rows.value;

  /// Fires when a refresh replaces the rows, and not otherwise.
  ValueListenable<List<ProteinTarget>> get rows => _rows;

  void dispose() {
    _rows.dispose();
    _status.dispose();
  }

  Future<ProteinTarget> protein(String slug) async {
    final ProteinTarget? held = bySlug(slug);
    if (held != null) {
      return held;
    }
    final ProteinTarget target = ProteinTarget.fromJson(
      await _api.getJson('/protein/${Uri.encodeComponent(slug)}'),
    );
    _details[slug] = target;
    return target;
  }

  ProteinTarget? bySlug(String slug) {
    for (final ProteinTarget target in _rows.value) {
      if (target.slug == slug) {
        return target;
      }
    }
    return _details[slug];
  }

  /// Search, ranked exactly as it was when the catalog was a const list.
  List<ProteinTarget> matching(String query) => rank(_rows.value, query);

  /// Restore the last complete catalog before the first frame.
  Future<void> hydrate() async {
    try {
      final List<Map<String, dynamic>>? cached = await _cache?.read();
      if (cached != null) {
        _adopt(cached);
        _status.value = CatalogStatus.ready;
      }
    } on Object catch (error) {
      _note('could not hydrate', error);
    }
  }

  /// Re-reads `/catalog` and keeps what comes back.
  ///
  /// A failure leaves the rows alone. The service answers 503 for "nobody could
  /// look" and it cold-starts in about forty-four seconds, so an unreachable
  /// backend has to mean the reader keeps the catalog they had — never an empty
  /// screen, and never "no such protein".
  Future<void> refresh() async {
    _status.value = CatalogStatus.loading;
    try {
      final List<Map<String, dynamic>> served = await _page();
      _adopt(served);
      _status.value = CatalogStatus.ready;
      await _cache?.write(served);
    } on Object catch (error) {
      _status.value = CatalogStatus.failed;
      _note('kept the rows it had', error);
    }
  }

  Future<List<Map<String, dynamic>>> _page() async {
    final List<Map<String, dynamic>> found = <Map<String, dynamic>>[];
    String? cursor;
    for (int page = 0; page < _maxPages; page++) {
      final Map<String, dynamic> body = await _api.getJson(
        '/catalog',
        query: <String, dynamic>{
          'limit': _pageSize,
          'cursor': ?cursor,
        },
      );
      for (final Object? row in body['proteins'] as List<dynamic>) {
        found.add(row as Map<String, dynamic>);
      }
      final String? next = body['next'] as String?;
      if (next == null || next == cursor) {
        break;
      }
      cursor = next;
    }
    return found;
  }

  /// Turns served rows into targets and takes them as the catalog.
  ///
  /// The service pages by slug and therefore orders by slug, because a keyset
  /// cursor is only stable on the column it compares. The reading order travels
  /// as `catalog_order` on each row instead, and is restored here — nulls last,
  /// which is where a protein resolved on demand belongs: it has no place in a
  /// sequence someone chose.
  void _adopt(List<Map<String, dynamic>> rows) {
    final List<Map<String, dynamic>> ordered = <Map<String, dynamic>>[...rows]
      ..sort(_byReadingOrder);
    // Parse the whole page before replacing a usable catalog or its cache.
    _rows.value = <ProteinTarget>[
      for (final Map<String, dynamic> row in ordered)
        ProteinTarget.fromJson(row),
    ];
  }

  static int _byReadingOrder(
    Map<String, dynamic> a,
    Map<String, dynamic> b,
  ) {
    final int? left = a['catalog_order'] as int?;
    final int? right = b['catalog_order'] as int?;
    if (left != right) {
      if (left == null) {
        return 1;
      }
      if (right == null) {
        return -1;
      }
      return left.compareTo(right);
    }
    final int byDisplay = (a['display'] as String? ?? '').compareTo(
      b['display'] as String? ?? '',
    );
    return byDisplay != 0
        ? byDisplay
        : (a['slug'] as String? ?? '').compareTo(b['slug'] as String? ?? '');
  }

  void _note(String what, Object error) {
    assert(() {
      debugPrint('ProteinCatalogRepository: $what — $error');
      return true;
    }(), 'debug-only diagnostic');
  }
}
