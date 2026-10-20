import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/locus_track.dart';
import '../../domain/zoom_camera.dart';
import '../../domain/zoom_depth.dart';
import '../zoom_inks.dart';
import 'band_scene.dart';
import 'body_scene.dart';
import 'chromosome/chromosome_art.dart';
import 'chromosome/chromosome_form.dart';
import 'chromosome/chromosome_style.dart';
import 'chromosome/chromosome_tube.dart';
import 'contour.dart';
import 'nucleus_scene.dart';
import 'sculpt.dart';
import 'zoom_scene.dart';
import 'zoom_subject.dart';

/// The gene's chromosome as it is when a cell divides, drawn as a scanning
/// micrograph shows one ([ChromosomeArt]): two sister chromatids, each a
/// coil of chromatin as thick as a chromatid is, touching along a groove and
/// pinched together at the centromere, their surface knobbly, their
/// cytoBand G-bands soft changes of tone. The gene is marked as FISH marks a
/// gene: a spot on each sister at its height, over its band, which is
/// bracketed and named. The spots are a probe's, never the gene, which is
/// far too small to see at this scale. Its parts are named in the quiet ink
/// in a column at the canvas's edge either side of it, level with each
/// ([parts]), the band's name at the head of the column on the right.
///
/// On the way in it condenses out of its territory in the nucleus. On the
/// way out it turns to lie along the genome, its chromatids merge into one
/// and it thins into the band's strip ([ChromosomeTube]), drawn by then as
/// the strip itself is, so the map takes over from it with nothing to see.
final class ChromosomeScene extends ZoomScene {
  ChromosomeScene(this.subject);

  final ZoomSubject subject;

  @override
  ZoomStop get stop => ZoomStop.chromosome;

  LocusTrack get _track => subject.track;

  /// The chromosome's length in the scene's units: the view is
  /// [ZoomDepth.chromosomeView] times it.
  static const double length = ChromosomeForm.length;

  /// How thick a chromatid is, in metres, condensed for division.
  static const double chromatidMetres = 0.7e-6;

  /// One chromatid's half-width in the scene's units: as thick as a
  /// chromatid is, but never more than a sixth of the chromosome's length,
  /// so a short one stays a chromosome rather than a blob.
  late final double half = math.min(
    chromatidMetres / 2 / subject.depth.widthOf(ZoomStop.chromosome),
    length * 0.075,
  );

  /// The chromosome as a form: the same for every protein on it.
  late final ChromosomeForm form = ChromosomeForm(_track, half: half);

  /// The map's band strip, in pixels: the chromosome thins to it.
  static const double stripPixels = BandScene.strip;

  double yOf(num base) => form.yOf(base);

  double get _bandY => form.bandY;

  /// Where the centromere is: the end of the short arm.
  double get centromere => form.centromere;

  @override
  Offset get portal => Offset(0, _bandY);

  // A chromosome condensing is drawn from the segment's first frame. One
  // turning into the map lies under it, drawn as the strip is, until the
  // map is all there: the two crossfaded would let the ground show through
  // both half way.
  @override
  double asChild(double progress) => 1;

  @override
  double asParent(double progress) => 1 - smoothstep((progress - 0.7) / 0.3);

  /// A chromatid's half-width at [y], as it is drawn.
  @visibleForTesting
  double widthAt(double y) => form.widthAt(y);

  ChromosomeArt? _art;

  /// The chromosome at rest in [inks], built once for them.
  ChromosomeArt _artIn(ZoomInks inks) {
    final ChromosomeArt? art = _art;
    if (art != null && art.inks == inks) {
      return art;
    }
    return _art = ChromosomeArt(form, inks)..prepare();
  }

  ChromosomeTube? _tube;

  /// The chromosome on its way into the map in [inks], for tests.
  @visibleForTesting
  ChromosomeTube tubeIn(ZoomInks inks) => _tubeIn(inks);

  /// The chromosome on its way into the map in [inks], built once for them.
  ChromosomeTube _tubeIn(ZoomInks inks) {
    final ChromosomeTube? tube = _tube;
    if (tube != null && tube.inks == inks) {
      return tube;
    }
    return _tube = ChromosomeTube(form, inks)..prepare();
  }

