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
import 'ovary_anatomy.dart';
import 'ovary_form.dart';
import 'ovary_style.dart';

/// The ovary cut through its thickness, drawn as a specimen under the
/// zoom's one lamp: where the zoom's cell lives in the mark, its follicles
/// (each one's granulosa and cumulus, and the dust of the earliest under
/// the surface) or its stroma, flat; everywhere else the cortex a pale warm
/// cut face turning away under its covering, the medulla deeper and redder
/// about the hilum, its helicine vessels cut across in the blood red; the
/// follicles' antra emptied, in shade, rimmed as the kidney's calyces are,
/// each ringed by its granulosa, its theca warmer outside it, its cumulus
/// standing into it with the oocyte; the corpus luteum a band of the
/// adrenal cortex's yellow thrown into folds round a pale core; the
/// corpora albicantia pale, convoluted scars; the tube a lit tube in the
/// fallopian tube's own tone, its fimbriae lit fingers by the tubal pole;
/// the ligament of the ovary a pale lit cord; the ovarian vessels in the
/// blood red, coming up out of the hilum; each cut short where it leaves.
///
/// Everything costly is built once, for one form and one set of inks:
/// meshes and paths in the scene's units, so a frame only hands them on.
final class OvaryArt {
  OvaryArt(this.form, this.inks)
    : _light = SpecimenLight(SpecimenLamp.zoom),
      _palette = SpecimenPalette(inks);

  final OvaryForm form;
  final ZoomInks inks;
  final SpecimenLight _light;
  final SpecimenPalette _palette;

  OvaryHome get home => form.home;

  /// Where the zoom's cell lives: one flat tone, the mark over a neutral,
  /// as the kidney's cortex is.
  static Color homeOf(ZoomInks inks) => Color.alphaBlend(
    inks.glow(OvaryStyle.homeMark),
    inks.lit(OvaryStyle.homeLit),
  );

  /// The cortex's cut face where it faces the eye: what the step from the
  /// body draws the ovary's bed in, so that the cut comes up on its own
  /// tone; in the mark where the stroma is the cell's home.
  static Color bedOf(ZoomInks inks, OvaryHome home) {
    if (home == OvaryHome.stroma) {
      return homeOf(inks);
    }
    final SpecimenLight light = SpecimenLight(SpecimenLamp.zoom);
    return Color(
      SpecimenPalette(inks).colour(
        _cortexToneOf(inks),
        light.light(0, 0, 1),
        sheen: light.sheen(0, 0, 1) * OvaryStyle.cutSheen,
      ),
    );
  }

  static SpecimenTone _cortexToneOf(ZoomInks inks) => SpecimenTone(
    _warmed(inks, OvaryStyle.cortexLit, OvaryStyle.cortexWarmth),
    inks.shadow,
  );

  static Color _warmed(ZoomInks inks, double lit, double warmth) =>
      Color.lerp(inks.lit(lit), inks.bases.thymine, warmth)!;

  SpecimenTone _tone(Color colour) => SpecimenTone(colour, inks.shadow);

  late final Color _home = homeOf(inks);
  late final SpecimenTone _cortexTone = _cortexToneOf(inks);
  late final SpecimenTone _medullaTone = _tone(
    _warmed(inks, OvaryStyle.medullaLit, OvaryStyle.medullaWarmth),
  );
  late final SpecimenTone _luteumTone = _tone(
    Color.lerp(
      inks.lit(OvaryStyle.luteumLit),
      inks.nerve,
      OvaryStyle.luteumHoney,
    )!,
  );
  late final SpecimenTone _coreTone = _tone(
    _warmed(inks, OvaryStyle.coreLit, OvaryStyle.coreWarmth),
  );
  late final SpecimenTone _albicansTone = _tone(
    _warmed(inks, OvaryStyle.albicansLit, OvaryStyle.albicansWarmth),
  );
  late final SpecimenTone _granulosaTone = _tone(
    _warmed(inks, OvaryStyle.granulosaLit, OvaryStyle.granulosaWarmth),
  );
  late final SpecimenTone _thecaTone = _tone(
    _warmed(inks, OvaryStyle.thecaLit, OvaryStyle.thecaWarmth),
  );
  late final SpecimenTone _arteryTone = _tone(
    Color.lerp(inks.blood, inks.ground, OvaryStyle.artery)!,
  );
  late final SpecimenTone _veinTone = _tone(
    Color.lerp(inks.blood, inks.ground, OvaryStyle.vein)!,
  );
  late final SpecimenTone _tubeTone = _tone(
    _warmed(inks, OvaryStyle.tubeLit, OvaryStyle.tubeWarmth),
  );
  late final SpecimenTone _ligamentTone = _tone(
    _warmed(inks, OvaryStyle.ligamentLit, OvaryStyle.ligamentWarmth),
  );

