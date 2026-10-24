import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../zoom_inks.dart';
import '../../coloured_mesh.dart';
import '../../cut_face.dart';
import '../../specimen_light.dart';
import '../../tube_course.dart';
import '../../tube_end.dart';
import 'node_form.dart';
import 'node_style.dart';

/// The lymph node cut in two through its hilum, drawn as a specimen under
/// the zoom's one lamp: where the zoom's cell lives flat in the mark (its
/// sinuses, its follicles, its paracortex, its medullary cords, or its
/// cortex); else the cortex the lightest cut face, its follicles darker
/// mantles round pale germinal centres, the paracortex a shade deeper and
/// the medulla the darkest, its cords paler in it, all turning away under
/// the capsule; the sinuses under the capsule, along the trabeculae and
/// between the cords fine pale lines; the afferent lymphatics pale lit
/// tubes coming in to it; the efferent, the artery and the vein at its
/// hilum, cut short.
///
/// Everything costly is built once, for one form and one set of inks:
/// meshes and paths in the scene's units, so a frame only hands them on.
final class NodeArt {
  NodeArt(this.form, this.inks)
    : _light = SpecimenLight(SpecimenLamp.zoom),
      _palette = SpecimenPalette(inks);

  final NodeForm form;
  final ZoomInks inks;
  final SpecimenLight _light;
  final SpecimenPalette _palette;

  NodeHome get home => form.home;

  /// Where the zoom's cell lives: one flat tone, the mark over a neutral,
  /// as the kidney's cortex is.
  static Color homeOf(ZoomInks inks) => Color.alphaBlend(
    inks.glow(NodeStyle.homeMark),
    inks.lit(NodeStyle.homeLit),
  );

  SpecimenTone _tone(double lit) => SpecimenTone(
    Color.lerp(inks.lit(lit), inks.bases.thymine, NodeStyle.warmth)!,
    inks.shadow,
  );

  late final Color _home = homeOf(inks);
  late final SpecimenTone _cortexTone = _tone(NodeStyle.cortexLit);
  late final SpecimenTone _medullaTone = _tone(NodeStyle.medullaLit);
  late final SpecimenTone _lymphTone = SpecimenTone(
    Color.lerp(inks.lit(NodeStyle.lymphLit), inks.nerve, NodeStyle.lymphHoney)!,
    inks.shadow,
  );
  late final SpecimenTone _arteryTone = SpecimenTone(
    Color.lerp(inks.blood, inks.ground, NodeStyle.artery)!,
    inks.shadow,
  );
  late final SpecimenTone _veinTone = SpecimenTone(
    Color.lerp(inks.blood, inks.ground, NodeStyle.vein)!,
    inks.shadow,
  );

  /// [lit]'s cut face where it faces the eye.
  Color _face(double lit) => Color(
    _palette.colour(
      _tone(lit),
      _light.light(0, 0, 1),
      sheen: _light.sheen(0, 0, 1) * NodeStyle.cutSheen,
    ),
  );

  late final Color _cortex = home == NodeHome.cortex
      ? _home
      : _face(NodeStyle.cortexLit);
  late final Color _paracortex = home == NodeHome.paracortex
      ? _home
      : _face(NodeStyle.paracortexLit);
  late final Color _medulla = _face(NodeStyle.medullaLit);
  late final Color _mantle = _face(NodeStyle.mantleLit);
  late final Color _germinal = _face(NodeStyle.germinalLit);
  late final Color _cord = home == NodeHome.cords
      ? _home
      : _face(NodeStyle.cordLit);
  late final Color _sinus = home == NodeHome.sinuses
      ? inks.mark
      : inks.lit(NodeStyle.sinusLit).withValues(alpha: NodeStyle.sinusAlpha);

  late final CutFace _faceOf = CutFace(
    _light,
    _palette,
    sheen: NodeStyle.cutSheen,
  );

  /// The cut face's edge turning away under the capsule.
  static const List<(double, double, double)> _rim = <(double, double, double)>[
    (0, NodeStyle.rimOuter, 0),
    (0.5, NodeStyle.rimMiddle, 0),
    (1, 0, 0),
  ];

