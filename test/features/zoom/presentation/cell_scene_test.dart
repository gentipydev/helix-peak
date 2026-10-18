import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/core/catalog/protein_target.dart';
import 'package:helixpeek/core/theme/app_theme.dart';
import 'package:helixpeek/features/zoom/domain/cell_archetypes.dart';
import 'package:helixpeek/features/zoom/domain/cell_parts.dart';
import 'package:helixpeek/features/zoom/domain/locus_track.dart';
import 'package:helixpeek/features/zoom/domain/zoom_depth.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/cell/cell_parts.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/cell/neuron_form.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/cell_scene.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/contour.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/nucleus_shape.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/zoom_scene.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/zoom_subject.dart';
import 'package:helixpeek/features/zoom/presentation/zoom_inks.dart';
import 'package:helixpeek/features/zoom/presentation/zoom_painter.dart';

import '../../../support/test_catalog.dart';
import '../record_fixtures.dart';
import '../zoom_fixtures.dart';

const List<Size> _canvases = <Size>[Size(390, 560), Size(320, 420)];

ZoomStage _stage(ProteinTarget t, [LocusTrack? track]) =>
    ZoomStage(ZoomSubject(track: track ?? locusOf(t), record: recordOf(t)));

CellScene _cellOf(ZoomStage stage) =>
    stage.scenes[ZoomStop.cell.index] as CellScene;

Future<ZoomInks> _inks(WidgetTester tester) async {
  late ZoomInks inks;
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.analysis,
      home: Builder(
        builder: (BuildContext context) {
          inks = ZoomInks.of(context);
          return const SizedBox();
        },
      ),
    ),
  );
  return inks;
}

/// The frame [scene] is drawn with at depth [d], if it shows.
ZoomFrame? _frameOf(
  ZoomStage stage,
  ZoomScene scene,
  double d,
  Size size,
  ZoomInks inks,
) {
  for (final (ZoomScene s, ZoomFrame frame) in stage.frames(d, size, inks)) {
    if (identical(s, scene)) {
      return frame;
    }
  }
  return null;
}

/// Points along every contour of [path].
List<Offset> _along(Path path, {int each = 6}) => <Offset>[
  for (final PathMetric m in path.computeMetrics())
    for (int i = 0; i <= each; i++)
      m.getTangentForOffset(m.length * i / each)!.position,
];

/// The proteins whose cells are drawn part by part.
List<ProteinTarget> _drawn() => <ProteinTarget>[
  for (final ProteinTarget t in TestCatalog.all)
    if (_cellOf(_stage(t)).parts != null) t,
];

/// A canvas that keeps the paths drawn on it, with the colour of each.
class _Paths implements Canvas {
  final List<(Path, Color)> drawn = <(Path, Color)>[];

  @override
  void drawPath(Path path, Paint paint) => drawn.add((path, paint.color));

  // Everything else is not a path.
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  test(
    'the endocrine cells and the neurons of the catalog are drawn part by part',
    () {
      expect(
        <String>[for (final ProteinTarget t in _drawn()) t.slug]..sort(),
        <String>[
          // A cell of the adrenal cortex, drawn as the endocrine cell it is.
          'cyp17a1',
          // An excitatory neuron of the brain, drawn as the neuron it is.
          'dynamin1',
          'glucagon',
          'insulin',
          'oxytocin',
          // A rod photoreceptor of the retina, drawn as the neuron it is.
          'recoverin',
          'somatotropin',
          'vasopressin',
        ],
      );
    },
  );

  test('every part lies in the cytoplasm: inside the cell, outside its '
      'nucleus', () {
    for (final ProteinTarget t in _drawn()) {
      final CellScene cell = _cellOf(_stage(t));
      final Path nucleus = cell.nucleusShape.outline(cell.nucleus).toPath();
      for (final MapEntry<PartLayer, Path> layer
          in cell.parts!.layers.entries) {
        for (final Offset p in _along(layer.value)) {
          final String where = '${t.slug}: ${layer.key.name} at $p';
          expect(cell.body.contains(p), isTrue, reason: where);
          expect(nucleus.contains(p), isFalse, reason: where);
        }
      }
    }
  });

