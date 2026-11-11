import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../zoom_inks.dart';
import '../../coloured_mesh.dart';
import '../../cut_face.dart';
import '../../relief.dart';
import '../../specimen_light.dart';
import '../../tube_course.dart';
import '../../tube_end.dart';
import 'lung_form.dart';
import 'lung_style.dart';

/// The lungs in place, seen from the front, drawn as a specimen under the
/// zoom's one lamp: the left lung cut open from front to back, where the
/// zoom's cell lives in the mark (its alveoli flat, as the liver's
/// parenchyma is, cut by its anatomy as crisp lines; or the lining of its
/// bronchi; or its pleura), else the parenchyma a deep warm grey turning
/// away under the pleura at its edge; its lobules' septa marked under the
/// pleura and fading toward the hilum; its oblique fissure a crease; its
/// bronchi laid open, their walls pale and their cartilage paler, their
/// lumens emptied in shade, the arteries beside them in the blood red and
/// the veins cut across between the segments in a darker red; the right
/// lung whole, its pleura lit as one rounded form, its fissures creases and
/// its lobules faint; the trachea and the main bronchi lit tubes, the
/// trachea ringed by its cartilages and cut short below the larynx; the
/// root's vessels lit tubes cut short past the hilum.
///
/// Everything costly is built once, for one form and one set of inks:
/// meshes and paths in the scene's units, so a frame only hands them on.
final class LungArt {
  LungArt(this.form, this.inks)
    : _light = SpecimenLight(SpecimenLamp.zoom),
      _palette = SpecimenPalette(inks);

  final LungForm form;
  final ZoomInks inks;
  final SpecimenLight _light;
  final SpecimenPalette _palette;

  LungHome get home => form.home;

  /// Where the zoom's cell lives: one flat tone, the mark over a neutral,
  /// as the liver's parenchyma is.
  static Color homeOf(ZoomInks inks) => Color.alphaBlend(
    inks.glow(LungStyle.homeMark),
    inks.lit(LungStyle.homeLit),
  );

  /// The left lung's cut face where it faces the eye: what the step from
  /// the body draws its bed in, so that the cut comes up on its own tone;
  /// in the mark where the alveoli are the cell's home.
  static Color bedOf(ZoomInks inks, LungHome home) {
    if (home == LungHome.alveoli) {
      return homeOf(inks);
    }
    final SpecimenLight light = SpecimenLight(SpecimenLamp.zoom);
    return Color(
      SpecimenPalette(inks).colour(
        _parenchymaToneOf(inks),
        light.light(0, 0, 1),
        sheen: light.sheen(0, 0, 1) * LungStyle.cutSheen,
      ),
    );
  }

  static SpecimenTone _parenchymaToneOf(ZoomInks inks) =>
      _warmed(inks, LungStyle.parenchymaLit, LungStyle.parenchymaWarmth);

  /// A tone [lit] of the way to the bright ink, warmed [warmth] of the way
  /// toward the home helix's clay.
  static SpecimenTone _warmed(ZoomInks inks, double lit, double warmth) =>
      SpecimenTone(
        Color.lerp(inks.lit(lit), inks.bases.thymine, warmth)!,
        inks.shadow,
      );

  late final Color _home = homeOf(inks);
  late final SpecimenTone _parenchymaTone = _parenchymaToneOf(inks);
  late final SpecimenTone _pleuraTone = _warmed(
    inks,
    LungStyle.pleuraLit,
    LungStyle.pleuraWarmth,
  );
  late final SpecimenTone _tracheaTone = _warmed(
    inks,
    LungStyle.tracheaLit,
    LungStyle.tracheaWarmth,
  );
  late final SpecimenTone _arteryTone = SpecimenTone(
    Color.lerp(inks.blood, inks.ground, LungStyle.artery)!,
    inks.shadow,
  );
  late final SpecimenTone _veinTone = SpecimenTone(
    Color.lerp(inks.blood, inks.ground, LungStyle.vein)!,
    inks.shadow,
  );

  /// [tone]'s cut face where it faces the eye.
  Color _face(SpecimenTone tone) => Color(
    _palette.colour(
      tone,
      _light.light(0, 0, 1),
      sheen: _light.sheen(0, 0, 1) * LungStyle.cutSheen,
    ),
  );

