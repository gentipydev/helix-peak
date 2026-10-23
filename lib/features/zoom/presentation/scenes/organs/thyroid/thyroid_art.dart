import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../zoom_inks.dart';
import '../../coloured_mesh.dart';
import '../../contour.dart';
import '../../cut_face.dart';
import '../../relief.dart';
import '../../specimen_light.dart';
import '../../tube_course.dart';
import '../../tube_end.dart';
import 'thyroid_form.dart';
import 'thyroid_style.dart';

/// The thyroid gland seen from the front in place, the lobe the body goes
/// into cut open, drawn as a specimen under the zoom's one lamp: where the
/// zoom's cell lives in the mark (the cut lobe's parenchyma flat, as the
/// kidney's cortex is, or its C cells); else that face a deep warm
/// red-brown turning away under the capsule; the septa parting its lobules
/// crisp lines over it; the other lobe and the isthmus a lit surface in the
/// same tone; the thyroid and cricoid cartilages pale and cool, the
/// trachea's rings pale over the membrane between them, the cricothyroid
/// muscles warm; the carotid arteries and the jugular veins at its sides,
/// the thyroid arteries and veins, lit tubes in the blood red, cut short
/// above, fading out below.
///
/// Everything costly is built once, for one form and one set of inks:
/// meshes and paths in the scene's units, so a frame only hands them on.
final class ThyroidArt {
  ThyroidArt(this.form, this.inks)
    : _light = SpecimenLight(SpecimenLamp.zoom),
      _palette = SpecimenPalette(inks);

  final ThyroidForm form;
  final ZoomInks inks;
  final SpecimenLight _light;
  final SpecimenPalette _palette;

  ThyroidHome get home => form.home;

  /// Where the zoom's cell lives: one flat tone, the mark over a neutral,
  /// as the kidney's cortex is.
  static Color homeOf(ZoomInks inks) => Color.alphaBlend(
    inks.glow(ThyroidStyle.homeMark),
    inks.lit(ThyroidStyle.homeLit),
  );

  /// The gland's tone where it faces the eye: what the step from the body
  /// draws its bed in, so that it comes up on its own tone; in the mark
  /// where the cut lobe's parenchyma is the cell's home.
  static Color bedOf(ZoomInks inks, ThyroidHome home) {
    if (home == ThyroidHome.follicles) {
      return homeOf(inks);
    }
    final SpecimenLight light = SpecimenLight(SpecimenLamp.zoom);
    return Color(
      SpecimenPalette(inks).colour(
        _glandToneOf(inks),
        light.light(0, 0, 1),
        sheen: light.sheen(0, 0, 1) * ThyroidStyle.cutSheen,
      ),
    );
  }

  static SpecimenTone _glandToneOf(ZoomInks inks) => SpecimenTone(
    Color.lerp(
      inks.lit(ThyroidStyle.glandLit),
      inks.bases.thymine,
      ThyroidStyle.glandWarmth,
    )!,
    inks.shadow,
  );

  SpecimenTone _tone(Color colour) => SpecimenTone(colour, inks.shadow);

  late final Color _home = homeOf(inks);
  late final SpecimenTone _glandTone = _glandToneOf(inks);
  late final SpecimenTone _cartilageTone = _tone(
    inks.lit(ThyroidStyle.cartilageLit),
  );
  late final SpecimenTone _membraneTone = _tone(
    Color.lerp(
      inks.lit(ThyroidStyle.membraneLit),
      inks.bases.thymine,
      ThyroidStyle.membraneWarmth,
    )!,
  );
  late final SpecimenTone _muscleTone = _tone(
    Color.lerp(
      inks.lit(ThyroidStyle.muscleLit),
      inks.bases.thymine,
      ThyroidStyle.muscleWarmth,
    )!,
  );
  late final SpecimenTone _arteryTone = _tone(
    Color.lerp(inks.blood, inks.ground, ThyroidStyle.artery)!,
  );
  late final SpecimenTone _veinTone = _tone(
    Color.lerp(inks.blood, inks.ground, ThyroidStyle.vein)!,
  );

