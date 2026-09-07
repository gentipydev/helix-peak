import 'package:flutter/material.dart';

abstract final class AppTypography {
  static const String sansFamily = 'SpaceGrotesk';
  static const String monoFamily = 'JetBrainsMono';

  static const List<String> _sansFallback = <String>[
    'Roboto',
    'Helvetica Neue',
    'Arial',
    'sans-serif',
  ];

  static const List<String> _monoFallback = <String>[
    'Menlo',
    'Consolas',
    'Courier New',
    'monospace',
  ];

  static TextTheme textTheme({
    required Color onSurface,
    required Color onSurfaceVariant,
  }) {
    return TextTheme(
      displayLarge: TextStyle(
        fontFamily: sansFamily,
        fontFamilyFallback: _sansFallback,
        fontSize: 40,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
        height: 1.1,
        color: onSurface,
      ),
      displayMedium: TextStyle(
        fontFamily: sansFamily,
        fontFamilyFallback: _sansFallback,
        fontSize: 32,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.4,
        height: 1.15,
        color: onSurface,
      ),
      headlineMedium: TextStyle(
        fontFamily: sansFamily,
        fontFamilyFallback: _sansFallback,
        fontSize: 24,
        fontWeight: FontWeight.w500,
        letterSpacing: -0.2,
        height: 1.25,
        color: onSurface,
      ),
      titleLarge: TextStyle(
        fontFamily: sansFamily,
        fontFamilyFallback: _sansFallback,
        fontSize: 20,
        fontWeight: FontWeight.w500,
        height: 1.3,
        color: onSurface,
      ),
      titleSmall: TextStyle(
        fontFamily: sansFamily,
        fontFamilyFallback: _sansFallback,
        fontSize: 15,
        fontWeight: FontWeight.w500,
        height: 1.35,
        color: onSurface,
      ),
      bodyLarge: TextStyle(
        fontFamily: sansFamily,
        fontFamilyFallback: _sansFallback,
        fontSize: 16,
        fontWeight: FontWeight.w400,
        height: 1.5,
        color: onSurface,
      ),
      bodyMedium: TextStyle(
        fontFamily: sansFamily,
        fontFamilyFallback: _sansFallback,
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 1.5,
        color: onSurfaceVariant,
      ),
      labelLarge: TextStyle(
        fontFamily: sansFamily,
        fontFamilyFallback: _sansFallback,
        fontSize: 14,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.3,
        color: onSurface,
      ),
      labelSmall: TextStyle(
        fontFamily: sansFamily,
        fontFamilyFallback: _sansFallback,
        fontSize: 12,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.6,
        color: onSurfaceVariant,
      ),
    );
  }

  static TextStyle wordmark(Color color) => TextStyle(
        fontFamily: sansFamily,
        fontFamilyFallback: _sansFallback,
        fontSize: 30,
        fontWeight: FontWeight.w700,
        letterSpacing: 6,
        color: color,
      );

  static TextStyle sequenceBody(Color color) => TextStyle(
        fontFamily: monoFamily,
        fontFamilyFallback: _monoFallback,
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 1.6,
        letterSpacing: 0.6,
        color: color,
      );

  static TextStyle sequenceSmall(Color color) => TextStyle(
        fontFamily: monoFamily,
        fontFamilyFallback: _monoFallback,
        fontSize: 12,
        fontWeight: FontWeight.w400,
        height: 1.5,
        letterSpacing: 0.5,
        color: color,
      );

  static TextStyle statValue(Color color) => TextStyle(
        fontFamily: monoFamily,
        fontFamilyFallback: _monoFallback,
        fontSize: 26,
        fontWeight: FontWeight.w500,
        height: 1.1,
        color: color,
      );
}
