part of 'translation_painter.dart';

/// An L-shaped tRNA spans the subunit interface. Its acceptor tips converge
/// at the catalytic centre, while its anticodon stays on its own codon.
final class _Trna {
  const _Trna(this.centre, this.bottom, this.acceptor, this.elbow);
  final double centre;
  final double bottom;
  final Offset acceptor;
  final Offset elbow;
}

final class _Frame {
  _Frame(this.size, this.state)
    : scale = TranslationPainter.viewportScale(size);

  final Size size;
  final TranslationState state;
  final double scale;
  double get width => size.width / scale;
  double get height => math.min(500, size.height / scale);
  Offset get origin => Offset(0, (size.height - height * scale) * 0.5);
  Offset toScreen(Offset p) => p * scale + origin;
  double get cx => width / 2;
  double get mrnaY => height - 90;
  double get lift => (1 - state.largeSubunit) * 48;
  static const double p = TranslationPainter.pitch;

  double xOf(num i) => cx + (i - (state.ribosome + 1)) * p;
  double baseAt(double x) => state.ribosome + 1 + (x - cx) / p;
  double siteCentre(int site) => cx + (site - 1) * 3 * p;
  double baseY(double x) {
    final double outside = ((x - cx).abs() - 104).clamp(0.0, 100.0) / 100;
    return mrnaY + math.sin(outside * math.pi / 2) * 15;
  }

  Rect get largeSubunit => Rect.fromLTWH(cx - 151, mrnaY - 222, 302, 203);
  Rect get smallSubunit => Rect.fromLTWH(cx - 150, mrnaY + 5, 300, 67);
  Offset get ptc => Offset(cx + 12, mrnaY - 123);
  Offset get tunnelExit => Offset(cx - 18, largeSubunit.top + 12);

  _Trna trna(TrnaSlot slot) {
    final bool scanning = state.phase == TranslationPhase.scanning;
    final bool leaving = identical(slot, state.e);
    final double away = 1 - slot.presence;
    // The state's ribosome is fractional during translocation. The codon
    // centre follows its fixed mRNA triplet through all three sites.
    final double relative;
    if (scanning || state.phase == TranslationPhase.joining) {
      relative = 0;
    } else if (state.phase == TranslationPhase.releaseFactor ||
        state.phase == TranslationPhase.release ||
        state.phase == TranslationPhase.dissociation) {
      relative = 0;
    } else {
      final double moving = state.phase == TranslationPhase.translocation
          ? AnatomyMotion.ease(state.phaseProgress)
          : state.phase == TranslationPhase.trnaExit
          ? 1
          : 0;
      relative = (slot.codon - state.codon + 1 - moving) * 3 * p;
    }
    final double centre = cx + relative + (leaving ? -away * 48 : away * 42);
    final double scanLift = scanning
        ? 8 * (1 - AnatomyMotion.ease(state.phaseProgress))
        : 0;
    final double bottom = mrnaY - 20 - away * 62 - scanLift;
    final double site = relative / (3 * p);
    final double reach = site >= 0 ? 12 - site * 38 : 12;
    final Offset acceptor = Offset(centre + reach, bottom - 103);
    final double elbowX =
        centre - 20 + 38 * AnatomyMotion.ease(site.clamp(0.0, 1.0));
    return _Trna(centre, bottom, acceptor, Offset(elbowX, bottom - 72));
  }

  Offset get attachment {
    final TrnaSlot? holder = TranslationPainter._holder(state);
    final Offset from = holder == null ? ptc : trna(holder).acceptor;
    if (state.phase == TranslationPhase.peptideBond && state.a != null) {
      return Offset.lerp(from, trna(state.a!).acceptor, state.chainShift)!;
    }
    return from;
  }

  Path get tunnelPath => Path()
    ..moveTo(ptc.dx, ptc.dy)
    ..cubicTo(
      cx + 6,
      ptc.dy - 30,
      cx - 36,
      tunnelExit.dy + 39,
      tunnelExit.dx,
      tunnelExit.dy,
    );

