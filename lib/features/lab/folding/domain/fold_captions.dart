import '../../../../core/biology/amino_acids.dart';
import '../../../../shared/format.dart';
import 'fold_geometry.dart';
import 'fold_timeline.dart';
import 'folding_track.dart';

/// The words under the fold animation: one caption per step, and the notes
/// that stay beside all of them. Every number is counted off the track; no
/// caption names a protein.
final class FoldCaptions {
  FoldCaptions(this.geometry)
    : _placed = geometry.drawn.where((FoldResidue r) => r.isOrdered).length,
      _waterAvoiding = geometry.drawn
          .where((FoldResidue r) => r.isOrdered && isWaterAvoiding(r.letter))
          .length,
      _loose = geometry.drawn.where((FoldResidue r) => !r.isOrdered).length,
      _helix = _elements(geometry, FoldShape.helix),
      _strand = _elements(geometry, FoldShape.strand);

  final FoldGeometry geometry;

  final int _placed;
  final int _waterAvoiding;
  final int _loose;

  /// How many runs of a shape the chains have, and how many residues in all.
  final (int runs, int residues) _helix;
  final (int runs, int residues) _strand;

  /// Beside every step: what this is, and what it is not.
  String get illustration =>
      'An illustration, not a simulation. The order of the steps is the '
      'textbook’s; only the last frame is measured: the ${geometry.track.pdb} '
      'structure the fold page draws.';

  /// Beside every step of a fold with residues that have no place, and null
  /// for one without.
  String? get looseNote {
    if (_loose == 0) {
      return null;
    }
    return '${_residues(_loose, leading: true)} no fixed shape and stay loose '
        'throughout: the experiment that solved this structure never placed '
        '${_loose == 1 ? 'it' : 'them'}.';
  }

  String captionOf(FoldStep step) => switch (step) {
    FoldStep.collapse =>
      'The chain draws together, water-avoiding residues first. '
          '${spelledLeading(_waterAvoiding)} of the ${grouped(_placed)} '
          'residues it folds with score above zero on the Kyte–Doolittle '
          'hydropathy scale, and they move furthest in.',
    FoldStep.helices =>
      _helix.$1 == 0
          ? 'No residue of this fold sits in a helix, so nothing coils.'
          : '${spelledLeading(_helix.$1)} '
                '${_helix.$1 == 1 ? 'helix coils' : 'helices coil'}: '
                '${grouped(_helix.$2)} residues wind into the turns the '
                'structure has them in.',
    FoldStep.strands =>
      _strand.$1 == 0
          ? 'No residue of this fold sits in a strand, so nothing pairs into '
                'a sheet. The loops between the helices settle instead.'
          : '${spelledLeading(_strand.$1)} '
                '${_strand.$1 == 1 ? 'strand moves' : 'strands move'} in '
                'beside ${_strand.$1 == 1 ? 'its partner' : 'their partners'} '
                'and pair into sheets, with the loops between: '
                '${grouped(_strand.$2)} residues.',
    FoldStep.bridges => _bridges(),
  };

  String _bridges() {
    final List<(int, int)> pairs = geometry.bridgeNumbers;
    if (pairs.isEmpty) {
      return 'No disulfide bridge holds this fold, so nothing snaps shut. '
          'What is left is the fold the structure page draws.';
    }
    const int named = 4;
    final List<String> cited = <String>[
      for (final (int a, int b) in pairs.take(named))
        '${AminoAcids.abbreviationOf('C')}$a–'
            '${AminoAcids.abbreviationOf('C')}$b',
    ];
    final String more = pairs.length > named
        ? ', and ${spelled(pairs.length - named)} more'
        : '';
    return '${spelledLeading(pairs.length)} disulfide '
        '${pairs.length == 1 ? 'bridge snaps' : 'bridges snap'} shut: '
        '${cited.join(', ')}$more. What is left is the fold the structure page '
        'draws.';
  }

  static String _residues(int count, {bool leading = false}) =>
      '${leading ? spelledLeading(count) : spelled(count)} '
      '${count == 1 ? 'residue has' : 'residues have'}';

  static (int, int) _elements(FoldGeometry geometry, FoldShape shape) {
    int runs = 0;
    int residues = 0;
    for (final (int start, int end) in geometry.chainRuns) {
      bool inside = false;
      for (int i = start; i < end; i++) {
        final bool here = geometry.drawn[i].shape == shape;
        if (here) {
          residues++;
          if (!inside) {
            runs++;
          }
        }
        inside = here;
      }
    }
    return (runs, residues);
  }
}
