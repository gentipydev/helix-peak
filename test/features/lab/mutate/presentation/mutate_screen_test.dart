import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/core/catalog/protein_target.dart';
import 'package:helixpeek/core/evidence/variant_evidence.dart';
import 'package:helixpeek/core/network/track_source.dart';
import 'package:helixpeek/core/theme/app_theme.dart';
import 'package:helixpeek/features/gene_lookup/data/datasources/gene_remote_data_source.dart';
import 'package:helixpeek/features/gene_lookup/data/repositories/gene_repository_impl.dart';
import 'package:helixpeek/features/gene_lookup/domain/usecases/fetch_gene.dart';
import 'package:helixpeek/features/lab/mutate/domain/apply_edit.dart';
import 'package:helixpeek/features/lab/mutate/presentation/mutate_cubit.dart';
import 'package:helixpeek/features/lab/mutate/presentation/mutate_screen.dart';
import 'package:helixpeek/features/lab/presentation/lab_anatomy_view.dart';
import 'package:helixpeek/shared/anatomy/anatomy_scene.dart';
import 'package:helixpeek/shared/anatomy/anatomy_stages.dart';
import 'package:helixpeek/shared/clinvar/evidence_row.dart';

import '../../../../support/fixture_track_source.dart';
import '../../../../support/test_catalog.dart';

const ValueKey<String> _canvas = ValueKey<String>('mutate-canvas');
const ValueKey<String> _lead = ValueKey<String>('mutate-lead');

/// A surface tall enough that every page of these genes fits without a
/// scroll, so a cell can be tapped where its layout puts it.
const Size _surface = Size(390, 1800);

Future<MutateCubit> _host(WidgetTester tester, String slug) async {
  final ProteinTarget target = TestCatalog.bySlug(slug)!;
  final TrackSource tracks = FixtureTrackSource();
  final MutateCubit cubit = MutateCubit(
    target: target,
    fetchGene: FetchGene(GeneRepositoryImpl(TrackGeneDataSource(tracks))),
    tracks: tracks,
  );
  addTearDown(cubit.close);
  // The record is read from disk and ClinVar is parsed on another isolate:
  // real async, both.
  await tester.runAsync(() async {
    await cubit.load();
    for (int i = 0; i < 200; i++) {
      if (cubit.state case final MutateReady ready
          when ready.clinvar != ClinVarLoad.loading) {
        break;
      }
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
  });
  await tester.binding.setSurfaceSize(_surface);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.analysis,
      home: BlocProvider<MutateCubit>.value(
        value: cubit,
        child: MutateScreen(target: target),
      ),
    ),
  );
  await tester.pump();
  return cubit;
}

AnatomyScene _scene(WidgetTester tester) =>
    tester.widget<LabAnatomyView>(find.byKey(_canvas)).scene;

String _leadText(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(_lead)).data!;

/// Taps the cell holding [position] on the page at rest.
Future<void> _tapPosition(WidgetTester tester, int position) async {
  final AnatomyScene scene = _scene(tester);
  final AnatomyStage stage = scene.isTransition ? scene.to : scene.from;
  final int cell = stage.cellAt(position);
  expect(cell, greaterThanOrEqualTo(0), reason: 'base $position is drawn');
  final Offset centre = (scene.isTransition ? scene.toLayout : scene.fromLayout)
      .centreOf(cell);
  await tester.tapAt(tester.getTopLeft(find.byKey(_canvas)) + centre);
  await tester.pump();
}

