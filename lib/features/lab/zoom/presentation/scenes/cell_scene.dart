import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/cell_archetypes.dart';
import '../../domain/locus_track.dart';
import '../../domain/zoom_camera.dart';
import '../../domain/zoom_depth.dart';
import '../../domain/zoom_path.dart';
import 'body_scene.dart';
import 'contour.dart';
import 'nucleus_shape.dart';
import 'zoom_scene.dart';
import 'zoom_subject.dart';

/// The cell the zoom lands in, as immunofluorescence shows a cell and as the
/// Human Protein Atlas images one: DNA blue, the endoplasmic reticulum
/// yellow, microtubules magenta (the Atlas's red, moved to magenta so a
/// reader who cannot tell red from green can tell them from the protein),
/// and the protein green, where the Atlas finds it in a cell: brighter where
/// it calls a location main, fainter where additional. A protein the Atlas
/// finds secreted leaves the cell in vesicles. Where the Atlas gives no
/// location, no green is drawn.
///
/// The cell's shape is its kind's ([CellArchetype]), its nucleus at the
/// centre where the zoom goes next. A red cell has none: the zoom lands in
/// an erythroblast of an island in the marrow, the grown red cells beside it.
///
/// Coming in from the tissue, the dark of the fluorescence field spreads out
/// from the cell over the stained slide.
final class CellScene extends ZoomScene {
  CellScene(this.subject)
    : archetype = subject.depth.archetype,
      nucleusShape = NucleusShape(subject.depth.archetype.shape);

  final ZoomSubject subject;
  final CellArchetype archetype;
  final NucleusShape nucleusShape;

  @override
  ZoomStop get stop => ZoomStop.cell;

  /// The cell's half-size and its nucleus's radius, in the scene's units.
  double get size => archetype.metres / 2 / subject.depth.widthOf(stop);
  double get nucleus => archetype.nucleus / 2 / subject.depth.widthOf(stop);

  late final _Cell _cell = _Cell.of(archetype.shape, size, nucleus, subject);

  SubcellularReading get _reading => subject.track.subcellular;

  bool get _secreted =>
      (subject.track.secretome ?? '').startsWith('Secreted');

  @override
  void stage(ZoomFrame frame, ZoomStaging out) {
    final double shown = calloutPresence(frame);
    out.item('cell:target', frame.toScreen(Offset.zero), frame.opacity);
    final _Cell cell = _cell;
    if (cell.mature.isNotEmpty) {
      out.callout(
        'cell:mature',
        'red cells: no nucleus',
        frame.toScreen(cell.mature.first),
        shown,
      );
    }
    final List<String> main = _reading.main;
    if (main.isEmpty) {
      out.callout(
        'cell',
        'its nucleus',
        frame.toScreen(Offset(nucleus * 0.7, -nucleus * 0.7)),
        shown,
      );
      return;
    }
    final Compartment first = compartmentOf[main.first] ?? Compartment.cytosol;
    out.callout(
      'cell',
      main.map(_word).join(', '),
      frame.toScreen(cell.pointOf(first)),
      shown,
    );
  }

  /// The Atlas's word as it reads mid-sentence: "cytosol", "Golgi
  /// apparatus".
  static String _word(String word) => word.startsWith('Golgi')
      ? word
      : '${word[0].toLowerCase()}${word.substring(1)}';

