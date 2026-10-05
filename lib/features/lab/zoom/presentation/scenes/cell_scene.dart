import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/zoom_depth.dart';
import '../../domain/zoom_path.dart';
import 'body_scene.dart';
import 'tissue_scene.dart';
import 'zoom_scene.dart';
import 'zoom_subject.dart';

/// The cell the zoom lands in, its nucleus at the centre. Where the Atlas's
/// cell type has no nucleus, the grown cell is drawn beside the precursor
/// the zoom enters.
final class CellScene extends ZoomScene {
  const CellScene(this.subject);

  final ZoomSubject subject;

  @override
  ZoomStop get stop => ZoomStop.cell;

  double get _radius => subject.unitsOf(stop, cellMetres) / 2;

  Offset get _beside {
    final Anucleate? anucleate = subject.path.anucleate;
    final double m = anucleate == null
        ? 0
        : subject.unitsOf(stop, anucleate.size) / 2;
    return Offset(-_radius - m - 0.03, -_radius);
  }

  @override
  void stage(ZoomFrame frame, ZoomStaging out) {
    final ZoomPath path = subject.path;
    final double shown = calloutPresence(frame);
    // The membrane, low on the right: where a name can land on the cell.
    final Offset below = frame.toScreen(
      Offset(_radius * 0.6, _radius * 0.8),
    );
    out.item('cell:target', frame.toScreen(Offset.zero), frame.opacity);
    final Anucleate? anucleate = path.anucleate;
    if (anucleate != null) {
      out.callout(
        'cell:mature',
        '${anucleate.mature}: no nucleus',
        frame.toScreen(_beside),
        shown,
      );
      out.callout('cell', anucleate.precursor, below, shown);
      return;
    }
    final String? cell = path.cellName;
    out.callout(
      'cell',
      cell == null
          ? 'a cell of the ${path.tissue ?? 'tissue'}'
          : cell.toLowerCase(),
      below,
      shown,
    );
  }

  @override
  void paint(Canvas canvas, ZoomFrame frame) {
    canvas.save();
    frame.enter(canvas);
    final double pixel = frame.pixel;
    final double r = _radius;
    final double n = subject.unitsOf(stop, nucleusMetres) / 2;
    // The dark of the fluorescence field, and the cell in it.
    canvas.drawCircle(
      Offset.zero,
      1.2,
      Paint()..color = frame.inks.scale.fluorescence,
    );
    final Paint edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4 * pixel
      ..color = frame.inks.scale.membrane;
    canvas.drawCircle(
      Offset.zero,
      r,
      Paint()..color = frame.inks.scale.reticulum.withValues(alpha: 0.12),
    );
    canvas.drawCircle(Offset.zero, r, edge);
    final Paint organelle = Paint()
      ..color = frame.inks.scale.microtubules.withValues(alpha: 0.45);
    for (int k = 0; k < 40; k++) {
      final double a = k * 2.399;
      final double d = r * (0.55 + 0.35 * ((k * 37 % 11) / 11));
      canvas.drawCircle(
        Offset(math.cos(a) * d, math.sin(a) * d),
        r * 0.027,
        organelle,
      );
    }
    canvas.drawCircle(Offset.zero, n, Paint()..color = frame.inks.scale.dapi);
    canvas.drawCircle(
      Offset.zero,
      n,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2 * pixel
        ..color = frame.inks.mark,
    );
    final Anucleate? anucleate = subject.path.anucleate;
    if (anucleate != null) {
      final double m = subject.unitsOf(stop, anucleate.size) / 2;
      final Offset beside = _beside;
      canvas.drawCircle(
        beside,
        m,
        Paint()..color = frame.inks.scale.eosinDeep.withValues(alpha: 0.6),
      );
      canvas.drawCircle(
        beside,
        m * 0.45,
        Paint()..color = frame.inks.scale.eosin.withValues(alpha: 0.4),
      );
      canvas.drawCircle(beside, m, edge);
    }
    canvas.restore();
  }
}
