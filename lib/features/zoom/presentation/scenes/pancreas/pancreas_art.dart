import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../domain/cell_archetypes.dart';
import '../../../domain/zoom_camera.dart';
import '../../zoom_inks.dart';
import '../coloured_mesh.dart';
import '../sculpt.dart';
import '../specimen_light.dart';
import '../tube_course.dart';
import 'pancreas_form.dart';
import 'pancreas_style.dart';

/// How the pancreas comes up on the step from the body, by how far the
/// organ has become its own (its scene's detail, 0 at the hand-over and 1
/// at its stop): its outline drawn in from the body's, the gland and its
/// neighbours coming up over it, and the figure's own parts giving way.
abstract final class PancreasStep {
  /// How far the outline has been drawn in from the body's to the gland's.
  static double settle(double detail) =>
      detail <= 0 ? 0 : smootherstep(detail / PancreasStyle.settle);

  /// How much of the gland and its neighbours shows.
  static double come(double detail) => detail <= 0
      ? 0
      : math.pow(math.min(1, detail), PancreasStyle.comePower).toDouble();

  /// How much of the figure's own parts round it still shows.
  static double figure(double detail) => 1 - detail.clamp(0.0, 1.0);
}

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

  Path _bed({required bool uncinate}) {
    final Path path = Path();
    final double grow = form.mm(PancreasStyle.cleft);
    for (final Lobule lobule in form.lobules) {
      if (lobule.uncinate == uncinate) {
        lobule.addTo(path, grow: grow);
      }
    }
    return path;
  }

  void _layLobules(ColouredMesh mesh, {required bool uncinate}) {
    const int rays = PancreasStyle.rays;
    const List<double> rings = PancreasStyle.rings;
    final math.Random random = math.Random(uncinate ? 71 : 73);
    final double feather =
        PancreasStyle.feather * form.mm(PancreasStyle.lobule);
    final double lobeRadius = form.mm(PancreasStyle.lobe) / 2;
    final double wash = _wash;
    final List<int> rim = List<int>.filled(rays, 0);
    for (final Lobule lobule in form.lobules) {
      if (lobule.uncinate != uncinate) {
        continue;
      }
      // Each lobe a little lighter or darker than the next, and each lobule
      // than the next in its lobe.
      final double tone =
          (1 + PancreasStyle.lobeTone * _jitter(lobule.lobeIndex)) *
          (1 + PancreasStyle.lobuleTone * (2 * random.nextDouble() - 1));
      // The lobe's own rounding, toward its edge.
      (double, double, double) rounded(
        Offset p,
        double nx,
        double ny,
        double nz,
        double tx,
        double ty,
      ) {
        Offset off = (p - lobule.lobe) / lobeRadius;
        if (off.distance > 1) {
          off = off / off.distance;
        }
        return _unit(
          nx + PancreasStyle.lobeTilt * off.dx + tx,
          ny + PancreasStyle.lobeTilt * off.dy + ty,
          nz,
        );
      }

      mesh.begin(1 + rays * (rings.length + 1));
      final int first = mesh.next;
      // Its top, nudged toward the light, where its sheen is.
      final (double, double, double) up = form.relief.normalAt(lobule.centre);
      final (double ux, double uy, double uz) = rounded(
        lobule.centre,
        up.$1,
        up.$2,
        up.$3,
        0,
        0,
      );
      final Offset top =
          lobule.centre + _light.screen * (PancreasStyle.nudge * lobule.radius);
      mesh.vertex(
        top.dx,
        top.dy,
        _palette.colour(
          _gland,
          _light.light(ux, uy, uz, form: up.$3) * tone,
          sheen: _light.sheen(ux, uy, uz),
          wash: wash,
        ),
      );
      for (int ring = 0; ring < rings.length; ring++) {
        final bool outer = ring == rings.length - 1;
        for (int k = 0; k < rays; k++) {
          final double depth = lobule.depth[k];
          final double tilt =
              (PancreasStyle.tilt +
                  (PancreasStyle.cleftTilt - PancreasStyle.tilt) * depth) *
              PancreasStyle.tilts[ring];
          final Offset p = lobule.at(k, rings[ring]);
          final Offset out = Lobule.direction(k);
          final (double nx, double ny, double nz) = form.relief.normalAt(p);
          final (double tx, double ty, double tz) = rounded(
            p,
            nx,
            ny,
            nz,
            tilt * out.dx,
            tilt * out.dy,
          );
          final int colour = _palette.colour(
            _gland,
            _light.light(tx, ty, tz, form: nz) * tone,
            occlusion: outer ? PancreasStyle.rimShade * depth : 0,
            sheen: _light.sheen(tx, ty, tz),
            wash: wash,
          );
          if (outer) {
            rim[k] = colour;
          }
          mesh.vertex(p.dx, p.dy, colour);
        }
      }
      // A feathered edge: the rim fading out across the crevice.
      for (int k = 0; k < rays; k++) {
        final Offset p =
            lobule.centre + Lobule.direction(k) * (lobule.reach[k] + feather);
        mesh.vertex(p.dx, p.dy, _clear(rim[k]));
      }
      for (int k = 0; k < rays; k++) {
        final int a = first + 1 + k;
        final int b = first + 1 + (k + 1) % rays;
        mesh.triangle(first, a, b);
        for (int band = 0; band < rings.length; band++) {
          final int a0 = a + band * rays;
          final int b0 = b + band * rays;
          mesh.triangle(a0, b0, a0 + rays);
          mesh.triangle(b0, b0 + rays, a0 + rays);
        }
      }
    }
  }

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
  }) {
    final int end = to ?? tube.length - 1;
    final int across = _columns.length;
    final int rows = end - from + 1;
    if (rows < 2) {
      return;
    }
    mesh.begin(rows * across);
    final int first = mesh.next;
    for (int i = from; i <= end; i++) {
      final Offset m = tube.across[i];
      for (final double u in _columns) {
        final Offset p = tube.at(i, u);
        final double nz = math.sqrt(math.max(0, 1 - u * u));
        final double nx = m.dx * u;
        final double ny = m.dy * u;
        mesh.vertex(
          p.dx,
          p.dy,
          _palette.colour(
            tone,
            _light.light(nx, ny, nz, form: nz) * light,
            sheen: _light.sheen(nx, ny, nz) * light,
            alpha: tube.shown[i],
          ),
        );
      }
    }
    for (int i = 0; i + 1 < rows; i++) {
      for (int j = 0; j + 1 < across; j++) {
        final int a = first + i * across + j;
        final int c = a + across;
        mesh.triangle(a, a + 1, c);
        mesh.triangle(a + 1, c + 1, c);
      }
    }
  }

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

(double, double, double) _unit(double x, double y, double z) {
  final double length = math.sqrt(x * x + y * y + z * z);
  return length <= 0 ? (0, 0, 1) : (x / length, y / length, z / length);
}

int _clear(int colour) => colour & ((1 << 24) - 1);

/// A number from -1 to 1 that is the same for [i] every time, and unlike
/// its neighbours'.
double _jitter(int i) {
  final double x = math.sin(i * 12.9898 + 78.233) * 43758.5453;
  return 2 * (x - x.floorToDouble()) - 1;
}