  late final Color _parenchyma = home == LungHome.alveoli
      ? _home
      : _face(_parenchymaTone);
  late final Color _wall = _face(
    _warmed(inks, LungStyle.wallLit, LungStyle.wallWarmth),
  );
  late final Color _cartilage = _face(
    _warmed(inks, LungStyle.cartilageLit, LungStyle.cartilageWarmth),
  );
  late final Color _lumen = inks.shade(LungStyle.lumenShade);
  late final Color _arteryWall = _face(_arteryTone);
  late final Color _veinWall = _face(_veinTone);
  late final Color _vesselLumen = inks.shade(LungStyle.vesselLumenShade);

  /// The septa over the cut face, band by band from under the pleura in,
  /// as the colours they make on its flat tone, so that where two meet
  /// nothing is laid twice; and on the right lung's surface, over it.
  late final List<Color> _septa = <Color>[
    for (int b = 0; b < LungForm.septaBands; b++)
      Color.alphaBlend(
        inks.shadow.withValues(
          alpha: LungStyle.septumAlpha * LungStyle.septumBands[b],
        ),
        _parenchyma,
      ),
  ];

  late final CutFace _cut = CutFace(
    _light,
    _palette,
    sheen: LungStyle.cutSheen,
  );

  /// The parenchyma's edge under the pleura, turning away.
  static const List<(double, double, double)> _rim = <(double, double, double)>[
    (0, LungStyle.rimOuter, 0),
    (0.5, LungStyle.rimMiddle, 0),
    (1, 0, 0),
  ];

  static final List<double> _round = <double>[
    for (final double u in LungStyle.tubeColumns.reversed) -u,
    ...LungStyle.tubeColumns.skip(1),
  ];

  // The meshes.

  /// The parenchyma's edge under the pleura, where the alveoli are not the
  /// cell's home: there the cut face is one flat tone.
  late final List<ui.Vertices> _rimMesh = _build((ColouredMesh mesh) {
    if (home != LungHome.alveoli) {
      _cut.lay(
        mesh,
        <Offset>[...form.outlinePoints, form.outlinePoints.first],
        <Offset>[...form.rimInner, form.rimInner.first],
        (int _) => _parenchymaTone,
        _rim,
      );
    }
  });

  /// The trachea and the main bronchi, lit tubes, the bronchi under it.
  late final List<ui.Vertices> _airTubes = _build(_layAirTubes);

  void _layAirTubes(ColouredMesh mesh) {
    _layTube(mesh, form.rightBronchus, _tracheaTone);
    _layTube(mesh, form.leftBronchus, _tracheaTone);
    _layTube(mesh, form.trachea, _tracheaTone);
  }

  /// The root's vessels, lit tubes over the main bronchus, as the artery
  /// lies in front of it: the lower vein, the upper, the artery.
  late final List<ui.Vertices> _rootVessels = _build(_layRootVessels);

  void _layRootVessels(ColouredMesh mesh) {
    _layTube(mesh, form.rootLowerVein, _veinTone);
    _layTube(mesh, form.rootUpperVein, _veinTone);
    _layTube(mesh, form.rootArtery, _arteryTone);
  }

  void _layTube(ColouredMesh mesh, TubeCourse tube, SpecimenTone tone) =>
      tube.lay(
        mesh,
        tone,
        _light,
        _palette,
        _round,
        brightness: LungStyle.tubeLight,
      );

  /// The right lung's pleura, lit as one rounded form.
  late final List<ui.Vertices> _rightLung = _build(_layRightLung);

