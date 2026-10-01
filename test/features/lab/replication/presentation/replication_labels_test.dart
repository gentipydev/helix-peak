import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/core/theme/app_typography.dart';
import 'package:helixpeek/features/lab/replication/domain/genome_replication.dart';
import 'package:helixpeek/features/lab/replication/domain/replication_tour.dart';
import 'package:helixpeek/features/lab/replication/presentation/replication_camera.dart';
import 'package:helixpeek/features/lab/replication/presentation/replication_geometry.dart';
import 'package:helixpeek/features/lab/replication/presentation/replication_staging.dart';

import '../../../gene_lookup/anatomy/anatomy_fixture.dart';

/// A close-up's words must be readable wherever the camera is: none may lie
/// on the DNA, on a protein, on other words or off the frame. The scene is a
/// pure function of time, so it is staged every quarter second and each
/// label is measured in the app's own font, as the scene draws it.
///
/// The whole fork's own words are left out: they sit at the ends of its
/// drawing by design.
void main() {
  setUpAll(loadAppFonts);

  final Map<(String, double), Size> measured = <(String, double), Size>{};
  Size measure(String text, double size) => measured.putIfAbsent(
    (text, size),
    () => (TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: AppTypography.sansFamily,
          fontSize: size,
          fontWeight: FontWeight.w500,
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
  Size Function(String, double) measure,
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
  for (final StagedLabel label in stage.labels) {
    if (!label.key.contains(':') || label.opacity < 0.3) continue;
    final Size box = measure(label.text, label.size);
    final Rect rect =
        (label.at - Offset(label.centred ? box.width / 2 : 0, 0) & box)
            .deflate(1);
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
  return faults.isEmpty ? '' : '${s.toStringAsFixed(2)} s: ${faults.join(', ')}';
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
