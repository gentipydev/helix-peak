import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeak/core/theme/nucleotide_colors.dart';

void main() {
  group('NucleotideColors.forBase', () {
    const NucleotideColors palette = NucleotideColors.dark;

    test('maps each canonical base to its own colour', () {
      expect(palette.forBase('A'), palette.adenine);
      expect(palette.forBase('T'), palette.thymine);
      expect(palette.forBase('G'), palette.guanine);
      expect(palette.forBase('C'), palette.cytosine);
    });

    test('is case-insensitive', () {
      expect(palette.forBase('a'), palette.adenine);
      expect(palette.forBase('t'), palette.thymine);
      expect(palette.forBase('g'), palette.guanine);
      expect(palette.forBase('c'), palette.cytosine);
    });

    test('maps uracil onto thymine so RNA renders consistently', () {
      expect(palette.forBase('U'), palette.thymine);
      expect(palette.forBase('u'), palette.thymine);
    });

    test('falls back to the neutral colour for ambiguity and gap codes', () {
      // Real data contains these constantly; throwing here would make the
      // sequence view unrenderable rather than merely uncoloured.
      expect(palette.forBase('N'), palette.unknown);
      expect(palette.forBase('-'), palette.unknown);
      expect(palette.forBase('?'), palette.unknown);
      expect(palette.forBase(''), palette.unknown);
    });

    test('the four bases are mutually distinct', () {
      final Set<int> values = <int>{
        palette.adenine.toARGB32(),
        palette.thymine.toARGB32(),
        palette.guanine.toARGB32(),
        palette.cytosine.toARGB32(),
      };
      expect(values, hasLength(4));
    });

    test('the light palette differs from the dark one', () {
      // The dark values are too light to read on paper; if these ever match,
      // the light theme has silently become an inversion.
      expect(
        NucleotideColors.light.adenine,
        isNot(NucleotideColors.dark.adenine),
      );
    });
  });
}
