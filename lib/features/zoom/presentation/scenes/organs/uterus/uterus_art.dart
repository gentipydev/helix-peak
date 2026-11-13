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
import '../cervix/cervix_anatomy.dart';
import 'uterus_anatomy.dart';
import 'uterus_form.dart';
import 'uterus_style.dart';

/// The uterus bivalved along its canal to the fundus, drawn as a specimen
/// under the zoom's one lamp: its endometrium, where the zoom's cell lives,
/// flat in the mark, as the cervix's ectocervix is, the cut through it
/// either side of the cavity and the cavity's back wall between, cut by its
/// anatomy as crisp lines (its glands running out from the cavity and
/// coiling, the line its basal layer meets its functional layer at, the
/// line it meets the muscle at, the openings of its glands on the back
/// wall); round it the muscle, cut, grey and a little warm, the vessels of
/// its middle layer cut across in it and the tubes' intramural parts
/// running through its cornua; below the isthmus the cervix as the cervix
/// specimen draws it, its stroma pale and fibrous, its crypts and cysts,
/// its canal a deep warm mucosa with its ridge and palmate folds, sunk
/// below the cut; the tubes and the ovarian ligaments lit, running out from
/// the cornua and fading out; the uterine arteries, lit tubes in the blood
/// red, climbing beside it with their branches to the wall, cut short or
/// fading out.
///
/// Everything costly is built once, for one form and one set of inks:
/// meshes and paths in the scene's units, so a frame only hands them on.
final class UterusArt {
  UterusArt(this.form, this.inks)
    : _light = SpecimenLight(SpecimenLamp.zoom),
      _palette = SpecimenPalette(inks);

  final UterusForm form;
  final ZoomInks inks;
  final SpecimenLight _light;
  final SpecimenPalette _palette;

  /// Where the zoom's cell lives, the endometrium: one flat tone, the mark
  /// over a neutral, as the cervix's ectocervix is.
  static Color homeOf(ZoomInks inks) => Color.alphaBlend(
    inks.glow(UterusStyle.homeMark),
    inks.lit(UterusStyle.homeLit),
  );

