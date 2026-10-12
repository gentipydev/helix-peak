import '../catalog/protein_target.dart';
import '../catalog/protein_track.dart';

/// A track source that reads a protein by rows it holds: one generation of
/// its tracks, fixed when the walk that reads them opened.
///
/// A protein built on demand can have its fold published again while the app
/// runs: an experimental entry where it drew AlphaFold's model, or an earlier
/// fold put back. Every object stays where it was, so a walk reading by the
/// rows it opened with stays whole; the next walk opened reads the new ones.
/// [TrackSource] is not given this: the walk's tests implement it, and a
/// source that is not one of these reads as it always has.
abstract interface class TrackRows {
  /// The rows [slug]'s tracks are read by, or null where this source holds
  /// none for it.
  Map<TrackKind, TrackRef>? rowsOf(String slug);
}

/// How far a protein's row and its track rows are one fold.
enum FoldCoherence {
  /// The row's words and chains are the model's, and its fold, where it has
  /// one, was made in that model's frame.
  whole,

  /// The row and the model agree, and the fold was made with another model:
  /// it is drawn still.
  modelOnly,

  /// The row names another model than the one its track holds.
  none,
}

/// Whether [target]'s row and [rows] are one generation of its fold.
///
/// The structure track's provenance names its entry and its nodes, as the
/// row's words and chains do, and its `.glb` by digest; the folding track's
/// provenance names the `.glb` it was made in the frame of. A model or a fold
/// that is not ready has nothing to disagree with.
FoldCoherence foldCoherence(
  ProteinTarget target,
  Map<TrackKind, TrackRef> rows,
) {
  final TrackRef? structure = rows[TrackKind.structure];
  if (structure == null || structure.state != TrackState.ready) {
    return FoldCoherence.whole;
  }
  final Map<String, dynamic> made = structure.provenance;
  final Object? pdb = made['pdb'];
  final Object? nodes = made['nodes'];
  final String? named = target.structure?.pdb;
  if ((named != null && pdb is String && pdb != named) ||
      (nodes is List<dynamic> &&
          !_same(nodes, <String>[
            for (final StructureChain chain in target.chains) chain.node,
          ]))) {
    return FoldCoherence.none;
  }
  final TrackRef? folding = rows[TrackKind.folding];
  if (folding == null || folding.state != TrackState.ready) {
    return FoldCoherence.whole;
  }
  final Object? glb = made['glb'];
  final Object? frame = folding.provenance['frame'];
  final Object? model = glb is Map<String, dynamic> ? glb['sha256'] : null;
  final Object? framed = frame is Map<String, dynamic>
      ? frame['glb_sha256']
      : null;
  return model is String && model == framed
      ? FoldCoherence.whole
      : FoldCoherence.modelOnly;
}

bool _same(List<dynamic> a, List<String> b) {
  if (a.length != b.length) {
    return false;
  }
  for (int i = 0; i < a.length; i++) {
    if (a[i] != b[i]) {
      return false;
    }
  }
  return true;
}
