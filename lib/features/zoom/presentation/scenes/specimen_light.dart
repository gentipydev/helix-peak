import 'dart:math' as math;
import 'dart:ui';

import '../zoom_inks.dart';

/// A lamp a specimen is drawn under: where it shines from, and how the
/// specimen's surfaces take it.
final class SpecimenLamp {
  const SpecimenLamp({
    required this.x,
    required this.y,
    required this.z,
    required this.ambient,
    required this.diffuse,
    required this.edgeDark,
    required this.edgePower,
    required this.sheen,
  });

  /// The way toward the light: x across the screen, y down it, z out of it.
  final double x;
  final double y;
  final double z;

  /// What every surface has, what the light adds, how much darker a form is
  /// toward its silhouette and how soon, and its sheen.
  final double ambient;
  final double diffuse;
  final double edgeDark;
  final double edgePower;
  final double sheen;

  /// The zoom's one lamp, the pancreas's and the brain's: from the upper
  /// left and in front, as the chromosome's, on fresh tissue with a moist
  /// sheen.
  static const SpecimenLamp zoom = SpecimenLamp(
    x: -0.48,
    y: -0.57,
    z: 0.66,
    ambient: 0.3,
    diffuse: 0.7,
    edgeDark: 0.45,
    edgePower: 0.6,
    sheen: 0.3,
  );
}

/// The one light, and how a specimen and what lies round it take it: lit as
/// a surface faces it, darker toward the silhouette of the form it is part
/// of, with the sheen of a moist surface where it faces half way between
/// the light and the eye.
final class SpecimenLight {
  SpecimenLight(this.lamp) {
    final double lx = lamp.x;
    final double ly = lamp.y;
    final double lz = lamp.z;
    final double length = math.sqrt(lx * lx + ly * ly + lz * lz);
    x = lx / length;
    y = ly / length;
    z = lz / length;
    final double hl = math.sqrt(x * x + y * y + (z + 1) * (z + 1));
    _hx = x / hl;
    _hy = y / hl;
    _hz = (z + 1) / hl;
    final double flat = math.sqrt(x * x + y * y);
    screen = Offset(x / flat, y / flat);
  }

  final SpecimenLamp lamp;

  late final double x;
  late final double y;
  late final double z;
  late final double _hx;
  late final double _hy;
  late final double _hz;

  /// The way toward the light, on the screen.
  late final Offset screen;

  /// How bright a surface facing (nx, ny, nz) is, on a form whose own face
  /// there turns [form] of the way toward the eye.
  double light(double nx, double ny, double nz, {double form = 1}) =>
      (lamp.ambient + lamp.diffuse * math.max(0, nx * x + ny * y + nz * z)) *
      (1 -
          lamp.edgeDark +
          lamp.edgeDark * math.pow(math.max(0, form), lamp.edgePower));

  /// How much of the light's own colour a surface facing (nx, ny, nz)
  /// sends back to the eye.
  double sheen(double nx, double ny, double nz) {
    double s = math.max(0, nx * _hx + ny * _hy + nz * _hz);
    // To the power 24, the sheen's tightness: s¹⁶ · s⁸.
    s = s * s;
    s = s * s;
    s = s * s;
    final double s8 = s;
    s = s * s;
    return lamp.sheen * s * s8;
  }
}

/// A surface's colour at its two ends: where the light leaves it, [deep],
/// and where it falls full on it, [tone].
final class SpecimenTone {
  SpecimenTone(Color tone, Color deep)
    : _r = tone.r,
      _g = tone.g,
      _b = tone.b,
      _dr = deep.r,
      _dg = deep.g,
      _db = deep.b;

  final double _r;
  final double _g;
  final double _b;
  final double _dr;
  final double _dg;
  final double _db;
}

/// The inks a specimen is mixed from, as channels to mix without building
/// a colour for every vertex: a surface from its deep end to its tone by
/// its light and on toward the bright ink past it, into the shadow where it
/// is shut in, toward the bright ink where it shines, and toward the mark by
/// [colour]'s wash.
final class SpecimenPalette {
  SpecimenPalette(ZoomInks inks)
    : _shadow = inks.shadow,
      _text = inks.text,
      _mark = inks.mark;

  final Color _shadow;
  final Color _text;
  final Color _mark;

  /// A vertex's colour, packed: [tone] at [light], [occlusion] of the way
  /// into the shadow, [sheen] of the way to the bright ink, [wash] of the
  /// way to the mark, at [alpha].
  int colour(
    SpecimenTone tone,
    double light, {
    double occlusion = 0,
    double sheen = 0,
    double wash = 0,
    double alpha = 1,
  }) {
    double r;
    double g;
    double b;
    if (light <= 1) {
      final double t = math.max(0, light);
      r = tone._dr + (tone._r - tone._dr) * t;
      g = tone._dg + (tone._g - tone._dg) * t;
      b = tone._db + (tone._b - tone._db) * t;
    } else {
      final double t = math.min(0.7, 0.9 * (light - 1));
      r = tone._r + (_text.r - tone._r) * t;
      g = tone._g + (_text.g - tone._g) * t;
      b = tone._b + (_text.b - tone._b) * t;
    }
    if (occlusion > 0) {
      r += (_shadow.r - r) * occlusion;
      g += (_shadow.g - g) * occlusion;
      b += (_shadow.b - b) * occlusion;
    }
    if (wash > 0) {
      r += (_mark.r - r) * wash;
      g += (_mark.g - g) * wash;
      b += (_mark.b - b) * wash;
    }
    if (sheen > 0) {
      final double s = math.min(1, sheen);
      r += (_text.r - r) * s;
      g += (_text.g - g) * s;
      b += (_text.b - b) * s;
    }
    return pack(alpha, r, g, b);
  }

  /// A colour from its channels, each from 0 to 1, packed for a mesh.
  static int pack(double a, double r, double g, double b) {
    int channel(double v) => (v.clamp(0.0, 1.0) * 255).round();
    return channel(a) << 24 | channel(r) << 16 | channel(g) << 8 | channel(b);
  }

  /// [colour] at [alpha], packed.
  static int packColour(Color colour, double alpha) =>
      pack(alpha, colour.r, colour.g, colour.b);
}
