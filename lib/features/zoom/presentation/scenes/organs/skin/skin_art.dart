import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../zoom_inks.dart';
import '../../coloured_mesh.dart';
import '../../lobule_domes.dart';
import '../../specimen_light.dart';
import 'skin_form.dart';
import 'skin_style.dart';

/// A block of the leg's skin drawn as a specimen under the zoom's one lamp:
/// its top the skin's surface, lit, its furrows faint creases, its pores
/// and the follicles' openings dark, its hairs dark and leaning; its front
/// a flat cut, the epidermis pale on the papillary dermis, the reticular
/// dermis a warm neutral with its bands of fibres faint in it, the fat in
/// lit lobules between pale septa; the follicle's sheaths pale round a dark
/// hair, its sebaceous gland paler still and flecked, its arrector pili a
/// muscle's warm; the sweat glands' coils and ducts pale; the vessels in
/// the blood red, the nerve in the honey; its right side a second cut, in
/// shade.
///
/// Where the zoom's cell lives is one flat tone in the mark, by the name
/// the Atlas gives the cell and never by gene (`SkinHome`).
///
/// Everything costly is built once, for one form, one home and one set of
/// inks.
final class SkinArt {
  SkinArt(this.form, this.inks, {required this.home})
    : _light = SpecimenLight(SpecimenLamp.zoom),
      _palette = SpecimenPalette(inks);

  final SkinForm form;
  final ZoomInks inks;
  final SkinHome home;
  final SpecimenLight _light;
  final SpecimenPalette _palette;

  /// Where the zoom's cell lives: one flat tone, the mark over a neutral.
  late final Color homeTone = Color.alphaBlend(
    inks.glow(SkinStyle.homeMark),
    inks.lit(SkinStyle.homeLit),
  );

  /// A tone [lit] of the way toward the bright ink, warmed [warmth] of the
  /// way toward the home helix's clay.
  SpecimenTone _warmed(double lit, double warmth) => SpecimenTone(
    Color.lerp(inks.lit(lit), inks.bases.thymine, warmth)!,
    inks.shadow,
  );

  /// [tone] on a face turned as [facing] is, lit by the lamp.
  Color _on(SpecimenTone tone, (double, double, double) facing) {
    final (double x, double y, double z) = facing;
    final double length = math.sqrt(x * x + y * y + z * z);
    final double nx = x / length;
    final double ny = y / length;
    final double nz = z / length;
    return Color(
      _palette.colour(
        tone,
        _light.light(nx, ny, nz, form: nz),
        sheen: _light.sheen(nx, ny, nz) * SkinStyle.cutSheen,
      ),
    );
  }

  Color _front(SpecimenTone tone) => _on(tone, SkinStyle.front);
  Color _sideOf(SpecimenTone tone) => _on(tone, SkinStyle.side);

  late final SpecimenTone _epidermisTone = _warmed(
    SkinStyle.epidermisLit,
    SkinStyle.epidermisWarmth,
  );
  late final SpecimenTone _papillaryTone = _warmed(
    SkinStyle.papillaryLit,
    SkinStyle.papillaryWarmth,
  );
  late final SpecimenTone _dermisTone = _warmed(
    SkinStyle.dermisLit,
    SkinStyle.dermisWarmth,
  );
  late final SpecimenTone _fatTone = _warmed(
    SkinStyle.fatLit,
    SkinStyle.fatWarmth,
  );
  late final SpecimenTone _septumTone = _warmed(
    SkinStyle.septumLit,
    SkinStyle.fatWarmth,
  );
  late final SpecimenTone _sheathTone = _warmed(
    SkinStyle.sheathLit,
    SkinStyle.sheathWarmth,
  );

