import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/core/catalog/protein_target.dart';
import 'package:helixpeek/core/theme/app_theme.dart';
import 'package:helixpeek/core/theme/chromosome_colors.dart';
import 'package:helixpeek/core/theme/nucleotide_colors.dart';
import 'package:helixpeek/features/zoom/domain/locus_track.dart';
import 'package:helixpeek/features/zoom/domain/zoom_camera.dart';
import 'package:helixpeek/features/zoom/domain/zoom_depth.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/band_scene.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/chromosome/chromosome_art.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/chromosome/chromosome_form.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/chromosome/chromosome_shading.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/chromosome/chromosome_style.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/chromosome/chromosome_tube.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/chromosome_scene.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/zoom_scene.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/zoom_subject.dart';
import 'package:helixpeek/features/zoom/presentation/zoom_inks.dart';
import 'package:helixpeek/features/zoom/presentation/zoom_painter.dart';

import '../../../support/test_catalog.dart';
import '../record_fixtures.dart';
import '../zoom_fixtures.dart';

/// The zoom's canvas on a phone, under the app bar and above the card.
const Size _canvas = Size(390, 560);

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

ZoomSubject _subject(ProteinTarget t) =>
    ZoomSubject(track: locusOf(t), record: recordOf(t));

ChromosomeScene _scene(ProteinTarget t, ChromosomeLook look) =>
    ChromosomeScene(_subject(t), look: look);

ZoomStage _stage(ProteinTarget t, ChromosomeLook look) =>
    ZoomStage(_subject(t), chromosome: look);

/// [t]'s chromosome as a form in the vivid look, freshly built.
ChromosomeForm _vivid(ProteinTarget t) => ChromosomeForm(
  locusOf(t),
  half: _scene(t, ChromosomeLook.stone).half,
  look: ChromosomeLookSpec.vivid,
);

/// A colour's channels as bytes.
(int, int, int) _bytes(int colour) =>
    (colour >> 16 & 255, colour >> 8 & 255, colour & 255);

/// The chromosome scene of [stage] at [s] of the way from its stop to the
/// band, and the frame it is drawn with.
(ChromosomeScene, ZoomFrame) _turning(
  ZoomStage stage,
  ZoomInks inks,
  double s,
) {
  final ZoomDepth depth = stage.depth;
  for (final (ZoomScene scene, ZoomFrame frame) in stage.frames(
    depth.depthOf(ZoomStop.chromosome) +
        s * depth.travelOf(ZoomStop.chromosome.index),
    _canvas,
    inks,
  )) {
    if (scene is ChromosomeScene) {
      return (scene, frame);
    }
  }
  throw StateError('no chromosome at $s');
}

/// What [paint] draws on a canvas of [size], as RGBA bytes.
Future<Uint8List> _raster(
  WidgetTester tester,
  Size size,
  void Function(Canvas) paint,
) async {
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  paint(Canvas(recorder));
  final ui.Picture picture = recorder.endRecording();
  final Uint8List? bytes = await tester.runAsync(() async {
    final ui.Image image = await picture.toImage(
      size.width.toInt(),
      size.height.toInt(),
    );
    final ByteData data = (await image.toByteData())!;
    image.dispose();
    return data.buffer.asUint8List();
  });
  picture.dispose();
  return bytes!;
}

/// A canvas that draws nothing.
class _Nowhere implements Canvas {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

/// A canvas that draws nothing, and keeps the paint of every path drawn on
/// it.
class _Paths implements Canvas {
  final List<Paint> paints = <Paint>[];

