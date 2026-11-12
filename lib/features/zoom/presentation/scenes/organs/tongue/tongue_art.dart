import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../zoom_inks.dart';
import '../../coloured_mesh.dart';
import '../../opening_rim.dart';
import '../../specimen_light.dart';
import 'tongue_anatomy.dart';
import 'tongue_form.dart';
import 'tongue_style.dart';

/// The tongue cut across at the lower first molars, drawn as a fresh
/// section under the zoom's one lamp: the intrinsic muscle, where the
/// zoom's cell lives, flat in the mark, as the thigh's vastus lateralis
/// is, its transverse sheets and vertical fibres crisp creases woven over
/// it, the genioglossus's fibres rising through them, its longitudinal
/// layers cut across as a fine cobble, the septum a pale line down its
/// middle; the genioglossus, the hyoglossus and the styloglossus, the
/// geniohyoids and the mylohyoid in the warmed muscle tone, their fibres
/// faint grooves; the mucous membrane over it all, pale, its papillae a
/// comb over the back; the sulci narrow clefts in shade; the sublingual
/// glands in lobules; the vessels cut across in the blood red, the nerves
/// in the honey; and either side the mandible's body, its cortex a mid
/// ivory over its spongy bone, its canal with its nerve and vessels, the
/// first molar on it, enamel over dentine, its pulp and the two canals of
/// its mesial root.
///
/// Everything costly is built once, for one form and one set of inks:
/// meshes and paths in the scene's units, so a frame only hands them on.
final class TongueArt {
  TongueArt(this.form, this.inks)
    : _light = SpecimenLight(SpecimenLamp.zoom),
      _palette = SpecimenPalette(inks);

  final TongueForm form;
  final ZoomInks inks;
  final SpecimenLight _light;
  final SpecimenPalette _palette;

  /// Where the zoom's cell lives, the intrinsic muscle: one flat tone, the
  /// mark over a neutral, as the thigh's vastus lateralis is.
  static Color homeOf(ZoomInks inks) => Color.alphaBlend(
    inks.glow(TongueStyle.homeMark),
    inks.lit(TongueStyle.homeLit),
  );

  /// What the step from the body draws the tongue's bed in: the muscle, so
  /// that the section comes up on its own tone.
  static Color bedOf(ZoomInks inks) => homeOf(inks);

  /// A tone [lit] of the way to the bright ink, warmed [warmth] of the way
  /// toward the home helix's clay.
  Color _warmed(double lit, double warmth) =>
      Color.lerp(inks.lit(lit), inks.bases.thymine, warmth)!;

  /// [colour] as a cut face facing the eye under the lamp.
  Color _face(Color colour) => Color(
    _palette.colour(
      SpecimenTone(colour, inks.shadow),
      _light.light(0, 0, 1),
      sheen: _light.sheen(0, 0, 1) * TongueStyle.cutSheen,
    ),
  );

  late final Color _home = homeOf(inks);
  late final Color _muscle = _face(
    _warmed(TongueStyle.muscleLit, TongueStyle.muscleWarmth),
  );
  late final Color _deep = _face(
    Color.lerp(
      inks.lit(TongueStyle.looseLit),
      inks.nerve,
      TongueStyle.looseHoney,
    )!,
  );
  late final Color _mucosa = _face(
    _warmed(TongueStyle.mucosaLit, TongueStyle.mucosaWarmth),
  );
  late final Color _fibrous = _face(
    _warmed(TongueStyle.fibrousLit, TongueStyle.fibrousWarmth),
  );
  late final Color _gingiva = _face(
    _warmed(TongueStyle.gingivaLit, TongueStyle.gingivaWarmth),
  );
  late final Color _gland = _face(
    _warmed(TongueStyle.glandLit, TongueStyle.glandWarmth),
  );
  late final Color _cortex = _face(
    _warmed(TongueStyle.cortexLit, TongueStyle.cortexWarmth),
  );
  late final Color _spongy = inks.shade(TongueStyle.spongyShade);
  late final Color _trabecula = _face(
    _warmed(TongueStyle.trabeculaLit, TongueStyle.trabeculaWarmth),
  );
  late final Color _enamel = _face(
    _warmed(TongueStyle.enamelLit, TongueStyle.enamelWarmth),
  );
  late final Color _dentine = _face(
    _warmed(TongueStyle.dentineLit, TongueStyle.dentineWarmth),
  );
  late final Color _pulp = Color.lerp(
    inks.blood,
    inks.ground,
    TongueStyle.pulp,
  )!;
  late final Color _artery = Color.lerp(
    inks.blood,
    inks.ground,
    TongueStyle.artery,
  )!;
  late final Color _vein = Color.lerp(
    inks.blood,
    inks.ground,
    TongueStyle.vein,
  )!;
  late final Color _nerve = Color.lerp(
    inks.nerve,
    inks.ground,
    TongueStyle.nerve,
  )!;
  late final Color _duct = _face(inks.lit(TongueStyle.ductLit));
  late final Color _lumen = inks.shade(TongueStyle.lumenShade);
  late final Color _cleft = inks.shade(TongueStyle.cleftShade);

