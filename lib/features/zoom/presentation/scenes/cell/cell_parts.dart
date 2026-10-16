import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import '../../../domain/cell_archetypes.dart';
import '../../../domain/cell_parts.dart';
import '../contour.dart';
import 'neuron_form.dart';

/// The shapes a cell's parts are drawn as, one layer each, in the order
/// they are drawn: the Nissl bodies and the reticulum under the rest.
enum PartLayer {
  nissl,
  neurofilaments,
  erSacs,
  golgiSacs,
  golgiEnds,
  mitochondria,
  cristae,
  lysosomes,
  vesicles,
  granuleHalos,
  granuleCores,
  centrioles,
}

/// A cell's parts, in the cell's units, laid once for its kind
/// ([recipeOf]): the shapes each layer draws, the ribosomes on its rough
/// ER, the point each part's name lands on, and what a protein in each
/// part glows on.
final class CellParts {
  CellParts._(
    this.layers,
    this.ribosomes,
    this.targets,
    this.golgiCentre,
    this.golgiAngle,
    this.centrosome,
  );

  /// The parts of a cell of [shape] whose outline is [body] and its
  /// nucleus's [nucleus] (of radius [n]), its half-size [r], [um] a
  /// micrometre in its units; a neuron's laid on its [neuron] form. Null
  /// where its kind has no recipe yet.
  static CellParts? lay(
    CellShape shape, {
    required List<Offset> body,
    required List<Offset> nucleus,
    required double r,
    required double n,
    required double um,
    NeuronForm? neuron,
  }) {
    final CellRecipe recipe = recipeOf(shape);
    if (recipe.drawn.isEmpty) {
      return null;
    }
    final _Lay lay = _Lay(body, nucleus, n, um, shape.index * 17 + 5);
    switch (shape) {
      case CellShape.neuron:
        lay.neuron(neuron!);
      default:
        lay.secretory();
    }
    return CellParts._(
      lay.layers,
      lay.ribosomes,
      lay.targets,
      lay.golgiCentre,
      lay.golgiAngle,
      lay.centrosome,
    );
  }

  final Map<PartLayer, Path> layers;
  final List<Offset> ribosomes;

  /// Where each part's name lands: on one of it.
  final Map<CellPart, Offset> targets;

  /// The middle of the Golgi, where secreted vesicles set out from, and the
  /// way it lies from the nucleus.
  final Offset golgiCentre;
  final double golgiAngle;

  /// Where the centrosome is: the microtubules leave from it.
  final Offset centrosome;

  /// What a protein in [part] glows on, and whether that is a line to
  /// stroke (a stack's sacs) rather than shapes to fill.
  (Path, bool)? glowOf(CellPart part) => switch (part) {
    CellPart.golgi => (layers[PartLayer.golgiSacs]!, true),
    CellPart.roughEr => (layers[PartLayer.erSacs]!, true),
    CellPart.nisslBodies => (layers[PartLayer.nissl]!, false),
    CellPart.mitochondria => (layers[PartLayer.mitochondria]!, false),
    CellPart.secretoryGranules => (layers[PartLayer.granuleHalos]!, false),
    CellPart.vesicles => (layers[PartLayer.vesicles]!, false),
    CellPart.lysosomes => (layers[PartLayer.lysosomes]!, false),
    _ => null,
  };
}

/// Lays a cell's parts: what is placed takes its room, so no two overlap.
///
/// What is inside the cell is read off its outline's points as a polygon,
/// not off the smooth path drawn through them: a part is kept a margin in
/// from the membrane, and far more points are tried than parts laid, so
/// the polygon's speed is what lets the cell be built ahead in one frame.
final class _Lay {
  _Lay(this.body, this.nucleus, this.n, this.um, int seed)
    : random = math.Random(seed),
      box = _boxOf(body);

  final List<Offset> body;
  final List<Offset> nucleus;
  final Rect box;
  final double n;
  final double um;
  final math.Random random;

  final Map<PartLayer, Path> layers = <PartLayer, Path>{
    for (final PartLayer layer in PartLayer.values) layer: Path(),
  };
  final List<Offset> ribosomes = <Offset>[];
  final Map<CellPart, Offset> targets = <CellPart, Offset>{};
  final List<(Offset, double)> _taken = <(Offset, double)>[];
  Offset golgiCentre = Offset.zero;
  double golgiAngle = -math.pi / 4;
  Offset centrosome = Offset.zero;