  @override
  void drawPath(Path path, Paint paint) => paints.add(paint);

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  test('the stone is ChromosomeStyle’s numbers, with no globules, and the '
      'vivid is what a build draws unless it asks for the stone', () {
    const ChromosomeLookSpec stone = ChromosomeLookSpec.stone;
    expect(
      <double>[
        stone.apart,
        stone.pinch,
        stone.opening,
        stone.openingPower,
        stone.bend,
        stone.rowStep,
        stone.waistRowStep,
        stone.waistRows,
        stone.feather,
        stone.featherShare,
        stone.bow,
        stone.sheen,
        stone.occlusion,
        stone.wash,
        stone.lobe,
        stone.lobeSpread,
        stone.lobeWaist,
        stone.lobeLattice,
        stone.lobeTilt,
        stone.skirtInner,
        stone.skirtOuter,
        stone.skirtAlpha,
        stone.granule,
        stone.granuleSpread,
        stone.granuleFloor,
        stone.granules,
        stone.bumpLift,
        stone.bumpAlpha,
        stone.pitAlpha,
        stone.shadowX,
        stone.shadowY,
        stone.shadowAlpha,
        stone.shadowSoft,
        stone.plateX,
        stone.plateY,
        stone.plateOut,
        stone.centromereTint,
        stone.centromereReach,
        stone.kinetochoreTint,
        stone.telomereTint,
        stone.telomereReach,
        stone.fish,
        stone.fishShare,
        stone.fishGlow,
        stone.fishOnStrip,
        stone.paleLit,
        stone.deepShade,
        stone.warmth,
      ],
      <double>[
        ChromosomeStyle.apart,
        ChromosomeStyle.pinch,
        ChromosomeStyle.opening,
        ChromosomeStyle.openingPower,
        ChromosomeStyle.bend,
        ChromosomeStyle.rowStep,
        ChromosomeStyle.waistRowStep,
        ChromosomeStyle.waistRows,
        ChromosomeStyle.feather,
        ChromosomeStyle.featherShare,
        ChromosomeStyle.bow,
        ChromosomeStyle.sheen,
        ChromosomeStyle.occlusion,
        ChromosomeStyle.wash,
        ChromosomeStyle.lobe,
        ChromosomeStyle.lobeSpread,
        ChromosomeStyle.lobeWaist,
        ChromosomeStyle.lobeLattice,
        ChromosomeStyle.lobeTilt,
        ChromosomeStyle.skirtInner,
        ChromosomeStyle.skirtOuter,
        ChromosomeStyle.skirtAlpha,
        ChromosomeStyle.granule,
        ChromosomeStyle.granuleSpread,
        ChromosomeStyle.granuleFloor,
        ChromosomeStyle.granules,
        ChromosomeStyle.bumpLift,
        ChromosomeStyle.bumpAlpha,
        ChromosomeStyle.pitAlpha,
        ChromosomeStyle.shadowX,
        ChromosomeStyle.shadowY,
        ChromosomeStyle.shadowAlpha,
        ChromosomeStyle.shadowSoft,
        ChromosomeStyle.plateX,
        ChromosomeStyle.plateY,
        ChromosomeStyle.plateOut,
        ChromosomeStyle.centromereTint,
        ChromosomeStyle.centromereReach,
        ChromosomeStyle.kinetochoreTint,
        ChromosomeStyle.telomereTint,
        ChromosomeStyle.telomereReach,
        ChromosomeStyle.fish,
        ChromosomeStyle.fishShare,
        ChromosomeStyle.fishGlow,
        ChromosomeStyle.fishOnStrip,
        ChromosomeStyle.paleLit,
        ChromosomeStyle.deepShade,
        ChromosomeStyle.warmth,
      ],
    );
    expect(stone.columns, ChromosomeStyle.columns);
    // What were numbers in the code before the looks.
    expect(stone.waistLength, 0.9);
    expect(stone.endRound, 1);
    expect(stone.boundsInflate, 1.2);
    expect(stone.ambientScale, 1);
    expect(stone.diffuseGain, 1);
    expect(stone.globules, isNull);
    expect(ChromosomeLook.stone.spec, same(ChromosomeLookSpec.stone));
    expect(ChromosomeLook.vivid.spec, same(ChromosomeLookSpec.vivid));
    expect(ChromosomeLook.chosen, ChromosomeLook.vivid);
    expect(
      _scene(TestCatalog.insulin, ChromosomeLook.chosen).form.look,
      same(ChromosomeLookSpec.vivid),
    );
    expect(
      (ZoomStage(_subject(TestCatalog.insulin))
                  .scenes[ZoomStop.chromosome.index]
              as ChromosomeScene)
          .look,
      ChromosomeLook.vivid,
    );
    // A stone chromosome's knobs carry no materials.
    final ChromosomeForm form = _scene(
      TestCatalog.insulin,
      ChromosomeLook.stone,
    ).form;
    for (final double side in <double>[-1, 1]) {
      expect(form.knobs(side).material, isEmpty);
      expect(form.knobs(side).pick, isEmpty);
      expect(form.knobs(side).lift, isEmpty);
    }
  });

