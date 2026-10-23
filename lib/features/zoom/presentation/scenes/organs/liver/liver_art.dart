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
import 'liver_anatomy.dart';
import 'liver_form.dart';
import 'liver_style.dart';

/// The liver cut open from front to back, drawn as a specimen under the
/// zoom's one lamp: where the zoom's cell lives in the mark (its
/// parenchyma flat, as the kidney's cortex is, or its bile ducts); else the
/// parenchyma a deep warm cut face turning away under the capsule; the
/// vena cava and the hepatic veins emptied, in shade, rimmed as the heart's
/// chambers are, bare; the portal veins emptied too, each in its pale
/// sheath with a bile duct in the honey and an artery in the blood red
/// beside it; the small vessels the cut crosses, holes in the face, the
/// portal tracts among them in their sheaths; the gallbladder cut open, its
/// wall pale and its bile honey in shade, its fundus past the lower border;
/// the vena cava cut short above, the portal vein and the hepatic artery
/// below, lit tubes, and the bile duct and the round ligament fading out
/// below.
///
/// Everything costly is built once, for one form and one set of inks:
/// meshes and paths in the scene's units, so a frame only hands them on.
final class LiverArt {
  LiverArt(this.form, this.inks)
    : _light = SpecimenLight(SpecimenLamp.zoom),
      _palette = SpecimenPalette(inks);

  final LiverForm form;
  final ZoomInks inks;
  final SpecimenLight _light;
  final SpecimenPalette _palette;

  LiverHome get home => form.home;

  /// Where the zoom's cell lives: one flat tone, the mark over a neutral,
  /// as the kidney's cortex is.
  static Color homeOf(ZoomInks inks) => Color.alphaBlend(
    inks.glow(LiverStyle.homeMark),
    inks.lit(LiverStyle.homeLit),
  );

  /// The parenchyma's cut face where it faces the eye: what the step from
  /// the body draws the liver's bed in, so that the cut comes up on its own
  /// tone; in the mark where the parenchyma is the cell's home.
  static Color bedOf(ZoomInks inks, LiverHome home) {
    if (home == LiverHome.parenchyma) {
      return homeOf(inks);
    }
    final SpecimenLight light = SpecimenLight(SpecimenLamp.zoom);
    return Color(
      SpecimenPalette(inks).colour(
        _parenchymaToneOf(inks),
        light.light(0, 0, 1),
        sheen: light.sheen(0, 0, 1) * LiverStyle.cutSheen,
      ),
    );
  }

  static SpecimenTone _parenchymaToneOf(ZoomInks inks) => SpecimenTone(
    Color.lerp(
      inks.lit(LiverStyle.parenchymaLit),
      inks.bases.thymine,
      LiverStyle.parenchymaWarmth,
    )!,
    inks.shadow,
  );

  SpecimenTone _tone(Color colour) => SpecimenTone(colour, inks.shadow);

  late final Color _home = homeOf(inks);
  late final SpecimenTone _parenchymaTone = _parenchymaToneOf(inks);
  late final SpecimenTone _arteryTone = _tone(
    Color.lerp(inks.blood, inks.ground, LiverStyle.artery)!,
  );
  late final SpecimenTone _veinTone = _tone(
    Color.lerp(inks.blood, inks.ground, LiverStyle.vein)!,
  );
  late final SpecimenTone _ductTone = _tone(
    home == LiverHome.ducts
        ? inks.mark
        : Color.lerp(
            inks.lit(LiverStyle.ductLit),
            inks.nerve,
            LiverStyle.ductHoney,
          )!,
  );
  late final SpecimenTone _ligamentTone = _tone(
    Color.lerp(
      inks.lit(LiverStyle.ligamentLit),
      inks.bases.thymine,
      LiverStyle.ligamentWarmth,
    )!,
  );
  late final SpecimenTone _wallTone = _tone(
    Color.lerp(
      inks.lit(LiverStyle.wallLit),
      inks.bases.thymine,
      LiverStyle.wallWarmth,
    )!,
  );

  /// [tone]'s cut face where it faces the eye.
  Color _face(SpecimenTone tone) => Color(
    _palette.colour(
      tone,
      _light.light(0, 0, 1),
      sheen: _light.sheen(0, 0, 1) * LiverStyle.cutSheen,
    ),
  );

