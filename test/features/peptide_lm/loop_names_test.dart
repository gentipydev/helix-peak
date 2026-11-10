import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/core/theme/app_theme.dart';
import 'package:helixpeek/core/theme/app_typography.dart';
import 'package:helixpeek/features/peptide_lm/domain/training_trace.dart';
import 'package:helixpeek/features/peptide_lm/presentation/lm_inks.dart';
import 'package:helixpeek/features/peptide_lm/presentation/scenes/lm_drawing.dart';
import 'package:helixpeek/features/peptide_lm/presentation/scenes/lm_scene.dart';
import 'package:helixpeek/features/peptide_lm/presentation/scenes/loop_scene.dart';

import '../gene_lookup/anatomy/anatomy_fixture.dart';
import 'support/toy_trace.dart';

// In the app's own fonts, which the scene tests' square glyphs are not: what
// Loop writes in the gutter at its plot's left, measured as a phone draws it.
void main() {
  setUpAll(loadAppFonts);

  testWidgets("Loop names its two scales on the canvas, and writes the first steps' loss clear of them", (
    WidgetTester tester,
  ) async {
    late LmInks inks;
    late LmKit kit;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.analysis,
        home: Builder(
          builder: (BuildContext context) {
            final ThemeData theme = Theme.of(context);
            inks = LmInks.of(context);
            kit = LmKit(
              mono: AppTypography.sequenceSmall(theme.colorScheme.onSurfaceVariant),
              sans: theme.caption!,
              label: theme.textTheme.labelSmall,
              scaler: TextScaler.noScaling,
            );
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    addTearDown(kit.dispose);
    final TrainingTrace trace = toyTrace();
    final LmView view = LmView(
      trace: trace,
      checkpoint: trace.checkpoints.first,
      peptide: 0,
      position: 3,
      head: null,
      inks: inks,
      kit: kit,
    );
    // A 375-point phone's canvas, a 17 Pro's and a Pro Max's.
    for (final Size size in const <Size>[Size(375, 476), Size(402, 619), Size(440, 697)]) {
      final LoopLayout layout = LoopLayout(size, view);
      // "nats" over the curve's scale, "rate" by the rate's strip: alike, and
      // both whole on the canvas.
      for (final String name in <String>['nats', 'rate']) {
        final double wide = kit.layout(name, LoopScene.nameStyle(view, 1)).width;
        expect(layout.namesRight - wide, greaterThanOrEqualTo(0), reason: '$name at $size');
      }
      // The loss written by a point at the plot's left edge, its ground
      // backing (1.5) included, starts clear of the name over the scale.
      for (int step = 1; layout.x(step.toDouble()) < layout.plot.left + 24; step++) {
        expect(
          layout.writtenLeft(layout.x(step.toDouble())) - 1.5,
          greaterThanOrEqualTo(layout.namesRight + 4),
          reason: 'step $step at $size',
        );
      }
    }
  });
}
