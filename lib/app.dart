import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'core/constants/app_constants.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/lab/lab_routes.dart';
import 'features/replication/replication_routes.dart';
import 'shared/share/clip_sheet.dart';

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
      // A clip that ends while no sheet shows it is said on any screen.
      builder: (BuildContext context, Widget? child) =>
          ClipReadyListener(child: child ?? const SizedBox.shrink()),
    );
  }

}

/// The walk's routes with replication's spread in after them, and the lab's
/// too when this build carries it. Both are handed over here, at the root, so
/// that core never names a feature for them.
final GoRouter _router = buildAppRouter(
  extra: <RouteBase>[...replicationRoutes, ...labRoutes],
);
