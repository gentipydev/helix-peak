import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/core/theme/app_theme.dart';
import 'package:helixpeek/features/replication/domain/genome_replication.dart';
import 'package:helixpeek/features/replication/domain/replication_tour.dart';
import 'package:helixpeek/features/replication/presentation/replication_camera.dart';
import 'package:helixpeek/features/replication/presentation/replication_geometry.dart';
import 'package:helixpeek/features/replication/presentation/replication_inks.dart';
import 'package:helixpeek/features/replication/presentation/replication_molecules.dart';
import 'package:helixpeek/features/replication/presentation/replication_scene.dart';
import 'package:helixpeek/features/replication/presentation/replication_staging.dart';

/// A label's line must land on what it names, not beside it or on the next
/// protein. The scene is a pure function of time, so every half second it
/// is drawn with its labels off and with what a label names, and nothing
/// else, in a marker colour; some pixel near the line's end must wear it,
/// shaded or flat. A ring's seams and a protein's outline are its own, so a
/// line that lands in a seam of PCNA still lands on PCNA. While a protein
/// over the line's end is fading in or out, the colours there are blends,
/// and that moment is not judged.
void main() {
  // A tall phone's scene, drawn at twice its size.
  const Size size = Size(376, 562);
  const double ratio = 2;

  testWidgets('every label line lands on what it names', (
    WidgetTester tester,
  ) async {
    late ReplicationInks inks;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.analysis,
        home: Builder(
          builder: (BuildContext context) {
            inks = ReplicationInks.of(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    final ReplicationMolecules molecules = ReplicationMolecules();
    addTearDown(molecules.dispose);
    final double scale = math.min(size.width / 360, size.height / 600);
    final Offset corner = Offset(
      (size.width - 360 * scale) / 2,
      (size.height - 600 * scale) / 2,
    );
    final List<String> faults = <String>[];
    int judged = 0;
    await tester.runAsync(() async {
      for (
        int step = 0;
        step <= ReplicationTimeline.durationSeconds * 2;
        step++
      ) {
        final double s = step / 2;
        final (List<StagedLabel> labels, List<(Offset, Offset)> fading) =
            _stagedAt(s, size);
        final List<StagedLabel> named = <StagedLabel>[
          for (final StagedLabel label in labels)
            if (label.target case final Offset target
                when label.opacity >= 0.95 &&
                    !fading.any(
                      ((Offset, Offset) f) => _inEllipse(target, f.$1, f.$2),
                    ))
              label,
        ];
        // One drawing for each thing named, in the marker colour.
        final Map<SceneInk, Uint8List> drawn = <SceneInk, Uint8List>{};
        for (final StagedLabel label in named) {
          judged++;
          final SceneInk ink = label.names ?? label.ink;
          if (const <SceneInk>[
            SceneInk.ink,
            SceneInk.quiet,
          ].contains(ink)) {
            faults.add('$s s: ${label.key} names no drawn colour ($ink)');
            continue;
          }
          final Uint8List pixels = drawn[ink] ??= await _draw(
            s,
            size * ratio,
            ratio,
            _marked(inks, ink),
            molecules,
          );
          final Offset at = (corner + label.target! * scale) * ratio;
          if (!_landsOn(pixels, size * ratio, at, 3 * scale * ratio)) {
            faults.add('$s s: ${label.key} misses ${ink.name}');
          }
        }
      }
    });
    expect(faults, isEmpty, reason: faults.join('\n'));
    // The tour names something at almost every moment.
    expect(judged, greaterThan(600), reason: 'lines judged');
  });
}

/// The scene's labels at playback second [s], staged as the painter stages
/// them on a canvas of [size], and where a protein fading in or out lies,
/// as an ellipse on the screen.
(List<StagedLabel>, List<(Offset, Offset)>) _stagedAt(double s, Size size) {
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
  final List<(Offset, Offset)> fading = <(Offset, Offset)>[
    for (final StagedItem item in <StagedItem>[
      ...stage.items,
      ...stage.rings,
      ...stage.shared,
    ])
      if (item.opacity < 0.95)
        (
          camera.project(item.centre),
          switch (item) {
                StagedMolecule(:final Size size) => Offset(
                  size.width,
                  size.height,
                ),
                StagedTopo() => const Offset(84, 64),
                _ => const Offset(66, 50),
              } *
              (0.5 * camera.zoom),
        ),
  ];
  return (stage.labels, fading);
}

/// Whether [p] lies in the ellipse at [centre] with semi-axes [half].
bool _inEllipse(Offset p, Offset centre, Offset half) {
  final double x = (p.dx - centre.dx) / half.dx;
  final double y = (p.dy - centre.dy) / half.dy;
  return x * x + y * y < 1;
}

/// The scene at playback second [s], labels off, as RGBA bytes.
Future<Uint8List> _draw(
  double s,
  Size size,
  double ratio,
  ReplicationInks inks,
  ReplicationMolecules molecules,
) async {
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  final Canvas canvas = Canvas(recorder)..scale(ratio);
  ReplicationScene(
    timeline: const ReplicationTimeline(),
    at: () => s / ReplicationTimeline.durationSeconds,
    molecules: molecules,
    inks: inks,
    showLabels: false,
  ).paint(canvas, size / ratio);
  final ui.Picture picture = recorder.endRecording();
  final ui.Image image = await picture.toImage(
    size.width.round(),
    size.height.round(),
  );
  picture.dispose();
  final ByteData data = (await image.toByteData())!;
  image.dispose();
  return data.buffer.asUint8List();
}

/// A colour nothing in the scene wears.
const Color _marker = Color(0xFFFF00FF);

/// [inks] with [ink] alone turned to the marker.
ReplicationInks _marked(ReplicationInks inks, SceneInk ink) {
  Color pick(SceneInk k) => k == ink ? _marker : inks[k];
  return ReplicationInks(
    ground: inks.ground,
    ink: pick(SceneInk.ink),
    quiet: pick(SceneInk.quiet),
    parental: pick(SceneInk.parental),
    newDna: pick(SceneInk.newDna),
    rna: pick(SceneInk.rna),
    helicase: pick(SceneInk.helicase),
    polymerase: pick(SceneInk.polymerase),
    primase: pick(SceneInk.primase),
    rpa: pick(SceneInk.rpa),
    clamp: pick(SceneInk.clamp),
    rfc: pick(SceneInk.rfc),
    nuclease: pick(SceneInk.nuclease),
    ligase: pick(SceneInk.ligase),
    topoisomerase: pick(SceneInk.topoisomerase),
    activeSite: pick(SceneInk.activeSite),
    orc: pick(SceneInk.orc),
    cdc6: pick(SceneInk.cdc6),
    cdt1: pick(SceneInk.cdt1),
  );
}

/// Whether a pixel is the marker, lit, shaded or flat: as red as it is
/// blue, with little green.
bool _isMarker(int r, int g, int b) =>
    r >= 40 &&
    b >= 40 &&
    (r - b).abs() <= 0.2 * math.max(r, b) + 8 &&
    g <= 0.45 * math.min(r, b) + 6;

/// Whether an opaque pixel within [reach] of [at] is the marker.
bool _landsOn(Uint8List pixels, Size size, Offset at, double reach) {
  final int width = size.width.round();
  final int height = size.height.round();
  for (int y = (at.dy - reach).floor(); y <= (at.dy + reach).ceil(); y++) {
    for (int x = (at.dx - reach).floor(); x <= (at.dx + reach).ceil(); x++) {
      if (x < 0 || y < 0 || x >= width || y >= height) continue;
      if ((Offset(x + 0.5, y + 0.5) - at).distance > reach) continue;
      final int i = (y * width + x) * 4;
      if (pixels[i + 3] >= 250 &&
          _isMarker(pixels[i], pixels[i + 1], pixels[i + 2])) {
        return true;
      }
    }
  }
  return false;
}
