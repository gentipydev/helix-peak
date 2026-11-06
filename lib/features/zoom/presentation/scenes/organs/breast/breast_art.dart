import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../zoom_inks.dart';
import '../../coloured_mesh.dart';
import '../../lobule_domes.dart';
import '../../lobules.dart';
import '../../relief.dart';
import '../../specimen_light.dart';
import '../../tube_course.dart';
import '../../tube_end.dart';
import 'breast_anatomy.dart';
import 'breast_form.dart';
import 'breast_style.dart';

/// The breast seen from the front in place, its lower half dissected, drawn
/// as a specimen under the zoom's one lamp: the upper half's skin a lit
/// dome, the areola and the nipple deeper and warmer on it, the areolar
/// glands small domes; the lower half's skin cut, its band round the
/// dissection, the upper skin's edge casting a thin shadow on it; the
/// gland's lobes and the ducts running in to the nipple, the lobules at
/// their ends, the fat in lit lobules between pale septa, the ligaments
/// paler strands through it; round it the pectoralis major, lit, fading out
/// with its distance from the breast, and the arteries cut short. Where the
/// zoom's cell lives is one flat tone in the mark, cut by its anatomy as
/// crisp lines: the lobes and their ducts, the fat, or the nipple and the
/// areola.
///
/// Everything costly is built once, for one form and one set of inks:
/// meshes and paths in the scene's units, so a frame only hands them on.
final class BreastArt {
  BreastArt(this.form, this.inks)
    : _light = SpecimenLight(SpecimenLamp.zoom),
      _palette = SpecimenPalette(inks);

  final BreastForm form;
  final ZoomInks inks;
  final SpecimenLight _light;
  final SpecimenPalette _palette;

  /// Where the zoom's cell lives in it.
  BreastHome get home => form.home;

  /// Where the zoom's cell lives: one flat tone, the mark over a neutral,
  /// as the other specimens draw it.
  static Color homeOf(ZoomInks inks) => Color.alphaBlend(
    inks.glow(BreastStyle.homeMark),
    inks.lit(BreastStyle.homeLit),
  );

  /// What the step from the body draws the breast's bed in: its skin as it
  /// faces the eye, the most of what covers it.
  static Color bedOf(ZoomInks inks) {
    final SpecimenLight light = SpecimenLight(SpecimenLamp.zoom);
    return Color(
      SpecimenPalette(inks).colour(
        _warmed(inks, BreastStyle.skinLit, BreastStyle.skinWarmth),
        light.light(0, 0, 1),
        sheen: light.sheen(0, 0, 1) * BreastStyle.skinSheen,
      ),
    );
  }

  /// A tone [lit] of the way to the bright ink, warmed [warmth] of the way
  /// toward the home helix's clay.
  static SpecimenTone _warmed(ZoomInks inks, double lit, double warmth) =>
      SpecimenTone(
        Color.lerp(inks.lit(lit), inks.bases.thymine, warmth)!,
        inks.shadow,
      );

  late final Color _home = homeOf(inks);
  late final SpecimenTone _skinTone = _warmed(
    inks,
    BreastStyle.skinLit,
    BreastStyle.skinWarmth,
  );
  late final SpecimenTone _areolaTone = _warmed(
    inks,
    BreastStyle.areolaLit,
    BreastStyle.areolaWarmth,
  );
  late final SpecimenTone _nippleTone = _warmed(
    inks,
    BreastStyle.nippleLit,
    BreastStyle.nippleWarmth,
  );
  late final SpecimenTone _glandTone = _warmed(
    inks,
    BreastStyle.glandLit,
    BreastStyle.glandWarmth,
  );
  late final SpecimenTone _fatTone = _warmed(
    inks,
    BreastStyle.fatLit,
    BreastStyle.fatWarmth,
  );
  late final SpecimenTone _muscleTone = _warmed(
    inks,
    BreastStyle.muscleLit,
    BreastStyle.muscleWarmth,
  );
  late final SpecimenTone _arteryTone = SpecimenTone(
    Color.lerp(inks.blood, inks.ground, BreastStyle.artery)!,
    inks.shadow,
  );

  /// [tone]'s cut face where it faces the eye.
  Color _face(SpecimenTone tone) => Color(
    _palette.colour(
      tone,
      _light.light(0, 0, 1),
      sheen: _light.sheen(0, 0, 1) * BreastStyle.cutSheen,
    ),
  );

