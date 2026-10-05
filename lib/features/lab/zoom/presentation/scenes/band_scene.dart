import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/locus_track.dart';
import '../../domain/zoom_depth.dart';
import 'body_scene.dart';
import 'zoom_scene.dart';
import 'zoom_subject.dart';

/// The gene's band as a genome browser shows it: the chromosome's bands laid
/// along the genome, a ruler in base pairs, and the gene's span on its own
/// track, where MANE puts it.
///
/// Its units are the width of the view at the band, in base pairs, from the
/// middle of the band; points are placed on screen through the camera in
/// doubles, so the view can close in by a thousandfold without a transform
/// at that scale.
final class BandScene extends ZoomScene {
  const BandScene(this.subject);

  final ZoomSubject subject;

  @override
  ZoomStop get stop => ZoomStop.band;

  LocusTrack get _track => subject.track;

  double get _width => subject.depth.widthOf(stop);

  /// A genome position in the scene's units.
  double unitOf(double position) => (position - subject.bandMiddle) / _width;

  @override
  Offset get portal => Offset(unitOf(subject.geneMiddle), 0);

  /// Where the band strip and the ruler sit above the gene's track, in
  /// pixels from the middle of the view.
  static const double stripY = -46;
  static const double rulerY = -84;

  double _x(ZoomFrame frame, double position) =>
      frame.toScreen(Offset(unitOf(position), 0)).dx;

  @override
  void stage(ZoomFrame frame, ZoomStaging out) {
    final double mid = frame.size.height / 2;
    final Offset gene = Offset(_x(frame, subject.geneMiddle), mid);
    out.item('band:gene', gene, frame.opacity);
    out.callout('band', subject.record.gene, gene, calloutPresence(frame));
  }

  @override
  void paint(Canvas canvas, ZoomFrame frame) {
    final double w = frame.size.width;
    final double mid = frame.size.height / 2;
    double clampX(double x) => x.clamp(-8.0, w + 8);
    final double left = subject.bandMiddle +
        frame.view.fromScreen(Offset.zero, frame.size).dx * _width;
    final double right = subject.bandMiddle +
        frame.view.fromScreen(Offset(w, 0), frame.size).dx * _width;

    // The bands in view, in their stain, the gene's own outlined.
    final Paint fill = Paint();
    final Color pale = frame.inks.scale.giemsaPale;
    final Color dark = frame.inks.scale.giemsaDark;
    for (final CytoBand band in _track.bands) {
      if (band.end < left || band.start > right) {
        continue;
      }
      fill.color = switch (band.stain) {
        Stain.acen => frame.inks.scale.centromere,
        Stain.gvar => Color.lerp(pale, dark, 0.35)!,
        _ => Color.lerp(pale, dark, 0.1 + 0.85 * band.stain.depth)!,
      };
      canvas.drawRect(
        Rect.fromLTRB(
          clampX(_x(frame, band.start.toDouble())),
          mid + stripY - 9,
          clampX(_x(frame, band.end + 1)),
          mid + stripY + 9,
        ),
        fill,
      );
    }
    canvas.drawRect(
      Rect.fromLTRB(
        clampX(_x(frame, _track.bandStart.toDouble())),
        mid + stripY - 12,
        clampX(_x(frame, _track.bandEnd + 1)),
        mid + stripY + 12,
      ),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = frame.inks.mark,
    );

    // A ruler: ticks at a round step, about four across the view.
    final double span = right - left;
    final double step = _roundStep(span / 4);
    final Paint rule = Paint()
      ..strokeWidth = 1
      ..color = frame.inks.label;
    canvas.drawLine(
      Offset(0, mid + rulerY),
      Offset(w, mid + rulerY),
      rule..color = frame.inks.outline,
    );
    rule.color = frame.inks.label;
    for (double at = (left / step).ceil() * step; at <= right; at += step) {
      final double x = _x(frame, at);
      canvas.drawLine(
        Offset(x, mid + rulerY - 4),
        Offset(x, mid + rulerY + 4),
        rule,
      );
      final TextPainter number = TextPainter(
        text: TextSpan(
          text: basePairLabel(at),
          style: frame.labels.copyWith(
            color: frame.inks.label.withValues(alpha: frame.opacity),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      number.paint(
        canvas,
        Offset(x - number.width / 2, mid + rulerY - 8 - number.height),
      );
      number.dispose();
    }

    // The gene, on its own track: at least two pixels wide.
    final double a = _x(frame, _track.spanStart.toDouble());
    final double b = _x(frame, _track.spanEnd + 1);
    final double centre = (a + b) / 2;
    final double half = math.max((b - a).abs() / 2, 1);
    canvas.drawRect(
      Rect.fromLTRB(
        clampX(centre - half),
        mid - 5,
        clampX(centre + half),
        mid + 5,
      ),
      Paint()..color = frame.inks.mark,
    );
  }

  /// A round step near [rough]: 1, 2 or 5 times a power of ten.
  static double _roundStep(double rough) {
    if (rough <= 0) {
      return 1;
    }
    final double power = math
        .pow(10, (math.log(rough) / math.ln10).floor())
        .toDouble();
    for (final double k in <double>[1, 2, 5, 10]) {
      if (power * k >= rough) {
        return power * k;
      }
    }
    return power * 10;
  }
}