  test('each name lands on what it names', () {
    for (final ProteinTarget t in _drawn()) {
      final CellScene cell = _cellOf(_stage(t));
      final CellParts parts = cell.parts!;
      for (final CellPart part in recipeOf(cell.archetype.shape).named) {
        final Offset at = parts.targets[part]!;
        final String where = '${t.slug}: ${part.word}';
        final (Path, bool)? glow = parts.glowOf(part);
        if (glow == null) {
          // A process: the dendrites, the hillock, the axon.
          expect(cell.body.contains(at), isTrue, reason: where);
        } else if (glow.$2) {
          // A sac of a stack, which the name lands on.
          final double near = _along(
            glow.$1,
            each: 24,
          ).map((Offset p) => (p - at).distance).reduce(math.min);
          expect(near, lessThan(1e-3 * cell.size), reason: where);
        } else {
          expect(glow.$1.contains(at), isTrue, reason: where);
        }
      }
    }
  });

  testWidgets('at rest every name round the cell sits outside it and on the '
      'canvas, its line crossing no other, for every curated protein, at '
      'two widths', (
    WidgetTester tester,
  ) async {
    final ZoomInks inks = await _inks(tester);
    final TextStyle labels = AppTheme.analysis.textTheme.labelSmall!;
    for (final Size size in _canvases) {
      for (final ProteinTarget t in TestCatalog.all) {
        final ZoomStage stage = _stage(t);
        final CellScene cell = _cellOf(stage);
        final double d = stage.depth.depthOf(ZoomStop.cell);
        final ZoomFrame frame = _frameOf(stage, cell, d, size, inks)!;
        final List<Offset> outline = <Offset>[
          for (final Offset p in cell.outline) frame.toScreen(p),
        ];
        final Path inside = Contour(outline).toPath();
        final Map<String, RingPlate> plates = stage.ringsAt(
          d,
          size,
          inks,
          labels,
        );
        final List<ZoomCallout> named = stage
            .stage(d, size, inks)
            .callouts
            .where((ZoomCallout c) => c.ring != null)
            .toList();
        expect(plates.keys.toSet(), <String>{
          for (final ZoomCallout c in named) c.key,
        });
        for (final ZoomCallout c in named) {
          final Rect plate = plates[c.key]!.plate;
          final String where = '${t.slug}, ${c.text} at ${size.width}';
          for (final Offset p in outline) {
            expect(plate.contains(p), isFalse, reason: where);
          }
          for (final Offset corner in <Offset>[
            plate.topLeft,
            plate.topRight,
            plate.bottomLeft,
            plate.bottomRight,
            plate.center,
          ]) {
            expect(inside.contains(corner), isFalse, reason: where);
          }
          expect(plate.left, greaterThanOrEqualTo(0), reason: where);
          expect(plate.right, lessThanOrEqualTo(size.width), reason: where);
          expect(plate.top, greaterThanOrEqualTo(0), reason: where);
          expect(plate.bottom, lessThanOrEqualTo(size.height), reason: where);
        }
        for (int i = 0; i < named.length; i++) {
          for (int j = i + 1; j < named.length; j++) {
            expect(
              linesCross(
                lineFrom(plates[named[i].key]!.plate, named[i].target),
                lineFrom(plates[named[j].key]!.plate, named[j].target),
              ),
              isFalse,
              reason: '${t.slug} at ${size.width}: '
                  '${named[i].text} and ${named[j].text}',
            );
          }
        }
      }
    }
  });

  testWidgets('the parts the cell names, but those the protein\'s own name '
      'says: glucagon\'s cell does not name its rough ER', (
    WidgetTester tester,
  ) async {
    final ZoomInks inks = await _inks(tester);
    const Size size = Size(390, 560);
    for (final ProteinTarget t in _drawn()) {
      final ZoomStage stage = _stage(t);
      final CellScene cell = _cellOf(stage);
      final List<String> quiet = <String>[
        for (final ZoomCallout c
            in stage
                .stage(stage.depth.depthOf(ZoomStop.cell), size, inks)
                .callouts)
          if (c.quiet) c.text,
      ];
      expect(quiet, <String>[
        for (final CellPart part in partsToName(
          recipeOf(cell.archetype.shape),
          locusOf(t).subcellular.main,
        ))
          part.word,
      ], reason: t.slug);
    }
    final List<String> glucagon = <String>[
      for (final ZoomCallout c
          in _stage(TestCatalog.glucagon)
              .stage(
                _stage(TestCatalog.glucagon).depth.depthOf(ZoomStop.cell),
                size,
                inks,
              )
              .callouts)
        c.text,
    ];
    expect(glucagon, contains('endoplasmic reticulum'));
    expect(glucagon, isNot(contains('rough ER')));
  });

