import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/anatomy_figure.dart';
import '../../domain/anatomy_tables.dart';
import '../../domain/cell_archetypes.dart';
import '../../domain/zoom_depth.dart';
import '../zoom_inks.dart';
import 'contour.dart';
import 'organ_studies.dart';
import 'organs/adrenal/adrenal_art.dart';
import 'organs/adrenal/adrenal_form.dart';
import 'organs/adrenal/adrenal_style.dart';
import 'organs/bone_marrow/marrow_art.dart';
import 'organs/bone_marrow/marrow_form.dart';
import 'organs/brain/brain_anatomy.dart';
import 'organs/brain/brain_art.dart';
import 'organs/brain/brain_form.dart';
import 'organs/brain/brain_style.dart';
import 'organs/esophagus/esophagus_art.dart';
import 'organs/esophagus/esophagus_form.dart';
import 'organs/esophagus/esophagus_style.dart';
import 'organs/eye/eye_art.dart';
import 'organs/eye/eye_form.dart';
import 'organs/eye/eye_style.dart';
import 'organs/fallopian_tube/fallopian_art.dart';
import 'organs/fallopian_tube/fallopian_form.dart';
import 'organs/fallopian_tube/fallopian_style.dart';
import 'organs/heart/heart_art.dart';
import 'organs/heart/heart_form.dart';
import 'organs/heart/heart_style.dart';
import 'organs/kidney/kidney_art.dart';
import 'organs/kidney/kidney_form.dart';
import 'organs/liver/liver_art.dart';
import 'organs/liver/liver_form.dart';
import 'organs/liver/liver_style.dart';
import 'organs/lymph_node/node_art.dart';
import 'organs/lymph_node/node_form.dart';
import 'organs/lymph_node/node_style.dart';
import 'organs/pancreas/pancreas_anatomy.dart';
import 'organs/pancreas/pancreas_art.dart';
import 'organs/pancreas/pancreas_form.dart';
import 'organs/pancreas/pancreas_style.dart';
import 'organs/pituitary/pituitary_art.dart';
import 'organs/pituitary/pituitary_form.dart';
import 'organs/placenta/placenta_art.dart';
import 'organs/placenta/placenta_form.dart';
import 'organs/salivary_gland/salivary_art.dart';
import 'organs/salivary_gland/salivary_form.dart';
import 'organs/salivary_gland/salivary_style.dart';
import 'organs/skeletal_muscle/thigh_art.dart';
import 'organs/skeletal_muscle/thigh_form.dart';
import 'organs/skeletal_muscle/thigh_style.dart';
import 'organs/skin/skin_art.dart';
import 'organs/skin/skin_form.dart';
import 'organs/skin/skin_style.dart';
import 'organs/stomach/stomach_art.dart';
import 'organs/stomach/stomach_form.dart';
import 'organs/stomach/stomach_style.dart';
import 'organs/testis/testis_anatomy.dart';
import 'organs/testis/testis_art.dart';
import 'organs/testis/testis_form.dart';
import 'organs/testis/testis_style.dart';
import 'organs/thyroid/thyroid_art.dart';
import 'organs/thyroid/thyroid_form.dart';
import 'organs/thyroid/thyroid_style.dart';
import 'sculpt.dart';
import 'specimen_step.dart';
import 'tube_course.dart';
import 'zoom_subject.dart';

/// A name an organ's scene sets: its [key] among the scene's, its [word],
/// what it names, at the organ's real size, and whether that is where the
/// zoom's cell lives ([home]), its line then in the mark.
typedef OrganName = ({String key, String word, Offset at, bool home});

/// The column at the canvas's edge a name is set in (`ZoomCallout.flush`):
/// on the organ's [side], -1 its left and 1 its right, beside the organ's
/// outermost points to its [left] and [right] at the height of what it
/// names, at the organ's real size.
typedef OrganColumn = ({double side, Offset left, Offset right});

/// An organ as its own scene draws it: in the scene's units, at its real
/// size, its middle at the origin, and where in it its tissue is sampled
/// ([site]).
///
/// Most organs are the anatomogram's own outline for them, the one the body
/// drew, sculpted in the app's neutrals and given what lies inside them for
/// the kind of organ each is. The anatomogram is a diagram and draws many
/// of them smaller than they are, so each knows how many times its drawn
/// size it really is ([real]): the scene grows it to that on the way in. A
/// few have no outline of their own there, or none that shows the tissue (a
/// lymph node, a vessel, the skin, a parathyroid gland, the retina), and are
/// drawn from general anatomy, as are the pancreas, the testis, cut down its
/// length, the salivary gland, its parotid in place, the brain, cut down
/// its middle, the eye, cut level through its optic nerve, the bone
/// marrow, its femur cut down its length, the heart, cut open, skeletal
/// muscle, the front of the thigh, the kidney and the liver, each cut open
/// from front to back, the stomach and the esophagus, each opened from
/// the front, the skin, a block of it cut from the leg, the thyroid, seen
/// from the front in place, one lobe cut open, the adrenal, cut through its
/// thickness on its kidney's upper pole, the pituitary, cut down its
/// middle as the brain is, a lymph node, cut through its hilum, the
/// fallopian tube, opened along its length, and the placenta, a block cut
/// through it in its uterine wall.
///
/// Where the gene is, the organ glows in the mark: the part of it the
/// zoom's cell lives in (the islets of a pancreas for an endocrine cell, its
/// ducts for a duct cell, the interstitium of a testis for a Leydig cell,
/// the loops of Henle of a kidney for a cell the Atlas names theirs, the
/// bile ducts of a liver for a cholangiocyte, the muscularis of a stomach
/// for a smooth muscle cell, the glands of an esophagus for a cell of its
/// submucosal glands, the basal layer of the skin and its hair bulbs for a
/// melanocyte, the C cells of a thyroid for a parafollicular cell, the
/// medulla of an adrenal for a chromaffin cell, the posterior lobe of a
/// pituitary for a pituicyte, the sinuses of a lymph node for a lymphatic
/// endothelial cell, the muscular coat of a fallopian tube for a smooth
/// muscle cell, the decidua of a placenta for a decidual stromal cell), by
/// the kind of organ and of cell, never by gene.
abstract class OrganArt {
  OrganArt();

  factory OrganArt.of(ZoomSubject subject) => OrganArt.forTissue(
    subject.anatomy,
    subject.bodyPart,
    subject.depth.widthOf(ZoomStop.organ),
    figure: subject.body,
    shape: subject.depth.archetype.shape,
    cellName: subject.path.cellName,
    level: subject.followedLevel,
  );

  /// The organ a tissue drawn as [anatomy] is in, where the body draws it
  /// as [part] of [figure] and the scene's unit is [view] metres, about a
  /// cell of [shape], which the Atlas calls [cellName] where it names one:
  /// an organ whose cells are all drawn as one shape tells them apart by it.
  /// [level] is how strongly the body lit it.
  factory OrganArt.forTissue(
    TissueAnatomy? anatomy,
    AnatomyPart? part,
    double view, {
    AnatomyFigure? figure,
    CellShape shape = CellShape.epithelial,
    String? cellName,
    double level = 1,
  }) {
    if (anatomy == null) {
      return _AnyOrgan();
    }
    final double size = anatomy.metres / view;
    return switch (anatomy.organ) {
      OrganKind.brain => _BrainOrgan(anatomy, view),
      OrganKind.lymphNode => _NodeOrgan(anatomy, view, cell: cellName),
      OrganKind.vessel => _VesselOrgan(size),
      OrganKind.skin => _SkinOrgan(anatomy, view, cell: cellName),
      OrganKind.placenta => _PlacentaOrgan(anatomy, view, cell: cellName),
      OrganKind.parathyroid => _ParathyroidOrgan(size),
      OrganKind.eye => _EyeOrgan(anatomy, view, part: part, cell: shape),
      OrganKind.pancreas when part != null => _PancreasOrgan(
        part,
        anatomy,
        view,
        figure: figure,
        cell: shape,
        level: level,
      ),
      OrganKind.testis when part != null => _TestisOrgan(
        part,
        anatomy,
        view,
        figure: figure,
        cell: shape,
        level: level,
      ),
      OrganKind.salivaryGland when part != null => _SalivaryOrgan(
        part,
        anatomy,
        view,
        figure: figure,
        cell: shape,
        level: level,
      ),
      OrganKind.boneMarrow when part != null => _MarrowOrgan(
        part,
        anatomy,
        view,
        figure: figure,
        level: level,
      ),
      OrganKind.heart when part != null => _HeartOrgan(
        part,
        anatomy,
        view,
        figure: figure,
        cell: shape,
        level: level,
      ),
      OrganKind.skeletalMuscle when part != null && figure != null =>
        _ThighOrgan(part, anatomy, view, figure: figure, level: level),
      OrganKind.kidney when part != null => _KidneyOrgan(
        part,
        anatomy,
        view,
        figure: figure,
        cell: cellName,
        level: level,
      ),
      OrganKind.liver when part != null => _LiverOrgan(
        part,
        anatomy,
        view,
        figure: figure,
        cell: cellName,
        level: level,
      ),
      OrganKind.stomach when part != null => _StomachOrgan(
        part,
        anatomy,
        view,
        figure: figure,
        cell: cellName,
        level: level,
      ),
      OrganKind.esophagus when part != null => _EsophagusOrgan(
        part,
        anatomy,
        view,
        figure: figure,
        cell: cellName,
        level: level,
      ),
      OrganKind.thyroid when part != null => _ThyroidOrgan(
        part,
        anatomy,
        view,
        figure: figure,
        cell: cellName,
        level: level,
      ),
      OrganKind.adrenal when part != null => _AdrenalOrgan(
        part,
        anatomy,
        view,
        figure: figure,
        cell: cellName,
        level: level,
      ),
      OrganKind.pituitary when part != null => _PituitaryOrgan(
        part,
        anatomy,
        view,
        figure: figure,
        cell: cellName,
        level: level,
      ),
      OrganKind.fallopianTube when part != null => _FallopianOrgan(
        part,
        anatomy,
        view,
        figure: figure,
        cell: cellName,
        level: level,
      ),
      _ =>
        part == null
            ? _AnyOrgan()
            : _DrawnOrgan(
                part,
                anatomy,
                view,
                figure: figure,
                shape: shape,
                level: level,
              ),
    };
  }

  /// How many times the size the body draws it at the organ really is.
  double get real => 1;

  /// Whether this is the body's own outline of the organ, seen closer: the
  /// two then coincide as the organ's scene takes over from the body's.
  bool get followsBody => false;

  /// Where in the organ its tissue is sampled, at its real size.
  Offset get site => Offset.zero;

  /// The organ's outline at its real size, for the light that passes over
  /// it as it is reached; none where it has no one outline.
  Path get outline => Path();

  /// What its scene names in it, at its real size: the part of it the
  /// zoom's cell lives in, and the neighbours drawn round it. None where
  /// it draws nothing to name.
  List<OrganName> get names => const <OrganName>[];

  /// The points its [names] are set round, at its real size: it and what
  /// is drawn round it.
  List<Offset> get named => const <Offset>[];

  /// How far along the step on to the tissue its [names] are gone by,
  /// where it is not the organ scene's own share (`OrganScene.leaving`): for
  /// an organ whose step to its tissue is short, so quick that its names
  /// would blink out at that share.
  double? get namesLeaving => null;

  /// The columns at the canvas's edges its [names] are set in instead, by
  /// their keys, each level with what it names: for an organ that stands
  /// tall and narrow, the femur. None where they are set round it.
  Map<String, OrganColumn> get columns => const <String, OrganColumn>{};

  /// Builds what the organ caches for its drawing in [inks] ahead of its
  /// first frame, as its scene's own preparing asks: by default its outline.
  void prepare(ZoomInks inks) => outline;

  /// Draws the organ at [scale] times its real size; [pixel] is one screen
  /// pixel in the scene's units. [detail], from 0 to 1, is how far it has
  /// become the organ from the body's drawing of it: at 0 the flat shape,
  /// lit in the mark, that the body hands over; at 1 the organ sculpted,
  /// with what lies inside it.
  void paint(
    Canvas canvas,
    ZoomInks inks,
    double pixel,
    double scale, {
    double detail = 1,
  });

  static Path _closed(List<Offset> points) {
    final Path path = Path();
    for (int i = 0; i < points.length; i++) {
      if (i == 0) {
        path.moveTo(points[i].dx, points[i].dy);
      } else {
        path.lineTo(points[i].dx, points[i].dy);
      }
    }
    return path..close();
  }

  /// The others of an organ's part beside it (the other lung, the other
  /// kidney), flat as the body drew them, [shown] of the way in.
  static void _flatOthers(
    Canvas canvas,
    Path others,
    ZoomInks inks,
    double line, {
    double shown = 1,
  }) {
    final Color fill = inks.lit(0.16);
    final Color edge = inks.lit(0.36).withValues(alpha: 0.6);
    canvas.drawPath(
      others,
      Paint()..color = fill.withValues(alpha: fill.a * shown),
    );
    canvas.drawPath(
      others,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.9 * line
        ..color = edge.withValues(alpha: edge.a * shown),
    );
  }

  /// A shape sculpted: its shadow on the ground, its body lit from the
  /// upper left, its edge and the light on it, at [detail] of the way from
  /// the flat shape the body drew.
  static void _sculpted(
    Canvas canvas,
    Path shape,
    Rect box,
    ZoomInks inks,
    double line,
    double detail, {
    double light = 0.3,
  }) {
    if (detail > 0) {
      Sculpt.shadowUnder(canvas, box, inks, strength: 0.55 * detail);
    }
    canvas.drawPath(shape, Paint()..color = inks.lit(0.14));
    if (detail > 0) {
      canvas.drawPath(
        shape,
        Paint()..shader = Sculpt.body(box, inks, light: light, opacity: detail),
      );
    }
  }

