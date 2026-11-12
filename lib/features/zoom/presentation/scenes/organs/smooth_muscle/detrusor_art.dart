import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../zoom_inks.dart';
import '../../coloured_mesh.dart';
import '../../opening_rim.dart';
import '../../specimen_light.dart';
import '../../tube_course.dart';
import '../../tube_end.dart';
import 'detrusor_form.dart';
import 'detrusor_style.dart';

/// Smooth muscle, the bladder's detrusor, drawn whole from the front as a
/// dissection under the zoom's one lamp: the muscle, where the zoom's cell
/// lives, flat in the mark over the whole bladder, as the thigh's vastus
/// lateralis is, its outer layer's bundles crisp creases over it from the
/// apex down to the neck, oblique ones at the sides and the sphincter's
/// rings round the neck; the patch cut from the outer layer rimmed as an
/// opening is, the circular layer's bundles creases in it; the ureters and
/// the urethra lit tubes, pale, under it, the urachus a pale cord from the
/// apex, and the vesical arteries lit tubes in the blood red ramifying over
/// the wall, each cut short.
///
/// Everything costly is built once, for one form and one set of inks:
/// meshes and paths in the scene's units, so a frame only hands them on.
final class DetrusorArt {
  DetrusorArt(this.form, this.inks)
    : _light = SpecimenLight(SpecimenLamp.zoom),
      _palette = SpecimenPalette(inks);

  final DetrusorForm form;
  final ZoomInks inks;
  final SpecimenLight _light;
  final SpecimenPalette _palette;

  /// Where the zoom's cell lives, the whole muscle: one flat tone, the mark
  /// over a neutral, as the thigh's vastus lateralis is.
  static Color homeOf(ZoomInks inks) => Color.alphaBlend(
    inks.glow(DetrusorStyle.homeMark),
    inks.lit(DetrusorStyle.homeLit),
  );

