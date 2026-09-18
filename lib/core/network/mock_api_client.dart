import 'dart:convert';

import 'package:flutter/services.dart';

import '../../features/gene_lookup/domain/entities/protein_catalog.dart';
import '../../features/gene_lookup/domain/entities/protein_target.dart';
import 'api_client.dart';
import 'api_exception.dart';

/// An [ApiClient] that answers from bundled fixtures instead of the network.
///
/// It sits at the transport seam rather than higher up on purpose. Everything
/// above it — `GeneRemoteDataSourceImpl`, `GeneRecordDto.fromJson`, the
/// DTO→entity mappers, `GeneRepositoryImpl`, `FetchGene`, `GeneLookupCubit` and
/// the [ApiException] → user-message translation — stays the real production
/// code, running exactly as it does against the live service. Only the socket
/// is gone. A fake one layer up would skip the JSON parsing, which is most of
/// what a mock build exists to check.
///
/// It behaves like the FastAPI service, not like a stub: it round-trips before
/// answering, matches the gene exactly the way `extract_gene` does, and fails
/// with the wording the backend fails with.
final class MockApiClient implements ApiClient {
  MockApiClient({
    AssetBundle? bundle,
    this.latency = const Duration(milliseconds: 700),
  }) : _bundle = bundle ?? rootBundle;

  static final RegExp _genePath = RegExp(r'^/gene/([^/]+)/([^/]+)$');

  final AssetBundle _bundle;

  /// How long a call takes before it answers.
  ///
  /// Not decoration: the live request goes on to NCBI and takes seconds, so
  /// `LoadingView(label: 'FETCHING NG_007114')` is part of the flow being
  /// checked. Answering instantly would make the mock build behave differently
  /// from the app it stands in for.
  final Duration latency;

  /// Read once per record, then decoded again per call.
  ///
  /// Caching the decoded map instead would hand every caller the same mutable
  /// object, where a real response is fresh bytes each time — and the callers
  /// do edit it: `anatomy_fixture.dart` builds its contrasting genes by
  /// deleting keys from a decoded payload. Dystrophin's fifty kilobytes is the
  /// largest of them, and still not worth a shared-mutable-state bug.
  final Map<String, Future<String>> _payloads = <String, Future<String>>{};

  @override
  Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, dynamic>? query,
  }) async {
    await Future<void>.delayed(latency);

    final RegExpMatch? match = _genePath.firstMatch(path);
    if (match == null) {
      // What FastAPI answers for a route it does not have.
      throw const ServerApiException(statusCode: 404, detail: 'Not Found');
    }

    final String id = match.group(1)!;
    final String name = match.group(2)!;
    // A fake server knows what it was given. Ten records are bundled, and a
    // gene that is not one of them correctly 404s rather than serving some
    // other protein under the wrong name.
    final ProteinTarget? target = ProteinCatalog.byPath(id, name);
    if (target == null) {
      // Verbatim from the backend's router, so `userMessage` reads the same.
      throw ServerApiException(
        statusCode: 404,
        detail: "No gene '$name' in record '$id'.",
      );
    }

    return _record(target);
  }

  @override
  Future<Map<String, dynamic>> postJson(
    String path, {
    required Map<String, dynamic> body,
  }) async {
    await Future<void>.delayed(latency);
    // The service exposes no POST route, so this is the honest answer rather
    // than an UnimplementedError the app has no way to interpret.
    throw const ServerApiException(
      statusCode: 405,
      detail: 'Method Not Allowed',
    );
  }

  Future<Map<String, dynamic>> _record(ProteinTarget target) async {
    final String raw = await (_payloads[target.slug] ??= _bundle.loadString(
      target.mockAsset,
    ));
    return jsonDecode(raw) as Map<String, dynamic>;
  }
}
