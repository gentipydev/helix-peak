import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../../core/theme/nucleotide_colors.dart';
import '../../../../shared/anatomy/anatomy_layout.dart';
import '../../../../shared/helix/helix_geometry.dart';
import '../domain/fidelity.dart';
import '../domain/replication_plan.dart';
import '../domain/replication_timeline.dart';

/// Every colour the replication draws with, from the theme.
@immutable
final class ReplicationInks {
  const ReplicationInks({
    required this.bases,
    required this.backbone,
    required this.fresh,
    required this.rna,
    required this.enzyme,
    required this.enzymeFill,
    required this.mismatch,
    required this.label,
    required this.ground,
  });

  factory ReplicationInks.of(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return ReplicationInks(
      bases: context.nucleotideColors,
      backbone: scheme.onSurfaceVariant,
      fresh: scheme.onSurface,
      rna: scheme.primary,
      enzyme: scheme.outline,
      enzymeFill: scheme.surfaceContainerHigh.withValues(alpha: 0.3),
      mismatch: scheme.error,
      label: scheme.onSurfaceVariant,
      ground: scheme.surface,
    );
  }

  final NucleotideColors bases;

  /// The parental strands' backbones.
  final Color backbone;

  /// The new strands' backbones: brighter than the old.
  final Color fresh;

  /// Primer RNA, in the colour the home helix gives RNA.
  final Color rna;

  final Color enzyme;
  final Color enzymeFill;
  final Color mismatch;
  final Color label;
  final Color ground;

  Color base(String letter) => switch (letter) {
    'A' => bases.adenine,
    'T' => bases.thymine,
    'G' => bases.guanine,
    _ => bases.cytosine,
  };

  Color slot(int slot) => switch (slot) {
    HelixPalette.adenine => bases.adenine,
    HelixPalette.thymine => bases.thymine,
    HelixPalette.guanine => bases.guanine,
    HelixPalette.cytosine => bases.cytosine,
    _ => backbone,
  };

  @override
  bool operator ==(Object other) =>
      other is ReplicationInks &&
      other.bases == bases &&
      other.backbone == backbone &&
      other.fresh == fresh &&
      other.rna == rna &&
      other.enzyme == enzyme &&
      other.enzymeFill == enzymeFill &&
      other.mismatch == mismatch &&
      other.label == label &&
      other.ground == ground;

  @override
  int get hashCode => Object.hash(
    bases,
    backbone,
    fresh,
    rna,
    enzyme,
    enzymeFill,
    mismatch,
    label,
    ground,
  );
}

/// The letter the set piece's site holds at [frame], at [fidelity], or null
/// where nothing is there yet.
String? siteBaseAt(
  ReplicationPlan plan,
  ReplicationFrame frame,
  Fidelity fidelity,
) {
  final bool proofread = fidelity != Fidelity.polymerase;
  final String right = plan.baseAt(plan.setPieceSite);
  final String wrong = plan.setPieceWrong;
  return switch (frame.setPiece) {
    SetPieceStep.retry => proofread ? right : wrong,
    SetPieceStep() => wrong,
    null => frame.setPiecePlayed ? (proofread ? right : wrong) : null,
  };
}

/// The last base of the right fork's leading strand made at [travel], or
/// null before its primer.
int? leadingEnd(ReplicationPlan plan, double travel) {
  final NewPiece lead = plan.rightLeading;
  final int made = plan.extensionAt(lead, travel);
  return made < 0
      ? null
      : lead.fivePrime + ReplicationPlan.primerLength - 1 + made;
}

/// Where the right fork's lagging polymerase is at [travel]: the fragment in
/// hand, and the template base in its active site. Null before the first
/// primer and once the last fragment is done.
(NewPiece, double)? laggingAt(ReplicationPlan plan, double travel) {
  for (final NewPiece f in plan.fragmentsOf(Fork.right)) {
    if (travel >= f.primedAt && travel < f.doneAt) {
      final int made = plan.extensionAt(f, travel);
      return (
        f,
        (f.fivePrime - ReplicationPlan.primerLength + 1 - made).toDouble(),
      );
    }
  }
  return null;
}

// ------------------------------------------------------------ the base view

/// Windows of the record's own helix, built with the shared geometry and
/// kept while they stay where they are: the base view draws two, one at the
/// fork and one at the lagging polymerase.
final class HelixWindow {
  final Map<(int, int, double), HelixModel> _models =
      <(int, int, double), HelixModel>{};

  /// The model of [count] bases from [start], at [radius] pixels.
  HelixModel of(ReplicationPlan plan, int start, int count, double radius) {
    final (int, int, double) key = (start, count, radius);
    final HelixModel? held = _models.remove(key);
    if (held != null) {
      _models[key] = held;
      return held;
    }
    final Uint8List bases = Uint8List(count);
    for (int r = 0; r < count; r++) {
      bases[r] = HelixPalette.ofBase(plan.baseAt(start + r));
    }
    final HelixModel model = HelixModel(
      radius: radius,
      pitch: radius * 2 * HelixModel.pitchPerDiameter,
      rungCount: count,
      sampleCount: 3 * count,
      bases: bases,
    );
    _models[key] = model;
    while (_models.length > 4) {
      _models.remove(_models.keys.first);
    }
    return model;
  }
}

/// The fork at the scale of single bases, drawn on the shared helix.
///
/// The record's own double helix comes in from the right, spinning in place
/// as a topoisomerase lets out the twist the fork winds in, and unzips at the
/// fork: each base moves from its place in the helix to its tile in a flat
/// row exactly as [HelixModel.unzipped] says, by how far behind the fork it
/// is. The leading strand's template lies flat below the fork, the leading
/// strand filling in along it towards the fork. The lagging strand's template
/// leaves the fork upwards and comes back down into the lagging polymerase,
/// which sits beside the fork: the loop. Its new fragment grows down the loop
/// into the polymerase, the way the fork runs. The loop outgrows the view;
/// the view below draws all of it.
class ForkBasePainter extends CustomPainter {
  ForkBasePainter({
    required this.plan,
    required this.timeline,
    required this.at,
    required this.fidelity,
    required this.inks,
    required this.window,
    required this.labels,
    super.repaint,
  });

