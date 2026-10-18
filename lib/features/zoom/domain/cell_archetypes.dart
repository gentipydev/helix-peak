import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'anatomy_tables.dart';
import 'zoom_path.dart';

/// The shapes a cell is drawn in at the cell level, by what the cell is:
/// general morphology, the same for every gene whose path lands in that kind
/// of cell.
enum CellShape {
  /// An epithelial cell of no special shape: polygonal, central nucleus.
  epithelial,

  /// A liver cell: large and polygonal, rich in reticulum and mitochondria.
  hepatocyte,

  /// A secretory acinar cell: pyramidal, its nucleus low, its granules at
  /// the apex.
  acinar,

  /// An endocrine cell: rounded, packed with small dense-core granules.
  endocrine,

  /// A columnar cell crowned with cilia.
  ciliated,

  /// A flat cell lining a vessel: long and thin, its nucleus a lens.
  endothelial,

  /// A neuron: a round body with a large nucleus, dendrites and an axon.
  neuron,

  /// A glial cell: a small body with fine branching processes.
  glial,

  /// A stretch of a skeletal muscle fibre: striated, its nuclei at the rim.
  myofibre,

  /// A heart muscle cell: branched, striated, its nucleus central.
  cardiomyocyte,

  /// A smooth muscle or other spindle cell.
  spindle,

  /// A fat cell: one lipid droplet, its nucleus pressed to the rim.
  adipocyte,

  /// A nucleated red cell precursor, among the grown red cells it becomes.
  erythroid,

  /// A megakaryocyte: huge, its nucleus lobed, shedding platelets.
  megakaryocyte,

  /// A white blood cell of the marrow or the blood.
  leukocyte,

  /// A germ cell in meiosis: its chromosomes condensing in a large nucleus.
  germ,

  /// A cell in division's first stage: its chromatin condensing.
  dividing,

  /// A trophoblast of the placenta.
  trophoblast,
}

/// How far a kind of cell reaches from its nucleus, which the view at the
/// cell centres, as multiples of its half-size: across, either way, up and
/// down. What must be seen of it, so a neuron's axon, which runs on down out
/// of view, does not count, nor an erythroblast's island; and a muscle
/// fibre, which runs off both sides, reaches no distance across that counts.
/// Read off the outline the cell's scene draws, its nucleus included, and
/// held to it by cell_scene_test.
@immutable
final class CellReach {
  const CellReach(this.across, this.up, this.down);

  /// A fibre's: running off both sides of the view.
  const CellReach.runsOff(this.up, this.down) : across = null;

  final double? across;
  final double up;
  final double down;
}

/// How a kind of cell is drawn: its shape, how big it is, how big its
/// nucleus is, how far it reaches from its nucleus, and so how wide the view
/// is at the cell and at the nucleus.
@immutable
final class CellArchetype {
  const CellArchetype(
    this.shape, {
    required this.metres,
    required this.nucleus,
    required this.reach,
  });

  final CellShape shape;

  /// The cell's own size, its longest extent, in metres.
  final double metres;

  /// Its nucleus's diameter, in metres.
  final double nucleus;

  /// How far it reaches from its nucleus.
  final CellReach reach;

  /// How much of the view's width the cell spans across: seven tenths, so
  /// its parts read (the user's choice of 2026-10-18; it was about half).
  static const double fill = 0.7;

  /// How far above and below the middle of the view the cell may reach, as
  /// shares of its width: a phone's canvas at its squattest, 320 by 420, is
  /// 0.65 of its width either side of the middle; a row of names and the
  /// margin take 0.13 of that above, the scale bar 0.15 below.
  static const double roomAbove = 0.52;
  static const double roomBelow = 0.5;

  /// How wide the view is at the cell: the cell spanning [fill] of it, but
  /// where a cell taller than it is wide, or hanging below its nucleus,
  /// would then run past the room above or below its middle: there it is as
  /// big as that room lets it be.
  double get viewMetres {
    final double? across = reach.across;
    final double half = math.min(
      across == null ? double.infinity : fill / 2 / across,
      math.min(roomAbove / reach.up, roomBelow / reach.down),
    );
    return metres / 2 / half;
  }