  late final Color _corneum = _front(
    _warmed(SkinStyle.corneumLit, SkinStyle.epidermisWarmth),
  );
  late final Color _epidermis = _front(_epidermisTone);
  late final Color _papillary = _front(_papillaryTone);
  late final Color _dermis = _front(_dermisTone);
  late final Color _septa = _front(_septumTone);
  late final Color _sheath = _front(_sheathTone);
  late final Color _innerSheath = _front(
    _warmed(SkinStyle.sheathLit + 0.1, SkinStyle.sheathWarmth),
  );
  late final Color _papilla = _front(
    _warmed(SkinStyle.papillaLit, SkinStyle.dermisWarmth),
  );
  late final Color _gland = _front(
    _warmed(SkinStyle.glandLit, SkinStyle.glandWarmth),
  );
  late final Color _muscle = _front(
    _warmed(SkinStyle.muscleLit, SkinStyle.muscleWarmth),
  );
  late final Color _coil = _front(
    _warmed(SkinStyle.coilLit, SkinStyle.coilWarmth),
  );

  /// The hair, a deep umber.
  late final Color _hair = Color.lerp(
    inks.shade(SkinStyle.hairShade),
    inks.bases.thymine,
    SkinStyle.hairWarmth,
  )!;

  late final Color _artery = Color.lerp(
    inks.blood,
    inks.ground,
    SkinStyle.artery,
  )!;
  late final Color _venule = Color.lerp(
    inks.blood,
    inks.ground,
    SkinStyle.vein,
  )!;
  late final Color _nerve = Color.lerp(
    inks.nerve,
    inks.ground,
    SkinStyle.nerve,
  )!;

  late final Color _surface = _on(
    _warmed(SkinStyle.surfaceLit, SkinStyle.surfaceWarmth),
    SkinStyle.top,
  );

  bool get _basalHome =>
      home == SkinHome.melanocytes || home == SkinHome.basalLayer;

  // The fat.

  late final List<ui.Vertices> _fat = _build(_layFat);

  void _layFat(ColouredMesh mesh) => LobuleDomes.lay(
    mesh,
    form.lobules.all,
    style: SkinStyle.lobules,
    relief: form.fatRelief,
    mm: form.mm,
    light: _light,
    palette: _palette,
    tone: _fatTone,
    wash: 0,
    seed: SkinStyle.seed,
  );

  // Paths built once.

  late final Path _basalPath = _polyline(form.basal);
  late final Path _papillaryPath = _polyline(form.papillaryLine);
  late final Path _dermisPath = _polyline(form.dermisLine);
  late final Path _fibrePath = () {
    final Path path = Path();
    for (final List<Offset> fibre in form.fibres) {
      path.addPath(_polyline(fibre), Offset.zero);
    }
    return path;
  }();
  late final Path _furrowPath = () {
    final Path path = Path();
    for (final List<Offset> furrow in form.furrows) {
      path.addPath(_polyline(furrow), Offset.zero);
    }
    return path;
  }();
  late final Path _septaPath = () {
    final Path path = Path();
    for (final List<Offset> septum in form.sideSepta) {
      path.addPath(_polyline(septum), Offset.zero);
    }
    return path;
  }();
  late final List<Path> _ducts = <Path>[
    for (final SkinCoil coil in form.coils) _polyline(coil.duct),
  ];

  // Drawing.

  /// What the block covers, its hairs and its shadow included: the room a
  /// layer of it needs.
  late final Rect bounds = () {
    Rect box = form.outline.getBounds();
    for (final SkinHair hair in form.hairs) {
      for (final Offset p in hair.points) {
        box = box.expandToInclude(Rect.fromCircle(center: p, radius: 0));
      }
    }
    return box.inflate(form.mm(SkinStyle.shadowY + SkinStyle.shadowSoft));
  }();

  /// Builds every mesh and path a frame will draw.
  void prepare() => <Object?>[
    _fat,
    _basalPath,
    _papillaryPath,
    _dermisPath,
    _fibrePath,
    _furrowPath,
    _septaPath,
    _ducts,
    form.follicle,
    form.gland,
    form.muscle,
    form.other,
    bounds,
  ];

  /// Draws it all, in the scene's units at the skin's real size; [line] is
  /// a pixel.
  void paint(Canvas canvas, double line) {
    _paintShadow(canvas);
    _paintSide(canvas, line);
    _paintTop(canvas, line);
    canvas.save();
    canvas.clipPath(form.front);
    _paintFront(canvas, line);
    canvas.restore();
    _paintEdges(canvas, line);
    _paintHairs(canvas, line);
  }

