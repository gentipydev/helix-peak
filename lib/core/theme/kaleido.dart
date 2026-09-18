import 'dart:math' as math;
import 'dart:ui';

/// A colour as the colour filter of an E Ink Kaleido 3 panel would show it, as
/// far as a panel that is not one can.
///
/// Kaleido lays a colour filter array over a monochrome ink layer, so every
/// colour it shows is that ink's grey seen through a tint: the lightness is the
/// ink's, the hue is the filter's, and the saturation is only what the filter
/// lets through, which is a good deal less than a backlit panel manages. That
/// is the whole of this filter. Lightness and hue are kept exactly — in CIE
/// L\*a\*b\*, so "kept" means as the eye measures it — and chroma is scaled by
/// [through].
///
/// Lightness is the part that may not move, because it is what carries a
/// residue's letter: every residue square has its letter knocked out in the
/// ground colour, and the floor that keeps that letter legible is a floor on
/// the square's lightness alone. So a palette cleared for it before the filter
/// is cleared for it after, and so is any ordering its lightness encodes.
///
/// Two things about the panel are deliberately left behind. Its grid of 4,096
/// colours — sixteen levels a channel — moves a soft hue by several degrees,
/// enough to break the rhyme between a residue and the base it is built from
/// and to land two chemistries on one colour. And its warm paper, which on a
/// ground this warm already is would only lean the blues toward grey and the
/// cut site toward the stop codon.
abstract final class Kaleido {
  /// How much of a colour's chroma the filter lets through.
  ///
  /// Half: soft enough to read as ink on paper rather than light behind glass,
  /// and still enough that no two residue chemistries fall within 14 ΔE00 of
  /// each other for normal vision.
  static const double through = 0.5;

  /// [colour] through the filter, rounded to the nearest 8-bit colour so a
  /// palette built from it can be pinned to exact values.
  static Color filter(Color colour) {
    final (double l, double a, double b) = _lab(colour);
    return _fromLab(l, a * through, b * through, colour.a);
  }

  // D65 white, as sRGB defines it.
  static const double _xn = 0.95047;
  static const double _yn = 1;
  static const double _zn = 1.08883;

  static double _linear(double c) => c <= 0.04045
      ? c / 12.92
      : math.pow((c + 0.055) / 1.055, 2.4).toDouble();

  static double _gamma(double c) {
    final double v = c.clamp(0.0, 1.0);
    return v <= 0.0031308
        ? 12.92 * v
        : 1.055 * math.pow(v, 1 / 2.4).toDouble() - 0.055;
  }

  static double _f(double t) =>
      t > 0.008856 ? math.pow(t, 1 / 3).toDouble() : 7.787 * t + 16 / 116;

  static double _fInverse(double t) {
    final double cube = t * t * t;
    return cube > 0.008856 ? cube : (t - 16 / 116) / 7.787;
  }

  static (double, double, double) _lab(Color colour) {
    final double r = _linear(colour.r);
    final double g = _linear(colour.g);
    final double b = _linear(colour.b);
    final double fx = _f((0.4124 * r + 0.3576 * g + 0.1805 * b) / _xn);
    final double fy = _f((0.2126 * r + 0.7152 * g + 0.0722 * b) / _yn);
    final double fz = _f((0.0193 * r + 0.1192 * g + 0.9505 * b) / _zn);
    return (116 * fy - 16, 500 * (fx - fy), 200 * (fy - fz));
  }

  static Color _fromLab(double l, double a, double b, double alpha) {
    final double fy = (l + 16) / 116;
    final double x = _fInverse(fy + a / 500) * _xn;
    final double y = _fInverse(fy) * _yn;
    final double z = _fInverse(fy - b / 200) * _zn;
    int channel(double linear) => (_gamma(linear) * 255).round();
    return Color.fromARGB(
      (alpha * 255).round(),
      channel(3.2406 * x - 1.5372 * y - 0.4986 * z),
      channel(-0.9689 * x + 1.8758 * y + 0.0415 * z),
      channel(0.0557 * x - 0.2040 * y + 1.0570 * z),
    );
  }
}
