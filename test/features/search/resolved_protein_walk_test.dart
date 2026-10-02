import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/core/biology/gene_record.dart';
import 'package:helixpeek/core/catalog/protein_target.dart';
import 'package:helixpeek/core/catalog/protein_track.dart';
import 'package:helixpeek/core/evidence/protein_constraint.dart';
import 'package:helixpeek/core/theme/app_theme.dart';
import 'package:helixpeek/features/gene_lookup/data/models/gene_record_dto.dart';
import 'package:helixpeek/features/gene_lookup/presentation/anatomy/anatomy_canvas.dart';
import 'package:helixpeek/features/gene_lookup/presentation/anatomy/anatomy_screen.dart';
import 'package:helixpeek/features/gene_lookup/presentation/constraint/constraint_toolbar.dart';
import 'package:helixpeek/shared/anatomy/anatomy_stages.dart';

/// A protein resolved on demand, walked through the real screen, as
/// `catalog_walk_test.dart` walks the curated twenty.
///
/// The fixtures under `fixtures/ins/` are what the service serves once the
/// backend's resolver (`pipeline/resolver/`) has resolved INS from the insulin
/// inputs its own tests use: `protein.json` is `GET /protein/ins` verbatim,
/// and `gene_ins.json` is the record track it stored. The constraint track is
/// a stand-in, because a real one is scored on a GPU: the curated insulin
/// track (the same model, over the same 110 residues) carrying the resolved
/// row's regions and disulfides, which is what the scorer writes into it.
///
/// A resolved protein is not a curated one: no structure and no chain tints,
/// templated prose, regions from UniProt's processing features, and no
/// mature-peptide page. This is the proof the walk survives all of it.

const Size _phone = Size(390, 844);
const String _fixtures = 'test/features/search/fixtures/ins';

Map<String, dynamic> _json(String name) =>
    jsonDecode(File('$_fixtures/$name').readAsStringSync()) as Map<String, dynamic>;

/// The row as served, with its constraint track in the state given.
ProteinTarget _target(String constraint) {
  final Map<String, dynamic> row = _json('protein.json');
  return ProteinTarget.fromJson(<String, dynamic>{
    ...row,
    'tracks': <String, dynamic>{
      ...row['tracks'] as Map<String, dynamic>,
      'constraint': constraint,
    },
  });
}

Future<void> _walk(
  WidgetTester tester,
  ProteinTarget target,
  ProteinConstraint? constraint,
) async {
  final GeneRecord record = GeneRecordDto.fromJson(_json('gene_ins.json')).toEntity();
  await tester.binding.setSurfaceSize(_phone);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.analysis,
      debugShowCheckedModeBanner: false,
      home: MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: AnatomyScreen(target: target, record: record, constraint: constraint),
      ),
    ),
  );
  await tester.pumpAndSettle();
  expect(find.byType(AnatomyCanvas), findsOneWidget);

  final List<AnatomyStage> stages =
      AnatomyModel.derive(record, chain: target.chain).stages;
  final int pages = stages.length + 1;
  final int proteinPage = stages.indexWhere(
    (AnatomyStage s) => s.kind == StageKind.protein,
  );
  expect(proteinPage, isNonNegative);
  for (final bool forward in <bool>[true, false]) {
    for (int i = 1; i < pages; i++) {
      final Rect screen = tester.getRect(find.byType(AnatomyScreen));
      await tester.dragFrom(
        Offset(screen.center.dx, screen.bottom - 40),
        Offset(forward ? -160 : 160, 0),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'page $i');
      if (forward && i == proteinPage) {
        expect(
          find.byType(ConstraintToolbar),
          constraint != null ? findsOneWidget : findsNothing,
        );
        expect(find.text('ESM-2 scores unavailable'), findsNothing);
      }
    }
  }
}

void main() {
  test('the served row reads as a protein the catalog does not list', () {
    final ProteinTarget target = _target('pending');
    expect((target.slug, target.gene, target.uniprot), ('ins', 'INS', 'P01308'));
    expect(target.display, 'Insulin');
    expect(target.summary, contains('Built on demand from UniProt P01308'));
    expect(target.structure, isNull);
    expect(target.chain, isNull);
    expect(target.state(TrackKind.record), TrackState.ready);
    expect(target.state(TrackKind.constraint), TrackState.pending);
    expect(target.state(TrackKind.clinvar), TrackState.absent);
    expect(target.state(TrackKind.structure), TrackState.absent);
    expect(target.scored, isFalse);
  });

  testWidgets('walks every page while its ESM-2 track is on its way', (
    WidgetTester tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await _walk(tester, _target('pending'), null);
    expect(tester.takeException(), isNull);
  });

  testWidgets('walks every page once its ESM-2 track has landed', (
    WidgetTester tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final ProteinTarget target = _target('ready');
    final ProteinConstraint constraint = ProteinConstraint.fromJson(
      _json('ins_esm_constraint.json'),
      target,
    );
    expect(constraint.bridges, hasLength(3));
    await _walk(tester, target, constraint);
    expect(tester.takeException(), isNull);
  });
}
