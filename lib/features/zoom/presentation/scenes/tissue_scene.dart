import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../../core/theme/scale_colors.dart';
import '../../domain/anatomy_tables.dart';
import '../../domain/cell_archetypes.dart';
import '../../domain/zoom_camera.dart';
import '../../domain/zoom_depth.dart';
import 'body_scene.dart';
import 'cell_scene.dart';
import 'contour.dart';
import 'nucleus_shape.dart';
import 'tissue/tissue_slide.dart';
import 'zoom_scene.dart';
import 'zoom_subject.dart';

/// The tissue as a pathologist sees it: a section stained with haematoxylin
/// and eosin, in the round field of a microscope's eyepiece under the lamp.
/// Its cells are laid out by the tissue's recipe ([TissueSlide]), and the
/// zoom's own cell sits at the centre in the outline the cell's scene draws
/// it in, ringed.
///
/// Coming from the organ, the field opens as a loupe on the place the organ
/// is sampled: a circle that grows from a few tens of pixels to the
/// eyepiece's field while what it shows stays magnified about the same,
/// meeting the camera's own scale at the tissue's stop, as the organ round
/// it dims. A step of some hundredfold, made a change of instrument.
final class TissueScene extends ZoomScene {
  TissueScene(this.subject) : archetype = subject.depth.archetype;

  final ZoomSubject subject;
  final CellArchetype archetype;

  @override
  ZoomStop get stop => ZoomStop.tissue;

  /// The radius of the eyepiece's field, in the scene's units: it stands
  /// clear of the rail, with the dark of the eyepiece round it.
  static const double field =
      ZoomDepth.tissueField / 2 / ZoomDepth.tissueMetres;

  /// One micrometre, in the scene's units: the slide is laid in
  /// micrometres.
  static const double micron = 1e-6 / ZoomDepth.tissueMetres;

  /// The loupe's radius on screen as it opens, in pixels.
  static const double loupeStart = 56;

  /// How much of the slide the loupe shows across as it opens, in the
  /// scene's units.
  static const double loupeField = 0.3;

  TissueRecipe get _recipe {
    final String? tissue = subject.path.tissue;
    final TissueAnatomy? anatomy = tissue == null
        ? null
        : tissueAnatomy[tissue];
    return anatomy?.recipe ?? TissueRecipe.squamous;
  }

  /// A cell of [archetype] and its nucleus as a slide shows them, in
  /// micrometres: the outline the cell's scene draws, where that scene's
  /// view is [cellMetres] wide. A cell that runs off the cell's own view,
  /// as a muscle fibre does, runs off the field here too.
  static (Contour, Contour) targetOf(
    CellArchetype archetype,
    double cellMetres,
  ) {
    final double r = archetype.metres / 2 / cellMetres;
    final double n = archetype.nucleus / 2 / cellMetres;
    final double scale = cellMetres * 1e6;
    const double beyond = ZoomDepth.tissueField * 1e6;
    return (
      Contour(<Offset>[
        for (final Offset p in cellOutline(archetype.shape, r, n).points)
          Offset(
            p.dx.abs() > 0.5 ? p.dx.sign * beyond : p.dx * scale,
            p.dy * scale,
          ),
      ]),
      Contour(<Offset>[
        for (final Offset p in NucleusShape(archetype.shape).outline(n).points)
          p * scale,
      ]),
    );
  }

  late final (Contour, Contour) _target = targetOf(
    archetype,
    subject.depth.widthOf(ZoomStop.cell),
  );

  late final Path _ring = _target.$1.toPath();

  /// Where the cell's scene draws a fibre's striations, in micrometres from
  /// the middle: the slide's stripes lie on them, so the two are one set of
  /// stripes across the step between the scenes. The cell's scene rules
  /// them from two of its views to the left of its middle.
  late final double _striaPhase =
      (-2 * subject.depth.widthOf(ZoomStop.cell) * 1e6) % TissueSlide.sarcomere;

