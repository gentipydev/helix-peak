import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../zoom_inks.dart';
import '../../coloured_mesh.dart';
import '../../cut_face.dart';
import '../../specimen_light.dart';
import '../../tube_course.dart';
import '../../tube_end.dart';
import 'esophagus_form.dart';
import 'esophagus_style.dart';

/// The esophagus opened from the front, drawn as a specimen under the
/// zoom's one lamp: where the zoom's cell lives in the mark (its mucosa
/// flat, as the stomach's is, its folds cut into it as crisp creases, or
/// its glands); else the lining pale, turning up to the cut toward its
/// edges; the cut wall a band down either side of its coats, the submucosa
/// pale with its glands and the muscle warm, thickening into its two
/// sphincters; the stomach's mucosa past the Z-line in the stomach's own
/// deep tone; the aorta passing to its left and behind it, a lit tube in
/// the blood red, the diaphragm either side of the hiatus in a muscle's
/// warm, and the pharynx and the stomach lit tubes in the gut's warm
/// neutral, each cut short.
///
/// Everything costly is built once, for one form and one set of inks:
/// meshes and paths in the scene's units, so a frame only hands them on.
final class EsophagusArt {
  EsophagusArt(this.form, this.inks)
    : _light = SpecimenLight(SpecimenLamp.zoom),
      _palette = SpecimenPalette(inks);

  final EsophagusForm form;
  final ZoomInks inks;
  final SpecimenLight _light;
  final SpecimenPalette _palette;

  EsophagusHome get home => form.home;

  /// Where the zoom's cell lives: one flat tone, the mark over a neutral,
  /// as the stomach's mucosa is.
  static Color homeOf(ZoomInks inks) => Color.alphaBlend(
    inks.glow(EsophagusStyle.homeMark),
    inks.lit(EsophagusStyle.homeLit),
  );

  /// The lining where it faces the eye: what the step from the body draws
  /// the esophagus's bed in, so that the specimen comes up on its own
  /// tone; in the mark where the mucosa is the cell's home.
  static Color bedOf(ZoomInks inks, EsophagusHome home) {
    if (home == EsophagusHome.mucosa) {
      return homeOf(inks);
    }
    final SpecimenLight light = SpecimenLight(SpecimenLamp.zoom);
    return Color(
      SpecimenPalette(inks).colour(
        _liningToneOf(inks),
        light.light(0, 0, 1),
        sheen: light.sheen(0, 0, 1) * EsophagusStyle.cutSheen,
      ),
    );
  }

  static SpecimenTone _liningToneOf(ZoomInks inks) =>
      _warmed(inks, EsophagusStyle.liningLit, EsophagusStyle.liningWarmth);

  /// A tone [lit] of the way to the bright ink, warmed [warmth] of the way
  /// toward the home helix's clay.
  static SpecimenTone _warmed(ZoomInks inks, double lit, double warmth) =>
      SpecimenTone(
        Color.lerp(inks.lit(lit), inks.bases.thymine, warmth)!,
        inks.shadow,
      );

  late final Color _home = homeOf(inks);
  late final SpecimenTone _liningTone = _liningToneOf(inks);
  late final SpecimenTone _gutTone = _warmed(
    inks,
    EsophagusStyle.gutLit,
    EsophagusStyle.gutWarmth,
  );
  late final SpecimenTone _muscleTone = _warmed(
    inks,
    EsophagusStyle.muscleLit,
    EsophagusStyle.muscleWarmth,
  );
  late final SpecimenTone _arteryTone = SpecimenTone(
    Color.lerp(inks.blood, inks.ground, EsophagusStyle.artery)!,
    inks.shadow,
  );

  /// [tone]'s cut face where it faces the eye.
  Color _face(SpecimenTone tone) => Color(
    _palette.colour(
      tone,
      _light.light(0, 0, 1),
      sheen: _light.sheen(0, 0, 1) * EsophagusStyle.cutSheen,
    ),
  );

