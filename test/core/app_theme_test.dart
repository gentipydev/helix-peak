import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/core/theme/app_colors.dart';
import 'package:helixpeek/core/theme/app_spacing.dart';
import 'package:helixpeek/core/theme/app_theme.dart';
import 'package:helixpeek/core/theme/app_typography.dart';
import 'package:helixpeek/core/theme/nucleotide_colors.dart';

double _contrast(Color a, Color b) {
  final double x = a.computeLuminance();
  final double y = b.computeLuminance();
  return (math.max(x, y) + 0.05) / (math.min(x, y) + 0.05);
}

/// Material's fifteen, by name.
List<(String, TextStyle?)> _styles(TextTheme type) => <(String, TextStyle?)>[
  ('displayLarge', type.displayLarge),
  ('displayMedium', type.displayMedium),
  ('displaySmall', type.displaySmall),
  ('headlineLarge', type.headlineLarge),
  ('headlineMedium', type.headlineMedium),
  ('headlineSmall', type.headlineSmall),
  ('titleLarge', type.titleLarge),
  ('titleMedium', type.titleMedium),
  ('titleSmall', type.titleSmall),
  ('bodyLarge', type.bodyLarge),
  ('bodyMedium', type.bodyMedium),
  ('bodySmall', type.bodySmall),
  ('labelLarge', type.labelLarge),
  ('labelMedium', type.labelMedium),
  ('labelSmall', type.labelSmall),
];

/// Every role a widget's default can reach for.
List<(String, Color)> _roles(ColorScheme scheme) => <(String, Color)>[
  ('primary', scheme.primary),
  ('onPrimary', scheme.onPrimary),
  ('primaryContainer', scheme.primaryContainer),
  ('onPrimaryContainer', scheme.onPrimaryContainer),
  ('primaryFixed', scheme.primaryFixed),
  ('primaryFixedDim', scheme.primaryFixedDim),
  ('onPrimaryFixed', scheme.onPrimaryFixed),
  ('onPrimaryFixedVariant', scheme.onPrimaryFixedVariant),
  ('secondary', scheme.secondary),
  ('onSecondary', scheme.onSecondary),
  ('secondaryContainer', scheme.secondaryContainer),
  ('onSecondaryContainer', scheme.onSecondaryContainer),
  ('secondaryFixed', scheme.secondaryFixed),
  ('secondaryFixedDim', scheme.secondaryFixedDim),
  ('onSecondaryFixed', scheme.onSecondaryFixed),
  ('onSecondaryFixedVariant', scheme.onSecondaryFixedVariant),
  ('tertiary', scheme.tertiary),
  ('onTertiary', scheme.onTertiary),
  ('tertiaryContainer', scheme.tertiaryContainer),
  ('onTertiaryContainer', scheme.onTertiaryContainer),
  ('tertiaryFixed', scheme.tertiaryFixed),
  ('tertiaryFixedDim', scheme.tertiaryFixedDim),
  ('onTertiaryFixed', scheme.onTertiaryFixed),
  ('onTertiaryFixedVariant', scheme.onTertiaryFixedVariant),
  ('error', scheme.error),
  ('onError', scheme.onError),
  ('errorContainer', scheme.errorContainer),
  ('onErrorContainer', scheme.onErrorContainer),
  ('surface', scheme.surface),
  ('onSurface', scheme.onSurface),
  ('onSurfaceVariant', scheme.onSurfaceVariant),
  ('surfaceDim', scheme.surfaceDim),
  ('surfaceBright', scheme.surfaceBright),
  ('surfaceContainerLowest', scheme.surfaceContainerLowest),
  ('surfaceContainerLow', scheme.surfaceContainerLow),
  ('surfaceContainer', scheme.surfaceContainer),
  ('surfaceContainerHigh', scheme.surfaceContainerHigh),
  ('surfaceContainerHighest', scheme.surfaceContainerHighest),
  ('outline', scheme.outline),
  ('outlineVariant', scheme.outlineVariant),
  ('inverseSurface', scheme.inverseSurface),
  ('onInverseSurface', scheme.onInverseSurface),
  ('inversePrimary', scheme.inversePrimary),
  ('surfaceTint', scheme.surfaceTint),
  ('shadow', scheme.shadow),
  ('scrim', scheme.scrim),
];

