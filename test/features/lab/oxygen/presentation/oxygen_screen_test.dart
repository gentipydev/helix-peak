import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/core/theme/app_theme.dart';
import 'package:helixpeek/features/lab/oxygen/domain/binding_timeline.dart';
import 'package:helixpeek/features/lab/oxygen/domain/mwc.dart';
import 'package:helixpeek/features/lab/oxygen/domain/oxygen_morph.dart';
import 'package:helixpeek/features/lab/oxygen/presentation/oxygen_cubit.dart';
import 'package:helixpeek/features/lab/oxygen/presentation/oxygen_painters.dart';
import 'package:helixpeek/features/lab/oxygen/presentation/oxygen_screen.dart';
import 'package:vector_math/vector_math.dart' as vm;

import '../domain/binding_timeline_test.dart' show fixture;

final class _Source implements AssemblySource {
  _Source({this.missing = false, this.failing = false});

  final bool missing;
  final bool failing;

  @override
  Future<Uint8List?> morph(String slug) async {
    if (failing) {
      throw const SocketException('offline');
    }
    return missing ? null : File(fixture).readAsBytesSync();
  }
}

Future<void> _host(WidgetTester tester, AssemblySource source) async {
  await tester.binding.setSurfaceSize(const Size(420, 1400));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.analysis,
      home: OxygenRoute(source: source),
    ),
  );
  await tester.pump();
  await tester.pump();
}

String _text(WidgetTester tester, String key) =>
    tester.widget<Text>(find.byKey(ValueKey<String>(key))).data!;

void main() {
  testWidgets('the tetramer, its curve, and the model named as the mechanism', (
    WidgetTester tester,
  ) async {
    await _host(tester, _Source());
    expect(find.text('Oxygen · Hemoglobin A'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('oxygen-tetramer')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey<String>('oxygen-curve')), findsOneWidget);
    expect(
      _text(tester, 'oxygen-mechanism'),
      startsWith('Drawn by the MWC model'),
    );
    expect(
      _text(tester, 'oxygen-mechanism'),
      contains('Hill curve is fitted to it for reference'),
    );
    expect(_text(tester, 'oxygen-caption'), startsWith('One of four bound.'));
    await tester.tap(find.byTooltip('Step forward'));
    await tester.pump();
    expect(_text(tester, 'oxygen-caption'), startsWith('Two of four bound.'));
    expect(_text(tester, 'oxygen-states'), contains('2DN2'));
  });

  testWidgets('each toggle changes the curve and the animation together', (
    WidgetTester tester,
  ) async {
    await _host(tester, _Source());
    await tester.tap(find.text('Fetal'));
    await tester.pump();
    expect(
      _text(tester, 'oxygen-shift'),
      startsWith('Fetal: half-saturation at 19.0 mmHg'),
    );
    await tester.tap(find.text('pH 7.2'));
    await tester.pump();
    expect(_text(tester, 'oxygen-shift'), contains('Bohr effect'));
    await tester.tap(find.text('One site'));
    await tester.pump();
    expect(_text(tester, 'oxygen-mechanism'), contains('hyperbola'));
    expect(find.byKey(const ValueKey<String>('oxygen-tetramer')), findsNothing);
    expect(
      _text(tester, 'oxygen-caption'),
      startsWith('Oxygen binds its one site.'),
    );
  });

  testWidgets(
    'with no morph published it says so, and a failure is a failure',
    (WidgetTester tester) async {
      await _host(tester, _Source(missing: true));
      expect(
        find.byKey(const ValueKey<String>('oxygen-unavailable')),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    await _host(tester, _Source(failing: true));
      expect(find.text('Fetch failed'), findsOneWidget);
    },
  );

  testWidgets('the painters draw every step', (WidgetTester tester) async {
    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.analysis,
        home: Builder(
          builder: (BuildContext c) {
            context = c;
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    final OxygenMorph morph = OxygenMorph.decode(
      File(fixture).readAsBytesSync(),
      oxygenAssembly,
    );
    for (final Carrier carrier in Carrier.values) {
      final Mwc model = OxygenModel.of(carrier, 7.4);
      final BindingTimeline timeline = BindingTimeline(model);
      for (final double t in <double>[0, 0.2, 0.55, 0.9, 1]) {
        final ui.PictureRecorder recorder = ui.PictureRecorder();
        final Canvas canvas = Canvas(recorder);
        TetramerPainter(
          morph: morph,
          timeline: timeline,
          at: () => t,
          rotation: vm.Quaternion.identity,
          inks: TetramerInks.of(context),
        ).paint(canvas, const Size(390, 300));
        SaturationPainter(
          model: model,
          timeline: timeline,
          at: () => t,
          ink: Colors.black,
          quiet: Colors.grey,
          accent: Colors.blue,
          label: const TextStyle(fontSize: 11),
          baseline: OxygenModel.adult,
        ).paint(canvas, const Size(390, 170));
        recorder.endRecording().dispose();
      }
    }
    final BindingTimeline adult = BindingTimeline(OxygenModel.adult);
    expect(
      TetramerPainter.describe(morph, adult.stateAt(1)),
      'Hemoglobin A: 4 of 4 oxygen bound, drawn 100% of the way from tense to relaxed.',
    );
  });
}
