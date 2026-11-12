import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../zoom_inks.dart';
import '../../coloured_mesh.dart';
import '../../cut_face.dart';
import '../../relief.dart';
import '../../specimen_light.dart';
import '../../tube_course.dart';
import 'parathyroid_anatomy.dart';
import 'parathyroid_form.dart';
import 'parathyroid_style.dart';

/// The parathyroid seen from behind on the back of its thyroid lobe, cut
/// through its thickness, drawn as a specimen under the zoom's one lamp:
/// where the zoom's cell lives flat in the mark (its chief cells, its
/// oxyphil nodules, or its fat); everywhere else the gland's cut face a tan
/// brown turning away under its capsule, its oxyphil nodules deeper and
/// warmer, its fat pale specks, its septa fine shadowed lines and its
/// vessels finer lines in the blood red, branching from the hilum; the
/// lobe behind it lit in the thyroid specimen's own red-brown, fading out
/// round it; the inferior thyroid artery coming in across the lobe's back,
/// its branches going into the lobe and one to the gland's hilum; the
/// recurrent laryngeal nerve over it, a lit cord in the honey.
///
/// Everything costly is built once, for one form and one set of inks:
/// meshes and paths in the scene's units, so a frame only hands them on.
final class ParathyroidArt {
  ParathyroidArt(this.form, this.inks)
    : _light = SpecimenLight(SpecimenLamp.zoom),
      _palette = SpecimenPalette(inks);

  final ParathyroidForm form;
  final ZoomInks inks;
  final SpecimenLight _light;
  final SpecimenPalette _palette;

  ParathyroidHome get home => form.home;

  /// Where the zoom's cell lives: one flat tone, the mark over a neutral,
  /// as the kidney's cortex is.
  static Color homeOf(ZoomInks inks) => Color.alphaBlend(
    inks.glow(ParathyroidStyle.homeMark),
    inks.lit(ParathyroidStyle.homeLit),
  );

  SpecimenTone _tone(Color colour) => SpecimenTone(colour, inks.shadow);

  Color _warmed(double lit, double warmth) =>
      Color.lerp(inks.lit(lit), inks.bases.thymine, warmth)!;

  late final Color _home = homeOf(inks);
  late final SpecimenTone _glandTone = _tone(
    Color.lerp(
      _warmed(ParathyroidStyle.glandLit, ParathyroidStyle.glandWarmth),
      inks.nerve,
      ParathyroidStyle.glandHoney,
    )!,
  );
  late final SpecimenTone _oxyphilTone = _tone(
    _warmed(ParathyroidStyle.oxyphilLit, ParathyroidStyle.oxyphilWarmth),
  );
  late final SpecimenTone _lobeTone = _tone(
    _warmed(ParathyroidStyle.lobeLit, ParathyroidStyle.lobeWarmth),
  );
  late final SpecimenTone _nerveTone = _tone(
    Color.lerp(inks.nerve, inks.ground, ParathyroidStyle.nerve)!,
  );
  late final SpecimenTone _arteryTone = _tone(
    Color.lerp(inks.blood, inks.ground, ParathyroidStyle.artery)!,
  );

  /// [tone]'s cut face where it faces the eye.
  Color _face(SpecimenTone tone) => Color(
    _palette.colour(
      tone,
      _light.light(0, 0, 1),
      sheen: _light.sheen(0, 0, 1) * ParathyroidStyle.cutSheen,
    ),
  );

  late final Color _parenchyma = home == ParathyroidHome.chief
      ? _home
      : _face(_glandTone);
  late final Color _oxyphil = home == ParathyroidHome.oxyphil
      ? _home
      : _face(_oxyphilTone);
  late final Color _fat = home == ParathyroidHome.fat
      ? inks.mark
      : Color.lerp(
          inks.lit(ParathyroidStyle.fatLit),
          inks.nerve,
          ParathyroidStyle.fatHoney,
        )!.withValues(alpha: ParathyroidStyle.fatAlpha);
  late final Color _arteryLine = Color.lerp(
    inks.blood,
    inks.ground,
    ParathyroidStyle.artery,
  )!;
  late final Color _veinLine = Color.lerp(
    inks.blood,
    inks.ground,
    ParathyroidStyle.vein,
  )!;

  late final CutFace _faceOf = CutFace(
    _light,
    _palette,
    sheen: ParathyroidStyle.cutSheen,
  );