  static void _edged(
    Canvas canvas,
    Path shape,
    Rect box,
    ZoomInks inks,
    double line,
    double detail,
  ) {
    canvas.drawPath(
      shape,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1 * line
        ..strokeJoin = StrokeJoin.round
        ..color = inks.lit(0.42).withValues(alpha: 0.55 + 0.4 * detail),
    );
    if (detail > 0) {
      Sculpt.rim(
        canvas,
        shape,
        box,
        inks,
        width: 1.8 * line,
        strength: 0.5 * detail,
      );
    }
  }
}

/// The surface an organ's outline is given.
enum _Look { lobules, hollow, fibres, airways, fat, coils }

_Look _lookOf(OrganKind kind) => switch (kind) {
  OrganKind.adipose => _Look.fat,
  OrganKind.lung => _Look.airways,
  OrganKind.intestine ||
  OrganKind.epididymis ||
  OrganKind.seminalVesicle => _Look.coils,
  OrganKind.smoothMuscle || OrganKind.tongue => _Look.fibres,
  OrganKind.bladder ||
  OrganKind.gallbladder ||
  OrganKind.uterus ||
  OrganKind.cervix ||
  OrganKind.vagina => _Look.hollow,
  _ => _Look.lobules,
};

/// Parts of the figure never drawn round an organ: the skin is the figure
/// itself, and fat lies over everything.
const Set<String> _notAround = <String>{'UBERON_0000014', 'UBERON_0001013'};

/// The figure's parts round an organ, faint, as the body drew them: as far
/// out as the view reaches, and a little beyond for the way in. [placed]
/// takes a point of the figure into the organ's scene.
final class _Surroundings {
  _Surroundings(
    AnatomyPart part,
    AnatomyFigure? figure,
    Offset Function(Offset) placed,
  ) {
    if (figure == null) {
      return;
    }
    final Rect reach = Rect.fromCenter(
      center: Offset.zero,
      width: 1.6,
      height: 2.6,
    );
    for (final MapEntry<String, AnatomyPart> other in figure.parts.entries) {
      if (_notAround.contains(other.key) || identical(other.value, part)) {
        continue;
      }
      for (final List<Offset> contour in other.value.contours) {
        final Path path = OrganArt._closed(<Offset>[
          for (final Offset p in contour) placed(p),
        ]);
        if (path.getBounds().overlaps(reach)) {
          _path.addPath(path, Offset.zero);
        }
      }
    }
  }

  final Path _path = Path();

  /// Draws them round an organ whose box is [box], [detail] of the way from
  /// the body's drawing of it to the organ, fading out with their distance
  /// from it once it is its own: the organ in its place, not a map. [fade]
  /// takes them away altogether, for an organ drawn among its own
  /// neighbours.
  void paint(
    Canvas canvas,
    ZoomInks inks,
    double line,
    Rect box,
    double detail, {
    double fade = 1,
  }) {
    if (fade <= 0.002) {
      return;
    }
    final double near = box.longestSide * (1.6 - 0.75 * detail);
    final Rect area = Rect.fromCircle(center: box.center, radius: near);
    Paint around(Color colour, double alpha) =>
        Paint()
          ..shader = RadialGradient(
            colors: <Color>[
              colour.withValues(alpha: alpha),
              colour.withValues(alpha: alpha * 0.5),
              colour.withValues(alpha: 0),
            ],
            stops: const <double>[0, 0.55, 1],
          ).createShader(area);
    canvas.drawPath(
      _path,
      around(inks.lit(0.14), 0.42 * (1 - 0.6 * detail) * fade),
    );
    canvas.drawPath(
      _path,
      around(inks.lit(0.32), 0.45 * (1 - 0.3 * detail) * fade)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8 * line,
    );
  }
}

/// An organ the anatomogram outlines: its own outline, sculpted, the others
/// of its part beside it (the other lung, the other adrenal gland), and the
/// figure's parts round it, faint, as the body drew them.
final class _DrawnOrgan extends OrganArt {
  _DrawnOrgan(
    AnatomyPart part,
    TissueAnatomy anatomy,
    double view, {
    AnatomyFigure? figure,
    CellShape shape = CellShape.epithelial,
    this.level = 1,
  }) : real = anatomy.metres / part.extent,
       _look = _lookOf(anatomy.organ) {
    Offset placed(Offset p) => (p - part.centre) * (real / view);
    _points = <Offset>[for (final Offset p in part.followed) placed(p)];
    // The outline's corners are the simplifying's, not the organ's: drawn
    // as a curve through them.
    _shape = Contour(_points).toPath();
    _site = placed(part.site);
    _others = Path();
    for (final List<Offset> other in part.others) {
      _others.addPath(
        OrganArt._closed(<Offset>[for (final Offset p in other) placed(p)]),
        Offset.zero,
      );
    }
    _box = _shape.getBounds();
    // The body's midline, in the scene: an organ's hilum faces it.
    _midline = placed(Offset(0, part.site.dy)).dx;
    _study = OrganStudy.of(
      anatomy.organ,
      OrganForm(_shape, _points, _site, midline: _midline),
      shape,
    );
    _detail = _surface();
    _around = _Surroundings(part, figure, placed);
  }

  @override
  final double real;

  /// How strongly the body lit the organ: the mark it is handed over in.
  final double level;

  @override
  bool get followsBody => true;

  @override
  Path get outline => _shape;

  final _Look _look;
  late final Offset _site;

  @override
  Offset get site => _site;

  late final Path _shape;
  late final List<Offset> _points;
  late final Path _others;
  late final _Surroundings _around;
  late final Rect _box;
  late final double _midline;
  late final OrganStudy? _study;

  /// What is stroked over the organ, and what is filled darker in it.
  late final (Path, Path) _detail;

  Offset get _middle {
    Offset sum = Offset.zero;
    for (final Offset p in _points) {
      sum += p;
    }
    return sum / _points.length.toDouble();
  }

  Path _inset(double share, {Offset? about, double across = 1}) {
    final Offset c = about ?? _middle;
    final bool tall = _box.height >= _box.width;
    return OrganArt._closed(<Offset>[
      for (final Offset p in _points)
        c +
            Offset(
              (p.dx - c.dx) * share * (tall ? across : 1),
              (p.dy - c.dy) * share * (tall ? 1 : across),
            ),
    ]);
  }

  (Path, Path) _surface() {
    // An organ with a study of its own is drawn by it.
    if (_study != null) {
      return (Path(), Path());
    }
    final math.Random random = math.Random(_look.index + 11);
    final Path lines = Path();
    final Path dark = Path();
    final double size = _box.longestSide;
    final Offset middle = _middle;
    switch (_look) {
      case _Look.lobules || _Look.fat:
        // Lobules, or lobes of fat: a cobble of rounded shapes.
        for (final Rect lobule in Sculpt.cobble(
          _box,
          size * (_look == _Look.fat ? 0.1 : 0.15),
          random,
        )) {
          lines.addOval(lobule);
        }
      case _Look.hollow:
        // A wall round a lumen: drawn in [paint], along the outline.
        break;
      case _Look.fibres:
        // Fibres running the organ's length, gathered at its ends.
        final bool tall = _box.height >= _box.width;
        for (double t = 0.04; t < 1; t += 0.045) {
          if (tall) {
            final double x = _box.left + _box.width * t;
            final double pinch = middle.dx + (x - middle.dx) * 0.5;
            lines
              ..moveTo(pinch, _box.top)
              ..quadraticBezierTo(x, middle.dy, pinch, _box.bottom);
          } else {
            final double y = _box.top + _box.height * t;
            final double pinch = middle.dy + (y - middle.dy) * 0.5;
            lines
              ..moveTo(_box.left, pinch)
              ..quadraticBezierTo(middle.dx, y, _box.right, pinch);
          }
        }
      case _Look.airways:
        // The bronchial tree, in from the hilum on the side of the midline.
        final bool hilumLeft = _midline < _box.center.dx;
        final Offset hilum = Offset(
          hilumLeft
              ? _box.left + _box.width * 0.16
              : _box.right - _box.width * 0.16,
          _box.top + _box.height * 0.4,
        );
        for (final Path generation in Sculpt.tree(
          hilum,
          hilumLeft ? 0.45 : math.pi - 0.45,
          size * 0.2,
          5,
          random,
          spread: 0.5,
          shrink: 0.74,
        )) {
          lines.addPath(generation, Offset.zero);
        }
      case _Look.coils:
        // Loops lying on one another.
        final double step = size * 0.085;
        int row = 0;
        for (double y = _box.top + step / 2; y < _box.bottom; y += step) {
          lines.moveTo(_box.left, y);
          for (double x = _box.left; x <= _box.right; x += size * 0.02) {
            lines.lineTo(
              x,
              y + math.sin(x / (size * 0.027) + row * 1.7) * step * 0.3,
            );
          }
          row++;
        }
    }
    return (lines, dark);
  }

  @override
  void paint(
    Canvas canvas,
    ZoomInks inks,
    double pixel,
    double scale, {
    double detail = 1,
  }) {
    canvas.save();
    canvas.scale(scale);
    final double line = pixel / scale;
    _around.paint(canvas, inks, line, _box, detail);
    OrganArt._flatOthers(canvas, _others, inks, line);
    _study?.behind(canvas, inks, line, detail);
    final bool hollow = _look == _Look.hollow && _study == null;
    OrganArt._sculpted(canvas, _shape, _box, inks, line, detail);
    // The mark the body handed it over in, giving way as it becomes the
    // organ and the gene's place in it comes up.
    final double handed = (1 - detail) * (0.2 + 0.55 * level);
    if (handed > 0.002) {
      canvas.drawPath(_shape, Paint()..color = inks.glow(handed));
    }
    canvas.save();
    canvas.clipPath(_shape);
    if (hollow && detail > 0) {
      // The lumen in shade, and the wall as a lit band inside the outline.
      canvas.drawPath(
        _inset(0.72, across: 0.55),
        Paint()..color = inks.shade(0.45).withValues(alpha: detail),
      );
    }
    if (detail > 0) {
      canvas.drawPath(
        _detail.$2,
        Paint()..color = inks.shade(0.5).withValues(alpha: 0.8 * detail),
      );
      canvas.drawPath(
        _detail.$1,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1 * line
          ..color = inks.lit(0.5).withValues(alpha: 0.22 * detail),
      );
      _study?.inside(canvas, inks, line, detail);
    }
    canvas.restore();
    OrganArt._edged(canvas, _shape, _box, inks, line, detail);
    if (handed > 0.002) {
      canvas.drawPath(
        _shape,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.1 * line
          ..strokeJoin = StrokeJoin.round
          ..color = inks.glow((1 - detail) * (0.5 + 0.5 * level)),
      );
    }
    canvas.restore();
  }
}

/// An organ drawn from general anatomy as a specimen among its own
/// neighbours, reached from the body's own outline of it: at the hand-over
/// that outline, flat and lit in the mark, as `_DrawnOrgan` draws an organ,
/// which then draws in toward the organ's own outline and becomes the bed
/// it lies on, while the figure's parts round it give way to its own
/// neighbours, which come up with it in one layer (`SpecimenStep`); or,
/// for an organ with none of its own ([_amongFigure]), stay round it, faint,
/// as they do round an organ the body's outline draws.
abstract class _SpecimenOrgan extends OrganArt {
  _SpecimenOrgan(
    AnatomyPart part,
    TissueAnatomy anatomy,
    double view, {
    AnatomyFigure? figure,
    this.level = 1,
    double? real,
  }) : real = real ?? anatomy.metres / part.extent {
    Offset placed(Offset p) => (p - part.centre) * (this.real / view);
    _around = _Surroundings(part, figure, placed);
  }

  @override
  final double real;

  /// How strongly the body lit the organ: the mark it is handed over in.
  final double level;

  late final Rect _box = _flatAt(0, 0).getBounds();
  late final _Surroundings _around;

  @override
  bool get followsBody => true;

  /// The flat shape the body hands over, [settle] of the way drawn in from
  /// the body's outline to the organ's own and [bed] of the way on toward
  /// the bed it lies on.
  Path _flatAt(double settle, double bed);

  /// What the bed is drawn in once the specimen is up over it.
  Color _bedOf(ZoomInks inks);

  /// The room a layer of the specimen and its neighbours needs, in [inks].
  Rect _specimenBounds(ZoomInks inks);

  /// Whether the figure's own parts stay round it, faint, as the body drew
  /// them, in place of neighbours of its own.
  bool get _amongFigure => false;

  /// How far the body's outline has been drawn in to the organ's own at
  /// [detail].
  double _settleOf(double detail) => SpecimenStep.settle(detail);

  /// Draws what of the body's drawing of its part lies beside the outline
  /// it follows, over the figure round it, [detail] of the way to the
  /// organ; [line] is a pixel. Nothing, for a part of one outline.
  void _paintBeside(
    Canvas canvas,
    ZoomInks inks,
    double line,
    double detail,
  ) {}

  /// The specimen and its neighbours, at the organ's real size; [line] is a
  /// pixel.
  void _paintSpecimen(Canvas canvas, ZoomInks inks, double line);

