import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../zoom_inks.dart';
import '../coloured_mesh.dart';
import '../sculpt.dart';
import '../zoom_scene.dart';
import 'chromosome_form.dart';
import 'chromosome_shading.dart';
import 'chromosome_style.dart';

/// A chromosome at rest, its form a scanning micrograph's and its surface
/// lit as the zoom's organs are, under the same lamp: two sisters, knobbly
/// with opaque lobes of chromatin, each lobe lit from the upper left with a
/// moist sheen and dark in the crevices round it, each sister darker toward
/// its edges and along the groove where they touch, a shadow under them, the
/// bands soft changes of tone, the centromere's waist and its two
/// kinetochores tinted in its ink and every chromatid's ends in the
/// telomeres', and the gene as two FISH spots, one on each sister.
///
/// In a look of globules, the vivid (the user's ask of 2026-10-23), its
/// relief is globules instead, each of one material, in a ramp of its own:
/// spheres drawn from the back of the tube to its front, each over a
/// crevice that falls away from the light and under a highlight of its own;
/// the arms blue, the centromere's neck coral and the caps gold, the
/// chromatin round the spots teal and lit by their glow, which brightens
/// what lies under it; the bodies under both sisters' globules, a cleft dark
/// between the sisters, a blurred shadow, and a micrograph's fine grain.
///
/// Everything costly is built once, for one form in one set of inks: the
/// body and its relief are meshes in the scene's units, so a frame only
/// hands them on, at any magnification. The form's look tunes it.
final class ChromosomeArt {
  ChromosomeArt(this.form, this.inks)
    : _light = ChromosomeLight(look: form.look),
      _palette = ChromosomePalette(inks, look: form.look);

  final ChromosomeForm form;
  final ZoomInks inks;
  final ChromosomeLight _light;
  final ChromosomePalette _palette;

  double get _half => form.half;

  ChromosomeLookSpec get _look => form.look;

  /// Each sister's body, its lobes and its kinetochore, left then right; in
  /// a look of globules its globules alone.
  late final List<List<ui.Vertices>> _sisters = <List<ui.Vertices>>[
    _sister(-1),
    _sister(1),
  ];

  /// In a look of globules, each sister's body, left then right: drawn under
  /// both sisters' globules, so where the sisters meet at the waist neither
  /// one's body lies over the other's globules. None in a look of lobes.
  late final List<List<ui.Vertices>> _bodies = <List<ui.Vertices>>[
    if (_look.globules != null) ...<List<ui.Vertices>>[_body(-1), _body(1)],
  ];

  /// Each sister's granules, left then right.
  late final List<List<ui.Vertices>> _granules = <List<ui.Vertices>>[
    _grains(-1),
    _grains(1),
  ];

  /// Each sister's outline, for its shadow and its coat.
  late final List<Path> _outlines = <Path>[
    form.chromatid(-1).toPath(),
    form.chromatid(1).toPath(),
  ];

  /// In a look of globules, the shade down each sister's side facing the
  /// other, left then right: the cleft between them. None in a look of
  /// lobes, whose sisters touch along a groove.
  late final List<ui.Vertices> _clefts = <ui.Vertices>[
    if (_look.globules case final ChromosomeGlobules globules) ...<ui.Vertices>[
      _cleftOf(-1, globules),
      _cleftOf(1, globules),
    ],
  ];

  /// The gene's two spots at rest, left then right: what the gene's
  /// chromatin is measured from, in a look of globules.
  late final List<Offset> _spots = <Offset>[form.fish(-1), form.fish(1)];

