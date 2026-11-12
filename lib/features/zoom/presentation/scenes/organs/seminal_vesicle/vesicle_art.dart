import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../zoom_inks.dart';
import '../../coloured_mesh.dart';
import '../../relief.dart';
import '../../specimen_light.dart';
import '../../tube_course.dart';
import 'vesicle_anatomy.dart';
import 'vesicle_form.dart';
import 'vesicle_style.dart';

/// The seminal vesicles seen from the front with the bladder taken away,
/// drawn as a specimen under the zoom's one lamp: the vesicle on the body's
/// left laid open, its mucosa, where the zoom's cell lives, flat in the
/// mark, cut by its anatomy as crisp lines (the honeycomb's fine folds,
/// the septa between its coils, the diverticula dark pits), the cut wall a
/// warm band round it and its duct a lit tube below; the vesicle on the
/// body's right whole, a lit coiled sac of Gray's whitish brown with the
/// creases between its coils; the deferent ducts coming in over the
/// vesicles' upper ends and down their medial margins as the ampullae, lit
/// cords, the one on the body's left laid open with its lining pale and
/// folded; the ejaculatory ducts going into the base; the arteries to the
/// vesicles in the blood red; the prostate's base below, lit as a cushion
/// in the prostate specimen's own tone, fading out below.
///
/// Everything costly is built once, for one form and one set of inks:
/// meshes and paths in the scene's units, so a frame only hands them on.
final class SeminalVesicleArt {
  SeminalVesicleArt(this.form, this.inks)
    : _light = SpecimenLight(SpecimenLamp.zoom),
      _palette = SpecimenPalette(inks);

  final SeminalVesicleForm form;
  final ZoomInks inks;
  final SpecimenLight _light;
  final SpecimenPalette _palette;

  /// Where the zoom's cell lives, the mucosa: one flat tone, the mark over
  /// a neutral, as the kidney's cortex is.
  static Color homeOf(ZoomInks inks) => Color.alphaBlend(
    inks.glow(SeminalVesicleStyle.homeMark),
    inks.lit(SeminalVesicleStyle.homeLit),
  );

  /// What the step from the body draws the opened vesicle's bed in: its
  /// mucosa, so that the specimen comes up on its own tone.
  static Color bedOf(ZoomInks inks) => homeOf(inks);

  SpecimenTone _tone(Color colour) => SpecimenTone(colour, inks.shadow);

  Color _warmed(double lit, double warmth) =>
      Color.lerp(inks.lit(lit), inks.bases.thymine, warmth)!;

  late final Color _home = homeOf(inks);
  late final SpecimenTone _vesicleTone = _tone(
    Color.lerp(
      _warmed(
        SeminalVesicleStyle.vesicleLit,
        SeminalVesicleStyle.vesicleWarmth,
      ),
      inks.nerve,
      SeminalVesicleStyle.vesicleHoney,
    )!,
  );
  late final SpecimenTone _wallTone = _tone(
    _warmed(SeminalVesicleStyle.wallLit, SeminalVesicleStyle.wallWarmth),
  );
  late final SpecimenTone _ductTone = _tone(
    _warmed(SeminalVesicleStyle.ductLit, SeminalVesicleStyle.ductWarmth),
  );
  late final SpecimenTone _liningTone = _tone(
    _warmed(SeminalVesicleStyle.liningLit, SeminalVesicleStyle.liningWarmth),
  );
  late final SpecimenTone _ejaculatoryTone = _tone(
    _warmed(
      SeminalVesicleStyle.ejaculatoryLit,
      SeminalVesicleStyle.ejaculatoryWarmth,
    ),
  );
  late final SpecimenTone _prostateTone = _tone(
    _warmed(
      SeminalVesicleStyle.prostateLit,
      SeminalVesicleStyle.prostateWarmth,
    ),
  );
  late final SpecimenTone _arteryTone = _tone(
    Color.lerp(inks.blood, inks.ground, SeminalVesicleStyle.artery)!,
  );

  /// [tone]'s cut face where it faces the eye.
  Color _face(SpecimenTone tone) => Color(
    _palette.colour(
      tone,
      _light.light(0, 0, 1),
      sheen: _light.sheen(0, 0, 1) * SeminalVesicleStyle.cutSheen,
    ),
  );

  late final Color _wall = _face(_wallTone);
  late final Color _lining = _face(_liningTone);

