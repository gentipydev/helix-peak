import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/app_theme.dart';
import 'presentation/zoom_screen.dart';

/// The zoom's routes, in every build: it left the lab for the walk's gene
/// page. `lib/app.dart` spreads these into the app's router, as it does
/// replication's and the lab's.
List<RouteBase> get zoomRoutes => <RouteBase>[
  GoRoute(
    path: '${RoutePaths.zoom}/:slug',
    builder: (BuildContext context, GoRouterState state) =>
        // Drawn as it was in the lab, whose shell wore the walk's theme.
        Theme(
          data: AppTheme.analysis,
          child: ZoomRoute(
            slug: state.pathParameters['slug']!,
            overWalk: RoutePaths.zoomIsOverWalk(state.uri),
          ),
        ),
  ),
  // Links saved while it was a lab flow open it where it is now. Two routes
  // side by side, not one under the other: a parent's redirect is taken
  // first, and would send a protein's link to the list.
  GoRoute(
    path: '${RoutePaths.lab}/zoom/:slug',
    redirect: (BuildContext context, GoRouterState state) =>
        '${RoutePaths.zoom}/${state.pathParameters['slug']}',
  ),
  // The lab's picker was a list of the catalog, which search is.
  GoRoute(
    path: '${RoutePaths.lab}/zoom',
    redirect: (BuildContext context, GoRouterState state) => RoutePaths.search,
  ),
];
