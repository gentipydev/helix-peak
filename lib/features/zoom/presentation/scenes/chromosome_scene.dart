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
/// An acrocentric's short arm ends in its satellite, a knob on the thin
/// thread of its stalk. The band the gene lies in is in the mark, bracketed
/// and named. Never the gene, which is far too small to see at this scale.
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

  /// How thick a stalk's thread is, against a chromatid.
  static const double thread = 0.2;

  /// The lengths a chromatid is in, top to bottom: the whole of it, or,
  /// where its short arm has a stalk, the satellite beyond the stalk and the
  /// chromatid this side of it. Each is rounded at both ends as a
  /// chromatid's end is, over [half] or half its own length, whichever is
  /// less, and is never much wider than it is long, so a short satellite is
  /// a round knob.
  late final List<_Span> _pieces = () {
    final List<_Span> pieces = <_Span>[];
    void add(double from, double to) {
      if (to > from) {
        pieces.add((
          from: from,
          to: to,
          round: math.min(half, (to - from) / 2),
          wide: math.min(half, (to - from) * 0.65),
        ));
      }
    }

    double from = yOf(1);
    for (final CytoBand band in _track.bands) {
      if (band.stain == Stain.stalk) {
        add(from, yOf(band.start));
        from = yOf(band.end + 1);
      }
    }
    add(from, yOf(_track.length + 1));
    return pieces;
  }();

  /// Each stalk's thread, top to bottom, reaching into the pieces either
  /// side of it as far as they are rounded, so it runs into them with no
  /// step.
  late final List<({double from, double to})> _threads =
      <({double from, double to})>[
        for (final CytoBand band in _track.bands)
          if (band.stain == Stain.stalk) _threadOf(band),
      ];

  ({double from, double to}) _threadOf(CytoBand stalk) {
    double from = yOf(stalk.start);
    double to = yOf(stalk.end + 1);
    for (final _Span piece in _pieces) {
      if (piece.to == from) {
        from -= piece.round;
      }
      if (piece.from == to) {
        to += piece.round;
      }
    }
    return (from: from, to: to);
  }

  /// A chromatid's half-width at [y], as it is drawn.
  @visibleForTesting
  double widthAt(double y) => _width(y);

  /// A chromatid's half-width at [y]: narrower at the waist and rounded to
  /// nothing at each end of each piece, a satellite held on its stalk's
  /// thread.
  double _width(double y) {
    double w = 0;
    for (final _Span piece in _pieces) {
      if (y >= piece.from && y <= piece.to) {
        final double fromEnd = math.min(y - piece.from, piece.to - y);
        final double t = math.max(0, piece.round - fromEnd) / piece.round;
        w =
            piece.wide *
            (1 - 0.42 * _waist(y)) *
            math.sqrt(math.max(0, 1 - t * t));
      }
    }
    for (final ({double from, double to}) stalk in _threads) {
      if (y >= stalk.from && y <= stalk.to) {
        w = _smoothMax(w, half * thread, half * 0.15);
      }
    }
    return w;
  }

  /// The larger of [a] and [b], eased where they come within [k] of each
  /// other, so the thread flows into the pieces it holds with no corner.
  static double _smoothMax(double a, double b, double k) {
    final double h = math.max(0, k - (a - b).abs()) / k;
    return math.max(a, b) + h * h * k / 4;
  }

  /// Where chromatid [side]'s middle lies at [y]: touching its sister along
  /// the groove at the centromere, splayed a little toward its ends, and
  /// [merge] of the way onto the axis.
  double _centreAt(double side, double y, {double merge = 0}) =>
      side *
      (apart * (1 - 0.7 * _waist(y)) + splay * (y - centromere).abs()) *
      (1 - merge);

  /// The heights an outline is drawn through, top to bottom: [steps] even
  /// ones, and more round each end of each piece, where it turns fastest.
  List<double> _rows(int steps) {
    const int round = 16;
    final double top = yOf(1);
    final double bottom = yOf(_track.length + 1);
    return <double>{
      for (int i = 0; i <= steps; i++) top + (bottom - top) * i / steps,
      for (final _Span piece in _pieces)
        for (int i = 1; i < round; i++) ...<double>[
          piece.from + piece.round * (1 - math.cos(math.pi / 2 * i / round)),
          piece.to - piece.round * (1 - math.cos(math.pi / 2 * i / round)),
        ],
    }.toList()..sort();
  }

  late final List<double> _chromatidRows = _rows(120);
  late final List<double> _outlineRows = _rows(64);

  /// One chromatid's outline, [merge] of the way to lying on the axis, at
  /// [thin] of the way to [target] half-width.
  Contour _chromatid(
    double side, {
    double merge = 0,
    double thin = 0,
    double? target,
  }) {
    final List<Offset> left = <Offset>[];
    final List<Offset> right = <Offset>[];
    for (final double y in _chromatidRows) {
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
    final List<Offset> left = <Offset>[];
    final List<Offset> right = <Offset>[];
    for (final double y in _outlineRows) {
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
    final double gene0 = yOf(_track.bandStart);
    final double gene1 = yOf(_track.bandEnd + 1);
    // Where an edge between two bands crosses the chromatid at [y]: it bows
    // as far as the tube is thick there, so the two meet along it however
    // the chromatid narrows between them.
    ({double centre, double w, double bow}) edge(double y) {
      final double w = side == 0
          ? 0
          : _width(y) + ((target ?? half) - _width(y)) * thin;
      return (
        centre: side == 0 ? 0 : _centreAt(side, y, merge: merge),
        w: w,
        bow: w * 0.32 * (1 - merge),
      );
    }

    for (final CytoBand band in _track.bands) {
      final double top = yOf(band.start);
      final double bottom = yOf(band.end + 1);
      final bool own = top >= gene0 - 1e-9 && bottom <= gene1 + 1e-9;
      fill.color = (own ? inks.glow(0.9) : _stain(inks, band)).withValues(
        alpha: opacity * (own ? 0.9 : 1),
      );
      final ({double centre, double w, double bow}) a = edge(top);
      final ({double centre, double w, double bow}) b = edge(bottom);
      final Path path = Path()
        ..moveTo(left, top + a.bow)
        ..lineTo(a.centre - a.w, top + a.bow)
        ..quadraticBezierTo(a.centre, top - a.bow, a.centre + a.w, top + a.bow)
        ..lineTo(right, top + a.bow)
        ..lineTo(right, bottom + b.bow)
        ..lineTo(b.centre + b.w, bottom + b.bow)
        ..quadraticBezierTo(
          b.centre,
          bottom - b.bow,
          b.centre - b.w,
          bottom + b.bow,
        )
        ..lineTo(left, bottom + b.bow)
        ..close();
      canvas.drawPath(path, fill);
    }
  }
}

/// A stretch of a chromatid, top to bottom in the scene's units: how far in
/// from each end it is rounded, and its half-width.
typedef _Span = ({double from, double to, double round, double wide});