  /// How wide the view is at the nucleus.
  double get nucleusViewMetres => nucleus * 1.5;
}

/// The reach of a round cell drawn as a blob about its nucleus.
const CellReach _round = CellReach(0.97, 0.9, 0.93);

const Map<CellShape, CellArchetype> _archetypes = <CellShape, CellArchetype>{
  CellShape.epithelial: CellArchetype(
    CellShape.epithelial,
    metres: 1.5e-5,
    nucleus: 7e-6,
    reach: _round,
  ),
  CellShape.hepatocyte: CellArchetype(
    CellShape.hepatocyte,
    metres: 2.5e-5,
    nucleus: 9e-6,
    reach: CellReach(1.07, 0.85, 0.97),
  ),
  CellShape.acinar: CellArchetype(
    CellShape.acinar,
    metres: 1.6e-5,
    nucleus: 6e-6,
    reach: CellReach(0.8, 1.06, 0.72),
  ),
  CellShape.endocrine: CellArchetype(
    CellShape.endocrine,
    metres: 1.3e-5,
    nucleus: 6e-6,
    reach: _round,
  ),
  CellShape.ciliated: CellArchetype(
    CellShape.ciliated,
    metres: 2e-5,
    nucleus: 6e-6,
    reach: CellReach(0.43, 1.21, 0.81),
  ),
  CellShape.endothelial: CellArchetype(
    CellShape.endothelial,
    metres: 3e-5,
    nucleus: 9e-6,
    reach: CellReach(1.01, 0.25, 0.24),
  ),
  CellShape.neuron: CellArchetype(
    CellShape.neuron,
    metres: 4e-5,
    nucleus: 1e-5,
    reach: CellReach(1.02, 1.01, 0.58),
  ),
  CellShape.glial: CellArchetype(
    CellShape.glial,
    metres: 2.5e-5,
    nucleus: 6e-6,
    reach: CellReach(0.49, 0.41, 0.33),
  ),
  CellShape.myofibre: CellArchetype(
    CellShape.myofibre,
    metres: 5e-5,
    nucleus: 9e-6,
    reach: CellReach.runsOff(0.12, 1.31),
  ),
  CellShape.cardiomyocyte: CellArchetype(
    CellShape.cardiomyocyte,
    metres: 6e-5,
    nucleus: 1e-5,
    reach: CellReach(1.1, 0.75, 0.36),
  ),
  CellShape.spindle: CellArchetype(
    CellShape.spindle,
    metres: 4e-5,
    nucleus: 8e-6,
    reach: CellReach(1, 0.22, 0.22),
  ),
  CellShape.adipocyte: CellArchetype(
    CellShape.adipocyte,
    metres: 6e-5,
    nucleus: 8e-6,
    reach: CellReach(1.01, 0.17, 1.84),
  ),
  CellShape.erythroid: CellArchetype(
    CellShape.erythroid,
    metres: 1.2e-5,
    nucleus: 7e-6,
    reach: _round,
  ),
  CellShape.megakaryocyte: CellArchetype(
    CellShape.megakaryocyte,
    metres: 5e-5,
    nucleus: 2e-5,
    reach: CellReach(1.05, 0.94, 1),
  ),
  CellShape.leukocyte: CellArchetype(
    CellShape.leukocyte,
    metres: 1.2e-5,
    nucleus: 7e-6,
    reach: _round,
  ),
  CellShape.germ: CellArchetype(
    CellShape.germ,
    metres: 1.8e-5,
    nucleus: 1e-5,
    reach: _round,
  ),
  CellShape.dividing: CellArchetype(
    CellShape.dividing,
    metres: 1.6e-5,
    nucleus: 9e-6,
    reach: _round,
  ),
  CellShape.trophoblast: CellArchetype(
    CellShape.trophoblast,
    metres: 3e-5,
    nucleus: 8e-6,
    reach: CellReach(1.1, 0.69, 0.8),
  ),
};

