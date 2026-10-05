import 'package:flutter/material.dart';

import '../../domain/locus_track.dart';
import '../../domain/zoom_depth.dart';
import 'body_scene.dart';
import 'zoom_scene.dart';
import 'zoom_subject.dart';

/// The gene's chromosome, condensed as it is when a cell divides, stained in
/// its cytoBand bands, with the gene's band marked and named. Never the gene,
/// which is far too small to see at this scale.
final class ChromosomeScene extends ZoomScene {
  const ChromosomeScene(this.subject);

  final ZoomSubject subject;

  @override
  ZoomStop get stop => ZoomStop.chromosome;

  LocusTrack get _track => subject.track;

  /// The chromosome's length in the scene's units: the view is one and a
  /// half times it.
  static const double length = 1 / 1.5;

  /// Half the chromosome's width, in the scene's units.
  static const double half = 0.045;

  double yOf(int base) =>
      -length / 2 + (base - 1) / _track.length * length;

  double get _bandY => (yOf(_track.bandStart) + yOf(_track.bandEnd)) / 2;

  @override
  Offset get portal => Offset(0, _bandY);

  @override
  void stage(ZoomFrame frame, ZoomStaging out) {
    final Offset target = frame.toScreen(Offset(half, _bandY));
    out.item('chromosome:target', target, frame.opacity);
    out.callout('chromosome', _track.locus, target, calloutPresence(frame));
  }

  @override
  void paint(Canvas canvas, ZoomFrame frame) {
    canvas.save();
    frame.enter(canvas);
    final double pixel = frame.pixel;
    final RRect outline = RRect.fromRectAndRadius(
      Rect.fromLTRB(-half, yOf(1), half, yOf(_track.length + 1)),
      const Radius.circular(half),
    );
    canvas.save();
    canvas.clipRRect(outline);
    final Paint fill = Paint();
    final Color pale = frame.inks.scale.giemsaPale;
    final Color dark = frame.inks.scale.giemsaDark;
    for (final CytoBand band in _track.bands) {
      final double top = yOf(band.start);
      final double bottom = yOf(band.end + 1);
      final double w = switch (band.stain) {
        Stain.acen => half * 0.55,
        Stain.stalk => half * 0.35,
        _ => half,
      };
      fill.color = switch (band.stain) {
        Stain.acen => frame.inks.scale.centromere,
        Stain.gvar => Color.lerp(pale, dark, 0.35)!,
        _ => Color.lerp(pale, dark, 0.1 + 0.85 * band.stain.depth)!,
      };
      canvas.drawRect(Rect.fromLTRB(-w, top, w, bottom), fill);
    }
    canvas.restore();
    canvas.drawRRect(
      outline,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4 * pixel
        ..color = frame.inks.outline,
    );
    final Rect band = Rect.fromLTRB(
      -half - 4 * pixel,
      yOf(_track.bandStart),
      half + 4 * pixel,
      yOf(_track.bandEnd + 1),
    );
    canvas.drawRect(
      band,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2 * pixel
        ..color = frame.inks.mark,
    );
    canvas.restore();
  }
}
