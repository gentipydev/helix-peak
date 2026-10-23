import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../domain/zoom_camera.dart';
import '../domain/zoom_depth.dart';
import 'scenes/band_scene.dart';
import 'scenes/body_scene.dart';
import 'scenes/cell_scene.dart';
import 'scenes/chromosome_scene.dart';
import 'scenes/dna_scene.dart';
import 'scenes/gene_scene.dart';
import 'scenes/nucleus_scene.dart';
import 'scenes/organ_scene.dart';
import 'scenes/tissue_scene.dart';
import 'scenes/zoom_scene.dart';
import 'scenes/zoom_subject.dart';
import 'zoom_inks.dart';

/// The nine scenes of one protein's zoom, and the camera that nests them.
final class ZoomStage {
  ZoomStage(this.subject)
    : scenes = <ZoomScene>[
        BodyScene(subject),
        OrganScene(subject),
        TissueScene(subject),
        CellScene(subject),
        NucleusScene(subject),
        ChromosomeScene(subject),
        BandScene(subject),
        GeneScene(subject),
        DnaScene(subject),
      ] {
    camera = ZoomCamera(
      subject.depth,
      portalOf: (ZoomStop stop) => scenes[stop.index].portal,
    );
  }

  final ZoomSubject subject;
  final List<ZoomScene> scenes;
  late final ZoomCamera camera;

  ZoomDepth get depth => subject.depth;

  /// The scenes on screen at depth [d], each with how much of it shows.
  List<(ZoomScene, ZoomView, double)> visible(double d, Size size) {
    final (ZoomView parent, ZoomView child) = camera.at(d, size);
    final ZoomScene leaving = scenes[parent.stop.index];
    final ZoomScene entering = scenes[child.stop.index];
    return <(ZoomScene, ZoomView, double)>[
      (leaving, parent, leaving.asParent(parent.progress)),
      (entering, child, entering.asChild(child.progress)),
    ];
  }

  /// The frames the scenes on screen at depth [d] are drawn with, the
  /// ones too faint to see left out.
  List<(ZoomScene, ZoomFrame)> frames(
    double d,
    Size size,
    ZoomInks inks, {
    double clock = 0,
    double dwell = ZoomFrame.settled,
    double unzip = 0,
    TextStyle labels = const TextStyle(fontSize: 12),
  }) => <(ZoomScene, ZoomFrame)>[
    for (final (ZoomScene scene, ZoomView view, double opacity) in visible(
      d,
      size,
    ))
      if (opacity >= 0.005)
        (
          scene,
          ZoomFrame(
            view: view,
            size: size,
            opacity: opacity,
            inks: inks,
            clock: clock,
            dwell: dwell,
            unzip: unzip,
            labels: labels,
          ),
        ),
  ];

  /// What the view shows at depth [d], by key, without drawing it.
  ZoomStaging stage(double d, Size size, ZoomInks inks, {double clock = 0}) {
    final ZoomStaging staging = ZoomStaging();
    for (final (ZoomScene scene, ZoomFrame frame) in frames(
      d,
      size,
      inks,
      clock: clock,
    )) {
      scene.stage(frame, staging);
    }
    return staging;
  }

  /// Whether anything on screen at depth [d] moves on its own, [dwell]
  /// seconds after the depth came to rest.
  bool wantsClock(double d, Size size, ZoomInks inks, {required double dwell}) {
    for (final (ZoomScene scene, ZoomFrame frame) in frames(
      d,
      size,
      inks,
      dwell: dwell,
    )) {
      if (scene.wantsClock(frame)) {
        return true;
      }
    }
    return false;
  }

  /// Which of its anchors each anchored callout on screen at depth [d] is
  /// set at, at rest at the stop that shows it, by key; where none had room
  /// there, which of [placePlate]'s own places it took, as -1 less its
  /// index (-1 the first). A plate keeps the place it has at rest for the
  /// whole of the steps either side, so it never jumps from one to another
  /// as the view moves. Only the stops either side of [d] are laid out:
  /// their scenes are the ones being drawn.
  Map<String, int> restingAnchors(
    double d,
    Size size,
    ZoomInks inks,
    TextStyle labels,
  ) {
    final (ZoomView parent, ZoomView child) = camera.at(d, size);
    return <String, int>{
      for (final ZoomStop stop in <ZoomStop>{parent.stop, child.stop})
        ...(_resting[(stop, size, labels)] ??= _restingAt(
          stop,
          size,
          inks,
          labels,
        )),
    };
  }

  Map<String, int> _restingAt(
    ZoomStop stop,
    Size size,
    ZoomInks inks,
    TextStyle labels,
  ) {
    final Map<String, int> out = <String, int>{};
    final List<ZoomCallout> callouts = stage(
      depth.depthOf(stop),
      size,
      inks,
    ).callouts;
    final List<Rect> placed = <Rect>[
      ...rowPlates(callouts, labels, inks, size).values,
      for (final RingPlate r
          in ringPlates(callouts, labels, inks, size).values)
        r.plate,
    ];
    for (final ZoomCallout c in callouts) {
      if (c.row != null || c.ring != null) {
        continue;
      }
      final TextPainter text = calloutText(c, labels, inks, size);
      final (Rect plate, int anchor) = placePlateAt(
        c.target,
        text.size,
        size,
        placed,
        anchors: c.anchors,
        flush: c.flush,
      );
      text.dispose();
      placed.add(plate);
      if (c.anchors.isNotEmpty) {
        out[c.key] = anchor;
      }
    }
    return out;
  }

