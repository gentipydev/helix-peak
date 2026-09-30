import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/anatomy_colors.dart';
import '../../../../core/theme/nucleotide_colors.dart';

/// What a drawn part of the replication scene is coloured as.
enum SceneInk {
  ink,
  quiet,
  parental,
  newDna,
  rna,
  helicase,
  polymerase,
  primase,
  rpa,
  clamp,
  nuclease,
  ligase,
  topoisomerase,
}

/// The replication scene's colours, each taken from the theme.
///
/// The three strands are the only saturated colours on screen: parental DNA
/// a neutral grey, new DNA a teal and RNA an amber. Every pair stays at least
/// 20 ΔE00 apart for normal vision and through protan, deutan and tritan
/// simulation (Machado 2009), and a strand's bases wear its colour, so which
/// strand is old, new or RNA reads at a glance. Proteins are muted, one hue
/// family each, so they frame the strands rather than compete with them.
@immutable
class ReplicationInks {
  const ReplicationInks({
    required this.ground,
    required this.ink,
    required this.quiet,
    required this.parental,
    required this.newDna,
    required this.rna,
    required this.helicase,
    required this.polymerase,
    required this.primase,
    required this.rpa,
    required this.clamp,
    required this.nuclease,
    required this.ligase,
    required this.topoisomerase,
  });

  factory ReplicationInks.of(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final AnatomyColors anatomy = context.anatomyColors;
    final NucleotideColors bases = context.nucleotideColors;
    Color mix(Color a, Color b, double t) => Color.lerp(a, b, t)!;
    final Color ground = scheme.surface;
    final Color grey = bases.unknown;
    return ReplicationInks(
      ground: ground,
      ink: scheme.onSurface,
      quiet: scheme.onSurfaceVariant,
      parental: mix(mix(grey, scheme.onSurfaceVariant, 0.3), ground, 0.2),
      newDna: mix(
        mix(scheme.primary, anatomy.roleCds, 0.2),
        scheme.onSurface,
        0.08,
      ),
      // Unfiltered: the Kaleido filter halves chroma, and RNA must stay the
      // one warm, saturated strand.
      rna: mix(
        AnatomyColors.dark.aminoSpecial,
        AnatomyColors.dark.aminoCysteine,
        0.15,
      ),
      helicase: mix(anatomy.roleExon, grey, 0.35),
      polymerase: mix(mix(anatomy.roleCds, ground, 0.3), grey, 0.3),
      primase: mix(anatomy.roleUtr5, grey, 0.25),
      rpa: mix(anatomy.roleSignal, grey, 0.2),
      clamp: mix(mix(anatomy.roleMature1, anatomy.roleUtr5, 0.55), grey, 0.3),
      nuclease: mix(anatomy.roleStopCodon, grey, 0.45),
      ligase: mix(anatomy.roleMature2, scheme.onSurfaceVariant, 0.35),
      topoisomerase: mix(anatomy.roleUtr3, scheme.onSurfaceVariant, 0.35),
    );
  }

  final Color ground;
  final Color ink;
  final Color quiet;
  final Color parental;
  final Color newDna;
  final Color rna;
  final Color helicase;
  final Color polymerase;
  final Color primase;
  final Color rpa;
  final Color clamp;
  final Color nuclease;
  final Color ligase;
  final Color topoisomerase;

  Color operator [](SceneInk ink) => switch (ink) {
    SceneInk.ink => this.ink,
    SceneInk.quiet => quiet,
    SceneInk.parental => parental,
    SceneInk.newDna => newDna,
    SceneInk.rna => rna,
    SceneInk.helicase => helicase,
    SceneInk.polymerase => polymerase,
    SceneInk.primase => primase,
    SceneInk.rpa => rpa,
    SceneInk.clamp => clamp,
    SceneInk.nuclease => nuclease,
    SceneInk.ligase => ligase,
    SceneInk.topoisomerase => topoisomerase,
  };

  List<Color> get _all => <Color>[
    ground,
    ink,
    quiet,
    parental,
    newDna,
    rna,
    helicase,
    polymerase,
    primase,
    rpa,
    clamp,
    nuclease,
    ligase,
    topoisomerase,
  ];

  @override
  bool operator ==(Object other) =>
      other is ReplicationInks && listEquals(other._all, _all);

  @override
  int get hashCode => Object.hashAll(_all);
}
