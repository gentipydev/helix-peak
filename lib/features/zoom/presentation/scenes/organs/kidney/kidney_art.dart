import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../zoom_inks.dart';
import '../../coloured_mesh.dart';
import '../../cut_face.dart';
import '../../opening_rim.dart';
import '../../specimen_light.dart';
import '../../tube_course.dart';
import '../../tube_end.dart';
import 'kidney_anatomy.dart';
import 'kidney_form.dart';
import 'kidney_style.dart';

/// The kidney cut open from front to back, drawn as a specimen under the
/// zoom's one lamp: where the zoom's cell lives flat in the mark, as the
/// brain's cortex is (its cortex, the outer medulla of its pyramids and the
/// medullary rays, its pyramids and rays, its papillae, or its glomeruli);
/// everywhere else the cortex a warm cut face turning away under the
/// capsule, the pyramids darker and redder, each a low cushion striated
/// down to its papilla; the medullary rays faint lines up through the
/// cortex among the dust of its glomeruli; the fat of the sinus warmed
/// toward the home helix's honey; the calyces and the pelvis emptied, in
/// shade, rimmed as the heart's chambers are; the renal artery and vein,
/// their branches and the arcuate arteries in the blood red, lit tubes, the
/// trunks cut short past the hilum; the ureter pale, fading out below.
///
/// Everything costly is built once, for one form and one set of inks:
/// meshes and paths in the scene's units, so a frame only hands them on.
final class KidneyArt {
  KidneyArt(this.form, this.inks)
    : _light = SpecimenLight(SpecimenLamp.zoom),
      _palette = SpecimenPalette(inks);

  final KidneyForm form;
  final ZoomInks inks;
  final SpecimenLight _light;
  final SpecimenPalette _palette;

  KidneyHome get home => form.home;

  /// Where the zoom's cell lives: one flat tone, the mark over a neutral,
  /// as the brain's cortex is.
  static Color homeOf(ZoomInks inks) => Color.alphaBlend(
    inks.glow(KidneyStyle.homeMark),
    inks.lit(KidneyStyle.homeLit),
  );

  /// The cortex's cut face where it faces the eye: what the step from the
  /// body draws the kidney's bed in, so that the cut comes up on its own
  /// tone; in the mark where the cortex is the cell's home.
  static Color bedOf(ZoomInks inks, KidneyHome home) {
    if (home == KidneyHome.cortex) {
      return homeOf(inks);
    }
    final SpecimenLight light = SpecimenLight(SpecimenLamp.zoom);
    return Color(
      SpecimenPalette(inks).colour(
        _cortexToneOf(inks),
        light.light(0, 0, 1),
        sheen: light.sheen(0, 0, 1) * KidneyStyle.cutSheen,
      ),
    );
  }

  static SpecimenTone _cortexToneOf(ZoomInks inks) => SpecimenTone(
    Color.lerp(
      inks.lit(KidneyStyle.cortexLit),
      inks.bases.thymine,
      KidneyStyle.cortexWarmth,
    )!,
    inks.shadow,
  );

  SpecimenTone _tone(Color colour) => SpecimenTone(colour, inks.shadow);

  late final Color _home = homeOf(inks);
  late final SpecimenTone _cortexTone = _cortexToneOf(inks);
  late final SpecimenTone _medullaTone = _tone(
    Color.lerp(
      inks.lit(KidneyStyle.medullaLit),
      inks.bases.thymine,
      KidneyStyle.medullaWarmth,
    )!,
  );
  late final SpecimenTone _papillaTone = _tone(
    Color.lerp(
      inks.lit(KidneyStyle.papillaLit),
      inks.bases.thymine,
      KidneyStyle.medullaWarmth,
    )!,
  );
  late final SpecimenTone _arteryTone = _tone(
    Color.lerp(inks.blood, inks.ground, KidneyStyle.artery)!,
  );
  late final SpecimenTone _veinTone = _tone(
    Color.lerp(inks.blood, inks.ground, KidneyStyle.vein)!,
  );
  late final SpecimenTone _ureterTone = _tone(
    Color.lerp(
      inks.lit(KidneyStyle.ureterLit),
      inks.bases.thymine,
      KidneyStyle.ureterWarmth,
    )!,
  );

  /// [tone]'s cut face where it faces the eye.
  Color _face(SpecimenTone tone) => Color(
    _palette.colour(
      tone,
      _light.light(0, 0, 1),
      sheen: _light.sheen(0, 0, 1) * KidneyStyle.cutSheen,
    ),
  );

