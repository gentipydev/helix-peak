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
import 'cervix_anatomy.dart';
import 'cervix_form.dart';
import 'cervix_style.dart';

/// The cervix opened along its canal, drawn as a specimen under the zoom's
/// one lamp: its vaginal part, the ectocervix, where the zoom goes in, flat
/// in the mark, as the bladder's urothelium is, cut by its anatomy as crisp
/// lines (the line its epithelium meets the stroma at, a little in from its
/// surface; the transformation zone's inner edges round the external
/// orifice; the crypts; the Nabothian cysts, pale); the cut stroma above it
/// pale and fibrous, giving way at the isthmus to the uterus's muscle, grey
/// and a little warm; the canal's back wall a deep warm mucosa, its ridge
/// and palmate folds as ridges and creases, sunk below the cut, and the
/// uterine cavity above it paler; round the vaginal part the vagina's vault,
/// its walls cut, its back wall's mucosa seen from in front with its column
/// and rugae, the vaginal part's shadow on it; and the uterine arteries,
/// lit tubes in the blood red, their branches and the small branches into
/// the wall, each cut short.
///
/// Everything costly is built once, for one form and one set of inks:
/// meshes and paths in the scene's units, so a frame only hands them on.
final class CervixArt {
  CervixArt(this.form, this.inks)
    : _light = SpecimenLight(SpecimenLamp.zoom),
      _palette = SpecimenPalette(inks);

  final CervixForm form;
  final ZoomInks inks;
  final SpecimenLight _light;
  final SpecimenPalette _palette;

  /// Where the zoom goes in, the ectocervix: one flat tone, the mark over a
  /// neutral, as the bladder's urothelium is.
  static Color homeOf(ZoomInks inks) => Color.alphaBlend(
    inks.glow(CervixStyle.homeMark),
    inks.lit(CervixStyle.homeLit),
  );

  /// What the step from the body draws the cervix's bed in: its cut
  /// stroma, most of what the half it draws in to covers.
  static Color bedOf(ZoomInks inks) => _cutFace(
    SpecimenLight(SpecimenLamp.zoom),
    SpecimenPalette(inks),
    _warmed(inks, CervixStyle.stromaLit, CervixStyle.stromaWarmth),
  );

  /// A tone [lit] of the way to the bright ink, warmed [warmth] of the way
  /// toward the home helix's clay.
  static SpecimenTone _warmed(ZoomInks inks, double lit, double warmth) =>
      SpecimenTone(
        Color.lerp(inks.lit(lit), inks.bases.thymine, warmth)!,
        inks.shadow,
      );

  /// [tone]'s cut face where it faces the eye: less sheen than a fresh
  /// surface, being cut.
  static Color _cutFace(
    SpecimenLight light,
    SpecimenPalette palette,
    SpecimenTone tone,
  ) => Color(
    palette.colour(
      tone,
      light.light(0, 0, 1),
      sheen: light.sheen(0, 0, 1) * CervixStyle.cutSheen,
    ),
  );

  Color _face(SpecimenTone tone) => _cutFace(_light, _palette, tone);

  /// [tone] as a fresh surface facing the eye, its full sheen.
  Color _surface(SpecimenTone tone) => Color(
    _palette.colour(tone, _light.light(0, 0, 1), sheen: _light.sheen(0, 0, 1)),
  );

  late final Color _home = homeOf(inks);
  late final Color _stroma = _face(
    _warmed(inks, CervixStyle.stromaLit, CervixStyle.stromaWarmth),
  );
  late final Color _muscle = _face(
    _warmed(inks, CervixStyle.muscleLit, CervixStyle.muscleWarmth),
  );
  late final Color _canalMucosa = _surface(
    _warmed(inks, CervixStyle.canalLit, CervixStyle.canalWarmth),
  );
  late final Color _cavityMucosa = _surface(
    _warmed(inks, CervixStyle.cavityLit, CervixStyle.cavityWarmth),
  );
  late final Color _vaginaMucosa = _surface(
    _warmed(inks, CervixStyle.vaginaLit, CervixStyle.vaginaWarmth),
  );
  late final Color _vaginaEpithelium = _face(
    _warmed(
      inks,
      CervixStyle.vaginaEpitheliumLit,
      CervixStyle.vaginaEpitheliumWarmth,
    ),
  );
  late final Color _vaginaLamina = _face(
    _warmed(inks, CervixStyle.vaginaLaminaLit, CervixStyle.vaginaLaminaWarmth),
  );
  late final Color _vaginaMuscle = _face(
    _warmed(inks, CervixStyle.vaginaMuscleLit, CervixStyle.vaginaMuscleWarmth),
  );
  late final Color _cyst = _face(
    _warmed(inks, CervixStyle.cystLit, CervixStyle.cystWarmth),
  );
  late final SpecimenTone _arteryTone = SpecimenTone(
    Color.lerp(inks.blood, inks.ground, CervixStyle.artery)!,
    inks.shadow,
  );

