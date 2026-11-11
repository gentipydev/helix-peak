import 'dart:math' as math;
import 'dart:ui';

/// A follicle or a corpus of the ovary's cut face: its middle and its
/// radius, in millimetres.
typedef OvaryBody = ({Offset centre, double radius});

/// The left ovary the anatomogram draws for the ovary, seen from the front
/// as the anatomogram lays the pelvis out, the broad ligament spread, its
/// broad face toward the eye, and cut through its thickness down its length
/// and through its hilum, its front half taken away, so that its cortex,
/// its follicles, its corpora and its medulla show on the cut face; its
/// tube arching over it, its ligaments and its vessels round it. It is
/// drawn from general anatomy, in millimetres along the ovary: x along its
/// long axis from its middle toward its tubal pole, which is the body's
/// left, y across it from its axis toward its free border; laid in the body
/// turned [tilt] from level, its tubal pole higher.
///
/// The left ovary is the one the zoom goes into: the GTEx Portal's sampling
/// site for the ovary is "Most normal regions of the left ovary (and right
/// if necessary to obtain sufficient aliquots)" (gtex_v10, read on
/// 2026-11-11), its Tissue Harvesting Work Instruction (PR-0004-W1, version
/// 03.05, 4.3.6.27.2) taking aliquots "10 mm x 10 mm x ≤4 mm", about half
/// an ovary's thickness; and the Atlas's reading of an ovary's cell types
/// is made from GTEx's samples. The section is Schrön's, as Gray reproduces
/// it (Fig. 1163, "Section of the ovary"): the outer covering, the
/// attached border where the vessels enter, the central stroma and the
/// peripheral, follicles from the earliest to an almost mature one, and a
/// corpus luteum.
///
/// What is measured. After Gray (1918, pp. 1254-1256, read in the
/// archive.org text of the 20th edition): the ovaries are "each about 4
/// cm. in length, 2 cm. in width, and about 8 mm. in thickness, and weigh
/// from 2 to 3.5 gm."; each "presents a lateral and a medial surface, an
/// upper or tubal and a lower or uterine extremity, and an anterior or
/// mesovarian and a posterior free border"; the uterine end "is usually
/// narrower than the tubal" and is attached to the uterus "by a rounded
/// cord termed the ligament of the ovary"; to the tubal end are attached
/// "the ovarian fimbria of the uterine tube and a fold of peritoneum, the
/// suspensory ligament of the ovary, which is directed upward over the
/// iliac vessels and contains the ovarian vessels"; "the mesovarian border
/// is straight", "the free border is convex"; "the uterine tube arches over
/// the ovary, running upward in relation to its mesovarian border, then
/// curving over its tubal pole". In its stroma, "immediately beneath the
/// superficial covering", lie "a large number of minute vesicles", the
/// follicles "in their earliest condition", in "the cortical layer"; the
/// larger follicles "increase in size as they recede from the surface
/// toward a highly vascular stroma in the center of the organ, termed the
/// medullary substance", which "forms the tissue of the hilum by which the
/// ovary is attached, and through which the bloodvessels enter: it does not
/// contain any follicles". A larger follicle has a fibrovascular coat and
/// within it the membrana granulosa, "collected into a mass which projects
/// into the cavity of the follicle", the discus proligerus, in which "the
/// ovum is imbedded"; a corpus luteum, the lining of a follicle "thrown
/// into folds" after the ovum is discharged, "consists at first of a radial
/// arrangement of yellow cells", "and later it merges with the surrounding
/// stroma". A primordial follicle is about 40 µm across and its oocyte
/// about 30 (Westergaard et al. 2007, Hum Reprod 22:2225; the NICHD
/// ovarian nomenclature of 2021); in women in their twenties to forties the
/// primordial and primary follicles lie on average 460 to 500 µm under the
/// surface and the secondary ones 640 µm (Haino et al. 2018, J Adolesc
/// Young Adult Oncol 7:46). A dominant follicle is selected in the
/// mid-follicular phase (Baerwald, Adams and Pierson 2012, Hum Reprod
/// Update 18:73) and measures 21.4 mm on average at ovulation, from 17.4 to
/// 27.0 (Bakos et al. 1994, Acta Obstet Gynecol Scand 73:790); a corpus
/// luteum is still to be seen, though no longer working, through the
/// following follicular phase (Baerwald, Adams and Pierson 2005, Ultrasound
/// Obstet Gynecol 25:498). An ovary of the reproductive years holds about
/// 7 mL and six antral follicles (Jabbar et al. 2026, Front Med 13:1765600:
/// the left, 7.1 ± 3.4 mL, 6.1 ± 3.2 follicles).
///
/// Drawing choices, measured by none of these: one moment of the ovary's
/// cycle, as Schrön's section has it, a follicle near ripeness, 13 mm
/// across, under its free border and the last cycle's corpus luteum, 10 mm,
/// toward its tubal pole, five small antral follicles of 2 to 4 mm and
/// three corpora albicantia; the tube cut short over the ovary's uterine
/// third; the cut face 40 mm long and 20 mm across, Gray's length and
/// width, the free border puckered a little; the medulla an oval about the
/// hilum, 14 mm along the mesovarian border; the
/// helicine vessels' courses in it; the follicles in the earliest stages
/// as dust under the surface, set so that they show; the tube's course,
/// close over the mesovarian border and round the tubal pole, its calibres
/// and its fimbriae the fallopian tube's own (`FallopianAnatomy`); the
/// ligament of the ovary 3 mm across; the ovarian vessels' courses down the
/// suspensory ligament to the hilum, the artery 1.5 mm across and the vein
/// 3; each cut short where it leaves; the ovary laid [tilt] from level; the
/// site's place on the free border, 1 mm in from the surface.
abstract final class OvaryAnatomy {
  /// How far from level the ovary is laid in the body, its tubal pole
  /// higher, as the anatomogram lays the pelvis out.
  static const double tilt = 13 * math.pi / 180;