  @override
  void paint(
    Canvas canvas,
    ZoomInks inks,
    double pixel,
    double scale, {
    double detail = 1,
  }) {
    canvas.save();
    canvas.scale(scale);
    final double line = pixel / scale;
    // The body's outline drawn in toward the organ's, and the organ coming
    // up over it.
    final double settle = _settleOf(detail);
    final double come = SpecimenStep.come(detail);
    _around.paint(
      canvas,
      inks,
      line,
      _box,
      detail,
      fade: _amongFigure ? 1 : SpecimenStep.figure(detail),
    );
    _paintBeside(canvas, inks, line, detail);
    // The flat shape the body hands over, which becomes the organ's bed:
    // opaque all the while, so nothing shows through as the organ comes
    // up.
    final Path flat = _flatAt(settle, come);
    final Rect box = flat.getBounds();
    final double sculpted = detail * (1 - come);
    if (sculpted > 0) {
      Sculpt.shadowUnder(canvas, box, inks, strength: 0.55 * sculpted);
    }
    canvas.drawPath(
      flat,
      Paint()
        ..color = come <= 0
            ? inks.lit(0.14)
            : Color.lerp(inks.lit(0.14), _bedOf(inks), come)!,
    );
    if (sculpted > 0) {
      canvas.drawPath(
        flat,
        Paint()..shader = Sculpt.body(box, inks, light: 0.3, opacity: sculpted),
      );
    }
    final double handed = (1 - detail) * (0.2 + 0.55 * level);
    if (handed > 0.002) {
      canvas.drawPath(flat, Paint()..color = inks.glow(handed));
    }
    final double edge = 1 - come;
    if (edge > 0.002) {
      canvas.drawPath(
        flat,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.1 * line
          ..strokeJoin = StrokeJoin.round
          ..color = inks
              .lit(0.42)
              .withValues(alpha: (0.55 + 0.4 * detail) * edge),
      );
      if (detail > 0) {
        Sculpt.rim(
          canvas,
          flat,
          box,
          inks,
          width: 1.8 * line,
          strength: 0.5 * detail * edge,
        );
      }
    }
    if (handed > 0.002) {
      canvas.drawPath(
        flat,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.1 * line
          ..strokeJoin = StrokeJoin.round
          ..color = inks.glow((1 - detail) * (0.5 + 0.5 * level)),
      );
    }
    // The organ and its neighbours, in one layer as they come up.
    if (come > 0.002) {
      final bool layered = come < 0.998;
      if (layered) {
        canvas.saveLayer(
          _specimenBounds(inks),
          Paint()..color = Color.fromRGBO(0, 0, 0, come),
        );
      }
      _paintSpecimen(canvas, inks, line);
      if (layered) {
        canvas.restore();
      }
    }
    canvas.restore();
  }
}

/// The pancreas, drawn from general anatomy as a fresh specimen among the
/// organs and vessels round it (`PancreasArt`), reached from the body's own
/// outline of it (`_SpecimenOrgan`): that outline draws in toward the
/// gland's own and becomes the bed its lobules come up on.
final class _PancreasOrgan extends _SpecimenOrgan {
  _PancreasOrgan(
    super.part,
    super.anatomy,
    super.view, {
    super.figure,
    this.cell = CellShape.epithelial,
    super.level,
  }) : _form = PancreasForm.place(part: part, anatomy: anatomy, view: view);

  /// The kind of cell the zoom goes on into, which the gland lights.
  final CellShape cell;

  final PancreasForm _form;

  @override
  Path get outline => _form.outline;

  @override
  Offset get site => _form.site;

  // Where the cell lives, at the place the tissue is sampled: an islet for
  // an endocrine cell, a duct for a duct cell. For any other it is the
  // gland itself, which the card names.
  @override
  late final List<OrganName> names = <OrganName>[
    if (switch (cell) {
          CellShape.endocrine => 'islets',
          CellShape.epithelial => 'ducts',
          _ => null,
        }
        case final String word)
      (key: 'home', word: word, at: _form.site, home: true),
    (
      key: 'duodenum',
      word: 'duodenum',
      at: _form.place(PancreasAnatomy.duodenumName),
      home: false,
    ),
    (
      key: 'spleen',
      word: 'spleen',
      at: _form.place(PancreasAnatomy.spleenName),
      home: false,
    ),
  ];

  // The gland, the spleen, and every tube where it shows, with room to
  // either side: a vessel hanging down beside a name's plate leaves it
  // room, and so does its fading end.
  @override
  late final List<Offset> named = () {
    final double clear = _form.mm(PancreasStyle.nameClear);
    return <Offset>[
      ..._form.outlinePoints,
      ..._form.spleenPoints,
      for (final TubeCourse tube in <TubeCourse>[
        _form.duodenum,
        _form.coeliacTrunk,
        _form.splenicArtery,
        ..._form.hilarBranches,
        _form.hepaticArtery,
        _form.mesentericVein,
        _form.mesentericArtery,
        _form.bileDuct,
      ])
        for (int i = 0; i < tube.length; i++)
          if (tube.shown[i] > PancreasStyle.nameShown) ...<Offset>[
            tube.centres[i] + tube.across[i] * (tube.plus[i] + clear),
            tube.centres[i] - tube.across[i] * (tube.minus[i] + clear),
          ],
    ];
  }();

  PancreasArt? _art;

  PancreasArt _artFor(ZoomInks inks) {
    final PancreasArt? art = _art;
    if (art != null && art.inks == inks) {
      return art;
    }
    return _art = PancreasArt(_form, inks, cell: cell)..prepare();
  }

  @override
  void prepare(ZoomInks inks) => _artFor(inks);

  @override
  Path _flatAt(double settle, double bed) => _form.pathAt(settle, bed: bed);

  @override
  Color _bedOf(ZoomInks inks) => PancreasArt.creviceOf(inks);

  @override
  Rect _specimenBounds(ZoomInks inks) => _artFor(inks).bounds;

  @override
  void _paintSpecimen(Canvas canvas, ZoomInks inks, double line) =>
      _artFor(inks).paint(canvas, line);
}

/// The testis, drawn from general anatomy as a fresh specimen cut down its
/// length, among its epididymis and its cord (`TestisArt`), reached from
/// the body's own outline of it (`_SpecimenOrgan`): that outline draws in
/// toward the testis's own and becomes the bed it lies on.
final class _TestisOrgan extends _SpecimenOrgan {
  _TestisOrgan(
    super.part,
    super.anatomy,
    super.view, {
    super.figure,
    CellShape cell = CellShape.germ,
    super.level,
  }) : home = TestisHome.of(cell),
       _form = TestisForm.place(part: part, anatomy: anatomy, view: view);

  /// Where the kind of cell the zoom goes on into lives, which the testis
  /// lights.
  final TestisHome home;

  final TestisForm _form;

  @override
  Path get outline => _form.outline;

  @override
  Offset get site => _form.site;

  // Where the cell lives, at the place the tissue is sampled, and the main
  // parts round it, no more (the user's choice of 2026-10-19).
  @override
  late final List<OrganName> names = <OrganName>[
    (
      key: 'home',
      word: home == TestisHome.interstitium
          ? 'interstitium'
          : 'seminiferous tubules',
      at: _form.site,
      home: true,
    ),
    (
      key: 'epididymis',
      word: 'epididymis',
      at: _form.place(TestisAnatomy.epididymisName),
      home: false,
    ),
    (
      key: 'rete',
      word: 'rete testis',
      at: _form.place(TestisAnatomy.reteName),
      home: false,
    ),
    (
      key: 'vas',
      word: 'vas deferens',
      at: _form.place(TestisAnatomy.vasName),
      home: false,
    ),
  ];

  // The testis, the epididymis, and the cord's tubes where they show beside
  // them, with room to either side. Above the epididymis's head the cord
  // only fades, and the names may lie beside its end.
  @override
  late final List<Offset> named = () {
    final double clear = _form.mm(TestisStyle.nameClear);
    double top = double.infinity;
    for (final Offset p in <Offset>[
      ..._form.outlinePoints,
      ..._form.epididymisPoints,
    ]) {
      top = math.min(top, p.dy);
    }
    return <Offset>[
      ..._form.outlinePoints,
      ..._form.epididymisPoints,
      for (final TubeCourse tube in <TubeCourse>[
        _form.vas,
        _form.artery,
        ..._form.veins,
      ])
        for (int i = 0; i < tube.length; i++)
          if (tube.shown[i] > TestisStyle.nameShown &&
              tube.centres[i].dy >= top) ...<Offset>[
            tube.centres[i] + tube.across[i] * (tube.plus[i] + clear),
            tube.centres[i] - tube.across[i] * (tube.minus[i] + clear),
          ],
    ];
  }();

  TestisArt? _art;

  TestisArt _artFor(ZoomInks inks) {
    final TestisArt? art = _art;
    if (art != null && art.inks == inks) {
      return art;
    }
    return _art = TestisArt(_form, inks, home: home)..prepare();
  }

  @override
  void prepare(ZoomInks inks) => _artFor(inks);

  @override
  Path _flatAt(double settle, double bed) => _form.pathAt(settle, bed: bed);

  @override
  Color _bedOf(ZoomInks inks) => TestisArt.bedOf(inks);

  @override
  Rect _specimenBounds(ZoomInks inks) => _artFor(inks).bounds;

  @override
  void _paintSpecimen(Canvas canvas, ZoomInks inks, double line) =>
      _artFor(inks).paint(canvas, line);
}

/// The salivary gland, drawn from general anatomy as its parotid in place,
/// seen from the side among the masseter, the ear, the facial nerve and the
/// submandibular gland (`SalivaryArt`), reached from the body's own outline
/// of the parotid (`_SpecimenOrgan`): that outline draws in toward the
/// parotid's own and becomes the bed its lobules come up on.
final class _SalivaryOrgan extends _SpecimenOrgan {
  _SalivaryOrgan(
    super.part,
    super.anatomy,
    super.view, {
    super.figure,
    CellShape cell = CellShape.acinar,
    super.level,
  }) : home = SalivaryHome.of(cell),
       _form = SalivaryForm.place(part: part, anatomy: anatomy, view: view);

  /// Where the kind of cell the zoom goes on into lives, which the gland
  /// lights.
  final SalivaryHome home;

  final SalivaryForm _form;

  @override
  Path get outline => _form.outline;

  @override
  Offset get site => _form.site;

  // Where the cell lives, at the place the tissue is sampled, where it is a
  // part of the gland of its own; and the duct, the facial nerve and the
  // submandibular gland (the user's choice of 2026-10-19).
  @override
  late final List<OrganName> names = <OrganName>[
    if (switch (home) {
          SalivaryHome.acini => 'acini',
          SalivaryHome.ducts => 'ducts',
          SalivaryHome.gland => null,
        }
        case final String word)
      (key: 'home', word: word, at: _form.site, home: true),
    (key: 'duct', word: 'parotid duct', at: _form.ductName, home: false),
    (key: 'nerve', word: 'facial nerve', at: _form.nerveName, home: false),
    (
      key: 'submandibular',
      word: 'submandibular gland',
      at: _form.submandibularName,
      home: false,
    ),
  ];

  // The glands, the masseter and the ear, and every tube where it shows,
  // with room to either side.
  @override
  late final List<Offset> named = () {
    final double clear = _form.mm(SalivaryStyle.nameClear);
    return <Offset>[
      ..._form.outlinePoints,
      ..._form.accessoryPoints,
      ..._form.masseterPoints,
      ..._form.earPoints,
      ..._form.submandibularPoints,
      for (final TubeCourse tube in <TubeCourse>[
        _form.duct,
        ..._form.nerves,
        _form.artery,
        _form.vein,
        _form.arch,
        _form.mandible,
      ])
        for (int i = 0; i < tube.length; i++)
          if (tube.shown[i] > SalivaryStyle.nameShown) ...<Offset>[
            tube.centres[i] + tube.across[i] * (tube.plus[i] + clear),
            tube.centres[i] - tube.across[i] * (tube.minus[i] + clear),
          ],
    ];
  }();

  SalivaryArt? _art;

  SalivaryArt _artFor(ZoomInks inks) {
    final SalivaryArt? art = _art;
    if (art != null && art.inks == inks) {
      return art;
    }
    return _art = SalivaryArt(_form, inks, home: home)..prepare();
  }

  @override
  void prepare(ZoomInks inks) => _artFor(inks);

  @override
  Path _flatAt(double settle, double bed) => _form.pathAt(settle, bed: bed);

  @override
  Color _bedOf(ZoomInks inks) => SalivaryArt.bedOf(inks);

  @override
  Rect _specimenBounds(ZoomInks inks) => _artFor(inks).bounds;

  @override
  void _paintSpecimen(Canvas canvas, ZoomInks inks, double line) =>
      _artFor(inks).paint(canvas, line);
}

/// The bone marrow, drawn from general anatomy as the femur the anatomogram
/// draws for it, cut down its length (`MarrowArt`): its red marrow, where
/// the zoom goes in, flat in the mark among the trabeculae of its upper
/// end; reached from the body's own outline of it (`_SpecimenOrgan`): that
/// outline draws in toward the femur's own and becomes the bed it lies on,
/// the pelvis and the legs staying round it, faint, as the body drew them
/// (the user's ask of 2026-10-21).
final class _MarrowOrgan extends _SpecimenOrgan {
  _MarrowOrgan(
    super.part,
    super.anatomy,
    super.view, {
    super.figure,
    super.level,
  }) : _form = MarrowForm.place(part: part, anatomy: anatomy, view: view);

  final MarrowForm _form;

  @override
  bool get _amongFigure => true;

  @override
  Path get outline => _form.outline;

  @override
  Offset get site => _form.site;