  late final Color _cortex = home == KidneyHome.cortex
      ? _home
      : _face(_cortexTone);
  late final Color _medulla = _face(_medullaTone);
  late final Color _fat = Color.lerp(
    inks.lit(KidneyStyle.fatLit),
    inks.nerve,
    KidneyStyle.fatWarmth,
  )!;
  late final Color _cavity = inks.shade(KidneyStyle.cavityShade);
  late final Color _glomerulus = Color.lerp(
    inks.blood,
    inks.ground,
    KidneyStyle.glomerulusBlood,
  )!;

  late final CutFace _faceOf = CutFace(
    _light,
    _palette,
    sheen: KidneyStyle.cutSheen,
  );

  /// A pyramid's cut face cushioned a little across, and the cortex's edge
  /// turning away under the capsule.
  static const List<(double, double, double)> _cushion =
      <(double, double, double)>[
        (0, KidneyStyle.cushion, 0),
        (0.5, 0, 0),
        (1, -KidneyStyle.cushion, 0),
      ];
  static const List<(double, double, double)> _rim = <(double, double, double)>[
    (0, KidneyStyle.rimOuter, 0),
    (0.5, KidneyStyle.rimMiddle, 0),
    (1, 0, 0),
  ];

  static final List<double> _round = <double>[
    for (final double u in KidneyStyle.tubeColumns.reversed) -u,
    ...KidneyStyle.tubeColumns.skip(1),
  ];

  // The meshes.

  /// The cortex's edge under the capsule, where the cortex is not the
  /// cell's home: there it is one flat tone.
  late final List<ui.Vertices> _rimMesh = _build((ColouredMesh mesh) {
    if (home != KidneyHome.cortex) {
      _layRim(mesh);
    }
  });

  void _layRim(ColouredMesh mesh) =>
      _faceOf.lay(mesh, form.run, form.rimInner, (int _) => _cortexTone, _rim);

  /// The pyramids' cut faces, cushioned, their papillae a little paler;
  /// none where the pyramids are the cell's home, which are flat.
  late final List<ui.Vertices> _pyramidMeshes = _build((ColouredMesh mesh) {
    if (home != KidneyHome.ducts) {
      _layPyramids(mesh);
    }
  });

  void _layPyramids(ColouredMesh mesh) {
    for (final KidneyPyramid p in form.pyramids) {
      final int n = p.left.length;
      final int papilla = ((1 - KidneyAnatomy.papilla) * (n - 1)).round();
      _faceOf.lay(
        mesh,
        p.left,
        p.right,
        (int i) => i >= papilla ? _papillaTone : _medullaTone,
        _cushion,
      );
    }
  }

  /// The vessels and the ureter, each a lit tube.
  late final List<ui.Vertices> _innerVessels = _build((ColouredMesh mesh) {
    for (final TubeCourse t in form.veinBranches) {
      _layTube(mesh, t, _veinTone);
    }
    for (final TubeCourse t in form.segmental) {
      _layTube(mesh, t, _arteryTone);
    }
  });
  late final List<ui.Vertices> _parenchymaVessels = _build((ColouredMesh mesh) {
    for (final TubeCourse t in form.interlobar) {
      _layTube(mesh, t, _arteryTone);
    }
    for (final TubeCourse t in form.arcuate) {
      _layTube(mesh, t, _arteryTone);
    }
  });
  late final List<ui.Vertices> _trunks = _build((ColouredMesh mesh) {
    _layTube(mesh, form.renalVein, _veinTone);
    _layTube(mesh, form.renalArtery, _arteryTone);
  });
  late final List<ui.Vertices> _ureter = _build(
    (ColouredMesh mesh) => _layTube(
      mesh,
      form.ureter,
      _ureterTone,
      brightness: KidneyStyle.ureterLight,
    ),
  );

  void _layTube(
    ColouredMesh mesh,
    TubeCourse tube,
    SpecimenTone tone, {
    double brightness = KidneyStyle.tubeLight,
  }) => tube.lay(mesh, tone, _light, _palette, _round, brightness: brightness);

  late final TubeEnd _end = TubeEnd(
    _palette,
    inks.shadow,
    length: KidneyStyle.endLength,
    wall: KidneyStyle.endWall,
  );

  /// The calyces' and the pelvis's rim: a shadow just inside their edges
  /// that face the lamp, and light just inside those that turn from it.
  late final List<ui.Vertices> _collectingRim = _build((ColouredMesh mesh) {
    final OpeningRim rim = OpeningRim(
      toward: _light.screen,
      shadow: inks.shadow,
      light: inks.lit(KidneyStyle.lipLit),
      shadowWidth: form.mm(KidneyStyle.lipShadow),
      lightWidth: form.mm(KidneyStyle.lipLight),
      shadowAlpha: KidneyStyle.lipShadowAlpha,
      lightAlpha: KidneyStyle.lipLightAlpha,
      probe: form.mm(0.3),
    );
    for (final List<Offset> edge in form.collectingEdges) {
      rim.lay(mesh, <Offset>[...edge, edge.first], form.collecting);
    }
  });