  final ReplicationPlan plan;
  final ReplicationTimeline timeline;
  final double Function() at;
  final Fidelity fidelity;
  final ReplicationInks inks;
  final HelixWindow window;
  final TextStyle labels;

  /// Bases across the view.
  static const double across = 34;

  /// How many bases behind the fork a strand takes to unwind fully.
  static const double unwinding = 2.5;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) {
      return;
    }
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    _BaseScene(this, size, timeline.stateAt(at())).paint(canvas);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant ForkBasePainter old) =>
      old.plan != plan ||
      old.fidelity != fidelity ||
      old.inks != inks ||
      old.labels != labels;
}

/// One frame of the base view, laid out.
final class _BaseScene {
  _BaseScene(this.painter, this.size, this.frame)
    : plan = painter.plan,
      inks = painter.inks,
      pitch = size.width / ForkBasePainter.across {
    side = pitch * (1 - AnatomyLayout.tileGapRatio);
    radius =
        pitch * HelixModel.basePairsPerTurn / (2 * HelixModel.pitchPerDiameter);
    y0 = size.height * 0.66;
    right = plan.rightFork(frame.travel);
    left = plan.leftFork(frame.travel);
    // The camera opens on the origin, both forks in view, and follows the
    // right fork once the bubble is open.
    final double follow = _smooth(
      ((frame.travel - ReplicationPlan.bubble) / 24).clamp(0.0, 1.0),
    );
    anchorX = _lerp(size.width * 0.5, size.width * 0.6, follow);
    // Past the end of the record the camera stays on its last bases.
    anchorBase = math.min(
      _lerp(plan.origin - 0.5, right + 0.5, follow),
      plan.length - 1 - (size.width - 2 * pitch - anchorX) / pitch,
    );
    final (NewPiece, double)? lagging = laggingAt(plan, frame.travel);
    loop = lagging == null || right > plan.length - 1
        ? null
        : LaggingLoop(
            fork: right,
            polymerase: lagging.$2,
            rightX: xOf(right),
            pitch: pitch,
            rowY: rowA,
          );
  }

  final ForkBasePainter painter;
  final Size size;
  final ReplicationFrame frame;
  final ReplicationPlan plan;
  final ReplicationInks inks;
  final double pitch;
  late final double side;
  late final double radius;
  late final double y0;
  late final double right;
  late final double left;
  late final double anchorBase;
  late final double anchorX;
  late final LaggingLoop? loop;

  /// The rows behind the fork: each template, and its new strand one row in.
  double get rowA => y0 - 2.5 * pitch;
  double get rowB => y0 + 2.5 * pitch;

  double xOf(double b) => anchorX + (b - anchorBase) * pitch;

  /// Whether template A's base [b] hangs in the lagging loop's scheme: it is
  /// between the forks while the lagging polymerase works.
  bool _looped(double b) => loop != null && b > left;

  void paint(Canvas canvas) {
    final double firstSeen = anchorBase - anchorX / pitch - 3;
    final double lastSeen = anchorBase + (size.width - anchorX) / pitch + 3;
    final int start = firstSeen.floor().clamp(0, plan.length - 1);
    final int end = lastSeen.ceil().clamp(0, plan.length - 1);
    // The lagging template beside its polymerase: flat to its left, and up
    // the loop's near leg. It lies far from the fork along the record.
    (int, int)? lagging;
    final LaggingLoop? held = loop;
    if (held != null) {
      final int from = (held.polymerase - held.leftX / pitch - 3).floor().clamp(
        0,
        plan.length - 1,
      );
      final int to = (held.polymerase + rowA / pitch + 3).ceil().clamp(
        0,
        plan.length - 1,
      );
      if (to - from >= 2) {
        lagging = (from, to);
      }
    }
    bool ownedByLagging(double b) =>
        lagging != null && b >= lagging.$1 - 0.5 && b <= lagging.$2 + 0.5;
    if (end - start >= 2) {
      _paintParents(
        canvas,
        start,
        end - start + 1,
        drawA: (double b) => !ownedByLagging(b),
        drawB: true,
      );
    }
    if (lagging != null) {
      _paintParents(
        canvas,
        lagging.$1,
        lagging.$2 - lagging.$1 + 1,
        drawA: ownedByLagging,
        drawB: false,
      );
    }
    _paintNew(canvas, start, end);
    _paintEnzymes(canvas);
    _paintSetPiece(canvas);
  }

