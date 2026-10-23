import 'dart:ui';

/// The front of the right thigh, its muscles as the anatomy plates draw them
/// from the front (Netter's "Muscles of thigh: anterior view"; Gray 1918,
/// fig. 430), from the iliac spines down to the knee: the vastus
/// lateralis on the lateral side under the fascia lata's iliotibial tract,
/// the rectus femoris down the middle to the quadriceps tendon, the patella
/// and the patellar ligament, the vastus medialis above the knee on the
/// medial side; the sartorius crossing all of it from the anterior superior
/// iliac spine to the medial side of the knee; the tensor fasciae latae at
/// the top of the lateral side; and on the medial side the adductor longus
/// and the gracilis. Between the sartorius, the adductor longus and the
/// inguinal ligament lies the femoral triangle, its floor the iliopsoas and
/// the pectineus, the femoral nerve, artery and vein running down it from
/// lateral to medial until the sartorius covers them.
///
/// The muscles are drawn in shares of the thigh where each figure draws it
/// (`ThighForm`): u across, from the outline's lateral edge (0) to its
/// medial edge (1), or to the midline above the crotch; v down the femur,
/// from the top of its head (0) to the bottom of its condyles (1). So the
/// one drawing lies in either figure's thigh. Widths of straps and tubes,
/// and the knee's bones and tendons, are in millimetres.
///
/// The lengths keep to what is measured in 21 lower limbs from people 168 ±
/// 9 cm tall, the figure's 1.70 m: the rectus femoris 36.3 ± 4.7 cm long,
/// the sartorius 44.8 ± 4.2 and the adductor longus 21.8 ± 4.5, and the
/// fibres' angles to the muscles' lines of pull, 13.9° in the rectus
/// femoris, 18.4° in the vastus lateralis and 29.6° in the vastus medialis
/// (Ward et al. 2009, Clin Orthop Relat Res 467:1074, table 3). The vastus
/// lateralis is the muscle human skeletal muscle is biopsied from with the
/// Bergström needle (Shanely et al. 2014, J Vis Exp 91:51812), best between
/// half and three quarters of the way from the greater trochanter to the
/// lateral epicondyle, just in front of the iliotibial tract (Chen et al.
/// 2019, Scand J Med Sci Sports 29:504): where the zoom goes in.
///
/// Drawing choices, measured by none of these: every muscle's borders, as
/// shares of the thigh from the plates; the vasti drawn from the trochanter
/// to the patella as the plates draw them, longer than the vastus
/// lateralis's 27.3 cm that Ward measured; the oblique fibres of the vasti
/// above the knee turned further across, as the plates draw them; the
/// patella 43 by 40 mm, its lower pole 15 mm above the joint, and the
/// patellar ligament as long, 27 mm wide; the femoral artery 8 mm across,
/// the vein 10 and the nerve's trunk 7; the iliotibial tract 5 mm wide seen
/// from the front; the skin and fat taken away, 3 mm in from the outline.
abstract final class ThighAnatomy {
  /// How far in from the figure's outline the muscles lie: its skin and
  /// fat taken away.
  static const double skin = 3;

  // The muscles, each a closed outline in shares (u across from lateral,
  // v down the femur), clockwise on screen from its top.

  /// The vastus lateralis: from below the greater trochanter, under the
  /// tensor's lower end, down the lateral side to the patella's upper
  /// lateral corner.
  static const List<Offset> vastusLateralis = <Offset>[
    Offset(0.12, 0.12),
    Offset(0.21, 0.14),
    Offset(0.30, 0.21),
    Offset(0.35, 0.36),
    Offset(0.37, 0.52),
    Offset(0.38, 0.66),
    Offset(0.37, 0.78),
    Offset(0.36, 0.86),
    Offset(0.30, 0.885),
    Offset(0.20, 0.86),
    Offset(0.11, 0.80),
    Offset(0.05, 0.68),
    Offset(0.025, 0.50),
    Offset(0.02, 0.32),
    Offset(0.05, 0.19),
  ];

  /// The rectus femoris: its straight head off the anterior inferior iliac
  /// spine, between the tensor and the sartorius, down the middle of the
  /// thigh to the quadriceps tendon.
  static const List<Offset> rectusFemoris = <Offset>[
    Offset(0.29, -0.04),
    Offset(0.33, -0.03),
    Offset(0.38, 0.06),
    Offset(0.47, 0.20),
    Offset(0.55, 0.36),
    Offset(0.58, 0.50),
    Offset(0.575, 0.62),
    Offset(0.555, 0.72),
    Offset(0.53, 0.78),
    Offset(0.47, 0.80),
    Offset(0.42, 0.78),
    Offset(0.37, 0.70),
    Offset(0.33, 0.58),
    Offset(0.30, 0.44),
    Offset(0.28, 0.28),
    Offset(0.27, 0.12),
    Offset(0.275, 0.02),
  ];