  // The paths.

  // The pyramids lie apart, so their shapes are drawn as one path as they
  // are, never united: a union at the scene's scale, a millimetre a few
  // thousandths of a unit, can lose a part.
  late final Path _sinus = _polygons(<List<Offset>>[form.sinus]);
  late final Path _pyramids = _polygons(<List<Offset>>[
    for (final KidneyPyramid p in form.pyramids) p.outline,
  ]);
  late final Path _outer = _polygons(<List<Offset>>[
    for (final KidneyPyramid p in form.pyramids) p.outer,
  ]);
  late final Path _papillae = _polygons(<List<Offset>>[
    for (final KidneyPyramid p in form.pyramids) p.papilla,
  ]);
  late final Path _rays = () {
    final Path path = Path();
    for (final KidneyPyramid p in form.pyramids) {
      for (final (Offset a, Offset b) in p.rays) {
        path
          ..moveTo(a.dx, a.dy)
          ..lineTo(b.dx, b.dy);
      }
    }
    return path;
  }();
  late final Path _striations = () {
    final Path path = Path();
    for (final KidneyPyramid p in form.pyramids) {
      for (final List<Offset> line in p.striations) {
        path.addPolygon(line, false);
      }
    }
    return path;
  }();
  late final Path _capsule = Path()..addPolygon(form.run, false);
  late final Float32List _dust = Float32List.fromList(<double>[
    for (final Offset g in form.glomeruli) ...<double>[g.dx, g.dy],
  ]);

  // The shadow.

  void _paintShadow(Canvas canvas) {
    canvas.save();
    canvas.translate(
      form.mm(KidneyStyle.shadowX),
      form.mm(KidneyStyle.shadowY),
    );
    final Color shadow = inks.shadow;
    canvas.drawPath(
      form.outline,
      Paint()..color = shadow.withValues(alpha: KidneyStyle.shadowAlpha),
    );
    canvas.drawPath(
      form.outline,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = form.mm(KidneyStyle.shadowSoft)
        ..strokeJoin = StrokeJoin.round
        ..color = shadow.withValues(alpha: 0.12),
    );
    canvas.restore();
  }

  // Drawing.

  /// What the kidney and what is drawn beside it cover, its shadow
  /// included: the room a layer of it needs.
  late final Rect bounds = () {
    Rect box = form.box;
    for (final TubeCourse t in <TubeCourse>[
      form.renalArtery,
      form.renalVein,
      form.ureter,
    ]) {
      for (int i = 0; i < t.length; i++) {
        box = box.expandToInclude(
          Rect.fromCircle(center: t.centres[i], radius: t.radius[i]),
        );
      }
    }
    return box.inflate(form.mm(KidneyStyle.shadowY + KidneyStyle.shadowSoft));
  }();

  /// Builds every mesh and path a frame will draw.
  void prepare() => <Object?>[
    _rimMesh,
    _pyramidMeshes,
    _innerVessels,
    _parenchymaVessels,
    _trunks,
    _ureter,
    _collectingRim,
    _sinus,
    _pyramids,
    _outer,
    _papillae,
    _rays,
    _striations,
    _capsule,
    _dust,
    bounds,
  ];

