import 'package:flutter/material.dart';

import 'anatomy_colors.dart';
import 'app_colors.dart';
import 'app_spacing.dart';
import 'app_typography.dart';
import 'nucleotide_colors.dart';

abstract final class AppTheme {
  /// The app's theme, and the home screen's. The anatomy palette encodes
  /// importance as lightness against a near-black ground, an ordering that
  /// cannot simply be inverted for a pale one, so the app does not offer a
  /// light theme to invert it into.
  static ThemeData get dark => _build(
    tokens: AppColorTokens.dark,
    nucleotides: NucleotideColors.dark,
    anatomy: AnatomyColors.dark,
  );

  /// The Protein Analyses flow, from the moment its button is pressed.
  ///
  /// Still dark — the ordering above holds on any ground this near black — but
  /// warm: every surface moves onto [AppColorTokens.warm], the sequence is
  /// lettered in [NucleotideColors.muted], and the residues are filled through
  /// the Kaleido filter, [AnatomyColors.kaleido]. `GeneScreen` puts it around
  /// all it shows, so the wait, the failure and every page of the walk share
  /// one ground, and the home screen keeps its own.
  ///
  /// Final rather than a getter because a screen reads it in `build`, and
  /// `ColorScheme.fromSeed` is too much work to redo on every state change.
  static final ThemeData analysis = _build(
    tokens: AppColorTokens.warm,
    nucleotides: NucleotideColors.muted,
    anatomy: AnatomyColors.kaleido,
  );

  static ThemeData _build({
    required AppColorTokens tokens,
    required NucleotideColors nucleotides,
    required AnatomyColors anatomy,
  }) {
    const Brightness brightness = Brightness.dark;
    final ColorScheme scheme =
        ColorScheme.fromSeed(
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

    // No ripple anywhere, but a press still shows: a faint wash while the
    // finger is down, so a tap on a card or a button is seen to land.
    final WidgetStateProperty<Color?> pressed =
        WidgetStateProperty.resolveWith<Color?>(
          (Set<WidgetState> states) => states.contains(WidgetState.pressed)
              ? tokens.onSurface.withValues(alpha: 0.08)
              : Colors.transparent,
        );

    return ThemeData(
      useMaterial3: true,
      splashFactory: NoSplash.splashFactory,
      splashColor: Colors.transparent,
      highlightColor: tokens.onSurface.withValues(alpha: 0.06),
      hoverColor: Colors.transparent,
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(
          overlayColor: pressed,
          splashFactory: NoSplash.splashFactory,
        ),
      ),
      brightness: brightness,
      colorScheme: scheme,
      textTheme: textTheme,
      scaffoldBackgroundColor: tokens.surfaceBase,
      shadowColor: Colors.transparent,
      extensions: <ThemeExtension<dynamic>>[nucleotides, anatomy],
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
          splashFactory: NoSplash.splashFactory,
          backgroundColor: tokens.accent,
          foregroundColor: tokens.onAccent,
          disabledBackgroundColor: tokens.surfaceHigh,
          disabledForegroundColor: tokens.onSurfaceVariant,
          textStyle: textTheme.labelLarge,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ).copyWith(overlayColor: pressed),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          splashFactory: NoSplash.splashFactory,
          foregroundColor: tokens.accent,
          textStyle: textTheme.labelLarge,
        ).copyWith(overlayColor: pressed),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          splashFactory: NoSplash.splashFactory,
          foregroundColor: tokens.accent,
          textStyle: textTheme.labelLarge,
          minimumSize: const Size.fromHeight(48),
          side: BorderSide(color: tokens.outline),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ).copyWith(overlayColor: pressed),
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
