import 'package:flutter/material.dart';

/// The type scale.
///
/// Two families, each with a job:
///
/// * **Space Grotesk** — a neo-grotesque with enough geometric character to
///   give the wordmark and headings a technical voice, used for the interface.
/// * **JetBrains Mono** — used for *every* piece of sequence data. Sequences
///   are always monospace: column alignment is meaningful, and a user
///   verifying bases by eye needs `0`/`O` and `1`/`l`/`I` to be unmistakable.
///
/// Call sites use named styles from the theme. There are no ad-hoc `fontSize`
/// values in feature code.
abstract final class AppTypography {
  static const String sansFamily = 'SpaceGrotesk';
  static const String monoFamily = 'JetBrainsMono';

  /// Declared on every style so the app still renders legibly if a bundled
  /// face fails to load, rather than falling back to a default that may not
  /// cover the glyphs.
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

  /// Builds the interface type scale in the given foreground colours.
  static TextTheme textTheme({
    required Color onSurface,
    required Color onSurfaceVariant,
  }) {
    return TextTheme(
      // Reserved for the wordmark and hero moments.
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
      // Overlines and captions. Wide tracking at small sizes is what makes
      // dense metadata scannable rather than cramped.
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

  /// The wordmark: wide tracking, set in caps at the call site.
  static TextStyle wordmark(Color color) => TextStyle(
        fontFamily: sansFamily,
        fontFamilyFallback: _sansFallback,
        fontSize: 30,
        fontWeight: FontWeight.w700,
        letterSpacing: 6,
        color: color,
      );

  /// Sequence data at reading size.
  ///
  /// The slight extra letter spacing is deliberate: it separates adjacent
  /// bases in long runs (`AAAAA`) so they can be counted by eye.
  static TextStyle sequenceBody(Color color) => TextStyle(
        fontFamily: monoFamily,
        fontFamilyFallback: _monoFallback,
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 1.6,
        letterSpacing: 0.6,
        color: color,
      );

  /// Sequence data in dense contexts — previews, inline runs, counters.
  static TextStyle sequenceSmall(Color color) => TextStyle(
        fontFamily: monoFamily,
        fontFamilyFallback: _monoFallback,
        fontSize: 12,
        fontWeight: FontWeight.w400,
        height: 1.5,
        letterSpacing: 0.5,
        color: color,
      );

  /// A single base, set to sit inside a shape that stands for it.
  ///
  /// The one style here that takes its size from the caller, and the exception
  /// earns itself: this letter is not set in a paragraph, it is set inside a
  /// nucleotide drawn on a canvas, so what governs it is the size of that
  /// molecule rather than the type scale. Medium rather than regular, because
  /// a lone glyph reversed out of a saturated fill needs the extra weight to
  /// hold its counters at these sizes.
  static TextStyle baseGlyph(Color color, double size) => TextStyle(
        fontFamily: monoFamily,
        fontFamilyFallback: _monoFallback,
        fontSize: size,
        fontWeight: FontWeight.w500,
        height: 1,
        color: color,
      );

  /// Numeric readouts on the results screen. Monospace keeps figures from
  /// jittering as values change.
  static TextStyle statValue(Color color) => TextStyle(
        fontFamily: monoFamily,
        fontFamilyFallback: _monoFallback,
        fontSize: 26,
        fontWeight: FontWeight.w500,
        height: 1.1,
        color: color,
      );
}
