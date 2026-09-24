import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';

/// The shared brand symbol. Flutter selects the appropriate density asset.
///
/// [width] is in logical pixels. Exclude semantics when accompanying the
/// app name, so screen readers announce the brand only once.
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.width = 96, this.excludeFromSemantics = false})
    : assert(width > 0 && width < double.infinity);

  final double width;
  final bool excludeFromSemantics;

  static const String assetPath = 'assets/branding/helix_peek_mark.png';

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      assetPath,
      width: width,
      height: width / 2,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
      semanticLabel: AppConstants.appName,
      excludeFromSemantics: excludeFromSemantics,
    );
  }
}