  /// The cut face's edge turning away under the capsule.
  static const List<(double, double, double)> _rim = <(double, double, double)>[
    (0, ParathyroidStyle.rimOuter, 0),
    (0.5, ParathyroidStyle.rimMiddle, 0),
    (1, 0, 0),
  ];

  static final List<double> _round = <double>[
    for (final double u in ParathyroidStyle.tubeColumns.reversed) -u,
    ...ParathyroidStyle.tubeColumns.skip(1),
  ];

  // The meshes.

  /// The cut face's edge under the capsule, where the parenchyma is not
  /// the cell's home: there it is one flat tone.
  late final List<ui.Vertices> _rimMesh = _build((ColouredMesh mesh) {
    if (home != ParathyroidHome.chief) {
      _layRim(mesh);
    }
  });

  void _layRim(ColouredMesh mesh) => _faceOf.lay(
    mesh,
    <Offset>[...form.outlinePoints, form.outlinePoints.first],
    <Offset>[...form.rimInner, form.rimInner.first],
    (int _) => _glandTone,
    _rim,
  );

  /// The lobe behind it, lit as a cushion, fading out round the gland.
  late final List<ui.Vertices> _lobeMesh = _build(_layLobe);

  void _layLobe(ColouredMesh mesh) {
    final Relief relief = Relief(
      form.lobe,
      cell: form.mm(ParathyroidStyle.reliefCell),
      inflation: ParathyroidStyle.reliefInflation,
      sweeps: ParathyroidStyle.reliefSweeps,
    );
    final double cell = form.mm(ParathyroidStyle.meshCell);
    // Only where it shows.
    final Rect grid = _lobeShown.inflate(cell);
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
            _lobeTone,
            _light.light(nx, ny, nz, form: nz),
            sheen: _light.sheen(nx, ny, nz),
            alpha: form.lobeShown(p),
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

  /// The artery, its branches and the gland's own; the nerve over them.
  late final List<ui.Vertices> _arteryMesh = _build(_layArteries);
  late final List<ui.Vertices> _nerveMesh = _build(_layNerve);

  void _layArteries(ColouredMesh mesh) {
    for (final TubeCourse t in <TubeCourse>[
      form.descending,
      form.ascending,
      form.artery,
      form.own,
    ]) {
      _layTube(mesh, t, _arteryTone, ParathyroidStyle.tubeLight);
    }
  }

  void _layNerve(ColouredMesh mesh) =>
      _layTube(mesh, form.nerve, _nerveTone, ParathyroidStyle.nerveLight);

  void _layTube(
    ColouredMesh mesh,
    TubeCourse tube,
    SpecimenTone tone,
    double brightness,
  ) => tube.lay(mesh, tone, _light, _palette, _round, brightness: brightness);

  /// The box the lobe shows in.
  late final Rect _lobeShown = Rect.fromCenter(
    center: form.place(ParathyroidAnatomy.lobeMiddle),
    width: form.mm(
      2 * ParathyroidAnatomy.lobeAcross * ParathyroidAnatomy.lobeGone,
    ),
    height: form.mm(
      2 * ParathyroidAnatomy.lobeDown * ParathyroidAnatomy.lobeGone,
    ),
  ).intersect(_bounds(form.lobe));

  // The paths.

  late final Path _lobePath = Path()..addPolygon(form.lobe, true);
  late final Path _nodules = () {
    final Path path = Path();
    for (final List<Offset> n in form.nodules) {
      path.addPolygon(n, true);
    }
    return path;
  }();
  late final Path _arteries = _lines(form.vessels);
  late final Path _veins = _lines(form.veins);
  late final Path _septa = () {
    final Path path = Path();
    for (final (Offset a, Offset b) in form.septa) {
      path
        ..moveTo(a.dx, a.dy)
        ..lineTo(b.dx, b.dy);
    }
    return path;
  }();
  late final Float32List _fatPoints = Float32List.fromList(<double>[
    for (final Offset p in form.fat) ...<double>[p.dx, p.dy],
  ]);

  static Path _lines(List<List<Offset>> lines) {
    final Path out = Path();
    for (final List<Offset> l in lines) {
      out.addPolygon(l, false);
    }
    return out;
  }

  // The shadow.

  void _paintShadow(Canvas canvas) {
    canvas.save();
    canvas.translate(
      form.mm(ParathyroidStyle.shadowX),
      form.mm(ParathyroidStyle.shadowY),
    );
    final Color shadow = inks.shadow;
    canvas.drawPath(
      form.outline,
      Paint()..color = shadow.withValues(alpha: ParathyroidStyle.shadowAlpha),
    );
    canvas.drawPath(
      form.outline,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = form.mm(ParathyroidStyle.shadowSoft)
        ..strokeJoin = StrokeJoin.round
        ..color = shadow.withValues(alpha: 0.14),
    );
    canvas.restore();
  }

  // Drawing.

  /// What the gland and what is drawn round it cover, its shadow included:
  /// the room a layer of it needs.
  late final Rect bounds = () {
    Rect box = form.box;
    box = box.expandToInclude(_lobeShown);
    for (final TubeCourse t in form.beside) {
      for (int i = 0; i < t.length; i++) {
        box = box.expandToInclude(
          Rect.fromCircle(center: t.centres[i], radius: t.radius[i]),
        );
      }
    }
    return box.inflate(
      form.mm(ParathyroidStyle.shadowY + ParathyroidStyle.shadowSoft),
    );
  }();

  /// Builds every mesh and path a frame will draw.
  void prepare() => <Object?>[
    _rimMesh,
    _lobeMesh,
    _arteryMesh,
    _nerveMesh,
    _lobePath,
    _nodules,
    _arteries,
    _veins,
    _septa,
    _fatPoints,
    bounds,
  ];

  /// Draws it all, in the scene's units at the gland's real size; [line]
  /// is a pixel.
  void paint(Canvas canvas, double line) {
    // The lobe behind it, fading out round it; the artery across its back
    // and its branches going into it; the nerve over the artery.
    canvas.save();
    canvas.clipPath(_lobePath);
    _draw(canvas, _lobeMesh);
    canvas.restore();
    _draw(canvas, _arteryMesh);
    _draw(canvas, _nerveMesh);
    // The gland, cut: its shadow on the lobe, its parenchyma, its oxyphil
    // nodules, its fat, its vessels and its septa, its edge turning away
    // under the capsule.
    _paintShadow(canvas);
    canvas.drawPath(form.outline, Paint()..color = _parenchyma);
    canvas.save();
    canvas.clipPath(form.outline);
    canvas.drawPath(_nodules, Paint()..color = _oxyphil);
    canvas.drawPath(
      _nodules,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = math.max(
          form.mm(ParathyroidStyle.edgeLine),
          ParathyroidStyle.edgeLineFloor * line,
        )
        ..color = inks.shadow.withValues(alpha: ParathyroidStyle.edgeLineAlpha),
    );
    canvas.drawRawPoints(
      ui.PointMode.points,
      _fatPoints,
      Paint()
        ..strokeCap = StrokeCap.round
        ..strokeWidth = math.max(
          form.mm(ParathyroidAnatomy.fatCell),
          (home == ParathyroidHome.fat
                  ? ParathyroidStyle.homeFatFloor
                  : ParathyroidStyle.fatFloor) *
              line,
        )
        ..color = _fat,
    );
    final double vessel = math.max(
      form.mm(ParathyroidStyle.vessel),
      ParathyroidStyle.vesselFloor * line,
    );
    canvas.drawPath(
      _veins,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = vessel
        ..color = _veinLine,
    );
    canvas.drawPath(
      _arteries,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = vessel
        ..color = _arteryLine,
    );
    canvas.drawPath(
      _septa,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = math.max(
          form.mm(ParathyroidStyle.septum),
          ParathyroidStyle.septumFloor * line,
        )
        ..color = inks.shadow.withValues(alpha: ParathyroidStyle.septumAlpha),
    );
    _draw(canvas, _rimMesh);
    canvas.restore();
    // The capsule's edge, as the other specimens'.
    canvas.drawPath(
      form.outline,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = line
        ..strokeJoin = StrokeJoin.round
        ..color = inks
            .lit(ParathyroidStyle.edgeLit)
            .withValues(alpha: ParathyroidStyle.edgeAlpha),
    );
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

    if (home != ParathyroidHome.chief) {
      add('rim', _layRim);
    }
    add('lobe', _layLobe);
    add('arteries', _layArteries);
    add('nerve', _layNerve);
    return out;
  }

  /// The colours the cut face and what lies in it are drawn in, by name.
  /// For tests.
  @visibleForTesting
  Map<String, Color> get fills => <String, Color>{
    'parenchyma': _parenchyma,
    'oxyphil': _oxyphil,
    'fat': _fat,
    'artery': _arteryLine,
    'vein': _veinLine,
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
