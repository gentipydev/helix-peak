import '../../core/biology/amino_acids.dart';
import '../format.dart';
import 'fold_geometry.dart';
import 'fold_timeline.dart';
import 'folding_track.dart';

/// The line under the fold as it plays: one per step, the step's name and
/// what it moves, counted off the track. No caption names a protein.
///
/// Each says a fact once. What the entry resolved, and which residues it did
/// not, is the header's (`PDB 4KML · residues 117–225 of 253`), so no caption
/// repeats it.
final class FoldCaptions {
  FoldCaptions(this.geometry)
    : _placed = geometry.drawn.where((FoldResidue r) => r.isOrdered).length,
      _waterAvoiding = geometry.drawn
          .where((FoldResidue r) => r.isOrdered && isWaterAvoiding(r.letter))
          .length,
      _helix = _elements(geometry, FoldShape.helix),
      _strand = _elements(geometry, FoldShape.strand);

  final FoldGeometry geometry;

  final int _placed;
  final int _waterAvoiding;

  /// How many runs of a shape the chains have, and how many residues in all.
  final (int runs, int residues) _helix;
  final (int runs, int residues) _strand;

  /// Bridges named in full; any past these are counted.
  static const int named = 3;

  /// The scale the collapse is told by, kept on one line: word joiners
  /// either side of its dash, and no-break spaces round the sign.
  static const String scale = '(Kyte\u2060–\u2060Doolittle\u00a0>\u00a00)';

  String captionOf(FoldStep step) => switch (step) {
    FoldStep.collapse =>
      'Hydrophobic collapse · ${grouped(_waterAvoiding)} of '
          '${grouped(_placed)} residues hydrophobic $scale',
    FoldStep.helices => 'Helices · ${_count(_helix)}',
    FoldStep.strands => 'Strands · ${_count(_strand)}',
    FoldStep.bridges => 'Disulfides · ${_bridges()}',
  };

  static String _count((int runs, int residues) element) => element.$1 == 0
      ? 'none'
      : '${grouped(element.$1)} (${grouped(element.$2)} residues)';

  String _bridges() {
    final List<(int, int)> pairs = geometry.bridgeNumbers;
    if (pairs.isEmpty) {
      return 'none';
    }
    final String cys = AminoAcids.abbreviationOf('C');
    final String cited = <String>[
      for (final (int a, int b) in pairs.take(named)) '$cys$a–$cys$b',
    ].join(', ');
    return pairs.length > named
        ? '$cited +${grouped(pairs.length - named)}'
        : cited;
  }

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
