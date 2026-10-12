// A protein resolved on demand, read from the live service through the app's
// production client, then walked on the real screen.
//
// Opt-in, like live_backend_check.dart: it is skipped unless LIVE_BACKEND and
// LIVE_RESOLVED are set, so the default `flutter test` stays offline and
// deterministic.
//
//   LIVE_BACKEND=https://helix-peak-backend.onrender.com LIVE_RESOLVED=B2M \
//     flutter test test/live_resolved_check.dart
//
// LIVE_EXPECT=refused is for a protein whose ESM-2 track the scorer declined,
// and LIVE_EXPECT=absent for one whose scoring a reader stopped (its track
// then says nothing is coming). LIVE_EVIDENCE says what its AlphaGenome and ClinVar
// tracks are: `ready` (the default, as every build has them since 2026-10-09),
// `refused`, or `absent`. The backend's scripts/check_built.py checks the same
// protein from the server's side.
//
// Its model is read as it stands, whichever state its structure track is in:
// ready (an experimental entry's, with its fold, held to each other and to
// the row as the walk holds them; or AlphaFold DB's, with its bands and its
// words), refused (the sentence the fold page shows), or never asked for.
// LIVE_FOLD says which it should be: `pdb`, `alphafold` or `none`; unset,
// either model passes.
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/core/biology/gene_record.dart';
import 'package:helixpeek/core/catalog/protein_resolver.dart';
import 'package:helixpeek/core/catalog/protein_suggestion.dart';
import 'package:helixpeek/core/catalog/protein_target.dart';
import 'package:helixpeek/core/catalog/protein_track.dart';
import 'package:helixpeek/core/evidence/gene_clinvar.dart';
import 'package:helixpeek/core/evidence/gene_impact.dart';
import 'package:helixpeek/core/evidence/protein_constraint.dart';
import 'package:helixpeek/core/network/api_exception.dart';
import 'package:helixpeek/core/network/dio_api_client.dart';
import 'package:helixpeek/core/network/track_client.dart';
import 'package:helixpeek/core/network/track_rows.dart';
import 'package:helixpeek/core/network/track_source.dart';
import 'package:helixpeek/core/theme/app_theme.dart';
import 'package:helixpeek/features/gene_lookup/data/datasources/gene_remote_data_source.dart';
import 'package:helixpeek/features/gene_lookup/data/models/gene_record_dto.dart';
import 'package:helixpeek/features/gene_lookup/data/repositories/protein_catalog_repository.dart';
import 'package:helixpeek/features/gene_lookup/presentation/anatomy/anatomy_canvas.dart';
import 'package:helixpeek/features/gene_lookup/presentation/anatomy/anatomy_screen.dart';
import 'package:helixpeek/features/gene_lookup/presentation/constraint/constraint_toolbar.dart';
import 'package:helixpeek/shared/anatomy/anatomy_stages.dart';
import 'package:helixpeek/shared/folding/folding_track.dart';
import 'package:helixpeek/shared/structure/structure_view.dart';

const Size _phone = Size(390, 844);

