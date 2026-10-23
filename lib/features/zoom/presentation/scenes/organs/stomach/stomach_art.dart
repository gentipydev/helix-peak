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
import 'stomach_form.dart';
import 'stomach_style.dart';

/// The stomach opened from the front, drawn as a specimen under the zoom's
/// one lamp: where the zoom's cell lives in the mark (its mucosa flat, as
/// the liver's parenchyma is, the rugae cut into it as crisp creases, or
/// its muscularis); else the mucosa a deep warm surface, turning up to the
/// cut toward its edge; the cut wall a band of its coats round it, the
/// submucosa pale and the muscle warm, thickening into the pyloric ring;
/// the esophagus's lining pale above the Z-line; the arteries along its
/// curvatures lit tubes in the blood red, their small branches running in
/// under its wall, and the esophagus and the duodenum lit tubes in its own
/// warm neutral, each cut short.
///
/// Everything costly is built once, for one form and one set of inks:
/// meshes and paths in the scene's units, so a frame only hands them on.
final class StomachArt {
  StomachArt(this.form, this.inks)
    : _light = SpecimenLight(SpecimenLamp.zoom),
      _palette = SpecimenPalette(inks);

  final StomachForm form;
  final ZoomInks inks;
  final SpecimenLight _light;
  final SpecimenPalette _palette;

  StomachHome get home => form.home;

  /// Where the zoom's cell lives: one flat tone, the mark over a neutral,
  /// as the liver's parenchyma is.
  static Color homeOf(ZoomInks inks) => Color.alphaBlend(
    inks.glow(StomachStyle.homeMark),
    inks.lit(StomachStyle.homeLit),
  );

  /// The mucosa where it faces the eye: what the step from the body draws
  /// the stomach's bed in, so that the specimen comes up on its own tone;
  /// in the mark where the mucosa is the cell's home.
  static Color bedOf(ZoomInks inks, StomachHome home) {
    if (home == StomachHome.mucosa) {
      return homeOf(inks);
    }
    final SpecimenLight light = SpecimenLight(SpecimenLamp.zoom);
    return Color(
      SpecimenPalette(inks).colour(
        _mucosaToneOf(inks),
        light.light(0, 0, 1),
        sheen: light.sheen(0, 0, 1) * StomachStyle.cutSheen,
      ),
    );
  }

  static SpecimenTone _mucosaToneOf(ZoomInks inks) =>
      _warmed(inks, StomachStyle.mucosaLit, StomachStyle.mucosaWarmth);

  /// A tone [lit] of the way to the bright ink, warmed [warmth] of the way
  /// toward the home helix's clay.
  static SpecimenTone _warmed(ZoomInks inks, double lit, double warmth) =>
      SpecimenTone(
        Color.lerp(inks.lit(lit), inks.bases.thymine, warmth)!,
        inks.shadow,
      );

  late final Color _home = homeOf(inks);
  late final SpecimenTone _mucosaTone = _mucosaToneOf(inks);
  late final SpecimenTone _gutTone = _warmed(
    inks,
    StomachStyle.gutLit,
    StomachStyle.gutWarmth,
  );
  late final SpecimenTone _arteryTone = SpecimenTone(
    Color.lerp(inks.blood, inks.ground, StomachStyle.artery)!,
    inks.shadow,
  );

  /// [tone]'s cut face where it faces the eye.
  Color _face(SpecimenTone tone) => Color(
    _palette.colour(
      tone,
      _light.light(0, 0, 1),
      sheen: _light.sheen(0, 0, 1) * StomachStyle.cutSheen,
    ),
  );

  late final Color _mucosa = home == StomachHome.mucosa
      ? _home
      : _face(_mucosaTone);
  late final Color _submucosa = _face(
    _warmed(inks, StomachStyle.submucosaLit, StomachStyle.submucosaWarmth),
  );
  late final Color _muscle = home == StomachHome.muscularis
      ? _home
      : _face(_warmed(inks, StomachStyle.muscleLit, StomachStyle.muscleWarmth));
  late final Color _serosa = _face(
    _warmed(inks, StomachStyle.serosaLit, StomachStyle.serosaWarmth),
  );
  late final Color _lining = _face(
    _warmed(inks, StomachStyle.liningLit, StomachStyle.liningWarmth),
  );

  late final CutFace _faceOf = CutFace(
    _light,
    _palette,
    sheen: StomachStyle.cutSheen,
  );

  /// The mucosa's edge turning up to the cut wall, as the inside of a bowl
  /// turns: toward the stomach's middle.
  static const List<(double, double, double)> _rim = <(double, double, double)>[
    (0, -StomachStyle.rimOuter, 0),
    (0.5, -StomachStyle.rimMiddle, 0),
    (1, 0, 0),
  ];

