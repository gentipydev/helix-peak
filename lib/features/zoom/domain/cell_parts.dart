import 'package:flutter/foundation.dart';

import 'cell_archetypes.dart';

/// A part of a cell the zoom draws at the cell, and may name: what tells
/// one kind of cell from another at the scale a cell is seen whole.
enum CellPart {
  secretoryGranules('secretory granules'),
  roughEr('rough ER'),
  golgi('Golgi'),
  mitochondria('mitochondria'),
  lysosomes('lysosomes'),
  vesicles('vesicles'),
  centrioles('centrosome'),
  nisslBodies('Nissl bodies'),
  dendrites('dendrites'),
  axon('axon'),
  axonHillock('axon hillock'),
  neurofilaments('neurofilaments');

  const CellPart(this.word);

  /// The part as it is named on the canvas: lower case, but for a name
  /// that is a person's (Golgi, Nissl), as a reader in the field writes it.
  final String word;
}

/// What a kind of cell is drawn with at the cell, and what of it is named.
@immutable
final class CellRecipe {
  const CellRecipe({required this.drawn, required this.named});

  /// The parts drawn. A cell with none is drawn as it was before its kind
  /// had a recipe.
  final List<CellPart> drawn;

  /// The parts named, the first given room first: at most four, each one
  /// drawn, the ones that tell the kind apart.
  final List<CellPart> named;
}

const CellRecipe _none = CellRecipe(drawn: <CellPart>[], named: <CellPart>[]);

const Map<CellShape, CellRecipe> _recipes = <CellShape, CellRecipe>{
  // A secretory endocrine cell, as a beta cell is: packed with small
  // dense-core granules in pale halos, with the rough ER and the Golgi that
  // make them.
  CellShape.endocrine: CellRecipe(
    drawn: <CellPart>[
      CellPart.roughEr,
      CellPart.golgi,
      CellPart.mitochondria,
      CellPart.lysosomes,
      CellPart.vesicles,
      CellPart.secretoryGranules,
      CellPart.centrioles,
    ],
    named: <CellPart>[
      CellPart.secretoryGranules,
      CellPart.golgi,
      CellPart.roughEr,
      CellPart.mitochondria,
    ],
  ),
  // A neuron: its dendrites and its one axon, leaving from a hillock that
  // has no Nissl bodies, the rough ER of its body and dendrites.
  CellShape.neuron: CellRecipe(
    drawn: <CellPart>[
      CellPart.dendrites,
      CellPart.axon,
      CellPart.axonHillock,
      CellPart.neurofilaments,
      CellPart.nisslBodies,
      CellPart.golgi,
      CellPart.mitochondria,
      CellPart.lysosomes,
      CellPart.vesicles,
    ],
    named: <CellPart>[
      CellPart.dendrites,
      CellPart.axon,
      CellPart.axonHillock,
      CellPart.nisslBodies,
    ],
  ),
};

/// What a cell of [shape] is drawn with at the cell.
CellRecipe recipeOf(CellShape shape) => _recipes[shape] ?? _none;

/// The part the Atlas's subcellular [word] is in, where [recipe] draws one,
/// so a protein the Atlas finds there glows in it: the rough ER of a
/// neuron is its Nissl bodies; vesicles are a secretory cell's granules.
CellPart? partOfWord(String word, CellRecipe recipe) {
  CellPart? drawn(List<CellPart> parts) {
    for (final CellPart part in parts) {
      if (recipe.drawn.contains(part)) {
        return part;
      }
    }
    return null;
  }

  return switch (word) {
    'Golgi apparatus' => drawn(<CellPart>[CellPart.golgi]),
    'Endoplasmic reticulum' => drawn(<CellPart>[
      CellPart.roughEr,
      CellPart.nisslBodies,
    ]),
    'Mitochondria' => drawn(<CellPart>[CellPart.mitochondria]),
    'Vesicles' => drawn(<CellPart>[
      CellPart.secretoryGranules,
      CellPart.vesicles,
    ]),
    'Lysosomes' => drawn(<CellPart>[CellPart.lysosomes]),
    'Endosomes' ||
    'Peroxisomes' ||
    'Lipid droplets' => drawn(<CellPart>[CellPart.vesicles]),
    _ => null,
  };
}

/// The parts [recipe] names, less those the protein's own name already
/// names, the Atlas's [main] words being where it is: a fact is said once.
List<CellPart> partsToName(CellRecipe recipe, List<String> main) {
  final Set<CellPart> said = <CellPart>{
    for (final String word in main) ?partOfWord(word, recipe),
  };
  return <CellPart>[
    for (final CellPart part in recipe.named)
      if (!said.contains(part)) part,
  ];
}
