import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../zoom_inks.dart';
import '../coloured_mesh.dart';
import '../sculpt.dart';
import '../specimen_light.dart';
import '../tube_course.dart';
import 'brain_anatomy.dart';
import 'brain_form.dart';
import 'brain_style.dart';

/// Where in the brain the zoom's cell lives, which its drawing lights in the
/// mark: the cortex, for a neuron or a glial cell of the brain; the choroid
/// plexus, for a cell of the plexus.
enum BrainHome { cortex, plexus }

/// The brain cut down its middle, drawn as a fresh specimen under the zoom's
/// one lamp, among its arteries: the medial face's gyri lit as rounded
/// ridges with a moist sheen, creased dark along their sulci; the cut faces
/// of the corpus callosum, the fornix and the brainstem flat and cushioned
/// a little, white matter bright and grey matter darker; the thalamus and
/// the hypothalamus, the third ventricle's walls, smooth domes; the
/// vermis's white arbor vitae in its grey; the arteries in the blood red,
/// dimmer than the brain.
///
/// Where the zoom's cell lives is in the mark, by its kind and never by
/// gene: for a cell of the cortex the medial face's gyri washed in it; for
/// one of the choroid plexus the septum cut away to show the lateral
/// ventricle, the plexus in it along the fornix, and the third and fourth
/// ventricles' plexus.
///
/// Everything costly is built once, for one form, one home and one set of
/// inks: meshes in the scene's units, so a frame only hands them on.
final class BrainArt {
  BrainArt(this.form, this.inks, {required this.home})
    : _light = SpecimenLight(SpecimenLamp.zoom),
      _palette = SpecimenPalette(inks);

  final BrainForm form;
  final ZoomInks inks;
  final BrainHome home;
  final SpecimenLight _light;
  final SpecimenPalette _palette;

  bool get _plexus => home == BrainHome.plexus;

  SpecimenTone _tone(Color colour) => SpecimenTone(colour, inks.shadow);

  late final SpecimenTone _faceTone = _tone(inks.lit(BrainStyle.faceLit));
  late final SpecimenTone _white = _tone(inks.lit(BrainStyle.whiteLit));
  late final SpecimenTone _grey = _tone(inks.lit(BrainStyle.greyLit));
  late final SpecimenTone _cerebellar = _tone(
    inks.lit(BrainStyle.cerebellarLit),
  );
  late final SpecimenTone _wall = _tone(inks.lit(BrainStyle.wallLit));
  late final SpecimenTone _anterior = _tone(
    inks.lit(BrainStyle.anteriorLobeLit),
  );
  late final SpecimenTone _posterior = _tone(
    inks.lit(BrainStyle.posteriorLobeLit),
  );
  late final SpecimenTone _pinealTone = _tone(inks.lit(BrainStyle.pinealLit));
  late final SpecimenTone _arteryTone = _tone(
    Color.lerp(inks.blood, inks.ground, BrainStyle.artery)!,
  );

  /// A part's tone, and how far past it its light is lifted.
  (SpecimenTone, double) _toneOf(BrainPart part) => switch (part) {
    BrainPart.callosum ||
    BrainPart.fornix ||
    BrainPart.chiasm => (_white, BrainStyle.whiteGain),
    BrainPart.brainstem => (_grey, 1),
    BrainPart.vermis => (_cerebellar, 1),
    BrainPart.thalamus ||
    BrainPart.hypothalamus ||
    BrainPart.infundibulum => (_wall, 1),
    BrainPart.pituitaryAnterior => (_anterior, 1),
    BrainPart.pituitaryPosterior => (_posterior, 1),
    BrainPart.pineal => (_pinealTone, 1),
    BrainPart.septum || BrainPart.fourthVentricle => (_grey, 1),
  };

  static final List<double> _columns = <double>[
    for (final double u in BrainStyle.columns.reversed) -u,
    ...BrainStyle.columns.skip(1),
  ];

  // The medial face.