  // Where every cell of the marrow lives, its red marrow, at the place its
  // tissue is sampled; and the bone's parts round it, no more (the user's
  // choice of 2026-10-20).
  @override
  late final List<OrganName> names = <OrganName>[
    (key: 'home', word: 'red marrow', at: _form.site, home: true),
    (
      key: 'trabecular',
      word: 'trabecular bone',
      at: _form.trabecularName,
      home: false,
    ),
    (
      key: 'cortical',
      word: 'cortical bone',
      at: _form.corticalName,
      home: false,
    ),
    (key: 'yellow', word: 'yellow marrow', at: _form.yellowName, home: false),
  ];

  // Each in a column at the canvas's edge, level with what it names (the
  // user's choice of 2026-10-20): the bone's on the left, by its head and
  // its shaft, the marrow's on the right.
  @override
  late final Map<String, OrganColumn> columns = <String, OrganColumn>{
    for (final OrganName name in names)
      name.key: () {
        final (Offset left, Offset right) = _form.edgesAt(name.at);
        return (
          side: name.key == 'trabecular' || name.key == 'cortical' ? -1.0 : 1.0,
          left: left,
          right: right,
        );
      }(),
  };

  MarrowArt? _art;

  MarrowArt _artFor(ZoomInks inks) {
    final MarrowArt? art = _art;
    if (art != null && art.inks == inks) {
      return art;
    }
    return _art = MarrowArt(_form, inks)..prepare();
  }

  @override
  void prepare(ZoomInks inks) => _artFor(inks);

  @override
  Path _flatAt(double settle, double bed) => _form.pathAt(settle, bed: bed);

  @override
  Color _bedOf(ZoomInks inks) => MarrowArt.bedOf(inks);

  @override
  Rect _specimenBounds(ZoomInks inks) => _artFor(inks).bounds;

  @override
  void _paintSpecimen(Canvas canvas, ZoomInks inks, double line) =>
      _artFor(inks).paint(canvas, line);
}

/// The heart, drawn from general anatomy as a specimen cut open from front
/// to back (`HeartArt`): its four chambers, its valves and the great
/// vessels rising from it, its muscle in the mark where the zoom's cell
/// lives there, or its epicardium for an epicardial cell; reached from the
/// body's own outline of it (`_SpecimenOrgan`), grown first to the heart's
/// own size: that outline draws in toward the heart's own and becomes the
/// bed it lies on, the lungs and the rest of the figure staying round it,
/// faint, as the body drew them (the user's choice of 2026-10-22).
final class _HeartOrgan extends _SpecimenOrgan {
  _HeartOrgan(
    super.part,
    super.anatomy,
    super.view, {
    super.figure,
    CellShape cell = CellShape.cardiomyocyte,
    super.level,
  }) : _form = HeartForm.place(part: part, view: view),
       _home = HeartHome.of(cell),
       super(real: HeartForm.realFor(part));

  final HeartForm _form;
  final HeartHome _home;

  @override
  bool get _amongFigure => true;

  // Its outline is drawn in a little more slowly than other specimens':
  // the anatomogram's heart, a sign more than a heart, lies further from it.
  @override
  double _settleOf(double detail) =>
      SpecimenStep.settle(detail, span: HeartStyle.settling);

  @override
  Path get outline => _form.outline;

  @override
  Offset get site => _form.site;

  // Its four chambers, in the quiet ink, and where the zoom's cell lives,
  // in the mark: its muscle, at the place its tissue is sampled, or its
  // epicardium beside it (the user's choice of 2026-10-22). The chambers
  // first, so that where a canvas has no room for all of them in a row,
  // the home is the name that moves.
  @override
  late final List<OrganName> names = <OrganName>[
    (key: 'ra', word: 'right atrium', at: _form.rightAtrium, home: false),
    (key: 'la', word: 'left atrium', at: _form.leftAtrium, home: false),
    (
      key: 'rv',
      word: 'right ventricle',
      at: _form.rightVentricle,
      home: false,
    ),
    (key: 'lv', word: 'left ventricle', at: _form.leftVentricle, home: false),
    switch (_home) {
      HeartHome.myocardium => (
        key: 'home',
        word: 'myocardium',
        at: _form.site,
        home: true,
      ),
      HeartHome.epicardium => (
        key: 'home',
        word: 'epicardium',
        at: _form.epicardiumNear(_form.site),
        home: true,
      ),
    },
  ];

  // Set round all of it, out at the canvas's corners: the heart is too
  // wide for a column of names at either side of it on a phone.
  @override
  late final List<Offset> named = <Offset>[
    for (int i = 0; i < _form.outlinePoints.length; i += 4)
      _form.outlinePoints[i],
  ];

  HeartArt? _art;

  HeartArt _artFor(ZoomInks inks) {
    final HeartArt? art = _art;
    if (art != null && art.inks == inks) {
      return art;
    }
    return _art = HeartArt(_form, inks, home: _home)..prepare();
  }

  @override
  void prepare(ZoomInks inks) => _artFor(inks);

  @override
  Path _flatAt(double settle, double bed) => _form.pathAt(settle, bed: bed);

  @override
  Color _bedOf(ZoomInks inks) => HeartArt.bedOf(inks);

  @override
  Rect _specimenBounds(ZoomInks inks) => _artFor(inks).bounds;

  @override
  void _paintSpecimen(Canvas canvas, ZoomInks inks, double line) =>
      _artFor(inks).paint(canvas, line);
}

/// Skeletal muscle, drawn from general anatomy as the front of the thigh
/// (`ThighArt`): its muscles from the iliac spines to the knee, the vastus
/// lateralis, where human muscle is biopsied and the zoom goes in, flat in
/// the mark; reached from the body's own outline of the vastus lateralis
/// (`_SpecimenOrgan`), the outermost of the five it draws for the thigh:
/// that outline draws in toward the muscle's own and becomes its bed, the
/// body's other four giving way under the muscles as they come up, and the
/// rest of the figure staying round it, faint (the user's choices of
/// 2026-10-22). The figure is drawn at a person's size, so nothing grows.
final class _ThighOrgan extends _SpecimenOrgan {
  _ThighOrgan(
    super.part,
    super.anatomy,
    super.view, {
    required AnatomyFigure super.figure,
    super.level,
  }) : _form = ThighForm.place(part: part, figure: figure, view: view),
       super(real: ThighForm.real);

  final ThighForm _form;

  @override
  bool get _amongFigure => true;

  // Its outline is drawn in more slowly than other specimens': the body's
  // strip widens about three times into the vastus lateralis.
  @override
  double _settleOf(double detail) =>
      SpecimenStep.settle(detail, span: ThighStyle.settling);

  @override
  Path get outline => _form.outline;

  @override
  Offset get site => _form.site;

  // Where the zoom's cell lives, the vastus lateralis, in the mark, and
  // three of the muscles round it in the quiet ink (the user's choice of
  // 2026-10-22), each two words on two lines, to fit a column at the
  // canvas's edge.
  @override
  late final List<OrganName> names = <OrganName>[
    (key: 'home', word: 'vastus\nlateralis', at: _form.site, home: true),
    (
      key: 'rectus',
      word: 'rectus\nfemoris',
      at: _form.rectusName,
      home: false,
    ),
    (
      key: 'sartorius',
      word: 'sartorius',
      at: _form.sartoriusName,
      home: false,
    ),
    (
      key: 'medialis',
      word: 'vastus\nmedialis',
      at: _form.medialisName,
      home: false,
    ),
  ];

  // Each in a column at the canvas's edge, level with what it names (the
  // user's choice of 2026-10-22): the lateral muscles' on the left, the
  // medial ones' on the right.
  @override
  late final Map<String, OrganColumn> columns = <String, OrganColumn>{
    for (final OrganName name in names)
      name.key: () {
        final (Offset left, Offset right) = _form.edgesAt(name.at);
        return (
          side: name.key == 'home' || name.key == 'rectus' ? -1.0 : 1.0,
          left: left,
          right: right,
        );
      }(),
  };

  /// The body's other outlines of the thigh, beside the vastus
  /// lateralis's.
  late final Path _others = () {
    final Path path = Path();
    for (final List<Offset> other in _form.others) {
      path.addPath(OrganArt._closed(other), Offset.zero);
    }
    return path;
  }();

  // They are flat as the body drew them, and give way under the muscles as
  // they come up.
  @override
  void _paintBeside(
    Canvas canvas,
    ZoomInks inks,
    double line,
    double detail,
  ) {
    final double shown = 1 - SpecimenStep.come(detail);
    if (shown > 0.002) {
      OrganArt._flatOthers(canvas, _others, inks, line, shown: shown);
    }
  }

  ThighArt? _art;

  ThighArt _artFor(ZoomInks inks) {
    final ThighArt? art = _art;
    if (art != null && art.inks == inks) {
      return art;
    }
    return _art = ThighArt(_form, inks)..prepare();
  }

  @override
  void prepare(ZoomInks inks) {
    _artFor(inks);
    _others;
  }

  @override
  Path _flatAt(double settle, double bed) => _form.pathAt(settle, bed: bed);

  @override
  Color _bedOf(ZoomInks inks) => ThighArt.bedOf(inks);

  @override
  Rect _specimenBounds(ZoomInks inks) => _artFor(inks).bounds;

  @override
  void _paintSpecimen(Canvas canvas, ZoomInks inks, double line) =>
      _artFor(inks).paint(canvas, line);
}

/// The kidney, drawn from general anatomy as a specimen cut open from front
/// to back (`KidneyArt`): its cortex and its pyramids, its calyces and its
/// pelvis in its sinus, the renal artery and vein cut short past its hilum
/// and the ureter running down; where the zoom's cell lives in the mark, by
/// the Atlas's name for the cell (`KidneyHome`); reached from the body's own
/// outline of it (`_SpecimenOrgan`): that outline draws in toward the
/// kidney's own and becomes the bed it lies on, the other kidney and the
/// rest of the figure staying round it, faint, as the body drew them (the
/// user's choices of 2026-10-23).
final class _KidneyOrgan extends _SpecimenOrgan {
  _KidneyOrgan(
    super.part,
    super.anatomy,
    super.view, {
    super.figure,
    String? cell,
    super.level,
  }) : _form = KidneyForm.place(
         part: part,
         anatomy: anatomy,
         view: view,
         home: KidneyHome.of(cell),
       ),
       _others = _othersOf(part, anatomy.metres / part.extent / view);

  final KidneyForm _form;

  /// The body's other kidney, flat as it drew it, in the scene.
  final Path _others;

  static Path _othersOf(AnatomyPart part, double scale) {
    final Path path = Path();
    for (final List<Offset> other in part.others) {
      path.addPath(
        OrganArt._closed(<Offset>[
          for (final Offset p in other) (p - part.centre) * scale,
        ]),
        Offset.zero,
      );
    }
    return path;
  }

  @override
  bool get _amongFigure => true;

  @override
  Path get outline => _form.outline;

  @override
  Offset get site => _form.site;

  // Where the zoom's cell lives, in the mark, at the place its tissue is
  // sampled (a papilla's at the papilla nearest it); and the cortex, the
  // medulla, the renal pelvis and the ureter in the quiet ink, the cortex
  // only where it is not the cell's home (the user's choice of 2026-10-23).
  @override
  late final List<OrganName> names = <OrganName>[
    (
      key: 'home',
      word: switch (_form.home) {
        KidneyHome.cortex => 'cortex',
        KidneyHome.loops => 'loops of\nHenle',
        KidneyHome.ducts => 'collecting\nducts',
        KidneyHome.papillae => 'papillae',
        KidneyHome.glomeruli => 'glomeruli',
      },
      at: _form.home == KidneyHome.papillae
          ? _form.papillaNear(_form.site)
          : _form.site,
      home: true,
    ),
    if (_form.home != KidneyHome.cortex)
      (key: 'cortex', word: 'cortex', at: _form.cortexName, home: false),
    (key: 'medulla', word: 'medulla', at: _form.medullaName, home: false),
    (key: 'pelvis', word: 'renal\npelvis', at: _form.pelvisName, home: false),
    (key: 'ureter', word: 'ureter', at: _form.ureterName, home: false),
  ];

  // Each in a column at the canvas's edge, level with what it names (the
  // user's choice of 2026-10-23): the parenchyma's on the kidney's lateral
  // side, the pelvis's and the ureter's on the side its hilum faces.
  @override
  late final Map<String, OrganColumn> columns = <String, OrganColumn>{
    for (final OrganName name in names)
      name.key: () {
        final (Offset left, Offset right) = _form.edgesAt(name.at);
        final bool medial = name.key == 'pelvis' || name.key == 'ureter';
        return (
          side: medial ? _form.side : -_form.side,
          left: left,
          right: right,
        );
      }(),
  };

  // The body's other kidney stays as it drew it, flat, as the figure's
  // parts stay round this one.
  @override
  void _paintBeside(
    Canvas canvas,
    ZoomInks inks,
    double line,
    double detail,
  ) => OrganArt._flatOthers(canvas, _others, inks, line);

  KidneyArt? _art;

  KidneyArt _artFor(ZoomInks inks) {
    final KidneyArt? art = _art;
    if (art != null && art.inks == inks) {
      return art;
    }
    return _art = KidneyArt(_form, inks)..prepare();
  }

  @override
  void prepare(ZoomInks inks) => _artFor(inks);

  @override
  Path _flatAt(double settle, double bed) => _form.pathAt(settle, bed: bed);

  @override
  Color _bedOf(ZoomInks inks) => KidneyArt.bedOf(inks, _form.home);

  @override
  Rect _specimenBounds(ZoomInks inks) => _artFor(inks).bounds;

