import 'dart:math' as math;
import 'dart:ui';

import '../../tube_course.dart';

/// The right superior parathyroid gland, seen from behind where it lies on
/// the back of its thyroid lobe, as Halsted and Evans drew the right
/// parathyroids (Gray 1918, Fig. 1177), and cut through its thickness, its
/// back half taken away, so that its parenchyma shows: in millimetres, x
/// toward the body's right, which from behind is the screen's right, y
/// down, from the middle of the view.
///
/// The body has no parathyroid of its own: the anatomogram's thyroid stands
/// in for it, and the scene comes up over the body's drawing of that, as
/// the lymph node's does over its chain.
///
/// What is measured. After Gray (1918, pp. 1271-1273, read in the
/// archive.org text of the 20th edition): the parathyroids are "small
/// brownish-red bodies, situated as a rule between the posterior borders of
/// the lateral lobes of the thyroid gland and its capsule"; they "measure
/// on an average about 6 mm. in length, and from 3 to 4 mm. in breadth,
/// and usually present the appearance of flattened oval disks"; the
/// superior "are the more constant in position, and are situated, one on
/// either side, at the level of the lower border of the cricoid cartilage,
/// behind the junction of the pharynx and esophagus"; within, "masses of
/// cells arranged in a more or less columnar fashion with numerous
/// intervening capillaries", "most of the cells are clear, but some, larger
/// in size, contain oxyphil granules". In 503 autopsies the superior glands
/// lay "just above the intersection between the recurrent laryngeal nerve
/// and the inferior thyroid artery", the inferior more ventrally, close to
/// the lower thyroid pole (Akerström, Malmaeus and Bergström 1984, Surgery
/// 95:14). A normal gland weighs 25.7 mg at the median, 8.2 to 75 mg in
/// 95% (Dufour and Wilkerson 1983, Arch Pathol Lab Med 107:167), which a
/// disc 6 by 4 by 1.5 mm holds; its stroma is 17% fat on average, under 10%
/// in nearly a third of people and over 50% in one of a hundred (Dufour and
/// Wilkerson 1982, Hum Pathol 13:717). Of 92 glands, 62% had a single
/// artery (Nobori et al. 1994, Surgery 115:417). The nerve passes behind
/// the inferior thyroid artery more often than in front of it or between
/// its branches (Noussios et al. 2020, J Clin Med Res 12:640, a review of
/// sixteen studies), so that from behind it is drawn over the artery; in
/// the normal parathyroid oxyphil cells lie in nodules, more of them with
/// age (Müller-Höcker et al. 1996, Hum Pathol 27:532).
///
/// Drawing choices, measured by none of these: the gland's outline, 6 by 4
/// mm, its long axis leaning [tilt] from upright, its hilum low on its
/// medial side; three oxyphil nodules 0.7 to 1 mm across; the stromal fat
/// as cells 70 µm across, about a fifth of the cut face, most in clusters;
/// the septa and the vessels branching in them from the hilum; the lobe's
/// outline, its medial border 4 mm from the gland's middle; the inferior
/// thyroid artery 1.8 mm across, its branches 1 mm and the gland's own
/// artery 0.3 mm; the nerve 1.6 mm; the crossing 5 mm below the gland's
/// middle; the lobe, the artery's branches and the nerve fading out above
/// and below, where the names stand; the place the body goes in, in the parenchyma above the
/// gland's middle.
abstract final class ParathyroidAnatomy {
  /// How long and how broad the gland is, Gray's 6 mm by 4.
  static const double length = 6;
  static const double breadth = 4;

  /// Where the gland's middle lies in the view, and how far its long axis
  /// leans from upright, its upper pole toward the body's middle, along
  /// the lobe's posterior border.
  static const Offset gland = Offset(0.5, -2);
  static const double tilt = -12 * math.pi / 180;

  /// The hilum, where its artery comes in: which way from the gland's
  /// middle, in the gland's own frame (0 along its long axis down), and how
  /// deep and wide its notch.
  static const double hilumAngle = 0.5;
  static const double hilumDepth = 0.28;
  static const double hilumWidth = 0.32;

  /// The oxyphil nodules, in the gland's own frame (x across, y along its
  /// long axis, down), and their radii.
  static const List<(Offset, double)> oxyphil = <(Offset, double)>[
    (Offset(0.85, -1.35), 0.5),
    (Offset(-0.95, 1.3), 0.38),
    (Offset(0.75, 1.65), 0.34),
  ];

  /// The clusters the stromal fat lies in, in the gland's own frame, and
  /// how far each spreads; and what share of the fat lies in none.
  static const List<(Offset, double)> fatClusters = <(Offset, double)>[
    (Offset(-1.05, -1.75), 0.32),
    (Offset(1.15, 0.2), 0.3),
    (Offset(-0.35, 2.15), 0.26),
    (Offset(-1.3, 0.35), 0.24),
    (Offset(0.2, -2.45), 0.2),
    (Offset(1.25, 1.6), 0.2),
    (Offset(-1.15, 1.95), 0.22),
  ];
  static const double fatScattered = 0.25;

  /// How much of the cut face the fat covers, and how wide a fat cell is.
  static const double fatShare = 0.17;
  static const double fatCell = 0.07;