/// The theme as a widget under it reads it: the text theme's own values over
/// Material's geometry, which `ThemeData` alone does not carry.
Future<ThemeData> _read(WidgetTester tester, ThemeData theme) async {
  late ThemeData read;
  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
      home: Builder(
        builder: (BuildContext context) {
          read = Theme.of(context);
          return const SizedBox.shrink();
        },
      ),
    ),
  );
  return read;
}

void main() {
  final Map<String, (ThemeData, AppColorTokens)> themes =
      <String, (ThemeData, AppColorTokens)>{
        'the cool ground': (AppTheme.dark, AppColorTokens.dark),
        'the app': (AppTheme.analysis, AppColorTokens.warm),
        'the home screen': (AppTheme.home, AppColorTokens.warm),
      };

  for (final MapEntry<String, (ThemeData, AppColorTokens)> entry
      in themes.entries) {
    final (ThemeData theme, AppColorTokens tokens) = entry.value;

    group(entry.key, () {
      testWidgets('sets every one of Material\'s styles in the app\'s face', (
        WidgetTester tester,
      ) async {
        // Six of the fifteen are not named by the text theme. Left to
        // Material they were set in the platform's face, which drew a second
        // typeface under every heading that had a caption.
        final ThemeData read = await _read(tester, theme);
        for (final (String name, TextStyle? style) in _styles(read.textTheme)) {
          expect(style, isNotNull, reason: name);
          expect(style!.fontFamily, AppTypography.sansFamily, reason: name);
          expect(style.fontSize, isNotNull, reason: name);
        }
      });

      testWidgets('keeps the small print the walk\'s sheets were drawn in', (
        WidgetTester tester,
      ) async {
        // The walk's sheets read `bodySmall` and `labelMedium` with the sans
        // put back by hand. Those two must stay what that made of them, to
        // the last figure, or every sheet moves.
        final ThemeData read = await _read(tester, theme);
        final TextTheme type = read.textTheme;

        final TextStyle small = type.bodySmall!;
        expect(small.fontSize, 12);
        expect(small.fontWeight, FontWeight.w400);
        expect(small.letterSpacing, 0.4);
        expect(small.height, 1.33);
        expect(small.color, tokens.onSurface);

        final TextStyle label = type.labelMedium!;
        expect(label.fontSize, 12);
        expect(label.fontWeight, FontWeight.w500);
        expect(label.letterSpacing, 0.5);
        expect(label.height, 1.33);
        expect(label.color, tokens.onSurface);

        // What the sheets do by hand now changes nothing.
        final TextTheme patched = type.apply(
          fontFamily: AppTypography.sansFamily,
        );
        expect(patched.bodySmall, small);
        expect(patched.labelMedium, label);
      });

      test('leaves no role of its scheme to a seed', () {
        // A role nobody named was a teal-grey Material grew from the accent.
        final Set<Color> own = <Color>{
          tokens.surfaceBase,
          tokens.surfaceRaised,
          tokens.surfaceOverlay,
          tokens.surfaceHigh,
          tokens.outline,
          tokens.onSurface,
          tokens.onSurfaceVariant,
          tokens.accent,
          tokens.onAccent,
          tokens.accentContainer,
          tokens.error,
          tokens.onError,
          Color.alphaBlend(
            tokens.error.withValues(alpha: 0.12),
            tokens.surfaceBase,
          ),
          Colors.transparent,
          const Color(0xFF000000),
        };
        for (final (String name, Color colour) in _roles(theme.colorScheme)) {
          expect(own, contains(colour), reason: '$name is $colour');
        }
      });

      test('draws what floats over a page in its own surfaces', () {
        final BoxDecoration tip =
            theme.tooltipTheme.decoration! as BoxDecoration;
        expect(tip.color, tokens.surfaceHigh);
        expect(theme.tooltipTheme.textStyle!.color, tokens.onSurface);
        expect(
          theme.tooltipTheme.textStyle!.fontFamily,
          AppTypography.sansFamily,
        );

        final SnackBarThemeData snack = theme.snackBarTheme;
        expect(snack.backgroundColor, tokens.surfaceHigh);
        expect(snack.actionTextColor, tokens.accent);
        expect(snack.closeIconColor, tokens.onSurfaceVariant);
        expect(snack.contentTextStyle!.color, tokens.onSurface);

        expect(theme.dialogTheme.backgroundColor, tokens.surfaceOverlay);
        // Titled as a sheet is, not in Material's 24 points.
        final TextStyle title = theme.dialogTheme.titleTextStyle!;
        final TextStyle sheetTitle = theme.textTheme.titleLarge!;
        expect(title.fontFamily, sheetTitle.fontFamily);
        expect(title.fontSize, sheetTitle.fontSize);
        expect(title.fontWeight, sheetTitle.fontWeight);
        expect(title.color, tokens.onSurface);
        expect(theme.popupMenuTheme.color, tokens.surfaceOverlay);

        final BottomSheetThemeData sheet = theme.bottomSheetTheme;
        expect(sheet.backgroundColor, tokens.surfaceRaised);
        expect(sheet.modalBackgroundColor, tokens.surfaceRaised);
        expect(
          sheet.shape,
          const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(AppRadius.sheet),
            ),
          ),
        );
      });

      test('sets a field\'s hint as what is typed over it, and legibly', () {
        final InputDecorationThemeData field = theme.inputDecorationTheme;
        final TextStyle hint = field.hintStyle!;
        final TextStyle typed = theme.textTheme.bodyLarge!;
        expect(hint.fontFamily, typed.fontFamily);
        expect(hint.fontSize, typed.fontSize);
        expect(hint.height, typed.height);

        final Color drawn = Color.alphaBlend(hint.color!, field.fillColor!);
        expect(_contrast(drawn, field.fillColor!), greaterThanOrEqualTo(4.5));
        // Still a hint: quieter than the quiet ink.
        expect(
          _contrast(drawn, field.fillColor!),
          lessThan(_contrast(tokens.onSurfaceVariant, field.fillColor!)),
        );
      });
    });
  }

  test('the home screen is on the app\'s ground, its bases at full strength', () {
    expect(
      AppTheme.home.scaffoldBackgroundColor,
      AppTheme.analysis.scaffoldBackgroundColor,
    );
    expect(AppTheme.home.colorScheme.surface, AppColorTokens.warm.surfaceBase);
    expect(AppTheme.home.extension<NucleotideColors>(), NucleotideColors.dark);
    // The walk's own are the muted ones, on the same ground.
    expect(
      AppTheme.analysis.extension<NucleotideColors>(),
      NucleotideColors.muted,
    );
  });

  test('small print is the theme\'s smallest body style in the quiet ink', () {
    final ThemeData theme = AppTheme.analysis;
    expect(
      theme.caption,
      theme.textTheme.bodySmall!.copyWith(
        color: AppColorTokens.warm.onSurfaceVariant,
      ),
    );
    expect(theme.cardBody!.fontSize, 13);
    expect(theme.cardBody!.color, AppColorTokens.warm.onSurfaceVariant);
    expect(AppTypography.spec(Colors.white).fontSize, 11);
    expect(AppTypography.spec(Colors.white).letterSpacing, 0);
    expect(
      AppTypography.spec(Colors.white).fontFamily,
      AppTypography.monoFamily,
    );
  });
}
