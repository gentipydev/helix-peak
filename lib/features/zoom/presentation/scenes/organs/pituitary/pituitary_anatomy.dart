import 'dart:ui';

import '../../tube_course.dart';
import '../brain/brain_anatomy.dart';

/// The pituitary gland the anatomogram draws for the pituitary, cut down
/// its middle as the brain's stop cuts the brain, seen from the left, front
/// to the left: in the brain's own millimetres ([BrainAnatomy]: from the
/// anterior commissure, x back, y down), so that its lobes, its stalk, the
/// chiasm and the hypothalamus over it are the very ones the brain draws,
/// and in the sphenoid bone's sella turcica, cut, the sphenoid sinus below
/// and in front of it, the dorsum sellae and the clivus behind it.
///
/// Sizes keep to what is measured. The hypophysis is a small reddish-grey
/// body about 1 cm across, on the end of the infundibulum, resting in the
/// hypophyseal fossa; its anterior lobe the larger, kidney-shaped, its
/// concavity backward round the posterior lobe, its pars intermedia a thin
/// lamina on the posterior lobe, parted from the pars anterior by a narrow
/// cleft; the optic chiasm in front of the infundibulum, the mammillary
/// body behind it, the basilar artery on the pons behind the clivus (Gray
/// 1918, pp. 1275–1276 and its Fig. 1180, the hypophysis in position in
/// sagittal section). On MRI in 70 controls the gland was 5.78 ± 1.15 mm
/// tall and 10.25 ± 1.41 mm front to back in the sagittal plane (Saba et al.
/// 2017, Iran J Neurol 16:218); the brain's lobes, which are these, are 7.2
/// and 11.2. The rest of the brain's measures are its own
/// ([BrainAnatomy]: AFIDs on the MNI152 2009c template, Lau et al. 2019).
/// The brainstem and the basilar artery behind the clivus are not drawn:
/// the view ends at the clivus.
///
/// Drawing choices, measured by none of these: the fossa drawn just round
/// the gland, its floor 1.4 mm of bone over the sinus; the tuberculum, the
/// planum, the dorsum sellae and the clivus; the sinus's extent; the
/// diaphragma sellae a dura line from the tuberculum to the posterior
/// clinoid, open round the stalk; the portal vessels down the stalk's
/// front, 0.5 mm across (the superior hypophyseal arteries come to them
/// from the side, out of the cut); what
/// lies above the floor of the third ventricle and the bone's foot fading
/// out where the view stops needing them; the place the body goes in, in
/// the anterior lobe's middle.
abstract final class PituitaryAnatomy {
  /// The gland's outline, its two lobes as one: round the anterior lobe
  /// from the stalk's front, and round the posterior lobe back up to it.
  static const List<Offset> outline = <Offset>[
    Offset(-1.0, 23.6),
    Offset(-3.8, 24.0),
    Offset(-5.4, 25.6),
    Offset(-5.6, 27.8),
    Offset(-4.4, 29.8),
    Offset(-1.6, 30.6),
    Offset(1.6, 30.2),
    Offset(3.8, 29.8),
    Offset(5.4, 28.2),
    Offset(5.6, 26.0),
    Offset(4.4, 24.0),
    Offset(2.6, 23.4),
    Offset(1.0, 23.9),
  ];

  /// The lobes, the brain's own.
  static const List<Offset> anterior = BrainAnatomy.pituitaryAnterior;
  static const List<Offset> posterior = BrainAnatomy.pituitaryPosterior;

  /// The cleft between the pars anterior and the pars intermedia, along
  /// the lobes' shared edge.
  static const List<Offset> cleft = <Offset>[
    Offset(1.0, 23.9),
    Offset(2.2, 25.8),
    Offset(2.6, 28.6),
    Offset(1.6, 30.2),
  ];

  /// Where the body goes in: in the anterior lobe's middle.
  static const Offset site = Offset(-2.4, 27.2);

  /// The sphenoid's cut, round the fossa: its upper face from the planum in
  /// front, over the tuberculum, down the fossa's front wall, along its
  /// floor and up the dorsum sellae to the posterior clinoid, down the
  /// dorsum's back and the clivus's, and along its foot back to the front.
  static const List<Offset> bone = <Offset>[
    Offset(-19, 20.4),
    Offset(-12, 20.6),
    Offset(-9, 21.0),
    Offset(-7.4, 22.0),
    Offset(-6.6, 23.4),
    Offset(-6.6, 26.6),
    Offset(-6.2, 29.4),
    Offset(-4.6, 31.2),
    Offset(-1.6, 31.8),
    Offset(1.8, 31.8),
    Offset(4.6, 31.0),
    Offset(6.2, 29.0),
    Offset(6.6, 25.6),
    Offset(6.4, 22.4),
    Offset(6.6, 20.2),
    Offset(7.4, 19.4),
    Offset(8.4, 19.8),
    Offset(8.8, 21.4),
    Offset(9.8, 25),
    Offset(11, 28.6),
    Offset(12.2, 32),
    Offset(13.4, 36),
    Offset(14.4, 40),
    Offset(15.2, 43),
    Offset(-19, 43),
  ];

  /// The sphenoid sinus, an air space in the bone under the fossa and in
  /// front of it.
  static const List<Offset> sinus = <Offset>[
    Offset(-19, 23.6),
    Offset(-12, 23.2),
    Offset(-9, 24.2),
    Offset(-7.8, 26.8),
    Offset(-7.6, 30.8),
    Offset(-5.6, 33.2),
    Offset(-1, 33.8),
    Offset(3.6, 33.6),
    Offset(7, 33),
    Offset(9, 34.6),
    Offset(10, 38),
    Offset(10.4, 43),
    Offset(-19, 43),
  ];

  /// How far down the bone and the sinus show whole, and over how much
  /// further they fade out; and how far forward the planum shows whole,
  /// and over how much it fades.
  static const double footShown = 32.6;
  static const double footFade = 3.2;
  static const double frontShown = -11;
  static const double frontFade = 5;

  /// How far down what lies above the third ventricle's floor fades in:
  /// gone above the first, whole below the second.
  static const double topGone = 4.8;
  static const double topWhole = 8.6;

  /// The diaphragma sellae, from the tuberculum over the gland to the
  /// stalk, and on from the stalk to the posterior clinoid.
  static const List<Offset> diaphragmFront = <Offset>[
    Offset(-7.4, 22.0),
    Offset(-4, 22.5),
    Offset(0.6, 22.7),
  ];
  static const List<Offset> diaphragmBack = <Offset>[
    Offset(3.6, 22.3),
    Offset(6, 20.8),
    Offset(7.4, 19.6),
  ];

  /// The portal vessels down the stalk's front to the anterior lobe.
  static const List<AnatomyTube> portalVessels = <AnatomyTube>[
    AnatomyTube(
      <Offset>[Offset(2.6, 14.6), Offset(1.6, 18.6), Offset(0.4, 22.4)],
      <double>[0.25, 0.25, 0.25],
    ),
    AnatomyTube(
      <Offset>[Offset(3.2, 15.4), Offset(2.4, 19.4), Offset(1.4, 23.2)],
      <double>[0.25, 0.25, 0.25],
    ),
  ];

  // Where the parts are named.

  static const Offset posteriorName = Offset(4.2, 27);
  static const Offset stalkName = Offset(3.2, 18.6);
  static const Offset chiasmName = Offset(-2.6, 15.6);
  static const Offset sinusName = Offset(-4.4, 33.6);
  static const Offset hypothalamusName = Offset(6.4, 9.6);
}
