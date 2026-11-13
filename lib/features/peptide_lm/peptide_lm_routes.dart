import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/api_client.dart';
import '../../core/network/track_client.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_theme.dart';
import 'data/training_run_repository.dart';
import 'presentation/cubit/peptide_lm_cubit.dart';
import 'presentation/peptide_lm_screen.dart';

/// The peptide language model's routes, in every build, from the home
/// screen's row. `lib/app.dart` spreads these into the app's router, as it
/// does the zoom's.
List<RouteBase> get peptideLmRoutes => <RouteBase>[
  GoRoute(
    path: RoutePaths.peptideLm,
    builder: (BuildContext context, GoRouterState state) => Theme(
      data: AppTheme.analysis,
      child: BlocProvider<PeptideLmCubit>(
        // A client of its own, so a run kept on the phone is never what
        // evicts a protein's track, nor one of them it.
        create: (BuildContext context) => PeptideLmCubit(
          TrainingRunRepository(
            TrackClient(context.read<ApiClient>(), folder: 'peptide_lm').readRow,
          ),
        )..load(),
        child: const PeptideLmScreen(),
      ),
    ),
  ),
];