  @override
  void _paintSpecimen(Canvas canvas, ZoomInks inks, double line) =>
      _artFor(inks).paint(canvas, line);
}

/// The liver, drawn from general anatomy as a specimen cut open from front
/// to back (`LiverArt`): its parenchyma, the vena cava and the hepatic
/// veins, the portal veins in their sheaths from the porta, the gallbladder
/// in its fossa; reached from the body's own outline of it
/// (`_SpecimenOrgan`), which draws in toward the liver's own and becomes
/// the bed it lies on, the figure staying round it, faint. Where the
/// zoom's cell lives is in the mark, by the Atlas's name for the cell: its
/// parenchyma, or its bile ducts for a cholangiocyte (the user's choices of
/// 2026-10-23).
final class _LiverOrgan extends _SpecimenOrgan {
  _LiverOrgan(
    super.part,
    super.anatomy,
    super.view, {
    super.figure,
    String? cell,
    super.level,
  }) : _form = LiverForm.place(
         part: part,
         anatomy: anatomy,
         view: view,
         home: LiverHome.of(cell),
       );

  final LiverForm _form;

  @override
  bool get _amongFigure => true;

  // Its outline is drawn in a little more slowly than other specimens'.
  @override
  double _settleOf(double detail) =>
      SpecimenStep.settle(detail, span: LiverStyle.settling);

  @override
  Path get outline => _form.outline;

  @override
  Offset get site => _form.site;

  // Where the zoom's cell lives, in the mark, at the place its tissue is
  // sampled (a bile duct's at the duct nearest it); and the vena cava, the
  // hepatic veins, the portal vein, the gallbladder and the two lobes, in
  // the quiet ink (the user's choices of 2026-10-23). The vena cava's and
  // the lobes' names are set on two lines, so that the three above the
  // liver and the four below it each fit in one row on the narrowest
  // phone's canvas, no line crossing another's plate.
  @override
  late final List<OrganName> names = <OrganName>[
    switch (_form.home) {
      LiverHome.parenchyma => (
        key: 'home',
        word: 'parenchyma',
        at: _form.site,
        home: true,
      ),
      LiverHome.ducts => (
        key: 'home',
        word: 'bile ducts',
        at: _form.ductNear(_form.site),
        home: true,
      ),
    },
    (
      key: 'cava',
      word: 'inferior\nvena cava',
      at: _form.cavaName,
      home: false,
    ),
    (
      key: 'hepatic',
      word: 'hepatic veins',
      at: _form.hepaticVeinsName,
      home: false,
    ),
    (key: 'portal', word: 'portal vein', at: _form.portalVeinName, home: false),
    (
      key: 'gallbladder',
      word: 'gallbladder',
      at: _form.gallbladderName,
      home: false,
    ),
    (key: 'right', word: 'right\nlobe', at: _form.rightLobeName, home: false),
    (key: 'left', word: 'left\nlobe', at: _form.leftLobeName, home: false),
  ];

  // Set round all of it, out at the canvas's corners, as the heart's are:
  // the liver is too wide for a column of names at either side of it on a
  // phone (the user's choice of 2026-10-23). Round the liver, its
  // gallbladder, and what runs on beside it where it shows, with room to
  // either side and past a cut end.
  @override
  late final List<Offset> named = () {
    final double clear = _form.mm(LiverStyle.nameClear);
    return <Offset>[
      for (int i = 0; i < _form.outlinePoints.length; i += 4)
        _form.outlinePoints[i],
      ..._form.gallbladderWall,
      for (final TubeCourse tube in _form.beside)
        for (int i = 0; i < tube.length; i++)
          if ((i % 4 == 0 || i == tube.length - 1) &&
              tube.shown[i] > LiverStyle.nameShown) ...<Offset>[
            tube.centres[i] + tube.across[i] * (tube.plus[i] + clear),
            tube.centres[i] - tube.across[i] * (tube.minus[i] + clear),
            if (i == tube.length - 1)
              tube.centres[i] +
                  Offset(tube.across[i].dy, -tube.across[i].dx) *
                      (tube.radius[i] + clear),
          ],
    ];
  }();

  LiverArt? _art;

  LiverArt _artFor(ZoomInks inks) {
    final LiverArt? art = _art;
    if (art != null && art.inks == inks) {
      return art;
    }
    return _art = LiverArt(_form, inks)..prepare();
  }

  @override
  void prepare(ZoomInks inks) => _artFor(inks);

  @override
  Path _flatAt(double settle, double bed) => _form.pathAt(settle, bed: bed);

  @override
  Color _bedOf(ZoomInks inks) => LiverArt.bedOf(inks, _form.home);

  @override
  Rect _specimenBounds(ZoomInks inks) => _artFor(inks).bounds;

  @override
  void _paintSpecimen(Canvas canvas, ZoomInks inks, double line) =>
      _artFor(inks).paint(canvas, line);
}

/// The thyroid gland, drawn from general anatomy as a specimen seen from
/// the front in place (`ThyroidArt`): over the larynx and the trachea, the
/// carotids and the jugulars at its sides, the lobe the body goes into cut
/// open to show its lobules; reached from the body's own outline of it
/// (`_SpecimenOrgan`), which draws in toward the gland's own and becomes the
/// bed it lies on, the figure staying round it, faint. Where the zoom's cell
/// lives is in the mark, by the Atlas's name for the cell: the cut lobe's
/// parenchyma, its follicles, or its C cells.
final class _ThyroidOrgan extends _SpecimenOrgan {
  _ThyroidOrgan(
    super.part,
    super.anatomy,
    super.view, {
    super.figure,
    String? cell,
    super.level,
  }) : _form = ThyroidForm.place(
         part: part,
         anatomy: anatomy,
         view: view,
         home: ThyroidHome.of(cell),
       );

  final ThyroidForm _form;

  @override
  bool get _amongFigure => true;

  @override
  Path get outline => _form.outline;

  @override
  Offset get site => _form.site;

  // Where the zoom's cell lives, in the mark, at the place its tissue is
  // sampled (the C cells' at the one nearest it); and the isthmus, the
  // larynx, the trachea, a carotid artery and a jugular vein, in the quiet
  // ink.
  @override
  late final List<OrganName> names = <OrganName>[
    (key: 'home', word: _form.home.word, at: _form.homeName, home: true),
    (key: 'larynx', word: 'larynx', at: _form.larynxName, home: false),
    (
      key: 'jugular',
      word: 'jugular vein',
      at: _form.jugularName,
      home: false,
    ),
    (
      key: 'carotid',
      word: 'carotid artery',
      at: _form.carotidName,
      home: false,
    ),
    (key: 'isthmus', word: 'isthmus', at: _form.isthmusName, home: false),
    (key: 'trachea', word: 'trachea', at: _form.tracheaName, home: false),
  ];

  // Set round all of it, out at the canvas's corners, as the liver's are:
  // the gland and the vessels at its sides fill the canvas's width. Round
  // the gland, the larynx, and the vessels and the trachea where they
  // show, with room to either side and past where each ends, cut or faded.
  @override
  late final List<Offset> named = () {
    final double clear = _form.mm(ThyroidStyle.nameClear);
    return <Offset>[
      for (int i = 0; i < _form.outlinePoints.length; i += 4)
        _form.outlinePoints[i],
      ..._form.cartilage,
      for (final TubeCourse tube in _form.beside)
        for (final int last in <int>[
          tube.shown.lastIndexWhere((double s) => s > ThyroidStyle.nameShown),
        ])
          for (int i = 0; i <= last; i++)
            if (i % 4 == 0 || i == last) ...<Offset>[
              tube.centres[i] + tube.across[i] * (tube.plus[i] + clear),
              tube.centres[i] - tube.across[i] * (tube.minus[i] + clear),
              // Round its end.
              if (i == last)
                for (int k = -2; k <= 2; k++)
                  tube.centres[i] +
                      (Offset(tube.across[i].dy, -tube.across[i].dx) *
                                  math.cos(k * math.pi / 6) +
                              tube.across[i] * math.sin(k * math.pi / 6)) *
                          (tube.radius[i] + clear),
            ],
    ];
  }();

  ThyroidArt? _art;

  ThyroidArt _artFor(ZoomInks inks) {
    final ThyroidArt? art = _art;
    if (art != null && art.inks == inks) {
      return art;
    }
    return _art = ThyroidArt(_form, inks)..prepare();
  }

  @override
  void prepare(ZoomInks inks) => _artFor(inks);

  @override
  Path _flatAt(double settle, double bed) => _form.pathAt(settle, bed: bed);

  @override
  Color _bedOf(ZoomInks inks) => ThyroidArt.bedOf(inks, _form.home);

  @override
  Rect _specimenBounds(ZoomInks inks) => _artFor(inks).bounds;

  @override
  void _paintSpecimen(Canvas canvas, ZoomInks inks, double line) =>
      _artFor(inks).paint(canvas, line);
}

/// The adrenal gland, drawn from general anatomy as a specimen cut through
/// the middle of its thickness (`AdrenalArt`), on its kidney's upper pole:
/// the right gland or the left, each of its own shape, its cortex round
/// the medulla in its body, its central vein leaving through its hilum,
/// cut short, its arteries coming in to its edge; reached from the body's
/// own outline of it (`_SpecimenOrgan`), which draws in toward the gland's
/// own and becomes the bed it lies on, the figure staying round it, faint,
/// and the body's kidney under it lit at its pole. Where the zoom's cell
/// lives is in the mark, by the Atlas's name for the cell: its cortex, or
/// its medulla for a chromaffin cell.
final class _AdrenalOrgan extends _SpecimenOrgan {
  _AdrenalOrgan(
    super.part,
    super.anatomy,
    super.view, {
    super.figure,
    String? cell,
    super.level,
  }) : _form = AdrenalForm.place(
         part: part,
         anatomy: anatomy,
         view: view,
         figure: figure,
         home: AdrenalHome.of(cell),
       ),
       _others = _othersOf(part, anatomy.metres / part.extent / view);

  final AdrenalForm _form;

  /// The body's other adrenal, flat as it drew it, in the scene.
  final Path _others;

  // Its outline is drawn in a little more slowly than other specimens'.
  @override
  double _settleOf(double detail) =>
      SpecimenStep.settle(detail, span: AdrenalStyle.settling);

  static Path _othersOf(AnatomyPart part, double scale) {
    final Path path = Path();
    for (final List<Offset> other in part.others) {
      path.addPath(
        OrganArt._closed(<Offset>[
          for (final Offset p in other) (p - part.centre) * scale,
        ]),
        Offset.zero,
      );
    }
    return path;
  }

  @override
  bool get _amongFigure => true;

  @override
  Path get outline => _form.outline;

  @override
  Offset get site => _form.site;

  // Where the zoom's cell lives, in the mark: its cortex at the place its
  // tissue is sampled, or its medulla; and the other, the central vein and
  // the kidney under it, in the quiet ink.
  @override
  late final List<OrganName> names = <OrganName>[
    switch (_form.home) {
      AdrenalHome.cortex => (
        key: 'home',
        word: 'cortex',
        at: _form.cortexName,
        home: true,
      ),
      AdrenalHome.medulla => (
        key: 'home',
        word: 'medulla',
        at: _form.medullaName,
        home: true,
      ),
    },
    switch (_form.home) {
      AdrenalHome.cortex => (
        key: 'medulla',
        word: 'medulla',
        at: _form.medullaName,
        home: false,
      ),
      AdrenalHome.medulla => (
        key: 'cortex',
        word: 'cortex',
        at: _form.cortexName,
        home: false,
      ),
    },
    (key: 'vein', word: 'central vein', at: _form.veinName, home: false),
    if (_form.kidneyName case final Offset at)
      (key: 'kidney', word: 'kidney', at: at, home: false),
  ];

  // Set round all of it, out at the canvas's corners: round the gland, the
  // kidney's pole where it shows and what is drawn beside it, with room to
  // either side and past where each tube ends.
  @override
  late final List<Offset> named = () {
    final double clear = _form.mm(AdrenalStyle.nameClear);
    return <Offset>[
      for (int i = 0; i < _form.outlinePoints.length; i += 4)
        _form.outlinePoints[i],
      for (final Offset p in _form.kidneyPole)
        if (_form.kidneyShownAt(p.dy) > AdrenalStyle.nameShown) p,
      for (final TubeCourse tube in _form.beside)
        for (final int last in <int>[
          tube.shown.lastIndexWhere((double s) => s > AdrenalStyle.nameShown),
        ])
          for (int i = 0; i <= last; i++)
            if (i % 4 == 0 || i == last) ...<Offset>[
              tube.centres[i] + tube.across[i] * (tube.plus[i] + clear),
              tube.centres[i] - tube.across[i] * (tube.minus[i] + clear),
              // Round its end.
              if (i == last)
                for (int k = -2; k <= 2; k++)
                  tube.centres[i] +
                      (Offset(tube.across[i].dy, -tube.across[i].dx) *
                                  math.cos(k * math.pi / 6) +
                              tube.across[i] * math.sin(k * math.pi / 6)) *
                          (tube.radius[i] + clear),
            ],
    ];
  }();

  // The body's other adrenal stays as it drew it, flat, as the figure's
  // parts stay round this one.
  @override
  void _paintBeside(
    Canvas canvas,
    ZoomInks inks,
    double line,
    double detail,
  ) => OrganArt._flatOthers(canvas, _others, inks, line);

  AdrenalArt? _art;

  AdrenalArt _artFor(ZoomInks inks) {
    final AdrenalArt? art = _art;
    if (art != null && art.inks == inks) {
      return art;
    }
    return _art = AdrenalArt(_form, inks)..prepare();
  }

