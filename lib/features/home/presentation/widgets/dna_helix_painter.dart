import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'helix_geometry.dart';

/// Draws the duplex back to front onto a flat, opaque ground.
///
/// Every colour this painter uses is fully opaque: depth is expressed by
/// mixing a palette colour *toward* [background] rather than by lowering its
/// alpha. Over a solid ground the two are the same composite, but opaque draws
/// never accumulate. Semi-transparent ones do — two round line caps meeting at
/// a shared vertex composite twice, so a strand drawn segment by segment picks
/// up a bright bead at every joint, and those beads crawl as the helix turns.
/// Painting opaque removes that whole class of artefact by construction.
///
/// The cost is that the widget must sit on [background] and nothing else. It
/// already had to: the nodes knock out a background-coloured disc behind them,
/// and the edge fade dissolves into the same colour.
class DnaHelixPainter extends CustomPainter {
  DnaHelixPainter({
    required Listenable repaint,
    required this.rotation,
    required this.drift,
    required this.transcription,
    required this.model,
    required this.backbone,
    required this.adenine,
    required this.thymine,
    required this.guanine,
    required this.cytosine,
    required this.transcript,
    required this.background,
  })  : _clear = background.withValues(alpha: 0),
        super(repaint: repaint) {
    _buildLuts();
  }

  final Animation<double> rotation;

  final Animation<double> drift;

  final Animation<double> transcription;

  final HelixModel model;

  final Color backbone;
  final Color adenine;
  final Color thymine;
  final Color guanine;
  final Color cytosine;

  final Color transcript;

  final Color background;

  final Color _clear;

  static const double _widthFraction = 0.40;

  static const double _overscan = 1.2;

  /// Nodes no longer read this — only the sideways sweep and the stroke widths
  /// do. Flattening it would buy nothing back on the pulsing, and would cost
  /// the parallax that now has to carry the depth read on its own.
  static const double _focalFactor = 12;

  static const double _cullMargin = 28;

  /// Depth is a continuous function of a point's angle, so the only true ties
  /// are genuine coincidences. Quantising the sort key coarsely invents ties
  /// that are not there and swaps draw order at the wrong moment: at 256 a
  /// primitive stayed in one bucket for about four frames, so flips landed
  /// late and several that should have been staggered collapsed onto a single
  /// frame. One frame of rotation moves depth by roughly a thousandth of its
  /// range, so this resolves each flip to the frame it belongs on.
  static const int _buckets = 4096;

  /// Shading varies only in how far a colour is mixed toward the background.
  /// The framebuffer holds that mix at 8 bits a channel, so 256 steps is
  /// exactly as fine as the result can be: depth reads as continuous.
  static const int _shadeSteps = 256;

  static const double _backboneMinShade = 0.55;
  static const double _backboneMaxShade = 1;

  static const double _rungMinShade = 0.85;
  static const double _rungMaxShade = 1;

  static const double _strandMinWidth = 2;
  static const double _strandMaxWidth = 3.2;

  static const double _rungMinWidth = 2.8;
  static const double _rungMaxWidth = 3.6;

  static const double _baseRadius = 6;

  static const double _purineScale = 1.10;
  static const double _pyrimidineScale = 0.90;

  static const double _ringWidth = 1.1;

  static const double _driftAmplitude = 8;
  static const double _fadeStop = 0.16;

  static const double _bubbleOpen = 0.26;

  /// How far past the cylinder the bubble spread can push a point, in depth.
  /// Clamping that away would flatten everything at the front of a bubble onto
  /// one depth, where the sort can only fall back on table order.
  static const double _depthMargin = _bubbleOpen / 2;

  /// A primitive fades by thinning now, so it can be carried much further
  /// down before it is dropped — but never to a width of exactly zero, which
  /// the rasteriser treats as a request for a full-strength hairline.
  static const double _fadeEpsilon = 0.002;

  final Paint _strokePaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;

  final Paint _fillPaint = Paint()..style = PaintingStyle.fill;

  final Paint _fadePaint = Paint();

  late final List<Color> _slotColour =
      List<Color>.filled(HelixPalette.count * _shadeSteps, background);

  late final Float32List _baseSizeScale = Float32List(HelixPalette.firstLit);

