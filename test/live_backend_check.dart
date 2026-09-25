// An end-to-end check against a running backend, which in turn calls NCBI.
//
// Opt-in, like the render checks: it is skipped unless LIVE_BACKEND is set, so
// the default `flutter test` stays offline and deterministic.
//
//   cd helix-peek-backend && .venv/bin/uvicorn app.main:app &
//   LIVE_BACKEND=http://localhost:8000 flutter test test/live_backend_check.dart
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/core/network/api_client.dart';
import 'package:helixpeek/core/network/api_exception.dart';
import 'package:helixpeek/core/network/dio_api_client.dart';
import 'package:helixpeek/core/network/track_client.dart';
import 'package:helixpeek/features/gene_lookup/data/datasources/gene_remote_data_source.dart';
import 'package:helixpeek/features/gene_lookup/data/repositories/gene_repository_impl.dart';
import 'package:helixpeek/features/gene_lookup/data/repositories/impact_explanation_repository.dart';
import 'package:helixpeek/features/gene_lookup/domain/entities/gene_clinvar.dart';
import 'package:helixpeek/features/gene_lookup/domain/entities/gene_impact.dart';
import 'package:helixpeek/features/gene_lookup/domain/entities/gene_record.dart';
import 'package:helixpeek/features/gene_lookup/domain/entities/impact_explanations.dart';
import 'package:helixpeek/features/gene_lookup/domain/entities/protein_catalog.dart';
import 'package:helixpeek/features/gene_lookup/domain/entities/protein_constraint.dart';
import 'package:helixpeek/features/gene_lookup/domain/entities/protein_target.dart';
import 'package:helixpeek/features/gene_lookup/domain/entities/protein_track.dart';
import 'package:helixpeek/features/gene_lookup/domain/usecases/fetch_gene.dart';

void main() {
  final String baseUrl = Platform.environment['LIVE_BACKEND'] ?? '';

  /// Every track of every protein, fetched and parsed the way the walk does.
  ///
  /// This is the migration's end-to-end proof, and there is no offline stand-in
  /// for it: the four families left the bundle, so the only thing that can say
  /// they still load is fetching them. It parses each payload with the same
  /// `load` the page calls, so a track that arrives and does not match the
  /// protein it was asked for fails here rather than on a phone.
  test('every track loads from storage and parses', () async {
    if (baseUrl.isEmpty) {
      markTestSkipped('set LIVE_BACKEND to run against a live backend');
      return;
    }
    final Directory cache = Directory.systemTemp.createTempSync('helixpeek-live');
    addTearDown(() => cache.deleteSync(recursive: true));
    final TrackClient tracks = TrackClient(
      DioApiClient(baseUrl: baseUrl, timeout: const Duration(seconds: 30)),
      cache: cache,
    );

    int bytes = 0;
    for (final ProteinTarget target in ProteinCatalog.all) {
      final ProteinConstraint constraint = await ProteinConstraint.load(
        target,
        tracks: tracks,
      );
      expect(constraint.positions.length, target.facts.residues, reason: target.slug);

      final GeneImpact impact = await GeneImpact.load(target, tracks: tracks);
      expect(impact.gene, target.gene, reason: target.slug);

      final GeneClinVar clinvar = await GeneClinVar.load(target, tracks: tracks);
      expect(clinvar.gene, target.gene, reason: target.slug);
      expect(clinvar.matchesImpact(impact), isTrue, reason: target.slug);

      // The fold is bytes here rather than a Node: realizing one needs a GPU
      // context, which `flutter test` has not got. What this proves is that the
      // container is reachable and is an `.fsceneb` — `check_assets.py
      // --against` is what holds its node names to the catalog.
      final Uint8List fold = await tracks.read(target.slug, TrackKind.structure);
      expect(utf8.decode(fold.sublist(0, 4)), 'FSCB', reason: target.slug);

      bytes += fold.length;
    }
    expect(bytes, greaterThan(0));

    // Every payload is now on disk under its digest, and a second read of the
    // largest one comes off it: 9.5 MB that does not cross the wire twice.
    final int held = cache
        .listSync()
        .whereType<File>()
        .fold(0, (int sum, File f) => sum + f.lengthSync());
    expect(held, greaterThan(30 * 1024 * 1024));
    await GeneClinVar.load(ProteinCatalog.dystrophin, tracks: tracks);
  }, timeout: const Timeout(Duration(minutes: 10)));

  test('AVI explanations use the same validated contract over HTTP', () async {
    if (baseUrl.isEmpty) {
      markTestSkipped('set LIVE_BACKEND to run against a live backend');
      return;
    }
    final repository = ImpactExplanationRepository(
      DioApiClient(baseUrl: baseUrl, timeout: const Duration(seconds: 30)),
    );
    for (final target in ProteinCatalog.all.where(
      (t) => t.impactExplanationsAvailable,
    )) {
      final track = GeneImpact.fromJson(
        jsonDecode(File(target.impactAsset).readAsStringSync())
            as Map<String, dynamic>,
        target,
      );
      final data = await repository.load(track);
      final base = track.at(track.start)!;
      final request = ImpactExplanationRequest.forAllele(
        track,
        base.position,
        base.wildtype,
        base.ranked.first.base,
      )!;
      expect(data.at(request), isNotNull);
      expect(data.atlasUrl(request).host, 'deepmind.google.com');
    }
  });

  test('fetches human insulin through the real client stack', () async {
    if (baseUrl.isEmpty) {
      markTestSkipped('set LIVE_BACKEND to run against a live backend');
      return;
    }

    final ApiClient client = DioApiClient(
      baseUrl: baseUrl,
      timeout: const Duration(seconds: 30),
    );
    final FetchGene fetchGene = FetchGene(
      GeneRepositoryImpl(GeneRemoteDataSourceImpl(client)),
    );

    final GeneRecord record = await fetchGene(ProteinCatalog.insulin.query);

    expect(record.gene, 'INS');
    expect(record.start, 4986);
    expect(record.lengthBp, 1431);
    expect(record.exons.length, 3);
    expect(record.protein!.product, 'insulin preproprotein');
    expect(record.peptides.map((Peptide p) => p.translation).toList(), <String>[
      'FVNQHLCGSHLVEALYLVCGERGFFYTPKT',
      'EAEDLQVGQVELGGGPGAGSLQPLALEGSLQ',
      'GIVEQCCTSICSLYQLENYCN',
    ]);
  }, timeout: const Timeout(Duration(seconds: 60)));

  test('surfaces the backend detail for an unknown gene', () async {
    if (baseUrl.isEmpty) {
      markTestSkipped('set LIVE_BACKEND to run against a live backend');
      return;
    }

    final GeneRemoteDataSource source = GeneRemoteDataSourceImpl(
      DioApiClient(baseUrl: baseUrl, timeout: const Duration(seconds: 30)),
    );

    await expectLater(
      source.fetchGene(accession: 'NG_007114', gene: 'BRCA1'),
      throwsA(
        isA<ServerApiException>()
            .having((ServerApiException e) => e.statusCode, 'statusCode', 404)
            .having(
              (ServerApiException e) => e.userMessage,
              'userMessage',
              contains('BRCA1'),
            ),
      ),
    );
  }, timeout: const Timeout(Duration(seconds: 60)));
}