  @override
  void prepare(ZoomInks inks) => _artFor(inks);

  @override
  Path _flatAt(double settle, double bed) => _form.pathAt(settle, bed: bed);

  @override
  Color _bedOf(ZoomInks inks) => AdrenalArt.bedOf(inks, _form.home);

  @override
  Rect _specimenBounds(ZoomInks inks) => _artFor(inks).bounds;

  @override
  void _paintSpecimen(Canvas canvas, ZoomInks inks, double line) =>
      _artFor(inks).paint(canvas, line);
}

/// The pituitary gland, drawn from general anatomy as a specimen cut down
/// its middle as the brain's stop cuts the brain (`PituitaryArt`): its two
/// lobes on the stalk under the hypothalamus and the chiasm, the brain's
/// own, in the sella turcica of the sphenoid bone, cut, the sphenoid sinus
/// under it; reached from the body's own outline of it (`_SpecimenOrgan`),
/// which draws in toward the gland's own and becomes the bed it lies on,
/// while the figure's parts give way to its own neighbours. Where the
/// zoom's cell lives is in the mark, by the Atlas's name for the cell: its
/// anterior lobe, or its posterior lobe for a pituicyte.
final class _PituitaryOrgan extends _SpecimenOrgan {
  _PituitaryOrgan(
    super.part,
    super.anatomy,
    super.view, {
    super.figure,
    String? cell,
    super.level,
  }) : _form = PituitaryForm.place(
         part: part,
         anatomy: anatomy,
         view: view,
         home: PituitaryHome.of(cell),
       );

  final PituitaryForm _form;

  @override
  Path get outline => _form.outline;

  @override
  Offset get site => _form.site;

  // Where the zoom's cell lives, in the mark; and the other lobe, the
  // stalk, the optic chiasm, the hypothalamus and the sphenoid sinus, in
  // the quiet ink.
  @override
  late final List<OrganName> names = <OrganName>[
    (key: 'home', word: _form.home.word, at: _form.homeName, home: true),
    switch (_form.home) {
      PituitaryHome.anterior => (
        key: 'posterior',
        word: 'posterior lobe',
        at: _form.posteriorName,
        home: false,
      ),
      PituitaryHome.posterior => (
        key: 'anterior',
        word: 'anterior lobe',
        at: _form.site,
        home: false,
      ),
    },
    (key: 'stalk', word: 'stalk', at: _form.stalkName, home: false),
    (key: 'chiasm', word: 'optic chiasm', at: _form.chiasmName, home: false),
    (
      key: 'hypothalamus',
      word: 'hypothalamus',
      at: _form.hypothalamusName,
      home: false,
    ),
    (key: 'sinus', word: 'sphenoid sinus', at: _form.sinusName, home: false),
  ];

  // Set round all of it, out at the canvas's corners: round the gland and
  // what is drawn round it where it shows.
  @override
  late final List<Offset> named = <Offset>[
    ..._form.outlinePoints,
    ..._form.drawn,
  ];

  PituitaryArt? _art;

  PituitaryArt _artFor(ZoomInks inks) {
    final PituitaryArt? art = _art;
    if (art != null && art.inks == inks) {
      return art;
    }
    return _art = PituitaryArt(_form, inks)..prepare();
  }

  @override
  void prepare(ZoomInks inks) => _artFor(inks);

  @override
  Path _flatAt(double settle, double bed) => _form.pathAt(settle, bed: bed);

  @override
  Color _bedOf(ZoomInks inks) => PituitaryArt.bedOf(inks, _form.home);

  @override
  Rect _specimenBounds(ZoomInks inks) => _artFor(inks).bounds;

  @override
  void _paintSpecimen(Canvas canvas, ZoomInks inks, double line) =>
      _artFor(inks).paint(canvas, line);
}

/// The fallopian tube, drawn from general anatomy as a specimen opened
/// along its length in place (`FallopianArt`): its lumen and the folds of
/// its mucosa between the wall's cut edges, its fimbriae round the
/// ostium, the mesosalpinx under it; reached from the body's own outline of
/// it (`_SpecimenOrgan`), which draws in toward the tube's own and becomes
/// the bed it lies on, the figure staying round it, faint, its uterus and
/// its ovary by it. The anatomogram draws its tube's arch longer for its
/// box than a tube is, so the tube, and the figure round it, are drawn at
/// a share of the size the body's outline grows to. Where the zoom's cell
/// lives is in the mark, by the Atlas's name for the cell: its mucosa and
/// the fimbriae's inner faces, or its muscular coat for a smooth muscle
/// cell.
final class _FallopianOrgan extends _SpecimenOrgan {
  _FallopianOrgan(
    super.part,
    super.anatomy,
    super.view, {
    super.figure,
    String? cell,
    super.level,
  }) : _form = FallopianForm.place(
         part: part,
         anatomy: anatomy,
         view: view,
         figure: figure,
         home: FallopianHome.of(cell),
       ),
       super(real: FallopianForm.realOf(anatomy, part));

  final FallopianForm _form;

  @override
  bool get _amongFigure => true;

  // Its outline is drawn in a little more slowly than other specimens'.
  @override
  double _settleOf(double detail) =>
      SpecimenStep.settle(detail, span: FallopianStyle.settling);

  @override
  Path get outline => _form.outline;

  @override
  Offset get site => _form.site;

  // Where the zoom's cell lives, in the mark: the mucosa among the
  // ampulla's folds, or the wall at the place its tissue is sampled; and
  // the ampulla, the isthmus, the fimbriae, and the figure's own ovary and
  // uterus by it, in the quiet ink.
  @override
  late final List<OrganName> names = <OrganName>[
    (
      key: 'home',
      word: _form.home.word,
      at: _form.home == FallopianHome.mucosa ? _form.mucosaName : _form.site,
      home: true,
    ),
    (key: 'ampulla', word: 'ampulla', at: _form.ampullaName, home: false),
    (key: 'isthmus', word: 'isthmus', at: _form.isthmusName, home: false),
    (key: 'fimbriae', word: 'fimbriae', at: _form.fimbriaeName, home: false),
    if (_form.ovaryName case final Offset at)
      (key: 'ovary', word: 'ovary', at: at, home: false),
    if (_form.uterusName case final Offset at)
      (key: 'uterus', word: 'uterus', at: at, home: false),
  ];

  // Set round all of it, out at the canvas's corners: round the tube, its
  // fimbriae and its artery, with room to either side and round where each
  // ends. The figure's faint ovary, which a name points into, may lie
  // under a name, as the figure's parts round any organ may.
  @override
  late final List<Offset> named = () {
    final double clear = _form.mm(FallopianStyle.nameClear);
    return <Offset>[
      for (int i = 0; i < _form.outlinePoints.length; i += 4)
        _form.outlinePoints[i],
      for (final TubeCourse tube in _form.beside)
        for (int i = 0; i < tube.length; i++)
          if (i % 4 == 0 || i == tube.length - 1) ...<Offset>[
            tube.centres[i] + tube.across[i] * (tube.plus[i] + clear),
            tube.centres[i] - tube.across[i] * (tube.minus[i] + clear),
            if (i == tube.length - 1)
              for (int k = -2; k <= 2; k++)
                tube.centres[i] +
                    (Offset(tube.across[i].dy, -tube.across[i].dx) *
                                math.cos(k * math.pi / 6) +
                            tube.across[i] * math.sin(k * math.pi / 6)) *
                        (tube.radius[i] + clear),
          ],
    ];
  }();

  FallopianArt? _art;

  FallopianArt _artFor(ZoomInks inks) {
    final FallopianArt? art = _art;
    if (art != null && art.inks == inks) {
      return art;
    }
    return _art = FallopianArt(_form, inks)..prepare();
  }

  @override
  void prepare(ZoomInks inks) => _artFor(inks);

  @override
  Path _flatAt(double settle, double bed) => _form.pathAt(settle, bed: bed);

  @override
  Color _bedOf(ZoomInks inks) => FallopianArt.bedOf(inks, _form.home);

  @override
  Rect _specimenBounds(ZoomInks inks) => _artFor(inks).bounds;

  @override
  void _paintSpecimen(Canvas canvas, ZoomInks inks, double line) =>
      _artFor(inks).paint(canvas, line);
}

/// The stomach, drawn from general anatomy as a specimen opened from the
/// front (`StomachArt`): its front wall cut away, the mucosa of its back
/// wall seen from inside, its rugae running its length, the cut wall's
/// coats round it thickening into the pyloric ring, the esophagus's lining
/// meeting it at the Z-line; the arteries along its curvatures, the
/// esophagus and the duodenum cut short; reached from the body's own
/// outline of it (`_SpecimenOrgan`), which draws in toward the stomach's
/// own and becomes the bed it lies on, the figure staying round it, faint.
/// Where the zoom's cell lives is in the mark, by the Atlas's name for the
/// cell: its mucosa, or its muscularis for a smooth muscle cell (the
/// user's choices of 2026-10-23).
final class _StomachOrgan extends _SpecimenOrgan {
  _StomachOrgan(
    super.part,
    super.anatomy,
    super.view, {
    super.figure,
    String? cell,
    super.level,
  }) : _form = StomachForm.place(
         part: part,
         anatomy: anatomy,
         view: view,
         home: StomachHome.of(cell),
       );

  final StomachForm _form;

  @override
  bool get _amongFigure => true;

  @override
  double _settleOf(double detail) =>
      SpecimenStep.settle(detail, span: StomachStyle.settling);

  @override
  Path get outline => _form.outline;

  @override
  Offset get site => _form.site;

  // Where the zoom's cell lives, in the mark, at the place its tissue is
  // sampled (the muscularis's at the wall nearest it); and its parts round
  // it, what runs on from it and its rugae, in the quiet ink (the user's
  // choices of 2026-10-23).
  @override
  late final List<OrganName> names = <OrganName>[
    switch (_form.home) {
      StomachHome.mucosa => (
        key: 'home',
        word: 'mucosa',
        at: _form.site,
        home: true,
      ),
      StomachHome.muscularis => (
        key: 'home',
        word: 'muscularis',
        at: _form.wallNear(_form.site),
        home: true,
      ),
    },
    (
      key: 'esophagus',
      word: 'esophagus',
      at: _form.esophagusName,
      home: false,
    ),
    (key: 'fundus', word: 'fundus', at: _form.fundusName, home: false),
    (key: 'body', word: 'body', at: _form.bodyName, home: false),
    (key: 'rugae', word: 'rugae', at: _form.rugaeName, home: false),
    (key: 'antrum', word: 'antrum', at: _form.antrumName, home: false),
    (key: 'pylorus', word: 'pylorus', at: _form.pylorusName, home: false),
    (
      key: 'duodenum',
      word: 'duodenum',
      at: _form.duodenumName,
      home: false,
    ),
  ];

  // Set round all of it, out at the canvas's corners, as the liver's are:
  // the stomach is too wide for a column of names at either side of it on
  // a phone (the user's choice of 2026-10-23). Round the stomach and what
  // runs on beside it where it shows, with room to either side and past a
  // cut end.
  @override
  late final List<Offset> named = () {
    final double clear = _form.mm(StomachStyle.nameClear);
    return <Offset>[
      for (int i = 0; i < _form.outlinePoints.length; i += 4)
        _form.outlinePoints[i],
      for (final TubeCourse tube in _form.beside)
        for (int i = 0; i < tube.length; i++)
          if ((i % 4 == 0 || i == tube.length - 1) &&
              tube.shown[i] > StomachStyle.nameShown) ...<Offset>[
            tube.centres[i] + tube.across[i] * (tube.plus[i] + clear),
            tube.centres[i] - tube.across[i] * (tube.minus[i] + clear),
            if (i == tube.length - 1)
              tube.centres[i] +
                  Offset(tube.across[i].dy, -tube.across[i].dx) *
                      (tube.radius[i] + clear),
          ],
    ];
  }();

  StomachArt? _art;

  StomachArt _artFor(ZoomInks inks) {
    final StomachArt? art = _art;
    if (art != null && art.inks == inks) {
      return art;
    }
    return _art = StomachArt(_form, inks)..prepare();
  }

  @override
  void prepare(ZoomInks inks) => _artFor(inks);

  @override
  Path _flatAt(double settle, double bed) => _form.pathAt(settle, bed: bed);

  @override
  Color _bedOf(ZoomInks inks) => StomachArt.bedOf(inks, _form.home);

  @override
  Rect _specimenBounds(ZoomInks inks) => _artFor(inks).bounds;

  @override
  void _paintSpecimen(Canvas canvas, ZoomInks inks, double line) =>
      _artFor(inks).paint(canvas, line);
}

/// The esophagus, drawn from general anatomy as a specimen opened from the
/// front (`EsophagusArt`): its front wall cut away down its length, the
/// lining of its back wall seen from inside, its folds running its length,
/// the cut wall's coats down either side thickening into its two
/// sphincters, its glands in its submucosa, the stomach's mucosa meeting
/// its lining at the Z-line; the pharynx above it and the stomach below,
/// the diaphragm either side of the hiatus and the aorta to its left and
/// behind it, each cut short; reached from the body's own outline of it
/// (`_SpecimenOrgan`), which draws in toward the esophagus's own and becomes
/// the bed it lies on, the figure staying round it, faint. Where the zoom's
/// cell lives is in the mark, by the Atlas's name for the cell: its mucosa,
/// or its glands for a cell of its submucosal glands; its parts, what runs
/// on from it and what it passes are named in the quiet ink, in a column at
/// either edge of the canvas, level with each (the user's choices of
/// 2026-10-23).
final class _EsophagusOrgan extends _SpecimenOrgan {
  _EsophagusOrgan(
    super.part,
    super.anatomy,
    super.view, {
    super.figure,
    String? cell,
    super.level,
  }) : _form = EsophagusForm.place(
         part: part,
         anatomy: anatomy,
         view: view,
         home: EsophagusHome.of(cell),
       );

