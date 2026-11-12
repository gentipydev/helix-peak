import 'dart:ui';

import '../../tube_course.dart';

/// The seminal vesicles the anatomogram draws on the base of the bladder,
/// seen from the front in place as the body shows them, with the bladder
/// taken away, as Gray's plate shows them (1918, Fig. 1153: "Vesiculae
/// seminales and ampullae of ductus deferentes, seen from the front. The
/// anterior walls of the left ampulla, left seminal vesicle, and prostatic
/// urethra have been cut away"): the two sacs diverging up and out from
/// the base of the prostate, the ampullae of the deferent ducts along their
/// medial margins and the ducts running on up out of the view, the one on
/// the body's left, with its ampulla, laid open, its front wall taken away
/// so that its mucosa shows; the prostate's base below them, fading out
/// below. It is drawn from general anatomy, in millimetres, x across to
/// the body's left, which from the front is the screen's right, y down,
/// from the midline at the top of the prostate's base.
///
/// What is measured. After Gray (1918, pp. 1245-1247, read in the
/// archive.org text of the 20th edition): the seminal vesicles are "two
/// lobulated membranous pouches, placed between the fundus of the bladder
/// and the rectum", each "somewhat pyramidal in form, the broad end being
/// directed backward, upward and lateralward", "usually about 7.5 cm.
/// long, but varies in size, not only in different individuals, but also
/// in the same individual on the two sides"; "the upper extremities of the
/// two vesicles diverge from each other", "the lower extremities are
/// pointed, and converge toward the base of the prostate, where each joins
/// with the corresponding ductus deferens to form the ejaculatory duct.
/// Along the medial margin of each vesicle runs the ampulla of the ductus
/// deferens"; "each vesicle consists of a single tube, coiled upon itself,
/// and giving off several irregular cecal diverticula; the separate coils,
/// as well as the diverticula, are connected together by fibrous tissue.
/// When uncoiled, the tube is about the diameter of a quill, and varies in
/// length from 10 to 15 cm."; its coats are "an external or areolar coat;
/// a middle or muscular coat thinner than in the ductus deferens and
/// arranged in two layers"; "an internal or mucous coat, which is pale, of
/// a whitish brown color, and presents a delicate reticular structure";
/// its arteries "are derived from the middle and inferior vesical and
/// middle hemorrhoidal". The ductus deferens "crosses in front of the
/// ureter", "runs medialward and slightly forward between the fundus of
/// the bladder and the upper end of the seminal vesicle", then "downward
/// and medialward in contact with it", and "at the fundus of the bladder
/// it becomes enlarged and tortuous, and this portion is termed the
/// ampulla"; "it is directed downward to the base of the prostate, where it
/// becomes greatly narrowed, and is joined at an acute angle by the duct
/// of the seminal vesicle to form the ejaculatory duct", which is "about 2
/// cm. long" (pp. 1245-1247). On transrectal ultrasound in 188 healthy
/// fertile men the vesicles' anterior-posterior diameter after ejaculation
/// runs from 6 to 16 mm between its lower and upper reference limits
/// (Lotti et al. 2022, Andrology 10:1150). The prostate's size is the
/// prostate specimen's (`prostate_anatomy.dart`, Gray's 4 by 3 cm).
///
/// Drawing choices, measured by none of these: each sac drawn 50 mm long
/// along its course from its duct to its broad end, the card's 5 cm,
/// shorter than Gray's 7.5 and within the variation he notes, 16 mm wide
/// at its broadest, Lotti's upper limit, lying at some 33 degrees from
/// upright; the coils as six swellings along it and, laid open, as six
/// septa across its lumen, and three diverticula as pits in its lateral
/// wall; the honeycomb of its mucosa 1.3 mm across its meshes, read from
/// Gray's "delicate reticular structure"; the wall 1 mm; the deferent
/// duct 3 mm across, its ampulla 6.4 at its widest and tortuous over its
/// lower two thirds, laid open on the body's left over 32 mm; the
/// ejaculatory ducts' first 5 mm, going into the base; the arteries to the
/// vesicles 1.6 mm, cut short to the side; the prostate's upper half,
/// fading out below; the place the body goes in, in the opened vesicle's
/// mucosa, in its upper third, clear of its septa and pits.
abstract final class SeminalVesicleAnatomy {
  /// How long each vesicle is drawn along its course, from the start of
  /// its duct at the prostate's base to its broad upper end: the card's
  /// 5 cm.
  static const double length = 50;

  /// The vesicle on the body's left, its spine from its narrow duct at the
  /// prostate's base up and out to its broad upper end (the right's is its
  /// mirror), and its half-width at each knot: the duct, then the sac
  /// widening to its broad end and rounding off at the tip.
  static const List<Offset> spine = <Offset>[
    Offset(4.2, 0.8),
    Offset(7.0, -6.0),
    Offset(11.0, -15.0),
    Offset(16.5, -24.5),
    Offset(22.5, -33.5),
    Offset(27.0, -39.5),
    Offset(29.5, -43.0),
  ];
  static const List<double> halfWidths = <double>[
    0.8,
    1.6,
    4.6,
    6.6,
    7.8,
    7.6,
    6.2,
  ];

  /// Where along the spine, in millimetres from its start, the sac begins
  /// beyond its duct: the vesicle on the body's left is laid open from
  /// here to its tip.
  static const double sacFrom = 7;

