import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/core/catalog/protein_target.dart';
import 'package:helixpeek/core/catalog/protein_track.dart';
import 'package:helixpeek/core/theme/app_theme.dart';
import 'package:helixpeek/features/lab/trafficking/domain/route_captions.dart';
import 'package:helixpeek/features/lab/trafficking/domain/route_timeline.dart';
import 'package:helixpeek/features/lab/trafficking/domain/trafficking_route.dart';
import 'package:helixpeek/features/lab/trafficking/presentation/cell_scene_screen.dart';

import '../../../../support/test_catalog.dart';
import '../trafficking_fixtures.dart';

/// The scene for [target], with its topology where [state] is ready.
Future<TraffickingRoute> _host(
  WidgetTester tester,
  ProteinTarget target, {
  TrackState state = TrackState.ready,
  String? reason,
}) async {
  final bool ready = state == TrackState.ready;
  final TraffickingRoute route = routeOf(target, topology: ready);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.analysis,
      home: CellSceneScreen(
        target: withTrafficking(target, state, reason: reason),
        route: route,
        topology: ready ? topologyOf(target) : null,
      ),
    ),
  );
  return route;
}

String _text(WidgetTester tester, String key) =>
    tester.widget<Text>(find.byKey(ValueKey<String>(key))).data!;

/// Every string the screen shows.
Iterable<String> _shown(WidgetTester tester) => tester
    .widgetList<Text>(find.byType(Text))
    .map((Text text) => text.data ?? text.textSpan?.toPlainText() ?? '');

void main() {
  testWidgets('one scene serves all twenty, a caption for every step', (
    WidgetTester tester,
  ) async {
    for (final ProteinTarget target in TestCatalog.all) {
      final TraffickingRoute route = await _host(tester, target);
      final RouteCaptions captions = RouteCaptions(
        route,
        chains: target.facts.chains,
      );
      expect(find.byKey(const ValueKey<String>('cell-canvas')), findsOneWidget);
      expect(
        find.text(CellSceneScreen.titleOf(target)),
        findsOneWidget,
        reason: target.slug,
      );
      for (int i = 0; i < route.steps.length; i++) {
        if (i > 0) {
          await tester.tap(find.byTooltip('Step forward'));
          await tester.pump();
        }
        expect(
          _text(tester, 'cell-caption'),
          captions.captionOf(i),
          reason: '${target.slug}, step $i',
        );
        expect(
          _text(tester, 'transport-phase'),
          contains(RouteTimeline.nameOf(route.steps[i].compartment)),
          reason: '${target.slug}, step $i',
        );
        for (final String shown in _shown(tester)) {
          expect(
            shown,
            isNot(contains(tissueWords)),
            reason: '${target.slug}: $shown',
          );
        }
      }
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });

  testWidgets('it says it is inferred, and where the topology came from', (
    WidgetTester tester,
  ) async {
    await _host(tester, TestCatalog.cftr);
    expect(
      _text(tester, 'cell-inferred'),
      'Worked out from its sequence features, not observed in a cell, and '
      'it says nothing about which cells make it.',
    );
    expect(
      _text(tester, 'cell-topology'),
      'Which stretches cross a membrane: UniProt release 2026_03, fetched '
      '2026-09-27.',
    );
  });

  testWidgets('without the track, it says why the route stops', (
    WidgetTester tester,
  ) async {
    final TraffickingRoute route = await _host(
      tester,
      TestCatalog.insulin,
      state: TrackState.absent,
    );
    expect(route.destination, Compartment.unknown);
    expect(
      _text(tester, 'cell-topology'),
      'Which stretches cross a membrane is not published for it.',
    );
    for (int i = 1; i < route.steps.length; i++) {
      await tester.tap(find.byTooltip('Step forward'));
      await tester.pump();
    }
    expect(_text(tester, 'cell-caption'), endsWith('its record does not say.'));
    expect(_text(tester, 'transport-phase'), contains('Not known'));
  });

  testWidgets('a track on its way, or declined, says which', (
    WidgetTester tester,
  ) async {
    await _host(tester, TestCatalog.p53, state: TrackState.pending);
    expect(
      _text(tester, 'cell-topology'),
      'Which stretches cross a membrane is on its way from UniProt.',
    );
    await _host(
      tester,
      TestCatalog.p53,
      state: TrackState.refused,
      reason: 'the entry has no sequence',
    );
    expect(
      _text(tester, 'cell-topology'),
      'Which stretches cross a membrane is not published for it: the entry '
      'has no sequence.',
    );
  });

  testWidgets('a screen reader hears where the chain is', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    await _host(tester, TestCatalog.prion);
    expect(
      find.bySemanticsLabel(
        RegExp(r'^A cell, and the route .* Now at: Cytosol\.$'),
      ),
      findsOneWidget,
    );
    await tester.tap(find.byTooltip('Step forward'));
    await tester.pump();
    expect(
      find.bySemanticsLabel(RegExp(r'Now at: Endoplasmic reticulum\.$')),
      findsOneWidget,
    );
    semantics.dispose();
  });
}
