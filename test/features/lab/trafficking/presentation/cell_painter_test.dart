import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/core/catalog/protein_target.dart';
import 'package:helixpeek/core/theme/app_theme.dart';
import 'package:helixpeek/features/lab/trafficking/domain/route_timeline.dart';
import 'package:helixpeek/features/lab/trafficking/domain/trafficking_route.dart';
import 'package:helixpeek/features/lab/trafficking/presentation/cell_painter.dart';

import '../../../../support/test_catalog.dart';
import '../trafficking_fixtures.dart';

/// The inks as the lab's theme gives them.
Future<CellInks> _inks(WidgetTester tester) async {
  late CellInks inks;
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.analysis,
      home: Builder(
        builder: (BuildContext context) {
          inks = CellInks.of(context);
          return const SizedBox.shrink();
        },
      ),
    ),
  );
  return inks;
}

void main() {
  test('every place the chain can be is on the canvas', () {
    for (final Size size in const <Size>[
      Size(360, 420),
      Size(390, 520),
      Size(700, 480),
    ]) {
      final CellLayout layout = CellLayout(size);
      final Rect canvas = Offset.zero & size;
      for (final Compartment compartment in Compartment.values) {
        for (final Compartment? after in <Compartment?>[
          null,
          Compartment.cytosol,
          Compartment.vesicle,
        ]) {
          expect(
            canvas.contains(layout.anchorOf(compartment, after: after)),
            isTrue,
            reason: '$compartment after $after at $size',
          );
        }
      }
      // Outside the cell is outside it, and everything else is inside.
      expect(
        layout.cell.contains(layout.anchorOf(Compartment.extracellular)),
        isFalse,
      );
      for (final Compartment inside in <Compartment>[
        Compartment.cytosol,
        Compartment.er,
        Compartment.golgi,
        Compartment.vesicle,
        Compartment.nucleus,
      ]) {
        expect(
          layout.cell.contains(layout.anchorOf(inside)),
          isTrue,
          reason: '$inside at $size',
        );
      }
    }
  });

  testWidgets('one painter draws every route, at every step and between', (
    WidgetTester tester,
  ) async {
    final CellInks inks = await _inks(tester);
    const Size size = Size(390, 520);
    for (final ProteinTarget target in TestCatalog.all) {
      for (final bool topology in <bool>[true, false]) {
        final RouteTimeline timeline = RouteTimeline(
          routeOf(target, topology: topology),
        );
        for (final double t in <double>[
          ...timeline.boundaries,
          for (final double b in timeline.boundaries)
            if (b < 1) b + 0.5 / timeline.beats,
        ]) {
          final ui.PictureRecorder recorder = ui.PictureRecorder();
          CellPainter(
            timeline: timeline,
            at: () => t,
            inks: inks,
          ).paint(Canvas(recorder), size);
          recorder.endRecording().dispose();
        }
      }
    }
  });

  test('a screen reader hears the route, and where the chain is on it', () {
    final RouteTimeline timeline = RouteTimeline(routeOf(TestCatalog.cftr));
    expect(
      CellPainter.describe(timeline, timeline.stateAt(0.5)),
      'A cell, and the route the chain takes through it: Cytosol, '
      'Endoplasmic reticulum, Golgi, Vesicle, Cell membrane. Now at: Golgi.',
    );
  });

  testWidgets('it repaints when the moment moves, and only then', (
    WidgetTester tester,
  ) async {
    final CellInks inks = await _inks(tester);
    final RouteTimeline timeline = RouteTimeline(routeOf(TestCatalog.insulin));
    double t = 0;
    final CellPainter painter = CellPainter(
      timeline: timeline,
      at: () => t,
      inks: inks,
    );
    final CellPainter same = CellPainter(
      timeline: timeline,
      at: () => 0,
      inks: inks,
    );
    expect(painter.shouldRepaint(same), isFalse);
    t = 0.3;
    expect(painter.shouldRepaint(same), isTrue);
  });
}
