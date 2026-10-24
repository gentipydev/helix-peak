import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../zoom_inks.dart';
import '../../specimen_light.dart';
import 'adipose_anatomy.dart';
import 'adipose_form.dart';
import 'adipose_style.dart';

/// A block of the abdominal wall drawn as a specimen under the zoom's one
/// lamp: its top the skin's surface, lit, its furrows faint; its front a
/// flat cut, the skin's dermis a warm neutral under its paler epidermis,
/// the fat of both its layers where the zoom's cell lives, one flat tone in
/// the mark, cut by pale septa, upright in the superficial layer and
/// leaning in the deep, the membranous layer between them and the rectus
/// sheath under them pale bands, the rectus warmed toward the clay, its
/// fascicles faint, the vessels in the blood red; its right side a second
/// cut, in shade.
///
/// Everything costly is built once, for one form and one set of inks.
final class AdiposeArt {
  AdiposeArt(this.form, this.inks)
    : _light = SpecimenLight(SpecimenLamp.zoom),
      _palette = SpecimenPalette(inks);

  final AdiposeForm form;
  final ZoomInks inks;
  final SpecimenLight _light;
  final SpecimenPalette _palette;

  /// Where the zoom's cell lives, the fat: one flat tone, the mark over a
  /// neutral.
  late final Color homeTone = Color.alphaBlend(
    inks.glow(AdiposeStyle.homeMark),
    inks.lit(AdiposeStyle.homeLit),
  );

  /// A tone [lit] of the way toward the bright ink, warmed [warmth] of the
  /// way toward the home helix's clay.
  SpecimenTone _warmed(double lit, double warmth) => SpecimenTone(
    Color.lerp(inks.lit(lit), inks.bases.thymine, warmth)!,
    inks.shadow,
  );

  /// [tone] on a face turned as [facing] is, lit by the lamp.
  Color _on(SpecimenTone tone, (double, double, double) facing) {
    final (double x, double y, double z) = facing;
    final double length = math.sqrt(x * x + y * y + z * z);
    final double nx = x / length;
    final double ny = y / length;
    final double nz = z / length;
    return Color(
      _palette.colour(
        tone,
        _light.light(nx, ny, nz, form: nz),
        sheen: _light.sheen(nx, ny, nz) * AdiposeStyle.cutSheen,
      ),
    );
  }

  Color _front(SpecimenTone tone) => _on(tone, AdiposeStyle.front);
  Color _sideOf(SpecimenTone tone) => _on(tone, AdiposeStyle.side);

  late final SpecimenTone _epidermisTone = _warmed(
    AdiposeStyle.epidermisLit,
    AdiposeStyle.epidermisWarmth,
  );
  late final SpecimenTone _dermisTone = _warmed(
    AdiposeStyle.dermisLit,
    AdiposeStyle.dermisWarmth,
  );
  late final SpecimenTone _septumTone = _warmed(
    AdiposeStyle.septumLit,
    AdiposeStyle.septumWarmth,
  );
  late final SpecimenTone _fasciaTone = _warmed(
    AdiposeStyle.fasciaLit,
    AdiposeStyle.fasciaWarmth,
  );
  late final SpecimenTone _muscleTone = _warmed(
    AdiposeStyle.muscleLit,
    AdiposeStyle.muscleWarmth,
  );

  late final Color _epidermis = _front(_epidermisTone);
  late final Color _dermis = _front(_dermisTone);
  late final Color _septum = _front(_septumTone);
  late final Color _fascia = _front(_fasciaTone);
  late final Color _muscle = _front(_muscleTone);
  late final Color _surface = _on(
    _warmed(AdiposeStyle.surfaceLit, AdiposeStyle.surfaceWarmth),
    AdiposeStyle.top,
  );
  late final Color _artery = Color.lerp(
    inks.blood,
    inks.ground,
    AdiposeStyle.artery,
  )!;
  late final Color _vein = Color.lerp(
    inks.blood,
    inks.ground,
    AdiposeStyle.vein,
  )!;