  test('every vivid knob’s material is picked the same every time, and '
      'proteins on one chromosome share their knobs', () {
    List<double> shape(ChromosomeForm form) => <double>[
      for (final double side in <double>[-1, 1]) ...<double>[
        ...form.knobs(side).y,
        ...form.knobs(side).phi,
        ...form.knobs(side).radius,
        for (final int kind in form.knobs(side).kind) kind.toDouble(),
        for (final int m in form.knobs(side).material) m.toDouble(),
        ...form.knobs(side).pick,
        ...form.knobs(side).lift,
      ],
    ];
    for (final ProteinTarget t in TestCatalog.all) {
      final ChromosomeForm form = _vivid(t);
      expect(shape(form), shape(_vivid(t)), reason: t.slug);
      for (final double side in <double>[-1, 1]) {
        final KnobField knobs = form.knobs(side);
        expect(knobs.material, hasLength(knobs.length), reason: t.slug);
        expect(knobs.pick, hasLength(knobs.length), reason: t.slug);
        expect(knobs.lift, hasLength(knobs.length), reason: t.slug);
        for (int k = 0; k < knobs.length; k++) {
          expect(knobs.pick[k], inInclusiveRange(-1, 1), reason: t.slug);
          expect(knobs.lift[k], inInclusiveRange(-1, 1), reason: t.slug);
          // The form picks the arms', the centromere's or a telomere's; the
          // gene's is each protein's, picked by the art.
          expect(
            knobs.material[k],
            isNot(ChromatinMaterial.gene.index),
            reason: t.slug,
          );
        }
      }
    }
    for (final List<ProteinTarget> same in <List<ProteinTarget>>[
      <ProteinTarget>[TestCatalog.insulin, TestCatalog.hemoglobin],
      <ProteinTarget>[TestCatalog.p53, TestCatalog.somatotropin],
      <ProteinTarget>[TestCatalog.app, TestCatalog.sod1],
    ]) {
      expect(
        shape(_vivid(same.last)),
        shape(_vivid(same.first)),
        reason: same.last.slug,
      );
    }
  });

