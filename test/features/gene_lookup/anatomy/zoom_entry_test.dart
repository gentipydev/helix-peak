import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:helixpeek/core/biology/gene_record.dart';
import 'package:helixpeek/core/catalog/protein_target.dart';
import 'package:helixpeek/core/catalog/protein_track.dart';
import 'package:helixpeek/core/router/app_router.dart';
import 'package:helixpeek/core/theme/app_theme.dart';
import 'package:helixpeek/features/gene_lookup/presentation/anatomy/anatomy_canvas.dart';
import 'package:helixpeek/features/gene_lookup/presentation/anatomy/anatomy_screen.dart';
import 'package:helixpeek/shared/anatomy/anatomy_stages.dart';

import '../../../support/test_catalog.dart';
import '../../lab/replication/replication_fixtures.dart';
import '../../zoom/zoom_fixtures.dart';
import '../clinvar/gene_clinvar_test.dart' show snapshot;
import '../clinvar/variant_evidence_test.dart'
    show insulinConstraint, insulinImpact;
import 'anatomy_fixture.dart';

/// The walk's gene page offers the zoom, for a protein whose `locus` track is
/// ready: the twenty curated ones as the service serves them today. The
/// walk's own fixtures name no locus, so every other walk test sees the page
/// without it, which the first test here holds.

final Finder _pill = find.byKey(const ValueKey<String>('open-zoom'));
final Finder _dna = find.byKey(const ValueKey<String>('open-dna'));
final Finder _ribosome = find.byKey(const ValueKey<String>('open-ribosome'));

const String _hint = 'Tap a region for its DNA';

/// Insulin, as the service serves it: its locus ready.
final ProteinTarget _located = withLocus(TestCatalog.insulin, TrackState.ready);

/// The zoom's location each time the walk opened it.
final List<Uri> _opened = <Uri>[];

