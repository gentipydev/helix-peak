import 'dart:math' as math;
import 'dart:ui';

import '../../../../../core/theme/chromosome_colors.dart';
import '../../zoom_inks.dart';
import '../specimen_light.dart';
import 'chromosome_style.dart';

/// A unit normal: x across the screen, y down it, z out of it.
final class SurfaceNormal {
  factory SurfaceNormal(double x, double y, double z) {
    final double length = math.sqrt(x * x + y * y + z * z);
    return length == 0
        ? const SurfaceNormal._(0, 0, 1)
        : SurfaceNormal._(x / length, y / length, z / length);
  }

  const SurfaceNormal._(this.x, this.y, this.z);

  final double x;
  final double y;
  final double z;
}

/// The zoom's one lamp, the organs' ([SpecimenLamp.zoom]), as chromatin
/// takes it: lit as a surface faces it, darker toward the edges of the
/// sister it is part of, with a moist sheen where it faces half way between
/// the light and the eye.
///
/// [turn] is how far the scene is turned back a quarter turn on the
/// canvas, as the chromosome is on its way to lying along the genome: the
/// light stays where it is on the screen, so in the turned scene's own
/// frame it comes from as far round the other way. [look] may scale what
/// the lamp gives for a contrast of its own, the lamp staying where it is.
final class ChromosomeLight {
  factory ChromosomeLight({
    double turn = 0,
    ChromosomeLookSpec look = ChromosomeLookSpec.stone,
  }) {
    SpecimenLamp lamp = SpecimenLamp.zoom;
    if (look.ambientScale != 1 || look.diffuseGain != 1) {
      lamp = SpecimenLamp(
        x: lamp.x,
        y: lamp.y,
        z: lamp.z,
        ambient: lamp.ambient * look.ambientScale,
        diffuse: lamp.diffuse * look.diffuseGain,
        edgeDark: lamp.edgeDark,
        edgePower: lamp.edgePower,
        sheen: lamp.sheen,
      );
    }
    if (turn == 0) {
      return ChromosomeLight._(SpecimenLight(lamp), look.sheen);
    }
    final double a = math.pi / 2 * turn;
    final double c = math.cos(a);
    final double s = math.sin(a);
    return ChromosomeLight._(
      SpecimenLight(
        SpecimenLamp(
          x: lamp.x * c - lamp.y * s,
          y: lamp.x * s + lamp.y * c,
          z: lamp.z,
          ambient: lamp.ambient,
          diffuse: lamp.diffuse,
          edgeDark: lamp.edgeDark,
          edgePower: lamp.edgePower,
          sheen: lamp.sheen,
        ),
      ),
      look.sheen,
    );
  }

  ChromosomeLight._(this._lamp, this._sheen);

  final SpecimenLight _lamp;

  /// The share of the lamp's sheen the chromatin takes.
  final double _sheen;

  /// The way toward the light, on the screen.
  Offset get screen => _lamp.screen;

  /// How bright a surface facing (nx, ny, nz) is, on a sister whose own
  /// face there turns [facing] of the way toward the eye.
  double light(double nx, double ny, double nz, {double facing = 1}) =>
      _lamp.light(nx, ny, nz, form: facing);

  /// How much of the light's own colour a surface facing (nx, ny, nz) sends
  /// back to the eye: as much as chromatin shines.
  double sheen(double nx, double ny, double nz) =>
      _sheen * _lamp.sheen(nx, ny, nz);
}

/// The inks the chromatin is mixed from, as channels to mix without
/// building a colour for every vertex: chromatin from the lit outline down
/// to the surfaces by its stain, both warmed toward the home helix's honey
/// ([ChromosomeLookSpec.warmth]), tinted toward the centromere's ink or the
/// telomeres', then as a specimen's surface is mixed
/// ([SpecimenPalette.colour], step for step): toward the shadow as light
/// leaves it, into the groove's shade, the mark in the gene's band, and
/// toward the bright ink where it shines.
///
/// A look of globules mixes each material along a ramp of its own instead
/// ([ChromatinRamp]), so it darkens and brightens in its own hue: from its
/// crevice in no light through its shadow to its own colour, past it to
/// its highlight, its sheen to its specular, and into its crevice and on to
/// the deepest shadow where it is shut in.
final class ChromosomePalette {
  ChromosomePalette(
    ZoomInks inks, {
    ChromosomeLookSpec look = ChromosomeLookSpec.stone,
  }) : _globules = look.globules,
       _ramps = <_Ramp>[
         if (look.globules case final ChromosomeGlobules globules)
           for (final ChromatinRamp ramp in <ChromatinRamp>[
             globules.colours.body,
             globules.colours.centromere,
             globules.colours.telomere,
             globules.colours.gene,
           ])
             _Ramp(ramp),
       ],
       _wash = look.wash,
       _pale = _Channels(_warmed(inks, inks.lit(look.paleLit), look.warmth)),
       _deep = _Channels(
         _warmed(inks, inks.shade(look.deepShade), look.warmth),
       ),
       _shadow = _Channels(inks.shadow),
       _text = _Channels(inks.text),
       _mark = _Channels(inks.mark),
       _centromere = _Channels(inks.centromere),
       _telomere = _Channels(inks.telomere);