  testWidgets('coral lies only about the centromere, gold only at the ends '
      'and teal only round the spots, and every chromosome shows all four '
      'and its arms’ blue', (WidgetTester tester) async {
    final ZoomInks inks = await _inks(tester);
    final ChromosomeLookSpec look = ChromosomeLookSpec.vivid;
    final ChromosomeGlobules globules = look.globules!;
    for (final ProteinTarget t in TestCatalog.all) {
      final ChromosomeForm form = _scene(t, ChromosomeLook.vivid).form;
      final ChromosomeArt art = ChromosomeArt(form, inks);
      // How far a knob is drawn from where its material was picked: the
      // bow of the band's edges.
      final double bow = look.bow * form.half;
      final List<Offset> spots = <Offset>[form.fish(-1), form.fish(1)];
      final Map<ChromatinMaterial, int> seen = <ChromatinMaterial, int>{};
      for (final double side in <double>[-1, 1]) {
        for (final ({Offset at, double radius, ChromatinMaterial material}) g
            in art.globulesOf(side)) {
          seen.update(g.material, (int n) => n + 1, ifAbsent: () => 1);
          final String where = '${t.slug}, ${g.material.name} at ${g.at}';
          switch (g.material) {
            case ChromatinMaterial.centromere:
              expect(
                (g.at.dy - form.centromere).abs(),
                lessThan(look.centromereReach * form.half + bow),
                reason: where,
              );
            case ChromatinMaterial.telomere:
              expect(
                math.min(g.at.dy - form.top, form.bottom - g.at.dy),
                lessThan(look.telomereReach * form.half + bow),
                reason: where,
              );
            case ChromatinMaterial.gene:
              expect(
                spots
                    .map((Offset spot) => (g.at - spot).distance)
                    .reduce(math.min),
                lessThan(globules.geneReach * form.half),
                reason: where,
              );
            case ChromatinMaterial.body:
              break;
          }
        }
      }
      for (final ChromatinMaterial m in ChromatinMaterial.values) {
        expect(seen[m] ?? 0, greaterThan(0), reason: '${t.slug}: ${m.name}');
      }
      expect(
        seen[ChromatinMaterial.body],
        greaterThan(seen.values.reduce((int a, int b) => a + b) ~/ 2),
        reason: '${t.slug}: mostly the arms’ blue',
      );
    }
  });

  testWidgets('each material keeps its hue from its crevice to its sheen, and '
      'grows lighter with the light', (WidgetTester tester) async {
    final ZoomInks inks = await _inks(tester);
    final ChromosomePalette palette = ChromosomePalette(
      inks,
      look: ChromosomeLookSpec.vivid,
    );
    bool keeps(ChromatinMaterial m, int r, int g, int b) => switch (m) {
      // Blue: even its shadows.
      ChromatinMaterial.body => b > r && b > g,
      // Coral: red over both.
      ChromatinMaterial.centromere => r > g && r > b,
      // Honey: both over blue.
      ChromatinMaterial.telomere => r > b && g > b,
      // Teal: green and blue over red.
      ChromatinMaterial.gene => g > r && b > r,
    };
    for (final ChromatinMaterial m in ChromatinMaterial.values) {
      for (int i = 0; i <= 26; i++) {
        final double light = i * 0.05;
        for (final double tone in <double>[0, 0.45, 0.82]) {
          for (final double occlusion in <double>[0, 0.3, 0.6, 0.9]) {
            for (final double sheen in <double>[0, 0.4, 1]) {
              for (final double lift in <double>[-1, 0, 1]) {
                final (int r, int g, int b) = _bytes(
                  palette.knob(
                    m,
                    tone,
                    light,
                    occlusion,
                    1,
                    sheen: sheen,
                    lift: lift,
                  ),
                );
                expect(
                  keeps(m, r, g, b),
                  isTrue,
                  reason:
                      '${m.name} at light $light, tone $tone, occlusion '
                      '$occlusion, sheen $sheen, lift $lift: ($r, $g, $b)',
                );
              }
            }
          }
        }
      }
      double last = -1;
      for (int i = 0; i <= 26; i++) {
        final (int r, int g, int b) = _bytes(
          palette.knob(m, 0, i * 0.05, 0, 1),
        );
        final double lightness = 0.2126 * r + 0.7152 * g + 0.0722 * b;
        expect(lightness, greaterThanOrEqualTo(last), reason: '${m.name} $i');
        last = lightness;
      }
    }
  });

  testWidgets('a band’s stain makes the arms’ chromatin no more than about '
      'an eighth darker', (WidgetTester tester) async {
    final ZoomInks inks = await _inks(tester);
    final ChromosomePalette palette = ChromosomePalette(
      inks,
      look: ChromosomeLookSpec.vivid,
    );
    int value(int colour) {
      final (int r, int g, int b) = _bytes(colour);
      return math.max(r, math.max(g, b));
    }

    for (int i = 6; i <= 20; i++) {
      final double light = i * 0.05;
      final int pale = value(
        palette.knob(
          ChromatinMaterial.body,
          ChromosomeStyle.tone(Stain.gneg),
          light,
          0,
          1,
        ),
      );
      final int deep = value(
        palette.knob(
          ChromatinMaterial.body,
          ChromosomeStyle.tone(Stain.gpos100),
          light,
          0,
          1,
        ),
      );
      expect(deep, lessThanOrEqualTo(pale), reason: 'light $light');
      expect(deep / pale, greaterThanOrEqualTo(0.87), reason: 'light $light');
    }
  });