  // The paths.

  static Path _closed(List<List<Offset>> polygons) {
    final Path path = Path();
    for (final List<Offset> p in polygons) {
      path.addPolygon(p, true);
    }
    return path;
  }

  static Path _lines(List<List<Offset>> lines) {
    final Path path = Path();
    for (final List<Offset> l in lines) {
      path.addPolygon(l, false);
    }
    return path;
  }

  late final Path _soft = form.outline;
  late final Path _homePath = _closed(<List<Offset>>[form.home]);
  late final Path _superior = _closed(<List<Offset>>[form.superior]);
  late final Path _inferiors = _closed(form.inferiors);
  late final Path _fibres = _lines(<List<Offset>>[
    ...form.transverse,
    ...form.vertical,
  ]);
  late final Path _genioFibres = _lines(form.genioFibres);
  late final Path _superiorCells = _closed(form.superiorCells);
  late final Path _inferiorCells = _closed(form.inferiorCells);
  late final Path _genioglossus = _closed(<List<Offset>>[form.genioglossus]);
  late final Path _hyoglossi = _closed(form.hyoglossi);
  late final Path _styloglossi = _closed(form.styloglossi);
  late final Path _geniohyoids = _closed(form.geniohyoids);
  late final Path _geniohyoidCells = _closed(form.geniohyoidCells);
  late final Path _mylohyoid = _closed(<List<Offset>>[form.mylohyoid]);
  late final Path _mylohyoidFibres = _lines(form.mylohyoidFibres);
  late final Path _glands = _closed(form.glands);
  late final Path _lobules = _closed(form.lobules);
  late final Path _sulci = _closed(form.sulci);
  late final Path _sulcusWalls = _lines(form.sulcusWalls);
  late final Path _surface = _lines(<List<Offset>>[form.surface]);
  late final Path _back = _lines(<List<Offset>>[form.back]);
  late final Path _septum = _lines(<List<Offset>>[form.septum]);
  late final Path _papillae = _closed(form.papillae);
  late final Path _bones = _closed(form.bones);
  late final Path _spongyPath = _closed(form.spongy);
  late final Path _trabeculae = _closed(form.trabeculae);
  late final Path _crowns = _closed(form.crowns);
  late final Path _dentines = _closed(form.dentines);
  late final Path _roots = _closed(form.roots);
  late final Path _pulps = _closed(form.pulps);
  late final Path _gingivae = _closed(form.gingivae);

  /// The sulci's rims: a shadow inside the edge facing the lamp and light
  /// inside the edge that turns from it.
  late final List<ui.Vertices> _rims = _build(_layRims);

  void _layRims(ColouredMesh mesh) {
    final OpeningRim rim = OpeningRim(
      toward: _light.screen,
      shadow: inks.shadow,
      light: inks.lit(TongueStyle.lipLit),
      shadowWidth: form.mm(TongueStyle.lipShadow),
      lightWidth: form.mm(TongueStyle.lipLight),
      shadowAlpha: TongueStyle.lipShadowAlpha,
      lightAlpha: TongueStyle.lipLightAlpha,
      probe: form.mm(0.05),
    );
    for (final List<Offset> sulcus in form.sulci) {
      rim.lay(mesh, <Offset>[...sulcus, sulcus.first], _sulci);
    }
  }

  // Drawing.

  /// What the section covers, its papillae and shadow included: the room a
  /// layer of it needs.
  late final Rect bounds = form.extent.inflate(
    form.mm(TongueStyle.shadowY + TongueStyle.shadowSoft),
  );