  static Offset _way(double angle) => Offset(math.cos(angle), math.sin(angle));

  static Rect _boxOf(List<Offset> points) {
    double left = double.infinity;
    double top = double.infinity;
    double right = double.negativeInfinity;
    double bottom = double.negativeInfinity;
    for (final Offset p in points) {
      left = math.min(left, p.dx);
      top = math.min(top, p.dy);
      right = math.max(right, p.dx);
      bottom = math.max(bottom, p.dy);
    }
    return Rect.fromLTRB(left, top, right, bottom);
  }

  /// Whether [p] is inside the polygon [points], by the even-odd rule.
  static bool _within(List<Offset> points, Offset p) {
    bool inside = false;
    for (int i = 0, j = points.length - 1; i < points.length; j = i++) {
      final Offset a = points[i];
      final Offset b = points[j];
      if ((a.dy > p.dy) != (b.dy > p.dy) &&
          p.dx < (b.dx - a.dx) * (p.dy - a.dy) / (b.dy - a.dy) + a.dx) {
        inside = !inside;
      }
    }
    return inside;
  }

  /// Whether [p] is at least [margin] from every edge of [points].
  static bool _clear(List<Offset> points, Offset p, double margin) {
    final double least = margin * margin;
    for (int i = 0, j = points.length - 1; i < points.length; j = i++) {
      final Offset a = points[j];
      final Offset ab = points[i] - a;
      final double length = ab.distanceSquared;
      final double t = length == 0
          ? 0
          : (((p - a).dx * ab.dx + (p - a).dy * ab.dy) / length).clamp(
              0.0,
              1.0,
            );
      if ((a + ab * t - p).distanceSquared < least) {
        return false;
      }
    }
    return true;
  }

  /// Whether [p] is in the cytoplasm, [margin] clear of the membrane and of
  /// the nucleus.
  bool _inside(Offset p, double margin) =>
      box.contains(p) &&
      _within(body, p) &&
      !_within(nucleus, p) &&
      _clear(body, p, margin) &&
      _clear(nucleus, p, margin);

  /// Whether a part of [radius] at [p] would overlap none placed.
  bool _free(Offset p, double radius) {
    for (final (Offset at, double r) in _taken) {
      if ((at - p).distance < r + radius) {
        return false;
      }
    }
    return true;
  }

  void _take(Offset p, double radius) => _taken.add((p, radius));

  /// A point in the cytoplasm with room for a part of [radius], drawn by
  /// [pick], within [tries]; null where none came up.
  Offset? _place(double radius, Offset Function() pick, {int tries = 400}) {
    for (int i = 0; i < tries; i++) {
      final Offset p = pick();
      if (_free(p, radius + 0.08 * um) && _inside(p, radius + 0.15 * um)) {
        return p;
      }
    }
    return null;
  }

  Offset _anywhere(Rect box) => Offset(
    box.left + random.nextDouble() * box.width,
    box.top + random.nextDouble() * box.height,
  );

  /// A stack of [count] sacs round the nucleus's middle, on the way
  /// [angle] from it, the first [from] out and each [step] beyond the
  /// last, each [length] long (the outer ones a little shorter): the rough
  /// ER's or the Golgi's. Returns the outer sac's middle.
  Offset _stack(
    PartLayer layer,
    double angle,
    double from,
    int count,
    double step,
    double length, {
    bool studded = false,
    bool ends = false,
  }) {
    final Path sacs = layers[layer]!;
    late Offset outer;
    for (int k = 0; k < count; k++) {
      final double radius = from + k * step;
      final double sweep = length * (1 - 0.1 * k) / radius;
      final double start = angle - sweep / 2;
      sacs.addArc(
        Rect.fromCircle(center: Offset.zero, radius: radius),
        start,
        sweep,
      );
      outer = _way(angle) * radius;
      final int marks = math.max(2, (radius * sweep / (0.3 * um)).round());
      for (int i = 0; i <= marks; i++) {
        final double a = start + sweep * i / marks;
        _take(_way(a) * radius, step * 0.5);
        if (studded) {
          // Ribosomes on both faces of the sac.
          for (final double face in <double>[-1, 1]) {
            ribosomes.add(_way(a) * (radius + face * 0.07 * um));
          }
        }
      }
      if (ends) {
        // Each sac swells at its rims.
        for (final double a in <double>[start, start + sweep]) {
          layers[PartLayer.golgiEnds]!.addOval(
            Rect.fromCircle(center: _way(a) * radius, radius: 0.09 * um),
          );
        }
      }
    }
    return outer;
  }

