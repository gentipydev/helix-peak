import 'package:flutter/material.dart';

import '../../core/theme/app_spacing.dart';

/// The app's single call-to-action treatment.
///
/// Styling lives in the theme's `filledButtonTheme`; this widget exists so
/// call sites express intent ("this is the primary action") rather than
/// repeating button configuration.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    required this.label,
    required this.onPressed,
    this.icon,
    super.key,
  });

  final String label;

  /// A null callback disables the button — used by the input screen while the
  /// sequence is empty or invalid.
  final VoidCallback? onPressed;

  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final Widget child = Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (icon != null) ...<Widget>[
          Icon(icon, size: 18),
          const SizedBox(width: AppSpacing.sm),
        ],
        Text(label),
      ],
    );

    return FilledButton(onPressed: onPressed, child: child);
  }
}