  static final List<double> _round = <double>[
    for (final double u in SeminalVesicleStyle.tubeColumns.reversed) -u,
    ...SeminalVesicleStyle.tubeColumns.skip(1),
  ];

  // The meshes.

  /// The prostate's base, lit as a cushion, fading out below.
  late final List<ui.Vertices> _prostateMesh = _build(_layProstate);

  void _layProstate(ColouredMesh mesh) {
    final Relief relief = Relief(
      form.prostate,
      cell: form.mm(SeminalVesicleStyle.reliefCell),
      inflation: SeminalVesicleStyle.reliefInflation,
      sweeps: SeminalVesicleStyle.reliefSweeps,
    );
    final double cell = form.mm(SeminalVesicleStyle.meshCell);
    final Rect grid = _prostateShown.inflate(cell);
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
            _prostateTone,
            _light.light(nx, ny, nz, form: nz),
            sheen: _light.sheen(nx, ny, nz),
            alpha: form.prostateShown(p),
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

  /// The box the prostate shows in: its outline's, cut where it has faded.
  late final Rect _prostateShown = () {
    final Rect box = _bounds(form.prostate);
    final double gone = form
        .place(const Offset(0, SeminalVesicleAnatomy.prostateGone))
        .dy;
    return Rect.fromLTRB(
      box.left,
      box.top,
      box.right,
      math.min(box.bottom, gone),
    );
  }();

  /// The arteries, the whole vesicle, the opened vesicle's duct, the
  /// deferent ducts and the ejaculatory ducts, each a lit tube.
  late final List<ui.Vertices> _arteryMesh = _build(_layArteries);
  late final List<ui.Vertices> _rightMesh = _build(_layRight);
  late final List<ui.Vertices> _leftDuctMesh = _build(_layLeftDuct);
  late final List<ui.Vertices> _deferensMesh = _build(_layDeferens);
  late final List<ui.Vertices> _ejaculatoryMesh = _build(_layEjaculatory);

  void _layArteries(ColouredMesh mesh) {
    for (final TubeCourse t in form.arteries) {
      _layTube(mesh, t, _arteryTone);
    }
  }

  void _layRight(ColouredMesh mesh) => _layTube(mesh, form.right, _vesicleTone);

  void _layLeftDuct(ColouredMesh mesh) =>
      _layTube(mesh, form.left, _vesicleTone, to: form.sacRow + 1);

  void _layDeferens(ColouredMesh mesh) {
    for (final TubeCourse t in form.deferens) {
      _layTube(mesh, t, _ductTone);
    }
  }

  void _layEjaculatory(ColouredMesh mesh) {
    for (final TubeCourse t in form.ejaculatory) {
      _layTube(mesh, t, _ejaculatoryTone);
    }
  }

  void _layTube(
    ColouredMesh mesh,
    TubeCourse tube,
    SpecimenTone tone, {
    int? to,
  }) => tube.lay(
    mesh,
    tone,
    _light,
    _palette,
    _round,
    to: to,
    brightness: SeminalVesicleStyle.tubeLight,
  );

  /// The creases between the whole vesicle's coils, across it: a mesh of
  /// thin quads in the shadow ink.
  late final List<ui.Vertices> _coilMesh = _build((ColouredMesh mesh) {
    final TubeCourse t = form.right;
    for (final double at in form.coilsAt) {
      int i = 0;
      while (i < t.length - 1 && t.arc[i] < at) {
        i++;
      }
      final Offset c = t.centres[i];
      final Offset across = t.across[i];
      final Offset along = Offset(across.dy, -across.dx);
      final double reach = t.radius[i] * SeminalVesicleStyle.coilReach;
      final double half = form.mm(SeminalVesicleStyle.coilCrease) / 2;
      // Bowed a little, as a crease round a coil is seen.
      final Offset bow = along * (t.radius[i] * 0.18);
      final List<Offset> line = <Offset>[
        for (int k = 0; k <= 8; k++)
          c +
              across * (reach * (k / 4 - 1)) +
              bow * (1 - (k / 4 - 1) * (k / 4 - 1)),
      ];
      final int colour = SpecimenPalette.packColour(
        inks.shadow,
        SeminalVesicleStyle.coilAlpha * t.shown[i],
      );
      mesh.begin(2 * line.length);
      final int first = mesh.next;
      for (int k = 0; k < line.length; k++) {
        final double taper = math.sin(math.pi * k / (line.length - 1));
        final Offset off = along * (half * (0.3 + 0.7 * taper));
        mesh
          ..vertex(line[k].dx + off.dx, line[k].dy + off.dy, colour)
          ..vertex(line[k].dx - off.dx, line[k].dy - off.dy, colour);
      }
      for (int k = 0; k + 1 < line.length; k++) {
        final int a = first + 2 * k;
        mesh
          ..triangle(a, a + 2, a + 1)
          ..triangle(a + 2, a + 3, a + 1);
      }
    }
  });

  // The paths.

  late final Path _outline = form.outline;
  late final Path _sac = _polygon(form.openedSac);
  late final Path _lumen = _polygon(form.lumen);
  late final Path _meshes = () {
    final Path path = Path();
    for (final (Offset a, Offset b) in form.meshEdges) {
      path
        ..moveTo(a.dx, a.dy)
        ..lineTo(b.dx, b.dy);
    }
    return path;
  }();
  late final Path _septa = _tapered(
    form.septa,
    SeminalVesicleStyle.septum,
    SeminalVesicleStyle.septumTaper,
  );
  late final Path _pits = () {
    final Path path = Path();
    for (final (Offset p, double r) in form.pits) {
      path.addOval(Rect.fromCircle(center: p, radius: r));
    }
    return path;
  }();
  late final Path _openedAmpulla = _polygon(form.openedAmpulla);
  late final Path _ampullaLining = _polygon(form.ampullaLining);
  late final Path _ampullaFolds = _tapered(
    form.ampullaFolds,
    SeminalVesicleStyle.fold,
    SeminalVesicleStyle.foldTaper,
  );
  late final Path _prostatePath = _polygon(form.prostate);

  /// The prostate's edge fading out as its base does: the edge's colour
  /// down to nothing over the fade, at the fade's own curve.
  late final ui.Shader _prostateEdge = () {
    final Color edge = inks
        .lit(SeminalVesicleStyle.edgeLit)
        .withValues(alpha: SeminalVesicleStyle.edgeAlpha);
    final double top = form.place(Offset.zero).dy;
    final double gone = form
        .place(const Offset(0, SeminalVesicleAnatomy.prostateGone))
        .dy;
    const int steps = 6;
    return LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: <Color>[
        for (int k = 0; k <= steps; k++)
          edge.withValues(
            alpha:
                edge.a *
                form.prostateShown(Offset(0, top + (gone - top) * k / steps)),
          ),
      ],
      stops: <double>[for (int k = 0; k <= steps; k++) k / steps],
    ).createShader(Rect.fromLTRB(form.box.left, top, form.box.right, gone));
  }();

