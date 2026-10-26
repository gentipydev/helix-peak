import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/anatomy_figure.dart';
import '../../domain/anatomy_tables.dart';
import '../../domain/zoom_camera.dart';
import '../../domain/zoom_depth.dart';
import '../zoom_inks.dart';
import 'body_scene.dart';
import 'contour.dart';
import 'nucleolus.dart';
import 'nucleus_shape.dart';
import 'sculpt.dart';
import 'zoom_scene.dart';
import 'zoom_subject.dart';

/// The 23 pairs of chromosomes a nucleus holds: 1 to 22, and the sex
/// chromosomes, of which a male body's second is a Y
/// ([NucleusScene.kindOf]).
const List<String> chromosomeNames = <String>[
  '1', '2', '3', '4', '5', '6', '7', '8', '9', '10', '11', '12', '13', '14', //
  '15', '16', '17', '18', '19', '20', '21', '22', 'X',
];

/// The nucleus and its chromosome territories: each of its 46 chromosomes
/// in a territory of its own, as chromosome painting shows them, a
/// territory as big as its chromosome's DNA, the gene-dense ones toward the
/// centre and the gene-poor at the rim, the five that carry ribosomal genes
/// gathered round the nucleolus. They are drawn in one neutral, a step
/// apart, the gene's own chromosome in the mark and its other copy, where
/// the body has one, faintly in it. The card names the territory; the
/// nucleolus, dark among them, is named here in the quiet ink, its name set
/// outside the nucleus as a cell's are round the cell (the user's ask of
/// 2026-10-19; the cell names it nowhere).
///
/// On the way in, the nucleus the cell drew resolves into its territories;
/// on the way out, the followed territory is handed to the chromosome's
/// scene to condense, and the rest give way.
final class NucleusScene extends ZoomScene {
  NucleusScene(this.subject)
    : shape = NucleusShape(subject.depth.archetype.shape);

  final ZoomSubject subject;
  final NucleusShape shape;

  @override
  ZoomStop get stop => ZoomStop.nucleus;

  /// The nucleus's radius, in the scene's units.
  double get radius =>
      subject.depth.archetype.nucleus / 2 / subject.depth.widthOf(stop);

  /// The nucleolus, as the cell drew it.
  late final Nucleolus nucleolus = Nucleolus(shape, radius);

  @override
  double asParent(double progress) => 1 - smoothstep((progress - 0.3) / 0.5);

  /// A territory's radius in the scene's units: its area as its DNA.
  double spotOf(String name) =>
      radius * 0.25 * math.sqrt((chromosomeMegabases[name] ?? 100) / 150);

  /// Which chromosome homologue [copy] of [name] is in this body: the
  /// second sex chromosome of the male figure's cells is a Y.
  String kindOf(String name, int copy) =>
      name == 'X' && copy == 1 && identical(subject.body, AnatomyFigure.male)
      ? 'Y'
      : name;

  /// Where homologue [copy] of chromosome [name] lies, in the scene's units:
  /// at the depth nuclei keep it, the two copies apart; an acrocentric
  /// beside the nucleolus.
  Offset territory(String name, int copy) {
    final int index = math.max(chromosomeNames.indexOf(name), 0);
    if (acrocentric.contains(name)) {
      final double a = index * 1.3 + copy * 2.6;
      final Offset unit = Nucleolus.at + Offset(math.cos(a), math.sin(a)) * 0.3;
      return shape.place(unit, radius);
    }
    final double depth = (territoryRadius[kindOf(name, copy)] ?? 0.6) * 0.92;
    double a = index * 2.39996 + copy * (math.pi * 0.9);
    if (copy == 0 && name == subject.track.chromosome) {
      a = _clearOfNucleolus(name, a, depth);
    }
    return shape.place(Offset(math.cos(a), math.sin(a)) * depth, radius);
  }

  /// The angle the followed territory lies at: its own, or, where the
  /// nucleolus would lie under its glow, a quarter turn from it, the way
  /// that takes it further off. A flat nucleus can bring the two together.
  double _clearOfNucleolus(String name, double a, double depth) {
    Offset at(double angle) =>
        shape.place(Offset(math.cos(angle), math.sin(angle)) * depth, radius);
    double off(double angle) => (at(angle) - nucleolus.centre).distance;
    final (double rx, double ry) = nucleolus.radii;
    if (off(a) >= 0.5 * (spotOf(kindOf(name, 0)) + math.max(rx, ry))) {
      return a;
    }
    final double left = a + math.pi / 2;
    final double right = a - math.pi / 2;
    return off(left) >= off(right) ? left : right;
  }

  /// A territory's outline, in the scene's units.
  Contour territoryShape(String name, int copy) {
    final double r = spotOf(kindOf(name, copy));
    return Contour.blob(
      territory(name, copy),
      r,
      r * 1.1,
      count: 128,
      wobble: 0.22,
      seed: chromosomeNames.indexOf(name) * 2 + copy + 11,
    );
  }

