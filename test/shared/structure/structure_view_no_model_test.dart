import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/core/catalog/protein_target.dart';
import 'package:helixpeek/core/catalog/protein_track.dart';
import 'package:helixpeek/core/network/api_exception.dart';
import 'package:helixpeek/core/network/track_source.dart';
import 'package:helixpeek/core/theme/app_theme.dart';
import 'package:helixpeek/shared/structure/structure_view.dart';

import '../../support/built_on_demand.dart';
import '../../support/test_catalog.dart';

const String _needsRenderer =
    'The structure needs 3D rendering, which is not available here.';
const String _couldNotLoad = 'The model could not be loaded.';

/// The track rows of a protein with no model, as `TrackClient.read` tells
/// them: a state and, where the pipeline refused, its sentence.
final class _NoModel implements TrackSource {
  _NoModel(this.state, [this.reason]);

  final String state;
  final String? reason;
  final List<TrackKind> asked = <TrackKind>[];

  @override
  Future<Uint8List> read(String slug, TrackKind kind) async {
    asked.add(kind);
    throw TrackApiException(
      slug: slug,
      kind: kind.wire,
      state: state,
      reason: reason,
    );
  }
}

/// A source that cannot be reached at all.
final class _Unreachable implements TrackSource {
  @override
  Future<Uint8List> read(String slug, TrackKind kind) async =>
      throw const UnknownApiException();
}

Future<void> _pump(
  WidgetTester tester,
  ProteinTarget target, {
  TrackSource? tracks,
}) async {
  await tester.pumpWidget(
    RepositoryProvider<TrackSource?>.value(
      value: tracks,
      child: MaterialApp(
        theme: AppTheme.analysis,
        home: Scaffold(
          body: StructureView(
            // A page of its own each time: one test may open two proteins.
            key: UniqueKey(),
            viewport: const Size(390, 520),
            target: target,
            folds: true,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  const String tooLong =
      'AlphaFold DB has no model of proteins over 2,700 residues; this one '
      'has 4,834.';

  testWidgets('a protein the pipeline refused a model says why, in its words', (
    WidgetTester tester,
  ) async {
    final _NoModel tracks = _NoModel('refused', tooLong);
    await _pump(tester, BuiltOnDemand.unmodelled('refused'), tracks: tracks);

    expect(find.text(tooLong), findsOneWidget);
    // The sentence is the track row's, read the way a model would be.
    expect(tracks.asked, <TrackKind>[TrackKind.structure]);
    // A state the page draws: not a model that failed to arrive, and
    // nothing asked of a renderer this test does not have.
    expect(find.text(_couldNotLoad), findsNothing);
    expect(find.text(_needsRenderer), findsNothing);
  });

  testWidgets('a refusal whose sentence cannot be read is still a refusal', (
    WidgetTester tester,
  ) async {
    const String plain = 'No structure model could be made for this protein.';
    await _pump(tester, BuiltOnDemand.unmodelled('refused'));
    expect(find.text(plain), findsOneWidget);

    await _pump(
      tester,
      BuiltOnDemand.unmodelled('refused'),
      tracks: _Unreachable(),
    );
    expect(find.text(plain), findsOneWidget);
    expect(find.text(_couldNotLoad), findsNothing);
  });

  testWidgets('a model still being made is said to be on its way', (
    WidgetTester tester,
  ) async {
    final _NoModel tracks = _NoModel('pending');
    await _pump(tester, BuiltOnDemand.unmodelled('pending'), tracks: tracks);

    expect(find.text('The structure model is still being made.'), findsOneWidget);
    // R9.3: arriving is not absent, and neither needs the row read again.
    expect(find.text('There is no structure model of this protein.'), findsNothing);
    expect(tracks.asked, isEmpty);
  });

  testWidgets('a protein nobody made a model of says there is none', (
    WidgetTester tester,
  ) async {
    final _NoModel tracks = _NoModel('absent');
    await _pump(tester, BuiltOnDemand.unmodelled('absent'), tracks: tracks);

    expect(
      find.text('There is no structure model of this protein.'),
      findsOneWidget,
    );
    expect(tracks.asked, isEmpty);
    expect(find.text(_couldNotLoad), findsNothing);
  });

  testWidgets('a protein with a model takes the page as it always was', (
    WidgetTester tester,
  ) async {
    // Built on demand, with its model made: the same path as the twenty,
    // which headless ends at the renderer this test does not have.
    await _pump(tester, BuiltOnDemand.modelled());
    expect(find.text(_needsRenderer), findsOneWidget);

    // And a curated protein whose row says its track is not ready keeps the
    // old path too: it has a fold described, so a model is what it lacks.
    final ProteinTarget insulin = TestCatalog.insulin;
    final ProteinTarget untracked = ProteinTarget(
      slug: insulin.slug,
      display: insulin.display,
      gene: insulin.gene,
      uniprot: insulin.uniprot,
      accession: insulin.accession,
      summary: insulin.summary,
      facts: insulin.facts,
      chains: insulin.chains,
      structure: insulin.structure,
    );
    expect(untracked.state(TrackKind.structure), TrackState.absent);
    await _pump(tester, untracked);
    expect(find.text(_needsRenderer), findsOneWidget);
    expect(
      find.text('There is no structure model of this protein.'),
      findsNothing,
    );
  });

  testWidgets('nothing is warmed for a protein with no model', (
    WidgetTester tester,
  ) async {
    final _NoModel tracks = _NoModel('refused', tooLong);
    late BuildContext context;
    await tester.pumpWidget(
      RepositoryProvider<TrackSource?>.value(
        value: tracks,
        child: Builder(
          builder: (BuildContext inner) {
            context = inner;
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    await StructureView.prepare(context, BuiltOnDemand.unmodelled('refused'));
    expect(tracks.asked, isEmpty);
  });
}