  late final Float32List _sx = Float32List(model.pointCount);
  late final Float32List _sy = Float32List(model.pointCount);
  late final Float32List _pointScale = Float32List(model.pointCount);
  late final Float32List _pointDepth = Float32List(model.pointCount);
  late final Float32List _pointFade = Float32List(model.pointCount);
  late final Float32List _primDepth = Float32List(model.primitiveCount);
  late final Float32List _primScale = Float32List(model.primitiveCount);
  late final Float32List _primFade = Float32List(model.primitiveCount);
  late final Int32List _primBucket = Int32List(model.primitiveCount);
  late final Int32List _order = Int32List(model.primitiveCount);
  late final Int32List _bucketStart = Int32List(_buckets + 1);

  int _visibleCount = 0;

  /// Half a nucleotide's thickness, in the normalised depth the sort uses.
  /// A base is a ball sitting on the backbone, so its front surface is nearer
  /// than its centre; sorting it by its centre is what let the strand paint
  /// across its face on some frames and not others.
  double _nodeDepthBias = 0;

  Size? _fadeSize;
  Rect _topFade = Rect.zero;
  Rect _bottomFade = Rect.zero;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) {
      return;
    }

    final double radius = math.min(model.radius, size.width * _widthFraction);
    final double height = math.max(model.modelHeight, size.height * _overscan);

    // Two independent terms, so they add: how far the ball's front surface
    // sits ahead of its centre, plus the uncertainty in the depth of the
    // strand segment spanning it. Well under the ~0.5 that separates the two
    // strands, so this only ever settles genuinely ambiguous ties.
    _nodeDepthBias = _baseRadius * _purineScale / (2 * radius) +
        math.max(model.sampleAngleStep / 4, model.rungDepthError);

    _project(size, radius, height);
    _sortByDepth(size.height);
    _drawPrimitives(canvas);
    _paintEdgeFade(canvas, size);
  }

  void _project(Size size, double radius, double height) {
    final double angle = rotation.value * 2 * math.pi;

    final double cr = math.cos(angle);
    final double sr = math.sin(angle);

    final double focal = radius * _focalFactor;
    final double centreX = size.width / 2;
    final double centreY = size.height / 2;
    final double driftY =
        math.sin(drift.value * 2 * math.pi) * _driftAmplitude;

    final double progress = transcription.value;
    final double reach = model.headReach;
    final double travel = 2 * reach;
    final double headA = reach - progress * travel;
    final double headB = reach - ((progress + 0.5) % 1) * travel;

    final double half = model.bubbleHalfWidth;
    final double span = model.transcriptSpan;

    final double tailLimit =
        (size.width / 2 - _baseRadius * _purineScale - _ringWidth) / radius -
            HelixModel.wanderAmplitude;
    final double tailX = math.max(HelixModel.transcriptTailX, -tailLimit);

    final Float32List pointCos = model.pointCos;
    final Float32List pointSin = model.pointSin;
    final Float32List pointAxial = model.pointAxial;
    final Float32List pointWander = model.pointWander;
    final Uint8List pointRole = model.pointRole;

    for (int i = 0; i < model.pointCount; i++) {
      final double axial = pointAxial[i];

      final double dA = axial - headA;
      final double dB = axial - headB;
      final double d = dA.abs() <= dB.abs() ? dA : dB;

      final bool inBubble = d > -half && d < half;
      final double bt = inBubble ? (d / half) * 0.5 + 0.5 : 0;

      final double open = inBubble ? _sample(model.bubbleSeparation, bt) : 0;
      final double cu = inBubble ? _sample(model.bubbleCosUnwind, bt) : 1;
      final double su = inBubble ? _sample(model.bubbleSinUnwind, bt) : 0;

      final double ct = cr * cu - sr * su;
      final double st = sr * cu + cr * su;

      final double cb = pointCos[i];
      final double sb = pointSin[i];
      double c = cb * ct - sb * st;
      double s = sb * ct + cb * st;

      final double spread = 1 + open * _bubbleOpen;
      c *= spread;
      s *= spread;

      double fade;
      if (pointRole[i] == HelixPointRole.transcript) {
        double t = double.infinity;
        if (dA > 0 && dA < span) {
          t = dA;
        }
        if (dB > 0 && dB < span && dB < t) {
          t = dB;
        }

        if (t == double.infinity) {
          fade = 0;
        } else {
          final double tt = t / span;
          final double peel = _sample(model.trailPeel, tt);
          fade = _sample(model.trailReveal, tt);

          c += (tailX + pointWander[i] - c) * peel;
          s += (HelixModel.transcriptTailZ - s) * peel;
        }
      } else {
        fade = inBubble ? _sample(model.bubblePairing, bt) : 1;
      }

      final double z = radius * s;
      final double scale = focal / (focal + z);

      _sx[i] = centreX + radius * c * scale;
      _sy[i] = centreY + axial * height + driftY;
      _pointScale[i] = scale;
      _pointFade[i] = fade;

      _pointDepth[i] = (1 - s) * 0.5;
    }
  }

  void _sortByDepth(double canvasHeight) {
    final int count = model.primitiveCount;
    final Int32List primStart = model.primStart;
    final Int32List primEnd = model.primEnd;
    final Uint8List primKind = model.primKind;

    const double top = -_cullMargin;
    final double bottom = canvasHeight + _cullMargin;

    _bucketStart.fillRange(0, _bucketStart.length, 0);
    _visibleCount = 0;

    for (int i = 0; i < count; i++) {
      final int a = primStart[i];
      final int b = primEnd[i];

      final double ya = _sy[a];
      final double yb = _sy[b];
      if ((ya < top && yb < top) || (ya > bottom && yb > bottom)) {
        _primBucket[i] = -1;
        continue;
      }

      final int kind = primKind[i];
      double fade = 1;
      if (kind != HelixPrimitiveKind.strandSegment &&
          kind != HelixPrimitiveKind.node) {
        fade = (_pointFade[a] + _pointFade[b]) * 0.5;
        if (fade < _fadeEpsilon) {
          _primBucket[i] = -1;
          continue;
        }
      }

      final double depth = (_pointDepth[a] + _pointDepth[b]) * 0.5;
      _primDepth[i] = depth;
      _primScale[i] = (_pointScale[a] + _pointScale[b]) * 0.5;
      _primFade[i] = fade;

      // Shading still uses the centre depth; only the sort sees the bias.
      final double sortDepth = kind == HelixPrimitiveKind.node ||
              kind == HelixPrimitiveKind.transcriptNode
          ? depth + _nodeDepthBias
          : depth;

      final int bucket =
          (((sortDepth + _depthMargin) / (1 + 2 * _depthMargin)) *
                  (_buckets - 1))
              .round()
              .clamp(0, _buckets - 1);
      _primBucket[i] = bucket;
      _bucketStart[bucket + 1]++;
      _visibleCount++;
    }

    for (int b = 1; b <= _buckets; b++) {
      _bucketStart[b] += _bucketStart[b - 1];
    }

    for (int i = 0; i < count; i++) {
      final int bucket = _primBucket[i];
      if (bucket >= 0) {
        _order[_bucketStart[bucket]++] = i;
      }
    }
  }

  void _drawPrimitives(Canvas canvas) {
    final int count = _visibleCount;
    final Int32List primStart = model.primStart;
    final Int32List primEnd = model.primEnd;
    final Uint8List primPalette = model.primPalette;
    final Uint8List primKind = model.primKind;

    for (int k = 0; k < count; k++) {
      final int i = _order[k];
      final int a = primStart[i];
      final int b = primEnd[i];

      final double depth = _primDepth[i].clamp(0.0, 1.0);
      final double scale = _primScale[i];
      final double fade = _primFade[i];
      final int kind = primKind[i];
      final int slot = primPalette[i];

      final bool isNode = kind == HelixPrimitiveKind.node ||
          kind == HelixPrimitiveKind.transcriptNode;

      // A base keeps its colour and its size wherever it is in the turn. Both
      // used to track depth, and together they swung a ball through 80% of its
      // area and 39% of its opacity once per revolution — read as a pulse, not
      // as rotation. Depth is left to occlusion, to the sideways parallax, and
      // to the strands.
      final double shade = isNode
          ? 1
          : (slot >= HelixPalette.firstLit
              ? _lerp(_backboneMinShade, _backboneMaxShade, depth)
              : _lerp(_rungMinShade, _rungMaxShade, depth));

      // Fade is deliberately absent here. Mixing a fading primitive toward the
      // background would make it erase whatever is behind it on its way out —
      // the same fault as an unfaded knockout halo, just spread over every
      // kind. Things leave by getting thinner instead, which also reads better:
      // a bond thins and parts as the bubble opens, a transcript tapers off.
      final int level =
          (shade * (_shadeSteps - 1)).round().clamp(0, _shadeSteps - 1);
      final Color colour = _slotColour[slot * _shadeSteps + level];

      if (isNode) {
        final Offset centre = Offset(_sx[a], _sy[a]);

        // Fade shrinks as well as blanches. Opaque colours mean a half-faded
        // node would otherwise stamp a solid background disc over whatever is
        // behind it, and blink out the moment it crossed the cull threshold.
        final double r = _baseRadius * _baseSizeScale[slot] * fade;

        _fillPaint.color = background;
        canvas.drawCircle(centre, r + _ringWidth * fade, _fillPaint);

        _fillPaint.color = colour;
        canvas.drawCircle(centre, r, _fillPaint);
        continue;
      }

      final double width = fade *
          scale *
          (kind == HelixPrimitiveKind.rungHalf
              ? _lerp(_rungMinWidth, _rungMaxWidth, depth) *
                  _baseSizeScale[slot]
              : _lerp(_strandMinWidth, _strandMaxWidth, depth));

      _strokePaint
        ..color = colour
        ..strokeWidth = width;
      canvas.drawLine(
        Offset(_sx[a], _sy[a]),
        Offset(_sx[b], _sy[b]),
        _strokePaint,
      );
    }
  }

  void _paintEdgeFade(Canvas canvas, Size size) {
    if (_fadeSize != size) {
      _fadeSize = size;

      final double band = size.height * _fadeStop;
      _topFade = Rect.fromLTWH(0, 0, size.width, band);
      _bottomFade = Rect.fromLTWH(0, size.height - band, size.width, band);

      _fadePaint.shader = ui.Gradient.linear(
        Offset.zero,
        Offset(0, size.height),
        <Color>[background, _clear, _clear, background],
        <double>[0, _fadeStop, 1 - _fadeStop, 1],
      );
    }

    canvas.drawRect(_topFade, _fadePaint);
    canvas.drawRect(_bottomFade, _fadePaint);
  }

  void _buildLuts() {
    assert(
      _rungsAndNodesCarryABaseSlot(),
      'rungs and nodes index _baseSizeScale by palette slot, so they may only '
      'carry a base slot',
    );

    for (int slot = 0; slot < HelixPalette.firstLit; slot++) {
      _baseSizeScale[slot] =
          HelixPalette.isPurine(slot) ? _purineScale : _pyrimidineScale;
    }

    for (int slot = 0; slot < HelixPalette.count; slot++) {
      final Color base = _paletteColor(slot);
      final int offset = slot * _shadeSteps;

      for (int a = 0; a < _shadeSteps; a++) {
        _slotColour[offset + a] =
            Color.lerp(background, base, a / (_shadeSteps - 1))!;
      }
    }
  }

  bool _rungsAndNodesCarryABaseSlot() {
    for (int i = 0; i < model.primitiveCount; i++) {
      final int kind = model.primKind[i];
      final bool indexesBySlot = kind == HelixPrimitiveKind.rungHalf ||
          kind == HelixPrimitiveKind.node ||
          kind == HelixPrimitiveKind.transcriptNode;
      if (indexesBySlot && model.primPalette[i] >= HelixPalette.firstLit) {
        return false;
      }
    }
    return true;
  }

  Color _paletteColor(int slot) => switch (slot) {
        HelixPalette.adenine => adenine,
        HelixPalette.thymine => thymine,
        HelixPalette.guanine => guanine,
        HelixPalette.cytosine => cytosine,
        HelixPalette.transcript => transcript,
        _ => backbone,
      };

  static double _lerp(double a, double b, double t) => a + (b - a) * t;

  /// Reads a profile table at a continuous position.
  ///
  /// The tables are only 129 entries wide, and a polymerase sweeps a point
  /// across the whole of one in a few seconds. Snapping to the nearest entry
  /// moved a peeling transcript point in jumps of up to ten pixels, each point
  /// stepping at its own moment — the tail shimmered rather than flowed.
  static double _sample(Float32List table, double t) {
    const int last = HelixModel.profileSteps - 1;
    final double x = (t * last).clamp(0.0, last.toDouble());
    final int i = x >= last ? last - 1 : x.floor();
    return table[i] + (table[i + 1] - table[i]) * (x - i);
  }

  @override
  bool shouldRepaint(covariant DnaHelixPainter oldDelegate) {
    return oldDelegate.rotation != rotation ||
        oldDelegate.drift != drift ||
        oldDelegate.transcription != transcription ||
        oldDelegate.model != model ||
        oldDelegate.backbone != backbone ||
        oldDelegate.adenine != adenine ||
        oldDelegate.thymine != thymine ||
        oldDelegate.guanine != guanine ||
        oldDelegate.cytosine != cytosine ||
        oldDelegate.transcript != transcript ||
        oldDelegate.background != background;
  }
}