  late final List<ui.Vertices> _face = _build(_layFace);

  void _layFace(ColouredMesh mesh) {
    final BrainSurface s = form.face;
    final double wash = home == BrainHome.cortex ? BrainStyle.cortexWash : 0;
    _layGrid(mesh, s, (int k) {
      final double nx = s.normals[3 * k];
      final double ny = s.normals[3 * k + 1];
      final double nz = s.normals[3 * k + 2];
      return _palette.colour(
        _faceTone,
        _light.light(nx, ny, nz, form: s.form[k]),
        occlusion: s.occlusion[k],
        sheen: _light.sheen(nx, ny, nz) * (1 - s.occlusion[k]),
        wash: wash,
      );
    });
  }

  // The core.

  late final Map<BrainPart, List<ui.Vertices>> _parts =
      <BrainPart, List<ui.Vertices>>{
        for (final BrainPart part in BrainForm.meshed)
          part: _build((ColouredMesh mesh) => _layPart(mesh, part)),
      };

  void _layPart(ColouredMesh mesh, BrainPart part) {
    final BrainSurface s = form.surfaceOf(part);
    final (SpecimenTone tone, double gain) = _toneOf(part);
    final double sheen = BrainForm.isWall(part) ? 1 : BrainStyle.cutSheen;
    _layGrid(mesh, s, (int k) {
      final double nx = s.normals[3 * k];
      final double ny = s.normals[3 * k + 1];
      final double nz = s.normals[3 * k + 2];
      return _palette.colour(
        tone,
        _light.light(nx, ny, nz, form: s.form[k]) * gain,
        sheen: _light.sheen(nx, ny, nz) * sheen,
      );
    });
  }

  /// A surface's grid laid in [mesh]: every point of it coloured by
  /// [colour], and a cell's two triangles where any of its corners lies in
  /// what it draws, or beside it.
  static void _layGrid(
    ColouredMesh mesh,
    BrainSurface s,
    int Function(int) colour,
  ) {
    assert(s.length <= 65000, 'a grid of ${s.length} points is too many');
    final int columns = s.columns;
    final int rows = s.rows;
    // What it draws, grown by a cell, so its clip's edge has colour under
    // it.
    final Uint8List shows = Uint8List.fromList(s.inside);
    for (int j = 0; j < rows; j++) {
      for (int i = 0; i < columns; i++) {
        if (s.inside[j * columns + i] == 0) {
          continue;
        }
        for (int dj = -1; dj <= 1; dj++) {
          for (int di = -1; di <= 1; di++) {
            final int ni = i + di;
            final int nj = j + dj;
            if (ni >= 0 && nj >= 0 && ni < columns && nj < rows) {
              shows[nj * columns + ni] = 1;
            }
          }
        }
      }
    }
    mesh.begin(s.length);
    final int first = mesh.next;
    for (int k = 0; k < s.length; k++) {
      mesh.vertex(
        s.positions[2 * k],
        s.positions[2 * k + 1],
        shows[k] == 0 ? 0 : colour(k),
      );
    }
    for (int j = 0; j + 1 < rows; j++) {
      for (int i = 0; i + 1 < columns; i++) {
        final int a = j * columns + i;
        if (shows[a] == 0 &&
            shows[a + 1] == 0 &&
            shows[a + columns] == 0 &&
            shows[a + columns + 1] == 0) {
          continue;
        }
        mesh.triangle(first + a, first + a + 1, first + a + columns);
        mesh.triangle(
          first + a + 1,
          first + a + columns + 1,
          first + a + columns,
        );
      }
    }
  }

  // The arteries.

  late final List<ui.Vertices> _faceVessels = _build((ColouredMesh mesh) {
    for (final TubeCourse tube in form.faceArteries) {
      tube.lay(
        mesh,
        _arteryTone,
        _light,
        _palette,
        _columns,
        brightness: BrainStyle.arteryLight,
      );
    }
  });
  late final List<ui.Vertices> _fossaVessels = _build((ColouredMesh mesh) {
    for (final TubeCourse tube in form.fossaArteries) {
      tube.lay(
        mesh,
        _arteryTone,
        _light,
        _palette,
        _columns,
        brightness: BrainStyle.arteryLight,
      );
    }
  });

