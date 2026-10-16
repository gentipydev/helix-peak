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
  /// set at, at rest at the stop that shows it, by key; -1 where none had
  /// room there. A plate keeps the anchor it has at rest for the whole of
  /// the steps either side, so it never jumps from one to another as the
  /// view moves. Only the stops either side of [d] are laid out: their
  /// scenes are the ones being drawn.
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
  /// either side ([ringHolds]), the side, row and lines each was given there
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
    final Offset from = Offset(
      target.dx.clamp(plate.left, plate.right),
      target.dy.clamp(plate.top, plate.bottom),
    );
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
/// nineteen times in one step.
(double, String) scaleBarAt(ZoomDepth depth, double d, Size size) {
  double roundAt(ZoomStop stop) {
    final (double _, double pixels, String _) = scaleBar(
      depth.widthOf(stop),
      size.width,
      unit: ZoomDepth.unitOf(stop),
    );
    return pixels;
  }

  final (int k, double s) = depth.segmentAt(d);
  final double from = roundAt(ZoomStop.values[k]);
  final double to = roundAt(ZoomStop.values[k + 1]);
  final double pixels = from + (to - from) * smoothstep(s);
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

/// The side of its shape a name set round one is on ([ZoomCallout.ring]).
enum RingSide { left, right, above, below }

/// Where a name set round a shape is set at rest ([ringHolds]): on which
/// side of it, in which row out from it where it is above or below, on one
/// line or two, and its plate's middle from what it names, when the shape
/// was [width] wide on screen.
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

/// The least room between two plates one over the other beside a shape.
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

/// A plate of [plate] size beside [outline] on [side], its middle at
/// height [y], its inner edge [ringGap] out from the outline's furthest
/// point within the plate's own height: so it hugs the outline, however it
/// bulges or narrows, rather than the box round it ([box]).
Rect _beside(
  List<Offset> outline,
  Rect box,
  RingSide side,
  double y,
  Size plate,
) {
  final double top = y - plate.height / 2;
  final double bottom = y + plate.height / 2;
  double? reach;
  for (final Offset p in outline) {
    if (p.dy < top - 2 || p.dy > bottom + 2) {
      continue;
    }
    reach = side == RingSide.right
        ? math.max(reach ?? p.dx, p.dx)
        : math.min(reach ?? p.dx, p.dx);
  }
  return side == RingSide.right
      ? Rect.fromLTWH(
          (reach ?? box.right) + ringGap,
          top,
          plate.width,
          plate.height,
        )
      : Rect.fromLTWH(
          (reach ?? box.left) - ringGap - plate.width,
          top,
          plate.width,
          plate.height,
        );
}

/// Where each name in [callouts] set round a shape goes at rest, by key
/// ([RingHold]), its words in [labels] on a canvas of [size].
///
/// Each is set beside its shape, on the side nearer what it names, its
/// plate hugging the outline and stacked by height with the others there,
/// on one line, or else on two; where neither fits on the canvas, in the
/// row above the shape or below it, the one nearer what it names first, each
/// row as near over what it names as the others leave room for, the nearer
/// rows first. Names are given room in the order they are staged.
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
  const double margin = ZoomOverlayPainter.margin;
  final List<Offset> outline = names.first.ring!.outline;
  final Rect box = _boundsOf(outline);
  // Clear of the scale bar at the canvas's foot.
  final double floor = size.height - 50;
  final double top = math.max(box.top, margin);
  final double bottom = math.min(box.bottom, floor);
  bool wraps(ZoomCallout c) => c.text.contains(' ');
  Size plateOf(ZoomCallout c, bool wrapped) =>
      _ringPlate(c, labels, inks, size, wrapped);

  // Beside the shape: each name on the side nearer what it names, on one
  // line or two, where its plate stays on the canvas.
  final Map<String, (RingSide, bool, Size)> beside =
      <String, (RingSide, bool, Size)>{};
  final List<ZoomCallout> over = <ZoomCallout>[];
  bool fits(Rect plate) =>
      plate.left >= margin && plate.right <= size.width - margin;
  for (final ZoomCallout c in names) {
    final RingSide side = c.target.dx < box.center.dx
        ? RingSide.left
        : RingSide.right;
    (RingSide, bool, Size)? chosen;
    for (final bool wrapped in <bool>[false, if (wraps(c)) true]) {
      final Size plate = plateOf(c, wrapped);
      final double y = c.target.dy.clamp(
        top + plate.height / 2,
        math.max(top + plate.height / 2, bottom - plate.height / 2),
      );
      if (fits(_beside(outline, box, side, y, plate))) {
        chosen = (side, wrapped, plate);
        break;
      }
    }
    if (chosen == null) {
      over.add(c);
    } else {
      beside[c.key] = chosen;
    }
  }

  // Stacked by height on each side, within the shape's own height; a name
  // stacked to where it no longer fits, or with no room left on its side,
  // goes to a row.
  final Map<String, Rect> sides = <String, Rect>{};
  for (int pass = 0; pass <= names.length; pass++) {
    sides.clear();
    String? misfit;
    for (final RingSide side in <RingSide>[RingSide.left, RingSide.right]) {
      final List<ZoomCallout> column = <ZoomCallout>[
        for (final ZoomCallout c in names)
          if (beside[c.key]?.$1 == side) c,
      ]..sort(
          (ZoomCallout a, ZoomCallout b) => a.target.dy.compareTo(b.target.dy),
        );
      if (column.isEmpty) {
        continue;
      }
      final List<double> heights = <double>[
        for (final ZoomCallout c in column) beside[c.key]!.$3.height,
      ];
      final double needed =
          heights.fold<double>(0, (double a, double b) => a + b) +
          ringStack * (column.length - 1);
      final List<double> middles = spreadRow(
        <double>[for (final ZoomCallout c in column) c.target.dy],
        heights,
        top,
        math.max(bottom, top + needed),
        ringStack,
      );
      for (int i = 0; i < column.length; i++) {
        final Rect plate = _beside(
          outline,
          box,
          side,
          middles[i],
          beside[column[i].key]!.$3,
        );
        sides[column[i].key] = plate;
        if (!fits(plate) || plate.top < margin || plate.bottom > floor) {
          // The one staged last gives way.
          if (misfit == null ||
              names.indexWhere((ZoomCallout c) => c.key == column[i].key) >
                  names.indexWhere((ZoomCallout c) => c.key == misfit)) {
            misfit = column[i].key;
          }
        }
      }
    }
    if (misfit == null) {
      break;
    }
    beside.remove(misfit);
    over.add(names.firstWhere((ZoomCallout c) => c.key == misfit));
  }

  // Rows above and below the shape, the nearer side first, then further out.
  final Map<(RingSide, int), List<(ZoomCallout, bool, Size)>> rows =
      <(RingSide, int), List<(ZoomCallout, bool, Size)>>{};
  double rowHeight(RingSide side, int row) => <double>[
    0,
    for (final (ZoomCallout _, bool _, Size plate)
        in rows[(side, row)] ?? const <(ZoomCallout, bool, Size)>[])
      plate.height,
  ].reduce(math.max);
  // The top of row [row] above the shape, or the bottom of one below it,
  // were it [height] tall.
  double rowEdge(RingSide side, int row, double height) {
    double at = side == RingSide.above
        ? box.top - ringGap
        : box.bottom + ringGap;
    for (int k = 0; k < row; k++) {
      final double h = rowHeight(side, k);
      at += side == RingSide.above ? -(h + ringStack) : h + ringStack;
    }
    return side == RingSide.above ? at - height : at + height;
  }

  bool rowFits(RingSide side, int row, Size plate) {
    final List<(ZoomCallout, bool, Size)> now =
        rows[(side, row)] ?? const <(ZoomCallout, bool, Size)>[];
    final double width =
        now.fold<double>(
          0,
          (double a, (ZoomCallout, bool, Size) b) => a + b.$3.width,
        ) +
        rowGap * now.length +
        plate.width;
    final double height = math.max(rowHeight(side, row), plate.height);
    final double edge = rowEdge(side, row, height);
    return width <= size.width - 2 * margin &&
        (side == RingSide.above ? edge >= margin : edge <= floor);
  }

  for (final ZoomCallout c in over) {
    final RingSide near = c.target.dy < box.center.dy
        ? RingSide.above
        : RingSide.below;
    final RingSide far = near == RingSide.above
        ? RingSide.below
        : RingSide.above;
    (RingSide, int, bool, Size)? chosen;
    for (int row = 0; row < ringRows && chosen == null; row++) {
      for (final RingSide side in <RingSide>[near, far]) {
        for (final bool wrapped in <bool>[false, if (wraps(c)) true]) {
          final Size plate = plateOf(c, wrapped);
          if (rowFits(side, row, plate)) {
            chosen = (side, row, wrapped, plate);
            break;
          }
        }
        if (chosen != null) {
          break;
        }
      }
    }
    // Where no row has room, the nearer row takes it all the same.
    chosen ??= (near, 0, false, plateOf(c, false));
    (rows[(chosen.$1, chosen.$2)] ??= <(ZoomCallout, bool, Size)>[]).add((
      c,
      chosen.$3,
      chosen.$4,
    ));
  }

  final Map<String, RingHold> out = <String, RingHold>{};
  for (final ZoomCallout c in names) {
    final Rect? plate = sides[c.key];
    if (plate != null) {
      out[c.key] = RingHold(
        beside[c.key]!.$1,
        beside[c.key]!.$2,
        plate.center - c.target,
        box.width,
      );
    }
  }
  for (final MapEntry<(RingSide, int), List<(ZoomCallout, bool, Size)>> row
      in rows.entries) {
    final (RingSide side, int index) = row.key;
    final List<(ZoomCallout, bool, Size)> set = row.value
      ..sort(
        ((ZoomCallout, bool, Size) a, (ZoomCallout, bool, Size) b) =>
            a.$1.target.dx.compareTo(b.$1.target.dx),
      );
    final double height = rowHeight(side, index);
    final double edge = rowEdge(side, index, height);
    // Each plate against the row's edge nearer the shape.
    final List<double> middles = spreadRow(
      <double>[for (final (ZoomCallout c, bool _, Size _) in set) c.target.dx],
      <double>[
        for (final (ZoomCallout _, bool _, Size plate) in set) plate.width,
      ],
      margin,
      size.width - margin,
      rowGap,
    );
    for (int i = 0; i < set.length; i++) {
      final (ZoomCallout c, bool wrapped, Size plate) = set[i];
      final double y = side == RingSide.above
          ? edge + height - plate.height / 2
          : edge - height + plate.height / 2;
      out[c.key] = RingHold(
        side,
        wrapped,
        Offset(middles[i], y) - c.target,
        box.width,
        row: index,
      );
    }
  }
  return out;
}

