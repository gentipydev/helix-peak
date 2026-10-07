import 'package:flutter/foundation.dart';

/// Which figure a tissue belongs to: one that every body has, or one of a
/// female or a male body only.
enum BodySex { either, female, male }

/// The organ a tissue is drawn as, at the organ level.
enum OrganKind {
  adipose,
  adrenal,
  bladder,
  boneMarrow,
  brain,
  breast,
  cervix,
  epididymis,
  esophagus,
  eye,
  fallopianTube,
  gallbladder,
  heart,
  intestine,
  kidney,
  liver,
  lung,
  lymphNode,
  ovary,
  pancreas,
  parathyroid,
  pituitary,
  placenta,
  prostate,
  salivaryGland,
  seminalVesicle,
  skeletalMuscle,
  skin,
  smoothMuscle,
  stomach,
  testis,
  thyroid,
  tongue,
  uterus,
  vagina,
  vessel,
}

/// How a tissue's cells are laid out under the microscope, at the tissue
/// level.
enum TissueRecipe {
  acinar,
  adipose,
  alveolar,
  cardiac,
  choroidPlexus,
  endocrine,
  follicular,
  gastric,
  glandular,
  hepatic,
  intestinal,
  lymphoid,
  marrow,
  neural,
  ovarian,
  placental,
  renal,
  retina,
  seminiferous,
  skeletalMuscle,
  smoothMuscle,
  squamous,
  urothelial,
  vascular,
}

/// How one of the Atlas's consensus tissues is drawn: the organ it is, how
/// big that organ is, the anatomogram part it is drawn from, whose body has
/// it, and the recipe its cells are laid out by. General anatomy, not any
/// gene's.
@immutable
final class TissueAnatomy {
  const TissueAnatomy({
    required this.organ,
    required this.metres,
    required this.uberon,
    required this.recipe,
    this.inBrain,
    this.sex = BodySex.either,
  });

  final OrganKind organ;

  /// The organ's longest extent, in metres: the organ level shows it whole.
  final double metres;

  /// The part of the anatomogram's standing figure it is found by, by
  /// UBERON id.
  final String uberon;

  /// For a tissue of the brain, the part of the anatomogram's brain it is:
  /// the organ level shows the brain cut down its middle, with this lit.
  final String? inBrain;

  final TissueRecipe recipe;
  final BodySex sex;
}

