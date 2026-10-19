import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/core/theme/anatomy_colors.dart';
import 'package:helixpeek/core/theme/app_theme.dart';
import 'package:helixpeek/core/theme/nucleotide_colors.dart';
import 'package:helixpeek/features/zoom/presentation/zoom_inks.dart';

/// The zoom draws in the app's colours and no others: its ground and
/// surfaces, its two inks and its accent, the walk's gene-part colours and
/// the home helix's bases, mixed. A colour of its own would be the zoom
/// drifting from the rest of the app, which is what its palette was.
void main() {
  test('no colour in the zoom is written out as a number', () {
    final RegExp hex = RegExp(r'Color\(\s*0x');
    // A layer's opacity is a colour with only its alpha: black, at that.
    final RegExp layer = RegExp(r'Color\.fromRGBO\(\s*0\s*,\s*0\s*,\s*0\s*,');
    final RegExp anyRgbo = RegExp(r'Color\.fromRGBO\(');
    final RegExp argb = RegExp(r'Color\.fromARGB\(');
    final List<String> found = <String>[];
    for (final FileSystemEntity entity in Directory(
      'lib/features/zoom',
    ).listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) {
        continue;
      }
      final List<String> lines = entity.readAsLinesSync();
      for (int i = 0; i < lines.length; i++) {
        final String line = lines[i];
        final int rgbo = anyRgbo.allMatches(line).length;
        if (hex.hasMatch(line) ||
            argb.hasMatch(line) ||
            rgbo != layer.allMatches(line).length) {
          found.add('${entity.path}:${i + 1}: ${line.trim()}');
        }
      }
    }
    expect(found, isEmpty, reason: found.join('\n'));
  });

  test('no colour is packed as a number where meshes are coloured', () {
    // The chromosome's and the pancreas's meshes take their colours as
    // packed integers, worked out from the inks: a literal there would be a
    // colour of its own.
    final RegExp literal = RegExp(r'0x[0-9A-Fa-f]{6,}');
    final List<String> found = <String>[];
    for (final FileSystemEntity entity in <FileSystemEntity>[
      ...Directory('lib/features/zoom/presentation/scenes/chromosome')
          .listSync(recursive: true),
      ...Directory('lib/features/zoom/presentation/scenes/pancreas')
          .listSync(recursive: true),
      File('lib/features/zoom/presentation/scenes/coloured_mesh.dart'),
    ]) {
      if (entity is! File || !entity.path.endsWith('.dart')) {
        continue;
      }
      final List<String> lines = entity.readAsLinesSync();
      for (int i = 0; i < lines.length; i++) {
        if (literal.hasMatch(lines[i])) {
          found.add('${entity.path}:${i + 1}: ${lines[i].trim()}');
        }
      }
    }
    expect(found, isEmpty, reason: found.join('\n'));
  });

  testWidgets('every ink is the theme’s own, or a mix of its own', (
    WidgetTester tester,
  ) async {
    late ZoomInks inks;
    late ThemeData theme;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.analysis,
        home: Builder(
          builder: (BuildContext context) {
            inks = ZoomInks.of(context);
            theme = Theme.of(context);
            return const SizedBox();
          },
        ),
      ),
    );
    final ColorScheme scheme = theme.colorScheme;
    expect(inks.ground, scheme.surface);
    expect(inks.raised, scheme.surfaceContainerLow);
    expect(inks.overlay, scheme.surfaceContainerHigh);
    expect(inks.high, scheme.surfaceContainerHighest);
    expect(inks.outline, scheme.outline);
    expect(inks.text, scheme.onSurface);
    expect(inks.label, scheme.onSurfaceVariant);
    // The gene, and what it makes, in the app's accent.
    expect(inks.mark, scheme.primary);
    expect(inks.markDeep, scheme.primaryContainer);
    // The helix is drawn as the home screen draws its own.
    expect(inks.bases, AppTheme.home.extension<NucleotideColors>());
    final AnatomyColors anatomy = theme.extension<AnatomyColors>()!;
    expect(inks.cds, anatomy.roleCds);
    expect(inks.utr, anatomy.roleUtr5);
    expect(inks.intron, anatomy.roleIntron);
    expect(inks.blood, theme.extension<NucleotideColors>()!.thymine);
    // Its tones run between the app's own.
    expect(inks.lit(0), scheme.outline);
    expect(inks.lit(1), scheme.onSurface);
    expect(inks.shade(0), scheme.surface);
    expect(inks.shade(1), scheme.outline);
    expect(inks.shade(0.5), scheme.surfaceContainerHigh);
  });
}