  /// Builds every mesh and path a frame will draw.
  void prepare() => <Object?>[
    _rims,
    _soft,
    _homePath,
    _superior,
    _inferiors,
    _fibres,
    _genioFibres,
    _superiorCells,
    _inferiorCells,
    _genioglossus,
    _hyoglossi,
    _styloglossi,
    _geniohyoids,
    _geniohyoidCells,
    _mylohyoid,
    _mylohyoidFibres,
    _glands,
    _lobules,
    _sulci,
    _sulcusWalls,
    _surface,
    _back,
    _septum,
    _papillae,
    _bones,
    _spongyPath,
    _trabeculae,
    _crowns,
    _dentines,
    _roots,
    _pulps,
    _gingivae,
    form.whole,
    bounds,
  ];

  Paint _fill(Color colour) => Paint()..color = colour;

  Paint _stroke(Color colour, double width) => Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = width
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..color = colour;

  double _width(double millimetres, double floor, double line) =>
      math.max(form.mm(millimetres), floor * line);

  /// Draws it all, in the scene's units at the tongue's real size; [line]
  /// is a pixel.
  void paint(Canvas canvas, double line) {
    _paintShadow(canvas);
    _paintJaw(canvas, line);
    canvas.save();
    canvas.clipPath(_soft);
    _paintFloor(canvas, line);
    _paintTongue(canvas, line);
    _paintDiscs(canvas, line);
    _paintLining(canvas, line);
    canvas.restore();
    _paintPapillae(canvas, line);
    // The section's edge, as the other specimens'.
    canvas.drawPath(
      form.whole,
      _stroke(
        inks.lit(TongueStyle.edgeLit).withValues(alpha: TongueStyle.edgeAlpha),
        line,
      ),
    );
  }

  void _paintShadow(Canvas canvas) {
    canvas.save();
    canvas.translate(
      form.mm(TongueStyle.shadowX),
      form.mm(TongueStyle.shadowY),
    );
    canvas.drawPath(
      form.whole,
      _fill(inks.shadow.withValues(alpha: TongueStyle.shadowAlpha)),
    );
    canvas.drawPath(
      form.whole,
      _stroke(
        inks.shadow.withValues(alpha: 0.12),
        form.mm(TongueStyle.shadowSoft),
      ),
    );
    canvas.restore();
  }

  /// Either half of the mandible: its cortex, its spongy bone and
  /// trabeculae, its canal and what runs in it; the molar on it.
  void _paintJaw(Canvas canvas, double line) {
    canvas.drawPath(_bones, _fill(_cortex));
    // The spongy bone: its trabeculae, and the marrow in the spaces they
    // leave.
    canvas.drawPath(_spongyPath, _fill(_trabecula));
    canvas.save();
    canvas.clipPath(_spongyPath);
    canvas.drawPath(_trabeculae, _fill(_spongy));
    canvas.restore();
    final double seam = _width(TongueStyle.seam, TongueStyle.seamFloor, line);
    final Color seamInk = inks.shadow.withValues(alpha: TongueStyle.seamAlpha);
    for (final (Offset c, double r) in form.alveolarCanals) {
      canvas.drawCircle(c, r + form.mm(0.25), _fill(_cortex));
      canvas.drawCircle(c, r, _fill(_lumen));
    }
    _discs(canvas, form.alveolarVeins, _vein, 0, line);
    _discs(canvas, form.alveolarArteries, _artery, 0, line);
    _discs(canvas, form.alveolarNerves, _nerve, 0, line);
    // The root in its socket: the lamina dura round it, the ligament a
    // dark hairline.
    canvas.drawPath(
      _roots,
      _stroke(
        _face(inks.lit(TongueStyle.cortexLit + 0.08)),
        form.mm(TongueStyle.laminaDura) * 2,
      ),
    );
    canvas.drawPath(
      _roots,
      _stroke(
        inks.shadow.withValues(alpha: TongueStyle.ligamentAlpha),
        _width(TongueStyle.ligament, 0.6, line),
      ),
    );
    canvas.drawPath(_crowns, _fill(_enamel));
    canvas.drawPath(_dentines, _fill(_dentine));
    canvas.drawPath(_pulps, _fill(_pulp));
    for (final List<Offset> canal in form.canals) {
      for (int i = 0; i + 1 < canal.length; i++) {
        final double t = i / (canal.length - 1);
        canvas.drawLine(
          canal[i],
          canal[i + 1],
          _stroke(
            _pulp,
            form.mm(
              TongueAnatomy.canalWide +
                  (TongueAnatomy.canalNarrow - TongueAnatomy.canalWide) * t,
            ),
          )..strokeCap = StrokeCap.round,
        );
      }
    }
    canvas.drawPath(_dentines, _stroke(seamInk, seam));
    canvas.drawPath(_gingivae, _fill(_gingiva));
    canvas.drawPath(_spongyPath, _stroke(seamInk, seam));
  }