  /// The whole vesicle's silhouette, for its shadow.
  late final Path _rightOutline = () {
    final TubeCourse t = form.right;
    return _polygon(<Offset>[
      for (int i = 0; i < t.length; i++) t.at(i, 1),
      for (int i = t.length - 1; i >= 0; i--) t.at(i, -1),
    ]);
  }();

  /// [lines] as creases [width] wide tapering to nothing over [taper] at
  /// each end, one path.
  Path _tapered(List<List<Offset>> lines, double width, double taper) {
    final Path path = Path();
    final double half = form.mm(width) / 2;
    final double over = form.mm(taper);
    for (final List<Offset> line in lines) {
      final List<double> along = <double>[0];
      for (int i = 1; i < line.length; i++) {
        along.add(along.last + (line[i] - line[i - 1]).distance);
      }
      final double total = along.last;
      final int n = line.length;
      final List<Offset> left = <Offset>[];
      final List<Offset> right = <Offset>[];
      for (int i = 0; i < n; i++) {
        final Offset t =
            line[math.min(n - 1, i + 1)] - line[math.max(0, i - 1)];
        final double length = t.distance;
        final Offset across = length <= 0
            ? Offset.zero
            : Offset(-t.dy, t.dx) / length;
        final double w =
            half *
            _smooth(along[i] / over) *
            _smooth((total - along[i]) / over);
        left.add(line[i] + across * w);
        right.add(line[i] - across * w);
      }
      path.addPolygon(<Offset>[...left, ...right.reversed], true);
    }
    return path;
  }

  static Path _polygon(List<Offset> points) => Path()..addPolygon(points, true);

  // The shadows.