  late final Color _dermis = _face(
    _warmed(inks, BreastStyle.dermisLit, BreastStyle.dermisWarmth),
  );
  late final Color _epidermis = _face(
    _warmed(inks, BreastStyle.epidermisLit, BreastStyle.epidermisWarmth),
  );
  late final Color _septa = _face(
    _warmed(inks, BreastStyle.septumLit, BreastStyle.septumWarmth),
  );
  late final Color _ligament = _face(
    _warmed(inks, BreastStyle.ligamentLit, BreastStyle.ligamentWarmth),
  );
  late final Color _duct = _face(
    _warmed(inks, BreastStyle.ductLit, BreastStyle.ductWarmth),
  );
  late final Color _areolarGland = Color(
    _palette.colour(
      _areolaTone,
      _light.light(0, 0, 1) * BreastStyle.glandLight,
    ),
  );

  static final List<double> _round = <double>[
    for (final double u in BreastStyle.tubeColumns.reversed) -u,
    ...BreastStyle.tubeColumns.skip(1),
  ];

  // The forms the meshes are lit by.

  /// The skin's dome over the whole breast, which the areola and the nipple
  /// lie on.
  late final Relief _dome = Relief(
    form.outlinePoints,
    cell: form.mm(BreastStyle.skinReliefCell),
    inflation: BreastStyle.skinInflation,
    sweeps: BreastStyle.skinSweeps,
  );

  // The meshes.

  /// The pectoralis major, lit, fading out with its distance from the
  /// breast.
  late final List<ui.Vertices> _pectoralis = _build(_layPectoralis);

  void _layPectoralis(ColouredMesh mesh) {
    final Relief relief = Relief(
      form.pectoralis,
      cell: form.mm(BreastStyle.muscleReliefCell),
      inflation: BreastStyle.muscleInflation,
      sweeps: BreastStyle.muscleSweeps,
    );
    _layGrid(mesh, form.pectoralisReach, form.mm(BreastStyle.muscleMeshCell), (
      Offset p,
    ) {
      final (double nx, double ny, double nz) = relief.normalAt(p);
      return _palette.colour(
        _muscleTone,
        _light.light(nx, ny, nz, form: nz),
        sheen: _light.sheen(nx, ny, nz),
        alpha: BreastForm.fadeAt(form.toMm(p)),
      );
    });
  }

  /// The upper half's skin, a lit dome.
  late final List<ui.Vertices> _skin = _build(_laySkin);

  void _laySkin(ColouredMesh mesh) => _layGrid(
    mesh,
    _bounds(form.upper),
    form.mm(BreastStyle.skinMeshCell),
    (Offset p) {
      final (double nx, double ny, double nz) = _dome.normalAt(p);
      return _palette.colour(
        _skinTone,
        _light.light(nx, ny, nz, form: nz),
        sheen: _light.sheen(nx, ny, nz) * BreastStyle.skinSheen,
      );
    },
  );

  /// The areola, a little raised on the dome, its rim turning away; and the
  /// nipple, a dome standing on it.
  late final List<ui.Vertices> _areola = _build(_layAreola);
  late final List<ui.Vertices> _nipple = _build(_layNipple);

  void _layAreola(ColouredMesh mesh) => _layDisc(
    mesh,
    form.nipple,
    form.areolaRadius,
    const <double>[0.3, 0.55, 0.75, 0.88, 0.96, 1],
    (Offset p, double u, Offset radial) {
      final (double bx, double by, double bz) = _dome.normalAt(p);
      final double rise = BreastStyle.areolaRise * _smooth((u - 0.7) / 0.3);
      final (double nx, double ny, double nz) = _unit3(
        bx + radial.dx * rise,
        by + radial.dy * rise,
        bz,
      );
      return _palette.colour(
        _areolaTone,
        _light.light(nx, ny, nz, form: nz),
        sheen: _light.sheen(nx, ny, nz) * BreastStyle.skinSheen,
      );
    },
  );

  void _layNipple(ColouredMesh mesh) => _layDisc(
    mesh,
    form.nipple,
    form.nippleRadius,
    const <double>[0.3, 0.55, 0.75, 0.9, 1],
    (Offset p, double u, Offset radial) {
      final (double bx, double by, double bz) = _dome.normalAt(form.nipple);
      final double s = BreastStyle.nippleRise * math.pow(u, 1.3).toDouble();
      final (double nx, double ny, double nz) = _unit3(
        bx + radial.dx * s,
        by + radial.dy * s,
        bz * math.sqrt(math.max(0, 1 - s * s)),
      );
      return _palette.colour(
        _nippleTone,
        _light.light(nx, ny, nz, form: nz),
        sheen: _light.sheen(nx, ny, nz) * BreastStyle.skinSheen,
      );
    },
  );