  /// [tone]'s cut face where it faces the eye.
  Color _face(SpecimenTone tone) => Color(
    _palette.colour(
      tone,
      _light.light(0, 0, 1),
      sheen: _light.sheen(0, 0, 1) * ThyroidStyle.cutSheen,
    ),
  );

  late final Color _cut = home == ThyroidHome.follicles
      ? _home
      : _face(_glandTone);
  late final Color _membrane = _face(_membraneTone);

  late final CutFace _faceOf = CutFace(
    _light,
    _palette,
    sheen: ThyroidStyle.cutSheen,
  );

  /// The cut face's edge turning away under the capsule.
  static const List<(double, double, double)> _rim = <(double, double, double)>[
    (0, ThyroidStyle.rimOuter, 0),
    (0.5, ThyroidStyle.rimMiddle, 0),
    (1, 0, 0),
  ];

  static final List<double> _round = <double>[
    for (final double u in ThyroidStyle.tubeColumns.reversed) -u,
    ...ThyroidStyle.tubeColumns.skip(1),
  ];

  // The meshes.

  /// The cut face's edge under the capsule, where the parenchyma is not
  /// the cell's home: there it is one flat tone.
  late final List<ui.Vertices> _rimMesh = _build((ColouredMesh mesh) {
    if (home != ThyroidHome.follicles) {
      _layRim(mesh);
    }
  });

  void _layRim(ColouredMesh mesh) => _faceOf.lay(
    mesh,
    form.faceRun,
    form.rimInner,
    (int _) => _glandTone,
    _rim,
  );

  /// What the cut leaves whole, the isthmus and the other lobe, lit.
  late final List<ui.Vertices> _wholeMesh = _build(
    (ColouredMesh mesh) => _layRelief(mesh, form.whole, _glandTone),
  );

  /// The cartilages, the cricothyroid muscles, lit.
  late final List<ui.Vertices> _cartilageMesh = _build((ColouredMesh mesh) {
    _layRelief(
      mesh,
      form.cartilage,
      _cartilageTone,
      inflation: ThyroidStyle.cartilageInflation,
      brightness: ThyroidStyle.cartilageLight,
      sheen: ThyroidStyle.cartilageSheen,
    );
  });
  late final List<ui.Vertices> _cricoidMesh = _build((ColouredMesh mesh) {
    _layRelief(
      mesh,
      form.cricoid,
      _cartilageTone,
      inflation: ThyroidStyle.cartilageInflation,
      brightness: ThyroidStyle.cartilageLight,
      sheen: ThyroidStyle.cartilageSheen,
    );
  });
  late final List<ui.Vertices> _muscleMesh = _build((ColouredMesh mesh) {
    for (final List<Offset> muscle in form.cricothyroids) {
      _layRelief(mesh, muscle, _muscleTone);
    }
  });

  /// [outline] inflated and laid as a lit surface in [tone] on a grid over
  /// its box, to be drawn clipped to it.
  void _layRelief(
    ColouredMesh mesh,
    List<Offset> outline,
    SpecimenTone tone, {
    double inflation = ThyroidStyle.reliefInflation,
    double brightness = 1,
    double sheen = 1,
  }) {
    final Relief relief = Relief(
      outline,
      cell: form.mm(ThyroidStyle.reliefCell),
      inflation: inflation,
      sweeps: ThyroidStyle.reliefSweeps,
    );
    final double cell = form.mm(ThyroidStyle.meshCell);
    final Rect grid = _bounds(outline).inflate(cell);
    final int columns = (grid.width / cell).ceil() + 1;
    final int rows = (grid.height / cell).ceil() + 1;
    mesh.begin(columns * rows);
    final int first = mesh.next;
    for (int j = 0; j < rows; j++) {
      for (int i = 0; i < columns; i++) {
        final Offset p = grid.topLeft + Offset(i * cell, j * cell);
        final (double nx, double ny, double nz) = relief.normalAt(p);
        mesh.vertex(
          p.dx,
          p.dy,
          _palette.colour(
            tone,
            _light.light(nx, ny, nz, form: nz) * brightness,
            sheen: _light.sheen(nx, ny, nz) * sheen,
          ),
        );
      }
    }
    for (int j = 0; j + 1 < rows; j++) {
      for (int i = 0; i + 1 < columns; i++) {
        final int a = first + j * columns + i;
        mesh.triangle(a, a + 1, a + columns);
        mesh.triangle(a + 1, a + columns + 1, a + columns);
      }
    }
  }

