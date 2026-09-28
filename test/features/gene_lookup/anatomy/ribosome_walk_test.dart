import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/core/catalog/protein_target.dart';
import 'package:helixpeek/core/evidence/protein_constraint.dart';
import 'package:helixpeek/core/theme/app_theme.dart';
import 'package:helixpeek/features/gene_lookup/data/models/gene_record_dto.dart';
import 'package:helixpeek/features/gene_lookup/presentation/anatomy/anatomy_canvas.dart';
import 'package:helixpeek/features/gene_lookup/presentation/anatomy/anatomy_screen.dart';
import 'package:helixpeek/features/gene_lookup/presentation/constraint/constraint_toolbar.dart';
import 'package:helixpeek/shared/anatomy/anatomy_layout.dart';
import 'package:helixpeek/shared/anatomy/anatomy_painter.dart';
import 'package:helixpeek/shared/anatomy/anatomy_stages.dart';
import 'package:helixpeek/shared/anatomy/stage_bar.dart';
import 'package:helixpeek/shared/motion/timeline_controller.dart';
import 'package:helixpeek/shared/motion/transport_bar.dart';
import 'package:helixpeek/shared/ribosome/translation_flight.dart';
import 'package:helixpeek/shared/ribosome/translation_player.dart';
import 'package:helixpeek/shared/ribosome/translation_timeline.dart';
import 'package:helixpeek/shared/structure/structure_view.dart';

import '../../../support/test_catalog.dart';
import 'anatomy_fixture.dart';

final ProteinConstraint _constraint = ProteinConstraint.fromJson(
  jsonDecode(File(TestCatalog.insulin.constraintAsset).readAsStringSync())
      as Map<String, dynamic>,
  TestCatalog.insulin,
);

const Size _phone = Size(390, 844);

const int _mrna = 1;

/// The first base of the coding sequence, where the start codon is read.
const int _startCodon = 5224;
const int _protein = 2;

final Finder _pill = find.byKey(const ValueKey<String>('open-ribosome'));
final Finder _flight = find.byKey(
  const ValueKey<String>('walk-ribosome-flight'),
);
final Finder _grid = find.byWidgetPredicate(
  (Widget w) => w is CustomPaint && w.painter is AnatomyPainter,
);

