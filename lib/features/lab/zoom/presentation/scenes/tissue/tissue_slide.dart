import 'dart:ui';

import '../../../domain/anatomy_tables.dart';
import '../../../domain/cell_archetypes.dart';
import '../contour.dart';
import 'recipes_bulk.dart';
import 'recipes_glands.dart';
import 'recipes_linings.dart';
import 'slide_builder.dart';

/// What a part of a slide stained with haematoxylin and eosin is drawn in.
/// A layer draws its inks in this order.
enum SlideInk {
  /// The lamp's own light, laid over what lies beneath: a space cut
  /// through it.
  lamp,

  /// Eosin, from the palest matrix to the deepest cytoplasm.
  eosin0,
  eosin1,
  eosin2,
  eosin3,

  /// Cytoplasm that takes haematoxylin as well: rich in ribosomes.
  basophil,

  /// Fine stripes laid over cytoplasm: a muscle fibre's striations.
  stria,

  /// The cells' borders, stroked thin.
  border,

  /// Fibres of the matrix, cilia, tails: stroked thin.
  fibre,

  /// What takes no stain, with a rim: lumens, fat, vessels.
  clear,

  /// Nuclei, from a pale one with its chromatin open to a dense dark one.
  nucleus0,
  nucleus1,
  nucleus2,

  /// Red cells.
  blood,
}

/// One layer of a slide: drawn whole over the layers before it, its inks in
/// [SlideInk]'s order.
final class SlideLayer {
  final Map<SlideInk, Path> _paths = <SlideInk, Path>{};

  /// The path [ink] is drawn from in this layer, to add to.
  Path of(SlideInk ink) => _paths.putIfAbsent(ink, Path.new);

  /// What is drawn in [ink] in this layer, or null where nothing is.
  Path? operator [](SlideInk ink) => _paths[ink];
}

/// A tissue as a section stained with haematoxylin and eosin shows it, laid
/// out once, in micrometres from the middle of the field: cytoplasm and
/// matrix in eosin's pinks, nuclei in haematoxylin's purples, lumens, fat and
/// vessels the lamp's own light, and red cells in the vessels.
///
/// Every slide is made by one engine ([SlideBuilder]) from a recipe for the
/// tissue's architecture, the same for every gene whose path goes there. The
/// zoom's own cell sits at the origin, in the outline the cell's scene draws
/// it in, and the recipe lays the tissue so that it belongs where it sits:
/// an acinar cell at the base of an acinus, a hepatocyte in a plate.
final class TissueSlide {
  TissueSlide._();

  /// The layers, in the order they are drawn: what lies under the tissue's
  /// cells, the cells, what is laid over them, what is laid over that, and
  /// the zoom's own cell.
  static const int ground = 0;
  static const int tissue = 1;
  static const int over = 2;
  static const int top = 3;
  static const int own = 4;

  final List<SlideLayer> layers = List<SlideLayer>.generate(
    5,
    (_) => SlideLayer(),
  );

  /// Lays the slide for [recipe] in a round field of [field] micrometres'
  /// radius: the zoom's cell [target], with [targetNucleus], at the origin,
  /// both in micrometres, and the kind of cell it is, [shape].
  factory TissueSlide.of(
    TissueRecipe recipe, {
    required double field,
    required CellShape shape,
    required Contour target,
    required Contour targetNucleus,
    int seed = 1,
  }) {
    final TissueSlide slide = TissueSlide._();
    final SlideBuilder b = SlideBuilder(
      slide,
      field: field,
      shape: shape,
      target: target,
      targetNucleus: targetNucleus,
      seed: seed,
    );
    switch (recipe) {
      case TissueRecipe.acinar:
        if (shape == CellShape.endocrine) {
          b.islet();
        } else if (shape == CellShape.epithelial) {
          b.ducts();
        } else {
          b.acini();
        }
      case TissueRecipe.hepatic:
        b.liver();
      case TissueRecipe.endocrine:
        b.cords();
      case TissueRecipe.follicular:
        b.follicles();
      case TissueRecipe.gastric:
        b.glands(kidney: false);
      case TissueRecipe.renal:
        b.glands(kidney: true);
      case TissueRecipe.seminiferous:
        b.tubules();
      case TissueRecipe.choroidPlexus:
        b.fronds(placenta: false);
      case TissueRecipe.placental:
        b.fronds(placenta: true);
      case TissueRecipe.glandular:
        b.folds(villi: false);
      case TissueRecipe.intestinal:
        b.folds(villi: true);
      case TissueRecipe.squamous:
        b.stratified(umbrella: false);
      case TissueRecipe.urothelial:
        b.stratified(umbrella: true);
      case TissueRecipe.alveolar:
        b.alveoli();
      case TissueRecipe.lymphoid:
        b.lymphNode();
      case TissueRecipe.vascular:
        b.vesselWall();
      case TissueRecipe.marrow:
        b.marrow(island: shape == CellShape.erythroid);
      case TissueRecipe.skeletalMuscle:
        b.muscle(heart: false);
      case TissueRecipe.cardiac:
        b.muscle(heart: true);
      case TissueRecipe.neural:
        b.greyMatter();
      case TissueRecipe.retina:
        b.retina();
      case TissueRecipe.adipose:
        b.fat();
      case TissueRecipe.smoothMuscle:
        b.spindles(whorled: false);
      case TissueRecipe.ovarian:
        b.spindles(whorled: true);
    }
    return slide;
  }
}
