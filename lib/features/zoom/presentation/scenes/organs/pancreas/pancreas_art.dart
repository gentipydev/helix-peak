import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../../domain/cell_archetypes.dart';
import '../../../zoom_inks.dart';
import '../../coloured_mesh.dart';
import '../../lobule_domes.dart';
import '../../lobules.dart';
import '../../sculpt.dart';
import '../../specimen_light.dart';
import '../../tube_course.dart';
import 'pancreas_form.dart';
import 'pancreas_style.dart';

/// The pancreas drawn as a fresh specimen under one lamp, among the organs
/// and vessels round it, with the stomach taken away: its lobules each a lit
/// dome, dark crevices between them; the duodenum round its head, the spleen
/// at its tail, the splenic artery along its upper border, the mesenteric
/// vessels down over its uncinate process, the bile duct coming down behind.
///
/// Where the zoom's cell lives is in the mark, by its kind and never by
/// gene: the islets, a dust of them through the gland, for an endocrine
/// cell; for a duct cell the ducts, the gland's front cut away along the
/// main one to show them; the gland's lobules themselves for any other.
///
/// Everything costly is built once, for one form, one kind of cell and one
/// set of inks: meshes in the scene's units, so a frame only hands them on.
final class PancreasArt {
  PancreasArt(this.form, this.inks, {required this.cell})
    : _light = SpecimenLight(SpecimenLamp.zoom),
      _palette = SpecimenPalette(inks);

  final PancreasForm form;
  final ZoomInks inks;
  final CellShape cell;
  final SpecimenLight _light;
  final SpecimenPalette _palette;

  bool get _islets => cell == CellShape.endocrine;
  bool get _ducts => cell == CellShape.epithelial;

  /// The share of the mark in the lobules: for a cell that is the gland
  /// itself.
  double get _wash => _islets || _ducts ? 0 : PancreasStyle.wash;

  /// What shows between the lobules: the gland's crevices.
  static Color creviceOf(ZoomInks inks) =>
      inks.shade(PancreasStyle.creviceShade);

  late final Color _crevice = creviceOf(inks);

  late final SpecimenTone _gland = SpecimenTone(
    inks.lit(PancreasStyle.glandLit),
    inks.shadow,
  );
  late final SpecimenTone _duodenumTone = SpecimenTone(
    inks.lit(PancreasStyle.duodenumLit),
    inks.shadow,
  );
  late final SpecimenTone _spleenTone = SpecimenTone(
    inks.lit(PancreasStyle.spleenLit),
    inks.shadow,
  );
  late final SpecimenTone _bileTone = SpecimenTone(
    inks.lit(PancreasStyle.bileLit),
    inks.shadow,
  );
  late final SpecimenTone _arteryTone = SpecimenTone(
    Color.lerp(inks.blood, inks.ground, PancreasStyle.artery)!,
    inks.shadow,
  );
  late final SpecimenTone _veinTone = SpecimenTone(
    Color.lerp(inks.blood, inks.ground, PancreasStyle.vein)!,
    inks.shadow,
  );
  late final SpecimenTone _ductTone = SpecimenTone(inks.mark, inks.markDeep);

  static final List<double> _columns = <double>[
    for (final double u in PancreasStyle.columns.reversed) -u,
    ...PancreasStyle.columns.skip(1),
  ];

  // The gland.

  /// The lobules of the uncinate process, and the rest, each a lit dome.
  late final List<ui.Vertices> _uncinate = _build(
    (ColouredMesh mesh) => _layLobules(mesh, uncinate: true),
  );
  late final List<ui.Vertices> _main = _build(
    (ColouredMesh mesh) => _layLobules(mesh, uncinate: false),
  );

  /// The crevices between each pass's lobules, filled: each lobule grown by
  /// a crevice, so the grown shapes meet.
  late final Path _uncinateBed = _bed(uncinate: true);
  late final Path _mainBed = _bed(uncinate: false);

  Path _bed({required bool uncinate}) => Lobules.bed(
    form.lobules.where((Lobule lobule) => lobule.behind == uncinate),
    form.mm(PancreasStyle.lobules.cleft),
  );

