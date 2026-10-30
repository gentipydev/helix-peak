import 'dart:math' as math;

import '../domain/training_trace.dart';

/// A loss, in nats, to three places: `3.145`, `0.068`.
String nats(double value) => value.toStringAsFixed(3);

/// A probability as a percentage, whole above ten and to a tenth below.
String percent(double p) =>
    p >= 0.1 ? '${(p * 100).round()}%' : '${(p * 100).toStringAsFixed(1)}%';

const String _minus = '−';

/// A number with its sign always shown, the minus a true minus.
String signed(double value, int digits) =>
    '${value < 0 ? _minus : '+'}${value.abs().toStringAsFixed(digits)}';

/// A number to [digits] places, the minus a true minus, and no sign on a
/// number that rounds to nothing: `−1.2`, `0.0`.
String fixed(double value, int digits) {
  final String text = value.abs().toStringAsFixed(digits);
  return value < 0 && double.parse(text) != 0 ? '$_minus$text' : text;
}

/// A small number in E notation, the minus a true one: `1.0e−3`. Neither of
/// the app's faces has a superscript minus.
String scientific(double value) {
  if (value <= 0) {
    return '0';
  }
  int exponent = (math.log(value) / math.ln10).floor();
  double mantissa = value / math.pow(10, exponent);
  if (double.parse(mantissa.toStringAsFixed(1)) >= 10) {
    exponent += 1;
    mantissa /= 10;
  }
  final String power = exponent < 0 ? '$_minus${-exponent}' : '$exponent';
  return '${mantissa.toStringAsFixed(1)}e$power';
}

/// What a position has read: the residues before it, the last [most] of them,
/// or `<bos>` at the very start.
String readSoFar(TrainingTrace trace, int peptide, int position, {int most = 6}) {
  if (position == 0) {
    return '<bos>';
  }
  final String sequence = trace.peptides[peptide].sequence;
  final int from = math.max(0, position - most);
  return '${from > 0 ? '…' : ''}${sequence.substring(from, position)}';
}
