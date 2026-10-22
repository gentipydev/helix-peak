import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/core/catalog/protein_target.dart';
import 'package:helixpeek/core/theme/app_theme.dart';
import 'package:helixpeek/features/zoom/domain/locus_track.dart';
import 'package:helixpeek/features/zoom/domain/zoom_depth.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/chromosome/chromosome_art.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/chromosome/chromosome_form.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/chromosome/chromosome_shading.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/chromosome/chromosome_style.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/chromosome/chromosome_tube.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/chromosome_scene.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/specimen_light.dart';
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

ZoomStage _stage(ProteinTarget t) =>
    ZoomStage(ZoomSubject(track: locusOf(t), record: recordOf(t)));

/// A vertex colour's channels, from 0 to 1.
(double, double, double) _channels(int colour) => (
  (colour >> 16 & 255) / 255,
  (colour >> 8 & 255) / 255,
  (colour & 255) / 255,
);

/// How far a colour leans to the mark, a teal: green over red where blue
/// is below green, else green over the other two. Every neutral of the
/// app's, and every mix of them, comes out at about nothing or below.
double _tealness(int colour) {
  final (double r, double g, double b) = _channels(colour);
  return b < g ? g - r : 2 * g - r - b;
}

/// Where along the chromosome the gene's band's wash may reach: the band,
/// its edges' softening, and the widest a lobe of it is drawn.
(double, double) _geneReach(ChromosomeForm form) {
  final LocusTrack track = form.track;
  final double reach =
      ChromosomeStyle.feather * form.half +
      (ChromosomeStyle.lobe + ChromosomeStyle.lobeSpread) *
          form.half *
          ChromosomeStyle.skirtOuter;
  return (
    form.yOf(track.bandStart) - reach,
    form.yOf(track.bandEnd + 1) + reach,
  );
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

/// The palest chromatin: the lit outline, warmed as the chromatin is.
Color _palest(ZoomInks inks) => Color.lerp(
  inks.lit(ChromosomeStyle.paleLit),
  inks.bases.guanine,
  ChromosomeStyle.warmth,
)!;

/// A colour's lightness, as its channels weigh: enough to tell which of two
/// mixes of the same inks is the lighter.
double _lightness(double r, double g, double b) =>
    0.2126 * r + 0.7152 * g + 0.0722 * b;

void main() {
  testWidgets('the bands’ tones run from the palest to the deepest, gvar '
      'among them', (WidgetTester tester) async {
    final ZoomInks inks = await _inks(tester);
    final ChromosomePalette palette = ChromosomePalette(inks);
    double lightness(Stain stain) {
      final (double r, double g, double b) = palette.mix(
        ChromosomeStyle.tone(stain),
        1,
        0,
        0,
      );
      return 0.2126 * r + 0.7152 * g + 0.0722 * b;
    }

    final List<double> ladder = <double>[
      for (final Stain stain in <Stain>[
        Stain.gneg,
        Stain.gpos25,
        Stain.gpos50,
        Stain.gpos75,
        Stain.gpos100,
      ])
        lightness(stain),
    ];
    for (int i = 0; i + 1 < ladder.length; i++) {
      expect(ladder[i], greaterThan(ladder[i + 1]), reason: 'step $i');
    }
    expect(lightness(Stain.gvar), inExclusiveRange(ladder.last, ladder.first));
  });

  testWidgets('every band’s tone is a warm stone, never a cool grey', (
    WidgetTester tester,
  ) async {
    final ZoomInks inks = await _inks(tester);
    final ChromosomePalette palette = ChromosomePalette(inks);
    for (final Stain stain in Stain.values) {
      final (double r, double g, double b) = palette.mix(
        ChromosomeStyle.tone(stain),
        1,
        0,
        0,
      );
      expect(r, greaterThanOrEqualTo(g), reason: stain.name);
      expect(g, greaterThanOrEqualTo(b), reason: stain.name);
      expect(r - b, greaterThan(0.02), reason: stain.name);
    }
  });

  testWidgets('the mark shows only in the gene’s band, at rest and on the '
      'way into the map', (WidgetTester tester) async {
    final ZoomInks inks = await _inks(tester);
    for (final ProteinTarget t in TestCatalog.all) {
      final ChromosomeScene scene = ChromosomeScene(
        ZoomSubject(track: locusOf(t), record: recordOf(t)),
      );
      final ChromosomeForm form = scene.form;
      final (double from, double to) = _geneReach(form);
      void hold(
        List<({Float32List positions, Int32List colours})> meshes,
        String what,
      ) {
        int teal = 0;
        double elsewhere = -1;
        for (final ({Float32List positions, Int32List colours}) mesh
            in meshes) {
          for (int i = 0; i < mesh.colours.length; i++) {
            final double lean = _tealness(mesh.colours[i]);
            final double y = mesh.positions[i * 2 + 1];
            if (y >= from && y <= to) {
              if (lean > 0.01) {
                teal++;
              }
            } else {
              elsewhere = math.max(elsewhere, lean);
            }
          }
        }
        expect(elsewhere, lessThanOrEqualTo(0.01), reason: '${t.slug}, $what');
        expect(teal, greaterThan(0), reason: '${t.slug}, $what');
      }

      hold(ChromosomeArt(form, inks).meshData, 'at rest');
      // On the way into the map, while the wash still shows.
      final ZoomStage stage = _stage(t);
      final ZoomDepth depth = stage.depth;
      for (final double s in <double>[0.02, 0.1, 0.2]) {
        for (final (ZoomScene shown, ZoomFrame frame) in stage.frames(
          depth.depthOf(ZoomStop.chromosome) +
              s * depth.travelOf(ZoomStop.chromosome.index),
          _canvas,
          inks,
        )) {
          if (shown is ChromosomeScene) {
            shown.paint(_Nowhere(), frame);
            final ChromosomeTube tube = shown.tubeIn(inks);
            hold(<({Float32List positions, Int32List colours})>[
              tube.laidVertices,
            ], 'turning, $s');
          }
        }
      }
    }
  });

  testWidgets('the centromere and the telomeres are tinted in their own '
      'inks, and nothing else is', (WidgetTester tester) async {
    final ZoomInks inks = await _inks(tester);
    // The same inks with the centromere's and the telomeres' as the palest
    // chromatin: where the two draw differently is where the tints are.
    final Color pale = _palest(inks);
    final ZoomInks plain = ZoomInks(
      ground: inks.ground,
      raised: inks.raised,
      overlay: inks.overlay,
      high: inks.high,
      outline: inks.outline,
      text: inks.text,
      label: inks.label,
      mark: inks.mark,
      markDeep: inks.markDeep,
      shadow: inks.shadow,
      blood: inks.blood,
      centromere: pale,
      telomere: pale,
      bases: inks.bases,
      cds: inks.cds,
      utr: inks.utr,
      intron: inks.intron,
    );
    for (final ProteinTarget t in TestCatalog.all) {
      final ChromosomeForm form = ChromosomeScene(
        ZoomSubject(track: locusOf(t), record: recordOf(t)),
      ).form;
      // How far past a tint's reach a lobe of it may be drawn.
      final double lobe =
          (ChromosomeStyle.lobe + ChromosomeStyle.lobeSpread) *
          form.half *
          ChromosomeStyle.skirtOuter;
      final double centromere =
          ChromosomeStyle.centromereReach * form.half + lobe;
      final double telomere = ChromosomeStyle.telomereReach * form.half + lobe;
      final List<({Float32List positions, Int32List colours})> tinted =
          ChromosomeArt(form, inks).meshData;
      final List<({Float32List positions, Int32List colours})> untinted =
          ChromosomeArt(form, plain).meshData;
      expect(tinted.length, untinted.length, reason: t.slug);
      int atCentromere = 0;
      int atEnds = 0;
      double clay = 0;
      double honey = 0;
      for (int m = 0; m < tinted.length; m++) {
        expect(tinted[m].positions, untinted[m].positions, reason: t.slug);
        final Int32List a = tinted[m].colours;
        final Int32List b = untinted[m].colours;
        for (int i = 0; i < a.length; i++) {
          if (a[i] == b[i]) {
            continue;
          }
          final double y = tinted[m].positions[i * 2 + 1];
          final bool nearCentromere = (y - form.centromere).abs() <= centromere;
          final bool nearEnd =
              math.min(y - form.top, form.bottom - y) <= telomere;
          expect(nearCentromere || nearEnd, isTrue, reason: '${t.slug} at $y');
          final (double r, double g, double bl) = _channels(a[i]);
          final (double r0, double g0, double b0) = _channels(b[i]);
          // Clay is redder than it is green; honey greener than it is blue.
          if (nearCentromere && !nearEnd) {
            atCentromere++;
            clay += (r - g) - (r0 - g0);
          }
          if (nearEnd && !nearCentromere) {
            atEnds++;
            honey += (g - bl) - (g0 - b0);
          }
        }
      }
      expect(atCentromere, greaterThan(0), reason: t.slug);
      expect(atEnds, greaterThan(0), reason: t.slug);
      expect(clay, greaterThan(0), reason: t.slug);
      expect(honey, greaterThan(0), reason: t.slug);
    }
  });

  testWidgets('the chromatin is lit and mixed as the organs’ specimens are, '
      'under their lamp', (WidgetTester tester) async {
    final ZoomInks inks = await _inks(tester);
    final ChromosomeLight light = ChromosomeLight();
    final SpecimenLight lamp = SpecimenLight(SpecimenLamp.zoom);
    final ChromosomePalette palette = ChromosomePalette(inks);
    final SpecimenPalette specimen = SpecimenPalette(inks);
    final math.Random random = math.Random(29);
    for (int i = 0; i < 400; i++) {
      final SurfaceNormal n = SurfaceNormal(
        2 * random.nextDouble() - 1,
        2 * random.nextDouble() - 1,
        random.nextDouble(),
      );
      final double facing = random.nextDouble();
      final double lit = light.light(n.x, n.y, n.z, facing: facing);
      final double sheen = light.sheen(n.x, n.y, n.z);
      expect(lit, closeTo(lamp.light(n.x, n.y, n.z, form: facing), 1e-12));
      expect(
        sheen,
        closeTo(ChromosomeStyle.sheen * lamp.sheen(n.x, n.y, n.z), 1e-12),
      );
      final double tone = random.nextDouble();
      final double occlusion = ChromosomeStyle.occlusion * random.nextDouble();
      final double gene = random.nextDouble();
      final (double r, double g, double b) = palette.mix(
        tone,
        lit,
        occlusion,
        gene,
        sheen: sheen,
      );
      final Color albedo = Color.lerp(
        Color.lerp(
          inks.lit(ChromosomeStyle.paleLit),
          inks.shade(ChromosomeStyle.deepShade),
          tone,
        )!,
        inks.bases.guanine,
        ChromosomeStyle.warmth,
      )!;
      final (double er, double eg, double eb) = _channels(
        specimen.colour(
          SpecimenTone(albedo, inks.shadow),
          lit,
          occlusion: occlusion,
          sheen: sheen,
          wash: ChromosomeStyle.wash * gene,
        ),
      );
      expect(r, closeTo(er, 1 / 255), reason: 'red, $i');
      expect(g, closeTo(eg, 1 / 255), reason: 'green, $i');
      expect(b, closeTo(eb, 1 / 255), reason: 'blue, $i');
    }
  });

  testWidgets('nothing is drawn round the chromosome but its shadow and its '
      'groove, in the shadow’s ink', (WidgetTester tester) async {
    final ZoomInks inks = await _inks(tester);
    final Color shadow = inks.shadow;
    for (final ProteinTarget t in TestCatalog.all) {
      final ZoomStage stage = _stage(t);
      int checked = 0;
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
          // The groove's shade is a gradient of the shadow's ink.
          if (paint.shader == null) {
            expect(paint.color.r, closeTo(shadow.r, 1e-6), reason: t.slug);
            expect(paint.color.g, closeTo(shadow.g, 1e-6), reason: t.slug);
            expect(paint.color.b, closeTo(shadow.b, 1e-6), reason: t.slug);
          }
          checked++;
        }
      }
      expect(checked, greaterThan(0), reason: t.slug);
    }
  });

  testWidgets('no surface is lit past its own tone but by its sheen', (
    WidgetTester tester,
  ) async {
    final ZoomInks inks = await _inks(tester);
    // The lightest the chromatin may be: its palest stain, tinted or washed
    // as far as anything is, in full light and at the most it shines.
    final Color pale = _palest(inks);
    final double most = ChromosomeStyle.sheen * SpecimenLamp.zoom.sheen;
    double bound = 0;
    for (final Color albedo in <Color>[
      pale,
      Color.lerp(pale, inks.telomere, ChromosomeStyle.telomereTint)!,
      Color.lerp(pale, inks.centromere, ChromosomeStyle.kinetochoreTint)!,
    ]) {
      final Color washed = Color.lerp(albedo, inks.mark, ChromosomeStyle.wash)!;
      final Color shone = Color.lerp(washed, inks.text, most)!;
      bound = math.max(bound, _lightness(shone.r, shone.g, shone.b));
    }
    for (final ProteinTarget t in TestCatalog.all) {
      final ChromosomeForm form = ChromosomeScene(
        ZoomSubject(track: locusOf(t), record: recordOf(t)),
      ).form;
      double brightest = 0;
      for (final ({Float32List positions, Int32List colours}) mesh
          in ChromosomeArt(form, inks).meshData) {
        for (final int colour in mesh.colours) {
          final (double r, double g, double b) = _channels(colour);
          brightest = math.max(brightest, _lightness(r, g, b));
        }
      }
      expect(brightest, lessThanOrEqualTo(bound + 1 / 255), reason: t.slug);
    }
  });

  testWidgets('no mesh holds more vertices than its indices reach', (
    WidgetTester tester,
  ) async {
    final ZoomInks inks = await _inks(tester);
    for (final ProteinTarget t in TestCatalog.all) {
      final ChromosomeScene scene = ChromosomeScene(
        ZoomSubject(track: locusOf(t), record: recordOf(t)),
      );
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

  testWidgets('a mesh’s translucent colours lie over the ground as the art '
      'takes them to', (WidgetTester tester) async {
    final ZoomInks inks = await _inks(tester);
    const double alpha = 0.4;
    const (double, double, double) colour = (0.9, 0.3, 0.1);
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder);
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, 8, 8),
      Paint()..color = inks.ground,
    );
    final ui.Vertices triangle = ui.Vertices.raw(
      VertexMode.triangles,
      Float32List.fromList(<double>[-8, -8, 40, -8, -8, 40]),
      colors: Int32List.fromList(<int>[
        for (int i = 0; i < 3; i++)
          ChromosomePalette.pack(alpha, colour.$1, colour.$2, colour.$3),
      ]),
    );
    canvas.drawVertices(triangle, BlendMode.dst, Paint());
    triangle.dispose();
    final ui.Picture picture = recorder.endRecording();
    final Uint8List pixels = (await tester.runAsync(() async {
      final ui.Image image = await picture.toImage(8, 8);
      final ByteData data = (await image.toByteData())!;
      image.dispose();
      return data.buffer.asUint8List();
    }))!;
    picture.dispose();
    const int i = (2 * 8 + 2) * 4;
    for (final (int c, double over, double ground) in <(int, double, double)>[
      (0, colour.$1, inks.ground.r),
      (1, colour.$2, inks.ground.g),
      (2, colour.$3, inks.ground.b),
    ]) {
      expect(
        pixels[i + c],
        closeTo((alpha * over + (1 - alpha) * ground) * 255, 1.5),
        reason: 'channel $c',
      );
    }
  });
}
