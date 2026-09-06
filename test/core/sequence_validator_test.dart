import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeak/core/utils/sequence_validator.dart';

void main() {
  group('SequenceValidator', () {
    test('rejects empty input', () {
      final SequenceValidation result = SequenceValidator.validate('');
      expect(result, isA<InvalidSequence>());
      expect(
        (result as InvalidSequence).message,
        contains('Enter a sequence'),
      );
    });

    test('rejects whitespace-only input', () {
      expect(
        SequenceValidator.validate('   \n\t  '),
        isA<InvalidSequence>(),
      );
    });

    test('rejects sequences below the minimum length', () {
      final SequenceValidation result = SequenceValidator.validate('ATGC');
      expect(result, isA<InvalidSequence>());
      expect((result as InvalidSequence).message, contains('too short'));
    });

    test('names the offending character and its position', () {
      // 'Z' is not an IUPAC code; it sits at 1-based position 11.
      final SequenceValidation result =
          SequenceValidator.validate('ATGCATGCAT Z GCATGCAT');
      expect(result, isA<InvalidSequence>());

      final String message = (result as InvalidSequence).message;
      expect(message, contains("'Z'"));
      expect(message, contains('position 11'));
    });

    test('accepts a plain sequence and reports no header', () {
      final SequenceValidation result =
          SequenceValidator.validate('ATGCGTAGCTAGCTAGCTA');

      expect(result, isA<ValidSequence>());
      final ValidSequence valid = result as ValidSequence;
      expect(valid.bases, 'ATGCGTAGCTAGCTAGCTA');
      expect(valid.fastaHeader, isNull);
    });

    test('uppercases and strips the whitespace FASTA wrapping introduces', () {
      final SequenceValidation result =
          SequenceValidator.validate('atgcgtagct\nagctagctag\n');

      expect(result, isA<ValidSequence>());
      expect((result as ValidSequence).bases, 'ATGCGTAGCTAGCTAGCTAG');
    });

    test('splits a FASTA header from the sequence body', () {
      final SequenceValidation result = SequenceValidator.validate(
        '>sp|P0DTC2|SPIKE_SARS2 Surface glycoprotein\n'
        'ATGCGTAGCT\n'
        'AGCTAGCTAG\n',
      );

      expect(result, isA<ValidSequence>());
      final ValidSequence valid = result as ValidSequence;
      expect(valid.fastaHeader, 'sp|P0DTC2|SPIKE_SARS2 Surface glycoprotein');
      // The header must not leak into the bases, or every count is wrong.
      expect(valid.bases, 'ATGCGTAGCTAGCTAGCTAG');
    });

    test('rejects a FASTA record that carries a header but no bases', () {
      final SequenceValidation result =
          SequenceValidator.validate('>header only\n');

      expect(result, isA<InvalidSequence>());
      expect(
        (result as InvalidSequence).message,
        contains('no sequence data'),
      );
    });

    test('accepts IUPAC ambiguity codes and gap characters', () {
      expect(
        SequenceValidator.validate('ATGCNNRYKM-.WSBDHV'),
        isA<ValidSequence>(),
      );
    });
  });
}
