import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/anatomy_figure.dart';
import '../../domain/anatomy_tables.dart';
import '../../domain/zoom_camera.dart';
import '../../domain/zoom_depth.dart';
import 'body_scene.dart';
import 'contour.dart';
import 'nucleus_shape.dart';
import 'zoom_scene.dart';
import 'zoom_subject.dart';

/// The 23 pairs of chromosomes a nucleus holds: 1 to 22, and the sex
/// chromosomes, of which a male body's second is a Y
/// ([NucleusScene.kindOf]).
const List<String> chromosomeNames = <String>[
  '1', '2', '3', '4', '5', '6', '7', '8', '9', '10', '11', '12', '13', '14', //
  '15', '16', '17', '18', '19', '20', '21', '22', 'X',
];

/// The nucleus in chromosome paint, as fluorescence in-situ hybridisation
/// shows it: each of its 46 chromosomes in a territory of its own, one
/// colour a chromosome, a territory as big as its chromosome's DNA, the
/// gene-dense ones toward the centre and the gene-poor at the rim, the five
/// that carry ribosomal genes gathered round the nucleolus. The gene's own
/// chromosome is the one the zoom follows.
///
/// On the way in, the nucleus's even DNA stain resolves into the paint; on
/// the way out, the followed territory is handed to the chromosome's scene
/// to condense, and the rest give way.
final class NucleusScene extends ZoomScene {
  NucleusScene(this.subject) : shape = NucleusShape(subject.depth.archetype.shape);

  final ZoomSubject subject;
  final NucleusShape shape;

  @override
  ZoomStop get stop => ZoomStop.nucleus;

  /// The nucleus's radius, in the scene's units.
  double get radius =>
      subject.depth.archetype.nucleus / 2 / subject.depth.widthOf(stop);

  /// Where the nucleolus is, as a point of the unit disc.
  static const Offset nucleolus = Offset(-0.32, -0.28);

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
      final Offset unit = nucleolus + Offset(math.cos(a), math.sin(a)) * 0.3;
      return shape.place(unit, radius);
    }
    final double depth = (territoryRadius[kindOf(name, copy)] ?? 0.6) * 0.92;
    final double a = index * 2.39996 + copy * (math.pi * 0.9);
    return shape.place(Offset(math.cos(a), math.sin(a)) * depth, radius);
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

  @override
  Offset get portal => territory(subject.track.chromosome, 0);

  @override
  void stage(ZoomFrame frame, ZoomStaging out) {
    final Offset target = frame.toScreen(portal);
    out.item('nucleus:target', target, frame.opacity);
    out.callout(
      'nucleus',
      'chromosome ${subject.track.chromosome}',
      target,
      calloutPresence(frame),
    );
  }

  @override
  void paint(Canvas canvas, ZoomFrame frame) {
    canvas.save();
    frame.enter(canvas);
    final double pixel = frame.pixel;
    final double r = radius;
    canvas.drawCircle(
      Offset.zero,
      2,
      Paint()..color = frame.inks.scale.fluorescence,
    );
    final Path outline = shape.outline(r).toPath();
    // The DNA stain, even, brightest at the centre.
    canvas.drawPath(
      outline,
      Paint()
        ..shader = RadialGradient(
          colors: <Color>[
            frame.inks.scale.dapi.withValues(alpha: 0.75),
            frame.inks.scale.dapi.withValues(alpha: 0.4),
          ],
        ).createShader(Rect.fromCircle(center: Offset.zero, radius: r * 1.6)),
    );
    // The paint resolves out of it on the way in.
    final double painted = frame.isChild
        ? smoothstep((frame.progress - 0.35) / 0.45)
        : 1;
    canvas.save();
    canvas.clipPath(outline);
    final String followed = subject.track.chromosome;
    if (painted > 0) {
      final Paint fill = Paint();
      for (final String name in chromosomeNames) {
        for (int copy = 0; copy < 2; copy++) {
          if (name == followed && copy == 0) {
            continue;
          }
          fill.color = frame.inks.scale
              .paintOf(kindOf(name, copy))
              .withValues(alpha: 0.62 * painted);
          canvas.drawPath(territoryShape(name, copy).toPath(), fill);
        }
      }
    }
    // The nucleolus: a hollow in the DNA stain.
    final Offset nucleolusAt = shape.place(nucleolus, r);
    canvas.drawCircle(
      nucleolusAt,
      r * 0.17,
      Paint()..color = frame.inks.scale.fluorescence.withValues(alpha: 0.55),
    );
    canvas.restore();
    // The envelope, and its pores once there is room to see them.
    canvas.drawPath(
      outline,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6 * pixel
        ..color = frame.inks.scale.membrane,
    );
    final double rimPixels = r * frame.view.pixelsPerUnit;
    if (rimPixels > 140) {
      final double pores = smoothstep((rimPixels - 140) / 80);
      final Paint pore = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2 * pixel
        ..color = frame.inks.scale.membrane.withValues(alpha: 0.8 * pores);
      final Contour rim = shape.outline(r).resampled(56);
      for (final Offset p in rim.points) {
        canvas.drawCircle(p, 2.2 * pixel, pore);
      }
    }
    // The followed territory, until the chromosome's scene takes it over.
    if (frame.isChild || frame.progress <= 0) {
      final Path own = territoryShape(followed, 0).toPath();
      canvas.drawPath(
        own,
        Paint()
          ..color = frame.inks.scale
              .paintOf(followed)
              .withValues(alpha: 0.4 + 0.6 * painted),
      );
      canvas.drawPath(
        own,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2 * pixel
          ..color = frame.inks.mark.withValues(alpha: painted),
      );
    }
    canvas.restore();
  }
}
