import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../zoom_inks.dart';
import '../../coloured_mesh.dart';
import '../../specimen_light.dart';
import '../../tube_course.dart';
import 'placenta_anatomy.dart';
import 'placenta_form.dart';
import 'placenta_style.dart';

/// A block of a placenta in its uterine wall drawn as a specimen under the
/// zoom's one lamp: its top the fetal surface, a lit cool grey under the
/// amnion, the chorionic vessels lit tubes over it, the arteries over the
/// veins, and the cord rising from it, pale, its arteries' grooves winding
/// round it, cut across to show its vein and its two arteries; its front a
/// flat cut, the chorionic plate pale under the amnion's edge, the villi in
/// a pale warm grey among the intervillous space's maternal blood, eased
/// toward the ground, the septa, the basal plate and the decidua a warm
/// neutral, the spiral arteries and the veins in the blood red, the
/// uterine muscle warmed toward the clay, its bundles faint; its right
/// side a second cut, in shade.
///
/// Where the zoom's cell lives is one flat tone in the mark, by the name
/// the Atlas gives the cell and never by gene (`PlacentaHome`).
///
/// Everything costly is built once, for one form, one home and one set of
/// inks.
final class PlacentaArt {
  PlacentaArt(this.form, this.inks, {required this.home})
    : _light = SpecimenLight(SpecimenLamp.zoom),
      _palette = SpecimenPalette(inks);

  final PlacentaForm form;
  final ZoomInks inks;
  final PlacentaHome home;
  final SpecimenLight _light;
  final SpecimenPalette _palette;

  /// Where the zoom's cell lives: one flat tone, the mark over a neutral.
  late final Color homeTone = Color.alphaBlend(
    inks.glow(PlacentaStyle.homeMark),
    inks.lit(PlacentaStyle.homeLit),
  );

  /// A tone [lit] of the way toward the bright ink, warmed [warmth] of the
  /// way toward the home helix's clay.
  SpecimenTone _warmed(double lit, double warmth) => SpecimenTone(
    Color.lerp(inks.lit(lit), inks.bases.thymine, warmth)!,
    inks.shadow,
  );

  /// A tone [lit] of the way toward the bright ink, cooled [cool] of the
  /// way toward the home helix's denim.
  SpecimenTone _cooled(double lit, double cool) => SpecimenTone(
    Color.lerp(inks.lit(lit), inks.bases.cytosine, cool)!,
    inks.shadow,
  );

  /// [tone] on a face turned as [facing] is, lit by the lamp.
  Color _on(SpecimenTone tone, (double, double, double) facing) {
    final (double x, double y, double z) = facing;
    final double length = math.sqrt(x * x + y * y + z * z);
    final double nx = x / length;
    final double ny = y / length;
    final double nz = z / length;
    return Color(
      _palette.colour(
        tone,
        _light.light(nx, ny, nz, form: nz),
        sheen: _light.sheen(nx, ny, nz) * PlacentaStyle.cutSheen,
      ),
    );
  }

  Color _front(SpecimenTone tone) => _on(tone, PlacentaStyle.front);
  Color _sideOf(SpecimenTone tone) => _on(tone, PlacentaStyle.side);

  late final SpecimenTone _villousTone = _warmed(
    PlacentaStyle.villousLit,
    PlacentaStyle.villousWarmth,
  );
  late final SpecimenTone _deciduaTone = _warmed(
    PlacentaStyle.deciduaLit,
    PlacentaStyle.deciduaWarmth,
  );
  late final SpecimenTone _muscleTone = _warmed(
    PlacentaStyle.muscleLit,
    PlacentaStyle.muscleWarmth,
  );
  late final SpecimenTone _plateTone = _warmed(
    PlacentaStyle.plateLit,
    PlacentaStyle.plateWarmth,
  );
  late final SpecimenTone _spaceTone = SpecimenTone(_space, inks.shadow);
  late final SpecimenTone _jellyTone = _cooled(
    PlacentaStyle.jellyLit,
    PlacentaStyle.jellyCool,
  );
  late final SpecimenTone _arteryTone = SpecimenTone(_artery, inks.shadow);
  late final SpecimenTone _veinTone = SpecimenTone(_vein, inks.shadow);