  /// In a look of globules with a grain, its tile: a square of fine noise,
  /// the same every time, drawn once; null otherwise.
  late final ui.Image? _grain = () {
    final ChromosomeGlobules? globules = _look.globules;
    if (globules == null || globules.grain <= 0) {
      return null;
    }
    const int size = 64;
    final math.Random random = math.Random(64);
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder);
    final Paint texel = Paint();
    for (int y = 0; y < size; y++) {
      for (int x = 0; x < size; x++) {
        final double v = random.nextDouble();
        texel.color = Color.lerp(inks.shadow, inks.text, v)!;
        canvas.drawRect(Rect.fromLTWH(x.toDouble(), y.toDouble(), 1, 1), texel);
      }
    }
    final ui.Picture picture = recorder.endRecording();
    final ui.Image image = picture.toImageSync(size, size);
    picture.dispose();
    return image;
  }();

  /// The groove where the sisters touch: the right sister's inner edge, the
  /// one drawn over the other, darkest where the arms meet at the waist.
  late final Path _seam = () {
    final Path path = Path();
    final Float64List rows = form.bodyRows;
    for (int i = 0; i < rows.length; i++) {
      final double y = rows[i];
      final double x = form.centreAt(1, y) - form.widthAt(y);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    return path;
  }();

  late final Rect _seamBox = _seam.getBounds().inflate(_half);

  late final Shader _seamShade = () {
    const int stops = 33;
    final double top = form.top;
    final double length = form.bottom - top;
    final List<double> at = <double>[];
    final List<Color> colours = <Color>[];
    for (int i = 0; i < stops; i++) {
      final double t = i / (stops - 1);
      final double y = top + length * t;
      final double d = ((y - form.centromere).abs() - _half) / (0.8 * _half);
      final double crotch = math.exp(-d * d);
      at.add(t);
      colours.add(
        inks.shadow.withValues(
          alpha: (form.contact(y) * (0.45 + 0.55 * crotch)).clamp(0.0, 1.0),
        ),
      );
    }
    return LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: colours,
      stops: at,
    ).createShader(
      Rect.fromLTRB(_seamBox.left, top, _seamBox.right, top + length),
    );
  }();

  /// What the chromosome at rest covers, its shadow and its relief included,
  /// in the scene's units: the room a layer of it needs.
  late final Rect bounds = _outlines[0]
      .getBounds()
      .expandToInclude(_outlines[1].getBounds())
      .inflate(_look.boundsInflate * _half);

  /// The body's colour averaged over its area on both sisters, lit as it
  /// is, the gene's wash and the centromere's and telomeres' tints left out:
  /// what the territory's mark gives way to as the chromosome condenses out
  /// of it.
  late final Color meanTone = () {
    final Float64List rows = form.bodyRows;
    final List<double> columns = _columns;
    double r = 0;
    double g = 0;
    double b = 0;
    double total = 0;
    for (final double side in <double>[-1, 1]) {
      for (int i = 0; i + 1 < rows.length; i++) {
        final double y = (rows[i] + rows[i + 1]) / 2;
        final double w = form.widthAt(y);
        final double slope = form.slope(y);
        final double tone = form.toneAt(y);
        for (int j = 0; j + 1 < columns.length; j++) {
          final double u = (columns[j] + columns[j + 1]) / 2;
          final double area =
              (rows[i + 1] - rows[i]) * w * (columns[j + 1] - columns[j]);
          final SurfaceNormal n = SurfaceNormal(
            u,
            -slope,
            math.sqrt(math.max(0, 1 - u * u)),
          );
          final _Lit s = _surface(side, y, u, n.x, n.y, n.z, facing: n.z);
          final (double, double, double) mix = _palette.mix(
            tone,
            s.light,
            s.occlusion,
            0,
            sheen: s.sheen,
          );
          r += mix.$1 * area;
          g += mix.$2 * area;
          b += mix.$3 * area;
          total += area;
        }
      }
    }
    return total <= 0
        ? inks.lit(_look.paleLit)
        : Color.from(
            alpha: 1,
            red: r / total,
            green: g / total,
            blue: b / total,
          );
  }();

  /// Builds every mesh now rather than at the first frame.
  void prepare() => <Object?>[
    _sisters,
    _bodies,
    _granules,
    _outlines,
    _clefts,
    _grain,
    _seamShade,
    bounds,
    meanTone,
  ];

  /// The chromosome at rest, without its spots. On its way into the band's
  /// map, each sister is moved [merge] of the way onto the axis at the
  /// band's height and thinned [thin] of the way to [target] half-width
  /// there, as the tube under it is: its shadow, its coat and the groove
  /// go with it.
  void paintRest(
    Canvas canvas,
    ZoomFrame frame, {
    double merge = 0,
    double thin = 0,
    double target = 0,
  }) {
    final double pixel = frame.pixel;
    final bool still = merge == 0 && thin == 0;
    // [draw] for sister [i], moved with it.
    void sister(int i, void Function() draw) {
      if (still) {
        draw();
        return;
      }
      canvas.save();
      _toward(canvas, i == 0 ? -1 : 1, merge, thin, target);
      draw();
      canvas.restore();
    }

    // The shadow the sisters cast, under them and to the lower right, as the
    // organs cast theirs. Nothing else lies round them.
    final ChromosomeGlobules? globules = _look.globules;
    canvas.save();
    canvas.translate(_look.shadowX * _half, _look.shadowY * _half);
    for (int i = 0; i < 2; i++) {
      sister(i, () {
        if (globules != null) {
          // Blurred, its sigma in the scene's units, so it is as soft at
          // any magnification.
          canvas.drawPath(
            _outlines[i],
            Paint()
              ..color = inks.shadow.withValues(alpha: _look.shadowAlpha)
              ..maskFilter = MaskFilter.blur(
                BlurStyle.normal,
                globules.shadowBlur * _half,
              ),
          );
          return;
        }
        canvas.drawPath(
          _outlines[i],
          Paint()..color = inks.shadow.withValues(alpha: _look.shadowAlpha),
        );
        canvas.drawPath(
          _outlines[i],
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = _look.shadowSoft * _half
            ..strokeJoin = StrokeJoin.round
            ..color = inks.shadow.withValues(alpha: 0.12),
        );
      });
    }
    canvas.restore();
    final Paint mesh = Paint();
    if (globules != null) {
      for (int i = 0; i < 2; i++) {
        sister(i, () {
          for (final ui.Vertices vertices in _bodies[i]) {
            canvas.drawVertices(vertices, BlendMode.dst, mesh);
          }
        });
      }
    }
    for (int i = 0; i < 2; i++) {
      sister(i, () {
        for (final ui.Vertices vertices in _sisters[i]) {
          canvas.drawVertices(vertices, BlendMode.dst, mesh);
        }
        for (final ui.Vertices vertices in _granules[i]) {
          canvas.drawVertices(vertices, BlendMode.dst, mesh);
        }
      });
    }
    if (globules != null) {
      // The cleft, down each sister's side facing the other.
      for (int i = 0; i < 2; i++) {
        sister(i, () => canvas.drawVertices(_clefts[i], BlendMode.dst, mesh));
      }
      // A micrograph's fine grain over the chromatin, in the scene's units,
      // so it grows with the chromosome.
      if (_grain case final ui.Image grain) {
        final double texel = globules.grainTile * _half / grain.width;
        final Paint fine = Paint()
          ..blendMode = BlendMode.overlay
          ..color = Color.fromRGBO(0, 0, 0, globules.grain)
          ..shader = ImageShader(
            grain,
            TileMode.repeated,
            TileMode.repeated,
            Matrix4.diagonal3Values(texel, texel, 1).storage,
          );
        for (int i = 0; i < 2; i++) {
          sister(i, () => canvas.drawPath(_outlines[i], fine));
        }
      }
      return;
    }
    // The groove, soft and then sharp: the right sister's facing side.
    sister(1, () {
      canvas.drawPath(
        _seam,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5 * pixel
          ..strokeCap = StrokeCap.round
          ..shader = _seamShade
          ..color = inks.shadow.withValues(alpha: 0.3),
      );
      canvas.drawPath(
        _seam,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(1.2 * pixel, 0.07 * _half)
          ..strokeCap = StrokeCap.round
          ..shader = _seamShade,
      );
    });
  }

  /// Moves [canvas] so that sister [side] is drawn [merge] of the way onto
  /// the axis at the band's height and [thin] of the way to [target]
  /// half-width there, about its own middle.
  void _toward(
    Canvas canvas,
    double side,
    double merge,
    double thin,
    double target,
  ) {
    final double y = form.bandY;
    final double from = form.centreAt(side, y);
    final double w = form.widthAt(y);
    canvas.translate(form.centreAt(side, y, merge: merge), 0);
    canvas.scale(w <= 0 ? 1 : (w + (target - w) * thin) / w, 1);
    canvas.translate(-from, 0);
  }

  /// The spots' core: the mark lightened toward the bright ink.
  late final Color _core = Color.lerp(inks.mark, inks.text, 0.55)!;

  /// The gene's two FISH spots, one on each sister at its height: a core of
  /// the mark lightened toward the bright ink, in its glow.
  void paintSpots(Canvas canvas, {double opacity = 1, double merge = 0}) {
    if (opacity <= 0.002) {
      return;
    }
    final double r = form.fishRadius;
    for (final double side in <double>[-1, 1]) {
      paintSpot(
        canvas,
        form.fish(side, merge: merge),
        r,
        _look.fishGlow * r,
        0.38 * opacity,
        opacity,
      );
    }
  }

  /// One FISH spot at [at]: its core [radius] across, at [opacity], in a
  /// glow of the mark [reach] out and [glow] at its heart. In a look of
  /// globules it is the look's own spot, [own] of the way; the rest of the
  /// way the mark's, as the band's map marks the gene, which it eases into
  /// on the way there.
  void paintSpot(
    Canvas canvas,
    Offset at,
    double radius,
    double reach,
    double glow,
    double opacity, {
    double own = 1,
  }) {
    final ChromosomeGlobules? globules = _look.globules;
    if (globules == null) {
      _markSpot(canvas, at, radius, reach, glow, opacity);
      return;
    }
    if (own < 1) {
      _markSpot(
        canvas,
        at,
        radius,
        reach,
        glow * (1 - own),
        opacity * (1 - own),
      );
    }
    if (own > 0) {
      _ownSpot(canvas, at, radius, reach, opacity * own, globules);
    }
  }

  /// A FISH spot in the mark.
  void _markSpot(
    Canvas canvas,
    Offset at,
    double radius,
    double reach,
    double glow,
    double opacity,
  ) {
    Sculpt.glow(canvas, at, reach, inks, glow);
    final Rect box = Rect.fromCircle(center: at, radius: radius);
    canvas.drawOval(
      box,
      Paint()
        ..shader = RadialGradient(
          colors: <Color>[
            _core.withValues(alpha: opacity),
            inks.glow(0.95 * opacity),
            inks.glow(0.35 * opacity),
            inks.glow(0),
          ],
          stops: const <double>[0, 0.42, 0.75, 1],
        ).createShader(box),
    );
  }

  /// A FISH spot in a look of globules' own colours: a glow of the gene's
  /// cyan [reach] out, added to the light of what lies under it, and a core
  /// [radius] across, all but white at its heart.
  void _ownSpot(
    Canvas canvas,
    Offset at,
    double radius,
    double reach,
    double opacity,
    ChromosomeGlobules globules,
  ) {
    if (opacity <= 0.002) {
      return;
    }
    final Color cyan = globules.colours.gene.highlight;
    final double heart = globules.spotGlow * opacity;
    final Rect area = Rect.fromCircle(center: at, radius: reach);
    canvas.drawOval(
      area,
      Paint()
        ..blendMode = BlendMode.plus
        ..shader = RadialGradient(
          colors: <Color>[
            cyan.withValues(alpha: heart),
            cyan.withValues(alpha: heart * 0.32),
            cyan.withValues(alpha: 0),
          ],
          stops: const <double>[0, 0.42, 1],
        ).createShader(area),
    );
    final Rect box = Rect.fromCircle(center: at, radius: radius);
    canvas.drawOval(
      box,
      Paint()
        ..shader = RadialGradient(
          colors: <Color>[
            globules.colours.glowCore.withValues(alpha: opacity),
            cyan.withValues(alpha: opacity),
            cyan.withValues(alpha: globules.spotFadeAlpha * opacity),
            cyan.withValues(alpha: 0),
          ],
          stops: <double>[0, globules.spotCore, globules.spotFade, 1],
        ).createShader(box),
    );
  }

  /// The spots flaring as the chromosome is reached, [t] of the way through
  /// the beat: nothing before it starts or after it ends.
  void paintFlare(Canvas canvas, ZoomFrame frame, double t, double opacity) {
    if (t <= 0 || t >= 1 || opacity <= 0) {
      return;
    }
    final double r = form.fishRadius;
    final double out = Curves.easeOutCubic.transform(t);
    for (final double side in <double>[-1, 1]) {
      final Offset at = form.fish(side);
      Sculpt.glow(
        canvas,
        at,
        r * (1.2 + 1.6 * out),
        inks,
        0.5 * math.sin(math.pi * t) * opacity,
      );
      Sculpt.ping(
        canvas,
        at,
        r,
        r * 1.6,
        t,
        frame.pixel,
        inks,
        opacity: opacity,
      );
    }
  }

  // The meshes.

  /// How a surface facing (nx, ny, nz) at [y], [u] of the way across the
  /// tube (the sine of its angle round it), on chromatid [side], is lit,
  /// where the sister's own face turns [facing] of the way toward the eye:
  /// its light, the shade of the groove where it is turned to its sister,
  /// and its sheen.
  _Lit _surface(
    double side,
    double y,
    double u,
    double nx,
    double ny,
    double nz, {
    required double facing,
  }) {
    final double turned = _smoothstep(0.3, 1, -side * u);
    return (
      light: _light.light(nx, ny, nz, facing: facing),
      occlusion: _look.occlusion * turned * form.contact(y),
      sheen: _light.sheen(nx, ny, nz),
    );
  }

  /// How far the chromatin at [y] is tinted toward the centromere's ink and
  /// toward the telomeres'.
  ({double centromere, double telomere}) _tints(double y) => (
    centromere: _look.centromereTint * form.centromereAt(y),
    telomere: _look.telomereTint * form.telomereAt(y),
  );

  /// How far across the tube each of the body's columns lies, from one
  /// edge to the other: the sine of its angle round it.
  late final List<double> _columns = <double>[
    for (final double u in _look.columns.reversed) -u,
    ..._look.columns.skip(1),
  ];

  /// Every mesh's vertices as built, for tests: where each lies, in the
  /// scene's units, and its colour.
  @visibleForTesting
  List<({Float32List positions, Int32List colours})> get meshData {
    final List<({Float32List positions, Int32List colours})> out =
        <({Float32List positions, Int32List colours})>[];
    for (final double side in <double>[-1, 1]) {
      for (final void Function(ColouredMesh, double) lay
          in <void Function(ColouredMesh, double)>[_laySister, _layGrains]) {
        final ColouredMesh mesh = ColouredMesh(keep: true);
        lay(mesh, side);
        mesh.build();
        out.addAll(mesh.kept);
      }
    }
    return out;
  }

  /// In a look of globules, every globule and granule of chromatid [side]
  /// as it is drawn, for tests: where its middle lies, its radius, and what
  /// it is made of. None in a look of lobes.
  @visibleForTesting
  List<({Offset at, double radius, ChromatinMaterial material})> globulesOf(
    double side,
  ) {
    final ChromosomeGlobules? globules = _look.globules;
    if (globules == null) {
      return const <({Offset at, double radius, ChromatinMaterial material})>[];
    }
    final KnobField knobs = form.knobs(side);
    return <({Offset at, double radius, ChromatinMaterial material})>[
      for (int k = 0; k < knobs.length; k++)
        if (knobs.kind[k] != KnobField.pit)
          if (_globule(side, knobs, k, globules) case final _Globule g)
            (at: Offset(g.x, g.y), radius: g.r, material: g.material),
    ];
  }

  List<ui.Vertices> _sister(double side) {
    final ColouredMesh mesh = ColouredMesh();
    if (_look.globules == null) {
      _laySister(mesh, side);
    } else {
      _layKnobs(mesh, side);
    }
    return mesh.build();
  }

  List<ui.Vertices> _body(double side) {
    final ColouredMesh mesh = ColouredMesh();
    _layBody(mesh, side);
    return mesh.build();
  }

  /// Sister [side]'s body, and over it its relief.
  void _laySister(ColouredMesh mesh, double side) {
    _layBody(mesh, side);
    _layKnobs(mesh, side);
  }

  void _layBody(ColouredMesh mesh, double side) {
    final ChromosomeGlobules? globules = _look.globules;
    final Float64List rows = form.bodyRows;
    final List<double> columns = _columns;
    final int across = columns.length;
    // The body: a sheet of rows across the tube, lit vertex by vertex; in a
    // look of globules a narrower tube, in their crevices' shade, that shows
    // only between them.
    mesh.begin(rows.length * across);
    final int first = mesh.next;
    for (final double y in rows) {
      final double w = globules == null
          ? form.widthAt(y)
          : globules.bodyWidth * form.widthAt(y);
      final double centre = form.centreAt(side, y);
      final double bow = form.bowAt(y);
      final double slope = form.slope(y);
      final double tone = form.toneAt(y);
      final double gene = form.geneAt(y);
      final ({double centromere, double telomere}) tint = _tints(y);
      for (final double u in columns) {
        final double nz = math.sqrt(math.max(0, 1 - u * u));
        final SurfaceNormal n = SurfaceNormal(u, -slope, nz);
        final _Lit s = _surface(side, y, u, n.x, n.y, n.z, facing: n.z);
        final double x = centre + w * u;
        mesh.vertex(
          x,
          y + bow * u * u,
          globules == null
              ? _palette.colour(
                  tone,
                  s.light,
                  s.occlusion,
                  gene,
                  1,
                  centromere: tint.centromere,
                  telomere: tint.telomere,
                  sheen: s.sheen,
                )
              : _palette.colour(
                  tone,
                  s.light,
                  s.occlusion + (1 - s.occlusion) * globules.bodyOcclusion,
                  _geneWeight(x, y, globules),
                  1,
                  centromere: tint.centromere,
                  telomere: tint.telomere,
                  sheen: s.sheen,
                ),
        );
      }
    }
    for (int i = 0; i + 1 < rows.length; i++) {
      for (int j = 0; j + 1 < across; j++) {
        final int a = first + i * across + j;
        final int b = a + 1;
        final int c = a + across;
        final int d = c + 1;
        mesh.triangle(a, b, c);
        mesh.triangle(b, d, c);
      }
    }
  }

  void _layKnobs(ColouredMesh mesh, double side) {
    final ChromosomeGlobules? globules = _look.globules;
    final KnobField knobs = form.knobs(side);
    if (globules != null) {
      // The globules, from the back of the tube to its front, each over its
      // crevice and under its highlight. There are no kinetochore plates:
      // the coral neck is the centromere.
      for (final int k in _order(knobs, globules)) {
        final _Globule p = _globule(side, knobs, k, globules);
        if (knobs.kind[k] == KnobField.bump) {
          _sphere(mesh, side, p, globules.granuleRing, globules);
          continue;
        }
        if (!p.deep) {
          _creviceOf(mesh, p, globules);
        }
        _sphere(mesh, side, p, _ringFor(p.r, globules), globules);
        if (!p.deep) {
          _highlightOf(mesh, p, globules);
        }
      }
      return;
    }
    // The lobes, each over the crevice round it: a lobe laid after another
    // shades it where the two meet, as a crevice between them would.
    for (int k = 0; k < knobs.length; k++) {
      if (knobs.kind[k] == KnobField.lobe) {
        _skirt(mesh, side, knobs, k);
        _dome(mesh, side, knobs, k);
      }
    }
    _plate(mesh, side);
  }

  /// Where knob [k] lies on screen, its surface's normal there, and the
  /// two axes of the ellipse it is seen as: a disc on the surface, squashed
  /// along the way the surface turns from the eye.
  _Knob _place(double side, KnobField knobs, int k) {
    final double y = knobs.y[k];
    final double phi = knobs.phi[k];
    final double u = math.sin(phi);
    final double r = knobs.radius[k];
    final SurfaceNormal n = SurfaceNormal(u, -form.slope(y), math.cos(phi));
    final double flat = math.sqrt(n.x * n.x + n.y * n.y);
    final double dx = flat < 1e-6 ? 1 : n.x / flat;
    final double dy = flat < 1e-6 ? 0 : n.y / flat;
    final double squash = math.max(n.z, 0.45);
    return _Knob(
      x: form.centreAt(side, y) + form.widthAt(y) * u,
      y: y + form.bowAt(y) * u * u,
      normal: n,
      // The squashed axis, along the turn, and the full one across it.
      ax: dx * r * squash,
      ay: dy * r * squash,
      bx: -dy * r,
      by: dx * r,
    );
  }

  void _skirt(ColouredMesh mesh, double side, KnobField knobs, int k) =>
      _skirtOf(mesh, _place(side, knobs, k));

  /// The crevice round [p]: shade falling away from its edge.
  void _skirtOf(ColouredMesh mesh, _Knob p) {
    const int ring = 12;
    mesh.begin(ring * 2);
    final int first = mesh.next;
    final int dark = _palette.shadow(_look.skirtAlpha);
    final int clear = _palette.shadow(0);
    for (final (double scale, int colour) in <(double, int)>[
      (_look.skirtInner, dark),
      (_look.skirtOuter, clear),
    ]) {
      for (int i = 0; i < ring; i++) {
        final Offset at = p.at(2 * math.pi * i / ring, scale);
        mesh.vertex(at.dx, at.dy, colour);
      }
    }
    for (int i = 0; i < ring; i++) {
      final int a = first + i;
      final int b = first + (i + 1) % ring;
      mesh.triangle(a, b, a + ring);
      mesh.triangle(b, b + ring, a + ring);
    }
  }

  void _dome(ColouredMesh mesh, double side, KnobField knobs, int k) {
    final double y = knobs.y[k];
    _domeOf(
      mesh,
      side,
      _place(side, knobs, k),
      y,
      math.sin(knobs.phi[k]),
      knobs.radius[k],
      form.geneAt(y),
      _tints(y),
    );
  }

  /// [p] as a small opaque dome at [y], [u] of the way across the tube and
  /// [r] across: lit as the surface under it is, its rim tilted out from its
  /// top, so it is lit on the side toward the light and in shade on the
  /// other, with its sheen between, [gene] of the way into the gene's band
  /// and tinted by [tint].
  void _domeOf(
    ColouredMesh mesh,
    double side,
    _Knob p,
    double y,
    double u,
    double r,
    double gene,
    ({double centromere, double telomere}) tint,
  ) {
    const int ring = 14;
    final double tone = form.toneAt(y);
    final SurfaceNormal base = p.normal;
    _Lit lit(double tilt, double a) {
      // The ring's normal, tilted out from the dome's top toward [a].
      final Offset out = p.at(a, 1) - Offset(p.x, p.y);
      final double length = out.distance;
      final SurfaceNormal n = length < 1e-12
          ? base
          : SurfaceNormal(
              base.x + tilt * out.dx / length,
              base.y + tilt * out.dy / length,
              base.z,
            );
      // Darker toward the sister's edges, as the surface under it is.
      return _surface(side, y, u, n.x, n.y, n.z, facing: base.z);
    }

    mesh.begin(1 + ring * 3);
    final int centre = mesh.next;
    final _Lit top = lit(0, 0);
    mesh.vertex(
      p.x + _light.screen.dx * 0.22 * r,
      p.y + _light.screen.dy * 0.22 * r,
      _palette.colour(
        tone,
        top.light,
        top.occlusion,
        gene,
        1,
        centromere: tint.centromere,
        telomere: tint.telomere,
        sheen: top.sheen,
      ),
    );
    final List<int> rim = <int>[];
    for (final (double scale, double tilt) in <(double, double)>[
      (0.62, 0.4 * _look.lobeTilt),
      (1, _look.lobeTilt),
    ]) {
      for (int i = 0; i < ring; i++) {
        final double a = 2 * math.pi * i / ring;
        final _Lit s = lit(tilt, a);
        final int colour = _palette.colour(
          tone,
          s.light,
          s.occlusion,
          gene,
          1,
          centromere: tint.centromere,
          telomere: tint.telomere,
          sheen: s.sheen,
        );
        if (scale == 1) {
          rim.add(colour);
        }
        final Offset at = p.at(a, scale);
        mesh.vertex(at.dx, at.dy, colour);
      }
    }
    for (int i = 0; i < ring; i++) {
      final Offset at = p.at(2 * math.pi * i / ring, 1.25);
      mesh.vertex(at.dx, at.dy, _clear(rim[i]));
    }
    for (int i = 0; i < ring; i++) {
      final int a = centre + 1 + i;
      final int b = centre + 1 + (i + 1) % ring;
      mesh.triangle(centre, a, b);
      for (int band = 0; band < 2; band++) {
        final int a0 = a + band * ring;
        final int b0 = b + band * ring;
        mesh.triangle(a0, b0, a0 + ring);
        mesh.triangle(b0, b0 + ring, a0 + ring);
      }
    }
  }

  /// The kinetochore: a small plate on the sister's outer face at the
  /// waist, in the centromere's ink, seated in a crevice of its own and lit
  /// as a lobe is.
  void _plate(ColouredMesh mesh, double side) {
    final Offset at = form.kinetochore(side);
    final double rx = _look.plateX * _half;
    final double ry = _look.plateY * _half;
    final double u = side * _look.plateOut;
    final _Knob plate = _Knob(
      x: at.dx,
      y: at.dy,
      normal: SurfaceNormal(u, 0, math.sqrt(1 - u * u)),
      ax: rx,
      ay: 0,
      bx: 0,
      by: ry,
    );
    _skirtOf(mesh, plate);
    _domeOf(mesh, side, plate, form.centromere, u, rx, 0, (
      centromere: _look.kinetochoreTint,
      telomere: 0,
    ));
  }

  // A look of globules.

  /// How much of the gene's chromatin is at ([x], [y]): all of it at either
  /// FISH spot, falling to none [ChromosomeGlobules.geneReach] from the
  /// nearer.
  double _geneWeight(double x, double y, ChromosomeGlobules globules) {
    double nearest = double.infinity;
    for (final Offset spot in _spots) {
      final double dx = x - spot.dx;
      final double dy = y - spot.dy;
      nearest = math.min(nearest, dx * dx + dy * dy);
    }
    final double t = (math.sqrt(nearest) / (globules.geneReach * _half)).clamp(
      0.0,
      1.0,
    );
    return 1 - t * t * (3 - 2 * t);
  }

  /// The order chromatid [knobs]' globules are laid in, its granules
  /// standing out of the surface among them: the layer behind first, then
  /// the rest from the rim round to the front, the larger after the smaller
  /// where they lie as far round: each stands over those behind it, as on a
  /// real tube, and a granule shows only between the globules.
  List<int> _order(KnobField knobs, ChromosomeGlobules globules) {
    final Float64List depth = Float64List(knobs.length);
    final List<int> order = <int>[];
    for (int k = 0; k < knobs.length; k++) {
      if (knobs.kind[k] == KnobField.pit) {
        continue;
      }
      order.add(k);
      depth[k] =
          globules.surface * form.widthAt(knobs.y[k]) * math.cos(knobs.phi[k]) +
          knobs.radius[k];
    }
    order.sort((int a, int b) {
      final bool behindA = knobs.kind[a] == KnobField.deep;
      final bool behindB = knobs.kind[b] == KnobField.deep;
      if (behindA != behindB) {
        return behindA ? -1 : 1;
      }
      final int byDepth = depth[a].compareTo(depth[b]);
      return byDepth != 0 ? byDepth : a.compareTo(b);
    });
    return order;
  }

  /// Knob [k] of chromatid [side] as a globule: a sphere, round from any
  /// side, its middle out on the tube ([ChromosomeGlobules.surface] of the
  /// way), made of the gene's chromatin where the gene's weight there, moved
  /// by its own jitter, passes the mark, else of what the form picked.
  _Globule _globule(
    double side,
    KnobField knobs,
    int k,
    ChromosomeGlobules globules,
  ) {
    final double y = knobs.y[k];
    final double phi = knobs.phi[k];
    final double u = math.sin(phi);
    final double x =
        form.centreAt(side, y) + globules.surface * form.widthAt(y) * u;
    final double at = y + form.bowAt(y) * u * u;
    final double moved = globules.pickJitter * knobs.pick[k];
    final double gene = _geneWeight(x, at, globules);
    final bool genes = gene + moved > globules.geneAt;
    return _Globule(
      x: x,
      y: at,
      r: knobs.radius[k],
      along: y,
      u: u,
      normal: SurfaceNormal(u, -form.slope(y), math.cos(phi)),
      material: genes
          ? ChromatinMaterial.gene
          : ChromatinMaterial.values[knobs.material[k]],
      lift: knobs.lift[k],
      pick: knobs.pick[k],
      lit: genes ? globules.glowLit + (1 - globules.glowLit) * gene : 1,
      deep: knobs.kind[k] == KnobField.deep,
    );
  }

  /// How many points round the rings of a globule [r] across: the largest
  /// globules' [ChromosomeGlobules.ring], the smaller fewer, never under
  /// [ChromosomeGlobules.leastRing].
  int _ringFor(double r, ChromosomeGlobules globules) {
    final double largest = (_look.lobe + _look.lobeSpread) * _half;
    return (globules.ring * r / largest).round().clamp(
      globules.leastRing,
      globules.ring,
    );
  }

  /// [p]'s crevice: its material's crevice, falling away from its edge,
  /// shifted away from the light, so it lies on the globules beside it on
  /// that side as the shadow it casts on them.
  void _creviceOf(ColouredMesh mesh, _Globule p, ChromosomeGlobules globules) {
    const int ring = 12;
    mesh.begin(1 + ring * 2);
    final int centre = mesh.next;
    final double cx = p.x - _light.screen.dx * globules.skirtShift * p.r;
    final double cy = p.y - _light.screen.dy * globules.skirtShift * p.r;
    final int dark = _palette.crevice(p.material, _look.skirtAlpha);
    mesh.vertex(cx, cy, dark);
    for (final (double scale, int colour) in <(double, int)>[
      (_look.skirtInner, dark),
      (_look.skirtOuter, _palette.crevice(p.material, 0)),
    ]) {
      for (int i = 0; i < ring; i++) {
        final double a = 2 * math.pi * i / ring;
        mesh.vertex(
          cx + p.r * scale * math.cos(a),
          cy + p.r * scale * math.sin(a),
          colour,
        );
      }
    }
    for (int i = 0; i < ring; i++) {
      final int a = centre + 1 + i;
      final int b = centre + 1 + (i + 1) % ring;
      mesh.triangle(centre, a, b);
      mesh.triangle(a, b, a + ring);
      mesh.triangle(b, b + ring, a + ring);
    }
  }

  /// [p] as a sphere seen from the front, [ring] points round: lit ring by
  /// ring as a sphere's normals face, each leaned toward the surface's under
  /// it, so it is bright on the side toward the light and falls into shade
  /// on the other, darker toward its sister's edges as the surface is; its
  /// edge a thin soft ring.
  void _sphere(
    ColouredMesh mesh,
    double side,
    _Globule p,
    int ring,
    ChromosomeGlobules globules,
  ) {
    final List<double> rings = globules.rings;
    mesh.begin(1 + ring * (rings.length + 1));
    final int centre = mesh.next;
    final double tone = form.toneAt(p.along);
    final SurfaceNormal base = p.normal;
    final double lean = globules.normalBlend;
    final double behind = p.deep ? globules.backOcclusion : 0;
    int lit(double nx, double ny, double nz) {
      final SurfaceNormal n = SurfaceNormal(
        nx + (base.x - nx) * lean,
        ny + (base.y - ny) * lean,
        nz + (base.z - nz) * lean,
      );
      final _Lit s = _surface(
        side,
        p.along,
        p.u,
        n.x,
        n.y,
        n.z,
        facing: base.z,
      );
      return _palette.knob(
        p.material,
        tone,
        s.light * p.lit,
        s.occlusion + (1 - s.occlusion) * behind,
        1,
        sheen: s.sheen,
        lift: p.lift,
      );
    }

    mesh.vertex(p.x, p.y, lit(0, 0, 1));
    // Its outline wanders a little from round, by two waves of its own.
    final double twice = 2 * math.pi * p.lift;
    final double thrice = 3 * math.pi * p.pick;
    double radius(double a) =>
        p.r *
        (1 +
            globules.wobble *
                (0.6 * math.sin(2 * a + twice) +
                    0.4 * math.sin(3 * a + thrice)));
    final List<int> rim = List<int>.filled(ring, 0);
    for (int j = 0; j < rings.length; j++) {
      final double scale = rings[j];
      final double nz = math.sqrt(math.max(0, 1 - scale * scale));
      for (int i = 0; i < ring; i++) {
        final double a = 2 * math.pi * i / ring;
        final double c = math.cos(a);
        final double sn = math.sin(a);
        final int colour = lit(scale * c, scale * sn, nz);
        rim[i] = colour;
        final double out = radius(a) * scale;
        mesh.vertex(p.x + out * c, p.y + out * sn, colour);
      }
    }
    for (int i = 0; i < ring; i++) {
      final double a = 2 * math.pi * i / ring;
      final double out = radius(a) * globules.edge;
      mesh.vertex(
        p.x + out * math.cos(a),
        p.y + out * math.sin(a),
        _clear(rim[i]),
      );
    }
    for (int i = 0; i < ring; i++) {
      final int a = centre + 1 + i;
      final int b = centre + 1 + (i + 1) % ring;
      mesh.triangle(centre, a, b);
      for (int band = 0; band < rings.length; band++) {
        final int a0 = a + band * ring;
        final int b0 = b + band * ring;
        mesh.triangle(a0, b0, a0 + ring);
        mesh.triangle(b0, b0 + ring, a0 + ring);
      }
    }
  }

  /// [p]'s highlight: a small disc of its material's specular toward the
  /// light from its middle, as bright as the surface under it faces the eye,
  /// so the rim's globules have little.
  void _highlightOf(
    ColouredMesh mesh,
    _Globule p,
    ChromosomeGlobules globules,
  ) {
    final double strength = globules.specular * math.max(0, p.normal.z);
    if (strength <= 0.004) {
      return;
    }
    const int ring = 8;
    mesh.begin(1 + ring);
    final int centre = mesh.next;
    final double cx = p.x + _light.screen.dx * globules.specularShift * p.r;
    final double cy = p.y + _light.screen.dy * globules.specularShift * p.r;
    final double radius = globules.specularRadius * p.r;
    mesh.vertex(cx, cy, _palette.specular(p.material, strength));
    final int clear = _palette.specular(p.material, 0);
    for (int i = 0; i < ring; i++) {
      final double a = 2 * math.pi * i / ring;
      mesh.vertex(cx + radius * math.cos(a), cy + radius * math.sin(a), clear);
    }
    for (int i = 0; i < ring; i++) {
      mesh.triangle(centre, centre + 1 + i, centre + 1 + (i + 1) % ring);
    }
  }

  /// The cleft's shade down chromatid [side]'s side facing its sister: the
  /// deepest shadow from the middle of the pair, fading out
  /// [ChromosomeGlobules.cleftWidth] into the sister; darkest beside the
  /// centromere, where the arms part, gone at the waist, where they meet,
  /// and toward the ends.
  ui.Vertices _cleftOf(double side, ChromosomeGlobules globules) {
    final Float64List rows = form.bodyRows;
    final Float32List positions = Float32List(rows.length * 4);
    final Int32List colours = Int32List(rows.length * 2);
    final List<int> indices = <int>[];
    for (int i = 0; i < rows.length; i++) {
      final double y = rows[i];
      final double middle = form.bend(y);
      final double d = ((y - form.centromere).abs() - _half) / (0.8 * _half);
      final double crotch = math.exp(-d * d);
      final double waist = form.waist(y);
      final double fromEnd = math.min(y - form.top, form.bottom - y) / _half;
      final double alpha =
          globules.cleft *
          (0.6 + 0.4 * crotch) *
          (1 - waist * waist) *
          _smoothstep(0, 1, fromEnd);
      positions
        ..[i * 4] = middle
        ..[i * 4 + 1] = y
        ..[i * 4 + 2] = middle + side * globules.cleftWidth * _half
        ..[i * 4 + 3] = y;
      colours
        ..[i * 2] = _palette.shadow(alpha)
        ..[i * 2 + 1] = _palette.shadow(0);
      if (i > 0) {
        final int a = (i - 1) * 2;
        indices.addAll(<int>[a, a + 1, a + 2, a + 1, a + 3, a + 2]);
      }
    }
    return ui.Vertices.raw(
      VertexMode.triangles,
      positions,
      colors: colours,
      indices: Uint16List.fromList(indices),
    );
  }

  List<ui.Vertices> _grains(double side) {
    final ColouredMesh mesh = ColouredMesh();
    _layGrains(mesh, side);
    return mesh.build();
  }

  void _layGrains(ColouredMesh mesh, double side) {
    const int ring = 6;
    final ChromosomeGlobules? globules = _look.globules;
    final KnobField knobs = form.knobs(side);
    final int pit = _palette.shadow(_look.pitAlpha);
    for (int k = 0; k < knobs.length; k++) {
      final int kind = knobs.kind[k];
      if (kind == KnobField.lobe || kind == KnobField.deep) {
        continue;
      }
      final _Knob p;
      if (globules != null) {
        // In a look of globules a granule standing out of the surface is a
        // small sphere among the globules ([_layKnobs]); one sunk into it is
        // a dark dot, round.
        if (kind == KnobField.bump) {
          continue;
        }
        final _Globule g = _globule(side, knobs, k, globules);
        p = _Knob(
          x: g.x,
          y: g.y,
          normal: g.normal,
          ax: g.r * 0.5,
          ay: 0,
          bx: 0,
          by: g.r * 0.5,
        );
      } else {
        p = _place(side, knobs, k);
      }
      final int heart = kind == KnobField.bump ? _bump(side, knobs, k, p) : pit;
      mesh.begin(1 + ring);
      final int centre = mesh.next;
      mesh.vertex(p.x, p.y, heart);
      for (int i = 0; i < ring; i++) {
        final Offset at = p.at(2 * math.pi * i / ring, 1);
        mesh.vertex(at.dx, at.dy, _clear(heart));
      }
      for (int i = 0; i < ring; i++) {
        mesh.triangle(centre, centre + 1 + i, centre + 1 + (i + 1) % ring);
      }
    }
  }

  /// The heart of granule [k], [p], standing out of the surface: the
  /// chromatin's own colour where it lies, lit a little nearer its full
  /// tone, never past it.
  int _bump(double side, KnobField knobs, int k, _Knob p) {
    final double y = knobs.y[k];
    final SurfaceNormal n = p.normal;
    final _Lit s = _surface(
      side,
      y,
      math.sin(knobs.phi[k]),
      n.x,
      n.y,
      n.z,
      facing: n.z,
    );
    final ({double centromere, double telomere}) tint = _tints(y);
    return _palette.colour(
      form.toneAt(y),
      s.light + (1 - s.light) * _look.bumpLift,
      s.occlusion,
      form.geneAt(y),
      _look.bumpAlpha,
      centromere: tint.centromere,
      telomere: tint.telomere,
    );
  }
}