  /// The arteries' middles, for their shadows on the face: each with its
  /// mean width.
  late final List<(Path, double)> _strands = <(Path, double)>[
    for (final TubeCourse tube in form.faceArteries)
      (tube.line, 2 * _mean(tube.radius)),
  ];

  // The window, for a cell of the choroid plexus.

  late final List<ui.Vertices> _lip = _build((ColouredMesh mesh) {
    final List<(Offset, Offset)> edge = form.windowEdge;
    if (edge.length < 3) {
      return;
    }
    final Offset toward = _light.screen;
    final Color wall = inks.lit(0.55);
    mesh.begin(2 * edge.length);
    final int first = mesh.next;
    for (final (Offset p, Offset out) in edge) {
      final double facing = out.dx * toward.dx + out.dy * toward.dy;
      final double width = form.mm(
        facing > 0 ? BrainStyle.lipShadow : BrainStyle.lipWall,
      );
      final int colour = facing > 0
          ? SpecimenPalette.packColour(
              inks.shadow,
              BrainStyle.lipShadowAlpha * facing,
            )
          : SpecimenPalette.packColour(wall, BrainStyle.lipWallAlpha * -facing);
      final Offset inner = p - out * width;
      mesh.vertex(p.dx, p.dy, colour);
      mesh.vertex(inner.dx, inner.dy, _clear(colour));
    }
    final int count = edge.length;
    for (int i = 0; i < count; i++) {
      final int a = first + 2 * i;
      final int b = first + 2 * ((i + 1) % count);
      mesh.triangle(a, b, a + 1);
      mesh.triangle(b, b + 1, a + 1);
    }
  });

  // Drawing.

  /// What the brain and its arteries cover, their shadows included: the
  /// room a layer of them needs.
  late final Rect bounds = form.outline.getBounds().inflate(
    form.mm(BrainStyle.shadowY + BrainStyle.shadowSoft),
  );

  /// Builds every mesh and path a frame will draw.
  void prepare() => <Object?>[
    _face,
    _parts,
    _faceVessels,
    _fossaVessels,
    _strands,
    form.creases,
    form.deep,
    form.arbor,
    bounds,
    if (_plexus) _lip,
  ];

  /// Draws it all, in the scene's units at the brain's real size; [line] is
  /// a pixel.
  void paint(Canvas canvas, double line) {
    _paintShadow(canvas);
    _paintFace(canvas, line);
    // What lies deep behind the core, then the core, part by part.
    canvas.drawPath(
      form.deep,
      Paint()..color = inks.shade(BrainStyle.deepShade),
    );
    canvas.drawPath(
      form.septum,
      Paint()
        ..color = Color(
          _palette.colour(_tone(inks.lit(BrainStyle.septumLit)), 0.9),
        ),
    );
    canvas.drawPath(
      form.fourthVentricle,
      Paint()..color = inks.shade(BrainStyle.cavityShade),
    );
    for (final BrainPart part in BrainForm.meshed) {
      canvas.save();
      canvas.clipPath(form.pathOf(part));
      _draw(canvas, _parts[part]!);
      canvas.restore();
    }
    _paintCoreLines(canvas, line);
    _paintCerebellum(canvas, line);
    if (_plexus) {
      _paintWindow(canvas, line);
      _beads(canvas, form.thirdPlexus, line);
      _beads(canvas, form.fourthPlexus, line);
    }
    _draw(canvas, _fossaVessels);
  }

