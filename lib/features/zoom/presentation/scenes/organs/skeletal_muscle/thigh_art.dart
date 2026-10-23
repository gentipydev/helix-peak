import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../zoom_inks.dart';
import '../../coloured_mesh.dart';
import '../../relief.dart';
import '../../specimen_light.dart';
import '../../tube_course.dart';
import 'thigh_form.dart';
import 'thigh_style.dart';

/// The front of the thigh drawn as a dissection under the zoom's one lamp:
/// the vastus lateralis, where the zoom's cell lives, flat in the mark as
/// the brain's cortex is, its fascicles crisp creases over it; every other
/// muscle a rounded form, lit, its fascicles faint grooves running its own
/// way, a crisp line where one lies on another; between them, in shade,
/// what lies deeper; the iliotibial tract, the tendons and the patella pale
/// and glossy; the femoral nerve, artery and vein down the femoral triangle
/// under the sartorius, in the home helix's honey and the blood red.
///
/// Everything costly is built once, for one form and one set of inks:
/// meshes and paths in the scene's units, so a frame only hands them on.
final class ThighArt {
  ThighArt(this.form, this.inks)
    : _light = SpecimenLight(SpecimenLamp.zoom),
      _palette = SpecimenPalette(inks);

  final ThighForm form;
  final ZoomInks inks;
  final SpecimenLight _light;
  final SpecimenPalette _palette;

  /// The vastus lateralis's one tone, where the zoom's cell lives: the mark
  /// over a neutral, as the brain's cortex is. The step from the body draws
  /// its bed in it, so the mark carries through.
  static Color homeOf(ZoomInks inks) => Color.alphaBlend(
    inks.glow(ThighStyle.homeMark),
    inks.lit(ThighStyle.homeLit),
  );

  /// What the step from the body draws the vastus lateralis's bed in.
  static Color bedOf(ZoomInks inks) => homeOf(inks);

  late final Color _home = homeOf(inks);

  SpecimenTone _tone(Color colour) => SpecimenTone(colour, inks.shadow);

  late final SpecimenTone _muscleTone = _tone(
    Color.lerp(
      inks.lit(ThighStyle.muscleLit),
      inks.bases.thymine,
      ThighStyle.muscleWarmth,
    )!,
  );
  late final SpecimenTone _tendonTone = _tone(inks.lit(ThighStyle.tendonLit));
  late final SpecimenTone _patellaTone = _tone(inks.lit(ThighStyle.patellaLit));
  late final SpecimenTone _arteryTone = _tone(
    Color.lerp(inks.blood, inks.ground, ThighStyle.artery)!,
  );
  late final SpecimenTone _veinTone = _tone(
    Color.lerp(inks.blood, inks.ground, ThighStyle.vein)!,
  );
  late final SpecimenTone _nerveTone = _tone(
    Color.lerp(inks.nerve, inks.ground, ThighStyle.nerve)!,
  );

  static final List<double> _round = <double>[
    for (final double u in ThighStyle.tubeColumns.reversed) -u,
    ...ThighStyle.tubeColumns.skip(1),
  ];

  // The muscles: each its path, its lit mesh, and its fascicles.

  late final List<_Muscle> _deeper = <_Muscle>[
    _lit(form.pectineus),
    _lit(form.iliopsoas),
    _lit(form.adductorLongus),
  ];
  late final List<_Muscle> _over = <_Muscle>[
    _lit(form.gracilis),
    _lit(form.vastusMedialis),
    _Muscle(
      _polygon(form.vastusLateralis.outline),
      const <ui.Vertices>[],
      _lines(form.vastusLateralis.fascicles),
    ),
    _lit(form.rectusFemoris),
    _lit(form.tensor),
  ];
  late final _Muscle _sartorius = _lit(form.sartorius);

  _Muscle _lit(ThighMuscle muscle) => _Muscle(
    _polygon(muscle.outline),
    _build(
      (ColouredMesh mesh) => _layRelief(mesh, muscle.outline, _muscleTone),
    ),
    _lines(muscle.fascicles),
  );

