import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../domain/anatomy_tables.dart';
import '../../domain/cell_archetypes.dart';
import '../../domain/zoom_camera.dart';
import '../../domain/zoom_depth.dart';
import '../zoom_inks.dart';
import 'body_scene.dart';
import 'cell_scene.dart';
import 'contour.dart';
import 'nucleus_shape.dart';
import 'sculpt.dart';
import 'tissue/tissue_slide.dart';
import 'zoom_scene.dart';
import 'zoom_subject.dart';

/// The tissue as a pathologist sees it: a section stained with haematoxylin
/// and eosin, in the round field of a microscope's eyepiece under the lamp.
/// Its cells are laid out by the tissue's recipe ([TissueSlide]), and the
/// zoom's own cell sits at the centre in the outline the cell's scene draws
/// it in, ringed.
///
/// Coming from the organ, the field is the organ's marker at the place its
/// tissue is sampled, and opens out of it: the marker's ring becomes the
/// field's rim and grows as the camera closes in and the organ gives way
/// round it, the section coming up inside, until it is the eyepiece's field
/// at the stop. A field half a millimetre across is less than a pixel at
/// the organ, so it is drawn larger than it is while it opens, as the organ
/// is drawn smaller than it is while it grows out of the body, and arrives
/// at the camera's own scale and speed.
final class TissueScene extends ZoomScene {
  TissueScene(this.subject) : archetype = subject.depth.archetype;

  final ZoomSubject subject;
  final CellArchetype archetype;

  @override
  ZoomStop get stop => ZoomStop.tissue;

  /// The radius of the eyepiece's field, in the scene's units: five sixths
  /// of the view across, the organ dimmed round it.
  static const double field =
      ZoomDepth.tissueField / 2 / ZoomDepth.tissueMetres;

  /// One micrometre, in the scene's units: the slide is laid in
  /// micrometres.
  static const double micron = 1e-6 / ZoomDepth.tissueMetres;

  /// The radius of the organ's marker's ring on screen, in pixels: the
  /// field opens out of it ([Sculpt.beacon]).
  static const double markerRing = Sculpt.beaconRadius - 0.7;

  /// How far past the marker's ring the field has grown when the section
  /// is all there in it, as a logarithm: twelvefold.
  static const double _opened = 2.4849066497880004;

  /// How fast the field leaves the marker's ring, against the even pace
  /// from the ring to the eyepiece's field.
  static const double _leaving = 1.5;

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

  // The field is drawn from the segment's first frame, as the organ's
  // marker, and opens on its own ([openingAt]); the slide gives way to the
  // cell in the usual crossfade.
  @override
  double asChild(double progress) => 1;

  /// How much the view narrows across the step from the organ.
  late final double _ratio = subject.depth.ratioOf(ZoomStop.organ.index);

  /// The field's radius on screen at [frame], in pixels, and how far it has
  /// opened from the organ's marker into the section, from 0 to 1.
  ///
  /// At the tissue and on into the cell it is the eyepiece's field at the
  /// camera's scale, open. On the way in from the organ it grows out of the
  /// marker's ring to the eyepiece's field by an ease of its own, in
  /// logarithms: setting off half as fast again as it would grow from the
  /// ring to the stop at an even pace, so it is well open by the time the
  /// organ has given way round it, arriving as fast as the camera grows the
  /// field, and never drawn smaller than the field is. The section comes up
  /// in it as it grows, whole by twelve times the ring.
  @visibleForTesting
  (double, double) openingAt(ZoomFrame frame) {
    final double own = field * frame.view.pixelsPerUnit;
    if (!frame.isChild) {
      return (own, 1);
    }
    final double s = frame.progress;
    // In logarithms past the ring: the field at the stop, as it is now, and
    // how fast the camera grows it, per step.
    final double whole = math.log(field * frame.size.width / markerRing);
    final double past = math.log(own / markerRing);
    final double rate = -math.log(_ratio);
    // From nothing to the whole, leaving at [_leaving] times the even pace
    // and arriving at the camera's: a cubic, rising all the way for any
    // step the zoom takes (the camera's pace is from 0.8 to 2.2 times the
    // even one).
    final double arrival = rate / whole;
    final double opened =
        whole *
        (((_leaving + arrival - 2) * s + 3 - 2 * _leaving - arrival) * s * s +
            _leaving * s);
    // A field already bigger than the ring at the organ starts from the
    // ring too, and is its own size by the time the view has narrowed
    // twofold.
    final double ahead =
        math.max(0.0, past - rate * s) * (1 - smoothstep(rate * s / math.ln2));
    final double over = math.max(opened, past - ahead);
    return (markerRing * math.exp(over), smoothstep(over / _opened));
  }

