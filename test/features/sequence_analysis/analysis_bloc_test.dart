import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeak/core/network/api_exception.dart';
import 'package:helixpeak/features/sequence_analysis/domain/entities/analysis_result.dart';
import 'package:helixpeak/features/sequence_analysis/domain/entities/nucleotide_counts.dart';
import 'package:helixpeak/features/sequence_analysis/domain/entities/sequence_input.dart';
import 'package:helixpeak/features/sequence_analysis/domain/entities/sequence_type.dart';
import 'package:helixpeak/features/sequence_analysis/domain/repositories/sequence_repository.dart';
import 'package:helixpeak/features/sequence_analysis/presentation/bloc/analysis_bloc.dart';
import 'package:helixpeak/features/sequence_analysis/presentation/bloc/analysis_event.dart';
import 'package:helixpeak/features/sequence_analysis/presentation/bloc/analysis_state.dart';
import 'package:mocktail/mocktail.dart';

class _MockSequenceRepository extends Mock implements SequenceRepository {}

/// 19 bases — comfortably over the minimum length.
const String _validSequence = 'ATGCGTAGCTAGCTAGCTA';

AnalysisResult _resultFor(SequenceInput input) => AnalysisResult(
      id: 'test',
      input: input,
      counts: NucleotideCounts.fromBases(input.bases),
      meltingTemperatureCelsius: 58.2,
      molecularWeightDaltons: 5871.4,
      generatedAt: DateTime.utc(2026),
    );

void main() {
  late _MockSequenceRepository repository;

  setUpAll(() {
    registerFallbackValue(
      const SequenceInput(bases: 'A', sequenceType: SequenceType.dna),
    );
  });

  setUp(() => repository = _MockSequenceRepository());

  group('AnalysisBloc', () {
    blocTest<AnalysisBloc, AnalysisState>(
      'emits [loading, success] when the repository succeeds',
      setUp: () {
        when(() => repository.analyse(any())).thenAnswer(
          (Invocation invocation) async => _resultFor(
            invocation.positionalArguments.first as SequenceInput,
          ),
        );
      },
      build: () => AnalysisBloc(repository),
      act: (AnalysisBloc bloc) =>
          bloc.add(const AnalysisEvent.requested(_validSequence)),
      expect: () => <Matcher>[isA<AnalysisLoading>(), isA<AnalysisSuccess>()],
      verify: (_) => verify(() => repository.analyse(any())).called(1),
    );

    blocTest<AnalysisBloc, AnalysisState>(
      'emits [loading, failure] carrying user-facing copy when the '
      'repository throws',
      setUp: () {
        when(() => repository.analyse(any()))
            .thenThrow(const NetworkApiException());
      },
      build: () => AnalysisBloc(repository),
      act: (AnalysisBloc bloc) =>
          bloc.add(const AnalysisEvent.requested(_validSequence)),
      expect: () => <Matcher>[
        isA<AnalysisLoading>(),
        // The message must be the exception's prepared copy, never its
        // toString() — the UI renders this verbatim.
        isA<AnalysisFailure>().having(
          (AnalysisFailure state) => state.message,
          'message',
          const NetworkApiException().userMessage,
        ),
      ],
    );

    blocTest<AnalysisBloc, AnalysisState>(
      'emits failure without loading when the input is invalid',
      build: () => AnalysisBloc(repository),
      act: (AnalysisBloc bloc) => bloc.add(const AnalysisEvent.requested('AT')),
      // Invalid input never reaches the repository, so there is nothing to
      // load and no loading state should appear.
      expect: () => <Matcher>[
        isA<AnalysisFailure>().having(
          (AnalysisFailure state) => state.message,
          'message',
          contains('too short'),
        ),
      ],
      verify: (_) => verifyNever(() => repository.analyse(any())),
    );

    blocTest<AnalysisBloc, AnalysisState>(
      'retry re-runs the analysis with the same input, unprompted by the UI',
      setUp: () {
        when(() => repository.analyse(any())).thenAnswer(
          (Invocation invocation) async => _resultFor(
            invocation.positionalArguments.first as SequenceInput,
          ),
        );
      },
      build: () => AnalysisBloc(repository),
      act: (AnalysisBloc bloc) async {
        bloc.add(const AnalysisEvent.requested(_validSequence));
        await bloc.stream.firstWhere((AnalysisState s) => s is AnalysisSuccess);
        // No payload: the bloc is expected to remember what was submitted.
        bloc.add(const AnalysisEvent.retried());
      },
      expect: () => <Matcher>[
        isA<AnalysisLoading>(),
        isA<AnalysisSuccess>(),
        isA<AnalysisLoading>(),
        isA<AnalysisSuccess>(),
      ],
      verify: (_) {
        final List<dynamic> captured =
            verify(() => repository.analyse(captureAny())).captured;
        expect(captured, hasLength(2));
        // This equality is the contract the results screen's retry depends on.
        expect(captured.first, captured.last);
        expect((captured.first as SequenceInput).bases, _validSequence);
      },
    );

    blocTest<AnalysisBloc, AnalysisState>(
      'retry does nothing when there is no previous input',
      build: () => AnalysisBloc(repository),
      act: (AnalysisBloc bloc) => bloc.add(const AnalysisEvent.retried()),
      expect: () => const <AnalysisState>[],
      verify: (_) => verifyNever(() => repository.analyse(any())),
    );

    blocTest<AnalysisBloc, AnalysisState>(
      'clearing returns to the initial state',
      setUp: () {
        when(() => repository.analyse(any())).thenAnswer(
          (Invocation invocation) async => _resultFor(
            invocation.positionalArguments.first as SequenceInput,
          ),
        );
      },
      build: () => AnalysisBloc(repository),
      act: (AnalysisBloc bloc) async {
        bloc.add(const AnalysisEvent.requested(_validSequence));
        await bloc.stream.firstWhere((AnalysisState s) => s is AnalysisSuccess);
        bloc.add(const AnalysisEvent.cleared());
      },
      skip: 2,
      expect: () => <Matcher>[isA<AnalysisInitial>()],
    );
  });
}