/// The plates of the names in [callouts] set round a shape
/// ([ZoomCallout.ring]), by key, their words in [labels] on a canvas of
/// [size]: as [held] sets them, or, without it, as they are set at rest
/// ([ringHolds]).
///
/// Held, each keeps its side, row and lines, and its plate's middle stays
/// where it was from what it names, scaled as the shape is: the zoom moves
/// a shape by scaling it about a point, so the plates move as though drawn
/// on it. Each side and row is then spread again so no two of its plates
/// meet as they come closer.
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
    for (final MapEntry<(RingSide, int), List<(ZoomCallout, Size, Offset)>>
        group in groups.entries) {
      final bool across =
          group.key.$1 == RingSide.above || group.key.$1 == RingSide.below;
      final List<(ZoomCallout, Size, Offset)> set = group.value
        ..sort(
          ((ZoomCallout, Size, Offset) a, (ZoomCallout, Size, Offset) b) =>
              across
              ? a.$3.dx.compareTo(b.$3.dx)
              : a.$3.dy.compareTo(b.$3.dy),
        );
      final List<double> middles = spreadRow(
        <double>[
          for (final (ZoomCallout _, Size _, Offset at) in set)
            across ? at.dx : at.dy,
        ],
        <double>[
          for (final (ZoomCallout _, Size plate, Offset _) in set)
            across ? plate.width : plate.height,
        ],
        double.negativeInfinity,
        double.infinity,
        across ? rowGap : ringStack,
      );
      for (int i = 0; i < set.length; i++) {
        final (ZoomCallout c, Size plate, Offset at) = set[i];
        out[c.key] = (
          plate: Rect.fromCenter(
            center: across
                ? Offset(middles[i], at.dy)
                : Offset(at.dx, middles[i]),
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
    return plateBeyond(callout.target, callout.anchors[resting], text, size);
  }
  return placePlate(
    callout.target,
    text,
    size,
    placed,
    // Where none of its anchors had room at rest, none is tried on the way.
    anchors: resting == null ? callout.anchors : const <Offset>[],
  );
}

/// A plate for words of [text] size naming [target], its corner or edge
/// that faces the target at [anchor] and reaching on away from it: a corner
/// where the way out is aslant, the middle of an edge where it is straight
/// across or down. Kept on a canvas of [size].
Rect plateBeyond(Offset target, Offset anchor, Size text, Size size) {
  final Rect plate = _plateBeyond(target, anchor, text);
  return _onCanvas(plate.left, plate.top, plate.size, size);
}

Rect _plateBeyond(Offset target, Offset anchor, Size text) {
  final double plateW = text.width + 2 * plateTextPadding;
  final double plateH = text.height + plateTextPadding;
  final Offset out = anchor - target;
  final Offset way = out.distance == 0 ? out : out / out.distance;
  return Rect.fromCenter(
    center:
        anchor +
        Offset(
          (way.dx * 2.5).clamp(-1.0, 1.0) * plateW / 2,
          (way.dy * 2.5).clamp(-1.0, 1.0) * plateH / 2,
        ),
    width: plateW,
    height: plateH,
  );
}

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
/// the target; else up and to the right where there is room, else at the
/// first corner that keeps it on the canvas.
Rect placePlate(
  Offset target,
  Size text,
  Size size,
  List<Rect> placed, {
  List<Offset> anchors = const <Offset>[],
}) => placePlateAt(target, text, size, placed, anchors: anchors).$1;

/// [placePlate]'s plate, and which of the [anchors] it is set at: -1 where
/// none had room.
(Rect, int) placePlateAt(
  Offset target,
  Size text,
  Size size,
  List<Rect> placed, {
  List<Offset> anchors = const <Offset>[],
}) {
  final double plateW = text.width + 2 * plateTextPadding;
  final double plateH = text.height + plateTextPadding;
  Rect at(double dx, double dy) => _onCanvas(
    dx >= 0 ? target.dx + dx : target.dx + dx - plateW,
    target.dy + dy - plateH / 2,
    Size(plateW, plateH),
    size,
  );
  bool clear(Rect plate) =>
      placed.every((Rect r) => !r.inflate(4).overlaps(plate));
  // A plate moved to stay on the canvas would reach back over what the
  // anchor keeps it off, so only one that fits as it is is taken.
  for (int i = 0; i < anchors.length; i++) {
    final Rect plate = _plateBeyond(target, anchors[i], text);
    if (_onCanvas(plate.left, plate.top, plate.size, size).topLeft ==
            plate.topLeft &&
        clear(plate)) {
      return (plate, i);
    }
  }

  final List<Rect> choices = <Rect>[
    at(24, -30),
    at(24, 30),
    at(-24, -30),
    at(-24, 30),
    at(24, -36 - plateH),
    at(24, 36 + plateH),
    at(-24, -36 - plateH),
    at(-24, 36 + plateH),
  ];
  for (final Rect choice in choices) {
    if (clear(choice)) {
      return (choice, -1);
    }
  }
  return (choices.first, -1);
}