  /// The trachea, its membrane and its rings over it.
  late final List<ui.Vertices> _tracheaMesh = _build((ColouredMesh mesh) {
    _layTube(mesh, form.trachea, _membraneTone, ThyroidStyle.cartilageLight);
    for (final (int from, int to) in form.rings) {
      form.trachea.lay(
        mesh,
        _cartilageTone,
        _light,
        _palette,
        _round,
        from: from,
        to: to,
        brightness: ThyroidStyle.cartilageLight,
      );
    }
  });

  /// The vessels behind the gland and beside it: the jugular veins and the
  /// carotids, and the middle thyroid veins crossing in front of the
  /// carotids into the jugulars.
  late final List<ui.Vertices> _deepVessels = _build((ColouredMesh mesh) {
    for (final TubeCourse t in form.jugulars) {
      _layTube(mesh, t, _veinTone);
    }
    for (final TubeCourse t in <TubeCourse>[
      ...form.carotids,
      ...form.internalCarotids,
      ...form.externalCarotids,
    ]) {
      _layTube(mesh, t, _arteryTone);
    }
    for (final TubeCourse t in form.middleVeins) {
      _layTube(mesh, t, _veinTone);
    }
  });

  /// The inferior thyroid veins, over the trachea's front.
  late final List<ui.Vertices> _inferiorVeins = _build((ColouredMesh mesh) {
    for (final TubeCourse t in form.inferiorVeins) {
      _layTube(mesh, t, _veinTone);
    }
  });

  /// The superior thyroid arteries over the lobes' apices, and the branch
  /// down the whole lobe to the isthmus.
  late final List<ui.Vertices> _superiorArteries = _build((ColouredMesh mesh) {
    for (final TubeCourse t in <TubeCourse>[
      ...form.superiorArteries,
      form.anteriorBranch,
    ]) {
      _layTube(mesh, t, _arteryTone);
    }
  });

  void _layTube(
    ColouredMesh mesh,
    TubeCourse tube,
    SpecimenTone tone, [
    double brightness = ThyroidStyle.tubeLight,
  ]) => tube.lay(mesh, tone, _light, _palette, _round, brightness: brightness);

  late final TubeEnd _end = TubeEnd(
    _palette,
    inks.shadow,
    length: ThyroidStyle.endLength,
    wall: ThyroidStyle.endWall,
  );

  // The paths.

  late final Path _whole = Path()..addPolygon(form.whole, true);
  late final Path _faceShape = Path()..addPolygon(form.face, true);
  late final Path _cartilage = Contour(form.cartilage).toPath();
  late final Path _cricoid = Contour(form.cricoid).toPath();
  late final Path _membraneShape = Path()..addPolygon(form.membrane, true);
  late final List<Path> _muscles = <Path>[
    for (final List<Offset> m in form.cricothyroids)
      Path()..addPolygon(m, true),
  ];
  late final Path _septa = () {
    final Path path = Path();
    for (final List<Offset> cell in form.lobules) {
      if (cell.length > 2) {
        path.addPolygon(cell, true);
      }
    }
    return path;
  }();
  late final Path _lobeEnd = Path()..addPolygon(form.lobeEnd, false);
  late final Path _ringEdges = () {
    final Path path = Path();
    for (final (int from, int to) in form.rings) {
      for (final int row in <int>[from, to]) {
        final Offset a = form.trachea.at(row, -1);
        final Offset b = form.trachea.at(row, 1);
        path
          ..moveTo(a.dx, a.dy)
          ..lineTo(b.dx, b.dy);
      }
    }
    return path;
  }();
  late final Float32List _cCells = Float32List.fromList(<double>[
    for (final Offset c in form.cCells) ...<double>[c.dx, c.dy],
  ]);