  // The two parental strands, as the shared geometry unzips them: strand A
  // where [drawA] says, strand B where [drawB] does.
  void _paintParents(
    Canvas canvas,
    int start,
    int count, {
    required bool Function(double b) drawA,
    required bool drawB,
  }) {
    final HelixModel model = painter.window.of(plan, start, count, radius);
    final double spin =
        (right - start) * 2 * math.pi / HelixModel.basePairsPerTurn;
    final double cr = math.cos(spin);
    final double sr = math.sin(spin);

    final int n = model.pointCount;
    final Float32List px = Float32List(n);
    final Float32List py = Float32List(n);
    final Float32List depth = Float32List(n);
    final Float32List open = Float32List(n);
    final Uint8List shown = Uint8List(n);
    for (int i = 0; i < n; i++) {
      final double b = start + (model.pointAxial[i] + 0.5) * count - 0.5;
      final double u = math.min(
        ((right + 1 - b) / ForkBasePainter.unwinding).clamp(0.0, 1.0),
        ((b - (left - 1)) / ForkBasePainter.unwinding).clamp(0.0, 1.0),
      );
      // The helix spins in place: a base's phase depends only on how far it
      // is from the fork.
      final double c0 = model.pointCos[i] * cr - model.pointSin[i] * sr;
      final double s0 = model.pointSin[i] * cr + model.pointCos[i] * sr;
      final double c = HelixModel.unzipped(c0, model.rowCos[i], u);
      final double s = HelixModel.unzipped(s0, 0, u);
      final bool strandA = model.rowCos[i] < 0;
      shown[i] = (strandA ? drawA(b) : drawB) ? 1 : 0;
      // Behind the fork the two daughters part to make room for the new
      // strands: each parental row a row and a half further out.
      final double part = (strandA ? -1.5 : 1.5) * model.rowPitch * u;
      double x = xOf(b);
      double y = y0 + (c + part) * radius;
      if (strandA && _looped(b)) {
        final Offset on = loop!.placeOf(b, across: y - rowA);
        x = _lerp(x, on.dx, u);
        y = _lerp(y, on.dy, u);
      }
      px[i] = x;
      py[i] = y;
      // Screen x is the axis and y the width, so nearer means larger sin:
      // that keeps the helix right-handed.
      depth[i] = s;
      open[i] = u;
    }

    final int rungBase = 2 * model.sampleCount;
    final List<_Primitive> parts = <_Primitive>[];
    for (int p = 0; p < model.primitiveCount; p++) {
      final int kind = model.primKind[p];
      final int a = model.primStart[p];
      int z = model.primEnd[p];
      if (kind == HelixPrimitiveKind.transcriptSegment ||
          kind == HelixPrimitiveKind.transcriptNode) {
        continue;
      }
      if (kind == HelixPrimitiveKind.rungHalf) {
        // Draw each half-rung once, whole, from its first piece.
        final int within = (a - rungBase) % HelixModel.rungPointStride;
        if (within != 0 && within != HelixModel.rungSegments + 1) {
          continue;
        }
        z = a + HelixModel.rungSegments;
      }
      if (shown[a] == 0 || shown[z] == 0) {
        continue;
      }
      parts.add(_Primitive(p, a, z, (depth[a] + depth[z]) / 2));
    }
    parts.sort((_Primitive x, _Primitive y) => x.depth.compareTo(y.depth));

    final Paint stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final Paint fill = Paint();
    for (final _Primitive part in parts) {
      final Offset a = Offset(px[part.a], py[part.a]);
      final Offset z = Offset(px[part.z], py[part.z]);
      final double u = (open[part.a] + open[part.z]) / 2;
      // Nearer is brighter, in the helix; the flat rows are all at full.
      final double shade = _lerp(0.72 + 0.28 * (part.depth + 1) / 2, 1, u);
      switch (model.primKind[part.index]) {
        case HelixPrimitiveKind.strandSegment:
          stroke
            ..color = Color.lerp(inks.ground, inks.backbone, shade)!
            ..strokeWidth = 2;
          canvas.drawLine(a, z, stroke);
        case HelixPrimitiveKind.node:
          if (u < 0.98) {
            fill.color = inks.slot(model.primPalette[part.index]);
            canvas.drawCircle(a, pitch * 0.26 * (1 - u), fill);
          }
        default:
          _tile(
            canvas,
            fill,
            a,
            z,
            thickness: _lerp(2.6, side, u),
            corner: _lerp(1.3, side * AnatomyLayout.tileRadiusRatio, u),
            color: Color.lerp(
              inks.ground,
              inks.slot(model.primPalette[part.index]),
              shade,
            )!,
          );
      }
    }
  }