  /// Where the zoom goes in: on the free border, 1 mm in from the surface,
  /// in a stretch of cortex clear of every follicle and corpus.
  static const Offset site = Offset(-0.5, 10);

  /// How long the ovary is, from its uterine pole to its tubal: the zoom's
  /// card's 4 cm.
  static const double length = 40;

  /// The cut face's outline, round from the uterine pole along the free
  /// border, the near-ripe follicle bulging it, over the tubal pole and
  /// back along the mesovarian border, nearly straight.
  static const List<Offset> outline = <Offset>[
    Offset(-20, 0),
    Offset(-19.7, 2),
    Offset(-19.1, 3.9),
    Offset(-16.8, 6.5),
    Offset(-13.8, 9.1),
    Offset(-11, 10.8),
    Offset(-7.7, 11.3),
    Offset(-4, 10.9),
    Offset(0, 11),
    Offset(4, 11.1),
    Offset(7.9, 10.9),
    Offset(11.5, 10.1),
    Offset(14.9, 8.6),
    Offset(17.6, 6.3),
    Offset(19.4, 3.5),
    Offset(20, -1.5),
    Offset(19.2, -4.5),
    Offset(17, -6.5),
    Offset(13.7, -7.7),
    Offset(9.9, -8.3),
    Offset(5.9, -8.4),
    Offset(1.8, -8.2),
    Offset(-2.4, -8.1),
    Offset(-6.5, -7.9),
    Offset(-10.4, -7.5),
    Offset(-14.2, -6.8),
    Offset(-17.5, -5.4),
    Offset(-19.5, -3.3),
  ];

  /// The medulla: an oval about the hilum, the central stroma, its middle
  /// and its reach along and across the ovary; where it meets the
  /// mesovarian border is the hilum.
  static const Offset medulla = Offset(1.5, -5);
  static const double medullaAlong = 9;
  static const double medullaAcross = 5.2;

  /// The follicle near ripeness, under the free border.
  static const OvaryBody ripe = (centre: Offset(-8.5, 4), radius: 6.5);

  /// The small antral follicles, deeper as they grow.
  static const List<OvaryBody> antral = <OvaryBody>[
    (centre: Offset(-17.5, 0), radius: 1.2),
    (centre: Offset(-14, -4.6), radius: 1.3),
    (centre: Offset(3.5, 8.2), radius: 2),
    (centre: Offset(8, 7.8), radius: 1.3),
    (centre: Offset(16.8, 3.8), radius: 1.2),
  ];

  /// A follicle's granulosa, how thick, in the near-ripe follicle and in
  /// the small ones; its cumulus, how far it stands into the antrum; its
  /// oocyte, how wide; its theca outside the granulosa, how thick.
  static const double granulosaRipe = 0.12;
  static const double granulosa = 0.08;
  static const double cumulusRipe = 0.5;
  static const double cumulus = 0.25;
  static const double oocyte = 0.12;
  static const double theca = 0.2;