  void _paintShadow(Canvas canvas) {
    canvas.save();
    canvas.translate(form.mm(BrainStyle.shadowX), form.mm(BrainStyle.shadowY));
    final Color shadow = inks.shadow;
    canvas.drawPath(
      form.outline,
      Paint()..color = shadow.withValues(alpha: BrainStyle.shadowAlpha),
    );
    canvas.drawPath(
      form.outline,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = form.mm(BrainStyle.shadowSoft)
        ..strokeJoin = StrokeJoin.round
        ..color = shadow.withValues(alpha: 0.12),
    );
    canvas.restore();
  }

  /// The medial face, rolling away at its edge, creased along its sulci,
  /// and its arteries on it with their shadows, ending at its edge where
  /// they go on over it.
  void _paintFace(Canvas canvas, double line) {
    canvas.save();
    canvas.clipPath(form.hemisphere);
    _draw(canvas, _face);
    final (Path major, Path minor) = form.creases;
    final Color cleft = inks.shadow.withValues(alpha: BrainStyle.creaseAlpha);
    canvas.drawPath(major, Paint()..color = cleft);
    canvas.drawPath(minor, Paint()..color = cleft);
    // Never thinner than a pixel or so.
    final double floor = BrainStyle.creaseFloor * line;
    if (form.mm(BrainStyle.minorCrease) < floor) {
      final Paint thin = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = floor - form.mm(BrainStyle.minorCrease)
        ..strokeJoin = StrokeJoin.round
        ..color = cleft;
      canvas.drawPath(minor, thin);
      if (form.mm(BrainStyle.crease) < floor) {
        canvas.drawPath(
          major,
          thin..strokeWidth = floor - form.mm(BrainStyle.crease),
        );
      }
    }
    canvas.save();
    canvas.translate(form.mm(0.5), form.mm(0.8));
    for (final (Path strand, double width) in _strands) {
      canvas.drawPath(
        strand,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = width
          ..strokeCap = StrokeCap.round
          ..color = inks.shadow.withValues(alpha: 0.3),
      );
    }
    canvas.restore();
    _draw(canvas, _faceVessels);
    canvas.restore();
    canvas.drawPath(
      form.hemisphere,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = line
        ..strokeJoin = StrokeJoin.round
        ..color = inks.lit(0.42).withValues(alpha: 0.45),
    );
    Sculpt.rim(
      canvas,
      form.hemisphere,
      form.hemisphere.getBounds(),
      inks,
      width: 1.6 * line,
      strength: 0.35,
    );
  }

  /// The cut's own lines over the core's parts: each part's edge, the
  /// small parts, the aqueduct, where the pons begins and ends.
  void _paintCoreLines(Canvas canvas, double line) {
    final double edge = math.max(BrainStyle.edgeLine * line, form.mm(0.1));
    final Paint stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = edge
      ..strokeJoin = StrokeJoin.round
      ..color = inks.shadow.withValues(alpha: 0.4);
    for (final BrainPart part in BrainForm.meshed) {
      canvas.drawPath(form.pathOf(part), stroke);
    }
    canvas.drawPath(form.septum, stroke);
    canvas.drawPath(
      form.fourthVentricle,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = edge
        ..color = inks.shadow.withValues(alpha: 0.55),
    );
    canvas.drawPath(
      form.aqueduct,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(form.mm(2 * BrainAnatomy.aqueductHalf), line)
        ..strokeCap = StrokeCap.round
        ..color = inks.shade(BrainStyle.cavityShade),
    );
    for (final Path seam in <Path>[form.ponsTop, form.ponsFoot]) {
      canvas.drawPath(
        seam,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = edge
          ..color = inks.shadow.withValues(alpha: 0.2),
      );
    }
    // The commissures, white; the adhesion, cut grey; the mammillary body.
    final Color white = Color(_palette.colour(_white, 1.3));
    for (final Rect commissure in <Rect>[
      form.anteriorCommissure,
      form.posteriorCommissure,
    ]) {
      canvas.drawOval(commissure, Paint()..color = white);
      canvas.drawOval(commissure, stroke);
    }
    canvas.drawOval(
      form.adhesion,
      Paint()..color = Color(_palette.colour(_grey, 0.95)),
    );
    canvas.drawOval(form.adhesion, stroke);
    canvas.drawOval(
      form.mammillary,
      Paint()
        ..shader = RadialGradient(
          center: Sculpt.highlight,
          colors: <Color>[
            Color(_palette.colour(_wall, 1.15)),
            Color(_palette.colour(_wall, 0.55)),
          ],
        ).createShader(form.mammillary),
    );
    canvas.drawOval(form.mammillary, stroke);
  }

