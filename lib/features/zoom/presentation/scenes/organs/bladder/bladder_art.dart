import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../zoom_inks.dart';
import '../../coloured_mesh.dart';
import '../../specimen_light.dart';
import '../../tube_course.dart';
import '../../tube_end.dart';
import 'bladder_form.dart';
import 'bladder_style.dart';

/// The urinary bladder opened from the front, drawn as a specimen under the
/// zoom's one lamp: its urothelium, where the zoom's cell lives, flat in the
/// mark, as the stomach's mucosa is, cut by its anatomy as crisp lines (the
/// low folds as creases, the torus uretericus and the plicae as ridges, a
/// pale band toward the lamp, the trigone's sides fine, the ureters' slits
/// and the urethra's crescent dark); the cut wall a band of its coats round
/// it, the lamina propria pale and the detrusor a muscle's warm, thickening
/// into the sphincter round the neck; the ureters and the urethra lit tubes,
/// pale, and the vesical arteries lit tubes in the blood red, their small
/// branches running in under the wall, each cut short.
///
/// Everything costly is built once, for one form and one set of inks:
/// meshes and paths in the scene's units, so a frame only hands them on.
final class BladderArt {
  BladderArt(this.form, this.inks)
    : _light = SpecimenLight(SpecimenLamp.zoom),
      _palette = SpecimenPalette(inks);

  final BladderForm form;
  final ZoomInks inks;
  final SpecimenLight _light;
  final SpecimenPalette _palette;

  /// Where the zoom's cell lives, the urothelium: one flat tone, the mark
  /// over a neutral, as the stomach's mucosa is.
  static Color homeOf(ZoomInks inks) => Color.alphaBlend(
    inks.glow(BladderStyle.homeMark),
    inks.lit(BladderStyle.homeLit),
  );

  /// What the step from the body draws the bladder's bed in: its
  /// urothelium, so that the specimen comes up on its own tone.
  static Color bedOf(ZoomInks inks) => homeOf(inks);

  /// A tone [lit] of the way to the bright ink, warmed [warmth] of the way
  /// toward the home helix's clay.
  static SpecimenTone _warmed(ZoomInks inks, double lit, double warmth) =>
      SpecimenTone(
        Color.lerp(inks.lit(lit), inks.bases.thymine, warmth)!,
        inks.shadow,
      );

  late final Color _home = homeOf(inks);
  late final SpecimenTone _ductTone = _warmed(
    inks,
    BladderStyle.ductLit,
    BladderStyle.ductWarmth,
  );
  late final SpecimenTone _arteryTone = SpecimenTone(
    Color.lerp(inks.blood, inks.ground, BladderStyle.artery)!,
    inks.shadow,
  );

  /// [tone]'s cut face where it faces the eye.
  Color _face(SpecimenTone tone) => Color(
    _palette.colour(
      tone,
      _light.light(0, 0, 1),
      sheen: _light.sheen(0, 0, 1) * BladderStyle.cutSheen,
    ),
  );

  late final Color _lamina = _face(
    _warmed(inks, BladderStyle.laminaLit, BladderStyle.laminaWarmth),
  );
  late final Color _muscle = _face(
    _warmed(inks, BladderStyle.muscleLit, BladderStyle.muscleWarmth),
  );
  late final Color _serosa = _face(
    _warmed(inks, BladderStyle.serosaLit, BladderStyle.serosaWarmth),
  );

  static final List<double> _round = <double>[
    for (final double u in BladderStyle.tubeColumns.reversed) -u,
    ...BladderStyle.tubeColumns.skip(1),
  ];

  // The meshes.

  /// What runs on beside the bladder, each a lit tube under it: the
  /// arteries' small branches into its wall, the ureters and the urethra,
  /// and the arteries over the ureters they cross in front of.
  late final List<ui.Vertices> _beside = _build(_layBeside);

  void _layBeside(ColouredMesh mesh) {
    _layBranches(mesh);
    _layDucts(mesh);
    _layArteries(mesh);
  }

  void _layBranches(ColouredMesh mesh) {
    for (final TubeCourse branch in form.branches) {
      _layTube(mesh, branch, _arteryTone);
    }
  }

  void _layDucts(ColouredMesh mesh) {
    for (final TubeCourse ureter in form.ureters) {
      _layTube(mesh, ureter, _ductTone, light: BladderStyle.ductLight);
    }
    _layTube(mesh, form.urethra, _ductTone, light: BladderStyle.ductLight);
  }