  // The new strands, over the templates.
  void _paintNew(Canvas canvas, int start, int end) {
    final double travel = frame.travel;
    final Paint fill = Paint();
    final Paint ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..color = inks.mismatch;
    final Paint spine = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 2
      ..color = inks.fresh;
    final double corner = side * AnatomyLayout.tileRadiusRatio;
    final int? leadEnd = leadingEnd(plan, travel);

    void tile(
      Offset centre,
      String letter,
      Made made, {
      double turn = 0,
      double scale = 1,
      bool wrong = false,
    }) {
      canvas.save();
      canvas.translate(centre.dx, centre.dy);
      canvas.rotate(turn);
      canvas.scale(scale);
      final RRect box = RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset.zero, width: side, height: side),
        Radius.circular(corner),
      );
      fill.color = made == Made.rna ? inks.rna : inks.base(letter);
      canvas.drawRRect(box, fill);
      if (wrong) {
        canvas.drawRRect(box.inflate(1.2), ring);
      }
      canvas.restore();
    }

    // The sense strand, on the lower template: the right fork's leading
    // strand, and the left fork's fragments.
    final double senseY = y0 + 1.5 * pitch;
    int? spineFrom;
    int? spineTo;
    for (int i = start; i <= end; i++) {
      final double x = xOf(i.toDouble());
      Made made = plan.madeAt(NewStrand.sense, i, travel);
      final bool site = i == plan.setPieceSite;
      final String? here = site
          ? siteBaseAt(plan, frame, painter.fidelity)
          : null;
      if (made == Made.none && here == null) {
        continue;
      }
      if (made == Made.none) {
        made = Made.dna;
      }
      spineFrom ??= i;
      spineTo = i;
      if (!site) {
        tile(Offset(x, senseY), plan.baseAt(i), made);
      }
    }
    if (spineFrom != null && spineTo != null) {
      final double y = senseY - side / 2 - 1.5;
      canvas.drawLine(
        Offset(xOf(spineFrom - 0.45), y),
        Offset(xOf(spineTo + 0.45), y),
        spine,
      );
      // The leading strand's direction: its 3' end, at its polymerase.
      if (leadEnd != null && leadEnd == spineTo) {
        _arrow(
          canvas,
          Offset(xOf(leadEnd + 0.95), y),
          direction: 0,
          size: pitch * 0.5,
          color: inks.fresh,
        );
      }
    }

    // The antisense strand, on the upper template: the left fork's leading
    // strand, and the right fork's fragments, in the loop or flat beyond it.
    final LaggingLoop? held = loop;
    final int from = held == null
        ? start
        : math.max(0, (held.polymerase - held.leftX / pitch - 3).floor());
    final int to = held == null ? end : right.floor();
    final List<(Offset, double)> spineOn = <(Offset, double)>[];
    for (int i = from; i <= to && i < plan.length; i++) {
      final Made made = plan.madeAt(NewStrand.antisense, i, travel);
      if (made == Made.none) {
        continue;
      }
      final (Offset centre, double turn) = held != null && _looped(i.toDouble())
          ? held.pairedWith(i.toDouble())
          : (Offset(xOf(i.toDouble()), y0 - 1.5 * pitch), 0.0);
      if (centre.dx < -pitch ||
          centre.dx > size.width + pitch ||
          centre.dy < -pitch) {
        continue;
      }
      tile(centre, plan.partnerAt(i), made, turn: turn);
      spineOn.add((centre, turn));
    }
    // Its backbone runs on the side away from its template.
    for (int k = 1; k < spineOn.length; k++) {
      final (Offset a, double ta) = spineOn[k - 1];
      final (Offset b, double tb) = spineOn[k];
      if ((a - b).distance > pitch * 1.6) {
        continue;
      }
      canvas.drawLine(
        a + _inward(ta) * (side / 2 + 1.5),
        b + _inward(tb) * (side / 2 + 1.5),
        spine,
      );
    }
    // The fragment grows 5' to 3' down the indices: down the loop, into its
    // polymerase.
    if (held != null) {
      final (Offset q, double turn) = held.pairedWith(held.polymerase);
      _arrow(
        canvas,
        q +
            _inward(turn) * (side / 2 + 1.5) +
            _along(turn + math.pi) * (pitch * 0.55),
        direction: turn + math.pi,
        size: pitch * 0.5,
        color: inks.fresh,
      );
    }
  }

  /// The base at the set piece's site, over the polymerase that holds it.
  void _paintSetPiece(Canvas canvas) {
    final String? here = siteBaseAt(plan, frame, painter.fidelity);
    final int site = plan.setPieceSite;
    if (here == null ||
        (frame.setPiece == null &&
            plan.madeAt(NewStrand.sense, site, frame.travel) == Made.none)) {
      return;
    }
    final (Offset shift, double scale, bool wrong) = _setPiece();
    if (scale <= 0.01) {
      return;
    }
    final Offset centre =
        Offset(xOf(site.toDouble()), y0 + 1.5 * pitch) + shift;
    canvas.save();
    canvas.translate(centre.dx, centre.dy);
    canvas.scale(scale);
    final RRect box = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset.zero, width: side, height: side),
      Radius.circular(side * AnatomyLayout.tileRadiusRatio),
    );
    canvas.drawRRect(box, Paint()..color = inks.base(here));
    if (wrong) {
      canvas.drawRRect(
        box.inflate(1.2),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..color = inks.mismatch,
      );
    }
    canvas.restore();
  }

  /// The set piece's tile: its offset from its place, its scale, and whether
  /// it is the wrong base.
  (Offset, double, bool) _setPiece() {
    final bool proofread = painter.fidelity != Fidelity.polymerase;
    final double p = _smooth(frame.setPieceProgress);
    // Stepping back lifts the new strand's end out of the polymerase's
    // building site and into its proofreading site, a base back and up.
    final Offset lifted = Offset(-pitch, -pitch * 0.95);
    return switch (frame.setPiece) {
      SetPieceStep.wrongBase => (Offset.zero, p, true),
      SetPieceStep.stall => (Offset.zero, 1, true),
      SetPieceStep.stepBack =>
        proofread ? (lifted * p, 1, true) : (Offset.zero, 1, true),
      SetPieceStep.excise =>
        proofread ? (lifted, 1 - p, true) : (Offset.zero, 1, true),
      SetPieceStep.retry =>
        proofread ? (Offset.zero, p, false) : (Offset.zero, 1, true),
      null => (Offset.zero, 1, !proofread),
    };
  }

  void _paintEnzymes(Canvas canvas) {
    final double travel = frame.travel;
    final Paint fill = Paint()..color = inks.enzymeFill;
    final Paint edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = inks.enzyme;
    bool onRecord(double b) =>
        b >= -0.5 &&
        b <= plan.length - 0.5 &&
        xOf(b) > -pitch * 2 &&
        xOf(b) < size.width + pitch * 2;

    void enzyme(Offset centre, Size box) {
      final RRect shape = RRect.fromRectAndRadius(
        Rect.fromCenter(center: centre, width: box.width, height: box.height),
        Radius.circular(math.min(box.width, box.height) / 2),
      );
      canvas.drawRRect(shape, fill);
      canvas.drawRRect(shape, edge);
    }

    if (travel <= 0) {
      return;
    }
    // A helicase at each fork, on the leading strand's template, named above
    // the helix.
    if (onRecord(right + 0.5)) {
      final double xr = xOf(right + 0.5);
      enzyme(Offset(xr, y0 + radius * 0.55), Size(pitch * 1.4, radius * 1.1));
      _label(
        canvas,
        'helicase',
        Offset(xr + pitch * 0.4, rowB + side / 2 + 3),
        align: -1,
      );
    }
    if (onRecord(left - 0.5)) {
      enzyme(
        Offset(xOf(left - 0.5), y0 - radius * 0.55),
        Size(pitch * 1.4, radius * 1.1),
      );
    }
    if (travel < ReplicationPlan.bubble) {
      return;
    }

    // A topoisomerase on the duplex ahead.
    if (onRecord(right + 8.5)) {
      final double xt = xOf(right + 8.5);
      final Rect box = Rect.fromCenter(
        center: Offset(xt, y0),
        width: pitch * 1.3,
        height: radius * 2.5,
      );
      canvas.drawArc(box, -math.pi * 0.3, math.pi * 1.6, false, edge);
      _label(canvas, 'topoisomerase', Offset(xt, box.top - 1), above: true);
    }

    // The leading polymerase, at its strand's 3' end: during the set piece,
    // a base on with the wrong base in, and back one while it proofreads.
    final int? end = leadingEnd(plan, travel);
    if (end != null) {
      double lead = end + 0.5;
      if (frame.setPiece case final SetPieceStep step) {
        final double p = _smooth(frame.setPieceProgress);
        lead += painter.fidelity == Fidelity.polymerase
            ? (step == SetPieceStep.wrongBase ? p : 1)
            : switch (step) {
                SetPieceStep.wrongBase => p,
                SetPieceStep.stall => 1,
                SetPieceStep.stepBack => 1 - p,
                SetPieceStep.excise => 0,
                SetPieceStep.retry => p,
              };
      }
      if (onRecord(lead)) {
        final Offset at = Offset(xOf(lead - 0.35), y0 + 1.5 * pitch);
        enzyme(at, Size(pitch * 2.2, pitch * 1.75));
        _label(
          canvas,
          'polymerase',
          Offset(
            math.min(at.dx + pitch, xOf(right + 0.5) - pitch * 0.4),
            rowB + side / 2 + 3,
          ),
          align: 1,
        );
      }
    }

    // The lagging polymerase, where the loop comes back down to the fork.
    final LaggingLoop? held = loop;
    if (held != null) {
      enzyme(
        held.polymeraseAt + Offset(pitch * 0.5, pitch * 0.35),
        Size(pitch * 2.2, pitch * 1.75),
      );
    }
  }

  /// [text] at [at]: centred on it, or with [align] -1 starting there and 1
  /// ending there; above it or below.
  void _label(
    Canvas canvas,
    String text,
    Offset at, {
    bool above = false,
    int align = 0,
  }) {
    final TextPainter label = TextPainter(
      text: TextSpan(
        text: text,
        style: painter.labels.copyWith(color: inks.label),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final double x = switch (align) {
      -1 => at.dx,
      1 => at.dx - label.width,
      _ => at.dx - label.width / 2,
    };
    label.paint(
      canvas,
      Offset(
        x.clamp(0.0, math.max(0, size.width - label.width)),
        above ? at.dy - label.height : at.dy,
      ),
    );
    label.dispose();
  }
}

/// The lagging polymerase's loop at the scale of bases.
///
/// The template leaves the fork straight up, turns over, and comes back down
/// into the polymerase, three bases behind the fork. Beyond the polymerase it
/// lies flat. Along the loop, a base's place is its distance from the fork,
/// counted in bases; across it, the side facing into the loop is the side a
/// flat row faces its partner.
final class LaggingLoop {
  LaggingLoop({
    required this.fork,
    required this.polymerase,
    required this.rightX,
    required this.pitch,
    required this.rowY,
  }) : leftX = rightX - 3 * pitch {
    _radius = (rightX - leftX) / 2;
    _arc = math.pi * _radius;
    final double bases = fork - polymerase + 1;
    _leg = math.max(0, (bases * pitch - _arc) / 2);
  }

  /// The last base the fork has unwound, and the base in the polymerase.
  final double fork;
  final double polymerase;

  final double rightX;
  final double leftX;
  final double pitch;
  final double rowY;

  late final double _radius;
  late final double _arc;
  late final double _leg;

  Offset get polymeraseAt => Offset(leftX, rowY);

  /// Where a point of template base [b] goes, [across] its row from the
  /// row's centre line: on the loop, or flat beyond the polymerase.
  Offset placeOf(double b, {required double across}) {
    if (b < polymerase) {
      return Offset(leftX - (polymerase - b) * pitch, rowY + across);
    }
    final (Offset on, double turn) = _at((fork - b) * pitch);
    return on + _inward(turn) * across;
  }

  /// The new strand's tile paired with template base [b], one row in from
  /// it, and how it is turned.
  (Offset, double) pairedWith(double b) {
    if (b < polymerase) {
      return (Offset(leftX - (polymerase - b) * pitch, rowY + pitch), 0);
    }
    final (Offset on, double turn) = _at((fork - b) * pitch);
    return (on + _inward(turn) * pitch, turn);
  }

  /// The point [s] along the loop from the fork, and how the template is
  /// turned there, read up its indices: 0 is a flat row read left to right.
  /// The loop runs from the fork down the indices, so that is against the
  /// way it runs.
  (Offset, double) _at(double s) {
    if (s <= _leg) {
      return (Offset(rightX, rowY - s), math.pi / 2);
    }
    if (s <= _leg + _arc) {
      final double theta = (s - _leg) / _radius;
      final Offset centre = Offset((rightX + leftX) / 2, rowY - _leg);
      return (
        centre + Offset(_radius * math.cos(theta), -_radius * math.sin(theta)),
        math.pi / 2 - theta,
      );
    }
    return (Offset(leftX, rowY - _leg + (s - _leg - _arc)), -math.pi / 2);
  }
}

// ------------------------------------------------------------ the fork view

/// The fork at the scale of fragments: a base to a pixel or so.
///
/// Drawn in the fork's own frame: the fork stands still near the right and
/// the DNA runs through it. Below, the leading strand runs unbroken from its
/// primer to its polymerase at the fork. Above, the trombone: the lagging
/// template leaves the helicase, loops out and comes back into the lagging
/// polymerase beside it, the growing fragment on the loop's inside, its
/// primer at the far end, its 3' end in the polymerase. Beyond the
/// polymerase the template lies flat with the fragments made before, each
/// sealed to the next, and the stretch still to be copied. When a fragment
/// meets the one before, it replaces that one's primer and ligase seals the
/// nick, here at the polymerase; then the next primer goes down and the loop
/// lets go.
class ForkLoopPainter extends CustomPainter {
  ForkLoopPainter({
    required this.plan,
    required this.timeline,
    required this.at,
    required this.fidelity,
    required this.inks,
    required this.labels,
    super.repaint,
  });

  final ReplicationPlan plan;
  final ReplicationTimeline timeline;
  final double Function() at;
  final Fidelity fidelity;
  final ReplicationInks inks;
  final TextStyle labels;

  /// Pixels to a base.
  static const double scale = 0.8;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) {
      return;
    }
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    _paint(canvas, size, timeline.stateAt(at()));
    canvas.restore();
  }

  void _paint(Canvas canvas, Size size, ReplicationFrame frame) {
    final double travel = frame.travel;
    final double s = scale * size.width / 390;
    // Past the end of the record the camera stays on its last bases, and the
    // fork, gone beyond it, is not drawn.
    final double fork = plan.rightFork(travel);
    final bool onRecord = fork <= plan.length - 1;
    final double right = onRecord ? fork : plan.length - 1.0;
    final double left = plan.leftFork(travel);
    final double forkX = size.width * 0.66;
    final double y0 = size.height * 0.8;
    const double gap = 5;
    final double rowA = y0 - 2 * gap;
    final double rowA2 = y0 - gap;
    final double rowB2 = y0 + gap;
    final double rowB = y0 + 2 * gap;
    double xOf(double b) => forkX + (b - right) * s;
    final double seenFrom = math.max(0, right - forkX / s - 2);
    final double seenTo = math.min(
      plan.length - 1.0,
      right + (size.width - forkX) / s + 2,
    );

    final Paint line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.butt
      ..strokeWidth = 2;

    // The duplex where it is still whole: ahead of the right fork, and
    // beyond the left one. It spins in place ahead of the fork.
    final double phase = right * 2 * math.pi / HelixModel.basePairsPerTurn;
    void duplex(double from, double to) {
      if (to <= from) {
        return;
      }
      for (final double offset in <double>[0, math.pi * 127 / 180]) {
        final Path strand = Path();
        bool first = true;
        for (double x = xOf(from); x <= xOf(to); x += 1) {
          final double b = right + (x - forkX) / s;
          final double y =
              y0 +
              gap *
                  1.6 *
                  math.cos(
                    b * 2 * math.pi / HelixModel.basePairsPerTurn -
                        phase +
                        offset,
                  );
          first ? strand.moveTo(x, y) : strand.lineTo(x, y);
          first = false;
        }
        line.color = inks.backbone;
        canvas.drawPath(strand, line);
      }
    }

    duplex(math.max(seenFrom, right + 0.5), seenTo);
    duplex(seenFrom, math.min(seenTo, left - 0.5));
    final double from = math.max(seenFrom, left);

    // The leading side: template below, the leading strand on it.
    _run(canvas, xOf, from, math.min(right, seenTo), rowB, inks.backbone, line);
    _strand(
      canvas,
      xOf,
      NewStrand.sense,
      from.floor(),
      right.floor(),
      rowB2,
      travel,
      line,
    );
    final int? lead = leadingEnd(plan, travel);
    if (lead != null && lead >= from && lead < plan.length) {
      _arrow(
        canvas,
        Offset(xOf(lead + 1) + 4, rowB2),
        direction: 0,
        size: 5,
        color: inks.fresh,
      );
    }
    if (right - from > 60) {
      _label(
        canvas,
        size,
        'leading strand',
        Offset(xOf(from) + 4, rowB + 4),
        left: true,
      );
    }

    // The lagging side.
    final (NewPiece, double)? lagging = onRecord
        ? laggingAt(plan, travel)
        : null;
    if (lagging == null) {
      // Before the first primer, and once the last fragment is sealed, the
      // template and whatever is made on it lie flat.
      _run(
        canvas,
        xOf,
        from,
        math.min(right, seenTo),
        rowA,
        inks.backbone,
        line,
      );
      _strand(
        canvas,
        xOf,
        NewStrand.antisense,
        from.floor(),
        right.floor(),
        rowA2,
        travel,
        line,
      );
    } else {
      final double q = lagging.$2;
      final double polymeraseX = forkX - 12;
      double flat(double b) => polymeraseX - (q - b) * s;
      final double flatFrom = math.max(0, q - polymeraseX / s - 2);
      _run(canvas, flat, flatFrom, q - 1, rowA, inks.backbone, line);
      _strand(
        canvas,
        flat,
        NewStrand.antisense,
        flatFrom.floor(),
        q.floor() - 1,
        rowA2,
        travel,
        line,
      );

      // The loop: out of the helicase, round, and back into the polymerase.
      final double length = (right - q + 1) * s;
      final _Round round = _Round(
        start: Offset(forkX, rowA),
        end: Offset(polymeraseX, rowA),
        length: length,
      );
      line.color = inks.backbone;
      canvas.drawPath(round.path(0, length), line);
      // The fragment in hand, on the loop's inside: primer and DNA.
      for (int i = q.ceil(); i <= right.floor(); i++) {
        final Made made = plan.madeAt(NewStrand.antisense, i, travel);
        if (made == Made.none) {
          continue;
        }
        final double at = (right - i) * s;
        line.color = made == Made.rna ? inks.rna : inks.fresh;
        canvas.drawPath(round.path(at, at + s, inset: gap), line);
      }
      // Its 3' end, at the polymerase, pointing the way it grows: down the
      // loop, the same way as the fork.
      final (Offset tip, double turn) = round.at(length, inset: gap);
      _arrow(
        canvas,
        tip + _along(turn + math.pi) * 3,
        direction: turn + math.pi,
        size: 5,
        color: inks.fresh,
      );
      final Rect bounds = round.bounds;
      _label(
        canvas,
        size,
        'lagging strand, looped',
        Offset(bounds.left - 6, math.max(0, bounds.top)),
        right: true,
      );
      _enzyme(canvas, Offset(polymeraseX + 2, rowA + 3), const Size(15, 11));
    }
    if (onRecord) {
      // The leading polymerase and the helicase, at the fork.
      _enzyme(canvas, Offset(forkX - 3, rowB2 - 1), const Size(15, 11));
      _enzyme(canvas, Offset(forkX + 4, y0), const Size(9, 17));
    }
  }

  /// A plain strand from [from] to [to].
  void _run(
    Canvas canvas,
    double Function(double) xOf,
    double from,
    double to,
    double y,
    Color color,
    Paint line,
  ) {
    line.color = color;
    canvas.drawLine(Offset(xOf(from), y), Offset(xOf(to + 0.5), y), line);
  }

  /// The made stretches of a new strand along a row: DNA, and primer RNA,
  /// with a notch at each nick no ligase has sealed.
  void _strand(
    Canvas canvas,
    double Function(double) xOf,
    NewStrand strand,
    int from,
    int to,
    double y,
    double travel,
    Paint line,
  ) {
    final int lo = from.clamp(0, plan.length - 1);
    final int hi = to.clamp(0, plan.length - 1);
    int i = lo;
    while (i <= hi) {
      final Made made = plan.madeAt(strand, i, travel);
      int j = i;
      while (j + 1 <= hi &&
          plan.madeAt(strand, j + 1, travel) == made &&
          !plan.nickAbove(strand, j, travel)) {
        j++;
      }
      if (made != Made.none) {
        line.color = made == Made.rna ? inks.rna : inks.fresh;
        final bool nick = plan.nickAbove(strand, j, travel);
        canvas.drawLine(
          Offset(xOf(i.toDouble()), y),
          Offset(xOf(j + 1.0) - (nick ? 1.5 : 0), y),
          line,
        );
      }
      i = j + 1;
    }
  }

  void _enzyme(Canvas canvas, Offset centre, Size box) {
    final RRect shape = RRect.fromRectAndRadius(
      Rect.fromCenter(center: centre, width: box.width, height: box.height),
      Radius.circular(math.min(box.width, box.height) / 2),
    );
    canvas.drawRRect(shape, Paint()..color = inks.enzymeFill);
    canvas.drawRRect(
      shape,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = inks.enzyme,
    );
  }

  void _label(
    Canvas canvas,
    Size size,
    String text,
    Offset at, {
    bool left = false,
    bool right = false,
  }) {
    final TextPainter label = TextPainter(
      text: TextSpan(
        text: text,
        style: labels.copyWith(color: inks.label),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final double x = left
        ? at.dx
        : right
        ? at.dx - label.width
        : at.dx - label.width / 2;
    label.paint(
      canvas,
      Offset(x.clamp(2.0, math.max(2.0, size.width - label.width - 2)), at.dy),
    );
    label.dispose();
  }

  @override
  bool shouldRepaint(covariant ForkLoopPainter old) =>
      old.plan != plan ||
      old.fidelity != fidelity ||
      old.inks != inks ||
      old.labels != labels;
}

/// A loop of a given length from [start] round to [end], both on one row:
/// nearly a whole circle, standing on the row, its two ends a little apart
/// where it meets it.
final class _Round {
  _Round({required this.start, required this.end, required this.length}) {
    final double chord = (start.dx - end.dx).abs();
    // The radius that leaves an arc [length] long once the chord's gap is
    // cut out of the circle: a few rounds of r = length / (2π - the cut).
    double r = math.max(chord / 2 + 0.5, length / (2 * math.pi));
    for (int k = 0; k < 8; k++) {
      final double cut = 2 * math.asin((chord / (2 * r)).clamp(0.0, 1.0));
      r = math.max(chord / 2 + 0.5, length / (2 * math.pi - cut));
    }
    _radius = r;
    _cut = 2 * math.asin((chord / (2 * r)).clamp(0.0, 1.0));
    final double depth = math.sqrt(math.max(0, r * r - chord * chord / 4));
    _centre = Offset((start.dx + end.dx) / 2, start.dy - depth);
  }

  final Offset start;
  final Offset end;
  final double length;

  late final double _radius;
  late final double _cut;
  late final Offset _centre;

  Rect get bounds => Rect.fromCircle(center: _centre, radius: _radius);

  /// The point [s] along, [inset] towards the inside, and the turn there,
  /// read against the way the loop runs, as [LaggingLoop] reads it.
  (Offset, double) at(double s, {double inset = 0}) {
    final double t = length <= 0 ? 0 : (s / length).clamp(0.0, 1.0);
    // From the start up the right side, over the top and down the left: the
    // angle falls as it runs.
    final double from = math.pi / 2 - _cut / 2;
    final double angle = from - t * (2 * math.pi - _cut);
    final Offset on =
        _centre + Offset(_radius * math.cos(angle), _radius * math.sin(angle));
    // Read against the way it runs, the angle rises: the turn is that
    // tangent.
    final double turn = angle + math.pi / 2;
    return (on + _inward(turn) * inset, turn);
  }

  Path path(double from, double to, {double inset = 0}) {
    final Path path = Path();
    final int steps = math.max(2, ((to - from) / 2).ceil());
    for (int k = 0; k <= steps; k++) {
      final (Offset p, _) = at(from + (to - from) * k / steps, inset: inset);
      k == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    return path;
  }
}

// ------------------------------------------------------------- the gene bar

/// The whole record, end to end: the bubble between the forks, what each new
/// strand has of the record so far, and the stretch the views above show.
class GeneBarPainter extends CustomPainter {
  GeneBarPainter({
    required this.plan,
    required this.timeline,
    required this.at,
    required this.inks,
    super.repaint,
  });

  final ReplicationPlan plan;
  final ReplicationTimeline timeline;
  final double Function() at;
  final ReplicationInks inks;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) {
      return;
    }
    final ReplicationFrame frame = timeline.stateAt(at());
    final double travel = frame.travel;
    const double pad = 12;
    final double width = size.width - 2 * pad;
    final double y0 = size.height / 2;
    double xOf(double b) => pad + b / plan.length * width;
    final double right = plan.rightFork(travel).clamp(-1.0, plan.length - 1.0);
    final double left = plan.leftFork(travel).clamp(0.0, plan.length * 1.0);

    final Paint line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = inks.backbone;
    // Outside the bubble the two strands are paired; inside it they part.
    const double apart = 5;
    final Path top = Path()
      ..moveTo(xOf(0), y0 - 1.5)
      ..lineTo(xOf(left), y0 - 1.5)
      ..lineTo(xOf(left) + 3, y0 - apart)
      ..lineTo(xOf(right + 1) - 3, y0 - apart)
      ..lineTo(xOf(right + 1), y0 - 1.5)
      ..lineTo(xOf(plan.length.toDouble()), y0 - 1.5);
    final Path bottom = Path()
      ..moveTo(xOf(0), y0 + 1.5)
      ..lineTo(xOf(left), y0 + 1.5)
      ..lineTo(xOf(left) + 3, y0 + apart)
      ..lineTo(xOf(right + 1) - 3, y0 + apart)
      ..lineTo(xOf(right + 1), y0 + 1.5)
      ..lineTo(xOf(plan.length.toDouble()), y0 + 1.5);
    canvas.drawPath(top, line);
    canvas.drawPath(bottom, line);

    // Each new strand, pixel by pixel: what is made there.
    final Paint mark = Paint()..strokeWidth = 1.5;
    for (int px = 0; px < width.floor(); px++) {
      final int i = (px / width * plan.length).floor().clamp(
        0,
        plan.length - 1,
      );
      for (final (NewStrand strand, double y) in <(NewStrand, double)>[
        (NewStrand.antisense, y0 - apart + 2.5),
        (NewStrand.sense, y0 + apart - 2.5),
      ]) {
        final Made made = plan.madeAt(strand, i, travel);
        if (made == Made.none) {
          continue;
        }
        mark.color = made == Made.rna ? inks.rna : inks.fresh;
        canvas.drawLine(Offset(pad + px, y), Offset(pad + px + 1, y), mark);
      }
    }

    // The origin.
    final Paint tick = Paint()
      ..strokeWidth = 1
      ..color = inks.label;
    final double xo = xOf(plan.origin.toDouble());
    canvas.drawLine(
      Offset(xo, y0 - apart - 4),
      Offset(xo, y0 - apart - 1),
      tick,
    );
  }

  @override
  bool shouldRepaint(covariant GeneBarPainter old) =>
      old.plan != plan || old.inks != inks;
}

