import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/core/theme/anatomy_colors.dart';
import 'package:helixpeek/core/theme/app_theme.dart';
import 'package:helixpeek/core/theme/nucleotide_colors.dart';
import 'package:helixpeek/features/peptide_lm/presentation/lm_inks.dart';

/// The training run is drawn in the app's colours and no others: its ground
/// and inks, its accent, the walk's residue colours and the home helix's
/// earth.
void main() {
  test('no colour in the peptide language model is written out as a number', () {
    final RegExp hex = RegExp(r'Color\(\s*0x');
    final RegExp literal = RegExp(r'Color\.from(ARGB|RGBO)\(');
    final RegExp packed = RegExp(r'0x[0-9A-Fa-f]{6,}');
    final List<String> found = <String>[];
    for (final FileSystemEntity entity in Directory(
      'lib/features/peptide_lm',
    ).listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) {
        continue;
      }
      final List<String> lines = entity.readAsLinesSync();
      for (int i = 0; i < lines.length; i++) {
        final String line = lines[i];
        if (hex.hasMatch(line) || literal.hasMatch(line) || packed.hasMatch(line)) {
          found.add('${entity.path}:${i + 1}: ${line.trim()}');
        }
      }
    }
    expect(found, isEmpty, reason: found.join('\n'));
  });

  testWidgets('every ink is the theme’s own', (WidgetTester tester) async {
    late LmInks inks;
    late ThemeData theme;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.analysis,
        home: Builder(
          builder: (BuildContext context) {
            inks = LmInks.of(context);
            theme = Theme.of(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    final AnatomyColors anatomy = theme.extension<AnatomyColors>()!;
    expect(inks.ground, theme.colorScheme.surface);
    expect(inks.signal, theme.colorScheme.primary);
    expect(inks.raised, theme.colorScheme.surfaceContainerLow);
    expect(inks.truth, anatomy.tracer);
    expect(inks.error, NucleotideColors.helix.guanine);
    expect(inks.negative, NucleotideColors.helix.cytosine);
    expect(inks.positive, NucleotideColors.helix.thymine);
    expect(inks.zero, anatomy.baseTile);
    expect(inks.residue('C'), anatomy.aminoCysteine);
    // The ends of the signed ramp are its two inks, and zero is the tile.
    expect(inks.signed(-1), inks.negative);
    expect(inks.signed(1), inks.positive);
    expect(inks.signed(0), inks.zero);
    // A number's tile is the ramp softened, from the same tile at zero.
    expect(inks.cell(0), inks.zero);
    expect(inks.cell(1), Color.lerp(inks.zero, inks.positive, LmInks.soft));
    expect(inks.cell(-1), Color.lerp(inks.zero, inks.negative, LmInks.soft));
  });
}