  /// [tone]'s cut face where it faces the eye.
  Color _face(SpecimenTone tone) => Color(
    _palette.colour(
      tone,
      _light.light(0, 0, 1),
      sheen: _light.sheen(0, 0, 1) * OvaryStyle.cutSheen,
    ),
  );

  late final Color _cortex = home == OvaryHome.stroma
      ? _home
      : _face(_cortexTone);
  late final Color _medulla = home == OvaryHome.stroma
      ? _home
      : _face(_medullaTone);
  late final Color _luteum = _face(_luteumTone);
  late final Color _core = _face(_coreTone);
  late final Color _albicans = _face(_albicansTone);
  late final Color _granulosa = home == OvaryHome.follicles
      ? inks.mark
      : _face(_granulosaTone);
  late final Color _theca = _face(_thecaTone);
  late final Color _oocyte = inks.lit(OvaryStyle.oocyteLit);
  late final Color _antrum = inks.shade(OvaryStyle.antrumShade);
  late final Color _arteryWall = _face(_arteryTone);
  late final Color _veinWall = _face(_veinTone);
  late final Color _lumen = inks.shade(OvaryStyle.lumenShade);

  late final CutFace _faceOf = CutFace(
    _light,
    _palette,
    sheen: OvaryStyle.cutSheen,
  );

  /// The cortex's edge under its covering, turning away.
  static const List<(double, double, double)> _rim = <(double, double, double)>[
    (0, OvaryStyle.rimOuter, 0),
    (0.5, OvaryStyle.rimMiddle, 0),
    (1, 0, 0),
  ];

  static final List<double> _round = <double>[
    for (final double u in OvaryStyle.tubeColumns.reversed) -u,
    ...OvaryStyle.tubeColumns.skip(1),
  ];

  // The meshes.

  /// The cortex's edge under its covering, where the stroma is not the
  /// cell's home: there it is one flat tone.
  late final List<ui.Vertices> _rimMesh = _build((ColouredMesh mesh) {
    if (home != OvaryHome.stroma) {
      _layRim(mesh);
    }
  });

  void _layRim(ColouredMesh mesh) =>
      _faceOf.lay(mesh, form.run, form.rimInner, (int _) => _cortexTone, _rim);

  /// The tube and its fimbriae; the ligament of the ovary; the ovarian
  /// vessels: each a lit tube.
  late final List<ui.Vertices> _tubeMesh = _build(_layTubes);
  late final List<ui.Vertices> _ligamentMesh = _build(
    (ColouredMesh mesh) => _layTube(mesh, form.ligament, _ligamentTone),
  );
  late final List<ui.Vertices> _vesselMesh = _build(_layVessels);

  void _layTubes(ColouredMesh mesh) {
    for (final TubeCourse f in form.fimbriae) {
      _layTube(mesh, f, _tubeTone);
    }
    _layTube(mesh, form.tube, _tubeTone);
  }

  void _layVessels(ColouredMesh mesh) {
    _layTube(mesh, form.vein, _veinTone);
    _layTube(mesh, form.artery, _arteryTone);
  }

  void _layTube(ColouredMesh mesh, TubeCourse tube, SpecimenTone tone) =>
      tube.lay(
        mesh,
        tone,
        _light,
        _palette,
        _round,
        brightness: OvaryStyle.tubeLight,
      );

  late final TubeEnd _end = TubeEnd(
    _palette,
    inks.shadow,
    length: OvaryStyle.endLength,
    wall: OvaryStyle.endWall,
  );