  /// The view the slide is drawn in, its field [radius] pixels across on
  /// screen: the camera's own, but while the field is opening, closer, so
  /// the section fills it.
  ZoomView _view(ZoomFrame frame, double radius) {
    if (!frame.isChild) {
      return frame.view;
    }
    final double ppu = radius / field;
    final Offset at = frame.toScreen(Offset.zero);
    return ZoomView(
      stop: stop,
      pixelsPerUnit: ppu,
      centre: (frame.size.center(Offset.zero) - at) / ppu,
      progress: frame.progress,
      isChild: true,
    );
  }

  @override
  void stage(ZoomFrame frame, ZoomStaging out) {
    final (double radius, double open) = openingAt(frame);
    final ZoomView view = _view(frame, radius);
    final double shown = open * frame.opacity;
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
  void prepare(ZoomInks inks) => <Object?>[_slide, _ring, _named];

  @override
  bool wantsClock(ZoomFrame frame) => !frame.isChild && frame.dwell < 1.4;

  // As the tissue is reached, the zoom's cell pings once.
  @override
  void paintAmbient(Canvas canvas, ZoomFrame frame) {
    if (frame.isChild) {
      return;
    }
    final double t = Sculpt.beat(frame.dwell, delay: 0.15, length: 1.1);
    final double here = frame.opacity * (1 - smoothstep(frame.progress / 0.15));
    if (t <= 0 || t >= 1 || here <= 0) {
      return;
    }
    final ZoomView view = frame.view;
    final Rect cell = _ring.getBounds();
    final double perMicron = view.pixelsPerUnit * micron;
    Sculpt.ping(
      canvas,
      view.toScreen(cell.center * micron, frame.size),
      cell.longestSide / 2 * perMicron,
      34,
      t,
      1,
      frame.inks,
      opacity: here,
    );
  }

  // At the organ the field is the organ's marker, drawn as the marker is
  // ([Sculpt.beacon]): a glow, a ring of the bright ink, a dot of the mark.
  // As it opens, the ring becomes the field's lit rim and the dot and the
  // glow give way to the section.
  @override
  void paint(Canvas canvas, ZoomFrame frame) {
    final (double radius, double open) = openingAt(frame);
    final ZoomView view = _view(frame, radius);
    final ZoomInks inks = frame.inks;
    final Offset centre = view.toScreen(Offset.zero, frame.size);
    final Rect rim = Rect.fromCircle(center: centre, radius: radius);
    final double closed = 1 - open;
    if (closed > 0) {
      Sculpt.glow(canvas, centre, 16, inks, 0.32 * closed);
    }
    if (open > 0) {
      // The field's shadow on what lies round it.
      Sculpt.shadowUnder(canvas, rim, inks, strength: 0.5 * open, spread: 1.1);
      final Path lens = Path()..addOval(rim);
      canvas.save();
      canvas.clipPath(lens);
      canvas.drawPath(
        lens,
        Paint()..color = inks.ground.withValues(alpha: open),
      );
      canvas.translate(centre.dx, centre.dy);
      final double perMicron = view.pixelsPerUnit * micron;
      canvas.scale(perMicron);
      // Smaller than at the stop, the section is drawn as it is there seen
      // from further away, its lines as fine against it as they are there.
      final double rest = field * frame.size.width;
      paintTissueSlide(
        canvas,
        _slide,
        inks,
        pixel: 1 / perMicron,
        lines: radius < rest ? radius / rest / perMicron : null,
        alpha: open,
        striaPhase: _striaPhase,
      );
      // The zoom's cell, in the mark.
      final Rect cell = _ring.getBounds();
      Sculpt.glow(
        canvas,
        cell.center,
        cell.longestSide * 0.95,
        inks,
        0.3 * open,
      );
      canvas.drawPath(_ring, Paint()..color = inks.glow(0.26 * open));
      Sculpt.glowingStroke(
        canvas,
        _ring,
        inks,
        width: 1.8 / perMicron,
        alpha: open,
      );
      canvas.restore();
      // The field falls off toward its edge, as an eyepiece's does.
      canvas.drawPath(
        lens,
        Paint()
          ..shader = RadialGradient(
            colors: <Color>[
              inks.shadow.withValues(alpha: 0),
              inks.shadow.withValues(alpha: 0),
              inks.shadow.withValues(alpha: 0.55 * open),
            ],
            stops: const <double>[0, 0.72, 1],
          ).createShader(rim),
      );
    }
    // Its rim, the marker's ring as it opens.
    canvas.drawCircle(
      centre,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = ui.lerpDouble(1.4, 1.5, open)!
        ..color = Color.lerp(
          inks.text.withValues(alpha: 0.92),
          inks.lit(0.3).withValues(alpha: 0.8),
          open,
        )!,
    );
    if (closed > 0) {
      canvas.drawCircle(
        centre,
        Sculpt.beaconRadius - 1.4,
        Paint()..color = inks.glow(closed),
      );
    }
    // The light along its upper left.
    if (open > 0) {
      canvas.drawArc(
        rim,
        math.pi * 1.05,
        math.pi * 0.5,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round
          ..color = inks.glow(0.75 * open),
      );
    }
  }
}

/// Draws [slide] in its own micrometres, layer over layer, in the zoom's
/// inks: [pixel] is one screen pixel in micrometres, so lines keep their
/// weight at any magnification, but where [lines] says how wide a line one
/// pixel wide is drawn instead: a slide drawn smaller than at its stop
/// thins its lines with it. A muscle fibre's stripes are centred
/// [striaPhase] micrometres from the middle, and every sarcomere from there.
///
/// The section is seen as the app draws: on its own ground, as though lit
/// from the side, the cells' cytoplasm in the warm neutrals by how much
/// stain it would take, their nuclei bright in the quiet ink, the denser
/// the brighter, what takes no stain the ground, and blood the thymine red.
void paintTissueSlide(
  Canvas canvas,
  TissueSlide slide,
  ZoomInks inks, {
  required double pixel,
  double? lines,
  double alpha = 1,
  double striaPhase = 0,
}) {
  final Color cool = Color.lerp(inks.high, inks.label, 0.35)!;
  final Paint fill = Paint();
  final Paint stroke = Paint()..style = PaintingStyle.stroke;
  final double line = lines ?? pixel;
  void filled(Path path, Color color) => canvas.drawPath(
    path,
    fill..color = color.withValues(alpha: color.a * alpha),
  );
  void stroked(Path path, Color color, double strength, double width) =>
      canvas.drawPath(
        path,
        stroke
          ..strokeWidth = width * line
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
          filled(path, inks.ground);
        case SlideInk.eosin0:
          filled(path, inks.shade(0.62));
        case SlideInk.eosin1:
          filled(path, inks.shade(0.8));
        case SlideInk.eosin2:
          filled(path, inks.lit(0.1));
        case SlideInk.eosin3:
          filled(path, inks.lit(0.22));
        case SlideInk.basophil:
          filled(path, cool);
        case SlideInk.granules:
          filled(path, inks.lit(0.2));
        case SlideInk.stria:
          // Stripes a sarcomere apart. Finer than a pixel they would only
          // shimmer, so they come up as the view closes on them.
          final double seen = smoothstep(
            (TissueSlide.sarcomere / pixel - 1) / 1.2,
          );
          if (seen > 0) {
            final Color stripe = inks
                .lit(0.38)
                .withValues(alpha: 0.45 * alpha * seen);
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
        case SlideInk.home:
          filled(path, inks.glow(0.13));
          stroked(path, inks.mark, 0.35, 1);
        case SlideInk.border:
          stroked(path, inks.ground, 0.55, 1);
        case SlideInk.fibre:
          stroked(path, inks.label, 0.16, 0.9);
        case SlideInk.clear:
          filled(path, inks.ground);
          stroked(path, inks.lit(0.3), 0.6, 1.2);
        case SlideInk.nucleus0:
          filled(path, Color.lerp(inks.high, inks.label, 0.38)!);
          stroked(path, inks.label, 0.55, 0.8);
        case SlideInk.nucleus1:
          filled(path, Color.lerp(inks.high, inks.label, 0.6)!);
        case SlideInk.nucleus2:
          filled(path, Color.lerp(inks.high, inks.label, 0.82)!);
        case SlideInk.blood:
          filled(path, inks.blood);
      }
    }
  }
}
