import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/locus_track.dart';
import '../../domain/zoom_camera.dart';
import '../../domain/zoom_depth.dart';
import 'body_scene.dart';
import 'zoom_scene.dart';
import 'zoom_subject.dart';

/// The gene's band as a genome browser shows it: the chromosome as a strip
/// of its bands laid along the genome, the whole of it docked above as a
/// map with the view boxed on it, a ruler in base pairs, and the gene's span
/// on its own track, where MANE puts it.
///
/// It takes over from the chromosome as it turns to lie along the genome:
/// the strip appears where the turned chromosome lies, on the middle of the
/// view, and rises to make room for the gene's track as the ruler and the
/// map come up.
///
/// Its units are the width of the view at the band, in base pairs, from the
/// middle of the band; points are placed on screen through the camera in
/// doubles, so the view can close in a thousandfold without a transform at
/// that scale.
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

  @override
  double asChild(double progress) => smoothstep((progress - 0.3) / 0.45);

  @override
  double asParent(double progress) =>
      1 - smoothstep((progress - 0.5) / 0.45);

  /// Where the band strip and the ruler come to sit above the gene's track,
  /// in pixels from the middle of the view.
  static const double stripY = -46;
  static const double rulerY = -84;

  /// The strip's thickness, in pixels: the chromosome thins to it.
  static const double strip = 18;

  double _x(ZoomFrame frame, double position) =>
      frame.toScreen(Offset(unitOf(position), 0)).dx;

  /// How far the strip has risen from the middle, and how much the ruler,
  /// the docked map and the gene's track show: all of it once the band is
  /// reached.
  (double, double, double, double) _beats(ZoomFrame frame) {
    if (!frame.isChild) {
      return (stripY, 1, 1, 1);
    }
    final double s = frame.progress;
    return (
      stripY * smootherstep((s - 0.5) / 0.45),
      smoothstep((s - 0.6) / 0.3),
      smoothstep((s - 0.55) / 0.3),
      smoothstep((s - 0.7) / 0.3),
    );
  }

  @override
  void stage(ZoomFrame frame, ZoomStaging out) {
    final double mid = frame.size.height / 2;
    final Offset gene = Offset(_x(frame, subject.geneMiddle), mid);
    final (double _, double _, double _, double track) = _beats(frame);
    out.item('band:gene', gene, frame.opacity * track);
    out.callout(
      'band',
      subject.record.gene,
      gene,
      math.min(calloutPresence(frame), track),
    );
  }

  Color _stain(ZoomFrame frame, CytoBand band) {
    final Color pale = frame.inks.scale.giemsaPale;
    final Color dark = frame.inks.scale.giemsaDark;
    return switch (band.stain) {
      Stain.acen => frame.inks.scale.centromere,
      Stain.gvar => Color.lerp(pale, dark, 0.5)!,
      Stain.stalk => Color.lerp(pale, dark, 0.2)!,
      _ => Color.lerp(pale, dark, 0.06 + 0.88 * band.stain.depth)!,
    };
  }

  @override
  void paint(Canvas canvas, ZoomFrame frame) {
    final double w = frame.size.width;
    final double mid = frame.size.height / 2;
    final (double rise, double ruler, double dock, double track) = _beats(
      frame,
    );
    double clampX(double x) => x.clamp(-8.0, w + 8);
    final double left =
        subject.bandMiddle +
        frame.view.fromScreen(Offset.zero, frame.size).dx * _width;
    final double right =
        subject.bandMiddle +
        frame.view.fromScreen(Offset(w, 0), frame.size).dx * _width;

    // The strip: the bands in view, in their stains, the gene's outlined.
    final double y = mid + rise;
    final Paint fill = Paint();
    for (final CytoBand band in _track.bands) {
      if (band.end < left || band.start > right) {
        continue;
      }
      fill.color = _stain(frame, band);
      final double thin = band.stain == Stain.acen || band.stain == Stain.stalk
          ? 0.6
          : 1;
      canvas.drawRect(
        Rect.fromLTRB(
          clampX(_x(frame, band.start.toDouble())),
          y - strip / 2 * thin,
          clampX(_x(frame, band.end + 1)),
          y + strip / 2 * thin,
        ),
        fill,
      );
    }
    canvas.drawRect(
      Rect.fromLTRB(
        clampX(_x(frame, _track.bandStart.toDouble())),
        y - strip / 2 - 3,
        clampX(_x(frame, _track.bandEnd + 1)),
        y + strip / 2 + 3,
      ),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = frame.inks.mark,
    );

    if (ruler > 0) {
      _ruler(canvas, frame, left, right, mid + rulerY, ruler);
    }
    if (dock > 0) {
      _dock(canvas, frame, left, right, dock);
    }
    if (track > 0) {
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
        Paint()..color = frame.inks.mark.withValues(alpha: track),
      );
    }
  }

  /// A ruler across the view, ticks at a round step and each numbered.
  void _ruler(
    Canvas canvas,
    ZoomFrame frame,
    double left,
    double right,
    double y,
    double alpha,
  ) {
    final double w = frame.size.width;
    final double step = roundStep((right - left) / 4);
    final Paint rule = Paint()
      ..strokeWidth = 1
      ..color = frame.inks.outline.withValues(alpha: alpha);
    canvas.drawLine(Offset(0, y), Offset(w, y), rule);
    rule.color = frame.inks.label.withValues(alpha: alpha);
    for (double at = (left / step).ceil() * step; at <= right; at += step) {
      final double x = _x(frame, at);
      canvas.drawLine(Offset(x, y - 4), Offset(x, y + 4), rule);
      final TextPainter number = TextPainter(
        text: TextSpan(
          text: rulerLabel(at, step),
          style: frame.labels.copyWith(
            color: frame.inks.label.withValues(alpha: alpha * frame.opacity),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      number.paint(canvas, Offset(x - number.width / 2, y - 8 - number.height));
      number.dispose();
    }
  }

  /// The whole chromosome, docked along the top, with the view boxed on it.
  void _dock(
    Canvas canvas,
    ZoomFrame frame,
    double left,
    double right,
    double alpha,
  ) {
    const double margin = 16;
    const double top = 30;
    const double height = 10;
    final double width = frame.size.width - 2 * margin - 28;
    final double length = _track.length.toDouble();
    double x(double position) => margin + position / length * width;
    final Paint fill = Paint();
    for (final CytoBand band in _track.bands) {
      fill.color = _stain(frame, band).withValues(alpha: alpha);
      final double thin = band.stain == Stain.acen ? 0.55 : 1;
      canvas.drawRect(
        Rect.fromLTRB(
          x(band.start - 1.0),
          top + height / 2 * (1 - thin),
          x(band.end.toDouble()),
          top + height / 2 * (1 + thin),
        ),
        fill,
      );
    }
    final double a = x(left.clamp(0.0, length));
    final double b = math.max(x(right.clamp(0.0, length)), a + 2);
    canvas.drawRect(
      Rect.fromLTRB(a, top - 4, b, top + height + 4),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = frame.inks.mark.withValues(alpha: alpha),
    );
    final TextPainter name = TextPainter(
      text: TextSpan(
        text: 'chr${_track.chromosome}',
        style: frame.labels.copyWith(
          color: frame.inks.label.withValues(alpha: alpha),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    name.paint(canvas, Offset(margin, top - 6 - name.height));
    name.dispose();
  }
}

/// A round step near [rough]: 1, 2 or 5 times a power of ten.
double roundStep(double rough) {
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