  void _layLobules(ColouredMesh mesh, {required bool uncinate}) =>
      LobuleDomes.lay(
        mesh,
        form.lobules.where((Lobule lobule) => lobule.behind == uncinate),
        style: PancreasStyle.lobules,
        relief: form.relief,
        mm: form.mm,
        light: _light,
        palette: _palette,
        tone: _gland,
        wash: _wash,
        seed: uncinate ? 71 : 73,
      );

  // The islets, for an endocrine cell.

  /// Each pass's islets (the uncinate process's, then the rest), by their
  /// size: x and y of each, in turn.
  late final List<Float32List> _isletPoints = () {
    final int sizes = PancreasStyle.isletRadii.length;
    final List<List<double>> lists = List<List<double>>.generate(
      2 * sizes,
      (_) => <double>[],
    );
    int sizeOf(double radius) {
      int best = 0;
      for (int k = 1; k < sizes; k++) {
        if ((form.mm(PancreasStyle.isletRadii[k] / 1000) - radius).abs() <
            (form.mm(PancreasStyle.isletRadii[best] / 1000) - radius).abs()) {
          best = k;
        }
      }
      return best;
    }

    for (final Islet islet in <Islet>[...form.islets, form.siteIslet]) {
      final int pass = islet.uncinate ? 0 : 1;
      lists[pass * sizes + sizeOf(islet.radius)]
        ..add(islet.at.dx)
        ..add(islet.at.dy);
    }
    return <Float32List>[
      for (final List<double> l in lists) Float32List.fromList(l),
    ];
  }();

  void _paintIslets(Canvas canvas, double line, {required bool uncinate}) {
    final int sizes = PancreasStyle.isletRadii.length;
    final int pass = uncinate ? 0 : 1;
    for (int k = 0; k < sizes; k++) {
      final Float32List points = _isletPoints[pass * sizes + k];
      if (points.isEmpty) {
        continue;
      }
      final double r = form.mm(PancreasStyle.isletRadii[k] / 1000);
      final Paint paint = Paint()..strokeCap = StrokeCap.round;
      canvas.drawRawPoints(
        ui.PointMode.points,
        points,
        paint
          ..strokeWidth = math.max(
            PancreasStyle.halo * r,
            PancreasStyle.haloFloor * line,
          )
          ..color = inks.glow(PancreasStyle.haloAlpha),
      );
      canvas.drawRawPoints(
        ui.PointMode.points,
        points,
        paint
          ..strokeWidth = math.max(2 * r, PancreasStyle.coreFloor * line)
          ..color = inks.glow(0.95),
      );
    }
  }

  // The neighbours.

  late final List<ui.Vertices> _spleen = _build(_laySpleen);

