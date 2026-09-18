import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';

/// The home screen's one action: go and pick a protein to walk.
///
/// Deliberately unfilled. The screen offers exactly one thing to do, so the row
/// does not need a solid slab to announce itself — a line of accent type and a
/// chevron are enough, and they leave the wordmark as the loudest thing here.
class ProteinAnalysesCta extends StatelessWidget {
  const ProteinAnalysesCta({required this.onPressed, super.key});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color accent = theme.colorScheme.primary;

    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        // Vertical-only padding: the label and chevron sit together in the
        // middle, but the button still spans the width as a tap target.
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Text(
            'Protein Analyses',
            style: theme.textTheme.titleSmall?.copyWith(color: accent),
          ),
          const SizedBox(width: AppSpacing.xs),
          Icon(Icons.chevron_right_rounded, size: 24, color: accent),
        ],
      ),
    );
  }
}