  /// The rectus femoris's central tendon, which its fibres leave on either
  /// side: it is bipennate.
  static const List<Offset> rectusTendon = <Offset>[
    Offset(0.30, -0.03),
    Offset(0.36, 0.14),
    Offset(0.43, 0.36),
    Offset(0.465, 0.56),
    Offset(0.48, 0.72),
  ];

  /// The vastus medialis: from under the sartorius, its lower part bulging
  /// above the knee, to the patella's medial border.
  static const List<Offset> vastusMedialis = <Offset>[
    Offset(0.555, 0.30),
    Offset(0.63, 0.40),
    Offset(0.72, 0.52),
    Offset(0.81, 0.63),
    Offset(0.875, 0.73),
    Offset(0.89, 0.80),
    Offset(0.85, 0.865),
    Offset(0.78, 0.90),
    Offset(0.70, 0.915),
    Offset(0.64, 0.885),
    Offset(0.60, 0.82),
    Offset(0.57, 0.72),
    Offset(0.55, 0.58),
    Offset(0.545, 0.44),
  ];

  /// The tensor fasciae latae: off the anterior superior iliac spine, down
  /// to the iliotibial tract in the upper third of the thigh.
  static const List<Offset> tensor = <Offset>[
    Offset(0.235, -0.075),
    Offset(0.25, -0.05),
    Offset(0.22, 0.04),
    Offset(0.16, 0.15),
    Offset(0.10, 0.25),
    Offset(0.06, 0.29),
    Offset(0.03, 0.25),
    Offset(0.03, 0.12),
    Offset(0.06, 0.0),
    Offset(0.11, -0.06),
  ];

  /// The adductor longus: its tendon off the pubic body, fanning down and
  /// out to where the sartorius covers it.
  static const List<Offset> adductorLongus = <Offset>[
    Offset(0.84, 0.0),
    Offset(0.89, 0.01),
    Offset(0.885, 0.12),
    Offset(0.86, 0.26),
    Offset(0.82, 0.40),
    Offset(0.74, 0.44),
    Offset(0.66, 0.40),
    Offset(0.63, 0.30),
    Offset(0.70, 0.16),
    Offset(0.80, 0.04),
  ];

  /// The pectineus, the triangle's floor on its medial side.
  static const List<Offset> pectineus = <Offset>[
    Offset(0.73, -0.01),
    Offset(0.845, 0.0),
    Offset(0.81, 0.08),
    Offset(0.73, 0.17),
    Offset(0.66, 0.21),
    Offset(0.63, 0.15),
    Offset(0.69, 0.04),
  ];

  /// The iliopsoas, the triangle's floor on its lateral side, out under the
  /// inguinal ligament and down to the lesser trochanter.
  static const List<Offset> iliopsoas = <Offset>[
    Offset(0.40, -0.05),
    Offset(0.73, -0.035),
    Offset(0.70, 0.04),
    Offset(0.66, 0.14),
    Offset(0.61, 0.21),
    Offset(0.54, 0.16),
    Offset(0.46, 0.06),
    Offset(0.40, 0.0),
  ];

  /// The retinacula either side of the patella, the fascia over the knee
  /// from the vasti and the iliotibial tract to the patella and its
  /// ligament.
  static const List<Offset> retinacula = <Offset>[
    Offset(0.15, 0.865),
    Offset(0.30, 0.875),
    Offset(0.70, 0.895),
    Offset(0.86, 0.88),
    Offset(0.86, 0.96),
    Offset(0.72, 1.03),
    Offset(0.55, 1.05),
    Offset(0.42, 1.05),
    Offset(0.26, 1.02),
    Offset(0.14, 0.95),
  ];

  /// The quadriceps tendon, from the rectus femoris's end to the patella.
  static const List<Offset> quadricepsTendon = <Offset>[
    Offset(0.43, 0.765),
    Offset(0.57, 0.765),
    Offset(0.65, 0.83),
    Offset(0.68, 0.89),
    Offset(0.37, 0.89),
    Offset(0.37, 0.83),
  ];