  /// [colour] warmed toward the home helix's honey, the ink the zoom's
  /// nerves are drawn in, [warmth] of the way, as far as the chromatin is.
  static Color _warmed(ZoomInks inks, Color colour, double warmth) =>
      Color.lerp(colour, inks.bases.guanine, warmth)!;

  /// How a look of globules mixes its chromatin, and its ramps, by
  /// [ChromatinMaterial]: null and none for a look of lobes.
  final ChromosomeGlobules? _globules;
  final List<_Ramp> _ramps;

  /// The share of the mark in the gene's band.
  final double _wash;

  final _Channels _pale;
  final _Channels _deep;
  final _Channels _shadow;
  final _Channels _text;
  final _Channels _mark;
  final _Channels _centromere;
  final _Channels _telomere;

  /// Chromatin of stain [tone], at brightness [light], [occlusion] of the
  /// way into the groove's shade and [gene] of the way into the gene's band,
  /// [centromere] and [telomere] of the way to their inks, and [sheen] of
  /// the way to the bright ink.
  int colour(
    double tone,
    double light,
    double occlusion,
    double gene,
    double alpha, {
    double centromere = 0,
    double telomere = 0,
    double sheen = 0,
  }) {
    final (double r, double g, double b) = mix(
      tone,
      light,
      occlusion,
      gene,
      centromere: centromere,
      telomere: telomere,
      sheen: sheen,
    );
    return pack(alpha, r, g, b);
  }

  /// [colour]'s channels, from 0 to 1, before they are packed. In a look of
  /// globules, the arms' chromatin is mixed [centromere], [telomere] and
  /// [gene] of the way to the centromere's, the telomeres' and the gene's,
  /// each at the same light: a smooth tube's, under the globules.
  (double, double, double) mix(
    double tone,
    double light,
    double occlusion,
    double gene, {
    double centromere = 0,
    double telomere = 0,
    double sheen = 0,
  }) {
    if (_globules != null) {
      double r;
      double g;
      double b;
      (r, g, b) = _along(0, tone, light, occlusion, sheen, 0);
      for (final (int material, double share) in <(int, double)>[
        (ChromatinMaterial.centromere.index, centromere),
        (ChromatinMaterial.telomere.index, telomere),
        (ChromatinMaterial.gene.index, gene),
      ]) {
        if (share > 0) {
          final (double mr, double mg, double mb) = _along(
            material,
            tone,
            light,
            occlusion,
            sheen,
            0,
          );
          r += (mr - r) * share;
          g += (mg - g) * share;
          b += (mb - b) * share;
        }
      }
      return (r, g, b);
    }
    double r = _pale.r + (_deep.r - _pale.r) * tone;
    double g = _pale.g + (_deep.g - _pale.g) * tone;
    double b = _pale.b + (_deep.b - _pale.b) * tone;
    // The centromere's and the telomeres' tints are the chromatin's own
    // colour there, lit as the rest is, so the light and the relief read
    // through them.
    r += (_centromere.r - r) * centromere;
    g += (_centromere.g - g) * centromere;
    b += (_centromere.b - b) * centromere;
    r += (_telomere.r - r) * telomere;
    g += (_telomere.g - g) * telomere;
    b += (_telomere.b - b) * telomere;
    if (light <= 1) {
      final double t = math.max(0, light);
      r = _shadow.r + (r - _shadow.r) * t;
      g = _shadow.g + (g - _shadow.g) * t;
      b = _shadow.b + (b - _shadow.b) * t;
    } else {
      final double t = math.min(0.7, 0.9 * (light - 1));
      r += (_text.r - r) * t;
      g += (_text.g - g) * t;
      b += (_text.b - b) * t;
    }
    r += (_shadow.r - r) * occlusion;
    g += (_shadow.g - g) * occlusion;
    b += (_shadow.b - b) * occlusion;
    final double wash = _wash * gene;
    r += (_mark.r - r) * wash;
    g += (_mark.g - g) * wash;
    b += (_mark.b - b) * wash;
    if (sheen > 0) {
      final double s = math.min(1, sheen);
      r += (_text.r - r) * s;
      g += (_text.g - g) * s;
      b += (_text.b - b) * s;
    }
    return (r, g, b);
  }

