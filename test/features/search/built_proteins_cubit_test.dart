import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/core/catalog/protein_builds.dart';
import 'package:helixpeek/core/catalog/protein_resolver.dart';
import 'package:helixpeek/core/catalog/protein_suggestion.dart';
import 'package:helixpeek/core/network/api_exception.dart';
import 'package:helixpeek/features/search/presentation/cubit/built_proteins_cubit.dart';

import 'support/resolver_api.dart';

Map<String, dynamic> _row(String gene, {bool stopped = false}) => <String, dynamic>{
  'uniprot': 'P$gene',
  'gene': gene,
  'name': '$gene protein',
  'display': '$gene protein',
  'length': 100,
  'slug': gene.toLowerCase(),
  'status': 'ready',
  'reason': null,
  'building': false,
  'stopped': stopped,
};

Map<String, dynamic> _page(List<String> genes) => <String, dynamic>{
  'proteins': <Object?>[for (final String gene in genes) _row(gene)],
  'next': null,
};

ProteinBuild _ended(String gene, BuildStage stage, {String? slug}) => ProteinBuild(
  protein: ProteinSuggestion.fromJson(_row(gene)),
  stage: stage,
  slug: slug,
);

List<String> _genes(BuiltState state) => <String>[
  for (final ProteinSuggestion protein in switch (state) {
    BuiltShown(:final BuiltPage page) => page.proteins,
    BuiltLoading(:final BuiltPage? previous) => previous?.proteins ?? const <ProteinSuggestion>[],
    _ => const <ProteinSuggestion>[],
  })
    protein.gene!,
];

void main() {
  testWidgets('the list is asked for when looked at, one page of up to 200', (
    WidgetTester tester,
  ) async {
    final List<int> limits = <int>[];
    final ResolverApi api = ResolverApi(
      built: (int limit) async {
        limits.add(limit);
        return _page(<String>['TTR', 'PRL', 'HERC2']);
      },
    );
    final BuiltProteinsCubit cubit = BuiltProteinsCubit(ProteinResolver(api));
    addTearDown(cubit.close);

    expect(cubit.state, isA<BuiltIdle>());
    expect(api.calls, isEmpty);
    cubit.load();
    expect(cubit.state, isA<BuiltLoading>());
    await tester.pump();
    expect(api.calls, <String>['GET /proteins/built']);
    expect(limits, <int>[200]);
    expect(_genes(cubit.state), <String>['TTR', 'PRL', 'HERC2']);
    expect(cubit.state, isA<BuiltShown>());
  });

  testWidgets('asking again keeps the list on screen until it answers', (
    WidgetTester tester,
  ) async {
    final List<Completer<Map<String, dynamic>>> waiting =
        <Completer<Map<String, dynamic>>>[];
    final BuiltProteinsCubit cubit = BuiltProteinsCubit(
      ProteinResolver(
        ResolverApi(
          built: (int limit) {
            final Completer<Map<String, dynamic>> answer = Completer<Map<String, dynamic>>();
            waiting.add(answer);
            return answer.future;
          },
        ),
      ),
    );
    addTearDown(cubit.close);

    cubit.load();
    waiting.last.complete(_page(<String>['PRL']));
    await tester.pump();
    cubit.load();
    expect(cubit.state, isA<BuiltLoading>());
    expect(_genes(cubit.state), <String>['PRL']);
    waiting.last.complete(_page(<String>['TTR', 'PRL']));
    await tester.pump();
    expect(_genes(cubit.state), <String>['TTR', 'PRL']);
  });

  testWidgets('an older answer arriving last never replaces a newer one', (
    WidgetTester tester,
  ) async {
    final List<Completer<Map<String, dynamic>>> waiting =
        <Completer<Map<String, dynamic>>>[];
    final BuiltProteinsCubit cubit = BuiltProteinsCubit(
      ProteinResolver(
        ResolverApi(
          built: (int limit) {
            final Completer<Map<String, dynamic>> answer = Completer<Map<String, dynamic>>();
            waiting.add(answer);
            return answer.future;
          },
        ),
      ),
    );
    addTearDown(cubit.close);

    cubit.load();
    cubit.load();
    waiting[1].complete(_page(<String>['TTR', 'PRL']));
    await tester.pump();
    waiting[0].complete(_page(<String>['PRL']));
    await tester.pump();
    expect(_genes(cubit.state), <String>['TTR', 'PRL']);
  });

  testWidgets('a service older than the list says so, apart from a failure', (
    WidgetTester tester,
  ) async {
    Object answer = const ServerApiException(statusCode: 404, detail: 'Not Found');
    final BuiltProteinsCubit cubit = BuiltProteinsCubit(
      ProteinResolver(ResolverApi(built: (int limit) async => throw answer)),
    );
    addTearDown(cubit.close);

    cubit.load();
    await tester.pump();
    expect(cubit.state, isA<BuiltNotListed>());

    answer = const ServerApiException(statusCode: 503);
    cubit.load();
    await tester.pump();
    expect(
      (cubit.state as BuiltFailed).message,
      const ServerApiException(statusCode: 503).userMessage,
    );

    answer = const NetworkApiException();
    cubit.load();
    await tester.pump();
    expect((cubit.state as BuiltFailed).message, const NetworkApiException().userMessage);

    answer = StateError('broken');
    cubit.load();
    await tester.pump();
    expect((cubit.state as BuiltFailed).message, const UnknownApiException().userMessage);
  });

  testWidgets('a build that ends with a protein to open asks the list again', (
    WidgetTester tester,
  ) async {
    final StreamController<ProteinBuild> ended = StreamController<ProteinBuild>.broadcast();
    addTearDown(ended.close);
    final ResolverApi api = ResolverApi(
      built: (int limit) async => _page(<String>['TTR']),
    );
    final BuiltProteinsCubit cubit = BuiltProteinsCubit(
      ProteinResolver(api),
      ended: ended.stream,
    );
    addTearDown(cubit.close);

    // Never looked at: asked for when it is, not before.
    ended.add(_ended('TTR', BuildStage.ready, slug: 'ttr'));
    await tester.pump();
    expect(api.calls, isEmpty);

    cubit.load();
    await tester.pump();
    expect(api.calls, hasLength(1));

    ended.add(_ended('ALB', BuildStage.ready, slug: 'alb'));
    await tester.pump();
    expect(api.calls, hasLength(2));

    // Stopped while ESM-2 scored: it opens unscored, so it is listed.
    ended.add(_ended('PRL', BuildStage.stopped, slug: 'prl'));
    await tester.pump();
    expect(api.calls, hasLength(3));

    // Nothing to open: no row was written.
    ended
      ..add(_ended('INSR', BuildStage.failed))
      ..add(_ended('OCA2', BuildStage.stopped))
      ..add(_ended('TP53BP2', BuildStage.refused));
    await tester.pump();
    expect(api.calls, hasLength(3));
  });

  testWidgets('a closed list stops listening for builds', (WidgetTester tester) async {
    final StreamController<ProteinBuild> ended = StreamController<ProteinBuild>.broadcast();
    addTearDown(ended.close);
    final BuiltProteinsCubit cubit = BuiltProteinsCubit(
      ProteinResolver(ResolverApi(built: (int limit) async => _page(<String>[]))),
      ended: ended.stream,
    );
    expect(ended.hasListener, isTrue);
    await cubit.close();
    expect(ended.hasListener, isFalse);
  });
}
