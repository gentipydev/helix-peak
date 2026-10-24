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
import '../../tube_end.dart';
import 'adrenal_form.dart';
import 'adrenal_style.dart';

/// The adrenal gland cut through the middle of its thickness on its
/// kidney's upper pole, drawn as a specimen under the zoom's one lamp:
/// where the zoom's cell lives flat in the mark (its cortex, as the
/// kidney's is, or its medulla); else the cortex a deep yellow and the
/// medulla a dark red-brown, each a cut face, the cortex turning away under
/// the capsule, the zona reticularis's edge a faint line round the medulla;
/// the central vein's channel emptied in the cut, the vein lit out of the
/// hilum and cut short; the suprarenal arteries fine lit tubes in the blood
/// red, fading toward where they come from; the kidney's upper pole under
/// it, the body's own outline of it lit, fading out below.
///
/// Everything costly is built once, for one form and one set of inks:
/// meshes and paths in the scene's units, so a frame only hands them on.
final class AdrenalArt {
  AdrenalArt(this.form, this.inks)
    : _light = SpecimenLight(SpecimenLamp.zoom),
      _palette = SpecimenPalette(inks);

  final AdrenalForm form;
  final ZoomInks inks;
  final SpecimenLight _light;
  final SpecimenPalette _palette;

  AdrenalHome get home => form.home;

  /// Where the zoom's cell lives: one flat tone, the mark over a neutral,
  /// as the kidney's cortex is.
  static Color homeOf(ZoomInks inks) => Color.alphaBlend(
    inks.glow(AdrenalStyle.homeMark),
    inks.lit(AdrenalStyle.homeLit),
  );

  /// The cortex's cut face where it faces the eye: what the step from the
  /// body draws the gland's bed in, so that the cut comes up on its own
  /// tone; in the mark where the cortex is the cell's home.
  static Color bedOf(ZoomInks inks, AdrenalHome home) {
    if (home == AdrenalHome.cortex) {
      return homeOf(inks);
    }
    final SpecimenLight light = SpecimenLight(SpecimenLamp.zoom);
    return Color(
      SpecimenPalette(inks).colour(
        _cortexToneOf(inks),
        light.light(0, 0, 1),
        sheen: light.sheen(0, 0, 1) * AdrenalStyle.cutSheen,
      ),
    );
  }

  static SpecimenTone _cortexToneOf(ZoomInks inks) => SpecimenTone(
    Color.lerp(
      inks.lit(AdrenalStyle.cortexLit),
      inks.nerve,
      AdrenalStyle.cortexHoney,
    )!,
    inks.shadow,
  );

  SpecimenTone _tone(Color colour) => SpecimenTone(colour, inks.shadow);

  late final Color _home = homeOf(inks);
  late final SpecimenTone _cortexTone = _cortexToneOf(inks);
  late final SpecimenTone _medullaTone = _tone(
    Color.lerp(
      inks.lit(AdrenalStyle.medullaLit),
      inks.bases.thymine,
      AdrenalStyle.medullaClay,
    )!,
  );
  late final SpecimenTone _kidneyTone = _tone(
    Color.lerp(
      inks.lit(AdrenalStyle.kidneyLit),
      inks.bases.thymine,
      AdrenalStyle.kidneyWarmth,
    )!,
  );
  late final SpecimenTone _arteryTone = _tone(
    Color.lerp(inks.blood, inks.ground, AdrenalStyle.artery)!,
  );
  late final SpecimenTone _veinTone = _tone(
    Color.lerp(inks.blood, inks.ground, AdrenalStyle.vein)!,
  );

  /// [tone]'s cut face where it faces the eye.
  Color _face(SpecimenTone tone) => Color(
    _palette.colour(
      tone,
      _light.light(0, 0, 1),
      sheen: _light.sheen(0, 0, 1) * AdrenalStyle.cutSheen,
    ),
  );

  late final Color _cortex = home == AdrenalHome.cortex
      ? _home
      : _face(_cortexTone);
  late final Color _medulla = home == AdrenalHome.medulla
      ? _home
      : _face(_medullaTone);
  late final Color _cavity = inks.shade(AdrenalStyle.cavityShade);

  late final CutFace _faceOf = CutFace(
    _light,
    _palette,
    sheen: AdrenalStyle.cutSheen,
  );