  /// The territory that is spot [spot] of the scene's own: the followed one.
  double get spot => spotOf(subject.track.chromosome);

  /// Whether the gene's chromosome has a second copy in this body: every
  /// autosome does, and the X in the female figure's cells.
  bool get paired =>
      kindOf(subject.track.chromosome, 1) == subject.track.chromosome;

  /// How far territory [copy] of [name] has drifted out from the followed
  /// one, [away] of the way to gone.
  Offset _drift(String name, int copy, double away) =>
      (territory(name, copy) - portal) * (0.35 * away);

  @override
  Offset get portal => territory(subject.track.chromosome, 0);

  // The territory is not named here: the card names it. The nucleolus is,
  // round the nucleus, so its name hides no territory.
  @override
  void stage(ZoomFrame frame, ZoomStaging out) {
    final Offset at = frame.toScreen(portal);
    out.item('nucleus:target', at, frame.opacity);
    out.callout(
      'nucleus:nucleolus',
      'nucleolus',
      frame.toScreen(nucleolus.centre),
      calloutPresence(frame),
      quiet: true,
      ring: ZoomRing('nucleus', <Offset>[
        for (final Offset p in _rim) frame.toScreen(p),
      ]),
    );
    // The gene's territory, for as long as this scene draws it: the
    // chromosome's scene draws it once the step to it is under way.
    if (frame.isChild || frame.progress <= 0) {
      final double shown = math.min(frame.opacity, _painted(frame));
      out.item('territory:followed', at, shown);
      out.item('territory:halo', at, shown);
    }
    // Its other copy resolves, drifts and fades with the rest.
    if (paired) {
      final String name = subject.track.chromosome;
      final double away = _away(frame);
      out.item(
        'territory:homologue',
        frame.toScreen(territory(name, 1) + _drift(name, 1, away)),
        math.min(frame.opacity, _painted(frame) * (1 - away)),
      );
    }
  }

  /// How far the territories have resolved out of the nucleus's even tone:
  /// all of them once it is reached.
  static double _painted(ZoomFrame frame) =>
      frame.isChild ? smoothstep((frame.progress - 0.35) / 0.45) : 1;

  /// How far the territories have given way as the gene's condenses into
  /// its chromosome: none of them until the step to it is under way.
  static double _away(ZoomFrame frame) =>
      frame.isChild ? 0 : smoothstep(frame.progress / 0.6);

  /// The gene's territory as the nucleus draws it, along [path] in a box
  /// [box], [pixel] the scene's pixel: filled in [fill], its glow [halo] of
  /// the way up and its edge in the mark [edge] of the way. The
  /// chromosome's scene draws it the same way as it condenses out of it, so
  /// the hand-over between the two is exact.
  static void paintFollowedTerritory(
    Canvas canvas,
    Path path,
    Rect box,
    ZoomInks inks,
    double pixel, {
    required Color fill,
    double halo = 1,
    double edge = 1,
  }) {
    Sculpt.glow(canvas, box.center, box.longestSide, inks, 0.3 * halo);
    canvas.drawPath(path, Paint()..color = fill);
    if (edge > 0) {
      Sculpt.glowingStroke(canvas, path, inks, width: 1.6 * pixel, alpha: edge);
    }
  }

  /// Every territory's outline as a path, built once: the 46 of them are
  /// drawn every frame the nucleus shows.
  late final Map<(String, int), Path> _territories = <(String, int), Path>{
    for (final String name in chromosomeNames)
      for (int copy = 0; copy < 2; copy++)
        (name, copy): territoryShape(name, copy).toPath(),
  };

  late final Path _outline = shape.outline(radius).toPath();

  late final List<Offset> _pores = shape.outline(radius).resampled(56).points;

  /// The nucleus's outline, as points: what its name is set round.
  late final List<Offset> _rim = shape.outline(radius).points;

  /// How light a territory is drawn, so neighbours tell apart in one
  /// neutral: a step of a small ramp, by its chromosome.
  static double _tone(String name, int copy) =>
      0.16 + 0.36 * (((chromosomeNames.indexOf(name) * 7 + copy * 3) % 9) / 8);

  @override
  void prepare(ZoomInks inks) => <Object?>[
    _territories,
    _outline,
    _pores,
    _rim,
    nucleolus.path,
  ];

  @override
  bool wantsClock(ZoomFrame frame) => !frame.isChild && frame.dwell < 1.4;

  // As the nucleus is reached, the gene's territory pings once.
  @override
  void paintAmbient(Canvas canvas, ZoomFrame frame) {
    if (frame.isChild) {
      return;
    }
    final Rect box = _territories[(subject.track.chromosome, 0)]!.getBounds();
    canvas.save();
    frame.enter(canvas);
    Sculpt.ping(
      canvas,
      box.center,
      box.longestSide / 2,
      box.longestSide * 0.6,
      Sculpt.beat(frame.dwell, delay: 0.15, length: 1.1),
      frame.pixel,
      frame.inks,
      opacity: frame.opacity * (1 - smoothstep(frame.progress / 0.15)),
    );
    canvas.restore();
  }