  /// The lobes, lit, where the zoom's cell does not live in them.
  late final List<ui.Vertices> _gland = _build(_layGland);

  void _layGland(ColouredMesh mesh) {
    for (final List<Offset> lobe in form.lobes) {
      final Relief relief = Relief(
        lobe,
        cell: form.mm(BreastStyle.glandReliefCell),
        inflation: BreastStyle.glandInflation,
        sweeps: BreastStyle.glandSweeps,
      );
      _layGrid(mesh, _bounds(lobe), form.mm(BreastStyle.glandMeshCell), (
        Offset p,
      ) {
        final (double nx, double ny, double nz) = relief.normalAt(p);
        return _palette.colour(
          _glandTone,
          _light.light(nx, ny, nz, form: nz),
          sheen: _light.sheen(nx, ny, nz),
        );
      });
    }
  }

  /// The fat's lobules, lit domes, where the zoom's cell does not live in
  /// them.
  late final List<ui.Vertices> _fat = _build(_layFat);

  void _layFat(ColouredMesh mesh) => LobuleDomes.lay(
    mesh,
    form.fatLobules,
    style: BreastStyle.fat,
    relief: Relief(
      form.dissection,
      cell: form.mm(BreastStyle.fatReliefCell),
      inflation: BreastStyle.fatInflation,
      sweeps: BreastStyle.fatSweeps,
    ),
    mm: form.mm,
    light: _light,
    palette: _palette,
    tone: _fatTone,
    wash: 0,
    seed: BreastStyle.seed,
  );

  /// The arteries, each a lit tube, and the lateral thoracic's small
  /// branches under it.
  late final List<ui.Vertices> _tubes = _build(_layTubes);

  void _layBranches(ColouredMesh mesh) {
    for (final TubeCourse branch in form.branches) {
      _layTube(mesh, branch);
    }
  }

  void _layArteries(ColouredMesh mesh) {
    for (final TubeCourse artery in form.arteries) {
      _layTube(mesh, artery);
    }
  }

  void _layTubes(ColouredMesh mesh) {
    _layBranches(mesh);
    _layArteries(mesh);
  }

  void _layTube(ColouredMesh mesh, TubeCourse tube) => tube.lay(
    mesh,
    _arteryTone,
    _light,
    _palette,
    _round,
    brightness: BreastStyle.tubeLight,
  );

  late final TubeEnd _end = TubeEnd(
    _palette,
    inks.shadow,
    length: BreastStyle.endLength,
    wall: BreastStyle.endWall,
  );

  // The paths.

  late final Path _upper = _polygon(form.upper);
  late final Path _lower = _polygon(form.lower);
  late final Path _dissection = _polygon(form.dissection);
  late final Path _cutBand = Path.combine(
    PathOperation.difference,
    _lower,
    _dissection,
  );
  late final Path _lobes = () {
    final Path path = Path();
    for (final List<Offset> lobe in form.lobes) {
      path.addPolygon(lobe, true);
    }
    return path;
  }();

  /// The ducts, by how wide each is, and the lumen along all of them.
  late final Map<double, Path> _ducts = () {
    final Map<double, Path> out = <double, Path>{};
    for (final BreastDuct duct in form.ducts) {
      out.putIfAbsent(duct.width, Path.new).addPolygon(duct.course, false);
    }
    return out;
  }();
  late final Path _lumens = () {
    final Path path = Path();
    for (final BreastDuct duct in form.ducts) {
      path.addPolygon(duct.course, false);
    }
    return path;
  }();

  late final Path _lobules = _dots(
    form.lobules,
    form.mm(BreastAnatomy.lobule / 2),
  );
  late final Path _ligaments = () {
    final Path path = Path();
    for (final List<Offset> ligament in form.ligaments) {
      path.addPolygon(
        _tapered(
          ligament,
          form.mm(BreastAnatomy.ligament / 2),
          form.mm(BreastStyle.ligamentTaper),
        ),
        true,
      );
    }
    return path;
  }();
  late final Path _fatHome = Lobules.bed(form.fatLobules, 0);

