import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_typography.dart';
import 'helix_geometry.dart';

/// Draws a DNA double helix rotating about its vertical axis, with RNA
/// polymerases transcribing it.
///
/// ## The projection
///
/// The helix is modelled in real 3D and projected here, rather than faked with
/// two offset sine waves. Each point is
///
/// ```
/// x = radius * cos(t + phase + rotation)
/// z = radius * sin(t + phase + rotation)     // +z points away from the camera
/// y = axial position along the molecule
/// ```
///
/// flattened through a weak perspective divide:
///
/// ```
/// scale   = focal / (focal + z)
/// screenX = centreX + x * scale
/// screenY = centreY + y             // orthographic, deliberately
/// ```
///
/// Leaving the vertical axis orthographic is the one place this departs from a
/// textbook pinhole camera; [_project] carries the reasoning. Everything else
/// follows from having a real `z`: rungs foreshorten to nothing as they turn
/// edge-on because their two endpoints genuinely converge in the projection,
/// not because a special case narrows them. There is no code anywhere in this
/// file that adjusts a rung's width.
///
/// ## The sort
///
/// Painting strand A, then strand B, then the rungs would destroy the illusion
/// immediately: every rung would sit in front of every strand segment,
/// including segments genuinely nearer the camera. Instead every drawable —
/// each backbone segment, each half rung, each nucleotide, each letter, each
/// length of transcript — lives in one flat table built by [HelixModel], and
/// each frame the whole table is sorted back to front by average depth and
/// painted in that order. The painter's algorithm, applied to one list rather
/// than to layers.
///
/// That is what makes a rung pass *behind* the near backbone and *in front of*
/// the far one as the structure turns. Without it none of the rest matters.
///
/// The sort is a counting sort into fixed depth buckets rather than a
/// comparison sort: `z` is bounded by the radius, so the key range is known up
/// front and the whole thing collapses to three linear passes over
/// preallocated buffers, with no comparator and no allocation.
///
/// ## The bases
///
/// A nucleotide has to be *identifiable*, not merely present, and colour alone
/// cannot do that: two of the four Okabe-Ito hues are close in value, and no
/// hue survives being shown as half of a two-pixel line. So a base is a filled
/// disc with room for its own letter, and identity is carried on three
/// independent channels rather than one — hue, area, and the glyph itself.
///
/// The area channel is free and it is real biology. A and G are purines with
/// two fused rings and C and T are single-ring pyrimidines, which [HelixPalette]
/// already encodes in the low bit of the slot, so the discs differ in size for
/// the same reason the molecules do. Every pair is one of each, so every rung
/// is a large disc joined to a small one — legible even when the letters are
/// too far away to read.
///
/// Only the near face is lettered. A receding base is small, dim and partly
/// occluded; a glyph on it would be noise rather than information, and the
/// depth cue is already saying what needs saying there. Little is given up by
/// that, because the two strands sit 140 degrees apart and the lettered band
/// spans about 162, so the two ends of a pair are both lettered on the order
/// of one rung in the frame at a time. One letter per pair turns out to be the
/// right amount anyway: reading `A` tells you the far end is `T`, so the render
/// ends up teaching complementarity rather than merely asserting it.
///
/// ## The lighting
///
/// The outward normal at a point on the backbone is exactly `(cos, 0, sin)` —
/// which [_project] has already computed in order to place the point at all.
/// So a Lambert term costs two multiplies on values that are in hand.
///
/// The larger point is that *the shading model is free regardless of its
/// cost*, because colours are baked into lookup tables at construction. The
/// Blinn-Phong exponent below is evaluated a few hundred times when the
/// painter is built and never again — not once per primitive per frame.
///
/// Base pairs are deliberately left unlit. They are flat plates whose normal
/// runs along the helix axis, so a side light grazes them at a constant angle
/// however the molecule turns; giving them a sweeping highlight would be
/// wrong, and would also steal the eye from where it belongs.
///
/// ## Repainting
///
/// The merged animation listenable is handed to `super(repaint:)`, so the
/// ticker drives this painter directly without rebuilding any widget. The
/// painter is constructed once by its parent, which is why the [Paint] objects,
/// the laid-out glyphs and every scratch buffer can live as fields.
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
    _buildLabels();
  }

  /// Rotation phase, in turns.
  final Animation<double> rotation;

  /// Slow vertical wander, so the loop never quite lands on the same frame.
  final Animation<double> drift;

  /// Progress of the polymerases along the molecule, in traversals.
  final Animation<double> transcription;

  /// Precomputed, rotation-independent geometry.
  final HelixModel model;

  final Color backbone;
  final Color adenine;
  final Color thymine;
  final Color guanine;
  final Color cytosine;

  /// The RNA transcript's backbone — the product of the reaction, so it gets
  /// the app's accent rather than the duplex's muted slate.
  final Color transcript;

  /// The surface the helix sits on. Used for atmospheric perspective, for the
  /// shadowed side of the lighting model, for the letters cut out of each
  /// base, and for the edge fade.
  final Color background;

  /// [background] at zero alpha — see [_paintEdgeFade].
  final Color _clear;

  // --- Fit ------------------------------------------------------------------

  /// Half-width the helix is allowed to occupy, as a fraction of the canvas.
  static const double _widthFraction = 0.40;

  /// How far past the canvas the model is stretched when the canvas is taller
  /// than the model, so the ends never come into view.
  static const double _overscan = 1.2;

  /// Focal length as a multiple of the radius. Long: subtle depth, no fisheye.
  static const double _focalFactor = 12;

  /// Slack around the canvas, in pixels, before a primitive is culled. Wide
  /// enough to cover the widest glow pass, so nothing pops at the edges — that
  /// is now a base disc's halo rather than a line's, which is why it is not
  /// the small number it used to be.
  static const double _cullMargin = 28;

  // --- Depth cueing ---------------------------------------------------------

  static const int _depthSteps = 24;

  /// Steps along each table's second axis: shading for the lit slots, pairing
  /// for the base slots.
  static const int _modSteps = 16;

  static const int _buckets = 256;

  /// How far the far side of the cylinder is blended toward the background.
  static const double _atmosphere = 0.28;

  /// The same, for bases, and deliberately gentler.
  ///
  /// A backbone that sinks into the surface as it recedes is doing its job. A
  /// base that does has stopped being identifiable, and identity is the one
  /// thing a base cannot give up to depth. The light theme is where the
  /// difference shows: blending toward a near-white ground drains a hue far
  /// faster than blending toward a dark one does, and the far face was going
  /// pale there while reading correctly on dark.
  static const double _baseAtmosphere = 0.16;

  static const double _backboneMinAlpha = 0.32;
  static const double _backboneMaxAlpha = 0.95;

  /// How present the far face of the molecule is.
  ///
  /// Much higher than it was, and it has to be: the old value was tuned when a
  /// base was a hairline, where anything brighter smeared into the near face.
  /// A disc has an edge, so it stays a distinct object at an alpha that would
  /// have been unreadable as a line, and dropping the back of the molecule to
  /// near-invisibility to protect the front is no longer a trade worth making.
  static const double _baseMinAlpha = 0.50;
  static const double _baseMaxAlpha = 1;

  static const double _strandMinWidth = 1.3;
  static const double _strandMaxWidth = 4;

  /// A rung is now a bond between two bodies rather than the base pair itself,
  /// so it is drawn at something like the weight of the chemistry it stands
  /// for instead of the width that used to have to carry the colour.
  static const double _rungMinWidth = 2.2;
  static const double _rungMaxWidth = 5.5;

  /// Radius of a base at the front of the cylinder, before its ring-count
  /// factor. Set against the rise between base pairs — about 29 logical pixels
  /// at the default geometry — so that two bases stacked at the silhouette,
  /// where the strand runs vertically and they are closest, still show a clear
  /// gap.
  static const double _baseRadius = 9;

  /// Size factors for the two ring counts, applied to both a base's disc and
  /// its half of the rung.
  ///
  /// A purine's fused pair of rings measures about 1.3 times a pyrimidine's
  /// single ring across; this is 1.22, which understates the difference rather
  /// than caricaturing it, and still leaves the smaller disc room for a letter.
  static const double _purineScale = 1.10;
  static const double _pyrimidineScale = 0.90;

  /// How far a base at the back of the cylinder shrinks. Enough to read as
  /// depth, not so much that a far base stops being a shape.
  static const double _baseMinScale = 0.62;

  /// Width of the background-coloured ring drawn under every base.
  ///
  /// Bases overlap constantly — a pair seen edge-on collapses onto itself, and
  /// the strand crowds them together at the silhouette. Separating each disc
  /// from whatever is behind it with a sliver of the background is what keeps
  /// two overlapping bases reading as two. It is the same cut-out treatment as
  /// the letters, for the same reason.
  static const double _ringWidth = 1.3;

  // --- Letters --------------------------------------------------------------

  /// Type size for a base's letter, in logical pixels.
  ///
  /// Sized against the *smallest* disc that ever gets one — a pyrimidine at
  /// [_labelDepth], about fourteen pixels across — so a letter never crowds
  /// its own body. On the larger discs it simply sits in more space, which is
  /// correct: these are labels, and labels of one size read as a set.
  static const double _labelSize = 11;

  /// Depth below which a base goes unlettered. See the note on the class.
  static const double _labelDepth = 0.58;

  /// Quantisation of the lettered band. Both the type size and the opacity of
  /// a letter are functions of depth alone, so one index covers both, and a
  /// laid-out glyph can be reused rather than re-measured.
  static const int _labelSteps = 6;

  /// How many of those steps a letter takes to reach full opacity, so it fades
  /// up with its disc instead of switching on at the threshold.
  static const int _labelFadeSteps = 3;

  /// How far the type shrinks across the lettered band.
  static const double _labelMinScale = 0.82;

  /// Layout width each glyph is centred in. Any value wider than the glyph
  /// does; fixing it makes the horizontal centring a constant rather than a
  /// per-glyph measurement.
  static const double _labelBox = 32;

  /// JetBrains Mono's cap height, as a fraction of the em.
  ///
  /// A capital centred on its layout box sits visibly low, because the box
  /// reserves descender space that no capital uses. Flutter exposes the
  /// baseline but not the cap height, and this is a bundled face at a known
  /// version, so the metric is taken from the font.
  static const double _capHeightRatio = 0.73;

  /// Glyph slots. The first four are [HelixPalette]'s base slots, so a duplex
  /// base indexes its letter with the palette slot it already has.
  static const int _glyphCount = 5;

  /// RNA's uracil. Thymine's colour stands in for it — the palette says so —
  /// but the letter must not, since it is the one character that distinguishes
  /// the transcript from the template it was copied off.
  static const int _uracil = 4;

  // --- Lighting -------------------------------------------------------------

  /// Light direction in the xz plane, fixed in world space so that highlights
  /// sweep across the surface as the molecule turns. That sweep does more to
  /// sell the rotation than the depth fade does.
  static const double _lightX = -0.53;
  static const double _lightZ = -0.85;

  /// Blinn-Phong halfway vector, for a viewer on the -z axis.
  static const double _halfX = -0.275;
  static const double _halfZ = -0.961;

  static const double _ambient = 0.30;
  static const double _diffuse = 0.70;
  static const double _shininess = 22;

  /// Where diffuse shading ends and the specular lobe begins on the shade
  /// axis. Splitting one axis this way keeps the table two-dimensional.
  static const double _specSplit = 0.72;

  static const int _specSteps = 65;

  /// How far a specular peak lifts the colour toward white. Kept well under 1:
  /// spec §4 wants the backbone quieter than the base pairs, and an uncapped
  /// highlight would invert that every time it swept past.
  static const double _specLift = 0.55;

  // --- Glow -----------------------------------------------------------------

  static const double _glowThreshold = 0.55;
  static const double _glowAlpha = 0.11;
  static const double _lineGlowScale = 3.2;

  /// Tighter than the line glow, and far tighter than it was. A halo scaled
  /// off a hairline is a suggestion; the same multiple on a twenty-pixel disc
  /// is a blob that swallows its neighbours.
  static const double _nodeGlowScale = 1.35;

  // --- Motion and framing ---------------------------------------------------

  static const double _driftAmplitude = 8;
  static const double _fadeStop = 0.16;

  /// How far the duplex is pushed open at the centre of a bubble, in radii.
  static const double _bubbleOpen = 0.40;

  /// Below this, a primitive has been faded out by the process and is skipped.
  static const double _fadeEpsilon = 0.02;

  /// The first depth step that gets a glow pass, so the loop can skip the test
  /// with an integer compare.
  static final int _glowStep = (_glowThreshold * (_depthSteps - 1)).ceil();

  /// Reciprocal of the lettered band, so the loop maps depth to a glyph step
  /// with a multiply.
  static const double _labelRange = 1 / (1 - _labelDepth);

  static const int _litSlots = HelixPalette.count - HelixPalette.firstLit;
  static const int _litSize = _litSlots * _depthSteps * _modSteps;
  static const int _baseSize = HelixPalette.firstLit * _depthSteps * _modSteps;

  // Reused across every frame and every primitive. Only `color` and
  // `strokeWidth` are touched as the loop runs.
  final Paint _strokePaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;

  final Paint _fillPaint = Paint()..style = PaintingStyle.fill;

  final Paint _fadePaint = Paint();

  /// Colours for the lit slots — the two backbones — indexed
  /// `((slot - firstLit) * depth + d) * mod + shade`.
  ///
  /// `withValues` and `Color.lerp` each allocate. Doing either per primitive
  /// would mean tens of thousands of short-lived objects a second, which is
  /// the largest single threat to the frame budget here — so every table is
  /// baked once and the draw loop does an index lookup.
  late final List<Color> _litCore = List<Color>.filled(_litSize, _clear);
  late final List<Color> _litGlow = List<Color>.filled(_litSize, _clear);

  /// Colours for the four bases, indexed `(slot * depth + d) * mod + pairing`.
  /// The second axis is how intact the base pair is, not how it is lit.
  late final List<Color> _baseCore = List<Color>.filled(_baseSize, _clear);
  late final List<Color> _baseGlow = List<Color>.filled(_baseSize, _clear);

  /// The background, at whatever alpha a base at that depth carries, for the
  /// ring cut under each disc. Depth is the only axis it needs: a node is
  /// never pair-faded.
  late final List<Color> _ringColour = List<Color>.filled(_depthSteps, _clear);

  /// Size factor per base slot, from its ring count.
  late final Float32List _baseSizeScale = Float32List(HelixPalette.firstLit);

  /// The lettering, laid out once and indexed `glyph * _labelSteps + step`.
  ///
  /// The same principle as the colour tables above, and for the same reason:
  /// laying out text shapes it, and shaping tens of glyphs a frame would cost
  /// more than everything else in this file put together. Shaping thirty of
  /// them at construction costs about a millisecond, once.
  ///
  /// Thirty and not more because the letters need only one colour between
  /// them. Each is cut out of its disc in the surface colour, which guarantees
  /// contrast against all four hues in both themes and ties the glyph to the
  /// ring under the disc as a single treatment.
  late final List<TextPainter> _labels = <TextPainter>[];

  /// Distance from the top of a laid-out glyph's box down to the centre of its
  /// ink, per step. Subtracting it from a disc's centre puts the letter in the
  /// middle of the body rather than in the middle of its line box.
  late final Float32List _labelDy = Float32List(_labelSteps);

  /// `pow(cos, shininess)`, so the exponent never runs at draw time.
  late final Float32List _specular = Float32List(_specSteps);

  // Per-frame scratch, sized once from the model.
  late final Float32List _sx = Float32List(model.pointCount);
  late final Float32List _sy = Float32List(model.pointCount);
  late final Float32List _pointScale = Float32List(model.pointCount);
  late final Float32List _pointDepth = Float32List(model.pointCount);
  late final Float32List _pointShade = Float32List(model.pointCount);
  late final Float32List _pointFade = Float32List(model.pointCount);
  late final Float32List _primDepth = Float32List(model.primitiveCount);
  late final Float32List _primScale = Float32List(model.primitiveCount);
  late final Float32List _primShade = Float32List(model.primitiveCount);
  late final Float32List _primFade = Float32List(model.primitiveCount);
  late final Int32List _primBucket = Int32List(model.primitiveCount);
  late final Int32List _order = Int32List(model.primitiveCount);
  late final Int32List _bucketStart = Int32List(_buckets + 1);

  /// How much of [_order] the last sort actually filled. The model is taller
  /// than the viewport by design, so this is well below the primitive count.
  int _visibleCount = 0;

  // The edge-fade shader depends only on the canvas, so it survives until the
  // widget is resized.
  Size? _fadeSize;
  Rect _fadeRect = Rect.zero;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) {
      return;
    }

    // Two clamps cover every canvas the widget can be handed. On a phone in
    // portrait both are no-ops and the helix renders at its designed size.
    final double radius = math.min(model.radius, size.width * _widthFraction);
    final double height = math.max(model.modelHeight, size.height * _overscan);

    _project(size, radius, height);
    _sortByDepth(size.height);
    _drawPrimitives(canvas);
    _paintEdgeFade(canvas, size);
  }

  /// Rotates, deforms and projects every point into the screen-space scratch
  /// buffers.
  void _project(Size size, double radius, double height) {
    final double angle = rotation.value * 2 * math.pi;

    // The only two trigonometric calls in the frame. Every point's rotated
    // cosine and sine comes from these by the angle addition identity — see
    // the note on [HelixModel].
    final double cr = math.cos(angle);
    final double sr = math.sin(angle);

    final double focal = radius * _focalFactor;
    final double centreX = size.width / 2;
    final double centreY = size.height / 2;
    final double driftY = (drift.value - 0.5) * 2 * _driftAmplitude;

    // Two polymerases, half a traversal apart. Real genes carry several at
    // once, each trailing a longer transcript; here the second one also means
    // the frame is never empty, since a single enzyme would spend most of its
    // run outside the viewport.
    final double progress = transcription.value;
    final double headA = 0.5 - progress;
    final double headB = 0.5 - (progress + 0.5) % 1;

    final double half = model.bubbleHalfWidth;
    final double span = model.transcriptSpan;
    const int lastProfile = HelixModel.profileSteps - 1;

    // Keep the free transcript inside the canvas on a narrow screen. The tail
    // is where the strand settles, not where it stops moving, so what has to
    // fit is the wander either side of it plus the radius of a base sitting on
    // it — a margin of ten pixels was enough when the RNA was a line with dots
    // on it and is not now.
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

      // Distance to each active site. The nearer one owns this point; the two
      // windows never overlap, so this is exact rather than a blend.
      final double dA = axial - headA;
      final double dB = axial - headB;
      final double d = dA.abs() <= dB.abs() ? dA : dB;

      final bool inBubble = d > -half && d < half;
      final int bi =
          inBubble ? (((d / half) * 0.5 + 0.5) * lastProfile).round() : 0;

      final double open = inBubble ? model.bubbleSeparation[bi] : 0;
      final double cu = inBubble ? model.bubbleCosUnwind[bi] : 1;
      final double su = inBubble ? model.bubbleSinUnwind[bi] : 0;

      // Compose the frame's rotation with this point's local untwist, then
      // apply the pair to the point. Two nested applications of the same
      // identity, both fed by tables — still no trigonometry here.
      final double ct = cr * cu - sr * su;
      final double st = sr * cu + cr * su;

      final double cb = pointCos[i];
      final double sb = pointSin[i];
      double c = cb * ct - sb * st;
      double s = sb * ct + cb * st;

      // The duplex balloons open where the enzyme holds it apart.
      final double spread = 1 + open * _bubbleOpen;
      c *= spread;
      s *= spread;

      double fade;
      if (pointRole[i] == HelixPointRole.transcript) {
        // Trailing distance behind whichever polymerase laid this base down.
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
          final int ti = ((t / span) * lastProfile).round();
          final double peel = model.trailPeel[ti];
          fade = model.trailReveal[ti];

          // Peel toward a fixed tail rather than a rotated one: RNA that has
          // left the duplex is no longer wound around it, and must not keep
          // spinning with it.
          c += (tailX + pointWander[i] - c) * peel;
          s += (HelixModel.transcriptTailZ - s) * peel;
        }
      } else {
        // How much base pairing survives here. Only the rungs read this; the
        // nucleotides themselves stay put whether or not they are paired.
        fade = inBubble ? model.bubblePairing[bi] : 1;
      }

      final double z = radius * s;
      final double scale = focal / (focal + z);

      _sx[i] = centreX + radius * c * scale;
      // Horizontal is projected, vertical is not.
      //
      // A full perspective divide on the axial term would be geometrically
      // correct, but it is wrong for this shape: the model is taller than the
      // focal length, so a point half a model-height from the centre shifts
      // vertically by tens of pixels purely according to its depth. The two
      // ends of a base pair sit at the same axial height but different depths,
      // so each rung would tilt — and the tilt grows with distance from the
      // centre, until rungs visibly cross one another. Base pairs are
      // perpendicular to the axis, and the eye knows it.
      //
      // Keeping y orthographic costs nothing: depth is already carried by the
      // horizontal projection, the width taper, the atmospheric tint and the
      // sort. It is the x divide that foreshortens the rungs, and that is
      // untouched.
      _sy[i] = centreY + axial * height + driftY;
      _pointScale[i] = scale;
      _pointFade[i] = fade;

      // `s` is already z/radius, so this is 1 at the front of the cylinder and
      // 0 at the back, with no extra division.
      _pointDepth[i] = ((1 - s) * 0.5).clamp(0.0, 1.0);

      // Lambert plus a Blinn-Phong lobe, both read straight off the normal the
      // projection already produced.
      final double nl = c * _lightX + s * _lightZ;
      final double nh = c * _halfX + s * _halfZ;
      final double lambert = nl > 0 ? nl : 0;
      final double spec = nh > 0
          ? _specular[(nh.clamp(0.0, 1.0) * (_specSteps - 1)).toInt()]
          : 0;
      _pointShade[i] =
          (_ambient + _diffuse * lambert).clamp(0.0, 1.0) * _specSplit +
              spec * (1 - _specSplit);
    }
  }

  /// Orders every visible primitive back to front by average depth.
  ///
  /// Counting sort: count into buckets, prefix-sum the counts into start
  /// offsets, then scatter. Bucket 0 is the far side of the cylinder, so
  /// walking [_order] forward is already back-to-front. The scatter pass
  /// consumes [_bucketStart] as it goes, which is why it is rebuilt each frame
  /// rather than kept.
  ///
  /// Three linear passes over preallocated buffers, no comparator, and a key
  /// range that is known in advance because `z` is bounded by the radius.
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

      // The molecule runs off both ends of the frame by design, so a good half
      // of it is out of view at any moment. Dropping those here keeps the sort
      // and the draw loop proportional to what is actually on screen rather
      // than to the length of the model.
      final double ya = _sy[a];
      final double yb = _sy[b];
      if ((ya < top && yb < top) || (ya > bottom && yb > bottom)) {
        _primBucket[i] = -1;
        continue;
      }

      // Rungs inside a bubble, and transcript that has not been laid down yet,
      // fade to nothing. Skipping them here keeps the cost of the process
      // proportional to how much of it is actually on screen.
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
      _primShade[i] = (_pointShade[a] + _pointShade[b]) * 0.5;
      _primFade[i] = fade;

      final int bucket =
          (depth * (_buckets - 1)).round().clamp(0, _buckets - 1);
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

  /// Paints the sorted table. Two draw calls for near geometry — a wide faint
  /// pass under a crisp one — and one for everything else.
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

      final double depth = _primDepth[i];
      final double scale = _primScale[i];
      final int kind = primKind[i];
      final int slot = primPalette[i];

      final int step =
          (depth * (_depthSteps - 1)).round().clamp(0, _depthSteps - 1);

      // The two tables differ in what their second axis means: how a backbone
      // is lit, or how intact a base pair is.
      final List<Color> core;
      final List<Color> glow;
      final int index;
      if (slot >= HelixPalette.firstLit) {
        final int shade =
            (_primShade[i] * (_modSteps - 1)).round().clamp(0, _modSteps - 1);
        core = _litCore;
        glow = _litGlow;
        index =
            ((slot - HelixPalette.firstLit) * _depthSteps + step) * _modSteps +
                shade;
      } else {
        final int pairing =
            (_primFade[i] * (_modSteps - 1)).round().clamp(0, _modSteps - 1);
        core = _baseCore;
        glow = _baseGlow;
        index = (slot * _depthSteps + step) * _modSteps + pairing;
      }

      // Everything near enough gets a glow pass, except a rung. A rung is now
      // a short, wide stroke with a deliberate gap at its junction, and a halo
      // three times its width closes that gap back up — the one cue that says
      // a pair is two molecules rather than one bar, lost to an effect that
      // was written for hairlines and has bodies to bloom off now instead.
      final bool glows =
          step >= _glowStep && kind != HelixPrimitiveKind.rungHalf;

      if (kind == HelixPrimitiveKind.node ||
          kind == HelixPrimitiveKind.transcriptNode) {
        final Offset centre = Offset(_sx[a], _sy[a]);
        final double r = _baseRadius *
            _baseSizeScale[slot] *
            scale *
            _lerp(_baseMinScale, 1, depth);

        if (glows) {
          _fillPaint.color = glow[index];
          canvas.drawCircle(centre, r * _nodeGlowScale, _fillPaint);
        }

        // Ring under disc rather than a stroke around it. Two fills cost the
        // same as a fill and a stroke, and this way the loop never has to put
        // the stroke paint back the way it found it.
        _fillPaint.color = _ringColour[step];
        canvas.drawCircle(centre, r + _ringWidth, _fillPaint);

        _fillPaint.color = core[index];
        canvas.drawCircle(centre, r, _fillPaint);

        if (depth >= _labelDepth) {
          final int byDepth =
              ((depth - _labelDepth) * _labelRange * (_labelSteps - 1))
                  .round()
                  .clamp(0, _labelSteps - 1);

          // A transcript base fades out along the tail of the strand where a
          // duplex base never does, so the lower of the two ramps wins. That
          // makes a letter recede with its own body instead of outliving it;
          // on the duplex the fade is always one and this does nothing.
          final int byFade = (_primFade[i] * (_labelSteps - 1))
              .round()
              .clamp(0, _labelSteps - 1);
          final int ls = byDepth < byFade ? byDepth : byFade;

          // The transcript is RNA, so what sits in thymine's slot is really
          // uracil. The palette deliberately does not distinguish them by
          // colour; this is the one place it matters, and a letter says it
          // better than a fifth hue would.
          final int glyph = kind == HelixPrimitiveKind.transcriptNode &&
                  slot == HelixPalette.thymine
              ? _uracil
              : slot;

          _labels[glyph * _labelSteps + ls].paint(
            canvas,
            Offset(centre.dx - _labelBox / 2, centre.dy - _labelDy[ls]),
          );
        }
        continue;
      }

      final Offset from = Offset(_sx[a], _sy[a]);
      final Offset to = Offset(_sx[b], _sy[b]);

      // Width narrows with the perspective scale and again with depth, and a
      // rung half also carries its base's ring-count factor, so the purine
      // side of a pair is the thicker as well as the longer one. The *length*
      // of a rung is left entirely to the projection.
      final double width = scale *
          (kind == HelixPrimitiveKind.rungHalf
              ? _lerp(_rungMinWidth, _rungMaxWidth, depth) *
                  _baseSizeScale[slot]
              : _lerp(_strandMinWidth, _strandMaxWidth, depth));

      if (glows) {
        _strokePaint
          ..color = glow[index]
          ..strokeWidth = width * _lineGlowScale;
        canvas.drawLine(from, to, _strokePaint);
      }

      _strokePaint
        ..color = core[index]
        ..strokeWidth = width;
      canvas.drawLine(from, to, _strokePaint);
    }
  }

  /// Softens the top and bottom edges so the helix reads as a section of
  /// something longer rather than an object with cut ends.
  ///
  /// A gradient rect rather than a [ShaderMask]: the mask would force a
  /// `saveLayer` on every frame, which is exactly the cost this painter is
  /// built to avoid. The shader outlives every frame at a given size.
  void _paintEdgeFade(Canvas canvas, Size size) {
    if (_fadeSize != size) {
      _fadeSize = size;
      _fadeRect = Offset.zero & size;

      // The midpoints fade to the background colour at zero alpha, not to
      // `Colors.transparent` — that is transparent *black*, and interpolating
      // toward it drags a grey bruise through the gradient. Obvious on the
      // light theme, subtle and ugly on the dark one.
      _fadePaint.shader = ui.Gradient.linear(
        Offset.zero,
        Offset(0, size.height),
        <Color>[background, _clear, _clear, background],
        <double>[0, _fadeStop, 1 - _fadeStop, 1],
      );
    }

    canvas.drawRect(_fadeRect, _fadePaint);
  }

  void _buildLuts() {
    for (int i = 0; i < _specSteps; i++) {
      _specular[i] = math.pow(i / (_specSteps - 1), _shininess).toDouble();
    }

    // Ring count decides how large a base is drawn, on both its disc and its
    // half of the rung. See the note on [HelixPalette]'s ordering.
    for (int slot = 0; slot < HelixPalette.firstLit; slot++) {
      _baseSizeScale[slot] =
          HelixPalette.isPurine(slot) ? _purineScale : _pyrimidineScale;
    }

    // --- Bases: the second axis is how intact the pair is -------------------
    for (int slot = 0; slot < HelixPalette.firstLit; slot++) {
      final Color base = _paletteColor(slot);

      for (int d = 0; d < _depthSteps; d++) {
        final double depth = d / (_depthSteps - 1);
        final Color tinted = _atmospheric(base, depth, _baseAtmosphere);
        final double alpha = _lerp(_baseMinAlpha, _baseMaxAlpha, depth);

        for (int m = 0; m < _modSteps; m++) {
          final double pairing = m / (_modSteps - 1);
          final int index = (slot * _depthSteps + d) * _modSteps + m;
          _bake(
            _baseCore,
            _baseGlow,
            index,
            tinted,
            alpha * pairing,
            depth,
            pairing,
          );
        }
      }
    }

    // The ring under a disc takes the alpha the disc itself is carrying, so it
    // reads as the background showing through rather than as a painted outline
    // that would go on announcing itself after its base had faded away.
    for (int d = 0; d < _depthSteps; d++) {
      final double depth = d / (_depthSteps - 1);
      _ringColour[d] = background.withValues(
        alpha: _lerp(_baseMinAlpha, _baseMaxAlpha, depth),
      );
    }

    // --- Backbones: the second axis is how they are lit ---------------------
    for (int slot = HelixPalette.firstLit; slot < HelixPalette.count; slot++) {
      final Color base = _paletteColor(slot);

      for (int d = 0; d < _depthSteps; d++) {
        final double depth = d / (_depthSteps - 1);
        final Color tinted = _atmospheric(base, depth, _atmosphere);
        final double alpha = _lerp(_backboneMinAlpha, _backboneMaxAlpha, depth);

        // The unlit side sinks toward the background rather than toward black,
        // so a backbone in shadow recedes instead of turning into a hole.
        final Color shadowed = Color.lerp(tinted, background, 0.55)!;
        final Color highlight =
            Color.lerp(tinted, const Color(0xFFFFFFFF), 0.8)!;

        for (int m = 0; m < _modSteps; m++) {
          final double shade = m / (_modSteps - 1);
          final double lambert = (shade / _specSplit).clamp(0.0, 1.0);
          final double spec =
              ((shade - _specSplit) / (1 - _specSplit)).clamp(0.0, 1.0);

          final Color body = Color.lerp(shadowed, tinted, lambert)!;
          final Color lit = Color.lerp(body, highlight, spec * _specLift)!;

          final int index =
              ((slot - HelixPalette.firstLit) * _depthSteps + d) * _modSteps +
                  m;
          _bake(_litCore, _litGlow, index, lit, alpha, depth, 1);
        }
      }
    }
  }

  /// Lays out every letter the draw loop can ever need, once.
  ///
  /// Five glyphs across [_labelSteps] sizes. Size and opacity are both
  /// functions of depth alone, so a single axis carries both and the loop
  /// reaches a finished, shaped glyph with one index and no measuring.
  void _buildLabels() {
    const List<String> glyphs = <String>['A', 'T', 'G', 'C', 'U'];
    assert(glyphs.length == _glyphCount, 'one glyph per slot, plus uracil');

    for (int g = 0; g < _glyphCount; g++) {
      for (int s = 0; s < _labelSteps; s++) {
        final double t = s / (_labelSteps - 1);
        final double size = _labelSize * _lerp(_labelMinScale, 1, t);
        final double alpha = ((s + 1) / _labelFadeSteps).clamp(0.0, 1.0);

        // Left unscaled by the platform text setting, which is what
        // [TextPainter] does unless told otherwise and what is wanted here:
        // the letter is sized to a disc rather than to a paragraph, and
        // growing one without the other would push the glyph out of the shape
        // that identifies it. Every other piece of type in the app scales.
        final TextPainter painter = TextPainter(
          text: TextSpan(
            text: glyphs[g],
            style: AppTypography.baseGlyph(
              background.withValues(alpha: alpha),
              size,
            ),
          ),
          textAlign: TextAlign.center,
          textDirection: TextDirection.ltr,
        )..layout(minWidth: _labelBox, maxWidth: _labelBox);

        _labels.add(painter);

        // Every glyph is a capital in a monospace face, so the metrics are the
        // same across all five at a given size and only need measuring once.
        if (g == 0) {
          final double baseline =
              painter.computeDistanceToActualBaseline(TextBaseline.alphabetic);
          _labelDy[s] = baseline - size * _capHeightRatio / 2;
        }
      }
    }
  }

  /// Atmospheric perspective: far geometry sinks toward the background instead
  /// of merely going translucent. How far it sinks depends on what it is —
  /// see [_baseAtmosphere].
  Color _atmospheric(Color base, double depth, double amount) =>
      Color.lerp(base, background, (1 - depth) * amount)!;

  /// Writes one entry into a core table and its matching glow table.
  void _bake(
    List<Color> core,
    List<Color> glow,
    int index,
    Color colour,
    double alpha,
    double depth,
    double fade,
  ) {
    core[index] = colour.withValues(alpha: alpha);
    glow[index] = colour.withValues(
      alpha: _glowAlpha *
          fade *
          ((depth - _glowThreshold) / (1 - _glowThreshold)).clamp(0.0, 1.0),
    );
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

  @override
  bool shouldRepaint(covariant DnaHelixPainter oldDelegate) {
    // Per-frame repainting is driven by `repaint:`, so this only runs when the
    // painter is reconstructed — which happens on a theme change or when the
    // widget's geometry parameters change. These comparisons cover exactly
    // those cases.
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
