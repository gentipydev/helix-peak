// An end-to-end check against a running backend, which in turn calls NCBI.
//
// Opt-in, like the render checks: it is skipped unless LIVE_BACKEND is set, so
// the default `flutter test` stays offline and deterministic.
//
//   cd helix-peak-backend && .venv/bin/uvicorn app.main:app &
//   LIVE_BACKEND=http://localhost:8000 flutter test test/live_backend_check.dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeak/core/network/api_client.dart';
import 'package:helixpeak/core/network/api_exception.dart';
import 'package:helixpeak/core/network/dio_api_client.dart';
import 'package:helixpeak/features/gene_lookup/data/datasources/gene_remote_data_source.dart';
import 'package:helixpeak/features/gene_lookup/data/repositories/gene_repository_impl.dart';
import 'package:helixpeak/features/gene_lookup/domain/entities/gene_record.dart';
import 'package:helixpeak/features/gene_lookup/domain/entities/protein_catalog.dart';
import 'package:helixpeak/features/gene_lookup/domain/usecases/fetch_gene.dart';

void main() {
  final String baseUrl = Platform.environment['LIVE_BACKEND'] ?? '';

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
    expect(
      record.peptides.map((Peptide p) => p.translation).toList(),
      <String>[
        'FVNQHLCGSHLVEALYLVCGERGFFYTPKT',
        'EAEDLQVGQVELGGGPGAGSLQPLALEGSLQ',
        'GIVEQCCTSICSLYQLENYCN',
      ],
    );
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
