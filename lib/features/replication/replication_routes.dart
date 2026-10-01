import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/app_theme.dart';
import 'presentation/replication_screen.dart';

/// Replication's routes, in every build: it left the lab for the home screen.
/// `lib/app.dart` spreads these into the app's router, as it does the lab's.
List<RouteBase> get replicationRoutes => <RouteBase>[
  GoRoute(
    path: RoutePaths.replication,
    builder: (BuildContext context, GoRouterState state) =>
        // Drawn as it was in the lab, whose shell wore the walk's theme.
        Theme(data: AppTheme.analysis, child: const ReplicationScreen()),
  ),
  // Links saved while it was a lab flow, `/lab/replication` and the older
  // `/lab/replication/<slug>`, open it where it is now.
  GoRoute(
    path: '${RoutePaths.lab}/replication',
    redirect: (BuildContext context, GoRouterState state) =>
        RoutePaths.replication,
    routes: <RouteBase>[
      GoRoute(
        path: ':slug',
        redirect: (BuildContext context, GoRouterState state) =>
            RoutePaths.replication,
      ),
    ],
  ),
];