  static final List<double> _round = <double>[
    for (final double u in CervixStyle.tubeColumns.reversed) -u,
    ...CervixStyle.tubeColumns.skip(1),
  ];

  // The meshes.

  /// What runs beside the cervix, each a lit tube under it: the small
  /// branches into its wall, then the arteries.
  late final List<ui.Vertices> _beside = _build(_layBeside);

  void _layBeside(ColouredMesh mesh) {
    _layBranches(mesh);
    _layArteries(mesh);
  }

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

  void _layTube(ColouredMesh mesh, TubeCourse tube) => tube.lay(
    mesh,
    _arteryTone,
    _light,
    _palette,
    _round,
    brightness: CervixStyle.tubeLight,
  );

  late final TubeEnd _end = TubeEnd(
    _palette,
    inks.shadow,
    length: CervixStyle.endLength,
    wall: CervixStyle.endWall,
  );

  /// The rims of the canal and of the vagina's vault, each sunk below the
  /// cut round it.
  late final OpeningRim _rim = OpeningRim(
    toward: _light.screen,
    shadow: inks.shadow,
    light: inks.lit(CervixStyle.ridgeLit),
    shadowWidth: form.mm(CervixStyle.rimShadow),
    lightWidth: form.mm(CervixStyle.rimLight),
    shadowAlpha: CervixStyle.rimShadowAlpha,
    lightAlpha: CervixStyle.rimLightAlpha,
    probe: form.mm(0.3),
  );
  late final List<ui.Vertices> _grooveRim = _build(
    (ColouredMesh mesh) =>
        _rim.lay(mesh, <Offset>[...form.groove, form.groove.first], _groove),
  );
  late final List<ui.Vertices> _lumenRim = _build((ColouredMesh mesh) {
    for (final List<Offset> edge in form.lumenEdges) {
      _rim.lay(mesh, edge, _lumen);
    }
  });

  // The paths.

  static Path _polygon(List<Offset> points) => Path()..addPolygon(points, true);
  static Path _open(List<Offset> points) => Path()..addPolygon(points, false);

  late final Path _groove = _polygon(form.groove);
  late final Path _cavity = _polygon(form.cavity);
  late final Path _canal = _polygon(form.canal);
  late final Path _below = _polygon(form.below);
  late final Path _epithelium = _open(form.epithelium);
  late final Path _zoneEdges = () {
    final Path path = Path();
    for (final List<Offset> edge in form.zoneEdges) {
      path.addPolygon(edge, false);
    }
    return path;
  }();
  late final Path _cysts = () {
    final Path path = Path();
    for (final (Offset at, double r) in form.cysts) {
      path.addOval(Rect.fromCircle(center: at, radius: r));
    }
    return path;
  }();
  late final Path _cystLight = () {
    // The lip of each cut cyst's hollow on the side away from the lamp,
    // which faces it.
    final Path path = Path();
    for (final (Offset at, double r) in form.cysts) {
      final Offset away = -_light.screen * (r * 0.32);
      path.addPath(
        Path.combine(
          PathOperation.difference,
          Path()..addOval(Rect.fromCircle(center: at, radius: r * 0.92)),
          Path()..addOval(Rect.fromCircle(center: at - away, radius: r * 0.92)),
        ),
        Offset.zero,
      );
    }
    return path;
  }();
  late final Path _column = _open(form.column);
  late final Path _vaginaColumn = _open(form.vaginaColumn);
  late final Path _lumen = _polygon(form.lumen);
  late final Path _vagina = _polygon(form.vaginaOutline);
  late final List<Path> _walls = <Path>[
    for (final List<Offset> wall in form.walls) _polygon(wall),
  ];
  late final List<Path> _laminae = <Path>[
    for (final List<Offset> lamina in form.laminae) _polygon(lamina),
  ];
  late final List<Path> _vaginalEpithelia = <Path>[
    for (final List<Offset> e in form.vaginalEpithelia) _polygon(e),
  ];
  late final Path _portio = _polygon(form.portio);

  /// The cut face's fill: the uterus's muscle above the isthmus, giving way
  /// across it to the cervix's stroma below.
  late final Paint _cut = Paint()
    ..shader = ui.Gradient.linear(
      form.place(
        const Offset(0, CervixAnatomy.internalOs - CervixAnatomy.isthmusBlend),
      ),
      form.place(
        const Offset(0, CervixAnatomy.internalOs + CervixAnatomy.isthmusBlend),
      ),
      <Color>[_muscle, _stroma],
    );

  // The shadow.