  final Map<(ZoomStop, Size, TextStyle), Map<String, int>> _resting =
      <(ZoomStop, Size, TextStyle), Map<String, int>>{};

  /// Where the names set round a shape on screen at depth [d] go
  /// ([ZoomCallout.ring]), by key: as they are set at rest at the stop
  /// either side ([ringHolds]), the band, row and lines each was given there
  /// held for the whole of the steps either side, so none jumps from one
  /// side to another as the view moves. [callouts] are the ones staged at
  /// [d], where the caller has them.
  Map<String, RingPlate> ringsAt(
    double d,
    Size size,
    ZoomInks inks,
    TextStyle labels, [
    List<ZoomCallout>? callouts,
  ]) {
    final (double, Size, TextStyle) key = (d, size, labels);
    if (_ringsKey == key) {
      return _rings;
    }
    final (ZoomView parent, ZoomView child) = camera.at(d, size);
    final Map<String, RingHold> held = <String, RingHold>{
      for (final ZoomStop stop in <ZoomStop>{parent.stop, child.stop})
        ...(_ringHolds[(stop, size, labels)] ??= ringHolds(
          stage(depth.depthOf(stop), size, inks).callouts,
          labels,
          inks,
          size,
        )),
    };
    _ringsKey = key;
    return _rings = ringPlates(
      callouts ?? stage(d, size, inks).callouts,
      labels,
      inks,
      size,
      held: held,
    );
  }

  final Map<(ZoomStop, Size, TextStyle), Map<String, RingHold>> _ringHolds =
      <(ZoomStop, Size, TextStyle), Map<String, RingHold>>{};
  (double, Size, TextStyle)? _ringsKey;
  Map<String, RingPlate> _rings = const <String, RingPlate>{};

  final Set<ZoomStop> _prepared = <ZoomStop>{};

  /// Whether every scene has built what it caches.
  bool get prepared => _prepared.length == scenes.length;

  /// Builds what the scene at [stop] caches, the first time it is asked.
  void prepare(ZoomStop stop, ZoomInks inks) {
    if (_prepared.add(stop)) {
      scenes[stop.index].prepare(inks);
    }
  }

  /// The stop nearest [from] whose scene has not built what it caches, the
  /// deeper first of two as near; null once every scene has.
  ZoomStop? unprepared(ZoomStop from) {
    for (int reach = 0; reach < scenes.length; reach++) {
      for (final int i in <int>[from.index + reach, from.index - reach]) {
        if (i >= 0 &&
            i < scenes.length &&
            !_prepared.contains(ZoomStop.values[i])) {
          return ZoomStop.values[i];
        }
      }
    }
    return null;
  }

  /// How much of the body's credit shows at depth [d]: at the body, and
  /// going over the first stretch of the way out, as a name does.
  double creditAt(double d) {
    final (int k, double s) = depth.segmentAt(d);
    return k == ZoomStop.body.index ? 1 - smoothstep(s / around) : 0;
  }
}

/// A continuous zoom from a body to its DNA: the stop being left and the
/// one being entered, nested where the next one lies. Drawn again only when
/// the depth moves: what moves on its own, and the names, are
/// [ZoomOverlayPainter]'s, on the layer above.
class ZoomPainter extends CustomPainter {
  ZoomPainter({
    required this.stage,
    required this.at,
    required this.inks,
    required this.labels,
    this.unzip,
    super.repaint,
  });

  final ZoomStage stage;
  final double Function() at;

  /// How far the helix is unzipped as the walk opens.
  final double Function()? unzip;
  final ZoomInks inks;
  final TextStyle labels;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) {
      return;
    }
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    for (final (ZoomScene scene, ZoomFrame frame) in stage.frames(
      at(),
      size,
      inks,
      labels: labels,
      unzip: unzip?.call() ?? 0,
    )) {
      if (frame.opacity < 0.995) {
        canvas.saveLayer(
          Offset.zero & size,
          Paint()..color = Color.fromRGBO(0, 0, 0, frame.opacity),
        );
        scene.paint(canvas, frame);
        canvas.restore();
      } else {
        scene.paint(canvas, frame);
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant ZoomPainter old) =>
      old.stage != stage || old.inks != inks || old.labels != labels;
}

/// What lies over the scenes: what moves on its own at rest (each scene's
/// [ZoomScene.paintAmbient], which fades itself with its scene), the names
/// of what the zoom follows, the scale bar, and at the body the credit for
/// what it is drawn from.
class ZoomOverlayPainter extends CustomPainter {
  ZoomOverlayPainter({
    required this.stage,
    required this.at,
    required this.inks,
    required this.labels,
    required this.caption,
    required this.credit,
    this.clock,
    this.dwell,
    this.unzip,
    super.repaint,
  });

  final ZoomStage stage;
  final double Function() at;
  final double Function()? clock;
  final double Function()? dwell;
  final double Function()? unzip;
  final ZoomInks inks;
  final TextStyle labels;

  /// The style the credit is set in: the app's small print.
  final TextStyle caption;

  /// The body's credit: who drew it and whose data lights it.
  final String credit;

