import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../../domain/cell_archetypes.dart';
import '../../../zoom_inks.dart';
import '../../coloured_mesh.dart';
import '../../cut_face.dart';
import '../../specimen_light.dart';
import '../../tube_course.dart';
import 'heart_form.dart';
import 'heart_style.dart';

/// Where in the heart the zoom's cell lives, which its drawing lights in
/// the mark: the epicardium, its surface, for an epithelial cell, as the
/// Atlas's epicardial cells are drawn; the myocardium, the heart muscle,
/// for a cardiomyocyte and for every other cell, the fibroblasts, the
/// capillaries' endothelium and the immune cells that live among its
/// fibres.
enum HeartHome {
  myocardium,
  epicardium;

  /// Where a cell of [shape] lives.
  static HeartHome of(CellShape shape) =>
      shape == CellShape.epithelial ? epicardium : myocardium;
}

/// The heart cut open from front to back, drawn as a specimen under the
/// zoom's one lamp: its muscle flat in the mark where the zoom's cell lives
/// there, as the brain's cortex is, cut sharply along its inner edge, its
/// papillary muscles and the moderator band with it; the chambers and the
/// great vessels emptied, in shade, rimmed with shadow where their edges
/// face the lamp and with light where they turn from it; the great
/// vessels' walls cut faces, the arteries' paler than the veins'; the
/// valves' leaflets and cusps pale and thin, the chordae fine; the fat of
/// the grooves, the coronary arteries cut across in it in the blood red.
///
/// For an epicardial cell the muscle is a deep cut face lit as the other
/// specimens' are, and the epicardium, its surface, is drawn in the mark.
///
/// Everything costly is built once, for one form, one home and one set of
/// inks: meshes and paths in the scene's units, so a frame only hands them
/// on.
final class HeartArt {
  HeartArt(this.form, this.inks, {required this.home})
    : _light = SpecimenLight(SpecimenLamp.zoom),
      _palette = SpecimenPalette(inks);

  final HeartForm form;
  final ZoomInks inks;
  final HeartHome home;
  final SpecimenLight _light;
  final SpecimenPalette _palette;

  bool get _muscleHome => home == HeartHome.myocardium;

  late final CutFace _face = CutFace(
    _light,
    _palette,
    sheen: HeartStyle.cutSheen,
  );

  /// A cut face cushioned a little across.
  static const List<(double, double, double)> _cut = <(double, double, double)>[
    (0, HeartStyle.cushion, 0),
    (0.5, 0, 0),
    (1, -HeartStyle.cushion, 0),
  ];

  /// The chambers' tone, which the step from the body draws the heart's
  /// bed in.
  static Color bedOf(ZoomInks inks) => inks.shade(HeartStyle.cavityShade);

  /// The heart muscle's one tone where the zoom's cell lives there: the
  /// mark over a neutral, as the brain's cortex is.
  static Color muscleOf(ZoomInks inks) => Color.alphaBlend(
    inks.glow(HeartStyle.muscleMark),
    inks.lit(HeartStyle.muscleLit),
  );

  late final Color _cavity = bedOf(inks);
  late final Color _muscle = _muscleHome
      ? muscleOf(inks)
      : inks.lit(HeartStyle.muscleCut);
  late final Color _leaflet = inks.lit(HeartStyle.leafletLit);

  SpecimenTone _tone(Color colour) => SpecimenTone(colour, inks.shadow);

  late final SpecimenTone _muscleTone = _tone(inks.lit(HeartStyle.muscleCut));

  /// The vessels where they are whole: lit tubes in the blood red, the
  /// arteries eased toward the ground less than the veins, as the other
  /// specimens' are.
  late final SpecimenTone _wholeArtery = _tone(
    Color.lerp(inks.blood, inks.ground, HeartStyle.wholeArtery)!,
  );
  late final SpecimenTone _wholeVein = _tone(
    Color.lerp(inks.blood, inks.ground, HeartStyle.wholeVein)!,
  );

  static final List<double> _round = <double>[
    for (final double u in HeartStyle.tubeColumns.reversed) -u,
    ...HeartStyle.tubeColumns.skip(1),
  ];

  // The muscle: one path for each chamber's, and the papillary muscles and
  // the moderator band.

