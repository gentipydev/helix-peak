import 'dart:typed_data';

import '../../features/gene_lookup/domain/entities/protein_track.dart';

/// Reads a track by protein and family, without exposing storage paths to UI.
/// Production reads cached Storage bytes; tests inject a file source.
abstract interface class TrackSource {
  /// The payload of [kind] for the protein [slug] names.
  ///
  /// Throws where there is no ready track to read — which is not the same as
  /// returning nothing. A family a protein does not have is a state the walk
  /// draws; a family it has and this could not fetch is a failure, and the two
  /// have to stay tellable apart.
  Future<Uint8List> read(String slug, TrackKind kind);
}
