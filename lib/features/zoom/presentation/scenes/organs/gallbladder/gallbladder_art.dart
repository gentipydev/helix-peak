import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../zoom_inks.dart';
import '../../coloured_mesh.dart';
import '../../specimen_light.dart';
import '../../tube_course.dart';
import '../../tube_end.dart';
import 'gallbladder_form.dart';
import 'gallbladder_style.dart';

/// The gallbladder laid open from the front with its ducts, drawn as a
/// specimen under the zoom's one lamp: its mucosa, where the zoom's cell
/// lives, flat in the mark, as the bladder's urothelium is, cut by its
/// anatomy as crisp lines (the honeycomb's fine folds, and the neck's and
/// the cystic duct's oblique folds, each a crease with the light on its far
/// side); the cut wall a band of its coats round it, the perimuscular tissue
/// pale and the fibromuscular coat between a fibrous pale and a muscle's
/// warm; the cystic duct laid open on with it, its wall pale and its lining
/// the gallbladder's; the hepatic and bile duct a lit tube in the honey the
/// liver draws its bile ducts in, and the cystic artery a lit tube in the
/// blood red, each cut short.
///
/// Everything costly is built once, for one form and one set of inks:
/// meshes and paths in the scene's units, so a frame only hands them on.
final class GallbladderArt {
  GallbladderArt(this.form, this.inks)
    : _light = SpecimenLight(SpecimenLamp.zoom),
      _palette = SpecimenPalette(inks);

  final GallbladderForm form;
  final ZoomInks inks;
  final SpecimenLight _light;
  final SpecimenPalette _palette;

  /// Where the zoom's cell lives, the mucosa: one flat tone, the mark over
  /// a neutral, as the bladder's urothelium is.
  static Color homeOf(ZoomInks inks) => Color.alphaBlend(
    inks.glow(GallbladderStyle.homeMark),
    inks.lit(GallbladderStyle.homeLit),
  );

  /// What the step from the body draws the gallbladder's bed in: its
  /// mucosa, so that the specimen comes up on its own tone.
  static Color bedOf(ZoomInks inks) => homeOf(inks);

  /// A tone [lit] of the way to the bright ink, warmed [warmth] of the way
  /// toward the home helix's clay.
  static SpecimenTone _warmed(ZoomInks inks, double lit, double warmth) =>
      SpecimenTone(
        Color.lerp(inks.lit(lit), inks.bases.thymine, warmth)!,
        inks.shadow,
      );

  late final Color _home = homeOf(inks);
  late final SpecimenTone _ductTone = SpecimenTone(
    Color.lerp(
      inks.lit(GallbladderStyle.ductLit),
      inks.nerve,
      GallbladderStyle.ductHoney,
    )!,
    inks.shadow,
  );
  late final SpecimenTone _arteryTone = SpecimenTone(
    Color.lerp(inks.blood, inks.ground, GallbladderStyle.artery)!,
    inks.shadow,
  );

  /// [tone]'s cut face where it faces the eye.
  Color _face(SpecimenTone tone) => Color(
    _palette.colour(
      tone,
      _light.light(0, 0, 1),
      sheen: _light.sheen(0, 0, 1) * GallbladderStyle.cutSheen,
    ),
  );

  late final Color _perimuscular = _face(
    _warmed(
      inks,
      GallbladderStyle.perimuscularLit,
      GallbladderStyle.perimuscularWarmth,
    ),
  );
  late final Color _muscle = _face(
    _warmed(inks, GallbladderStyle.muscleLit, GallbladderStyle.muscleWarmth),
  );
  late final Color _serosa = _face(
    _warmed(inks, GallbladderStyle.serosaLit, GallbladderStyle.serosaWarmth),
  );

  /// The honeycomb's folds over the mark: the light on each fold's far
  /// side, and its crease, as the colours they make on the mark's flat
  /// tone, so that where two meet nothing is laid twice.
  late final Color _meshLight = Color.alphaBlend(
    inks
        .lit(GallbladderStyle.meshLightLit)
        .withValues(alpha: GallbladderStyle.meshLightAlpha),
    _home,
  );
  late final Color _meshCrease = Color.alphaBlend(
    inks.shadow.withValues(alpha: GallbladderStyle.meshAlpha),
    _home,
  );

  static final List<double> _round = <double>[
    for (final double u in GallbladderStyle.tubeColumns.reversed) -u,
    ...GallbladderStyle.tubeColumns.skip(1),
  ];

  // The meshes.

  /// What runs on beside the gallbladder, each a lit tube under it: the
  /// hepatic and bile duct, and the cystic artery.
  late final List<ui.Vertices> _beside = _build(_layBeside);

