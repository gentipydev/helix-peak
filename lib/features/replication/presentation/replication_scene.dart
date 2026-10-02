import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../core/theme/app_typography.dart';
import '../domain/genome_replication.dart';
import '../domain/replication_tour.dart';
import 'replication_camera.dart';
import 'replication_geometry.dart';
import 'replication_inks.dart';
import 'replication_molecules.dart';
import 'replication_rings.dart';
import 'replication_staging.dart';

class ReplicationScene extends CustomPainter {
  ReplicationScene({
    required this.timeline,
    required this.at,
    required this.molecules,
    required this.inks,
    this.showLabels = true,
    this.followCamera = true,
    this.followBlend,
    this.reducedMotion = false,
    super.repaint,
  });

  final ReplicationTimeline timeline;
  final double Function() at;
  final ReplicationMolecules molecules;
  final ReplicationInks inks;
  final bool showLabels;
  final bool followCamera;

  /// How far the camera is between the whole fork (0) and the guided
  /// close-ups (1) while the reader switches; [followCamera] when absent.
  final double Function()? followBlend;
  final bool reducedMotion;
  final Map<(String, Color, double, FontWeight), TextPainter> _textCache =
      <(String, Color, double, FontWeight), TextPainter>{};

  final Paint _line = Paint()
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..style = PaintingStyle.stroke;

  /// Square-ended strokes: a base ends flat at its pair's gap.
  final Paint _bar = Paint()
    ..strokeCap = StrokeCap.butt
    ..strokeJoin = StrokeJoin.round
    ..style = PaintingStyle.stroke;
  final Paint _fill = Paint();

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final ReplicationMoment moment = timeline.stateAt(at());
    final ReplicationFrame frame = moment.frame;
    final ReplicationCamera camera = ReplicationCamera.at(
      moment,
      blend: followBlend?.call() ?? (followCamera ? 1 : 0),
      reducedMotion: reducedMotion,
    );
    final double scale = math.min(size.width / 360, size.height / 600);
    // Let a close-up fill tall phones too. Extend the DNA beyond the viewport
    // instead of showing the ends of the overview's drawing inside the zoom.
    final Rect viewport = Rect.fromCenter(
      center: const Offset(180, 300),
      width: size.width / scale,
      height: size.height / scale,
    );
    final Rect crop = Rect.lerp(
      const Rect.fromLTWH(0, 27, 360, 523),
      viewport,
      ((camera.zoom - 1).abs() / 0.4).clamp(0.0, 1.0),
    )!;
    final ReplicationGeometry g = ReplicationGeometry(
      frame,
      top: camera.centre.dy + (crop.top - 300) / camera.zoom,
      bottom: camera.centre.dy + (crop.bottom - 300) / camera.zoom,
    );
    // Below the origin the lower fork is the upper one turned about it:
    // stage for both halves, draw the upper half, and draw it again turned.
    final double originY = g.yOf(GenomeReplication.origin);
    final bool lower = originY < g.bottom + 30;
    final ReplicationStaging stage = ReplicationStaging(
      moment,
      lower
          ? ReplicationGeometry(
              frame,
              top: math.min(g.top, originY * 2 - g.bottom),
              bottom: math.max(g.bottom, originY * 2 - g.top),
            )
          : g,
      camera,
      showLabels: showLabels,
      reducedMotion: reducedMotion,
    );
    _zoom = camera.zoom;
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.translate(
      (size.width - 360 * scale) / 2,
      (size.height - 600 * scale) / 2,
    );
    canvas.scale(scale);

