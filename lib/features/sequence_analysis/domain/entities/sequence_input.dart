import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../../core/utils/sequence_validator.dart';
import 'sequence_type.dart';

part 'sequence_input.freezed.dart';

/// A validated sequence, ready to analyse.
///
/// There is no public constructor path from raw text: [fromValidated] is the
/// only way in, so an instance existing is itself proof that validation passed.
@freezed
abstract class SequenceInput with _$SequenceInput {
  const factory SequenceInput({
    required String bases,
    required SequenceType sequenceType,
    String? fastaHeader,
  }) = _SequenceInput;

  const SequenceInput._();

  /// Builds an input from a [ValidSequence], inferring the molecule type.
  factory SequenceInput.fromValidated(ValidSequence validated) {
    return SequenceInput(
      bases: validated.bases,
      sequenceType: detectType(validated.bases),
      fastaHeader: validated.fastaHeader,
    );
  }

  int get length => bases.length;

  /// Name for display. FASTA headers are often long; screens truncate.
  String get displayName => fastaHeader ?? 'Untitled sequence';

  /// Infers the molecule type from the alphabet in use.
  ///
  /// The order matters: U-without-T implies RNA, and anything using letters
  /// outside the nucleotide alphabet is assumed to be amino acids. Sequences
  /// short enough or ambiguous enough to defeat this land on
  /// [SequenceType.unknown] rather than being guessed at.
  @visibleForTesting
  static SequenceType detectType(String bases) {
    if (bases.isEmpty) {
      return SequenceType.unknown;
    }

    const String nucleotideAlphabet = 'ACGTURYKMSWBDHVN-.';
    bool hasT = false;
    bool hasU = false;

    for (int i = 0; i < bases.length; i++) {
      final String character = bases[i];
      if (!nucleotideAlphabet.contains(character)) {
        return SequenceType.protein;
      }
      if (character == 'T') {
        hasT = true;
      } else if (character == 'U') {
        hasU = true;
      }
    }

    // Both present is contradictory — real DNA has no U, real RNA no T.
    if (hasT && hasU) {
      return SequenceType.unknown;
    }
    return hasU ? SequenceType.rna : SequenceType.dna;
  }
}
