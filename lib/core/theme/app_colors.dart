import 'package:flutter/material.dart';

/// The complete colour vocabulary of the app.
///
/// This is the only file in the codebase permitted to contain raw hex values.
/// Feature code reads colours from `Theme.of(context).colorScheme` or from the
/// [NucleotideColors] theme extension — never from here directly.
///
/// Elevation is expressed as *lightness*, not shadow. Each surface step is
/// both slightly lighter and slightly more saturated toward violet, which is
/// what reads as depth on a dark UI; `shadowColor` is set to transparent in
/// [AppTheme] so nothing leans on drop shadows.
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

  /// App background — the floor of the elevation ramp.
  final Color surfaceBase;

  /// Cards and panels resting on the background.
  final Color surfaceRaised;

  /// Elevated cards, sheets, menus.
  final Color surfaceOverlay;

  /// Inputs, pressed and hovered states — the top of the ramp.
  final Color surfaceHigh;

  /// Hairline dividers and input borders.
  final Color outline;

  /// Primary reading colour.
  final Color onSurface;

  /// Secondary text, captions, disabled states.
  final Color onSurfaceVariant;

  /// The single accent. Interactive elements, focus states, data highlights.
  final Color accent;

  /// Text and icons drawn on top of [accent] fills.
  final Color onAccent;

  /// Low-emphasis accent wash for tracks, selections, and subtle fills.
  final Color accentContainer;

  final Color error;
  final Color onError;

  /// Dark is the app's primary identity.
  ///
  /// The base is a desaturated slate with a blue-violet undertone rather than
  /// pure black, which flattens depth on OLED and reads cheap.
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

  /// The light theme is a genuine design, not an inversion of the dark one.
  ///
  /// The ground is warm-neutral paper rather than pure white, and the ramp
  /// climbs *down* in lightness. The range is deliberately much narrower than
  /// the dark ramp: light UIs separate surfaces with tint and hairlines, where
  /// dark UIs need large lightness steps to do the same work.
  static const AppColorTokens light = AppColorTokens(
    surfaceBase: Color(0xFFFAFAF8),
    surfaceRaised: Color(0xFFF2F3F0),
    surfaceOverlay: Color(0xFFEAECE8),
    surfaceHigh: Color(0xFFE2E5E0),
    outline: Color(0xFFCDD2CB),
    onSurface: Color(0xFF16191C),
    onSurfaceVariant: Color(0xFF5A6169),
    // The dark theme's bright teal fails text contrast on paper, so the light
    // theme deepens the same hue rather than reusing the value.
    accent: Color(0xFF0E9B84),
    onAccent: Color(0xFFFFFFFF),
    accentContainer: Color(0xFFCFEDE6),
    error: Color(0xFFB3261E),
    onError: Color(0xFFFFFFFF),
  );
}