  /// What the step from the body draws the uterus's bed in: its cut
  /// muscle, most of what its outline covers.
  static Color bedOf(ZoomInks inks) => _cutFace(
    SpecimenLight(SpecimenLamp.zoom),
    SpecimenPalette(inks),
    _warmed(inks, UterusStyle.muscleLit, UterusStyle.muscleWarmth),
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
      sheen: light.sheen(0, 0, 1) * UterusStyle.cutSheen,
    ),
  );

  Color _face(SpecimenTone tone) => _cutFace(_light, _palette, tone);

  /// [tone] as a fresh surface facing the eye, its full sheen.
  Color _surface(SpecimenTone tone) => Color(
    _palette.colour(tone, _light.light(0, 0, 1), sheen: _light.sheen(0, 0, 1)),
  );

  late final Color _home = homeOf(inks);
  late final Color _muscle = _face(
    _warmed(inks, UterusStyle.muscleLit, UterusStyle.muscleWarmth),
  );
  late final Color _stroma = _face(
    _warmed(inks, UterusStyle.stromaLit, UterusStyle.stromaWarmth),
  );
  late final Color _canalMucosa = _surface(
    _warmed(inks, UterusStyle.canalLit, UterusStyle.canalWarmth),
  );
  late final Color _cyst = _face(
    _warmed(inks, UterusStyle.cystLit, UterusStyle.cystWarmth),
  );
  late final SpecimenTone _arteryTone = SpecimenTone(
    Color.lerp(inks.blood, inks.ground, UterusStyle.artery)!,
    inks.shadow,
  );
  late final SpecimenTone _tubeTone = _warmed(
    inks,
    UterusStyle.tubeLit,
    UterusStyle.tubeWarmth,
  );
  late final SpecimenTone _ligamentTone = _warmed(
    inks,
    UterusStyle.ligamentLit,
    UterusStyle.ligamentWarmth,
  );

  static final List<double> _round = <double>[
    for (final double u in UterusStyle.tubeColumns.reversed) -u,
    ...UterusStyle.tubeColumns.skip(1),
  ];

  // The meshes.

  /// What runs beside the uterus, each a lit tube under it: the ligaments
  /// and the tubes, the small branches into its wall, then the arteries.
  late final List<ui.Vertices> _beside = _build(_layBeside);

  void _layBeside(ColouredMesh mesh) {
    _layLigaments(mesh);
    _layTubes(mesh);
    _layBranches(mesh);
    _layArteries(mesh);
  }

  void _layLigaments(ColouredMesh mesh) {
    for (final TubeCourse ligament in form.ligaments) {
      _layTube(mesh, ligament, _ligamentTone);
    }
  }

  void _layTubes(ColouredMesh mesh) {
    for (final TubeCourse tube in form.tubes) {
      _layTube(mesh, tube, _tubeTone);
    }
  }

  void _layBranches(ColouredMesh mesh) {
    for (final TubeCourse branch in form.branches) {
      _layTube(mesh, branch, _arteryTone);
    }
  }

  void _layArteries(ColouredMesh mesh) {
    for (final TubeCourse artery in form.arteries) {
      _layTube(mesh, artery, _arteryTone);
    }
  }

  void _layTube(ColouredMesh mesh, TubeCourse tube, SpecimenTone tone) =>
      tube.lay(
        mesh,
        tone,
        _light,
        _palette,
        _round,
        brightness: UterusStyle.tubeLight,
      );

  late final TubeEnd _end = TubeEnd(
    _palette,
    inks.shadow,
    length: UterusStyle.endLength,
    wall: UterusStyle.endWall,
  );

  /// The rim of the cavity and the canal, sunk below the cut round them.
  late final OpeningRim _rim = OpeningRim(
    toward: _light.screen,
    shadow: inks.shadow,
    light: inks.lit(UterusStyle.ridgeLit),
    shadowWidth: form.mm(UterusStyle.rimShadow),
    lightWidth: form.mm(UterusStyle.rimLight),
    shadowAlpha: UterusStyle.rimShadowAlpha,
    lightAlpha: UterusStyle.rimLightAlpha,
    probe: form.mm(0.3),
  );
  late final List<ui.Vertices> _grooveRim = _build(_layRim);

  void _layRim(ColouredMesh mesh) =>
      _rim.lay(mesh, <Offset>[...form.groove, form.groove.first], _groove);

  // The paths.

  static Path _polygon(List<Offset> points) => Path()..addPolygon(points, true);
  static Path _open(List<Offset> points) => Path()..addPolygon(points, false);

  late final Path _groove = _polygon(form.groove);
  late final Path _canal = _polygon(form.canal);
  late final Path _endometrium = _polygon(form.endometrium);
  late final Path _junction = _open(form.junction);
  late final Path _basal = _open(form.basalLine);
  late final Path _epithelium = _open(form.epithelium);
  late final Path _column = _open(form.column);
  late final Path _pits = () {
    final Path path = Path();
    final double r = form.mm(0.11);
    for (final Offset p in form.pits) {
      path.addOval(Rect.fromCircle(center: p, radius: r));
    }
    return path;
  }();
  late final Path _vessels = () {
    final Path path = Path();
    for (final (Offset at, double rx, double ry, double turn) in form.vessels) {
      path.addPath(
        Path()..addOval(
          Rect.fromCenter(center: Offset.zero, width: 2 * rx, height: 2 * ry),
        ),
        Offset.zero,
        matrix4: _turned(at, turn),
      );
    }
    return path;
  }();
  late final Path _intramural = () {
    final Path path = Path();
    for (final List<Offset> tube in form.intramural) {
      path.addPolygon(tube, false);
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

  static Float64List _turned(Offset at, double turn) {
    final double c = math.cos(turn);
    final double s = math.sin(turn);
    return Float64List.fromList(<double>[
      c, s, 0, 0, //
      -s, c, 0, 0, //
      0, 0, 1, 0, //
      at.dx, at.dy, 0, 1,
    ]);
  }

  /// The cut face's fill: the muscle above the isthmus, giving way across
  /// it to the cervix's stroma below.
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
      form.mm(UterusStyle.shadowX),
      form.mm(UterusStyle.shadowY),
    );
    final Color shadow = inks.shadow;
    canvas.drawPath(
      form.outline,
      Paint()..color = shadow.withValues(alpha: UterusStyle.shadowAlpha),
    );
    canvas.drawPath(
      form.outline,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = form.mm(UterusStyle.shadowSoft)
        ..strokeJoin = StrokeJoin.round
        ..color = shadow.withValues(alpha: 0.12),
    );
    canvas.restore();
  }

  // Drawing.

  /// What the uterus and what is drawn beside it cover, its shadow
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
    return box.inflate(form.mm(UterusStyle.shadowY + UterusStyle.shadowSoft));
  }();

  /// Builds every mesh and path a frame will draw.
  void prepare() => <Object?>[
    _beside,
    _grooveRim,
    _groove,
    _canal,
    _endometrium,
    _junction,
    _basal,
    _epithelium,
    _column,
    _pits,
    _vessels,
    _intramural,
    _cysts,
    _cut,
    form.glandCreases,
    form.foldCreases,
    form.columnCrease,
    form.cryptCreases,
    bounds,
  ];

  /// Draws it all, in the scene's units at the uterus's real size; [line]
  /// is a pixel.
  void paint(Canvas canvas, double line) {
    _paintShadow(canvas);
    // What runs beside it, under it, cut short or fading out.
    _draw(canvas, _beside);
    for (final TubeCourse artery in form.arteries) {
      if (artery.cutEnd) {
        _end.paint(
          canvas,
          artery,
          _arteryTone,
          _light.light(0, 0, 1) * UterusStyle.tubeLight,
        );
      }
    }
    _paintCut(canvas, line);
    _paintOpening(canvas, line);
    _paintEdge(canvas, line, form.outline);
  }

  /// The cut through the wall: the muscle and the cervix's stroma, the
  /// endometrium in the mark over it, and what is cut in each.
  void _paintCut(Canvas canvas, double line) {
    canvas.drawPath(form.outline, _cut);
    canvas.save();
    canvas.clipPath(form.outline);
    // The muscle's vessels, and the tubes running through the cornua.
    canvas.drawPath(
      _vessels,
      Paint()..color = inks.shadow.withValues(alpha: UterusStyle.vesselAlpha),
    );
    canvas.drawPath(
      _vessels,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(
          form.mm(UterusStyle.vesselWall),
          UterusStyle.coatLineFloor * line,
        )
        ..color = inks
            .lit(UterusStyle.vesselWallLit)
            .withValues(alpha: UterusStyle.vesselWallAlpha),
    );
    canvas.drawPath(
      _intramural,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = math.max(
          form.mm(
            2 * UterusAnatomy.intramural + 2 * UterusStyle.intramuralLining,
          ),
          2 * line,
        )
        ..color = inks
            .lit(UterusStyle.intramuralLiningLit)
            .withValues(alpha: UterusStyle.intramuralLiningAlpha),
    );
    canvas.drawPath(
      _intramural,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = math.max(form.mm(2 * UterusAnatomy.intramural), line)
        ..color = inks.shadow.withValues(alpha: UterusStyle.intramuralAlpha),
    );
    // The cervix's crypts and cysts, in its stroma.
    _paintCreases(
      canvas,
      line,
      form.cryptCreases,
      UterusStyle.crypt,
      UterusStyle.cryptAlpha,
    );
    canvas.drawPath(_cysts, Paint()..color = _cyst);
    canvas.drawPath(
      _cysts,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(
          form.mm(UterusStyle.cystRim),
          UterusStyle.coatLineFloor * line,
        )
        ..color = inks.shadow.withValues(alpha: UterusStyle.cystRimAlpha),
    );
    _paintLine(
      canvas,
      line,
      _epithelium,
      UterusStyle.coatLine,
      UterusStyle.epitheliumAlpha,
    );
    // The endometrium, in the mark, and its glands and layers.
    canvas.drawPath(_endometrium, Paint()..color = _home);
    _paintCreases(
      canvas,
      line,
      form.glandCreases,
      UterusStyle.gland,
      UterusStyle.glandAlpha,
    );
    _paintLine(
      canvas,
      line,
      _basal,
      UterusStyle.basalLine,
      UterusStyle.basalAlpha,
    );
    _paintLine(
      canvas,
      line,
      _junction,
      UterusStyle.junctionLine,
      UterusStyle.junctionAlpha,
    );
    canvas.restore();
  }

  /// The cavity's back wall and the canal, sunk below the cut: the
  /// endometrium's surface in the mark with the openings of its glands, the
  /// canal's mucosa with its ridge and folds; the rim round them, the
  /// internal orifice, and where the cut meets the mucosa.
  void _paintOpening(Canvas canvas, double line) {
    canvas.save();
    canvas.clipPath(_endometrium);
    final double pit = UterusStyle.pitFloor * line;
    if (form.mm(0.11) >= pit) {
      canvas.drawPath(
        _pits,
        Paint()..color = inks.shadow.withValues(alpha: UterusStyle.pitAlpha),
      );
    } else {
      final Paint dots = Paint()
        ..color = inks.shadow.withValues(alpha: UterusStyle.pitAlpha);
      for (final Offset p in form.pits) {
        canvas.drawCircle(p, pit, dots);
      }
    }
    canvas.restore();
    canvas.drawPath(_canal, Paint()..color = _canalMucosa);
    canvas.save();
    canvas.clipPath(_canal);
    _paintFolds(canvas, line, form.foldCreases, UterusStyle.foldAlpha);
    _paintRidge(canvas, line);
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
          form.mm(UterusStyle.osLine),
          UterusStyle.coatLineFloor * line,
        )
        ..color = inks.shadow.withValues(alpha: UterusStyle.osAlpha),
    );
    _paintLine(
      canvas,
      line,
      _groove,
      UterusStyle.coatLine,
      UterusStyle.coatLineAlpha,
    );
  }

  void _paintEdge(Canvas canvas, double line, Path path) => canvas.drawPath(
    path,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = line
      ..strokeJoin = StrokeJoin.round
      ..color = inks
          .lit(UterusStyle.edgeLit)
          .withValues(alpha: UterusStyle.edgeAlpha),
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
      ..strokeWidth = math.max(form.mm(width), UterusStyle.coatLineFloor * line)
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round
      ..color = inks.shadow.withValues(alpha: alpha),
  );

  /// Folds: the light on each one's far side, toward the lamp, and the
  /// crease along it at [alpha].
  void _paintFolds(Canvas canvas, double line, Path creases, double alpha) {
    canvas.save();
    final Offset toward = _light.screen * form.mm(UterusStyle.ridge);
    canvas.translate(toward.dx, toward.dy);
    canvas.drawPath(
      creases,
      Paint()
        ..color = inks
            .lit(UterusStyle.ridgeLit)
            .withValues(alpha: UterusStyle.ridgeAlpha),
    );
    canvas.restore();
    _paintCreases(canvas, line, creases, UterusStyle.crease, alpha);
  }

  /// The ridge down the canal's back wall: a pale band toward the lamp
  /// over a crease.
  void _paintRidge(Canvas canvas, double line) {
    canvas.save();
    final Offset toward = _light.screen * form.mm(0.6);
    canvas.translate(toward.dx, toward.dy);
    canvas.drawPath(
      _column,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(form.mm(0.6), UterusStyle.creaseFloor * line)
        ..strokeCap = StrokeCap.round
        ..color = inks.lit(UterusStyle.ridgeLit).withValues(alpha: 0.2),
    );
    canvas.restore();
    _paintCreases(
      canvas,
      line,
      form.columnCrease,
      UterusStyle.crease,
      UterusStyle.creaseAlpha,
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
    final double floor = UterusStyle.creaseFloor * line;
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

    add('ligaments', _layLigaments);
    add('tubes', _layTubes);
    add('branches', _layBranches);
    add('arteries', _layArteries);
    add('rim', _layRim);
    return out;
  }

  /// The colours each part is filled in, by name. For tests.
  @visibleForTesting
  Map<String, Color> get fills => <String, Color>{
    'endometrium': _home,
    'myometrium': _muscle,
    'stroma': _stroma,
    'canal': _canalMucosa,
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