  late final Color _lining = home == EsophagusHome.mucosa
      ? _home
      : _face(_liningTone);
  late final Color _gastric = _face(
    _warmed(inks, EsophagusStyle.gastricLit, EsophagusStyle.gastricWarmth),
  );
  late final Color _submucosa = _face(
    _warmed(inks, EsophagusStyle.submucosaLit, EsophagusStyle.submucosaWarmth),
  );
  late final Color _muscle = _face(_muscleTone);
  late final Color _fibrous = _face(
    _warmed(inks, EsophagusStyle.fibrousLit, EsophagusStyle.fibrousWarmth),
  );
  late final Color _gland = home == EsophagusHome.glands
      ? _home
      : _face(
          _warmed(inks, EsophagusStyle.glandLit, EsophagusStyle.glandWarmth),
        );

  late final CutFace _faceOf = CutFace(
    _light,
    _palette,
    sheen: EsophagusStyle.cutSheen,
  );

  /// The lining's edges turning up to the cut wall, as the inside of a
  /// gutter turns: toward its middle.
  static const List<(double, double, double)> _rim = <(double, double, double)>[
    (0, -EsophagusStyle.rimOuter, 0),
    (0.5, -EsophagusStyle.rimMiddle, 0),
    (1, 0, 0),
  ];

  static final List<double> _round = <double>[
    for (final double u in EsophagusStyle.tubeColumns.reversed) -u,
    ...EsophagusStyle.tubeColumns.skip(1),
  ];

  // The meshes.

  /// The lining's edges turning up to the cut, where the mucosa is not the
  /// cell's home: there it is one flat tone.
  late final List<ui.Vertices> _rimMesh = _build((ColouredMesh mesh) {
    if (home != EsophagusHome.mucosa) {
      _layRims(mesh);
    }
  });

  void _layRims(ColouredMesh mesh) {
    for (final (List<Offset> edge, List<Offset> inner) in form.rims) {
      _faceOf.lay(mesh, edge, inner, (int _) => _liningTone, _rim);
    }
  }

  /// What runs on beside the esophagus, each a lit tube under it: the
  /// aorta, behind the diaphragm either side of the hiatus, and the
  /// pharynx and the stomach.
  late final List<ui.Vertices> _beside = _build(_layBeside);

  void _layBeside(ColouredMesh mesh) {
    _layTube(mesh, form.aorta, _arteryTone);
    for (final TubeCourse half in form.diaphragm) {
      _layTube(mesh, half, _muscleTone);
    }
    _layTube(mesh, form.pharynx, _gutTone);
    _layTube(mesh, form.stomach, _gutTone);
  }

  void _layTube(ColouredMesh mesh, TubeCourse tube, SpecimenTone tone) =>
      tube.lay(
        mesh,
        tone,
        _light,
        _palette,
        _round,
        brightness: EsophagusStyle.tubeLight,
      );

  late final TubeEnd _end = TubeEnd(
    _palette,
    inks.shadow,
    length: EsophagusStyle.endLength,
    wall: EsophagusStyle.endWall,
  );

  // The paths.

  late final Path _fibrousInner = _polygon(form.fibrousInner);
  late final Path _muscleInner = _polygon(form.muscleInner);
  late final Path _submucosaInner = _polygon(form.submucosaInner);
  late final Path _liningShape = _polygon(form.lining);
  late final Path _gastricShape = _polygon(form.gastric);
  late final Path _zLine = Path()..addPolygon(form.zLine, false);
  late final Path _planes = () {
    final Path path = Path();
    for (final List<Offset> plane in form.planes) {
      path.addPolygon(plane, false);
    }
    return path;
  }();

  static Path _polygon(List<Offset> points) => Path()..addPolygon(points, true);

  // The shadow.

  void _paintShadow(Canvas canvas) {
    canvas.save();
    canvas.translate(
      form.mm(EsophagusStyle.shadowX),
      form.mm(EsophagusStyle.shadowY),
    );
    final Color shadow = inks.shadow;
    canvas.drawPath(
      form.outline,
      Paint()..color = shadow.withValues(alpha: EsophagusStyle.shadowAlpha),
    );
    canvas.drawPath(
      form.outline,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = form.mm(EsophagusStyle.shadowSoft)
        ..strokeJoin = StrokeJoin.round
        ..color = shadow.withValues(alpha: 0.12),
    );
    canvas.restore();
  }

