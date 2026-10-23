import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/anatomy_figure.dart';
import '../../domain/anatomy_tables.dart';
import '../../domain/cell_archetypes.dart';
import '../../domain/zoom_depth.dart';
import '../zoom_inks.dart';
import 'contour.dart';
import 'organ_studies.dart';
import 'organs/bone_marrow/marrow_art.dart';
import 'organs/bone_marrow/marrow_form.dart';
import 'organs/brain/brain_anatomy.dart';
import 'organs/brain/brain_art.dart';
import 'organs/brain/brain_form.dart';
import 'organs/brain/brain_style.dart';
import 'organs/eye/eye_art.dart';
import 'organs/eye/eye_form.dart';
import 'organs/eye/eye_style.dart';
import 'organs/heart/heart_art.dart';
import 'organs/heart/heart_form.dart';
import 'organs/heart/heart_style.dart';
import 'organs/kidney/kidney_art.dart';
import 'organs/kidney/kidney_form.dart';
import 'organs/pancreas/pancreas_anatomy.dart';
import 'organs/pancreas/pancreas_art.dart';
import 'organs/pancreas/pancreas_form.dart';
import 'organs/pancreas/pancreas_style.dart';
import 'organs/salivary_gland/salivary_art.dart';
import 'organs/salivary_gland/salivary_form.dart';
import 'organs/salivary_gland/salivary_style.dart';
import 'organs/skeletal_muscle/thigh_art.dart';
import 'organs/skeletal_muscle/thigh_form.dart';
import 'organs/skeletal_muscle/thigh_style.dart';
import 'organs/testis/testis_anatomy.dart';
import 'organs/testis/testis_art.dart';
import 'organs/testis/testis_form.dart';
import 'organs/testis/testis_style.dart';
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
/// muscle, the front of the thigh, and the kidney, cut open from front to
/// back.
///
/// Where the gene is, the organ glows in the mark: the part of it the
/// zoom's cell lives in (the islets of a pancreas for an endocrine cell, its
/// ducts for a duct cell, the interstitium of a testis for a Leydig cell,
/// the loops of Henle of a kidney for a cell the Atlas names theirs), by
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
      OrganKind.lymphNode => _NodeOrgan(size, shape),
      OrganKind.vessel => _VesselOrgan(size),
      OrganKind.skin => _SkinOrgan(size),
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

  static Offset _unit(double angle) => Offset(math.cos(angle), math.sin(angle));

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
  OrganKind.stomach ||
  OrganKind.bladder ||
  OrganKind.gallbladder ||
  OrganKind.uterus ||
  OrganKind.cervix ||
  OrganKind.vagina ||
  OrganKind.fallopianTube ||
  OrganKind.esophagus => _Look.hollow,
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

/// A lymph node: a bean in its capsule, follicles round its cortex, the
/// cords of its medulla at the hilum, vessels in and out. The tissue is
/// sampled under the capsule, at the top. Where the zoom's cell lives is in
/// the mark: the sinuses lymph runs through, lined by endothelium, for an
/// endothelial cell; the follicles for a white cell.
final class _NodeOrgan extends OrganArt {
  _NodeOrgan(this.size, this.cell);

  /// How long the node is, in the scene's units.
  final double size;
  final CellShape cell;

  Offset get _centre => Offset.zero;

  @override
  Offset get site => Offset(0, -size * 0.34);

  @override
  Path get outline => OrganArt._closed(_bean);

