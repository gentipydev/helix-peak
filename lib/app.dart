import 'package:flutter/material.dart';

import 'core/constants/app_constants.dart';
import 'core/constants/app_router.dart';
import 'core/theme/app_theme.dart';

/// The application widget: theme and routing, and nothing else.
///
/// Dependency wiring lives in `main.dart` above this widget, so this stays a
/// pure composition of presentation concerns.
class HelixPeakApp extends StatelessWidget {
  const HelixPeakApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      routerConfig: appRouter,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      // Dark is the app's identity, but the light theme is a real design, so
      // the OS preference is honoured rather than overridden.
      themeMode: ThemeMode.system,
    );
  }
}
