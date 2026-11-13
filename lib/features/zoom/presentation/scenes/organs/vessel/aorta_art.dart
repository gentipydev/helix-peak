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
import 'aorta_anatomy.dart';
import 'aorta_form.dart';
import 'aorta_style.dart';

/// A length of the descending thoracic aorta on its vertebrae, drawn as a
/// specimen under the zoom's one lamp: the coat the zoom's cell lives in
/// flat in the mark, cut by its anatomy as crisp lines; the adventitia lit
/// as the aorta rounds, its vasa vasorum fine and red on it, turned back
/// over the window; the media bared in the window, its lamellae running
/// round the aorta; the intima pale through the inner window, sunk below
/// the cut, the openings of a pair of intercostal arteries in it; the
/// aorta's cut ends; round it the vertebral bodies and the discs, fading
/// out above and below, the intercostal arteries leaving its back in pairs,
/// the azygos and the hemiazygos, and the thoracic duct between the
/// azygos and the aorta.
///
/// Everything costly is built once, for one form and one set of inks:
/// meshes and paths in the scene's units, so a frame only hands them on.
final class AortaArt {
  AortaArt(this.form, this.inks)
    : _light = SpecimenLight(SpecimenLamp.zoom),
      _palette = SpecimenPalette(inks);

  final AortaForm form;
  final ZoomInks inks;
  final SpecimenLight _light;
  final SpecimenPalette _palette;

  /// Where the zoom's cell lives: one flat tone, the mark over a neutral,
  /// as every specimen's home is.
  static Color homeOf(ZoomInks inks) => Color.alphaBlend(
    inks.glow(AortaStyle.homeMark),
    inks.lit(AortaStyle.homeLit),
  );

  /// A tone [lit] of the way to the bright ink, warmed [warmth] of the way
  /// toward the home helix's clay.
  static SpecimenTone _warmed(ZoomInks inks, double lit, double warmth) =>
      SpecimenTone(
        Color.lerp(inks.lit(lit), inks.bases.thymine, warmth)!,
        inks.shadow,
      );

  /// [tone] as a fresh surface facing the eye, its full sheen.
  Color _surface(SpecimenTone tone) => Color(
    _palette.colour(tone, _light.light(0, 0, 1), sheen: _light.sheen(0, 0, 1)),
  );

  late final Color _home = homeOf(inks);
  late final SpecimenTone _adventitiaTone = _warmed(
    inks,
    AortaStyle.adventitiaLit,
    AortaStyle.adventitiaWarmth,
  );
  late final Color _adventitia = _surface(_adventitiaTone);
  late final Color _media = form.home == AortaHome.media
      ? _home
      : _surface(_warmed(inks, AortaStyle.mediaLit, AortaStyle.mediaWarmth));
  late final Color _intima = form.home == AortaHome.intima
      ? _home
      : _surface(_warmed(inks, AortaStyle.intimaLit, AortaStyle.intimaWarmth));
  late final SpecimenTone _boneTone = _warmed(
    inks,
    AortaStyle.boneLit,
    AortaStyle.boneWarmth,
  );
  late final SpecimenTone _discTone = _warmed(
    inks,
    AortaStyle.discLit,
    AortaStyle.discWarmth,
  );
  late final Color _bone = _surface(_boneTone);
  late final Color _disc = _surface(_discTone);
  late final SpecimenTone _arteryTone = SpecimenTone(
    Color.lerp(inks.blood, inks.ground, AortaStyle.artery)!,
    inks.shadow,
  );
  late final SpecimenTone _veinTone = SpecimenTone(
    Color.lerp(inks.blood, inks.ground, AortaStyle.vein)!,
    inks.shadow,
  );
  late final SpecimenTone _ductTone = SpecimenTone(
    Color.lerp(inks.lit(AortaStyle.ductLit), inks.nerve, AortaStyle.ductHoney)!,
    inks.shadow,
  );

  static final List<double> _round = <double>[
    for (final double u in AortaStyle.tubeColumns.reversed) -u,
    ...AortaStyle.tubeColumns.skip(1),
  ];

  // The meshes.