  /// What the step from the body draws the bladder's bed in: the muscle,
  /// so that the specimen comes up on its own tone.
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
    DetrusorStyle.ductLit,
    DetrusorStyle.ductWarmth,
  );
  late final SpecimenTone _urachusTone = _warmed(
    inks,
    DetrusorStyle.urachusLit,
    DetrusorStyle.urachusWarmth,
  );
  late final SpecimenTone _arteryTone = SpecimenTone(
    Color.lerp(inks.blood, inks.ground, DetrusorStyle.artery)!,
    inks.shadow,
  );

  static final List<double> _round = <double>[
    for (final double u in DetrusorStyle.tubeColumns.reversed) -u,
    ...DetrusorStyle.tubeColumns.skip(1),
  ];

  // The meshes.

  /// What runs on behind the bladder, each a lit tube under it: the
  /// ureters and the urethra.
  late final List<ui.Vertices> _under = _build(_layDucts);

  /// What runs over it: the arteries and their branches, and the urachus.
  late final List<ui.Vertices> _over = _build((ColouredMesh mesh) {
    _layArteries(mesh);
    _layUrachus(mesh);
  });

  void _layDucts(ColouredMesh mesh) {
    for (final TubeCourse ureter in form.ureters) {
      _layTube(mesh, ureter, _ductTone, light: DetrusorStyle.ductLight);
    }
    _layTube(mesh, form.urethra, _ductTone, light: DetrusorStyle.ductLight);
  }

  void _layArteries(ColouredMesh mesh) {
    for (final TubeCourse branch in form.branches) {
      _layTube(mesh, branch, _arteryTone);
    }
    for (final TubeCourse artery in form.arteries) {
      _layTube(mesh, artery, _arteryTone);
    }
  }

  void _layUrachus(ColouredMesh mesh) => _layTube(
    mesh,
    form.urachus,
    _urachusTone,
    light: DetrusorStyle.ductLight,
  );

  void _layTube(
    ColouredMesh mesh,
    TubeCourse tube,
    SpecimenTone tone, {
    double light = DetrusorStyle.tubeLight,
  }) => tube.lay(mesh, tone, _light, _palette, _round, brightness: light);

  /// The patch's rim: a shadow just inside its edge that faces the lamp,
  /// and light just inside the edge that turns from it.
  late final List<ui.Vertices> _rim = _build((ColouredMesh mesh) {
    final OpeningRim rim = OpeningRim(
      toward: _light.screen,
      shadow: inks.shadow,
      light: inks.lit(DetrusorStyle.lipLit),
      shadowWidth: form.mm(DetrusorStyle.lipShadow),
      lightWidth: form.mm(DetrusorStyle.lipLight),
      shadowAlpha: DetrusorStyle.lipShadowAlpha,
      lightAlpha: DetrusorStyle.lipLightAlpha,
      probe: form.mm(0.05),
    );
    rim.lay(mesh, <Offset>[...form.patch, form.patch.first], _patch);
  });

  late final TubeEnd _end = TubeEnd(
    _palette,
    inks.shadow,
    length: DetrusorStyle.endLength,
    wall: DetrusorStyle.endWall,
  );

  // The paths.

  late final Path _bundles = _lines(form.bundles);
  late final Path _obliques = _lines(form.obliques);
  late final Path _rings = _lines(form.rings);
  late final Path _patch = Path()..addPolygon(form.patch, true);
  late final Path _circular = _lines(form.circular);

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
      form.mm(DetrusorStyle.shadowX),
      form.mm(DetrusorStyle.shadowY),
    );
    final Color shadow = inks.shadow;
    canvas.drawPath(
      form.outline,
      Paint()..color = shadow.withValues(alpha: DetrusorStyle.shadowAlpha),
    );
    canvas.drawPath(
      form.outline,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = form.mm(DetrusorStyle.shadowSoft)
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
    return box.inflate(
      form.mm(DetrusorStyle.shadowY + DetrusorStyle.shadowSoft),
    );
  }();

  /// Builds every mesh and path a frame will draw.
  void prepare() => <Object?>[
    _under,
    _over,
    _rim,
    _bundles,
    _obliques,
    _rings,
    _patch,
    _circular,
    bounds,
  ];

  /// Draws it all, in the scene's units at the bladder's real size; [line]
  /// is a pixel.
  void paint(Canvas canvas, double line) {
    _paintShadow(canvas);
    // The ureters and the urethra behind it, cut short.
    _draw(canvas, _under);
    for (final TubeCourse ureter in form.ureters) {
      _paintEnd(canvas, ureter, _ductTone, DetrusorStyle.ductLight);
    }
    _paintEnd(canvas, form.urethra, _ductTone, DetrusorStyle.ductLight);
    // The muscle, flat in the mark, its bundles cut into it; the patch,
    // rimmed, the circular layer's bundles in it.
    canvas.drawPath(form.outline, Paint()..color = _home);
    canvas.save();
    canvas.clipPath(form.outline);
    _paintCreases(canvas, line, _bundles, DetrusorStyle.creaseAlpha);
    _paintCreases(canvas, line, _obliques, DetrusorStyle.obliqueAlpha);
    _paintCreases(canvas, line, _rings, DetrusorStyle.creaseAlpha);
    canvas.save();
    canvas.clipPath(_patch);
    _paintCreases(canvas, line, _circular, DetrusorStyle.creaseAlpha);
    _draw(canvas, _rim);
    canvas.restore();
    canvas.drawPath(
      _patch,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = math.max(
          form.mm(DetrusorStyle.patchEdge),
          DetrusorStyle.patchEdgeFloor * line,
        )
        ..color = inks.shadow.withValues(alpha: DetrusorStyle.patchEdgeAlpha),
    );
    canvas.restore();
    // The arteries ramifying over it and the urachus from its apex, cut
    // short.
    _draw(canvas, _over);
    for (final TubeCourse artery in form.arteries) {
      _paintEnd(canvas, artery, _arteryTone, DetrusorStyle.tubeLight);
    }
    // The outline's edge, as the other specimens'.
    canvas.drawPath(
      form.outline,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = line
        ..strokeJoin = StrokeJoin.round
        ..color = inks
            .lit(DetrusorStyle.edgeLit)
            .withValues(alpha: DetrusorStyle.edgeAlpha),
    );
  }

  void _paintEnd(
    Canvas canvas,
    TubeCourse tube,
    SpecimenTone tone,
    double light,
  ) => _end.paint(canvas, tube, tone, _light.light(0, 0, 1) * light);

  /// Bundles as crisp creases in the shadow ink, never thinner than a
  /// pixel or so.
  void _paintCreases(Canvas canvas, double line, Path creases, double alpha) =>
      canvas.drawPath(
        creases,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(
            form.mm(DetrusorStyle.crease),
            DetrusorStyle.creaseFloor * line,
          )
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = inks.shadow.withValues(alpha: alpha),
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

    add('ducts', _layDucts);
    add('arteries', _layArteries);
    add('urachus', _layUrachus);
    return out;
  }

  /// The colour the muscle is filled in. For tests.
  @visibleForTesting
  Map<String, Color> get fills => <String, Color>{'detrusor': _home};

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
