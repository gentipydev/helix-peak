import 'package:flutter/foundation.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_exception.dart';
import '../../domain/entities/protein_catalog.dart';
import '../../domain/entities/protein_ranking.dart';
import '../../domain/entities/protein_target.dart';
import '../datasources/catalog_local_data_source.dart';

/// The proteins the app can walk, from the service, cached on device.
///
/// **It answers synchronously and it always answers.** It is constructed
/// already holding [ProteinCatalog.all], so [bySlug], [byPath], [matching] and
/// [fallback] never return nothing-because-loading and never need an `await`.
/// That is the whole reason this is a plain object rather than a cubit: the
/// router builds `appRouter` as a top-level global outside any widget tree and
/// resolves a slug inside a `Widget` builder, and the search screen ranks
/// inside `build` on every keystroke. Neither can take an async boundary, and
/// with a seeded list neither has to.
///
/// [load] then replaces the rows, cache first and network second. A reader who
/// never waits for it sees the twenty bundled proteins, which is what the app
/// showed before there was a service at all.
///
/// The rows are what changes, so [rows] is the [Listenable] and this is not
/// one. A `RepositoryProvider` holding a `Listenable` is a mistake `provider`
/// asserts on by name, and rightly: it would not rebuild anything that read it.
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
      ValueNotifier<List<ProteinTarget>>(ProteinCatalog.all);

  /// Every protein, in reading order.
  List<ProteinTarget> get all => _rows.value;

  /// Fires when a refresh replaces the rows, and not otherwise.
  ValueListenable<List<ProteinTarget>> get rows => _rows;

  void dispose() => _rows.dispose();

  /// The one the home screen's chevron leads to, and what `/gene` with no slug
  /// means. Insulin by name, so that reordering the catalog cannot move it, and
  /// the bundled row if the service has somehow stopped serving it.
  ProteinTarget get fallback =>
      bySlug(ProteinCatalog.fallback.slug) ?? ProteinCatalog.fallback;

  ProteinTarget? bySlug(String slug) {
    for (final ProteinTarget target in _rows.value) {
      if (target.slug == slug) {
        return target;
      }
    }
    return null;
  }

  /// The target a `/gene/{accession}/{gene}` path is asking for, or null.
  ProteinTarget? byPath(String accession, String gene) {
    for (final ProteinTarget target in _rows.value) {
      if (target.accession == accession && target.gene == gene) {
        return target;
      }
    }
    return null;
  }

  /// Search, ranked exactly as it was when the catalog was a const list.
  List<ProteinTarget> matching(String query) => rank(_rows.value, query);

  /// The cached rows, then the served ones. Safe to call more than once.
  Future<void> load() async {
    final List<Map<String, dynamic>>? cached = await _cache?.read();
    if (cached != null) {
      _adopt(cached);
    }
    await refresh();
  }

  /// Re-reads `/catalog` and keeps what comes back.
  ///
  /// A failure leaves the rows alone. The service answers 503 for "nobody could
  /// look" and it cold-starts in about forty-four seconds, so an unreachable
  /// backend has to mean the reader keeps the catalog they had — never an empty
  /// screen, and never "no such protein".
  Future<void> refresh() async {
    try {
      final List<Map<String, dynamic>> served = await _page();
      if (served.isEmpty) {
        return;
      }
      _adopt(served);
      await _cache?.write(served);
    } on ApiException catch (error) {
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
      for (final Object? row in body['proteins'] as List<dynamic>? ??
          <dynamic>[]) {
        if (row is Map<String, dynamic>) {
          found.add(row);
        }
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
    final List<ProteinTarget> found = <ProteinTarget>[];
    for (final Map<String, dynamic> row in ordered) {
      try {
        found.add(
          ProteinTarget.fromJson(
            row,
            seed: ProteinCatalog.bySlug(row['slug'] as String? ?? ''),
          ),
        );
      } on Object catch (error) {
        // A row the walk cannot draw is left out rather than carried. Today
        // that is only a protein with no structure; the fold page has no
        // rendering for its absence yet.
        _note('left out ${row['slug']}', error);
      }
    }
    if (found.isEmpty) {
      return;
    }
    _rows.value = found;
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