  // Paths built once.

  late final Path _superficialSepta = _cells(form.superficialLobes);
  late final Path _deepSepta = _cells(form.deepLobes);
  late final Path _fascicles = _cells(form.fascicles);
  late final Path _layers = _lines(form.layerLines);
  late final Path _furrows = _lines(form.furrows);
  late final Path _perforatorArtery = _lines(<List<Offset>>[
    form.perforatorArtery,
  ]);
  late final Path _perforatorVein = _lines(<List<Offset>>[form.perforatorVein]);

  // Drawing.

  /// What the block covers, its shadow included: the room a layer of it
  /// needs.
  late final Rect bounds = form.outline.getBounds().inflate(
    form.mm(AdiposeStyle.shadowY + AdiposeStyle.shadowSoft),
  );

  /// Builds every path a frame will draw.
  void prepare() => <Object?>[
    _superficialSepta,
    _deepSepta,
    _fascicles,
    _layers,
    _furrows,
    _perforatorArtery,
    _perforatorVein,
    bounds,
  ];

  /// Draws it all, in the scene's units at the wall's real size; [line] is
  /// a pixel.
  void paint(Canvas canvas, double line) {
    _paintShadow(canvas);
    _paintSide(canvas, line);
    _paintTop(canvas, line);
    canvas.save();
    canvas.clipPath(form.front);
    _paintFront(canvas, line);
    canvas.restore();
    _paintEdges(canvas, line);
  }

  void _paintShadow(Canvas canvas) {
    canvas.save();
    canvas.translate(
      form.mm(AdiposeStyle.shadowX),
      form.mm(AdiposeStyle.shadowY),
    );
    final Color shadow = inks.shadow;
    canvas.drawPath(
      form.outline,
      Paint()..color = shadow.withValues(alpha: AdiposeStyle.shadowAlpha),
    );
    canvas.drawPath(
      form.outline,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = form.mm(AdiposeStyle.shadowSoft)
        ..strokeJoin = StrokeJoin.round
        ..color = shadow.withValues(alpha: 0.12),
    );
    canvas.restore();
  }

  void _paintSide(Canvas canvas, double line) {
    canvas.drawPath(form.sideSkin, Paint()..color = _sideOf(_dermisTone));
    final Paint fat = Paint()..color = homeTone;
    canvas.drawPath(form.sideSuperficial, fat);
    canvas.drawPath(form.sideDeep, fat);
    final Paint fascia = Paint()..color = _sideOf(_fasciaTone);
    canvas.drawPath(form.sideMembranous, fascia);
    canvas.drawPath(form.sideSheath, fascia);
    canvas.drawPath(form.sideRectus, Paint()..color = _sideOf(_muscleTone));
  }

  void _paintTop(Canvas canvas, double line) {
    canvas.drawPath(form.top, Paint()..color = _surface);
    canvas.save();
    canvas.clipPath(form.top);
    canvas.drawPath(
      _furrows,
      _stroke(
        inks.shadow.withValues(alpha: AdiposeStyle.furrowAlpha),
        0.8 * line,
      ),
    );
    canvas.restore();
  }