  static final List<double> _round = <double>[
    for (final double u in StomachStyle.tubeColumns.reversed) -u,
    ...StomachStyle.tubeColumns.skip(1),
  ];

  // The meshes.

  /// The mucosa's edge turning up to the cut, where the mucosa is not the
  /// cell's home: there it is one flat tone.
  late final List<ui.Vertices> _rimMesh = _build((ColouredMesh mesh) {
    if (home != StomachHome.mucosa) {
      _layRim(mesh);
    }
  });

  void _layRim(ColouredMesh mesh) => _faceOf.lay(
    mesh,
    <Offset>[...form.inner, form.inner.first],
    <Offset>[...form.rimInner, form.rimInner.first],
    (int _) => _mucosaTone,
    _rim,
  );

  /// What runs on beside the stomach, each a lit tube under it: the small
  /// branches into its wall, the arteries along its curvatures, the
  /// esophagus and the duodenum.
  late final List<ui.Vertices> _beside = _build(_layBeside);

  void _layBeside(ColouredMesh mesh) {
    for (final TubeCourse branch in form.branches) {
      _layTube(mesh, branch, _arteryTone);
    }
    for (final TubeCourse artery in form.arteries) {
      _layTube(mesh, artery, _arteryTone);
    }
    _layTube(mesh, form.esophagus, _gutTone);
    _layTube(mesh, form.duodenum, _gutTone);
  }

  void _layTube(ColouredMesh mesh, TubeCourse tube, SpecimenTone tone) =>
      tube.lay(
        mesh,
        tone,
        _light,
        _palette,
        _round,
        brightness: StomachStyle.tubeLight,
      );

  late final TubeEnd _end = TubeEnd(
    _palette,
    inks.shadow,
    length: StomachStyle.endLength,
    wall: StomachStyle.endWall,
  );

  // The paths.

  late final Path _serosaInner = _polygon(form.coats[0]);
  late final Path _muscleInner = _polygon(form.coats[1]);
  late final Path _submucosaInner = _polygon(form.coats[2]);
  late final Path _surface = _polygon(form.inner);
  late final Path _liningShape = _polygon(form.lining);
  late final Path _zLine = Path()..addPolygon(form.zLine, false);
  late final Path _muscleMiddle = () {
    final Path path = Path();
    for (final List<Offset> run in form.muscleMiddle) {
      path.addPolygon(run, false);
    }
    return path;
  }();

  static Path _polygon(List<Offset> points) => Path()..addPolygon(points, true);

  // The shadow.

  void _paintShadow(Canvas canvas) {
    canvas.save();
    canvas.translate(
      form.mm(StomachStyle.shadowX),
      form.mm(StomachStyle.shadowY),
    );
    final Color shadow = inks.shadow;
    canvas.drawPath(
      form.outline,
      Paint()..color = shadow.withValues(alpha: StomachStyle.shadowAlpha),
    );
    canvas.drawPath(
      form.outline,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = form.mm(StomachStyle.shadowSoft)
        ..strokeJoin = StrokeJoin.round
        ..color = shadow.withValues(alpha: 0.12),
    );
    canvas.restore();
  }

  // Drawing.

  /// What the stomach and what is drawn beside it cover, its shadow
  /// included: the room a layer of it needs.
  late final Rect bounds = () {
    Rect box = form.box;
    for (final TubeCourse t in <TubeCourse>[...form.beside, ...form.branches]) {
      for (int i = 0; i < t.length; i++) {
        box = box.expandToInclude(
          Rect.fromCircle(center: t.centres[i], radius: t.radius[i]),
        );
      }
    }
    return box.inflate(form.mm(StomachStyle.shadowY + StomachStyle.shadowSoft));
  }();

  /// Builds every mesh and path a frame will draw.
  void prepare() => <Object?>[
    _rimMesh,
    _beside,
    _serosaInner,
    _muscleInner,
    _submucosaInner,
    _surface,
    _liningShape,
    _zLine,
    _muscleMiddle,
    form.creases,
    form.liningCreases,
    bounds,
  ];