  late final Path _atria = _union(<List<Offset>>[form.raMuscle, form.laMuscle]);
  late final Path _ventricles = _union(<List<Offset>>[
    form.lvMuscle,
    form.rvMuscle,
  ]);
  late final Path _columns = _union(<List<Offset>>[
    ...form.papillary,
    form.moderator,
  ]);

  /// Where the muscle is not the zoom's cell's home, its cut faces lit.
  late final List<ui.Vertices> _atrialFaces = _build((ColouredMesh mesh) {
    if (_muscleHome) {
      return;
    }
    for (final (List<Offset> a, List<Offset> b) in form.bands.skip(3)) {
      _face.lay(mesh, a, b, (int _) => _muscleTone, _cut);
    }
  });
  late final List<ui.Vertices> _ventricularFaces = _build((ColouredMesh mesh) {
    if (_muscleHome) {
      return;
    }
    for (final (List<Offset> a, List<Offset> b) in form.bands.take(3)) {
      _face.lay(mesh, a, b, (int _) => _muscleTone, _cut);
    }
  });

  // The cavities and lumens, each with its rim.

  late final List<(Path, List<ui.Vertices>)> _atrialCavities =
      <(Path, List<ui.Vertices>)>[
        _opening(form.raCavity.shape, form.raCavity.rims),
        _opening(form.laCavity.shape, form.laCavity.rims),
      ];
  late final List<(Path, List<ui.Vertices>)> _ventricularCavities =
      <(Path, List<ui.Vertices>)>[
        _opening(form.lvCavity.shape, form.lvCavity.rims),
        _opening(form.rvCavity.shape, form.rvCavity.rims),
      ];

  /// An opening's path and the mesh of its rim: a shadow just inside the
  /// edges that face the lamp, light just inside those that turn from it.
  (Path, List<ui.Vertices>) _opening(
    List<Offset> shape,
    List<List<Offset>> rims, {
    double fadeIn = 0,
  }) {
    final Path path = _polygon(shape);
    return (
      path,
      _build((ColouredMesh mesh) {
        for (final List<Offset> rim in rims) {
          _rim(mesh, rim, path, fadeIn: fadeIn);
        }
      }),
    );
  }

  /// [rim]'s shadow and light, coming up over [fadeIn] from its start.
  void _rim(
    ColouredMesh mesh,
    List<Offset> rim,
    Path inside, {
    double fadeIn = 0,
  }) {
    final int n = rim.length;
    if (n < 2) {
      return;
    }
    double along = 0;
    final Offset toward = _light.screen;
    final Color lit = inks.lit(HeartStyle.leafletLit);
    final double probe = form.mm(0.3);
    mesh.begin(2 * n);
    final int first = mesh.next;
    for (int i = 0; i < n; i++) {
      final Offset t = rim[math.min(n - 1, i + 1)] - rim[math.max(0, i - 1)];
      final double length = t.distance;
      Offset out = length <= 0 ? Offset.zero : Offset(t.dy, -t.dx) / length;
      if (inside.contains(rim[i] + out * probe)) {
        out = -out;
      }
      if (i > 0) {
        along += (rim[i] - rim[i - 1]).distance;
      }
      final double shown = fadeIn <= 0
          ? 1
          : math.min(1, along / fadeIn) * math.min(1, along / fadeIn);
      final double facing = (out.dx * toward.dx + out.dy * toward.dy) * shown;
      final double width = form.mm(
        facing > 0 ? HeartStyle.lipShadow : HeartStyle.lipLight,
      );
      final int colour = facing > 0
          ? SpecimenPalette.packColour(
              inks.shadow,
              HeartStyle.lipShadowAlpha * facing,
            )
          : SpecimenPalette.packColour(lit, HeartStyle.lipLightAlpha * -facing);
      final Offset inner = rim[i] - out * width;
      mesh.vertex(rim[i].dx, rim[i].dy, colour);
      mesh.vertex(inner.dx, inner.dy, colour & ((1 << 24) - 1));
    }
    for (int i = 0; i + 1 < n; i++) {
      final int a = first + 2 * i;
      final int b = a + 2;
      mesh
        ..triangle(a, b, a + 1)
        ..triangle(b, b + 1, a + 1);
    }
  }

  // The great vessels, cut open: their walls, their lumens and rims.

