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
import 'prostate_anatomy.dart';
import 'prostate_form.dart';
import 'prostate_style.dart';

/// The prostate cut from front to back through its ejaculatory ducts,
/// drawn as a specimen under the zoom's one lamp: where the zoom's cell
/// lives flat in the mark (the glands of its peripheral and central zones,
/// cut by their ducts and the line between the zones; its stroma, the
/// capsule and the muscle round the urethra; or its urethra's lining);
/// everywhere else the peripheral zone a pale reddish grey cut face turning
/// away under its capsule, the central zone a shade deeper round the
/// ejaculatory ducts, the ducts fine shadowed lines, the glands' lumens
/// pores; the ejaculatory ducts pale walls round their lumens, the utricle
/// between them; the urethra laid open below the colliculus, its lumen
/// emptied in shade and rimmed, its lining pale, the crest down its floor
/// and the colliculus a pale mound with the utricle's and the ducts'
/// mouths on it, the sinuses' orifices beside the crest; the muscle round
/// it and the sphincter below warm; the seminal vesicles lit coiled sacs
/// and the ampullae lit cords above the base, fading out above; the
/// prostatic arteries coming in to the base's corners.
///
/// Everything costly is built once, for one form and one set of inks:
/// meshes and paths in the scene's units, so a frame only hands them on.
final class ProstateArt {
  ProstateArt(this.form, this.inks)
    : _light = SpecimenLight(SpecimenLamp.zoom),
      _palette = SpecimenPalette(inks);

  final ProstateForm form;
  final ZoomInks inks;
  final SpecimenLight _light;
  final SpecimenPalette _palette;

  ProstateHome get home => form.home;

  /// Where the zoom's cell lives: one flat tone, the mark over a neutral,
  /// as the kidney's cortex is.
  static Color homeOf(ZoomInks inks) => Color.alphaBlend(
    inks.glow(ProstateStyle.homeMark),
    inks.lit(ProstateStyle.homeLit),
  );

  /// The peripheral zone's cut face where it faces the eye: what the step
  /// from the body draws the prostate's bed in, so that the cut comes up on
  /// its own tone; in the mark where the glands are the cell's home.
  static Color bedOf(ZoomInks inks, ProstateHome home) {
    if (home == ProstateHome.glands) {
      return homeOf(inks);
    }
    final SpecimenLight light = SpecimenLight(SpecimenLamp.zoom);
    return Color(
      SpecimenPalette(inks).colour(
        _peripheralToneOf(inks),
        light.light(0, 0, 1),
        sheen: light.sheen(0, 0, 1) * ProstateStyle.cutSheen,
      ),
    );
  }

  static SpecimenTone _peripheralToneOf(ZoomInks inks) => SpecimenTone(
    _warmed(inks, ProstateStyle.peripheralLit, ProstateStyle.peripheralWarmth),
    inks.shadow,
  );

  static Color _warmed(ZoomInks inks, double lit, double warmth) =>
      Color.lerp(inks.lit(lit), inks.bases.thymine, warmth)!;

  SpecimenTone _tone(Color colour) => SpecimenTone(colour, inks.shadow);

  late final Color _home = homeOf(inks);
  late final SpecimenTone _peripheralTone = _peripheralToneOf(inks);
  late final SpecimenTone _centralTone = _tone(
    _warmed(inks, ProstateStyle.centralLit, ProstateStyle.centralWarmth),
  );
  late final SpecimenTone _muscleTone = _tone(
    _warmed(inks, ProstateStyle.muscleLit, ProstateStyle.muscleWarmth),
  );
  late final SpecimenTone _liningTone = _tone(
    _warmed(inks, ProstateStyle.liningLit, ProstateStyle.liningWarmth),
  );
  late final SpecimenTone _colliculusTone = _tone(
    _warmed(inks, ProstateStyle.colliculusLit, ProstateStyle.colliculusWarmth),
  );
  late final SpecimenTone _ductTone = _tone(
    _warmed(inks, ProstateStyle.ductLit, ProstateStyle.ductWarmth),
  );
  late final SpecimenTone _vesicleTone = _tone(
    Color.lerp(
      _warmed(inks, ProstateStyle.vesicleLit, ProstateStyle.vesicleWarmth),
      inks.nerve,
      ProstateStyle.vesicleHoney,
    )!,
  );
  late final SpecimenTone _ampullaTone = _tone(
    _warmed(inks, ProstateStyle.ampullaLit, ProstateStyle.ampullaWarmth),
  );
  late final SpecimenTone _arteryTone = _tone(
    Color.lerp(inks.blood, inks.ground, ProstateStyle.artery)!,
  );