  /// What lies deeper, where the muscles part: the thigh between its
  /// edges from the cut at the inguinal ligament down to the tibia, seen in
  /// shade between them.
  static const List<Offset> deep = <Offset>[
    Offset(0.06, -0.03),
    Offset(0.25, -0.07),
    Offset(0.45, -0.045),
    Offset(0.74, -0.03),
    Offset(0.86, -0.005),
    Offset(0.96, 0.01),
    Offset(0.975, 0.4),
    Offset(0.975, 0.8),
    Offset(0.93, 0.93),
    Offset(0.84, 0.97),
    Offset(0.62, 0.99),
    Offset(0.40, 0.99),
    Offset(0.16, 0.97),
    Offset(0.04, 0.92),
    Offset(0.005, 0.7),
    Offset(0.005, 0.3),
  ];

  // The straps: each its course in shares and its half width there, in
  // millimetres.

  /// The sartorius: from the anterior superior iliac spine across the front
  /// of the thigh, down its medial side behind the vastus medialis and on
  /// to the tibia.
  static const List<Offset> sartorius = <Offset>[
    Offset(0.21, -0.075),
    Offset(0.28, 0.0),
    Offset(0.40, 0.10),
    Offset(0.53, 0.22),
    Offset(0.66, 0.36),
    Offset(0.78, 0.49),
    Offset(0.88, 0.62),
    Offset(0.935, 0.74),
    Offset(0.945, 0.86),
    Offset(0.92, 0.96),
    Offset(0.86, 1.03),
    Offset(0.79, 1.07),
  ];
  static const List<double> sartoriusWidth = <double>[
    7,
    10,
    12,
    12.5,
    12.5,
    12,
    10,
    8,
    6.5,
    5,
    3.5,
    2.5,
  ];

  /// The gracilis, down the medial side from the pubis.
  static const List<Offset> gracilis = <Offset>[
    Offset(0.90, 0.0),
    Offset(0.915, 0.2),
    Offset(0.94, 0.5),
    Offset(0.945, 0.75),
    Offset(0.935, 0.88),
    Offset(0.87, 1.0),
    Offset(0.82, 1.06),
  ];
  static const List<double> gracilisWidth = <double>[
    8.5,
    7,
    6.5,
    5.5,
    4.5,
    3,
    2,
  ];

  /// The iliotibial tract: down the lateral edge, as wide as it shows from
  /// the front, and forward over the knee to the tibia's lateral tubercle.
  static const double tract = 5;
  static const List<double> tractDown = <double>[
    0.10,
    0.2,
    0.35,
    0.5,
    0.65,
    0.8,
    0.88,
  ];
  static const List<Offset> tractKnee = <Offset>[
    Offset(0.07, 0.95),
    Offset(0.17, 1.04),
  ];
  static const List<double> tractKneeWidth = <double>[3.5, 4.5];

  // The knee's bones and tendons, in millimetres from the patella's middle,
  // x lateral and y down.

  /// How far above the bottom of the condyles the patella's middle lies.
  static const double patellaHeight = 35;

  /// The patella, base up and apex down.
  static const List<Offset> patella = <Offset>[
    Offset(-21.5, -12),
    Offset(-14, -19),
    Offset(0, -20.5),
    Offset(14, -19),
    Offset(21.5, -12),
    Offset(19, 4),
    Offset(10, 15),
    Offset(0, 19.5),
    Offset(-10, 15),
    Offset(-19, 4),
  ];

  /// The patellar ligament, from the patella's apex to the tibial
  /// tuberosity, a little lateral.
  static const List<Offset> patellarLigament = <Offset>[
    Offset(-13.5, 14),
    Offset(13.5, 14),
    Offset(12.5, 55),
    Offset(-6.5, 55),
  ];

  // The femoral triangle's nerve, artery and vein, in shares, each its
  // radius at each point in millimetres; the nerve's branches. Each runs
  // under the sartorius at its lower end.