  /// Draws it all, in the scene's units at the kidney's real size; [line]
  /// is a pixel.
  void paint(Canvas canvas, double line) {
    _paintShadow(canvas);
    // The ureter, running down from the pelvis beside the lower pole.
    _draw(canvas, _ureter);
    // The cortex, its edge turning away under the capsule; its rays and its
    // glomeruli.
    canvas.drawPath(form.outline, Paint()..color = _cortex);
    _draw(canvas, _rimMesh);
    _paintRays(canvas, line);
    if (home != KidneyHome.glomeruli) {
      _paintDust(canvas, line, _glomerulus, KidneyStyle.glomerulusFloor);
    }
    // The sinus: its fat, the branches of the vessels in it, and the
    // calyces and the pelvis, emptied.
    canvas.drawPath(_sinus, Paint()..color = _fat);
    _draw(canvas, _innerVessels);
    canvas.drawPath(form.collecting, Paint()..color = _cavity);
    canvas.save();
    canvas.clipPath(form.collecting);
    _draw(canvas, _collectingRim);
    canvas.restore();
    // The pyramids, their papillae standing into the calyces.
    _paintPyramids(canvas, line);
    // The arteries up the columns and over the pyramids' bases, the trunks
    // at the hilum, cut short past it.
    _draw(canvas, _parenchymaVessels);
    _draw(canvas, _trunks);
    for (final (TubeCourse tube, SpecimenTone tone)
        in <(TubeCourse, SpecimenTone)>[
          (form.renalVein, _veinTone),
          (form.renalArtery, _arteryTone),
        ]) {
      _end.paint(
        canvas,
        tube,
        tone,
        _light.light(0, 0, 1) * KidneyStyle.tubeLight,
      );
    }
    // The capsule's edge, as the other specimens' is.
    canvas.drawPath(
      _capsule,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = line
        ..strokeJoin = StrokeJoin.round
        ..color = inks
            .lit(KidneyStyle.edgeLit)
            .withValues(alpha: KidneyStyle.edgeAlpha),
    );
    // Where the glomeruli are the cell's home, their dust in the mark, and
    // the one at the site.
    if (home == KidneyHome.glomeruli) {
      _paintDust(canvas, line, inks.mark, KidneyStyle.homeGlomerulusFloor);
      final Offset? site = form.siteGlomerulus;
      if (site != null) {
        canvas.drawCircle(
          site,
          math.max(
            form.mm(KidneyAnatomy.glomerulus),
            KidneyStyle.homeGlomerulusFloor * line / 2,
          ),
          Paint()..color = inks.mark,
        );
      }
    }
  }

  void _paintRays(Canvas canvas, double line) {
    final bool marked = home == KidneyHome.loops || home == KidneyHome.ducts;
    canvas.drawPath(
      _rays,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = marked
            ? math.max(
                form.mm(KidneyAnatomy.ray),
                KidneyStyle.homeRayFloor * line,
              )
            : math.max(form.mm(KidneyAnatomy.ray), KidneyStyle.rayFloor * line)
        ..color = marked
            ? _home
            : inks.shadow.withValues(alpha: KidneyStyle.rayAlpha),
    );
  }

  void _paintDust(Canvas canvas, double line, Color colour, double floor) {
    canvas.drawRawPoints(
      ui.PointMode.points,
      _dust,
      Paint()
        ..strokeCap = StrokeCap.round
        ..strokeWidth = math.max(
          form.mm(2 * KidneyAnatomy.glomerulus),
          floor * line,
        )
        ..color = colour,
    );
  }

  void _paintPyramids(Canvas canvas, double line) {
    canvas.drawPath(
      _pyramids,
      Paint()..color = home == KidneyHome.ducts ? _home : _medulla,
    );
    _draw(canvas, _pyramidMeshes);
    if (home == KidneyHome.loops) {
      canvas.drawPath(_outer, Paint()..color = _home);
    } else if (home == KidneyHome.papillae) {
      canvas.drawPath(_papillae, Paint()..color = _home);
    }
    canvas.drawPath(
      _striations,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(
          form.mm(KidneyStyle.striation),
          KidneyStyle.striationFloor * line,
        )
        ..color = inks.shadow.withValues(alpha: KidneyStyle.striationAlpha),
    );
    canvas.drawPath(
      _pyramids,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(
          form.mm(KidneyStyle.edgeLine),
          KidneyStyle.edgeLineFloor * line,
        )
        ..strokeJoin = StrokeJoin.round
        ..color = inks.shadow.withValues(alpha: KidneyStyle.edgeLineAlpha),
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

    if (home != KidneyHome.cortex) {
      add('cortex', _layRim);
    }
    if (home != KidneyHome.ducts) {
      add('pyramids', _layPyramids);
    }
    add('vessels', (ColouredMesh mesh) {
      for (final TubeCourse t in <TubeCourse>[
        ...form.veinBranches,
        form.renalVein,
      ]) {
        _layTube(mesh, t, _veinTone);
      }
      for (final TubeCourse t in <TubeCourse>[
        ...form.segmental,
        ...form.interlobar,
        ...form.arcuate,
        form.renalArtery,
      ]) {
        _layTube(mesh, t, _arteryTone);
      }
    });
    add(
      'ureter',
      (ColouredMesh mesh) => _layTube(
        mesh,
        form.ureter,
        _ureterTone,
        brightness: KidneyStyle.ureterLight,
      ),
    );
    return out;
  }

  static Path _polygons(List<List<Offset>> polygons) {
    final Path out = Path();
    for (final List<Offset> p in polygons) {
      out.addPolygon(p, true);
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
