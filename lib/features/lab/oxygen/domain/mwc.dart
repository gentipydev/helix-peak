import 'dart:math' as math;

import 'package:flutter/foundation.dart';

/// The assembly the oxygen flow is about, and the one-site protein it is
/// held against. A story names its subject, as the sickle story does.
const String oxygenAssembly = 'hemoglobin-a';
const String oneSiteContrast = 'myoglobin';

/// Oxygen binding as Monod, Wyman and Changeux (1965) explain it.
///
/// Every molecule is in one of two states, tense (T) or relaxed (R), and all
/// of its sites are in the state it is in. R binds oxygen more tightly than T:
/// [ratio], `c = K_R / K_T`, is how much. Without oxygen, T outnumbers R by
/// [allosteric], `L`. Each oxygen bound multiplies R's odds by `1 / c`, so the
/// molecule tips from T to R as it fills: that tipping is cooperativity, and it
/// is what the animation shows. The saturation curve comes out of it.
///
/// With one site there is nothing to tip, and the curve is a hyperbola.
@immutable
final class Mwc {
  const Mwc({
    required this.sites,
    required this.allosteric,
    required this.ratio,
    required this.relaxedDissociation,
  });

  /// One site, one state: `Y = p / (p + P50)`.
  const Mwc.singleSite(double p50)
    : sites = 1,
      allosteric = 0,
      ratio = 1,
      relaxedDissociation = p50;

  final int sites;

  /// `L`: T over R, with no oxygen bound.
  final double allosteric;

  /// `c`: R's dissociation constant over T's, below one.
  final double ratio;

  /// `K_R`, in mmHg.
  final double relaxedDissociation;

  Mwc withAllosteric(double value) => Mwc(
    sites: sites,
    allosteric: value,
    ratio: ratio,
    relaxedDissociation: relaxedDissociation,
  );

  /// How full the sites are at [pressure] mmHg, from 0 to 1.
  double saturation(double pressure) {
    final double a = pressure / relaxedDissociation;
    final double ca = ratio * a;
    final int n = sites;
    final double r = math.pow(1 + a, n).toDouble();
    final double t = allosteric * math.pow(1 + ca, n);
    return (a * math.pow(1 + a, n - 1) +
            allosteric * ca * math.pow(1 + ca, n - 1)) /
        (r + t);
  }

  /// The share of molecules in R at [pressure].
  double relaxedFraction(double pressure) {
    final double a = pressure / relaxedDissociation;
    final double r = math.pow(1 + a, sites).toDouble();
    return r / (r + allosteric * math.pow(1 + ratio * a, sites));
  }

  /// The share of molecules with [bound] oxygen that are in R: `1 / (1 + L c^i)`.
  double relaxedWith(int bound) =>
      1 / (1 + allosteric * math.pow(ratio, bound));

  /// The pressure at which the sites are [fill] full, for `0 < fill < 1`.
  double pressureAt(double fill) {
    double low = 1e-9;
    double high = 1e7;
    for (int i = 0; i < 200; i++) {
      final double middle = math.sqrt(low * high);
      if (saturation(middle) < fill) {
        low = middle;
      } else {
        high = middle;
      }
    }
    return math.sqrt(low * high);
  }

  /// Half-saturation, in mmHg.
  double get p50 => pressureAt(0.5);

  /// The slope of `ln(Y / (1 - Y))` against `ln p` at [pressure]: the Hill
  /// coefficient the curve has there. It describes the curve; it explains
  /// nothing about it.
  double hillSlope(double pressure) {
    double logit(double p) {
      final double y = saturation(p);
      return math.log(y / (1 - y));
    }

    const double h = 1e-4;
    return (logit(pressure * (1 + h)) - logit(pressure * (1 - h))) /
        (math.log(1 + h) - math.log(1 - h));
  }

  /// This model with `L` set so that half-saturation falls at [p50].
  Mwc tunedTo(double p50) {
    double low = math.log(1e-6);
    double high = math.log(1e14);
    for (int i = 0; i < 200; i++) {
      final double middle = (low + high) / 2;
      if (withAllosteric(math.exp(middle)).p50 < p50) {
        low = middle;
      } else {
        high = middle;
      }
    }
    return withAllosteric(math.exp((low + high) / 2));
  }
}

