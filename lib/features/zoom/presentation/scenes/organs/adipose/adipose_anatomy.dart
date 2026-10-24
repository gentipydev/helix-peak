import 'dart:ui';

/// A block cut through the abdominal wall 5 cm to the body's right of the
/// navel, at its height, where abdominal fat is biopsied (the tool's
/// `SITE_BESIDE`), drawn from general anatomy in millimetres: x across the
/// block's front face from its left edge, the side away from the body's
/// middle, the figure facing the view, y down from the skin's surface, z
/// back into the block from the front face. Its front
/// face is a cut across the body, flat to the view, from the skin down
/// through the two layers of fat to the rectus abdominis; its top is the
/// skin's surface; its right side is a second cut, seen in shade.
///
/// What is measured:
/// - The subcutaneous tissue of the abdomen has a superficial adipose layer,
///   whose fibrous septa part its fat into polygonal-oval lobes (a mean
///   circularity of 0.856), a continuous membranous layer, 847 ± 295 µm
///   thick, and a deep adipose layer, whose septa run mostly obliquely and
///   horizontally and part it into large, flat lobes (circularity 0.473)
///   (Lancerotto et al. 2011, Surg Radiol Anat 33:835); the superficial
///   layer's septa are organised and compact, the deep layer's looser and
///   more widely spaced, the deep layer held between the subcutaneous
///   fascia above and the muscle's fascia below (Markman and Barton 1987,
///   Plast Reconstr Surg 80:248).
/// - The superficial septa, the retinacula cutis, are short, vertical and
///   dense, and tie the membranous layer to the skin; the deep ones are
///   rare, thin and oblique; the membranous layer is 391 µm thick in the
///   female lower abdomen on histology (Fede et al. 2025, Int J Mol Sci
///   26:1289, from the studies it reviews).
/// - By ultrasound at the abdomen of 300 women of normal weight, the
///   subcutaneous fat is 17.48 mm thick, its superficial layer 8.18 mm, and
///   the superficial layer 0.92 of the deep one; the muscle under it is
///   14.75 to 16.06 mm thick in women under 39 (Annunziata et al. 2025, J
///   Transl Med 23:236).
/// - The abdomen's skin is 2.29 mm thick by ultrasound (Sim et al. 2014,
///   Diabetes Metab J 38:120).
/// - Perforators of the deep inferior epigastric artery pass through the
///   rectus and its sheath to the skin's plexus; the superficial inferior
///   epigastric artery runs up toward the navel in the superficial fat
///   (Childs et al. 2023, Int J Environ Res Public Health 20:5100).
///
/// Drawing choices, measured by none of these: the block, 4 cm across and
/// 2.5 deep; the subcutaneous fat drawn as thick as the women's mean, its
/// superficial layer as thick as its own mean and the deep one the rest;
/// the membranous layer 0.6 mm, between the two measures; the rectus cut
/// 7 mm under its sheath; the size and lean
/// of the lobes in each layer and how far their septa stray; the rectus
/// sheath's thickness; where the vessels lie and how wide they are; the
/// rectus's fascicles.
abstract final class AdiposeAnatomy {
  // The block.

  /// How wide its front face is, and how far back into the wall its top
  /// and its side reach.
  static const double width = 40;
  static const double depth = 25;

  // The layers, down from the skin's surface: where each ends.

  /// The skin, and the epidermis in it.
  static const double epidermis = 0.1;
  static const double skin = 2.29;

  /// The subcutaneous fat, as thick as the women's mean, and its
  /// superficial layer, as thick as its own; the membranous layer between
  /// the two.
  static const double fat = 17.48;
  static const double superficial = 8.18;
  static const double membranous = 0.6;

  /// Where the superficial layer ends, and where the membranous layer and
  /// the deep layer do.
  static const double superficialEnd = skin + superficial;
  static const double membranousEnd = superficialEnd + membranous;
  static const double deepEnd = skin + fat;

  /// The anterior rectus sheath, and how much of the rectus abdominis under
  /// it the block keeps, a little under half its thickness.
  static const double sheath = 0.5;
  static const double rectus = 7;

  /// How deep the block's front face reaches.
  static const double faceDepth = deepEnd + sheath + rectus;

  // The lobes.

  /// The superficial layer's lobes: how far apart they lie across the face
  /// and down it, and how far each strays.
  static const double superficialAcross = 2.6;
  static const double superficialDown = 3.4;

  /// The deep layer's: wide and flat, their septa leaning.
  static const double deepAcross = 9;
  static const double deepDown = 2.9;
  static const double deepLean = 0.2;

  /// How far a lobe's middle strays from its lattice, a share of the way to
  /// the next.
  static const double stray = 0.3;

  /// A septum's breadth, in each layer.
  static const double superficialSeptum = 0.18;
  static const double deepSeptum = 0.14;

  // The vessels.

  /// The superficial inferior epigastric artery and vein, cut across in the
  /// superficial fat: where each lies, across and down, and its breadth.
  static const (Offset, double) epigastricArtery = (Offset(29.5, 8.2), 1.2);
  static const (Offset, double) epigastricVein = (Offset(32.5, 8.6), 2);

  /// A perforator, artery and vein, rising from the rectus through its
  /// sheath and the fat to the skin: across the face where it leaves the
  /// muscle and where it reaches the skin; each one's breadth.
  static const double perforatorFrom = 24;
  static const double perforatorTo = 21;
  static const double perforatorArtery = 0.7;
  static const double perforatorVein = 1;

  /// The rectus's fascicles, cut across: how far apart.
  static const double fascicle = 2.4;

  /// Where in the front face its tissue is sampled: in the superficial fat,
  /// low in it, a little left of the middle.
  static const Offset site = Offset(16, 8.6);
}
