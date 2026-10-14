import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/locus_track.dart';
import '../../domain/zoom_camera.dart';
import '../../domain/zoom_depth.dart';
import '../zoom_inks.dart';
import 'band_scene.dart';
import 'body_scene.dart';
import 'contour.dart';
import 'nucleus_scene.dart';
import 'sculpt.dart';
import 'zoom_scene.dart';
import 'zoom_subject.dart';

/// The gene's chromosome as it is when a cell divides: two sister
/// chromatids, each a coil of chromatin as thick as a chromatid is, lying
/// side by side and joined at the centromere, their arms splayed a little,
/// stained in their cytoBand G-bands, which ring them as bands ring a tube.
/// The band the gene lies in is in the mark, bracketed and named. Never the
/// gene, which is far too small to see at this scale.
///
/// On the way in it condenses out of its territory in the nucleus, the mark
/// drawing in to the gene's band as the bands come up. On the way out it
/// turns to lie along the genome, its chromatids merge into one and it thins
/// into the band's map, which takes over from it.
final class ChromosomeScene extends ZoomScene {
  ChromosomeScene(this.subject);

  final ZoomSubject subject;

  @override
  ZoomStop get stop => ZoomStop.chromosome;

  LocusTrack get _track => subject.track;

  /// The chromosome's length in the scene's units: the view is
  /// [ZoomDepth.chromosomeView] times it.
  static const double length = 1 / ZoomDepth.chromosomeView;

  /// How thick a chromatid is, in metres, condensed for division.
  static const double chromatidMetres = 0.7e-6;

  /// One chromatid's half-width in the scene's units: as thick as a
  /// chromatid is, but never more than a sixth of the chromosome's length,
  /// so a short one stays a chromosome rather than a blob.
  late final double half = math.min(
    chromatidMetres / 2 / subject.depth.widthOf(ZoomStop.chromosome),
    length * 0.075,
  );

  /// How far apart the two chromatids' middles lie at the centromere's
  /// height: touching, along a groove.
  double get apart => half * 1.12;

  /// How far each arm splays from its sister, for each unit of length from
  /// the centromere.
  static const double splay = 0.07;