    canvas.save();
    canvas.clipRect(crop);
    canvas.translate(180, 300);
    canvas.scale(camera.zoom);
    canvas.translate(-camera.centre.dx, -camera.centre.dy);
    for (final StagedItem item in stage.shared) {
      if (item is StagedBand) _band(canvas, item);
    }
    if (lower) {
      canvas.save();
      canvas.translate(180, originY);
      canvas.rotate(math.pi);
      canvas.translate(-180, -originY);
      _turned = true;
      _half(
        canvas,
        ReplicationGeometry(
          frame,
          top: originY * 2 - g.bottom,
          bottom: originY * 2 - g.top,
        ),
        stage,
      );
      _turned = false;
      canvas.restore();
    }
    _half(canvas, g, stage, origin: true);
    canvas.restore();
    // Words live in screen space, so magnifying an enzyme does not magnify
    // its name.
    for (final StagedArrow arrow in stage.arrows) {
      _arrow(
        canvas,
        arrow.from,
        arrow.to,
        inks[arrow.ink].withValues(alpha: arrow.opacity),
      );
    }
    for (final StagedLabel label in stage.labels) {
      _label(canvas, label);
    }
    canvas.restore();
  }

  /// Whether this pass draws the lower fork, turned about the origin. Its
  /// rings are still seen a little from above, and its lit proteins keep
  /// their light from the top left.
  bool _turned = false;

  /// The camera's zoom while a frame is painted.
  double _zoom = 1;

  /// One fork's half of the scene. Rings go round the DNA: their far halves
  /// first, their near halves over it and over the enzymes they carry. The
  /// upper pass also draws what belongs to the [origin] itself.
  void _half(
    Canvas canvas,
    ReplicationGeometry g,
    ReplicationStaging stage, {
    bool origin = false,
  }) {
    final List<StagedRing> rings = <StagedRing>[
      if (origin)
        for (final StagedItem item in stage.shared)
          if (item is StagedRing) item,
      ...stage.rings,
    ];
    _rings(canvas, rings, near: false);
    _parent(canvas, g);
    _daughter(canvas, g, leading: true);
    _daughter(canvas, g, leading: false);
    _stage(canvas, g, stage);
    _rings(canvas, rings, near: true);
    _traces(canvas, g, stage);
    for (final StagedFlap flap in stage.flaps) {
      _flap(canvas, flap);
    }
    for (final StagedNick nick in stage.nicks) {
      _nick(canvas, nick);
    }
  }

  /// Draws [paint] with the canvas turned back upright about [at] in the
  /// lower fork's pass, so a lit shape keeps its light from the top left.
  void _upright(Canvas canvas, Offset at, void Function() paint) {
    if (!_turned) {
      paint();
      return;
    }
    canvas.save();
    canvas.translate(at.dx, at.dy);
    canvas.rotate(math.pi);
    canvas.translate(-at.dx, -at.dy);
    paint();
    canvas.restore();
  }

  /// The origin's A/T-rich stretch, softly lit behind the duplex.
  void _band(Canvas canvas, StagedBand band) {
    if (band.opacity <= 0) return;
    final double half = band.length / 2 * ReplicationGeometry.pitch;
    final RRect shape = RRect.fromRectAndRadius(
      Rect.fromCenter(center: band.centre, width: 46, height: half * 2 + 20),
      const Radius.circular(23),
    );
    canvas.drawRRect(
      shape,
      _fill..color = inks.quiet.withValues(alpha: 0.1 * band.opacity),
    );
    canvas.drawRRect(
      shape,
      _line
        ..strokeWidth = 0.8
        ..color = inks.quiet.withValues(alpha: 0.25 * band.opacity),
    );
  }

  void _parent(Canvas canvas, ReplicationGeometry g) {
    final double fork = g.frame.fork;
    final double top = fork + (g.forkY - g.top) / ReplicationGeometry.pitch + 2;
    // Each half-turn is one smooth tube, ending where the strands pass from
    // front to back: every multiple of π in the helix's phase, which comes
    // round sooner where the DNA is overwound. Both strands are one colour;
    // a front half-turn is drawn last, over a band of the ground, so where it
    // crosses the other strand the crossing shows as a clean gap.
    final double cut = g.frame.topoCut;
    final List<({double from, double to, bool leading, bool front})> turns =
        <({double from, double to, bool leading, bool front})>[];
    for (final bool leading in <bool>[false, true]) {
      // Topoisomerase II's cut, while it holds a strand open.
      final double at = g.parentalCut(leading: leading);
      final List<(double, double)> spans = cut > 0
          ? <(double, double)>[(fork, at - 1.2 * cut), (at + 1.2 * cut, top)]
          : <(double, double)>[(fork, top)];
      for (final (double from, double to) in spans) {
        double start = from;
        while (start < to - 1e-6) {
          final int half = (g.parentalPhase(start) / math.pi + 1e-9).floor();
          final double end = math.min(
            to,
            g.parentalIndexAt((half + 1) * math.pi),
          );
          if (end > start) {
            turns.add((
              from: start,
              to: end,
              leading: leading,
              front: leading == half.isEven,
            ));
          }
          start = math.max(end, start + 1e-3);
        }
      }
    }
    for (final bool front in <bool>[false, true]) {
      for (final ({double from, double to, bool leading, bool front}) turn
          in turns) {
        if (turn.front != front) continue;
        Offset strand(double i) => g.template(i, leading: turn.leading);
        if (front) {
          // The band stops short of the half-turn's ends, where it meets the
          // strand's own back half-turns.
          final double margin = math.min(1.5, (turn.to - turn.from) / 4);
          _halo(canvas, _trace(turn.from + margin, turn.to - margin, strand));
        }
        _backbonePath(canvas, _trace(turn.from, turn.to, strand), inks.parental);
      }
    }
    final double origin = g.frame.originShown;
    // Before the origin fires the fork is the origin itself, whose pair is
    // still whole: its bonds break only as the origin starts to melt.
    final double melting = ReplicationFrame.eased(
      g.frame.seconds,
      -37.5,
      -36,
    );
    for (double i = (fork / 5).ceil() * 5; i <= top; i += 5) {
      // Base pairs at the cut part as the gate opens.
      final double near = (i - g.frame.topoIndex).abs();
      _rung(
        canvas,
        g.template(i, leading: true),
        g.template(i, leading: false),
        inks.parental,
        inks.parental,
        bonds: GenomeReplication.hydrogenBonds(i.round()),
        opacity: 1 - cut * (1 - ReplicationGeometry.ease((near - 2) / 2)),
        // The helicase breaks each pair's bonds as the fork reaches it.
        bonded: ReplicationGeometry.ease((i - fork) / 2 + 2 * (1 - melting)),
        bondsShown: origin,
      );
    }
  }

  void _daughter(
    Canvas canvas,
    ReplicationGeometry g, {
    required bool leading,
  }) {
    final ReplicationFrame f = g.frame;
    // Below the origin is the lower fork's, drawn by its own turned pass.
    final double first = math.max(
      g.firstVisible - 2,
      GenomeReplication.origin,
    );
    final double fork = f.fork;
    _backbonePath(
      canvas,
      _trace(first, fork, (double i) => g.template(i, leading: leading)),
      inks.parental,
    );

    // The new strand: each piece between its exact ends, with a break where
    // two pieces are not yet joined. RNA is drawn over DNA where they meet.
    Offset newStrand(double i) => g.daughter(i, leading: leading);
    final List<DaughterPiece> pieces = g.piecesOn(leading: leading);
    final List<PieceJunction> joins = f.junctions(leading: leading);
    final List<(double, double)> rna = <(double, double)>[];
    for (int k = 0; k < pieces.length; k++) {
      final DaughterPiece piece = pieces[k];
      double low = math.max(piece.from, first);
      double high = math.min(piece.to, fork);
      if (k > 0 && k - 1 < joins.length) {
        low = math.max(low, _breakEdge(joins[k - 1], upper: true));
      }
      if (k < joins.length) {
        high = math.min(high, _breakEdge(joins[k], upper: false));
      }
      if (high <= low) continue;
      final double rnaLow = piece.hasRna ? math.max(low, piece.rnaFrom) : high;
      final double rnaHigh = piece.hasRna ? math.min(high, piece.rnaTo) : low;
      if (rnaHigh > rnaLow) {
        rna.add((rnaLow, rnaHigh));
        if (rnaLow > low) {
          _backbonePath(canvas, _trace(low, rnaLow, newStrand), inks.newDna);
        }
        if (high > rnaHigh) {
          _backbonePath(canvas, _trace(rnaHigh, high, newStrand), inks.newDna);
        }
      } else {
        _backbonePath(canvas, _trace(low, high, newStrand), inks.newDna);
      }
    }
    for (final (double low, double high) in rna) {
      _backbonePath(canvas, _trace(low, high, newStrand), inks.rna);
    }

    for (int i = (first / 5).floor() * 5; i < fork; i += 5) {
      final double index = i.toDouble();
      final Offset template = g.template(index, leading: leading);
      final double grown = g.presence(index, leading: leading);
      if (grown <= 0) {
        // A bare template base reaches towards its future partner. Near the
        // fork it still spans the parental pair's half, and shortens away
        // from it smoothly to the stub a new pair starts from.
        final double reach =
            _stub +
            (12 - _bondGap - _stub) *
                (1 - ReplicationGeometry.ease((fork - index) / 4));
        _rod(
          canvas,
          template,
          template + Offset(leading ? reach : -reach, 0),
          inks.parental,
        );
        _sphere(canvas, template, 2, inks.parental);
      } else {
        _rung(
          canvas,
          template,
          g.daughter(index, leading: leading),
          inks.parental,
          Color.lerp(inks.newDna, inks.rna, g.rna(index, leading: leading))!,
          bonds: GenomeReplication.hydrogenBonds(i),
          grown: grown,
        );
      }
    }
  }

  /// Where a strand stops short of a junction: the whole gap while the next
  /// piece is still coming, then a nick that ligase closes.
  static double _breakEdge(PieceJunction join, {required bool upper}) {
    final double width = math.max(join.gap, 1.2 * (1 - join.sealed));
    final double centre = (join.lower + join.upper) / 2;
    return upper ? centre + width / 2 : centre - width / 2;
  }

  /// A base pair from [a] to [b], each base in its strand's colour and cut
  /// square at a gap in the middle, where the pair's hydrogen bonds show as
  /// thin lines: [bonds] of them, two for A·T and three for G·C. A new
  /// base ([grown] below 1) grows out from its backbone towards the middle,
  /// and its bonds form as it docks. [bonded] breaks them, as the helicase
  /// does at the fork. At the origin ([bondsShown]) the gap widens, so the
  /// bonds are drawn larger and are easy to count.
  void _rung(
    Canvas canvas,
    Offset a,
    Offset b,
    Color aColor,
    Color bColor, {
    required int bonds,
    double grown = 1,
    double opacity = 1,
    double bonded = 1,
    double bondsShown = 0,
  }) {
    final double distance = (b - a).distance;
    // Where two strands cross in projection, a rung has no length to show.
    final double shown =
        opacity * ReplicationGeometry.ease((distance - 2) / 4);
    if (shown <= 0) return;
    final Offset direction = (b - a) / distance;
    final double gap = _bondGap + _originGap * bondsShown;
    final double half = math.max(0, distance / 2 - gap);
    final double stub = math.min(_stub, half);
    _rod(
      canvas,
      a,
      a + direction * (stub + (half - stub) * grown),
      aColor,
      opacity: shown,
    );
    if (grown > 0) {
      _rod(canvas, b, b - direction * half * grown, bColor, opacity: shown);
      // The bonds form as the new base docks. Too small to read in the
      // whole fork, they come with the close-ups; at the origin they always
      // show.
      _bonds(
        canvas,
        (a + b) / 2,
        direction,
        math.min(gap, distance / 2),
        bonds,
        shown *
            bonded *
            ReplicationGeometry.ease((grown - 0.6) / 0.4) *
            math.max(
              bondsShown,
              ReplicationGeometry.ease((_zoom - 1.3) / 0.5),
            ),
      );
      _sphere(canvas, b, 2.2, bColor, opacity: grown * shown);
    }
    _sphere(canvas, a, 2 + 0.2 * grown, aColor, opacity: shown);
  }

  /// Half the gap between a pair's two bases, and how much wider it opens
  /// at the origin, where the bonds are counted.
  static const double _bondGap = 1;
  static const double _originGap = 1.6;

  /// A new pair's template base before its partner arrives.
  static const double _stub = 7;

  /// The hydrogen bonds across a pair's gap: [count] thin lines from one
  /// base to the other, side by side about [middle], as long as the gap
  /// ([halfGap] either side), so a widening gap lengthens them smoothly.
  void _bonds(
    Canvas canvas,
    Offset middle,
    Offset direction,
    double halfGap,
    int count,
    double opacity,
  ) {
    if (opacity <= 0) return;
    final Offset across = Offset(-direction.dy, direction.dx);
    final Offset reach = direction * math.max(0, halfGap - 0.1);
    _bar
      ..strokeWidth = 0.45
      ..color = inks.ink.withValues(alpha: 0.8 * opacity);
    for (int k = 0; k < count; k++) {
      final Offset lane = middle + across * ((k - (count - 1) / 2) * 0.95);
      canvas.drawLine(lane - reach, lane + reach, _bar);
    }
  }

  void _stage(Canvas canvas, ReplicationGeometry g, ReplicationStaging stage) {
    for (final StagedItem item in stage.items) {
      switch (item) {
        case StagedMolecule():
          molecules.draw(
            canvas,
            item.centre,
            item.size,
            inks[item.ink],
            seed: item.seed,
            channel: item.channel,
            angle: item.angle + (_turned ? math.pi : 0),
            opacity: item.opacity,
          );
        case StagedGlow():
          _activeSite(
            canvas,
            item.centre,
            item.pulse,
            inks[item.ink],
            item.opacity,
          );
        case StagedTopo():
          _upright(
            canvas,
            item.centre,
            () => molecules.topo.draw(
              canvas,
              item.centre,
              upper: Color.lerp(inks.topoisomerase, Colors.white, 0.12)!,
              lower: Color.lerp(inks.topoisomerase, Colors.black, 0.1)!,
              site: inks.activeSite,
              gate: item.gate,
              sites: item.sites,
              opacity: item.opacity,
            ),
          );
        case StagedDuplexEnd():
          _duplexEnd(canvas, item.centre, item.turn, item.opacity);
        case StagedRing():
        case StagedTrace():
        case StagedBand():
          break;
      }
    }
  }

  /// A duplex seen end-on: its backbones as a ring, the two strands as beads
  /// half a turn apart, a base pair between them.
  void _duplexEnd(Canvas canvas, Offset centre, double turn, double opacity) {
    if (opacity <= 0) return;
    canvas.drawCircle(
      centre,
      11,
      _fill
        ..color = Color.lerp(
          inks.parental,
          inks.ground,
          0.7,
        )!.withValues(alpha: opacity),
    );
    final Offset spoke = Offset(math.cos(turn), math.sin(turn)) * 9;
    _rod(canvas, centre - spoke, centre + spoke, inks.parental, opacity: opacity);
    canvas.drawCircle(
      centre,
      11,
      _line
        ..strokeWidth = 2.9
        ..color = inks.parental.withValues(alpha: opacity),
    );
    _sphere(canvas, centre - spoke, 2.4, inks.parental, opacity: opacity);
    _sphere(canvas, centre + spoke, 2.4, inks.parental, opacity: opacity);
  }

  /// Templates that pass outside a protein, drawn again over it.
  void _traces(Canvas canvas, ReplicationGeometry g, ReplicationStaging stage) {
    for (final StagedItem item in stage.items) {
      if (item is StagedTrace) {
        final double from = math.max(
          g.frame.fork + item.from,
          GenomeReplication.origin,
        );
        final double to = g.frame.fork + item.to;
        if (to <= from) continue;
        _backbonePath(
          canvas,
          _trace(
            from,
            to,
            (double i) => g.template(i, leading: item.leading),
          ),
          inks.parental,
        );
      }
    }
  }

  ProteinRing _ring(StagedRing ring) {
    switch (ring.kind) {
      case RingKind.pcna:
        // Three subunits of two domains each, told apart by their seams, and
        // the hole a little wider than the duplex it holds at a tilt.
        return ProteinRing(
          centre: ring.centre,
          radius: 20,
          thickness: 7,
          height: 10,
          angles: ringAngles(
            count: 6,
            groups: 3,
            rotation: ring.rotation,
            open: ring.open,
          ),
          extents: ringExtents(count: 6, groups: 3, open: ring.open),
          colors: List<Color>.filled(6, inks.clamp),
          opacity: ring.opacity,
        );
      case RingKind.mcmN:
      case RingKind.mcmC:
        final bool motor = ring.kind == RingKind.mcmC;
        return ProteinRing(
          centre: ring.centre,
          radius: motor ? 23 : 21,
          thickness: motor ? 10 : 9,
          height: motor ? 12 : 10,
          tilt: 0.4,
          round: 10,
          angles: ringAngles(count: 6, open: ring.open),
          extents: ringExtents(count: 6, seam: 0.018, open: ring.open),
          // MCM2–7: six subunits, told apart by their seams.
          colors: List<Color>.filled(6, inks.helicase),
          glow: motor
              ? <double>[
                  for (int j = 0; j < 6; j++)
                    0.9 *
                        ring.firing *
                        math
                            .pow(
                              math.max(
                                0,
                                math.cos(
                                  ring.atp * math.pi * 2 - j * math.pi / 3,
                                ),
                              ),
                              6,
                            )
                            .toDouble(),
                ]
              : const <double>[],
          opacity: ring.opacity,
        );
      case RingKind.orc:
      case RingKind.cdc6:
        // ORC1–5 wrap the DNA as an open crescent; Cdc6 closes the gap.
        final List<double> angles = ringAngles(
          count: 6,
          rotation: math.pi / 2,
        );
        final List<(double, double)> extents = ringExtents(count: 6);
        final bool orc = ring.kind == RingKind.orc;
        return ProteinRing(
          centre: ring.centre,
          radius: 20,
          thickness: 8,
          height: 12,
          angles: orc ? angles.sublist(0, 5) : <double>[angles[5]],
          extents: orc ? extents.sublist(0, 5) : <(double, double)>[extents[5]],
          colors: orc
              ? List<Color>.filled(5, inks.orc)
              : <Color>[inks.cdc6],
          opacity: ring.opacity,
        );
      case RingKind.rfc:
        return ProteinRing(
          centre: ring.centre,
          radius: 13,
          thickness: 5.5,
          height: 8,
          angles: ringAngles(
            count: 5,
            rotation: ring.rotation,
            open: ring.open,
          ),
          extents: ringExtents(count: 5, open: ring.open),
          colors: List<Color>.filled(5, inks.rfc),
          opacity: ring.opacity,
        );
    }
  }

  void _rings(Canvas canvas, List<StagedRing> rings, {required bool near}) {
    // The lowest on the screen first: a ring stacked on another along the
    // DNA, as MCM2–7's tiers and RFC on PCNA are, covers its top face. The
    // turned pass mirrors heights.
    final List<(int, StagedRing)> ordered = <(int, StagedRing)>[
      for (int k = 0; k < rings.length; k++) (k, rings[k]),
    ]..sort(((int, StagedRing) p, (int, StagedRing) q) {
        final int byHeight = _turned
            ? p.$2.centre.dy.compareTo(q.$2.centre.dy)
            : q.$2.centre.dy.compareTo(p.$2.centre.dy);
        return byHeight != 0 ? byHeight : p.$1.compareTo(q.$1);
      });
    for (final (int _, StagedRing ring) in ordered) {
      if (ring.opacity <= 0) continue;
      // Rings are seen a little from above in both forks' halves: in the
      // lower fork's pass each is turned back upright about its centre.
      final double turn = ring.axis + (_turned ? math.pi : 0);
      final bool turned = turn.abs() > 1e-4;
      if (turned) {
        canvas.save();
        canvas.translate(ring.centre.dx, ring.centre.dy);
        canvas.rotate(turn);
        canvas.translate(-ring.centre.dx, -ring.centre.dy);
      }
      _ring(ring).draw(canvas, near: near);
      if (turned) canvas.restore();
      if (near && ring.kind == RingKind.mcmN) {
        _cmgPartners(canvas, ring);
      }
    }
  }

  /// Cdc45 and GINS, bound on the MCM ring's side, complete CMG.
  void _cmgPartners(Canvas canvas, StagedRing ring) {
    final double opacity = ring.opacity * ring.partners;
    if (opacity <= 0) return;
    final Offset c = ring.centre;
    if (opacity < 1) {
      canvas.saveLayer(
        Rect.fromCenter(
          center: c + const Offset(-40, 8),
          width: 64,
          height: 80,
        ),
        Paint()..color = Colors.black.withValues(alpha: opacity),
      );
    }
    // Cdc45 below, the four-subunit GINS above, both on the ring's side.
    molecules.draw(
      canvas,
      c + const Offset(-39, 22),
      const Size(27, 25),
      Color.lerp(inks.helicase, Colors.black, 0.08)!,
      seed: 46,
      channel: false,
      angle: _turned ? math.pi : 0,
    );
    molecules.draw(
      canvas,
      c + const Offset(-40, -6),
      const Size(25, 21),
      Color.lerp(inks.helicase, Colors.white, 0.1)!,
      seed: 53,
      channel: false,
      angle: _turned ? math.pi : 0,
    );
    if (opacity < 1) canvas.restore();
  }

  void _activeSite(
    Canvas canvas,
    Offset p,
    double pulse,
    Color color,
    double opacity,
  ) {
    if (opacity <= 0) return;
    canvas.drawCircle(
      p,
      12,
      _fill
        ..color = Colors.black
        ..shader = ui.Gradient.radial(p, 12, <Color>[
          color.withValues(alpha: (0.1 + pulse * 0.08) * opacity),
          color.withValues(alpha: 0),
        ]),
    );
    _fill.shader = null;
  }

  /// Displaced RNA peels away from the template towards FEN1 as a short,
  /// loose single strand.
  void _flap(Canvas canvas, StagedFlap flap) {
    if (flap.length <= 0 || flap.opacity <= 0) return;
    final Offset toward = flap.towards - flap.base;
    final double reach = toward.distance;
    if (reach < 0.01) return;
    final Offset along = toward / reach;
    final Offset across = Offset(-along.dy, along.dx);
    final double length = math.min(reach * 0.8, flap.length * 3.2);
    final Offset tip = flap.base + along * length + across * length * 0.18;
    final Offset bend =
        flap.base + along * length * 0.45 - across * length * 0.22;
    _backbonePath(
      canvas,
      Path()
        ..moveTo(flap.base.dx, flap.base.dy)
        ..quadraticBezierTo(bend.dx, bend.dy, tip.dx, tip.dy),
      inks.rna,
      opacity: flap.opacity,
    );
    _sphere(canvas, tip, 1.9, inks.rna, opacity: flap.opacity);
  }

  void _nick(Canvas canvas, StagedNick nick) {
    canvas.drawCircle(
      nick.centre,
      7 + 5 * nick.sealed,
      _line
        ..strokeWidth = 1.2 + 0.3 * nick.sealed
        ..color = Color.lerp(
          inks.quiet,
          inks.newDna,
          nick.sealed,
        )!.withValues(alpha: nick.opacity * (1 - 0.4 * nick.sealed)),
    );
  }

  Color _labelColor(SceneInk ink) => switch (ink) {
    SceneInk.ink ||
    SceneInk.quiet ||
    SceneInk.newDna ||
    SceneInk.rna => inks[ink],
    // Proteins are muted; their names are lifted towards the text colour so
    // they stay legible on the dark ground.
    _ => Color.lerp(inks[ink], inks.ink, 0.35)!,
  };

  void _label(Canvas canvas, StagedLabel label) {
    final Color color = _labelColor(label.ink);
    final TextPainter name = _painter(label.text, color, label.size);
    final String? noteText = label.note;
    final TextPainter? note = noteText == null
        ? null
        : _painter(
            noteText,
            inks.quiet,
            StagedLabel.noteSize,
            weight: FontWeight.w400,
          );
    final Rect block = label.block(name.size, note?.size);
    final Offset? target = label.target;
    if (target != null) {
      // The line leaves the words on the side facing what they name, so it
      // never crosses them, and slides round them as the target moves.
      final Offset from = StagedLabel.exit(block, target);
      canvas.drawLine(
        from,
        target,
        _line
          ..strokeWidth = 0.9
          ..color = color.withValues(alpha: 0.6 * label.opacity),
      );
      // Its end, ringed with the ground so it reads on a protein too.
      canvas.drawCircle(
        target,
        2.4,
        _fill..color = inks.ground.withValues(alpha: label.opacity),
      );
      canvas.drawCircle(
        target,
        1.6,
        _fill..color = color.withValues(alpha: label.opacity),
      );
    }
    double left(TextPainter words) =>
        label.centred ? block.center.dx - words.width / 2 : block.left;
    _words(canvas, name, Offset(left(name), block.top), label.opacity);
    if (note != null) {
      _words(
        canvas,
        note,
        Offset(left(note), block.top + name.height),
        label.opacity,
      );
    }
  }

  /// Words laid out once, in the scene's font, and kept.
  TextPainter _painter(
    String text,
    Color color,
    double size, {
    FontWeight weight = FontWeight.w500,
  }) => _textCache.putIfAbsent(
    (text, color, size, weight),
    () => TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: AppTypography.sansFamily,
          fontFamilyFallback: const <String>[
            'Roboto',
            'Helvetica Neue',
            'Arial',
          ],
          fontSize: size,
          fontWeight: weight,
          color: color,
          height: 1.15,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(),
  );

  void _words(
    Canvas canvas,
    TextPainter painter,
    Offset origin,
    double opacity,
  ) {
    if (opacity >= 1) {
      painter.paint(canvas, origin);
      return;
    }
    canvas.saveLayer(
      (origin & painter.size).inflate(2),
      Paint()..color = Colors.black.withValues(alpha: opacity),
    );
    painter.paint(canvas, origin);
    canvas.restore();
  }

  static const double _lattice = 0.5;

  /// A path through [pointAt] from [start] to [end], sampled at fixed
  /// positions on the DNA (every half nucleotide) plus the exact ends. The
  /// samples move with the molecule, never with the camera, so a strand's
  /// outline cannot shimmer as the view pans or a strand grows.
  static Path _trace(
    double start,
    double end,
    Offset Function(double) pointAt,
  ) {
    final Offset startPoint = pointAt(start);
    final Path path = Path()..moveTo(startPoint.dx, startPoint.dy);
    for (
      double i = (start / _lattice).floorToDouble() * _lattice + _lattice;
      i < end;
      i += _lattice
    ) {
      final Offset p = pointAt(i);
      path.lineTo(p.dx, p.dy);
    }
    final Offset endPoint = pointAt(end);
    path.lineTo(endPoint.dx, endPoint.dy);
    return path;
  }

  /// A strand's backbone: one flat stroke in its colour.
  void _backbonePath(
    Canvas canvas,
    Path path,
    Color color, {
    double opacity = 1,
  }) {
    canvas.drawPath(
      path,
      _line
        ..strokeWidth = 2.9
        ..color = color.withValues(alpha: opacity),
    );
  }

  /// A band of the ground under a backbone about to cross in front of the
  /// other strand, so the crossing shows as a gap.
  void _halo(Canvas canvas, Path path) {
    canvas.drawPath(
      path,
      _bar
        ..strokeWidth = 2.9 + 2.2
        ..color = inks.ground,
    );
  }

  /// A base, as a flat bar cut square at both ends: its backbone's bead
  /// covers one, and the other meets its partner's gap.
  void _rod(
    Canvas canvas,
    Offset a,
    Offset b,
    Color color, {
    double width = 2.8,
    double opacity = 1,
  }) {
    canvas.drawLine(
      a,
      b,
      _bar
        ..strokeWidth = width
        ..color = color.withValues(alpha: opacity),
    );
  }

  /// A backbone bead: a flat disc in its strand's colour.
  void _sphere(
    Canvas canvas,
    Offset at,
    double radius,
    Color color, {
    double opacity = 1,
  }) {
    if (opacity <= 0) return;
    canvas.drawCircle(
      at,
      radius,
      _fill..color = color.withValues(alpha: opacity),
    );
  }

  void _arrow(Canvas canvas, Offset from, Offset to, Color color) {
    if (color.a <= 0) return;
    final Offset direction = (to - from) / (to - from).distance;
    final Offset normal = Offset(-direction.dy, direction.dx);
    canvas.drawLine(
      from,
      to,
      _line
        ..strokeWidth = 1.5
        ..color = color,
    );
    canvas.drawPath(
      Path()
        ..moveTo(
          (to - direction * 4 + normal * 3).dx,
          (to - direction * 4 + normal * 3).dy,
        )
        ..lineTo(to.dx, to.dy)
        ..lineTo(
          (to - direction * 4 - normal * 3).dx,
          (to - direction * 4 - normal * 3).dy,
        ),
      _line,
    );
  }

  @override
  bool shouldRepaint(covariant ReplicationScene oldDelegate) =>
      oldDelegate.inks != inks ||
      oldDelegate.showLabels != showLabels ||
      oldDelegate.followCamera != followCamera ||
      oldDelegate.followBlend != followBlend ||
      oldDelegate.reducedMotion != reducedMotion ||
      oldDelegate.molecules != molecules ||
      oldDelegate.timeline != timeline ||
      oldDelegate.at != at;
}