  /// Each antrum's rim: a shadow just inside its edge that faces the lamp,
  /// and light just inside the edge that turns from it, as the kidney's
  /// calyces have; narrower in the small follicles.
  late final List<ui.Vertices> _antrumRims = _build((ColouredMesh mesh) {
    for (final OvaryFollicle f in form.follicles) {
      final double r = f.radius - f.granulosa;
      final OpeningRim rim = OpeningRim(
        toward: _light.screen,
        shadow: inks.shadow,
        light: inks.lit(OvaryStyle.lipLit),
        shadowWidth: math.min(form.mm(OvaryStyle.lipShadow), 0.3 * r),
        lightWidth: math.min(form.mm(OvaryStyle.lipLight), 0.15 * r),
        shadowAlpha: OvaryStyle.lipShadowAlpha,
        lightAlpha: OvaryStyle.lipLightAlpha,
        probe: 0.05 * r,
      );
      final List<Offset> circle = _circle(f.centre, r);
      rim.lay(mesh, <Offset>[
        ...circle,
        circle.first,
      ], Path()..addOval(Rect.fromCircle(center: f.centre, radius: r)));
    }
  });

  // The paths.

  late final Path _outline = form.outline;
  late final Path _medullaPath = Path()..addPolygon(form.medulla, true);
  late final Path _luteumPath = Path()..addPolygon(form.luteum, true);
  late final Path _corePath = Path()..addPolygon(form.luteumCore, true);
  late final Path _albicantiaPath = _polygons(form.albicantia);
  late final Path _surface = Path()..addPolygon(form.run, false);
  late final Path _luteumCreases = () {
    final Path path = Path();
    for (final (Offset a, Offset b) in form.luteumCreases) {
      path
        ..moveTo(a.dx, a.dy)
        ..lineTo(b.dx, b.dy);
    }
    return path;
  }();
  late final Path _albicansCreases = () {
    final Path path = Path();
    for (final List<Offset> line in form.albicantiaCreases) {
      path.addPolygon(line, false);
    }
    return path;
  }();
  late final Path _arteryWalls = _profiles(artery: true, inner: false);
  late final Path _arteryLumens = _profiles(artery: true, inner: true);
  late final Path _veinWalls = _profiles(artery: false, inner: false);
  late final Path _veinLumens = _profiles(artery: false, inner: true);
  late final Path _antra = () {
    final Path path = Path();
    for (final OvaryFollicle f in form.follicles) {
      path.addOval(
        Rect.fromCircle(center: f.centre, radius: f.radius - f.granulosa),
      );
    }
    return path;
  }();
  late final Path _cumuli = () {
    final Path path = Path();
    for (final OvaryFollicle f in form.follicles) {
      path.addOval(Rect.fromCircle(center: f.cumulus, radius: f.cumulusRadius));
    }
    return path;
  }();
  late final Float32List _primordial = _points(form.primordial);
  late final Float32List _growing = _points(form.growing);

  /// The helicine vessels' profiles, each an oval lying along its cut:
  /// their walls' outer edges, or their lumens' where [inner].
  Path _profiles({required bool artery, required bool inner}) {
    final Path path = Path();
    for (final OvaryProfile p in form.profiles) {
      if (p.artery != artery) {
        continue;
      }
      final double share = inner ? 1 - p.wall : 1;
      final double c = math.cos(p.angle);
      final double s = math.sin(p.angle);
      path.addPolygon(<Offset>[
        for (int k = 0; k < 20; k++)
          () {
            final double t = 2 * math.pi * k / 20;
            final double a = p.along * share * math.cos(t);
            final double b = p.across * share * math.sin(t);
            return p.centre + Offset(a * c - b * s, a * s + b * c);
          }(),
      ], true);
    }
    return path;
  }

  // The shadow.

  void _paintShadow(Canvas canvas) {
    canvas.save();
    canvas.translate(form.mm(OvaryStyle.shadowX), form.mm(OvaryStyle.shadowY));
    final Color shadow = inks.shadow;
    canvas.drawPath(
      _outline,
      Paint()..color = shadow.withValues(alpha: OvaryStyle.shadowAlpha),
    );
    canvas.drawPath(
      _outline,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = form.mm(OvaryStyle.shadowSoft)
        ..strokeJoin = StrokeJoin.round
        ..color = shadow.withValues(alpha: 0.12),
    );
    canvas.restore();
  }

