import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:helixpeek/core/biology/gene_record.dart';
import 'package:helixpeek/core/catalog/protein_target.dart';
import 'package:helixpeek/core/network/track_source.dart';
import 'package:helixpeek/core/theme/app_theme.dart';
import 'package:helixpeek/features/gene_lookup/data/models/gene_record_dto.dart';
import 'package:helixpeek/features/lab/presentation/lab_anatomy_view.dart';
import 'package:helixpeek/features/lab/ribosome/presentation/ribosome_screen.dart';
import 'package:helixpeek/features/lab/ribosome/presentation/translation_ending.dart';
import 'package:helixpeek/shared/anatomy/anatomy_motion.dart';
import 'package:helixpeek/shared/anatomy/anatomy_stages.dart';
import 'package:helixpeek/shared/motion/transport_bar.dart';
import 'package:helixpeek/shared/ribosome/translation_flight.dart';

import '../../../../support/catalog_api.dart';
import '../../../../support/fixture_track_source.dart';
import '../../../../support/test_catalog.dart';

GeneRecord _gene(String gene) => GeneRecordDto.fromJson(
  jsonDecode(File('test/fixtures/mock/gene_$gene.json').readAsStringSync())
      as Map<String, dynamic>,
).toEntity();

/// Insulin's own catalog row with its constraint track absent: an unscored
/// protein, as the walk's own "unscored" golden draws one.
ProteinTarget _unscoredInsulin() {
  final Map<String, dynamic> row = Map<String, dynamic>.from(
    (catalogFixture()['proteins'] as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .firstWhere((Map<String, dynamic> p) => p['slug'] == 'insulin'),
  );
  final Map<String, dynamic> tracks = Map<String, dynamic>.from(
    row['tracks'] as Map<String, dynamic>,
  )..['constraint'] = 'absent';
  row['tracks'] = tracks;
  return ProteinTarget.fromJson(row);
}

/// The ribosome screen under a router, so the walk's link has somewhere to
/// go: `/gene/<slug>` lands on a stand-in that names what it was sent.
Future<GoRouter> _host(
  WidgetTester tester, {
  required ProteinTarget target,
  required GeneRecord record,
  bool reduced = false,
}) async {
  await tester.binding.setSurfaceSize(const Size(390, 844));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final GoRouter router = GoRouter(
    routes: <RouteBase>[
      GoRoute(
        path: '/',
        builder: (BuildContext context, GoRouterState state) =>
            RibosomeScreen(target: target, record: record),
      ),
      GoRoute(
        path: '/gene/:slug',
        builder: (BuildContext context, GoRouterState state) =>
            Text('walk ${state.pathParameters['slug']}'),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    RepositoryProvider<TrackSource>.value(
      value: FixtureTrackSource(),
      child: MediaQuery(
        data: MediaQueryData(
          size: const Size(390, 844),
          disableAnimations: reduced,
        ),
        child: MaterialApp.router(
          theme: AppTheme.analysis,
          routerConfig: router,
        ),
      ),
    ),
  );
  await tester.pump();
  return router;
}

/// Plays the translation to its end.
Future<void> _toTheEnd(WidgetTester tester) async {
  final Finder bar = find.byType(TransportBar);
  final TransportBar transport = tester.widget<TransportBar>(bar);
  transport.controller.seek(1);
  await tester.pump();
}

void main() {
  group('the flight', () {
    test('starts where the chain is and ends in the cell', () {
      const Offset from = Offset(10, 300);
      const Offset to = Offset(200, 40);
      expect(flightPosition(from, to, 0), from);
      expect(flightPosition(from, to, 1), to);
    });

    test('bows off the straight line by the walk’s own bow', () {
      const Offset from = Offset(0, 0);
      const Offset to = Offset(100, 0);
      final Offset middle = flightPosition(from, to, 0.5);
      expect(middle.dx, closeTo(50, 1e-9));
      // Halfway along a quadratic sits half its control point's offset.
      expect(middle.dy, closeTo(100 * AnatomyMotion.bow / 2, 1e-9));
    });

    test('sets off 5′ first, by the walk’s own stagger', () {
      expect(flightProgress(0.3, 0), greaterThan(flightProgress(0.3, 1)));
      expect(flightProgress(0, 0), 0);
      expect(flightProgress(1, 1), 1);
      expect(
        flightProgress(0.5, 0.5),
        AnatomyMotion.ease(AnatomyMotion.staggered(0.5, 0.5)),
      );
    });
  });

  testWidgets('the chain lands on the walk’s own protein page, then offers '
      'the walk', (WidgetTester tester) async {
    final GeneRecord insulin = _gene('ins');
    await _host(tester, target: TestCatalog.insulin, record: insulin);
    await _toTheEnd(tester);
    expect(find.byType(TranslationEnding), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('ending-flight')), findsOneWidget);

    await tester.pump(TranslationEnding.flight);
    await tester.pump();
    final LabAnatomyView page = tester.widget<LabAnatomyView>(
      find.byKey(const ValueKey<String>('ending-page')),
    );
    // The same record's protein page, as the walk derives and draws it.
    expect(page.scene.from.kind, StageKind.protein);
    expect(page.scene.from.letters, insulin.protein!.translation);
    expect(page.scene.isTransition, isFalse);

    await tester.tap(find.byKey(const ValueKey<String>('ending-open-walk')));
    await tester.pumpAndSettle();
    // Pushed onto the app's own route, at its start: the walk itself.
    expect(find.text('walk insulin'), findsOneWidget);
    expect(find.byType(TranslationEnding), findsNothing);
  });

  testWidgets('with reduced motion the page is simply there', (
    WidgetTester tester,
  ) async {
    await _host(
      tester,
      target: TestCatalog.insulin,
      record: _gene('ins'),
      reduced: true,
    );
    await _toTheEnd(tester);
    await tester.pump();
    expect(find.byKey(const ValueKey<String>('ending-flight')), findsNothing);
    expect(find.byKey(const ValueKey<String>('ending-page')), findsOneWidget);
  });

  testWidgets('a protein with no signal peptide ends the same way: p53', (
    WidgetTester tester,
  ) async {
    final GeneRecord p53 = _gene('tp53');
    expect(p53.signalPeptide, isNull);
    await _host(tester, target: TestCatalog.bySlug('p53')!, record: p53);
    await _toTheEnd(tester);
    await tester.pump(TranslationEnding.flight);
    await tester.pump();
    final LabAnatomyView page = tester.widget<LabAnatomyView>(
      find.byKey(const ValueKey<String>('ending-page')),
    );
    expect(page.scene.from.letters, p53.protein!.translation);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an unscored protein is drawn without a constraint track, and '
      'offers no conservation', (WidgetTester tester) async {
    final ProteinTarget unscored = _unscoredInsulin();
    expect(unscored.scored, isFalse);
    await _host(tester, target: unscored, record: _gene('ins'));
    await _toTheEnd(tester);
    await tester.pump(TranslationEnding.flight);
    await tester.pump();
    final LabAnatomyView page = tester.widget<LabAnatomyView>(
      find.byKey(const ValueKey<String>('ending-page')),
    );
    expect(page.constraint, isNull);
    expect(
      find.byKey(const ValueKey<String>('ending-conservation')),
      findsNothing,
    );
  });

  testWidgets('a scored protein can show its conservation on the same page', (
    WidgetTester tester,
  ) async {
    await _host(tester, target: TestCatalog.insulin, record: _gene('ins'));
    await _toTheEnd(tester);
    await tester.pump(TranslationEnding.flight);
    // The constraint track is read from disk and parsed on another isolate.
    for (int i = 0; i < 50; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump();
      if (find
          .byKey(const ValueKey<String>('ending-conservation'))
          .evaluate()
          .isNotEmpty) {
        break;
      }
    }
    expect(
      find.byKey(const ValueKey<String>('ending-conservation')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey<String>('ending-conservation')));
    await tester.pump();
    final LabAnatomyView page = tester.widget<LabAnatomyView>(
      find.byKey(const ValueKey<String>('ending-page')),
    );
    expect(page.constraint, isNotNull);
    expect(page.conservation, isTrue);
  });

  testWidgets('replay goes back to the start and plays', (
    WidgetTester tester,
  ) async {
    await _host(tester, target: TestCatalog.insulin, record: _gene('ins'));
    await _toTheEnd(tester);
    await tester.pump(TranslationEnding.flight);
    await tester.pump();
    await tester.tap(find.text('Replay'));
    await tester.pump();
    expect(find.byType(TranslationEnding), findsNothing);
    expect(find.byTooltip('Pause'), findsOneWidget);
    await tester.tap(find.byTooltip('Pause'));
    await tester.pump();
  });
}