  /// Draws it all, in the scene's units at the stomach's real size; [line]
  /// is a pixel.
  void paint(Canvas canvas, double line) {
    _paintShadow(canvas);
    // What runs on beside it, under it, cut short.
    _draw(canvas, _beside);
    for (final TubeCourse artery in form.arteries) {
      _paintEnd(canvas, artery, _arteryTone);
    }
    _paintEnd(canvas, form.esophagus, _gutTone);
    _paintEnd(canvas, form.duodenum, _gutTone);
    // The cut wall, coat by coat from the serosa in, and the mucosa inside
    // it.
    canvas.drawPath(form.outline, Paint()..color = _serosa);
    canvas.drawPath(_serosaInner, Paint()..color = _muscle);
    if (home == StomachHome.muscularis) {
      canvas.drawPath(
        _muscleMiddle,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = StomachStyle.muscleFloor * line
          ..strokeJoin = StrokeJoin.round
          ..color = _muscle,
      );
    }
    canvas.drawPath(_muscleInner, Paint()..color = _submucosa);
    canvas.drawPath(_submucosaInner, Paint()..color = _mucosa);
    canvas.drawPath(_surface, Paint()..color = _mucosa);
    canvas.save();
    canvas.clipPath(_surface);
    _draw(canvas, _rimMesh);
    _paintRugae(canvas, line);
    canvas.restore();
    // The esophagus's lining above the Z-line, its own mucosa in the cut
    // wall with it, its folds in it.
    canvas.save();
    canvas.clipPath(_submucosaInner);
    canvas.drawPath(_liningShape, Paint()..color = _lining);
    _paintCreases(
      canvas,
      line,
      form.liningCreases,
      StomachStyle.liningCreaseAlpha,
    );
    canvas.drawPath(
      _zLine,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(
          form.mm(StomachStyle.zLine),
          StomachStyle.zLineFloor * line,
        )
        ..strokeJoin = StrokeJoin.round
        ..color = inks.shadow.withValues(alpha: StomachStyle.zLineAlpha),
    );
    canvas.restore();
    // The mucosa's edge, where the cut meets it, and the serosa's, as the
    // other specimens' outlines are edged.
    canvas.drawPath(
      _surface,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(
          form.mm(StomachStyle.coatLine),
          StomachStyle.coatLineFloor * line,
        )
        ..strokeJoin = StrokeJoin.round
        ..color = inks.shadow.withValues(alpha: StomachStyle.coatLineAlpha),
    );
    canvas.drawPath(
      form.outline,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = line
        ..strokeJoin = StrokeJoin.round
        ..color = inks
            .lit(StomachStyle.edgeLit)
            .withValues(alpha: StomachStyle.edgeAlpha),
    );
  }

  void _paintEnd(Canvas canvas, TubeCourse tube, SpecimenTone tone) =>
      _end.paint(
        canvas,
        tube,
        tone,
        _light.light(0, 0, 1) * StomachStyle.tubeLight,
      );

  /// The rugae: the light on each fold's far side, toward the lamp, and
  /// the crease along it.
  void _paintRugae(Canvas canvas, double line) {
    canvas.save();
    final Offset toward = _light.screen * form.mm(StomachStyle.ridge);
    canvas.translate(toward.dx, toward.dy);
    canvas.drawPath(
      form.creases,
      Paint()
        ..color = inks
            .lit(StomachStyle.ridgeLit)
            .withValues(alpha: StomachStyle.ridgeAlpha),
    );
    canvas.restore();
    _paintCreases(canvas, line, form.creases, StomachStyle.creaseAlpha);
  }

  /// [creases] in the shadow ink at [alpha], never thinner than a pixel or
  /// so.
  void _paintCreases(Canvas canvas, double line, Path creases, double alpha) {
    final Color cleft = inks.shadow.withValues(alpha: alpha);
    canvas.drawPath(creases, Paint()..color = cleft);
    final double floor = StomachStyle.creaseFloor * line;
    if (form.mm(StomachStyle.crease) < floor) {
      canvas.drawPath(
        creases,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = floor - form.mm(StomachStyle.crease)
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

    if (home != StomachHome.mucosa) {
      add('mucosa', _layRim);
    }
    add('branches', (ColouredMesh mesh) {
      for (final TubeCourse branch in form.branches) {
        _layTube(mesh, branch, _arteryTone);
      }
    });
    add('arteries', (ColouredMesh mesh) {
      for (final TubeCourse artery in form.arteries) {
        _layTube(mesh, artery, _arteryTone);
      }
    });
    add(
      'esophagus',
      (ColouredMesh mesh) => _layTube(mesh, form.esophagus, _gutTone),
    );
    add(
      'duodenum',
      (ColouredMesh mesh) => _layTube(mesh, form.duodenum, _gutTone),
    );
    return out;
  }

  /// The colours the cut wall's coats, the mucosa and the esophagus's
  /// lining are filled in, by name. For tests.
  @visibleForTesting
  Map<String, Color> get fills => <String, Color>{
    'serosa': _serosa,
    'muscularis': _muscle,
    'submucosa': _submucosa,
    'mucosa': _mucosa,
    'lining': _lining,
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