  late final List<_Vessel> _behind = <_Vessel>[
    for (final HeartVessel v in form.behind) _vessel(v),
  ];
  late final List<_Vessel> _veins = <_Vessel>[
    for (final HeartVessel v in form.veins) _vessel(v),
  ];
  late final List<_Vessel> _branches = <_Vessel>[
    for (final HeartVessel v in form.branches) _vessel(v),
  ];
  late final _Vessel _aorta = _vessel(form.aorta);
  late final _Vessel _infundibulum = _vessel(form.infundibulum);
  late final List<_Vessel> _pulmonary = <_Vessel>[
    for (final HeartVessel v in form.pulmonary) _vessel(v),
  ];

  _Vessel _vessel(HeartVessel v) {
    final (Path lumen, List<ui.Vertices> rim) = v.lumen.isEmpty
        ? (Path(), const <ui.Vertices>[])
        : _opening(
            v.lumen,
            v.rims,
            fadeIn: v.muscle ? form.mm(HeartStyle.outflowTaper) : 0,
          );
    return _Vessel(
      source: v,
      tube: !v.whole
          ? const <ui.Vertices>[]
          : _build(
              (ColouredMesh mesh) => v.course.lay(
                mesh,
                v.artery ? _wholeArtery : _wholeVein,
                _light,
                _palette,
                _round,
                from: v.cut,
                brightness: HeartStyle.tubeLight,
              ),
            ),
      outer: _union(<List<Offset>>[
        for (final (List<Offset> a, List<Offset> b) in v.walls)
          <Offset>[...a, ...b.reversed],
      ]),
      walls: v.muscle && _muscleHome
          ? const <ui.Vertices>[]
          : _build((ColouredMesh mesh) {
              for (final (List<Offset> a, List<Offset> b) in v.walls) {
                _face.lay(
                  mesh,
                  a,
                  b,
                  (int _) => v.muscle
                      ? _muscleTone
                      : v.artery
                      ? _wholeArtery
                      : _wholeVein,
                  _cut,
                  brightness: v.muscle ? 1 : HeartStyle.tubeLight,
                );
              }
            }),
      muscle: v.muscle,
      lumen: lumen,
      rim: rim,
    );
  }

  void _paintVessel(Canvas canvas, _Vessel v) {
    _draw(canvas, v.tube);
    if (v.source.whole && v.source.endCut) {
      _paintEnd(canvas, v.source);
    }
    if (v.source.cut <= 0) {
      return;
    }
    if (v.muscle) {
      canvas.drawPath(v.outer, Paint()..color = _muscle);
    }
    _draw(canvas, v.walls);
    _paintOpening(canvas, v.lumen, v.rim);
  }