  /// The column, its bodies and discs lit as they round to either side and
  /// fading out above and below.
  late final List<ui.Vertices> _column = _build(_layColumn);

  void _layColumn(ColouredMesh mesh) {
    const double reach = AortaAnatomy.discWide + 1;
    const double cell = 0.5;
    const int columns = 2 * 19;
    final int rows = (2 * AortaAnatomy.columnTo / cell).ceil() + 1;
    mesh.begin(rows * (columns + 1));
    final int first = mesh.next;
    for (int j = 0; j < rows; j++) {
      final double y = -AortaAnatomy.columnTo + j * cell;
      final bool body = AortaAnatomy.bodies.any(
        (double b) => (y - b).abs() <= AortaAnatomy.bodyHigh,
      );
      final double shown = AortaForm.columnShown(y);
      for (int i = 0; i <= columns; i++) {
        final double x = -reach + 2 * reach * i / columns;
        final double nx = (x / reach).clamp(-0.95, 0.95);
        final double nz = math.sqrt(1 - nx * nx);
        final Offset at = form.place(Offset(x, y));
        mesh.vertex(
          at.dx,
          at.dy,
          _palette.colour(
            body ? _boneTone : _discTone,
            _light.light(nx, 0, nz, form: nz),
            sheen: _light.sheen(nx, 0, nz) * 0.4,
            alpha: shown,
          ),
        );
      }
    }
    for (int j = 0; j + 1 < rows; j++) {
      for (int i = 0; i < columns; i++) {
        final int a = first + j * (columns + 1) + i;
        final int c = a + columns + 1;
        mesh
          ..triangle(a, a + 1, c)
          ..triangle(a + 1, c + 1, c);
      }
    }
  }

  /// What runs beside the aorta, behind and round it: the hemiazygos, the
  /// intercostals, the azygos and the duct.
  late final List<ui.Vertices> _beside = _build(_layBeside);

  void _layBeside(ColouredMesh mesh) {
    _layTube(mesh, form.hemiazygos, _veinTone);
    for (final TubeCourse t in <TubeCourse>[
      ...form.rightIntercostals,
      ...form.leftIntercostals,
    ]) {
      _layTube(mesh, t, _arteryTone);
    }
    _layTube(mesh, form.azygos, _veinTone);
    _layTube(mesh, form.duct, _ductTone);
  }

  /// The aorta itself, its adventitia lit as it rounds; none where the
  /// adventitia is the home, drawn flat.
  late final List<ui.Vertices> _aorta = _build(_layAorta);

  void _layAorta(ColouredMesh mesh) {
    if (form.home == AortaHome.adventitia) {
      return;
    }
    _layTube(mesh, form.aorta, _adventitiaTone);
  }

  void _layTube(ColouredMesh mesh, TubeCourse tube, SpecimenTone tone) =>
      tube.lay(
        mesh,
        tone,
        _light,
        _palette,
        _round,
        brightness: AortaStyle.tubeLight,
      );

  late final TubeEnd _end = TubeEnd(
    _palette,
    inks.shadow,
    length: AortaStyle.endLength,
    wall: AortaStyle.endWall,
  );

  /// The rim of the inner window, sunk below the cut round it.
  late final OpeningRim _rim = OpeningRim(
    toward: _light.screen,
    shadow: inks.shadow,
    light: inks.lit(AortaStyle.ridgeLit),
    shadowWidth: form.mm(AortaStyle.rimShadow),
    lightWidth: form.mm(AortaStyle.rimLight),
    shadowAlpha: AortaStyle.rimShadowAlpha,
    lightAlpha: AortaStyle.rimLightAlpha,
    probe: form.mm(0.3),
  );
  late final List<ui.Vertices> _innerRim = _build(_layRim);

  void _layRim(ColouredMesh mesh) =>
      _rim.lay(mesh, <Offset>[...form.inner, form.inner.first], _inner);

  // The paths.

  static Path _polygon(List<Offset> points) => Path()..addPolygon(points, true);