void main() {
  final String baseUrl = Platform.environment['LIVE_BACKEND'] ?? '';
  final String gene = Platform.environment['LIVE_RESOLVED'] ?? '';
  final String scoring = Platform.environment['LIVE_EXPECT'] ?? 'ready';
  final bool scored = scoring == 'ready';
  final bool on = baseUrl.isNotEmpty && gene.isNotEmpty;
  final String slug = gene.toLowerCase();
  final TrackState expected = switch (scoring) {
    'refused' => TrackState.refused,
    'absent' => TrackState.absent,
    _ => TrackState.ready,
  };
  final TrackState evidence = switch (Platform.environment['LIVE_EVIDENCE'] ?? 'ready') {
    'refused' => TrackState.refused,
    'absent' => TrackState.absent,
    _ => TrackState.ready,
  };

  late Directory root;
  late ProteinTarget target;
  late GeneRecord record;
  late TrackClient tracks;
  ProteinConstraint? constraint;
  Object? constraintError;
  Uint8List? model;
  Object? modelError;
  late Map<TrackKind, TrackRef> rows;
  FoldingTrack? fold;
  Object? foldError;
  final String source = Platform.environment['LIVE_FOLD'] ?? '';
  GeneImpact? impact;
  GeneClinVar? clinvar;
  late ResolveStatus status;
  late TrackState trackState;
  late SuggestionPage suggested;
  late int listed;
  late bool inList;

  setUpAll(() async {
    if (!on) return;
    // The widget binding answers every request with a 400; this is the one
    // file that wants the real network.
    HttpOverrides.global = null;
    root = Directory.systemTemp.createTempSync('helixpeek-resolved');
    final DioApiClient api = DioApiClient(
      baseUrl: baseUrl,
      timeout: const Duration(seconds: 60),
    );
    final ProteinCatalogRepository catalog = ProteinCatalogRepository(
      api,
      null,
    );
    await catalog.refresh();
    listed = catalog.all.length;
    inList = catalog.bySlug(slug) != null;

    // The row, as a deep link outside the catalog reads it.
    target = await catalog.protein(slug);

    // The record and the ESM-2 track, as the walk reads them.
    tracks = TrackClient(
      api,
      cache: Directory('${root.path}/tracks')..createSync(),
    );
    record = (await TrackGeneDataSource(tracks).fetchGene(target.query))
        .toEntity();
    try {
      constraint = await ProteinConstraint.load(target, tracks: tracks);
    } on Object catch (error) {
      constraintError = error;
    }
    // The model, as the fold page reads it, and its fold, by the rows a walk
    // of it is opened with.
    rows = await tracks.refresh(slug);
    try {
      model = await tracks.read(slug, TrackKind.structure);
    } on Object catch (error) {
      modelError = error;
    }
    if (rows[TrackKind.folding]?.state == TrackState.ready) {
      try {
        fold = await FoldingTrack.load(target, tracks: tracks);
      } on Object catch (error) {
        foldError = error;
      }
    }
    // Its AlphaGenome and ClinVar tracks, as the walk reads them, where the
    // service says they are ready; a widget test could not finish loading them.
    if (target.impactScored) {
      impact = await GeneImpact.load(target, tracks: tracks);
    }
    if (target.clinvarAvailable) {
      clinvar = await GeneClinVar.load(target, tracks: tracks);
    }

    // What the search screen asks.
    final ProteinResolver resolver = ProteinResolver(api);
    status = await resolver.status(gene);
    trackState = await resolver.trackState(slug, TrackKind.constraint);
    suggested = await resolver.suggest(gene);
    catalog.dispose();
  });

  tearDownAll(() {
    if (on) root.deleteSync(recursive: true);
  });

  test('the service serves it as a built protein outside the list', () {
    if (!on) {
      markTestSkipped('set LIVE_BACKEND and LIVE_RESOLVED');
      return;
    }
    expect(listed, 20);
    expect(inList, isFalse);
    expect((target.slug, target.gene), (slug, gene));
    expect(target.summary, contains('Built on demand from UniProt'));
    expect(target.state(TrackKind.record), TrackState.ready);
    expect(target.state(TrackKind.constraint), expected);
    expect(target.state(TrackKind.impact), evidence);
    expect(target.state(TrackKind.clinvar), evidence);
    expect(target.scored, scored);

    expect(record.gene, gene);
    expect(record.protein!.translation.length, target.facts.residues);
    if (scored) {
      expect(constraintError, isNull);
      expect(constraint!.positions.length, target.facts.residues);
    } else {
      // ignore: avoid_print
      print('$gene: asking for its ESM-2 track gives: $constraintError');
      expect(constraint, isNull);
    }

    expect(status.state, ResolveState.ready);
    expect(status.slug, slug);
    expect(trackState, expected);
    final ProteinSuggestion row = suggested.suggestions.firstWhere(
      (ProteinSuggestion s) => s.gene == gene,
    );
    expect(row.status, SuggestionStatus.ready);
    expect(row.slug, slug);
    // ignore: avoid_print
    print(
      '$gene: ${target.display}, ${target.facts.residues} residues, '
      '${record.exons.length} exons, ${target.facts.chains} chain(s), '
      '${target.facts.bridges} bridge(s); record ${record.lengthBp} bp'
      '${record.isIntronCompressed ? ' (introns shortened)' : ''}; '
      'ESM-2 track ${expected.name}.',
    );
  });

  test('its AVI and ClinVar are the service\u2019s, or it says why there are none', () {
    if (!on) {
      markTestSkipped('set LIVE_BACKEND and LIVE_RESOLVED');
      return;
    }
    if (evidence == TrackState.ready) {
      // Every drawn base scored, and every record mapped to one of them.
      expect(impact, isNotNull);
      expect(clinvar, isNotNull);
      expect(clinvar!.variants, isNotEmpty);
      for (final ClinVarVariant variant in clinvar!.variants) {
        expect(variant.position, inInclusiveRange(record.start, record.end));
      }
      // ignore: avoid_print
      print(
        '$gene: AVI ready; ClinVar ${clinvar!.variants.length} of '
        '${clinvar!.searchedRecords} records mapped, snapshot ${clinvar!.snapshotDate}.',
      );
    } else {
      expect((impact, clinvar), (null, null));
      for (final TrackKind kind in <TrackKind>[TrackKind.impact, TrackKind.clinvar]) {
        final String? reason = target.reason(kind);
        expect(reason, evidence == TrackState.refused ? isNotNull : isNull);
        // ignore: avoid_print
        print('$gene: ${kind.wire} ${evidence.name}${reason == null ? '' : ': $reason'}');
      }
    }
  });

  test('its model is an experimental entry\u2019s with its fold, or AlphaFold DB\u2019s, '
      'or the service says why there is none', () {
    if (!on) {
      markTestSkipped('set LIVE_BACKEND and LIVE_RESOLVED');
      return;
    }
    final TrackState state = target.state(TrackKind.structure);
    // The row, the model and its fold are one generation of it.
    expect(foldCoherence(target, rows), FoldCoherence.whole);
    if (state == TrackState.ready) {
      final StructureChrome chrome = target.structure!;
      expect(modelError, isNull);
      expect(model, isNotEmpty);
      expect(chrome.sentence.length, lessThanOrEqualTo(80));
      expect(target.chains, isNotEmpty);
      final Map<String, dynamic> made = rows[TrackKind.structure]!.provenance;
      expect(made['pdb'], chrome.pdb);
      if (!chrome.predicted) {
        expect(source, anyOf('', 'pdb'));
        // An experimental entry: its chains as the twenty's are tinted, and
        // its fold, made in the frame of the model it ends on.
        for (final StructureChain chain in target.chains) {
          expect(
            <ChainTint>[ChainTint.mature1, ChainTint.mature2, ChainTint.mature3,
                        ChainTint.cysteine],
            contains(chain.tint),
            reason: chain.node,
          );
        }
        expect(made['source'], 'PDB');
        expect(target.state(TrackKind.folding), TrackState.ready);
        expect(foldError, isNull);
        expect(fold, isNotNull);
        expect(fold!.glbSha256, (made['glb'] as Map<String, dynamic>)['sha256']);
        expect(fold!.pdb, chrome.pdb);
        // ignore: avoid_print
        print(
          '$gene: model PDB ${chrome.pdb}, ${model!.length} bytes, ${chrome.count} '
          '${chrome.unit}, ${chrome.label}; nodes '
          '${target.chains.map((StructureChain c) => c.node).toList()}; its fold '
          '${fold!.chains.length} chain(s), ${fold!.bridges.length} bridge(s). '
          '"${chrome.sentence}"',
        );
      } else {
        expect(source, anyOf('', 'alphafold'));
        expect(chrome.pdb, 'AF-${target.uniprot}-F1');
        // Every node is a band of confidence, or the bridges; and it is drawn
        // still, with no fold.
        for (final StructureChain chain in target.chains) {
          expect(
            chain.tint.confidence != null || chain.tint == ChainTint.cysteine,
            isTrue,
            reason: chain.node,
          );
        }
        expect(target.state(TrackKind.folding), isNot(TrackState.ready));
        // ignore: avoid_print
        print(
          '$gene: model ${chrome.source}, ${model!.length} bytes, '
          '${chrome.count} ${chrome.unit}, modelled ${chrome.modelled}; nodes '
          '${target.chains.map((StructureChain c) => c.node).toList()}. '
          '"${chrome.sentence}"',
        );
      }
    } else {
      expect(source, anyOf('', 'none'));
      // No model: no words and no chains for one, and the track row says
      // which state it is in, with the sentence where the pipeline refused.
      expect(target.structure, isNull);
      expect(target.chains, isEmpty);
      expect(model, isNull);
      expect(modelError, isA<TrackApiException>());
      final TrackApiException said = modelError! as TrackApiException;
      expect(said.state, state.wire);
      expect(said.reason, state == TrackState.refused ? isNotNull : isNull);
      expect(target.state(TrackKind.folding), isNot(TrackState.ready));
      // ignore: avoid_print
      print('$gene: no model, ${said.state}: ${said.reason}');
    }
  });

  testWidgets('the walk draws every page of it', (WidgetTester tester) async {
    if (!on) {
      markTestSkipped('set LIVE_BACKEND and LIVE_RESOLVED');
      return;
    }
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(_phone);
    await tester.pumpWidget(
      // The rows the client read above: where the fold page has no model, it
      // asks them why.
      RepositoryProvider<TrackSource?>.value(
        value: tracks,
        child: MaterialApp(
          theme: AppTheme.analysis,
          debugShowCheckedModeBanner: false,
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: AnatomyScreen(
              target: target,
              record: record,
              constraint: constraint,
              impact: impact,
              clinvar: clinvar,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(AnatomyCanvas), findsOneWidget);

    final List<AnatomyStage> stages = AnatomyModel.derive(
      record,
      chain: target.chain,
    ).stages;
    final int pages = stages.length + 1;
    final int proteinPage = stages.indexWhere(
      (AnatomyStage s) => s.kind == StageKind.protein,
    );
    expect(proteinPage, isNonNegative);
    final Set<String> seen = <String>{};
    for (final bool forward in <bool>[true, false]) {
      for (int i = 1; i < pages; i++) {
        final Rect screen = tester.getRect(find.byType(AnatomyScreen));
        await tester.dragFrom(
          Offset(screen.center.dx, screen.bottom - 40),
          Offset(forward ? -160 : 160, 0),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'page $i');
        if (forward && i == pages - 1) {
          // The fold: its source where it has a model, and why where not.
          expect(find.byType(StructureView), findsOneWidget);
          // The rows were read on the real clock, in `setUpAll`, and a page
          // that asks them why is answered on it: this test's own clock
          // would never deliver it.
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 50)),
          );
          await tester.pump();
          final Object? none = modelError;
          if (target.structure case final StructureChrome chrome) {
            expect(find.textContaining(chrome.source), findsOneWidget);
            expect(find.text(chrome.sentence), findsOneWidget);
          } else if (none is TrackApiException && none.reason != null) {
            expect(find.text(none.reason!), findsOneWidget);
          }
          expect(find.text('The model could not be loaded.'), findsNothing);
        }
        if (forward && i == proteinPage) {
          expect(
            find.byType(ConstraintToolbar),
            scored ? findsOneWidget : findsNothing,
          );
          // What the protein page says in words, to read what a reader is
          // told about a track that is not there.
          for (final Element e in find.byType(Text).evaluate()) {
            final String? words = (e.widget as Text).data;
            if (words != null &&
                RegExp(
                  'ESM|scor|conserv',
                  caseSensitive: false,
                ).hasMatch(words)) {
              seen.add(words);
            }
          }
        }
      }
    }
    // ignore: avoid_print
    print(
      '$gene: walked $pages pages forward and back. Protein page says: $seen',
    );
  });
}
