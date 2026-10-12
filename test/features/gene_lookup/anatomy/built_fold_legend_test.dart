// The fold page's legend for a protein built on demand drawn as two of its
// products: each chain named by its region in the protein's table, where its
// record names no peptides (the user's decision of 2026-10-12).
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/core/biology/gene_record.dart';
import 'package:helixpeek/core/catalog/protein_target.dart';
import 'package:helixpeek/core/network/track_source.dart';
import 'package:helixpeek/core/theme/app_theme.dart';
import 'package:helixpeek/features/gene_lookup/presentation/anatomy/anatomy_screen.dart';
import 'package:helixpeek/shared/anatomy/anatomy_stages.dart';
import 'package:helixpeek/shared/structure/structure_view.dart';

import '../../../support/built_on_demand.dart';
import '../../../support/test_catalog.dart';
import 'anatomy_fixture.dart';

const Size _phone = Size(390, 844);

/// B2M's row as an experimental fold of two of its products would carry it:
/// two chains and a bridge, and a table naming two kept regions. B2M is one
/// chain; the record is its own, which names no peptides, as no record built
/// on demand does, and the row is made up to be two.
ProteinTarget _twoProducts({bool kept = true}) => ProteinTarget.fromJson(<String, dynamic>{
  'slug': 'b2m',
  'display': 'Beta-2-microglobulin',
  'gene': 'B2M',
  'uniprot': 'P61769',
  'accession': 'NG_012920.2',
  'summary': 'Built on demand.',
  'facts': <String, int>{'residues': 119, 'exons': 4, 'chains': 2, 'bridges': 1},
  'catalog_order': null,
  'chain': null,
  'chains': <Map<String, String>>[
    <String, String>{'node': 'chainA', 'tint': 'mature1'},
    <String, String>{'node': 'chainB', 'tint': 'mature2'},
    <String, String>{'node': 'bonds', 'tint': 'cysteine'},
  ],
  'structure': <String, dynamic>{
    'pdb': '1ABC',
    'modelled': null,
    'label': 'the mature chains',
    'count': 99,
    'unit': 'residues',
    'sentence': 'X-ray, 1.50 Å. Two chains, joined by a disulfide bridge.',
    'semantics': 'Two chains. Drag to turn it.',
  },
  'regions': <Map<String, dynamic>>[
    <String, dynamic>{'label': 'Signal peptide', 'short': 'S', 'start': 1, 'end': 20,
                      'origin': 1, 'kept': false},
    <String, dynamic>{'label': 'First chain', 'short': 'F', 'start': 21, 'end': 60,
                      'origin': 21, 'kept': kept},
    <String, dynamic>{'label': 'Second chain', 'short': 'D', 'start': 61, 'end': 119,
                      'origin': 61, 'kept': kept},
  ],
  'tracks': <String, String>{'record': 'ready', 'constraint': 'ready', 'structure': 'ready'},
});

/// The legend the fold page is handed, by name, once the walk reaches it.
Future<List<String>> _legendOf(
  WidgetTester tester,
  ProteinTarget target,
  GeneRecord record,
) async {
  await tester.binding.setSurfaceSize(_phone);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    RepositoryProvider<TrackSource?>.value(
      value: null,
      child: MaterialApp(
        theme: AppTheme.analysis,
        home: AnatomyScreen(target: target, record: record),
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
  return <String>[
    for (final (Color, String) entry
        in tester.widget<StructureView>(find.byType(StructureView)).legend)
      entry.$2,
  ];
}

void main() {
  group('the fold legend of a protein built on demand', () {
    testWidgets('names two products by their regions, where its record names no peptides', (
      WidgetTester tester,
    ) async {
      final GeneRecord record = BuiltOnDemand.record();
      expect(record.peptides, isEmpty);
      expect(await _legendOf(tester, _twoProducts(), record),
             <String>['First chain', 'Second chain', 'disulfide bridges']);
    });

    testWidgets('falls back to the protein\'s name where its table names no kept region', (
      WidgetTester tester,
    ) async {
      expect(await _legendOf(tester, _twoProducts(kept: false), BuiltOnDemand.record()),
             <String>['Beta-2-microglobulin', 'Beta-2-microglobulin', 'disulfide bridges']);
    });

    testWidgets('of one chain, or of AlphaFold\'s bands, is as it was', (
      WidgetTester tester,
    ) async {
      final List<String> bands = await _legendOf(
        tester, BuiltOnDemand.modelled(), BuiltOnDemand.record());
      expect(bands.last, 'disulfide bridges');
      expect(bands, isNot(contains('Signal peptide')));
    });
  });

  testWidgets('one of the twenty names its chains by its record\'s peptides, as it did', (
    WidgetTester tester,
  ) async {
    final List<String> names = await _legendOf(tester, TestCatalog.insulin, insulin());
    expect(names.last, 'disulfide bridges');
    expect(names.where((String name) => name.contains('First')), isEmpty);
  });
}
