import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/shared/motion/animation_timeline.dart';
import 'package:helixpeek/shared/motion/timeline_controller.dart';
import 'package:helixpeek/shared/motion/transport_bar.dart';

final class _Two extends AnimationTimeline<double> {
  const _Two();

  @override
  int get beats => 2;

  @override
  List<PhaseMark> get phases => const <PhaseMark>[
    PhaseMark(name: 'Forward', t: 0, captionKey: 'forward'),
    PhaseMark(name: 'Backward', t: 0.5, captionKey: 'backward'),
  ];

  @override
  double stateAt(double t) => t;
}

void main() {
  late TimelineController controller;

  setUp(() {
    controller = TimelineController(
      vsync: const TestVSync(),
      timeline: const _Two(),
      beat: const Duration(milliseconds: 100),
    );
  });
  tearDown(() => controller.dispose());

  Future<void> host(WidgetTester tester, TransportBar bar) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: Center(child: bar))));
    await tester.pump();
  }

  testWidgets('by default the bar names the phase on screen', (
    WidgetTester tester,
  ) async {
    await host(tester, TransportBar(controller: controller));
    expect(find.byKey(const ValueKey<String>('transport-phase')), findsOneWidget);
    expect(find.text('Forward'), findsOneWidget);
  });

  testWidgets('a page that names the phase itself can leave it out', (
    WidgetTester tester,
  ) async {
    await host(tester, TransportBar(controller: controller, showPhase: false));
    expect(find.byKey(const ValueKey<String>('transport-phase')), findsNothing);
    expect(find.text('Forward'), findsNothing);
    // The controls are all still there.
    expect(find.byTooltip('Play'), findsOneWidget);
    expect(find.byTooltip('Step forward'), findsOneWidget);
    await tester.tap(find.byTooltip('Step forward'));
    await tester.pump();
    expect(controller.phase?.name, 'Backward');
  });
}
