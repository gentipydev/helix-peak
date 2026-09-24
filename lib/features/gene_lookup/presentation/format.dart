import 'dart:math' as math;

import '../domain/entities/gene_impact.dart';

/// Thousands separators for coordinates and lengths, e.g. 8416 -> "8,416".
///
/// `intl` is not a dependency of this project and one call site does not
/// justify adding it.
String grouped(int value) {
  final String digits = value.abs().toString();
  final StringBuffer buffer = StringBuffer(value < 0 ? '-' : '');
  for (int i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) {
      buffer.write(',');
    }
    buffer.write(digits[i]);
  }
  return buffer.toString();
}

const List<String> _numberWords = <String>[
  'zero',
  'one',
  'two',
  'three',
  'four',
  'five',
  'six',
  'seven',
  'eight',
  'nine',
  'ten',
  'eleven',
  'twelve',
];

/// Small counts as words, larger ones as digits — "Three exons", "17 exons".
///
/// The caption is one sentence of prose and a leading digit reads as a label
/// rather than a sentence. Above twelve the word is longer than the number and
/// stops helping, which is the usual editorial cutoff.
String spelled(int value) {
  if (value < 0 || value >= _numberWords.length) {
    return grouped(value);
  }
  return _numberWords[value];
}

/// [spelled], capitalised for the start of a sentence.
String spelledLeading(int value) {
  final String word = spelled(value);
  return word[0].toUpperCase() + word.substring(1);
}

/// Where a Phred score sits against every SNV in the genome, in the Atlas's
/// own words: `top 0.071%`, or `bottom 90%`.
///
/// Below Phred 10 it is the bottom nine tenths of the genome and says so,
/// because 'top 87.1%' is not a thing anyone means: the percentile is the share
/// scoring at least this high, and at the quiet end that reading is worse than
/// useless.
String genomeRank(double phred) {
  if (phred < GeneImpact.middlePhred) {
    return 'bottom 90%';
  }
  final double value = math.pow(10, -phred / 10) * 100;
  // Enough figures to stay true at both ends: `1.0%` near the middle of the
  // scale, `0.0032%` out at the tail where every digit is the point. Two
  // significant figures there, written out: the bundled tracks reach Phred 70,
  // `0.000010%`, and `3.2e-3%` is not how a percentile is read.
  if (value >= 1) {
    return 'top ${value.toStringAsFixed(1)}%';
  }
  if (value >= 0.01) {
    return 'top ${value.toStringAsFixed(3)}%';
  }
  return 'top ${value.toStringAsPrecision(2)}%';
}

/// A log-ratio as the residue panel prints it: `−11.0`, `+0.4`, `0.0`.
String formatScore(double value) => value == 0
    ? '0.0'
    : '${value < 0 ? '\u2212' : '+'}${value.abs().toStringAsFixed(1)}';
