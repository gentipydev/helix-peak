import 'package:flutter/material.dart';

@immutable
final class AppColorTokens {
  const AppColorTokens({
    required this.surfaceBase,
    required this.surfaceRaised,
    required this.surfaceOverlay,
    required this.surfaceHigh,
    required this.outline,
    required this.onSurface,
    required this.onSurfaceVariant,
    required this.accent,
    required this.onAccent,
    required this.accentContainer,
    required this.error,
    required this.onError,
  });

  final Color surfaceBase;

  final Color surfaceRaised;

  final Color surfaceOverlay;

  final Color surfaceHigh;

  final Color outline;

  final Color onSurface;

  final Color onSurfaceVariant;

  final Color accent;

  final Color onAccent;

  final Color accentContainer;

  final Color error;
  final Color onError;

  static const AppColorTokens dark = AppColorTokens(
    surfaceBase: Color(0xFF0E1116),
    surfaceRaised: Color(0xFF141922),
    surfaceOverlay: Color(0xFF1B2230),
    surfaceHigh: Color(0xFF232C3D),
    outline: Color(0xFF2E3849),
    onSurface: Color(0xFFE6EAF2),
    onSurfaceVariant: Color(0xFF9BA6BC),
    accent: Color(0xFF4DD9C0),
    onAccent: Color(0xFF06231E),
    accentContainer: Color(0xFF0E3B34),
    error: Color(0xFFF4726A),
    onError: Color(0xFF2B0906),
  );

  /// The Protein Analyses flow: [dark]'s ramp, re-placed on a warm dark neutral.
  ///
  /// The ground is the change and the surfaces follow it. Each keeps the step
  /// it had above [dark]'s ground — 1.07, 1.19, 1.35 and 1.60 to one — because
  /// the count badge and the paginator are drawn in them, and [dark]'s overlay
  /// left on this ground sits at 1.09:1: a pill all but gone, in a blue nothing
  /// else on the page is. The inks are [dark]'s, and still clear this ground at
  /// 14.4, 7.1 and 9.9 to one.
  static const AppColorTokens warm = AppColorTokens(
    surfaceBase: Color(0xFF1C1A18),
    surfaceRaised: Color(0xFF23201E),
    surfaceOverlay: Color(0xFF2C2825),
    surfaceHigh: Color(0xFF35312E),
    outline: Color(0xFF413C38),
    onSurface: Color(0xFFE6EAF2),
    onSurfaceVariant: Color(0xFF9BA6BC),
    accent: Color(0xFF4DD9C0),
    onAccent: Color(0xFF06231E),
    accentContainer: Color(0xFF0E3B34),
    error: Color(0xFFF4726A),
    onError: Color(0xFF2B0906),
  );
}