  testWidgets('the vivid look’s centromere and telomeres are the home '
      'helix’s clay and honey, and its gene’s shadow the accent’s deep teal', (
    WidgetTester tester,
  ) async {
    final ZoomInks inks = await _inks(tester);
    final ChromosomeColors colours = ChromosomeColors.vivid;
    expect(colours.centromere.base, NucleotideColors.helix.thymine);
    expect(colours.telomere.base, NucleotideColors.helix.guanine);
    expect(colours.centromere.base, inks.centromere);
    expect(colours.telomere.base, inks.telomere);
    expect(colours.gene.shadow, inks.markDeep);
    expect(ChromosomeLookSpec.vivid.globules!.colours, same(colours));
    for (final ChromatinRamp ramp in <ChromatinRamp>[
      colours.body,
      colours.centromere,
      colours.telomere,
      colours.gene,
    ]) {
      // Each ramp climbs from its crevice to its specular.
      double lightness(Color c) => 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b;
      for (int i = 0; i + 1 < ramp.stops.length; i++) {
        expect(
          lightness(ramp.stops[i + 1]),
          greaterThan(lightness(ramp.stops[i])),
        );
      }
    }
  });

  testWidgets('turned, merged and thinned all the way, the vivid tube is the '
      'strip: the stone’s, vertex for vertex', (WidgetTester tester) async {
    final ZoomInks inks = await _inks(tester);
    for (final ProteinTarget t in <ProteinTarget>[
      TestCatalog.insulin,
      TestCatalog.sod1,
      TestCatalog.amylase,
      TestCatalog.dystrophin,
      TestCatalog.bySlug('uromodulin')!,
    ]) {
      final (ChromosomeScene scene, ZoomFrame frame) = _turning(
        _stage(t, ChromosomeLook.stone),
        inks,
        0.5,
      );
      final double target = ChromosomeScene.stripPixels / 2 * frame.pixel;
      ({Float32List positions, Int32List colours}) laid(ChromosomeLook look) {
        final ChromosomeTube tube = ChromosomeTube(_scene(t, look).form, inks);
        tube.paint(
          _Nowhere(),
          frame,
          turn: 1,
          merge: 1,
          thin: 1,
          strip: 1,
          target: target,
          under: 0.6,
        );
        return tube.laidVertices;
      }

      final ({Float32List positions, Int32List colours}) stone = laid(
        ChromosomeLook.stone,
      );
      final ({Float32List positions, Int32List colours}) vivid = laid(
        ChromosomeLook.vivid,
      );
      expect(vivid.colours, stone.colours, reason: t.slug);
      expect(vivid.positions.length, stone.positions.length, reason: t.slug);
      for (int i = 0; i < vivid.positions.length; i++) {
        expect(
          vivid.positions[i],
          closeTo(stone.positions[i], 1e-6 * scene.half),
          reason: '${t.slug}, $i',
        );
      }
    }
  });