  late final Path _areolaDisc = Path()
    ..addOval(Rect.fromCircle(center: form.nipple, radius: form.areolaRadius));
  late final Path _nippleDisc = Path()
    ..addOval(Rect.fromCircle(center: form.nipple, radius: form.nippleRadius));
  late final Path _areolarGlands = _dots(
    form.areolarGlands,
    form.mm(BreastAnatomy.areolarGland),
  );
  late final Path _orifices = _dots(
    form.orifices,
    form.mm(BreastAnatomy.orifice),
  );

  /// The pectoralis's fascicles and its border, each in as many paths as
  /// it fades by, each path's runs showing about as much.
  late final List<Path> _fibres = _binned(form.fibres);
  late final List<Path> _border = _binned(form.border);
  late final Path _pectoralisPath = _polygon(form.pectoralis);

  static List<Path> _binned(List<(Offset, Offset, double)> runs) {
    const int levels = BreastStyle.fadeLevels;
    final List<Path> out = <Path>[for (int k = 0; k < levels; k++) Path()];
    for (final (Offset a, Offset b, double shown) in runs) {
      final int k = math.min(levels - 1, (shown * levels).floor());
      out[k]
        ..moveTo(a.dx, a.dy)
        ..lineTo(b.dx, b.dy);
    }
    return out;
  }

  /// The epidermis along the cut and round the lower edge.
  late final Path _epidermisLine = () {
    final Path path = Path()
      ..moveTo(form.cutLine.$1.dx, form.cutLine.$1.dy)
      ..lineTo(form.cutLine.$2.dx, form.cutLine.$2.dy);
    return path..addPolygon(form.lowerEdge, false);
  }();

