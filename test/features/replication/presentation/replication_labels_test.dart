import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/core/theme/app_typography.dart';
import 'package:helixpeek/features/replication/domain/genome_replication.dart';
import 'package:helixpeek/features/replication/domain/replication_tour.dart';
import 'package:helixpeek/features/replication/presentation/replication_camera.dart';
import 'package:helixpeek/features/replication/presentation/replication_geometry.dart';
import 'package:helixpeek/features/replication/presentation/replication_staging.dart';

import '../../gene_lookup/anatomy/anatomy_fixture.dart';

/// A close-up's words must be readable wherever the camera is: none may lie
/// on the DNA, on a protein, on other words or off the frame. A label's line
/// may not cross other words or another line, nor pass over a protein other
/// than the one what it names lies in, and a direction arrow may not lie on
/// a protein or the DNA. The scene is a pure function of time, so it is
/// staged every quarter second and each label, name and note, is measured in
/// the app's own font, as the scene draws it.
///
/// The whole fork's own words are left out: they sit at the ends of its
/// drawing by design.
void main() {
  setUpAll(loadAppFonts);

  final Map<(String, double, FontWeight), Size> measured =
      <(String, double, FontWeight), Size>{};
  Size measure(String text, double size, FontWeight weight) =>
      measured.putIfAbsent(
        (text, size, weight),
        () => (TextPainter(
          text: TextSpan(
            text: text,
            style: TextStyle(
              fontFamily: AppTypography.sansFamily,
              fontSize: size,
              fontWeight: weight,
              height: 1.15,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout()).size,
      );

  // A tall phone's scene, and a narrow one that shows only the design width.
  for (final Size size in <Size>[const Size(376, 562), const Size(300, 562)]) {
    test('close-up words keep clear of what they name at '
        '${size.width.toInt()}×${size.height.toInt()}', () {
      final List<String> faults = <String>[];
      for (int step = 0; step <= ReplicationTimeline.durationSeconds * 4; step++) {
        final String fault = _faultsAt(step / 4, size, measure);
        if (fault.isNotEmpty) {
          faults.add(fault);
        }
      }
      expect(faults.take(12), isEmpty, reason: '${faults.length} moments');
    });
  }
}

/// What a close-up label covers at playback second [s], as the painter
/// lays the scene out on a canvas of [size].
String _faultsAt(
  double s,
  Size size,
  Size Function(String, double, FontWeight) measure,
) {
  final ReplicationMoment moment = ReplicationMoment(s);
  final ReplicationFrame frame = moment.frame;
  final ReplicationCamera camera = ReplicationCamera.at(moment);
  final double scale = math.min(size.width / 360, size.height / 600);
  final Rect crop = Rect.lerp(
    const Rect.fromLTWH(0, 27, 360, 523),
    Rect.fromCenter(
      center: const Offset(180, 300),
      width: size.width / scale,
      height: size.height / scale,
    ),
    ((camera.zoom - 1).abs() / 0.4).clamp(0.0, 1.0),
  )!;
  final ReplicationGeometry g = ReplicationGeometry(
    frame,
    top: camera.centre.dy + (crop.top - 300) / camera.zoom,
    bottom: camera.centre.dy + (crop.bottom - 300) / camera.zoom,
  );
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
  );
  // Below the origin the lower fork is the upper one turned about it.
  List<Offset> onScreen(Offset p) => <Offset>[
    camera.project(p),
    if (lower) camera.project(Offset(360 - p.dx, originY * 2 - p.dy)),
  ];

  // Every rung of DNA in view, backbone to backbone.
  final List<Offset> dna = <Offset>[];
  final double top = frame.fork + (g.forkY - g.top) / ReplicationGeometry.pitch;
  for (
    double i = math.max(g.firstVisible, GenomeReplication.origin.toDouble());
    i <= top;
    i += 0.5
  ) {
    for (final bool leading in <bool>[true, false]) {
      final Offset strand = g.template(i, leading: leading);
      final Offset partner = i >= frame.fork
          ? g.template(i, leading: !leading)
          : g.presence(i, leading: leading) > 0.5
          ? g.daughter(i, leading: leading)
          : strand;
      for (final double f in <double>[0, 0.25, 0.5, 0.75, 1]) {
        dna.addAll(
          onScreen(Offset.lerp(strand, partner, f)!).where(crop.contains),
        );
      }
    }
  }

  // Each protein as the ellipse its body fills, without its soft rim.
  final List<(String, Offset, Offset)> proteins = <(String, Offset, Offset)>[];
  void protein(StagedItem item, Offset half, {bool turned = true}) {
    if (item.opacity < 0.4) return;
    final List<Offset> at = turned
        ? onScreen(item.centre)
        : <Offset>[camera.project(item.centre)];
    for (final Offset centre in at) {
      if (crop.contains(centre)) {
        proteins.add((item.key, centre, half * camera.zoom));
      }
    }
  }

  for (final StagedItem item in <StagedItem>[...stage.items, ...stage.rings]) {
    switch (item) {
      case StagedMolecule(:final Size size):
        protein(item, Offset(size.width, size.height) * 0.42);
      case StagedRing(:final RingKind kind):
        protein(item, _ring(kind));
      case StagedTopo():
        protein(item, const Offset(38, 29));
      default:
    }
  }
  for (final StagedItem item in stage.shared) {
    if (item is StagedRing) protein(item, _ring(item.kind), turned: false);
  }

  final List<String> faults = <String>[];
  final List<(String, Rect)> words = <(String, Rect)>[];
  final List<(String, Offset, Offset)> lines = <(String, Offset, Offset)>[];
  for (final StagedLabel label in stage.labels) {
    if (!label.key.contains(':') || label.opacity < 0.3) continue;
    final String? note = label.note;
    final Rect block = label.block(
      measure(label.text, label.size, FontWeight.w500),
      note == null
          ? null
          : measure(note, StagedLabel.noteSize, FontWeight.w400),
    );
    final Rect rect = block.deflate(1);
    if (label.target case final Offset target) {
      lines.add((label.key, StagedLabel.exit(block, target), target));
    }
    // A backbone bead is about 2.2 design units across, before the zoom.
    final Rect clear = rect.inflate(1 + 2.2 * camera.zoom);
    if (dna.any(clear.contains)) {
      faults.add('${label.key} on DNA');
    }
    for (final (String key, Offset centre, Offset half) in proteins) {
      if (_covers(rect, centre, half)) {
        faults.add('${label.key} on $key');
      }
    }
    if (rect.left < 0 || rect.right > 360) {
      faults.add('${label.key} off the frame');
    }
    for (final (String key, Rect other) in words) {
      if (other.overlaps(rect)) {
        faults.add('${label.key} on $key');
      }
    }
    words.add((label.key, rect));
  }

  for (final (String key, Offset from, Offset to) in lines) {
    for (final (String other, Rect rect) in words) {
      if (other != key && _throughRect(from, to, rect)) {
        faults.add('$key line through $other');
      }
    }
    for (final (String other, Offset a, Offset b) in lines) {
      if (other.compareTo(key) > 0 && _cross(from, to, a, b)) {
        faults.add('$key line crosses $other line');
      }
    }
    // What a label names may lie inside a protein, as DNA in a channel does:
    // its line may cross that protein, but no other.
    for (final (String protein, Offset centre, Offset half) in proteins) {
      if (!_inEllipse(to, centre, half) &&
          _overEllipse(from, to, centre, half * 0.85)) {
        faults.add('$key line over $protein');
      }
    }
  }

  // A direction arrow beside an enzyme lies on nothing.
  for (final StagedArrow arrow in stage.arrows) {
    if (!arrow.key.contains(':') || arrow.opacity < 0.3) continue;
    for (final (String protein, Offset centre, Offset half) in proteins) {
      if (_overEllipse(arrow.from, arrow.to, centre, half)) {
        faults.add('${arrow.key} on $protein');
      }
    }
    final double clear = 1 + 2.2 * camera.zoom;
    if (dna.any((Offset p) => _distance(p, arrow.from, arrow.to) < clear)) {
      faults.add('${arrow.key} on DNA');
    }
  }
  return faults.isEmpty ? '' : '${s.toStringAsFixed(2)} s: ${faults.join(', ')}';
}

/// How far [p] is from the segment [a]–[b].
double _distance(Offset p, Offset a, Offset b) {
  final Offset ab = b - a;
  final double length = ab.distanceSquared;
  if (length == 0) return (p - a).distance;
  final double t = (((p - a).dx * ab.dx + (p - a).dy * ab.dy) / length).clamp(
    0.0,
    1.0,
  );
  return (p - (a + ab * t)).distance;
}

/// Whether the segment [a]–[b] passes through [rect].
bool _throughRect(Offset a, Offset b, Rect rect) {
  if (rect.contains(a) || rect.contains(b)) return true;
  final List<Offset> corners = <Offset>[
    rect.topLeft,
    rect.topRight,
    rect.bottomRight,
    rect.bottomLeft,
  ];
  for (int k = 0; k < 4; k++) {
    if (_cross(a, b, corners[k], corners[(k + 1) % 4])) return true;
  }
  return false;
}

/// Whether the segments [a]–[b] and [c]–[d] cross, other than at an end.
bool _cross(Offset a, Offset b, Offset c, Offset d) {
  double side(Offset p, Offset q, Offset r) =>
      (q.dx - p.dx) * (r.dy - p.dy) - (q.dy - p.dy) * (r.dx - p.dx);
  final double d1 = side(c, d, a);
  final double d2 = side(c, d, b);
  final double d3 = side(a, b, c);
  final double d4 = side(a, b, d);
  return d1 * d2 < 0 && d3 * d4 < 0;
}

/// Whether [p] lies in the ellipse at [centre] with semi-axes [half].
bool _inEllipse(Offset p, Offset centre, Offset half) {
  final double x = (p.dx - centre.dx) / half.dx;
  final double y = (p.dy - centre.dy) / half.dy;
  return x * x + y * y < 1;
}

/// Whether the segment [a]–[b] passes over the ellipse at [centre] with
/// semi-axes [half].
bool _overEllipse(Offset a, Offset b, Offset centre, Offset half) {
  Offset unit(Offset p) => Offset(
    (p.dx - centre.dx) / half.dx,
    (p.dy - centre.dy) / half.dy,
  );
  return _distance(Offset.zero, unit(a), unit(b)) < 1;
}

/// A ring's outer half-width, and its half-height seen at its tilt.
Offset _ring(RingKind kind) => switch (kind) {
  RingKind.pcna => const Offset(23.5, 18.4),
  RingKind.mcmN => const Offset(25.5, 18.8),
  RingKind.mcmC => const Offset(28, 21.7),
  RingKind.orc || RingKind.cdc6 => const Offset(24, 20.4),
  RingKind.rfc => const Offset(15.75, 13.5),
};

/// Whether the ellipse at [centre] with semi-axes [half] reaches into
/// [rect].
bool _covers(Rect rect, Offset centre, Offset half) {
  final double x = (centre.dx.clamp(rect.left, rect.right) - centre.dx) / half.dx;
  final double y = (centre.dy.clamp(rect.top, rect.bottom) - centre.dy) / half.dy;
  return x * x + y * y < 1;
}