  late final Color _parenchyma = home == LiverHome.parenchyma
      ? _home
      : _face(_parenchymaTone);
  late final Color _cavity = inks.shade(LiverStyle.cavityShade);
  late final Color _sheath = Color.lerp(
    inks.lit(LiverStyle.sheathLit),
    inks.bases.thymine,
    LiverStyle.sheathWarmth,
  )!;
  late final Color _bile = Color.lerp(
    inks.shade(LiverStyle.bileShade),
    inks.nerve,
    LiverStyle.bileHoney,
  )!;
  late final Color _duct = home == LiverHome.ducts
      ? inks.mark
      : Color.lerp(inks.nerve, inks.ground, 0.2)!;
  late final Color _artery = Color.lerp(
    inks.blood,
    inks.ground,
    LiverStyle.artery,
  )!;
  late final Color _wall = _face(_wallTone);

  late final CutFace _faceOf = CutFace(
    _light,
    _palette,
    sheen: LiverStyle.cutSheen,
  );

  /// The parenchyma's edge turning away under the capsule.
  static const List<(double, double, double)> _rim = <(double, double, double)>[
    (0, LiverStyle.rimOuter, 0),
    (0.5, LiverStyle.rimMiddle, 0),
    (1, 0, 0),
  ];

  static final List<double> _round = <double>[
    for (final double u in LiverStyle.tubeColumns.reversed) -u,
    ...LiverStyle.tubeColumns.skip(1),
  ];

  // The meshes.

  /// The parenchyma's edge under the capsule, where the parenchyma is not
  /// the cell's home: there it is one flat tone.
  late final List<ui.Vertices> _rimMesh = _build((ColouredMesh mesh) {
    if (home != LiverHome.parenchyma) {
      _layRim(mesh);
    }
  });

  void _layRim(ColouredMesh mesh) => _faceOf.lay(
    mesh,
    <Offset>[...form.outlinePoints, form.outlinePoints.first],
    <Offset>[...form.rimInner, form.rimInner.first],
    (int _) => _parenchymaTone,
    _rim,
  );

  /// What runs on beside the liver, each a lit tube: the vena cava above
  /// it, the portal vein, the hepatic artery, the bile duct and the round
  /// ligament below.
  late final List<ui.Vertices> _beside = _build(_layBeside);

  void _layBeside(ColouredMesh mesh) {
    _layTube(mesh, form.cava, _veinTone);
    _layTube(mesh, form.roundLigament, _ligamentTone, LiverStyle.paleLight);
    _layTube(mesh, form.bileDuct, _ductTone, LiverStyle.paleLight);
    _layTube(mesh, form.portalVein, _veinTone);
    _layTube(mesh, form.hepaticArtery, _arteryTone);
  }

  void _layTube(
    ColouredMesh mesh,
    TubeCourse tube,
    SpecimenTone tone, [
    double brightness = LiverStyle.tubeLight,
  ]) => tube.lay(mesh, tone, _light, _palette, _round, brightness: brightness);

  late final TubeEnd _end = TubeEnd(
    _palette,
    inks.shadow,
    length: LiverStyle.endLength,
    wall: LiverStyle.endWall,
  );

  /// The emptied veins' rims: a shadow just inside their edges that face
  /// the lamp, and light just inside those that turn from it.
  late final OpeningRim _opening = OpeningRim(
    toward: _light.screen,
    shadow: inks.shadow,
    light: inks.lit(LiverStyle.lipLit),
    shadowWidth: form.mm(LiverStyle.lipShadow),
    lightWidth: form.mm(LiverStyle.lipLight),
    shadowAlpha: LiverStyle.lipShadowAlpha,
    lightAlpha: LiverStyle.lipLightAlpha,
    probe: form.mm(0.3),
  );
  late final List<ui.Vertices> _veinRims = _build((ColouredMesh mesh) {
    for (final List<Offset> edge in form.veinEdges) {
      _opening.lay(mesh, <Offset>[...edge, edge.first], form.veins);
    }
  });
  late final List<ui.Vertices> _portalRims = _build((ColouredMesh mesh) {
    for (final List<Offset> edge in form.portalEdges) {
      _opening.lay(mesh, <Offset>[...edge, edge.first], form.portal);
    }
  });
  late final List<ui.Vertices> _bileRim = _build(
    (ColouredMesh mesh) => _opening.lay(mesh, <Offset>[
      ...form.gallbladder,
      form.gallbladder.first,
    ], _gallbladder),
  );