/// Opens the region holding [position], then picks that base.
Future<void> _pick(WidgetTester tester, int position) async {
  await _tapPosition(tester, position);
  await tester.pump(const Duration(milliseconds: 1500));
  await tester.pump();
  expect(_scene(tester).from.kind, StageKind.dna);
  await _tapPosition(tester, position);
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  testWidgets('a base picked on the gene is changed, and the change is read', (
    WidgetTester tester,
  ) async {
    await _host(tester, 'insulin');
    expect(_scene(tester).from.kind, StageKind.gene);
    expect(_leadText(tester), 'Tap a region of the gene to open its bases.');

    await _pick(tester, 5368);
    expect(find.text('Base 5,368'), findsOneWidget);
    expect(
      tester.widget<LabAnatomyView>(find.byKey(_canvas)).maskedIndex,
      isNotNull,
      reason: 'the base the sheet is about stands out',
    );
    // The three other bases and a deletion; never the base it already is.
    expect(find.byKey(const ValueKey<String>('mutate-to-T')), findsNothing);
    expect(find.byKey(const ValueKey<String>('mutate-to-C')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('mutate-delete')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey<String>('mutate-to-C')));
    await tester.pump();
    expect(
      _leadText(tester),
      'Codon 49 now reads leucine where it read phenylalanine: one residue of '
      '110 changes.',
    );
    // The mRNA page plays the edited record's own translation.
    final AnatomyScene reading = _scene(tester);
    expect(reading.translation, isNotNull);
    expect(reading.to.letters[48], 'L');
    await tester.pump(const Duration(milliseconds: 3000));

    await tester.tap(find.text('Protein'));
    await tester.pump();
    final AnatomyScene ripple = _scene(tester);
    expect(ripple.from.letters[48], 'F');
    expect(ripple.to.letters[48], 'L');
    await tester.pump(const Duration(milliseconds: 1500));

    // The original is one tap away.
    await tester.tap(find.byKey(const ValueKey<String>('mutate-original')));
    await tester.pump();
    expect(find.byKey(const ValueKey<String>('mutate-original')), findsNothing);
    expect(_scene(tester).from.letters, isNot(contains('L' * 200)));
    await tester.pump(const Duration(milliseconds: 1500));
  });

  testWidgets('decay fades the mRNA, with its sentence, and draws no short '
      'protein', (WidgetTester tester) async {
    await _host(tester, 'insulin');
    await _pick(tester, 5352);
    await tester.tap(find.byKey(const ValueKey<String>('mutate-to-A')));
    await tester.pump();
    expect(_leadText(tester), contains('nonsense-mediated decay'));
    expect(_scene(tester).isTransition, isFalse, reason: 'no translation');
    expect(_scene(tester).from.kind, StageKind.mrna);
    await tester.pump(const Duration(milliseconds: 1500));
    final Opacity fade = tester.widget<Opacity>(
      find.ancestor(of: find.byKey(_canvas), matching: find.byType(Opacity)),
    );
    expect(fade.opacity, closeTo(0.25, 1e-9));

    await tester.tap(find.text('Protein'));
    await tester.pump();
    final AnatomyScene gone = _scene(tester);
    expect(gone.target, everyElement(-1), reason: 'no protein is made');
    await tester.pump(const Duration(milliseconds: 1500));
  });

  testWidgets('a base in a shortened intron offers no edit, and says why', (
    WidgetTester tester,
  ) async {
    await _host(tester, 'cftr');
    // Near the start of intron 1, which is drawn shortened: on screen once
    // the intron opens.
    await _pick(tester, 19370);
    expect(
      find.byKey(const ValueKey<String>('mutate-ineligible')),
      findsOneWidget,
    );
    expect(
      find.text(
        'This intron is drawn shortened, so an edit here cannot be placed on '
        'the chromosome.',
      ),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey<String>('mutate-delete')), findsNothing);
  });

  testWidgets('ClinVar’s record of exactly the edited change is quoted in its '
      'own row', (WidgetTester tester) async {
    final MutateCubit cubit = await _host(tester, 'insulin');
    final MutateReady ready = cubit.state as MutateReady;
    expect(ready.clinvar, ClinVarLoad.ready);
    // A coding single-base record, so its base sits in an exon the gene page
    // opens.
    final VariantEvidence record = ready.evidence.firstWhere(
      (VariantEvidence e) =>
          e.variant.residue != null &&
          e.variant.ref.length == 1 &&
          e.variant.alt.length == 1,
    );
    await _pick(tester, record.variant.position);
    expect(find.text('ClinVar records at this base'), findsOneWidget);
    expect(find.byType(EvidenceRow), findsWidgets);

    await tester.tap(
      find.byKey(ValueKey<String>('mutate-to-${record.variant.alt}')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 3000));
    expect(find.text('ClinVar has this exact change'), findsOneWidget);
    expect(find.byType(EvidenceRow), findsWidgets);
    expect(
      (cubit.state as MutateReady).applied!.edit,
      isA<Substitution>(),
    );
  });
}