Future<void> _pumpScreen(
  WidgetTester tester, {
  bool reduceMotion = false,
}) async {
  await tester.binding.setSurfaceSize(_phone);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.analysis,
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reduceMotion),
        child: AnatomyScreen(
          target: TestCatalog.insulin,
          record: insulin(),
          constraint: _constraint,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _swipe(WidgetTester tester, {required bool forward}) async {
  final Rect screen = tester.getRect(find.byType(AnatomyScreen));
  await tester.dragFrom(
    Offset(screen.center.dx, screen.bottom - 40),
    Offset(forward ? -160 : 160, 0),
  );
  await tester.pump();
}

/// The transcript page, with the ribosome playing over it.
Future<void> _playing(WidgetTester tester, {bool reduceMotion = false}) async {
  await _pumpScreen(tester, reduceMotion: reduceMotion);
  await _swipe(tester, forward: true);
  await tester.pumpAndSettle();
  await tester.tap(_pill);
  await tester.pump();
}

TimelineController _controller(WidgetTester tester) =>
    tester.widget<TranslationPlayer>(find.byType(TranslationPlayer)).controller;

int _page(WidgetTester tester) =>
    tester.widget<StageBar>(find.byType(StageBar)).index;

AnatomyPainter _painter(WidgetTester tester) =>
    tester.widget<CustomPaint>(_grid).painter! as AnatomyPainter;

/// Lets go of what is still playing, so the test ends with no clock running.
Future<void> _stop(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
}

void main() {
  group('the offer', () {
    testWidgets('is made on the transcript page, and on no other', (
      WidgetTester tester,
    ) async {
      await _pumpScreen(tester);
      expect(_pill, findsNothing);

      await _swipe(tester, forward: true);
      await tester.pumpAndSettle();
      expect(find.text('465'), findsOneWidget);
      expect(_pill, findsOneWidget);
      expect(find.text('Ribosome ›'), findsOneWidget);

      await _swipe(tester, forward: true);
      await tester.pumpAndSettle();
      expect(_page(tester), _protein);
      expect(_pill, findsNothing);
    });

    testWidgets('goes while a base is picked, and comes back when let go', (
      WidgetTester tester,
    ) async {
      await _pumpScreen(tester);
      await _swipe(tester, forward: true);
      await tester.pumpAndSettle();
      // The start codon's first base, a few rows down the transcript.
      final AnatomyStage transcript = AnatomyModel.derive(
        insulin(),
      ).stages[_mrna];
      final Rect grid = tester.getRect(_grid);
      final Offset base =
          grid.topLeft +
          AnatomyLayout.forStage(
            transcript,
            grid.size,
            grid.size,
          ).centreOf(transcript.cellAt(_startCodon));

      await tester.tapAt(base);
      await tester.pumpAndSettle();
      expect(_pill, findsNothing);

      await tester.tapAt(base);
      await tester.pumpAndSettle();
      expect(_pill, findsOneWidget);
    });

    testWidgets('is made for every protein in the catalog', (
      WidgetTester tester,
    ) async {
      for (final ProteinTarget target in TestCatalog.all) {
        final AnatomyModel model = AnatomyModel.derive(
          GeneRecordDto.fromJson(
            jsonDecode(File(target.mockAsset).readAsStringSync())
                as Map<String, dynamic>,
          ).toEntity(),
          chain: target.chain,
        );
        expect(
          TranslationTimeline.translatable(model),
          isTrue,
          reason: target.slug,
        );
      }
    });

    testWidgets('is not made for a record with no coding sequence', (
      WidgetTester tester,
    ) async {
      expect(
        TranslationTimeline.translatable(
          AnatomyModel.derive(insulinWithout(cds: true)),
        ),
        isFalse,
      );
    });
  });

  group('the ribosome', () {
    testWidgets('plays over the transcript, under the header and stage bar', (
      WidgetTester tester,
    ) async {
      await _playing(tester);

      expect(find.byType(TranslationPlayer), findsOneWidget);
      expect(find.byType(TransportBar), findsOneWidget);
      expect(find.byType(AnatomyCanvas), findsNothing);
      expect(_controller(tester).isPlaying, isTrue);
      // The walk's own chrome stays: the transcript's header and the bar,
      // still on the transcript.
      expect(find.text('465'), findsOneWidget);
      expect(_page(tester), _mrna);
      expect(_pill, findsNothing);
      // The player ends above the stage bar.
      expect(
        tester.getRect(find.byType(TransportBar)).bottom,
        lessThanOrEqualTo(tester.getRect(find.byType(StageBar)).top),
      );
      await _stop(tester);
    });

    testWidgets('lands its chain on the protein page at the stop codon', (
      WidgetTester tester,
    ) async {
      await _playing(tester);
      _controller(tester).seek(1);
      await tester.pump();
      await tester.pump();

      // The walk turns to the protein page under the flight.
      expect(_flight, findsOneWidget);
      expect(find.byType(TranslationPlayer), findsNothing);
      expect(_page(tester), _protein);
      expect(find.text('110'), findsOneWidget);
      expect(find.byType(ConstraintToolbar), findsOneWidget);
      final TranslationFlightPainter flight =
          tester.widget<CustomPaint>(_flight).painter!
              as TranslationFlightPainter;
      final Offset flown = tester.getTopLeft(_flight);

      await tester.pumpAndSettle();

      // Where the chain landed is where the page rests, and it rests there
      // without the walk's own translation.
      expect(_flight, findsNothing);
      final AnatomyPainter painter = _painter(tester);
      expect(painter.scene.fromIndex, _protein);
      expect(painter.scene.toIndex, _protein);
      expect(painter.scene.translation, isNull);
      expect(painter.scene.toLayout, flight.layout);
      expect(tester.getTopLeft(_grid), flown);
      await tester.pumpAndSettle();
    });

    testWidgets('lands with no flight when motion is reduced', (
      WidgetTester tester,
    ) async {
      await _playing(tester, reduceMotion: true);
      _controller(tester).seek(1);
      await tester.pump();
      await tester.pump();

      expect(_flight, findsNothing);
      expect(find.byType(TranslationPlayer), findsNothing);
      expect(_page(tester), _protein);
      expect(_painter(tester).scene.toIndex, _protein);
    });
  });

  group('leaving the ribosome', () {
    Future<void> expectTranscript(WidgetTester tester) async {
      await tester.pumpAndSettle();
      expect(find.byType(TranslationPlayer), findsNothing);
      expect(_page(tester), _mrna);
      expect(_painter(tester).scene.toIndex, _mrna);
      expect(_painter(tester).scene.isTransition, isFalse);
      expect(_pill, findsOneWidget);
    }

    Future<void> expectLanded(WidgetTester tester) async {
      await tester.pump();
      await tester.pump();
      expect(_flight, findsOneWidget);
      await tester.pumpAndSettle();
      expect(_flight, findsNothing);
      expect(_page(tester), _protein);
      expect(_painter(tester).scene.toIndex, _protein);
    }

    testWidgets('back, by a swipe, puts it away onto the transcript', (
      WidgetTester tester,
    ) async {
      await _playing(tester);
      await _swipe(tester, forward: false);
      await expectTranscript(tester);
    });

    testWidgets('back, by the transcript\'s own name, puts it away', (
      WidgetTester tester,
    ) async {
      await _playing(tester);
      await tester.tap(find.byKey(const ValueKey<String>('stage-mRNA')));
      await expectTranscript(tester);
    });

    testWidgets('back, by the system, puts it away and stays in the walk', (
      WidgetTester tester,
    ) async {
      await _playing(tester);
      await tester.binding.handlePopRoute();
      await expectTranscript(tester);
      expect(find.byType(AnatomyScreen), findsOneWidget);
    });

    testWidgets('forward, by a swipe, is the stop codon and the flight', (
      WidgetTester tester,
    ) async {
      await _playing(tester);
      await _swipe(tester, forward: true);
      await expectLanded(tester);
    });

    testWidgets('forward, by the protein\'s name, is the stop codon', (
      WidgetTester tester,
    ) async {
      await _playing(tester);
      await tester.tap(find.byKey(const ValueKey<String>('stage-Protein')));
      await expectLanded(tester);
    });

    testWidgets('any other page is gone to straight', (
      WidgetTester tester,
    ) async {
      await _playing(tester);
      await tester.tap(find.byKey(const ValueKey<String>('stage-Gene')));
      await tester.pumpAndSettle();
      expect(find.byType(TranslationPlayer), findsNothing);
      expect(_page(tester), 0);
      expect(_painter(tester).scene.isTransition, isFalse);

      await _swipe(tester, forward: true);
      await tester.pumpAndSettle();
      await tester.tap(_pill);
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey<String>('stage-Fold')));
      await tester.pumpAndSettle();
      expect(find.byType(TranslationPlayer), findsNothing);
      expect(find.byType(StructureView), findsOneWidget);
    });

    testWidgets('a turn during the flight lands the chain first', (
      WidgetTester tester,
    ) async {
      await _playing(tester);
      _controller(tester).seek(1);
      await tester.pump();
      await tester.pump();
      expect(_flight, findsOneWidget);

      await _swipe(tester, forward: false);
      await tester.pumpAndSettle();
      expect(_flight, findsNothing);
      expect(_page(tester), _mrna);
      expect(_painter(tester).scene.toIndex, _mrna);
    });
  });
}
