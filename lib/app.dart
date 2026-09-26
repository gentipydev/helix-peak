import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'core/constants/app_constants.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/lab/lab_routes.dart';

class HelixPeekApp extends StatelessWidget {
  const HelixPeekApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      routerConfig: _router,
      theme: AppTheme.dark,
      themeMode: ThemeMode.dark,
    );
  }

}

/// The walk's [appRouter] itself, unless this build carries the lab: then the
/// same routes with the lab's spread in after them. The lab's routes are
/// handed over here, at the root, so that core never names the lab.
final GoRouter _router = _withLab(labRoutes);

GoRouter _withLab(List<RouteBase> lab) =>
    lab.isEmpty ? appRouter : buildAppRouter(extra: lab);