/// How a cell of [shape] is drawn.
CellArchetype archetypeFor(CellShape shape) => _archetypes[shape]!;

/// The shape of a cell the Atlas names, by its name where the name says
/// more than its class, then by its class: every one of the Atlas's fifteen
/// classes has a shape, so every cell type does.
CellShape shapeOfCell(String name, String? cellClass) {
  final String n = name.toLowerCase();
  bool has(String part) => n.contains(part);
  if (has('hepatocyte')) {
    return CellShape.hepatocyte;
  }
  if (has('erythro')) {
    return CellShape.erythroid;
  }
  if (has('megakaryocyte') || has('platelet')) {
    return CellShape.megakaryocyte;
  }
  if (has('adipocyte')) {
    return CellShape.adipocyte;
  }
  if (has('myonucle') || has('skeletal myocyte') || has('myosatellite')) {
    return CellShape.myofibre;
  }
  if (has('cardiomyocyte')) {
    return CellShape.cardiomyocyte;
  }
  if (has('acinar') || has('glandular') || has('chief') || has('lactating')) {
    return CellShape.acinar;
  }
  if (has('mitotic') || has('progenitor') || has('stem') ||
      has('transient amplifying')) {
    return CellShape.dividing;
  }
  if (has('endothelial')) {
    return CellShape.endothelial;
  }
  return switch (cellClass) {
    'Neuronal cells' => CellShape.neuron,
    'Glial cells' => CellShape.glial,
    'Endocrine cells' => CellShape.endocrine,
    'Squamous epithelial cells' => CellShape.epithelial,
    'Pigment cells' => CellShape.epithelial,
    'Ciliated cells' => CellShape.ciliated,
    'Specialized epithelial cells' => CellShape.epithelial,
    'Glandular epithelial cells' => CellShape.acinar,
    'Germ cells' => CellShape.germ,
    'Trophoblast cells' => CellShape.trophoblast,
    'Muscle cells' => CellShape.spindle,
    'Endothelial and mural cells' => CellShape.endothelial,
    'Mesenchymal cells' => CellShape.spindle,
    'Blood and immune cells' => CellShape.leukocyte,
    'Stem and proliferating cells' => CellShape.dividing,
    _ => CellShape.epithelial,
  };
}

/// The cell a tissue's own is drawn as, where the path names none that
/// lives in it: the cells its recipe is made of.
CellShape shapeOfTissue(TissueRecipe recipe) => switch (recipe) {
  TissueRecipe.acinar => CellShape.acinar,
  TissueRecipe.adipose => CellShape.adipocyte,
  TissueRecipe.alveolar => CellShape.epithelial,
  TissueRecipe.cardiac => CellShape.cardiomyocyte,
  TissueRecipe.choroidPlexus => CellShape.epithelial,
  TissueRecipe.endocrine => CellShape.endocrine,
  TissueRecipe.follicular => CellShape.epithelial,
  TissueRecipe.gastric => CellShape.acinar,
  TissueRecipe.glandular => CellShape.acinar,
  TissueRecipe.hepatic => CellShape.hepatocyte,
  TissueRecipe.intestinal => CellShape.ciliated,
  TissueRecipe.lymphoid => CellShape.leukocyte,
  TissueRecipe.marrow => CellShape.leukocyte,
  TissueRecipe.neural => CellShape.neuron,
  TissueRecipe.ovarian => CellShape.spindle,
  TissueRecipe.placental => CellShape.trophoblast,
  TissueRecipe.renal => CellShape.epithelial,
  TissueRecipe.retina => CellShape.neuron,
  TissueRecipe.seminiferous => CellShape.germ,
  TissueRecipe.skeletalMuscle => CellShape.myofibre,
  TissueRecipe.smoothMuscle => CellShape.spindle,
  TissueRecipe.squamous => CellShape.epithelial,
  TissueRecipe.urothelial => CellShape.epithelial,
  TissueRecipe.vascular => CellShape.endothelial,
};

