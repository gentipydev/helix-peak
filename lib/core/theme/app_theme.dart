import 'package:flutter/material.dart';

import 'anatomy_colors.dart';
import 'app_colors.dart';
import 'app_spacing.dart';
import 'app_typography.dart';
import 'nucleotide_colors.dart';

abstract final class AppTheme {
  /// The cool ground the app began on, which no screen wears now: the home
  /// screen was the last on it, and moved onto the warm one the rest of the
  /// app is on ([home]). It is kept for the walk's tests, which set the walk
  /// inside it to hold that the walk brings its own ground with it.
  ///
  /// The anatomy palette encodes importance as lightness against a near-black
  /// ground, an ordering that cannot simply be inverted for a pale one, so
  /// the app does not offer a light theme to invert it into.
  static ThemeData get dark => _build(
    tokens: AppColorTokens.dark,
    nucleotides: NucleotideColors.dark,
    anatomy: AnatomyColors.dark,
  );

  /// The app's theme, and the walk's first: it began as the Protein Analyses
  /// flow's own, from the moment its button was pressed.
  ///
  /// Still dark — the ordering above holds on any ground this near black — but
  /// warm: every surface moves onto [AppColorTokens.warm], the sequence is
  /// lettered in [NucleotideColors.muted], and the residues are filled through
  /// the Kaleido filter, [AnatomyColors.kaleido]. `GeneScreen` puts it around
  /// all it shows, so the wait, the failure and every page of the walk share
  /// one ground whatever the walk is opened inside.
  ///
  /// Final rather than a getter because a screen reads it in `build`, and
  /// a theme is too much work to build again on every state change.
  static final ThemeData analysis = _build(
    tokens: AppColorTokens.warm,
    nucleotides: NucleotideColors.muted,
    anatomy: AnatomyColors.kaleido,
  );

  /// The home screen: [analysis]'s ground, with the bases as the helix draws
  /// them.
  ///
  /// [NucleotideColors.muted] is for a sequence that is read, letter by
  /// letter. The helix on the home screen is a drawing of one, and is drawn in
  /// [NucleotideColors.helix]: the convention, warmed and softened to sit
  /// beside the accent rather than over it. The ground is the one every
  /// screen it leads to is on, so it no longer changes hue under the reader on
  /// the way in.
  static final ThemeData home = _build(
    tokens: AppColorTokens.warm,
    nucleotides: NucleotideColors.helix,
    anatomy: AnatomyColors.kaleido,
  );

  static ThemeData _build({
    required AppColorTokens tokens,
    required NucleotideColors nucleotides,
    required AnatomyColors anatomy,
  }) {
    const Brightness brightness = Brightness.dark;
    // Every role is told, or falls back to one that is. A scheme grown from a
    // seed fills in whatever it is not given with a teal-grey of Material's
    // own, and some widget's default then reaches for it: the snackbar's
    // action was one, a generated dark teal on the theme's dark surface, put
    // right by hand wherever a snackbar had an action.
    final ColorScheme scheme = ColorScheme(
      brightness: brightness,
      primary: tokens.accent,
      onPrimary: tokens.onAccent,
      primaryContainer: tokens.accentContainer,
      onPrimaryContainer: tokens.accent,
      secondary: tokens.accent,
      onSecondary: tokens.onAccent,
      secondaryContainer: tokens.accentContainer,
      onSecondaryContainer: tokens.accent,
      tertiary: tokens.accent,
      onTertiary: tokens.onAccent,
      tertiaryContainer: tokens.accentContainer,
      onTertiaryContainer: tokens.accent,
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
      // The tint `ErrorView` lays under its mark, as one colour.
      errorContainer: Color.alphaBlend(
        tokens.error.withValues(alpha: 0.12),
        tokens.surfaceBase,
      ),
      onErrorContainer: tokens.error,
      // There is no light surface to invert to: what Material calls the
      // inverse is the highest of the dark ones, as the snackbar already is.
      inverseSurface: tokens.surfaceHigh,
      onInverseSurface: tokens.onSurface,
      inversePrimary: tokens.accent,
      surfaceTint: Colors.transparent,
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

    // A field's hint, in the face and size of what is typed over it. It was
    // the sequence face, from when the field took a sequence, a size down:
    // the line changed face at the first keystroke. Quieter than the type it
    // stands in for, and still 4.5:1 on the field.
    final TextStyle? hint = textTheme.bodyLarge?.copyWith(
      color: tokens.onSurfaceVariant.withValues(alpha: 0.8),
    );

    // What floats over a page is told from it by a line, since nothing here
    // casts a shadow and a step of surface alone is 1.2:1.
    final BorderSide edge = BorderSide(color: tokens.outline);

    return ThemeData(
      useMaterial3: true,
      // [AppTypography.textTheme] names nine of Material's fifteen styles. The
      // other six are Material's own, `bodySmall` among them, and without
      // this they are set in the platform's face: a second typeface under
      // every heading that had a caption. The walk's sheets each put the sans
      // back by hand (`textTheme.apply`), which this makes the same style
      // twice over; what they draw does not change.
      fontFamily: AppTypography.sansFamily,
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
        hintStyle: hint,
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
      // What it says is read once, in passing, so it is said in the bright
      // ink. Its action and its close mark are named here: Material's own are
      // made for a light snackbar on a dark page, and all but vanished on
      // this one.
      snackBarTheme: SnackBarThemeData(
        backgroundColor: tokens.surfaceHigh,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: tokens.onSurface,
        ),
        actionTextColor: tokens.accent,
        closeIconColor: tokens.onSurfaceVariant,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          side: edge,
        ),
      ),
      // Material's own, on a dark theme, is a white bubble with black type.
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: tokens.surfaceHigh,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.fromBorderSide(edge),
        ),
        textStyle: textTheme.labelSmall?.copyWith(color: tokens.onSurface),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
      ),
      // Titled as a sheet is. Material's title is `headlineSmall`, which the
      // text theme leaves at Material's 24 points.
      dialogTheme: DialogThemeData(
        backgroundColor: tokens.surfaceOverlay,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: edge,
        ),
        titleTextStyle: textTheme.titleLarge,
        contentTextStyle: textTheme.bodyMedium,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: tokens.surfaceOverlay,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          side: edge,
        ),
      ),
      // A modal sheet, cut as the walk's own inspector is: its corners, and
      // its handle at the same strength. No line round it: it stands over a
      // scrim, where the inspector stands over the page.
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: tokens.surfaceRaised,
        modalBackgroundColor: tokens.surfaceRaised,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.sheet),
          ),
        ),
        dragHandleColor: tokens.onSurfaceVariant.withValues(alpha: 0.45),
        dragHandleSize: const Size(32, 4),
      ),
    );
  }
}