  testWidgets('the protein glows in the parts the Atlas finds it in, as drawn: '
      'glucagon\'s in the rough ER and the granules, and a lysosomal one in '
      'the lysosomes, not the granules', (WidgetTester tester) async {
    final ZoomInks inks = await _inks(tester);
    const Size size = Size(390, 560);
    bool marked(Color c) =>
        (c.r - inks.mark.r).abs() < 1e-3 &&
        (c.g - inks.mark.g).abs() < 1e-3 &&
        (c.b - inks.mark.b).abs() < 1e-3 &&
        c.a > 0;
    Set<PartLayer> glowing(ZoomStage stage) {
      final CellScene cell = _cellOf(stage);
      final _Paths canvas = _Paths();
      cell.paint(
        canvas,
        _frameOf(stage, cell, stage.depth.depthOf(ZoomStop.cell), size, inks)!,
      );
      return <PartLayer>{
        for (final (Path path, Color color) in canvas.drawn)
          if (marked(color))
            for (final MapEntry<PartLayer, Path> layer
                in cell.parts!.layers.entries)
              if (identical(layer.value, path)) layer.key,
      };
    }

    expect(glowing(_stage(TestCatalog.glucagon)), <PartLayer>{
      PartLayer.erSacs,
      PartLayer.granuleHalos,
    });
    expect(glowing(_stage(TestCatalog.insulin)), isEmpty);
    final Map<String, dynamic> json = jsonDecode(
      jsonEncode(locusJson(TestCatalog.insulin)),
    ) as Map<String, dynamic>;
    (json['expression']
        as Map<String, dynamic>)['subcellular'] = <String, dynamic>{
      'main': <String>['Lysosomes'],
      'additional': <String>[],
    };
    expect(
      glowing(
        _stage(
          TestCatalog.insulin,
          LocusTrack.fromJson(json, TestCatalog.insulin),
        ),
      ),
      <PartLayer>{PartLayer.lysosomes},
    );
  });

  test('each kind of cell reaches from its nucleus as far as its archetype '
      'says: its outline and nucleus, a neuron less its axon', () {
    for (final CellShape shape in CellShape.values) {
      final CellArchetype archetype = archetypeFor(shape);
      final double n = archetype.nucleus / archetype.metres;
      final Rect box;
      if (shape == CellShape.neuron) {
        final NeuronForm form = NeuronForm(1);
        final Path all = Path()..addPath(form.body.toPath(), Offset.zero);
        for (final NeuronBranch b in <NeuronBranch>[
          ...form.dendrites,
          form.hillock,
        ]) {
          all.addPath(b.path, Offset.zero);
        }
        box = all.getBounds();
      } else {
        // As drawn: the smooth path through the outline's points bulges a
        // little past them.
        box = _along(
          Path()
            ..addPath(cellOutline(shape, 1, n).toPath(), Offset.zero)
            ..addPath(NucleusShape(shape).outline(n).toPath(), Offset.zero),
          each: 400,
        ).fold<Rect?>(
              null,
              (Rect? b, Offset p) => b == null
                  ? Rect.fromPoints(p, p)
                  : b.expandToInclude(Rect.fromPoints(p, p)),
            )!;
      }
      final CellReach reach = archetype.reach;
      void holds(double? said, double measured, String what) {
        expect(said, isNotNull, reason: '${shape.name} $what');
        expect(
          said!,
          inInclusiveRange(measured - 1e-3, measured + 0.02),
          reason: '${shape.name} $what',
        );
      }

      if (shape == CellShape.myofibre) {
        // A fibre runs off both sides of the view: two views either way.
        expect(reach.across, isNull);
        expect(box.width, greaterThan(3));
      } else {
        holds(reach.across, math.max(-box.left, box.right), 'across');
      }
      holds(reach.up, -box.top, 'up');
      holds(reach.down, box.bottom, 'down');
    }
  });

  test('every cell is framed as big as its room lets it: across seven '
      'tenths of the view, or as far up or down as a squat canvas leaves '
      'it, or as near as its nucleus\'s own view lets it', () {
    const double fill = CellArchetype.fill;
    for (final ProteinTarget t in TestCatalog.all) {
      final ZoomStage stage = _stage(t);
      final CellScene cell = _cellOf(stage);
      final CellReach reach = cell.archetype.reach;
      final double half = cell.size;
      final String where = '${t.slug} (${cell.archetype.shape.name})';
      final double? across = reach.across;
      if (across != null) {
        expect(2 * across * half, lessThanOrEqualTo(fill + 1e-9), reason: where);
      }
      expect(
        reach.up * half,
        lessThanOrEqualTo(CellArchetype.roomAbove + 1e-9),
        reason: where,
      );
      expect(
        reach.down * half,
        lessThanOrEqualTo(CellArchetype.roomBelow + 1e-9),
        reason: where,
      );
      final bool bound =
          (across != null && 2 * across * half > fill - 1e-6) ||
          reach.up * half > CellArchetype.roomAbove - 1e-6 ||
          reach.down * half > CellArchetype.roomBelow - 1e-6 ||
          (stage.depth.widthOf(ZoomStop.cell) -
                      1.3 * stage.depth.widthOf(ZoomStop.nucleus))
                  .abs() <
              1e-15;
      expect(bound, isTrue, reason: where);
    }
    // The beta cell, as the user saw it: seven tenths across, not half.
    final CellScene insulin = _cellOf(_stage(TestCatalog.insulin));
    final Rect box = Contour(insulin.outline).toPath().getBounds();
    expect(box.width, inInclusiveRange(0.66, 0.72));
  });