  /// The two chromatids' outer outline, as the territory's outline is drawn
  /// in to it.
  late final Contour _outline = form.outline().resampled(128);

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
    final double s = frame.progress;
    final Offset band = frame.toScreen(Offset(0, _bandY));
    if (frame.isChild) {
      // Entering, the band is there only as much as the chromosome has
      // condensed out of its territory.
      final double formed = smootherstep((s - 0.08) / 0.62);
      final Offset target = frame.toScreen(_bandEdge(frame, 0));
      out.item('chromosome:target', target, frame.opacity * formed);
      out.callout(
        'chromosome',
        _track.locus,
        target,
        math.min(calloutPresence(frame), formed),
        anchors: _bandAnchors(target),
        flush: true,
      );
      _nameParts(frame, out, math.min(calloutPresence(frame), formed));
      // Before the step is under way the nucleus draws the territory.
      if (s <= 0) {
        return;
      }
      final _Condensing c = _Condensing(s);
      final Offset origin = frame.toScreen(Offset.zero);
      out.item('territory:followed', origin, 1 - c.tint);
      out.item('territory:halo', origin, c.edge);
      out.item('chromosome:art', band, c.art);
      out.item('chromosome:bracket', band, c.spots);
      out.item('chromosome:spots', frame.toScreen(_spotsAt(0)), c.spots);
      return;
    }
    final _Turning t = _Turning(s);
    // The band's name keeps to where the band lies at rest as it fades over
    // the first third of the way: followed through the turn and the merge,
    // its line jolted by more than a pixel and a half a frame near the
    // middle of the view.
    final Offset target = frame.toScreen(_bandEdge(frame, 0));
    out.item('chromosome:target', target, frame.opacity);
    out.callout(
      'chromosome',
      _track.locus,
      target,
      calloutPresence(frame),
      anchors: _bandAnchors(target),
      flush: true,
    );
    _nameParts(frame, out, calloutPresence(frame));
    out.item('chromosome:art', band, math.min(frame.opacity, t.art));
    out.item('chromosome:bracket', band, math.min(frame.opacity, t.art));
    out.item('chromosome:ring', band, math.min(frame.opacity, t.ring));
    out.item(
      'chromosome:spots',
      _onScreen(frame, _spotsAt(t.merge), t.turn),
      math.min(frame.opacity, 1 - t.mark),
    );
  }

  /// The parts of the chromosome a reader looks for, named in the quiet ink
  /// (the user's ask of 2026-10-19): each by its name, the point it names at
  /// rest, and the side its name is set on: the arms and the centromere on
  /// the left, a chromatid and a telomere on the right, where the band's
  /// name is too. The telomere named is at the end further from the band,
  /// and the chromatid at whichever of three heights on the long arm is
  /// furthest from both, so no two of the names on the right crowd.
  late final List<(String, Offset, double)> parts = () {
    final double c = centromere;
    Offset on(double side, double y) =>
        Offset(form.centreAt(side, y) + side * form.widthAt(y) * 0.5, y);
    final double end = _bandY - form.top > form.bottom - _bandY
        ? form.top + half * 0.3
        : form.bottom - half * 0.3;
    double room(double y) =>
        math.min((y - _bandY).abs(), (y - end).abs());
    final double sister = <double>[
      for (final double f in <double>[0.25, 0.45, 0.65])
        c + (form.bottom - c) * f,
    ].reduce((double a, double b) => room(b) > room(a) ? b : a);
    return <(String, Offset, double)>[
      ('p arm', on(-1, (form.top + c) / 2), -1),
      (
        'centromere',
        Offset((form.centreAt(-1, c) + form.centreAt(1, c)) / 2, c),
        -1,
      ),
      ('q arm', on(-1, (c + form.bottom) / 2), -1),
      ('chromatid', on(1, sister), 1),
      ('telomere', Offset(form.centreAt(1, end), end), 1),
    ];
  }();

  /// Where the band's name, which points at [target], may be set: above
  /// the band and then below it, at the heights the painter would set it,
  /// then higher, for a band at the foot of a squat canvas; each out at the
  /// canvas's right edge (the user's ask of 2026-10-19), at the head of the
  /// column the names on that side are set in.
  static List<Offset> _bandAnchors(Offset target) => <Offset>[
    target + const Offset(24, -20),
    target + const Offset(24, 20),
    target + const Offset(24, -50),
  ];

  /// Names the chromosome's [parts], [presence] of the way there, each in a
  /// column at the canvas's edge on its side (the user's ask of
  /// 2026-10-19), but no nearer the chromosome than 14 px off its outer
  /// edge: level with what it names, or a little below or above it where
  /// another name is there, and only then on the other side.
  void _nameParts(ZoomFrame frame, ZoomStaging out, double presence) {
    for (final (String name, Offset at, double side) in parts) {
      Offset edge(double s) => frame.toScreen(
        Offset(form.centreAt(s, at.dy) + s * form.widthAt(at.dy), at.dy),
      );
      out.callout(
        'chromosome:$name',
        name,
        frame.toScreen(at),
        presence,
        anchors: columnAnchors(side, edge(-1), edge(1)),
        flush: true,
        quiet: true,
      );
    }
  }

  /// The gene's band's outer edge, which its name points at: [merge] of the
  /// way onto the axis, and thinned as far to the strip's thickness.
  Offset _bandEdge(ZoomFrame frame, double merge) {
    final double w = form.widthAt(_bandY);
    final double target = stripPixels / 2 * frame.pixel;
    return Offset(
      form.centreAt(1, _bandY, merge: merge) + w + (target - w) * merge,
      _bandY,
    );
  }

  /// The middle of the gene's two spots, [merge] of the way onto the axis.
  Offset _spotsAt(double merge) => Offset(
    (form.fish(-1, merge: merge).dx + form.fish(1, merge: merge).dx) / 2,
    form.geneY,
  );

  /// Where the scene's point [p] is on screen while the chromosome is
  /// turned [turn] of the way to lying along the genome, about its band.
  Offset _onScreen(ZoomFrame frame, Offset p, double turn) {
    if (turn <= 0) {
      return frame.toScreen(p);
    }
    final double a = -math.pi / 2 * turn;
    final Offset d = p - Offset(0, _bandY);
    return frame.toScreen(
      Offset(
        d.dx * math.cos(a) - d.dy * math.sin(a),
        _bandY + d.dx * math.sin(a) + d.dy * math.cos(a),
      ),
    );
  }

  /// Turns [canvas] [turn] of the way to lying along the genome as a
  /// browser draws it, the short arm to the left, about the band.
  void _turn(Canvas canvas, double turn) {
    if (turn <= 0) {
      return;
    }
    canvas.translate(0, _bandY);
    canvas.rotate(-math.pi / 2 * turn);
    canvas.translate(0, -_bandY);
  }

  @override
  void prepare(ZoomInks inks) => <Object?>[
    _outline,
    _territoryOutline,
    _artIn(inks),
    _tubeIn(inks),
  ];

  @override
  bool wantsClock(ZoomFrame frame) => !frame.isChild && frame.dwell < 1.4;

  // As the chromosome is reached, the gene's two spots flare once.
  @override
  void paintAmbient(Canvas canvas, ZoomFrame frame) {
    if (frame.isChild) {
      return;
    }
    final double here = frame.opacity * (1 - smoothstep(frame.progress / 0.15));
    canvas.save();
    frame.enter(canvas);
    _turn(canvas, _Turning(frame.progress).turn);
    _artIn(frame.inks).paintFlare(
      canvas,
      frame,
      Sculpt.beat(frame.dwell, delay: 0.15, length: 1.1),
      here,
    );
    canvas.restore();
  }

  @override
  void paint(Canvas canvas, ZoomFrame frame) {
    canvas.save();
    frame.enter(canvas);
    if (frame.isChild) {
      _condensing(canvas, frame);
    } else if (frame.progress <= 0) {
      _resting(canvas, frame);
    } else {
      _turning(canvas, frame);
    }
    canvas.restore();
  }

  /// The chromosome at rest: the micrograph, the gene's spots, and its
  /// band's bracket.
  void _resting(Canvas canvas, ZoomFrame frame) {
    final ChromosomeArt art = _artIn(frame.inks);
    art.paintRest(canvas, frame);
    art.paintSpots(canvas);
    _bracket(canvas, frame);
  }

  /// The territory condensing into the chromosome. Its outline draws in to
  /// the chromosome's while its mark gives way to the chromatin's own tone,
  /// as the nucleus's edge and glow fade; the micrograph comes up over it,
  /// the fill under it going last; and the gene's spots come up on the
  /// sisters. Nothing is drawn before the step is under way, where the
  /// nucleus draws the territory, and once every part is at rest the stop
  /// itself is drawn, so the step's last frames are the stop's.
  void _condensing(Canvas canvas, ZoomFrame frame) {
    final double s = frame.progress;
    if (s <= 0) {
      return;
    }
    if (s >= _Condensing.done) {
      _resting(canvas, frame);
      return;
    }
    final ZoomInks inks = frame.inks;
    final ChromosomeArt art = _artIn(inks);
    final _Condensing c = _Condensing(s);
    final Path path = _territoryOutline.lerp(_outline, c.shape).toPath();
    final Color fill = Color.lerp(inks.glow(0.8), art.meanTone, c.tint)!;
    NucleusScene.paintFollowedTerritory(
      canvas,
      path,
      path.getBounds(),
      inks,
      frame.pixel,
      fill: fill.withValues(alpha: fill.a * c.fill),
      halo: c.edge,
      edge: c.edge,
    );
    if (c.art > 0) {
      canvas.saveLayer(
        art.bounds,
        Paint()..color = Color.fromRGBO(0, 0, 0, c.art),
      );
      art.paintRest(canvas, frame);
      canvas.restore();
    }
    art.paintSpots(canvas, opacity: c.spots);
    _bracket(canvas, frame, alpha: c.spots);
  }

  /// The chromosome turning into the band's map. Under the micrograph, which
  /// fades as the turn begins, the tube turns, merges and thins into the
  /// strip; the gene's band is ringed as the strip rings it; the gene's
  /// spots merge on the axis into the glow the map marks the gene with,
  /// until the map's own mark takes over; and the band's bracket goes with
  /// the micrograph.
  void _turning(Canvas canvas, ZoomFrame frame) {
    final ZoomInks inks = frame.inks;
    final ChromosomeArt art = _artIn(inks);
    final _Turning t = _Turning(frame.progress);
    final double target = stripPixels / 2 * frame.pixel;
    // How much of the map shows over the tube: what the tube draws that the
    // map draws too, and lets the ground through, it draws only as faint as
    // the two together should be.
    final double under = BandScene.arriving(frame.progress);
    _turn(canvas, t.turn);
    _tubeIn(inks).paint(
      canvas,
      frame,
      turn: t.turn,
      merge: t.merge,
      thin: t.merge,
      strip: t.strip,
      target: target,
      under: under,
    );
    if (t.art > 0) {
      canvas.saveLayer(
        art.bounds,
        Paint()..color = Color.fromRGBO(0, 0, 0, t.art),
      );
      art.paintRest(
        canvas,
        frame,
        merge: t.merge,
        thin: t.merge,
        target: target,
      );
      canvas.restore();
    }
    _ring(canvas, frame, t.ring, t.merge, target, under);
    _spotsOnTheWay(canvas, frame, art, t);
    _bracket(
      canvas,
      frame,
      alpha: t.art,
      merge: t.merge,
      thin: t.merge,
      target: target,
    );
  }

  /// The ring round the gene's band, [alpha] of the way up, as the strip
  /// rings it: as far out from the two sisters, [merge] of the way onto the
  /// axis and thinned as far to [target] half-width, as it stands out from
  /// the strip, and as faint under the map's own at [under] as the two
  /// together should be.
  void _ring(
    Canvas canvas,
    ZoomFrame frame,
    double alpha,
    double merge,
    double target,
    double under,
  ) {
    if (alpha <= 0) {
      return;
    }
    final double pixel = frame.pixel;
    final double y = _bandY;
    final double w = form.widthAt(y) + (target - form.widthAt(y)) * merge;
    final double reach = BandScene.ringReach * pixel;
    final Rect box = Rect.fromLTRB(
      form.centreAt(-1, y, merge: merge) - w - reach,
      yOf(_track.bandStart),
      form.centreAt(1, y, merge: merge) + w + reach,
      yOf(_track.bandEnd + 1),
    );
    Sculpt.glowingStroke(
      canvas,
      Path()..addRRect(
        RRect.fromRectAndRadius(
          box,
          Radius.circular(BandScene.ringRadius * pixel),
        ),
      ),
      frame.inks,
      width: BandScene.ringWidth * pixel,
      alpha: alpha,
      under: under,
    );
  }

  /// The gene's spots on the way into the map: merging onto the axis as the
  /// sisters do, the left one going into the right, and easing into the
  /// glow the map marks the gene with, which takes over from them as it
  /// comes up.
  void _spotsOnTheWay(
    Canvas canvas,
    ZoomFrame frame,
    ChromosomeArt art,
    _Turning t,
  ) {
    final double shown = 1 - t.mark;
    if (shown <= 0.002) {
      return;
    }
    final double pixel = frame.pixel;
    final double r = form.fishRadius;
    final double reach = ChromosomeStyle.fishGlow * r;
    final double core = r + (ChromosomeStyle.fishOnStrip * pixel - r) * t.strip;
    final double glow = reach + (BandScene.geneGlow * pixel - reach) * t.strip;
    final double heart = 0.38 + (BandScene.geneGlowAlpha - 0.38) * t.strip;
    for (final double side in <double>[-1, 1]) {
      final double alpha = shown * (side < 0 ? 1 - t.merge : 1);
      if (alpha > 0.002) {
        art.paintSpot(
          canvas,
          form.fish(side, merge: t.merge),
          core,
          glow,
          heart * alpha,
          alpha,
        );
      }
    }
  }

  /// The band the gene lies in: a bracket beside it, as ISCN marks one,
  /// [alpha] of the way up; on the way into the map, beside the band
  /// [merge] of the way onto the axis and thinned [thin] of the way to
  /// [target] half-width.
  void _bracket(
    Canvas canvas,
    ZoomFrame frame, {
    double alpha = 1,
    double merge = 0,
    double thin = 0,
    double? target,
  }) {
    if (alpha <= 0.02) {
      return;
    }
    final double pixel = frame.pixel;
    final double w = form.widthAt(_bandY);
    final double x =
        form.centreAt(1, _bandY, merge: merge) +
        w +
        ((target ?? half) - w) * thin +
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
        ..color = frame.inks.glow(alpha),
    );
  }
}