  void _paintShadow(Canvas canvas) {
    canvas.save();
    canvas.translate(
      form.mm(CervixStyle.shadowX),
      form.mm(CervixStyle.shadowY),
    );
    final Color shadow = inks.shadow;
    final Path shape = Path()
      ..addPath(form.outline, Offset.zero)
      ..addPath(_vagina, Offset.zero);
    canvas.drawPath(
      shape,
      Paint()..color = shadow.withValues(alpha: CervixStyle.shadowAlpha),
    );
    canvas.drawPath(
      shape,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = form.mm(CervixStyle.shadowSoft)
        ..strokeJoin = StrokeJoin.round
        ..color = shadow.withValues(alpha: 0.12),
    );
    canvas.restore();
  }

  // Drawing.

  /// What the cervix, the vagina and what is drawn beside them cover, their
  /// shadow included: the room a layer of it needs.
  late final Rect bounds = () {
    Rect box = form.box.expandToInclude(_vagina.getBounds());
    for (final TubeCourse t in <TubeCourse>[...form.beside, ...form.branches]) {
      for (int i = 0; i < t.length; i++) {
        box = box.expandToInclude(
          Rect.fromCircle(center: t.centres[i], radius: t.radius[i]),
        );
      }
    }
    return box.inflate(form.mm(CervixStyle.shadowY + CervixStyle.shadowSoft));
  }();

  /// Builds every mesh and path a frame will draw.
  void prepare() => <Object?>[
    _beside,
    _grooveRim,
    _lumenRim,
    _groove,
    _cavity,
    _canal,
    _below,
    _epithelium,
    _zoneEdges,
    _cysts,
    _cystLight,
    _column,
    _vaginaColumn,
    _lumen,
    _vagina,
    _walls,
    _laminae,
    _vaginalEpithelia,
    _portio,
    _cut,
    form.foldCreases,
    form.finerCreases,
    form.cryptCreases,
    form.columnCrease,
    form.vaginaColumnCrease,
    form.rugaCreases,
    bounds,
  ];

  /// Draws it all, in the scene's units at the cervix's real size; [line]
  /// is a pixel.
  void paint(Canvas canvas, double line) {
    _paintShadow(canvas);
    // What runs beside it, under it, cut short.
    _draw(canvas, _beside);
    for (final TubeCourse artery in form.arteries) {
      _end.paint(
        canvas,
        artery,
        _arteryTone,
        _light.light(0, 0, 1) * CervixStyle.tubeLight,
      );
    }
    _paintVagina(canvas, line);
    _paintCervix(canvas, line);
  }

  /// The vagina's vault: its back wall's mucosa, its column and rugae, the
  /// rim of its walls and the vaginal part's shadow on it; then its walls,
  /// cut, coat by coat.
  void _paintVagina(Canvas canvas, double line) {
    canvas.drawPath(_lumen, Paint()..color = _vaginaMucosa);
    canvas.save();
    canvas.clipPath(_lumen);
    _paintRidge(canvas, line, _vaginaColumn, form.vaginaColumnCrease);
    _paintFolds(canvas, line, form.rugaCreases, CervixStyle.rugaAlpha);
    _draw(canvas, _lumenRim);
    canvas.save();
    canvas.translate(
      form.mm(CervixStyle.lipShadowX),
      form.mm(CervixStyle.lipShadowY),
    );
    canvas.drawPath(
      _portio,
      Paint()
        ..color = inks.shadow.withValues(alpha: CervixStyle.lipShadowAlpha),
    );
    canvas.restore();
    canvas.restore();
    for (int i = 0; i < _walls.length; i++) {
      canvas.drawPath(_walls[i], Paint()..color = _vaginaMuscle);
      canvas.drawPath(_laminae[i], Paint()..color = _vaginaLamina);
      canvas.drawPath(_vaginalEpithelia[i], Paint()..color = _vaginaEpithelium);
    }
    _paintEdge(canvas, line, _vagina);
  }