  testWidgets('from a third of the way to the band on, the vivid chromosome '
      'draws what the stone one does, and is the strip', (
    WidgetTester tester,
  ) async {
    final ZoomInks inks = await _inks(tester);
    for (final ProteinTarget t in <ProteinTarget>[
      TestCatalog.insulin,
      TestCatalog.sod1,
      TestCatalog.amylase,
      TestCatalog.bySlug('uromodulin')!,
    ]) {
      final ZoomStage stone = _stage(t, ChromosomeLook.stone);
      final ZoomStage vivid = _stage(t, ChromosomeLook.vivid);
      for (final double s in <double>[0.35, 0.5, 0.7]) {
        final (ChromosomeScene a, ZoomFrame fa) = _turning(stone, inks, s);
        final (ChromosomeScene b, ZoomFrame fb) = _turning(vivid, inks, s);
        final Uint8List drawnA = await _raster(
          tester,
          _canvas,
          (Canvas c) => a.paint(c, fa),
        );
        final Uint8List drawnB = await _raster(
          tester,
          _canvas,
          (Canvas c) => b.paint(c, fb),
        );
        int most = 0;
        for (int i = 0; i < drawnA.length; i++) {
          most = math.max(most, (drawnA[i] - drawnB[i]).abs());
        }
        expect(most, lessThanOrEqualTo(1), reason: '${t.slug} at $s');
      }
      // And, at half way, the band's own strip under it, band for band.
      final ZoomDepth depth = vivid.depth;
      final LocusTrack track = vivid.subject.track;
      final double d =
          depth.depthOf(ZoomStop.chromosome) +
          0.5 * depth.travelOf(ZoomStop.chromosome.index);
      final Map<ZoomStop, (ZoomScene, ZoomFrame)> at =
          <ZoomStop, (ZoomScene, ZoomFrame)>{
            for (final (ZoomScene scene, ZoomFrame frame) in vivid.frames(
              d,
              _canvas,
              inks,
            ))
              scene.stop: (scene, frame),
          };
      final (ZoomScene chromosome, ZoomFrame turning) =
          at[ZoomStop.chromosome]!;
      final (ZoomScene band, ZoomFrame map) = at[ZoomStop.band]!;
      final Uint8List tube = await _raster(
        tester,
        _canvas,
        (Canvas c) => chromosome.paint(c, turning),
      );
      final Uint8List drawn = await _raster(
        tester,
        _canvas,
        (Canvas c) => band.paint(c, map),
      );
      final BandScene strip = band as BandScene;
      final double y = strip.stripY(map);
      final double ringFrom = strip.stripX(map, track.bandStart - 1.0);
      final double ringTo = strip.stripX(map, track.bandEnd + 1.0);
      int probed = 0;
      int most = 0;
      for (final CytoBand own in track.bands) {
        final double a = strip.stripX(map, own.start.toDouble());
        final double b = strip.stripX(map, own.end + 1.0);
        final double reach =
            (BandScene.strip / 2 * BandScene.thickness(own.stain) - 3)
                .floorToDouble();
        for (double x = a + 3; x <= b - 3; x += 4) {
          if (x < 4 ||
              x > _canvas.width - 4 ||
              (x > ringFrom - 26 && x < ringTo + 26)) {
            continue;
          }
          for (double dy = -reach; dy <= reach; dy += 2) {
            final int i =
                ((y + dy).round() * _canvas.width.toInt() + x.round()) * 4;
            for (int c = 0; c < 4; c++) {
              most = math.max(most, (tube[i + c] - drawn[i + c]).abs());
            }
            probed++;
          }
        }
      }
      expect(probed, greaterThan(20), reason: t.slug);
      expect(most, lessThanOrEqualTo(4), reason: t.slug);
    }
  });