  void _paintShadow(Canvas canvas) {
    canvas.save();
    canvas.translate(form.mm(SkinStyle.shadowX), form.mm(SkinStyle.shadowY));
    final Color shadow = inks.shadow;
    canvas.drawPath(
      form.outline,
      Paint()..color = shadow.withValues(alpha: SkinStyle.shadowAlpha),
    );
    canvas.drawPath(
      form.outline,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = form.mm(SkinStyle.shadowSoft)
        ..strokeJoin = StrokeJoin.round
        ..color = shadow.withValues(alpha: 0.12),
    );
    canvas.restore();
  }

  void _paintSide(Canvas canvas, double line) {
    final bool dermisHome = home == SkinHome.dermis;
    canvas.drawPath(form.sideFat, Paint()..color = _sideOf(_fatTone));
    canvas.drawPath(
      form.sideReticular,
      Paint()..color = dermisHome ? homeTone : _sideOf(_dermisTone),
    );
    canvas.drawPath(
      form.sidePapillary,
      Paint()..color = dermisHome ? homeTone : _sideOf(_papillaryTone),
    );
    canvas.drawPath(
      form.sideEpidermis,
      Paint()
        ..color = home == SkinHome.epidermis
            ? homeTone
            : _sideOf(_epidermisTone),
    );
    canvas.save();
    canvas.clipPath(form.sideFat);
    canvas.drawPath(
      _septaPath,
      _stroke(
        _sideOf(_septumTone).withValues(alpha: 0.6),
        SkinStyle.layerFloor * line,
      ),
    );
    canvas.restore();
    final Paint vessel = Paint()..color = _sideOf(_venuleTone);
    for (final Offset p in form.sideVessels) {
      canvas.drawOval(
        Rect.fromCenter(
          center: p,
          width: math.max(form.mm(0.05), SkinStyle.vesselFloor * line),
          height: math.max(form.mm(0.07), SkinStyle.vesselFloor * line),
        ),
        vessel,
      );
    }
  }

  late final SpecimenTone _venuleTone = SpecimenTone(_venule, inks.shadow);

  void _paintTop(Canvas canvas, double line) {
    canvas.drawPath(form.top, Paint()..color = _surface);
    canvas.save();
    canvas.clipPath(form.top);
    canvas.drawPath(
      _furrowPath,
      _stroke(inks.shadow.withValues(alpha: SkinStyle.furrowAlpha), 0.8 * line),
    );
    final Paint dark = Paint()..color = inks.shadow.withValues(alpha: 0.55);
    final double pore = math.max(form.mm(SkinStyle.pore), 0.9 * line);
    for (final Offset p in form.pores) {
      canvas.drawCircle(p, pore, dark);
    }
    final double opening = math.max(
      form.mm(SkinStyle.openingRadius),
      1.4 * line,
    );
    for (final Offset p in form.openings) {
      canvas.drawOval(
        Rect.fromCenter(
          center: p,
          width: 2 * opening,
          height: 2 * opening * SkinStyle.backUp * 1.6,
        ),
        dark,
      );
    }
    canvas.restore();
  }

