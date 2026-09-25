import 'dart:typed_data';

import '../../features/gene_lookup/domain/entities/protein_track.dart';

/// Where a loader gets the bytes of one track.
///
/// The `load` methods on the track entities take one of these rather than an
/// [AssetBundle], so a family that has moved to storage and a family that is
/// still bundled are the same call with a different source behind it. That is
/// the seam this migration moves one family at a time.
///
/// It is named by slug and kind rather than by path, because a path is the one
/// thing that stops being true: `assets/clinvar/insulin_clinvar.json` is a
/// bundle key today and a digest-named object in storage tomorrow, and the
/// walk should not have to know which.
abstract interface class TrackSource {
  /// The payload of [kind] for the protein [slug] names.
  ///
  /// Throws where there is no ready track to read — which is not the same as
  /// returning nothing. A family a protein does not have is a state the walk
  /// draws; a family it has and this could not fetch is a failure, and the two
  /// have to stay tellable apart.
  Future<Uint8List> read(String slug, TrackKind kind);
}