  /// A mitochondrion at [at], lying the way [angle], [length] long.
  void _mitochondrion(Offset at, double angle, double length, double width) {
    final Offset along = _way(angle);
    final Offset across = Offset(-along.dy, along.dx);
    final Float64List turn = Float64List.fromList(<double>[
      along.dx, along.dy, 0, 0, //
      across.dx, across.dy, 0, 0,
      0, 0, 1, 0,
      at.dx, at.dy, 0, 1,
    ]);
    layers[PartLayer.mitochondria]!.addPath(
      Path()..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: length, height: width),
          Radius.circular(width / 2),
        ),
      ),
      Offset.zero,
      matrix4: turn,
    );
    // Its cristae: folds of the inner membrane across it.
    final Path cristae = layers[PartLayer.cristae]!;
    final int folds = math.max(2, (length / (0.22 * um)).floor());
    for (int i = 1; i < folds; i++) {
      final Offset c = at + along * (length * (i / folds - 0.5));
      final double reach = width * 0.32 * (i.isEven ? 1 : -1);
      cristae
        ..moveTo(c.dx - across.dx * reach, c.dy - across.dy * reach)
        ..lineTo(
          c.dx + across.dx * reach * 0.2,
          c.dy + across.dy * reach * 0.2,
        );
    }
    _take(at, length / 2);
  }

  /// [count] mitochondria about the cytoplasm, picked by [pick], each lying
  /// round the nucleus with a little play.
  List<Offset> _mitochondria(int count, Offset Function() pick, double size) {
    final List<Offset> out = <Offset>[];
    for (int i = 0; i < count; i++) {
      final double length = size * (0.9 + 0.7 * random.nextDouble());
      final Offset? at = _place(length / 2, pick);
      if (at == null) {
        continue;
      }
      final double angle =
          math.atan2(at.dy, at.dx) + math.pi / 2 + (random.nextDouble() - 0.5);
      _mitochondrion(at, angle, length, size * 0.42);
      out.add(at);
    }
    return out;
  }

  /// [count] round bodies of about [radius] in [layer], picked by [pick]:
  /// [part]'s, whose name lands on the first.
  List<Offset> _bodies(
    PartLayer layer,
    CellPart part,
    int count,
    double radius,
    Offset Function() pick,
  ) {
    final List<Offset> out = <Offset>[];
    for (int i = 0; i < count; i++) {
      final double size = radius * (0.8 + 0.4 * random.nextDouble());
      final Offset? at = _place(size, pick);
      if (at == null) {
        continue;
      }
      layers[layer]!.addOval(Rect.fromCircle(center: at, radius: size));
      _take(at, size);
      targets[part] ??= at;
      out.add(at);
    }
    return out;
  }

  /// The centrosome at [at]: two centrioles, one across the other.
  void _centrioles(Offset at, double angle) {
    centrosome = at;
    for (final (Offset offset, double turn) in <(Offset, double)>[
      (Offset.zero, angle),
      (_way(angle) * (0.32 * um), angle + math.pi / 2),
    ]) {
      final Offset c = at + offset;
      final Offset along = _way(turn);
      final Offset across = Offset(-along.dy, along.dx);
      final Offset a = along * (0.22 * um);
      final Offset b = across * (0.1 * um);
      layers[PartLayer.centrioles]!.addPolygon(<Offset>[
        c - a - b,
        c + a - b,
        c + a + b,
        c - a + b,
      ], true);
    }
    _take(at, 0.45 * um);
  }

  /// A secretory cell's parts, as a beta cell's: the Golgi off the nucleus
  /// on the upper left, the centrosome by it, three short stacks of rough
  /// ER, mitochondria, a few lysosomes and small clear vesicles, and the
  /// granules filling the rest, densest toward the side the Golgi faces
  /// away from, where they are released.
  void secretory() {
    golgiAngle = -3 * math.pi / 4;
    final Offset golgi = _stack(
      PartLayer.golgiSacs,
      golgiAngle,
      n + 0.45 * um,
      5,
      0.26 * um,
      2.1 * um,
      ends: true,
    );
    golgiCentre = _way(golgiAngle) * (n + 0.95 * um);
    targets[CellPart.golgi] = golgi;
    // Vesicles budding off its trans face.
    for (int i = 0; i < 7; i++) {
      final double a = golgiAngle + (random.nextDouble() - 0.5) * 0.55;
      final Offset at =
          _way(a) * (n + 1.75 * um + random.nextDouble() * 0.3 * um);
      if (_free(at, 0.08 * um) && _inside(at, 0.1 * um)) {
        layers[PartLayer.golgiEnds]!.addOval(
          Rect.fromCircle(center: at, radius: 0.08 * um),
        );
        _take(at, 0.09 * um);
      }
    }
    _centrioles(_way(golgiAngle + 0.62) * (n + 0.75 * um), golgiAngle);
    Offset? er;
    for (final double angle in <double>[3.02, 2.3, 0.78]) {
      final Offset outer = _stack(
        PartLayer.erSacs,
        angle,
        n + 0.5 * um,
        3,
        0.3 * um,
        2.4 * um,
        studded: true,
      );
      er ??= outer;
    }
    targets[CellPart.roughEr] = er!;
    Offset pick() => _anywhere(box);
    final List<Offset> mitochondria = _mitochondria(12, pick, 1.0 * um);
    targets[CellPart.mitochondria] = mitochondria.reduce(
      (Offset a, Offset b) => a.dy + 0.3 * a.dx >= b.dy + 0.3 * b.dx ? a : b,
    );
    _bodies(PartLayer.lysosomes, CellPart.lysosomes, 3, 0.22 * um, pick);
    _bodies(PartLayer.vesicles, CellPart.vesicles, 10, 0.07 * um, pick);
    // The granules, by a Poisson-disc throw: densest away from the Golgi.
    final Offset pole = -_way(golgiAngle);
    final List<Offset> granules = <Offset>[];
    for (int i = 0; i < 6000 && granules.length < 140; i++) {
      final Offset p = _anywhere(box);
      final double toward = (p.dx * pole.dx + p.dy * pole.dy) / box.width;
      if (random.nextDouble() > 0.35 + 1.3 * toward.clamp(0.0, 0.5)) {
        continue;
      }
      final double halo = 0.15 * um + random.nextDouble() * 0.04 * um;
      if (!_free(p, halo + 0.07 * um) || !_inside(p, halo + 0.08 * um)) {
        continue;
      }
      layers[PartLayer.granuleHalos]!.addOval(
        Rect.fromCircle(center: p, radius: halo),
      );
      // The dense core, a little off the middle of its halo.
      final Offset core =
          p + _way(random.nextDouble() * 2 * math.pi) * (halo * 0.18);
      layers[PartLayer.granuleCores]!.addOval(
        Rect.fromCircle(
          center: core,
          radius: halo * (0.48 + 0.12 * random.nextDouble()),
        ),
      );
      _take(p, halo);
      granules.add(p);
    }
    targets[CellPart.secretoryGranules] = granules.reduce(
      (Offset a, Offset b) =>
          a.dx - 0.6 * a.dy.abs() >= b.dx - 0.6 * b.dy.abs() ? a : b,
    );
  }

  /// A neuron's parts, laid on its [form]: Nissl bodies about its nucleus
  /// and up its dendrites' trunks but never in the hillock, neurofilaments
  /// down every process, small Golgi stacks about the nucleus, mitochondria
  /// along the processes and in the body.
  void neuron(NeuronForm form) {
    final double soma = form.soma;
    golgiAngle = -2.25;
    // The hillock and the axon first, so nothing else is laid in them.
    for (final NeuronBranch b in <NeuronBranch>[form.hillock, form.axon]) {
      for (double t = 0; t <= 1; t += 0.05) {
        _take(b.at(t), b.widthAt(t) * 0.6);
      }
    }
    // Neurofilaments: two lines down each trunk, branch, the hillock and
    // the axon.
    final Path filaments = layers[PartLayer.neurofilaments]!;
    for (final NeuronBranch b in <NeuronBranch>[
      for (final NeuronBranch d in form.dendrites)
        if (d.generation < 2) d,
      form.hillock,
      form.axon,
    ]) {
      for (final double side in <double>[-0.22, 0.22]) {
        final Offset a = b.at(0.04) + b.across * (b.widthAt(0.04) * side);
        final Offset z = b.at(0.97) + b.across * (b.widthAt(0.97) * side);
        filaments
          ..moveTo(a.dx, a.dy)
          ..lineTo(z.dx, z.dy);
      }
    }
    // Golgi: small stacks about the nucleus, none toward the hillock.
    for (final double angle in <double>[-2.25, -0.7, 2.45]) {
      _stack(
        PartLayer.golgiSacs,
        angle,
        n + 0.55 * um,
        3,
        0.3 * um,
        1.7 * um,
        ends: true,
      );
    }
    golgiCentre = _way(golgiAngle) * (n + 0.85 * um);
    targets[CellPart.golgi] = golgiCentre;
    // Nissl bodies: clumps of rough ER in the body and the trunks.
    final Path nissl = layers[PartLayer.nissl]!;
    final List<Offset> clumps = <Offset>[];
    void clump(Offset at, double size, int seed) {
      nissl.addPath(
        Contour.blob(
          at,
          size,
          size * (0.6 + 0.3 * random.nextDouble()),
          count: 14,
          wobble: 0.3,
          seed: seed,
        ).toPath(),
        Offset.zero,
      );
      _take(at, size);
      clumps.add(at);
    }

    for (int i = 0; i < 900 && clumps.length < 26; i++) {
      final double angle = random.nextDouble() * 2 * math.pi;
      // None in the hillock's way.
      final double off = math.atan2(
        math.sin(angle - math.pi / 2),
        math.cos(angle - math.pi / 2),
      );
      if (off.abs() < 0.62) {
        continue;
      }
      final double reach =
          n + 0.6 * um + random.nextDouble() * (soma - n - 1.2 * um);
      final Offset at = _way(angle) * reach;
      final double size = 0.55 * um + random.nextDouble() * 0.35 * um;
      // A clump's wobble reaches 1.3 times its size: all of it in the
      // cytoplasm.
      if (!_free(at, size + 0.15 * um) || !_inside(at, size * 1.35)) {
        continue;
      }
      clump(at, size, i);
    }
    final List<Offset> inSoma = List<Offset>.of(clumps);
    for (final NeuronBranch trunk in form.dendrites) {
      if (trunk.generation > 0) {
        continue;
      }
      for (final double t in <double>[0.25, 0.55]) {
        final Offset at = trunk.at(t);
        final double size = math.min(0.6 * um, trunk.widthAt(t) * 0.32);
        if (_free(at, size)) {
          clump(at, size, (t * 100).round() + clumps.length);
        }
      }
    }
    targets[CellPart.nisslBodies] = inSoma.reduce(
      (Offset a, Offset b) => a.dx - 0.3 * a.dy <= b.dx - 0.3 * b.dy ? a : b,
    );
    // Mitochondria along the processes, lying the way they run, and a few
    // in the body.
    for (final NeuronBranch b in <NeuronBranch>[
      for (final NeuronBranch d in form.dendrites)
        if (d.generation == 0) d,
      form.axon,
      form.axon,
    ]) {
      final double t = b == form.axon
          ? 0.2 + 0.6 * random.nextDouble()
          : 0.75 + 0.15 * random.nextDouble();
      final Offset at = b.at(t);
      final double length = 1.0 * um;
      if (_free(at, length / 2)) {
        _mitochondrion(
          at,
          math.atan2(b.along.dy, b.along.dx),
          length,
          math.min(0.36 * um, b.widthAt(t) * 0.5),
        );
      }
    }
    final Rect box = Rect.fromCircle(center: Offset.zero, radius: soma);
    Offset pick() => _anywhere(box);
    targets[CellPart.mitochondria] = _mitochondria(4, pick, 0.9 * um).first;
    _bodies(PartLayer.lysosomes, CellPart.lysosomes, 2, 0.22 * um, pick);
    _bodies(PartLayer.vesicles, CellPart.vesicles, 5, 0.07 * um, pick);
    // Where the names land: the trunk of the dendrite reaching up and to
    // the left, whose branches leave its name room beside them; the
    // hillock; the axon.
    final NeuronBranch left = form.dendrites
        .where((NeuronBranch d) => d.generation == 0)
        .reduce(
          (NeuronBranch a, NeuronBranch b) =>
              a.along.dx + a.along.dy <= b.along.dx + b.along.dy ? a : b,
        );
    targets[CellPart.dendrites] = left.at(0.8);
    targets[CellPart.axonHillock] =
        form.hillock.at(0.45) + Offset(form.hillock.widthAt(0.45) * 0.2, 0);
    targets[CellPart.axon] =
        form.axon.at(0.35) + Offset(form.axon.widthAt(0.35) * 0.2, 0);
    centrosome = _way(-1.2) * (n + 0.5 * um);
  }
}