  /// The far end of [v], cut as an anatomy plate cuts what it has taken
  /// away: its wall round its dark lumen.
  void _paintEnd(Canvas canvas, HeartVessel v) {
    final TubeCourse tube = v.course;
    final int row = tube.length - 1;
    final Offset c = tube.centres[row];
    final Offset m = tube.across[row];
    final double r = tube.radius[row];
    final SpecimenTone tone = v.artery ? _wholeArtery : _wholeVein;
    final double light = _light.light(0, 0, 1) * HeartStyle.tubeLight;
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(math.atan2(m.dy, m.dx));
    final Rect wall = Rect.fromCenter(
      center: Offset.zero,
      width: 2 * r,
      height: 2 * r * HeartStyle.endLength,
    );
    canvas.drawOval(
      wall,
      Paint()..color = Color(_palette.colour(tone, light * 1.15)),
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset.zero,
        width: wall.width * (1 - HeartStyle.endWall),
        height: wall.height * (1 - HeartStyle.endWall),
      ),
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0.3, 0.4),
          colors: <Color>[
            inks.shadow,
            Color(_palette.colour(tone, light * 0.35)),
          ],
        ).createShader(wall),
    );
    canvas.restore();
  }

  void _paintOpening(Canvas canvas, Path path, List<ui.Vertices> rim) {
    canvas.drawPath(path, Paint()..color = _cavity);
    if (rim.isEmpty) {
      return;
    }
    canvas.save();
    canvas.clipPath(path);
    _draw(canvas, rim);
    canvas.restore();
  }

  // The valves and the chordae.

  late final Path _leaflets = _union(form.leaflets);
  late final Path _cusps = _union(form.cusps);
  late final Path _chordae = () {
    final Path path = Path();
    for (final (Offset a, Offset b) in form.chordae) {
      path
        ..moveTo(a.dx, a.dy)
        ..lineTo(b.dx, b.dy);
    }
    return path;
  }();

  // The fat and the coronary arteries.

  late final Path _fat = _union(form.fat);
  late final Color _fatColour = Color.lerp(
    inks.lit(HeartStyle.fatLit),
    inks.nerve,
    HeartStyle.fatWarmth,
  )!;
  late final Color _artery = Color.lerp(
    inks.blood,
    inks.ground,
    HeartStyle.coronary,
  )!;

  // The lines.

  late final Path _atrialEdges = _lines(form.atrialEdges);
  late final Path _innerEdges = _lines(form.innerEdges);
  late final Path _columnEdges = _lines(form.columnEdges);
  late final Path _ventricularCavityShape = _union(<List<Offset>>[
    form.lvCavity.shape,
    form.rvCavity.shape,
  ]);

  static Path _lines(List<List<Offset>> lines) {
    final Path path = Path();
    for (final List<Offset> line in lines) {
      path.addPolygon(line, false);
    }
    return path;
  }

  Paint _edgePaint(double line) => Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = math.max(
      form.mm(HeartStyle.edgeLine),
      HeartStyle.edgeLineFloor * line,
    )
    ..strokeJoin = StrokeJoin.round
    ..color = inks.shadow.withValues(alpha: HeartStyle.edgeLineAlpha);
  late final Path _epicardium = () {
    final Path path = Path();
    for (final List<Offset> run in form.epicardium) {
      path.addPolygon(run, false);
    }
    return path;
  }();

  // The shadow.

  void _paintShadow(Canvas canvas) {
    canvas.save();
    canvas.translate(form.mm(HeartStyle.shadowX), form.mm(HeartStyle.shadowY));
    final Color shadow = inks.shadow;
    canvas.drawPath(
      form.outline,
      Paint()..color = shadow.withValues(alpha: HeartStyle.shadowAlpha),
    );
    canvas.drawPath(
      form.outline,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = form.mm(HeartStyle.shadowSoft)
        ..strokeJoin = StrokeJoin.round
        ..color = shadow.withValues(alpha: 0.12),
    );
    canvas.restore();
  }

  // Drawing.

  /// What the heart covers, its shadow included: the room a layer of it
  /// needs.
  late final Rect bounds = form.box.inflate(
    form.mm(HeartStyle.shadowY + HeartStyle.shadowSoft),
  );

  /// Builds every mesh and path a frame will draw.
  void prepare() => <Object?>[
    _atria,
    _ventricles,
    _columns,
    _atrialFaces,
    _ventricularFaces,
    _atrialCavities,
    _ventricularCavities,
    _behind,
    _veins,
    _branches,
    _aorta,
    _infundibulum,
    _pulmonary,
    _leaflets,
    _cusps,
    _chordae,
    _fat,
    _atrialEdges,
    _innerEdges,
    _columnEdges,
    _ventricularCavityShape,
    _epicardium,
    bounds,
  ];

  /// Draws it all, in the scene's units at the heart's real size; [line]
  /// is a pixel.
  void paint(Canvas canvas, double line) {
    _paintShadow(canvas);
    // Behind the atria: the right pulmonary artery and veins.
    for (final _Vessel v in _behind) {
      _paintVessel(canvas, v);
    }
    // The atria, and the veins that open into them.
    canvas.drawPath(_atria, Paint()..color = _muscle);
    _draw(canvas, _atrialFaces);
    for (final (Path path, List<ui.Vertices> rim) in _atrialCavities) {
      _paintOpening(canvas, path, rim);
    }
    canvas.drawPath(_atrialEdges, _edgePaint(line));
    for (final _Vessel v in _veins) {
      _paintVessel(canvas, v);
    }
    // The aorta, its branches, and its valve.
    for (final _Vessel v in _branches) {
      _paintVessel(canvas, v);
    }
    _paintVessel(canvas, _aorta);
    // The ventricles, their papillary muscles and the moderator band, the
    // chordae and the leaflets.
    canvas.drawPath(_ventricles, Paint()..color = _muscle);
    _draw(canvas, _ventricularFaces);
    for (final (Path path, List<ui.Vertices> rim) in _ventricularCavities) {
      _paintOpening(canvas, path, rim);
    }
    canvas.drawPath(_innerEdges, _edgePaint(line));
    canvas.drawPath(_columns, Paint()..color = _muscle);
    canvas.save();
    canvas.clipPath(_ventricularCavityShape);
    canvas.drawPath(_columnEdges, _edgePaint(line));
    canvas.restore();
    canvas.drawPath(
      _chordae,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(
          form.mm(HeartStyle.chorda),
          HeartStyle.chordaFloor * line,
        )
        ..strokeCap = StrokeCap.round
        ..color = inks
            .lit(HeartStyle.chordaLit)
            .withValues(alpha: HeartStyle.chordaAlpha),
    );
    canvas.drawPath(_leaflets, Paint()..color = _leaflet);
    // In front, the right ventricle's outflow and the pulmonary trunk, and
    // the valves at the roots of the great arteries.
    _paintVessel(canvas, _infundibulum);
    for (final _Vessel v in _pulmonary) {
      _paintVessel(canvas, v);
    }
    canvas.drawPath(_cusps, Paint()..color = _leaflet);
    // The fat of the grooves and the coronary arteries in it.
    canvas.drawPath(_fat, Paint()..color = _fatColour);
    for (final HeartCoronary c in form.coronaries) {
      canvas.drawCircle(
        c.centre,
        c.outer,
        Paint()..color = inks.lit(HeartStyle.coronaryWallLit),
      );
      canvas.drawCircle(c.centre, c.lumen, Paint()..color = _artery);
    }
    // The heart's own surface, its edge as the other specimens' is; or,
    // where the zoom's cell lives there, the epicardium in the mark.
    if (_muscleHome) {
      canvas.drawPath(
        _epicardium,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = line
          ..strokeJoin = StrokeJoin.round
          ..color = inks
              .lit(HeartStyle.edgeLit)
              .withValues(alpha: HeartStyle.edgeAlpha),
      );
    } else {
      canvas.drawPath(
        _epicardium,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(
            form.mm(HeartStyle.epicardium),
            HeartStyle.epicardiumFloor * line,
          )
          ..strokeJoin = StrokeJoin.round
          ..strokeCap = StrokeCap.round
          ..color = inks.glow(HeartStyle.epicardiumGlow),
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

    if (!_muscleHome) {
      add('muscle', (ColouredMesh mesh) {
        for (final (List<Offset> a, List<Offset> b) in form.bands) {
          _face.lay(mesh, a, b, (int _) => _muscleTone, _cut);
        }
      });
    }
    add('vessels', (ColouredMesh mesh) {
      for (final HeartVessel v in <HeartVessel>[
        ...form.behind,
        ...form.veins,
        ...form.branches,
        form.aorta,
        if (!_muscleHome) form.infundibulum,
        ...form.pulmonary,
      ]) {
        for (final (List<Offset> a, List<Offset> b) in v.walls) {
          _face.lay(
            mesh,
            a,
            b,
            (int _) => v.muscle
                ? _muscleTone
                : v.artery
                ? _wholeArtery
                : _wholeVein,
            _cut,
            brightness: v.muscle ? 1 : HeartStyle.tubeLight,
          );
        }
      }
    });
    add('rims', (ColouredMesh mesh) {
      for (final HeartCavity c in <HeartCavity>[
        form.raCavity,
        form.laCavity,
        form.lvCavity,
        form.rvCavity,
      ]) {
        final Path path = _polygon(c.shape);
        for (final List<Offset> rim in c.rims) {
          _rim(mesh, rim, path);
        }
      }
    });
    return out;
  }

  static Path _polygon(List<Offset> points) => Path()..addPolygon(points, true);

  static Path _union(List<List<Offset>> polygons) {
    Path out = Path();
    for (final List<Offset> p in polygons) {
      out = Path.combine(PathOperation.union, out, _polygon(p));
    }
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

/// A great vessel as drawn: its outer shape, its walls' meshes, its lumen
/// and its rim.
final class _Vessel {
  _Vessel({
    required this.source,
    required this.tube,
    required this.outer,
    required this.walls,
    required this.muscle,
    required this.lumen,
    required this.rim,
  });

  final HeartVessel source;
  final List<ui.Vertices> tube;
  final Path outer;
  final List<ui.Vertices> walls;
  final bool muscle;
  final Path lumen;
  final List<ui.Vertices> rim;
}
