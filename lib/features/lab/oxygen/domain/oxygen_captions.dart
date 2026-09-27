import 'dart:math' as math;

import '../../../../shared/format.dart';
import 'mwc.dart';

/// The words beside the binding: counted off the model, never a fitted curve.
final class OxygenCaptions {
  OxygenCaptions(this.model, this.carrier, this.ph);

  final Mwc model;
  final Carrier carrier;
  final double ph;

  /// What the model is, beside every step.
  String get mechanism => carrier == Carrier.oneSite
      ? 'One site and one state: it binds, and nothing else changes. '
            'Its curve is a hyperbola.'
      : 'Drawn by the MWC model: every molecule is tense or relaxed, all four '
            'sites together, and relaxed binds ${grouped((1 / model.ratio).round())} '
            'times more tightly. The dashed Hill curve is fitted to it for '
            'reference, and explains nothing.';

  /// The caption for the step in which the [bound]-th oxygen binds.
  String captionOf(int bound) {
    if (carrier == Carrier.oneSite) {
      return 'Oxygen binds its one site. Half the sites are full at '
          '${model.p50.toStringAsFixed(1)} mmHg.';
    }
    final int relaxed = (model.relaxedWith(bound) * 100).round();
    final String share = relaxed >= 99
        ? 'nearly every molecule is relaxed'
        : relaxed <= 1
        ? 'nearly every molecule is still tense'
        : '$relaxed% of molecules are relaxed';
    final String why = bound == 1
        ? 'Each one bound makes relaxed ${grouped((1 / model.ratio).round())} '
              'times likelier. '
        : '';
    return '${spelledLeading(bound)} of ${spelled(model.sites)} bound. $why'
        'With ${spelled(bound)} bound, $share.';
  }

  /// Where half-saturation sits, and why it moved.
  String get shift {
    final String p50 = model.p50.toStringAsFixed(1);
    if (carrier == Carrier.oneSite) {
      return 'Half-saturation at $p50 mmHg, far left of blood’s: it holds '
          'oxygen until the tissue is nearly out of it.';
    }
    final String where = switch (carrier) {
      Carrier.fetal => 'Fetal: ',
      _ => '',
    };
    final String acid = ph < OxygenModel.neutralPh
        ? ' More acid holds the tense state (the Bohr effect): the curve moves right.'
        : ph > OxygenModel.neutralPh
        ? ' Less acid lets it go: the curve moves left.'
        : '';
    return '${where}half-saturation at $p50 mmHg, pH ${ph.toStringAsFixed(1)}; '
        'L, tense over relaxed with none bound, is '
        '${_scientific(model.allosteric)}.$acid';
  }

  static String _scientific(double value) {
    final int exponent = (math.log(value) / math.ln10).floor();
    final double mantissa = value / math.pow(10, exponent);
    return '${mantissa.toStringAsFixed(1)} × 10^$exponent';
  }
}