  testWidgets('the chromosome at rest draws nothing outside its bounds, in '
      'either look', (WidgetTester tester) async {
    final ZoomInks inks = await _inks(tester);
    for (final ChromosomeLook look in ChromosomeLook.values) {
      for (final ProteinTarget t in <ProteinTarget>[
        TestCatalog.insulin,
        TestCatalog.sod1,
        TestCatalog.amylase,
        TestCatalog.bySlug('uromodulin')!,
      ]) {
        final ChromosomeArt art = ChromosomeArt(_scene(t, look).form, inks);
        final Rect bounds = art.bounds;
        // The bounds a third of the image's height, in its middle.
        final double k = 240 / bounds.height;
        final Size size = Size(
          (bounds.width * k * 3).ceilToDouble(),
          (bounds.height * k * 3).ceilToDouble(),
        );
        final ZoomFrame frame = ZoomFrame(
          view: ZoomView(
            stop: ZoomStop.chromosome,
            pixelsPerUnit: k,
            centre: bounds.center,
            progress: 0,
            isChild: false,
          ),
          size: size,
          opacity: 1,
          inks: inks,
          clock: 0,
        );
        final Uint8List pixels = await _raster(tester, size, (Canvas c) {
          frame.enter(c);
          art.paintRest(c, frame);
        });
        final Rect inside = Rect.fromCenter(
          center: size.center(Offset.zero),
          width: bounds.width * k + 2,
          height: bounds.height * k + 2,
        );
        int outside = 0;
        for (int y = 0; y < size.height; y++) {
          for (int x = 0; x < size.width; x++) {
            if (inside.contains(Offset(x + 0.5, y + 0.5))) {
              continue;
            }
            if (pixels[(y * size.width.toInt() + x) * 4 + 3] != 0) {
              outside++;
            }
          }
        }
        expect(outside, 0, reason: '${look.name}, ${t.slug}');
      }
    }
  });

  testWidgets('the vivid shadow is as soft at any magnification: its blur '
      'grows with the chromosome', (WidgetTester tester) async {
    final ZoomInks inks = await _inks(tester);
    final ChromosomeForm form = _scene(
      TestCatalog.bySlug('uromodulin')!,
      ChromosomeLook.vivid,
    ).form;
    final ChromosomeArt art = ChromosomeArt(form, inks);
    final Rect bounds = art.bounds;
    // Below the lower end, where only the shadow falls: the alpha there at
    // the same points of the scene, drawn at two magnifications.
    final List<Offset> probes = <Offset>[
      for (final double down in <double>[0.55, 0.75, 0.95])
        Offset(
          form.centreAt(1, form.bottom) + 0.12 * form.half,
          form.bottom + down * form.half,
        ),
    ];
    Future<List<int>> alphas(double k) async {
      final Size size = Size(
        (bounds.width * k).ceilToDouble(),
        (bounds.height * k).ceilToDouble(),
      );
      final ZoomFrame frame = ZoomFrame(
        view: ZoomView(
          stop: ZoomStop.chromosome,
          pixelsPerUnit: k,
          centre: bounds.center,
          progress: 0,
          isChild: false,
        ),
        size: size,
        opacity: 1,
        inks: inks,
        clock: 0,
      );
      final Uint8List pixels = await _raster(tester, size, (Canvas c) {
        frame.enter(c);
        art.paintRest(c, frame);
      });
      return <int>[
        for (final Offset p in probes)
          if (frame.toScreen(p) case final Offset at)
            pixels[(at.dy.floor() * size.width.toInt() + at.dx.floor()) * 4 +
                3],
      ];
    }

    final double k = 300 / bounds.height;
    final List<int> near = await alphas(k);
    final List<int> close = await alphas(2 * k);
    expect(near.first, greaterThan(8), reason: 'a shadow there at all');
    for (int i = 0; i < near.length; i++) {
      expect(close[i], closeTo(near[i], 6), reason: 'probe $i');
    }
  });

  testWidgets('nothing is drawn round the vivid chromosome but its blurred '
      'shadow, in the shadow’s ink', (WidgetTester tester) async {
    final ZoomInks inks = await _inks(tester);
    final Color shadow = inks.shadow;
    for (final ProteinTarget t in TestCatalog.all) {
      final ZoomStage stage = _stage(t, ChromosomeLook.vivid);
      int shadows = 0;
      for (final (ZoomScene shown, ZoomFrame frame) in stage.frames(
        stage.depth.depthOf(ZoomStop.chromosome),
        _canvas,
        inks,
      )) {
        if (shown is! ChromosomeScene) {
          continue;
        }
        final _Paths canvas = _Paths();
        ChromosomeArt(shown.form, inks).paintRest(canvas, frame);
        for (final Paint paint in canvas.paints) {
          expect(paint.shader, isNull, reason: t.slug);
          expect(paint.maskFilter, isNotNull, reason: t.slug);
          expect(paint.color.r, closeTo(shadow.r, 1e-6), reason: t.slug);
          expect(paint.color.g, closeTo(shadow.g, 1e-6), reason: t.slug);
          expect(paint.color.b, closeTo(shadow.b, 1e-6), reason: t.slug);
          shadows++;
        }
      }
      expect(shadows, 2, reason: '${t.slug}: one shadow under each sister');
    }
  });