  /// How far a name, the scale bar and the credit keep from the canvas's
  /// edges.
  static const double margin = 8;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) {
      return;
    }
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    final double d = at();
    for (final (ZoomScene scene, ZoomFrame frame) in stage.frames(
      d,
      size,
      inks,
      clock: clock?.call() ?? 0,
      dwell: dwell?.call() ?? ZoomFrame.settled,
      unzip: unzip?.call() ?? 0,
      labels: labels,
    )) {
      scene.paintAmbient(canvas, frame);
    }
    final ZoomStaging staging = stage.stage(d, size, inks);
    // The names set in rows and round a shape first, so the others keep
    // clear of them.
    final Map<String, Rect> rows = rowPlates(
      staging.callouts,
      labels,
      inks,
      size,
    );
    final Map<String, RingPlate> rings = stage.ringsAt(
      d,
      size,
      inks,
      labels,
      staging.callouts,
    );
    final List<Rect> placed = <Rect>[
      ...rows.values,
      for (final RingPlate r in rings.values) r.plate,
    ];
    for (final ZoomCallout callout in staging.callouts) {
      final RingPlate? ring = rings[callout.key];
      final Rect plate = _callout(
        canvas,
        size,
        d,
        callout,
        placed,
        rows[callout.key] ?? ring?.plate,
        ring?.wrapped ?? false,
      );
      if (callout.row == null && callout.ring == null) {
        placed.add(plate);
      }
    }
    final Rect bar = _scaleBar(canvas, size, d);
    _credit(canvas, size, d, bar);
    canvas.restore();
  }

  /// A name on a plate, beside what it names or where its row [sets] it,
  /// with a line that lands on what it names.
  Rect _callout(
    Canvas canvas,
    Size size,
    double d,
    ZoomCallout callout,
    List<Rect> placed, [
    Rect? sets,
    bool wrapped = false,
  ]) {
    final TextPainter text = calloutText(
      callout,
      labels,
      inks,
      size,
      wrapped: wrapped,
    );
    final Rect plate =
        sets ??
        calloutPlate(
          stage,
          d,
          callout,
          text.size,
          size,
          placed,
          inks,
          labels,
        );
    final Offset target = callout.target;
    final (Offset from, Offset _) = lineFrom(plate, target);
    final Paint line = Paint()
      ..strokeWidth = 1.2
      ..color = (callout.quiet ? inks.label : inks.mark).withValues(
        alpha: callout.opacity,
      );
    canvas.drawLine(from, target, line);
    canvas.drawCircle(target, 2.6, line);
    canvas.drawRRect(
      RRect.fromRectAndRadius(plate, const Radius.circular(6)),
      Paint()..color = inks.raised.withValues(alpha: 0.88 * callout.opacity),
    );
    text.paint(
      canvas,
      Offset(plate.left + plateTextPadding, plate.top + plateTextPadding / 2),
    );
    text.dispose();
    return plate;
  }

  /// The scale bar at the lower left, and the box it takes.
  Rect _scaleBar(Canvas canvas, Size size, double d) {
    final (double pixels, String label) = scaleBarAt(stage.depth, d, size);
    const double left = scaleBarLeft;
    final double y = size.height - 18;
    final TextPainter measure = TextPainter(
      text: TextSpan(
        text: label,
        // Its figures count as the bar glides: each as wide as the next, so
        // the words do not shuffle.
        style: labels.copyWith(
          color: inks.label,
          fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final Rect box = scaleBarBox(pixels, measure.size, size);
    canvas.drawRRect(
      RRect.fromRectAndRadius(box, const Radius.circular(6)),
      Paint()..color = inks.ground.withValues(alpha: 0.8),
    );
    final Paint bar = Paint()
      ..strokeWidth = 2
      ..color = inks.label;
    canvas.drawLine(Offset(left, y), Offset(left + pixels, y), bar);
    canvas.drawLine(Offset(left, y - 4), Offset(left, y + 4), bar);
    canvas.drawLine(
      Offset(left + pixels, y - 4),
      Offset(left + pixels, y + 4),
      bar,
    );
    measure.paint(canvas, Offset(left, y - 8 - measure.height));
    measure.dispose();
    return box;
  }

  /// The credit at the lower right while the body shows, on a second line
  /// where one would meet the scale bar.
  void _credit(Canvas canvas, Size size, double d, Rect bar) {
    final double shown = stage.creditAt(d);
    if (shown <= 0 || credit.isEmpty) {
      return;
    }
    final Rect box = creditBox(credit, caption, size, bar);
    final TextPainter text = creditText(credit, caption, size, bar, shown);
    text.paint(canvas, box.topLeft);
    text.dispose();
  }

  @override
  bool shouldRepaint(covariant ZoomOverlayPainter old) =>
      old.stage != stage ||
      old.inks != inks ||
      old.labels != labels ||
      old.caption != caption ||
      old.credit != credit;
}

/// Where the scale bar starts, from the canvas's left edge.
const double scaleBarLeft = 16;

/// The scale bar's length in pixels and its label at depth [d] on a canvas
/// of [size].
///
/// At a stop it is the round length [scaleBar] picks for the view there.
/// Between two stops it glides from the one stop's length on screen to the
/// next one's as the depth moves, and reads the length it spans as it goes,
/// to two figures. Held to round lengths all the way, it shrank with the
/// view and sprang back long at every 1, 2 and 5 it passed, as many as
/// nineteen times in one step. It glides at the depth's own pace, which
/// the flight eases: eased again on top, it outran two pixels a frame
/// where the cell's bar, drawn longer since 2026-10-18, meets the nucleus's.
(double, String) scaleBarAt(ZoomDepth depth, double d, Size size) {
  double roundAt(ZoomStop stop) {
    final (double _, double pixels, String _) = scaleBar(
      depth.widthOf(stop),
      size.width,
      unit: ZoomDepth.unitOf(stop),
      share: ZoomDepth.barShareOf(stop),
    );
    return pixels;
  }

  final (int k, double s) = depth.segmentAt(d);
  final double from = roundAt(ZoomStop.values[k]);
  final double to = roundAt(ZoomStop.values[k + 1]);
  final double pixels = from + (to - from) * s;
  return (pixels, depth.labelAt(d, pixels / size.width * depth.widthAt(d)));
}

/// The box the scale bar's plate takes on a canvas of [size]: a bar
/// [pixels] long under a label of [label] size.
Rect scaleBarBox(double pixels, Size label, Size size) {
  final double y = size.height - 18;
  return Rect.fromLTRB(
    scaleBarLeft - 8,
    y - 14 - label.height,
    scaleBarLeft + math.max(pixels, label.width) + 8,
    y + 10,
  );
}

/// How far a callout's words sit inside its plate.
const double plateTextPadding = 6;

/// The least room between two plates set in a row.
const double rowGap = 10;

/// The plates of the names in [callouts] set in rows ([ZoomCallout.row]),
/// by key, their words in [labels] on a canvas of [size]: in each row, in
/// the order of what they name across it, each as nearly centred over what
/// it names as the others leave room for ([spreadRow]), [rowGap] apart and
/// clear of the canvas's edges while what they name is on it.
Map<String, Rect> rowPlates(
  List<ZoomCallout> callouts,
  TextStyle labels,
  ZoomInks inks,
  Size size,
) {
  final Map<double, List<ZoomCallout>> rows = <double, List<ZoomCallout>>{};
  for (final ZoomCallout c in callouts) {
    final double? row = c.row;
    if (row != null) {
      (rows[row] ??= <ZoomCallout>[]).add(c);
    }
  }
  final Map<String, Rect> out = <String, Rect>{};
  for (final MapEntry<double, List<ZoomCallout>> row in rows.entries) {
    final List<ZoomCallout> names = row.value
      ..sort((ZoomCallout a, ZoomCallout b) => a.target.dx.compareTo(b.target.dx));
    final List<Size> plates = <Size>[
      for (final ZoomCallout c in names)
        () {
          final TextPainter text = calloutText(c, labels, inks, size);
          final Size plate = Size(
            text.width + 2 * plateTextPadding,
            text.height + plateTextPadding,
          );
          text.dispose();
          return plate;
        }(),
    ];
    // Kept clear of the canvas's edges, but where what they name goes off
    // it, as the view flies on, the row goes with it.
    const double margin = ZoomOverlayPainter.margin;
    final double first = names.first.target.dx;
    final double last = names.last.target.dx;
    final List<double> middles = spreadRow(
      <double>[for (final ZoomCallout c in names) c.target.dx],
      <double>[for (final Size p in plates) p.width],
      math.min(margin, first - margin),
      math.max(size.width - margin, last + margin),
      rowGap,
    );
    for (int i = 0; i < names.length; i++) {
      final Rect plate = _onCanvas(0, row.key, plates[i], size);
      out[names[i].key] = Rect.fromLTWH(
        middles[i] - plates[i].width / 2,
        plate.top,
        plates[i].width,
        plates[i].height,
      );
    }
  }
  return out;
}

/// Where plates [widths] wide go along a row from [left] to [right], in
/// order, each wanting its middle at [wants]: as near it as the ones before
/// leave room for, [gap] apart, then drawn back from the right end where
/// they run past it. No plate passes another, and each moves only as what
/// the plates name moves, so a row glides as the view does.
List<double> spreadRow(
  List<double> wants,
  List<double> widths,
  double left,
  double right,
  double gap,
) {
  final int n = wants.length;
  final List<double> at = List<double>.of(wants);
  for (int i = 0; i < n; i++) {
    final double least = i == 0
        ? left + widths[0] / 2
        : at[i - 1] + widths[i - 1] / 2 + gap + widths[i] / 2;
    at[i] = math.max(at[i], least);
  }
  for (int i = n - 1; i >= 0; i--) {
    final double most = i == n - 1
        ? right - widths[i] / 2
        : at[i + 1] - widths[i + 1] / 2 - gap - widths[i] / 2;
    at[i] = math.min(at[i], most);
  }
  return at;
}

/// A callout's words, laid out as the painter sets them: a name round a
/// shape on one line, or on two where it is [wrapped] ([twoLines]); any
/// other on as many as two, at most 55% of the canvas wide.
TextPainter calloutText(
  ZoomCallout callout,
  TextStyle labels,
  ZoomInks inks,
  Size size, {
  bool wrapped = false,
}) => TextPainter(
  text: TextSpan(
    text: wrapped ? twoLines(callout.text) : callout.text,
    style: labels.copyWith(color: inks.text.withValues(alpha: callout.opacity)),
  ),
  textDirection: TextDirection.ltr,
  maxLines: 2,
)..layout(
    maxWidth: callout.ring == null ? size.width * 0.55 : double.infinity,
  );

/// [text] broken onto two lines at the space nearest its middle; as it is
/// where it has no space.
String twoLines(String text) {
  int best = -1;
  for (int i = 0; i < text.length; i++) {
    if (text[i] == ' ' &&
        (best < 0 ||
            (i - text.length / 2).abs() < (best - text.length / 2).abs())) {
      best = i;
    }
  }
  return best < 0
      ? text
      : '${text.substring(0, best)}\n${text.substring(best + 1)}';
}

/// The band of its shape a name set round one is in ([ZoomCallout.ring]):
/// above it or below it.
enum RingSide { above, below }

/// Where a name set round a shape is set at rest ([ringHolds]): in which
/// band, in which row out from the shape, on one line or two, and its
/// plate's middle from what it names, when the shape was [width] wide on
/// screen.
@immutable
final class RingHold {
  const RingHold(
    this.side,
    this.wrapped,
    this.offset,
    this.width, {
    this.row = 0,
  });

  final RingSide side;
  final int row;
  final bool wrapped;
  final Offset offset;
  final double width;
}

/// A name's plate round its shape, and whether its words are on two lines.
typedef RingPlate = ({Rect plate, bool wrapped});

/// How far a plate round a shape keeps from its outline.
const double ringGap = 10;

/// The least room between two rows of plates, one over the other.
const double ringStack = 4;

/// The rows out from a shape, above it and below, a name may go to.
const int ringRows = 3;

/// The box round [points].
Rect _boundsOf(List<Offset> points) {
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

/// The names in [callouts] set round a shape, shape by shape, in the order
/// they are staged.
Map<String, List<ZoomCallout>> _ringsOf(List<ZoomCallout> callouts) {
  final Map<String, List<ZoomCallout>> rings = <String, List<ZoomCallout>>{};
  for (final ZoomCallout c in callouts) {
    final ZoomRing? ring = c.ring;
    if (ring != null) {
      (rings[ring.key] ??= <ZoomCallout>[]).add(c);
    }
  }
  return rings;
}

/// The size of [callout]'s plate, on one line or [wrapped] onto two.
Size _ringPlate(
  ZoomCallout callout,
  TextStyle labels,
  ZoomInks inks,
  Size size,
  bool wrapped,
) {
  final TextPainter text = calloutText(
    callout,
    labels,
    inks,
    size,
    wrapped: wrapped,
  );
  final Size plate = Size(
    text.width + 2 * plateTextPadding,
    text.height + plateTextPadding,
  );
  text.dispose();
  return plate;
}

/// A name given a place in a band round a shape: on one line or two, and
/// its plate's size.
typedef _Placed = ({ZoomCallout callout, bool wrapped, Size plate});

/// The plates of [rows], the rows of one band out from the shape [outline]
/// (of box [box]) on a canvas of [size]: each row's plates pushed out to
/// the canvas's edges, a name whose part lies left of the shape's middle
/// against the left, the others against the right, in the order of what
/// they name across it, so no two lines cross; the row against the
/// outline, [ringGap] from it where it lies under the row's plates or in
/// the outer third of the canvas a corner of the row is in, so a shape
/// that narrows toward the edges, or runs on down its middle, leaves its
/// corners room; each further row beyond the one before. Null where a row
/// is wider than the canvas or reaches past its edge or the scale bar,
/// unless [force]d.
Map<String, Rect>? _band(
  RingSide side,
  List<List<_Placed>> rows,
  List<Offset> outline,
  Rect box,
  Size size, {
  bool force = false,
}) {
  const double margin = ZoomOverlayPainter.margin;
  // Clear of the scale bar at the canvas's foot.
  final double floor = size.height - 50;
  final bool above = side == RingSide.above;
  final Map<String, Rect> out = <String, Rect>{};
  double? outer;
  for (final List<_Placed> row in rows) {
    if (row.isEmpty) {
      continue;
    }
    final List<_Placed> set = List<_Placed>.of(row)
      ..sort(
        (_Placed a, _Placed b) =>
            a.callout.target.dx.compareTo(b.callout.target.dx),
      );
    final double width =
        set.fold<double>(0, (double a, _Placed b) => a + b.plate.width) +
        rowGap * (set.length - 1);
    if (width > size.width - 2 * margin && !force) {
      return null;
    }
    bool leftward(_Placed p) => p.callout.target.dx < box.center.dx;
    final List<double> middles = spreadRow(
      <double>[
        for (final _Placed p in set)
          leftward(p) ? double.negativeInfinity : double.infinity,
      ],
      <double>[for (final _Placed p in set) p.plate.width],
      margin,
      size.width - margin,
      rowGap,
    );
    // Where the outline reaches nearest this band, under the row.
    final List<(double, double)> spans = <(double, double)>[
      for (int i = 0; i < set.length; i++)
        (
          middles[i] - set[i].plate.width / 2,
          middles[i] + set[i].plate.width / 2,
        ),
      if (set.any(leftward)) (double.negativeInfinity, size.width / 3),
      if (!set.every(leftward)) (size.width * 2 / 3, double.infinity),
    ];
    double? reach;
    for (final Offset p in outline) {
      if (!spans.any(((double, double) s) => p.dx >= s.$1 && p.dx <= s.$2)) {
        continue;
      }
      reach = above
          ? math.min(reach ?? p.dy, p.dy)
          : math.max(reach ?? p.dy, p.dy);
    }
    double edge = above
        ? (reach ?? box.top) - ringGap
        : (reach ?? box.bottom) + ringGap;
    if (outer != null) {
      edge = above
          ? math.min(edge, outer - ringStack)
          : math.max(edge, outer + ringStack);
    }
    final double height = set
        .map((_Placed p) => p.plate.height)
        .reduce(math.max);
    outer = above ? edge - height : edge + height;
    if ((above ? outer < margin : outer > floor) && !force) {
      return null;
    }
    // Each plate against the row's edge nearer the shape.
    for (int i = 0; i < set.length; i++) {
      final Size plate = set[i].plate;
      out[set[i].callout.key] = Rect.fromLTWH(
        middles[i] - plate.width / 2,
        above ? edge - plate.height : edge,
        plate.width,
        plate.height,
      );
    }
  }
  return out;
}

/// How many pairs of lines from the plates of [rows], one band round a
/// shape, to what they name cross each other.
int _crossings(
  RingSide side,
  List<List<_Placed>> rows,
  List<Offset> outline,
  Rect box,
  Size size,
) {
  final Map<String, Rect> plates = _band(
    side,
    rows,
    outline,
    box,
    size,
    force: true,
  )!;
  final List<(Offset, Offset)> lines = <(Offset, Offset)>[
    for (final List<_Placed> row in rows)
      for (final _Placed p in row)
        lineFrom(plates[p.callout.key]!, p.callout.target),
  ];
  int count = 0;
  for (int i = 0; i < lines.length; i++) {
    for (int j = i + 1; j < lines.length; j++) {
      if (linesCross(lines[i], lines[j])) {
        count++;
      }
    }
  }
  return count;
}

/// The line the painter draws from a callout's [plate] to its [target]:
/// from the plate's point nearest the target.
(Offset, Offset) lineFrom(Rect plate, Offset target) => (
  Offset(
    target.dx.clamp(plate.left, plate.right),
    target.dy.clamp(plate.top, plate.bottom),
  ),
  target,
);

/// Whether lines [a] and [b] cross, other than where one ends on the other.
bool linesCross((Offset, Offset) a, (Offset, Offset) b) {
  double turn(Offset p, Offset q, Offset r) =>
      (q.dx - p.dx) * (r.dy - p.dy) - (q.dy - p.dy) * (r.dx - p.dx);
  return turn(b.$1, b.$2, a.$1) * turn(b.$1, b.$2, a.$2) < 0 &&
      turn(a.$1, a.$2, b.$1) * turn(a.$1, a.$2, b.$2) < 0;
}

/// Where each name in [callouts] set round a shape goes at rest, by key
/// ([RingHold]), its words in [labels] on a canvas of [size].
///
/// Each is set in a corner of the canvas: in the band above the shape or
/// below it, the one nearer what it names, out at the canvas's edge on the
/// side of the shape what it names is on (the user's choice of
/// 2026-10-18), on one line, or on two where one does not fit; where its
/// band has no room, in a row further out, and then in the other band.
/// Names are given room in the order they are staged.
Map<String, RingHold> ringHolds(
  List<ZoomCallout> callouts,
  TextStyle labels,
  ZoomInks inks,
  Size size,
) => <String, RingHold>{
  for (final List<ZoomCallout> names in _ringsOf(callouts).values)
    ..._holdRing(names, labels, inks, size),
};

Map<String, RingHold> _holdRing(
  List<ZoomCallout> names,
  TextStyle labels,
  ZoomInks inks,
  Size size,
) {
  final List<Offset> outline = names.first.ring!.outline;
  final Rect box = _boundsOf(outline);
  bool wraps(ZoomCallout c) => c.text.contains(' ');
  final Map<RingSide, List<List<_Placed>>> bands =
      <RingSide, List<List<_Placed>>>{
        for (final RingSide side in RingSide.values)
          side: <List<_Placed>>[
            for (int row = 0; row < ringRows; row++) <_Placed>[],
          ],
      };
  for (final ZoomCallout c in names) {
    final RingSide near = c.target.dy < box.center.dy
        ? RingSide.above
        : RingSide.below;
    final RingSide far = near == RingSide.above
        ? RingSide.below
        : RingSide.above;
    bool placed = false;
    for (final RingSide side in <RingSide>[near, far]) {
      final List<List<_Placed>> rows = bands[side]!;
      for (int row = 0; row < ringRows && !placed; row++) {
        // A row further out only once the one before it has a name.
        if (row > 0 && rows[row - 1].isEmpty) {
          break;
        }
        for (final bool wrapped in <bool>[false, if (wraps(c)) true]) {
          final _Placed p = (
            callout: c,
            wrapped: wrapped,
            plate: _ringPlate(c, labels, inks, size, wrapped),
          );
          rows[row].add(p);
          if (_band(side, rows, outline, box, size) != null) {
            placed = true;
            break;
          }
          rows[row].removeLast();
        }
      }
      if (placed) {
        break;
      }
    }
    // Where no row has room, the nearer row takes it all the same.
    if (!placed) {
      bands[near]![0].add((
        callout: c,
        wrapped: false,
        plate: _ringPlate(c, labels, inks, size, false),
      ));
    }
  }

  // Two names of a band whose lines cross change places, where both still
  // fit: a name a row further out may have taken what lies further in.
  for (final RingSide side in RingSide.values) {
    final List<List<_Placed>> rows = bands[side]!;
    for (int pass = 0; pass < 8; pass++) {
      final int before = _crossings(side, rows, outline, box, size);
      if (before == 0) {
        break;
      }
      bool better = false;
      for (int a = 0; a < rows.length && !better; a++) {
        for (int b = a + 1; b < rows.length && !better; b++) {
          for (int i = 0; i < rows[a].length && !better; i++) {
            for (int j = 0; j < rows[b].length && !better; j++) {
              final _Placed p = rows[a][i];
              rows[a][i] = rows[b][j];
              rows[b][j] = p;
              if (_band(side, rows, outline, box, size) != null &&
                  _crossings(side, rows, outline, box, size) < before) {
                better = true;
              } else {
                rows[b][j] = rows[a][i];
                rows[a][i] = p;
              }
            }
          }
        }
      }
      if (!better) {
        break;
      }
    }
  }

  final Map<String, RingHold> out = <String, RingHold>{};
  for (final RingSide side in RingSide.values) {
    final List<List<_Placed>> rows = bands[side]!;
    final Map<String, Rect> plates = _band(
      side,
      rows,
      outline,
      box,
      size,
      force: true,
    )!;
    for (int row = 0; row < rows.length; row++) {
      for (final _Placed p in rows[row]) {
        final Rect plate = plates[p.callout.key]!;
        out[p.callout.key] = RingHold(
          side,
          p.wrapped,
          plate.center - p.callout.target,
          box.width,
          row: row,
        );
      }
    }
  }
  return out;
}

/// The plates of the names in [callouts] set round a shape
/// ([ZoomCallout.ring]), by key, their words in [labels] on a canvas of
/// [size]: as [held] sets them, or, without it, as they are set at rest
/// ([ringHolds]).
///
/// Held, each keeps its band, row and lines, and its plate's middle stays
/// where it was from what it names, scaled as the shape is: the zoom moves
/// a shape by scaling it about a point, so the plates move as though drawn
/// on it. Each row is then spread again so no two of its plates meet as
/// they come closer.
Map<String, RingPlate> ringPlates(
  List<ZoomCallout> callouts,
  TextStyle labels,
  ZoomInks inks,
  Size size, {
  Map<String, RingHold>? held,
}) {
  final Map<String, RingPlate> out = <String, RingPlate>{};
  for (final List<ZoomCallout> names in _ringsOf(callouts).values) {
    final Map<String, RingHold> holds =
        held != null && names.every((ZoomCallout c) => held.containsKey(c.key))
        ? held
        : _holdRing(names, labels, inks, size);
    final Rect box = _boundsOf(names.first.ring!.outline);
    final Map<(RingSide, int), List<(ZoomCallout, Size, Offset)>> groups =
        <(RingSide, int), List<(ZoomCallout, Size, Offset)>>{};
    for (final ZoomCallout c in names) {
      final RingHold hold = holds[c.key]!;
      final double scale = hold.width <= 0 ? 1 : box.width / hold.width;
      (groups[(hold.side, hold.row)] ??= <(ZoomCallout, Size, Offset)>[]).add((
        c,
        _ringPlate(c, labels, inks, size, hold.wrapped),
        c.target + hold.offset * scale,
      ));
    }
    for (final List<(ZoomCallout, Size, Offset)> group in groups.values) {
      final List<(ZoomCallout, Size, Offset)> set = group
        ..sort(
          ((ZoomCallout, Size, Offset) a, (ZoomCallout, Size, Offset) b) =>
              a.$3.dx.compareTo(b.$3.dx),
        );
      final List<double> middles = spreadRow(
        <double>[for (final (ZoomCallout _, Size _, Offset at) in set) at.dx],
        <double>[
          for (final (ZoomCallout _, Size plate, Offset _) in set) plate.width,
        ],
        double.negativeInfinity,
        double.infinity,
        rowGap,
      );
      for (int i = 0; i < set.length; i++) {
        final (ZoomCallout c, Size plate, Offset at) = set[i];
        out[c.key] = (
          plate: Rect.fromCenter(
            center: Offset(middles[i], at.dy),
            width: plate.width,
            height: plate.height,
          ),
          wrapped: holds[c.key]!.wrapped,
        );
      }
    }
  }
  return out;
}

/// The credit's words, laid out right-aligned in the room the scale bar
/// [bar] leaves on a canvas of [size], at most two lines.
TextPainter creditText(
  String credit,
  TextStyle caption,
  Size size,
  Rect bar, [
  double opacity = 1,
]) => TextPainter(
  text: TextSpan(
    text: credit,
    style: caption.copyWith(
      color: caption.color?.withValues(
        alpha: (caption.color?.a ?? 1) * opacity,
      ),
    ),
  ),
  textDirection: TextDirection.ltr,
  textAlign: TextAlign.right,
  maxLines: 2,
)..layout(maxWidth: size.width - bar.right - 2 * ZoomOverlayPainter.margin);

/// Where the credit goes: its lines' box against the lower right corner,
/// level with the scale bar's foot.
Rect creditBox(String credit, TextStyle caption, Size size, Rect bar) {
  final TextPainter text = creditText(credit, caption, size, bar);
  final Size box = text.size;
  text.dispose();
  return Rect.fromLTWH(
    size.width - ZoomOverlayPainter.margin - box.width,
    bar.bottom - box.height,
    box.width,
    box.height,
  );
}

/// Where [callout]'s plate goes, its words of [text] size, on a canvas of
/// [size] of [stage] at depth [d], the plates already [placed]: at the
/// anchor it has at rest, wherever the view is, or where [placePlate] puts
/// it.
Rect calloutPlate(
  ZoomStage stage,
  double d,
  ZoomCallout callout,
  Size text,
  Size size,
  List<Rect> placed,
  ZoomInks inks,
  TextStyle labels,
) {
  if (callout.ring != null) {
    final RingPlate? ring = stage.ringsAt(d, size, inks, labels)[callout.key];
    if (ring != null) {
      return ring.plate;
    }
  }
  final int? resting = callout.anchors.isEmpty
      ? null
      : stage.restingAnchors(d, size, inks, labels)[callout.key];
  if (resting != null && resting >= 0) {
    // An organ's name set in a column at the canvas's edge goes on with what
    // it names, off the canvas if that is where it goes, rather than piling
    // up against the canvas's top or foot with the others as it fades: at
    // rest it fits as it is, as its anchor was only taken where it did.
    if (callout.flush && callout.follows) {
      return _plateBeyond(
        callout.target,
        callout.anchors[resting],
        text,
        size,
      );
    }
    return plateBeyond(
      callout.target,
      callout.anchors[resting],
      text,
      size,
      flush: callout.flush,
    );
  }
  // Where none of its anchors had room at rest, it keeps the place by its
  // target it took there instead.
  if (resting != null) {
    return _choices(callout.target, text, size)[-1 - resting];
  }
  return placePlate(
    callout.target,
    text,
    size,
    placed,
    anchors: callout.anchors,
    flush: callout.flush,
  );
}

/// A plate for words of [text] size naming [target], its corner or edge
/// that faces the target at [anchor] and reaching on away from it: a corner
/// where the way out is aslant, the middle of an edge where it is straight
/// across or down; or, [flush], set out from there against the canvas's
/// edge on the anchor's side. Kept on a canvas of [size].
Rect plateBeyond(
  Offset target,
  Offset anchor,
  Size text,
  Size size, {
  bool flush = false,
}) {
  final Rect plate = _plateBeyond(target, anchor, text, flush ? size : null);
  return _onCanvas(plate.left, plate.top, plate.size, size);
}

/// [plateBeyond]'s plate before it is kept on the canvas, set out against
/// the edge of a canvas of [edge] size where one is given.
Rect _plateBeyond(Offset target, Offset anchor, Size text, [Size? edge]) {
  final double plateW = text.width + 2 * plateTextPadding;
  final double plateH = text.height + plateTextPadding;
  final Offset out = anchor - target;
  final Offset way = out.distance == 0 ? out : out / out.distance;
  final Rect plate = Rect.fromCenter(
    center:
        anchor +
        Offset(
          (way.dx * 2.5).clamp(-1.0, 1.0) * plateW / 2,
          (way.dy * 2.5).clamp(-1.0, 1.0) * plateH / 2,
        ),
    width: plateW,
    height: plateH,
  );
  if (edge == null) {
    return plate;
  }
  return Rect.fromLTWH(
    anchor.dx < target.dx
        ? ZoomOverlayPainter.margin
        : edge.width - ZoomOverlayPainter.margin - plateW,
    plate.top,
    plateW,
    plateH,
  );
}

/// Whether a plate set out against the canvas's edge keeps from [target]
/// at least as far as its [anchor] does: one too wide for the room between
/// the two would reach back over what the anchor keeps it off.
bool _keepsOff(Rect plate, Offset target, Offset anchor) =>
    anchor.dx < target.dx ? plate.right <= anchor.dx : plate.left >= anchor.dx;

/// A plate of [plate] size at [x], [y], moved as little as keeps it on a
/// canvas of [size], clear of its edges and the card's.
Rect _onCanvas(double x, double y, Size plate, Size size) {
  final double right = size.width - ZoomOverlayPainter.margin;
  final double bottom = size.height - 40;
  return Rect.fromLTWH(
    x.clamp(
      ZoomOverlayPainter.margin,
      math.max(ZoomOverlayPainter.margin, right - plate.width),
    ),
    y.clamp(
      ZoomOverlayPainter.margin,
      math.max(ZoomOverlayPainter.margin, bottom - plate.height),
    ),
    plate.width,
    plate.height,
  );
}

/// Where a callout's plate goes for words of [text] size naming [target] on
/// a canvas of [size], clear of the plates already [placed]: at the first of
/// its [anchors] where it fits on the canvas as it is, reaching on away from
/// the target, or, [flush], set out from there against the canvas's edge
/// where it keeps as far from the target as the anchor does; else up and to
/// the right where there is room, else at the first corner that keeps it on
/// the canvas.
Rect placePlate(
  Offset target,
  Size text,
  Size size,
  List<Rect> placed, {
  List<Offset> anchors = const <Offset>[],
  bool flush = false,
}) =>
    placePlateAt(target, text, size, placed, anchors: anchors, flush: flush).$1;

/// [placePlate]'s plate, and which of the [anchors] it is set at; where
/// none had room, -1 less the index of the place of its own it took
/// ([_choices]).
(Rect, int) placePlateAt(
  Offset target,
  Size text,
  Size size,
  List<Rect> placed, {
  List<Offset> anchors = const <Offset>[],
  bool flush = false,
}) {
  bool clear(Rect plate) =>
      placed.every((Rect r) => !r.inflate(4).overlaps(plate));
  // A plate moved to stay on the canvas would reach back over what the
  // anchor keeps it off, so only one that fits as it is is taken.
  for (int i = 0; i < anchors.length; i++) {
    final Rect plate = _plateBeyond(
      target,
      anchors[i],
      text,
      flush ? size : null,
    );
    if (_onCanvas(plate.left, plate.top, plate.size, size).topLeft ==
            plate.topLeft &&
        (!flush || _keepsOff(plate, target, anchors[i])) &&
        clear(plate)) {
      return (plate, i);
    }
  }

  final List<Rect> choices = _choices(target, text, size);
  for (int i = 0; i < choices.length; i++) {
    if (clear(choices[i])) {
      return (choices[i], -1 - i);
    }
  }
  return (choices.first, -1);
}

/// The places a plate for words of [text] size naming [target] is tried in
/// where it has no anchor with room, in order: up and to the right, then
/// down, then to the left, then further out.
List<Rect> _choices(Offset target, Size text, Size size) {
  final double plateW = text.width + 2 * plateTextPadding;
  final double plateH = text.height + plateTextPadding;
  Rect at(double dx, double dy) => _onCanvas(
    dx >= 0 ? target.dx + dx : target.dx + dx - plateW,
    target.dy + dy - plateH / 2,
    Size(plateW, plateH),
    size,
  );
  return <Rect>[
    at(24, -30),
    at(24, 30),
    at(-24, -30),
    at(-24, 30),
    at(24, -36 - plateH),
    at(24, 36 + plateH),
    at(-24, -36 - plateH),
    at(-24, 36 + plateH),
  ];
}