  /// The floor of the mouth: what lies loose in it, deep; the mylohyoid,
  /// the geniohyoids and the sublingual glands.
  void _paintFloor(Canvas canvas, double line) {
    canvas.drawPath(_soft, _fill(_deep));
    final double groove = _width(
      TongueStyle.groove,
      TongueStyle.grooveFloor,
      line,
    );
    final Color grooveInk = inks.shadow.withValues(
      alpha: TongueStyle.grooveAlpha,
    );
    final double seam = _width(TongueStyle.seam, TongueStyle.seamFloor, line);
    final Color seamInk = inks.shadow.withValues(alpha: TongueStyle.seamAlpha);
    canvas.drawPath(_mylohyoid, _fill(_muscle));
    canvas.save();
    canvas.clipPath(_mylohyoid);
    canvas.drawPath(_mylohyoidFibres, _stroke(grooveInk, groove));
    canvas.restore();
    canvas.drawPath(_mylohyoid, _stroke(seamInk, seam));
    canvas.drawPath(_geniohyoids, _fill(_muscle));
    canvas.save();
    canvas.clipPath(_geniohyoids);
    canvas.drawPath(_geniohyoidCells, _stroke(grooveInk, groove));
    canvas.restore();
    canvas.drawPath(_geniohyoids, _stroke(seamInk, seam));
    canvas.drawPath(_glands, _fill(_gland));
    canvas.save();
    canvas.clipPath(_glands);
    canvas.drawPath(
      _lobules,
      _stroke(
        inks.shadow.withValues(alpha: TongueStyle.lobuleAlpha),
        _width(TongueStyle.crease, TongueStyle.creaseFloor, line),
      ),
    );
    canvas.restore();
    canvas.drawPath(_glands, _stroke(seamInk, seam));
  }

  /// The tongue: its aponeurosis, its intrinsic muscle in the mark with
  /// its fibres, the genioglossus, the hyoglossus and the styloglossus, the
  /// septum.
  void _paintTongue(Canvas canvas, double line) {
    final double crease = _width(
      TongueStyle.crease,
      TongueStyle.creaseFloor,
      line,
    );
    final Color creaseInk = inks.shadow.withValues(
      alpha: TongueStyle.creaseAlpha,
    );
    final Color cobbleInk = inks.shadow.withValues(
      alpha: TongueStyle.cobbleAlpha,
    );
    final double groove = _width(
      TongueStyle.groove,
      TongueStyle.grooveFloor,
      line,
    );
    final Color grooveInk = inks.shadow.withValues(
      alpha: TongueStyle.grooveAlpha,
    );
    // The aponeurosis under the back's mucosa.
    canvas.drawPath(
      _back,
      _stroke(
        _fibrous,
        form.mm(TongueAnatomy.mucosaBack + TongueAnatomy.aponeurosis) * 2,
      ),
    );
    // The intrinsic muscle, flat in the mark, its fibres creases woven
    // over it; its longitudinal layers cut across.
    canvas.drawPath(_homePath, _fill(_home));
    canvas.save();
    canvas.clipPath(_homePath);
    canvas.drawPath(_fibres, _stroke(creaseInk, crease));
    canvas.drawPath(_genioFibres, _stroke(creaseInk, crease));
    canvas.drawPath(_superior, _fill(_home));
    canvas.drawPath(_inferiors, _fill(_home));
    canvas.save();
    canvas.clipPath(_superior);
    canvas.drawPath(_superiorCells, _stroke(cobbleInk, crease));
    canvas.restore();
    canvas.save();
    canvas.clipPath(_inferiors);
    canvas.drawPath(_inferiorCells, _stroke(cobbleInk, crease));
    canvas.restore();
    canvas.drawPath(_inferiors, _stroke(creaseInk, crease));
    canvas.restore();
    // The genioglossus rising into it, the hyoglossus and the styloglossus
    // at its margins.
    canvas.drawPath(_genioglossus, _fill(_muscle));
    canvas.save();
    canvas.clipPath(_genioglossus);
    canvas.drawPath(_genioFibres, _stroke(grooveInk, groove));
    canvas.restore();
    canvas.drawPath(_hyoglossi, _fill(_muscle));
    canvas.drawPath(_styloglossi, _fill(_muscle));
    canvas.save();
    canvas.clipPath(_styloglossi);
    canvas.drawPath(_inferiorCells, _stroke(grooveInk, groove));
    canvas.restore();
    final double seam = _width(TongueStyle.seam, TongueStyle.seamFloor, line);
    final Color seamInk = inks.shadow.withValues(alpha: TongueStyle.seamAlpha);
    canvas.drawPath(_hyoglossi, _stroke(seamInk, seam));
    canvas.drawPath(_genioglossus, _stroke(seamInk, seam));
    // The septum down the middle.
    canvas.drawPath(
      _septum,
      _stroke(
        _fibrous,
        _width(TongueAnatomy.septum, TongueStyle.seamFloor, line),
      )..strokeCap = StrokeCap.butt,
    );
  }