  final EsophagusForm _form;

  @override
  bool get _amongFigure => true;

  @override
  double _settleOf(double detail) =>
      SpecimenStep.settle(detail, span: EsophagusStyle.settling);

  @override
  Path get outline => _form.outline;

  @override
  Offset get site => _form.site;

  // Where the zoom's cell lives, in the mark, at the place its tissue is
  // sampled (its glands' at the gland nearest it); and, in the quiet ink,
  // its two sphincters, what runs on from it, the Z-line, what it passes
  // and its three parts (the user's choices of 2026-10-23).
  @override
  late final List<OrganName> names = <OrganName>[
    switch (_form.home) {
      EsophagusHome.mucosa => (
        key: 'home',
        word: 'mucosa',
        at: _form.site,
        home: true,
      ),
      EsophagusHome.glands => (
        key: 'home',
        word: 'submucosal glands',
        at: _form.glandNear(_form.site),
        home: true,
      ),
    },
    (key: 'pharynx', word: 'pharynx', at: _form.pharynxName, home: false),
    (
      key: 'upper',
      word: 'upper sphincter',
      at: _form.upperSphincterName,
      home: false,
    ),
    (key: 'cervical', word: 'cervical', at: _form.cervicalName, home: false),
    (key: 'arch', word: 'aortic arch', at: _form.archName, home: false),
    (key: 'thoracic', word: 'thoracic', at: _form.thoracicName, home: false),
    (
      key: 'diaphragm',
      word: 'diaphragm',
      at: _form.diaphragmName,
      home: false,
    ),
    (
      key: 'lower',
      word: 'lower sphincter',
      at: _form.lowerSphincterName,
      home: false,
    ),
    (
      key: 'abdominal',
      word: 'abdominal',
      at: _form.abdominalName,
      home: false,
    ),
    (key: 'zline', word: 'Z-line', at: _form.zLineName, home: false),
    (key: 'stomach', word: 'stomach', at: _form.stomachName, home: false),
  ];

  /// The side of the canvas each name is set on, three of the six round
  /// its lower end on either side, each far enough from the next to be
  /// set level with it on the narrowest phone, and each where nothing
  /// drawn beside it reaches out at its height: the diaphragm's, at its
  /// right half's cut end, and the Z-line's, at its lowest, on the left;
  /// the sphincters', on the body's left wall, the aorta's and the
  /// stomach's on the right.
  static const Map<String, double> _sides = <String, double>{
    'home': -1,
    'pharynx': -1,
    'upper': 1,
    'cervical': -1,
    'arch': 1,
    'thoracic': -1,
    'diaphragm': -1,
    'lower': 1,
    'abdominal': 1,
    'zline': -1,
    'stomach': 1,
  };

  // Each in a column at the canvas's edge, level with what it names, as the
  // kidney's are: the esophagus stands tall and narrow.
  @override
  late final Map<String, OrganColumn> columns = <String, OrganColumn>{
    for (final OrganName name in names)
      name.key: () {
        final (Offset left, Offset right) = _form.edgesAt(name.at);
        return (side: _sides[name.key]!, left: left, right: right);
      }(),
  };

  EsophagusArt? _art;

  EsophagusArt _artFor(ZoomInks inks) {
    final EsophagusArt? art = _art;
    if (art != null && art.inks == inks) {
      return art;
    }
    return _art = EsophagusArt(_form, inks)..prepare();
  }

  @override
  void prepare(ZoomInks inks) => _artFor(inks);

  @override
  Path _flatAt(double settle, double bed) => _form.pathAt(settle, bed: bed);

  @override
  Color _bedOf(ZoomInks inks) => EsophagusArt.bedOf(inks, _form.home);

  @override
  Rect _specimenBounds(ZoomInks inks) => _artFor(inks).bounds;

  @override
  void _paintSpecimen(Canvas canvas, ZoomInks inks, double line) =>
      _artFor(inks).paint(canvas, line);
}

/// The brain cut down its middle, drawn from anatomy as a specimen among
/// its arteries (`BrainArt`): the medial face, the cortex, flat and cut
/// along its sulci, the cut core with the corpus callosum, the third
/// ventricle's walls and the brainstem, the vermis's arbor vitae. For a
/// cell of the cortex the cortex is drawn in the mark; for one of the
/// choroid plexus the lateral ventricle is opened through the septum, the
/// plexus in it in the mark.
/// The body draws the brain from the front, so the step from it is a
/// crossfade, as before.
final class _BrainOrgan extends OrganArt {
  _BrainOrgan(TissueAnatomy anatomy, double view)
    : _home = anatomy.inBrain == _ventricle
          ? BrainHome.plexus
          : BrainHome.cortex,
      _form = BrainForm(length: anatomy.metres / view, view: view);

  static const String _ventricle = 'UBERON_0002285';

  final BrainHome _home;
  final BrainForm _form;

  @override
  late final Offset site = _form.place(
    _home == BrainHome.plexus
        ? BrainAnatomy.plexusSite
        : BrainAnatomy.cortexSite,
  );

  @override
  Path get outline => _form.outline;

  // Where the cell lives, for a cell of the cortex; the plexus the card
  // names. And the main parts, round it.
  @override
  late final List<OrganName> names = <OrganName>[
    if (_home == BrainHome.cortex)
      (key: 'home', word: 'cortex', at: site, home: true),
    (
      key: 'callosum',
      word: 'corpus callosum',
      at: _form.place(BrainAnatomy.callosumName),
      home: false,
    ),
    (
      key: 'thalamus',
      word: 'thalamus',
      at: _form.place(BrainAnatomy.thalamusName),
      home: false,
    ),
    (
      key: 'hypothalamus',
      word: 'hypothalamus',
      at: _form.place(BrainAnatomy.hypothalamusName),
      home: false,
    ),
    (
      key: 'cerebellum',
      word: 'cerebellum',
      at: _form.place(BrainAnatomy.cerebellumName),
      home: false,
    ),
    (
      key: 'brainstem',
      word: 'brainstem',
      at: _form.place(BrainAnatomy.brainstemName),
      home: false,
    ),
  ];

  // The brain, and the arteries of the posterior fossa where they show
  // beyond it, with room to either side.
  @override
  late final List<Offset> named = () {
    final double clear = _form.mm(BrainStyle.nameClear);
    return <Offset>[
      ..._form.outlinePoints,
      for (final TubeCourse tube in _form.fossaArteries)
        for (int i = 0; i < tube.length; i++)
          if (tube.shown[i] > BrainStyle.nameShown) ...<Offset>[
            tube.centres[i] + tube.across[i] * (tube.plus[i] + clear),
            tube.centres[i] - tube.across[i] * (tube.minus[i] + clear),
          ],
    ];
  }();

  BrainArt? _art;

  BrainArt _artFor(ZoomInks inks) {
    final BrainArt? art = _art;
    if (art != null && art.inks == inks) {
      return art;
    }
    return _art = BrainArt(_form, inks, home: _home)..prepare();
  }

  @override
  void prepare(ZoomInks inks) => _artFor(inks);

  @override
  void paint(
    Canvas canvas,
    ZoomInks inks,
    double pixel,
    double scale, {
    double detail = 1,
  }) {
    canvas.save();
    canvas.scale(scale);
    _artFor(inks).paint(canvas, pixel / scale);
    canvas.restore();
  }
}

/// A lymph node, drawn from general anatomy as a specimen cut in two
/// through its hilum (`NodeArt`): its cortex with its follicles, its
/// paracortex and its medulla with its cords, its sinuses, the afferent
/// lymphatics coming in to it and the efferent, the artery and the vein at
/// its hilum. The body has no outline of one node that shows it, so it
/// comes up over the body's drawing of its chain of nodes, as the eye and
/// the skin do. Where the zoom's cell lives is in the mark, by the Atlas's
/// name for the cell: its sinuses, its follicles, its paracortex, its
/// medullary cords or its cortex.
final class _NodeOrgan extends OrganArt {
  _NodeOrgan(TissueAnatomy anatomy, double view, {String? cell})
    : _form = NodeForm(view: view, home: NodeHome.of(cell));

  final NodeForm _form;

  @override
  Offset get site => _form.site;

  @override
  Path get outline => _form.outline;

  // Where the zoom's cell lives, in the mark, at the place its tissue is
  // sampled or in the part it lives in; and the follicles, the paracortex
  // and the medulla, each but the one the home's name stands for, and an
  // afferent lymphatic and the efferent, in the quiet ink.
  @override
  late final List<OrganName> names = <OrganName>[
    (key: 'home', word: _form.home.word, at: _form.homeName, home: true),
    if (_form.home != NodeHome.follicles)
      (
        key: 'follicles',
        word: 'follicles',
        at: _form.folliclesName,
        home: false,
      ),
    if (_form.home != NodeHome.paracortex)
      (
        key: 'paracortex',
        word: 'paracortex',
        at: _form.paracortexName,
        home: false,
      ),
    (key: 'medulla', word: 'medulla', at: _form.medullaName, home: false),
    (
      key: 'afferent',
      word: 'afferent lymphatic',
      at: _form.afferentName,
      home: false,
    ),
    (
      key: 'efferent',
      word: 'efferent lymphatic',
      at: _form.efferentName,
      home: false,
    ),
  ];

  // Set round all of it, out at the canvas's corners: round the node and
  // the vessels coming to it and leaving it where they show, with room to
  // either side and round where each ends.
  @override
  late final List<Offset> named = () {
    final double clear = _form.mm(NodeStyle.nameClear);
    return <Offset>[
      ..._form.outlinePoints,
      for (final TubeCourse tube in _form.beside)
        for (final int last in <int>[
          tube.shown.lastIndexWhere((double s) => s > NodeStyle.nameShown),
        ])
          for (
            int i = tube.shown.indexWhere(
              (double s) => s > NodeStyle.nameShown,
            );
            i <= last;
            i++
          )
            if (i % 4 == 0 || i == last) ...<Offset>[
              tube.centres[i] + tube.across[i] * (tube.plus[i] + clear),
              tube.centres[i] - tube.across[i] * (tube.minus[i] + clear),
              if (i == last)
                for (int k = -2; k <= 2; k++)
                  tube.centres[i] +
                      (Offset(tube.across[i].dy, -tube.across[i].dx) *
                                  math.cos(k * math.pi / 6) +
                              tube.across[i] * math.sin(k * math.pi / 6)) *
                          (tube.radius[i] + clear),
            ],
    ];
  }();

  @override
  double get namesLeaving => NodeStyle.namesLeaving;

  NodeArt? _art;

  NodeArt _artFor(ZoomInks inks) {
    final NodeArt? art = _art;
    if (art != null && art.inks == inks) {
      return art;
    }
    return _art = NodeArt(_form, inks)..prepare();
  }

  @override
  void prepare(ZoomInks inks) => _artFor(inks);

  @override
  void paint(
    Canvas canvas,
    ZoomInks inks,
    double pixel,
    double scale, {
    double detail = 1,
  }) {
    canvas.save();
    canvas.scale(scale);
    _artFor(inks).paint(canvas, pixel / scale);
    canvas.restore();
  }
}

/// A length of artery with a branch: its wall, and the blood in its lumen.
/// The tissue is sampled in the wall.
final class _VesselOrgan extends OrganArt {
  _VesselOrgan(this.size);

  final double size;

  Path _tube(List<Offset> spine, double half) {
    final List<Offset> left = <Offset>[];
    final List<Offset> right = <Offset>[];
    for (int i = 0; i < spine.length; i++) {
      final Offset run =
          spine[math.min(i + 1, spine.length - 1)] - spine[math.max(i - 1, 0)];
      final Offset side = Offset(-run.dy, run.dx) / run.distance * half;
      left.add(spine[i] + side);
      right.add(spine[i] - side);
    }
    return OrganArt._closed(<Offset>[...left, ...right.reversed]);
  }

  @override
  void paint(
    Canvas canvas,
    ZoomInks inks,
    double pixel,
    double scale, {
    double detail = 1,
  }) {
    canvas.save();
    canvas.scale(scale);
    final double line = pixel / scale;
    final double wall = size * 0.115;
    // The upper edge of the wall passes just above the origin.
    final List<Offset> trunk = <Offset>[
      for (int i = 0; i <= 40; i++)
        Offset(
          size * (-1 + 2 * i / 40),
          wall * 0.72 + size * 0.05 * math.sin(i / 40 * math.pi * 1.2 + 0.6),
        ),
    ];
    final Offset fork = trunk[26];
    final List<Offset> branch = <Offset>[
      for (int i = 0; i <= 20; i++)
        fork +
            Offset(
              size * 0.9 * i / 20,
              size * (0.03 * i / 20 + 0.5 * math.pow(i / 20, 1.5)),
            ),
    ];
    final Paint blood = Paint()
      ..color = Color.lerp(inks.blood, inks.ground, 0.35)!;
    for (final (List<Offset> spine, double half) in <(List<Offset>, double)>[
      (branch, wall * 0.62),
      (trunk, wall),
    ]) {
      final Path tube = _tube(spine, half);
      OrganArt._sculpted(canvas, tube, tube.getBounds(), inks, line, 1);
      OrganArt._edged(canvas, tube, tube.getBounds(), inks, line, 1);
    }
    canvas.drawPath(_tube(branch, wall * 0.36), blood);
    canvas.drawPath(_tube(trunk, wall * 0.62), blood);
    canvas.restore();
  }
}

