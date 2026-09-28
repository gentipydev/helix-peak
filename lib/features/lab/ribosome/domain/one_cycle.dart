import '../../../../shared/motion/animation_timeline.dart';
import '../../../../shared/ribosome/translation_timeline.dart';

/// One elongation cycle of a [TranslationTimeline], on its own: the beat in
/// which [codon] is read, stretched over `t` from 0 to 1.
///
/// Its phases are that beat's four slices, so the transport bar's step
/// buttons walk decoding, peptide bond, translocation and tRNA exit one at a
/// time. Every state is the full timeline's own state at the same moment:
/// nothing about the cycle is drawn differently for being shown alone.
final class OneCycle extends AnimationTimeline<TranslationState> {
  OneCycle(this.translation, {required this.codon})
    : assert(
        codon >= 2 && codon <= translation.protein.length,
        'a codon the A site reads',
      );

  final TranslationTimeline translation;

  /// The codon whose beat this is: 2 is the first elongation cycle.
  final int codon;

  int get _beat => translation.beatOfCodon(codon);

  @override
  int get beats => 1;

  @override
  late final List<PhaseMark> phases = List<PhaseMark>.unmodifiable(<PhaseMark>[
    for (final PhaseMark mark in translation.phases)
      if (translation.beatAt(mark.t).$1 == _beat &&
          mark.t < translation.beatStart(_beat + 1))
        PhaseMark(
          name: mark.name,
          t: (mark.t * translation.beats - _beat).clamp(0.0, 1.0),
          captionKey: mark.captionKey,
        ),
  ]);

  @override
  TranslationState stateAt(double t) => translation.stateAt(fullT(t));

  /// Where [t] of this cycle falls on the whole translation.
  double fullT(double t) => translation.beatStart(_beat + t.clamp(0.0, 1.0));
}
