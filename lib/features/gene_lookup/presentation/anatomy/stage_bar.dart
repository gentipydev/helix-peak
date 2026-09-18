import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import 'anatomy_stages.dart';

/// Where you are in the walk, and every other place you can go from here.
///
/// The walk used to be five unlabelled dots: nothing said what the pages were,
/// the swipe that turned them was undiscoverable, and the fold was four
/// animated page turns away from the gene. Named, a reader sees the whole route
/// before taking it, and a tap goes straight to any stage — the canvas jumps a
/// stage that is not a neighbour without animating the ones in between. The
/// swipe still works; this is a second way, not a replacement.
class StageBar extends StatelessWidget {
  const StageBar({
    required this.labels,
    required this.index,
    required this.onSelect,
    this.locked = false,
    super.key,
  });

  /// What each page is called, in walk order. See [StageBar.labelsFor].
  final List<String> labels;

  /// The page on screen.
  final int index;

  final ValueChanged<int> onSelect;

  /// Whether the walk is holding a region's DNA open. Every stage but the gene
  /// is then out of reach until the reader returns to it.
  final bool locked;

  static const double height = 48;

  /// The names of a model's stages, and the fold after them.
  static List<String> labelsFor(AnatomyModel model) => <String>[
    for (final AnatomyStage stage in model.stages)
      switch (stage.kind) {
        StageKind.gene => 'Gene',
        StageKind.dna => 'DNA',
        StageKind.mrna => 'mRNA',
        StageKind.protein => 'Protein',
        StageKind.proprotein => 'Proprotein',
        StageKind.maturePeptides =>
          stage.blocks.length == 1 ? 'Chain' : 'Chains',
      },
    'Fold',
  ];

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    return SizedBox(
      height: height,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          for (int i = 0; i < labels.length; i++)
            _StageLabel(
              key: ValueKey<String>('stage-${labels[i]}'),
              label: labels[i],
              position: i,
              count: labels.length,
              selected: i == index,
              enabled: !locked || i == 0,
              color: i == index ? colors.onSurface : colors.onSurfaceVariant,
              accent: colors.primary,
              onTap: () {
                if (i == index) {
                  return;
                }
                onSelect(i);
              },
            ),
        ],
      ),
    );
  }
}

class _StageLabel extends StatelessWidget {
  const _StageLabel({
    required this.label,
    required this.position,
    required this.count,
    required this.selected,
    required this.enabled,
    required this.color,
    required this.accent,
    required this.onTap,
    super.key,
  });

  final String label;
  final int position;
  final int count;
  final bool selected;
  final bool enabled;
  final Color color;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Semantics(
      button: true,
      selected: selected,
      enabled: enabled,
      label: '$label, stage ${position + 1} of $count',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? onTap : null,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 44),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Text(
                  label,
                  maxLines: 1,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontSize: 13,
                    letterSpacing: 0.2,
                    color: enabled ? color : color.withValues(alpha: 0.4),
                  ),
                ),
                const SizedBox(height: 5),
                AnimatedContainer(
                  duration: MediaQuery.disableAnimationsOf(context)
                      ? Duration.zero
                      : const Duration(milliseconds: 220),
                  width: selected ? 18 : 4,
                  height: 3,
                  decoration: BoxDecoration(
                    color: selected ? accent : color.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
