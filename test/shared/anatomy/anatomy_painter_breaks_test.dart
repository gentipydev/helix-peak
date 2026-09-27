import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/core/biology/gene_record.dart';
import 'package:helixpeek/core/theme/anatomy_colors.dart';
import 'package:helixpeek/core/theme/app_theme.dart';
import 'package:helixpeek/core/theme/nucleotide_colors.dart';
import 'package:helixpeek/features/gene_lookup/data/models/gene_record_dto.dart';
import 'package:helixpeek/shared/anatomy/anatomy_painter.dart';
import 'package:helixpeek/shared/anatomy/anatomy_scene.dart';
import 'package:helixpeek/shared/anatomy/anatomy_selection.dart';
import 'package:helixpeek/shared/anatomy/anatomy_stages.dart';

/// The painter's `breaks` is a new parameter on a shared widget, so what it
/// has to prove is that leaving it out draws exactly what the walk drew
/// before, and that passing it draws something more.
///
/// The render baseline is the other half of this proof: those 32 goldens are
/// drawn by this painter with `breaks` left out, and they diff to zero.
const Size _canvas = Size(390, 900);

GeneRecord _insulin() => GeneRecordDto.fromJson(
  jsonDecode(File('test/fixtures/mock/gene_ins.json').readAsStringSync())
      as Map<String, dynamic>,
).toEntity();

AnatomyPainter _painter({
  required AnatomyScene scene,
  required NucleotideColors nucleotides,
  required AnatomyColors anatomy,
  required ColorScheme colors,
  List<int> breaks = const <int>[],
  bool passBreaks = true,
}) => passBreaks
    ? AnatomyPainter(
        repaint: const AlwaysStoppedAnimation<double>(1),
        scene: scene,
        progress: const AlwaysStoppedAnimation<double>(1),
        groove: const AlwaysStoppedAnimation<double>(1),
        reverse: false,
        tracer: null,
        status: null,
        inertTracer: null,
        background: colors.surface,
        nucleotides: nucleotides,
        anatomy: anatomy,
        maskAccent: colors.primary,
        rulerInk: colors.onSurfaceVariant,
        breaks: breaks,
      )
    : AnatomyPainter(
        repaint: const AlwaysStoppedAnimation<double>(1),
        scene: scene,
        progress: const AlwaysStoppedAnimation<double>(1),
        groove: const AlwaysStoppedAnimation<double>(1),
        reverse: false,
        tracer: null,
        status: null,
        inertTracer: null,
        background: colors.surface,
        nucleotides: nucleotides,
        anatomy: anatomy,
        maskAccent: colors.primary,
        rulerInk: colors.onSurfaceVariant,
      );

Future<Uint8List> _pixels(AnatomyPainter painter) async {
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  painter.paint(Canvas(recorder), _canvas);
  final ui.Image image = await recorder.endRecording().toImage(
    _canvas.width.round(),
    _canvas.height.round(),
  );
  final ByteData? data = await image.toByteData(
    format: ui.ImageByteFormat.rawRgba,
  );
  image.dispose();
  return data!.buffer.asUint8List();
}

void main() {
  testWidgets('a page with nothing cut draws what it always drew', (
    WidgetTester tester,
  ) async {
    final GeneRecord insulin = _insulin();
    final AnatomyModel model = AnatomyModel.derive(insulin);
    // A region opened into its letters: tiles large enough for a mark in the
    // mortar to have somewhere to go.
    final AnatomySelection region = AnatomySelection.of(model, 5358);
    late NucleotideColors nucleotides;
    late AnatomyColors anatomy;
    late ColorScheme colors;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.analysis,
        home: Builder(
          builder: (BuildContext context) {
            nucleotides = context.nucleotideColors;
            anatomy = context.anatomyColors;
            colors = Theme.of(context).colorScheme;
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    final AnatomyScene scene = AnatomyScene.selection(
      model: model,
      selected: region.stage,
      canvas: _canvas,
      viewport: _canvas,
      resting: true,
    );
    AnatomyPainter painting({List<int>? breaks}) => _painter(
      scene: scene,
      nucleotides: nucleotides,
      anatomy: anatomy,
      colors: colors,
      breaks: breaks ?? const <int>[],
      passBreaks: breaks != null,
    );

    expect(painting().breaks, isEmpty);

    await tester.runAsync(() async {
      final Uint8List left = await _pixels(painting());
      final Uint8List given = await _pixels(painting(breaks: <int>[]));
      final Uint8List cut = await _pixels(
        painting(breaks: <int>[region.stage.cellAt(5358)]),
      );
      expect(given, left, reason: 'an empty list is what leaving it out means');
      expect(cut, isNot(left), reason: 'a cut is drawn where one is given');
    });
  });

  testWidgets('the painter repaints when the cuts change', (
    WidgetTester tester,
  ) async {
    final AnatomyModel model = AnatomyModel.derive(_insulin());
    final AnatomySelection region = AnatomySelection.of(model, 5358);
    late NucleotideColors nucleotides;
    late AnatomyColors anatomy;
    late ColorScheme colors;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.analysis,
        home: Builder(
          builder: (BuildContext context) {
            nucleotides = context.nucleotideColors;
            anatomy = context.anatomyColors;
            colors = Theme.of(context).colorScheme;
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    final AnatomyScene scene = AnatomyScene.selection(
      model: model,
      selected: region.stage,
      canvas: _canvas,
      viewport: _canvas,
      resting: true,
    );
    AnatomyPainter painting(List<int> breaks) => _painter(
      scene: scene,
      nucleotides: nucleotides,
      anatomy: anatomy,
      colors: colors,
      breaks: breaks,
    );

    expect(painting(<int>[4]).shouldRepaint(painting(<int>[])), isTrue);
    expect(painting(<int>[4]).shouldRepaint(painting(<int>[4])), isFalse);
  });
}
