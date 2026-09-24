import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/app_logo.dart';

class Wordmark extends StatelessWidget {
  const Wordmark({super.key});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const AppLogo(excludeFromSemantics: true),
        const SizedBox(height: AppSpacing.lg),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text.rich(
            TextSpan(
              children: <TextSpan>[
                TextSpan(
                  text: 'HELIX',
                  style: AppTypography.wordmark(theme.colorScheme.onSurface),
                ),
                TextSpan(
                  text: 'PEEK',
                  style: AppTypography.wordmark(theme.colorScheme.primary),
                ),
              ],
            ),
            textAlign: TextAlign.center,
            semanticsLabel: AppConstants.appName,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          AppConstants.tagline.toUpperCase(),
          textAlign: TextAlign.center,
          style: theme.textTheme.labelSmall?.copyWith(letterSpacing: 1.6),
        ),
      ],
    );
  }
}