/// How far the chromosome has condensed out of its territory, [s] of the
/// way through the step from the nucleus: each part on its own schedule,
/// every one of them at rest by [done]. None of the fades changes by more
/// than 0.08 a frame at 60 fps on the shortest flight.
final class _Condensing {
  _Condensing(double s)
    : shape = smootherstep((s - 0.08) / 0.62),
      edge = 1 - smoothstep(s / 0.45),
      tint = smoothstep((s - 0.15) / 0.5),
      art = smoothstep((s - 0.35) / 0.45),
      fill = 1 - smoothstep((s - 0.62) / 0.36),
      spots = smoothstep((s - 0.5) / 0.45);

  /// Where every part is at rest, and the stop itself is drawn.
  static const double done = 0.98;

  /// How far the territory's outline has drawn in to the chromosome's.
  final double shape;

  /// How much of the nucleus's edge and glow round the territory is left.
  final double edge;

  /// How far the territory's mark has given way to the chromatin's tone.
  final double tint;

  /// How far the micrograph has come up.
  final double art;

  /// How much of the fill under the micrograph is left.
  final double fill;

  /// How far the gene's spots and its band's bracket have come up.
  final double spots;
}

/// How far the chromosome has turned into the band's map, [s] of the way
/// through the step to the band: each part on its own schedule. None of
/// the fades changes by more than 0.08 a frame at 60 fps on the shortest
/// flight.
final class _Turning {
  _Turning(double s)
    : turn = smootherstep(s / 0.35),
      merge = smootherstep((s - 0.08) / 0.27),
      strip = smoothstep((s - 0.12) / 0.23),
      art = 1 - smoothstep(s / 0.3),
      ring = smoothstep((s - 0.05) / 0.45),
      mark = BandScene.markArriving(s);

  /// How far it has turned to lie along the genome.
  final double turn;

  /// How far its sisters have merged onto its axis, and thinned to the
  /// strip's thickness.
  final double merge;

  /// How far it looks as the strip does: its edges, its ends, its colours
  /// and its light.
  final double strip;

  /// How much of the micrograph, and of its band's bracket, is left.
  final double art;

  /// How far the ring round the gene's band has come up.
  final double ring;

  /// How far the map's own mark of the gene has come up, taking over from
  /// the spots.
  final double mark;
}