  void _laySpleen(ColouredMesh mesh) {
    final double cell = form.mm(PancreasStyle.reliefCell);
    final Rect box = form.spleen.getBounds().inflate(cell);
    final int columns = (box.width / cell).ceil() + 1;
    final int rows = (box.height / cell).ceil() + 1;
    mesh.begin(columns * rows);
    final int first = mesh.next;
    for (int j = 0; j < rows; j++) {
      for (int i = 0; i < columns; i++) {
        final Offset p = box.topLeft + Offset(i * cell, j * cell);
        final (double nx, double ny, double nz) = form.spleenRelief.normalAt(p);
        mesh.vertex(
          p.dx,
          p.dy,
          _palette.colour(
            _spleenTone,
            _light.light(nx, ny, nz, form: nz) * PancreasStyle.neighbourLight,
            sheen: _light.sheen(nx, ny, nz) * PancreasStyle.neighbourLight,
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

  /// The duodenum behind the head, and its first part in front of it.
  late final List<ui.Vertices> _duodenumBack = _build(
    (ColouredMesh mesh) => _layTube(
      mesh,
      form.duodenum,
      _duodenumTone,
      from: form.duodenumFront,
      light: PancreasStyle.neighbourLight,
    ),
  );
  late final List<ui.Vertices> _duodenumFront = _build(
    (ColouredMesh mesh) => _layTube(
      mesh,
      form.duodenum,
      _duodenumTone,
      to: form.duodenumFront,
      light: PancreasStyle.neighbourLight,
    ),
  );

  /// The arteries behind the gland: the coeliac trunk, the splenic artery
  /// and its branches into the spleen, the hepatic artery.
  late final List<ui.Vertices> _arteries = _build((ColouredMesh mesh) {
    for (final TubeCourse tube in <TubeCourse>[
      ...form.hilarBranches,
      form.splenicArtery,
      form.hepaticArtery,
      form.coeliacTrunk,
    ]) {
      _layTube(mesh, tube, _arteryTone, light: PancreasStyle.neighbourLight);
    }
  });

  /// The superior mesenteric vein and artery, over the uncinate process.
  late final List<ui.Vertices> _mesenteric = _build((ColouredMesh mesh) {
    _layTube(
      mesh,
      form.mesentericVein,
      _veinTone,
      light: PancreasStyle.neighbourLight,
    );
    _layTube(
      mesh,
      form.mesentericArtery,
      _arteryTone,
      light: PancreasStyle.neighbourLight,
    );
  });

  late final List<ui.Vertices> _bile = _build(
    (ColouredMesh mesh) => _layTube(
      mesh,
      form.bileDuct,
      _bileTone,
      light: PancreasStyle.neighbourLight,
    ),
  );

  /// [tube]'s rows [from] to [to] as a lit tube in [tone], at [light] of
  /// the gland's own light.
  void _layTube(
    ColouredMesh mesh,
    TubeCourse tube,
    SpecimenTone tone, {
    int from = 0,
    int? to,
    double light = 1,
  }) => tube.lay(
    mesh,
    tone,
    _light,
    _palette,
    _columns,
    from: from,
    to: to,
    brightness: light,
  );

  /// A cut end of [tube] at [row]: its wall, cut, round its dark lumen.
  void _paintCut(Canvas canvas, TubeCourse tube, int row, SpecimenTone tone) {
    final Offset c = tube.centres[row];
    final Offset m = tube.across[row];
    final double r = tube.radius[row];
    final double light = _light.light(0, 0, 1) * PancreasStyle.neighbourLight;
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(math.atan2(m.dy, m.dx));
    final Rect wall = Rect.fromCenter(
      center: Offset.zero,
      width: 2 * r,
      height: 2 * r * PancreasStyle.cutLength,
    );
    canvas.drawOval(
      wall,
      Paint()..color = Color(_palette.colour(tone, light * 1.15)),
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset.zero,
        width: wall.width * (1 - PancreasStyle.cutWall),
        height: wall.height * (1 - PancreasStyle.cutWall),
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

  // The shadows.

  /// The shapes that cast a shadow on what lies behind: the gland, the
  /// spleen and the duodenum.
  late final Path _casting = () {
    final TubeCourse duodenum = form.duodenum;
    final List<Offset> side = <Offset>[
      for (int i = 0; i < duodenum.length; i++) duodenum.at(i, 1),
      for (int i = duodenum.length - 1; i >= 0; i--) duodenum.at(i, -1),
    ];
    return Path()
      ..addPath(form.outline, Offset.zero)
      ..addPath(form.spleen, Offset.zero)
      ..addPolygon(side, true);
  }();

  /// The vessels' middles, for their shadows: each with its mean width.
  late final List<(Path, double)> _strands = <(Path, double)>[
    for (final TubeCourse tube in <TubeCourse>[
      form.splenicArtery,
      form.hepaticArtery,
      form.mesentericVein,
      form.mesentericArtery,
      form.bileDuct,
    ])
      (tube.line, 2 * _mean(tube.radius)),
  ];

  void _paintShadows(Canvas canvas) {
    canvas.save();
    canvas.translate(
      PancreasStyle.shadowX * form.scale,
      PancreasStyle.shadowY * form.scale,
    );
    final Color shadow = inks.shadow;
    canvas.drawPath(
      _casting,
      Paint()..color = shadow.withValues(alpha: PancreasStyle.shadowAlpha),
    );
    canvas.drawPath(
      _casting,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = PancreasStyle.shadowSoft * form.scale
        ..strokeJoin = StrokeJoin.round
        ..color = shadow.withValues(alpha: 0.12),
    );
    for (final (Path line, double width) in _strands) {
      canvas.drawPath(
        line,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = width
          ..strokeCap = StrokeCap.round
          ..color = shadow.withValues(alpha: 0.25),
      );
    }
    canvas.restore();
  }

  // The window, for a duct cell.

  late final Color _cut = Color(
    _palette.colour(
      SpecimenTone(inks.lit(PancreasStyle.cutLit), inks.shadow),
      _light.light(0, 0, 1),
    ),
  );

  /// The lobules' outlines, which show on the cut face as its septa.
  late final Path _septa = () {
    final Path path = Path();
    for (final Lobule lobule in form.lobules) {
      lobule.addTo(path);
    }
    return path;
  }();

  late final List<ui.Vertices> _ductMeshes = _build((ColouredMesh mesh) {
    _layTube(mesh, form.mainDuct, _ductTone);
    _layTube(mesh, form.accessoryDuct, _ductTone);
  });

  /// The cut's edge: in shade where its wall faces away from the light, lit
  /// where it faces it.
  late final List<ui.Vertices> _lip = _build((ColouredMesh mesh) {
    final List<(Offset, Offset)> edge = form.windowEdge;
    if (edge.length < 3) {
      return;
    }
    final Offset toward = _light.screen;
    final double jump = form.mm(1.5);
    final Color wall = inks.lit(0.62);
    // The edge in runs, broken where it jumps from one outline to the next.
    final List<List<(Offset, Offset)>> runs = <List<(Offset, Offset)>>[
      <(Offset, Offset)>[edge.first],
    ];
    for (int i = 1; i < edge.length; i++) {
      if ((edge[i].$1 - edge[i - 1].$1).distance > jump) {
        runs.add(<(Offset, Offset)>[]);
      }
      runs.last.add(edge[i]);
    }
    for (final List<(Offset, Offset)> run in runs) {
      if (run.length < 2) {
        continue;
      }
      final bool closed = (run.first.$1 - run.last.$1).distance <= jump;
      mesh.begin(2 * run.length);
      final int first = mesh.next;
      for (final (Offset p, Offset out) in run) {
        final double facing = out.dx * toward.dx + out.dy * toward.dy;
        final double width = form.mm(
          facing > 0 ? PancreasStyle.lipShadow : PancreasStyle.lipWall,
        );
        final int colour = facing > 0
            ? SpecimenPalette.packColour(
                inks.shadow,
                PancreasStyle.lipShadowAlpha * facing,
              )
            : SpecimenPalette.packColour(
                wall,
                PancreasStyle.lipWallAlpha * -facing,
              );
        final Offset inner = p - out * width;
        mesh.vertex(p.dx, p.dy, colour);
        mesh.vertex(inner.dx, inner.dy, _clear(colour));
      }
      final int count = run.length;
      for (int i = 0; i < (closed ? count : count - 1); i++) {
        final int a = first + 2 * i;
        final int b = first + 2 * ((i + 1) % count);
        mesh.triangle(a, b, a + 1);
        mesh.triangle(b, b + 1, a + 1);
      }
    }
  });

  void _paintWindow(Canvas canvas, double line) {
    canvas.save();
    canvas.clipPath(form.window);
    canvas.drawPath(form.window, Paint()..color = _cut);
    canvas.drawPath(
      _septa,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = PancreasStyle.septum * line
        ..color = _crevice.withValues(alpha: 0.55),
    );
    _draw(canvas, _bile);
    final double branch = math.max(
      form.mm(PancreasStyle.branchWidth),
      PancreasStyle.coreFloor * line,
    );
    Sculpt.glowingStroke(canvas, form.branches, inks, width: branch);
    final Path? toSite = form.siteBranch;
    if (toSite != null) {
      Sculpt.glowingStroke(canvas, toSite, inks, width: 1.3 * branch);
    }
    for (final TubeCourse duct in <TubeCourse>[
      form.mainDuct,
      form.accessoryDuct,
    ]) {
      Sculpt.glowingStroke(
        canvas,
        duct.line,
        inks,
        width: math.max(2 * _mean(duct.radius), branch),
        alpha: 0.6,
      );
    }
    _draw(canvas, _ductMeshes);
    _draw(canvas, _lip);
    canvas.restore();
  }

  // Drawing.

  /// What the gland and its neighbours cover, their shadows included: the
  /// room a layer of them needs.
  late final Rect bounds = () {
    Rect box = form.outline.getBounds().expandToInclude(
      form.spleen.getBounds(),
    );
    for (final TubeCourse tube in <TubeCourse>[
      form.duodenum,
      form.splenicArtery,
      form.hepaticArtery,
      form.mesentericVein,
      form.mesentericArtery,
      form.bileDuct,
    ]) {
      double widest = 0;
      for (final double r in tube.radius) {
        widest = math.max(widest, r);
      }
      box = box.expandToInclude(tube.line.getBounds().inflate(widest));
    }
    return box.inflate(
      (PancreasStyle.shadowY + PancreasStyle.shadowSoft) * form.scale,
    );
  }();

  /// Builds every mesh and path a frame will draw, for this kind of cell.
  void prepare() => <Object?>[
    _uncinate,
    _main,
    _uncinateBed,
    _mainBed,
    _spleen,
    _duodenumBack,
    _duodenumFront,
    _arteries,
    _mesenteric,
    _bile,
    _casting,
    _strands,
    bounds,
    if (_islets) _isletPoints,
    if (_ducts) ...<Object?>[_septa, _ductMeshes, _lip, form.branches],
  ];

  /// Draws it all, in the scene's units at the gland's real size; [line] is
  /// a pixel.
  void paint(Canvas canvas, double line) {
    _paintShadows(canvas);
    // Behind the gland.
    canvas.save();
    canvas.clipPath(form.spleen);
    _draw(canvas, _spleen);
    canvas.restore();
    _draw(canvas, _arteries);
    _draw(canvas, _duodenumBack);
    final TubeCourse duodenum = form.duodenum;
    if (duodenum.cutEnd) {
      _paintCut(canvas, duodenum, duodenum.length - 1, _duodenumTone);
    }
    _draw(canvas, _bile);
    // The uncinate process, behind the mesenteric vessels.
    canvas.drawPath(_uncinateBed, Paint()..color = _crevice);
    _draw(canvas, _uncinate);
    if (_islets) {
      _paintIslets(canvas, line, uncinate: true);
    }
    _draw(canvas, _mesenteric);
    // The rest of the gland, over the vessels' upper ends.
    canvas.drawPath(_mainBed, Paint()..color = _crevice);
    _draw(canvas, _main);
    if (_islets) {
      _paintIslets(canvas, line, uncinate: false);
    }
    if (_ducts) {
      _paintWindow(canvas, line);
    }
    // The duodenum's first part, in front of the head.
    _draw(canvas, _duodenumFront);
    if (duodenum.cutStart) {
      _paintCut(canvas, duodenum, 0, _duodenumTone);
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

    add('uncinate', (ColouredMesh m) => _layLobules(m, uncinate: true));
    add('lobules', (ColouredMesh m) => _layLobules(m, uncinate: false));
    add('spleen', _laySpleen);
    add(
      'duodenum',
      (ColouredMesh m) => _layTube(m, form.duodenum, _duodenumTone),
    );
    add('vessels', (ColouredMesh m) {
      for (final TubeCourse tube in <TubeCourse>[
        ...form.hilarBranches,
        form.splenicArtery,
        form.hepaticArtery,
        form.coeliacTrunk,
        form.mesentericArtery,
      ]) {
        _layTube(m, tube, _arteryTone);
      }
      _layTube(m, form.mesentericVein, _veinTone);
    });
    add('bile', (ColouredMesh m) => _layTube(m, form.bileDuct, _bileTone));
    if (_ducts) {
      add('ducts', (ColouredMesh m) {
        _layTube(m, form.mainDuct, _ductTone);
        _layTube(m, form.accessoryDuct, _ductTone);
      });
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

double _mean(Float64List values) {
  double sum = 0;
  for (final double v in values) {
    sum += v;
  }
  return values.isEmpty ? 0 : sum / values.length;
}

int _clear(int colour) => colour & ((1 << 24) - 1);
