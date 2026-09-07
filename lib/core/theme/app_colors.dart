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

  static const AppColorTokens light = AppColorTokens(
    surfaceBase: Color(0xFFFAFAF8),
    surfaceRaised: Color(0xFFF2F3F0),
    surfaceOverlay: Color(0xFFEAECE8),
    surfaceHigh: Color(0xFFE2E5E0),
    outline: Color(0xFFCDD2CB),
    onSurface: Color(0xFF16191C),
    onSurfaceVariant: Color(0xFF5A6169),
    accent: Color(0xFF0E9B84),
    onAccent: Color(0xFFFFFFFF),
    accentContainer: Color(0xFFCFEDE6),
    error: Color(0xFFB3261E),
    onError: Color(0xFFFFFFFF),
  );
}
