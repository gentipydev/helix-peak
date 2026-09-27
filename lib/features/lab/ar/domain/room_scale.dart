import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../../../core/catalog/protein_track.dart';

/// A fold at room scale, as its `structure_ar` track describes it.
///
/// The track is a USDZ for AR Quick Look, with a `.glb` beside it for Android's
/// Scene Viewer, both at one angstrom to one centimetre (`pipeline/structure_ar`
/// in the backend). The row's provenance says how big the molecule really is,
/// and that is what the screen says too: nothing here assumes a size.
@immutable
final class RoomScale {
  const RoomScale({required this.box, required this.glb});

  /// The fold's real bounding box, x by y by z, in angstroms.
  final List<double> box;

  /// Where Scene Viewer can fetch the fold at room scale.
  final Uri glb;

  /// One angstrom is drawn as one centimetre.
  static const double centimetresPerAngstrom = 1;

  /// The longest side, in angstroms, which is its length in the room in cm.
  double get longestAngstroms => box.reduce(math.max);

  /// Read from a ready `structure_ar` row, or null where there is none to
  /// read: no row yet, or one whose provenance does not say what this needs.
  static RoomScale? of(TrackRef? track) {
    if (track == null || track.state != TrackState.ready) {
      return null;
    }
    final String? url = track.url;
    final Object? box = track.provenance['bbox_angstrom'];
    final Object? glb = track.provenance['glb'];
    if (url == null || box is! List || box.length != 3 || glb is! Map) {
      return null;
    }
    final String? path = glb['path'] as String?;
    final List<double> sides = <double>[
      for (final Object? side in box) (side as num?)?.toDouble() ?? 0,
    ];
    if (path == null || sides.any((double side) => side <= 0)) {
      return null;
    }
    // The `.glb` sits in the same bucket as the USDZ the row names, under its
    // own object path; the backend's fetch_tracks.py finds it the same way.
    final String kind = '/${path.split('/').first}/';
    final int at = url.lastIndexOf(kind);
    if (at < 0) {
      return null;
    }
    return RoomScale(
      box: sides,
      glb: Uri.parse(url.substring(0, at + 1) + path),
    );
  }

  /// Scene Viewer, opened on [glb] at its own size: `ar_preferred` falls back
  /// to a plain 3D view on a phone with no ARCore, and `resizable=false` keeps
  /// a pinch from breaking the one-angstrom-to-one-centimetre promise.
  Uri sceneViewer({required String title}) =>
      Uri.https('arvr.google.com', '/scene-viewer/1.2', <String, String>{
        'file': glb.toString(),
        'mode': 'ar_preferred',
        'resizable': 'false',
        'title': title,
      });
}