  /// The vessels branching from the hilum along the septa, in the gland's
  /// own frame: each a course from the hilum.
  static const List<List<Offset>> vessels = <List<Offset>>[
    <Offset>[Offset(-0.85, 2.6), Offset(-0.5, 1.6), Offset(-0.25, 0.4)],
    <Offset>[
      Offset(-0.25, 0.4),
      Offset(-0.45, -0.8),
      Offset(-0.35, -1.9),
      Offset(-0.05, -2.75),
    ],
    <Offset>[Offset(-0.25, 0.4), Offset(0.45, -0.15), Offset(1.35, -0.55)],
    <Offset>[Offset(-0.45, -0.8), Offset(-1.15, -1.05), Offset(-1.75, -0.7)],
    <Offset>[Offset(-0.5, 1.6), Offset(0.25, 1.15), Offset(1.0, 0.95)],
    <Offset>[Offset(-0.35, -1.9), Offset(0.45, -2.3), Offset(0.95, -2.4)],
  ];

  /// The septa the capsule sends in, each from a share of the way round
  /// the outline, how far in.
  static const List<(double, double)> septa = <(double, double)>[
    (0.06, 0.55),
    (0.2, 0.7),
    (0.33, 0.5),
    (0.47, 0.6),
    (0.62, 0.45),
    (0.86, 0.65),
  ];

  /// Where the body goes in: in the parenchyma, above the gland's middle,
  /// in its own frame.
  static const Offset site = Offset(-0.55, -0.45);

  /// The thyroid's right lobe behind it, from its medial border down
  /// round its lower half and up its lateral border over its top; most of
  /// it fades out round the gland.
  static const List<Offset> lobe = <Offset>[
    Offset(-2.8, 22),
    Offset(-3.4, 14),
    Offset(-3.8, 6),
    Offset(-4.0, -1),
    Offset(-3.9, -8),
    Offset(-3.3, -14),
    Offset(-1.8, -20),
    Offset(1.2, -25),
    Offset(6, -27),
    Offset(11, -24),
    Offset(15, -16),
    Offset(17, -6),
    Offset(17.4, 4),
    Offset(16.5, 14),
    Offset(14.5, 22),
    Offset(10, 27),
    Offset(4, 27.5),
    Offset(0, 26),
  ];

  /// How far the lobe shows round [lobeMiddle]: whole within
  /// [lobeWhole] of the reach across it and up and down it, gone by
  /// [lobeGone], its fade's corners rounded by [lobeRound].
  static const Offset lobeMiddle = Offset(0, -1.3);
  static const double lobeAcross = 6.2;
  static const double lobeDown = 5.4;
  static const double lobeWhole = 0.7;
  static const double lobeGone = 1.25;
  static const double lobeRound = 3;

  /// The inferior thyroid artery, from the side, across the lobe's back
  /// and under the nerve, on toward the trachea and the esophagus; its
  /// branches up and down the lobe, each going in; and the gland's own,
  /// from the ascending branch to its hilum.
  static const AnatomyTube artery = AnatomyTube(
    <Offset>[
      Offset(9.6, 4.05),
      Offset(6.5, 3.6),
      Offset(3, 3),
      Offset(-1.2, 2.6),
      Offset(-4.8, 2.5),
      Offset(-9.2, 3.1),
    ],
    <double>[0.9, 0.9, 0.88, 0.85, 0.7, 0.6],
    fadeIn: 3.5,
    fadeOut: 2.5,
  );
  static const AnatomyTube ascending = AnatomyTube(
    <Offset>[
      Offset(-1.6, 2.6),
      Offset(-2.5, 0.5),
      Offset(-2.8, -2.7),
      Offset(-2.5, -5.1),
      Offset(-2.0, -6.7),
    ],
    <double>[0.55, 0.55, 0.5, 0.46, 0.42],
    fadeOut: 2.4,
  );
  static const AnatomyTube descending = AnatomyTube(
    <Offset>[
      Offset(0.4, 2.9),
      Offset(0.9, 3.7),
      Offset(1.2, 4.4),
      Offset(1.35, 5.1),
    ],
    <double>[0.5, 0.5, 0.46, 0.42],
    fadeOut: 2,
  );

  /// The gland's own artery, from the ascending branch to the hilum, in
  /// the view: its last point is set on the hilum by the form.
  static const List<Offset> own = <Offset>[Offset(-2.65, 0), Offset(-1.6, 0.7)];
  static const double ownRadius = 0.15;

  /// The recurrent laryngeal nerve, up the groove beside the trachea and
  /// over the artery, on toward the larynx; fading out at either end.
  static const AnatomyTube nerve = AnatomyTube(
    <Offset>[
      Offset(-5.2, 4.9),
      Offset(-5.05, 2.3),
      Offset(-4.85, -0.7),
      Offset(-5.0, -4.3),
      Offset(-5.4, -7.7),
    ],
    <double>[0.8, 0.8, 0.8, 0.8, 0.8],
    fadeIn: 2.2,
    fadeOut: 2.4,
  );

  // Where the parts are named.

  /// The lobe, on its back above the gland, toward its lateral side; the
  /// nerve beside the gland, above the crossing.
  static const Offset thyroidName = Offset(4.0, -4.1);
  static const Offset nerveName = Offset(-4.95, -3.3);
}
