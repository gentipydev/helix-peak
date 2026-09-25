import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/core/network/api_exception.dart';
import 'package:helixpeek/features/gene_lookup/domain/entities/gene_record.dart';
import 'package:helixpeek/features/gene_lookup/domain/entities/protein_catalog.dart';
import 'package:helixpeek/features/gene_lookup/domain/repositories/gene_repository.dart';
import 'package:helixpeek/features/gene_lookup/domain/usecases/fetch_gene.dart';
import 'package:helixpeek/features/gene_lookup/presentation/cubit/gene_lookup_cubit.dart';
import 'package:helixpeek/features/gene_lookup/presentation/cubit/gene_lookup_state.dart';
import 'package:mocktail/mocktail.dart';

// FetchGene is a final class and cannot be implemented outside its library, so
// the mock goes one layer down at the repository port.
class _MockGeneRepository extends Mock implements GeneRepository {}

const GeneRecord _record = GeneRecord(
  gene: 'INS',
  start: 4986,
  end: 6416,
  sequence: 'ACGT',
  exons: <Exon>[],
  peptides: <Peptide>[],
);

void main() {
  late _MockGeneRepository repository;

  // `any()` stands in for a GeneQuery, which mocktail needs a real one of.
  setUpAll(() => registerFallbackValue(ProteinCatalog.insulin.query));

  setUp(() => repository = _MockGeneRepository());

  GeneLookupCubit buildCubit() => GeneLookupCubit(FetchGene(repository));

  void stubSuccess() {
    when(
      () => repository.fetchGene(any()),
    ).thenAnswer((_) async => _record);
  }

  void stubFailure(Object error) {
    when(
      () => repository.fetchGene(any()),
    ).thenThrow(error);
  }

  group('GeneLookupCubit', () {
    blocTest<GeneLookupCubit, GeneLookupState>(
      'emits [loading, success] when the fetch succeeds',
      setUp: stubSuccess,
      build: buildCubit,
      act: (GeneLookupCubit cubit) => cubit.load(ProteinCatalog.insulin.query),
      expect: () => <Matcher>[
        isA<GeneLookupLoading>(),
        isA<GeneLookupSuccess>().having(
          (GeneLookupSuccess s) => s.record.gene,
          'gene',
          'INS',
        ),
      ],
    );

    blocTest<GeneLookupCubit, GeneLookupState>(
      'asks the repository for the query it was given',
      setUp: stubSuccess,
      build: buildCubit,
      act: (GeneLookupCubit cubit) => cubit.load(ProteinCatalog.insulin.query),
      verify: (_) {
        verify(
          () => repository.fetchGene(ProteinCatalog.insulin.query),
        ).called(1);
      },
    );

    blocTest<GeneLookupCubit, GeneLookupState>(
      'surfaces an ApiException message verbatim',
      setUp: () => stubFailure(
        const ServerApiException(statusCode: 404, detail: 'No gene found.'),
      ),
      build: buildCubit,
      act: (GeneLookupCubit cubit) => cubit.load(ProteinCatalog.insulin.query),
      expect: () => <Matcher>[
        isA<GeneLookupLoading>(),
        isA<GeneLookupFailure>().having(
          (GeneLookupFailure f) => f.message,
          'message',
          'No gene found.',
        ),
      ],
    );

    blocTest<GeneLookupCubit, GeneLookupState>(
      'falls back to a generic message for an unexpected error',
      setUp: () => stubFailure(StateError('boom')),
      build: buildCubit,
      act: (GeneLookupCubit cubit) => cubit.load(ProteinCatalog.insulin.query),
      expect: () => <Matcher>[
        isA<GeneLookupLoading>(),
        isA<GeneLookupFailure>().having(
          (GeneLookupFailure f) => f.message,
          'message',
          contains('Something went wrong'),
        ),
      ],
    );

    blocTest<GeneLookupCubit, GeneLookupState>(
      'retry repeats the last query',
      setUp: stubSuccess,
      build: buildCubit,
      act: (GeneLookupCubit cubit) async {
        await cubit.load(ProteinCatalog.insulin.query);
        await cubit.retry();
      },
      verify: (_) {
        verify(
          () => repository.fetchGene(ProteinCatalog.insulin.query),
        ).called(2);
      },
    );

    blocTest<GeneLookupCubit, GeneLookupState>(
      'retry does nothing before a first load',
      build: buildCubit,
      act: (GeneLookupCubit cubit) => cubit.retry(),
      expect: () => <Matcher>[],
      verify: (_) => verifyNever(
        () => repository.fetchGene(any()),
      ),
    );
  });
}