/// The walk at `/`, and a page standing in for the zoom at its own route.
Future<GoRouter> _walk(
  WidgetTester tester,
  ProteinTarget target, {
  GeneRecord? record,
  double width = 390,
  double textScale = 1,
}) async {
  _opened.clear();
  await tester.binding.setSurfaceSize(Size(width, 844));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final GoRouter router = GoRouter(
    routes: <RouteBase>[
      GoRoute(
        path: '/',
        builder: (BuildContext context, GoRouterState state) =>
            AnatomyScreen(target: target, record: record ?? recordOf(target)),
      ),
      GoRoute(
        path: '${RoutePaths.zoom}/:slug',
        builder: (BuildContext context, GoRouterState state) {
          _opened.add(state.uri);
          return const Scaffold(body: Text('the zoom'));
        },
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    MaterialApp.router(
      theme: AppTheme.analysis,
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      builder: (BuildContext context, Widget? child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          disableAnimations: true,
          textScaler: TextScaler.linear(textScale),
        ),
        child: child!,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

Future<void> _swipe(WidgetTester tester, {required bool forward}) async {
  final Rect screen = tester.getRect(find.byType(AnatomyScreen));
  await tester.dragFrom(
    Offset(screen.center.dx, screen.bottom - 40),
    Offset(forward ? -160 : 160, 0),
  );
  await tester.pumpAndSettle();
}

/// A tap on the gene page at record position [position]: its region, as a
/// tap picks one there, or the one base where [asRun] is false.
Future<void> _tap(
  WidgetTester tester,
  int position, {
  bool asRun = true,
}) async {
  tester
      .widget<AnatomyCanvas>(find.byType(AnatomyCanvas))
      .onTapped(position, asRun: asRun);
  await tester.pump();
}

int _pages(ProteinTarget target) =>
    AnatomyModel.derive(recordOf(target), chain: target.chain).stages.length +
    1;

void main() {
  setUpAll(loadAppFonts);

  testWidgets('a protein with no locus is walked as it always was: no page '
      'offers the zoom', (WidgetTester tester) async {
    for (final ProteinTarget target in <ProteinTarget>[
      TestCatalog.insulin,
      withLocus(TestCatalog.insulin, TrackState.pending),
      withLocus(TestCatalog.insulin, TrackState.refused, reason: 'no band'),
    ]) {
      expect(target.state(TrackKind.locus), isNot(TrackState.ready));
      await _walk(tester, target);
      expect(find.text(_hint), findsOneWidget);
      for (int page = 0; page < _pages(target); page++) {
        expect(_pill, findsNothing, reason: 'page $page');
        expect(
          find.byKey(const ValueKey<String>('open-zoom-reach')),
          findsNothing,
        );
        await _swipe(tester, forward: true);
      }
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });

  testWidgets('with one, the gene page offers it at rest, and no other page '
      'does', (WidgetTester tester) async {
    await _walk(tester, _located);
    expect(_pill, findsOneWidget);
    expect(find.text('Zoom ›'), findsOneWidget);
    // Beside the page's line and over its hint, both still there.
    expect(find.text(_hint), findsOneWidget);
    expect(_dna, findsNothing);

    final int pages = _pages(_located);
    for (int page = 1; page < pages; page++) {
      await _swipe(tester, forward: true);
      expect(_pill, findsNothing, reason: 'page $page');
    }
    for (int page = 1; page < pages; page++) {
      await _swipe(tester, forward: false);
    }
    expect(_pill, findsOneWidget);
    // The transcript's own offer is the transcript's alone.
    expect(_ribosome, findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('a picked region takes its place with "DNA ›", and letting go '
      'gives it back', (WidgetTester tester) async {
    await _walk(tester, _located);
    await _tap(tester, 6000);
    expect(_dna, findsOneWidget);
    expect(_pill, findsNothing);
    // The same region again lets go of it.
    await _tap(tester, 6000);
    await tester.pumpAndSettle();
    expect(_dna, findsNothing);
    expect(_pill, findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('a traced base hides it, as it hides the hint', (
    WidgetTester tester,
  ) async {
    await _walk(tester, _located);
    await _tap(tester, 6000, asRun: false);
    expect(_pill, findsNothing);
    expect(find.text(_hint), findsNothing);
    await _tap(tester, 6000, asRun: false);
    await tester.pumpAndSettle();
    expect(_pill, findsOneWidget);
    expect(find.text(_hint), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('a tap on it, or beside it, opens the zoom over the walk, and '
      'Back returns to the gene page', (WidgetTester tester) async {
    final GoRouter router = await _walk(tester, _located);
    await tester.tap(_pill);
    await tester.pumpAndSettle();
    expect(find.text('the zoom'), findsOneWidget);
    expect(_opened.single.path, '/zoom/insulin');
    expect(RoutePaths.zoomIsOverWalk(_opened.single), isTrue);
    expect(
      _opened.single.toString(),
      RoutePaths.zoomFor(_located, overWalk: true),
    );

    router.pop();
    await tester.pumpAndSettle();
    expect(find.text('the zoom'), findsNothing);
    expect(_pill, findsOneWidget);
    expect(find.text(_hint), findsOneWidget);

    // Under the pill, where the strip's second line runs: the pill is 24
    // points tall, and a thumb lands where it lands.
    await tester.tapAt(tester.getRect(_pill).bottomCenter + const Offset(0, 16));
    await tester.pumpAndSettle();
    expect(find.text('the zoom'), findsOneWidget);
    expect(_opened, hasLength(2));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('a screen reader is offered it on the strip, by name', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    await _walk(tester, _located);
    final SemanticsNode strip = tester.getSemantics(
      find.bySemanticsLabel(RegExp(r', the gene\. ')),
    );
    expect(
      <String?>[
        for (final int id
            in strip.getSemanticsData().customSemanticsActionIds ??
                const <int>[])
          CustomSemanticsAction.getAction(id)?.label,
      ],
      <String>['Zoom from a body down to this gene'],
      reason: 'the strip carries its one action',
    );
    expect(
      find.bySemanticsLabel('Zoom from a body down to this gene'),
      findsNothing,
      reason: 'folded into the strip, which is read as one',
    );
    await tester.pumpWidget(const SizedBox.shrink());
    // Not `addTearDown`: the framework checks for leaked handles before tear
    // downs run.
    semantics.dispose();
  });

  testWidgets('a landing does not offer it: its header names its way back', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    Finder key(String value) => find.byKey(ValueKey<String>(value));
    // The ClinVar list builds its rows only as they come near the screen.
    Future<void> tapKey(String value) async {
      if (find
          .byKey(ValueKey<String>(value), skipOffstage: false)
          .evaluate()
          .isEmpty) {
        await tester.scrollUntilVisible(
          key(value),
          200,
          scrollable: find.descendant(
            of: key('variants-overview-scroll'),
            matching: find.byType(Scrollable),
          ),
        );
      }
      await tester.ensureVisible(
        find.byKey(ValueKey<String>(value), skipOffstage: false),
      );
      await tester.pumpAndSettle();
      await tester.tap(key(value));
      await tester.pumpAndSettle();
    }

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        debugShowCheckedModeBanner: false,
        builder: (BuildContext context, Widget? child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: Theme(
          data: AppTheme.analysis,
          child: AnatomyScreen(
            record: insulin(),
            target: _located,
            constraint: insulinConstraint(),
            impact: insulinImpact(),
            clinvar: snapshot(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    // The walk itself offers it.
    expect(_pill, findsOneWidget);

    // To the protein page, and from a ClinVar record's residue to a landing.
    await _swipe(tester, forward: true);
    await _swipe(tester, forward: true);
    await tester.tap(key('conservation-toggle'));
    await tester.pumpAndSettle();
    await tester.tap(key('clinvar-key'));
    await tester.pumpAndSettle();
    await tapKey('evidence-row-13387');
    await tapKey('evidence-residue-13387');
    expect(key('walk-return-clinvar'), findsOneWidget);

    // The landing's own gene page, and the base it carried there let go:
    // at rest, with its hint up, and no pill.
    await tester.tap(key('stage-Gene'));
    await tester.pumpAndSettle();
    tester
        .widget<AnatomyCanvas>(find.byType(AnatomyCanvas).last)
        .onTapped(null);
    await tester.pumpAndSettle();
    expect(key('walk-return-clinvar'), findsOneWidget);
    expect(find.text(_hint), findsOneWidget);
    expect(_pill, findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  group('the gene page’s line is whole beside it', () {
    // The three whose record shortens its introns say so on this line, and
    // are the long ones: 62 characters where the others have 21 at most.
    for (final (double width, double scale) in <(double, double)>[
      (390, 1),
      (390, 1.2),
      (360, 1),
      (360, 1.2),
      (320, 1),
    ]) {
      testWidgets('for all twenty at $width pt, text at $scale', (
        WidgetTester tester,
      ) async {
        for (final ProteinTarget target in TestCatalog.all) {
          final GeneRecord record = recordOf(target);
          await _walk(
            tester,
            withLocus(target, TrackState.ready),
            record: record,
            width: width,
            textScale: scale,
          );
          expect(_pill, findsOneWidget, reason: target.slug);
          final String line = AnatomyModel.derive(
            record,
            chain: target.chain,
          ).stages.first.sentence;
          final RenderParagraph paragraph = tester.renderObject<RenderParagraph>(
            find.text(line),
          );
          expect(
            paragraph.didExceedMaxLines,
            isFalse,
            reason: '${target.slug}: "$line" is cut short',
          );
          expect(tester.takeException(), isNull, reason: target.slug);
          await tester.pumpWidget(const SizedBox.shrink());
        }
      });
    }

    testWidgets('but for the three long ones on the narrowest phone with '
        'text turned up, whose line ends in an ellipsis', (
      WidgetTester tester,
    ) async {
      final Set<String> cut = <String>{};
      for (final ProteinTarget target in TestCatalog.all) {
        final GeneRecord record = recordOf(target);
        await _walk(
          tester,
          withLocus(target, TrackState.ready),
          record: record,
          width: 320,
          textScale: 1.2,
        );
        final String line = AnatomyModel.derive(
          record,
          chain: target.chain,
        ).stages.first.sentence;
        if (tester
            .renderObject<RenderParagraph>(find.text(line))
            .didExceedMaxLines) {
          cut.add(target.slug);
        }
        // Cut short, never overflowing: the strip keeps its height.
        expect(tester.takeException(), isNull, reason: target.slug);
        await tester.pumpWidget(const SizedBox.shrink());
      }
      // Known, and held so that it cannot spread unseen: only the records
      // whose introns are drawn shortened, whose line says so.
      expect(cut, <String>{
        for (final ProteinTarget target in TestCatalog.all)
          if (recordOf(target).isIntronCompressed) target.slug,
      });
      expect(cut, hasLength(3));
    });
  });
}