  late final List<Offset> _bean = <Offset>[
    for (int i = 0; i < 96; i++)
      () {
        final double a = 2 * math.pi * i / 96;
        // Drawn in at the hilum, below.
        final double from = math.atan2(
          math.sin(a - math.pi / 2),
          math.cos(a - math.pi / 2),
        );
        final double r = 1 - 0.26 * math.exp(-from * from / 0.16);
        return _centre +
            Offset(math.cos(a) * size * 0.5 * r, math.sin(a) * size * 0.4 * r);
      }(),
  ];

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
    final Path bean = OrganArt._closed(_bean);
    final Rect box = bean.getBounds();
    final Paint vessel = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2 * line
      ..strokeCap = StrokeCap.round
      ..color = inks.lit(0.42).withValues(alpha: 0.7);
    // Lymph comes in through the capsule all round, and leaves at the hilum.
    for (final double a in <double>[-2.6, -2.0, -1.2, -0.5, 0.3, 3.4]) {
      final Offset at =
          _centre + Offset(math.cos(a) * size * 0.5, math.sin(a) * size * 0.4);
      canvas.drawLine(at, at + OrganArt._unit(a) * (size * 0.16), vessel);
    }
    canvas.drawLine(
      _centre + Offset(0, size * 0.28),
      _centre + Offset(size * 0.04, size * 0.52),
      vessel..strokeWidth = 3.4 * line,
    );
    OrganArt._sculpted(canvas, bean, box, inks, line, 1);
    canvas.save();
    canvas.clipPath(bean);
    // The medulla, darker, and its cords.
    canvas.drawOval(
      Rect.fromCenter(
        center: _centre + Offset(0, size * 0.14),
        width: size * 0.5,
        height: size * 0.36,
      ),
      Paint()..color = inks.shade(0.55),
    );
    final Paint cord = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1 * line
      ..color = inks.lit(0.5).withValues(alpha: 0.3);
    for (int k = 0; k < 7; k++) {
      final double a = math.pi * (1.15 + 0.12 * k);
      final Offset from = _centre + Offset(0, size * 0.24);
      final Offset to =
          _centre +
          Offset(math.cos(a) * size * 0.22, math.sin(a) * size * 0.16);
      canvas.drawLine(from, to, cord);
    }
    // Follicles in the cortex, each with its pale centre.
    final bool white = cell == CellShape.leukocyte;
    for (int k = 0; k < 9; k++) {
      final double a = math.pi * (0.92 + 0.145 * k);
      final Offset at =
          _centre +
          Offset(math.cos(a) * size * 0.37, math.sin(a) * size * 0.28);
      Sculpt.dome(
        canvas,
        Rect.fromCircle(center: at, radius: size * 0.062),
        inks,
        0.4,
      );
      canvas.drawCircle(
        at,
        size * 0.03,
        Paint()
          ..color = white
              ? inks.glow(0.8)
              : inks.lit(0.45).withValues(alpha: 0.6),
      );
    }
    if (cell == CellShape.endothelial) {
      // The subcapsular sinus under the capsule, and the medullary sinuses
      // between the cords, down to the hilum.
      Sculpt.glowingStroke(
        canvas,
        OrganArt._closed(<Offset>[
          for (final Offset p in _bean) _centre + (p - _centre) * 0.92,
        ]),
        inks,
        width: 1.6 * line,
      );
      final Path sinuses = Path();
      for (int k = 0; k < 6; k++) {
        final double a = math.pi * (1.21 + 0.12 * k);
        final Offset from = _centre + Offset(0, size * 0.27);
        final Offset to =
            _centre +
            Offset(math.cos(a) * size * 0.4, math.sin(a) * size * 0.3);
        sinuses
          ..moveTo(from.dx, from.dy)
          ..lineTo(to.dx, to.dy);
      }
      Sculpt.glowingStroke(canvas, sinuses, inks, width: 1.1 * line);
    }
    canvas.restore();
    OrganArt._edged(canvas, bean, box, inks, line, 1);
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

/// A block cut from the skin: its surface with its creases and hairs, and
/// on the cut face the epidermis, the dermis and the fat beneath. The
/// tissue is sampled at the top of the cut face.
final class _SkinOrgan extends OrganArt {
  _SkinOrgan(this.size);

  final double size;

  // The block's middle is at the origin; it is drawn about the place it is
  // sampled.
  @override
  Offset get site => Offset(-size * 0.04, -size * 0.13);

  // The block as it is drawn: its cut face, and the top and side seen behind
  // it, about the place it is sampled.
  @override
  Path get outline => _outline;