  // The shadow.

  void _paintShadow(Canvas canvas) {
    canvas.save();
    canvas.translate(
      form.mm(ThyroidStyle.shadowX),
      form.mm(ThyroidStyle.shadowY),
    );
    final Color shadow = inks.shadow;
    canvas.drawPath(
      form.outline,
      Paint()..color = shadow.withValues(alpha: ThyroidStyle.shadowAlpha),
    );
    canvas.drawPath(
      form.outline,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = form.mm(ThyroidStyle.shadowSoft)
        ..strokeJoin = StrokeJoin.round
        ..color = shadow.withValues(alpha: 0.12),
    );
    canvas.restore();
  }

  // Drawing.

  /// What the gland and what is drawn beside it cover, its shadow
  /// included: the room a layer of it needs.
  late final Rect bounds = () {
    Rect box = form.box.expandToInclude(_bounds(form.cartilage));
    for (final TubeCourse t in form.beside) {
      for (int i = 0; i < t.length; i++) {
        box = box.expandToInclude(
          Rect.fromCircle(center: t.centres[i], radius: t.radius[i]),
        );
      }
    }
    return box.inflate(form.mm(ThyroidStyle.shadowY + ThyroidStyle.shadowSoft));
  }();

  /// Builds every mesh and path a frame will draw.
  void prepare() => <Object?>[
    _rimMesh,
    _wholeMesh,
    _cartilageMesh,
    _cricoidMesh,
    _muscleMesh,
    _tracheaMesh,
    _deepVessels,
    _inferiorVeins,
    _superiorArteries,
    _whole,
    _faceShape,
    _cartilage,
    _cricoid,
    _membraneShape,
    _muscles,
    _septa,
    _lobeEnd,
    _ringEdges,
    _cCells,
    bounds,
  ];