  /// The follicles in the earliest stages, under the surface: the
  /// primordial ones, about 40 µm, from this deep to this deep, and the
  /// growing ones, deeper.
  static const double primordial = 0.04;
  static const double primordialFrom = 0.15;
  static const double primordialTo = 0.75;
  static const double growing = 0.12;
  static const double growingFrom = 0.5;
  static const double growingTo = 1.4;

  /// The corpus luteum: its middle and its reach, how deep its band of
  /// luteal tissue is, and how many folds its lining is thrown into.
  static const OvaryBody luteum = (centre: Offset(11.5, -1.5), radius: 5);
  static const double luteumBand = 2.2;
  static const int luteumFolds = 13;

  /// The corpora albicantia, scars of corpora lutea long gone.
  static const List<OvaryBody> albicantia = <OvaryBody>[
    (centre: Offset(-2, -3.5), radius: 1.8),
    (centre: Offset(4, 2.5), radius: 1.4),
    (centre: Offset(-17, -3.4), radius: 0.9),
  ];

  /// The helicine vessels' courses in the medulla, from the hilum inward.
  static const List<List<Offset>> helicine = <List<Offset>>[
    <Offset>[Offset(-3.5, -8), Offset(-5, -5.5), Offset(-5.5, -3)],
    <Offset>[Offset(0.5, -8.1), Offset(0, -5.2), Offset(0.8, -2)],
    <Offset>[Offset(4.5, -8.2), Offset(5.5, -5), Offset(5.8, -2)],
    <Offset>[Offset(7.6, -8.1), Offset(7, -5.5)],
  ];

  /// The helicine vessels' profiles: an artery's and a vein's outer
  /// radius, how thick each wall is, a share of it; how far apart the
  /// profiles lie along a course and how far they swing to either side.
  static const double arteryProfile = 0.35;
  static const double veinProfile = 0.6;
  static const double arteryWall = 0.35;
  static const double veinWall = 0.16;
  static const double coilPitch = 0.9;
  static const double coilSwing = 0.45;

  /// The tube, from where it is cut short over the ovary's uterine third,
  /// along the mesovarian border, over the tubal pole and down beside it
  /// to the ostium, which opens onto the pole behind it, its fimbriae
  /// spreading from under it.
  static const List<Offset> tube = <Offset>[
    Offset(-9, -13.6),
    Offset(-3, -14.2),
    Offset(3, -14.7),
    Offset(9, -15),
    Offset(14.5, -14.7),
    Offset(19, -13.2),
    Offset(21.8, -10),
    Offset(21.8, -6.6),
    Offset(19, -3),
  ];

  /// Which way the fimbriae spread from the ostium, behind the pole: down
  /// past its lateral edge, the ovarian fimbria running down along it.
  static const Offset fimbriaeWay = Offset(0.5, 0.87);

  /// The ligament of the ovary, from the uterine pole toward the uterus,
  /// cut short; how wide.
  static const List<Offset> ligament = <Offset>[
    Offset(-19.6, 0.8),
    Offset(-23, 0),
    Offset(-27, -0.8),
  ];
  static const double ligamentRadius = 1.5;

  /// The ovarian vein and artery, from the hilum, where they dive into the
  /// ovary, along the mesovarium and up the suspensory ligament, cut short;
  /// how wide each is, and how far along from the hilum each comes up.
  static const List<Offset> vein = <Offset>[
    Offset(2, -9.2),
    Offset(8, -9.6),
    Offset(14.5, -9.3),
    Offset(19.6, -8.2),
    Offset(24, -9.4),
    Offset(28.6, -12.6),
  ];
  static const List<Offset> artery = <Offset>[
    Offset(3.6, -9.4),
    Offset(9, -10),
    Offset(15, -9.9),
    Offset(19.8, -9.6),
    Offset(23.6, -11.2),
    Offset(27.6, -14.6),
  ];
  static const double veinRadius = 1.5;
  static const double arteryRadius = 0.75;
  static const double vesselsRise = 2.5;

  // Where the parts are named.

  static const Offset luteumName = Offset(11.5, 2.4);
  static const Offset albicansName = Offset(4, 2.5);
  static const Offset medullaName = Offset(3, -6);
  static const Offset ligamentName = Offset(-23, 0);

  /// The tube named over the ovary's middle, where it runs along the
  /// mesovarian border.
  static const Offset tubeName = Offset(-2, -14.3);
}
