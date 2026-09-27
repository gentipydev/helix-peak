import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/features/lab/oxygen/domain/mwc.dart';

double _curvature(Mwc model, double p) {
  final double h = p * 1e-2;
  return (model.saturation(p + h) -
          2 * model.saturation(p) +
          model.saturation(p - h)) /
      (h * h);
}

void main() {
  final Mwc adult = OxygenModel.of(Carrier.adult, 7.4);
  final Mwc oneSite = OxygenModel.of(Carrier.oneSite, 7.4);

  test('the tetramer’s curve is sigmoid: it bends up, then over', () {
    // Upward at first, the mark of cooperativity: binding helps binding.
    expect(_curvature(adult, 2), greaterThan(0));
    expect(_curvature(adult, 10), greaterThan(0));
    // Then over, as the sites run out.
    expect(_curvature(adult, 40), lessThan(0));
    expect(_curvature(adult, 80), lessThan(0));
    // Exactly one inflection from 2 to 100 mmHg. Below about 1 mmHg the few
    // molecules binding are tense ones, and T binding on its own is a
    // hyperbola: the curve has a faint concave foot there, at a fraction of a
    // per cent saturation, which is MWC and not an error. Past 100 mmHg it is
    // flat to within rounding, and a finite difference there is noise.
    int flips = 0;
    double previous = _curvature(adult, 2);
    for (double p = 2.5; p <= 100; p += 0.5) {
      final double now = _curvature(adult, p);
      if (now.abs() > 1e-9 &&
          previous.abs() > 1e-9 &&
          now.sign != previous.sign) {
        flips++;
      }
      if (now.abs() > 1e-9) {
        previous = now;
      }
    }
    expect(flips, 1);
    expect(adult.hillSlope(adult.p50), inInclusiveRange(2.6, 3.1));
  });

  test('the single site’s curve is a hyperbola, and never bends up', () {
    for (double p = 0.1; p < 150; p *= 1.3) {
      expect(oneSite.saturation(p), closeTo(p / (p + 2.8), 1e-12));
      expect(_curvature(oneSite, p), lessThan(0));
      expect(oneSite.hillSlope(p), closeTo(1, 1e-6));
    }
  });

  test('half-saturation falls where blood’s does', () {
    expect(adult.p50, closeTo(26.8, 0.01));
    expect(OxygenModel.of(Carrier.fetal, 7.4).p50, closeTo(19, 0.01));
    expect(oneSite.p50, closeTo(2.8, 1e-9));
  });

  test('the Bohr effect moves the curve through L alone', () {
    final Mwc acid = OxygenModel.of(Carrier.adult, 7.2);
    final Mwc base = OxygenModel.of(Carrier.adult, 7.6);
    expect(acid.p50, greaterThan(adult.p50));
    expect(base.p50, lessThan(adult.p50));
    final double slope =
        (math.log(base.p50) - math.log(acid.p50)) / math.ln10 / (7.6 - 7.2);
    expect(slope, closeTo(OxygenModel.bohr, 1e-6));
    // Protons hold the tense state: more of it at lower pH, and nothing else moves.
    expect(acid.allosteric, greaterThan(adult.allosteric));
    expect(base.allosteric, lessThan(adult.allosteric));
    for (final Mwc model in <Mwc>[acid, base]) {
      expect(model.ratio, adult.ratio);
      expect(model.relaxedDissociation, adult.relaxedDissociation);
    }
    // Fetal hemoglobin sits left, by the same mechanism.
    expect(
      OxygenModel.of(Carrier.fetal, 7.4).allosteric,
      lessThan(adult.allosteric),
    );
  });

  test('each oxygen bound tips the molecule towards R by 1/c', () {
    expect(adult.relaxedWith(0), lessThan(1e-4));
    expect(adult.relaxedWith(4), greaterThan(0.99));
    for (int i = 0; i < 4; i++) {
      final double odds = adult.relaxedWith(i) / (1 - adult.relaxedWith(i));
      final double next =
          adult.relaxedWith(i + 1) / (1 - adult.relaxedWith(i + 1));
      expect(next / odds, closeTo(1 / adult.ratio, 1e-6));
    }
    // A single site has no tense state to leave.
    expect(oneSite.relaxedWith(0), 1);
  });

  test('saturation and the R fraction agree with the ligation states', () {
    // Y is the average of i/n over the populations; R-bar the R share of them.
    for (final double p in <double>[5, 20, 26.8, 60]) {
      final double a = p / adult.relaxedDissociation;
      double z = 0;
      double filled = 0;
      double relaxed = 0;
      for (int i = 0; i <= 4; i++) {
        final double ways = <double>[1, 4, 6, 4, 1][i];
        final double r = ways * math.pow(a, i);
        final double t = adult.allosteric * ways * math.pow(adult.ratio * a, i);
        z += r + t;
        filled += (r + t) * i / 4;
        relaxed += r;
      }
      expect(adult.saturation(p), closeTo(filled / z, 1e-12));
      expect(adult.relaxedFraction(p), closeTo(relaxed / z, 1e-12));
    }
  });

  test('the Hill fit is a reference: it says n, and nothing drives by it', () {
    final HillFit fit = HillFit.to(adult);
    expect(fit.n, inInclusiveRange(2.6, 3.1));
    expect(fit.p50, closeTo(adult.p50, 1));
    expect(HillFit.to(oneSite).n, closeTo(1, 1e-6));
  });
}