/// Every consensus tissue the Atlas names (version 25.1), by its own
/// lower-case name. Where the anatomogram has no part of its own for a
/// tissue, the part that holds it stands in: the choroid plexus lies in the
/// brain's lateral ventricle, the parathyroid glands behind the thyroid, and
/// the consensus "lymphoid tissue" is drawn as a lymph node.
const Map<String, TissueAnatomy> tissueAnatomy = <String, TissueAnatomy>{
  'adipose tissue': TissueAnatomy(
    organ: OrganKind.adipose,
    metres: 0.2,
    uberon: 'UBERON_0001013',
    recipe: TissueRecipe.adipose,
  ),
  'adrenal gland': TissueAnatomy(
    organ: OrganKind.adrenal,
    metres: 0.05,
    uberon: 'UBERON_0002369',
    recipe: TissueRecipe.endocrine,
  ),
  'blood vessel': TissueAnatomy(
    organ: OrganKind.vessel,
    metres: 0.12,
    uberon: 'UBERON_0001981',
    recipe: TissueRecipe.vascular,
  ),
  'bone marrow': TissueAnatomy(
    organ: OrganKind.boneMarrow,
    metres: 0.45,
    uberon: 'UBERON_0002371',
    recipe: TissueRecipe.marrow,
  ),
  'brain': TissueAnatomy(
    organ: OrganKind.brain,
    metres: 0.17,
    uberon: 'UBERON_0000955',
    inBrain: 'UBERON_0000956',
    recipe: TissueRecipe.neural,
  ),
  'breast': TissueAnatomy(
    organ: OrganKind.breast,
    metres: 0.15,
    uberon: 'UBERON_0000310',
    recipe: TissueRecipe.glandular,
  ),
  'cervix': TissueAnatomy(
    organ: OrganKind.cervix,
    metres: 0.04,
    uberon: 'UBERON_0000002',
    recipe: TissueRecipe.squamous,
    sex: BodySex.female,
  ),
  'choroid plexus': TissueAnatomy(
    organ: OrganKind.brain,
    metres: 0.17,
    uberon: 'UBERON_0000955',
    inBrain: 'UBERON_0002285',
    recipe: TissueRecipe.choroidPlexus,
  ),
  'endometrium': TissueAnatomy(
    organ: OrganKind.uterus,
    metres: 0.08,
    uberon: 'UBERON_0001295',
    recipe: TissueRecipe.glandular,
    sex: BodySex.female,
  ),
  'epididymis': TissueAnatomy(
    organ: OrganKind.epididymis,
    metres: 0.05,
    uberon: 'UBERON_0001301',
    recipe: TissueRecipe.glandular,
    sex: BodySex.male,
  ),
  'esophagus': TissueAnatomy(
    organ: OrganKind.esophagus,
    metres: 0.25,
    uberon: 'UBERON_0001043',
    recipe: TissueRecipe.squamous,
  ),
  'fallopian tube': TissueAnatomy(
    organ: OrganKind.fallopianTube,
    metres: 0.11,
    uberon: 'UBERON_0003889',
    recipe: TissueRecipe.glandular,
    sex: BodySex.female,
  ),
  'gallbladder': TissueAnatomy(
    organ: OrganKind.gallbladder,
    metres: 0.09,
    uberon: 'UBERON_0002110',
    recipe: TissueRecipe.glandular,
  ),
  'heart muscle': TissueAnatomy(
    organ: OrganKind.heart,
    metres: 0.13,
    uberon: 'UBERON_0000948',
    recipe: TissueRecipe.cardiac,
  ),
  'intestine': TissueAnatomy(
    organ: OrganKind.intestine,
    metres: 0.35,
    uberon: 'UBERON_0002108',
    recipe: TissueRecipe.intestinal,
  ),
  'kidney': TissueAnatomy(
    organ: OrganKind.kidney,
    metres: 0.12,
    uberon: 'UBERON_0002113',
    recipe: TissueRecipe.renal,
  ),
  'liver': TissueAnatomy(
    organ: OrganKind.liver,
    metres: 0.22,
    uberon: 'UBERON_0002107',
    recipe: TissueRecipe.hepatic,
  ),
  'lung': TissueAnatomy(
    organ: OrganKind.lung,
    metres: 0.25,
    uberon: 'UBERON_0002048',
    recipe: TissueRecipe.alveolar,
  ),
  'lymphoid tissue': TissueAnatomy(
    organ: OrganKind.lymphNode,
    metres: 0.02,
    uberon: 'UBERON_0000029',
    recipe: TissueRecipe.lymphoid,
  ),
  'ovary': TissueAnatomy(
    organ: OrganKind.ovary,
    metres: 0.04,
    uberon: 'UBERON_0000992',
    recipe: TissueRecipe.ovarian,
    sex: BodySex.female,
  ),
  'pancreas': TissueAnatomy(
    organ: OrganKind.pancreas,
    metres: 0.16,
    uberon: 'UBERON_0001264',
    recipe: TissueRecipe.acinar,
  ),
  'parathyroid gland': TissueAnatomy(
    organ: OrganKind.parathyroid,
    metres: 0.006,
    uberon: 'UBERON_0002046',
    recipe: TissueRecipe.endocrine,
  ),
  'pituitary gland': TissueAnatomy(
    organ: OrganKind.pituitary,
    metres: 0.012,
    uberon: 'UBERON_0000007',
    recipe: TissueRecipe.endocrine,
  ),
  'placenta': TissueAnatomy(
    organ: OrganKind.placenta,
    metres: 0.22,
    uberon: 'UBERON_0001987',
    recipe: TissueRecipe.placental,
    sex: BodySex.female,
  ),
  'prostate': TissueAnatomy(
    organ: OrganKind.prostate,
    metres: 0.04,
    uberon: 'UBERON_0002367',
    recipe: TissueRecipe.glandular,
    sex: BodySex.male,
  ),
  'retina': TissueAnatomy(
    organ: OrganKind.eye,
    metres: 0.024,
    uberon: 'UBERON_0000966',
    recipe: TissueRecipe.retina,
  ),
  'salivary gland': TissueAnatomy(
    organ: OrganKind.salivaryGland,
    metres: 0.06,
    uberon: 'UBERON_0001044',
    recipe: TissueRecipe.acinar,
  ),
  'seminal vesicle': TissueAnatomy(
    organ: OrganKind.seminalVesicle,
    metres: 0.05,
    uberon: 'UBERON_0000998',
    recipe: TissueRecipe.glandular,
    sex: BodySex.male,
  ),
  'skeletal muscle': TissueAnatomy(
    organ: OrganKind.skeletalMuscle,
    metres: 0.35,
    uberon: 'UBERON_0001134',
    recipe: TissueRecipe.skeletalMuscle,
  ),
  'skin': TissueAnatomy(
    organ: OrganKind.skin,
    metres: 0.08,
    uberon: 'UBERON_0000014',
    recipe: TissueRecipe.squamous,
  ),
  'smooth muscle': TissueAnatomy(
    organ: OrganKind.smoothMuscle,
    metres: 0.08,
    uberon: 'UBERON_0001135',
    recipe: TissueRecipe.smoothMuscle,
  ),
  'stomach': TissueAnatomy(
    organ: OrganKind.stomach,
    metres: 0.25,
    uberon: 'UBERON_0000945',
    recipe: TissueRecipe.gastric,
  ),
  'testis': TissueAnatomy(
    organ: OrganKind.testis,
    metres: 0.05,
    uberon: 'UBERON_0000473',
    recipe: TissueRecipe.seminiferous,
    sex: BodySex.male,
  ),
  'thyroid gland': TissueAnatomy(
    organ: OrganKind.thyroid,
    metres: 0.06,
    uberon: 'UBERON_0002046',
    recipe: TissueRecipe.follicular,
  ),
  'tongue': TissueAnatomy(
    organ: OrganKind.tongue,
    metres: 0.1,
    uberon: 'UBERON_0001723',
    recipe: TissueRecipe.skeletalMuscle,
  ),
  'urinary bladder': TissueAnatomy(
    organ: OrganKind.bladder,
    metres: 0.1,
    uberon: 'UBERON_0001255',
    recipe: TissueRecipe.urothelial,
  ),
  'vagina': TissueAnatomy(
    organ: OrganKind.vagina,
    metres: 0.09,
    uberon: 'UBERON_0000996',
    recipe: TissueRecipe.squamous,
    sex: BodySex.female,
  ),
};