  void _layBeside(ColouredMesh mesh) {
    _layDuct(mesh);
    _layArtery(mesh);
  }

  void _layDuct(ColouredMesh mesh) => _layTube(mesh, form.bileDuct, _ductTone);

  void _layArtery(ColouredMesh mesh) =>
      _layTube(mesh, form.cysticArtery, _arteryTone);

  void _layTube(ColouredMesh mesh, TubeCourse tube, SpecimenTone tone) =>
      tube.lay(
        mesh,
        tone,
        _light,
        _palette,
        _round,
        brightness: GallbladderStyle.tubeLight,
      );

  late final TubeEnd _end = TubeEnd(
    _palette,
    inks.shadow,
    length: GallbladderStyle.endLength,
    wall: GallbladderStyle.endWall,
  );

  // The paths.

  late final Path _serosaInner = _polygon(form.coats[0]);
  late final Path _perimuscularInner = _polygon(form.coats[1]);
  late final Path _muscleInner = _polygon(form.coats[2]);
  late final Path _surface = _polygon(form.inner);
  late final Path _cysticWall = _polygon(form.cysticWall);
  late final Path _cysticLumen = _polygon(form.cysticLumen);

  /// The cystic duct's two sides, its lumen's and its wall's, each as an
  /// open line: its start lies in the neck, where its lumen opens.
  late final Path _cysticLumenSides = _sides(form.cysticLumen);
  late final Path _cysticWallSides = _sides(form.cysticWall);

  late final Path _folds = Path()
    ..addPath(form.neckCreases, Offset.zero)
    ..addPath(form.cysticCreases, Offset.zero);

  /// The lining the folds are cut into: the gallbladder's and its cystic
  /// duct's, one.
  late final Path _lining = Path.combine(
    PathOperation.union,
    _surface,
    _cysticLumen,
  );

  static Path _polygon(List<Offset> points) => Path()..addPolygon(points, true);

  static Path _sides(List<Offset> strip) {
    final int half = strip.length ~/ 2;
    return Path()
      ..addPolygon(strip.sublist(0, half), false)
      ..addPolygon(strip.sublist(half), false);
  }

  // The shadow.

  void _paintShadow(Canvas canvas) {
    canvas.save();
    canvas.translate(
      form.mm(GallbladderStyle.shadowX),
      form.mm(GallbladderStyle.shadowY),
    );
    final Color shadow = inks.shadow;
    final Path shape = Path()
      ..addPath(form.outline, Offset.zero)
      ..addPath(_cysticWall, Offset.zero);
    canvas.drawPath(
      shape,
      Paint()..color = shadow.withValues(alpha: GallbladderStyle.shadowAlpha),
    );
    canvas.drawPath(
      shape,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = form.mm(GallbladderStyle.shadowSoft)
        ..strokeJoin = StrokeJoin.round
        ..color = shadow.withValues(alpha: 0.12),
    );
    canvas.restore();
  }

  // Drawing.

  /// What the gallbladder and what is drawn beside it cover, its shadow
  /// included: the room a layer of it needs.
  late final Rect bounds = () {
    Rect box = form.box;
    for (final TubeCourse t in form.beside) {
      for (int i = 0; i < t.length; i++) {
        box = box.expandToInclude(
          Rect.fromCircle(center: t.centres[i], radius: t.radius[i]),
        );
      }
    }
    box = box.expandToInclude(_cysticWall.getBounds());
    return box.inflate(
      form.mm(GallbladderStyle.shadowY + GallbladderStyle.shadowSoft),
    );
  }();

  /// Builds every mesh and path a frame will draw.
  void prepare() => <Object?>[
    _beside,
    _serosaInner,
    _perimuscularInner,
    _muscleInner,
    _surface,
    _cysticWall,
    _cysticLumen,
    _cysticLumenSides,
    _cysticWallSides,
    _folds,
    _lining,
    form.meshes,
    bounds,
  ];