  void _layArteries(ColouredMesh mesh) {
    for (final TubeCourse artery in form.arteries) {
      _layTube(mesh, artery, _arteryTone);
    }
  }

  void _layTube(
    ColouredMesh mesh,
    TubeCourse tube,
    SpecimenTone tone, {
    double light = BladderStyle.tubeLight,
  }) => tube.lay(mesh, tone, _light, _palette, _round, brightness: light);

  late final TubeEnd _end = TubeEnd(
    _palette,
    inks.shadow,
    length: BladderStyle.endLength,
    wall: BladderStyle.endWall,
  );

  // The paths.

  late final Path _serosaInner = _polygon(form.coats[0]);
  late final Path _muscleInner = _polygon(form.coats[1]);
  late final Path _laminaInner = _polygon(form.coats[2]);
  late final Path _surface = _polygon(form.inner);
  late final Path _orifices = () {
    final Path path = Path();
    for (final List<Offset> slit in form.slits) {
      path.addPolygon(slit, true);
    }
    return path..addPolygon(form.crescent, true);
  }();
  late final Path _ridges = () {
    final Path path = Path()..addPolygon(form.torus, false);
    for (final List<Offset> plica in form.plicae) {
      path.addPolygon(plica, false);
    }
    return path;
  }();
  late final Path _ridgeCreases = Path()
    ..addPath(form.torusCrease, Offset.zero)
    ..addPath(form.plicaCreases, Offset.zero);

  static Path _polygon(List<Offset> points) => Path()..addPolygon(points, true);

  // The shadow.

  void _paintShadow(Canvas canvas) {
    canvas.save();
    canvas.translate(
      form.mm(BladderStyle.shadowX),
      form.mm(BladderStyle.shadowY),
    );
    final Color shadow = inks.shadow;
    canvas.drawPath(
      form.outline,
      Paint()..color = shadow.withValues(alpha: BladderStyle.shadowAlpha),
    );
    canvas.drawPath(
      form.outline,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = form.mm(BladderStyle.shadowSoft)
        ..strokeJoin = StrokeJoin.round
        ..color = shadow.withValues(alpha: 0.12),
    );
    canvas.restore();
  }

  // Drawing.

  /// What the bladder and what is drawn beside it cover, its shadow
  /// included: the room a layer of it needs.
  late final Rect bounds = () {
    Rect box = form.box;
    for (final TubeCourse t in <TubeCourse>[...form.beside, ...form.branches]) {
      for (int i = 0; i < t.length; i++) {
        box = box.expandToInclude(
          Rect.fromCircle(center: t.centres[i], radius: t.radius[i]),
        );
      }
    }
    return box.inflate(form.mm(BladderStyle.shadowY + BladderStyle.shadowSoft));
  }();

  /// Builds every mesh and path a frame will draw.
  void prepare() => <Object?>[
    _beside,
    _serosaInner,
    _muscleInner,
    _laminaInner,
    _surface,
    _orifices,
    _ridges,
    _ridgeCreases,
    form.creases,
    form.trigoneEdges,
    bounds,
  ];

  /// Draws it all, in the scene's units at the bladder's real size; [line]
  /// is a pixel.
  void paint(Canvas canvas, double line) {
    _paintShadow(canvas);
    // What runs on beside it, under it, cut short.
    _draw(canvas, _beside);
    for (final TubeCourse ureter in form.ureters) {
      _paintEnd(canvas, ureter, _ductTone, BladderStyle.ductLight);
    }
    _paintEnd(canvas, form.urethra, _ductTone, BladderStyle.ductLight);
    for (final TubeCourse artery in form.arteries) {
      _paintEnd(canvas, artery, _arteryTone, BladderStyle.tubeLight);
    }
    // The cut wall, coat by coat from the serosa in, and the urothelium
    // inside it, which lines the cut never thinner than a pixel or so.
    canvas.drawPath(form.outline, Paint()..color = _serosa);
    canvas.drawPath(_serosaInner, Paint()..color = _muscle);
    canvas.drawPath(_muscleInner, Paint()..color = _lamina);
    canvas.drawPath(_laminaInner, Paint()..color = _home);
    canvas.save();
    canvas.clipPath(form.outline);
    canvas.drawPath(
      _laminaInner,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2 * BladderStyle.urotheliumFloor * line
        ..strokeJoin = StrokeJoin.round
        ..color = _home,
    );
    canvas.restore();
    canvas.drawPath(_surface, Paint()..color = _home);
    // Its anatomy, cut into it as crisp lines.
    canvas.save();
    canvas.clipPath(_surface);
    _paintCreases(
      canvas,
      line,
      form.trigoneEdges,
      BladderStyle.trigoneEdge,
      BladderStyle.trigoneEdgeAlpha,
    );
    _paintFolds(canvas, line);
    _paintRidges(canvas, line);
    _paintOrifices(canvas);
    canvas.restore();
    // Where the cut meets the urothelium, and the serosa's edge, as the
    // other specimens' outlines are edged.
    canvas.drawPath(
      _surface,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(
          form.mm(BladderStyle.coatLine),
          BladderStyle.coatLineFloor * line,
        )
        ..strokeJoin = StrokeJoin.round
        ..color = inks.shadow.withValues(alpha: BladderStyle.coatLineAlpha),
    );
    canvas.drawPath(
      form.outline,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = line
        ..strokeJoin = StrokeJoin.round
        ..color = inks
            .lit(BladderStyle.edgeLit)
            .withValues(alpha: BladderStyle.edgeAlpha),
    );
  }