  // Drawing.

  /// What the ovary and what is drawn round it cover, its shadow included:
  /// the room a layer of it needs.
  late final Rect bounds = () {
    Rect box = form.box;
    for (final TubeCourse t in form.beside) {
      for (int i = 0; i < t.length; i++) {
        box = box.expandToInclude(
          Rect.fromCircle(center: t.centres[i], radius: t.radius[i]),
        );
      }
    }
    return box.inflate(form.mm(OvaryStyle.shadowY + OvaryStyle.shadowSoft));
  }();

  /// Builds every mesh and path a frame will draw.
  void prepare() => <Object?>[
    _rimMesh,
    _tubeMesh,
    _ligamentMesh,
    _vesselMesh,
    _antrumRims,
    _medullaPath,
    _luteumPath,
    _corePath,
    _albicantiaPath,
    _surface,
    _luteumCreases,
    _albicansCreases,
    _arteryWalls,
    _arteryLumens,
    _veinWalls,
    _veinLumens,
    _antra,
    _cumuli,
    _primordial,
    _growing,
    bounds,
  ];

  /// Draws it all, in the scene's units at the ovary's real size; [line]
  /// is a pixel.
  void paint(Canvas canvas, double line) {
    // The ovarian vessels coming up out of the hilum and the ligament of
    // the ovary, each cut short; the tube over them, its fimbriae by the
    // tubal pole.
    _draw(canvas, _vesselMesh);
    _draw(canvas, _ligamentMesh);
    _draw(canvas, _tubeMesh);
    final double cutLight = _light.light(0, 0, 1) * OvaryStyle.tubeLight;
    _end.paint(canvas, form.vein, _veinTone, cutLight);
    _end.paint(canvas, form.artery, _arteryTone, cutLight);
    _end.paint(canvas, form.ligament, _ligamentTone, cutLight);
    _end.paint(canvas, form.tube, _tubeTone, cutLight);
    // The ovary: its shadow, its cortex, its edge turning away under its
    // covering, its medulla about the hilum.
    _paintShadow(canvas);
    canvas.drawPath(_outline, Paint()..color = _cortex);
    _draw(canvas, _rimMesh);
    canvas.save();
    canvas.clipPath(_outline);
    canvas.drawPath(_medullaPath, Paint()..color = _medulla);
    if (home != OvaryHome.stroma) {
      canvas.drawPath(
        _medullaPath,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(
            form.mm(OvaryStyle.edgeLine),
            OvaryStyle.edgeLineFloor * line,
          )
          ..color = inks.shadow.withValues(alpha: OvaryStyle.medullaEdgeAlpha),
      );
    }
    canvas.restore();
    // The helicine vessels cut across in the medulla.
    canvas.drawPath(_veinWalls, Paint()..color = _veinWall);
    canvas.drawPath(_arteryWalls, Paint()..color = _arteryWall);
    canvas.drawPath(_veinLumens, Paint()..color = _lumen);
    canvas.drawPath(_arteryLumens, Paint()..color = _lumen);
    // The corpora albicantia, and the corpus luteum.
    _paintCorpora(canvas, line);
    // The follicles.
    _paintFollicles(canvas, line);
    // Where the follicles are the cell's home, the dust of the earliest
    // under the surface, in the mark.
    if (home == OvaryHome.follicles) {
      _paintDust(canvas, line, _primordial, form.mm(OvaryAnatomy.primordial));
      _paintDust(canvas, line, _growing, form.mm(OvaryAnatomy.growing));
    }
    // The surface's edge, as the other specimens' is: round the cortex,
    // open where the hilum meets the mesovarium.
    canvas.drawPath(
      _surface,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = line
        ..strokeJoin = StrokeJoin.round
        ..color = inks
            .lit(OvaryStyle.edgeLit)
            .withValues(alpha: OvaryStyle.edgeAlpha),
    );
  }