  /// The map's band strip, in pixels: the chromosome thins to it.
  static const double stripPixels = BandScene.strip;

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
    final double d = (y - centromere) / (half * 0.9);
    return math.exp(-d * d);
  }

  /// A chromatid's half-width at [y]: narrower at the waist, thin along a
  /// stalk, rounded to nothing at each end.
  double _width(double y) {
    double w = half * (1 - 0.42 * _waist(y));
    for (final CytoBand band in _track.bands) {
      if (band.stain == Stain.stalk &&
          y >= yOf(band.start) &&
          y <= yOf(band.end + 1)) {
        w *= 0.35;
      }
    }
    final double top = yOf(1);
    final double bottom = yOf(_track.length + 1);
    final double cap = half;
    final double fromEnd = math.min(y - top, bottom - y);
    if (fromEnd < cap) {
      final double t = (cap - fromEnd) / cap;
      w *= math.sqrt(math.max(0, 1 - t * t));
    }
    return w;
  }

  /// Where chromatid [side]'s middle lies at [y]: touching its sister along
  /// the groove at the centromere, splayed a little toward its ends, and
  /// [merge] of the way onto the axis.
  double _centreAt(double side, double y, {double merge = 0}) =>
      side *
      (apart * (1 - 0.7 * _waist(y)) + splay * (y - centromere).abs()) *
      (1 - merge);

  /// One chromatid's outline, [merge] of the way to lying on the axis, at
  /// [thin] of the way to [target] half-width.
  Contour _chromatid(
    double side, {
    double merge = 0,
    double thin = 0,
    double? target,
  }) {
    const int steps = 120;
    final double top = yOf(1);
    final double bottom = yOf(_track.length + 1);
    final List<Offset> left = <Offset>[];
    final List<Offset> right = <Offset>[];
    for (int i = 0; i <= steps; i++) {
      final double y = top + (bottom - top) * i / steps;
      final double centre = _centreAt(side, y, merge: merge);
      final double w = _width(y) + ((target ?? half) - _width(y)) * thin;
      left.add(Offset(centre - w, y));
      right.add(Offset(centre + w, y));
    }
    return Contour(<Offset>[...right, ...left.reversed]);
  }

  /// The chromatids at rest, built once.
  late final List<Path> _sisters = <Path>[
    for (final double side in <double>[-1, 1]) _chromatid(side).toPath(),
  ];

  /// The coils of chromatin standing out of each chromatid's edge, built
  /// once: a loop every few hundredths of a micrometre.
  late final Path _fuzz = () {
    final Path loops = Path();
    final math.Random random = math.Random(_track.length % 997);
    for (final double side in <double>[-1, 1]) {
      final List<Offset> points = _chromatid(side).resampled(260).points;
      for (int i = 0; i < points.length; i++) {
        final Offset p = points[i];
        final Offset q = points[(i + 1) % points.length];
        final Offset run = q - p;
        if (run.distance == 0) {
          continue;
        }
        final Offset out = Offset(run.dy, -run.dx) / run.distance;
        final double r = half * (0.06 + 0.07 * random.nextDouble());
        loops.addOval(Rect.fromCircle(center: p + out * (r * 0.4), radius: r));
      }
    }
    return loops;
  }();

  /// The territory the chromosome condenses from: the nucleus scene's own
  /// outline for it, in this scene's units, so the hand-over is exact.
  late final Contour _territoryOutline = () {
    final NucleusScene nucleus = NucleusScene(subject);
    final double ratio = subject.depth.ratioOf(ZoomStop.nucleus.index);
    final Offset portal = nucleus.portal;
    final Contour shape = nucleus
        .territoryShape(_track.chromosome, 0)
        .resampled(128);
    return Contour(<Offset>[
      for (final Offset p in shape.points) (p - portal) / ratio,
    ]);
  }();

  @override
  void stage(ZoomFrame frame, ZoomStaging out) {
    final Offset target = frame.toScreen(
      Offset(_centreAt(1, _bandY) + _width(_bandY), _bandY),
    );
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
  void prepare(ZoomInks inks) => <Object?>[_sisters, _fuzz, _territoryOutline];

  @override
  bool wantsClock(ZoomFrame frame) => !frame.isChild && frame.dwell < 1.4;

  // As the chromosome is reached, the gene's band pings once.
  @override
  void paintAmbient(Canvas canvas, ZoomFrame frame) {
    if (frame.isChild) {
      return;
    }
    final double here = frame.opacity * (1 - smoothstep(frame.progress / 0.15));
    canvas.save();
    frame.enter(canvas);
    for (final double side in <double>[-1, 1]) {
      Sculpt.ping(
        canvas,
        Offset(_centreAt(side, _bandY), _bandY),
        _width(_bandY),
        half * 1.6,
        Sculpt.beat(frame.dwell, delay: 0.15, length: 1.1),
        frame.pixel,
        frame.inks,
        opacity: here,
      );
    }
    canvas.restore();
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

  /// The territory condensing into the chromosome: the mark drawing in to
  /// the gene's band as the bands come up.
  void _condensing(Canvas canvas, ZoomFrame frame) {
    final double m = smootherstep((frame.progress - 0.08) / 0.62);
    if (m >= 1) {
      _metaphase(canvas, frame);
      return;
    }
    final ZoomInks inks = frame.inks;
    final Contour outline = _outline().resampled(128);
    final Contour shape = _territoryOutline.lerp(outline, m);
    final Path path = shape.toPath();
    canvas.drawPath(
      path,
      Paint()
        ..color = Color.lerp(
          inks.glow(0.8),
          _pale(inks),
          smoothstep((m - 0.3) / 0.6),
        )!,
    );
    final double bands = smoothstep((m - 0.55) / 0.4);
    if (bands > 0) {
      canvas.save();
      canvas.clipPath(path);
      _bands(canvas, frame, -0.3, 0.3, opacity: bands);
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
      final double centre = _centreAt(1, y);
      final double w = _width(y);
      left.add(Offset(-centre - w, y));
      right.add(Offset(centre + w, y));
    }
    return Contour(<Offset>[...right, ...left.reversed]);
  }

  static Color _pale(ZoomInks inks) => inks.lit(0.56);

  /// The chromosome at metaphase, or on its way to the map: [merge] and
  /// [thin] from 0 to 1.
  void _metaphase(
    Canvas canvas,
    ZoomFrame frame, {
    double merge = 0,
    double thin = 0,
    double? target,
  }) {
    final ZoomInks inks = frame.inks;
    final double pixel = frame.pixel;
    final bool resting = merge == 0 && thin == 0;
    final double top = yOf(1);
    final double bottom = yOf(_track.length + 1);
    final double reach = apart + half + splay * length;
    if (resting) {
      Sculpt.shadowUnder(
        canvas,
        Rect.fromLTRB(-reach, top, reach, bottom),
        inks,
        strength: 0.6,
        spread: 1.06,
      );
    }
    for (final double side in <double>[-1, 1]) {
      final Path chromatid = resting
          ? _sisters[side < 0 ? 0 : 1]
          : _chromatid(side, merge: merge, thin: thin, target: target).toPath();
      final double w = half + ((target ?? half) - half) * thin;
      final double centre = side * (apart + splay * length * 0.5) * (1 - merge);
      canvas.save();
      canvas.clipPath(chromatid);
      _bands(
        canvas,
        frame,
        centre - w * 2.4,
        centre + w * 2.4,
        side: side,
        merge: merge,
        thin: thin,
        target: target,
      );
      // Lit from the upper left: a rounded body, not a flat strip.
      canvas.drawRect(
        Rect.fromLTRB(centre - w * 2.4, top, centre + w * 2.4, bottom),
        Paint()
          ..shader =
              LinearGradient(
                colors: <Color>[
                  inks.shadow.withValues(alpha: 0.55),
                  inks.text.withValues(alpha: 0.16),
                  inks.text.withValues(alpha: 0),
                  inks.shadow.withValues(alpha: 0.6),
                ],
                stops: const <double>[0, 0.3, 0.55, 1],
              ).createShader(
                Rect.fromLTRB(centre - w * 1.25, 0, centre + w * 1.25, 1),
              ),
      );
      canvas.restore();
      canvas.drawPath(
        chromatid,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1 * pixel
          ..color = inks.shade(0.6),
      );
    }
    if (resting) {
      // The coils standing out of its edge, and the light on them.
      canvas.drawPath(
        _fuzz,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8 * pixel
          ..color = inks.lit(0.5).withValues(alpha: 0.28),
      );
      for (final Path chromatid in _sisters) {
        Sculpt.rim(
          canvas,
          chromatid,
          chromatid.getBounds(),
          inks,
          width: 1.6 * pixel,
          strength: 0.45,
        );
      }
      // The kinetochores, one on each chromatid's outer face at the
      // centromere.
      for (final double side in <double>[-1, 1]) {
        final double x =
            _centreAt(side, centromere) + side * _width(centromere) * 0.9;
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(x, centromere),
            width: half * 0.5,
            height: half * 0.9,
          ),
          Paint()..color = inks.shade(0.45),
        );
      }
    }
    // The band the gene lies in: a bracket beside it, as ISCN marks one.
    final double turned = 1 - merge;
    if (turned > 0.02) {
      final double x =
          _centreAt(1, _bandY, merge: merge) +
          _width(_bandY) +
          ((target ?? half) - _width(_bandY)) * thin +
          6 * pixel;
      final double a = yOf(_track.bandStart);
      final double b = yOf(_track.bandEnd + 1);
      canvas.drawPath(
        Path()
          ..moveTo(x, a)
          ..lineTo(x + 4 * pixel, a)
          ..lineTo(x + 4 * pixel, b)
          ..lineTo(x, b),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2 * pixel
          ..color = inks.glow(turned),
      );
    }
  }

  Color _stain(ZoomInks inks, CytoBand band) {
    final Color pale = _pale(inks);
    final Color dark = inks.shade(0.55);
    return switch (band.stain) {
      Stain.acen => inks.shade(0.42),
      Stain.gvar => Color.lerp(pale, dark, 0.5)!,
      Stain.stalk => Color.lerp(pale, dark, 0.2)!,
      _ => Color.lerp(pale, dark, 0.06 + 0.88 * band.stain.depth)!,
    };
  }

  /// The bands across [left] to [right], in their stains, each ringing the
  /// chromatid as a band rings a tube seen a little from above; the gene's
  /// in the mark.
  void _bands(
    Canvas canvas,
    ZoomFrame frame,
    double left,
    double right, {
    double opacity = 1,
    double side = 0,
    double merge = 0,
    double thin = 0,
    double? target,
  }) {
    final ZoomInks inks = frame.inks;
    final Paint fill = Paint();
    final Color dark = inks.shade(0.55);
    final double gene0 = yOf(_track.bandStart);
    final double gene1 = yOf(_track.bandEnd + 1);
    for (final CytoBand band in _track.bands) {
      final double top = yOf(band.start);
      final double bottom = yOf(band.end + 1);
      final bool own = top >= gene0 - 1e-9 && bottom <= gene1 + 1e-9;
      fill.color = (own ? inks.glow(0.9) : _stain(inks, band)).withValues(
        alpha: opacity * (own ? 0.9 : 1),
      );
      // How far the band's edges bow, at its middle's width.
      final double mid = (top + bottom) / 2;
      final double w = side == 0
          ? 0
          : _width(mid) + ((target ?? half) - _width(mid)) * thin;
      final double bow = w * 0.32 * (1 - merge);
      final double centre = side == 0 ? 0 : _centreAt(side, mid, merge: merge);
      final Path path = Path()
        ..moveTo(left, top + bow)
        ..lineTo(centre - w, top + bow)
        ..quadraticBezierTo(centre, top - bow, centre + w, top + bow)
        ..lineTo(right, top + bow)
        ..lineTo(right, bottom + bow)
        ..lineTo(centre + w, bottom + bow)
        ..quadraticBezierTo(centre, bottom - bow, centre - w, bottom + bow)
        ..lineTo(left, bottom + bow)
        ..close();
      canvas.drawPath(path, fill);
      if (band.stain == Stain.gvar) {
        // Variable heterochromatin, hatched as ideograms draw it.
        canvas.save();
        canvas.clipPath(path);
        final Paint hatch = Paint()
          ..strokeWidth = 1.2 * frame.pixel
          ..color = dark.withValues(alpha: 0.7 * opacity);
        final double step = 5 * frame.pixel;
        for (double x = left - (bottom - top); x < right; x += step) {
          canvas.drawLine(
            Offset(x, bottom + bow),
            Offset(x + (bottom - top), top + bow),
            hatch,
          );
        }
        canvas.restore();
      }
    }
  }
}
