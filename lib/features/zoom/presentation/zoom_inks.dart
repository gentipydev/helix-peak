import 'package:flutter/material.dart';

import '../../../core/theme/anatomy_colors.dart';
import '../../../core/theme/nucleotide_colors.dart';
import '../../../core/theme/scale_colors.dart';

/// Every colour the zoom draws with, from the theme: the app's own surfaces
/// and accent, the walk's base and gene-part colours, and the zoom's own
/// scale colours ([ScaleColors]).
@immutable
final class ZoomInks {
  const ZoomInks({
    required this.scale,
    required this.bases,
    required this.ground,
    required this.raised,
    required this.outline,
    required this.mark,
    required this.label,
    required this.text,
    required this.cds,
    required this.utr,
    required this.intron,
  });

  factory ZoomInks.of(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final AnatomyColors anatomy = context.anatomyColors;
    return ZoomInks(
      scale: context.scaleColors,
      bases: context.nucleotideColors,
      ground: scheme.surface,
      raised: scheme.surfaceContainerHigh,
      outline: scheme.outline,
      mark: scheme.primary,
      label: scheme.onSurfaceVariant,
      text: scheme.onSurface,
      cds: anatomy.roleCds,
      utr: anatomy.roleUtr5,
      intron: anatomy.roleIntron,
    );
  }

  final ScaleColors scale;
  final NucleotideColors bases;

  /// What the screen is drawn on, and a plate raised from it.
  final Color ground;
  final Color raised;
  final Color outline;

  /// What the zoom follows: the organ, the cell, the band, the gene.
  final Color mark;
  final Color label;
  final Color text;

  /// The gene's parts, in the walk's own colours.
  final Color cds;
  final Color utr;
  final Color intron;

  @override
  bool operator ==(Object other) =>
      other is ZoomInks &&
      other.scale == scale &&
      other.bases == bases &&
      other.ground == ground &&
      other.raised == raised &&
      other.outline == outline &&
      other.mark == mark &&
      other.label == label &&
      other.text == text &&
      other.cds == cds &&
      other.utr == utr &&
      other.intron == intron;

  @override
  int get hashCode => Object.hash(
    scale,
    bases,
    ground,
    raised,
    outline,
    mark,
    label,
    text,
    cds,
    utr,
    intron,
  );
}
