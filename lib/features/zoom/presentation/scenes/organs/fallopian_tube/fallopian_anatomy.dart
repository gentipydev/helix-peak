import 'dart:ui';

/// The uterine tube the anatomogram draws for the fallopian tube, seen from
/// the front in place, as the body shows it, its front wall cut away along
/// its length so that its lumen and the folds of its mucosa show: the body's
/// right tube, on the left, its uterine end to the right. It is drawn from
/// general anatomy, in millimetres, x across to the body's left, y down,
/// from the middle of the anatomogram's outline of it, along the course the
/// anatomogram gives it, as long as a tube is.
///
/// Sizes keep to what is measured. Each tube is about 10 cm long, in the
/// upper margin of the broad ligament, from the uterus's superior angle to
/// the side of the pelvis: its isthmus, the medial constricted third; its
/// ampulla, dilated, curving over the ovary; its infundibulum, the abdominal
/// ostium ringed by fimbriae, one of them, the ovarian fimbria, attached to
/// the ovary. It runs lateral as far as the ovary, rises along it, arches
/// over it and turns down to end by the ovary's free border. Its coats are
/// serous, muscular and mucous; the mucous coat is thrown into longitudinal
/// folds, far more extensive in the ampulla than in the isthmus, its
/// epithelium columnar and ciliated, as on the fimbriae's inner surfaces
/// (Gray 1918, pp. 1257–1258). The tube's course is the anatomogram's, which
/// draws its arch longer for its box than a tube is: drawn 110 mm long, the
/// zoom's card's 11 cm, it is the anatomogram's tube at 0.66 of the size the
/// body's outline grows to.
///
/// Drawing choices, measured by none of these: the tube's outer diameter,
/// 4 mm at the isthmus widening to 9 at the ampulla and 12 at the ostium;
/// its wall, 1.2 mm thick at the isthmus and 0.75 at the ampulla; its
/// folds, three low ones in the isthmus, branching to nine in the ampulla;
/// the fimbriae, seven, 6 to 9 mm long, the ovarian 14; the mesosalpinx a
/// thin sheet under it, the tubal branches of the uterine and ovarian
/// arteries along it; the place the body goes in, in the infundibulum,
/// where the anatomogram goes in.
abstract final class FallopianAnatomy {
  /// The share of the size the body's outline grows to that the tube is
  /// drawn at: the anatomogram's arch, at a real tube's length.
  static const double diagramShare = 0.66;

  /// The tube's middle line, from its uterine end, along the isthmus,
  /// the ampulla over the ovary and down the infundibulum to the ostium;
  /// and how wide it is outside at each knot.
  static const List<Offset> course = <Offset>[
    Offset(34.3, 9.9),
    Offset(29, 8.9),
    Offset(22.4, 5.6),
    Offset(14.5, 0),
    Offset(6.6, -5.6),
    Offset(-1.3, -10.9),
    Offset(-9.2, -15.6),
    Offset(-17.2, -19.4),
    Offset(-24.4, -21.4),
    Offset(-30, -19.5),
    Offset(-33, -13.9),
    Offset(-33.2, -6.6),
    Offset(-31.5, 0),
    Offset(-28.7, 5.9),
    Offset(-25.7, 11.2),
    Offset(-24.1, 14.2),
  ];
  static const List<double> half = <double>[
    2.0, 2.0, 2.05, 2.2, 2.6, 3.2, 3.8, 4.2, 4.4, 4.5, 4.5, 4.5, 4.7, 5.1, //
    5.6, 6.0,
  ];

  /// The knots the isthmus ends at and the infundibulum begins at.
  static const int isthmusEnd = 4;
  static const int infundibulumStart = 12;

  /// How thick the wall is at the isthmus and at the ampulla.
  static const double isthmusWall = 1.2;
  static const double ampullaWall = 0.75;

  /// The folds: as many as nine, never nearer one another than this.
  static const int folds = 9;
  static const double foldApart = 0.75;
  static const double foldSway = 0.18;

  /// The fimbriae round the ostium: each a finger, from where on the rim
  /// it starts (a share round it), which way it points (a turn from the
  /// tube's own way, in radians), how long, and the ovarian fimbria's
  /// index.
  static const List<(double, double, double)> fimbriae =
      <(double, double, double)>[
        (0.0, -1.05, 6.4),
        (0.17, -0.7, 8.2),
        (0.33, -0.36, 9.0),
        (0.5, 0.02, 8.6),
        (0.67, 0.4, 14),
        (0.83, 0.74, 7.6),
        (1.0, 1.08, 6.2),
      ];
  static const int ovarianFimbria = 4;
  static const double fimbriaRoot = 1.5;
  static const double fimbriaTip = 0.55;

  /// The mesosalpinx under the tube, how deep it reaches below it before
  /// it fades out, from the uterine end to where the ampulla turns down.
  static const double mesosalpinx = 9;
  static const int mesosalpinxEnd = 10;

  /// The tubal artery along the mesosalpinx, so far below the tube.
  static const double arteryBelow = 3.2;

  /// Where the body goes in: in the infundibulum.
  static const Offset site = Offset(-26.2, 11.6);

  // Where the parts are named.

  static const int isthmusName = 3;
  static const int ampullaName = 7;
  static const int mucosaName = 11;
}