  @override
  void paint(Canvas canvas, ZoomFrame frame) {
    canvas.save();
    frame.enter(canvas);
    final double pixel = frame.pixel;
    final _Cell cell = _cell;
    // The fluorescence field: spreading from the cell over the slide as the
    // view comes in, everywhere at the cell's stop.
    final double spread = frame.isChild
        ? smoothstep((frame.progress - 0.3) / 0.6)
        : 1;
    canvas.drawCircle(
      Offset.zero,
      size * 1.25 + (3 - size * 1.25) * spread,
      Paint()..color = frame.inks.scale.fluorescence,
    );
    final Paint membrane = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2 * pixel
      ..color = frame.inks.scale.membrane.withValues(alpha: 0.7);

    // The island's other cells, dimmer: the macrophage, the erythroblasts
    // round it and the grown red cells leaving it.
    for (final Path other in cell.neighbours) {
      canvas.drawPath(
        other,
        Paint()..color = frame.inks.scale.reticulum.withValues(alpha: 0.08),
      );
      canvas.drawPath(other, membrane);
    }
    for (final (Offset at, double r) in cell.neighbourNuclei) {
      canvas.drawCircle(
        at,
        r,
        Paint()..color = frame.inks.scale.dapi.withValues(alpha: 0.6),
      );
    }
    for (final Offset at in cell.mature) {
      _redCell(canvas, frame, at, cell.matureRadius);
    }

    final Path body = cell.body;
    final Path nucleusPath = cell.nucleus;
    canvas.drawPath(
      body,
      Paint()..color = frame.inks.scale.reticulum.withValues(alpha: 0.06),
    );
    canvas.save();
    canvas.clipPath(body);
    // The reticulum, and the microtubules from the centrosome.
    final Paint reticulum = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3 * pixel
      ..strokeCap = StrokeCap.round
      ..color = frame.inks.scale.reticulum.withValues(alpha: 0.42);
    canvas.drawPath(cell.reticulum, reticulum);
    final Paint tubules = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1 * pixel
      ..color = frame.inks.scale.microtubules.withValues(alpha: 0.5);
    canvas.drawPath(cell.microtubules, tubules);
    if (cell.striations != null) {
      canvas.drawPath(
        cell.striations!,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6 * pixel
          ..color = frame.inks.scale.microtubules.withValues(alpha: 0.28),
      );
    }
    if (cell.droplet != null) {
      canvas.drawPath(
        cell.droplet!,
        Paint()..color = frame.inks.scale.fluorescence,
      );
    }
    canvas.restore();
    canvas.drawPath(body, membrane);

    // The protein, where the Atlas finds it.
    _protein(canvas, frame, cell, _reading.main, 0.9);
    _protein(canvas, frame, cell, _reading.additional, 0.45);

    // The nucleus: DNA blue, its nucleolus a hollow in it, its chromatin
    // condensing in a cell that is dividing or in meiosis. Opaque: nothing
    // of the cytoplasm shows through it.
    canvas.drawPath(
      nucleusPath,
      Paint()..color = frame.inks.scale.fluorescence,
    );
    canvas.drawPath(
      nucleusPath,
      Paint()
        ..shader = RadialGradient(
          colors: <Color>[
            frame.inks.scale.dapi,
            frame.inks.scale.dapi.withValues(alpha: 0.7),
          ],
        ).createShader(Rect.fromCircle(center: Offset.zero, radius: nucleus)),
    );
    if (cell.chromatin != null) {
      canvas.drawPath(
        cell.chromatin!,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2 * pixel
          ..strokeCap = StrokeCap.round
          ..color = Color.lerp(
            frame.inks.scale.dapi,
            Colors.white,
            0.45,
          )!,
      );
    }
    canvas.drawCircle(
      cell.nucleolus,
      nucleus * 0.22,
      Paint()..color = frame.inks.scale.fluorescence.withValues(alpha: 0.5),
    );
    canvas.drawPath(
      nucleusPath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2 * pixel
        ..color = frame.inks.mark,
    );
    // Nucleus-bound protein shows over the DNA it is in.
    _protein(canvas, frame, cell, _reading.main, 0.9, nuclear: true);
    _protein(canvas, frame, cell, _reading.additional, 0.45, nuclear: true);

    if (_secreted) {
      _secretion(canvas, frame, cell);
    }
    canvas.restore();
  }

  void _redCell(Canvas canvas, ZoomFrame frame, Offset at, double r) {
    // A biconcave disc: pale at its centre, with no nucleus.
    canvas.drawCircle(
      at,
      r,
      Paint()
        ..shader = RadialGradient(
          colors: <Color>[
            frame.inks.scale.eosin.withValues(alpha: 0.18),
            frame.inks.scale.eosinDeep.withValues(alpha: 0.55),
          ],
          stops: const <double>[0.45, 1],
        ).createShader(Rect.fromCircle(center: at, radius: r)),
    );
    canvas.drawCircle(
      at,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1 * frame.pixel
        ..color = frame.inks.scale.membrane.withValues(alpha: 0.6),
    );
  }