  static const List<Offset> nerve = <Offset>[
    Offset(0.50, -0.045),
    Offset(0.52, 0.03),
    Offset(0.54, 0.09),
  ];
  static const List<double> nerveWidth = <double>[3.5, 3.5, 3];
  static const List<List<Offset>> nerveBranches = <List<Offset>>[
    <Offset>[Offset(0.54, 0.09), Offset(0.58, 0.18), Offset(0.63, 0.30)],
    <Offset>[Offset(0.54, 0.09), Offset(0.49, 0.14), Offset(0.45, 0.17)],
    <Offset>[Offset(0.54, 0.09), Offset(0.53, 0.16), Offset(0.52, 0.21)],
  ];
  static const List<List<double>> nerveBranchWidths = <List<double>>[
    <double>[1.3, 1.2, 1.1],
    <double>[1.6, 1.4, 1.2],
    <double>[1.4, 1.2, 1.0],
  ];
  static const List<Offset> artery = <Offset>[
    Offset(0.585, -0.045),
    Offset(0.60, 0.06),
    Offset(0.63, 0.18),
    Offset(0.655, 0.27),
    Offset(0.675, 0.34),
  ];
  static const List<double> arteryWidth = <double>[4, 3.8, 3.6, 3.5, 3.4];
  static const List<Offset> vein = <Offset>[
    Offset(0.665, -0.045),
    Offset(0.675, 0.06),
    Offset(0.69, 0.18),
    Offset(0.705, 0.27),
    Offset(0.72, 0.34),
  ];
  static const List<double> veinWidth = <double>[5, 5, 4.6, 4.2, 4];

  // The fibres: each family runs from one line to another, fibre by fibre
  // at matching shares along each, so they never cross.

  /// The vastus lateralis's: from its lateral aponeurosis down and in to
  /// the deep one, turning across over its lowest few centimetres.
  static const List<Offset> lateralisFrom = <Offset>[
    Offset(0.0, 0.08),
    Offset(0.0, 0.33),
    Offset(0.03, 0.58),
    Offset(0.08, 0.74),
    Offset(0.20, 0.86),
  ];
  static const List<Offset> lateralisTo = <Offset>[
    Offset(0.30, 0.36),
    Offset(0.38, 0.62),
    Offset(0.38, 0.80),
    Offset(0.35, 0.87),
    Offset(0.33, 0.90),
  ];

  /// The rectus femoris's: from its central tendon down and out to either
  /// border.
  static const List<Offset> rectusLateral = <Offset>[
    Offset(0.26, 0.12),
    Offset(0.28, 0.34),
    Offset(0.31, 0.54),
    Offset(0.37, 0.72),
    Offset(0.44, 0.80),
  ];
  static const List<Offset> rectusMedial = <Offset>[
    Offset(0.40, 0.10),
    Offset(0.53, 0.32),
    Offset(0.585, 0.52),
    Offset(0.57, 0.70),
    Offset(0.52, 0.80),
  ];

  /// The vastus medialis's: from its medial border down and out to the
  /// quadriceps tendon and the patella, nearly across at the bottom.
  static const List<Offset> medialisFrom = <Offset>[
    Offset(0.60, 0.30),
    Offset(0.72, 0.45),
    Offset(0.85, 0.60),
    Offset(0.92, 0.72),
    Offset(0.92, 0.82),
  ];
  static const List<Offset> medialisTo = <Offset>[
    Offset(0.545, 0.50),
    Offset(0.555, 0.64),
    Offset(0.58, 0.75),
    Offset(0.62, 0.83),
    Offset(0.69, 0.87),
  ];

  /// The tensor's, the adductor longus's, the pectineus's and the
  /// iliopsoas's: each from its origin to its insertion.
  static const List<Offset> tensorFrom = <Offset>[
    Offset(0.06, -0.08),
    Offset(0.26, -0.08),
  ];
  static const List<Offset> tensorTo = <Offset>[
    Offset(0.0, 0.26),
    Offset(0.09, 0.31),
  ];
  static const List<Offset> adductorFrom = <Offset>[
    Offset(0.835, -0.01),
    Offset(0.895, 0.0),
  ];
  static const List<Offset> adductorTo = <Offset>[
    Offset(0.62, 0.30),
    Offset(0.70, 0.45),
    Offset(0.84, 0.43),
  ];
  static const List<Offset> pectineusFrom = <Offset>[
    Offset(0.72, -0.02),
    Offset(0.86, -0.01),
  ];
  static const List<Offset> pectineusTo = <Offset>[
    Offset(0.62, 0.14),
    Offset(0.70, 0.22),
  ];
  static const List<Offset> iliopsoasFrom = <Offset>[
    Offset(0.39, -0.06),
    Offset(0.74, -0.045),
  ];
  static const List<Offset> iliopsoasTo = <Offset>[
    Offset(0.52, 0.16),
    Offset(0.63, 0.22),
  ];

  // Where the names point.

  static const Offset rectusName = Offset(0.43, 0.30);
  static const Offset sartoriusName = Offset(0.78, 0.49);
  static const Offset medialisName = Offset(0.79, 0.74);
}
