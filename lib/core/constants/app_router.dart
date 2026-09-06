import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../features/home/presentation/screens/home_screen.dart';
import '../../features/sequence_analysis/domain/repositories/sequence_repository.dart';
import '../../features/sequence_analysis/presentation/bloc/analysis_bloc.dart';
import '../../features/sequence_analysis/presentation/screens/results_screen.dart';
import '../../features/sequence_analysis/presentation/screens/sequence_input_screen.dart';
import '../../shared/widgets/error_view.dart';

/// Route locations, named so no screen contains a path literal.
abstract final class RoutePaths {
  static const String home = '/';
  static const String sequenceInput = '/analyse';
  static const String results = '/analyse/results';
}

/// The app's route table.
final GoRouter appRouter = GoRouter(
  initialLocation: RoutePaths.home,
  debugLogDiagnostics: kDebugMode,
  routes: <RouteBase>[
    GoRoute(
      path: RoutePaths.home,
      builder: (BuildContext context, GoRouterState state) =>
          const HomeScreen(),
    ),

    // The shell is load-bearing, not decoration. It gives the input and
    // results screens a single shared AnalysisBloc, which is what lets the
    // input screen start an analysis and immediately push results — the
    // results screen then reads the in-flight loading state from the same
    // instance instead of receiving the payload through route `extra`.
    //
    // It also means retry works: the bloc still holds the last input, so the
    // results screen can re-run an analysis it never had the input for.
    // Leaving the subtree disposes the bloc automatically.
    ShellRoute(
      builder: (BuildContext context, GoRouterState state, Widget child) {
        return BlocProvider<AnalysisBloc>(
          create: (BuildContext context) =>
              AnalysisBloc(context.read<SequenceRepository>()),
          child: child,
        );
      },
      routes: <RouteBase>[
        GoRoute(
          path: RoutePaths.sequenceInput,
          builder: (BuildContext context, GoRouterState state) =>
              const SequenceInputScreen(),
        ),
        GoRoute(
          path: RoutePaths.results,
          builder: (BuildContext context, GoRouterState state) =>
              const ResultsScreen(),
        ),
      ],
    ),
  ],
  errorBuilder: (BuildContext context, GoRouterState state) => Scaffold(
    body: ErrorView(
      title: 'Page not found',
      message: 'No route matches ${state.uri}.',
      onRetry: () => context.go(RoutePaths.home),
    ),
  ),
);