  /// The protein in [locations], [strength] bright, glowing as a
  /// fluorophore does; [nuclear] draws only what lies in the nucleus, over
  /// its DNA, and otherwise only what lies outside it.
  void _protein(
    Canvas canvas,
    ZoomFrame frame,
    _Cell cell,
    List<String> locations,
    double strength, {
    bool nuclear = false,
  }) {
    if (locations.isEmpty) {
      return;
    }
    final double pixel = frame.pixel;
    final Color green = frame.inks.scale.protein.withValues(alpha: strength);
    final Paint glow = Paint()
      ..color = green.withValues(alpha: strength * 0.55)
      ..blendMode = BlendMode.plus
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 5 * pixel);
    final Paint crisp = Paint()
      ..color = green
      ..blendMode = BlendMode.plus;
    void fill(Path path) {
      canvas.drawPath(path, glow..style = PaintingStyle.fill);
      canvas.drawPath(path, crisp..style = PaintingStyle.fill);
    }

    void stroke(Path path, double width) {
      glow
        ..style = PaintingStyle.stroke
        ..strokeWidth = width * 2 * pixel;
      crisp
        ..style = PaintingStyle.stroke
        ..strokeWidth = width * pixel
        ..strokeCap = StrokeCap.round;
      canvas.drawPath(path, glow);
      canvas.drawPath(path, crisp);
    }

    final Set<Compartment> drawn = <Compartment>{};
    for (final String location in locations) {
      final Compartment? compartment = compartmentOf[location];
      if (compartment == null || !drawn.add(compartment)) {
        continue;
      }
      final bool inside =
          compartment == Compartment.nucleoplasm ||
          compartment == Compartment.nucleoli;
      if (inside != nuclear &&
          compartment != Compartment.nuclearMembrane &&
          compartment != Compartment.sperm) {
        continue;
      }
      if (nuclear &&
          (compartment == Compartment.nuclearMembrane ||
              compartment == Compartment.sperm)) {
        continue;
      }
      switch (compartment) {
        case Compartment.nucleoplasm:
          canvas.save();
          canvas.clipPath(cell.nucleus);
          fill(
            Path()..addOval(
              Rect.fromCircle(center: Offset.zero, radius: nucleus * 2),
            ),
          );
          canvas.restore();
        case Compartment.nucleoli:
          fill(
            Path()..addOval(
              Rect.fromCircle(center: cell.nucleolus, radius: nucleus * 0.22),
            ),
          );
        case Compartment.nuclearMembrane:
          stroke(cell.nucleus, 2.4);
        case Compartment.cytosol:
          canvas.save();
          canvas.clipPath(
            Path.combine(PathOperation.difference, cell.body, cell.nucleus),
          );
          canvas.drawPath(
            cell.body,
            Paint()
              ..color = green.withValues(alpha: strength * 0.22)
              ..blendMode = BlendMode.plus,
          );
          canvas.restore();
        case Compartment.plasmaMembrane || Compartment.junctions:
          stroke(cell.body, 2.2);
        case Compartment.golgi:
          stroke(cell.golgi, 2.4);
        case Compartment.reticulum:
          canvas.save();
          canvas.clipPath(cell.body);
          stroke(cell.reticulum, 1.4);
          canvas.restore();
        case Compartment.vesicles || Compartment.lipidDroplets:
          fill(cell.vesicles);
        case Compartment.mitochondria:
          fill(cell.mitochondria);
        case Compartment.cytoskeleton:
          canvas.save();
          canvas.clipPath(cell.body);
          stroke(cell.cortex, 1.6);
          canvas.restore();
        case Compartment.centrosome || Compartment.division:
          fill(
            Path()
              ..addOval(Rect.fromCircle(center: cell.centrosome, radius: 3 * pixel)),
          );
        case Compartment.sperm:
          stroke(cell.cap, 3);
      }
    }
  }

  /// Vesicles carrying the protein from the Golgi to the membrane, and out:
  /// moving with the ambient clock, still under reduced motion.
  void _secretion(Canvas canvas, ZoomFrame frame, _Cell cell) {
    final double pixel = frame.pixel;
    final Paint vesicle = Paint()
      ..color = frame.inks.scale.protein.withValues(alpha: 0.85)
      ..blendMode = BlendMode.plus;
    final Paint halo = Paint()
      ..color = frame.inks.scale.protein.withValues(alpha: 0.4)
      ..blendMode = BlendMode.plus
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 4 * pixel);
    for (int i = 0; i < cell.exits.length; i++) {
      final double t = (frame.clock / 3.2 + i / cell.exits.length) % 1;
      final Offset from = cell.golgiCentre;
      final Offset to = cell.exits[i];
      // Out past the membrane over the last fifth, fading as it goes.
      final Offset at = t < 0.8
          ? Offset.lerp(from, to, smoothstep(t / 0.8))!
          : to + (to - from) * ((t - 0.8) * 0.6);
      final double fade = t < 0.8 ? 1 : 1 - (t - 0.8) / 0.2;
      canvas.drawCircle(at, 4.5 * pixel, halo..color = halo.color.withValues(alpha: 0.4 * fade));
      canvas.drawCircle(
        at,
        2.6 * pixel,
        vesicle..color = vesicle.color.withValues(alpha: 0.85 * fade),
      );
    }
  }
}

