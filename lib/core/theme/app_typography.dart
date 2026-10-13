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

  /// A card's line of figures: an accession, a length, a count.
  ///
  /// [sequenceSmall] a point down and untracked, so that five figures and the
  /// dots between them fit a phone's width on one line.
  static TextStyle spec(Color color) =>
      sequenceSmall(color).copyWith(fontSize: 11, letterSpacing: 0);

  /// The note under the tracer's line: the fact its name and size do not give.
  ///
  /// Deliberately the smallest type in the app. It is a footnote to the line
  /// above it and must never compete with the count, so it is set below the
  /// body scale and carries no weight of its own.
  static TextStyle anatomyNote(Color color) => TextStyle(
        fontFamily: sansFamily,
        fontFamilyFallback: _sansFallback,
        fontSize: 11,
        fontWeight: FontWeight.w400,
        height: 1.35,
        color: color,
      );

  /// The one number the anatomy screen is about, set as a badge.
  ///
  /// Watching it fall from 1,431 to 82 is still the narrative, but a number is
  /// what the picture *is about* rather than what the picture *is*: at 44pt it
  /// was the largest thing on a screen whose subject is a grid of 1,431 cells,
  /// and it was charging the grid a display line's worth of height to say so.
  /// Nineteen points of semibold mono in a pill holds the same reading — the
  /// digits are still the widest thing in the header and still change under the
  /// reader on every swipe — and hands the difference back to the map.
  ///
  /// Mono, and mono for the reason it always was: the count is the one number
  /// on the screen that changes in place, and a proportional 1 against a
  /// proportional 4 would make it shuffle sideways while it fell.
  ///
  /// Medium rather than semibold because [monoFamily] ships 400 and 500 and
  /// nothing heavier — a `w600` here would resolve to this same face without
  /// saying so, and at 19pt on a raised pill Medium is already the weight a
  /// semibold was being asked for.
  static TextStyle anatomyCount(Color color) => TextStyle(
        fontFamily: monoFamily,
        fontFamilyFallback: _monoFallback,
        fontSize: 19,
        fontWeight: FontWeight.w500,
        height: 1,
        letterSpacing: -0.3,
        color: color,
      );
}

/// The styles a screen builds from the theme's own, named once here so that
/// each is one style wherever it is set.
extension AppTextStyles on ThemeData {
  /// Small print: a line under a heading, a note beside a figure.
  ///
  /// `bodySmall` on its own is Material's, in the bright ink, which made the
  /// small print under a line of body text the louder of the two. This is
  /// that style in the quiet ink.
  TextStyle? get caption =>
      textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant);

  /// A line of prose on a card: body type a step down, so that two lines of
  /// it sit under a name without the row growing past a thumb's reach.
  TextStyle? get cardBody =>
      textTheme.bodyMedium?.copyWith(fontSize: 13, height: 1.35);
}
