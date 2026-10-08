import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:helixpeek/core/catalog/protein_builds.dart';
import 'package:helixpeek/core/catalog/protein_resolver.dart';
import 'package:helixpeek/core/catalog/protein_suggestion.dart';
import 'package:helixpeek/features/search/presentation/widgets/build_ready_listener.dart';

import 'support/resolver_api.dart';

/// [BuildReadyListener]: a build that ends while search is not on screen is
/// said on whatever screen is, with Open; on search its card says it.

const Duration _tick = Duration(seconds: 3);

const ProteinSuggestion _brca1 = ProteinSuggestion(
  uniprot: 'P38398',
  gene: 'BRCA1',
  name: 'Breast cancer type 1 susceptibility protein',
  display: null,
  length: 1863,
  slug: 'brca1',
  status: SuggestionStatus.buildable,
  reason: null,
);

Map<String, dynamic> _said(String state, {String? slug, Map<String, dynamic>? build}) =>
    <String, dynamic>{'slug': slug, 'state': state, 'reason': null, 'build': build};

Map<String, dynamic> _report(String step, double elapsed, {String? reason}) =>
    <String, dynamic>{
      'step': step, 'ahead': null, 'scored': null, 'residues': null, 'left': null,
      'elapsed': elapsed, 'transcript': null, 'reason': reason,
    };

/// The app's shape: builds above the router, the listener in the builder.
/// Returns the builds, and the router at [at].
Future<(ProteinBuilds, GoRouter)> _pump(
  WidgetTester tester,
  ResolverApi api, {
  String at = '/',
}) async {
  final ProteinBuilds builds = ProteinBuilds(ProteinResolver(api));
  final GoRouter router = GoRouter(
    initialLocation: at,
    routes: <RouteBase>[
      for (final String path in <String>['/', '/search'])
        GoRoute(
          path: path,
          builder: (BuildContext context, GoRouterState state) =>
              Scaffold(body: Text('at $path')),
        ),
      GoRoute(
        path: '/gene/:slug',
        builder: (BuildContext context, GoRouterState state) =>
            Scaffold(body: Text('walk ${state.pathParameters['slug']}')),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    RepositoryProvider<ProteinBuilds>(
      create: (BuildContext context) => builds,
      dispose: (ProteinBuilds builds) => builds.dispose(),
      child: MaterialApp.router(
        routerConfig: router,
        builder: (BuildContext context, Widget? child) =>
            BuildReadyListener(router: router, child: child!),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return (builds, router);
}

ResolverApi _endsBuilt({String? reason}) => ResolverApi(
  resolve: (String gene) async =>
      _said('pending', slug: 'brca1', build: _report('queued', 0)),
  status: (String gene) async =>
      _said('ready', slug: 'brca1', build: _report(reason == null ? 'done' : 'check', 540,
          reason: reason)),
);

void main() {
  testWidgets('built while elsewhere, it is said with Open, which opens it', (
    WidgetTester tester,
  ) async {
    final (ProteinBuilds builds, _) = await _pump(tester, _endsBuilt());
    unawaited(builds.build(_brca1));
    await tester.pump();
    expect(find.byType(SnackBar), findsNothing);

    await tester.pump(_tick);
    await tester.pump();
    expect(find.text('BRCA1 is built'), findsOneWidget);
    // In, before it is tapped.
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.text('walk brca1'), findsOneWidget);
    // Opened, it leaves the top of search.
    expect(builds.of('BRCA1')!.pinned, isFalse);
  });

  testWidgets('built without its ESM-2 scores, it says so', (WidgetTester tester) async {
    final (ProteinBuilds builds, _) = await _pump(tester, _endsBuilt(reason: 'Declined.'));
    unawaited(builds.build(_brca1));
    await tester.pump();
    await tester.pump(_tick);
    await tester.pump();
    expect(find.text('BRCA1 is built, without ESM-2 scores'), findsOneWidget);
  });

  testWidgets('on search, its card says it and nothing more is said', (
    WidgetTester tester,
  ) async {
    final (ProteinBuilds builds, _) = await _pump(tester, _endsBuilt(), at: '/search');
    unawaited(builds.build(_brca1));
    await tester.pump();
    await tester.pump(_tick);
    await tester.pump();
    expect(builds.of('BRCA1')!.stage, BuildStage.ready);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('built while the app was away, it is said when the app is back', (
    WidgetTester tester,
  ) async {
    final (ProteinBuilds builds, _) = await _pump(tester, _endsBuilt());
    unawaited(builds.build(_brca1));
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(_tick);
    await tester.pump();
    expect(find.byType(SnackBar), findsNothing);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(find.text('BRCA1 is built'), findsOneWidget);
  });

  testWidgets('opened before the app came back, it is not said at all', (
    WidgetTester tester,
  ) async {
    final (ProteinBuilds builds, _) = await _pump(tester, _endsBuilt());
    unawaited(builds.build(_brca1));
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(_tick);
    builds.opened('BRCA1');
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(find.byType(SnackBar), findsNothing);
  });
}
