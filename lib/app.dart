import 'package:flutter/material.dart';

import 'core/constants/app_constants.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

class HelixPeekApp extends StatelessWidget {
  const HelixPeekApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      routerConfig: appRouter,
      theme: AppTheme.dark,
      themeMode: ThemeMode.dark,
    );
  }

}