  /// The cervix: its cut face, the ectocervix in the mark over it, the
  /// crypts, cysts and the zone's edges cut into them; the canal and the
  /// cavity sunk below it, the canal's ridge and folds; its edges.
  void _paintCervix(Canvas canvas, double line) {
    canvas.drawPath(form.outline, _cut);
    canvas.save();
    canvas.clipPath(form.outline);
    canvas.drawPath(_below, Paint()..color = _home);
    _paintCreases(
      canvas,
      line,
      form.cryptCreases,
      CervixStyle.crypt,
      CervixStyle.cryptAlpha,
    );
    canvas.drawPath(_cysts, Paint()..color = _cyst);
    canvas.drawPath(
      _cystLight,
      Paint()
        ..color = inks
            .lit(CervixStyle.cystLight)
            .withValues(alpha: CervixStyle.cystLightAlpha),
    );
    canvas.drawPath(
      _cysts,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(
          form.mm(CervixStyle.cystRim),
          CervixStyle.coatLineFloor * line,
        )
        ..color = inks.shadow.withValues(alpha: CervixStyle.cystRimAlpha),
    );
    _paintLine(
      canvas,
      line,
      _zoneEdges,
      CervixStyle.zoneLine,
      CervixStyle.zoneAlpha,
    );
    _paintLine(
      canvas,
      line,
      _epithelium,
      CervixStyle.coatLine,
      CervixStyle.epitheliumAlpha,
    );
    canvas.restore();
    // The cavity and the canal, sunk below the cut.
    canvas.drawPath(_cavity, Paint()..color = _cavityMucosa);
    canvas.drawPath(_canal, Paint()..color = _canalMucosa);
    canvas.save();
    canvas.clipPath(_canal);
    _paintFolds(canvas, line, form.foldCreases, CervixStyle.creaseAlpha);
    _paintFolds(canvas, line, form.finerCreases, CervixStyle.finerAlpha);
    _paintRidge(canvas, line, _column, form.columnCrease);
    canvas.restore();
    canvas.save();
    canvas.clipPath(_groove);
    _draw(canvas, _grooveRim);
    canvas.restore();
    final (Offset a, Offset b) = form.internalOsLine;
    canvas.drawLine(
      a,
      b,
      Paint()
        ..strokeWidth = math.max(
          form.mm(CervixStyle.osLine),
          CervixStyle.coatLineFloor * line,
        )
        ..color = inks.shadow.withValues(alpha: CervixStyle.osAlpha),
    );
    // Where the cut meets the mucosa, and the outline's own edge.
    _paintLine(
      canvas,
      line,
      _groove,
      CervixStyle.coatLine,
      CervixStyle.coatLineAlpha,
    );
    _paintEdge(canvas, line, form.outline);
  }

  void _paintEdge(Canvas canvas, double line, Path path) => canvas.drawPath(
    path,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = line
      ..strokeJoin = StrokeJoin.round
      ..color = inks
          .lit(CervixStyle.edgeLit)
          .withValues(alpha: CervixStyle.edgeAlpha),
  );

  /// [path], a line [width] wide in the shadow ink at [alpha], never
  /// thinner than half a pixel.
  void _paintLine(
    Canvas canvas,
    double line,
    Path path,
    double width,
    double alpha,
  ) => canvas.drawPath(
    path,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(form.mm(width), CervixStyle.coatLineFloor * line)
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round
      ..color = inks.shadow.withValues(alpha: alpha),
  );

  /// Folds or rugae: the light on each one's far side, toward the lamp, and
  /// the crease along it at [alpha].
  void _paintFolds(Canvas canvas, double line, Path creases, double alpha) {
    canvas.save();
    final Offset toward = _light.screen * form.mm(CervixStyle.ridge);
    canvas.translate(toward.dx, toward.dy);
    canvas.drawPath(
      creases,
      Paint()
        ..color = inks
            .lit(CervixStyle.ridgeLit)
            .withValues(alpha: CervixStyle.ridgeAlpha),
    );
    canvas.restore();
    _paintCreases(canvas, line, creases, CervixStyle.crease, alpha);
  }

  /// A ridge: a pale band toward the lamp over a crease.
  void _paintRidge(Canvas canvas, double line, Path ridge, Path crease) {
    canvas.save();
    final Offset toward = _light.screen * form.mm(CervixStyle.columnLight);
    canvas.translate(toward.dx, toward.dy);
    canvas.drawPath(
      ridge,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(
          form.mm(CervixStyle.columnLightWidth),
          CervixStyle.creaseFloor * line,
        )
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = inks
            .lit(CervixStyle.ridgeLit)
            .withValues(alpha: CervixStyle.columnLightAlpha),
    );
    canvas.restore();
    _paintCreases(
      canvas,
      line,
      crease,
      CervixStyle.columnCrease,
      CervixStyle.columnAlpha,
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
    final double floor = CervixStyle.creaseFloor * line;
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
    add('arteries', _layArteries);
    add(
      'canal rim',
      (ColouredMesh mesh) =>
          _rim.lay(mesh, <Offset>[...form.groove, form.groove.first], _groove),
    );
    add('vault rim', (ColouredMesh mesh) {
      for (final List<Offset> edge in form.lumenEdges) {
        _rim.lay(mesh, edge, _lumen);
      }
    });
    return out;
  }

  /// The colours each part is filled in, by name. For tests.
  @visibleForTesting
  Map<String, Color> get fills => <String, Color>{
    'ectocervix': _home,
    'stroma': _stroma,
    'myometrium': _muscle,
    'canal': _canalMucosa,
    'cavity': _cavityMucosa,
    'vaginal mucosa': _vaginaMucosa,
    'vaginal epithelium': _vaginaEpithelium,
    'vaginal lamina propria': _vaginaLamina,
    'vaginal muscularis': _vaginaMuscle,
    'Nabothian cysts': _cyst,
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