  /// What runs under the tongue and in the floor, cut across.
  void _paintDiscs(Canvas canvas, double line) {
    _discs(canvas, form.veins, _vein, TongueStyle.veinLumen, line);
    _discs(canvas, form.arteries, _artery, TongueStyle.arteryLumen, line);
    _discs(canvas, form.ducts, _duct, TongueStyle.ductLumen, line);
    _discs(canvas, form.nerves, _nerve, 0, line);
  }

  void _discs(
    Canvas canvas,
    List<(Offset, double)> discs,
    Color colour,
    double lumen,
    double line,
  ) {
    final double seam = _width(TongueStyle.seam, TongueStyle.seamFloor, line);
    for (final (Offset c, double r) in discs) {
      canvas.drawCircle(c, r, _fill(colour));
      if (lumen > 0) {
        canvas.drawCircle(c, r * lumen, _fill(_lumen));
      }
      canvas.drawCircle(
        c,
        r,
        _stroke(inks.shadow.withValues(alpha: TongueStyle.seamAlpha), seam),
      );
    }
  }

  /// The mucous membrane over the tongue and lining the sulci, and the
  /// sulci's clefts.
  void _paintLining(Canvas canvas, double line) {
    canvas.drawPath(
      _back,
      _stroke(_mucosa, form.mm(TongueAnatomy.mucosaBack) * 2),
    );
    canvas.drawPath(
      _surface,
      _stroke(_mucosa, form.mm(TongueAnatomy.mucosaSide) * 2),
    );
    canvas.drawPath(
      _sulcusWalls,
      _stroke(_mucosa, form.mm(TongueAnatomy.mucosaSide) * 2),
    );
    canvas.drawPath(_sulci, _fill(_cleft));
    _draw(canvas, _rims);
  }

  /// The papillae over the back, in the mucous membrane's tone.
  void _paintPapillae(Canvas canvas, double line) {
    canvas.drawPath(_papillae, _fill(_mucosa));
    canvas.drawPath(
      _papillae,
      _stroke(inks.lit(TongueStyle.edgeLit).withValues(alpha: 0.5), line * 0.8),
    );
  }

  /// Every mesh's vertices as built, for tests, each tagged with the part
  /// it draws: where each lies, in the scene's units, and its colour.
  @visibleForTesting
  List<(String, Float32List, Int32List)> get meshData {
    final List<(String, Float32List, Int32List)> out =
        <(String, Float32List, Int32List)>[];
    final ColouredMesh mesh = ColouredMesh(keep: true);
    _layRims(mesh);
    mesh.build();
    for (final ({Float32List positions, Int32List colours}) kept in mesh.kept) {
      out.add(('rims', kept.positions, kept.colours));
    }
    return out;
  }

  /// The colours the section's parts are filled in, by name. For tests.
  @visibleForTesting
  Map<String, Color> get fills => <String, Color>{
    'intrinsic': _home,
    'muscle': _muscle,
    'deep': _deep,
    'mucosa': _mucosa,
    'fibrous': _fibrous,
    'gingiva': _gingiva,
    'gland': _gland,
    'cortex': _cortex,
    'spongy': _spongy,
    'enamel': _enamel,
    'dentine': _dentine,
    'pulp': _pulp,
    'artery': _artery,
    'vein': _vein,
    'nerve': _nerve,
    'duct': _duct,
    'lumen': _lumen,
    'cleft': _cleft,
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