  /// Draws it all, in the scene's units at the gland's real size; [line]
  /// is a pixel.
  void paint(Canvas canvas, double line) {
    // The carotids and the jugulars at its sides, the middle thyroid veins
    // crossing into them, behind it.
    _draw(canvas, _deepVessels);
    // The trachea and its rings, then the larynx over its top: the
    // cricothyroid membrane and muscles, the cricoid, the thyroid
    // cartilage.
    _draw(canvas, _tracheaMesh);
    canvas.drawPath(
      _ringEdges,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = line
        ..color = inks.shadow.withValues(alpha: ThyroidStyle.ringEdgeAlpha),
    );
    canvas.drawPath(_membraneShape, Paint()..color = _membrane);
    for (final Path muscle in _muscles) {
      _clipped(canvas, muscle, _muscleMesh);
    }
    _clipped(canvas, _cricoid, _cricoidMesh);
    _edge(canvas, _cricoid, line, ThyroidStyle.edgeAlpha * 0.6);
    _clipped(canvas, _cartilage, _cartilageMesh);
    _edge(canvas, _cartilage, line, ThyroidStyle.edgeAlpha * 0.6);
    _end.paint(
      canvas,
      form.trachea,
      _cartilageTone,
      _light.light(0, 0, 1) * ThyroidStyle.cartilageLight,
    );
    // The inferior thyroid veins down the trachea's front.
    _draw(canvas, _inferiorVeins);
    // The gland: its shadow, what the cut leaves whole, lit; the cut
    // lobe's face, its lobules, and its C cells where they are the home.
    _paintShadow(canvas);
    _clipped(canvas, _whole, _wholeMesh);
    canvas.drawPath(_faceShape, Paint()..color = _cut);
    _draw(canvas, _rimMesh);
    canvas.save();
    canvas.clipPath(_faceShape);
    canvas.drawPath(
      _septa,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = math.max(
          form.mm(ThyroidStyle.septum),
          ThyroidStyle.septumFloor * line,
        )
        ..color = inks.shadow.withValues(alpha: ThyroidStyle.septumAlpha),
    );
    canvas.restore();
    if (home == ThyroidHome.cCells) {
      canvas.drawRawPoints(
        ui.PointMode.points,
        _cCells,
        Paint()
          ..strokeCap = StrokeCap.round
          ..strokeWidth = ThyroidStyle.cFloor * line
          ..color = inks.mark,
      );
    }
    canvas.drawPath(
      _lobeEnd,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = line
        ..color = inks.shadow.withValues(alpha: ThyroidStyle.lobeEndAlpha),
    );
    _edge(canvas, form.outline, line, ThyroidStyle.edgeAlpha);
    // The superior thyroid arteries over the apices, the branch down the
    // whole lobe to the isthmus, and every end the cut or the view takes.
    _draw(canvas, _superiorArteries);
    final double lit = _light.light(0, 0, 1) * ThyroidStyle.tubeLight;
    for (final TubeCourse t in <TubeCourse>[
      ...form.carotids,
      ...form.internalCarotids,
      ...form.externalCarotids,
      form.superiorArteries.first,
      form.anteriorBranch,
    ]) {
      _end.paint(canvas, t, _arteryTone, lit);
    }
    for (final TubeCourse t in <TubeCourse>[
      ...form.jugulars,
      ...form.jugularTops,
      ...form.inferiorVeins,
    ]) {
      _end.paint(canvas, t, _veinTone, lit);
    }
  }

  void _edge(Canvas canvas, Path path, double line, double alpha) =>
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = line
          ..strokeJoin = StrokeJoin.round
          ..color = inks.lit(ThyroidStyle.edgeLit).withValues(alpha: alpha),
      );

  void _clipped(Canvas canvas, Path shape, List<ui.Vertices> meshes) {
    canvas.save();
    canvas.clipPath(shape);
    _draw(canvas, meshes);
    canvas.restore();
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

    if (home != ThyroidHome.follicles) {
      add('face', _layRim);
    }
    add(
      'whole',
      (ColouredMesh mesh) => _layRelief(mesh, form.whole, _glandTone),
    );
    add(
      'cartilage',
      (ColouredMesh mesh) => _layRelief(mesh, form.cartilage, _cartilageTone),
    );
    add('vessels', (ColouredMesh mesh) {
      for (final TubeCourse t in <TubeCourse>[
        ...form.jugulars,
        ...form.middleVeins,
        ...form.inferiorVeins,
      ]) {
        _layTube(mesh, t, _veinTone);
      }
      for (final TubeCourse t in <TubeCourse>[
        ...form.carotids,
        ...form.internalCarotids,
        ...form.externalCarotids,
        ...form.superiorArteries,
        form.anteriorBranch,
      ]) {
        _layTube(mesh, t, _arteryTone);
      }
    });
    add(
      'trachea',
      (ColouredMesh mesh) => _layTube(mesh, form.trachea, _membraneTone),
    );
    return out;
  }

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

Rect _bounds(List<Offset> points) {
  double left = double.infinity;
  double top = double.infinity;
  double right = double.negativeInfinity;
  double bottom = double.negativeInfinity;
  for (final Offset p in points) {
    left = math.min(left, p.dx);
    right = math.max(right, p.dx);
    top = math.min(top, p.dy);
    bottom = math.max(bottom, p.dy);
  }
  return Rect.fromLTRB(left, top, right, bottom);
}
