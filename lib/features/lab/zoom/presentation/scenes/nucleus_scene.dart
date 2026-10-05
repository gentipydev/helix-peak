import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/anatomy_tables.dart';
import '../../domain/zoom_camera.dart';
import '../../domain/zoom_depth.dart';
import 'body_scene.dart';
import 'tissue_scene.dart';
import 'zoom_scene.dart';
import 'zoom_subject.dart';

/// The 23 kinds of chromosome a nucleus holds two of: 1 to 22, and X.
const List<String> chromosomeNames = <String>[
  '1', '2', '3', '4', '5', '6', '7', '8', '9', '10', '11', '12', '13', '14', //
  '15', '16', '17', '18', '19', '20', '21', '22', 'X',
];

/// The nucleus, its 46 chromosomes each in a territory of its own, the
/// gene's chromosome at the place nuclei tend to keep it.
final class NucleusScene extends ZoomScene {
  const NucleusScene(this.subject);

  final ZoomSubject subject;

  @override
  ZoomStop get stop => ZoomStop.nucleus;

  double get _radius => subject.unitsOf(stop, nucleusMetres) / 2;

  /// A territory's radius, in the scene's units.
  double get spot => _radius * 0.14;

  // Its other territories and its envelope give way while the followed one
  // condenses, which the chromosome's scene draws from the first frame.
  @override
  double asParent(double progress) => 1 - smoothstep((progress - 0.3) / 0.5);

  /// Where homologue [copy] of chromosome [name] lies: at its usual depth
  /// from the centre, the two copies apart.
  Offset territory(String name, int copy) {
    final int index = math.max(chromosomeNames.indexOf(name), 0);
    final double depth = territoryRadius[name] ?? 0.6;
    final double a = index * 2.39996 + copy * (math.pi * 0.86);
    final double d = _radius * 0.78 * depth;
    return Offset(math.cos(a) * d, math.sin(a) * d);
  }

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
    final double r = _radius;
    final double spot = this.spot;
    canvas.drawCircle(
      Offset.zero,
      1.2,
      Paint()..color = frame.inks.scale.fluorescence,
    );
    canvas.drawCircle(
      Offset.zero,
      r,
      Paint()..color = frame.inks.scale.dapi.withValues(alpha: 0.35),
    );
    canvas.drawCircle(
      Offset.zero,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6 * pixel
        ..color = frame.inks.scale.membrane,
    );
    final String followed = subject.track.chromosome;
    final Paint territory = Paint();
    for (final String name in chromosomeNames) {
      for (int copy = 0; copy < 2; copy++) {
        if (name == followed && copy == 0) {
          continue;
        }
        territory.color = frame.inks.scale
            .paintOf(name)
            .withValues(alpha: 0.42);
        canvas.drawCircle(this.territory(name, copy), spot, territory);
      }
    }
    // A nucleolus.
    canvas.drawCircle(
      Offset(-r * 0.32, -r * 0.3),
      r * 0.17,
      Paint()..color = frame.inks.scale.dapi.withValues(alpha: 0.15),
    );
    // The followed territory, until the chromosome's scene takes it over.
    if (frame.isChild || frame.progress <= 0) {
      final Offset at = portal;
      canvas.drawCircle(
        at,
        spot,
        Paint()..color = frame.inks.scale.paintOf(followed),
      );
      canvas.drawCircle(
        at,
        spot,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2 * pixel
          ..color = frame.inks.mark,
      );
    }
    canvas.restore();
  }
}
