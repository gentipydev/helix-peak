import 'dart:ui';

import '../../tube_course.dart';

/// Smooth muscle as the anatomogram places it: the wall of the urinary
/// bladder, the detrusor, drawn whole, seen from the front in place as the
/// body shows it, its peritoneum and fat taken away so that its muscle
/// shows: the bundles of its outer layer running from the apex down over
/// the front to the neck, interlacing obliquely at the sides and ringing
/// the neck; a patch of that layer taken away low on the body's right,
/// where the middle layer's circular bundles show beneath; the urachus
/// rising from the apex; the ureters coming down to it behind, the urethra
/// leaving it below, and the vesical arteries ramifying over it, each cut
/// short. It is drawn from general anatomy in the bladder specimen's own
/// frame (`bladder_anatomy.dart`): millimetres of a bladder 100 mm across,
/// x across to the body's left, y down, from the middle of its outline's
/// box; the zoom's card gives smooth muscle 8 cm, so it is drawn at 0.8
/// of that bladder.
///
/// What is measured. After Gray (1918, pp. 1230-1233, read in the
/// archive.org text of the 20th edition): the muscular coat "consists of
/// three layers of unstriped muscular fibers: an external layer, composed
/// of fibers having for the most part a longitudinal arrangement; a middle
/// layer, in which the fibers are arranged, more or less, in a circular
/// manner; and an internal layer, in which the fibers have a general
/// longitudinal arrangement"; the external layer's fibers "pass, in a more
/// or less longitudinal manner, up the inferior surface of the bladder,
/// over its vertex, and then descend along its fundus", and "at the sides
/// of the bladder the fibers are arranged obliquely and intersect one
/// another. This layer has been named the Detrusor urinae muscle"; "the
/// fibers of the middle circular layer are very thinly and irregularly
/// scattered on the body of the organ, and, although to some extent placed
/// transversely to the long axis of the bladder, are for the most part
/// arranged obliquely. Toward the lower part of the bladder, around the
/// internal urethral orifice, they are disposed in a thick circular layer,
/// forming the Sphincter vesicae"; the apex is joined to the umbilicus by
/// the middle umbilical ligament, the urachus (p. 1228). The detrusor is
/// 1.2 mm thick in women and 1.4 mm in men on ultrasound from 250 mL on
/// (Oelke et al. 2006, Neurourol Urodyn 25:308), and the whole wall 2.0 ±
/// 0.4 mm at 338 ± 82 mL (Kanyilmaz et al. 2013, J Res Med Sci 18:103).
/// The Human Protein Atlas's single cell type that lives in smooth muscle
/// is the smooth muscle cell, which is why the whole muscle is where the
/// zoom's cell lives, whatever the gene.
///
/// Drawing choices, measured by none of these: the bladder's outline, its
/// ureters and arteries the bladder specimen's, at 0.8 of its size, a
/// bladder less full, its urethra cut 10 mm below the neck; thirty-one bundles in the outer layer, laid as
/// the meridians of the bladder's form are seen from the front, so that
/// they lie about 5 mm apart over the front and bunch toward the sides,
/// each wandering a little, and none drawn where they would lie under 2
/// mm apart toward the apex and the neck; eight oblique bundles a side;
/// three rings round the neck for the sphincter; the patch 10 by 18 mm,
/// cut along two bundles and across between them, the circular layer's
/// bundles in it 2 to 3 mm apart and a little oblique; the urachus 3 mm
/// across at the apex, fading out above; the arteries' branches running 9
/// mm over the wall; the place the body goes in, on the front wall at the
/// bladder specimen's site.
abstract final class DetrusorAnatomy {
  /// How many bundles the outer layer is drawn with across the front, from
  /// one side round to the other (an odd number, so that one runs down the
  /// middle and the site lies between two), and how far apart two must lie
  /// for both to be drawn.
  static const int bundles = 31;
  static const double bundleLeast = 2.2;

  /// How far in from the silhouette the outermost bundle lies, a share of
  /// the half-width.
  static const double bundleEdge = 0.96;

  /// How far a bundle wanders to either side at most, and the wavelength
  /// it wanders by.
  static const double wander = 0.35;
  static const double wave = 18;

  /// The oblique bundles at the sides: each from a point on the silhouette
  /// at these heights, running in and down by [obliqueRun] and
  /// [obliqueDrop], and a second from each running in and up.
  static const List<double> obliqueAt = <double>[-18, -6, 6, 18];
  static const double obliqueRun = 14;
  static const double obliqueDrop = 9;

  /// The sphincter's rings round the neck: across the bladder at these
  /// heights, each sagging this far at its middle, this far in from the
  /// silhouette.
  static const List<double> rings = <double>[27, 30, 33];
  static const double ringSag = 1;
  static const double ringIn = 1.5;

  /// The patch where the outer layer is taken away, low on the body's
  /// right: between these two bundles (shares of the half-width, toward
  /// the body's left) and these heights.
  static const double patchFrom = -0.78;
  static const double patchTo = -0.42;
  static const double patchTop = 3;
  static const double patchBottom = 21;

  /// The circular layer's bundles in the patch: at these heights at its
  /// middle, each rising toward the body's side by this much per
  /// millimetre, kept this far in from the patch's edges.
  static const List<double> circular = <double>[
    4.6,
    7.2,
    10.1,
    12.4,
    15.3,
    17.9,
    20.0,
  ];
  static const double circularSlant = 0.1;
  static const double circularIn = 0.8;

  /// The urethra, from inside the neck down to where it is cut short: a
  /// little shorter than the bladder specimen's, this bladder being the
  /// smaller.
  static const AnatomyTube urethra = AnatomyTube(
    <Offset>[Offset(0, 33), Offset(0, 40), Offset(0, 47)],
    <double>[3, 3, 3],
    cutEnd: true,
  );

  /// The urachus, from the apex up toward the navel, fading out above.
  static const AnatomyTube urachus = AnatomyTube(
    <Offset>[Offset(0, -36.5), Offset(0.3, -47), Offset(0.7, -60)],
    <double>[1.6, 1.3, 1.0],
    fadeOut: 10,
  );

  /// How far the arteries' small branches run over the wall from its
  /// edge, and over how much of that they fade into it.
  static const double branchOver = 9;
  static const double branchFade = 6;

  // Where the parts are named.

  /// The circular layer at the patch's middle; the urachus a little above
  /// the apex; the sphincter on its middle ring, toward the body's left.
  static const double circularNameAt = -0.6;
  static const double circularNameY = 12;
  static const Offset urachusName = Offset(0.2, -45);
  static const Offset sphincterName = Offset(18, 30);
}