  /// [outline] inflated and laid as a lit surface in [tone] on a grid over
  /// its box, to be drawn clipped to it.
  void _layRelief(
    ColouredMesh mesh,
    List<Offset> outline,
    SpecimenTone tone, {
    double inflation = ThighStyle.reliefInflation,
    double brightness = 1,
    double sheen = 1,
  }) {
    final Relief relief = Relief(
      outline,
      cell: form.mm(ThighStyle.reliefCell),
      inflation: inflation,
      sweeps: ThighStyle.reliefSweeps,
    );
    final double cell = form.mm(ThighStyle.meshCell);
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

  // The tendons and the bone.

  late final Path _deep = _polygon(form.deep);
  late final Path _tract = _polygon(form.tractOutline);
  late final Path _tractStrands = () {
    final Path path = Path();
    for (final double u in <double>[-0.4, 0.35]) {
      path.addPolygon(<Offset>[
        for (int i = 0; i < form.tract.length; i++) form.tract.at(i, u),
      ], false);
    }
    return path;
  }();
  late final Path _retinacula = _polygon(form.retinacula);
  late final Path _tendon = _polygon(form.quadricepsTendon);
  late final Path _ligament = _polygon(form.patellarLigament);
  late final Path _patella = _polygon(form.patella);
  late final List<ui.Vertices> _tendons = _build((ColouredMesh mesh) {
    for (final List<Offset> outline in <List<Offset>>[
      form.quadricepsTendon,
      form.patellarLigament,
    ]) {
      _layRelief(
        mesh,
        outline,
        _tendonTone,
        brightness: ThighStyle.tendonLight,
        sheen: ThighStyle.tendonSheen,
      );
    }
  });
  late final List<ui.Vertices> _patellaMesh = _build(
    (ColouredMesh mesh) => _layRelief(
      mesh,
      form.patella,
      _patellaTone,
      brightness: ThighStyle.tendonLight,
      sheen: ThighStyle.tendonSheen,
    ),
  );

  // The femoral triangle's nerve, artery and vein.

  late final List<ui.Vertices> _vessels = _build((ColouredMesh mesh) {
    _layTube(mesh, form.vein, _veinTone);
    _layTube(mesh, form.artery, _arteryTone);
    for (final TubeCourse branch in form.nerveBranches) {
      _layTube(mesh, branch, _nerveTone);
    }
    _layTube(mesh, form.nerve, _nerveTone);
  });

  void _layTube(ColouredMesh mesh, TubeCourse tube, SpecimenTone tone) =>
      tube.lay(
        mesh,
        tone,
        _light,
        _palette,
        _round,
        brightness: ThighStyle.tubeLight,
      );

  // Drawing.

  /// What the thigh covers, its shadow included: the room a layer of it
  /// needs.
  late final Rect bounds = form.box.inflate(
    form.mm(ThighStyle.shadowY + ThighStyle.shadowSoft),
  );

  /// Builds every mesh and path a frame will draw.
  void prepare() => <Object?>[
    _deeper,
    _over,
    _sartorius,
    _deep,
    _tract,
    _tractStrands,
    _retinacula,
    _tendon,
    _ligament,
    _patella,
    _tendons,
    _patellaMesh,
    _vessels,
    bounds,
  ];

  /// Draws it all, in the scene's units at the thigh's real size; [line] is
  /// a pixel.
  void paint(Canvas canvas, double line) {
    _paintShadow(canvas);
    canvas.drawPath(_deep, Paint()..color = inks.shade(ThighStyle.deepShade));
    for (final _Muscle m in _deeper) {
      _paintMuscle(canvas, m, line);
    }
    // The nerve, the artery and the vein on the triangle's floor, under the
    // sartorius.
    _draw(canvas, _vessels);
    for (final _Muscle m in _over) {
      _paintMuscle(canvas, m, line, home: m.meshes.isEmpty);
    }
    // The retinacula over the knee; the iliotibial tract over the vastus
    // lateralis's lateral edge, the quadriceps tendon, the patella and its
    // ligament.
    canvas.drawPath(
      _retinacula,
      Paint()..color = inks.lit(ThighStyle.retinaculumLit),
    );
    canvas.drawPath(_retinacula, _border(line));
    canvas.drawPath(_tract, Paint()..color = inks.lit(ThighStyle.tractLit));
    canvas.drawPath(
      _tractStrands,
      _stroke(inks.shadow.withValues(alpha: ThighStyle.strandAlpha), line),
    );
    canvas.drawPath(_tract, _border(line));
    for (final Path p in <Path>[_tendon, _ligament]) {
      canvas.save();
      canvas.clipPath(p);
      _draw(canvas, _tendons);
      canvas.restore();
      canvas.drawPath(p, _border(line));
    }
    canvas.save();
    canvas.clipPath(_patella);
    _draw(canvas, _patellaMesh);
    canvas.restore();
    canvas.drawPath(_patella, _border(line));
    _paintMuscle(canvas, _sartorius, line);
    canvas.drawPath(
      form.outline,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = line
        ..strokeJoin = StrokeJoin.round
        ..color = inks
            .lit(ThighStyle.edgeLit)
            .withValues(alpha: ThighStyle.edgeAlpha),
    );
  }

  /// [m] lit, its fascicles grooves, or where it is the home flat in the
  /// mark, its fascicles crisp creases; and its edge where it lies on what
  /// is under it.
  void _paintMuscle(
    Canvas canvas,
    _Muscle m,
    double line, {
    bool home = false,
  }) {
    if (home) {
      canvas.drawPath(m.path, Paint()..color = _home);
    }
    canvas.save();
    canvas.clipPath(m.path);
    if (home) {
      canvas.drawPath(
        m.fascicles,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(
            form.mm(ThighStyle.crease),
            ThighStyle.creaseFloor * line,
          )
          ..strokeCap = StrokeCap.round
          ..color = inks.shadow.withValues(alpha: ThighStyle.creaseAlpha),
      );
    } else {
      _draw(canvas, m.meshes);
      canvas.drawPath(
        m.fascicles,
        _stroke(inks.shadow.withValues(alpha: ThighStyle.grooveShade), line),
      );
      canvas.drawPath(
        m.fascicles.shift(
          _light.screen * form.mm(ThighStyle.ridge * ThighStyle.fascicle),
        ),
        _stroke(inks.text.withValues(alpha: ThighStyle.grooveLight), line),
      );
    }
    canvas.restore();
    canvas.drawPath(m.path, _border(line));
  }

  Paint _stroke(Color colour, double line) => Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = line
    ..strokeCap = StrokeCap.round
    ..color = colour;

  Paint _border(double line) => Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = math.max(
      form.mm(ThighStyle.border),
      ThighStyle.borderFloor * line,
    )
    ..strokeJoin = StrokeJoin.round
    ..color = inks.shadow.withValues(alpha: ThighStyle.borderAlpha);

  // The shadow.

  void _paintShadow(Canvas canvas) {
    canvas.save();
    canvas.translate(form.mm(ThighStyle.shadowX), form.mm(ThighStyle.shadowY));
    final Color shadow = inks.shadow;
    canvas.drawPath(
      form.outline,
      Paint()..color = shadow.withValues(alpha: ThighStyle.shadowAlpha),
    );
    canvas.drawPath(
      form.outline,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = form.mm(ThighStyle.shadowSoft)
        ..strokeJoin = StrokeJoin.round
        ..color = shadow.withValues(alpha: 0.12),
    );
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

    for (final ThighMuscle m in form.muscles) {
      if (identical(m, form.vastusLateralis)) {
        continue;
      }
      add(
        'muscle',
        (ColouredMesh mesh) => _layRelief(mesh, m.outline, _muscleTone),
      );
    }
    add('tendons', (ColouredMesh mesh) {
      for (final List<Offset> outline in <List<Offset>>[
        form.quadricepsTendon,
        form.patellarLigament,
      ]) {
        _layRelief(mesh, outline, _tendonTone);
      }
      _layRelief(mesh, form.patella, _patellaTone);
    });
    add('vessels', (ColouredMesh mesh) {
      _layTube(mesh, form.vein, _veinTone);
      _layTube(mesh, form.artery, _arteryTone);
      for (final TubeCourse branch in form.nerveBranches) {
        _layTube(mesh, branch, _nerveTone);
      }
      _layTube(mesh, form.nerve, _nerveTone);
    });
    return out;
  }

  static Path _polygon(List<Offset> points) => Path()..addPolygon(points, true);

  static Path _lines(List<List<Offset>> lines) {
    final Path path = Path();
    for (final List<Offset> line in lines) {
      path.addPolygon(line, false);
    }
    return path;
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

  static Rect _bounds(List<Offset> points) {
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
}

/// A muscle as drawn: its outline's path, its lit mesh (none for the home,
/// which is flat), and its fascicles.
final class _Muscle {
  const _Muscle(this.path, this.meshes, this.fascicles);

  final Path path;
  final List<ui.Vertices> meshes;
  final Path fascicles;
}