  late final Color _space = Color.lerp(
    inks.blood,
    inks.ground,
    PlacentaStyle.space,
  )!;
  late final Color _artery = Color.lerp(
    inks.blood,
    inks.ground,
    PlacentaStyle.artery,
  )!;
  late final Color _vein = Color.lerp(
    inks.blood,
    inks.ground,
    PlacentaStyle.vein,
  )!;

  late final Color _plate = _front(_plateTone);
  late final Color _amnion = inks.lit(PlacentaStyle.amnionLit);
  late final Color _villi = home == PlacentaHome.villi
      ? homeTone
      : _front(_villousTone);
  late final Color _decidua = home == PlacentaHome.decidua
      ? homeTone
      : _front(_deciduaTone);
  late final Color _muscle = _front(_muscleTone);
  late final Color _surface = _on(
    _cooled(PlacentaStyle.surfaceLit, PlacentaStyle.surfaceCool),
    PlacentaStyle.top,
  );
  late final Color _jellyEnd = _on(_jellyTone, PlacentaStyle.top);
  late final Color _jellyFoot = _on(_jellyTone, PlacentaStyle.side);
  late final Color _arteryWall = _on(
    _warmed(PlacentaStyle.muscleLit + 0.18, PlacentaStyle.muscleWarmth),
    PlacentaStyle.top,
  );

  late final Color _sidePlate = _sideOf(_plateTone);
  late final Color _sideSpace = _sideOf(_spaceTone);
  late final Color _sideVilli = home == PlacentaHome.villi
      ? homeTone
      : _sideOf(_villousTone);
  late final Color _sideDecidua = home == PlacentaHome.decidua
      ? homeTone
      : _sideOf(_deciduaTone);
  late final Color _sideMuscle = _sideOf(_muscleTone);

  static final List<double> _round = <double>[
    for (final double u in PlacentaStyle.tubeColumns.reversed) -u,
    ...PlacentaStyle.tubeColumns.skip(1),
  ];

  // The meshes.

  late final List<ui.Vertices> _veinMesh = _build(_layVeins);
  late final List<ui.Vertices> _arteryMesh = _build(_layArteries);
  late final List<ui.Vertices> _cordMesh = _build(_layCord);

  void _layVeins(ColouredMesh mesh) {
    for (final TubeCourse t in form.chorionicVeins) {
      _layTube(mesh, t, _veinTone, PlacentaStyle.tubeLight);
    }
  }

  void _layArteries(ColouredMesh mesh) {
    for (final TubeCourse t in form.chorionicArteries) {
      _layTube(mesh, t, _arteryTone, PlacentaStyle.tubeLight);
    }
  }

  void _layCord(ColouredMesh mesh) =>
      _layTube(mesh, form.cord, _jellyTone, PlacentaStyle.cordLight);

  void _layTube(
    ColouredMesh mesh,
    TubeCourse tube,
    SpecimenTone tone,
    double brightness,
  ) => tube.lay(mesh, tone, _light, _palette, _round, brightness: brightness);

  // Paths built once.

  late final Path _fibrePath = _lines(form.fibres);
  late final Path _layerPath = _lines(form.layerLines);
  late final Path _spiralPath = _lines(form.spirals);
  late final Path _septaPath = () {
    final Path path = Path();
    for (final List<Offset> s in form.septaPoints) {
      path.addPolygon(s, true);
    }
    return path;
  }();
  late final List<Path> _cordWalls = form.cordVessels(1);
  late final List<Path> _cordLumens = <Path>[
    form.cordVessels(0.78).first,
    ...form.cordVessels(0.32).skip(1),
  ];

  // Drawing.

  /// What the block covers, its cord and its shadow included: the room a
  /// layer of it needs.
  late final Rect bounds = form.outline.getBounds().inflate(
    form.mm(PlacentaStyle.shadowY + PlacentaStyle.shadowSoft),
  );

  /// Builds every mesh and path a frame will draw.
  void prepare() => <Object?>[
    _veinMesh,
    _arteryMesh,
    _cordMesh,
    _fibrePath,
    _layerPath,
    _spiralPath,
    _septaPath,
    _cordWalls,
    _cordLumens,
    form.stems,
    form.clumps,
    form.sideClumps,
    form.veins,
    form.funnels,
    form.sinuses,
    bounds,
  ];

