import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/core/evidence/protein_constraint.dart';
import 'package:helixpeek/core/theme/app_theme.dart';
import 'package:helixpeek/features/gene_lookup/presentation/anatomy/anatomy_screen.dart';
import 'package:helixpeek/features/gene_lookup/presentation/anatomy/walk_ribosome.dart';
import 'package:helixpeek/shared/motion/timeline_controller.dart';
import 'package:helixpeek/shared/ribosome/translation_player.dart';
import 'package:helixpeek/shared/ribosome/translation_timeline.dart';
import 'package:helixpeek/shared/share/share_action.dart';
import 'package:helixpeek/shared/share/share_clip_button.dart';

import '../../../support/test_catalog.dart';
import 'anatomy_fixture.dart';

final ProteinConstraint _constraint = ProteinConstraint.fromJson(
  jsonDecode(File(TestCatalog.insulin.constraintAsset).readAsStringSync())
      as Map<String, dynamic>,
  TestCatalog.insulin,
);

final Finder _clip = find.byKey(const ValueKey<String>('share-clip'));
final Finder _poster = find.byKey(const ValueKey<String>('share-poster'));
final Finder _pill = find.byKey(const ValueKey<String>('open-ribosome'));

/// The transcript page, as the walk opens onto it.
Future<void> _transcript(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(390, 844));
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.analysis,
      home: AnatomyScreen(
        target: TestCatalog.insulin,
        record: insulin(),
        constraint: _constraint,
      ),
    ),
  );
  await tester.pumpAndSettle();
  await _swipe(tester, forward: true);
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

Future<void> _play(WidgetTester tester) async {
  await tester.tap(_pill);
  await tester.pump();
}

TimelineController _controller(WidgetTester tester) =>
    tester.widget<TranslationPlayer>(find.byType(TranslationPlayer)).controller;

void main() {
  group('while the ribosome is up, the header shares', () {
    testWidgets('its clip and the protein’s poster, and nowhere else', (
      WidgetTester tester,
    ) async {
      await _transcript(tester);
      expect(_clip, findsNothing);
      expect(_poster, findsNothing);

      await _play(tester);
      expect(_clip, findsOneWidget);
      expect(_poster, findsOneWidget);
      // Up in the header, beside the count, where the lab had them.
      final Rect count = tester.getRect(find.text('465'));
      for (final Finder share in <Finder>[_clip, _poster]) {
        final Rect rect = tester.getRect(share);
        expect(rect.bottom, lessThanOrEqualTo(count.bottom + 16));
        expect(rect.right, lessThanOrEqualTo(count.left));
      }

      // Through the chain's flight, and not once it has landed.
      _controller(tester).seek(1);
      await tester.pump();
      await tester.pump();
      expect(
        find.byKey(const ValueKey<String>('walk-ribosome-flight')),
        findsOneWidget,
      );
      expect(_clip, findsOneWidget);
      expect(_poster, findsOneWidget);
      await tester.pumpAndSettle();
      expect(_clip, findsNothing);
      expect(_poster, findsNothing);
    });

    testWidgets('and stops sharing once it is put away', (
      WidgetTester tester,
    ) async {
      await _transcript(tester);
      await _play(tester);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(_pill, findsOneWidget);
      expect(_clip, findsNothing);
      expect(_poster, findsNothing);
    });

    testWidgets('a clip of the whole translation, paced by its director', (
      WidgetTester tester,
    ) async {
      await _transcript(tester);
      await _play(tester);
      final ShareClipButton clip = tester.widget<ShareClipButton>(
        find.byType(ShareClipButton),
      );
      final TranslationTimeline translation = TranslationTimeline(
        insulin(),
        chain: TestCatalog.insulin.chain,
      );
      expect(clip.target, TestCatalog.insulin);
      expect(clip.duration, WalkRibosome.clipBeat * translation.beats);
      for (final double wall in <double>[0, 0.5, 1]) {
        final ui.PictureRecorder recorder = ui.PictureRecorder();
        clip.painter(wall).paint(Canvas(recorder), clip.size);
        recorder.endRecording().dispose();
      }
      _controller(tester).pause();
    });

    testWidgets('a poster of the walk’s own protein', (
      WidgetTester tester,
    ) async {
      await _transcript(tester);
      await _play(tester);
      final SharePosterButton poster = tester.widget<SharePosterButton>(
        find.byType(SharePosterButton),
      );
      expect(poster.target, TestCatalog.insulin);
      expect(
        poster.model.record.protein!.translation,
        insulin().protein!.translation,
      );
      _controller(tester).pause();
    });
  });
}