  /// The cut face's edge turning away under the capsule.
  static const List<(double, double, double)> _rim = <(double, double, double)>[
    (0, AdrenalStyle.rimOuter, 0),
    (0.5, AdrenalStyle.rimMiddle, 0),
    (1, 0, 0),
  ];

  static final List<double> _round = <double>[
    for (final double u in AdrenalStyle.tubeColumns.reversed) -u,
    ...AdrenalStyle.tubeColumns.skip(1),
  ];

  // The meshes.

  /// The cortex's edge under the capsule, where the cortex is not the
  /// cell's home: there it is one flat tone.
  late final List<ui.Vertices> _rimMesh = _build((ColouredMesh mesh) {
    if (home != AdrenalHome.cortex) {
      _layRim(mesh);
    }
  });

  void _layRim(ColouredMesh mesh) => _faceOf.lay(
    mesh,
    <Offset>[...form.outlinePoints, form.outlinePoints.first],
    <Offset>[...form.rimInner, form.rimInner.first],
    (int _) => _cortexTone,
    _rim,
  );

  /// The kidney's upper pole, lit, fading out below.
  late final List<ui.Vertices> _kidneyMesh = _build(_layKidney);

  void _layKidney(ColouredMesh mesh) {
    final List<Offset> pole = form.kidneyPole;
    if (pole.length < 3) {
      return;
    }
    final Relief relief = Relief(
      form.kidney!,
      cell: form.mm(AdrenalStyle.reliefCell),
      inflation: AdrenalStyle.reliefInflation,
      sweeps: AdrenalStyle.reliefSweeps,
    );
    final double cell = form.mm(AdrenalStyle.meshCell);
    final Rect grid = _bounds(pole).inflate(cell);
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
            _kidneyTone,
            _light.light(nx, ny, nz, form: nz) * AdrenalStyle.kidneyLight,
            sheen: _light.sheen(nx, ny, nz) * AdrenalStyle.kidneyLight,
            alpha: form.kidneyShownAt(p.dy),
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

  /// The arteries, behind the gland's edge; the vein, out of its hilum.
  late final List<ui.Vertices> _arteries = _build((ColouredMesh mesh) {
    for (final TubeCourse t in form.arteries) {
      _layTube(mesh, t, _arteryTone);
    }
  });
  late final List<ui.Vertices> _vein = _build(
    (ColouredMesh mesh) => _layTube(mesh, form.vein, _veinTone),
  );

  void _layTube(ColouredMesh mesh, TubeCourse tube, SpecimenTone tone) =>
      tube.lay(
        mesh,
        tone,
        _light,
        _palette,
        _round,
        brightness: AdrenalStyle.tubeLight,
      );

  late final TubeEnd _end = TubeEnd(
    _palette,
    inks.shadow,
    length: AdrenalStyle.endLength,
    wall: AdrenalStyle.endWall,
  );

  // The paths.

  late final Path _kidney = () {
    final List<Offset>? k = form.kidney;
    return k == null ? Path() : (Path()..addPolygon(k, true));
  }();
  late final Path _pole = Path()..addPolygon(form.kidneyPole, true);
  late final Path _medullaShape = Path()..addPolygon(form.medulla, true);
  late final Path _reticularis = Path()..addPolygon(form.reticularis, true);
  late final Path _channel = _tubeShape(form.channel);

  /// [tube]'s shape round its course, its first end rounded: a polygon,
  /// never a union, which at the scene's scale can lose a part.
  static Path _tubeShape(TubeCourse tube) {
    final int n = tube.length;
    final Offset c = tube.centres.first;
    final Offset across = tube.across.first;
    final Offset back = Offset(across.dy, -across.dx);
    final double r = tube.radius.first;
    return Path()..addPolygon(<Offset>[
      for (int i = 0; i < n; i++) tube.at(i, 1),
      for (int i = n - 1; i >= 0; i--) tube.at(i, -1),
      for (int k = 1; k < 8; k++)
        c +
            (across * -math.cos(math.pi * k / 8) +
                    back * math.sin(math.pi * k / 8)) *
                r,
    ], true);
  }

  // The shadow.

  void _paintShadow(Canvas canvas) {
    canvas.save();
    canvas.translate(
      form.mm(AdrenalStyle.shadowX),
      form.mm(AdrenalStyle.shadowY),
    );
    final Color shadow = inks.shadow;
    canvas.drawPath(
      form.outline,
      Paint()..color = shadow.withValues(alpha: AdrenalStyle.shadowAlpha),
    );
    canvas.drawPath(
      form.outline,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = form.mm(AdrenalStyle.shadowSoft)
        ..strokeJoin = StrokeJoin.round
        ..color = shadow.withValues(alpha: 0.12),
    );
    canvas.restore();
  }

  // Drawing.

  /// What the gland and what is drawn beside it cover, its shadow included:
  /// the room a layer of it needs.
  late final Rect bounds = () {
    Rect box = form.box;
    if (form.kidneyPole.length > 2) {
      box = box.expandToInclude(_bounds(form.kidneyPole));
    }
    for (final TubeCourse t in form.beside) {
      for (int i = 0; i < t.length; i++) {
        box = box.expandToInclude(
          Rect.fromCircle(center: t.centres[i], radius: t.radius[i]),
        );
      }
    }
    return box.inflate(form.mm(AdrenalStyle.shadowY + AdrenalStyle.shadowSoft));
  }();

  /// Builds every mesh and path a frame will draw.
  void prepare() => <Object?>[
    _rimMesh,
    _kidneyMesh,
    _arteries,
    _vein,
    _kidney,
    _pole,
    _medullaShape,
    _reticularis,
    _channel,
    bounds,
  ];

  /// Draws it all, in the scene's units at the gland's real size; [line] is
  /// a pixel.
  void paint(Canvas canvas, double line) {
    // The kidney's upper pole under it, lit, its edge fading out with it.
    if (form.kidneyPole.length > 2) {
      canvas.save();
      canvas.clipPath(_kidney);
      _draw(canvas, _kidneyMesh);
      canvas.restore();
      final Rect pole = _bounds(form.kidneyPole);
      canvas.drawPath(
        _pole,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = line
          ..strokeJoin = StrokeJoin.round
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[
              inks
                  .lit(AdrenalStyle.edgeLit)
                  .withValues(alpha: AdrenalStyle.edgeAlpha * 0.7),
              inks.lit(AdrenalStyle.edgeLit).withValues(alpha: 0),
            ],
            stops: <double>[(form.mm(20) / pole.height).clamp(0.0, 1.0), 1],
          ).createShader(pole),
      );
    }
    // The arteries, coming in to its edge.
    _draw(canvas, _arteries);
    // The gland, cut: its shadow, the cortex turning away under the
    // capsule, the medulla, the zona reticularis's edge round it, and the
    // central vein's channel emptied.
    _paintShadow(canvas);
    canvas.drawPath(form.outline, Paint()..color = _cortex);
    _draw(canvas, _rimMesh);
    canvas.drawPath(
      _reticularis,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = math.max(
          form.mm(AdrenalStyle.zoneLine),
          AdrenalStyle.zoneFloor * line,
        )
        ..color = inks.shadow.withValues(alpha: AdrenalStyle.zoneAlpha),
    );
    canvas.drawPath(_medullaShape, Paint()..color = _medulla);
    canvas.drawPath(
      _medullaShape,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = math.max(
          form.mm(AdrenalStyle.zoneLine),
          AdrenalStyle.zoneFloor * line,
        )
        ..color = inks.shadow.withValues(alpha: AdrenalStyle.medullaEdgeAlpha),
    );
    canvas.save();
    canvas.clipPath(form.outline);
    canvas.drawPath(_channel, Paint()..color = _cavity);
    canvas.restore();
    // The capsule's edge, as the other specimens'.
    canvas.drawPath(
      form.outline,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = line
        ..strokeJoin = StrokeJoin.round
        ..color = inks
            .lit(AdrenalStyle.edgeLit)
            .withValues(alpha: AdrenalStyle.edgeAlpha),
    );
    // The vein out of the hilum, cut short.
    _draw(canvas, _vein);
    _end.paint(
      canvas,
      form.vein,
      _veinTone,
      _light.light(0, 0, 1) * AdrenalStyle.tubeLight,
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

    if (home != AdrenalHome.cortex) {
      add('cortex', _layRim);
    }
    add('kidney', _layKidney);
    add('vessels', (ColouredMesh mesh) {
      for (final TubeCourse t in form.arteries) {
        _layTube(mesh, t, _arteryTone);
      }
      _layTube(mesh, form.vein, _veinTone);
    });
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
