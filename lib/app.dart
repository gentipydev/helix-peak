import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'core/constants/app_constants.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/peptide_lm/peptide_lm_routes.dart';
import 'features/search/presentation/widgets/build_ready_listener.dart';
import 'features/zoom/zoom_routes.dart';

class HelixPeekApp extends StatelessWidget {
  const HelixPeekApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      routerConfig: _router,
      // One ground for the whole app: the warm one the walk is drawn on.
      // Each flow still puts it around itself, as the walk has to; this is
      // what whatever has no flow of its own is on.
      theme: AppTheme.analysis,
      themeMode: ThemeMode.dark,
      // A protein's build that ends while search is not open is said on any
      // screen.
      builder: (BuildContext context, Widget? child) => BuildReadyListener(
        router: _router,
        child: child ?? const SizedBox.shrink(),
      ),
    );
  }

}

/// The walk's routes with the zoom's and the peptide language model's spread
/// in after them. They are handed over here, at the root, so that core never
/// names a feature for them.
final GoRouter _router = buildAppRouter(
  extra: <RouteBase>[...zoomRoutes, ...peptideLmRoutes, ..._replicationLinks],
);

/// DNA Replication was removed on 2026-11-13. Links saved to it, at
/// `/replication` or from when it was a lab flow, open home.
final List<RouteBase> _replicationLinks = <RouteBase>[
  GoRoute(path: '/replication', redirect: _home),
  GoRoute(
    path: '${RoutePaths.lab}/replication',
    redirect: _home,
    routes: <RouteBase>[GoRoute(path: ':slug', redirect: _home)],
  ),
];

String _home(BuildContext context, GoRouterState state) => RoutePaths.home;