/// How a point of the surface is lit: its light, the groove's shade on it,
/// and its sheen.
typedef _Lit = ({double light, double occlusion, double sheen});

/// A globule as it is seen: its middle and radius on screen, where along the
/// chromosome it lies and how far across the tube (the sine of its angle
/// round it), the surface's normal under it, what it is made of, how much
/// lighter or darker it is than the next, how much of the light it takes,
/// and whether it lies in the layer behind.
final class _Globule {
  const _Globule({
    required this.x,
    required this.y,
    required this.r,
    required this.along,
    required this.u,
    required this.normal,
    required this.material,
    required this.lift,
    required this.pick,
    required this.lit,
    required this.deep,
  });

  final double x;
  final double y;
  final double r;
  final double along;
  final double u;
  final SurfaceNormal normal;
  final ChromatinMaterial material;
  final double lift;

  /// The jitter its material was picked with, which also turns its outline.
  final double pick;

  /// How much of the light it takes: the gene's globules are lit by the
  /// spot's glow, the farther from it the less.
  final double lit;
  final bool deep;
}

/// [colour] with no alpha: where a soft edge fades to nothing.
int _clear(int colour) => colour & ((1 << 24) - 1);

double _smoothstep(double from, double to, double x) {
  final double t = ((x - from) / (to - from)).clamp(0.0, 1.0);
  return t * t * (3 - 2 * t);
}

/// A knob as it is seen: its middle, its surface's normal, and the two
/// half-axes of its ellipse.
final class _Knob {
  const _Knob({
    required this.x,
    required this.y,
    required this.normal,
    required this.ax,
    required this.ay,
    required this.bx,
    required this.by,
  });

  final double x;
  final double y;
  final SurfaceNormal normal;
  final double ax;
  final double ay;
  final double bx;
  final double by;

  /// The point [scale] of the way out to its edge, at angle [a] round it.
  Offset at(double a, double scale) {
    final double c = math.cos(a) * scale;
    final double s = math.sin(a) * scale;
    return Offset(x + ax * c + bx * s, y + ay * c + by * s);
  }
}
