import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/features/zoom/domain/cell_archetypes.dart';
import 'package:helixpeek/features/zoom/domain/cell_parts.dart';

/// The Atlas's words whose compartment is a part a cell draws: a protein
/// found there glows in it.
const List<String> _organelleWords = <String>[
  'Golgi apparatus',
  'Endoplasmic reticulum',
  'Mitochondria',
  'Vesicles',
  'Lysosomes',
  'Endosomes',
  'Peroxisomes',
  'Lipid droplets',
];

void main() {
  test('a cell names at most four of its parts, each of them drawn, none '
      'twice', () {
    for (final CellShape shape in CellShape.values) {
      final CellRecipe recipe = recipeOf(shape);
      expect(recipe.named.length, lessThanOrEqualTo(4), reason: shape.name);
      expect(recipe.named.toSet(), hasLength(recipe.named.length));
      for (final CellPart part in recipe.named) {
        expect(recipe.drawn, contains(part), reason: '${shape.name} $part');
      }
    }
  });

  test('a beta cell names its granules, Golgi, rough ER and mitochondria; a '
      'neuron its dendrites, axon, hillock and Nissl bodies', () {
    expect(recipeOf(CellShape.endocrine).named, <CellPart>[
      CellPart.secretoryGranules,
      CellPart.golgi,
      CellPart.roughEr,
      CellPart.mitochondria,
    ]);
    expect(recipeOf(CellShape.neuron).named, <CellPart>[
      CellPart.dendrites,
      CellPart.axon,
      CellPart.axonHillock,
      CellPart.nisslBodies,
    ]);
  });

  test('every organelle the Atlas names has a part to glow in, in every cell '
      'drawn part by part', () {
    for (final CellShape shape in CellShape.values) {
      final CellRecipe recipe = recipeOf(shape);
      if (recipe.drawn.isEmpty) {
        continue;
      }
      for (final String word in _organelleWords) {
        final CellPart? part = partOfWord(word, recipe);
        expect(part, isNotNull, reason: '${shape.name}: $word');
        expect(recipe.drawn, contains(part), reason: '${shape.name}: $word');
      }
    }
  });

  test('each word glows in its own part: a neuron\'s rough ER is its Nissl '
      'bodies, a secretory cell\'s vesicles its granules, and a lysosome is '
      'never a granule', () {
    final CellRecipe beta = recipeOf(CellShape.endocrine);
    final CellRecipe neuron = recipeOf(CellShape.neuron);
    expect(partOfWord('Endoplasmic reticulum', beta), CellPart.roughEr);
    expect(partOfWord('Endoplasmic reticulum', neuron), CellPart.nisslBodies);
    expect(partOfWord('Vesicles', beta), CellPart.secretoryGranules);
    expect(partOfWord('Vesicles', neuron), CellPart.vesicles);
    expect(partOfWord('Lysosomes', beta), CellPart.lysosomes);
    expect(partOfWord('Peroxisomes', beta), CellPart.vesicles);
    expect(partOfWord('Cytosol', beta), isNull);
    expect(partOfWord('Nucleoplasm', neuron), isNull);
  });

  test('a part the protein\'s own name says is not named again', () {
    final CellRecipe beta = recipeOf(CellShape.endocrine);
    // Glucagon's: the Atlas finds it in the endoplasmic reticulum.
    expect(partsToName(beta, <String>['Endoplasmic reticulum']), <CellPart>[
      CellPart.secretoryGranules,
      CellPart.golgi,
      CellPart.mitochondria,
    ]);
    expect(
      partsToName(beta, <String>['Golgi apparatus', 'Cytosol']),
      <CellPart>[
        CellPart.secretoryGranules,
        CellPart.roughEr,
        CellPart.mitochondria,
      ],
    );
    expect(partsToName(beta, <String>[]), beta.named);
    // A neuron's rough ER is its Nissl bodies.
    expect(
      partsToName(recipeOf(CellShape.neuron), <String>[
        'Endoplasmic reticulum',
      ]),
      isNot(contains(CellPart.nisslBodies)),
    );
  });

  test('each part is named as the field writes it', () {
    expect(CellPart.golgi.word, 'Golgi');
    expect(CellPart.nisslBodies.word, 'Nissl bodies');
    expect(CellPart.roughEr.word, 'rough ER');
    for (final CellPart part in CellPart.values) {
      final String first = part.word[0];
      expect(
        first == first.toLowerCase() ||
            part == CellPart.golgi ||
            part == CellPart.nisslBodies,
        isTrue,
        reason: part.word,
      );
    }
  });
}