  testWidgets('no vivid mesh holds more vertices than its indices reach, and '
      'the tube is the stone’s size', (WidgetTester tester) async {
    final ZoomInks inks = await _inks(tester);
    for (final ProteinTarget t in TestCatalog.all) {
      final ChromosomeScene scene = _scene(t, ChromosomeLook.vivid);
      for (final ({Float32List positions, Int32List colours}) mesh
          in ChromosomeArt(scene.form, inks).meshData) {
        expect(mesh.colours.length, lessThanOrEqualTo(65000), reason: t.slug);
        expect(mesh.positions.length, mesh.colours.length * 2);
      }
      expect(
        ChromosomeTube(scene.form, inks).vertexCount,
        ChromosomeTube(_scene(t, ChromosomeLook.stone).form, inks).vertexCount,
        reason: t.slug,
      );
    }
  });

  test('a vivid chromatid narrows toward its centromere and its rounded ends '
      'and nowhere else, a stalk as thick as its arm', () {
    // The most it widens on the way from [from] to [to].
    double widening(ChromosomeForm form, double from, double to) {
      const int steps = 4000;
      double last = form.widthAt(from);
      double most = 0;
      for (int i = 1; i <= steps; i++) {
        final double w = form.widthAt(from + (to - from) * i / steps);
        most = math.max(most, w - last);
        last = w;
      }
      return most;
    }

    for (final ProteinTarget t in TestCatalog.all) {
      final ChromosomeForm form = _vivid(t);
      final double ends = form.look.endRound * form.half;
      expect(
        widening(form, form.top + ends, form.centromere),
        lessThan(1e-12),
        reason: '${t.slug}: the short arm',
      );
      expect(
        widening(form, form.bottom - ends, form.centromere),
        lessThan(1e-12),
        reason: '${t.slug}: the long arm',
      );
      for (final CytoBand band in locusOf(t).bands) {
        if (band.stain == Stain.stalk) {
          final double y = (form.yOf(band.start) + form.yOf(band.end + 1)) / 2;
          expect(
            form.widthAt(y),
            greaterThan(form.half * 0.9),
            reason: '${t.slug}: ${band.name}',
          );
        }
      }
    }
  });

  test('no vivid knob crosses into the cleft down the arms, and none reaches '
      'across the waist by more than a hair', () {
    for (final ProteinTarget t in TestCatalog.all) {
      final ChromosomeForm form = _vivid(t);
      final ChromosomeGlobules globules = form.look.globules!;
      for (final double side in <double>[-1, 1]) {
        final KnobField knobs = form.knobs(side);
        for (int k = 0; k < knobs.length; k++) {
          final double y = knobs.y[k];
          final double x =
              form.centreAt(side, y) +
              globules.surface * form.widthAt(y) * math.sin(knobs.phi[k]);
          expect(
            side * (x - form.bend(y)) - knobs.radius[k],
            // To the float a knob's radius is kept in.
            greaterThanOrEqualTo(
              form.keepOff(y) * form.half - 1e-6 * form.half,
            ),
            reason: '${t.slug}, side $side, knob $k',
          );
        }
      }
      // Down the arms the cleft is kept; at the waist the sisters meet.
      expect(form.keepOff(form.top), closeTo(globules.cleftGap, 1e-3));
      expect(form.keepOff(form.centromere), closeTo(-0.05, 1e-12));
    }
  });
}