  static final List<double> _round = <double>[
    for (final double u in NodeStyle.tubeColumns.reversed) -u,
    ...NodeStyle.tubeColumns.skip(1),
  ];

  // The meshes.

  /// The cut face's edge under the capsule, all the way round but where
  /// the cortex is the cell's home, flat: there only at the hilum.
  late final List<ui.Vertices> _rimMesh = _build(_layRim);

  void _layRim(ColouredMesh mesh) {
    final int n = form.outlinePoints.length;
    // From the hilum's middle round, so a run is never broken where the
    // list wraps.
    final List<int> order = <int>[
      for (int k = 0; k <= n; k++) (k + n ~/ 2) % n,
    ];
    final List<Offset> outer = <Offset>[];
    final List<Offset> inner = <Offset>[];
    final List<SpecimenTone> tones = <SpecimenTone>[];
    void flush() {
      if (outer.length > 1) {
        final List<SpecimenTone> laid = List<SpecimenTone>.of(tones);
        _faceOf.lay(
          mesh,
          List<Offset>.of(outer),
          List<Offset>.of(inner),
          (int i) => laid[i],
          _rim,
        );
      }
      outer.clear();
      inner.clear();
      tones.clear();
    }

    for (final int i in order) {
      final bool hilum = form.atHilum(i);
      if (!hilum && home == NodeHome.cortex) {
        flush();
        continue;
      }
      outer.add(form.outlinePoints[i]);
      inner.add(form.rimInner[i]);
      tones.add(hilum ? _medullaTone : _cortexTone);
    }
    flush();
  }

  /// The lymphatics and the vessels, each a lit tube.
  late final List<ui.Vertices> _afferents = _build((ColouredMesh mesh) {
    for (final TubeCourse t in form.afferents) {
      _layTube(mesh, t, _lymphTone);
    }
  });
  late final List<ui.Vertices> _hilumVessels = _build((ColouredMesh mesh) {
    _layTube(mesh, form.vein, _veinTone);
    _layTube(mesh, form.artery, _arteryTone);
    _layTube(mesh, form.efferent, _lymphTone);
  });

  void _layTube(ColouredMesh mesh, TubeCourse tube, SpecimenTone tone) =>
      tube.lay(
        mesh,
        tone,
        _light,
        _palette,
        _round,
        brightness: NodeStyle.tubeLight,
      );

  late final TubeEnd _end = TubeEnd(
    _palette,
    inks.shadow,
    length: NodeStyle.endLength,
    wall: NodeStyle.endWall,
  );

  // The paths.

  late final Path _cortexBand = Path()..addPolygon(form.cortexBand, true);
  late final Path _paracortexBand = Path()
    ..addPolygon(form.paracortexBand, true);
  late final Path _mantles = () {
    final Path path = Path();
    for (final NodeFollicle f in form.follicles) {
      path.addOval(Rect.fromCircle(center: f.centre, radius: f.radius));
    }
    return path;
  }();
  late final Path _germs = () {
    final Path path = Path();
    for (final NodeFollicle f in form.follicles) {
      final Offset? g = f.germ;
      if (g != null) {
        path.addOval(Rect.fromCircle(center: g, radius: f.germRadius));
      }
    }
    return path;
  }();
  late final Path _cords = _lines(form.cords);
  late final Path _trabeculae = () {
    final Path path = Path();
    for (final (Offset a, Offset b) in form.trabeculae) {
      path
        ..moveTo(a.dx, a.dy)
        ..lineTo(b.dx, b.dy);
    }
    return path;
  }();

