import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../zoom_inks.dart';
import '../../coloured_mesh.dart';
import '../../specimen_light.dart';
import '../../tube_course.dart';
import 'intestine_form.dart';
import 'intestine_style.dart';

/// The intestines in place from the front, drawn as a specimen under the
/// zoom's one lamp: the coils and the colon lit tubes of the gut's warm
/// neutral, each coil casting a soft shadow on what it lies on, the colon's
/// sacculi swelling between their grooves, its free band paler and its
/// appendices the breast's fat; through the window, the lining where the
/// zoom's cell lives flat in the mark, as the stomach's mucosa is, cut by
/// its anatomy as crisp lines (the semilunar fold, the valve's lips and
/// frenula, its aperture and the appendix's orifice, the Peyer's patch and
/// its nodules), the lining where it does not live a deep warm neutral, and
/// the cut wall a thin band of its coats round each opening.
///
/// Everything costly is built once, for one form and one set of inks:
/// meshes and paths in the scene's units, so a frame only hands them on.
final class IntestineArt {
  IntestineArt(this.form, this.inks)
    : _light = SpecimenLight(SpecimenLamp.zoom),
      _palette = SpecimenPalette(inks);

  final IntestineForm form;
  final ZoomInks inks;
  final SpecimenLight _light;
  final SpecimenPalette _palette;

  /// Where the zoom's cell lives: one flat tone, the mark over a neutral,
  /// as the stomach's mucosa is.
  static Color homeOf(ZoomInks inks) => Color.alphaBlend(
    inks.glow(IntestineStyle.homeMark),
    inks.lit(IntestineStyle.homeLit),
  );

  /// What the step from the body draws the intestines' bed in: the
  /// mesentery and the back wall in shade, seen between the coils.
  static Color bedOf(ZoomInks inks) => Color.lerp(
    inks.lit(IntestineStyle.bedLit),
    inks.bases.thymine,
    IntestineStyle.bedWarmth,
  )!;

  /// A tone [lit] of the way to the bright ink, warmed [warmth] of the way
  /// toward the home helix's clay.
  static SpecimenTone _warmed(ZoomInks inks, double lit, double warmth) =>
      SpecimenTone(
        Color.lerp(inks.lit(lit), inks.bases.thymine, warmth)!,
        inks.shadow,
      );

  late final Color _home = homeOf(inks);
  late final SpecimenTone _jejunum = _warmed(
    inks,
    IntestineStyle.jejunumLit,
    IntestineStyle.jejunumWarmth,
  );
  late final SpecimenTone _ileumTone = _warmed(
    inks,
    IntestineStyle.ileumLit,
    IntestineStyle.ileumWarmth,
  );
  late final SpecimenTone _colonTone = _warmed(
    inks,
    IntestineStyle.colonLit,
    IntestineStyle.colonWarmth,
  );
  late final SpecimenTone _bandTone = _warmed(
    inks,
    IntestineStyle.bandLit,
    IntestineStyle.bandWarmth,
  );
  late final SpecimenTone _fat = _warmed(
    inks,
    IntestineStyle.fatLit,
    IntestineStyle.fatWarmth,
  );

  /// [tone]'s cut face where it faces the eye.
  Color _face(SpecimenTone tone) => Color(
    _palette.colour(
      tone,
      _light.light(0, 0, 1),
      sheen: _light.sheen(0, 0, 1) * IntestineStyle.cutSheen,
    ),
  );

  late final Color _mucosa = _face(
    _warmed(inks, IntestineStyle.mucosaLit, IntestineStyle.mucosaWarmth),
  );
  late final Color _submucosa = _face(
    _warmed(inks, IntestineStyle.submucosaLit, IntestineStyle.submucosaWarmth),
  );
  late final Color _muscle = _face(
    _warmed(inks, IntestineStyle.muscleLit, IntestineStyle.muscleWarmth),
  );
  late final Color _serosa = _face(
    _warmed(inks, IntestineStyle.serosaLit, IntestineStyle.serosaWarmth),
  );

