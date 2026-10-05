import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/locus_track.dart';
import '../../domain/zoom_camera.dart';
import '../../domain/zoom_depth.dart';
import 'body_scene.dart';
import 'contour.dart';
import 'nucleus_scene.dart';
import 'zoom_scene.dart';
import 'zoom_subject.dart';

/// The gene's chromosome as it is when a cell divides: two sister
/// chromatids joined at the centromere, stained in their cytoBand G-bands,
/// with the band the gene lies in bracketed and named. Never the gene,
/// which is far too small to see at this scale.
///
/// On the way in it condenses out of its territory in the nucleus, the
/// paint giving way to Giemsa's grey as the bands come up. On the way out it
/// turns to lie along the genome, its chromatids merge into one and it thins
/// into the band's map, which takes over from it.
final class ChromosomeScene extends ZoomScene {
  ChromosomeScene(this.subject);

  final ZoomSubject subject;

  @override
  ZoomStop get stop => ZoomStop.chromosome;

  LocusTrack get _track => subject.track;

  /// The chromosome's length in the scene's units: the view is one and a
  /// half times it.
  static const double length = 1 / 1.5;

  /// One chromatid's half-width, and how far apart the two sit.
  static const double half = 0.021;
  static const double apart = 0.025;

  /// The map's band strip, in pixels: the chromosome thins to it.
  static const double stripPixels = 18;

  double yOf(num base) => -length / 2 + (base - 1) / _track.length * length;

  double get _bandY => (yOf(_track.bandStart) + yOf(_track.bandEnd + 1)) / 2;

  /// Where the centromere is: the end of the short arm.
  late final double centromere = () {
    for (final CytoBand band in _track.bands) {
      if (!band.onShortArm) {
        return yOf(band.start);
      }
    }
    return 0.0;
  }();

  @override
  Offset get portal => Offset(0, _bandY);

  // A chromosome condensing is drawn from the segment's first frame; one
  // turning into the map gives way to it once it lies along the genome.
  @override
  double asChild(double progress) => 1;

  @override
  double asParent(double progress) => 1 - smoothstep((progress - 0.3) / 0.5);

  /// How pinched the chromatids are at [y]: 1 at the centromere.
  double _waist(double y) {
    final double d = (y - centromere) / 0.018;
    return math.exp(-d * d);
  }

  /// A chromatid's half-width at [y]: narrower at the waist, thin along a
  /// stalk, rounded to nothing at each end.
  double _width(double y) {
    double w = half * (1 - 0.45 * _waist(y));
    for (final CytoBand band in _track.bands) {
      if (band.stain == Stain.stalk && y >= yOf(band.start) &&
          y <= yOf(band.end + 1)) {
        w *= 0.35;
      }
    }
    final double top = yOf(1);
    final double bottom = yOf(_track.length + 1);
    const double cap = half;
    final double fromEnd = math.min(y - top, bottom - y);
    if (fromEnd < cap) {
      final double t = (cap - fromEnd) / cap;
      w *= math.sqrt(math.max(0, 1 - t * t));
    }
    return w;
  }

  /// One chromatid's outline about [centre] (its offset across), [merge]
  /// of the way to lying on the axis, at [thin] of the way to [target]
  /// half-width.
  Contour _chromatid(
    double side, {
    double merge = 0,
    double thin = 0,
    double target = half,
  }) {
    const int steps = 90;
    final double top = yOf(1);
    final double bottom = yOf(_track.length + 1);
    final List<Offset> left = <Offset>[];
    final List<Offset> right = <Offset>[];
    for (int i = 0; i <= steps; i++) {
      final double y = top + (bottom - top) * i / steps;
      final double centre =
          side * apart * (1 - 0.75 * _waist(y)) * (1 - merge);
      final double w = _width(y) + (target - _width(y)) * thin;
      left.add(Offset(centre - w, y));
      right.add(Offset(centre + w, y));
    }
    return Contour(<Offset>[...right, ...left.reversed]);
  }

  /// The territory the chromosome condenses from: the nucleus scene's own
  /// spot for it, in this scene's units.
  Contour _territory() {
    final double ratio = subject.depth.ratioOf(ZoomStop.nucleus.index);
    final double radius = NucleusScene(subject).spot / ratio;
    return Contour.blob(
      Offset.zero,
      radius,
      radius * 1.15,
      count: 128,
      wobble: 0.16,
      seed: _track.chromosome.hashCode,
    );
  }

  @override
  void stage(ZoomFrame frame, ZoomStaging out) {
    final Offset target = frame.toScreen(Offset(apart + half, _bandY));
    // Entering, the band is there only as much as the chromosome has
    // condensed out of its territory.
    final double formed = frame.isChild
        ? smootherstep((frame.progress - 0.08) / 0.62)
        : 1;
    out.item('chromosome:target', target, frame.opacity * formed);
    out.callout(
      'chromosome',
      _track.locus,
      target,
      math.min(calloutPresence(frame), formed),
    );
  }

  @override
  void paint(Canvas canvas, ZoomFrame frame) {
    canvas.save();
    frame.enter(canvas);
    if (frame.isChild) {
      _condensing(canvas, frame);
    } else {
      final double turn = smootherstep(frame.progress / 0.35);
      // Turned about the band, to lie along the genome as a browser draws
      // it, the short arm to the left.
      canvas.translate(0, _bandY);
      canvas.rotate(-math.pi / 2 * turn);
      canvas.translate(0, -_bandY);
      _metaphase(
        canvas,
        frame,
        merge: turn,
        thin: turn,
        target: stripPixels / 2 * frame.pixel,
      );
    }
    canvas.restore();
  }