/// One cell's geometry in its scene's units, built once: its body and
/// nucleus, the organelles drawn in each channel, and the points a callout
/// can name.
final class _Cell {
  _Cell({
    required this.body,
    required this.nucleus,
    required this.nucleolus,
    required this.reticulum,
    required this.microtubules,
    required this.golgi,
    required this.golgiCentre,
    required this.vesicles,
    required this.mitochondria,
    required this.centrosome,
    required this.cortex,
    required this.cap,
    required this.exits,
    required this.membranePoint,
    this.striations,
    this.droplet,
    this.chromatin,
    this.neighbours = const <Path>[],
    this.neighbourNuclei = const <(Offset, double)>[],
    this.mature = const <Offset>[],
    this.matureRadius = 0,
  });

  factory _Cell.of(CellShape shape, double r, double n, ZoomSubject subject) {
    final math.Random random = math.Random(shape.index * 31 + 7);
    final Contour outline = cellOutline(shape, r, n);
    final Path body = outline.toPath();
    final Path nucleus = NucleusShape(shape).outline(n).toPath();
    final (double ax, double ay) = NucleusShape(shape).axes;
    final List<Offset> rim = outline.resampled(48).points;

    final Path? lipid = shape == CellShape.adipocyte
        ? (Path()
          ..addOval(Rect.fromCircle(center: Offset(0, r * 0.84), radius: r * 0.9)))
        : null;
    bool inBody(Offset p) =>
        body.contains(p) &&
        !nucleus.contains(p) &&
        !(lipid?.contains(p) ?? false);

    // The reticulum: short winding threads out from round the nucleus.
    final Path reticulum = Path();
    for (int k = 0; k < 26; k++) {
      final double a = 2 * math.pi * k / 26 + random.nextDouble() * 0.2;
      Offset p = Offset(math.cos(a) * n * ax * 1.15, math.sin(a) * n * ay * 1.15);
      reticulum.moveTo(p.dx, p.dy);
      double heading = a;
      for (int step = 0; step < 9; step++) {
        heading += (random.nextDouble() - 0.5) * 1.1;
        p += Offset(math.cos(heading), math.sin(heading)) * r * 0.09;
        reticulum.lineTo(p.dx, p.dy);
      }
    }
    // The centrosome by the nucleus, its microtubules out to the membrane;
    // in a long cell, running its length.
    final Offset centrosome = Offset(n * ax * 1.25, -n * ay * 0.85);
    final Path microtubules = Path();
    final bool long = shape == CellShape.myofibre ||
        shape == CellShape.cardiomyocyte ||
        shape == CellShape.spindle ||
        shape == CellShape.endothelial;
    if (long) {
      final Rect span = body.getBounds();
      for (int k = 0; k < 7; k++) {
        final double y = span.top + span.height * (k + 0.5) / 7;
        microtubules
          ..moveTo(span.left, y)
          ..cubicTo(
            span.left + span.width * 0.33,
            y + span.height * 0.04,
            span.left + span.width * 0.66,
            y - span.height * 0.04,
            span.right,
            y,
          );
      }
    }
    for (int k = 0; !long && k < rim.length; k += 2) {
      final Offset end = rim[k];
      final Offset mid = Offset.lerp(centrosome, end, 0.5)! +
          Offset(-(end - centrosome).dy, (end - centrosome).dx) *
              (random.nextDouble() - 0.5) *
              0.25;
      microtubules
        ..moveTo(centrosome.dx, centrosome.dy)
        ..quadraticBezierTo(mid.dx, mid.dy, end.dx, end.dy);
    }
    // The Golgi: stacked crescents on the far side of the nucleus from the
    // cell's apex.
    final double golgiAngle = shape == CellShape.acinar || shape == CellShape.ciliated
        ? -math.pi / 2
        : -math.pi / 4;
    final Path golgi = Path();
    for (int k = 0; k < 4; k++) {
      final double radius = n * (1.25 + 0.14 * k) * math.max(ax, ay);
      golgi.addArc(
        Rect.fromCircle(center: Offset.zero, radius: radius),
        golgiAngle - 0.55 + 0.05 * k,
        1.1 - 0.1 * k,
      );
    }
    final Offset golgiCentre =
        Offset(math.cos(golgiAngle), math.sin(golgiAngle)) * n * 1.45 * math.max(ax, ay);
    // Vesicles and mitochondria scattered in the cytoplasm.
    final Path vesicles = Path();
    final Path mitochondria = Path();
    int placed = 0;
    for (int tries = 0; tries < 600 && placed < 70; tries++) {
      final Offset p = Offset(
        (random.nextDouble() * 2 - 1) * r * 1.3,
        (random.nextDouble() * 2 - 1) * r * 1.3,
      );
      if (!inBody(p)) {
        continue;
      }
      if (placed.isEven) {
        vesicles.addOval(Rect.fromCircle(center: p, radius: r * 0.022));
      } else {
        final double a = random.nextDouble() * math.pi;
        final Offset along = Offset(math.cos(a), math.sin(a)) * r * 0.045;
        mitochondria.addRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: p,
              width: (along.dx.abs() + r * 0.02) * 2,
              height: (along.dy.abs() + r * 0.02) * 2,
            ),
            Radius.circular(r * 0.02),
          ),
        );
      }
      placed++;
    }
    // Where secreted vesicles leave: points on the membrane away from the
    // nucleus side the Golgi faces.
    final List<Offset> exits = <Offset>[
      for (int k = 0; k < 6; k++)
        rim[(rim.length * (0.62 + 0.06 * k) +
                    (golgiAngle / (2 * math.pi)) * rim.length)
                .round() %
            rim.length],
    ];
    final Offset membranePoint = rim[rim.length ~/ 4];
    // Actin's cortex: just inside the membrane all round.
    final Offset middle =
        outline.points.fold<Offset>(Offset.zero, (Offset a, Offset b) => a + b) /
        outline.points.length.toDouble();
    final Path cortex = Contour(<Offset>[
      for (final Offset p in outline.resampled(120).points)
        p - (p - middle) * 0.06,
    ]).toPath();
    // The acrosome's cap over the nucleus, in a germ cell.
    final Path cap = Path()
      ..addArc(
        Rect.fromCircle(center: Offset.zero, radius: n * 1.08),
        -math.pi * 0.85,
        math.pi * 0.7,
      );

    Path? striations;
    if (shape == CellShape.myofibre || shape == CellShape.cardiomyocyte) {
      // Sarcomeres, 2.5 µm apart.
      final double step =
          2.5e-6 / subject.depth.widthOf(ZoomStop.cell);
      striations = Path();
      for (double x = -2; x <= 2; x += step) {
        striations
          ..moveTo(x, -r * 2)
          ..lineTo(x, r * 2);
      }
    }
    final Path? droplet = lipid;
    Path? chromatin;
    if (shape == CellShape.germ || shape == CellShape.dividing) {
      // Chromosomes condensing: paired threads winding through the nucleus.
      chromatin = Path();
      for (int k = 0; k < 9; k++) {
        Offset p = Offset(
          (random.nextDouble() - 0.5) * n * 1.2,
          (random.nextDouble() - 0.5) * n * 1.2,
        );
        double heading = random.nextDouble() * 2 * math.pi;
        chromatin.moveTo(p.dx, p.dy);
        for (int step = 0; step < 6; step++) {
          heading += (random.nextDouble() - 0.5) * 1.4;
          final Offset next = p + Offset(math.cos(heading), math.sin(heading)) * n * 0.16;
          if (next.distance > n * 0.85) {
            break;
          }
          p = next;
          chromatin.lineTo(p.dx, p.dy);
        }
      }
    }

    final List<Path> neighbours = <Path>[];
    final List<(Offset, double)> neighbourNuclei = <(Offset, double)>[];
    if (shape == CellShape.myofibre) {
      // The fibre's other nuclei, along its rim.
      for (final double x in <double>[-1.7, -1.05, 0.95, 1.6]) {
        neighbourNuclei.add((Offset(x * r, -n * 0.1), n * 0.55));
      }
    }
    final List<Offset> mature = <Offset>[];
    double matureRadius = 0;
    if (shape == CellShape.erythroid) {
      // An erythroblastic island: a macrophage, erythroblasts round it at
      // every stage, the youngest largest, and grown red cells leaving it.
      final Offset macrophage = Offset(-r * 2.3, r * 0.25);
      neighbours.add(
        Contour.blob(macrophage, r * 1.5, r * 1.25, wobble: 0.18, seed: 5).toPath(),
      );
      neighbourNuclei.add((macrophage + Offset(-r * 0.3, 0), r * 0.42));
      for (int k = 0; k < 5; k++) {
        final double a = math.pi * (0.45 + 0.28 * k);
        final double size = r * (0.95 - 0.1 * k);
        final Offset c = macrophage + Offset(math.cos(a), math.sin(a)) * r * 2.25;
        neighbours.add(
          Contour.blob(c, size, size, wobble: 0.05, seed: 20 + k).toPath(),
        );
        // The last, its nucleus going: pushed out to the rim.
        final double out = k == 4 ? 0.62 : 0;
        neighbourNuclei.add((
          c + Offset(math.cos(a), math.sin(a)) * size * out,
          size * (0.55 - 0.05 * k),
        ));
      }
      matureRadius = 7.5e-6 / 2 / subject.depth.widthOf(ZoomStop.cell);
      mature.addAll(<Offset>[
        Offset(r * 1.9, -r * 1.6),
        Offset(r * 2.5, -r * 0.4),
        Offset(r * 1.7, r * 1.5),
      ]);
    }

    return _Cell(
      body: body,
      nucleus: nucleus,
      nucleolus: NucleusShape(shape).place(const Offset(-0.3, -0.25), n),
      reticulum: reticulum,
      microtubules: microtubules,
      golgi: golgi,
      golgiCentre: golgiCentre,
      vesicles: vesicles,
      mitochondria: mitochondria,
      centrosome: centrosome,
      cortex: cortex,
      cap: cap,
      exits: exits,
      membranePoint: membranePoint,
      striations: striations,
      droplet: droplet,
      chromatin: chromatin,
      neighbours: neighbours,
      neighbourNuclei: neighbourNuclei,
      mature: mature,
      matureRadius: matureRadius,
    );
  }

  /// The cell's outline for its shape: see [cellOutline].
  static Contour outlineOf(CellShape shape, double r, double n) {
    Contour polygon(List<Offset> corners) {
      final List<Offset> points = <Offset>[];
      for (int i = 0; i < corners.length; i++) {
        final Offset a = corners[i];
        final Offset b = corners[(i + 1) % corners.length];
        for (int k = 0; k < 24; k++) {
          points.add(Offset.lerp(a, b, k / 24)!);
        }
      }
      return Contour(points).resampled(160);
    }

    return switch (shape) {
      CellShape.acinar => polygon(<Offset>[
        Offset(-r * 0.8, n * 1.9),
        Offset(r * 0.8, n * 1.9),
        Offset(r * 0.38, -r * 1.05),
        Offset(-r * 0.38, -r * 1.05),
      ]),
      CellShape.ciliated => polygon(<Offset>[
        Offset(-r * 0.42, r * 0.8),
        Offset(r * 0.42, r * 0.8),
        Offset(r * 0.42, -r * 1.2),
        Offset(-r * 0.42, -r * 1.2),
      ]),
      CellShape.endothelial => Contour.blob(
        Offset.zero,
        r,
        r * 0.24,
        count: 160,
        wobble: 0.04,
        seed: 2,
      ),
      CellShape.spindle => Contour.blob(
        Offset.zero,
        r,
        r * 0.22,
        count: 160,
        seed: 2,
      ),
      CellShape.myofibre => polygon(<Offset>[
        Offset(-2, -n * 0.6),
        Offset(2, -n * 0.6),
        Offset(2, r * 1.3),
        Offset(-2, r * 1.3),
      ]),
      CellShape.cardiomyocyte => polygon(<Offset>[
        Offset(-r, -r * 0.35),
        Offset(r * 0.45, -r * 0.35),
        Offset(r, -r * 0.75),
        Offset(r * 1.1, -r * 0.45),
        Offset(r * 0.7, r * 0.05),
        Offset(r, r * 0.35),
        Offset(-r, r * 0.35),
      ]),
      CellShape.adipocyte => Contour.blob(
        Offset(0, r * 0.84),
        r,
        r,
        count: 160,
        wobble: 0.03,
        seed: 2,
      ),
      CellShape.neuron => _neuron(r),
      CellShape.glial => Contour.blob(
        Offset.zero,
        r * 0.38,
        r * 0.36,
        count: 160,
        wobble: 0.35,
        seed: 6,
      ),
      CellShape.megakaryocyte => Contour.blob(
        Offset.zero,
        r,
        r * 0.95,
        count: 160,
        wobble: 0.08,
        seed: 4,
      ),
      CellShape.trophoblast => Contour.blob(
        Offset.zero,
        r,
        r * 0.7,
        count: 160,
        wobble: 0.2,
        seed: 8,
      ),
      CellShape.hepatocyte => Contour.blob(
        Offset.zero,
        r,
        r * 0.9,
        count: 160,
        wobble: 0.1,
        seed: 3,
      ),
      _ => Contour.blob(
        Offset.zero,
        r * 0.95,
        r * 0.9,
        count: 160,
        wobble: 0.07,
        seed: 1,
      ),
    };
  }

  /// A neuron's body, drawn out into its dendrites and its axon.
  static Contour _neuron(double r) {
    final List<Offset> points = <Offset>[];
    const int count = 220;
    const List<double> processes = <double>[-1.6, -0.6, 0.3, 1.2, 2.2, 2.9];
    for (int i = 0; i < count; i++) {
      final double a = -math.pi / 2 + 2 * math.pi * i / count;
      double reach = r * 0.42;
      for (final double p in processes) {
        final double d = math.atan2(math.sin(a - p), math.cos(a - p));
        reach += r * 0.62 * math.exp(-d * d / 0.018);
      }
      // The axon, longest, straight down.
      final double axon = math.atan2(math.sin(a - math.pi / 2), math.cos(a - math.pi / 2));
      reach += r * 1.4 * math.exp(-axon * axon / 0.006);
      points.add(Offset(math.cos(a) * reach, math.sin(a) * reach));
    }
    return Contour(points);
  }

  final Path body;
  final Path nucleus;
  final Offset nucleolus;
  final Path reticulum;
  final Path microtubules;
  final Path golgi;
  final Offset golgiCentre;
  final Path vesicles;
  final Path mitochondria;
  final Offset centrosome;
  final Path cortex;
  final Path cap;
  final List<Offset> exits;
  final Offset membranePoint;
  final Path? striations;
  final Path? droplet;
  final Path? chromatin;
  final List<Path> neighbours;
  final List<(Offset, double)> neighbourNuclei;
  final List<Offset> mature;
  final double matureRadius;

  /// Where a callout naming [compartment] lands.
  Offset pointOf(Compartment compartment) {
    final Rect bounds = body.getBounds();
    return switch (compartment) {
      Compartment.nucleoplasm => nucleolus * -0.9,
      Compartment.nucleoli => nucleolus,
      Compartment.nuclearMembrane => nucleus.getBounds().centerRight,
      Compartment.golgi => golgiCentre,
      Compartment.centrosome || Compartment.division => centrosome,
      Compartment.sperm => nucleus.getBounds().topCenter,
      Compartment.plasmaMembrane || Compartment.junctions => membranePoint,
      _ => Offset(
        (nucleus.getBounds().right + bounds.right) / 2,
        bounds.center.dy,
      ),
    };
  }
}

/// The cell type the path names, as it reads mid-sentence.
String cellWord(ZoomPath path) => path.cellName?.toLowerCase() ?? 'a cell';

/// A cell's outline for its [shape], of half-size [r], its nucleus of radius
/// [n] at the origin: the cell scene draws it in fluorescence, and the
/// tissue draws the same outline in its stain, so the cell the zoom closes
/// on is one shape across the step between them.
Contour cellOutline(CellShape shape, double r, double n) =>
    _Cell.outlineOf(shape, r, n);

