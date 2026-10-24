import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../zoom_inks.dart';
import '../../coloured_mesh.dart';
import '../../specimen_light.dart';
import '../../tube_course.dart';
import 'fallopian_form.dart';
import 'fallopian_style.dart';

/// The fallopian tube opened along its length in place, drawn as a
/// specimen under the zoom's one lamp: where the zoom's cell lives flat in
/// the mark (its mucosa, the fimbriae's inner faces with it, or its
/// muscular coat); else the mucosa a deep warm pink-grey, its folds crisp
/// cut lines over it, three in the isthmus and nine in the ampulla; the
/// wall's cut edges either side of it, its muscle warmed toward the clay;
/// the fimbriae lit fingers round the ostium; the mesosalpinx a thin pale
/// sheet under it, fading out, the tubal artery along it in the blood red.
///
/// Everything costly is built once, for one form and one set of inks:
/// meshes and paths in the scene's units, so a frame only hands them on.
final class FallopianArt {
  FallopianArt(this.form, this.inks)
    : _light = SpecimenLight(SpecimenLamp.zoom),
      _palette = SpecimenPalette(inks);

  final FallopianForm form;
  final ZoomInks inks;
  final SpecimenLight _light;
  final SpecimenPalette _palette;

  FallopianHome get home => form.home;

  /// Where the zoom's cell lives: one flat tone, the mark over a neutral,
  /// as the stomach's mucosa is.
  static Color homeOf(ZoomInks inks) => Color.alphaBlend(
    inks.glow(FallopianStyle.homeMark),
    inks.lit(FallopianStyle.homeLit),
  );

  /// What the step from the body draws the tube's bed in: its mucosa's
  /// tone, in the mark where the mucosa is the cell's home.
  static Color bedOf(ZoomInks inks, FallopianHome home) {
    if (home == FallopianHome.mucosa) {
      return homeOf(inks);
    }
    final SpecimenLight light = SpecimenLight(SpecimenLamp.zoom);
    return Color(
      SpecimenPalette(inks).colour(
        _toneOf(inks, FallopianStyle.mucosaLit, FallopianStyle.mucosaWarmth),
        light.light(0, 0, 1),
        sheen: light.sheen(0, 0, 1) * FallopianStyle.cutSheen,
      ),
    );
  }

  static SpecimenTone _toneOf(ZoomInks inks, double lit, double warmth) =>
      SpecimenTone(
        Color.lerp(inks.lit(lit), inks.bases.thymine, warmth)!,
        inks.shadow,
      );

  late final Color _home = homeOf(inks);
  late final SpecimenTone _mucosaTone = _toneOf(
    inks,
    FallopianStyle.mucosaLit,
    FallopianStyle.mucosaWarmth,
  );
  late final SpecimenTone _muscleTone = _toneOf(
    inks,
    FallopianStyle.muscleLit,
    FallopianStyle.muscleWarmth,
  );
  late final SpecimenTone _arteryTone = SpecimenTone(
    Color.lerp(inks.blood, inks.ground, FallopianStyle.artery)!,
    inks.shadow,
  );

  /// [tone]'s cut face where it faces the eye.
  Color _face(SpecimenTone tone) => Color(
    _palette.colour(
      tone,
      _light.light(0, 0, 1),
      sheen: _light.sheen(0, 0, 1) * FallopianStyle.cutSheen,
    ),
  );

  late final Color _mucosa = home == FallopianHome.mucosa
      ? _home
      : _face(_mucosaTone);
  late final Color _muscle = home == FallopianHome.muscularis
      ? _home
      : _face(_muscleTone);

  static final List<double> _round = <double>[
    for (final double u in FallopianStyle.tubeColumns.reversed) -u,
    ...FallopianStyle.tubeColumns.skip(1),
  ];

  // The meshes.

  /// The fimbriae, lit fingers where the mucosa is not the cell's home:
  /// there they are one flat tone.
  late final List<ui.Vertices> _fimbriaMesh = _build((ColouredMesh mesh) {
    if (home != FallopianHome.mucosa) {
      for (final TubeCourse t in form.fimbriae) {
        _layTube(mesh, t, _mucosaTone);
      }
    }
  });
  late final List<ui.Vertices> _arteryMesh = _build(
    (ColouredMesh mesh) => _layTube(mesh, form.artery, _arteryTone),
  );

  void _layTube(ColouredMesh mesh, TubeCourse tube, SpecimenTone tone) =>
      tube.lay(
        mesh,
        tone,
        _light,
        _palette,
        _round,
        brightness: FallopianStyle.tubeLight,
      );

  // The paths.

