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

ChromosomeScene _scene(ProteinTarget t) => ChromosomeScene(_subject(t));

ZoomStage _stage(ProteinTarget t) => ZoomStage(_subject(t));

/// [t]'s chromosome as a form, freshly built.
ChromosomeForm _form(ProteinTarget t) => ChromosomeForm(
  locusOf(t),
  half: _scene(t).half,
  look: ChromosomeLookSpec.zoom,
);

/// A colour's channels as bytes.
(int, int, int) _bytes(int colour) =>
    (colour >> 16 & 255, colour >> 8 & 255, colour & 255);

/// [colour] in CIELAB's polar form, under D65: its lightness, its chroma
/// and its hue in degrees.
({double lightness, double chroma, double hue}) _lch(Color colour) {
  double linear(double c) =>
      c <= 0.04045 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();
  double f(double t) =>
      t > 0.008856 ? math.pow(t, 1 / 3).toDouble() : 7.787 * t + 16 / 116;
  final double r = linear(colour.r);
  final double g = linear(colour.g);
  final double b = linear(colour.b);
  final double fx = f((0.4124 * r + 0.3576 * g + 0.1805 * b) / 0.95047);
  final double fy = f(0.2126 * r + 0.7152 * g + 0.0722 * b);
  final double fz = f((0.0193 * r + 0.1192 * g + 0.9505 * b) / 1.08883);
  final double a = 500 * (fx - fy);
  final double bb = 200 * (fy - fz);
  return (
    lightness: 116 * fy - 16,
    chroma: math.sqrt(a * a + bb * bb),
    hue: (math.atan2(bb, a) * 180 / math.pi) % 360,
  );
}

/// [colour]'s chroma in CIELAB, under D65.
double _chroma(Color colour) => _lch(colour).chroma;