  late final Path _outer = _polygon(form.outer);
  late final Path _inner = _polygon(form.inner);
  late final Path _lamellae = () {
    final Path path = Path();
    for (final List<Offset> l in form.lamellae) {
      path.addPolygon(l, false);
    }
    return path;
  }();
  late final Path _vasa = () {
    final Path path = Path();
    for (final List<Offset> v in form.vasa) {
      path.addPolygon(v, false);
    }
    return path;
  }();
  late final Path _ostia = () {
    final Path path = Path();
    for (final Offset o in form.ostia) {
      path.addOval(
        Rect.fromCenter(
          center: o,
          width: form.mm(2 * AortaAnatomy.ostiumWide),
          height: form.mm(2 * AortaAnatomy.ostiumHigh),
        ),
      );
    }
    return path;
  }();
  late final Path _bodies = () {
    final Path path = Path();
    for (final List<Offset> b in form.bodies) {
      path.addPolygon(b, true);
    }
    return path;
  }();
  late final Path _discs = () {
    final Path path = Path();
    for (final List<Offset> d in form.discs) {
      path.addPolygon(d, true);
    }
    return path;
  }();
  late final Path _vertebrae = Path()
    ..addPath(_bodies, Offset.zero)
    ..addPath(_discs, Offset.zero);

  /// [colour], fading out above and below as the column does.
  Paint _fading(Color colour) {
    final (double t0, double t1, double b1, double b0) = form.columnFade;
    final double span = b0 - t0;
    return Paint()
      ..shader = ui.Gradient.linear(
        Offset(0, t0),
        Offset(0, b0),
        <Color>[
          colour.withValues(alpha: 0),
          colour,
          colour,
          colour.withValues(alpha: 0),
        ],
        <double>[0, (t1 - t0) / span, (b1 - t0) / span, 1],
      );
  }

  // Drawing.

  /// What the aorta and what is drawn round it cover, its shadow included:
  /// the room a layer of it needs.
  late final Rect bounds = () {
    Rect box = form.box
        .expandToInclude(_bodies.getBounds())
        .expandToInclude(_discs.getBounds())
        .expandToInclude(
          Rect.fromPoints(
            form.place(
              const Offset(-AortaAnatomy.discWide - 1, -AortaAnatomy.columnTo),
            ),
            form.place(
              const Offset(AortaAnatomy.discWide + 1, AortaAnatomy.columnTo),
            ),
          ),
        );
    for (final TubeCourse t in form.beside) {
      for (int i = 0; i < t.length; i++) {
        box = box.expandToInclude(
          Rect.fromCircle(center: t.centres[i], radius: t.radius[i]),
        );
      }
    }
    return box.inflate(form.mm(AortaStyle.shadowY + AortaStyle.shadowSoft));
  }();

  /// Builds every mesh and path a frame will draw.
  void prepare() => <Object?>[
    _column,
    _vertebrae,
    _beside,
    _aorta,
    _innerRim,
    _outer,
    _inner,
    _lamellae,
    _vasa,
    _ostia,
    _bodies,
    _discs,
    bounds,
  ];

  /// Draws it all, in the scene's units at the aorta's real size; [line]
  /// is a pixel.
  void paint(Canvas canvas, double line) {
    // The column, lit, fading out above and below.
    canvas.save();
    canvas.clipPath(_vertebrae);
    _draw(canvas, _column);
    canvas.restore();
    canvas.drawPath(
      _bodies,
      _fading(inks.shadow.withValues(alpha: AortaStyle.boneEdgeAlpha))
        ..style = PaintingStyle.stroke
        ..strokeWidth = line,
    );
    // The aorta's shadow on it.
    canvas.save();
    canvas.translate(form.mm(AortaStyle.shadowX), form.mm(AortaStyle.shadowY));
    canvas.drawPath(
      form.outline,
      Paint()..color = inks.shadow.withValues(alpha: AortaStyle.shadowAlpha),
    );
    canvas.drawPath(
      form.outline,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = form.mm(AortaStyle.shadowSoft)
        ..color = inks.shadow.withValues(alpha: 0.1),
    );
    canvas.restore();
    // What runs beside it, then the aorta and its cut ends.
    _draw(canvas, _beside);
    if (form.home == AortaHome.adventitia) {
      canvas.drawPath(form.outline, Paint()..color = _home);
    } else {
      _draw(canvas, _aorta);
    }
    final double light = _light.light(0, 0, 1) * AortaStyle.tubeLight;
    _end.paint(canvas, form.aorta, _adventitiaTone, light);
    _end.paint(canvas, form.aortaTop, _adventitiaTone, light);
    canvas.save();
    canvas.clipPath(form.outline);
    canvas.drawPath(
      _vasa,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(
          form.mm(AortaAnatomy.vasum),
          AortaStyle.lineFloor * line,
        )
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = Color.lerp(
          inks.blood,
          inks.ground,
          AortaStyle.vasa,
        )!.withValues(alpha: AortaStyle.vasaAlpha),
    );
    canvas.restore();
    _paintWindow(canvas, line);
    _paintEdge(canvas, line, form.outline);
  }