  /// [tone]'s cut face where it faces the eye.
  Color _face(SpecimenTone tone) => Color(
    _palette.colour(
      tone,
      _light.light(0, 0, 1),
      sheen: _light.sheen(0, 0, 1) * ProstateStyle.cutSheen,
    ),
  );

  late final Color _peripheral = home == ProstateHome.glands
      ? _home
      : _face(_peripheralTone);
  late final Color _central = home == ProstateHome.glands
      ? _home
      : _face(_centralTone);
  late final Color _muscle = home == ProstateHome.stroma
      ? _home
      : _face(_muscleTone);
  late final Color _lining = home == ProstateHome.urethra
      ? _home
      : _face(_liningTone);
  late final Color _colliculus = home == ProstateHome.urethra
      ? _home
      : _face(_colliculusTone);
  late final Color _ductWall = _face(_ductTone);
  late final Color _lumen = inks.shade(ProstateStyle.lumenShade);
  late final Color _slit = inks.shade(ProstateStyle.slitShade);

  late final CutFace _faceOf = CutFace(
    _light,
    _palette,
    sheen: ProstateStyle.cutSheen,
  );

  /// The cut face turning away under the capsule.
  static const List<(double, double, double)> _rim = <(double, double, double)>[
    (0, ProstateStyle.rimOuter, 0),
    (0.5, ProstateStyle.rimMiddle, 0),
    (1, 0, 0),
  ];

  static final List<double> _round = <double>[
    for (final double u in ProstateStyle.tubeColumns.reversed) -u,
    ...ProstateStyle.tubeColumns.skip(1),
  ];

  // The meshes.

  /// The cut face's edge under its capsule, where the glands are not the
  /// cell's home: there the cut face is one flat tone to its edge.
  late final List<ui.Vertices> _rimMesh = _build((ColouredMesh mesh) {
    if (home != ProstateHome.glands) {
      _layRim(mesh);
    }
  });

  void _layRim(ColouredMesh mesh) => _faceOf.lay(
    mesh,
    <Offset>[...form.rimOuter, form.rimOuter.first],
    <Offset>[...form.rimInner, form.rimInner.first],
    (int _) => _peripheralTone,
    _rim,
  );

  /// The seminal vesicles, the ampullae over their medial margins, and the
  /// arteries; the sphincter below.
  late final List<ui.Vertices> _vesicleMesh = _build(_layVesicles);
  late final List<ui.Vertices> _ampullaMesh = _build(_layAmpullae);
  late final List<ui.Vertices> _arteryMesh = _build(_layArteries);
  late final List<ui.Vertices> _sphincterMesh = _build(_laySphincter);

  void _layVesicles(ColouredMesh mesh) {
    for (final TubeCourse t in form.vesicles) {
      _layTube(mesh, t, _vesicleTone);
    }
  }

  void _layAmpullae(ColouredMesh mesh) {
    for (final TubeCourse t in form.ampullae) {
      _layTube(mesh, t, _ampullaTone);
    }
  }

  void _layArteries(ColouredMesh mesh) {
    for (final TubeCourse t in form.arteries) {
      _layTube(mesh, t, _arteryTone);
    }
  }

  void _laySphincter(ColouredMesh mesh) =>
      _layTube(mesh, form.sphincter, _muscleTone);

  void _layTube(ColouredMesh mesh, TubeCourse tube, SpecimenTone tone) =>
      tube.lay(
        mesh,
        tone,
        _light,
        _palette,
        _round,
        brightness: ProstateStyle.tubeLight,
      );

  /// The creases between each vesicle's coils, across it, fading out with
  /// it: a mesh of thin quads in the shadow ink.
  late final List<ui.Vertices> _coilMesh = _build((ColouredMesh mesh) {
    for (final TubeCourse t in form.vesicles) {
      for (final double at in form.coilsAt) {
        int i = 0;
        while (i < t.length - 1 && t.arc[i] < at) {
          i++;
        }
        final double shown = t.shown[i];
        if (shown <= 0.01) {
          continue;
        }
        final Offset c = t.centres[i];
        final Offset across = t.across[i];
        final Offset along = Offset(across.dy, -across.dx);
        final double reach = t.radius[i] * ProstateStyle.coilReach;
        final double half = form.mm(ProstateStyle.coilCrease) / 2;
        // Bowed a little, as a crease round a coil is seen.
        final Offset bow = along * (t.radius[i] * 0.18);
        final List<Offset> line = <Offset>[
          for (int k = 0; k <= 8; k++)
            c +
                across * (reach * (k / 4 - 1)) +
                bow * (1 - (k / 4 - 1) * (k / 4 - 1)),
        ];
        final int colour = SpecimenPalette.packColour(
          inks.shadow,
          ProstateStyle.coilAlpha * shown,
        );
        mesh.begin(2 * line.length);
        final int first = mesh.next;
        for (int k = 0; k < line.length; k++) {
          final double taper = math.sin(math.pi * k / (line.length - 1));
          final Offset off = along * (half * (0.3 + 0.7 * taper));
          mesh
            ..vertex(line[k].dx + off.dx, line[k].dy + off.dy, colour)
            ..vertex(line[k].dx - off.dx, line[k].dy - off.dy, colour);
        }
        for (int k = 0; k + 1 < line.length; k++) {
          final int a = first + 2 * k;
          mesh
            ..triangle(a, a + 2, a + 1)
            ..triangle(a + 2, a + 3, a + 1);
        }
      }
    }
  });

