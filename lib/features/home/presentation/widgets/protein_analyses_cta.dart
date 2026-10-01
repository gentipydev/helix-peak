import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';

/// The home screen's action: go and pick a protein to walk.
///
/// Deliberately unfilled. The screen offers almost nothing else to do, so the
/// row does not need a solid slab to announce itself — a line of accent type
/// and a chevron are enough, and they leave the wordmark as the loudest thing
/// here. Replication's entry sits below it, and a build with the lab switched
/// on shows the lab's below that, each carrying its own [label].
class ProteinAnalysesCta extends StatelessWidget {
  const ProteinAnalysesCta({
    required this.onPressed,
    this.label = defaultLabel,
    super.key,
  });

  /// What the walk's entry has always said.
  static const String defaultLabel = 'Protein Analyses';

  final VoidCallback? onPressed;

  /// The words on the row. Defaults to the walk's entry.
  final String label;

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
            label,
            style: theme.textTheme.titleSmall?.copyWith(color: accent),
          ),
          const SizedBox(width: AppSpacing.xs),
          Icon(Icons.chevron_right_rounded, size: 24, color: accent),
        ],
      ),
    );
  }
}