/// A block of the leg's skin, drawn from anatomy as a specimen (`SkinArt`):
/// its top the skin's surface with its furrows, pores and hairs, its front
/// the cut through the epidermis, the dermis and the fat, a follicle with
/// its sebaceous gland and its arrector pili, the sweat glands, the vessels
/// and a nerve, and its right side a second cut. Where the zoom's cell
/// lives, by the name the Atlas gives it, is in the mark, and the layers and
/// what lies in them are named in a column at either edge of the canvas,
/// level with each.
/// The body draws the skin as the figure's own edge, so the step from it
/// is a crossfade, as the brain's and the eye's are.
final class _SkinOrgan extends OrganArt {
  _SkinOrgan(TissueAnatomy anatomy, double view, {String? cell})
    : _home = SkinHome.of(cell),
      _form = SkinForm(width: anatomy.metres / view, view: view);

  final SkinHome _home;
  final SkinForm _form;

  @override
  Offset get site => _form.site;

  @override
  Path get outline => _form.outline;

  // Where the cell lives, named where it lies nearest the site; and the
  // layers and what lies in them (the user's choice of 2026-10-23), each
  // but the one the home's name stands for.
  @override
  late final List<OrganName> names = () {
    final SkinHome home = _home;
    final Offset at = switch (home) {
      SkinHome.melanocytes || SkinHome.basalLayer => _form.basalName,
      SkinHome.epidermis => _form.epidermisSiteName,
      SkinHome.follicle => _form.follicleName,
      SkinHome.sebaceousGland => _form.glandName,
      SkinHome.sweatGland => _form.sweatName,
      SkinHome.dermis => _form.dermisSiteName,
    };
    // In each column from the top down, so that each takes its own level
    // or the step below another's.
    return <OrganName>[
      (key: 'home', word: home.word, at: at, home: true),
      if (home != SkinHome.epidermis)
        (
          key: 'epidermis',
          word: 'epidermis',
          at: _form.epidermisName,
          home: false,
        ),
      if (home != SkinHome.dermis)
        (key: 'dermis', word: 'dermis', at: _form.dermisName, home: false),
      if (home != SkinHome.sebaceousGland)
        (
          key: 'gland',
          word: 'sebaceous\ngland',
          at: _form.glandName,
          home: false,
        ),
      (
        key: 'arrector',
        word: 'arrector\npili',
        at: _form.muscleName,
        home: false,
      ),
      if (home != SkinHome.sweatGland)
        (
          key: 'sweat',
          word: 'sweat\ngland',
          at: _form.sweatName,
          home: false,
        ),
      if (home != SkinHome.follicle)
        (
          key: 'follicle',
          word: 'hair\nfollicle',
          at: _form.follicleName,
          home: false,
        ),
      (key: 'subcutis', word: 'subcutis', at: _form.fatName, home: false),
    ];
  }();

  @override
  List<Offset> get named => _form.outlinePoints;

  @override
  double get namesLeaving => SkinStyle.namesLeaving;

  // The layers on the left, where the home's name points into the
  // epidermis or the dermis near the site, with the sweat gland in the fat;
  // the follicle, its gland and its muscle on the right, where they lie,
  // and the epidermis where the side cuts it.
  @override
  late final Map<String, OrganColumn> columns = <String, OrganColumn>{
    for (final OrganName name in names)
      name.key: () {
        final double side = switch (name.key) {
          'dermis' || 'subcutis' || 'sweat' => -1.0,
          'home' => switch (_home) {
            SkinHome.melanocytes ||
            SkinHome.basalLayer ||
            SkinHome.epidermis ||
            SkinHome.dermis ||
            SkinHome.sweatGland => -1.0,
            _ => 1.0,
          },
          _ => 1.0,
        };
        final (Offset left, Offset right) = _form.edgesAt(
          _form.toMm(name.at).dy,
        );
        return (side: side, left: left, right: right);
      }(),
  };

  SkinArt? _art;

  SkinArt _artFor(ZoomInks inks) {
    final SkinArt? art = _art;
    if (art != null && art.inks == inks) {
      return art;
    }
    return _art = SkinArt(_form, inks, home: _home)..prepare();
  }

  @override
  void prepare(ZoomInks inks) => _artFor(inks);

  @override
  void paint(
    Canvas canvas,
    ZoomInks inks,
    double pixel,
    double scale, {
    double detail = 1,
  }) {
    canvas.save();
    canvas.scale(scale);
    _artFor(inks).paint(canvas, pixel / scale);
    canvas.restore();
  }
}

/// A block cut through a placenta at term in its uterine wall, beside its
/// cord's insertion (`PlacentaArt`): its villi or its decidua in the mark,
/// by the Atlas's name for the cell, its names in a column at either edge
/// of the canvas, level with what each names. It comes up over the body's
/// figure on its own, as the skin's block does.
final class _PlacentaOrgan extends OrganArt {
  _PlacentaOrgan(TissueAnatomy anatomy, double view, {String? cell})
    : _home = PlacentaHome.of(cell),
      _form = PlacentaForm(width: anatomy.metres / view, view: view);

  final PlacentaHome _home;
  final PlacentaForm _form;

  @override
  Offset get site => _form.site;

  @override
  Path get outline => _form.outline;

  // Where the cell lives, in the mark, and the placenta's layers and what
  // runs through them in the quiet ink, from the top down: the villi at the
  // site and the decidua under it, one of them the home.
  @override
  late final List<OrganName> names = <OrganName>[
    for (final PlacentaHome home in PlacentaHome.values)
      if (home == _home)
        (key: 'home', word: home.word, at: _form.nameOf(home), home: true),
    (key: 'cord', word: 'umbilical\ncord', at: _form.cordName, home: false),
    (
      key: 'plate',
      word: 'chorionic\nplate',
      at: _form.plateName,
      home: false,
    ),
    for (final PlacentaHome home in PlacentaHome.values)
      if (home != _home)
        (key: home.name, word: home.word, at: _form.nameOf(home), home: false),
    (
      key: 'space',
      word: 'intervillous\nspace',
      at: _form.spaceName,
      home: false,
    ),
    (
      key: 'spiral',
      word: 'spiral\nartery',
      at: _form.spiralName,
      home: false,
    ),
  ];

  @override
  List<Offset> get named => _form.outlinePoints;

  // The layers by the site on the left, the chorionic plate, the villi and
  // the decidua; the cord, and the right lobule's central cavity and its
  // spiral artery, on the right.
  @override
  late final Map<String, OrganColumn> columns = <String, OrganColumn>{
    for (final OrganName name in names)
      name.key: () {
        final double side = switch (name.key) {
          'cord' || 'space' || 'spiral' => 1.0,
          _ => -1.0,
        };
        final (Offset left, Offset right) = _form.edgesAt(
          _form.toMm(name.at).dy,
        );
        return (side: side, left: left, right: right);
      }(),
  };

  PlacentaArt? _art;

  PlacentaArt _artFor(ZoomInks inks) {
    final PlacentaArt? art = _art;
    if (art != null && art.inks == inks) {
      return art;
    }
    return _art = PlacentaArt(_form, inks, home: _home)..prepare();
  }

  @override
  void prepare(ZoomInks inks) => _artFor(inks);

  @override
  void paint(
    Canvas canvas,
    ZoomInks inks,
    double pixel,
    double scale, {
    double detail = 1,
  }) {
    canvas.save();
    canvas.scale(scale);
    _artFor(inks).paint(canvas, pixel / scale);
    canvas.restore();
  }
}

/// A parathyroid gland: a small oval lying on the back of the thyroid.
final class _ParathyroidOrgan extends OrganArt {
  _ParathyroidOrgan(this.size);

  final double size;

  @override
  void paint(
    Canvas canvas,
    ZoomInks inks,
    double pixel,
    double scale, {
    double detail = 1,
  }) {
    canvas.save();
    canvas.scale(scale);
    final double line = pixel / scale;
    // The thyroid behind it, ten times its size: only its surface shows.
    final Rect thyroid = Rect.fromCircle(
      center: Offset(-size * 2.6, size * 0.6),
      radius: size * 3.1,
    );
    canvas.drawOval(thyroid, Paint()..color = inks.shade(0.7));
    canvas.drawOval(
      thyroid,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2 * line
        ..color = inks.lit(0.3).withValues(alpha: 0.6),
    );
    final Rect gland = Rect.fromCenter(
      center: Offset.zero,
      width: size,
      height: size * 0.68,
    );
    // The artery that feeds it.
    canvas.drawLine(
      Offset(size * 0.3, size * 0.2),
      Offset(size * 1.1, size * 0.8),
      Paint()
        ..strokeWidth = 3 * line
        ..strokeCap = StrokeCap.round
        ..color = Color.lerp(inks.blood, inks.ground, 0.3)!,
    );
    final Path oval = Path()..addOval(gland);
    OrganArt._sculpted(canvas, oval, gland, inks, line, 1);
    canvas.save();
    canvas.clipPath(oval);
    for (final Rect lobule in Sculpt.cobble(
      gland,
      size * 0.15,
      math.Random(5),
    )) {
      Sculpt.dome(canvas, lobule, inks, 0.36);
    }
    canvas.restore();
    OrganArt._edged(canvas, oval, gland, inks, line, 1);
    canvas.restore();
  }
}

/// The right eye cut level through its optic nerve, drawn from anatomy as
/// a specimen among its recti (`EyeArt`), seen from above and turned with
/// its cornea to the left: the retina flat in its one tone, the coats, the
/// cornea, the iris on the lens and the ciliary body lit softly, the optic
/// nerve leaving through the lamina cribrosa in its sheath. For a cell of
/// the retina the retina is drawn in the mark; for a pigment epithelial
/// cell the pigment epithelium under it.
/// The body draws the eye from the front, so the step from it is a
/// crossfade, as the brain's is: the section is drawn about the body's
/// circle of the eye at its size as the step begins, and grows to the
/// eye's own.
final class _EyeOrgan extends OrganArt {
  _EyeOrgan(
    TissueAnatomy anatomy,
    double view, {
    AnatomyPart? part,
    CellShape cell = CellShape.neuron,
  }) : real = part == null ? 1 : anatomy.metres / part.extent,
       _home = EyeHome.of(cell),
       _form = EyeForm(length: anatomy.metres / view, view: view);

  @override
  final double real;

  final EyeHome _home;
  final EyeForm _form;

  @override
  Offset get site => _form.site;

  @override
  Path get outline => _form.outline;

  // Where the cell lives, for a pigment epithelial cell; the retina the
  // card names. And the main parts, no more (the user's choice of
  // 2026-10-19).
  @override
  late final List<OrganName> names = <OrganName>[
    if (_home == EyeHome.pigmentEpithelium)
      (key: 'home', word: 'pigment epithelium', at: site, home: true),
    (key: 'cornea', word: 'cornea', at: _form.corneaName, home: false),
    (key: 'lens', word: 'lens', at: _form.lensName, home: false),
    (key: 'nerve', word: 'optic nerve', at: _form.nerveName, home: false),
  ];

  // The globe, and the nerve's sheath and the recti where they show behind
  // it, with room to either side.
  @override
  late final List<Offset> named = () {
    final double clear = _form.mm(EyeStyle.nameClear);
    return <Offset>[
      ..._form.outlinePoints,
      for (final TubeCourse tube in <TubeCourse>[
        _form.sheath,
        ..._form.recti,
      ])
        for (int i = 0; i < tube.length; i++)
          if (tube.shown[i] > EyeStyle.nameShown) ...<Offset>[
            tube.centres[i] + tube.across[i] * (tube.plus[i] + clear),
            tube.centres[i] - tube.across[i] * (tube.minus[i] + clear),
          ],
    ];
  }();

  EyeArt? _art;

  EyeArt _artFor(ZoomInks inks) {
    final EyeArt? art = _art;
    if (art != null && art.inks == inks) {
      return art;
    }
    return _art = EyeArt(_form, inks, home: _home)..prepare();
  }

  @override
  void prepare(ZoomInks inks) => _artFor(inks);

  @override
  void paint(
    Canvas canvas,
    ZoomInks inks,
    double pixel,
    double scale, {
    double detail = 1,
  }) {
    canvas.save();
    canvas.scale(scale);
    _artFor(inks).paint(canvas, pixel / scale);
    canvas.restore();
  }
}

/// No tissue stands out for the gene: an organ, any.
final class _AnyOrgan extends OrganArt {
  late final Path _shape = () {
    final Path shape = Path();
    const int points = 90;
    for (int i = 0; i <= points; i++) {
      final double a = 2 * math.pi * i / points;
      final double r =
          0.3 +
          0.035 * math.sin(3 * a + 0.4) +
          0.02 * math.sin(5 * a + 1.3) +
          0.012 * math.sin(9 * a);
      final Offset p = Offset(r * math.cos(a) * 1.15, r * math.sin(a) * 0.85);
      if (i == 0) {
        shape.moveTo(p.dx, p.dy);
      } else {
        shape.lineTo(p.dx, p.dy);
      }
    }
    return shape..close();
  }();

  @override
  Path get outline => _shape;

  @override
  void paint(
    Canvas canvas,
    ZoomInks inks,
    double pixel,
    double scale, {
    double detail = 1,
  }) {
    canvas.save();
    canvas.scale(scale);
    final double line = pixel / scale;
    final Rect box = _shape.getBounds();
    OrganArt._sculpted(canvas, _shape, box, inks, line, 1);
    OrganArt._edged(canvas, _shape, box, inks, line, 1);
    canvas.restore();
  }
}
