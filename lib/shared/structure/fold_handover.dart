import 'dart:ui';

import '../folding/fold_timeline.dart';

/// The final surface takes over as soon as the bridges have closed, within
/// the existing nine-second timeline. Both ends have zero speed and zero
/// acceleration, so the change in shading starts and finishes gently.
double foldHandoverAt(double t) {
  final double u =
      ((t - FoldTimeline.bridgesClosedAt) / (1 - FoldTimeline.bridgesClosedAt))
          .clamp(0.0, 1.0);
  return u * u * u * (10 + u * (-15 + 6 * u));
}

/// Mixes two fully shaded, opaque-surface renders in premultiplied space.
///
/// Each render has its own depth buffer. Mixing their completed images
/// avoids intersecting surfaces, transparent back faces and depth flicker.
/// `plus` keeps the weights complementary: ordinary source-over would dim
/// matching pixels halfway through and reveal the model's outline early.
void paintFoldHandover(
  Canvas canvas,
  Rect bounds, {
  required double progress,
  required void Function() paintFold,
  required void Function() paintModel,
}) {
  final double p = progress.clamp(0.0, 1.0);
  if (p <= 0) {
    paintFold();
    return;
  }
  if (p >= 1) {
    paintModel();
    return;
  }
  canvas.saveLayer(bounds, Paint());
  canvas.saveLayer(
    bounds,
    Paint()..color = Color.fromRGBO(255, 255, 255, 1 - p),
  );
  paintFold();
  canvas.restore();
  canvas.saveLayer(
    bounds,
    Paint()
      ..color = Color.fromRGBO(255, 255, 255, p)
      ..blendMode = BlendMode.plus,
  );
  paintModel();
  canvas.restore();
  canvas.restore();
}