  void _paintCorpora(Canvas canvas, double line) {
    final Paint edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = math.max(
        form.mm(OvaryStyle.edgeLine),
        OvaryStyle.edgeLineFloor * line,
      )
      ..color = inks.shadow.withValues(alpha: OvaryStyle.edgeLineAlpha);
    canvas.drawPath(_albicantiaPath, Paint()..color = _albicans);
    canvas.drawPath(
      _albicansCreases,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = math.max(
          form.mm(OvaryStyle.crease),
          OvaryStyle.edgeLineFloor * line,
        )
        ..color = inks.shadow.withValues(alpha: OvaryStyle.albicansCreaseAlpha),
    );
    canvas.drawPath(_albicantiaPath, edge);
    canvas.drawPath(_luteumPath, Paint()..color = _luteum);
    canvas.drawPath(_corePath, Paint()..color = _core);
    canvas.drawPath(
      _luteumCreases,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = math.max(
          form.mm(OvaryStyle.crease),
          OvaryStyle.creaseFloor * line,
        )
        ..color = inks.shadow.withValues(alpha: OvaryStyle.creaseAlpha),
    );
    canvas.drawPath(_luteumPath, edge);
    canvas.drawPath(_corePath, edge);
  }

  void _paintFollicles(Canvas canvas, double line) {
    final bool marked = home == OvaryHome.follicles;
    // The theca round each, warm, then its antrum emptied and rimmed.
    for (final OvaryFollicle f in form.follicles) {
      final double theca = math.max(
        form.mm(OvaryAnatomy.theca),
        OvaryStyle.lineFloor * line,
      );
      canvas.drawCircle(
        f.centre,
        f.radius + theca / 2,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = theca
          ..color = _theca,
      );
    }
    canvas.drawPath(_antra, Paint()..color = _antrum);
    _draw(canvas, _antrumRims);
    // Its granulosa round the antrum, its cumulus standing into it, and
    // the oocyte in that.
    final double floor = marked
        ? OvaryStyle.homeLineFloor
        : OvaryStyle.lineFloor;
    for (final OvaryFollicle f in form.follicles) {
      final double width = math.max(f.granulosa, floor * line);
      canvas.drawCircle(
        f.centre,
        f.radius - width / 2,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = width
          ..color = _granulosa,
      );
    }
    canvas.drawPath(_cumuli, Paint()..color = _granulosa);
    for (final OvaryFollicle f in form.follicles) {
      canvas.drawCircle(
        f.oocyte,
        math.max(f.oocyteRadius, 0.5 * line),
        Paint()..color = _oocyte,
      );
    }
  }

  void _paintDust(
    Canvas canvas,
    double line,
    Float32List points,
    double across,
  ) {
    canvas.drawRawPoints(
      ui.PointMode.points,
      points,
      Paint()
        ..strokeCap = StrokeCap.round
        ..strokeWidth = math.max(across, OvaryStyle.homeDustFloor * line)
        ..color = inks.mark,
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

    if (home != OvaryHome.stroma) {
      add('cortex', _layRim);
    }
    add('tube', _layTubes);
    add(
      'ligament',
      (ColouredMesh mesh) => _layTube(mesh, form.ligament, _ligamentTone),
    );
    add('vessels', _layVessels);
    return out;
  }

  /// The colours the cut face and what lies in it are drawn in, by name.
  /// For tests.
  @visibleForTesting
  Map<String, Color> get fills => <String, Color>{
    'cortex': _cortex,
    'medulla': _medulla,
    'corpus luteum': _luteum,
    'core': _core,
    'corpus albicans': _albicans,
    'granulosa': _granulosa,
    'theca': _theca,
    'oocyte': _oocyte,
    'antrum': _antrum,
    'artery': _arteryWall,
    'vein': _veinWall,
    'lumen': _lumen,
  };

  /// A circle round [centre], in points [OvaryStyle.edgeStep] apart at
  /// most.
  List<Offset> _circle(Offset centre, double radius) {
    final int n = math.max(
      24,
      (2 * math.pi * radius / form.mm(OvaryStyle.edgeStep)).ceil(),
    );
    return <Offset>[
      for (int k = 0; k < n; k++)
        centre +
            Offset(
                  math.cos(2 * math.pi * k / n),
                  math.sin(2 * math.pi * k / n),
                ) *
                radius,
    ];
  }

  static Float32List _points(List<Offset> points) =>
      Float32List.fromList(<double>[
        for (final Offset p in points) ...<double>[p.dx, p.dy],
      ]);

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