  /// The window: the media bared, its lamellae; the adventitia turned back
  /// round it; the intima through the inner window, with the intercostal
  /// openings and the rim it is sunk by.
  void _paintWindow(Canvas canvas, double line) {
    canvas.drawPath(_outer, Paint()..color = _media);
    canvas.save();
    canvas.clipPath(_outer);
    canvas.drawPath(
      _lamellae,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(
          form.mm(AortaStyle.lamella),
          AortaStyle.lineFloor * line,
        )
        ..color = inks.shadow.withValues(alpha: AortaStyle.lamellaAlpha),
    );
    // The turned-back adventitia's shadow on the media inside its edge.
    canvas.drawPath(
      _outer,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = form.mm(2 * AortaStyle.turnedShadow)
        ..color = inks.shadow.withValues(alpha: AortaStyle.turnedShadowAlpha),
    );
    canvas.restore();
    canvas.drawPath(
      _outer,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(form.mm(AortaStyle.turnedBack), line)
        ..strokeJoin = StrokeJoin.round
        ..color = form.home == AortaHome.adventitia
            ? _home
            : inks
                  .lit(AortaStyle.turnedBackLit)
                  .withValues(alpha: AortaStyle.turnedBackAlpha),
    );
    canvas.drawPath(_inner, Paint()..color = _intima);
    canvas.save();
    canvas.clipPath(_inner);
    canvas.drawPath(
      _ostia,
      Paint()..color = inks.shadow.withValues(alpha: AortaStyle.ostiumAlpha),
    );
    canvas.save();
    final Offset away = -_light.screen * form.mm(AortaStyle.ostiumLip);
    canvas.translate(away.dx, away.dy);
    canvas.drawPath(
      _ostia,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(form.mm(0.12), AortaStyle.lineFloor * line)
        ..color = inks
            .lit(AortaStyle.ridgeLit)
            .withValues(alpha: AortaStyle.ostiumLipAlpha),
    );
    canvas.restore();
    _draw(canvas, _innerRim);
    canvas.restore();
    canvas.drawPath(
      _inner,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(
          form.mm(AortaStyle.intimaEdge),
          AortaStyle.lineFloor * line,
        )
        ..strokeJoin = StrokeJoin.round
        ..color = form.home == AortaHome.intima
            ? _home
            : inks
                  .lit(AortaStyle.intimaLit)
                  .withValues(alpha: AortaStyle.intimaEdgeAlpha),
    );
  }

  void _paintEdge(Canvas canvas, double line, Path path) => canvas.drawPath(
    path,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = line
      ..strokeJoin = StrokeJoin.round
      ..color = inks
          .lit(AortaStyle.edgeLit)
          .withValues(alpha: AortaStyle.edgeAlpha),
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

    add('column', _layColumn);
    add('beside', _layBeside);
    add('aorta', _layAorta);
    add('rim', _layRim);
    return out;
  }

  /// The colours each part is filled in, by name. For tests.
  @visibleForTesting
  Map<String, Color> get fills => <String, Color>{
    'adventitia': form.home == AortaHome.adventitia ? _home : _adventitia,
    'media': _media,
    'intima': _intima,
    'vertebral bodies': _bone,
    'discs': _disc,
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