  /// The vermis's arbor vitae, white in its grey, and its fissures.
  void _paintCerebellum(Canvas canvas, double line) {
    final (:Path white, :Path fissures, :Path folia, outline: _) = form.arbor;
    canvas.save();
    canvas.clipPath(form.vermis);
    canvas.drawPath(
      white,
      Paint()..color = Color(_palette.colour(_white, 1.05)),
    );
    canvas.drawPath(
      fissures,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(BrainStyle.fissureLine * line, form.mm(0.4))
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = inks.shadow.withValues(alpha: 0.7),
    );
    canvas.drawPath(
      folia,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(0.8 * line, form.mm(0.25))
        ..strokeCap = StrokeCap.round
        ..color = inks.shadow.withValues(alpha: 0.55),
    );
    canvas.restore();
  }

  /// The septum cut away: the lateral ventricle's dark, the caudate's
  /// light on its far wall, the plexus along the fornix in the mark, and
  /// the cut's own edge.
  void _paintWindow(Canvas canvas, double line) {
    final Path window = form.window;
    canvas.save();
    canvas.clipPath(window);
    canvas.drawPath(
      window,
      Paint()..color = inks.shade(BrainStyle.ventricleShade),
    );
    final Rect caudate = Rect.fromCircle(
      center: form.place(const Offset(-12, -13)),
      radius: form.mm(11),
    );
    canvas.drawOval(
      caudate,
      Paint()
        ..shader = RadialGradient(
          center: Sculpt.highlight,
          colors: <Color>[
            inks.lit(BrainStyle.caudateLit).withValues(alpha: 0.75),
            inks.lit(BrainStyle.caudateLit).withValues(alpha: 0),
          ],
        ).createShader(caudate),
    );
    _beads(canvas, form.lateralPlexus, line);
    _draw(canvas, _lip);
    canvas.restore();
    canvas.drawPath(
      window,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = line
        ..color = inks.lit(0.5).withValues(alpha: 0.6),
    );
  }

  /// [beads] of the plexus in the mark, each a core in a halo, never less
  /// than a pixel or so across.
  void _beads(Canvas canvas, List<(Offset, double)> beads, double line) {
    final Paint paint = Paint()..color = inks.glow(BrainStyle.haloAlpha);
    for (final (Offset at, double r) in beads) {
      canvas.drawCircle(
        at,
        math.max(BrainStyle.halo * r, BrainStyle.haloFloor * line / 2),
        paint,
      );
    }
    paint.color = inks.glow(0.95);
    for (final (Offset at, double r) in beads) {
      canvas.drawCircle(
        at,
        math.max(r, BrainStyle.coreFloor * line / 2),
        paint,
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

    add('face', _layFace);
    for (final BrainPart part in BrainForm.meshed) {
      add(part.name, (ColouredMesh mesh) => _layPart(mesh, part));
    }
    add('vessels', (ColouredMesh mesh) {
      for (final TubeCourse tube in <TubeCourse>[
        ...form.faceArteries,
        ...form.fossaArteries,
      ]) {
        tube.lay(mesh, _arteryTone, _light, _palette, _columns);
      }
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

double _mean(Float64List values) {
  double sum = 0;
  for (final double v in values) {
    sum += v;
  }
  return values.isEmpty ? 0 : sum / values.length;
}

int _clear(int colour) => colour & ((1 << 24) - 1);
