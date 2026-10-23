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
/// lit as the zoom's organs are, under the same lamp: two sisters of
/// globules of chromatin, each of one material, in a ramp of its own:
/// spheres drawn from the back of the tube to its front, each over a
/// crevice that falls away from the light and under a highlight of its own;
/// the arms a soft blue, the centromere's neck clay and the caps honey, and
/// the chromatin round the gene in the mark, lit as the rest is, with
/// nothing glowing over it (the user's ask of 2026-10-23: the gene in the
/// plain mark, as the other stops draw it); the bodies under both sisters'
/// globules, a cleft dark between the sisters, a blurred shadow under them,
/// the bands faint changes of the arms' value, and a micrograph's fine
/// grain.
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

  /// Each sister's globules, left then right.
  late final List<List<ui.Vertices>> _sisters = <List<ui.Vertices>>[
    _sister(-1),
    _sister(1),
  ];

  /// Each sister's body, left then right: drawn under both sisters'
  /// globules, so where the sisters meet at the waist neither one's body
  /// lies over the other's globules.
  late final List<List<ui.Vertices>> _bodies = <List<ui.Vertices>>[
    _body(-1),
    _body(1),
  ];

  /// Each sister's granules, left then right.
  late final List<List<ui.Vertices>> _granules = <List<ui.Vertices>>[
    _grains(-1),
    _grains(1),
  ];

  /// Each sister's outline, for its shadow.
  late final List<Path> _outlines = <Path>[
    form.chromatid(-1).toPath(),
    form.chromatid(1).toPath(),
  ];

  /// The shade down each sister's side facing the other, left then right:
  /// the cleft between them.
  late final List<ui.Vertices> _clefts = <ui.Vertices>[
    _cleftOf(-1, _look.globules),
    _cleftOf(1, _look.globules),
  ];

  /// The gene's place on each sister at rest, left then right: what the
  /// gene's chromatin is measured from.
  late final List<Offset> _genePlaces = <Offset>[
    form.geneOn(-1),
    form.geneOn(1),
  ];

  /// What the globules' meshes are drawn with, where they have a grain: a
  /// tile of fine specks, the same every time, drawn once, that the
  /// globules' colours are multiplied by, so it lies on them and nowhere
  /// else, in a layer or out of one ([ChromosomeGlobules.grain]); a plain
  /// paint otherwise.
  late final Paint _grained = () {
    final ChromosomeGlobules globules = _look.globules;
    if (globules.grain <= 0) {
      return Paint();
    }
    const int size = 64;
    final math.Random random = math.Random(64);
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder);
    final Paint texel = Paint();
    for (int y = 0; y < size; y++) {
      for (int x = 0; x < size; x++) {
        // A speck's share of the light, from 1 down to twice the grain off.
        final double v = 1 - 2 * globules.grain * random.nextDouble();
        texel.color = Color.from(alpha: 1, red: v, green: v, blue: v);
        canvas.drawRect(Rect.fromLTWH(x.toDouble(), y.toDouble(), 1, 1), texel);
      }
    }
    final ui.Picture picture = recorder.endRecording();
    final ui.Image tile = picture.toImageSync(size, size);
    picture.dispose();
    final double scale = globules.grainTile * _half / size;
    // Sampled smoothly, and from smaller copies where a speck is smaller
    // than a pixel: specks neither flicker as the view moves nor change
    // with how the canvas is laid out under them.
    return Paint()
      ..shader = ImageShader(
        tile,
        TileMode.repeated,
        TileMode.repeated,
        Matrix4.diagonal3Values(scale, scale, 1).storage,
        filterQuality: FilterQuality.medium,
      );
  }();

  /// What the chromosome at rest covers, its shadow and its relief included,
  /// in the scene's units: the room a layer of it needs.
  late final Rect bounds = _outlines[0]
      .getBounds()
      .expandToInclude(_outlines[1].getBounds())
      .inflate(_look.boundsInflate * _half);

  /// The body's colour averaged over its area on both sisters, lit as it
  /// is, the gene's chromatin and the centromere's and telomeres' left out:
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
        ? _look.globules.colours.body.base
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
    _grained,
    bounds,
    meanTone,
  ];

  /// The chromosome at rest. On its way into the band's map, each sister is
  /// moved [merge] of the way onto the axis at the band's height and thinned
  /// [thin] of the way to [target] half-width there, as the tube under it
  /// is: its shadow and the cleft go with it.
  void paintRest(
    Canvas canvas,
    ZoomFrame frame, {
    double merge = 0,
    double thin = 0,
    double target = 0,
  }) {
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
    // organs cast theirs, blurred, its sigma in the scene's units, so it is
    // as soft at any magnification. Nothing else lies round them.
    final ChromosomeGlobules globules = _look.globules;
    canvas.save();
    canvas.translate(_look.shadowX * _half, _look.shadowY * _half);
    for (int i = 0; i < 2; i++) {
      sister(
        i,
        () => canvas.drawPath(
          _outlines[i],
          Paint()
            ..color = inks.shadow.withValues(alpha: _look.shadowAlpha)
            ..maskFilter = MaskFilter.blur(
              BlurStyle.normal,
              globules.shadowBlur * _half,
            ),
        ),
      );
    }
    canvas.restore();
    final Paint mesh = Paint();
    for (int i = 0; i < 2; i++) {
      sister(i, () {
        for (final ui.Vertices vertices in _bodies[i]) {
          canvas.drawVertices(vertices, BlendMode.dst, mesh);
        }
      });
    }
    // Where there is a grain, the globules' colours multiplied by its
    // specks.
    final bool grained = globules.grain > 0;
    for (int i = 0; i < 2; i++) {
      sister(i, () {
        for (final ui.Vertices vertices in _sisters[i]) {
          if (grained) {
            canvas.drawVertices(vertices, BlendMode.modulate, _grained);
          } else {
            canvas.drawVertices(vertices, BlendMode.dst, mesh);
          }
        }
        for (final ui.Vertices vertices in _granules[i]) {
          canvas.drawVertices(vertices, BlendMode.dst, mesh);
        }
      });
    }
    // The cleft, down each sister's side facing the other.
    for (int i = 0; i < 2; i++) {
      sister(i, () => canvas.drawVertices(_clefts[i], BlendMode.dst, mesh));
    }
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

  /// The gene's place on each sister pinged once as the chromosome is
  /// reached, [t] of the way through the beat, as the body's and the
  /// organ's places are: a ring in the mark, nothing before the beat starts
  /// or after it ends.
  void paintPing(Canvas canvas, ZoomFrame frame, double t, double opacity) {
    if (t <= 0 || t >= 1 || opacity <= 0) {
      return;
    }
    final double r = form.pingRadius;
    for (final double side in <double>[-1, 1]) {
      Sculpt.ping(
        canvas,
        form.geneOn(side),
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

  /// Every globule and granule of chromatid [side] as it is drawn, for
  /// tests: where its middle lies, its radius, and what it is made of.
  @visibleForTesting
  List<({Offset at, double radius, ChromatinMaterial material})> globulesOf(
    double side,
  ) {
    final ChromosomeGlobules globules = _look.globules;
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
    _layKnobs(mesh, side);
    return mesh.build();
  }

  List<ui.Vertices> _body(double side) {
    final ColouredMesh mesh = ColouredMesh();
    _layBody(mesh, side);
    return mesh.build();
  }

  /// Sister [side]'s body, and over it its globules.
  void _laySister(ColouredMesh mesh, double side) {
    _layBody(mesh, side);
    _layKnobs(mesh, side);
  }

  void _layBody(ColouredMesh mesh, double side) {
    final ChromosomeGlobules globules = _look.globules;
    final Float64List rows = form.bodyRows;
    final List<double> columns = _columns;
    final int across = columns.length;
    // The body: a sheet of rows across a tube narrower than the globules',
    // lit vertex by vertex, in their crevices' shade, that shows only
    // between them.
    mesh.begin(rows.length * across);
    final int first = mesh.next;
    for (final double y in rows) {
      final double w = globules.bodyWidth * form.widthAt(y);
      final double centre = form.centreAt(side, y);
      final double bow = form.bowAt(y);
      final double slope = form.slope(y);
      final double tone = form.toneAt(y);
      final ({double centromere, double telomere}) tint = _tints(y);
      for (final double u in columns) {
        final double nz = math.sqrt(math.max(0, 1 - u * u));
        final SurfaceNormal n = SurfaceNormal(u, -slope, nz);
        final _Lit s = _surface(side, y, u, n.x, n.y, n.z, facing: n.z);
        final double x = centre + w * u;
        mesh.vertex(
          x,
          y + bow * u * u,
          _palette.colour(
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
    final ChromosomeGlobules globules = _look.globules;
    final KnobField knobs = form.knobs(side);
    // The globules, from the back of the tube to its front, each over its
    // crevice and under its highlight. The neck of the centromere's globules
    // is the centromere.
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
  }

  // The globules.

  /// How much of the gene's chromatin is at ([x], [y]): all of it at the
  /// gene's place on either sister, falling to none
  /// [ChromosomeGlobules.geneReach] from the nearer.
  double _geneWeight(double x, double y, ChromosomeGlobules globules) {
    double nearest = double.infinity;
    for (final Offset place in _genePlaces) {
      final double dx = x - place.dx;
      final double dy = y - place.dy;
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
        s.light,
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
    final ChromosomeGlobules globules = _look.globules;
    final KnobField knobs = form.knobs(side);
    final int pit = _palette.shadow(_look.pitAlpha);
    for (int k = 0; k < knobs.length; k++) {
      // A granule standing out of the surface is a small sphere among the
      // globules ([_layKnobs]); one sunk into it is a dark dot, round.
      if (knobs.kind[k] != KnobField.pit) {
        continue;
      }
      final _Globule g = _globule(side, knobs, k, globules);
      final _Knob p = _Knob(
        x: g.x,
        y: g.y,
        ax: g.r * 0.5,
        ay: 0,
        bx: 0,
        by: g.r * 0.5,
      );
      mesh.begin(1 + ring);
      final int centre = mesh.next;
      mesh.vertex(p.x, p.y, pit);
      for (int i = 0; i < ring; i++) {
        final Offset at = p.at(2 * math.pi * i / ring, 1);
        mesh.vertex(at.dx, at.dy, _clear(pit));
      }
      for (int i = 0; i < ring; i++) {
        mesh.triangle(centre, centre + 1 + i, centre + 1 + (i + 1) % ring);
      }
    }
  }
}

/// How a point of the surface is lit: its light, the groove's shade on it,
/// and its sheen.
typedef _Lit = ({double light, double occlusion, double sheen});

/// A globule as it is seen: its middle and radius on screen, where along the
/// chromosome it lies and how far across the tube (the sine of its angle
/// round it), the surface's normal under it, what it is made of, how much
/// lighter or darker it is than the next, and whether it lies in the layer
/// behind.
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
  final bool deep;
}

/// [colour] with no alpha: where a soft edge fades to nothing.
int _clear(int colour) => colour & ((1 << 24) - 1);

double _smoothstep(double from, double to, double x) {
  final double t = ((x - from) / (to - from)).clamp(0.0, 1.0);
  return t * t * (3 - 2 * t);
}

/// A granule sunk into the surface as it is seen: its middle, and the two
/// half-axes of its ellipse.
final class _Knob {
  const _Knob({
    required this.x,
    required this.y,
    required this.ax,
    required this.ay,
    required this.bx,
    required this.by,
  });

  final double x;
  final double y;
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