  void _paintShadow(Canvas canvas, Path shape) {
    canvas.save();
    canvas.translate(
      form.mm(SeminalVesicleStyle.shadowX),
      form.mm(SeminalVesicleStyle.shadowY),
    );
    final Color shadow = inks.shadow;
    canvas.drawPath(
      shape,
      Paint()
        ..color = shadow.withValues(alpha: SeminalVesicleStyle.shadowAlpha),
    );
    canvas.drawPath(
      shape,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = form.mm(SeminalVesicleStyle.shadowSoft)
        ..strokeJoin = StrokeJoin.round
        ..color = shadow.withValues(alpha: 0.12),
    );
    canvas.restore();
  }

  // Drawing.

  /// What the vesicles and what is drawn round them cover, their shadows
  /// included: the room a layer of it needs.
  late final Rect bounds = () {
    Rect box = form.box.expandToInclude(_bounds(form.prostate));
    for (final TubeCourse t in form.beside) {
      for (int i = 0; i < t.length; i++) {
        box = box.expandToInclude(
          Rect.fromCircle(center: t.centres[i], radius: t.radius[i]),
        );
      }
    }
    return box.inflate(
      form.mm(SeminalVesicleStyle.shadowY + SeminalVesicleStyle.shadowSoft),
    );
  }();

  /// Builds every mesh and path a frame will draw.
  void prepare() => <Object?>[
    _prostateMesh,
    _arteryMesh,
    _rightMesh,
    _leftDuctMesh,
    _deferensMesh,
    _ejaculatoryMesh,
    _coilMesh,
    _sac,
    _lumen,
    _meshes,
    _septa,
    _pits,
    _openedAmpulla,
    _ampullaLining,
    _ampullaFolds,
    _prostatePath,
    _prostateEdge,
    _rightOutline,
    bounds,
  ];

  /// Draws it all, in the scene's units at the vesicles' real size; [line]
  /// is a pixel.
  void paint(Canvas canvas, double line) {
    // The prostate's base below, fading out; the arteries coming in from
    // the sides, under the vesicles.
    canvas.save();
    canvas.clipPath(_prostatePath);
    _draw(canvas, _prostateMesh);
    canvas.restore();
    _draw(canvas, _arteryMesh);
    // The whole vesicle on the body's right: its shadow, its coiled sac
    // and the creases between its coils.
    _paintShadow(canvas, _rightOutline);
    _draw(canvas, _rightMesh);
    _draw(canvas, _coilMesh);
    // The opened vesicle on the body's left: its shadow, its duct a lit
    // tube, its cut wall, and inside it its mucosa, the honeycomb cut into
    // it, the septa between its coils and the diverticula's pits.
    _paintShadow(canvas, _outline);
    _draw(canvas, _leftDuctMesh);
    canvas.drawPath(_sac, Paint()..color = _wall);
    canvas.drawPath(_lumen, Paint()..color = _home);
    canvas.save();
    canvas.clipPath(_lumen);
    _paintMeshes(canvas, line);
    _paintFolds(
      canvas,
      line,
      _septa,
      SeminalVesicleStyle.septum,
      SeminalVesicleStyle.septumAlpha,
      SeminalVesicleStyle.septumFloor,
    );
    _paintPits(canvas);
    canvas.restore();
    _paintCoatLine(canvas, line, _lumen);
    // The deferent ducts over the vesicles' upper ends and down their
    // medial margins; the one on the body's left laid open along its
    // ampulla, its lining pale and folded; the ejaculatory ducts going
    // into the base.
    _draw(canvas, _deferensMesh);
    canvas.drawPath(_openedAmpulla, Paint()..color = _wall);
    canvas.drawPath(_ampullaLining, Paint()..color = _lining);
    canvas.save();
    canvas.clipPath(_ampullaLining);
    _paintFolds(
      canvas,
      line,
      _ampullaFolds,
      SeminalVesicleStyle.fold,
      SeminalVesicleStyle.foldAlpha,
      SeminalVesicleStyle.septumFloor,
    );
    canvas.restore();
    _paintCoatLine(canvas, line, _ampullaLining);
    _draw(canvas, _ejaculatoryMesh);
    // The edges, as the other specimens' outlines are edged: the
    // prostate's, fading out with it, and the opened vesicle's.
    canvas.drawPath(
      _prostatePath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = line
        ..strokeJoin = StrokeJoin.round
        ..shader = _prostateEdge,
    );
    canvas.drawPath(
      _outline,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = line
        ..strokeJoin = StrokeJoin.round
        ..color = inks
            .lit(SeminalVesicleStyle.edgeLit)
            .withValues(alpha: SeminalVesicleStyle.edgeAlpha),
    );
  }

