import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/locus_track.dart';
import '../../domain/zoom_camera.dart';
import '../../domain/zoom_depth.dart';
import '../zoom_inks.dart';
import 'body_scene.dart';
import 'sculpt.dart';
import 'zoom_scene.dart';
import 'zoom_subject.dart';

/// The gene's band as a genome browser shows it: the chromosome opened out
/// as a lit strip of its bands laid along the genome, each named, the
/// gene's band ringed in the mark and the gene marked on the strip where
/// MANE puts it; the whole chromosome docked above as a map with the view
/// boxed on it, and a funnel from the box down to the strip; and a ruler in
/// base pairs.
///
/// It takes over from the chromosome as it turns to lie along the genome:
/// the strip appears where the turned chromosome lies, on the middle of the
/// view, and stays there as the ruler, the map and the gene's mark come up.
/// On the way out the zoom goes into the strip where the DNA's view lies,
/// read from the left end of the gene's mark ([ZoomSubject.geneEntry]), and
/// the map gives way over the first half of the step as the gene's own DNA
/// opens out of the mark.
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
  Offset get portal => Offset(unitOf(subject.geneEntry), 0);

  @override
  double asChild(double progress) => smoothstep((progress - 0.3) / 0.45);

  // The step out goes down to the DNA, past the gene's whole scale, so the
  // map gives way while the gene is still small on it.
  @override
  double asParent(double progress) => 1 - smoothstep((progress - 0.1) / 0.45);

  /// Where the ruler runs, in pixels below the middle of the view, where
  /// the strip lies.
  static const double rulerY = 40;

  /// The strip's thickness, in pixels: the chromosome thins to it.
  static const double strip = 26;

  /// How far the gene's mark stands above and below the strip, in pixels:
  /// prouder than the band's own ring, which stands 3.
  static const double markReach = 8;

  /// The gene's mark at its least width, in pixels: a gene far narrower
  /// than a pixel is still a tick across the strip.
  static const double tick = 1.5;

  /// The whole chromosome docked along the top: how far down, and how
  /// thick.
  static const double dockTop = 44;
  static const double dockHeight = 14;

  double _x(ZoomFrame frame, double position) =>
      frame.toScreen(Offset(unitOf(position), 0)).dx;

  /// How much the ruler, the docked map and the gene's mark show: all of
  /// them once the band is reached.
  (double, double, double) _beats(ZoomFrame frame) {
    if (!frame.isChild) {
      return (1, 1, 1);
    }
    final double s = frame.progress;
    return (
      smoothstep((s - 0.6) / 0.3),
      smoothstep((s - 0.55) / 0.3),
      smoothstep((s - 0.7) / 0.3),
    );
  }

  // The gene is named at the top of its mark, where the zoom goes into it:
  // on a mark at its least width that is its middle, and on a wide one a
  // point that stays put as the view closes in on it.
  @override
  void stage(ZoomFrame frame, ZoomStaging out) {
    final double mid = frame.size.height / 2;
    final Offset gene = Offset(
      _x(frame, subject.geneEntry),
      mid - strip / 2 - markReach,
    );
    final (double _, double _, double mark) = _beats(frame);
    out.item('band:gene', gene, frame.opacity * mark);
    out.callout(
      'band',
      subject.record.gene,
      gene,
      math.min(calloutPresence(frame), mark),
    );
  }

  /// A band in its stain, as the strip and the chromosome both draw it:
  /// the pale bands lit, the dark ones deep, the centromere deepest.
  static Color stain(ZoomInks inks, Stain stain) {
    final Color pale = inks.lit(0.56);
    final Color dark = inks.shade(0.55);
    return switch (stain) {
      Stain.acen => inks.shade(0.42),
      Stain.gvar => Color.lerp(pale, dark, 0.5)!,
      Stain.stalk => Color.lerp(pale, dark, 0.2)!,
      _ => Color.lerp(pale, dark, 0.06 + 0.88 * stain.depth)!,
    };
  }

  @override
  void paint(Canvas canvas, ZoomFrame frame) {
    final double w = frame.size.width;
    final double mid = frame.size.height / 2;
    final ZoomInks inks = frame.inks;
    final (double ruler, double dock, double mark) = _beats(frame);
    double clampX(double x) => x.clamp(-8.0, w + 8);
    final double left =
        subject.bandMiddle +
        frame.view.fromScreen(Offset.zero, frame.size).dx * _width;
    final double right =
        subject.bandMiddle +
        frame.view.fromScreen(Offset(w, 0), frame.size).dx * _width;
    final double y = mid;

    // The funnel from the docked chromosome's box down to the strip, under
    // everything: the stretch of the whole the strip opens out.
    if (dock > 0) {
      _funnel(canvas, frame, left, right, y - strip / 2, dock);
    }

    // The strip: the chromatid's tube opened along the genome, its bands in
    // their stains, lit from above, the gene's band ringed in the mark.
    final Paint fill = Paint();
    final double from = clampX(_x(frame, 1));
    final double to = clampX(_x(frame, _track.length + 1.0));
    final Rect tube = Rect.fromLTRB(from, y - strip / 2, to, y + strip / 2);
    canvas.save();
    canvas.clipRRect(
      RRect.fromRectAndRadius(tube, const Radius.circular(strip / 2)),
    );
    for (final CytoBand band in _track.bands) {
      if (band.end < left || band.start > right) {
        continue;
      }
      fill.color = stain(frame.inks, band.stain);
      final double thin = band.stain == Stain.acen || band.stain == Stain.stalk
          ? 0.55
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
      tube,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            inks.text.withValues(alpha: 0.05),
            inks.text.withValues(alpha: 0.22),
            inks.text.withValues(alpha: 0),
            inks.shadow.withValues(alpha: 0.5),
          ],
          stops: const <double>[0, 0.25, 0.55, 1],
        ).createShader(tube),
    );
    canvas.restore();
    final Rect own = Rect.fromLTRB(
      clampX(_x(frame, _track.bandStart.toDouble())),
      y - strip / 2 - 3,
      clampX(_x(frame, _track.bandEnd + 1)),
      y + strip / 2 + 3,
    );
    final Path ring = Path()
      ..addRRect(RRect.fromRectAndRadius(own, const Radius.circular(5)));
    Sculpt.glowingStroke(canvas, ring, inks, width: 1.8);
    _names(canvas, frame, y, ruler);

    if (ruler > 0) {
      _ruler(canvas, frame, left, right, mid + rulerY, ruler);
    }
    if (dock > 0) {
      _dock(canvas, frame, left, right, dock);
    }
    if (mark > 0) {
      // The gene, on the strip: its stretch of it ringed in the mark, where
      // MANE puts it, at the least a tick across the strip.
      final double a = _x(frame, _track.spanStart.toDouble());
      final double b = _x(frame, _track.spanEnd + 1);
      final double centre = (a + b) / 2;
      final double half = math.max((b - a).abs() / 2, tick / 2);
      final Rect gene = Rect.fromLTRB(
        clampX(centre - half),
        y - strip / 2 - markReach,
        clampX(centre + half),
        y + strip / 2 + markReach,
      );
      Sculpt.glow(canvas, gene.center, 22, inks, 0.3 * mark);
      Sculpt.glowingStroke(
        canvas,
        Path()..addRRect(
          RRect.fromRectAndRadius(
            gene,
            Radius.circular(math.min(4, gene.width / 2)),
          ),
        ),
        inks,
        width: 1.8,
        alpha: mark,
      );
    }
  }

  /// The names of the bands in view, over the strip, each over the part of
  /// its band in view and only where that part has room for it, so no two
  /// ever meet; the gene's band, named by the card, left to its ring.
  void _names(Canvas canvas, ZoomFrame frame, double y, double alpha) {
    if (alpha <= 0) {
      return;
    }
    final double w = frame.size.width;
    for (final CytoBand band in _track.bands) {
      if (band.start >= _track.bandStart && band.end <= _track.bandEnd) {
        continue;
      }
      final double from = _x(frame, band.start.toDouble());
      final double to = _x(frame, band.end + 1);
      // The part of the band in view, a little in from the edges.
      final double a = math.max(math.min(from, to), 4);
      final double b = math.min(math.max(from, to), w - 4);
      if (b - a < 24) {
        continue;
      }
      TextSpan span(double shown) => TextSpan(
        text: band.name,
        style: frame.labels.copyWith(
          color: frame.inks.label.withValues(
            alpha: alpha * frame.opacity * shown,
          ),
        ),
      );
      final TextPainter name = TextPainter(
        text: span(1),
        textDirection: TextDirection.ltr,
      )..layout();
      // It fades in as the room opens, rather than appearing.
      final double room = smoothstep((b - a - name.width - 8) / 16);
      if (room > 0) {
        if (room < 1) {
          name
            ..text = span(room)
            ..layout();
        }
        name.paint(
          canvas,
          Offset((a + b - name.width) / 2, y - strip / 2 - 6 - name.height),
        );
      }
      name.dispose();
    }
  }

  /// A ruler across the view, ticks at a round step and each numbered
  /// under it.
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
      number.paint(canvas, Offset(x - number.width / 2, y + 7));
      number.dispose();
    }
  }

  /// Where the docked chromosome lies across the top, and where on it the
  /// view's stretch of the genome is.
  (double, double, double, double) _docked(
    ZoomFrame frame,
    double left,
    double right,
  ) {
    const double margin = 16;
    final double width = frame.size.width - 2 * margin;
    final double length = _track.length.toDouble();
    double x(double position) => margin + position / length * width;
    final double a = x(left.clamp(0.0, length));
    final double b = math.max(x(right.clamp(0.0, length)), a + 3);
    return (margin, width, a, b);
  }

  /// The whole chromosome, docked along the top as a lit tube pinched at
  /// its centromere, with the view's stretch of it boxed in the mark.
  void _dock(
    Canvas canvas,
    ZoomFrame frame,
    double left,
    double right,
    double alpha,
  ) {
    final ZoomInks inks = frame.inks;
    final (double margin, double width, double a, double b) = _docked(
      frame,
      left,
      right,
    );
    final double length = _track.length.toDouble();
    double x(double position) => margin + position / length * width;
    final Rect tube = Rect.fromLTWH(margin, dockTop, width, dockHeight);
    canvas.save();
    canvas.clipRRect(
      RRect.fromRectAndRadius(tube, const Radius.circular(dockHeight / 2)),
    );
    final Paint fill = Paint();
    for (final CytoBand band in _track.bands) {
      fill.color = stain(frame.inks, band.stain).withValues(alpha: alpha);
      final double thin = band.stain == Stain.acen ? 0.5 : 1;
      canvas.drawRect(
        Rect.fromLTRB(
          x(band.start - 1.0),
          dockTop + dockHeight / 2 * (1 - thin),
          x(band.end.toDouble()),
          dockTop + dockHeight / 2 * (1 + thin),
        ),
        fill,
      );
    }
    canvas.drawRect(
      tube,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            inks.text.withValues(alpha: 0.2 * alpha),
            inks.text.withValues(alpha: 0),
            inks.shadow.withValues(alpha: 0.45 * alpha),
          ],
          stops: const <double>[0.15, 0.5, 1],
        ).createShader(tube),
    );
    canvas.restore();
    final Path box = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(a, dockTop - 4, b, dockTop + dockHeight + 4),
          const Radius.circular(3),
        ),
      );
    Sculpt.glowingStroke(canvas, box, inks, width: 1.6, alpha: alpha);
    final TextPainter name = TextPainter(
      text: TextSpan(
        text: 'chr${_track.chromosome}',
        style: frame.labels.copyWith(
          color: inks.label.withValues(alpha: alpha),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    name.paint(canvas, Offset(margin, dockTop - 8 - name.height));
    name.dispose();
  }

  /// The funnel: from the docked chromosome's box to the strip's ends, the
  /// stretch of the whole the strip opens out, faint in the mark.
  void _funnel(
    Canvas canvas,
    ZoomFrame frame,
    double left,
    double right,
    double top,
    double alpha,
  ) {
    final double w = frame.size.width;
    final (double _, double _, double a, double b) = _docked(
      frame,
      left,
      right,
    );
    const double from = dockTop + dockHeight + 4;
    final Path cone = Path()
      ..moveTo(a, from)
      ..lineTo(b, from)
      ..lineTo(w, top)
      ..lineTo(0, top)
      ..close();
    canvas.drawPath(
      cone,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            frame.inks.glow(0.14 * alpha),
            frame.inks.glow(0.02 * alpha),
          ],
        ).createShader(Rect.fromLTRB(0, from, w, top)),
    );
    final Paint edge = Paint()
      ..strokeWidth = 1
      ..color = frame.inks.glow(0.45 * alpha);
    canvas.drawLine(Offset(a, from), Offset(0, top), edge);
    canvas.drawLine(Offset(b, from), Offset(w, top), edge);
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