  void _layRightLung(ColouredMesh mesh) {
    final Relief relief = Relief(
      form.rightPoints,
      cell: form.mm(LungStyle.reliefCell),
      inflation: LungStyle.inflation,
      sweeps: LungStyle.sweeps,
    );
    final double cell = form.mm(LungStyle.meshCell);
    final Rect grid = _bounds(form.rightPoints).inflate(cell);
    final int columns = (grid.width / cell).ceil() + 1;
    final int rows = (grid.height / cell).ceil() + 1;
    mesh.begin(columns * rows);
    final int first = mesh.next;
    for (int j = 0; j < rows; j++) {
      for (int i = 0; i < columns; i++) {
        final Offset p = grid.topLeft + Offset(i * cell, j * cell);
        final (double nx, double ny, double nz) = relief.normalAt(p);
        mesh.vertex(
          p.dx,
          p.dy,
          _palette.colour(
            _pleuraTone,
            _light.light(nx, ny, nz, form: nz),
            sheen: _light.sheen(nx, ny, nz) * LungStyle.surfaceSheen,
          ),
        );
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

  late final TubeEnd _end = TubeEnd(
    _palette,
    inks.shadow,
    length: LungStyle.endLength,
    wall: LungStyle.endWall,
  );

  // The paths.

  /// A laid-open tube's strip, [share] of its radius to either side: one
  /// side from its start and the other back, wound the same way as every
  /// other, so that strips that overlap fill as one.
  static List<Offset> _strip(TubeCourse t, double share) {
    final List<Offset> out = <Offset>[
      for (int i = 0; i < t.length; i++) t.at(i, share),
      for (int i = t.length - 1; i >= 0; i--) t.at(i, -share),
    ];
    return _area(out) < 0 ? out.reversed.toList() : out;
  }

  static Path _strips(Iterable<TubeCourse> tubes, double share) {
    final Path path = Path();
    for (final TubeCourse t in tubes) {
      path.addPolygon(_strip(t, share), true);
    }
    return path;
  }

  static Path _discs(Iterable<(Offset, double)> discs, double share) {
    final Path path = Path();
    for (final (Offset c, double r) in discs) {
      path.addOval(Rect.fromCircle(center: c, radius: r * share));
    }
    return path;
  }

  late final List<TubeCourse> _airways = <TubeCourse>[
    for (final LungTube a in form.airways) a.course,
  ];

  /// The share of an airway's radius its lumen is, by its generation.
  static double _lumenOf(int generation) =>
      LungStyle.lumenShare[math.min(
        generation,
        LungStyle.lumenShare.length - 1,
      )];

  /// The airways' walls, and their lumens inside them.
  late final Path _airwayWalls = _strips(_airways, 1);
  late final Path _airwayLumens = () {
    final Path path = Path();
    for (final LungTube a in form.airways) {
      path.addPolygon(_strip(a.course, _lumenOf(a.generation)), true);
    }
    return path;
  }();

  /// The lumens' sides, each an open line: the lining, where it is the
  /// cell's home.
  late final Path _lining = () {
    final Path path = Path();
    for (final LungTube a in form.airways) {
      final TubeCourse t = a.course;
      final double share = _lumenOf(a.generation);
      path
        ..addPolygon(<Offset>[
          for (int i = 0; i < t.length; i++) t.at(i, share),
        ], false)
        ..addPolygon(<Offset>[
          for (int i = 0; i < t.length; i++) t.at(i, -share),
        ], false);
    }
    return path;
  }();

  /// The cartilage's plates in the larger bronchi's walls, at intervals
  /// along each side, thickest at its middle.
  late final Path _plates = () {
    final Path path = Path();
    for (final LungTube a in form.airways) {
      if (a.generation > LungStyle.cartilageUpTo) {
        continue;
      }
      final double inner = _lumenOf(a.generation);
      final TubeCourse t = a.course;
      final double radius = t.radius[t.length ~/ 2];
      final double pitch = radius * LungStyle.cartilagePitch;
      final double length = radius * LungStyle.cartilageLength;
      int side = 0;
      for (
        double s = pitch * 0.6;
        s + length < t.arc[t.length - 1];
        s += pitch, side++
      ) {
        final int i = _rowAt(t, s);
        final int j = _rowAt(t, s + length);
        if (j <= i) {
          continue;
        }
        for (final double sign in <double>[1, -1]) {
          // Every other plate on the far side, so they alternate.
          if (sign < 0 && side.isOdd) {
            continue;
          }
          final List<Offset> plate = <Offset>[
            for (int k = i; k <= j; k++) t.at(k, sign * 0.97),
            for (int k = j; k >= i; k--)
              t.at(
                k,
                sign *
                    (1 -
                        (1 - inner) *
                            0.85 *
                            math.sin(math.pi * (k - i) / (j - i))),
              ),
          ];
          path.addPolygon(
            _area(plate) < 0 ? plate.reversed.toList() : plate,
            true,
          );
        }
      }
    }
    return path;
  }();

  static int _rowAt(TubeCourse t, double arc) {
    int i = 0;
    while (i + 1 < t.length && t.arc[i + 1] <= arc) {
      i++;
    }
    return i;
  }

  /// The arteries and the vein, and the vessels cut across: where the
  /// artery and the vein turn back, and the veins between the segments. The
  /// pulmonary artery's and the vein's trunks are emptied, a lumen in shade
  /// inside each wall; the small arteries beside the bronchi are drawn
  /// whole in their wall's red.
  late final Path _arteryWalls = Path()
    ..addPath(_strips(form.arteries, 1), Offset.zero)
    ..addPath(_discs(<(Offset, double)>[form.arteryEnd], 1), Offset.zero);
  late final Path _arteryLumens = Path()
    ..addPath(
      _strips(form.arteries.take(1), 1 - LungStyle.vesselWall),
      Offset.zero,
    )
    ..addPath(
      _discs(<(Offset, double)>[form.arteryEnd], 1 - LungStyle.vesselWall),
      Offset.zero,
    );
  late final Path _veinWalls = Path()
    ..addPath(_strips(<TubeCourse>[form.vein], 1), Offset.zero)
    ..addPath(
      _discs(<(Offset, double)>[form.veinEnd, ...form.veins], 1),
      Offset.zero,
    );
  late final Path _veinLumens = Path()
    ..addPath(
      _strips(<TubeCourse>[form.vein], LungStyle.veinLumen),
      Offset.zero,
    )
    ..addPath(
      _discs(<(Offset, double)>[
        form.veinEnd,
        ...form.veins,
      ], LungStyle.veinLumen),
      Offset.zero,
    );

  /// The lower lobe's bronchi cut across, and the artery beside each.
  late final Path _crossedWalls = _discs(<(Offset, double)>[
    for (final LungCrossing x in form.crossings) (x.centre, x.radius),
  ], 1);
  late final Path _crossedLumens = _discs(<(Offset, double)>[
    for (final LungCrossing x in form.crossings) (x.centre, x.radius),
  ], _lumenOf(4));
  late final Path _crossedArteries = _discs(<(Offset, double)>[
    for (final LungCrossing x in form.crossings) (x.artery, x.arteryRadius),
  ], 1);

  /// The trachea's strip, which its rings are drawn in.
  late final Path _tracheaStrip = Path()
    ..addPolygon(_strip(form.trachea, 1), true);

  /// The trachea's cartilages, each a band across it, and the grooves
  /// between them.
  late final Path _rings = () {
    final Path path = Path();
    final double half = form.ringDepth / 2;
    for (final (Offset a, Offset b) in form.rings) {
      path.addRect(Rect.fromLTRB(a.dx, a.dy - half, b.dx, b.dy + half));
    }
    return path;
  }();
  late final Path _grooves = () {
    final Path path = Path();
    final double half = form.ringPitch / 2;
    for (final (Offset a, Offset b) in form.rings) {
      path
        ..moveTo(a.dx, a.dy + half)
        ..lineTo(b.dx, b.dy + half);
    }
    return path;
  }();

  // The shadow.

  void _paintShadow(Canvas canvas) {
    canvas.save();
    canvas.translate(form.mm(LungStyle.shadowX), form.mm(LungStyle.shadowY));
    final Color shadow = inks.shadow;
    final Path shape = Path()
      ..addPath(form.outline, Offset.zero)
      ..addPath(form.rightOutline, Offset.zero)
      ..addPath(_tracheaStrip, Offset.zero);
    canvas.drawPath(
      shape,
      Paint()..color = shadow.withValues(alpha: LungStyle.shadowAlpha),
    );
    canvas.drawPath(
      shape,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = form.mm(LungStyle.shadowSoft)
        ..strokeJoin = StrokeJoin.round
        ..color = shadow.withValues(alpha: 0.12),
    );
    canvas.restore();
  }

  // Drawing.

  /// What the lungs and what is drawn between them cover, their shadow
  /// included: the room a layer of them needs.
  late final Rect bounds = () {
    Rect box = form.box.expandToInclude(form.rightOutline.getBounds());
    for (final TubeCourse t in form.outside) {
      for (int i = 0; i < t.length; i++) {
        box = box.expandToInclude(
          Rect.fromCircle(center: t.centres[i], radius: t.radius[i] * 1.6),
        );
      }
    }
    return box.inflate(form.mm(LungStyle.shadowY + LungStyle.shadowSoft));
  }();

  /// Builds every mesh and path a frame will draw.
  void prepare() => <Object?>[
    _rimMesh,
    _airTubes,
    _rootVessels,
    _rightLung,
    _airwayWalls,
    _airwayLumens,
    _lining,
    _plates,
    _arteryWalls,
    _arteryLumens,
    _veinWalls,
    _veinLumens,
    _crossedWalls,
    _crossedLumens,
    _crossedArteries,
    _tracheaStrip,
    _rings,
    _grooves,
    form.septa,
    form.surfaceSepta,
    form.upperLobe,
    form.fissure,
    form.rightFissures,
    bounds,
  ];

  /// Draws it all, in the scene's units at the lungs' real size; [line] is
  /// a pixel.
  void paint(Canvas canvas, double line) {
    _paintShadow(canvas);
    // The main bronchi and the trachea, ringed by its cartilages and cut
    // short below the larynx; the root's vessels over the left bronchus,
    // cut short past the hilum.
    _draw(canvas, _airTubes);
    _paintRings(canvas, line);
    _paintEnd(canvas, form.trachea, _tracheaTone);
    _draw(canvas, _rootVessels);
    _paintEnd(canvas, form.rootLowerVein, _veinTone);
    _paintEnd(canvas, form.rootUpperVein, _veinTone);
    _paintEnd(canvas, form.rootArtery, _arteryTone);
    // The right lung, whole.
    _paintRightLung(canvas, line);
    // The left lung's cut face.
    canvas.drawPath(form.outline, Paint()..color = _parenchyma);
    canvas.save();
    canvas.clipPath(form.outline);
    _draw(canvas, _rimMesh);
    _paintSepta(canvas, line);
    _paintFissure(canvas, line, form.fissure);
    canvas.drawPath(_arteryWalls, Paint()..color = _arteryWall);
    canvas.drawPath(_arteryLumens, Paint()..color = _vesselLumen);
    canvas.drawPath(_veinWalls, Paint()..color = _veinWall);
    canvas.drawPath(_veinLumens, Paint()..color = _vesselLumen);
    canvas.drawPath(_crossedArteries, Paint()..color = _arteryWall);
    canvas.drawPath(_airwayWalls, Paint()..color = _wall);
    canvas.drawPath(_crossedWalls, Paint()..color = _wall);
    canvas.drawPath(_plates, Paint()..color = _cartilage);
    canvas.drawPath(_airwayLumens, Paint()..color = _lumen);
    canvas.drawPath(_crossedLumens, Paint()..color = _lumen);
    _paintEdgeLines(canvas, line);
    if (home == LungHome.airways) {
      _paintLining(canvas, line);
    }
    if (home == LungHome.pleura) {
      _paintPleura(canvas, line, form.outline);
      _paintPleura(canvas, line, _fissureLine);
    }
    canvas.restore();
    _paintEdge(canvas, line, form.outline);
  }

  late final Path _fissureLine = Path()..addPolygon(form.fissureLine, false);

  void _paintEnd(Canvas canvas, TubeCourse tube, SpecimenTone tone) => _end
      .paint(canvas, tube, tone, _light.light(0, 0, 1) * LungStyle.tubeLight);

  /// The trachea's rings: the light on each cartilage, and the groove
  /// between two, never thinner than a pixel or so.
  void _paintRings(Canvas canvas, double line) {
    canvas.save();
    canvas.clipPath(_tracheaStrip);
    canvas.drawPath(
      _rings,
      Paint()
        ..color = inks
            .lit(LungStyle.ringLit)
            .withValues(alpha: LungStyle.ringAlpha),
    );
    canvas.drawPath(
      _grooves,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(
          form.ringPitch - form.ringDepth,
          LungStyle.grooveFloor * line,
        )
        ..color = inks.shadow.withValues(alpha: LungStyle.grooveAlpha),
    );
    canvas.restore();
  }

  /// The right lung: its pleura lit, its lobules marked faintly on it, its
  /// fissures creases, its edge.
  void _paintRightLung(Canvas canvas, double line) {
    canvas.drawPath(form.rightOutline, Paint()..color = _face(_pleuraTone));
    canvas.save();
    canvas.clipPath(form.rightOutline);
    _draw(canvas, _rightLung);
    final double width = math.max(
      form.mm(LungStyle.septum),
      LungStyle.septumFloor * line,
    );
    canvas.save();
    final Offset toward = _light.screen * form.mm(LungStyle.septumLight);
    canvas.translate(toward.dx, toward.dy);
    canvas.drawPath(
      form.surfaceSepta,
      _lines(
        width,
        inks
            .lit(LungStyle.septumLightLit)
            .withValues(alpha: LungStyle.septumLightAlpha),
      ),
    );
    canvas.restore();
    canvas.drawPath(
      form.surfaceSepta,
      _lines(
        width,
        inks.shadow.withValues(alpha: LungStyle.surfaceSeptumAlpha),
      ),
    );
    _paintFissure(canvas, line, form.rightFissures);
    if (home == LungHome.pleura) {
      _paintPleura(canvas, line, form.rightOutline);
    }
    canvas.restore();
    _paintEdge(canvas, line, form.rightOutline);
  }

  /// The septa over the cut face, band by band, never thinner than a pixel
  /// or so.
  void _paintSepta(Canvas canvas, double line) {
    final double width = math.max(
      form.mm(LungStyle.septum),
      LungStyle.septumFloor * line,
    );
    for (int b = form.septa.length - 1; b >= 0; b--) {
      canvas.drawPath(form.septa[b], _lines(width, _septa[b]));
    }
  }

  /// A fissure: the light on its far side, toward the lamp, and the crease
  /// along it, never thinner than a pixel or so.
  void _paintFissure(Canvas canvas, double line, Path crease) {
    canvas.save();
    final Offset toward = _light.screen * form.mm(LungStyle.fissureLight);
    canvas.translate(toward.dx, toward.dy);
    canvas.drawPath(
      crease,
      Paint()
        ..color = inks
            .lit(LungStyle.fissureLightLit)
            .withValues(alpha: LungStyle.fissureLightAlpha),
    );
    canvas.restore();
    final Color cleft = inks.shadow.withValues(alpha: LungStyle.fissureAlpha);
    canvas.drawPath(crease, Paint()..color = cleft);
    final double floor = LungStyle.fissureFloor * line;
    if (form.mm(LungStyle.fissure) < floor) {
      canvas.drawPath(
        crease,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = floor - form.mm(LungStyle.fissure)
          ..strokeJoin = StrokeJoin.round
          ..color = cleft,
      );
    }
  }

  /// The crisp line round every emptied lumen, in the shadow ink.
  void _paintEdgeLines(Canvas canvas, double line) {
    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(
        form.mm(LungStyle.edgeLine),
        LungStyle.edgeLineFloor * line,
      )
      ..strokeJoin = StrokeJoin.round
      ..color = inks.shadow.withValues(alpha: LungStyle.edgeLineAlpha);
    canvas.drawPath(_airwayWalls, paint);
    canvas.drawPath(_crossedWalls, paint);
  }

  /// The bronchi's lining along their lumens, in the mark.
  void _paintLining(Canvas canvas, double line) => canvas.drawPath(
    _lining,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(
        form.mm(LungStyle.liningShare),
        LungStyle.liningFloor * line,
      )
      ..strokeJoin = StrokeJoin.round
      ..color = _home,
  );

  /// The visceral pleura along [path], in the mark.
  void _paintPleura(Canvas canvas, double line, Path path) => canvas.drawPath(
    path,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(
        2 * form.mm(LungStyle.pleuraLine),
        LungStyle.pleuraFloor * line,
      )
      ..strokeJoin = StrokeJoin.round
      ..color = _home,
  );

  static Paint _lines(double width, Color colour) => Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = width
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..color = colour;

  /// The outline's own edge, as the other specimens' are edged.
  void _paintEdge(Canvas canvas, double line, Path path) => canvas.drawPath(
    path,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = line
      ..strokeJoin = StrokeJoin.round
      ..color = inks
          .lit(LungStyle.edgeLit)
          .withValues(alpha: LungStyle.edgeAlpha),
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

    add('air tubes', _layAirTubes);
    add('root vessels', _layRootVessels);
    add('right lung', _layRightLung);
    return out;
  }

  /// The colours the cut face and what lies in it are drawn in, by name.
  /// For tests.
  @visibleForTesting
  Map<String, Color> get fills => <String, Color>{
    'parenchyma': _parenchyma,
    'bronchial wall': _wall,
    'cartilage': _cartilage,
    'lumen': _lumen,
    'artery': _arteryWall,
    'vein': _veinWall,
    'vessel lumen': _vesselLumen,
    for (int b = 0; b < _septa.length; b++) 'septum $b': _septa[b],
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

double _area(List<Offset> points) {
  double sum = 0;
  for (int i = 0; i < points.length; i++) {
    final Offset a = points[i];
    final Offset b = points[(i + 1) % points.length];
    sum += a.dx * b.dy - b.dx * a.dy;
  }
  return sum / 2;
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