  /// The lining of the colon and of the ileum: the mark where the zoom's
  /// cell lives, else the mucosa's warm neutral.
  late final Color _colonLining = form.home.inColon ? _home : _mucosa;
  late final Color _ileumLining = form.home.inIleum ? _home : _mucosa;

  /// The muscle coats, and the colon's free band: the mark where the zoom's
  /// cell is a muscle cell.
  bool get _muscleHome => form.home == IntestineHome.muscle;
  late final Color _muscleCoat = _muscleHome ? _home : _muscle;

  static final List<double> _round = <double>[
    for (final double u in IntestineStyle.tubeColumns.reversed) -u,
    ...IntestineStyle.tubeColumns.skip(1),
  ];

  // The meshes.

  /// The sigmoid colon, behind the coils in the pelvis, its band on it.
  late final List<ui.Vertices> _sigmoid = _build(
    (ColouredMesh mesh) =>
        _layColon(mesh, math.max(form.windowRow, form.sigmoidRow - 2), null),
  );

  /// The coils, back to front, each its own mesh, so each casts its shadow
  /// on those under it before it is laid over them.
  late final List<List<ui.Vertices>> _coils = <List<ui.Vertices>>[
    for (int k = 0; k < form.coils.length; k++)
      _build((ColouredMesh mesh) => _layCoil(mesh, k)),
  ];

  /// The terminal ileum where it is not cut open, and the appendix.
  late final List<ui.Vertices> _ileum = _build(_layIleum);
  late final List<ui.Vertices> _appendix = _build(_layAppendix);

  /// The colon but the sigmoid, over the coils, from the window up.
  late final List<ui.Vertices> _colon = _build(
    (ColouredMesh mesh) => _layColon(mesh, form.windowRow, form.sigmoidRow),
  );

  /// The appendices epiploicae, the sigmoid's and the rest's.
  late final List<ui.Vertices> _sigmoidFat = _build(
    (ColouredMesh mesh) => _layAppendices(mesh, true),
  );
  late final List<ui.Vertices> _fatMesh = _build(
    (ColouredMesh mesh) => _layAppendices(mesh, false),
  );

  void _layCoil(ColouredMesh mesh, int k) => _layShaded(
    mesh,
    form.coils[k],
    IntestineForm.jejunal[k] ? _jejunum : _ileumTone,
  );

  void _layIleum(ColouredMesh mesh) {
    _layShaded(mesh, form.ileum, _ileumTone, to: form.openFirst);
    _layShaded(mesh, form.ileum, _ileumTone, from: form.openLast);
  }

  /// [t]'s rows [from] to [to] as a lit tube in [tone], as `TubeCourse.lay`
  /// lays one, but running back into the shade where it fades, opaque, so
  /// that a coil's end turns away into the dark between the coils and
  /// nothing under it shows through.
  void _layShaded(
    ColouredMesh mesh,
    TubeCourse t,
    SpecimenTone tone, {
    int from = 0,
    int? to,
  }) {
    final int end = to ?? t.length - 1;
    final int rows = end - from + 1;
    if (rows < 2) {
      return;
    }
    final int around = _round.length;
    mesh.begin(rows * around);
    final int first = mesh.next;
    for (int i = from; i <= end; i++) {
      final Offset m = t.across[i];
      final double away = (1 - t.shown[i]) * IntestineStyle.shadeAway;
      for (final double u in _round) {
        final Offset p = t.at(i, u);
        final double nz = math.sqrt(math.max(0, 1 - u * u));
        final double nx = m.dx * u;
        final double ny = m.dy * u;
        mesh.vertex(
          p.dx,
          p.dy,
          _palette.colour(
            tone,
            _light.light(nx, ny, nz, form: nz) * IntestineStyle.tubeLight,
            occlusion: away,
            sheen:
                _light.sheen(nx, ny, nz) *
                IntestineStyle.tubeLight *
                t.shown[i],
          ),
        );
      }
    }
    _stitch(mesh, first, rows, around);
    // Where it fades, it turns away: a rounded end, shaded as its last row.
    for (final (int row, double back) in <(int, double)>[
      if (t.shown[from] < 0.99) (from, -1),
      if (t.shown[end] < 0.99) (end, 1),
    ]) {
      final Offset m = t.across[row];
      final Offset way = Offset(m.dy, -m.dx) * back;
      _layDome(
        mesh,
        t.centres[row],
        way,
        2 * t.radius[row] * IntestineStyle.endRound,
        t.plus[row] + t.minus[row],
        tone,
        half: true,
        occlusion: (1 - t.shown[row]) * IntestineStyle.shadeAway,
      );
    }
  }

