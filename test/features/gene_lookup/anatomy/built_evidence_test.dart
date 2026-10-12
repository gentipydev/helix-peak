import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/core/catalog/protein_target.dart';
import 'package:helixpeek/core/evidence/gene_clinvar.dart';
import 'package:helixpeek/core/evidence/gene_impact.dart';
import 'package:helixpeek/core/network/track_source.dart';
import 'package:helixpeek/core/theme/app_theme.dart';
import 'package:helixpeek/features/gene_lookup/presentation/anatomy/anatomy_screen.dart';
import 'package:helixpeek/shared/anatomy/anatomy_stages.dart';
import 'package:helixpeek/shared/structure/structure_view.dart';

import '../../../support/built_on_demand.dart';
import '../../../support/test_catalog.dart';

/// A protein built on demand with its AlphaGenome and ClinVar tracks, as every
/// build has them since 2026-10-09 (the backend's HANDOFF-AVI-CLINVAR.md): the
/// walk reads them as it reads the twenty's, and nothing in it asks whether a
/// protein was curated.
///
/// Beta-2-microglobulin's stored tracks, byte for byte, beside its record
/// (`built_on_demand/b2m_avi.json`, `b2m_clinvar.json`), handed to the screen
/// as every walk test hands its evidence: a widget test never finishes loading
/// a track that large.

const Size _phone = Size(390, 844);

/// B2M's row as the service serves it, with its AVI and ClinVar tracks in
/// [evidence]'s state and no model.
ProteinTarget _b2m(String evidence) => ProteinTarget.fromJson(<String, dynamic>{
  'slug': 'b2m',
  'display': 'Beta-2-microglobulin',
  'gene': 'B2M',
  'uniprot': 'P61769',
  'accession': 'NG_012920.2',
  'summary':
      'Made by B2M on chromosome 15. Built on demand from UniProt P61769 '
      'and MANE Select NM_004048.4, not curated by hand.',
  'facts': <String, int>{'residues': 119, 'exons': 4, 'chains': 1, 'bridges': 1},
  'catalog_order': null,
  'chain': null,
  'chains': <dynamic>[],
  'structure': null,
  'tracks': <String, String>{
    'record': 'ready',
    'constraint': 'ready',
    'impact': evidence,
    'clinvar': evidence,
    'impact_explanations': 'absent',
    'structure': 'absent',
  },
});

Map<String, dynamic> _stored(String name) =>
    jsonDecode(File('test/support/built_on_demand/$name').readAsStringSync())
        as Map<String, dynamic>;

/// Opens the walk of [target], turns to its fold, and opens its About sheet's
/// sources, as `predicted_fold_test.dart` does.
Future<void> _about(
  WidgetTester tester,
  ProteinTarget target, {
  GeneImpact? impact,
  GeneClinVar? clinvar,
}) async {
  await tester.binding.setSurfaceSize(_phone);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final record = BuiltOnDemand.record();
  await tester.pumpWidget(
    RepositoryProvider<TrackSource?>.value(
      value: null,
      child: MaterialApp(
        theme: AppTheme.analysis,
        home: AnatomyScreen(target: target, record: record, impact: impact, clinvar: clinvar),
      ),
    ),
  );
  await tester.pumpAndSettle();
  final int stages = AnatomyModel.derive(record).stages.length;
  for (int page = 0; page < stages; page++) {
    final Rect screen = tester.getRect(find.byType(AnatomyScreen));
    await tester.dragFrom(
      Offset(screen.center.dx, screen.bottom - 40),
      const Offset(-160, 0),
    );
    await tester.pumpAndSettle();
  }
  expect(find.byType(StructureView), findsOneWidget);
  await tester.tap(find.text(target.gene));
  await tester.pumpAndSettle();
  final Finder sources = find.byKey(const ValueKey<String>('about-sources'));
  await tester.ensureVisible(sources);
  await tester.tap(sources);
  await tester.pumpAndSettle();
}

void main() {
  test('the stored tracks are this protein\'s, and no other\'s', () {
    final ProteinTarget target = _b2m('ready');
    expect((target.impactScored, target.clinvarAvailable), (true, true));
    final GeneImpact impact = GeneImpact.fromJson(_stored('b2m_avi.json'), target);
    final GeneClinVar clinvar = GeneClinVar.fromJson(_stored('b2m_clinvar.json'), target);
    expect(impact.runtimeType, GeneImpact);
    expect((clinvar.variants.length, clinvar.searchedRecords), (76, 121));
    // Each parser refuses a payload that names another protein.
    expect(
      () => GeneImpact.fromJson(_stored('b2m_avi.json'), TestCatalog.insulin),
      throwsFormatException,
    );
    expect(
      () => GeneClinVar.fromJson(_stored('b2m_clinvar.json'), TestCatalog.insulin),
      throwsFormatException,
    );
  });

  testWidgets('its About sheet names AVI and its ClinVar snapshot, as for the twenty', (
    WidgetTester tester,
  ) async {
    final ProteinTarget target = _b2m('ready');
    final GeneClinVar clinvar = GeneClinVar.fromJson(_stored('b2m_clinvar.json'), target);
    await _about(
      tester,
      target,
      impact: GeneImpact.fromJson(_stored('b2m_avi.json'), target),
      clinvar: clinvar,
    );

    expect(find.text('AVI'), findsOneWidget);
    expect(
      find.text(
        'AlphaGenome Variant Impact, precomputed · GRCh38 · Phred calibrated genome-wide',
      ),
      findsOneWidget,
    );
    expect(
      find.text('NCBI snapshot ${clinvar.snapshotDate} · 76 of 121 records mapped'),
      findsOneWidget,
    );
    expect(find.textContaining('not yet included'), findsNothing);
  });

  testWidgets('without them it is drawn as before: no AVI, and ClinVar not yet included', (
    WidgetTester tester,
  ) async {
    await _about(tester, _b2m('absent'));
    expect(find.text('AVI'), findsNothing);
    expect(find.text('not yet included for B2M'), findsOneWidget);
    expect(find.textContaining('NCBI snapshot'), findsNothing);
  });
}
