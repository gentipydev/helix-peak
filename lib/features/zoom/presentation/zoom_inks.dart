import 'package:flutter/material.dart';

import '../../../core/theme/anatomy_colors.dart';
import '../../../core/theme/nucleotide_colors.dart';

/// Every colour the zoom draws with, and all of them the app's own: the
/// ground and surfaces every screen is on, its two inks, its accent, the
/// walk's gene-part colours and the home helix's bases. Nothing here is a
/// colour of its own; the zoom's tones are the app's, mixed.
///
/// The zoom draws in two voices:
/// - **The mark**, the app's accent, is the gene and what it makes, at every
///   scale: the organs its RNA is raised in, its cell, where its protein
///   sits, its chromosome, its band, its gene, its RNA. Nothing else is
///   teal.
/// - **Form**, everything else, is sculpted in the app's warm neutrals: the
///   surfaces for what is in shade, [lit] (the outline lifted toward the
///   ink) for what the light falls on, and the quiet ink for fine line work.
///
/// Data keeps its own colours where it has them: the gene's parts are the
/// walk's, the bases the home helix's, blood the thymine red.
@immutable
final class ZoomInks {
  const ZoomInks({
    required this.ground,
    required this.raised,
    required this.overlay,
    required this.high,
    required this.outline,
    required this.text,
    required this.label,
    required this.mark,
    required this.markDeep,
    required this.shadow,
    required this.blood,
    required this.bases,
    required this.cds,
    required this.utr,
    required this.intron,
  });

  factory ZoomInks.of(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final AnatomyColors anatomy = context.anatomyColors;
    return ZoomInks(
      ground: scheme.surface,
      raised: scheme.surfaceContainerLow,
      overlay: scheme.surfaceContainerHigh,
      high: scheme.surfaceContainerHighest,
      outline: scheme.outline,
      text: scheme.onSurface,
      label: scheme.onSurfaceVariant,
      mark: scheme.primary,
      markDeep: scheme.primaryContainer,
      // No light at all: the ground, most of the way to black.
      shadow: Color.lerp(scheme.surface, Colors.black, 0.75)!,
      // The sequence's thymine, as the walk letters it: the one red the app
      // has, quiet enough to sit in a stained field.
      blood: context.nucleotideColors.thymine,
      // The helix is a drawing of one, as the home screen's is, in the
      // home helix's own bases (`AppTheme.home`).
      bases: NucleotideColors.helix,
      cds: anatomy.roleCds,
      utr: anatomy.roleUtr5,
      intron: anatomy.roleIntron,
    );
  }

  /// The ground every stop is on, and the app's surfaces raised from it:
  /// the zoom's shade, darkest first.
  final Color ground;
  final Color raised;
  final Color overlay;
  final Color high;
  final Color outline;

  /// The bright ink and the quiet one.
  final Color text;
  final Color label;

  /// The gene and what it makes, and the same hue deep in shade.
  final Color mark;
  final Color markDeep;

  /// Where no light falls: under a form, at the bottom of a groove.
  final Color shadow;

  final Color blood;
  final NucleotideColors bases;

  /// The gene's parts, in the walk's own colours.
  final Color cds;
  final Color utr;
  final Color intron;

  /// Light falling on a form: the outline lifted [t] of the way toward the
  /// bright ink. Half way is as light as a form is drawn.
  Color lit(double t) => Color.lerp(outline, text, t)!;

  /// A form in shade, from the ground at 0 through the surfaces to the
  /// outline at 1.
  Color shade(double t) {
    final List<Color> ramp = <Color>[ground, raised, overlay, high, outline];
    final double x = t.clamp(0.0, 1.0) * (ramp.length - 1);
    final int i = x.floor().clamp(0, ramp.length - 2);
    return Color.lerp(ramp[i], ramp[i + 1], x - i)!;
  }

  /// The mark at [alpha].
  Color glow(double alpha) => mark.withValues(alpha: alpha.clamp(0.0, 1.0));

  @override
  bool operator ==(Object other) =>
      other is ZoomInks &&
      other.ground == ground &&
      other.raised == raised &&
      other.overlay == overlay &&
      other.high == high &&
      other.outline == outline &&
      other.text == text &&
      other.label == label &&
      other.mark == mark &&
      other.markDeep == markDeep &&
      other.shadow == shadow &&
      other.blood == blood &&
      other.bases == bases &&
      other.cds == cds &&
      other.utr == utr &&
      other.intron == intron;

  @override
  int get hashCode => Object.hash(
    ground,
    raised,
    overlay,
    high,
    outline,
    text,
    label,
    mark,
    markDeep,
    shadow,
    blood,
    bases,
    cds,
    utr,
    intron,
  );
}