  /// The sinuses: under the capsule, beside each trabecula, and between
  /// the cords.
  late final Path _sinuses = () {
    final Path path = Path()..addPolygon(form.subcapsular, false);
    final double off = form.mm(NodeStyle.trabecula * 1.6);
    for (final (Offset a, Offset b) in form.trabeculae) {
      final Offset way = b - a;
      final Offset across =
          Offset(-way.dy, way.dx) / math.max(way.distance, 1e-12) * off;
      path
        ..moveTo(a.dx + across.dx, a.dy + across.dy)
        ..lineTo(b.dx + across.dx, b.dy + across.dy);
    }
    for (final List<Offset> s in form.medullarySinuses) {
      path.addPolygon(s, false);
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
    canvas.translate(form.mm(NodeStyle.shadowX), form.mm(NodeStyle.shadowY));
    final Color shadow = inks.shadow;
    canvas.drawPath(
      form.outline,
      Paint()..color = shadow.withValues(alpha: NodeStyle.shadowAlpha),
    );
    canvas.drawPath(
      form.outline,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = form.mm(NodeStyle.shadowSoft)
        ..strokeJoin = StrokeJoin.round
        ..color = shadow.withValues(alpha: 0.12),
    );
    canvas.restore();
  }

  // Drawing.

  /// What the node and what is drawn beside it cover, its shadow included:
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
    return box.inflate(form.mm(NodeStyle.shadowY + NodeStyle.shadowSoft));
  }();

  /// Builds every mesh and path a frame will draw.
  void prepare() => <Object?>[
    _rimMesh,
    _afferents,
    _hilumVessels,
    _cortexBand,
    _paracortexBand,
    _mantles,
    _germs,
    _cords,
    _trabeculae,
    _sinuses,
    bounds,
  ];

  /// Draws it all, in the scene's units at the node's real size; [line] is
  /// a pixel.
  void paint(Canvas canvas, double line) {
    // What comes to it and leaves it: the afferents, and at the hilum the
    // vein, the artery and the efferent, cut short.
    _draw(canvas, _afferents);
    _draw(canvas, _hilumVessels);
    final double lit = _light.light(0, 0, 1) * NodeStyle.tubeLight;
    _end.paint(canvas, form.vein, _veinTone, lit);
    _end.paint(canvas, form.artery, _arteryTone, lit);
    _end.paint(canvas, form.efferent, _lymphTone, lit);
    // The node, cut: the medulla, the paracortex and the cortex over it,
    // the follicles in the cortex, the cords in the medulla.
    _paintShadow(canvas);
    canvas.drawPath(form.outline, Paint()..color = _medulla);
    canvas.save();
    canvas.clipPath(form.outline);
    canvas.drawPath(_paracortexBand, Paint()..color = _paracortex);
    canvas.drawPath(_cortexBand, Paint()..color = _cortex);
    canvas.drawPath(
      _cords,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = math.max(
          form.mm(NodeStyle.cord),
          NodeStyle.lineFloor * line,
        )
        ..color = _cord,
    );
    if (home == NodeHome.follicles) {
      canvas.drawPath(_mantles, Paint()..color = _home);
      canvas.drawPath(
        _germs,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = line
          ..color = inks.shadow.withValues(alpha: 0.3),
      );
    } else {
      canvas.drawPath(_mantles, Paint()..color = _mantle);
      canvas.drawPath(_germs, Paint()..color = _germinal);
    }
    _draw(canvas, _rimMesh);
    // The trabeculae, and the sinuses beside them, under the capsule and
    // between the cords.
    canvas.drawPath(
      _trabeculae,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = math.max(
          form.mm(NodeStyle.trabecula),
          NodeStyle.lineFloor * line,
        )
        ..color = inks.shadow.withValues(alpha: 0.35),
    );
    canvas.drawPath(
      _sinuses,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = math.max(
          form.mm(0.12),
          (home == NodeHome.sinuses
                  ? NodeStyle.homeSinusFloor
                  : NodeStyle.sinusFloor) *
              line,
        )
        ..color = _sinus,
    );
    canvas.restore();
    // The capsule's edge, as the other specimens'.
    canvas.drawPath(
      form.outline,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = line
        ..strokeJoin = StrokeJoin.round
        ..color = inks
            .lit(NodeStyle.edgeLit)
            .withValues(alpha: NodeStyle.edgeAlpha),
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

    add('rim', _layRim);
    add('vessels', (ColouredMesh mesh) {
      for (final TubeCourse t in form.afferents) {
        _layTube(mesh, t, _lymphTone);
      }
      _layTube(mesh, form.vein, _veinTone);
      _layTube(mesh, form.artery, _arteryTone);
      _layTube(mesh, form.efferent, _lymphTone);
    });
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