  void _layAppendix(ColouredMesh mesh) {
    form.appendix.lay(
      mesh,
      _colonTone,
      _light,
      _palette,
      _round,
      brightness: IntestineStyle.tubeLight,
    );
    final TubeCourse t = form.appendix;
    final int last = t.length - 1;
    final Offset way = Offset(t.across[last].dy, -t.across[last].dx);
    _layDome(
      mesh,
      t.centres[last],
      way,
      2 * t.radius[last],
      2 * t.radius[last],
      _colonTone,
      half: true,
    );
  }

  /// The colon's rows [from] to [to] (its end where null), a lit tube whose
  /// sacculi swell between their grooves, and its free band along it.
  void _layColon(ColouredMesh mesh, int from, int? to) {
    final IntestineRows c = form.colon;
    final int end = to ?? c.centres.length - 1;
    final int rows = end - from + 1;
    if (rows < 2) {
      return;
    }
    final int around = _round.length;
    mesh.begin(rows * around);
    final int first = mesh.next;
    for (int i = from; i <= end; i++) {
      for (final double u in _round) {
        final (Offset p, int colour) = _colonVertex(i, u, _colonTone);
        mesh.vertex(p.dx, p.dy, colour);
      }
    }
    _stitch(mesh, first, rows, around);
    // The free band, along the colon's front, its own tube of its paler
    // tone laid over it.
    const int bandColumns = 5;
    mesh.begin(rows * bandColumns);
    final int band = mesh.next;
    for (int i = from; i <= end; i++) {
      final double b = form.band[i];
      for (int j = 0; j < bandColumns; j++) {
        final double u = -b + 2 * b * j / (bandColumns - 1);
        if (_muscleHome) {
          final Offset p = _colonPoint(i, u);
          mesh.vertex(p.dx, p.dy, SpecimenPalette.packColour(_home, 1));
        } else {
          final (Offset p, int colour) = _colonVertex(i, u, _bandTone);
          mesh.vertex(p.dx, p.dy, colour);
        }
      }
    }
    _stitch(mesh, band, rows, bandColumns);
  }

  Offset _colonPoint(int i, double u) {
    final IntestineRows c = form.colon;
    return c.centres[i] +
        c.across[i] * (u >= 0 ? c.plus[i] * u : c.minus[i] * u);
  }

  /// The colon's point [u] of the way across row [i], and its colour in
  /// [tone]: lit round it, and tipped along it where a sacculus swells.
  (Offset, int) _colonVertex(int i, double u, SpecimenTone tone) {
    final IntestineRows c = form.colon;
    final Offset m = c.across[i];
    final Offset way = Offset(m.dy, -m.dx);
    final double nz0 = math.sqrt(math.max(0, 1 - u * u));
    final double tip = c.tilt[i] * IntestineStyle.sacculusTilt * nz0;
    double nx = m.dx * u - way.dx * tip;
    double ny = m.dy * u - way.dy * tip;
    double nz = nz0;
    final double l = math.sqrt(nx * nx + ny * ny + nz * nz);
    nx /= l;
    ny /= l;
    nz /= l;
    return (
      _colonPoint(i, u),
      _palette.colour(
        tone,
        _light.light(nx, ny, nz, form: nz0) * IntestineStyle.tubeLight,
        occlusion: (1 - c.shown[i]) * IntestineStyle.shadeAway,
        sheen: _light.sheen(nx, ny, nz) * IntestineStyle.tubeLight * c.shown[i],
      ),
    );
  }