/// The middle of [values], sorted in place.
double _median(List<double> values) {
  values.sort();
  return values[values.length ~/ 2];
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

/// A canvas that draws nothing, and keeps the paint of every path drawn on
/// it.
class _Paths implements Canvas {
  final List<Paint> paints = <Paint>[];

  @override
  void drawPath(Path path, Paint paint) => paints.add(paint);

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

/// A canvas that draws nothing, and keeps every paint it is drawn with,
/// with how many ovals and circles were drawn and the paints of the
/// circles.
class _Drawn implements Canvas {
  final List<Paint> paints = <Paint>[];
  final List<Paint> circles = <Paint>[];
  int ovals = 0;

  @override
  void drawPath(Path path, Paint paint) => paints.add(paint);

  @override
  void drawVertices(ui.Vertices vertices, BlendMode mode, Paint paint) =>
      paints.add(paint);

  @override
  void drawOval(Rect rect, Paint paint) {
    ovals++;
    paints.add(paint);
  }

  @override
  void drawCircle(Offset c, double radius, Paint paint) {
    circles.add(paint);
    paints.add(paint);
  }

  @override
  void drawRect(Rect rect, Paint paint) => paints.add(paint);

  @override
  void drawRRect(RRect rrect, Paint paint) => paints.add(paint);

  @override
  void saveLayer(Rect? bounds, Paint paint) => paints.add(paint);

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  test('every knob’s material is picked the same every time, and proteins '
      'on one chromosome share their knobs', () {
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
      final ChromosomeForm form = _form(t);
      expect(shape(form), shape(_form(t)), reason: t.slug);
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
        shape(_form(same.last)),
        shape(_form(same.first)),
        reason: same.last.slug,
      );
    }
  });

  testWidgets('the centromere’s chromatin lies only about it, the telomeres’ '
      'only at the ends and the gene’s band’s only in its band, all round '
      'both sisters, and every chromosome shows all four, mostly the arms’', (
    WidgetTester tester,
  ) async {
    final ZoomInks inks = await _inks(tester);
    final ChromosomeLookSpec look = ChromosomeLookSpec.zoom;
    final ChromosomeGlobules globules = look.globules;
    for (final ProteinTarget t in TestCatalog.all) {
      final ChromosomeForm form = _scene(t).form;
      final ChromosomeArt art = ChromosomeArt(form, inks);
      // How far a knob is drawn from where its material was picked: the
      // bow of the band's edges.
      final double bow = look.bow * form.half;
      final (double bandTop, double bandBottom) = form.marked;
      final Map<ChromatinMaterial, int> seen = <ChromatinMaterial, int>{};
      for (final double side in <double>[-1, 1]) {
        int band = 0;
        for (final ({
              Offset at,
              double along,
              double radius,
              ChromatinMaterial material,
            })
            g
            in art.globulesOf(side)) {
          seen.update(g.material, (int n) => n + 1, ifAbsent: () => 1);
          final String where = '${t.slug}, ${g.material.name} at ${g.at}';
          // Where the band is whole, no jitter takes a globule out of it.
          if (form.geneAt(g.along) - globules.pickJitter > globules.geneAt) {
            expect(g.material, ChromatinMaterial.gene, reason: where);
          }
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
              band++;
              // In the marked band, or within its edges' softening of it.
              expect(
                g.along,
                inInclusiveRange(
                  bandTop - look.feather * form.half,
                  bandBottom + look.feather * form.half,
                ),
                reason: where,
              );
            case ChromatinMaterial.body:
              break;
          }
        }
        expect(band, greaterThan(0), reason: '${t.slug}: side $side');
      }
      for (final ChromatinMaterial m in ChromatinMaterial.values) {
        expect(seen[m] ?? 0, greaterThan(0), reason: '${t.slug}: ${m.name}');
      }
      expect(
        seen[ChromatinMaterial.body],
        greaterThan(seen.values.reduce((int a, int b) => a + b) ~/ 2),
        reason: '${t.slug}: mostly the arms’',
      );
    }
  });

  testWidgets('each material keeps its hue from its crevice to its sheen, and '
      'grows lighter with the light', (WidgetTester tester) async {
    final ZoomInks inks = await _inks(tester);
    final ChromosomePalette palette = ChromosomePalette(
      inks,
      look: ChromosomeLookSpec.zoom,
    );
    bool keeps(ChromatinMaterial m, int r, int g, int b, double sheen) =>
        switch (m) {
          // A warm stone, near neutral: never more than a little colour,
          // and warm wherever no sheen of the bright ink lies on it.
          ChromatinMaterial.body =>
            _chroma(Color.fromARGB(255, r, g, b)) <= 8.5 &&
                (sheen > 0 || r >= b),
          // Clay: red over both.
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
                  keeps(m, r, g, b, sheen),
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
      look: ChromosomeLookSpec.zoom,
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
          ChromosomeLookSpec.tone(Stain.gneg),
          light,
          0,
          1,
        ),
      );
      final int deep = value(
        palette.knob(
          ChromatinMaterial.body,
          ChromosomeLookSpec.tone(Stain.gpos100),
          light,
          0,
          1,
        ),
      );
      expect(deep, lessThanOrEqualTo(pale), reason: 'light $light');
      expect(deep / pale, greaterThanOrEqualTo(0.87), reason: 'light $light');
    }
  });

  testWidgets('the chromosome’s colours are the app’s own: its arms the '
      'organs’ lit stone warmed toward the home helix’s honey, its neck half '
      'way to the helix’s clay and its caps over a third of the way to its '
      'honey, its '
      'gene’s band the organs’ home tone, shaded toward the accent’s deep and '
      'lit toward the accent, and every ramp climbs from its crevice to its '
      'specular', (WidgetTester tester) async {
    final ZoomInks inks = await _inks(tester);
    final ChromosomeColors colours = ChromosomeColors.zoom;
    // Where an organ's cell lives (`homeOf` in each organ's art).
    final Color home = Color.alphaBlend(inks.glow(0.42), inks.lit(0.2));
    expect(
      colours.body.base,
      Color.lerp(inks.lit(0.38), inks.bases.guanine, 0.12),
    );
    expect(
      colours.centromere.base,
      Color.lerp(colours.body.base, NucleotideColors.helix.thymine, 0.5),
    );
    expect(
      colours.telomere.base,
      Color.lerp(colours.body.base, NucleotideColors.helix.guanine, 0.38),
    );
    expect(colours.gene.base, home);
    expect(colours.gene.shadow, Color.lerp(inks.markDeep, home, 0.45));
    expect(colours.gene.highlight, Color.lerp(home, inks.mark, 0.4));
    expect(ChromosomeLookSpec.zoom.globules.colours, same(colours));
    for (final ChromatinRamp ramp in <ChromatinRamp>[
      colours.body,
      colours.centromere,
      colours.telomere,
      colours.gene,
    ]) {
      double lightness(Color c) => 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b;
      for (int i = 0; i + 1 < ramp.stops.length; i++) {
        expect(
          lightness(ramp.stops[i + 1]),
          greaterThan(lightness(ramp.stops[i])),
        );
      }
    }
  });

  testWidgets('the chromosome is as quiet as the organs beside its gene’s '
      'band: its arms near neutral, its neck and caps clear of them, and '
      'nothing on it more than half as saturated as the mark but the band '
      'where it is lit, the band the most saturated of all', (
    WidgetTester tester,
  ) async {
    final ZoomInks inks = await _inks(tester);
    final ChromosomeColors colours = ChromosomeColors.zoom;
    final double mark = _chroma(inks.mark);
    final double band = _chroma(colours.gene.base);
    for (final (String name, ChromatinRamp ramp, double most)
        in <(String, ChromatinRamp, double)>[
          ('arms', colours.body, 8),
          ('centromere', colours.centromere, mark / 2),
          ('telomeres', colours.telomere, mark / 2),
          ('band', colours.gene, mark / 2),
        ]) {
      for (final Color stop in ramp.stops) {
        if (stop == colours.gene.highlight) {
          continue;
        }
        expect(_chroma(stop), lessThanOrEqualTo(most), reason: name);
      }
    }
    for (final Color stop in <Color>[
      ...colours.body.stops,
      ...colours.centromere.stops,
      ...colours.telomere.stops,
    ]) {
      expect(_chroma(stop), lessThan(band));
    }
    for (final Color stop in colours.body.stops) {
      expect(_chroma(stop), lessThanOrEqualTo(band / 2.5));
    }
    // The neck and the caps stand clear of the arms in their own colour.
    for (final ChromatinRamp ends in <ChromatinRamp>[
      colours.centromere,
      colours.telomere,
    ]) {
      expect(
        _chroma(ends.base),
        greaterThanOrEqualTo(3 * _chroma(colours.body.base)),
      );
    }
  });

  testWidgets('nothing glows on the gene: at rest and as the chromosome is '
      'reached, it is drawn with no spot and nothing added to the light '
      'under it, its place only pinged with a ring', (
    WidgetTester tester,
  ) async {
    final ZoomInks inks = await _inks(tester);
    for (final ProteinTarget t in <ProteinTarget>[
      TestCatalog.insulin,
      TestCatalog.myoglobin,
      TestCatalog.bySlug('uromodulin')!,
    ]) {
      final ZoomStage stage = _stage(t);
      final double depth = stage.depth.depthOf(ZoomStop.chromosome);
      for (final (ZoomScene shown, ZoomFrame frame) in stage.frames(
        depth,
        _canvas,
        inks,
      )) {
        if (shown is! ChromosomeScene) {
          continue;
        }
        final _Drawn rest = _Drawn();
        shown.paint(rest, frame);
        expect(rest.ovals, 0, reason: '${t.slug}: a spot at rest');
        expect(rest.circles, isEmpty, reason: '${t.slug}: a spot at rest');
        for (final Paint paint in rest.paints) {
          expect(paint.blendMode, isNot(BlendMode.plus), reason: t.slug);
        }
        int rings = 0;
        for (double dwell = 0; dwell <= 1.4; dwell += 0.05) {
          final _Drawn arriving = _Drawn();
          shown.paintAmbient(
            arriving,
            ZoomFrame(
              view: frame.view,
              size: frame.size,
              opacity: frame.opacity,
              inks: inks,
              clock: dwell,
              dwell: dwell,
            ),
          );
          expect(arriving.ovals, 0, reason: '${t.slug}: a glow at $dwell');
          for (final Paint paint in arriving.circles) {
            expect(paint.style, PaintingStyle.stroke, reason: t.slug);
            expect(paint.shader, isNull, reason: t.slug);
            rings++;
          }
        }
        expect(rings, greaterThan(0), reason: '${t.slug}: never pinged');
      }
    }
  });

  testWidgets('half way to the band the chromosome is the strip, band for '
      'band', (WidgetTester tester) async {
    final ZoomInks inks = await _inks(tester);
    for (final ProteinTarget t in <ProteinTarget>[
      TestCatalog.insulin,
      TestCatalog.sod1,
      TestCatalog.amylase,
      TestCatalog.bySlug('uromodulin')!,
    ]) {
      final ZoomStage stage = _stage(t);
      final ZoomDepth depth = stage.depth;
      final LocusTrack track = stage.subject.track;
      final double d =
          depth.depthOf(ZoomStop.chromosome) +
          0.5 * depth.travelOf(ZoomStop.chromosome.index);
      final Map<ZoomStop, (ZoomScene, ZoomFrame)> at =
          <ZoomStop, (ZoomScene, ZoomFrame)>{
            for (final (ZoomScene scene, ZoomFrame frame) in stage.frames(
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

  testWidgets('the chromosome at rest draws nothing outside its bounds', (
    WidgetTester tester,
  ) async {
    final ZoomInks inks = await _inks(tester);
    for (final ProteinTarget t in <ProteinTarget>[
      TestCatalog.insulin,
      TestCatalog.sod1,
      TestCatalog.amylase,
      TestCatalog.bySlug('uromodulin')!,
    ]) {
      final ChromosomeArt art = ChromosomeArt(_scene(t).form, inks);
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
      expect(outside, 0, reason: t.slug);
    }
  });

  testWidgets('at rest the chromosome is as quiet as the organs but for its '
      'gene’s band, which is in the mark all round both sisters', (
    WidgetTester tester,
  ) async {
    final ZoomInks inks = await _inks(tester);
    for (final ProteinTarget t in <ProteinTarget>[
      TestCatalog.insulin,
      TestCatalog.leptin,
      TestCatalog.p53,
      TestCatalog.bySlug('uromodulin')!,
    ]) {
      final ChromosomeForm form = _scene(t).form;
      final ChromosomeArt art = ChromosomeArt(form, inks);
      final Rect bounds = art.bounds;
      final double k = 600 / bounds.height;
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
        c.drawRect(Offset.zero & size, Paint()..color = inks.ground);
        frame.enter(c);
        art.paintRest(c, frame);
      });
      final ChromosomeLookSpec look = form.look;
      final (double a, double b) = form.marked;
      // How far from its row a globule of the band may be drawn: its edge's
      // softening, the bow of the ring it lies on, and its own radius.
      final double reach =
          (look.feather + look.bow + look.lobe + look.lobeSpread) * form.half;
      final double outsideTop = frame.toScreen(Offset(0, a - reach)).dy;
      final double outsideBottom = frame.toScreen(Offset(0, b + reach)).dy;
      final double insideTop = frame
          .toScreen(Offset(0, a + look.feather * form.half))
          .dy;
      final double insideBottom = frame
          .toScreen(Offset(0, b - look.feather * form.half))
          .dy;
      final List<double> quiet = <double>[];
      final List<double> hues = <double>[];
      int inside = 0;
      for (int y = 0; y < size.height; y++) {
        final bool out = y < outsideTop || y > outsideBottom;
        final bool core = y >= insideTop && y <= insideBottom;
        if (!out && !core) {
          continue;
        }
        for (int x = 0; x < size.width; x++) {
          final int i = (y * size.width.toInt() + x) * 4;
          final ({double lightness, double chroma, double hue}) c = _lch(
            Color.fromARGB(255, pixels[i], pixels[i + 1], pixels[i + 2]),
          );
          // The chromatin, not the ground or the shadow on it.
          if (c.lightness < 14) {
            continue;
          }
          if (out) {
            quiet.add(c.chroma);
          } else {
            inside++;
            if (c.chroma > 8) {
              hues.add(c.hue);
            }
          }
        }
      }
      expect(quiet.length, greaterThan(1000), reason: t.slug);
      expect(_median(quiet), lessThanOrEqualTo(6), reason: t.slug);
      expect(hues.length, greaterThan(inside * 0.6), reason: t.slug);
      expect(_median(hues), inInclusiveRange(170, 190), reason: t.slug);
    }
  });

  testWidgets('the shadow is as soft at any magnification: its blur grows '
      'with the chromosome', (WidgetTester tester) async {
    final ZoomInks inks = await _inks(tester);
    final ChromosomeForm form = _scene(TestCatalog.bySlug('uromodulin')!).form;
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

  testWidgets('nothing is drawn round the chromosome but its blurred shadow, '
      'in the shadow’s ink', (WidgetTester tester) async {
    final ZoomInks inks = await _inks(tester);
    final Color shadow = inks.shadow;
    for (final ProteinTarget t in TestCatalog.all) {
      final ZoomStage stage = _stage(t);
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

  testWidgets('no mesh holds more vertices than its indices reach, the '
      'tube’s neither', (WidgetTester tester) async {
    final ZoomInks inks = await _inks(tester);
    for (final ProteinTarget t in TestCatalog.all) {
      final ChromosomeScene scene = _scene(t);
      for (final ({Float32List positions, Int32List colours}) mesh
          in ChromosomeArt(scene.form, inks).meshData) {
        expect(mesh.colours.length, lessThanOrEqualTo(65000), reason: t.slug);
        expect(mesh.positions.length, mesh.colours.length * 2);
      }
      expect(
        ChromosomeTube(scene.form, inks).vertexCount,
        lessThanOrEqualTo(65000),
        reason: t.slug,
      );
    }
  });

  test('no knob crosses into the cleft down the arms, and none reaches '
      'across the waist by more than a hair', () {
    for (final ProteinTarget t in TestCatalog.all) {
      final ChromosomeForm form = _form(t);
      final ChromosomeGlobules globules = form.look.globules;
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
