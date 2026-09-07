import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeak/core/network/api_exception.dart';
import 'package:helixpeak/features/sequence_analysis/domain/entities/analysis_result.dart';
import 'package:helixpeak/features/sequence_analysis/domain/entities/sequence_input.dart';
import 'package:helixpeak/features/sequence_analysis/domain/repositories/sequence_repository.dart';
import 'package:helixpeak/features/sequence_analysis/domain/usecases/analyse_sequence.dart';
import 'package:helixpeak/features/sequence_analysis/presentation/bloc/analysis_bloc.dart';
import 'package:helixpeak/features/sequence_analysis/presentation/bloc/analysis_event.dart';
import 'package:helixpeak/features/sequence_analysis/presentation/bloc/analysis_state.dart';
import 'package:mocktail/mocktail.dart';

class _MockSequenceRepository extends Mock implements SequenceRepository {}

const String _rawText = 'ATGCGTAGCTAGCTAGCTA';

final AnalysisResult _result = AnalysisResult(
  id: 'test',
  summary: 'Placeholder analysis',
  generatedAt: DateTime.utc(2026),
);

void main() {
  late _MockSequenceRepository repository;

  setUpAll(() {
    registerFallbackValue(const SequenceInput(rawText: 'A'));
  });

  setUp(() => repository = _MockSequenceRepository());

  AnalysisBloc buildBloc() => AnalysisBloc(AnalyseSequence(repository));

  group('AnalysisBloc', () {
    blocTest<AnalysisBloc, AnalysisState>(
      'emits [loading, success] when the use case succeeds',
      setUp: () {
        when(() => repository.analyse(any()))
            .thenAnswer((_) async => _result);
      },
      build: buildBloc,
      act: (AnalysisBloc bloc) =>
          bloc.add(const AnalysisEvent.requested(_rawText)),
      expect: () => <Matcher>[isA<AnalysisLoading>(), isA<AnalysisSuccess>()],
      verify: (_) => verify(
        () => repository.analyse(const SequenceInput(rawText: _rawText)),
      ).called(1),
    );

    blocTest<AnalysisBloc, AnalysisState>(
      'emits [loading, failure] carrying user-facing copy when the use case '
      'throws an ApiException',
      setUp: () {
        when(() => repository.analyse(any()))
            .thenThrow(const NetworkApiException());
      },
      build: buildBloc,
      act: (AnalysisBloc bloc) =>
          bloc.add(const AnalysisEvent.requested(_rawText)),
      expect: () => <Matcher>[
        isA<AnalysisLoading>(),
        isA<AnalysisFailure>().having(
          (AnalysisFailure state) => state.message,
          'message',
          const NetworkApiException().userMessage,
        ),
      ],
    );

    blocTest<AnalysisBloc, AnalysisState>(
      'retry re-runs the analysis with the same input',
      setUp: () {
        when(() => repository.analyse(any()))
            .thenAnswer((_) async => _result);
      },
      build: buildBloc,
      act: (AnalysisBloc bloc) async {
        bloc.add(const AnalysisEvent.requested(_rawText));
        await bloc.stream.firstWhere((AnalysisState s) => s is AnalysisSuccess);
        bloc.add(const AnalysisEvent.retried());
      },
      expect: () => <Matcher>[
        isA<AnalysisLoading>(),
        isA<AnalysisSuccess>(),
        isA<AnalysisLoading>(),
        isA<AnalysisSuccess>(),
      ],
      verify: (_) => verify(() => repository.analyse(any())).called(2),
    );

    blocTest<AnalysisBloc, AnalysisState>(
      'retry does nothing when there is no previous input',
      build: buildBloc,
      act: (AnalysisBloc bloc) => bloc.add(const AnalysisEvent.retried()),
      expect: () => <Matcher>[],
      verify: (_) => verifyNever(() => repository.analyse(any())),
    );

    blocTest<AnalysisBloc, AnalysisState>(
      'clearing returns to the initial state',
      setUp: () {
        when(() => repository.analyse(any()))
            .thenAnswer((_) async => _result);
      },
      build: buildBloc,
      act: (AnalysisBloc bloc) async {
        bloc.add(const AnalysisEvent.requested(_rawText));
        await bloc.stream.firstWhere((AnalysisState s) => s is AnalysisSuccess);
        bloc.add(const AnalysisEvent.cleared());
      },
      expect: () => <Matcher>[
        isA<AnalysisLoading>(),
        isA<AnalysisSuccess>(),
        isA<AnalysisInitial>(),
      ],
    );
  });
}