  static void _stitch(ColouredMesh mesh, int first, int rows, int around) {
    for (int i = 0; i + 1 < rows; i++) {
      for (int j = 0; j + 1 < around; j++) {
        final int a = first + i * around + j;
        final int c = a + around;
        mesh.triangle(a, a + 1, c);
        mesh.triangle(a + 1, c + 1, c);
      }
    }
  }

  void _layAppendices(ColouredMesh mesh, bool sigmoid) {
    for (final (Offset c, Offset out, double long, double wide, bool onSigmoid)
        in form.appendices) {
      if (onSigmoid == sigmoid) {
        _layDome(mesh, c, out, long, wide, _fat);
      }
    }
  }

  /// A small lit dome [long] along [axis] and [wide] across it, round
  /// [centre]: an appendix of fat, or the appendix's rounded tip ([half]:
  /// only the half beyond its last row).
  void _layDome(
    ColouredMesh mesh,
    Offset centre,
    Offset axis,
    double long,
    double wide,
    SpecimenTone tone, {
    bool half = false,
    double occlusion = 0,
  }) {
    const int ring = 20;
    const List<double> radii = <double>[0.55, 1];
    final Offset across = Offset(-axis.dy, axis.dx);
    mesh.begin(1 + ring * radii.length);
    final int first = mesh.next;
    int vertex(Offset p, double nx, double ny, double nz) {
      mesh.vertex(
        p.dx,
        p.dy,
        _palette.colour(
          tone,
          _light.light(nx, ny, nz, form: nz) * IntestineStyle.tubeLight,
          occlusion: occlusion,
          sheen:
              _light.sheen(nx, ny, nz) *
              IntestineStyle.tubeLight *
              (1 - occlusion),
        ),
      );
      return 0;
    }

    vertex(centre, 0, 0, 1);
    for (final double r in radii) {
      for (int k = 0; k < ring; k++) {
        final double th = half
            ? -math.pi / 2 + math.pi * k / (ring - 1)
            : 2 * math.pi * k / ring;
        final double ca = math.cos(th);
        final double sa = math.sin(th);
        final Offset p =
            centre + axis * (long / 2 * r * ca) + across * (wide / 2 * r * sa);
        final double nz = math.sqrt(math.max(0, 1 - r * r * 0.85));
        final double s = math.sqrt(math.max(0, 1 - nz * nz));
        vertex(
          p,
          (axis.dx * ca + across.dx * sa) * s,
          (axis.dy * ca + across.dy * sa) * s,
          nz,
        );
      }
    }
    for (int k = 0; k < ring; k++) {
      final int next = half ? k + 1 : (k + 1) % ring;
      if (half && k == ring - 1) {
        break;
      }
      final int a = first + 1 + k;
      final int b = first + 1 + next;
      mesh.triangle(first, a, b);
      final int c = a + ring;
      final int d = b + ring;
      mesh.triangle(a, c, d);
      mesh.triangle(a, d, b);
    }
  }

  // The paths.

  static Path _polygon(List<Offset> points) => Path()..addPolygon(points, true);

  late final List<Path> _window = <Path>[
    for (final List<Offset> edge in form.window) _polygon(edge),
  ];
  late final List<Path> _strip = <Path>[
    for (final List<Offset> edge in form.strip) _polygon(edge),
  ];
  late final Path _patch = _polygon(form.patch);

