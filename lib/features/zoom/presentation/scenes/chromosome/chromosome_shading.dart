import 'dart:math' as math;
import 'dart:ui';

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
/// frame it comes from as far round the other way.
final class ChromosomeLight {
  factory ChromosomeLight({double turn = 0}) {
    const SpecimenLamp lamp = SpecimenLamp.zoom;
    if (turn == 0) {
      return ChromosomeLight._(SpecimenLight(lamp));
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
    );
  }

  ChromosomeLight._(this._lamp);

  final SpecimenLight _lamp;

  /// The way toward the light, on the screen.
  Offset get screen => _lamp.screen;

  /// How bright a surface facing (nx, ny, nz) is, on a sister whose own
  /// face there turns [facing] of the way toward the eye.
  double light(double nx, double ny, double nz, {double facing = 1}) =>
      _lamp.light(nx, ny, nz, form: facing);

  /// How much of the light's own colour a surface facing (nx, ny, nz) sends
  /// back to the eye: as much as chromatin shines.
  double sheen(double nx, double ny, double nz) =>
      ChromosomeStyle.sheen * _lamp.sheen(nx, ny, nz);
}

/// The inks the chromatin is mixed from, as channels to mix without
/// building a colour for every vertex: chromatin from the lit outline down
/// to the surfaces by its stain, tinted toward the centromere's ink or the
/// telomeres', then as a specimen's surface is mixed
/// ([SpecimenPalette.colour], step for step): toward the shadow as light
/// leaves it, into the groove's shade, the mark in the gene's band, and
/// toward the bright ink where it shines.
final class ChromosomePalette {
  ChromosomePalette(ZoomInks inks)
    : _pale = _Channels(inks.lit(ChromosomeStyle.paleLit)),
      _deep = _Channels(inks.shade(ChromosomeStyle.deepShade)),
      _shadow = _Channels(inks.shadow),
      _text = _Channels(inks.text),
      _mark = _Channels(inks.mark),
      _centromere = _Channels(inks.centromere),
      _telomere = _Channels(inks.telomere);

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

  /// [colour]'s channels, from 0 to 1, before they are packed.
  (double, double, double) mix(
    double tone,
    double light,
    double occlusion,
    double gene, {
    double centromere = 0,
    double telomere = 0,
    double sheen = 0,
  }) {
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
    final double wash = ChromosomeStyle.wash * gene;
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