  void _paintFront(Canvas canvas, double line) {
    // The fat: its septa, its lobules, and what runs in its septa.
    canvas.drawPath(form.fat, Paint()..color = _septa);
    _draw(canvas, _fat);
    // The dermis, the papillary layer paler, its bands of fibres faint.
    final bool dermisHome = home == SkinHome.dermis;
    canvas.drawPath(
      form.reticular,
      Paint()..color = dermisHome ? homeTone : _dermis,
    );
    canvas.drawPath(
      form.papillary,
      Paint()..color = dermisHome ? homeTone : _papillary,
    );
    canvas.save();
    canvas.clipPath(form.reticular);
    canvas.drawPath(
      _fibrePath,
      _stroke(
        inks.shadow.withValues(alpha: SkinStyle.fibreAlpha),
        math.max(form.mm(0.012), 0.8 * line),
      ),
    );
    canvas.restore();
    final Paint layer = _stroke(
      inks.shadow.withValues(alpha: SkinStyle.layerAlpha * 0.6),
      SkinStyle.layerFloor * line,
    );
    canvas.drawPath(_papillaryPath, layer);
    canvas.drawPath(_dermisPath, layer);
    // The vessels: the two plexuses, the fat's septa, the vessels joining
    // the plexuses; and the nerve.
    final double floor = SkinStyle.vesselFloor * line / 2;
    for (final (Offset p, double r, bool vein) in form.vessels) {
      canvas.drawCircle(
        p,
        math.max(r, floor),
        Paint()..color = vein ? _venule : _artery,
      );
    }
    canvas.drawPath(form.arteriole, Paint()..color = _artery);
    canvas.drawPath(form.venule, Paint()..color = _venule);
    canvas.drawCircle(form.nerve, form.nerveRadius, Paint()..color = _nerve);
    final Paint fascicle = Paint()
      ..color = Color.lerp(_nerve, inks.text, 0.18)!;
    for (int k = 0; k < 3; k++) {
      final double a = 2 * math.pi * k / 3 + 0.4;
      canvas.drawCircle(
        form.nerve +
            Offset(math.cos(a), math.sin(a)) * (form.nerveRadius * 0.42),
        form.nerveRadius * 0.34,
        fascicle,
      );
    }
    // The sweat glands' coils.
    final bool sweatHome = home == SkinHome.sweatGland;
    final double tube = math.max(
      form.mm(SkinStyle.coilTube),
      SkinStyle.ductFloor * line,
    );
    final Paint tubeEdge = _stroke(
      inks.shadow.withValues(alpha: SkinStyle.edgeCutAlpha),
      tube + 2 * SkinStyle.cutLine * line,
    );
    for (final SkinCoil coil in form.coils) {
      canvas.drawPath(
        coil.ball,
        Paint()
          ..color = sweatHome
              ? homeTone
              : _coil.withValues(alpha: SkinStyle.coilBall),
      );
      canvas.drawPath(coil.loops, tubeEdge);
      canvas.drawPath(coil.loops, _stroke(sweatHome ? homeTone : _coil, tube));
    }
    // The epidermis on its ridges, its horny layer, and its basal layer
    // along its floor.
    canvas.drawPath(
      form.epidermis,
      Paint()..color = home == SkinHome.epidermis ? homeTone : _epidermis,
    );
    canvas.drawPath(form.corneum, Paint()..color = _corneum);
    canvas.drawPath(
      _basalPath,
      _basalHome
          ? _stroke(
              homeTone,
              math.max(form.mm(0.014), SkinStyle.basalFloor * line),
            )
          : _stroke(
              inks.shadow.withValues(alpha: SkinStyle.layerAlpha),
              SkinStyle.layerFloor * line,
            ),
    );
    // The ducts, up through the dermis and the epidermis to their pores.
    final double duct = math.max(form.mm(0.03), SkinStyle.ductFloor * line);
    for (final Path path in _ducts) {
      canvas.drawPath(path, _stroke(sweatHome ? homeTone : _coil, duct));
    }
    // The follicles: their sheaths, their bulbs, the hair in them and the
    // papilla under each bulb.
    final bool follicleHome = home == SkinHome.follicle;
    final Paint sheath = Paint()..color = follicleHome ? homeTone : _sheath;
    canvas.drawPath(form.follicle, sheath);
    canvas.drawPath(form.other, sheath);
    canvas.drawPath(form.otherBulb, sheath);
    if (home == SkinHome.melanocytes) {
      final Paint matrix = Paint()..color = homeTone;
      canvas.drawPath(form.bulb, matrix);
      canvas.drawPath(form.otherBulb, matrix);
    }
    if (!follicleHome) {
      canvas.drawPath(form.innerSheath, Paint()..color = _innerSheath);
    }
    final Paint hair = Paint()..color = _hair;
    canvas.drawPath(form.shaft, hair);
    canvas.drawPath(form.otherShaft, hair);
    final Paint papilla = Paint()..color = _papilla;
    canvas.drawPath(form.papilla, papilla);
    canvas.drawPath(form.otherPapilla, papilla);
    canvas.drawPath(
      form.follicle,
      _stroke(
        inks.shadow.withValues(alpha: SkinStyle.layerAlpha),
        SkinStyle.layerFloor * line,
      ),
    );
    // The sebaceous gland, flecked, and the arrector pili.
    final bool glandHome = home == SkinHome.sebaceousGland;
    canvas.drawPath(form.gland, Paint()..color = glandHome ? homeTone : _gland);
    if (!glandHome) {
      final Paint fleck = Paint()
        ..color = inks.shadow.withValues(alpha: SkinStyle.fleckAlpha);
      final double r = math.max(form.mm(0.012), 0.5 * line);
      for (final Offset p in form.glandFlecks) {
        canvas.drawCircle(p, r, fleck);
      }
    }
    canvas.drawPath(
      form.gland,
      _stroke(
        inks.shadow.withValues(alpha: SkinStyle.layerAlpha),
        SkinStyle.layerFloor * line,
      ),
    );
    canvas.drawPath(form.muscle, Paint()..color = _muscle);
    canvas.drawPath(
      form.muscle,
      _stroke(
        inks.shadow.withValues(alpha: SkinStyle.edgeCutAlpha),
        SkinStyle.cutLine * line,
      ),
    );
  }

