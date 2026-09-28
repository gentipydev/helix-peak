import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_scene/scene.dart';

import '../../core/catalog/protein_target.dart';
import '../../core/network/track_source.dart';
import '../../core/theme/anatomy_colors.dart';
import '../structure/structure_model.dart';
import '../structure/structure_rotation.dart';

/// The fold as one still image, [width] by [height] pixels, or null where it
/// cannot be drawn.
///
/// Drawn offscreen by the walk's own renderer and loader
/// ([buildStructureModel]), so the model, its chain colours and its framing
/// are the fold page's, in the pose that page opens on. Nothing here is a
/// second way of drawing a protein.
///
/// Null is not an error. A device with no Flutter GPU cannot draw the fold at
/// all, and a model that does not arrive cannot be drawn either; a poster is
/// still worth making without it, so the caller leaves the space out.
Future<ui.Image?> renderFoldStill({
  required ProteinTarget target,
  required TrackSource tracks,
  required AnatomyColors anatomy,
  required int width,
  required int height,
}) async {
  final Scene scene;
  try {
    // Constructing a Scene reads the GPU context and throws where there is
    // none: the same probe the fold page uses.
    scene = Scene();
  } on Object catch (error) {
    debugPrint('helixpeek: no Flutter GPU for the poster fold ($error)');
    return null;
  }
  try {
    final (Node molecule, PerspectiveCamera camera) = await buildStructureModel(
      scene,
      anatomy,
      target,
      tracks,
    );
    molecule.rotation = StructureRotation().value;
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    scene.render(
      camera,
      Canvas(recorder),
      viewport: Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
      pixelRatio: 1,
    );
    final ui.Picture picture = recorder.endRecording();
    final ui.Image framed;
    try {
      framed = await picture.toImage(width, height);
    } finally {
      picture.dispose();
    }
    return await trimToContent(framed);
  } on Object catch (error) {
    debugPrint('helixpeek: could not draw the poster fold ($error)');
    return null;
  }
}

/// [image] cut down to what is drawn in it, plus [padding] pixels, where
/// the rest is transparent. [image] itself is disposed.
///
/// The fold page frames the molecule's bounding sphere, so that no turn can
/// swing it out of shot. A still never turns, and in a poster that margin is
/// most of the box, which drew the fold at a third of the size it had room
/// for. Cutting to the drawn pixels lets the poster fit the molecule itself.
/// An image with nothing transparent in it comes back as it was.
Future<ui.Image> trimToContent(ui.Image image, {int padding = 8}) async {
  final ByteData? data = await image.toByteData();
  if (data == null) {
    return image;
  }
  final Uint8List bytes = data.buffer.asUint8List(
    data.offsetInBytes,
    data.lengthInBytes,
  );
  final int width = image.width;
  final int height = image.height;
  int left = width;
  int top = height;
  int right = -1;
  int bottom = -1;
  bool clear = false;
  for (int y = 0; y < height; y++) {
    final int row = y * width * 4;
    for (int x = 0; x < width; x++) {
      if (bytes[row + x * 4 + 3] == 0) {
        clear = true;
        continue;
      }
      if (x < left) left = x;
      if (x > right) right = x;
      if (y < top) top = y;
      if (y > bottom) bottom = y;
    }
  }
  if (!clear || right < 0) {
    return image;
  }
  final Rect content = Rect.fromLTRB(
    (left - padding).clamp(0, width).toDouble(),
    (top - padding).clamp(0, height).toDouble(),
    (right + 1 + padding).clamp(0, width).toDouble(),
    (bottom + 1 + padding).clamp(0, height).toDouble(),
  );
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  Canvas(recorder)
      .drawImageRect(image, content, Offset.zero & content.size, Paint());
  final ui.Picture picture = recorder.endRecording();
  try {
    return await picture.toImage(content.width.round(), content.height.round());
  } finally {
    picture.dispose();
    image.dispose();
  }
}
