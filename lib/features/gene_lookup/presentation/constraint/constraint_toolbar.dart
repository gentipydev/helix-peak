import 'package:flutter/material.dart';

import '../../../../core/biology/amino_acids.dart';
import '../../../../core/theme/anatomy_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/entities/gene_clinvar.dart';
import '../clinvar/clinvar_colors.dart';

import 'constraint_colors.dart';

/// The strip under a scored protein page: what its colours mean, and the switch
/// between chemistry and ESM-2 constraint.
///
/// The legend is the one thing that changes. With the switch off the squares
/// are coloured by chemistry, so the strip is that key — each colour with the
/// residues it stands for, which is what a reader needs to decode it, rather
/// than a group name they would have to map back to letters. With it on, the
/// squares are the constraint scale and the strip is that scale — and, for a
/// gene with ClinVar records, the key to the dots they carry, which is also the
/// way to every record.
class ConstraintToolbar extends StatelessWidget {
  const ConstraintToolbar({
    required this.conservation,
    required this.onChanged,
    this.onClinVar,
    super.key,
  });
  static const double height = 48;
  final bool conservation;
  final ValueChanged<bool> onChanged;

  /// Opens every ClinVar record of the gene; null for a gene without them.
  final VoidCallback? onClinVar;

  @override
  Widget build(BuildContext context) {
    final ThemeData base = Theme.of(context);
    final ThemeData theme = base.copyWith(
      textTheme: base.textTheme.apply(fontFamily: AppTypography.sansFamily),
    );
    return SizedBox(
      height: height,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: <Widget>[
            Expanded(
              child: conservation
                  ? Row(
                      children: <Widget>[
                        Text('low', style: theme.textTheme.labelSmall),
                        Expanded(
                          child: Container(
                            height: 4,
                            margin: const EdgeInsets.symmetric(horizontal: 8),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(2),
                              gradient: const LinearGradient(
                                colors: <Color>[
                                  ConstraintColors.tolerant,
                                  ConstraintColors.moderate,
                                  ConstraintColors.constrained,
                                ],
                              ),
                            ),
                          ),
                        ),
                        Text('high', style: theme.textTheme.labelSmall),
                        if (onClinVar case final VoidCallback open) ...<Widget>[
                          const SizedBox(width: 4),
                          _ClinVarKey(onTap: open),
                        ],
                      ],
                    )
                  : const ChemistryKey(),
            ),
            const SizedBox(width: 12),
            ExcludeSemantics(
              child: Text(
                'ESM-2',
                maxLines: 1,
                style: theme.textTheme.labelMedium,
              ),
            ),
            const SizedBox(width: 2),
            ConservationToggle(value: conservation, onChanged: onChanged),
          ],
        ),
      ),
    );
  }
}

/// The residue colours, each with the one-letter codes it stands for.
///
/// Seven chemistries and the cut site. The grouping is the app's own variant of
/// Zappo's — glycine and proline apart as the residues that decide where a
/// chain bends, histidine with the bases — so it is spelled out rather than
/// assumed.
class ChemistryKey extends StatelessWidget {
  const ChemistryKey({super.key});

  static const List<(AminoAcidProperty, String, String)> _groups =
      <(AminoAcidProperty, String, String)>[
        (AminoAcidProperty.aliphatic, 'AILMV', 'aliphatic'),
        (AminoAcidProperty.aromatic, 'FWY', 'aromatic'),
        (AminoAcidProperty.positive, 'HKR', 'positive'),
        (AminoAcidProperty.negative, 'DE', 'negative'),
        (AminoAcidProperty.polar, 'NQST', 'polar'),
        (AminoAcidProperty.special, 'GP', 'glycine and proline'),
        (AminoAcidProperty.cysteine, 'C', 'cysteine'),
      ];

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AnatomyColors palette = context.anatomyColors;
    final TextStyle label = AppTypography.sequenceSmall(
      theme.colorScheme.onSurfaceVariant,
    ).copyWith(fontSize: 10, letterSpacing: 0, height: 1);

    Widget item(Color colour, String text) => Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: colour,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 3),
        Text(text, style: label),
      ],
    );

    return Semantics(
      label:
          'Residue colours: '
          '${_groups.map(((AminoAcidProperty, String, String) g) => '${g.$3} ${g.$2.split('').join(' ')}').join('; ')}; '
          'cut site',
      excludeSemantics: true,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            for (final (AminoAcidProperty property, String codes, String _)
                in _groups) ...<Widget>[
              item(palette.forProperty(property), codes),
              const SizedBox(width: 8),
            ],
            item(palette.dibasic, 'cut'),
          ],
        ),
      ),
    );
  }
}

/// A thumb-reachable control grouped with its label and legend.
class ConservationToggle extends StatelessWidget {
  const ConservationToggle({
    required this.value,
    required this.onChanged,
    super.key,
  });

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Semantics(
      label: 'Colour residues by ESM-2 constraint',
      toggled: value,
      onTap: () => onChanged(!value),
      child: ExcludeSemantics(
        child: Tooltip(
          message: 'ESM-2 constraint',
          child: TextButton(
            key: const ValueKey<String>('conservation-toggle'),
            onPressed: () => onChanged(!value),
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: const Size(48, 48),
              fixedSize: const Size(48, 48),
              overlayColor: Colors.transparent,
              splashFactory: NoSplash.splashFactory,
              enableFeedback: false,
            ),
            child: Container(
              width: 44,
              height: 24,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: colors.surfaceContainerHigh,
                border: Border.all(
                  color: value ? colors.onSurfaceVariant : colors.outline,
                ),
              ),
              child: Align(
                alignment: value ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: value ? colors.onSurface : colors.onSurfaceVariant,
                  ),
                  child: value
                      ? Icon(
                          Icons.check_rounded,
                          size: 12,
                          color: colors.surface,
                        )
                      : null,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The dots' key in ESM mode, and the way into every record: three of the
/// class colours and the source's name, one tap target.
class _ClinVarKey extends StatelessWidget {
  const _ClinVarKey({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Semantics(
      button: true,
      label: 'ClinVar records',
      hint: 'Dots mark residues with ClinVar records. Opens all of them.',
      excludeSemantics: true,
      child: InkWell(
        key: const ValueKey<String>('clinvar-key'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                for (final ClinVarGroup group in const <ClinVarGroup>[
                  ClinVarGroup.pathogenic,
                  ClinVarGroup.uncertain,
                  ClinVarGroup.benign,
                ])
                  Padding(
                    padding: const EdgeInsets.only(right: 2),
                    child: ClinVarDot(group: group, size: 7),
                  ),
                const SizedBox(width: 4),
                Text('ClinVar ›', style: theme.textTheme.labelSmall),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