  /// Draws it all, in the scene's units at the placenta's real size; [line]
  /// is a pixel.
  void paint(Canvas canvas, double line) {
    _paintShadow(canvas);
    _paintSide(canvas, line);
    _paintTop(canvas, line);
    _paintCord(canvas, line);
    canvas.save();
    canvas.clipPath(form.front);
    _paintFront(canvas, line);
    canvas.restore();
    _paintEdges(canvas, line);
  }

  void _paintShadow(Canvas canvas) {
    canvas.save();
    canvas.translate(
      form.mm(PlacentaStyle.shadowX),
      form.mm(PlacentaStyle.shadowY),
    );
    final Color shadow = inks.shadow;
    canvas.drawPath(
      form.outline,
      Paint()..color = shadow.withValues(alpha: PlacentaStyle.shadowAlpha),
    );
    canvas.drawPath(
      form.outline,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = form.mm(PlacentaStyle.shadowSoft)
        ..strokeJoin = StrokeJoin.round
        ..color = shadow.withValues(alpha: 0.12),
    );
    canvas.restore();
  }

  void _paintSide(Canvas canvas, double line) {
    canvas.drawPath(form.sidePlate, Paint()..color = _sidePlate);
    canvas.drawPath(form.sideSpace, Paint()..color = _sideSpace);
    canvas.save();
    canvas.clipPath(form.sideSpace);
    _clumps(canvas, form.sideClumps, _sideVilli, line);
    canvas.restore();
    canvas.drawPath(form.sideDecidua, Paint()..color = _sideDecidua);
    canvas.drawPath(form.sideMuscle, Paint()..color = _sideMuscle);
  }

  void _paintTop(Canvas canvas, double line) {
    canvas.drawPath(form.top, Paint()..color = _surface);
    canvas.save();
    canvas.clipPath(form.top);
    // The arteries over the veins, as Gray has them.
    _draw(canvas, _veinMesh);
    _draw(canvas, _arteryMesh);
    canvas.restore();
  }

  void _paintCord(Canvas canvas, double line) {
    canvas.drawPath(form.cordFoot, Paint()..color = _jellyFoot);
    _draw(canvas, _cordMesh);
    // Its arteries winding round its vein, seen through its jelly, fainter
    // where they pass behind.
    canvas.save();
    canvas.clipPath(form.cordOutline);
    final double width = form.mm(PlacentaAnatomy.cordArtery * 0.9);
    for (final List<(Offset, Offset, double)> run in form.cordWindings) {
      for (final (Offset a, Offset b, double near) in run) {
        canvas.drawLine(
          a,
          b,
          Paint()
            ..strokeWidth = width
            ..color = _artery.withValues(
              alpha:
                  PlacentaStyle.windingAlpha *
                  (near >= 0 ? 1 : PlacentaStyle.windingBehind),
            ),
        );
      }
    }
    canvas.restore();
    canvas.drawPath(form.cordEnd, Paint()..color = _jellyEnd);
    // Its vein, a thin wall round a wide lumen, and its arteries, thick
    // walls round narrow ones.
    canvas.drawPath(_cordWalls.first, Paint()..color = _arteryWall);
    canvas.drawPath(_cordLumens.first, Paint()..color = _vein);
    for (final Path wall in _cordWalls.skip(1)) {
      canvas.drawPath(wall, Paint()..color = _arteryWall);
    }
    for (final Path lumen in _cordLumens.skip(1)) {
      canvas.drawPath(lumen, Paint()..color = _artery);
    }
    canvas.drawPath(
      form.cordEnd,
      _stroke(
        inks.lit(PlacentaStyle.edgeLit).withValues(alpha: 0.5),
        line * 0.8,
      ),
    );
  }

