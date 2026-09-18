import 'package:flutter/material.dart';

import 'core/config/env.dart';
import 'core/constants/app_constants.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

class HelixPeakApp extends StatelessWidget {
  const HelixPeakApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      routerConfig: appRouter,
      theme: AppTheme.dark,
      themeMode: ThemeMode.dark,
      builder: _bannerMockBuilds,
    );
  }

  /// A mock build is meant to be installed and handed to someone, and a screen
  /// full of real insulin is exactly as convincing whether or not it came from
  /// NCBI. The ribbon is the one thing that says which — so it ships with the
  /// fixture and with nothing else.
  static Widget _bannerMockBuilds(BuildContext context, Widget? child) {
    final Widget app = child ?? const SizedBox.shrink();
    if (!Env.useMockData) {
      return app;
    }
    return Banner(
      message: 'MOCK',
      location: BannerLocation.topEnd,
      child: app,
    );
  }
}