  void _paintEdges(Canvas canvas, double line) {
    canvas.drawPath(
      _polyline(form.topEdge),
      _stroke(
        inks.lit(SkinStyle.edgeLit).withValues(alpha: SkinStyle.edgeAlpha),
        line,
      ),
    );
    canvas.drawPath(
      _polyline(form.sideEdge),
      _stroke(inks.shadow.withValues(alpha: SkinStyle.edgeShadeAlpha), line),
    );
  }

  void _paintHairs(Canvas canvas, double line) {
    for (final SkinHair h in form.hairs) {
      final double width = math.max(h.width, SkinStyle.hairFloor * line);
      final int n = h.points.length - 1;
      for (int i = 0; i < n; i++) {
        final double t = (i + 0.5) / n;
        final double fade =
            1 -
            ((t - (1 - SkinStyle.hairFade)) / SkinStyle.hairFade).clamp(
              0.0,
              1.0,
            );
        canvas.drawLine(
          h.points[i],
          h.points[i + 1],
          Paint()
            ..strokeWidth = width
            ..strokeCap = StrokeCap.round
            ..color = _hair.withValues(alpha: fade),
        );
      }
    }
  }

  /// Every mesh's vertices as built, for tests, each tagged with the part
  /// it draws: where each lies, in the scene's units, and its colour.
  @visibleForTesting
  List<(String, Float32List, Int32List)> get meshData {
    final List<(String, Float32List, Int32List)> out =
        <(String, Float32List, Int32List)>[];
    final ColouredMesh mesh = ColouredMesh(keep: true);
    _layFat(mesh);
    mesh.build();
    for (final ({Float32List positions, Int32List colours}) kept in mesh.kept) {
      out.add(('fat', kept.positions, kept.colours));
    }
    return out;
  }

  /// Every flat colour it fills or strokes with, for tests, by the part it
  /// draws.
  @visibleForTesting
  Map<String, Color> get fills => <String, Color>{
    'home': homeTone,
    'corneum': _corneum,
    'epidermis': _epidermis,
    'papillary': _papillary,
    'dermis': _dermis,
    'septa': _septa,
    'sheath': _sheath,
    'innerSheath': _innerSheath,
    'papilla': _papilla,
    'gland': _gland,
    'muscle': _muscle,
    'coil': _coil,
    'hair': _hair,
    'artery': _artery,
    'venule': _venule,
    'nerve': _nerve,
    'surface': _surface,
  };

  // Helpers.

  static Path _polyline(List<Offset> points) {
    final Path path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final Offset p in points.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    return path;
  }

  static Paint _stroke(Color colour, double width) => Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = width
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..color = colour;

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