  @override
  void paint(Canvas canvas, ZoomFrame frame) {
    canvas.save();
    frame.enter(canvas);
    final double pixel = frame.pixel;
    final ZoomInks inks = frame.inks;
    final double r = radius;
    canvas.drawCircle(Offset.zero, 2, Paint()..color = inks.ground);
    final Path outline = _outline;
    final Rect round = Rect.fromCircle(center: Offset.zero, radius: r);
    Sculpt.shadowUnder(canvas, round, inks, strength: 0.5);
    // The nucleus as the cell drew it: a sphere in the quiet ink.
    canvas.drawPath(
      outline,
      Paint()
        ..shader = RadialGradient(
          center: Sculpt.highlight,
          radius: 1.05,
          colors: <Color>[
            Color.lerp(inks.high, inks.label, 0.78)!,
            Color.lerp(inks.high, inks.label, 0.4)!,
            inks.shade(0.7),
          ],
          stops: const <double>[0, 0.5, 1],
        ).createShader(round),
    );
    // The territories resolve out of it on the way in, each in a neutral
    // a step from its neighbours'.
    final double painted = _painted(frame);
    canvas.save();
    canvas.clipPath(outline);
    final String followed = subject.track.chromosome;
    // As the gene's territory condenses into its chromosome, the others
    // drift out from it and fade.
    final double away = _away(frame);
    final double shown = painted * (1 - away);
    if (shown > 0) {
      final Paint fill = Paint();
      final Paint edge = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1 * pixel
        ..color = inks.shade(0.55).withValues(alpha: 0.9 * shown);
      for (final String name in chromosomeNames) {
        for (int copy = 0; copy < 2; copy++) {
          if (name == followed && (copy == 0 || paired)) {
            continue;
          }
          final Path territory = _territories[(name, copy)]!;
          fill.color = Color.lerp(
            inks.high,
            inks.label,
            _tone(kindOf(name, copy), copy),
          )!.withValues(alpha: 0.9 * shown);
          final Offset drift = _drift(name, copy, away);
          canvas.save();
          canvas.translate(drift.dx, drift.dy);
          canvas.drawPath(territory, fill);
          canvas.drawPath(territory, edge);
          canvas.restore();
        }
      }
      // The gene's chromosome's other copy, over the rest so it shows whole,
      // faintly in the mark: the followed territory is one of two.
      if (paired) {
        final Path other = _territories[(followed, 1)]!;
        final Offset drift = _drift(followed, 1, away);
        canvas.save();
        canvas.translate(drift.dx, drift.dy);
        canvas.drawPath(
          other,
          fill
            ..color = Color.lerp(
              Color.lerp(inks.high, inks.label, _tone(followed, 1)),
              inks.mark,
              0.3,
            )!.withValues(alpha: 0.9 * shown),
        );
        canvas.drawPath(
          other,
          edge
            ..strokeWidth = 1.2 * pixel
            ..color = inks.glow(0.6 * shown),
        );
        canvas.restore();
      }
    }
    // The light falling across the whole of it.
    canvas.drawPath(
      outline,
      Paint()
        ..shader = RadialGradient(
          center: Sculpt.highlight,
          radius: 1.1,
          colors: <Color>[
            inks.text.withValues(alpha: 0.1),
            inks.text.withValues(alpha: 0),
            inks.shadow.withValues(alpha: 0.35),
          ],
          stops: const <double>[0, 0.5, 1],
        ).createShader(round),
    );
    // The nucleolus: a dark body among them, over the light, as the cell
    // draws it, so it is one tone at both stops.
    nucleolus.paint(canvas, inks, pixel);
    canvas.restore();
    // The envelope, and its pores once there is room to see them.
    canvas.drawPath(
      outline,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4 * pixel
        ..color = inks.lit(0.42),
    );
    Sculpt.rim(canvas, outline, round, inks, width: 1.8 * pixel, strength: 0.4);
    final double rimPixels = r * frame.view.pixelsPerUnit;
    if (rimPixels > 140) {
      final double pores = smoothstep((rimPixels - 140) / 80);
      final Paint pore = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1 * pixel
        ..color = inks.lit(0.55).withValues(alpha: 0.8 * pores);
      for (final Offset p in _pores) {
        canvas.drawCircle(p, 2.2 * pixel, pore);
      }
    }
    // The gene's chromosome, in the mark, until the chromosome's scene takes
    // it over.
    if (frame.isChild || frame.progress <= 0) {
      final Path own = _territories[(followed, 0)]!;
      paintFollowedTerritory(
        canvas,
        own,
        own.getBounds(),
        inks,
        pixel,
        fill: inks.glow(0.35 + 0.45 * painted),
        halo: painted,
        edge: painted,
      );
    }
    canvas.restore();
  }
}