  /// The wall's cut edge where it meets the mucosa or the lining, in the
  /// shadow ink, never thinner than a pixel or so.
  void _paintCoatLine(Canvas canvas, double line, Path edge) => canvas.drawPath(
    edge,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(
        form.mm(SeminalVesicleStyle.coatLine),
        SeminalVesicleStyle.coatLineFloor * line,
      )
      ..strokeJoin = StrokeJoin.round
      ..color = inks.shadow.withValues(
        alpha: SeminalVesicleStyle.coatLineAlpha,
      ),
  );

  /// The honeycomb: the light on each fold's far side, toward the lamp,
  /// and the crease along it, never thinner than a pixel or so.
  void _paintMeshes(Canvas canvas, double line) {
    final double width = math.max(
      form.mm(SeminalVesicleStyle.mesh),
      SeminalVesicleStyle.meshFloor * line,
    );
    canvas.save();
    final Offset toward =
        _light.screen * form.mm(SeminalVesicleStyle.meshLight);
    canvas.translate(toward.dx, toward.dy);
    canvas.drawPath(
      _meshes,
      _lines(
        width,
        inks
            .lit(SeminalVesicleStyle.meshLightLit)
            .withValues(alpha: SeminalVesicleStyle.meshLightAlpha),
      ),
    );
    canvas.restore();
    canvas.drawPath(
      _meshes,
      _lines(
        width,
        inks.shadow.withValues(alpha: SeminalVesicleStyle.meshAlpha),
      ),
    );
  }

  static Paint _lines(double width, Color colour) => Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = width
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..color = colour;

  /// Folds across a lumen: the light on each fold's far side, toward the
  /// lamp, and the crease along it, [width] wide at [alpha], never thinner
  /// than [floor] pixels.
  void _paintFolds(
    Canvas canvas,
    double line,
    Path creases,
    double width,
    double alpha,
    double floor,
  ) {
    canvas.save();
    final Offset toward =
        _light.screen * form.mm(SeminalVesicleStyle.foldLight);
    canvas.translate(toward.dx, toward.dy);
    canvas.drawPath(
      creases,
      Paint()
        ..color = inks
            .lit(SeminalVesicleStyle.foldLightLit)
            .withValues(alpha: SeminalVesicleStyle.foldLightAlpha),
    );
    canvas.restore();
    final Color cleft = inks.shadow.withValues(alpha: alpha);
    canvas.drawPath(creases, Paint()..color = cleft);
    final double least = floor * line;
    if (form.mm(width) < least) {
      canvas.drawPath(
        creases,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = least - form.mm(width)
          ..strokeJoin = StrokeJoin.round
          ..color = cleft,
      );
    }
  }

  /// The diverticula's pits: a hair of light on the lip toward the lamp,
  /// and the pit dark.
  void _paintPits(Canvas canvas) {
    canvas.save();
    final Offset toward =
        _light.screen * form.mm(SeminalVesicleStyle.lipOffset);
    canvas.translate(toward.dx, toward.dy);
    canvas.drawPath(
      _pits,
      Paint()
        ..color = inks
            .lit(SeminalVesicleStyle.lipLit)
            .withValues(alpha: SeminalVesicleStyle.lipAlpha),
    );
    canvas.restore();
    canvas.drawPath(
      _pits,
      Paint()
        ..color = inks.shadow.withValues(alpha: SeminalVesicleStyle.pitAlpha),
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

    add('prostate', _layProstate);
    add('arteries', _layArteries);
    add('vesicle', _layRight);
    add('duct', _layLeftDuct);
    add('deferens', _layDeferens);
    add('ejaculatory', _layEjaculatory);
    return out;
  }

  /// The colours the opened vesicle's parts are filled in, by name. For
  /// tests.
  @visibleForTesting
  Map<String, Color> get fills => <String, Color>{
    'mucosa': _home,
    'wall': _wall,
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

double _smooth(double t) {
  final double x = t.clamp(0.0, 1.0);
  return x * x * (3 - 2 * x);
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