  void _paintEnd(
    Canvas canvas,
    TubeCourse tube,
    SpecimenTone tone,
    double light,
  ) => _end.paint(canvas, tube, tone, _light.light(0, 0, 1) * light);

  /// The low folds: the light on each fold's far side, toward the lamp,
  /// and the crease along it.
  void _paintFolds(Canvas canvas, double line) {
    canvas.save();
    final Offset toward = _light.screen * form.mm(BladderStyle.ridge);
    canvas.translate(toward.dx, toward.dy);
    canvas.drawPath(
      form.creases,
      Paint()
        ..color = inks
            .lit(BladderStyle.ridgeLit)
            .withValues(alpha: BladderStyle.ridgeAlpha),
    );
    canvas.restore();
    _paintCreases(
      canvas,
      line,
      form.creases,
      BladderStyle.crease,
      BladderStyle.creaseAlpha,
    );
  }

  /// The torus uretericus and the plicae: a pale band toward the lamp over
  /// a crease.
  void _paintRidges(Canvas canvas, double line) {
    canvas.save();
    final Offset toward = _light.screen * form.mm(BladderStyle.torusLight);
    canvas.translate(toward.dx, toward.dy);
    canvas.drawPath(
      _ridges,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(
          form.mm(BladderStyle.torusLightWidth),
          BladderStyle.creaseFloor * line,
        )
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = inks
            .lit(BladderStyle.ridgeLit)
            .withValues(alpha: BladderStyle.torusLightAlpha),
    );
    canvas.restore();
    _paintCreases(
      canvas,
      line,
      _ridgeCreases,
      BladderStyle.torusCrease,
      BladderStyle.torusAlpha,
    );
  }

  /// The ureters' slits and the urethra's crescent: a hair of light on the
  /// lip toward the lamp, and the opening dark.
  void _paintOrifices(Canvas canvas) {
    canvas.save();
    final Offset toward = _light.screen * form.mm(BladderStyle.lipOffset);
    canvas.translate(toward.dx, toward.dy);
    canvas.drawPath(
      _orifices,
      Paint()
        ..color = inks
            .lit(BladderStyle.lipLit)
            .withValues(alpha: BladderStyle.lipAlpha),
    );
    canvas.restore();
    canvas.drawPath(
      _orifices,
      Paint()..color = inks.shadow.withValues(alpha: BladderStyle.orificeAlpha),
    );
  }

  /// [creases], [width] wide, in the shadow ink at [alpha], never thinner
  /// than a pixel or so.
  void _paintCreases(
    Canvas canvas,
    double line,
    Path creases,
    double width,
    double alpha,
  ) {
    final Color cleft = inks.shadow.withValues(alpha: alpha);
    canvas.drawPath(creases, Paint()..color = cleft);
    final double floor = BladderStyle.creaseFloor * line;
    if (form.mm(width) < floor) {
      canvas.drawPath(
        creases,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = floor - form.mm(width)
          ..strokeJoin = StrokeJoin.round
          ..color = cleft,
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

    add('branches', _layBranches);
    add('ducts', _layDucts);
    add('arteries', _layArteries);
    return out;
  }

  /// The colours the cut wall's coats and the urothelium are filled in, by
  /// name. For tests.
  @visibleForTesting
  Map<String, Color> get fills => <String, Color>{
    'serosa': _serosa,
    'detrusor': _muscle,
    'lamina propria': _lamina,
    'urothelium': _home,
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