  testWidgets('the scale bar at the cell reads what it did, drawn as much '
      'longer as the cell is drawn bigger: a beta cell\'s and an alpha '
      'cell\'s 5 µm', (WidgetTester tester) async {
    for (final ProteinTarget t in <ProteinTarget>[
      TestCatalog.insulin,
      TestCatalog.glucagon,
    ]) {
      final ZoomDepth depth = _stage(t).depth;
      for (final Size size in _canvases) {
        final (double pixels, String label) = scaleBarAt(
          depth,
          depth.depthOf(ZoomStop.cell),
          size,
        );
        expect(label, '5 µm', reason: t.slug);
        expect(
          pixels,
          closeTo(5e-6 / depth.widthOf(ZoomStop.cell) * size.width, 1e-6),
          reason: t.slug,
        );
      }
    }
  });

  test('a neuron is one outline round its body, its dendrites and its axon, '
      'reaching no further than it always did', () {
    for (final double r in <double>[0.263, 20]) {
      final NeuronForm form = NeuronForm(r);
      final List<Offset> points = form.outline().points;
      final Path outline = Contour(points).toPath();
      expect(outline.contains(Offset.zero), isTrue);
      for (final Offset p in form.body.points) {
        expect(outline.contains(p * 0.95), isTrue);
      }
      for (final NeuronBranch b in <NeuronBranch>[
        ...form.dendrites,
        form.hillock,
        form.axon,
      ]) {
        expect(outline.contains(b.at(0.5)), isTrue);
      }
      final double left = points.map((Offset p) => p.dx).reduce(math.min);
      final double right = points.map((Offset p) => p.dx).reduce(math.max);
      final double top = points.map((Offset p) => p.dy).reduce(math.min);
      final double bottom = points.map((Offset p) => p.dy).reduce(math.max);
      expect(left, greaterThan(-1.05 * r));
      expect(right, lessThan(1.05 * r));
      expect(top, greaterThan(-1.05 * r));
      expect(bottom, lessThan(1.86 * r));
      // Its axon is even past the hillock.
      expect(form.axon.toWidth / form.axon.fromWidth, closeTo(1, 0.1));
    }
  });

  test('a neuron\'s Nissl bodies keep out of its hillock and its axon', () {
    for (final ProteinTarget t in _drawn()) {
      final CellScene cell = _cellOf(_stage(t));
      if (cell.archetype.shape != CellShape.neuron) {
        continue;
      }
      final NeuronForm form = NeuronForm(cell.size);
      final Path hillock = form.hillock.path;
      final Path axon = form.axon.path;
      final List<Offset> nissl = _along(cell.parts!.layers[PartLayer.nissl]!);
      expect(nissl, isNotEmpty);
      for (final Offset p in nissl) {
        expect(hillock.contains(p), isFalse, reason: '${t.slug} at $p');
        expect(axon.contains(p), isFalse, reason: '${t.slug} at $p');
      }
    }
  });

  testWidgets('the parts come up as the step from the tissue ends, and are '
      'whole at rest', (WidgetTester tester) async {
    final ZoomInks inks = await _inks(tester);
    const Size size = Size(390, 560);
    for (final ProteinTarget t in _drawn()) {
      final ZoomStage stage = _stage(t);
      final double tissue = stage.depth.depthOf(ZoomStop.tissue);
      final double cell = stage.depth.depthOf(ZoomStop.cell);
      double detail(double d) =>
          stage.stage(d, size, inks).items['cell:detail']?.$2 ?? 0;
      expect(detail(cell), closeTo(1, 1e-9), reason: t.slug);
      expect(detail(tissue + 0.4 * (cell - tissue)), 0, reason: t.slug);
      expect(detail(cell + 0.2 * (cell - tissue)), greaterThan(0));
    }
  });
}