  /// Draws it all, in the scene's units at the gallbladder's real size;
  /// [line] is a pixel.
  void paint(Canvas canvas, double line) {
    _paintShadow(canvas);
    // What runs on beside it, under it, cut short.
    _draw(canvas, _beside);
    _paintEnd(canvas, form.bileDuct, _ductTone);
    _paintEnd(canvas, form.cysticArtery, _arteryTone);
    // The cystic duct's cut wall, under the neck it leaves.
    canvas.drawPath(_cysticWall, Paint()..color = _perimuscular);
    // The cut wall, coat by coat from the serosa in, and the mucosa inside
    // it, which lines the cut never thinner than a pixel or so.
    canvas.drawPath(form.outline, Paint()..color = _serosa);
    canvas.drawPath(_serosaInner, Paint()..color = _perimuscular);
    canvas.drawPath(_perimuscularInner, Paint()..color = _muscle);
    canvas.drawPath(_muscleInner, Paint()..color = _home);
    canvas.save();
    canvas.clipPath(form.outline);
    canvas.drawPath(
      _muscleInner,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2 * GallbladderStyle.mucosaFloor * line
        ..strokeJoin = StrokeJoin.round
        ..color = _home,
    );
    canvas.restore();
    canvas.drawPath(_surface, Paint()..color = _home);
    // Its anatomy, cut into it as crisp lines.
    canvas.save();
    canvas.clipPath(_surface);
    _paintMeshes(canvas, line);
    canvas.restore();
    // Where the cut meets the mucosa, and the serosa's edge, as the other
    // specimens' outlines are edged.
    _paintCoatLine(canvas, line, _surface);
    _paintEdge(canvas, line, form.outline);
    // The cystic duct's lining, opening out of the neck, over the neck's
    // end; its folds; its sides.
    canvas.drawPath(_cysticLumen, Paint()..color = _home);
    canvas.save();
    canvas.clipPath(_lining);
    _paintFolds(canvas, line);
    canvas.restore();
    _paintCoatLine(canvas, line, _cysticLumenSides);
    _paintEdge(canvas, line, _cysticWallSides);
  }

  void _paintEnd(Canvas canvas, TubeCourse tube, SpecimenTone tone) =>
      _end.paint(
        canvas,
        tube,
        tone,
        _light.light(0, 0, 1) * GallbladderStyle.tubeLight,
      );

  /// The honeycomb: the light on each fold's far side, toward the lamp,
  /// and the crease along it, never thinner than a pixel or so.
  void _paintMeshes(Canvas canvas, double line) {
    final double width = math.max(
      form.mm(GallbladderStyle.mesh),
      GallbladderStyle.meshFloor * line,
    );
    canvas.save();
    final Offset toward = _light.screen * form.mm(GallbladderStyle.meshLight);
    canvas.translate(toward.dx, toward.dy);
    canvas.drawPath(form.meshes, _lines(width, _meshLight));
    canvas.restore();
    canvas.drawPath(form.meshes, _lines(width, _meshCrease));
  }

  static Paint _lines(double width, Color colour) => Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = width
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..color = colour;

  /// The neck's and the cystic duct's oblique folds: the light on each
  /// fold's far side, toward the lamp, and the crease along it.
  void _paintFolds(Canvas canvas, double line) {
    canvas.save();
    final Offset toward = _light.screen * form.mm(GallbladderStyle.foldLight);
    canvas.translate(toward.dx, toward.dy);
    canvas.drawPath(
      _folds,
      Paint()
        ..color = inks
            .lit(GallbladderStyle.foldLightLit)
            .withValues(alpha: GallbladderStyle.foldLightAlpha),
    );
    canvas.restore();
    final Color cleft = inks.shadow.withValues(
      alpha: GallbladderStyle.foldAlpha,
    );
    canvas.drawPath(_folds, Paint()..color = cleft);
    final double floor = GallbladderStyle.foldFloor * line;
    if (form.mm(GallbladderStyle.fold) < floor) {
      canvas.drawPath(
        _folds,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = floor - form.mm(GallbladderStyle.fold)
          ..strokeJoin = StrokeJoin.round
          ..color = cleft,
      );
    }
  }

  /// The line where the cut wall meets the mucosa, in the shadow ink.
  void _paintCoatLine(Canvas canvas, double line, Path path) => canvas.drawPath(
    path,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(
        form.mm(GallbladderStyle.coatLine),
        GallbladderStyle.coatLineFloor * line,
      )
      ..strokeJoin = StrokeJoin.round
      ..color = inks.shadow.withValues(alpha: GallbladderStyle.coatLineAlpha),
  );

  /// The outline's own edge, as the other specimens' are edged.
  void _paintEdge(Canvas canvas, double line, Path path) => canvas.drawPath(
    path,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = line
      ..strokeJoin = StrokeJoin.round
      ..color = inks
          .lit(GallbladderStyle.edgeLit)
          .withValues(alpha: GallbladderStyle.edgeAlpha),
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

    add('bile duct', _layDuct);
    add('cystic artery', _layArtery);
    return out;
  }

  /// The colours the cut wall's coats, the mucosa and the honeycomb's
  /// folds are drawn in, by name. For tests.
  @visibleForTesting
  Map<String, Color> get fills => <String, Color>{
    'serosa': _serosa,
    'perimuscular tissue': _perimuscular,
    'fibromuscular coat': _muscle,
    'mucosa': _home,
    'honeycomb light': _meshLight,
    'honeycomb crease': _meshCrease,
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