  /// Where on the cell's outline its name's line lands, in micrometres:
  /// its upper right, near its nucleus.
  late final Offset _named = () {
    Offset best = _target.$1.points.first;
    double most = double.negativeInfinity;
    for (final Offset p in _target.$1.points) {
      if (p.dx.abs() <= 40 && p.dx - p.dy > most) {
        most = p.dx - p.dy;
        best = p;
      }
    }
    return best;
  }();

  late final TissueSlide _slide = TissueSlide.of(
    _recipe,
    field: ZoomDepth.tissueField * 1e6 / 2,
    shape: archetype.shape,
    target: _target.$1,
    targetNucleus: _target.$2,
    seed: _recipe.index + 3,
  );

  // The loupe is drawn from the segment's first frame, its opening its own
  // fade; the slide gives way to the cell in the usual crossfade.
  @override
  double asChild(double progress) => 1;

  /// How far the loupe has opened, from 0 to 1, at [frame].
  double _opening(ZoomFrame frame) =>
      frame.isChild ? smootherstep((frame.progress - 0.04) / 0.92) : 1;

  /// How much of the loupe shows: it fades in as it starts to open.
  double _shown(ZoomFrame frame) =>
      frame.isChild ? smoothstep((frame.progress - 0.02) / 0.2) : 1;

  /// The view the slide is drawn in: through the loupe as it opens, the
  /// camera's own once it has.
  ZoomView _view(ZoomFrame frame) {
    if (!frame.isChild) {
      return frame.view;
    }
    final double e = _opening(frame);
    final double w = frame.size.width;
    final double r1 = field * w;
    final double radius = loupeStart * math.pow(r1 / loupeStart, e);
    final double shown = loupeField * math.pow(2 * field / loupeField, e);
    final double ppu = 2 * radius / shown;
    final Offset at = frame.toScreen(Offset.zero);
    final Offset centre = (frame.size.center(Offset.zero) - at) / ppu;
    return ZoomView(
      stop: stop,
      pixelsPerUnit: ppu,
      centre: centre,
      progress: frame.progress,
      isChild: true,
    );
  }

  @override
  void stage(ZoomFrame frame, ZoomStaging out) {
    final ZoomView view = _view(frame);
    final double shown = _shown(frame) * frame.opacity;
    out.item('tissue:target', view.toScreen(Offset.zero, frame.size), shown);
    final String? cell = subject.path.cellName;
    out.callout(
      'tissue',
      cell == null
          ? 'a cell of the ${subject.path.tissue ?? 'tissue'}'
          : (subject.path.landsIn?.cell ?? cell.toLowerCase()),
      view.toScreen(_named * micron, frame.size),
      math.min(calloutPresence(frame), shown),
    );
  }

  @override
  void paint(Canvas canvas, ZoomFrame frame) {
    final ZoomView view = _view(frame);
    final Size size = frame.size;
    final Offset centre = view.toScreen(Offset.zero, size);
    final double radius = field * view.pixelsPerUnit;
    final double shown = _shown(frame);
    final Path lens = Path()
      ..addOval(Rect.fromCircle(center: centre, radius: radius));
    // Outside the field: the organ dimming as the loupe opens, then the
    // dark of the eyepiece.
    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(Offset.zero & size),
        lens,
      ),
      Paint()
        ..color = frame.inks.scale.eyepiece.withValues(
          alpha: _opening(frame) * shown,
        ),
    );
    canvas.save();
    canvas.clipPath(lens);
    canvas.drawPath(
      lens,
      Paint()..color = frame.inks.scale.brightfield.withValues(alpha: shown),
    );
    canvas.translate(centre.dx, centre.dy);
    final double perMicron = view.pixelsPerUnit * micron;
    canvas.scale(perMicron);
    paintTissueSlide(
      canvas,
      _slide,
      frame.inks.scale,
      pixel: 1 / perMicron,
      alpha: shown,
      striaPhase: _striaPhase,
    );
    // The zoom's cell, ringed.
    canvas.drawPath(
      _ring,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2 / perMicron
        ..color = frame.inks.mark.withValues(alpha: shown),
    );
    canvas.restore();
    // The field darkens toward its edge, as an eyepiece's does.
    final Color dark = frame.inks.scale.eyepiece;
    canvas.drawPath(
      lens,
      Paint()
        ..shader = RadialGradient(
          colors: <Color>[
            dark.withValues(alpha: 0),
            dark.withValues(alpha: 0),
            dark.withValues(alpha: 0.3 * shown),
          ],
          stops: const <double>[0, 0.74, 1],
        ).createShader(Rect.fromCircle(center: centre, radius: radius)),
    );
    canvas.drawCircle(
      centre,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = frame.inks.scale.membrane.withValues(alpha: 0.6 * shown),
    );
  }
}

