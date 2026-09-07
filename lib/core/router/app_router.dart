import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../features/home/presentation/screens/home_screen.dart';
import '../../features/sequence_analysis/domain/usecases/analyse_sequence.dart';
import '../../features/sequence_analysis/presentation/bloc/analysis_bloc.dart';
import '../../features/sequence_analysis/presentation/screens/results_screen.dart';
import '../../features/sequence_analysis/presentation/screens/sequence_input_screen.dart';
import '../../shared/widgets/error_view.dart';

abstract final class RoutePaths {
  static const String home = '/';
  static const String sequenceInput = '/analyse';
  static const String results = '/analyse/results';
}

final GoRouter appRouter = GoRouter(
  initialLocation: RoutePaths.home,
  debugLogDiagnostics: kDebugMode,
  routes: <RouteBase>[
    GoRoute(
      path: RoutePaths.home,
      builder: (BuildContext context, GoRouterState state) =>
          const HomeScreen(),
    ),

    ShellRoute(
      builder: (BuildContext context, GoRouterState state, Widget child) {
        return BlocProvider<AnalysisBloc>(
          create: (BuildContext context) =>
              AnalysisBloc(context.read<AnalyseSequence>()),
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