/// Where each chromosome's territory is drawn in a nucleus, from its centre
/// (0) to its edge (1): gene-dense chromosomes inward, gene-poor ones at the
/// rim, in the order Boyle et al. 2001 (Hum Mol Genet 10:211) and Croft et
/// al. 1999 (J Cell Biol 145:1119) measured them. The values place
/// territories for drawing and are not measurements; a general fact about
/// nuclei, not about any gene.
const Map<String, double> territoryRadius = <String, double>{
  '1': 0.48,
  '2': 0.66,
  '3': 0.64,
  '4': 0.74,
  '5': 0.68,
  '6': 0.62,
  '7': 0.66,
  '8': 0.70,
  '9': 0.56,
  '10': 0.58,
  '11': 0.52,
  '12': 0.56,
  '13': 0.72,
  '14': 0.54,
  '15': 0.50,
  '16': 0.40,
  '17': 0.36,
  '18': 0.78,
  '19': 0.28,
  '20': 0.44,
  '21': 0.52,
  '22': 0.38,
  'X': 0.70,
  'Y': 0.62,
};

/// How long each chromosome is on GRCh38, in millions of base pairs: a
/// territory's size in the nucleus follows how much DNA it holds. General,
/// the same for every gene.
const Map<String, double> chromosomeMegabases = <String, double>{
  '1': 248.96,
  '2': 242.19,
  '3': 198.30,
  '4': 190.21,
  '5': 181.54,
  '6': 170.81,
  '7': 159.35,
  '8': 145.14,
  '9': 138.39,
  '10': 133.80,
  '11': 135.09,
  '12': 133.28,
  '13': 114.36,
  '14': 107.04,
  '15': 101.99,
  '16': 90.34,
  '17': 83.26,
  '18': 80.37,
  '19': 58.62,
  '20': 64.44,
  '21': 46.71,
  '22': 50.82,
  'X': 156.04,
  'Y': 57.23,
};

/// The chromosomes whose short arms carry the genes for ribosomal RNA,
/// which gather round the nucleolus: the five acrocentrics.
const Set<String> acrocentric = <String>{'13', '14', '15', '21', '22'};