  void _paintFront(Canvas canvas, double line) {
    // The skin.
    canvas.drawPath(form.dermis, Paint()..color = _dermis);
    // The fat of both layers, flat, cut by its septa.
    final Paint fat = Paint()..color = homeTone;
    final double septum = math.max(
      form.mm(AdiposeAnatomy.superficialSeptum),
      AdiposeStyle.septumFloor * line,
    );
    canvas.drawPath(form.superficial, fat);
    canvas.save();
    canvas.clipPath(form.superficial);
    canvas.drawPath(_superficialSepta, _stroke(_septum, septum));
    canvas.restore();
    canvas.drawPath(form.deep, fat);
    canvas.save();
    canvas.clipPath(form.deep);
    canvas.drawPath(
      _deepSepta,
      _stroke(
        _septum,
        math.max(
          form.mm(AdiposeAnatomy.deepSeptum),
          AdiposeStyle.septumFloor * line,
        ),
      ),
    );
    canvas.restore();
    // The membranous layer, the rectus sheath, the rectus and its fascicles.
    final Paint fascia = Paint()..color = _fascia;
    canvas.drawPath(form.membranous, fascia);
    canvas.drawPath(form.sheath, fascia);
    canvas.drawPath(form.rectus, Paint()..color = _muscle);
    canvas.save();
    canvas.clipPath(form.rectus);
    canvas.drawPath(
      _fascicles,
      _stroke(
        inks.shadow.withValues(alpha: AdiposeStyle.fascicleAlpha),
        AdiposeStyle.fascicleWidth * line,
      ),
    );
    canvas.restore();
    canvas.drawPath(
      _layers,
      _stroke(
        inks.shadow.withValues(alpha: AdiposeStyle.layerAlpha),
        AdiposeStyle.layerFloor * line,
      ),
    );
    // The vessels: the perforator rising to the skin, the superficial
    // epigastric artery and vein cut across.
    final double floor = AdiposeStyle.vesselFloor * line;
    canvas.drawPath(
      _perforatorVein,
      _stroke(_vein, math.max(form.mm(AdiposeAnatomy.perforatorVein), floor)),
    );
    canvas.drawPath(
      _perforatorArtery,
      _stroke(
        _artery,
        math.max(form.mm(AdiposeAnatomy.perforatorArtery), floor),
      ),
    );
    final (Offset vein, double veinRadius) = form.epigastricVein;
    final (Offset artery, double arteryRadius) = form.epigastricArtery;
    canvas.drawCircle(
      vein,
      math.max(veinRadius, floor / 2),
      Paint()..color = _vein,
    );
    canvas.drawCircle(
      artery,
      math.max(arteryRadius, floor / 2),
      Paint()..color = _artery,
    );
    // The epidermis over it all, pale.
    canvas.drawPath(
      _lines(<List<Offset>>[form.epidermisLine]),
      _stroke(
        _epidermis,
        math.max(
          form.mm(AdiposeAnatomy.epidermis),
          AdiposeStyle.epidermisFloor * line,
        ),
      ),
    );
  }

  void _paintEdges(Canvas canvas, double line) {
    canvas.drawPath(
      _lines(<List<Offset>>[form.topEdge]),
      _stroke(
        inks
            .lit(AdiposeStyle.edgeLit)
            .withValues(alpha: AdiposeStyle.edgeAlpha),
        line,
      ),
    );
    canvas.drawPath(
      _lines(<List<Offset>>[form.sideEdge]),
      _stroke(inks.shadow.withValues(alpha: AdiposeStyle.edgeShadeAlpha), line),
    );
  }

  /// Every flat colour it fills or strokes with, for tests, by the part it
  /// draws.
  @visibleForTesting
  Map<String, Color> get fills => <String, Color>{
    'home': homeTone,
    'epidermis': _epidermis,
    'dermis': _dermis,
    'septum': _septum,
    'fascia': _fascia,
    'muscle': _muscle,
    'surface': _surface,
    'artery': _artery,
    'vein': _vein,
  };

  // Helpers.

  static Path _cells(List<List<Offset>> cells) {
    final Path path = Path();
    for (final List<Offset> cell in cells) {
      if (cell.length > 2) {
        path.addPolygon(cell, true);
      }
    }
    return path;
  }

  static Path _lines(List<List<Offset>> lines) {
    final Path path = Path();
    for (final List<Offset> points in lines) {
      path.moveTo(points.first.dx, points.first.dy);
      for (final Offset p in points.skip(1)) {
        path.lineTo(p.dx, p.dy);
      }
    }
    return path;
  }

  static Paint _stroke(Color colour, double width) => Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = width
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..color = colour;
}
