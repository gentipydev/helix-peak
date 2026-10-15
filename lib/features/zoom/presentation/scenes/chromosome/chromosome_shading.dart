import 'dart:math' as math;
import 'dart:ui';

import '../../zoom_inks.dart';
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

/// The one light, from the upper left and a little in front, and how a
/// scanning micrograph sees a surface under it: lit as it faces the light,
/// its edges glowing on the side the light comes from and darkening on the
/// other.
///
/// [turn] is how far the scene is turned back a quarter turn on the
/// canvas, as the chromosome is on its way to lying along the genome: the
/// light stays where it is on the screen, so in the turned scene's own
/// frame it comes from as far round the other way.
final class ChromosomeLight {
  ChromosomeLight({double turn = 0}) {
    double lx = ChromosomeStyle.lightX;
    double ly = ChromosomeStyle.lightY;
    if (turn != 0) {
      final double a = math.pi / 2 * turn;
      final double c = math.cos(a);
      final double s = math.sin(a);
      final double turnedX = lx * c - ly * s;
      final double turnedY = lx * s + ly * c;
      lx = turnedX;
      ly = turnedY;
    }
    const double lz = ChromosomeStyle.lightZ;
    final double length = math.sqrt(lx * lx + ly * ly + lz * lz);
    x = lx / length;
    y = ly / length;
    z = lz / length;
    final double flat = math.sqrt(x * x + y * y);
    screenX = x / flat;
    screenY = y / flat;
  }

  late final double x;
  late final double y;
  late final double z;

  /// The light's direction on the screen.
  late final double screenX;
  late final double screenY;

  double brightness(double nx, double ny, double nz) {
    final double lit = math.max(0, nx * x + ny * y + nz * z);
    final double edge = math
        .pow(math.max(0, 1 - nz), ChromosomeStyle.edgePower)
        .toDouble();
    final double flat = math.sqrt(nx * nx + ny * ny);
    final double facing = flat < 1e-6
        ? 0
        : math.max(0, (nx * screenX + ny * screenY) / flat);
    final double toward = 0.35 + 0.65 * facing;
    return ChromosomeStyle.ambient +
        ChromosomeStyle.diffuse * lit +
        ChromosomeStyle.edgeLit * edge * toward -
        ChromosomeStyle.edgeShade * edge * (1 - toward);
  }
}

/// The inks the micrograph is mixed from, as channels to mix without
/// building a colour for every vertex: chromatin from the lit outline down
/// to the surfaces by its stain, toward the shadow as light leaves it,
/// toward the bright ink where it is brightest, and the mark in the gene's
/// band.
final class ChromosomePalette {
  ChromosomePalette(ZoomInks inks)
    : _pale = _Channels(inks.lit(ChromosomeStyle.paleLit)),
      _deep = _Channels(inks.shade(ChromosomeStyle.deepShade)),
      _shadow = _Channels(inks.shadow),
      _text = _Channels(inks.text),
      _mark = _Channels(inks.mark);

  final _Channels _pale;
  final _Channels _deep;
  final _Channels _shadow;
  final _Channels _text;
  final _Channels _mark;

  /// Chromatin of stain [tone], at brightness [light], [occlusion] of the
  /// way into the groove's shade and [gene] of the way into the gene's band.
  int colour(
    double tone,
    double light,
    double occlusion,
    double gene,
    double alpha,
  ) {
    final (double r, double g, double b) = mix(tone, light, occlusion, gene);
    return pack(alpha, r, g, b);
  }

  /// [colour]'s channels, from 0 to 1, before they are packed.
  (double, double, double) mix(
    double tone,
    double light,
    double occlusion,
    double gene,
  ) {
    double r = _pale.r + (_deep.r - _pale.r) * tone;
    double g = _pale.g + (_deep.g - _pale.g) * tone;
    double b = _pale.b + (_deep.b - _pale.b) * tone;
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
    return (r, g, b);
  }

  int shadow(double alpha) => pack(alpha, _shadow.r, _shadow.g, _shadow.b);

  int text(double alpha) => pack(alpha, _text.r, _text.g, _text.b);

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
