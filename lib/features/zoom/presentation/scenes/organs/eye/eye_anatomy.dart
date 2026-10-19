/// The right eye cut level through its optic nerve and seen from above, as
/// Gray's and Netter's plates draw its horizontal section, drawn from
/// general anatomy: in millimetres, the cornea up, the temporal side to the
/// right. The origin is the middle of the globe, front to back and side to
/// side, where the body's circle of the eye has its middle; x runs to the
/// temple, y back.
///
/// The cut shows the coats: the sclera, the choroid and the retina, from
/// the ora serrata back to the optic disc, the retina thinning into the
/// fovea temporal of the disc; the cornea in front, the iris on the lens,
/// the ciliary body round the lens from the scleral spur back to the ora,
/// and the lens hung on its zonules. Behind, the optic nerve leaves through
/// the lamina cribrosa in its sheath, the central retinal artery and vein
/// in it; the medial and lateral recti run back from their insertions, and
/// the long posterior ciliary arteries forward between the sclera and the
/// choroid.
///
/// Sizes keep to what is measured. The globe is about 24 mm front to back
/// and across (Gray 1918). The cornea is 11.71 mm across (Rüfer et al.
/// 2005, Cornea 24:259), its front of radius 7.8, as Le Grand's schematic
/// eye has it, 0.52 mm thick in the middle and 0.67 at its edge (Maurice
/// 1969). The anterior chamber is 3.05 deep (Le Grand). The lens is 9.21 mm
/// across and 4.18 thick (Xue and Zou 2019, J Ophthalmol 8319027), its
/// front 1.7 times as flat as its back, as Le Grand's radii (10.2 and 6.0)
/// have it. The iris is 0.45 mm thick near its root and 0.60 at most (Wang
/// et al. 2011, Br J Ophthalmol 95:46).
///
/// The sclera is 0.53 mm thick at the limbus, 0.39 near the equator and
/// 0.9 to 1.0 by the optic nerve (Olsen et al. 1998, Am J Ophthalmol
/// 125:237). The choroid is 0.287 mm thick under the fovea and 0.145 at
/// 3 mm nasal of it (Margolis and Spaide 2009, Am J Ophthalmol 147:811),
/// and thinner in front than behind (Gray 1918). The retina is 0.32 mm
/// thick at the fovea's rim and 0.08 at the ora serrata. The fovea's floor
/// is 0.15 (Yamada 1969) and the fovea 1.5 mm from rim to rim (Polyak
/// 1941), all as Webvision gathers them (Kolb, Fernandez and Nelson). The
/// fovea lies 3.4 mm temporal of the disc's edge, and the disc is 1.75 mm
/// across (Webvision).
///
/// The ora serrata lies about 6 mm behind the limbus nasally and 7
/// temporally (EyeWiki, "Ora Serrata"). The ciliary body starts about 1 mm
/// behind the limbus, its pars plicata, where its processes are, the first
/// 2 mm of it (EyeWiki), sixty to eighty processes (Gray 1918), and the
/// ciliary muscle a band about 3 mm broad (Gray 1918).
/// The optic nerve enters 3 mm to the nasal side of the posterior pole
/// (Gray 1918). Behind the globe it is 2.76 mm across at 3 mm and 2.32 at
/// 8, and its sheath 5.10 and 4.38 (Watcharakorn et al. 2021, Sci Technol
/// Asia 26:167). The central retinal artery pierces its sheath about 10 mm
/// behind the eye (Hayreh 1960, Br J Ophthalmol 44:193). The long posterior
/// ciliary arteries pierce the sclera 3 to 4 mm to either side of the
/// nerve and run forward in the horizontal meridian (Radiopaedia). The
/// medial rectus inserts 5.5 mm behind the limbus and the lateral 6.9 (the
/// spiral of Tillaux), their bellies 4.1 and 3.4 mm thick (Rana et al.
/// 2022, Int Ophthalmol 42:3869).
abstract final class EyeAnatomy {
  /// How long the globe is from the cornea's apex to the back of the
  /// sclera, and how broad it is across.
  static const double length = 24;
  static const double breadth = 24;

  /// The cornea: how far across it is at the limbus, the radius of its
  /// front, and how thick it is in its middle and at its edge.
  static const double corneaAcross = 11.71;
  static const double corneaRadius = 7.8;
  static const double corneaMiddle = 0.52;
  static const double corneaEdge = 0.67;

  /// How deep the anterior chamber is, from the cornea's back to the lens.
  static const double chamber = 3.05;

  /// The lens: how far across and how thick it is, and how many times as
  /// flat its front is as its back.
  static const double lensAcross = 9.21;
  static const double lensThick = 4.18;
  static const double lensFlatter = 10.2 / 6.0;

  /// The iris: how thick it is near its root and at its thickest; the
  /// pupil, drawn 4 mm across.
  static const double irisRoot = 0.45;
  static const double irisMost = 0.60;
  static const double pupil = 4;

  /// The sclera: how thick it is at the limbus, at the equator and by the
  /// optic nerve.
  static const double scleraLimbus = 0.53;
  static const double scleraEquator = 0.39;
  static const double scleraNerve = 0.95;

  /// The choroid: how thick it is under the fovea, and at [choroidNasalAt]
  /// millimetres nasal of it.
  static const double choroidFovea = 0.287;
  static const double choroidNasal = 0.145;
  static const double choroidNasalAt = 3;

  /// The retina: how thick it is at the fovea's floor, at its rim and at
  /// the ora serrata; how far across the fovea is, rim to rim.
  static const double retinaFloor = 0.15;
  static const double retinaRim = 0.32;
  static const double retinaOra = 0.08;
  static const double fovea = 1.5;

  /// The optic disc: how far across it is, how far nasal of the posterior
  /// pole the nerve enters, and how far temporal of the disc's edge the
  /// fovea lies.
  static const double disc = 1.75;
  static const double nerveNasal = 3;
  static const double foveaFromDisc = 3.4;

  /// How far behind the limbus the ora serrata lies, nasally and
  /// temporally, and the ciliary body begins; how long its pars plicata
  /// is, and how many processes it has; how broad the ciliary muscle is.
  static const double oraNasal = 6;
  static const double oraTemporal = 7;
  static const double ciliaryFrom = 1;
  static const double plicata = 2;
  static const int processes = 70;
  static const double ciliaryMuscle = 3;

  /// The optic nerve behind the globe: across at [nerveNear] and
  /// [nerveFar] millimetres behind it, and its sheath there.
  static const double nerveNear = 3;
  static const double nerveFar = 8;
  static const double nerveNearAcross = 2.76;
  static const double nerveFarAcross = 2.32;
  static const double sheathNearAcross = 5.10;
  static const double sheathFarAcross = 4.38;

  /// How far behind the globe the central retinal artery and vein come
  /// into the nerve.
  static const double vesselsJoin = 10;

  /// How far to either side of the nerve the long posterior ciliary
  /// arteries pierce the sclera.
  static const double ciliaryArteries = 3.5;

  /// How far behind the limbus the medial and lateral recti insert, and how
  /// thick their bellies are.
  static const double medialInsertion = 5.5;
  static const double lateralInsertion = 6.9;
  static const double medialBelly = 4.1;
  static const double lateralBelly = 3.4;
}