  // The paths.

  late final Path _gallbladder = Path()..addPolygon(form.gallbladder, true);
  late final Path _gallbladderWall = Path()
    ..addPolygon(form.gallbladderWall, true);
  late final Path _smallLumens = () {
    final Path path = Path();
    for (final LiverVessel v in form.small) {
      path.addPolygon(v.lumen, true);
    }
    return path;
  }();
  late final Path _smallSheaths = () {
    final Path path = Path();
    for (final LiverVessel v in form.small) {
      final List<Offset>? sheath = v.sheath;
      if (sheath != null) {
        path.addPolygon(sheath, true);
      }
    }
    return path;
  }();

  /// The small portal tracts' ducts: a point on each sheath's edge.
  late final Float32List _smallDucts = Float32List.fromList(<double>[
    for (final LiverVessel v in form.small)
      if (v.sheath case final List<Offset> sheath) ...<double>[
        sheath.first.dx,
        sheath.first.dy,
      ],
  ]);
  late final Path _ducts = _lines(form.ducts);
  late final Path _arteries = _lines(form.arteries);

  // The shadow.

  void _paintShadow(Canvas canvas) {
    canvas.save();
    canvas.translate(form.mm(LiverStyle.shadowX), form.mm(LiverStyle.shadowY));
    final Color shadow = inks.shadow;
    canvas.drawPath(
      form.outline,
      Paint()..color = shadow.withValues(alpha: LiverStyle.shadowAlpha),
    );
    canvas.drawPath(
      form.outline,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = form.mm(LiverStyle.shadowSoft)
        ..strokeJoin = StrokeJoin.round
        ..color = shadow.withValues(alpha: 0.12),
    );
    canvas.restore();
  }

  // Drawing.

