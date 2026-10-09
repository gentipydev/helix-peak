import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/core/catalog/protein_target.dart';
import 'package:helixpeek/core/catalog/protein_track.dart';
import 'package:helixpeek/core/network/api_exception.dart';
import 'package:helixpeek/core/network/track_source.dart';
import 'package:helixpeek/core/theme/app_theme.dart';
import 'package:helixpeek/features/gene_lookup/presentation/anatomy/anatomy_screen.dart';
import 'package:helixpeek/shared/anatomy/anatomy_stages.dart';
import 'package:helixpeek/shared/structure/structure_view.dart';

import '../../../support/built_on_demand.dart';
import '../../../support/test_catalog.dart';
import 'anatomy_fixture.dart';

const Size _phone = Size(390, 844);

const String _sentence =
    'AlphaFold prediction, mean pLDDT 97.0. 99% of residues at 70 or over.';
const String _source = 'AlphaFold DB AF-P61769-F1 · residues 21–119 of 119';

/// Every track of a protein, in one state: the rows of one built on demand
/// whose model the pipeline refused, as `TrackClient.read` tells them.
final class _Refused implements TrackSource {
  const _Refused(this.reason);

  final String reason;

  @override
  Future<Uint8List> read(String slug, TrackKind kind) async =>
      throw TrackApiException(
        slug: slug,
        kind: kind.wire,
        state: kind == TrackKind.structure ? 'refused' : 'absent',
        reason: kind == TrackKind.structure ? reason : null,
      );
}

/// Opens the walk of [target] and turns to its last page, the fold.
Future<void> _toTheFold(
  WidgetTester tester,
  ProteinTarget target, {
  TrackSource? tracks,
}) async {
  await tester.binding.setSurfaceSize(_phone);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final record = target.gene == 'B2M' ? BuiltOnDemand.record() : insulin();
  await tester.pumpWidget(
    RepositoryProvider<TrackSource?>.value(
      value: tracks,
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
  expect(find.byType(StructureView), findsOneWidget);
}

Future<void> _openAbout(WidgetTester tester, String gene) async {
  await tester.tap(find.text(gene));
  await tester.pumpAndSettle();
  final Finder sources = find.byKey(const ValueKey<String>('about-sources'));
  await tester.ensureVisible(sources);
  await tester.tap(sources);
  await tester.pumpAndSettle();
}

void main() {
  // The app's own type: whether a line fits is a fact about its letters.
  setUpAll(loadAppFonts);

  group('the fold page of a protein built on demand', () {
    testWidgets('is captioned by its model’s own numbers, and says whose it is', (
      WidgetTester tester,
    ) async {
      await _toTheFold(tester, BuiltOnDemand.modelled());

      // The count is the span drawn, 21–119: the signal peptide is not.
      expect(find.text('99'), findsOneWidget);
      expect(find.text(_sentence), findsOneWidget);
      expect(find.text(_source), findsOneWidget);
      expect(find.textContaining('PDB'), findsNothing);
      // One line, as a hint is, and all of it.
      final RenderParagraph hint = tester.renderObject(find.text(_source));
      expect(hint.didExceedMaxLines, isFalse);
      // The whole strip, as a screen reader hears it.
      expect(
        find.bySemanticsLabel(
          '99 residues, the predicted fold. $_sentence $_source',
        ),
        findsOneWidget,
      );
    });

    testWidgets('with no model, says why in one line and nothing else', (
      WidgetTester tester,
    ) async {
      const String tooLong =
          'AlphaFold DB has no model of proteins over 2,700 residues; this '
          'one has 4,834.';
      await _toTheFold(
        tester,
        BuiltOnDemand.unmodelled('refused'),
        tracks: const _Refused(tooLong),
      );

      expect(find.text(tooLong), findsOneWidget);
      expect(find.text('The model could not be loaded.'), findsNothing);
      // No model, so no count of one and no source for one: the page is the
      // fold's place, and the line is what it has to say.
      expect(find.bySemanticsLabel(RegExp(r'^the fold\.\s*$')), findsOneWidget);
      expect(find.textContaining('AlphaFold DB AF-'), findsNothing);
      // The walk behind it is whole: back one page is the protein.
      final Rect screen = tester.getRect(find.byType(AnatomyScreen));
      await tester.dragFrom(
        Offset(screen.center.dx, screen.bottom - 40),
        const Offset(160, 0),
      );
      await tester.pumpAndSettle();
      expect(find.byType(StructureView), findsNothing);
      expect(find.text('119'), findsOneWidget);
    });

    testWidgets('with its model still being made, says that', (
      WidgetTester tester,
    ) async {
      await _toTheFold(tester, BuiltOnDemand.unmodelled('pending'));
      expect(
        find.text('The structure model is still being made.'),
        findsOneWidget,
      );
    });
  });

  group('the About sheet', () {
    testWidgets('names AlphaFold DB as the fold’s source, and credits it', (
      WidgetTester tester,
    ) async {
      await _toTheFold(tester, BuiltOnDemand.modelled());
      await _openAbout(tester, 'B2M');

      expect(
        find.text('AlphaFold DB AF-P61769-F1 · residues 21–119'),
        findsOneWidget,
      );
      // The licence asks for the credit, and the colours for their meaning:
      // both said here, once.
      final Finder credit = find.textContaining(
        'AlphaFold  Predicted structure, from AlphaFold DB (EMBL-EBI and '
        'Google DeepMind), CC BY 4.0.',
        findRichText: true,
      );
      expect(credit, findsOneWidget);
      expect(
        find.textContaining('pLDDT, the model’s own confidence', findRichText: true),
        findsOneWidget,
      );
      expect(
        find.textContaining('Jumper et al. 2021; Varadi et al. 2024.', findRichText: true),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('source-link-AlphaFold')),
        findsOneWidget,
      );
      expect(
        find.text('https://alphafold.ebi.ac.uk/entry/P61769'),
        findsOneWidget,
      );
    });

    testWidgets('of a protein with no model names no structure at all', (
      WidgetTester tester,
    ) async {
      await _toTheFold(tester, BuiltOnDemand.unmodelled('absent'));
      await _openAbout(tester, 'B2M');
      expect(find.text('Structure'), findsNothing);
      expect(find.textContaining('AlphaFold', findRichText: true), findsNothing);
    });

    testWidgets('of a curated protein is as it was: a PDB entry, and no credit', (
      WidgetTester tester,
    ) async {
      await _toTheFold(tester, TestCatalog.insulin);
      expect(find.text('PDB 3I40'), findsOneWidget);
      await _openAbout(tester, 'INS');

      expect(find.text('PDB 3I40'), findsNWidgets(2));
      expect(find.textContaining('AlphaFold', findRichText: true), findsNothing);
      expect(find.byKey(const ValueKey<String>('source-link-AlphaFold')), findsNothing);
    });
  });
}