/// The archetype the zoom draws [path]'s cell as: the cell it names, or,
/// where it names none that lives in its tissue, the tissue's own; where the
/// cell has no nucleus, the precursor it lands in instead.
CellArchetype archetypeOf(ZoomPath path) {
  final String? cell = path.cellType;
  final String? tissue = path.tissue;
  final TissueAnatomy? anatomy = tissue == null ? null : tissueAnatomy[tissue];
  final CellShape shape = cell != null
      ? shapeOfCell(path.landsIn?.cell ?? cell, path.cellClass)
      : anatomy != null
      ? shapeOfTissue(anatomy.recipe)
      : CellShape.epithelial;
  return archetypeFor(shape);
}

/// What a cell compartment is, where the Atlas finds a protein in it.
enum Compartment {
  nucleoplasm,
  nucleoli,
  nuclearMembrane,
  cytosol,
  plasmaMembrane,
  golgi,
  reticulum,
  vesicles,
  mitochondria,
  cytoskeleton,
  centrosome,
  junctions,
  lipidDroplets,
  sperm,
  division,
}

/// The compartment each of the Atlas's subcellular words is drawn in. Every
/// one of its 49 words has one.
const Map<String, Compartment> compartmentOf = <String, Compartment>{
  'Acrosome': Compartment.sperm,
  'Actin filaments': Compartment.cytoskeleton,
  'Aggresome': Compartment.cytosol,
  'Annulus': Compartment.sperm,
  'Basal body': Compartment.centrosome,
  'Calyx': Compartment.sperm,
  'Cell Junctions': Compartment.junctions,
  'Centriolar satellite': Compartment.centrosome,
  'Centrosome': Compartment.centrosome,
  'Cleavage furrow': Compartment.division,
  'Connecting piece': Compartment.sperm,
  'Cytokinetic bridge': Compartment.division,
  'Cytoplasmic bodies': Compartment.cytosol,
  'Cytosol': Compartment.cytosol,
  'End piece': Compartment.sperm,
  'Endoplasmic reticulum': Compartment.reticulum,
  'Endosomes': Compartment.vesicles,
  'Equatorial segment': Compartment.sperm,
  'Flagellar centriole': Compartment.sperm,
  'Focal adhesion sites': Compartment.junctions,
  'Golgi apparatus': Compartment.golgi,
  'Intermediate filaments': Compartment.cytoskeleton,
  'Kinetochore': Compartment.division,
  'Lipid droplets': Compartment.lipidDroplets,
  'Lysosomes': Compartment.vesicles,
  'Microtubule ends': Compartment.cytoskeleton,
  'Microtubules': Compartment.cytoskeleton,
  'Mid piece': Compartment.sperm,
  'Midbody': Compartment.division,
  'Midbody ring': Compartment.division,
  'Mitochondria': Compartment.mitochondria,
  'Mitotic chromosome': Compartment.division,
  'Mitotic spindle': Compartment.division,
  'Nuclear bodies': Compartment.nucleoplasm,
  'Nuclear membrane': Compartment.nuclearMembrane,
  'Nuclear speckles': Compartment.nucleoplasm,
  'Nucleoli': Compartment.nucleoli,
  'Nucleoli fibrillar center': Compartment.nucleoli,
  'Nucleoli rim': Compartment.nucleoli,
  'Nucleoplasm': Compartment.nucleoplasm,
  'Perinuclear theca': Compartment.sperm,
  'Peroxisomes': Compartment.vesicles,
  'Plasma membrane': Compartment.plasmaMembrane,
  'Primary cilium': Compartment.centrosome,
  'Primary cilium tip': Compartment.centrosome,
  'Primary cilium transition zone': Compartment.centrosome,
  'Principal piece': Compartment.sperm,
  'Rods & Rings': Compartment.cytosol,
  'Vesicles': Compartment.vesicles,
};