  /// The shadow a tube casts on what it lies on, away from the lamp: a
  /// band under it, as dark as [IntestineStyle.castAlpha] where the tube
  /// shows whole and fading with it where it runs back into the shade,
  /// softened at its sides.
  void _layCast(
    ColouredMesh mesh,
    List<Offset> centres,
    List<Offset> across,
    List<double> plus,
    List<double> minus,
    List<double> shown, {
    int from = 0,
    int? to,
  }) {
    final int end = to ?? centres.length - 1;
    final int rows = end - from + 1;
    if (rows < 2) {
      return;
    }
    final Offset offset = Offset(
      form.mm(IntestineStyle.castX),
      form.mm(IntestineStyle.castY),
    );
    final double soft = form.mm(IntestineStyle.castSoft);
    const List<(double, double)> columns = <(double, double)>[
      (-1, 0),
      (-1, 1),
      (1, 1),
      (1, 0),
    ];
    mesh.begin(rows * columns.length);
    final int first = mesh.next;
    final Color shadow = inks.shadow;
    for (int i = from; i <= end; i++) {
      for (final (double side, double dark) in columns) {
        final double reach = side > 0 ? plus[i] : minus[i];
        final double r = dark > 0 ? reach - soft / 2 : reach + soft / 2;
        final Offset p = centres[i] + offset + across[i] * (side * r);
        mesh.vertex(
          p.dx,
          p.dy,
          SpecimenPalette.packColour(
            shadow,
            IntestineStyle.castAlpha * dark * shown[i],
          ),
        );
      }
    }
    _stitch(mesh, first, rows, columns.length);
  }

  void _layTubeCast(ColouredMesh mesh, TubeCourse t) =>
      _layCast(mesh, t.centres, t.across, t.plus, t.minus, t.shown);

  late final List<List<ui.Vertices>> _coilShadows = <List<ui.Vertices>>[
    for (final TubeCourse t in form.coils)
      _build((ColouredMesh mesh) => _layTubeCast(mesh, t)),
  ];
  late final List<ui.Vertices> _ileumShadow = _build(
    (ColouredMesh mesh) => _layTubeCast(mesh, form.ileum),
  );
  late final List<ui.Vertices> _appendixShadow = _build(
    (ColouredMesh mesh) => _layTubeCast(mesh, form.appendix),
  );

  /// The colon's shadow but the sigmoid's, the window's included.
  late final List<ui.Vertices> _colonShadow = _build((ColouredMesh mesh) {
    final IntestineRows c = form.colon;
    _layCast(
      mesh,
      c.centres,
      c.across,
      c.plus,
      c.minus,
      c.shown,
      to: form.sigmoidRow,
    );
  });

  // The shadows.

  void _paintShadow(Canvas canvas) {
    canvas.save();
    canvas.translate(
      form.mm(IntestineStyle.shadowX),
      form.mm(IntestineStyle.shadowY),
    );
    final Color shadow = inks.shadow;
    canvas.drawPath(
      form.outline,
      Paint()..color = shadow.withValues(alpha: IntestineStyle.shadowAlpha),
    );
    canvas.drawPath(
      form.outline,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = form.mm(IntestineStyle.shadowSoft)
        ..strokeJoin = StrokeJoin.round
        ..color = shadow.withValues(alpha: 0.12),
    );
    canvas.restore();
  }

  // Drawing.

  /// What the intestines cover, their shadow included: the room a layer of
  /// them needs.
  late final Rect bounds = () {
    Rect box = form.box;
    for (final (Offset c, Offset _, double long, double _, bool _)
        in form.appendices) {
      box = box.expandToInclude(Rect.fromCircle(center: c, radius: long));
    }
    return box.inflate(
      form.mm(IntestineStyle.shadowY + IntestineStyle.shadowSoft) +
          form.mm(IntestineStyle.castY + IntestineStyle.castSoft),
    );
  }();

  /// Builds every mesh and path a frame will draw.
  void prepare() => <Object?>[
    _sigmoid,
    _coils,
    _ileum,
    _appendix,
    _colon,
    _sigmoidFat,
    _fatMesh,
    _window,
    _strip,
    _patch,
    _coilShadows,
    _ileumShadow,
    _appendixShadow,
    _colonShadow,
    form.folds,
    form.slit,
    form.grooves,
    form.sigmoidGrooves,
    bounds,
  ];