  // Drawing.

  /// What the esophagus and what is drawn beside it cover, its shadow
  /// included: the room a layer of it needs.
  late final Rect bounds = () {
    Rect box = form.box;
    for (final TubeCourse t in form.beside) {
      for (int i = 0; i < t.length; i++) {
        box = box.expandToInclude(
          Rect.fromCircle(center: t.centres[i], radius: t.radius[i]),
        );
      }
    }
    return box.inflate(
      form.mm(EsophagusStyle.shadowY + EsophagusStyle.shadowSoft),
    );
  }();

  /// Builds every mesh and path a frame will draw.
  void prepare() => <Object?>[
    _rimMesh,
    _beside,
    _fibrousInner,
    _muscleInner,
    _submucosaInner,
    _liningShape,
    _gastricShape,
    _zLine,
    _planes,
    form.creases,
    form.glands,
    bounds,
  ];

  /// Draws it all, in the scene's units at the esophagus's real size;
  /// [line] is a pixel.
  void paint(Canvas canvas, double line) {
    _paintShadow(canvas);
    // What runs on beside it, under it, cut short.
    _draw(canvas, _beside);
    for (final TubeCourse half in form.diaphragm) {
      _paintEnd(canvas, half, _muscleTone);
    }
    _paintEnd(canvas, form.aorta, _arteryTone);
    _paintEnd(canvas, form.pharynx, _gutTone);
    _paintEnd(canvas, form.stomach, _gutTone);
    // The cut wall, coat by coat from the fibrous coat in, its glands in
    // its submucosa, and the lining inside it.
    canvas.drawPath(form.outline, Paint()..color = _fibrous);
    canvas.drawPath(_fibrousInner, Paint()..color = _muscle);
    _paintLine(canvas, line, _planes, EsophagusStyle.planeLineAlpha);
    canvas.drawPath(_muscleInner, Paint()..color = _submucosa);
    if (home != EsophagusHome.glands) {
      canvas.save();
      canvas.clipPath(_muscleInner);
      _paintGlands(
        canvas,
        math.max(form.glandRadius, EsophagusStyle.glandLeast * line / 2),
      );
      canvas.restore();
    }
    canvas.drawPath(_submucosaInner, Paint()..color = _lining);
    canvas.drawPath(_liningShape, Paint()..color = _lining);
    canvas.save();
    canvas.clipPath(_liningShape);
    _draw(canvas, _rimMesh);
    _paintFolds(canvas, line);
    canvas.restore();
    // The stomach's mucosa past the Z-line, its own coat in the cut wall
    // with it.
    canvas.save();
    canvas.clipPath(_submucosaInner);
    canvas.drawPath(_gastricShape, Paint()..color = _gastric);
    canvas.drawPath(
      _zLine,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(
          form.mm(EsophagusStyle.zLine),
          EsophagusStyle.zLineFloor * line,
        )
        ..strokeJoin = StrokeJoin.round
        ..color = inks.shadow.withValues(alpha: EsophagusStyle.zLineAlpha),
    );
    canvas.restore();
    // Its glands where they are the cell's home, in the mark, never too
    // small to be seen.
    if (home == EsophagusHome.glands) {
      _paintGlands(
        canvas,
        math.max(form.glandRadius, EsophagusStyle.glandFloor * line / 2),
      );
    }
    // The lining's edges, where the cut meets it, and the outline's, as
    // the other specimens' outlines are edged.
    _paintLine(canvas, line, _liningShape, EsophagusStyle.coatLineAlpha);
    canvas.drawPath(
      form.outline,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = line
        ..strokeJoin = StrokeJoin.round
        ..color = inks
            .lit(EsophagusStyle.edgeLit)
            .withValues(alpha: EsophagusStyle.edgeAlpha),
    );
  }

