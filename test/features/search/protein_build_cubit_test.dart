import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/core/catalog/protein_resolver.dart';
import 'package:helixpeek/core/network/api_exception.dart';
import 'package:helixpeek/features/search/presentation/cubit/protein_build_cubit.dart';

import 'support/resolver_api.dart';

const Duration _tick = Duration(seconds: 3);

Map<String, dynamic> _said(String state, {String? slug, String? reason}) =>
    <String, dynamic>{'slug': slug, 'state': state, 'reason': reason};

Map<String, dynamic> _constraint(String state) => <String, dynamic>{
  'record': <String, dynamic>{'state': 'ready'},
  'constraint': <String, dynamic>{'state': state},
};

/// The service's answers, one per ask, in order.
Future<Map<String, dynamic>> Function(String) _answers(
  List<Map<String, dynamic>> answers,
) =>
    (String _) async => answers.removeAt(0);

BuildStage? _stage(ProteinBuildCubit cubit, [String gene = 'BRCA1']) =>
    cubit.state.of(gene)?.stage;

void main() {
  // Each test runs in the widget binding's fake time, so a tick of the poll is
  // a `tester.pump(_tick)` and never a real wait.

  testWidgets('a build is asked for, watched through both steps, then opens', (
    WidgetTester tester,
  ) async {
    final ResolverApi api = ResolverApi(
      resolve: _answers(<Map<String, dynamic>>[_said('pending', slug: 'brca1')]),
      status: _answers(<Map<String, dynamic>>[
        _said('pending', slug: 'brca1'),
        _said('ready', slug: 'brca1'),
      ]),
      tracks: _answers(<Map<String, dynamic>>[
        _constraint('pending'),
        _constraint('ready'),
      ]),
    );
    final ProteinBuildCubit cubit = ProteinBuildCubit(ProteinResolver(api));
    addTearDown(cubit.close);

    await cubit.build('BRCA1');
    expect(_stage(cubit), BuildStage.resolving);
    await tester.pump(_tick);
    expect(_stage(cubit), BuildStage.resolving);
    await tester.pump(_tick);
    // Its row is written, but its ESM-2 track is not: not open yet.
    expect(_stage(cubit), BuildStage.scoring);
    await tester.pump(_tick);
    expect(_stage(cubit), BuildStage.ready);
    expect(cubit.state.of('BRCA1')!.slug, 'brca1');
    expect(api.calls, <String>[
      'POST /proteins/resolve BRCA1',
      'GET /proteins/resolve/BRCA1',
      'GET /proteins/resolve/BRCA1',
      'GET /protein/brca1/tracks',
      'GET /protein/brca1/tracks',
    ]);
    // Nothing is watched any more, so nothing more is asked.
    await tester.pump(_tick * 3);
    expect(api.calls, hasLength(5));
  });

  testWidgets('a protein that is already built opens once its scores are in', (
    WidgetTester tester,
  ) async {
    final ProteinBuildCubit cubit = ProteinBuildCubit(
      ProteinResolver(
        ResolverApi(
          resolve: _answers(<Map<String, dynamic>>[_said('ready', slug: 'insulin')]),
          tracks: _answers(<Map<String, dynamic>>[_constraint('ready')]),
        ),
      ),
    );
    addTearDown(cubit.close);
    await cubit.build('INS');
    expect(_stage(cubit, 'INS'), BuildStage.ready);
    expect(cubit.state.of('INS')!.slug, 'insulin');
  });

  testWidgets('a refusal is said in the service\'s words and not watched', (
    WidgetTester tester,
  ) async {
    final ProteinBuildCubit cubit = ProteinBuildCubit(
      ProteinResolver(
        ResolverApi(
          resolve: _answers(<Map<String, dynamic>>[
            _said('refused', reason: 'Exons alone are 81,000 bp, over the 24,000 bp budget.'),
          ]),
        ),
      ),
    );
    addTearDown(cubit.close);
    await cubit.build('TTN');
    expect(_stage(cubit, 'TTN'), BuildStage.refused);
    expect(cubit.state.of('TTN')!.message, contains('over the 24,000 bp budget'));
    expect(cubit.state.watching, isFalse);
  });

  testWidgets('a day with its builds taken says so', (WidgetTester tester) async {
    final ProteinBuildCubit cubit = ProteinBuildCubit(
      ProteinResolver(
        ResolverApi(
          resolve: (String gene) async => throw const ServerApiException(
            statusCode: 429,
            detail: "The service builds 50 proteins a day, and today's are taken. "
                'Ask again tomorrow.',
          ),
        ),
      ),
    );
    addTearDown(cubit.close);
    await cubit.build('BRCA1');
    expect(_stage(cubit), BuildStage.capped);
    expect(cubit.state.of('BRCA1')!.message, contains("today's are taken"));
  });

  testWidgets('a service that does not answer is a failure that can be asked again', (
    WidgetTester tester,
  ) async {
    int asked = 0;
    final ProteinBuildCubit cubit = ProteinBuildCubit(
      ProteinResolver(
        ResolverApi(
          resolve: (String gene) async {
            asked++;
            if (asked == 1) {
              throw const NetworkApiException();
            }
            return _said('pending', slug: 'brca1');
          },
          status: (String gene) async => _said('pending', slug: 'brca1'),
        ),
      ),
    );
    await cubit.build('BRCA1');
    expect(_stage(cubit), BuildStage.failed);
    expect(cubit.state.of('BRCA1')!.message, const NetworkApiException().userMessage);
    await cubit.build('BRCA1');
    expect(_stage(cubit), BuildStage.resolving);
    // Closed here, not in a tear-down: the framework looks for pending timers
    // before tear-downs run, and this one is still watching. Not awaited: the
    // close finishes on a microtask, which only a pump runs in fake time.
    unawaited(cubit.close());
    await tester.pump();
  });

  testWidgets('a poll that is not answered is asked again at the next tick', (
    WidgetTester tester,
  ) async {
    int polled = 0;
    final ProteinBuildCubit cubit = ProteinBuildCubit(
      ProteinResolver(
        ResolverApi(
          resolve: (String gene) async => _said('pending', slug: 'brca1'),
          status: (String gene) async {
            polled++;
            if (polled == 1) {
              throw const TimeoutApiException();
            }
            return _said('ready', slug: 'brca1');
          },
          tracks: (String slug) async => _constraint('ready'),
        ),
      ),
    );
    addTearDown(cubit.close);
    await cubit.build('BRCA1');
    await tester.pump(_tick);
    expect(_stage(cubit), BuildStage.resolving);
    await tester.pump(_tick);
    expect(_stage(cubit), BuildStage.ready);
  });

  testWidgets('a build that never lands is let go of, saying why', (
    WidgetTester tester,
  ) async {
    final ProteinBuildCubit cubit = ProteinBuildCubit(
      ProteinResolver(
        ResolverApi(
          resolve: (String gene) async => _said('pending', slug: 'brca1'),
          status: (String gene) async => _said('pending', slug: 'brca1'),
        ),
      ),
      patience: 3,
    );
    addTearDown(cubit.close);
    await cubit.build('BRCA1');
    await tester.pump(_tick);
    await tester.pump(_tick);
    expect(_stage(cubit), BuildStage.resolving);
    await tester.pump(_tick);
    expect(_stage(cubit), BuildStage.failed);
    expect(cubit.state.of('BRCA1')!.message, contains('taking longer than it should'));
  });

  testWidgets('scores that never land still let the protein open, saying so', (
    WidgetTester tester,
  ) async {
    final ProteinBuildCubit cubit = ProteinBuildCubit(
      ProteinResolver(
        ResolverApi(
          resolve: (String gene) async => _said('ready', slug: 'brca1'),
          tracks: (String slug) async => _constraint('pending'),
        ),
      ),
      patience: 2,
    );
    addTearDown(cubit.close);
    await cubit.build('BRCA1');
    expect(_stage(cubit), BuildStage.scoring);
    await tester.pump(_tick);
    await tester.pump(_tick);
    expect(_stage(cubit), BuildStage.ready);
    expect(cubit.state.of('BRCA1')!.message, 'Its ESM-2 scores are still on their way.');
  });
}