// ------------------------------------------------------------------ helpers

final class _Primitive {
  const _Primitive(this.index, this.a, this.z, this.depth);

  final int index;
  final int a;
  final int z;
  final double depth;
}

/// The unit vector a path turned by [turn] runs along.
Offset _along(double turn) => Offset(math.cos(turn), math.sin(turn));

/// The unit vector into a loop turned by [turn]: for a flat row read left to
/// right, down, the way a row faces its partner below.
Offset _inward(double turn) => Offset(-math.sin(turn), math.cos(turn));

double _lerp(double a, double b, double t) => a + (b - a) * t;

double _smooth(double t) {
  final double c = t.clamp(0.0, 1.0);
  return c * c * (3 - 2 * c);
}

void _tile(
  Canvas canvas,
  Paint fill,
  Offset a,
  Offset z, {
  required double thickness,
  required double corner,
  required Color color,
}) {
  final Offset along = z - a;
  final double length = along.distance;
  if (length < 0.01) {
    return;
  }
  canvas.save();
  canvas.translate((a.dx + z.dx) / 2, (a.dy + z.dy) / 2);
  canvas.rotate(math.atan2(along.dy, along.dx));
  fill.color = color;
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset.zero, width: length, height: thickness),
      Radius.circular(math.min(corner, math.min(length, thickness) / 2)),
    ),
    fill,
  );
  canvas.restore();
}

/// An arrowhead with its tip at [tip], pointing along [direction].
void _arrow(
  Canvas canvas,
  Offset tip, {
  required double direction,
  required double size,
  required Color color,
}) {
  final Offset back = _along(direction) * -size;
  final Offset wide = _inward(direction) * (size * 0.6);
  final Path head = Path()
    ..moveTo(tip.dx, tip.dy)
    ..lineTo(tip.dx + back.dx + wide.dx, tip.dy + back.dy + wide.dy)
    ..lineTo(tip.dx + back.dx - wide.dx, tip.dy + back.dy - wide.dy)
    ..close();
  canvas.drawPath(head, Paint()..color = color);
}