  /// The shadow the upper skin's edge casts down onto the dissection.
  late final Path _cutShadowPath = () {
    final Rect d = _bounds(form.dissection);
    final double top = form.cutLine.$1.dy + form.mm(BreastAnatomy.skin);
    return Path()..addRect(
      Rect.fromLTRB(d.left, top, d.right, top + form.mm(BreastStyle.cutShadow)),
    );
  }();
  late final Paint _cutShadowPaint = () {
    final Rect r = _cutShadowPath.getBounds();
    return Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[
          inks.shadow.withValues(alpha: BreastStyle.cutShadowAlpha),
          inks.shadow.withValues(alpha: 0),
        ],
      ).createShader(r);
  }();

  static Path _polygon(List<Offset> points) => Path()..addPolygon(points, true);

  static Path _dots(List<Offset> centres, double radius) {
    final Path path = Path();
    for (final Offset c in centres) {
      path.addOval(Rect.fromCircle(center: c, radius: radius));
    }
    return path;
  }

  // The shadow.

  void _paintShadow(Canvas canvas) {
    canvas.save();
    canvas.translate(
      form.mm(BreastStyle.shadowX),
      form.mm(BreastStyle.shadowY),
    );
    final Color shadow = inks.shadow;
    canvas.drawPath(
      form.outline,
      Paint()..color = shadow.withValues(alpha: BreastStyle.shadowAlpha),
    );
    canvas.drawPath(
      form.outline,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = form.mm(BreastStyle.shadowSoft)
        ..strokeJoin = StrokeJoin.round
        ..color = shadow.withValues(alpha: 0.12),
    );
    canvas.restore();
  }

  // Drawing.

  /// What the breast, the pectoralis round it and the arteries cover, its
  /// shadow included: the room a layer of it needs.
  late final Rect bounds = () {
    Rect box = form.box.expandToInclude(form.pectoralisReach);
    for (final TubeCourse t in <TubeCourse>[...form.beside, ...form.branches]) {
      for (int i = 0; i < t.length; i++) {
        box = box.expandToInclude(
          Rect.fromCircle(center: t.centres[i], radius: t.radius[i]),
        );
      }
    }
    return box.inflate(
      form.mm(
        math.max(
          BreastStyle.muscleMeshCell,
          BreastStyle.shadowY + BreastStyle.shadowSoft,
        ),
      ),
    );
  }();

  /// Builds every mesh and path a frame will draw.
  void prepare() => <Object?>[
    _pectoralis,
    _skin,
    if (home != BreastHome.nipple) ...<Object?>[_areola, _nipple],
    if (home != BreastHome.gland) _gland,
    if (home != BreastHome.fat) _fat,
    if (home == BreastHome.fat) _fatHome,
    _tubes,
    _upper,
    _cutBand,
    _lobes,
    _ducts,
    _lumens,
    _lobules,
    _ligaments,
    _areolaDisc,
    _nippleDisc,
    _areolarGlands,
    _orifices,
    _fibres,
    _border,
    _pectoralisPath,
    _epidermisLine,
    _cutShadowPaint,
    bounds,
  ];

  /// Draws it all, in the scene's units at the breast's real size; [line]
  /// is a pixel.
  void paint(Canvas canvas, double line) {
    // Round it, under it: the pectoralis and the arteries, cut short.
    _paintPectoralis(canvas, line);
    _draw(canvas, _tubes);
    for (final TubeCourse artery in form.arteries) {
      _end.paint(
        canvas,
        artery,
        _arteryTone,
        _light.light(0, 0, 1) * BreastStyle.tubeLight,
      );
    }
    _paintShadow(canvas);
    _paintUpper(canvas, line);
    _paintDissection(canvas, line);
    // The cut skin round the dissection, its epidermis on its outer edge,
    // and where it meets the dissection.
    canvas.drawPath(_cutBand, Paint()..color = _dermis);
    canvas.save();
    canvas.clipPath(_lower);
    canvas.drawPath(
      _epidermisLine,
      _stroke(
        _epidermis,
        math.max(
          form.mm(BreastAnatomy.epidermis),
          BreastStyle.epidermisFloor * line,
        ),
      ),
    );
    canvas.restore();
    canvas.drawPath(
      _dissection,
      _stroke(
        inks.shadow.withValues(alpha: BreastStyle.coatLineAlpha),
        math.max(
          form.mm(BreastStyle.coatLine),
          BreastStyle.coatLineFloor * line,
        ),
      ),
    );
    // The outline's own edge, as the other specimens' outlines are edged.
    canvas.drawPath(
      form.outline,
      _stroke(
        inks.lit(BreastStyle.edgeLit).withValues(alpha: BreastStyle.edgeAlpha),
        line,
      ),
    );
  }

  /// The pectoralis, lit, its fascicles faint grooves and its border a
  /// little stronger, each fading out with its distance from the breast.
  void _paintPectoralis(Canvas canvas, double line) {
    canvas.save();
    canvas.clipPath(_pectoralisPath);
    _draw(canvas, _pectoralis);
    final Offset toward =
        _light.screen * form.mm(BreastStyle.ridge * BreastAnatomy.fascicle);
    const int levels = BreastStyle.fadeLevels;
    for (int k = 0; k < levels; k++) {
      final double shown = (k + 1) / levels;
      canvas.drawPath(
        _fibres[k],
        _stroke(
          inks.shadow.withValues(alpha: BreastStyle.grooveShade * shown),
          line,
        ),
      );
      canvas.drawPath(
        _fibres[k].shift(toward),
        _stroke(
          inks.text.withValues(alpha: BreastStyle.grooveLight * shown),
          line,
        ),
      );
    }
    canvas.restore();
    for (int k = 0; k < levels; k++) {
      canvas.drawPath(
        _border[k],
        _stroke(
          inks.shadow.withValues(
            alpha: BreastStyle.borderShade * (k + 1) / levels,
          ),
          line,
        ),
      );
    }
  }

  /// The upper half under its skin: the dome, the areola and its glands,
  /// and the nipple, whole, standing on it.
  void _paintUpper(Canvas canvas, double line) {
    final bool nippleHome = home == BreastHome.nipple;
    canvas.save();
    canvas.clipPath(_upper);
    _draw(canvas, _skin);
    if (nippleHome) {
      canvas.drawPath(_areolaDisc, Paint()..color = _home);
      canvas.drawPath(
        _areolarGlands,
        _stroke(
          inks.shadow.withValues(alpha: BreastStyle.ringAlpha),
          math.max(
            form.mm(BreastStyle.lobeEdge),
            BreastStyle.creaseFloor * line,
          ),
        ),
      );
    } else {
      _draw(canvas, _areola);
      canvas.drawPath(
        _areolarGlands.shift(-_light.screen * form.mm(BreastStyle.glandShadow)),
        Paint()
          ..color = inks.shadow.withValues(alpha: BreastStyle.glandShadowAlpha),
      );
      canvas.drawPath(_areolarGlands, Paint()..color = _areolarGland);
      // The nipple's shadow on the areola, away from the lamp.
      canvas.drawPath(
        _nippleDisc.shift(-_light.screen * form.mm(BreastStyle.nippleShadow)),
        Paint()
          ..color = inks.shadow.withValues(
            alpha: BreastStyle.nippleShadowAlpha,
          ),
      );
    }
    canvas.restore();
    if (nippleHome) {
      canvas.drawPath(_nippleDisc, Paint()..color = _home);
      canvas.drawPath(
        _nippleDisc,
        _stroke(
          inks.shadow.withValues(alpha: BreastStyle.lobeEdgeAlpha),
          math.max(
            form.mm(BreastStyle.lobeEdge),
            BreastStyle.creaseFloor * line,
          ),
        ),
      );
    } else {
      _draw(canvas, _nipple);
    }
    _paintDots(
      canvas,
      line,
      _orifices,
      form.mm(2 * BreastAnatomy.orifice),
      BreastStyle.orificeFloor,
      BreastStyle.orificeAlpha,
    );
  }

  /// The lower half, dissected: the fat between its septa, the ligaments
  /// through it, the lobes and their ducts, the lobules at the ducts' ends,
  /// and the upper skin's shadow along the cut.
  void _paintDissection(Canvas canvas, double line) {
    final bool glandHome = home == BreastHome.gland;
    canvas.save();
    canvas.clipPath(_dissection);
    canvas.drawPath(_dissection, Paint()..color = _septa);
    if (home == BreastHome.fat) {
      canvas.drawPath(_fatHome, Paint()..color = _home);
    } else {
      _draw(canvas, _fat);
    }
    canvas.drawPath(_ligaments, Paint()..color = _ligament);
    final double ligament = form.mm(BreastAnatomy.ligament);
    if (ligament < BreastStyle.ligamentFloor * line) {
      canvas.drawPath(
        _ligaments,
        _stroke(_ligament, BreastStyle.ligamentFloor * line - ligament),
      );
    }
    if (glandHome) {
      canvas.drawPath(_lobes, Paint()..color = _home);
    } else {
      canvas.save();
      canvas.clipPath(_lobes);
      _draw(canvas, _gland);
      canvas.restore();
    }
    canvas.drawPath(
      _lobes,
      _stroke(
        inks.shadow.withValues(alpha: BreastStyle.lobeEdgeAlpha),
        math.max(form.mm(BreastStyle.lobeEdge), BreastStyle.creaseFloor * line),
      ),
    );
    // The ducts in their own tone, never thinner than so many pixels, and
    // the lumen along each.
    final double floor =
        (glandHome ? BreastStyle.ductFloor : BreastStyle.creaseFloor) * line;
    for (final MapEntry<double, Path> ducts in _ducts.entries) {
      canvas.drawPath(
        ducts.value,
        _stroke(glandHome ? _home : _duct, math.max(form.mm(ducts.key), floor))
          ..strokeCap = StrokeCap.round,
      );
    }
    canvas.drawPath(
      _lumens,
      _stroke(
        inks.shadow.withValues(
          alpha: glandHome
              ? BreastStyle.lumenAlpha
              : BreastStyle.lumenAlphaElsewhere,
        ),
        math.max(form.mm(BreastStyle.lumen), BreastStyle.creaseFloor * line),
      ),
    );
    _paintDots(
      canvas,
      line,
      _lobules,
      form.mm(BreastAnatomy.lobule),
      BreastStyle.lobuleFloor,
      glandHome ? BreastStyle.lobuleAlpha : BreastStyle.lobuleAlphaElsewhere,
    );
    canvas.drawPath(_cutShadowPath, _cutShadowPaint);
    canvas.restore();
  }

  /// [dots], each [across] wide, in the shadow ink at [alpha], never
  /// smaller across than [floor] pixels.
  void _paintDots(
    Canvas canvas,
    double line,
    Path dots,
    double across,
    double floor,
    double alpha,
  ) {
    final Color dark = inks.shadow.withValues(alpha: alpha);
    canvas.drawPath(dots, Paint()..color = dark);
    if (across < floor * line) {
      canvas.drawPath(dots, _stroke(dark, floor * line - across));
    }
  }

  Paint _stroke(Color colour, double width) => Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = width
    ..strokeJoin = StrokeJoin.round
    ..color = colour;

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

    add('pectoralis', _layPectoralis);
    add('skin', _laySkin);
    if (home != BreastHome.nipple) {
      add('areola', _layAreola);
      add('nipple', _layNipple);
    }
    if (home != BreastHome.gland) {
      add('gland', _layGland);
    }
    if (home != BreastHome.fat) {
      add('fat', _layFat);
    }
    add('branches', _layBranches);
    add('arteries', _layArteries);
    return out;
  }

  /// The colours its flat parts are filled in, by name. For tests.
  @visibleForTesting
  Map<String, Color> get fills => <String, Color>{
    'septa': _septa,
    'ligament': _ligament,
    'dermis': _dermis,
    'epidermis': _epidermis,
    'areolar gland': _areolarGland,
    'duct': home == BreastHome.gland ? _home : _duct,
    if (home == BreastHome.gland) 'gland': _home,
    if (home == BreastHome.fat) 'fat': _home,
    if (home == BreastHome.nipple) ...<String, Color>{
      'nipple': _home,
      'areola': _home,
    },
  };

  // Laying meshes.

  /// A grid [cell] apart over [area], a little beyond it, each vertex
  /// coloured by [colour].
  static void _layGrid(
    ColouredMesh mesh,
    Rect area,
    double cell,
    int Function(Offset p) colour,
  ) {
    final Rect grid = area.inflate(cell);
    final int columns = (grid.width / cell).ceil() + 1;
    final int rows = (grid.height / cell).ceil() + 1;
    mesh.begin(columns * rows);
    final int first = mesh.next;
    for (int j = 0; j < rows; j++) {
      for (int i = 0; i < columns; i++) {
        final Offset p = grid.topLeft + Offset(i * cell, j * cell);
        mesh.vertex(p.dx, p.dy, colour(p));
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

  /// A disc of [radius] about [centre], laid in [rings], each a share of
  /// its radius out, and [BreastStyle.rays] ways round; each vertex
  /// coloured by [colour] from where it lies, how far out it is and the way
  /// out there.
  static void _layDisc(
    ColouredMesh mesh,
    Offset centre,
    double radius,
    List<double> rings,
    int Function(Offset p, double u, Offset radial) colour,
  ) {
    const int rays = BreastStyle.rays;
    mesh.begin(1 + rings.length * rays);
    final int first = mesh.next;
    mesh.vertex(centre.dx, centre.dy, colour(centre, 0, Offset.zero));
    for (final double u in rings) {
      for (int k = 0; k < rays; k++) {
        final double a = 2 * math.pi * k / rays;
        final Offset radial = Offset(math.cos(a), math.sin(a));
        final Offset p = centre + radial * (u * radius);
        mesh.vertex(p.dx, p.dy, colour(p, u, radial));
      }
    }
    for (int k = 0; k < rays; k++) {
      final int a = first + 1 + k;
      final int b = first + 1 + (k + 1) % rays;
      mesh.triangle(first, a, b);
      for (int band = 0; band + 1 < rings.length; band++) {
        final int a0 = a + band * rays;
        final int b0 = b + band * rays;
        mesh.triangle(a0, b0, a0 + rays);
        mesh.triangle(b0, b0 + rays, a0 + rays);
      }
    }
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

// Geometry, in the scene's units.

/// The shape of a line [half] wide to either side, narrowing to nothing
/// over [taper] from its start.
List<Offset> _tapered(List<Offset> line, double half, double taper) {
  final int n = line.length;
  final List<double> along = <double>[0];
  for (int i = 1; i < n; i++) {
    along.add(along.last + (line[i] - line[i - 1]).distance);
  }
  final List<Offset> left = <Offset>[];
  final List<Offset> right = <Offset>[];
  for (int i = 0; i < n; i++) {
    final Offset t = line[math.min(n - 1, i + 1)] - line[math.max(0, i - 1)];
    final double length = t.distance;
    final Offset across = length <= 0
        ? Offset.zero
        : Offset(-t.dy, t.dx) / length;
    final double w = half * _smooth(along[i] / taper);
    left.add(line[i] + across * w);
    right.add(line[i] - across * w);
  }
  return <Offset>[...left, ...right.reversed];
}

double _smooth(double t) {
  final double x = t.clamp(0.0, 1.0);
  return x * x * (3 - 2 * x);
}

(double, double, double) _unit3(double x, double y, double z) {
  final double length = math.sqrt(x * x + y * y + z * z);
  return length <= 0 ? (0, 0, 1) : (x / length, y / length, z / length);
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