  /// What the liver and what is drawn beside it cover, its shadow
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
    for (final Offset p in form.gallbladderWall) {
      box = box.expandToInclude(Rect.fromCircle(center: p, radius: 0));
    }
    return box.inflate(form.mm(LiverStyle.shadowY + LiverStyle.shadowSoft));
  }();

  /// Builds every mesh and path a frame will draw.
  void prepare() => <Object?>[
    _rimMesh,
    _beside,
    _veinRims,
    _portalRims,
    _bileRim,
    _gallbladder,
    _gallbladderWall,
    _smallLumens,
    _smallSheaths,
    _smallDucts,
    _ducts,
    _arteries,
    bounds,
  ];

  /// Draws it all, in the scene's units at the liver's real size; [line] is
  /// a pixel.
  void paint(Canvas canvas, double line) {
    _paintShadow(canvas);
    // What runs on beside it, under it, cut short or fading out.
    _draw(canvas, _beside);
    for (final (TubeCourse tube, SpecimenTone tone)
        in <(TubeCourse, SpecimenTone)>[
          (form.cava, _veinTone),
          (form.portalVein, _veinTone),
          (form.hepaticArtery, _arteryTone),
        ]) {
      _end.paint(
        canvas,
        tube,
        tone,
        _light.light(0, 0, 1) * LiverStyle.tubeLight,
      );
    }
    // The parenchyma, its edge turning away under the capsule.
    canvas.drawPath(form.outline, Paint()..color = _parenchyma);
    _draw(canvas, _rimMesh);
    canvas.save();
    canvas.clipPath(form.outline);
    // The small vessels the cut crosses, the portal tracts in their
    // sheaths.
    canvas.drawPath(_smallSheaths, Paint()..color = _sheath);
    canvas.drawPath(_smallLumens, Paint()..color = _cavity);
    _paintSmallDucts(canvas, line);
    // The portal veins in their sheaths, a bile duct and an artery beside
    // each; the bile duct, the cystic duct and the hepatic artery where the
    // cut shows them in the porta; and the veins themselves, emptied, over
    // where those start, and the hepatic veins and the vena cava.
    canvas.drawPath(form.sheaths, Paint()..color = _sheath);
    _paintLines(canvas, line);
    _paintCavity(canvas, line, form.portal, _portalRims);
    _paintCavity(canvas, line, form.veins, _veinRims);
    canvas.restore();
    // The gallbladder, cut open in its fossa, its fundus past the border.
    canvas.drawPath(_gallbladderWall, Paint()..color = _wall);
    canvas.drawPath(_gallbladder, Paint()..color = _bile);
    canvas.save();
    canvas.clipPath(_gallbladder);
    _draw(canvas, _bileRim);
    canvas.restore();
    // The capsule's edge, and the gallbladder's, as the other specimens'.
    final Paint edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = line
      ..strokeJoin = StrokeJoin.round
      ..color = inks
          .lit(LiverStyle.edgeLit)
          .withValues(alpha: LiverStyle.edgeAlpha);
    canvas.drawPath(form.outline, edge);
    canvas.drawPath(_gallbladderWall, edge);
  }

  void _paintCavity(
    Canvas canvas,
    double line,
    Path cavity,
    List<ui.Vertices> rims,
  ) {
    canvas.drawPath(cavity, Paint()..color = _cavity);
    canvas.save();
    canvas.clipPath(cavity);
    _draw(canvas, rims);
    canvas.restore();
    canvas.drawPath(
      cavity,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(
          form.mm(LiverStyle.edgeLine),
          LiverStyle.edgeLineFloor * line,
        )
        ..strokeJoin = StrokeJoin.round
        ..color = inks.shadow.withValues(alpha: LiverStyle.edgeLineAlpha),
    );
  }

  void _paintLines(Canvas canvas, double line) {
    final bool marked = home == LiverHome.ducts;
    Paint stroke(Color colour, double width) => Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = width
      ..color = colour;
    final double duct = math.max(
      form.mm(LiverAnatomy.duct),
      (marked ? LiverStyle.homeDuctFloor : LiverStyle.ductFloor) * line,
    );
    canvas.drawPath(
      _arteries,
      stroke(
        _artery,
        math.max(form.mm(LiverAnatomy.duct), LiverStyle.arteryFloor * line),
      ),
    );
    canvas.drawPath(
      form.hepaticArtery.line,
      stroke(_artery, 2 * form.hepaticArtery.radius.first),
    );
    canvas.drawPath(_ducts, stroke(_duct, duct));
    for (final TubeCourse t in <TubeCourse>[form.bileDuct, form.cysticDuct]) {
      canvas.drawPath(t.line, stroke(_duct, 2 * t.radius.first));
    }
  }

  void _paintSmallDucts(Canvas canvas, double line) {
    canvas.drawRawPoints(
      ui.PointMode.points,
      _smallDucts,
      Paint()
        ..strokeCap = StrokeCap.round
        ..strokeWidth = math.max(
          form.mm(LiverAnatomy.duct),
          (home == LiverHome.ducts
                  ? LiverStyle.homeDuctFloor
                  : LiverStyle.ductFloor) *
              line,
        )
        ..color = _duct,
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

    if (home != LiverHome.parenchyma) {
      add('parenchyma', _layRim);
    }
    add('cava', (ColouredMesh mesh) => _layTube(mesh, form.cava, _veinTone));
    add(
      'round ligament',
      (ColouredMesh mesh) => _layTube(
        mesh,
        form.roundLigament,
        _ligamentTone,
        LiverStyle.paleLight,
      ),
    );
    add(
      'bile duct',
      (ColouredMesh mesh) =>
          _layTube(mesh, form.bileDuct, _ductTone, LiverStyle.paleLight),
    );
    add(
      'portal vein',
      (ColouredMesh mesh) => _layTube(mesh, form.portalVein, _veinTone),
    );
    add(
      'hepatic artery',
      (ColouredMesh mesh) => _layTube(mesh, form.hepaticArtery, _arteryTone),
    );
    return out;
  }

  static Path _lines(List<List<Offset>> lines) {
    final Path out = Path();
    for (final List<Offset> l in lines) {
      out.addPolygon(l, false);
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