  Offset inTunnel(double depth) {
    final double packed = depth <= 2
        ? depth * 0.17
        : 0.34 + (depth - 2) / (TranslationTimeline.tunnelCapacity - 2) * 0.66;
    final double u = packed.clamp(0.0, 1.0);
    return _cubic(
      attachment,
      Offset(cx + 8, ptc.dy - 33),
      Offset(cx - 40, tunnelExit.dy + 36),
      tunnelExit,
      u,
    );
  }

  // A stable phase clock means pause and scrubbing freeze the molecular
  // movement too. It is continuous across cycle boundaries, including the
  // peptide transfer and translocation (which have different durations).
  double get motion {
    final double u = state.phaseProgress;
    return switch (state.phase) {
      TranslationPhase.scanning => 3 * u,
      TranslationPhase.joining => 3 + u,
      TranslationPhase.decoding => state.codon + 2 + u * 0.35,
      TranslationPhase.peptideBond => state.codon + 2.35 + u * 0.2,
      TranslationPhase.translocation => state.codon + 2.55 + u * 0.3,
      TranslationPhase.trnaExit => state.codon + 2.85 + u * 0.15,
      TranslationPhase.releaseFactor => state.codon + 2 + u,
      TranslationPhase.release => state.codon + 3 + u,
      TranslationPhase.dissociation => state.codon + 4 + u,
    };
  }

  static Offset _cubic(Offset a, Offset b, Offset c, Offset d, double u) {
    final double v = 1 - u;
    return a * (v * v * v) +
        b * (3 * v * v * u) +
        c * (3 * v * u * u) +
        d * (u * u * u);
  }

  // The liberated chain floats above the machinery. Sampling by arc length
  // keeps neighbours together around bends instead of stretching the bonds.
  late final List<Offset> _trail = _buildTrail();
  late final List<double> _distances = _trailDistances();
  List<Offset> _buildTrail() {
    final double top = tunnelExit.dy;
    final double room = top - 40;
    final List<Offset> points = <Offset>[];
    final List<Offset> controls = <Offset>[
      tunnelExit,
      Offset(cx - 38, top - room * 0.28),
      Offset(cx - 135, top - room * 0.05),
      Offset(cx - 111, top - room * 0.48),
      Offset(cx - 82, top - room * 0.87),
      Offset(cx + 101, top - room * 0.04),
      Offset(cx + 104, top - room * 0.57),
      Offset(cx + 106, top - room * 1.05),
      Offset(cx + 18, top - room * 0.94),
      Offset(cx - 23, top - room * 0.82),
    ];
    for (int i = 0; i <= 90; i++) {
      final double t = i / 90;
      final int segment = math.min(2, (t * 3).floor());
      final int start = segment * 3;
      final Offset at = _cubic(
        controls[start],
        controls[start + 1],
        controls[start + 2],
        controls[start + 3],
        t * 3 - segment,
      );
      final double freedom = math.sin(math.min(1, t * 3) * math.pi / 2);
      points.add(
        at +
            Offset(
              math.sin(t * 9 + motion * 0.72) * 5 * freedom,
              math.sin(t * 12 - motion * 0.58) * 4 * freedom,
            ),
      );
    }
    return points;
  }

  List<double> _trailDistances() {
    final List<double> distances = <double>[0];
    for (int i = 1; i < _trail.length; i++) {
      distances.add(distances.last + (_trail[i] - _trail[i - 1]).distance);
    }
    return distances;
  }

  int shownPast(int trailing) => math.min(trailing, _distances.last ~/ 17);
  Offset chainAt(double depth) => depth < TranslationTimeline.tunnelCapacity
      ? inTunnel(depth)
      : trail(depth - TranslationTimeline.tunnelCapacity);

  Offset trail(double past) {
    final double along = past * 17;
    for (int i = 1; i < _trail.length; i++) {
      if (along <= _distances[i]) {
        return Offset.lerp(
          _trail[i - 1],
          _trail[i],
          (along - _distances[i - 1]) / (_distances[i] - _distances[i - 1]),
        )!;
      }
    }
    return _trail.last;
  }
}