/// What carries the oxygen.
enum Carrier {
  /// Adult hemoglobin: four sites, two states.
  adult,

  /// Fetal hemoglobin: the same mechanism, holding its oxygen tighter.
  fetal,

  /// One site: no second state, nothing to tip.
  oneSite,
}

/// The numbers the model is set with, and where each comes from. These are
/// textbook-scale values chosen so the model's curve has the half-saturation
/// pressures blood is known for; the model is an illustration of the
/// mechanism, not a fit to any one measurement.
abstract final class OxygenModel {
  /// `c`: R binds a hundred times more tightly than T. With [adultL] this gives
  /// a Hill slope of about 2.85 at half-saturation.
  static const double ratio = 0.01;

  /// `L` for adult hemoglobin at pH 7.4.
  static const double adultL = 1e5;

  /// Half-saturation of adult blood at pH 7.4, 37 degrees C: 26.8 mmHg.
  static const double adultP50 = 26.8;

  /// Fetal blood's: about 19 mmHg, left of the adult's.
  static const double fetalP50 = 19;

  /// Myoglobin's, one site: about 2.8 mmHg.
  static const double oneSiteP50 = 2.8;

  /// The Bohr effect: `log10 P50` falls by this for each unit pH rises.
  static const double bohr = -0.48;

  static const double neutralPh = 7.4;

  static const List<double> phs = <double>[7.2, 7.4, 7.6];

  /// Adult hemoglobin at pH 7.4: `K_R` set so that `L` = [adultL] puts
  /// half-saturation at [adultP50].
  static final Mwc adult = () {
    const Mwc unit = Mwc(
      sites: 4,
      allosteric: adultL,
      ratio: ratio,
      relaxedDissociation: 1,
    );
    return Mwc(
      sites: 4,
      allosteric: adultL,
      ratio: ratio,
      relaxedDissociation: adultP50 / unit.p50,
    );
  }();

  /// [carrier] at [ph]. The Bohr effect and the fetal shift both act on `L`:
  /// protons, and the 2,3-BPG adult hemoglobin binds more than fetal does,
  /// hold the tense state. `K_R` and `c` are the same throughout.
  static Mwc of(Carrier carrier, double ph) {
    final double shift = math.pow(10, bohr * (ph - neutralPh)).toDouble();
    return switch (carrier) {
      Carrier.adult => adult.tunedTo(adultP50 * shift),
      Carrier.fetal => adult.tunedTo(fetalP50 * shift),
      Carrier.oneSite => const Mwc.singleSite(oneSiteP50),
    };
  }
}

/// A Hill curve fitted to a model's curve: a reference line, drawn as one and
/// labelled as one. It is the curve's shape in a number, `n`, and nothing in
/// the animation reads it.
@immutable
final class HillFit {
  const HillFit(this.n, this.p50);

  /// Least squares on `ln(Y / (1 - Y))` against `ln p`, between 10% and 90%
  /// saturation, where the Hill plot is read.
  factory HillFit.to(Mwc model, {int samples = 81}) {
    final double from = math.log(model.pressureAt(0.1));
    final double to = math.log(model.pressureAt(0.9));
    double sx = 0;
    double sy = 0;
    double sxx = 0;
    double sxy = 0;
    for (int i = 0; i < samples; i++) {
      final double x = from + (to - from) * i / (samples - 1);
      final double y0 = model.saturation(math.exp(x));
      final double y = math.log(y0 / (1 - y0));
      sx += x;
      sy += y;
      sxx += x * x;
      sxy += x * y;
    }
    final double n = (samples * sxy - sx * sy) / (samples * sxx - sx * sx);
    final double intercept = (sy - n * sx) / samples;
    return HillFit(n, math.exp(-intercept / n));
  }

  final double n;
  final double p50;

  double saturation(double pressure) {
    final double x = math.pow(pressure / p50, n).toDouble();
    return x / (1 + x);
  }
}
