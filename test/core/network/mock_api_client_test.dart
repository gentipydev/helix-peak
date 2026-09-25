import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/core/network/api_client.dart';
import 'package:helixpeek/core/network/api_exception.dart';
import 'package:helixpeek/core/network/mock_api_client.dart';
import 'package:helixpeek/features/gene_lookup/data/datasources/gene_remote_data_source.dart';
import 'package:helixpeek/features/gene_lookup/data/repositories/gene_repository_impl.dart';
import 'package:helixpeek/features/gene_lookup/domain/entities/gene_query.dart';
import 'package:helixpeek/features/gene_lookup/domain/entities/gene_record.dart';
import 'package:helixpeek/features/gene_lookup/domain/entities/protein_catalog.dart';
import 'package:helixpeek/features/gene_lookup/domain/usecases/fetch_gene.dart';

/// The assertions below are the ones `test/live_backend_check.dart` makes
/// against the running service. Holding the fake to the same ones is the whole
/// claim of mock mode: the record the app draws is the record the backend
/// sends, so the flow a mock build exercises is the real flow.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockApiClient client;

  setUp(() => client = MockApiClient(latency: Duration.zero));

  FetchGene fetchGeneOver(ApiClient client) =>
      FetchGene(GeneRepositoryImpl(GeneRemoteDataSourceImpl(client)));

  group('MockApiClient', () {
    test('fetches human insulin through the real client stack', () async {
      final GeneRecord record = await fetchGeneOver(
        client,
      )(ProteinCatalog.insulin.query);

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
    });

    test('parses the same record on a retry', () async {
      final FetchGene fetchGene = fetchGeneOver(client);

      final GeneRecord first = await fetchGene(ProteinCatalog.insulin.query);
      final GeneRecord second = await fetchGene(ProteinCatalog.insulin.query);

      expect(second.sequence, first.sequence);
      expect(second.exons.length, first.exons.length);
    });

    test('surfaces a backend-shaped detail for an unknown gene', () async {
      final GeneRemoteDataSource source = GeneRemoteDataSourceImpl(client);

      await expectLater(
        source.fetchGene(
        const GeneQuery(slug: 'brca1', accession: 'NG_007114', gene: 'BRCA1'),
      ),
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
    });

    test('matches the gene exactly, as extract_gene does', () async {
      // "INS-IGF2" overlaps INS in NG_007114, so a prefix match here would be
      // the same bug the backend's parser documents avoiding.
      await expectLater(
        client.getJson('/gene/NG_007114/INS-IGF2'),
        throwsA(isA<ServerApiException>()),
      );
      await expectLater(
        client.getJson('/gene/NG_007114/ins'),
        throwsA(isA<ServerApiException>()),
      );
    });

    test('404s an unknown record', () async {
      await expectLater(
        client.getJson('/gene/NG_000000/INS'),
        throwsA(
          isA<ServerApiException>().having(
            (ServerApiException e) => e.userMessage,
            'userMessage',
            contains('NG_000000'),
          ),
        ),
      );
    });

    test('404s a route the service does not have', () async {
      await expectLater(
        client.getJson('/gene'),
        throwsA(
          isA<ServerApiException>().having(
            (ServerApiException e) => e.statusCode,
            'statusCode',
            404,
          ),
        ),
      );
    });

    test('405s a POST, since the service exposes no POST route', () async {
      await expectLater(
        client.postJson('/gene', body: <String, dynamic>{}),
        throwsA(
          isA<ServerApiException>().having(
            (ServerApiException e) => e.statusCode,
            'statusCode',
            405,
          ),
        ),
      );
    });

    test('waits the configured latency before answering', () async {
      final MockApiClient slow = MockApiClient(
        latency: const Duration(milliseconds: 120),
      );
      final Stopwatch stopwatch = Stopwatch()..start();

      await slow.getJson('/gene/NG_007114/INS');

      expect(stopwatch.elapsedMilliseconds, greaterThanOrEqualTo(100));
    });

    test('defaults to a latency the loading state is visible at', () {
      expect(
        MockApiClient().latency,
        greaterThanOrEqualTo(const Duration(milliseconds: 300)),
      );
    });
  });
}