  /// Draws them all, in the scene's units at the intestines' real size;
  /// [line] is a pixel.
  void paint(Canvas canvas, double line) {
    _paintShadow(canvas);
    // The sigmoid colon, behind the coils in the pelvis, running on into
    // the shade toward the rectum.
    _draw(canvas, _sigmoid);
    _paintGrooves(canvas, line, form.sigmoidGrooves);
    _draw(canvas, _sigmoidFat);
    // The coils, back to front, each over the shadow it casts.
    for (int k = 0; k < form.coils.length; k++) {
      _draw(canvas, _coilShadows[k]);
      _draw(canvas, _coils[k]);
    }
    // The terminal ileum, rising out of the pelvis to the cecum, laid open
    // short of it; the appendix.
    _draw(canvas, _ileumShadow);
    _draw(canvas, _ileum);
    _paintOpening(canvas, line, _strip, _ileumLining);
    canvas.save();
    canvas.clipPath(_strip.last);
    _paintPatch(canvas, line);
    canvas.restore();
    _draw(canvas, _appendixShadow);
    _draw(canvas, _appendix);
    // The colon framing them all, its sacculi's grooves and its appendices.
    _draw(canvas, _colonShadow);
    _draw(canvas, _colon);
    _paintGrooves(canvas, line, form.grooves);
    _draw(canvas, _fatMesh);
    // The window in the cecum, and what is seen through it.
    _paintOpening(canvas, line, _window, _colonLining);
    canvas.save();
    canvas.clipPath(_window.last);
    _paintFolds(canvas, line);
    canvas.restore();
    _paintEdge(canvas, line, form.outline);
  }

  /// An opening cut in a wall, as its coats' [edges] from the outside in
  /// and its [lining] inside them: each coat's cut face, the lining never
  /// thinner than a pixel or so along the cut, the line where they meet.
  void _paintOpening(
    Canvas canvas,
    double line,
    List<Path> edges,
    Color lining,
  ) {
    canvas.drawPath(edges[0], Paint()..color = _serosa);
    canvas.drawPath(edges[1], Paint()..color = _muscleCoat);
    canvas.drawPath(edges[2], Paint()..color = _muscleCoat);
    canvas.drawPath(edges[3], Paint()..color = _submucosa);
    canvas.drawPath(edges[4], Paint()..color = lining);
    canvas.save();
    canvas.clipPath(edges[0]);
    canvas.drawPath(
      edges[4],
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2 * IntestineStyle.mucosaFloor * line
        ..strokeJoin = StrokeJoin.round
        ..color = lining,
    );
    if (_muscleHome) {
      canvas.drawPath(
        edges[2],
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = line
          ..strokeJoin = StrokeJoin.round
          ..color = _home,
      );
    }
    canvas.restore();
    canvas.drawPath(edges[5], Paint()..color = lining);
    canvas.drawPath(
      edges[5],
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(
          form.mm(IntestineStyle.coatLine),
          IntestineStyle.coatLineFloor * line,
        )
        ..strokeJoin = StrokeJoin.round
        ..color = inks.shadow.withValues(alpha: IntestineStyle.coatLineAlpha),
    );
  }

  /// The semilunar fold and the valve's lips and frenula: the light on each
  /// fold's far side, toward the lamp, and the crease along it; the valve's
  /// aperture and the appendix's orifice, dark.
  void _paintFolds(Canvas canvas, double line) {
    _paintCreases(canvas, line, form.folds, IntestineStyle.foldAlpha);
    final Color dark = inks.shadow.withValues(alpha: IntestineStyle.slitAlpha);
    canvas.drawPath(form.slit, Paint()..color = dark);
    final double floor = 1.2 * line;
    if (form.mm(IntestineStyle.slit) < floor) {
      canvas.drawPath(
        form.slit,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = floor - form.mm(IntestineStyle.slit)
          ..strokeJoin = StrokeJoin.round
          ..color = dark,
      );
    }
    final double r = math.max(form.mm(2.4), 1.4 * line);
    canvas.drawOval(
      Rect.fromCenter(center: form.orifice, width: 2 * r, height: 1.5 * r),
      Paint()..color = dark,
    );
  }