  void _paintEnd(Canvas canvas, TubeCourse tube, SpecimenTone tone) =>
      _end.paint(
        canvas,
        tube,
        tone,
        _light.light(0, 0, 1) * EsophagusStyle.tubeLight,
      );

  /// A fine line along [path] in the shadow ink at [alpha], never thinner
  /// than a pixel or so.
  void _paintLine(Canvas canvas, double line, Path path, double alpha) =>
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(
            form.mm(EsophagusStyle.coatLine),
            EsophagusStyle.coatLineFloor * line,
          )
          ..strokeJoin = StrokeJoin.round
          ..color = inks.shadow.withValues(alpha: alpha),
      );

  void _paintGlands(Canvas canvas, double radius) {
    final Paint paint = Paint()..color = _gland;
    for (final Offset gland in form.glands) {
      canvas.drawCircle(gland, radius, paint);
    }
  }

  /// The folds: the light on each fold's far side, toward the lamp, and
  /// the crease along it, never thinner than a pixel or so.
  void _paintFolds(Canvas canvas, double line) {
    canvas.save();
    final Offset toward = _light.screen * form.mm(EsophagusStyle.ridge);
    canvas.translate(toward.dx, toward.dy);
    canvas.drawPath(
      form.creases,
      Paint()
        ..color = inks
            .lit(EsophagusStyle.ridgeLit)
            .withValues(alpha: EsophagusStyle.ridgeAlpha),
    );
    canvas.restore();
    final Color cleft = inks.shadow.withValues(
      alpha: EsophagusStyle.creaseAlpha,
    );
    canvas.drawPath(form.creases, Paint()..color = cleft);
    final double floor = EsophagusStyle.creaseFloor * line;
    if (form.mm(EsophagusStyle.crease) < floor) {
      canvas.drawPath(
        form.creases,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = floor - form.mm(EsophagusStyle.crease)
          ..strokeJoin = StrokeJoin.round
          ..color = cleft,
      );
    }
  }

  /// Every mesh's vertices as built, for tests, each tagged with the part
  /// it draws: where each lies, in the scene's units, and its colour.
  @visibleForTesting
  List<(String, Float32List, Int32List)> get meshData {
    final List<(String, Float32List, Int32List)> out =
        <(String, Float32List, Int32List)>[];
    void add(String part, void Function(ColouredMesh) lay) {
      final ColouredMesh mesh = ColouredMesh(keep: true);
      lay(mesh);
      mesh.build();
      for (final ({Float32List positions, Int32List colours}) kept
          in mesh.kept) {
        out.add((part, kept.positions, kept.colours));
      }
    }

    if (home != EsophagusHome.mucosa) {
      add('lining', _layRims);
    }
    add(
      'aorta',
      (ColouredMesh mesh) => _layTube(mesh, form.aorta, _arteryTone),
    );
    add('diaphragm', (ColouredMesh mesh) {
      for (final TubeCourse half in form.diaphragm) {
        _layTube(mesh, half, _muscleTone);
      }
    });
    add(
      'pharynx',
      (ColouredMesh mesh) => _layTube(mesh, form.pharynx, _gutTone),
    );
    add(
      'stomach',
      (ColouredMesh mesh) => _layTube(mesh, form.stomach, _gutTone),
    );
    return out;
  }

  /// The colours the cut wall's coats, the lining, the stomach's mucosa and
  /// the glands are filled in, by name. For tests.
  @visibleForTesting
  Map<String, Color> get fills => <String, Color>{
    'fibrous': _fibrous,
    'muscularis': _muscle,
    'submucosa': _submucosa,
    'lining': _lining,
    'gastric': _gastric,
    'glands': _gland,
  };

  static List<ui.Vertices> _build(void Function(ColouredMesh) lay) {
    final ColouredMesh mesh = ColouredMesh();
    lay(mesh);
    return mesh.build();
  }

  static final Paint _meshPaint = Paint();

  static void _draw(Canvas canvas, List<ui.Vertices> meshes) {
    for (final ui.Vertices vertices in meshes) {
      canvas.drawVertices(vertices, BlendMode.dst, _meshPaint);
    }
  }
}
