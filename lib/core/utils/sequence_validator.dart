import 'package:flutter/foundation.dart';

import '../constants/app_constants.dart';

/// Outcome of validating raw user input.
///
/// Modelled as a sealed union rather than an exception because invalid input
/// is an expected result here, not an exceptional one — the input screen
/// renders the failure inline as it types.
@immutable
sealed class SequenceValidation {
  const SequenceValidation();
}

/// Input that parsed cleanly.
@immutable
final class ValidSequence extends SequenceValidation {
  const ValidSequence({required this.bases, this.fastaHeader});

  /// Uppercased, whitespace-stripped bases with any FASTA header removed.
  final String bases;

  /// The FASTA description line, without its leading '>', when one was given.
  final String? fastaHeader;
}

/// Input that could not be used, with copy suitable for showing to the user.
@immutable
final class InvalidSequence extends SequenceValidation {
  const InvalidSequence(this.message);

  final String message;
}

/// Parses and validates raw sequence text.
///
/// Deliberately free of any feature-level types so it stays a pure, trivially
/// testable function: it answers "is this usable, and what are the bases",
/// and nothing about what the bases mean.
abstract final class SequenceValidator {
  /// Characters permitted in a sequence body, precomputed once.
  static final Set<String> _allowed =
      AppConstants.iupacNucleotideCodes.split('').toSet();

  static SequenceValidation validate(String raw) {
    if (raw.trim().isEmpty) {
      return const InvalidSequence('Enter a sequence to analyse.');
    }

    final (String? header, String body) = _splitFastaHeader(raw);
    final String bases = _normalise(body);

    if (bases.isEmpty) {
      return const InvalidSequence(
        'This FASTA record has a header but no sequence data.',
      );
    }

    if (bases.length < AppConstants.minSequenceLength) {
      return InvalidSequence(
        'Sequence is too short — at least ${AppConstants.minSequenceLength} '
        'bases are needed, found ${bases.length}.',
      );
    }

    if (bases.length > AppConstants.maxSequenceLength) {
      return InvalidSequence(
        'Sequence exceeds the ${AppConstants.maxSequenceLength}-base limit '
        '(found ${bases.length}).',
      );
    }

    for (int i = 0; i < bases.length; i++) {
      final String character = bases[i];
      if (!_allowed.contains(character)) {
        // Reporting the position matters: in a wall of monospace text, "there
        // is a bad character somewhere" is not actionable feedback.
        return InvalidSequence(
          "Unexpected character '$character' at position ${i + 1}.",
        );
      }
    }

    return ValidSequence(bases: bases, fastaHeader: header);
  }

  /// Splits a leading FASTA header line from the sequence body.
  ///
  /// Returns `(null, raw)` when the input is a bare sequence.
  static (String?, String) _splitFastaHeader(String raw) {
    final String trimmed = raw.trimLeft();
    if (!trimmed.startsWith(AppConstants.fastaHeaderMarker)) {
      return (null, raw);
    }

    final int firstBreak = trimmed.indexOf('\n');
    if (firstBreak == -1) {
      // Header only, no body — the emptiness check downstream reports it.
      return (trimmed.substring(1).trim(), '');
    }

    return (
      trimmed.substring(1, firstBreak).trim(),
      trimmed.substring(firstBreak + 1),
    );
  }

  /// Strips all whitespace (FASTA wraps at 60–80 columns) and uppercases.
  static String _normalise(String body) =>
      body.replaceAll(RegExp(r'\s'), '').toUpperCase();
}
