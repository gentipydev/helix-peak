import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_spacing.dart';
import 'app_typography.dart';
import 'nucleotide_colors.dart';

abstract final class AppTheme {
  static ThemeData get dark => _build(
        tokens: AppColorTokens.dark,
        nucleotides: NucleotideColors.dark,
        brightness: Brightness.dark,
      );

  static ThemeData get light => _build(
        tokens: AppColorTokens.light,
        nucleotides: NucleotideColors.light,
        brightness: Brightness.light,
      );

  static ThemeData _build({
    required AppColorTokens tokens,
    required NucleotideColors nucleotides,
    required Brightness brightness,
  }) {
    final ColorScheme scheme = ColorScheme.fromSeed(
      seedColor: tokens.accent,
      brightness: brightness,
    ).copyWith(
      primary: tokens.accent,
      onPrimary: tokens.onAccent,
      primaryContainer: tokens.accentContainer,
      onPrimaryContainer: tokens.accent,
      secondary: tokens.accent,
      onSecondary: tokens.onAccent,
      surface: tokens.surfaceBase,
      onSurface: tokens.onSurface,
      onSurfaceVariant: tokens.onSurfaceVariant,
      surfaceContainerLowest: tokens.surfaceBase,
      surfaceContainerLow: tokens.surfaceRaised,
      surfaceContainer: tokens.surfaceRaised,
      surfaceContainerHigh: tokens.surfaceOverlay,
      surfaceContainerHighest: tokens.surfaceHigh,
      surfaceDim: tokens.surfaceBase,
      surfaceBright: tokens.surfaceHigh,
      outline: tokens.outline,
      outlineVariant: tokens.outline,
      error: tokens.error,
      onError: tokens.onError,
    );

    final TextTheme textTheme = AppTypography.textTheme(
      onSurface: tokens.onSurface,
      onSurfaceVariant: tokens.onSurfaceVariant,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      textTheme: textTheme,
      scaffoldBackgroundColor: tokens.surfaceBase,
      shadowColor: Colors.transparent,
      extensions: <ThemeExtension<dynamic>>[nucleotides],
      appBarTheme: AppBarTheme(
        backgroundColor: tokens.surfaceBase,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge,
        iconTheme: IconThemeData(color: tokens.onSurfaceVariant),
      ),
      dividerTheme: DividerThemeData(
        color: tokens.outline,
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: tokens.surfaceRaised,
        contentPadding: const EdgeInsets.all(AppSpacing.lg),
        hintStyle: AppTypography.sequenceBody(
          tokens.onSurfaceVariant.withValues(alpha: 0.5),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: tokens.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: tokens.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: tokens.accent, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: tokens.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: tokens.error, width: 1.5),
        ),
        errorStyle: textTheme.labelSmall?.copyWith(color: tokens.error),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: tokens.accent,
          foregroundColor: tokens.onAccent,
          disabledBackgroundColor: tokens.surfaceHigh,
          disabledForegroundColor: tokens.onSurfaceVariant,
          textStyle: textTheme.labelLarge,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: tokens.accent,
          textStyle: textTheme.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: tokens.accent,
          textStyle: textTheme.labelLarge,
          minimumSize: const Size.fromHeight(48),
          side: BorderSide(color: tokens.outline),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: tokens.accent,
        selectionColor: tokens.accent.withValues(alpha: 0.28),
        selectionHandleColor: tokens.accent,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: tokens.accent,
        linearTrackColor: tokens.surfaceHigh,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: tokens.surfaceHigh,
        contentTextStyle: textTheme.bodyMedium,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