  late final Path _lumen = Path()..addPolygon(form.lumen, true);
  late final List<Path> _walls = <Path>[
    for (final List<Offset> w in form.walls) Path()..addPolygon(w, true),
  ];
  late final Path _folds = () {
    final Path path = Path();
    for (final List<Offset> f in form.folds) {
      path.addPolygon(f, false);
    }
    return path;
  }();
  late final Path _fimbriae = () {
    final Path path = Path()..fillType = PathFillType.nonZero;
    for (final TubeCourse t in form.fimbriae) {
      path.addPolygon(<Offset>[
        for (int i = 0; i < t.length; i++) t.at(i, 1),
        for (int i = t.length - 1; i >= 0; i--) t.at(i, -1),
      ], true);
    }
    return path;
  }();
  late final Path _sheet = Path()..addPolygon(form.mesosalpinx, true);

  // The shadow.

  void _paintShadow(Canvas canvas) {
    canvas.save();
    canvas.translate(
      form.mm(FallopianStyle.shadowX),
      form.mm(FallopianStyle.shadowY),
    );
    final Color shadow = inks.shadow;
    canvas.drawPath(
      form.outline,
      Paint()..color = shadow.withValues(alpha: FallopianStyle.shadowAlpha),
    );
    canvas.drawPath(
      form.outline,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = form.mm(FallopianStyle.shadowSoft)
        ..strokeJoin = StrokeJoin.round
        ..color = shadow.withValues(alpha: 0.12),
    );
    canvas.restore();
  }

  // Drawing.

  /// What the tube and what is drawn beside it cover, its shadow included:
  /// the room a layer of it needs.
  late final Rect bounds = () {
    Rect box = form.box.expandToInclude(_bounds(form.mesosalpinx));
    for (final TubeCourse t in form.beside) {
      for (int i = 0; i < t.length; i++) {
        box = box.expandToInclude(
          Rect.fromCircle(center: t.centres[i], radius: t.radius[i]),
        );
      }
    }
    return box.inflate(
      form.mm(FallopianStyle.shadowY + FallopianStyle.shadowSoft),
    );
  }();

  /// Builds every mesh and path a frame will draw.
  void prepare() => <Object?>[
    _fimbriaMesh,
    _arteryMesh,
    _lumen,
    _walls,
    _folds,
    _fimbriae,
    _sheet,
    bounds,
  ];

  /// Draws it all, in the scene's units at the tube's real size; [line] is
  /// a pixel.
  void paint(Canvas canvas, double line) {
    // The mesosalpinx under it, fading out, and the artery along it.
    final Rect sheet = _bounds(form.mesosalpinx);
    canvas.drawPath(
      _sheet,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            inks
                .lit(FallopianStyle.sheetLit)
                .withValues(alpha: FallopianStyle.sheetAlpha),
            inks.lit(FallopianStyle.sheetLit).withValues(alpha: 0),
          ],
        ).createShader(sheet),
    );
    _draw(canvas, _arteryMesh);
    // The tube, opened: its shadow, the wall's cut edges either side of
    // the lumen, the mucosa and its folds.
    _paintShadow(canvas);
    for (final Path wall in _walls) {
      canvas.drawPath(wall, Paint()..color = _muscle);
    }
    canvas.drawPath(_lumen, Paint()..color = _mucosa);
    canvas.save();
    canvas.clipPath(_lumen);
    canvas.drawPath(
      _folds,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = math.max(
          form.mm(FallopianStyle.fold),
          FallopianStyle.foldFloor * line,
        )
        ..color = inks.shadow.withValues(alpha: FallopianStyle.foldAlpha),
    );
    canvas.restore();
    // The fimbriae round the ostium.
    if (home == FallopianHome.mucosa) {
      canvas.drawPath(_fimbriae, Paint()..color = _home);
    } else {
      _draw(canvas, _fimbriaMesh);
    }
    final Paint edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = line
      ..strokeJoin = StrokeJoin.round
      ..color = inks
          .lit(FallopianStyle.edgeLit)
          .withValues(alpha: FallopianStyle.edgeAlpha);
    canvas.drawPath(_fimbriae, edge);
    canvas.drawPath(form.outline, edge);
    canvas.drawPath(
      _lumen,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = line
        ..strokeJoin = StrokeJoin.round
        ..color = inks.shadow.withValues(alpha: 0.4),
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

    if (home != FallopianHome.mucosa) {
      add('fimbriae', (ColouredMesh mesh) {
        for (final TubeCourse t in form.fimbriae) {
          _layTube(mesh, t, _mucosaTone);
        }
      });
    }
    add(
      'artery',
      (ColouredMesh mesh) => _layTube(mesh, form.artery, _arteryTone),
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