  /// The territory condensing into the chromosome, the paint fading to
  /// Giemsa's grey as the bands come up.
  void _condensing(Canvas canvas, ZoomFrame frame) {
    final double m = smootherstep((frame.progress - 0.08) / 0.62);
    if (m >= 1) {
      _metaphase(canvas, frame);
      return;
    }
    final Contour outline = _outline().resampled(128);
    final Contour shape = _territory().lerp(outline, m);
    final Path path = shape.toPath();
    final Color paint = frame.inks.scale.paintOf(_track.chromosome);
    final Color grey = frame.inks.scale.giemsaPale;
    canvas.drawPath(
      path,
      Paint()..color = Color.lerp(paint, grey, smoothstep((m - 0.3) / 0.6))!,
    );
    final double bands = smoothstep((m - 0.55) / 0.4);
    if (bands > 0) {
      canvas.save();
      canvas.clipPath(path);
      _bands(canvas, frame, -0.2, 0.2, opacity: bands);
      canvas.restore();
    }
    if (m > 0.85) {
      // The two chromatids resolve out of one shape at the very end.
      canvas.saveLayer(
        null,
        Paint()..color = Color.fromRGBO(0, 0, 0, smoothstep((m - 0.85) / 0.15)),
      );
      _metaphase(canvas, frame);
      canvas.restore();
    }
  }

  /// The two chromatids' outer outline, as one shape.
  Contour _outline() {
    const int steps = 64;
    final double top = yOf(1);
    final double bottom = yOf(_track.length + 1);
    final List<Offset> left = <Offset>[];
    final List<Offset> right = <Offset>[];
    for (int i = 0; i <= steps; i++) {
      final double y = top + (bottom - top) * i / steps;
      final double centre = apart * (1 - 0.75 * _waist(y));
      final double w = _width(y);
      left.add(Offset(-centre - w, y));
      right.add(Offset(centre + w, y));
    }
    return Contour(<Offset>[...right, ...left.reversed]);
  }

  /// The chromosome at metaphase, or on its way to the map: [merge] and
  /// [thin] from 0 to 1.
  void _metaphase(
    Canvas canvas,
    ZoomFrame frame, {
    double merge = 0,
    double thin = 0,
    double target = half,
  }) {
    final double pixel = frame.pixel;
    for (final double side in <double>[-1, 1]) {
      final Path chromatid = _chromatid(
        side,
        merge: merge,
        thin: thin,
        target: target,
      ).toPath();
      canvas.save();
      canvas.clipPath(chromatid);
      final double centre = side * apart * (1 - merge);
      final double w = half + (target - half) * thin;
      _bands(canvas, frame, centre - w * 1.6, centre + w * 1.6);
      // Lit from the upper left: a rounded body, not a flat strip.
      canvas.drawRect(
        Rect.fromLTRB(centre - w * 1.6, yOf(1), centre + w * 1.6, yOf(_track.length + 1)),
        Paint()
          ..shader = LinearGradient(
            colors: <Color>[
              Colors.black.withValues(alpha: 0.38),
              Colors.white.withValues(alpha: 0.10),
              Colors.transparent,
              Colors.black.withValues(alpha: 0.42),
            ],
            stops: const <double>[0, 0.32, 0.55, 1],
          ).createShader(
            Rect.fromLTRB(centre - w, 0, centre + w, 1),
          ),
      );
      canvas.restore();
      canvas.drawPath(
        chromatid,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1 * pixel
          ..color = frame.inks.outline,
      );
    }
    // The band the gene lies in: a bracket beside it, as ISCN marks one.
    final double turned = 1 - merge;
    if (turned > 0.02) {
      final double x =
          apart * turned + half + (target - half) * thin + 5 * pixel;
      final double a = yOf(_track.bandStart);
      final double b = yOf(_track.bandEnd + 1);
      final Paint bracket = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2 * pixel
        ..color = frame.inks.mark.withValues(alpha: turned);
      canvas.drawPath(
        Path()
          ..moveTo(x, a)
          ..lineTo(x + 4 * pixel, a)
          ..lineTo(x + 4 * pixel, b)
          ..lineTo(x, b),
        bracket,
      );
    }
  }

  /// The bands across [left] to [right], in their stains.
  void _bands(
    Canvas canvas,
    ZoomFrame frame,
    double left,
    double right, {
    double opacity = 1,
  }) {
    final Paint fill = Paint();
    final Color pale = frame.inks.scale.giemsaPale;
    final Color dark = frame.inks.scale.giemsaDark;
    for (final CytoBand band in _track.bands) {
      final double top = yOf(band.start);
      final double bottom = yOf(band.end + 1);
      final Color colour = switch (band.stain) {
        Stain.acen => frame.inks.scale.centromere,
        Stain.gvar => Color.lerp(pale, dark, 0.5)!,
        Stain.stalk => Color.lerp(pale, dark, 0.2)!,
        _ => Color.lerp(pale, dark, 0.06 + 0.88 * band.stain.depth)!,
      };
      fill.color = colour.withValues(alpha: opacity);
      final Rect rect = Rect.fromLTRB(left, top, right, bottom);
      canvas.drawRect(rect, fill);
      if (band.stain == Stain.gvar) {
        // Variable heterochromatin, hatched as ideograms draw it.
        canvas.save();
        canvas.clipRect(rect);
        final Paint hatch = Paint()
          ..strokeWidth = 1.2 * frame.pixel
          ..color = dark.withValues(alpha: 0.7 * opacity);
        final double step = 5 * frame.pixel;
        for (double x = left - (bottom - top); x < right; x += step) {
          canvas.drawLine(Offset(x, bottom), Offset(x + (bottom - top), top), hatch);
        }
        canvas.restore();
      }
    }
  }
}