  late final Path _outline = () {
    final double s = size;
    final Rect face = Rect.fromLTRB(-s * 0.45, -s * 0.03, s * 0.55, s * 0.6);
    final Offset back = Offset(-s * 0.22, -s * 0.34);
    return OrganArt._closed(<Offset>[
      face.bottomLeft + back,
      face.topLeft + back,
      face.topRight + back,
      face.topRight,
      face.bottomRight,
      face.bottomLeft,
    ]).shift(site);
  }();

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
    canvas.translate(site.dx, site.dy);
    final double line = pixel / scale;
    final double s = size;
    // The cut face, its top edge just above the origin.
    final Rect face = Rect.fromLTRB(-s * 0.45, -s * 0.03, s * 0.55, s * 0.6);
    final Offset back = Offset(-s * 0.22, -s * 0.34);
    final Path top = OrganArt._closed(<Offset>[
      face.topLeft,
      face.topRight,
      face.topRight + back,
      face.topLeft + back,
    ]);
    final Path side = OrganArt._closed(<Offset>[
      face.topLeft,
      face.topLeft + back,
      face.bottomLeft + back,
      face.bottomLeft,
    ]);
    Sculpt.shadowUnder(canvas, face.inflate(s * 0.05), inks);
    canvas.drawPath(side, Paint()..color = inks.shade(0.62));
    canvas.drawPath(top, Paint()..color = inks.lit(0.32));
    // Creases across the surface, and hairs out of it.
    final Paint fine = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1 * line
      ..color = inks.lit(0.55).withValues(alpha: 0.4);
    for (int k = 1; k < 7; k++) {
      final Offset from = Offset.lerp(face.topLeft, face.topRight, k / 7)!;
      canvas.drawLine(from, from + back, fine);
    }
    for (final double t in <double>[0.18, 0.44, 0.7, 0.9]) {
      final Offset root =
          Offset.lerp(face.topLeft, face.topRight, t)! + back * 0.5;
      canvas.drawLine(
        root,
        root + Offset(-s * 0.05, -s * 0.2),
        Paint()
          ..strokeWidth = 1.6 * line
          ..strokeCap = StrokeCap.round
          ..color = inks.lit(0.5),
      );
    }
    // The layers.
    final double epidermis = face.top + s * 0.035;
    final double dermis = face.top + s * 0.25;
    canvas.drawRect(face, Paint()..color = inks.lit(0.2));
    canvas.drawRect(
      Rect.fromLTRB(face.left, dermis, face.right, face.bottom),
      Paint()..color = inks.shade(0.82),
    );
    final Path wavy = Path()..moveTo(face.left, face.top);
    for (int i = 0; i <= 60; i++) {
      wavy.lineTo(
        face.left + face.width * i / 60,
        epidermis + s * 0.012 * math.sin(i * 0.9),
      );
    }
    wavy
      ..lineTo(face.right, face.top)
      ..close();
    canvas.drawPath(wavy, Paint()..color = inks.lit(0.36));
    canvas.save();
    canvas.clipRect(Rect.fromLTRB(face.left, dermis, face.right, face.bottom));
    final double lobe = s * 0.085;
    int row = 0;
    for (
      double y = dermis + lobe * 0.3;
      y < face.bottom + lobe;
      y += lobe * 0.9
    ) {
      for (
        double x = face.left + (row.isOdd ? lobe / 2 : 0);
        x < face.right + lobe;
        x += lobe
      ) {
        Sculpt.dome(
          canvas,
          Rect.fromCircle(center: Offset(x, y), radius: lobe * 0.46),
          inks,
          0.3,
        );
      }
      row++;
    }
    canvas.restore();
    final Paint rim = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2 * line
      ..strokeJoin = StrokeJoin.round
      ..color = inks.lit(0.45);
    canvas.drawRect(face, rim);
    canvas.drawPath(top, rim);
    canvas.drawPath(side, rim);
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