  void _paintFront(Canvas canvas, double line) {
    // The intervillous space, its villi, and the septa between its lobules.
    canvas.drawPath(form.space, Paint()..color = _space);
    canvas.drawPath(form.stems, Paint()..color = _villi);
    _clumps(canvas, form.clumps, _villi, line);
    final Paint decidua = Paint()..color = _decidua;
    canvas.drawPath(_septaPath, decidua);
    // The chorionic plate under the amnion's edge, and the vessels cut in
    // it.
    canvas.drawPath(form.plate, Paint()..color = _plate);
    for (final (Offset c, double r, bool vein) in form.cutVessels) {
      canvas.drawCircle(
        c,
        math.max(r, PlacentaStyle.vesselFloor * line / 2),
        Paint()..color = vein ? _vein : _artery,
      );
    }
    canvas.drawPath(
      _lines(<List<Offset>>[form.amnion]),
      _stroke(
        _amnion,
        math.max(form.mm(0.2), PlacentaStyle.amnionFloor * line),
      ),
    );
    // The basal plate, the decidua under it and the uterine muscle.
    canvas.drawPath(form.basal, decidua);
    canvas.drawPath(form.decidua, decidua);
    canvas.drawPath(form.myometrium, Paint()..color = _muscle);
    canvas.save();
    canvas.clipPath(form.myometrium);
    canvas.drawPath(
      _fibrePath,
      _stroke(
        inks.shadow.withValues(alpha: PlacentaStyle.fibreAlpha),
        math.max(form.mm(0.12), 0.8 * line),
      ),
    );
    canvas.restore();
    final Paint layer = _stroke(
      inks.shadow.withValues(alpha: PlacentaStyle.layerAlpha),
      PlacentaStyle.layerFloor * line,
    );
    canvas.drawPath(_layerPath, layer);
    // The veins leaving at the lobules' edges and those cut in the muscle;
    // the spiral arteries coiling up into their funnels.
    final Paint vein = Paint()..color = _vein;
    for (final Path v in form.veins) {
      canvas.drawPath(v, vein);
    }
    for (final Path s in form.sinuses) {
      canvas.drawPath(s, vein);
    }
    canvas.drawPath(
      _spiralPath,
      _stroke(
        _artery,
        math.max(form.mm(0.45), PlacentaStyle.spiralFloor * line),
      ),
    );
    final Paint artery = Paint()..color = _artery;
    for (final Path f in form.funnels) {
      canvas.drawPath(f, artery);
    }
  }

  void _paintEdges(Canvas canvas, double line) {
    canvas.drawPath(
      _lines(<List<Offset>>[form.topEdge]),
      _stroke(
        inks
            .lit(PlacentaStyle.edgeLit)
            .withValues(alpha: PlacentaStyle.edgeAlpha),
        line,
      ),
    );
    canvas.drawPath(
      _lines(<List<Offset>>[form.sideEdge]),
      _stroke(
        inks.shadow.withValues(alpha: PlacentaStyle.edgeShadeAlpha),
        line,
      ),
    );
  }

  /// Clumps of villi, each a round dot in [colour], at least half a pixel
  /// in radius.
  static void _clumps(
    Canvas canvas,
    List<PlacentaClumps> clumps,
    Color colour,
    double line,
  ) {
    for (final PlacentaClumps c in clumps) {
      canvas.drawRawPoints(
        ui.PointMode.points,
        c.points,
        Paint()
          ..color = colour
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 2 * math.max(c.radius, 0.5 * line),
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

    add('veins', _layVeins);
    add('arteries', _layArteries);
    add('cord', _layCord);
    return out;
  }

  /// Every flat colour it fills or strokes with, for tests, by the part it
  /// draws.
  @visibleForTesting
  Map<String, Color> get fills => <String, Color>{
    'home': homeTone,
    'villi': _villi,
    'decidua': _decidua,
    'space': _space,
    'plate': _plate,
    'amnion': _amnion,
    'muscle': _muscle,
    'surface': _surface,
    'artery': _artery,
    'vein': _vein,
    'jelly': _jellyEnd,
    'arteryWall': _arteryWall,
  };

  // Helpers.

  static Path _lines(List<List<Offset>> lines) {
    final Path path = Path();
    for (final List<Offset> points in lines) {
      path.moveTo(points.first.dx, points.first.dy);
      for (final Offset p in points.skip(1)) {
        path.lineTo(p.dx, p.dy);
      }
    }
    return path;
  }

  static Paint _stroke(Color colour, double width) => Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = width
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..color = colour;

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
