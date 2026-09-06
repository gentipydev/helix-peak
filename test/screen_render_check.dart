// Temporary visual check — renders real screens with the bundled fonts
// loaded, so the composition and typography can be inspected.
// Not part of the test suite.
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeak/core/theme/app_theme.dart';
import 'package:helixpeak/features/home/presentation/screens/home_screen.dart';
import 'package:helixpeak/features/sequence_analysis/domain/entities/analysis_result.dart';
import 'package:helixpeak/features/sequence_analysis/domain/entities/nucleotide_counts.dart';
import 'package:helixpeak/features/sequence_analysis/domain/entities/sequence_input.dart';
import 'package:helixpeak/features/sequence_analysis/domain/entities/sequence_type.dart';
import 'package:helixpeak/features/sequence_analysis/presentation/widgets/composition_bar.dart';
import 'package:helixpeak/features/sequence_analysis/presentation/widgets/sequence_view.dart';
import 'package:helixpeak/features/sequence_analysis/presentation/widgets/stat_card.dart';

Future<void> _loadFont(String family, List<String> paths) async {
  final FontLoader loader = FontLoader(family);
  for (final String path in paths) {
    loader.addFont(
      Future<ByteData>.value(
        ByteData.view(File(path).readAsBytesSync().buffer),
      ),
    );
  }
  await loader.load();
}

Future<void> _capture(WidgetTester tester, String name) async {
  final RenderRepaintBoundary boundary =
      tester.firstRenderObject(find.byType(RepaintBoundary))
          as RenderRepaintBoundary;
  final ui.Image image = await boundary.toImage(pixelRatio: 2);
  final ByteData? bytes =
      await image.toByteData(format: ui.ImageByteFormat.png);
  File('${Platform.environment['SHOT_DIR']}/$name.png')
      .writeAsBytesSync(bytes!.buffer.asUint8List());
}

const String _bases =
    'ATGTTTGTTTTTCTTGTTTTATTGCCACTAGTCTCTAGTCAGTGTGTTAATCTTACAACC'
    'AGAACTCAATTACCCCCTGCATACACTAATTCTTTCACACGTGGTGTTTATTACCCTGAC';

void main() {
  setUpAll(() async {
    await _loadFont('SpaceGrotesk', <String>[
      'assets/fonts/SpaceGrotesk-Regular.ttf',
      'assets/fonts/SpaceGrotesk-Medium.ttf',
      'assets/fonts/SpaceGrotesk-Bold.ttf',
    ]);
    await _loadFont('JetBrainsMono', <String>[
      'assets/fonts/JetBrainsMono-Regular.ttf',
      'assets/fonts/JetBrainsMono-Medium.ttf',
    ]);
  });

  testWidgets('home screen', (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    await tester.pumpWidget(
      RepaintBoundary(
        child: MaterialApp(
          theme: AppTheme.dark,
          debugShowCheckedModeBanner: false,
          home: const HomeScreen(),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 3));
    await _capture(tester, 'home');
  });

  testWidgets('results pieces', (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 900));

    final SequenceInput input = SequenceInput(
      bases: _bases,
      sequenceType: SequenceType.dna,
      fastaHeader: 'sp|P0DTC2|SPIKE_SARS2 Surface glycoprotein',
    );
    final AnalysisResult result = AnalysisResult(
      id: 'demo',
      input: input,
      counts: NucleotideCounts.fromBases(_bases),
      meltingTemperatureCelsius: 71.4,
      molecularWeightDaltons: 37120,
      generatedAt: DateTime.utc(2026),
    );

    await tester.pumpWidget(
      RepaintBoundary(
        child: MaterialApp(
          theme: AppTheme.dark,
          debugShowCheckedModeBanner: false,
          home: Scaffold(
            body: SafeArea(
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: StatCard(
                          label: 'GC content',
                          value:
                              '${result.gcContentPercent.toStringAsFixed(1)}%',
                          caption: 'Guanine + cytosine',
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: StatCard(
                          label: 'Melting point',
                          value: '71.4°C',
                          caption: 'Estimated Tm',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  CompositionBar(counts: result.counts),
                  const SizedBox(height: 32),
                  SequenceView(bases: _bases),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await _capture(tester, 'results');
  });
}