  /// The coils of the tube the sac is: how far apart their swellings lie
  /// along the whole vesicle, and how deep each swelling is, a share of
  /// its half-width; and, laid open, the septa between the coils, each
  /// this far along the sac from its start, from either side in turn, how
  /// far across the lumen each reaches, a share of it, and how far it
  /// slants back toward the duct from its root to its tip, in millimetres.
  static const double coil = 6;
  static const double coilDepth = 0.16;
  static const List<double> septa = <double>[13.5, 19.5, 25.5, 31.5, 37, 49.5];
  static const double septumReach = 0.6;
  static const double septumSlant = 1.4;

  /// The diverticula, laid open, as pits in the lateral wall: each this
  /// far along the sac, this share of the way across the lumen from its
  /// medial side, and this wide.
  static const List<(double, double, double)> pits = <(double, double, double)>[
    (22, 0.72, 1.1),
    (35, 0.74, 1.3),
    (47.5, 0.7, 1.0),
  ];

  /// The mucosa's honeycomb: how far apart its meshes' middles lie, how far
  /// each strays from its lattice, a share of that, and how many times
  /// they are evened out as packed cells are.
  static const double mesh = 1.3;
  static const double meshJitter = 0.35;
  static const int meshRelax = 2;

  /// The wall, cut through where the vesicle is laid open: its muscular and
  /// areolar coats together.
  static const double wall = 1;

  /// Where the body goes in: in the opened vesicle's mucosa, in its upper
  /// third, on its spine, clear of its septa and pits. Its distance from
  /// the midline is the body's site's at the vesicle's real size.
  static const Offset site = Offset(25.3, -37.3);

  /// The deferent duct on the body's left (the right's is its mirror): from
  /// above and to the side, where it runs on out of the view, in past the
  /// vesicle's upper end to its medial margin, down along it as the
  /// ampulla, enlarged, to the base, where it narrows to meet the vesicle's
  /// duct; its half-width at each knot.
  static const AnatomyTube deferens = AnatomyTube(
    <Offset>[
      Offset(34.5, -58),
      Offset(30.5, -54.5),
      Offset(24, -48.5),
      Offset(18, -41.5),
      Offset(13.5, -32),
      Offset(9.5, -22),
      Offset(6.8, -11.5),
      Offset(4.7, -2.5),
      Offset(4.2, 0.8),
    ],
    <double>[1.5, 1.5, 1.6, 2.0, 2.9, 3.2, 2.8, 1.7, 1.1],
    fadeIn: 8,
  );

  /// The ampulla's tortuous stretch: between these distances along the
  /// deferent duct from its start, how far it swings to either side of its
  /// course at most, in millimetres, how long one turn of it is, and how
  /// much its sacculations swell it, a share of its width, every fold's
  /// length along it.
  static const double ampullaFrom = 36;
  static const double ampullaTo = 64;
  static const double ampullaSwing = 0.45;
  static const double ampullaTurn = 9;
  static const double ampullaSwell = 0.1;

  /// The ampulla on the body's left is laid open between these distances
  /// along the duct; its wall is this thick, and its lining is thrown into
  /// cross folds this far apart, each reaching this share of the way across
  /// from either side in turn.
  static const double openedFrom = 39;
  static const double openedTo = 63;
  static const double ampullaWall = 0.55;
  static const double ampullaFold = 3.6;
  static const double ampullaFoldReach = 0.62;

  /// The ejaculatory duct on the body's left (the right's is its mirror):
  /// from where the vesicle's duct and the ampulla meet, into the base of
  /// the prostate, fading into it.
  static const AnatomyTube ejaculatory = AnatomyTube(
    <Offset>[Offset(4.2, 0.6), Offset(3.4, 3.2), Offset(2.6, 6.0)],
    <double>[1.0, 0.9, 0.8],
    fadeOut: 3.5,
  );

  /// The artery to the vesicle on the body's left, from the inferior
  /// vesical, coming in from the side to the vesicle's lateral border and
  /// under it (the right's is its mirror).
  static const AnatomyTube artery = AnatomyTube(
    <Offset>[
      Offset(43, -24),
      Offset(37, -25.5),
      Offset(31.5, -29),
      Offset(27.5, -33),
    ],
    <double>[0.8, 0.8, 0.75, 0.7],
    fadeIn: 8,
  );

  /// The prostate below: its outline is the prostate specimen's, laid with
  /// the top of its base at the origin ([prostateDown], how far its box's
  /// middle lies below), and it fades out from [prostateWhole] below the
  /// base to [prostateGone].
  static const double prostateDown = 16;
  static const double prostateWhole = 8;
  static const double prostateGone = 20;

  // Where the parts are named.

  /// The whole vesicle, on the body's right, part way up its sac; its
  /// ampulla low down, where it is still wide; its deferent duct above, where it comes
  /// in past the vesicle's upper end; the ejaculatory duct on the body's
  /// left where the vesicle's duct and the ampulla meet; the prostate on
  /// its upper half, toward the body's right.
  static const Offset vesicleName = Offset(-20.5, -30);
  static const Offset ampullaName = Offset(-7.2, -13);
  static const Offset deferensName = Offset(-28, -52.5);
  static const Offset ejaculatoryName = Offset(3.7, 2.2);
  static const Offset prostateName = Offset(-12, 8);
}