  /// The urethra's rim: a shadow just inside its edge that faces the lamp,
  /// and light just inside the edge that turns from it.
  late final List<ui.Vertices> _lumenRim = _build((ColouredMesh mesh) {
    final OpeningRim rim = OpeningRim(
      toward: _light.screen,
      shadow: inks.shadow,
      light: inks.lit(ProstateStyle.lipLit),
      shadowWidth: form.mm(ProstateStyle.lipShadow),
      lightWidth: form.mm(ProstateStyle.lipLight),
      shadowAlpha: ProstateStyle.lipShadowAlpha,
      lightAlpha: ProstateStyle.lipLightAlpha,
      probe: form.mm(0.05),
    );
    rim.lay(mesh, <Offset>[
      ...form.urethra,
      form.urethra.first,
    ], Path()..addPolygon(form.urethra, true));
  });

  late final TubeEnd _end = TubeEnd(
    _palette,
    inks.shadow,
    length: ProstateStyle.endLength,
    wall: ProstateStyle.endWall,
  );

  // The paths.

  late final Path _outline = form.outline;
  late final Path _centralPath = Path()..addPolygon(form.central, true);
  late final Path _borders = _lines(form.centralBorders);
  late final Path _glandDucts = _lines(form.glandDucts);
  late final Path _pores = () {
    final Path path = Path();
    for (final (Offset p, double r) in form.pores) {
      path.addOval(Rect.fromCircle(center: p, radius: r));
    }
    return path;
  }();
  late final Path _sleevePath = Path()..addPolygon(form.sleeve, true);
  late final Path _urethraPath = Path()..addPolygon(form.urethra, true);
  late final Path _colliculusPath = Path()..addPolygon(form.colliculus, true);
  late final Path _utriclePath = Path()..addPolygon(form.utricle, true);
  late final Path _ductWalls = () {
    final Path path = Path();
    for (final List<Offset> w in form.ductWalls) {
      path.addPolygon(w, true);
    }
    return path;
  }();
  late final Path _ductLumens = _lines(form.ductLines);
  late final Path _crest = Path()
    ..moveTo(form.crest.$1.dx, form.crest.$1.dy)
    ..lineTo(form.crest.$2.dx, form.crest.$2.dy);
  late final Path _slits = () {
    final Path path = Path();
    void slit(Offset at, double across, double down) => path.addOval(
      Rect.fromCenter(
        center: at,
        width: form.mm(across),
        height: form.mm(down),
      ),
    );
    slit(form.utricleMouth, 0.4, 1.0);
    for (final Offset m in form.ductMouths) {
      slit(m, 0.24, 0.7);
    }
    for (final Offset o in form.orifices) {
      slit(o, 0.26, 0.26);
    }
    return path;
  }();

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
      form.mm(ProstateStyle.shadowX),
      form.mm(ProstateStyle.shadowY),
    );
    final Color shadow = inks.shadow;
    canvas.drawPath(
      _outline,
      Paint()..color = shadow.withValues(alpha: ProstateStyle.shadowAlpha),
    );
    canvas.drawPath(
      _outline,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = form.mm(ProstateStyle.shadowSoft)
        ..strokeJoin = StrokeJoin.round
        ..color = shadow.withValues(alpha: 0.12),
    );
    canvas.restore();
  }

  // Drawing.

  /// What the prostate and what is drawn round it cover, its shadow
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
    return box.inflate(
      form.mm(ProstateStyle.shadowY + ProstateStyle.shadowSoft),
    );
  }();

  /// Builds every mesh and path a frame will draw.
  void prepare() => <Object?>[
    _rimMesh,
    _vesicleMesh,
    _ampullaMesh,
    _arteryMesh,
    _sphincterMesh,
    _coilMesh,
    _lumenRim,
    _centralPath,
    _borders,
    _glandDucts,
    _pores,
    _sleevePath,
    _urethraPath,
    _colliculusPath,
    _utriclePath,
    _ductWalls,
    _ductLumens,
    _crest,
    _slits,
    bounds,
  ];

  /// Draws it all, in the scene's units at the prostate's real size; [line]
  /// is a pixel.
  void paint(Canvas canvas, double line) {
    // Above the base the seminal vesicles, coiled, and the ampullae along
    // their medial margins, fading out above; the arteries coming in to
    // the base's corners; below the apex the sphincter, cut short.
    _draw(canvas, _arteryMesh);
    _draw(canvas, _vesicleMesh);
    _draw(canvas, _coilMesh);
    _draw(canvas, _ampullaMesh);
    _draw(canvas, _sphincterMesh);
    _end.paint(
      canvas,
      form.sphincter,
      _muscleTone,
      _light.light(0, 0, 1) * ProstateStyle.tubeLight,
    );
    // The prostate, cut: its shadow, the peripheral zone and its edge
    // turning away under the capsule.
    _paintShadow(canvas);
    canvas.drawPath(_outline, Paint()..color = _peripheral);
    _draw(canvas, _rimMesh);
    canvas.save();
    canvas.clipPath(_outline);
    // The central zone round the ejaculatory ducts, the line between the
    // zones, the ducts of the glands and their lumens.
    canvas.drawPath(_centralPath, Paint()..color = _central);
    canvas.drawPath(
      _borders,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = math.max(
          form.mm(ProstateStyle.zoneLine),
          ProstateStyle.zoneFloor * line,
        )
        ..color = inks.shadow.withValues(alpha: ProstateStyle.zoneAlpha),
    );
    canvas.drawPath(
      _glandDucts,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = math.max(
          form.mm(ProstateStyle.ductLine),
          ProstateStyle.ductFloor * line,
        )
        ..color = inks.shadow.withValues(
          alpha: home == ProstateHome.glands
              ? ProstateStyle.homeDuctAlpha
              : ProstateStyle.ductAlpha,
        ),
    );
    canvas.drawPath(
      _pores,
      Paint()..color = inks.shadow.withValues(alpha: ProstateStyle.poreAlpha),
    );
    // Where the stroma is the cell's home, the capsule under the edge.
    if (home == ProstateHome.stroma) {
      canvas.drawPath(
        _outline,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeJoin = StrokeJoin.round
          ..strokeWidth =
              2 *
              math.max(
                form.mm(ProstateStyle.capsule),
                ProstateStyle.capsuleFloor * line,
              )
          ..color = _home,
      );
    }
    // The ejaculatory ducts and the utricle between them.
    canvas.drawPath(_ductWalls, Paint()..color = _ductWall);
    canvas.drawPath(
      _ductLumens,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = math.max(
          form.mm(2 * ProstateAnatomy.ductLumen),
          0.7 * line,
        )
        ..color = _slit,
    );
    canvas.drawPath(_utriclePath, Paint()..color = _slit);
    // The urethra laid open: the muscle round it, its lumen emptied and
    // rimmed, its lining, the crest down its floor and the colliculus on
    // it, with the utricle's and the ducts' mouths and the sinuses'
    // orifices.
    canvas.drawPath(_sleevePath, Paint()..color = _muscle);
    canvas.drawPath(_urethraPath, Paint()..color = _lumen);
    _draw(canvas, _lumenRim);
    canvas.drawPath(
      _urethraPath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = math.max(
          form.mm(ProstateStyle.lining),
          ProstateStyle.liningFloor * line,
        )
        ..color = _lining,
    );
    canvas.drawPath(
      _crest,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = form.mm(ProstateAnatomy.crestWidth)
        ..color = _colliculus,
    );
    canvas.drawPath(_colliculusPath, Paint()..color = _colliculus);
    canvas.drawPath(_slits, Paint()..color = _slit);
    canvas.restore();
    // The capsule's edge, as the other specimens'.
    canvas.drawPath(
      _outline,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = line
        ..strokeJoin = StrokeJoin.round
        ..color = inks
            .lit(ProstateStyle.edgeLit)
            .withValues(alpha: ProstateStyle.edgeAlpha),
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

    if (home != ProstateHome.glands) {
      add('rim', _layRim);
    }
    add('vesicles', _layVesicles);
    add('ampullae', _layAmpullae);
    add('arteries', _layArteries);
    add('sphincter', _laySphincter);
    return out;
  }

  /// The colours the cut face and what lies in it are drawn in, by name.
  /// For tests.
  @visibleForTesting
  Map<String, Color> get fills => <String, Color>{
    'peripheral': _peripheral,
    'central': _central,
    'muscle': _muscle,
    'lining': _lining,
    'colliculus': _colliculus,
    'duct': _ductWall,
    'lumen': _lumen,
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
