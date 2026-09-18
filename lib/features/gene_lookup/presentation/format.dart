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
