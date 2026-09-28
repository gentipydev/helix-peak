import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:helixpeek/features/lab/presentation/lab_index_screen.dart';

/// Home, and `/lab` as the first page of a shell navigator, as the app has it.
GoRouter _router(String initialLocation) => GoRouter(
  initialLocation: initialLocation,
  routes: <RouteBase>[
    GoRoute(
      path: '/',
      builder: (BuildContext context, GoRouterState state) =>
          const Scaffold(body: Text('home')),
    ),
    ShellRoute(
      builder: (BuildContext context, GoRouterState state, Widget child) =>
          child,
      routes: <RouteBase>[
        GoRoute(
          path: '/lab',
          builder: (BuildContext context, GoRouterState state) =>
              const LabIndexScreen(features: <LabFeature>[]),
        ),
      ],
    ),
  ],
);

void main() {
  testWidgets('the index pushed from home has a back arrow that returns', (
    WidgetTester tester,
  ) async {
    final GoRouter router = _router('/');
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    unawaited(router.push<void>('/lab'));
    await tester.pumpAndSettle();

    expect(find.byType(BackButton), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('home'), findsOneWidget);
  });

  testWidgets('the index opened directly has nothing to go back to', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(MaterialApp.router(routerConfig: _router('/lab')));
    await tester.pumpAndSettle();

    expect(find.byType(BackButton), findsNothing);
  });
}
