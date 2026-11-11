/// Every number the lungs' look is tuned by, in one place. Lengths are in
/// millimetres of the real lungs unless they say otherwise; the anatomy
/// itself is in `lung_anatomy.dart`, and the light is the zoom's one lamp
/// (`SpecimenLamp.zoom`), the other specimens'.
///
/// The look is a fresh specimen's, in deep tones that stand out among the
/// body's faint parts round it: the left lung cut open from front to back,
/// its cut face flat, where the zoom's cell lives in the mark (its
/// alveoli, the lining of its bronchi, or its pleura), else the parenchyma
/// a deep warm grey; its lobules' septa crisp under the pleura, fading
/// toward the hilum; its bronchi laid open, emptied in shade, their walls
/// pale and their cartilage paler, the arteries beside them in the blood
/// red, the veins between the segments a darker red; the oblique fissure a
/// crease; the right lung whole, its pleura lit as one rounded form, its
/// fissures creases and its lobules faint; the trachea a lit tube ringed by
/// its cartilages; the root's vessels cut short past the hilum.
abstract final class LungStyle {
  // The outline, and the step from the body.

  /// How finely the outlines are followed, how many points the step from
  /// the body morphs round the left lung by, and how far in from the
  /// lung's outline the flat shape is drawn as it becomes the bed it lies
  /// on.
  static const double outlineStep = 1;
  static const int morphPoints = 320;
  static const double bed = 0.5;

  /// Over how much of its detail the body's outline is drawn in to the
  /// lung's: the specimens' own (`SpecimenStep.settling`).
  static const double settling = 0.45;

  /// How finely the airways' and the vessels' edges are followed.
  static const double edgeStep = 0.6;

  // The tones, each a share of the way from the outline toward the bright
  // ink (`ZoomInks.lit`), or into the shade (`ZoomInks.shade`), warmed a
  // share of the way toward the home helix's clay.

  /// Where the zoom's cell lives: one flat tone, the mark over a neutral,
  /// as the liver's parenchyma is.
  static const double homeLit = 0.2;
  static const double homeMark = 0.42;

  /// The parenchyma's cut face, where the cell does not live in it: a deep
  /// warm grey, paler and less red than the liver's.
  static const double parenchymaLit = 0.34;
  static const double parenchymaWarmth = 0.22;

  /// The right lung's pleura, lit.
  static const double pleuraLit = 0.5;
  static const double pleuraWarmth = 0.14;

  /// A bronchus's wall, its cartilage, and its emptied lumen.
  static const double wallLit = 0.72;
  static const double wallWarmth = 0.06;
  static const double cartilageLit = 0.86;
  static const double cartilageWarmth = 0.04;
  static const double lumenShade = 0.7;

  /// An artery's and a vein's wall in the cut, the blood red eased toward
  /// the ground, the vein more, as the other specimens' vessels are; and
  /// their emptied lumens.
  static const double artery = 0.25;
  static const double vein = 0.5;
  static const double vesselLumenShade = 0.85;

  /// The share of a laid-open bronchus's radius its lumen is, by its
  /// generation from the trachea, the smaller ones' walls thicker for their
  /// size; and of a vessel's.
  static const List<double> lumenShare = <double>[
    0.52,
    0.52,
    0.5,
    0.46,
    0.4,
    0.34,
    0.28,
  ];
  static const double vesselWall = 0.22;
  static const double veinLumen = 0.55;

  /// Cartilage plates in the wall of a bronchus of these generations at
  /// most: how far apart along it, and how long each is, shares of its
  /// radius.
  static const int cartilageUpTo = 4;
  static const double cartilagePitch = 2.4;
  static const double cartilageLength = 1.3;

  /// The lining's line along each lumen, where the bronchi are the cell's
  /// home, in pixels at least, and as a share of the wall where wider.
  static const double liningShare = 0.4;
  static const double liningFloor = 1.1;

  /// The trachea and what runs outside the lungs: lit tubes under a light
  /// a little dimmer than the lungs' own, round each at these shares of its
  /// radius; a cut end's length along its tube and its wall, shares of its
  /// width.
  static const double tubeLight = 0.62;
  static const List<double> tubeColumns = <double>[0, 0.38, 0.7, 0.92, 1];
  static const double endLength = 0.45;
  static const double endWall = 0.25;
  static const double tracheaLit = 0.6;
  static const double tracheaWarmth = 0.06;

  /// The trachea's cartilages: the light on each ring, and the groove
  /// between two, in the shadow ink.
  static const double ringLit = 0.78;
  static const double ringAlpha = 0.32;
  static const double grooveAlpha = 0.42;
  static const double grooveFloor = 0.8;

  // The cut face's light.

  /// How much a cut face shines: less than a fresh surface, being cut.
  static const double cutSheen = 0.6;

  /// The parenchyma's edge under the pleura, turning away from the eye:
  /// how wide, and how far its middle and its outer edge turn, as the
  /// liver's.
  static const double rim = 2.4;
  static const double rimMiddle = 0.45;
  static const double rimOuter = 0.85;

  // The right lung's light.

  /// The grid its rounded form is solved on, how high it stands, and how
  /// finely its mesh is laid.
  static const double reliefCell = 2.5;
  static const double inflation = 0.8;
  static const int sweeps = 160;
  static const double meshCell = 2;
  static const double surfaceSheen = 0.5;

  // The lines.

  /// The lobules' septa: their width, in pixels at least, the shadow ink's
  /// alpha over the cut face at the pleura, and on the right lung's
  /// surface; the light on a septum's far side there.
  static const double septum = 0.5;
  static const double septumFloor = 0.8;
  static const double septumAlpha = 0.3;
  static const List<double> septumBands = <double>[1, 0.55, 0.28, 0.12];
  static const double surfaceSeptumAlpha = 0.13;
  static const double septumLight = 0.5;
  static const double septumLightLit = 0.75;
  static const double septumLightAlpha = 0.1;
  static const int seed = 47;

  /// A fissure: a crease in the shadow ink, tapering in from its ends, the
  /// light on its far side.
  static const double fissure = 1.2;
  static const double fissureTaper = 10;
  static const double fissureAlpha = 0.55;
  static const double fissureFloor = 0.9;
  static const double fissureLight = 0.9;
  static const double fissureLightLit = 0.75;
  static const double fissureLightAlpha = 0.16;

  /// The visceral pleura round the cut face and along the fissure, where it
  /// is the cell's home, in pixels at least.
  static const double pleuraLine = 0.2;
  static const double pleuraFloor = 1.2;

  /// The outline's own edge, as the other specimens'.
  static const double edgeLit = 0.42;
  static const double edgeAlpha = 0.85;

  /// The crisp line round each emptied lumen, in the shadow ink.
  static const double edgeLine = 0.15;
  static const double edgeLineFloor = 0.6;
  static const double edgeLineAlpha = 0.3;

  // The shadow the lungs cast.

  static const double shadowX = 1;
  static const double shadowY = 1.5;
  static const double shadowAlpha = 0.35;
  static const double shadowSoft = 2.5;
}