  int shadow(double alpha) => pack(alpha, _shadow.r, _shadow.g, _shadow.b);

  /// A knob of [material] in a look of globules, packed: of stain [tone], at
  /// brightness [light], [occlusion] of the way into its crevice and on into
  /// the deepest shadow, its own jitter [lift] (-1 to 1) of the way lighter
  /// or darker, and [sheen] of the way to its specular.
  int knob(
    ChromatinMaterial material,
    double tone,
    double light,
    double occlusion,
    double alpha, {
    double sheen = 0,
    double lift = 0,
  }) {
    final (double r, double g, double b) = _along(
      material.index,
      tone,
      light,
      occlusion,
      sheen,
      lift,
    );
    return pack(alpha, r, g, b);
  }

  /// [material]'s crevice, and its specular, at [alpha], packed.
  int crevice(ChromatinMaterial material, double alpha) {
    final _Channels c = _ramps[material.index].stops.first;
    return pack(alpha, c.r, c.g, c.b);
  }

  int specular(ChromatinMaterial material, double alpha) {
    final _Channels c = _ramps[material.index].stops.last;
    return pack(alpha, c.r, c.g, c.b);
  }

  /// The ramp of material [index] at [light], darker by the band's stain
  /// [tone] and lighter or darker by [lift], shut [occlusion] of the way in
  /// and shining [sheen] of the way.
  (double, double, double) _along(
    int index,
    double tone,
    double light,
    double occlusion,
    double sheen,
    double lift,
  ) {
    final ChromosomeGlobules globules = _globules!;
    final List<_Channels> stops = _ramps[index].stops;
    final double at =
        light * (1 - globules.bandShade * tone) * (1 + globules.lift * lift);
    final _Channels from;
    final _Channels to;
    final double t;
    if (at <= globules.shadowAt) {
      (from, to) = (stops[0], stops[1]);
      t = math.max(0, at) / globules.shadowAt;
    } else if (at <= globules.baseAt) {
      (from, to) = (stops[1], stops[2]);
      t = (at - globules.shadowAt) / (globules.baseAt - globules.shadowAt);
    } else {
      (from, to) = (stops[2], stops[3]);
      t = math.min(
        1,
        (at - globules.baseAt) / (globules.highlightAt - globules.baseAt),
      );
    }
    double r = from.r + (to.r - from.r) * t;
    double g = from.g + (to.g - from.g) * t;
    double b = from.b + (to.b - from.b) * t;
    if (occlusion > 0) {
      // Into the material's own crevice, and past it to the deepest shadow.
      final _Channels crevice = stops[0];
      final double inward = math.min(1, 2 * occlusion);
      r += (crevice.r - r) * inward;
      g += (crevice.g - g) * inward;
      b += (crevice.b - b) * inward;
      final double deeper = math.min(1, 2 * occlusion - 1);
      if (deeper > 0) {
        r += (_shadow.r - r) * deeper;
        g += (_shadow.g - g) * deeper;
        b += (_shadow.b - b) * deeper;
      }
    }
    if (sheen > 0) {
      final _Channels specular = stops[4];
      final double s = math.min(1, sheen);
      r += (specular.r - r) * s;
      g += (specular.g - g) * s;
      b += (specular.b - b) * s;
    }
    return (r, g, b);
  }

  /// A vertex's colour from its channels, each from 0 to 1.
  static int pack(double a, double r, double g, double b) {
    int channel(double v) => (v.clamp(0.0, 1.0) * 255).round();
    return channel(a) << 24 | channel(r) << 16 | channel(g) << 8 | channel(b);
  }
}

final class _Channels {
  _Channels(Color colour) : r = colour.r, g = colour.g, b = colour.b;

  final double r;
  final double g;
  final double b;
}

/// A material's ramp, as channels: crevice, shadow, its own colour,
/// highlight and specular.
final class _Ramp {
  _Ramp(ChromatinRamp ramp)
    : stops = <_Channels>[for (final Color c in ramp.stops) _Channels(c)];

  final List<_Channels> stops;
}