  void _paintCreases(Canvas canvas, double line, Path creases, double alpha) {
    canvas.save();
    final Offset toward = _light.screen * form.mm(IntestineStyle.foldLight);
    canvas.translate(toward.dx, toward.dy);
    canvas.drawPath(
      creases,
      Paint()
        ..color = inks
            .lit(IntestineStyle.foldLightLit)
            .withValues(alpha: IntestineStyle.foldLightAlpha),
    );
    canvas.restore();
    final Color cleft = inks.shadow.withValues(alpha: alpha);
    canvas.drawPath(creases, Paint()..color = cleft);
    final double floor = IntestineStyle.foldFloor * line;
    if (form.mm(IntestineStyle.fold) < floor) {
      canvas.drawPath(
        creases,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = floor - form.mm(IntestineStyle.fold)
          ..strokeJoin = StrokeJoin.round
          ..color = cleft,
      );
    }
  }

  /// The grooves between the colon's sacculi.
  void _paintGrooves(Canvas canvas, double line, Path grooves) =>
      _paintCreases(canvas, line, grooves, IntestineStyle.grooveAlpha);

  /// The Peyer's patch: its edge a crease, its nodules small pits.
  void _paintPatch(Canvas canvas, double line) {
    final Color dark = inks.shadow.withValues(alpha: IntestineStyle.patchAlpha);
    canvas.drawPath(
      _patch,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(
          form.mm(IntestineStyle.patchEdge),
          IntestineStyle.foldFloor * line,
        )
        ..strokeJoin = StrokeJoin.round
        ..color = dark,
    );
    canvas.drawRawPoints(
      ui.PointMode.points,
      Float32List.fromList(<double>[
        for (final Offset p in form.nodules) ...<double>[p.dx, p.dy],
      ]),
      Paint()
        ..strokeWidth = math.max(form.mm(IntestineStyle.nodule), 1.2 * line)
        ..strokeCap = StrokeCap.round
        ..color = inks.shadow.withValues(alpha: IntestineStyle.noduleAlpha),
    );
  }

  /// The outline's own edge, as the other specimens' are edged.
  void _paintEdge(Canvas canvas, double line, Path path) => canvas.drawPath(
    path,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = line
      ..strokeJoin = StrokeJoin.round
      ..color = inks
          .lit(IntestineStyle.edgeLit)
          .withValues(alpha: IntestineStyle.edgeAlpha),
  );

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

    add(
      'sigmoid colon',
      (ColouredMesh mesh) =>
          _layColon(mesh, math.max(form.windowRow, form.sigmoidRow - 2), null),
    );
    for (int k = 0; k < form.coils.length; k++) {
      add('coil $k', (ColouredMesh mesh) => _layCoil(mesh, k));
    }
    add('terminal ileum', _layIleum);
    add('appendix', _layAppendix);
    add(
      'colon',
      (ColouredMesh mesh) => _layColon(mesh, form.windowRow, form.sigmoidRow),
    );
    add('appendices', (ColouredMesh mesh) {
      _layAppendices(mesh, true);
      _layAppendices(mesh, false);
    });
    return out;
  }

  /// The colours the cut walls' coats and the linings are drawn in, by
  /// name. For tests.
  @visibleForTesting
  Map<String, Color> get fills => <String, Color>{
    'serosa': _serosa,
    'muscle': _muscleCoat,
    'submucosa': _submucosa,
    'colon lining': _colonLining,
    'ileum lining': _ileumLining,
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