/// Draws [slide] in its own micrometres, layer over layer, in the stains'
/// colours: [pixel] is one screen pixel in micrometres, so lines keep their
/// weight at any magnification. A muscle fibre's stripes are centred
/// [striaPhase] micrometres from the middle, and every sarcomere from there.
void paintTissueSlide(
  Canvas canvas,
  TissueSlide slide,
  ScaleColors colors, {
  required double pixel,
  double alpha = 1,
  double striaPhase = 0,
}) {
  final Color lamp = colors.brightfield;
  final Color eosin = colors.eosin;
  final Color deep = colors.eosinDeep;
  final Color pale = colors.haematoxylinLight;
  final Color dark = colors.haematoxylin;
  Color mix(Color a, Color b, double t) => Color.lerp(a, b, t)!;
  final Paint fill = Paint();
  final Paint stroke = Paint()..style = PaintingStyle.stroke;
  void filled(Path path, Color color) =>
      canvas.drawPath(path, fill..color = color.withValues(alpha: alpha));
  void stroked(Path path, Color color, double strength, double width) =>
      canvas.drawPath(
        path,
        stroke
          ..strokeWidth = width * pixel
          ..color = color.withValues(alpha: strength * alpha),
      );
  for (final SlideLayer layer in slide.layers) {
    for (final SlideInk ink in SlideInk.values) {
      final Path? path = layer[ink];
      if (path == null) {
        continue;
      }
      switch (ink) {
        case SlideInk.lamp:
          filled(path, lamp);
        case SlideInk.eosin0:
          filled(path, mix(lamp, eosin, 0.55));
        case SlideInk.eosin1:
          filled(path, eosin);
        case SlideInk.eosin2:
          filled(path, mix(eosin, deep, 0.45));
        case SlideInk.eosin3:
          filled(path, mix(eosin, deep, 0.9));
        case SlideInk.basophil:
          filled(path, mix(mix(eosin, deep, 0.5), pale, 0.55));
        case SlideInk.granules:
          filled(path, mix(eosin, deep, 0.9));
        case SlideInk.stria:
          // Stripes a sarcomere apart. Finer than a pixel they would only
          // shimmer, so they come up as the view closes on them.
          final double seen = smoothstep(
            (TissueSlide.sarcomere / pixel - 1) / 1.2,
          );
          if (seen > 0) {
            final Color stripe = deep.withValues(alpha: 0.36 * alpha * seen);
            final double from = striaPhase - 0.21 * TissueSlide.sarcomere;
            canvas.drawPath(
              path,
              Paint()
                ..shader = ui.Gradient.linear(
                  Offset(from, 0),
                  Offset(from + TissueSlide.sarcomere, 0),
                  <Color>[
                    stripe,
                    stripe,
                    stripe.withValues(alpha: 0),
                    stripe.withValues(alpha: 0),
                  ],
                  const <double>[0, 0.42, 0.42, 1],
                  TileMode.repeated,
                ),
            );
          }
        case SlideInk.border:
          stroked(path, deep, 0.42, 1);
        case SlideInk.fibre:
          stroked(path, deep, 0.45, 1.1);
        case SlideInk.clear:
          filled(path, lamp);
          stroked(path, deep, 0.35, 1.3);
        case SlideInk.nucleus0:
          filled(path, mix(lamp, pale, 0.62));
          stroked(path, dark, 0.75, 0.9);
        case SlideInk.nucleus1:
          filled(path, mix(pale, dark, 0.45));
          stroked(path, dark, 0.5, 0.7);
        case SlideInk.nucleus2:
          filled(path, dark);
        case SlideInk.blood:
          filled(path, colors.redCell);
      }
    }
  }
}
