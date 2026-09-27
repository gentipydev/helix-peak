import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../../core/theme/nucleotide_colors.dart';
import '../../../../shared/helix/helix_geometry.dart';
import '../domain/locus_track.dart';
import '../domain/zoom_path.dart';
import '../domain/zoom_scale.dart';

/// Every colour the zoom draws with, from the theme.
@immutable
final class ZoomInks {
  const ZoomInks({
    required this.bases,
    required this.outline,
    required this.body,
    required this.mark,
    required this.cell,
    required this.nucleus,
    required this.stain,
    required this.pale,
    required this.label,
    required this.ground,
  });

  factory ZoomInks.of(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return ZoomInks(
      bases: context.nucleotideColors,
      outline: scheme.outline,
      body: scheme.surfaceContainerHigh,
      mark: scheme.primary,
      cell: scheme.surfaceContainerHighest,
      nucleus: scheme.onSurfaceVariant,
      stain: scheme.onSurface,
      pale: scheme.surfaceBright,
      label: scheme.onSurfaceVariant,
      ground: scheme.surface,
    );
  }

  final NucleotideColors bases;
  final Color outline;
  final Color body;

  /// What the zoom follows: the organ, the cell, the band.
  final Color mark;
  final Color cell;
  final Color nucleus;

  /// Giemsa, and the bands that take none of it.
  final Color stain;
  final Color pale;
  final Color label;

  /// What the screen is drawn on: the plate under the scale bar.
  final Color ground;

  @override
  bool operator ==(Object other) =>
      other is ZoomInks &&
      other.bases == bases &&
      other.outline == outline &&
      other.body == body &&
      other.mark == mark &&
      other.cell == cell &&
      other.nucleus == nucleus &&
      other.stain == stain &&
      other.pale == pale &&
      other.label == label &&
      other.ground == ground;

  @override
  int get hashCode => Object.hash(
    bases,
    outline,
    body,
    mark,
    cell,
    nucleus,
    stain,
    pale,
    label,
    ground,
  );
}

/// Where each of the Atlas's tissues lies in a body standing facing the
/// reader, in metres from the top of the head and across from its midline,
/// the body's own left to the reader's right. General anatomy: a tissue's
/// place, not any gene's.
const Map<String, (double, double)> tissuePlaces = <String, (double, double)>{
  'brain': (0.08, 0),
  'choroid plexus': (0.09, 0.01),
  'cerebral cortex': (0.06, 0.03),
  'pituitary gland': (0.10, 0),
  'retina': (0.11, 0.03),
  'tongue': (0.16, 0),
  'salivary gland': (0.17, -0.05),
  'thyroid gland': (0.22, 0),
  'parathyroid gland': (0.22, 0.015),
  'lymphoid tissue': (0.21, -0.05),
  'esophagus': (0.30, 0),
  'thymus': (0.32, 0),
  'breast': (0.40, -0.08),
  'lung': (0.40, -0.08),
  'heart muscle': (0.42, 0.04),
  'liver': (0.50, -0.07),
  'gallbladder': (0.53, -0.05),
  'stomach': (0.50, 0.06),
  'spleen': (0.49, 0.10),
  'pancreas': (0.53, 0.035),
  'adrenal gland': (0.52, -0.05),
  'kidney': (0.56, 0.06),
  'intestine': (0.66, 0),
  'small intestine': (0.66, 0),
  'colon': (0.70, -0.04),
  'appendix': (0.72, -0.06),
  'smooth muscle': (0.68, 0.02),
  'adipose tissue': (0.62, 0.12),
  'placenta': (0.72, 0),
  'bone marrow': (0.80, 0.09),
  'urinary bladder': (0.86, 0),
  'endometrium': (0.83, 0),
  'cervix': (0.85, 0),
  'vagina': (0.88, 0),
  'fallopian tube': (0.82, 0.06),
  'ovary': (0.83, 0.08),
  'prostate': (0.89, 0),
  'seminal vesicle': (0.88, 0.02),
  'ductus deferens': (0.90, 0.03),
  'epididymis': (0.93, 0.03),
  'testis': (0.94, 0.02),
  'skin': (0.60, -0.24),
  'skeletal muscle': (1.08, 0.08),
};

/// [tissue]'s place, by the name the zoom's path gives it; null for a name
/// the table lacks.
(double, double)? placeOf(String tissue) => tissuePlaces[tissue.toLowerCase()];

/// A continuous zoom from a body to a gene, one layer per level, crossfaded
/// as the view's width passes from one level's to the next.
///
/// Each layer is drawn in its own units, the width of the view at its level,
/// and scaled to the width the view has now. It grows as the view closes in
/// on the place the next level lies in, its focus, which drifts to the centre
/// meanwhile, and the next level is drawn around that place.
/// Every level but two is illustration. The chromosome is the locus track's:
/// its bands, stained as cytoBand says, the gene's band marked, never the gene.
/// The gene is its record's first bases on the shared helix.
class ZoomPainter extends CustomPainter {
  ZoomPainter({
    required this.scale,
    required this.path,
    required this.bases,
    required this.at,
    required this.inks,
    required this.labels,
    super.repaint,
  });

  final ZoomScale scale;
  final ZoomPath path;

  /// The gene's first bases, read 5' to 3', for its level.
  final String bases;
  final double Function() at;
  final ZoomInks inks;
  final TextStyle labels;

  LocusTrack get track => scale.track;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) {
      return;
    }
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    final double zoom = at();
    final double width = scale.widthAt(zoom);
    final (ZoomLevel from, ZoomLevel to, double p) = scale.between(zoom);
    // Where the next level lies, on screen from the centre: where the level
    // before draws it, drifting to the centre as the view closes in. The
    // view zooms about it, so it never leaves the view, and the next level
    // is drawn around it.
    final Offset focus = focusOf(from, size);
    final Offset anchor =
        focus * size.width * (1 - _smooth((p * 1.8).clamp(0.0, 1.0)));
    for (final ZoomLevel level in <ZoomLevel>[from, to]) {
      final double alpha = scale.presence(level, zoom);
      if (alpha < 0.005) {
        continue;
      }
      final double perUnit =
          size.width * ZoomScale.widthOf(level, track) / width;
      final Offset shift = level == from
          ? focus - anchor / perUnit
          : -anchor / perUnit;
      final List<_Label> found = <_Label>[];
      canvas.save();
      canvas.translate(size.width / 2, size.height / 2);
      canvas.scale(perUnit);
      canvas.translate(-shift.dx, -shift.dy);
      canvas.saveLayer(null, Paint()..color = Color.fromRGBO(0, 0, 0, alpha));
      _draw(canvas, level, 1 / perUnit, size, found);
      canvas.restore();
      canvas.restore();
      // Labels read at their own size, and only near their own level.
      final double near = perUnit / size.width;
      if (near > 0.45 && near < 2.2) {
        for (final _Label label in found) {
          _text(
            canvas,
            label.text,
            Offset(size.width / 2, size.height / 2) +
                (label.at - shift) * perUnit,
            alpha * (label.strong ? 1 : 0.9),
            size,
            align: label.align,
          );
        }
      }
    }
    _scaleBar(canvas, size, width);
    canvas.restore();
  }

  /// Where in [level]'s layer the next level lies, in the layer's units.
  Offset focusOf(ZoomLevel level, Size size) => switch (level) {
    ZoomLevel.body => _bodyFocus(),
    ZoomLevel.organ => Offset.zero,
    ZoomLevel.tissue => Offset.zero,
    ZoomLevel.cell => Offset.zero,
    ZoomLevel.nucleus => _territory(_followed),
    ZoomLevel.chromosome => Offset(0, _bandY()),
    ZoomLevel.gene => Offset.zero,
  };

  void _draw(
    Canvas canvas,
    ZoomLevel level,
    double pixel,
    Size size,
    List<_Label> found,
  ) {
    switch (level) {
      case ZoomLevel.body:
        _body(canvas, pixel, found);
      case ZoomLevel.organ:
        _organ(canvas, pixel, found);
      case ZoomLevel.tissue:
        _tissue(canvas, pixel, size);
      case ZoomLevel.cell:
        _cell(canvas, pixel, found);
      case ZoomLevel.nucleus:
        _nucleus(canvas, pixel, found);
      case ZoomLevel.chromosome:
        _chromosome(canvas, pixel, found);
      case ZoomLevel.gene:
        _gene(canvas, pixel, size, found);
    }
  }

  // ---------------------------------------------------------------- the body

  static const double _bodyWidth = 2.2;

  /// Metres from the top of the head and across the midline, as the body
  /// layer's units: centred on the view, the head up.
  static Offset _inBody(double down, double across) =>
      Offset(across / _bodyWidth, (down - 0.85) / _bodyWidth);

  Offset _bodyFocus() {
    final String? tissue = path.tissue;
    final (double, double)? place = tissue == null ? null : placeOf(tissue);
    return place == null ? _inBody(0.55, 0) : _inBody(place.$1, place.$2);
  }

  void _body(Canvas canvas, double pixel, List<_Label> found) {
    final Paint limb = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..color = inks.body;
    final Paint edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2 * pixel
      ..color = inks.outline;
    void capsule(double d1, double a1, double d2, double a2, double thick) {
      limb.strokeWidth = thick / _bodyWidth;
      canvas.drawLine(_inBody(d1, a1), _inBody(d2, a2), limb);
    }

    for (final double side in <double>[-1, 1]) {
      capsule(0.32, side * 0.19, 0.84, side * 0.27, 0.085);
      capsule(0.92, side * 0.085, 1.66, side * 0.11, 0.13);
    }
    final RRect torso = RRect.fromRectAndRadius(
      Rect.fromPoints(_inBody(0.27, -0.2), _inBody(0.95, 0.2)),
      const Radius.circular(0.07 / _bodyWidth),
    );
    canvas.drawRRect(torso, Paint()..color = inks.body);
    canvas.drawRRect(torso, edge);
    capsule(0.19, 0, 0.28, 0, 0.1);
    final Offset head = _inBody(0.11, 0);
    canvas.drawCircle(head, 0.1 / _bodyWidth, Paint()..color = inks.body);
    canvas.drawCircle(head, 0.1 / _bodyWidth, edge);

    final String? tissue = path.tissue;
    final (double, double)? place = tissue == null ? null : placeOf(tissue);
    if (tissue != null && place != null) {
      final Offset at = _inBody(place.$1, place.$2);
      canvas.drawCircle(
        at,
        9 * pixel,
        Paint()..color = inks.mark.withValues(alpha: 0.3),
      );
      canvas.drawCircle(at, 4.5 * pixel, Paint()..color = inks.mark);
      found.add(
        _Label(
          tissue,
          at + Offset(12 * pixel, 0),
          align: TextAlign.left,
          strong: true,
        ),
      );
    }
  }

  // --------------------------------------------------------------- the organ

  void _organ(Canvas canvas, double pixel, List<_Label> found) {
    // An organ as a lobed shape: an illustration, the same for every tissue.
    final Path shape = Path();
    const int points = 90;
    for (int i = 0; i <= points; i++) {
      final double a = 2 * math.pi * i / points;
      final double r =
          0.3 +
          0.035 * math.sin(3 * a + 0.4) +
          0.02 * math.sin(5 * a + 1.3) +
          0.012 * math.sin(9 * a);
      final Offset p = Offset(r * math.cos(a) * 1.15, r * math.sin(a) * 0.85);
      i == 0 ? shape.moveTo(p.dx, p.dy) : shape.lineTo(p.dx, p.dy);
    }
    shape.close();
    canvas.drawPath(shape, Paint()..color = inks.body);
    canvas.drawPath(
      shape,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4 * pixel
        ..color = inks.outline,
    );
    // Lobules, and the one the view is closing on.
    final Paint lobule = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1 * pixel
      ..color = inks.outline.withValues(alpha: 0.5);
    for (int ring = 1; ring <= 3; ring++) {
      for (int k = 0; k < ring * 6; k++) {
        final double a = 2 * math.pi * k / (ring * 6) + ring;
        final Offset c = Offset(
          math.cos(a) * ring * 0.075 * 1.1,
          math.sin(a) * ring * 0.075 * 0.8,
        );
        canvas.drawCircle(c, 0.028, lobule);
      }
    }
    canvas.drawCircle(
      Offset.zero,
      0.03,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2 * pixel
        ..color = inks.mark,
    );
    final String? tissue = path.tissue;
    found.add(
      _Label(
        tissue ?? 'an organ, any',
        const Offset(0, -0.36),
        strong: tissue != null,
      ),
    );
  }

  // -------------------------------------------------------------- the tissue

  /// A cell, tens of micrometres across: each of the tissue's, and the one the
  /// cell level draws, so the cell the zoom closes on keeps its size.
  static const double _cellMetres = 2e-5;

  /// Its nucleus, about ten micrometres across, at every level that draws it.
  static const double _nucleusMetres = 1e-5;

  /// [metres] in [level]'s units.
  double _in(ZoomLevel level, double metres) =>
      metres / ZoomScale.widthOf(level, track);

  (double, Path, Path)? _cells;

  /// The tissue's cells and their nuclei, packed side by side at their size
  /// in a patch that fills the view at its level, [aspect] tall to one wide.
  (Path, Path) _cellsFor(double aspect) {
    final (double, Path, Path)? kept = _cells;
    if (kept != null && kept.$1 == aspect) {
      return (kept.$2, kept.$3);
    }
    final double cell = _in(ZoomLevel.tissue, _cellMetres);
    final double nucleus = _in(ZoomLevel.tissue, _nucleusMetres) / 2;
    final double rise = cell * 0.87;
    final double reach = 0.5 * math.sqrt(1 + aspect * aspect) + cell;
    final int cols = (reach / cell).ceil();
    final int rows = (reach / rise).ceil();
    final Path cells = Path();
    final Path nuclei = Path();
    for (int row = -rows; row <= rows; row++) {
      for (int col = -cols; col <= cols; col++) {
        final Offset c = Offset(
          (col + (row.isOdd ? 0.5 : 0)) * cell,
          row * rise,
        );
        if (c.distance > reach) {
          continue;
        }
        for (int k = 0; k < 6; k++) {
          final double a = math.pi / 6 + k * math.pi / 3;
          final Offset v = c + Offset(math.cos(a), math.sin(a)) * cell * 0.55;
          k == 0 ? cells.moveTo(v.dx, v.dy) : cells.lineTo(v.dx, v.dy);
        }
        cells.close();
        nuclei.addOval(
          Rect.fromCircle(
            center: c + Offset(math.sin(row * 1.7 + col) * cell * 0.08, 0),
            radius: nucleus,
          ),
        );
      }
    }
    _cells = (aspect, cells, nuclei);
    return (cells, nuclei);
  }

  void _tissue(Canvas canvas, double pixel, Size size) {
    // Cells packed side by side, at their size: a round patch of them, as a
    // microscope's field is round, that fills the view at this level.
    final (Path cells, Path nuclei) = _cellsFor(size.height / size.width);
    canvas.drawPath(cells, Paint()..color = inks.cell);
    canvas.drawPath(
      cells,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1 * pixel
        ..color = inks.outline,
    );
    canvas.drawPath(
      nuclei,
      Paint()..color = inks.nucleus.withValues(alpha: 0.7),
    );
    canvas.drawCircle(
      Offset.zero,
      _in(ZoomLevel.tissue, _cellMetres) * 0.58,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2 * pixel
        ..color = inks.mark,
    );
  }

  // ---------------------------------------------------------------- the cell

  void _cell(Canvas canvas, double pixel, List<_Label> found) {
    final Anucleate? anucleate = path.anucleate;
    final double r = _in(ZoomLevel.cell, _cellMetres) / 2;
    final double n = _in(ZoomLevel.cell, _nucleusMetres) / 2;
    final Paint edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4 * pixel
      ..color = inks.outline;
    // The cell the zoom lands in, with its nucleus at the centre.
    canvas.drawCircle(Offset.zero, r, Paint()..color = inks.cell);
    canvas.drawCircle(Offset.zero, r, edge);
    final Paint organelle = Paint()
      ..color = inks.outline.withValues(alpha: 0.35);
    for (int k = 0; k < 40; k++) {
      final double a = k * 2.399;
      final double d = r * (0.55 + 0.35 * ((k * 37 % 11) / 11));
      canvas.drawCircle(
        Offset(math.cos(a) * d, math.sin(a) * d),
        r * 0.027,
        organelle,
      );
    }
    canvas.drawCircle(Offset.zero, n, Paint()..color = inks.nucleus);
    canvas.drawCircle(
      Offset.zero,
      n,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2 * pixel
        ..color = inks.mark,
    );
    if (anucleate != null) {
      // The cell the Atlas names, grown, at its own size and without a
      // nucleus, beside the precursor the zoom lands in instead.
      final double m = _in(ZoomLevel.cell, anucleate.size) / 2;
      final Offset beside = Offset(-r - m - 0.03, -r);
      canvas.drawCircle(
        beside,
        m,
        Paint()..color = inks.mark.withValues(alpha: 0.45),
      );
      canvas.drawCircle(
        beside,
        m * 0.45,
        Paint()..color = inks.mark.withValues(alpha: 0.2),
      );
      canvas.drawCircle(beside, m, edge);
      found.add(
        _Label('no nucleus', beside + Offset(0, m + 0.03), strong: true),
      );
      found.add(_Label(anucleate.precursor, Offset(0, r + 0.06), strong: true));
      return;
    }
    final String? cellType = path.cellType;
    found.add(_Label(cellType ?? 'a cell', Offset(0, r + 0.06)));
  }

  // ------------------------------------------------------------- the nucleus

  /// Which of the 46 territories the zoom follows down to the chromosome.
  static const int _followed = 29;

  /// Where chromosome [k]'s territory lies, the 46 spread over the nucleus
  /// the way a sunflower sets its seeds.
  Offset _territory(int k) {
    final double r = _in(ZoomLevel.nucleus, _nucleusMetres) / 2;
    final double d = r * 0.72 * math.sqrt((k + 0.5) / 46);
    final double a = k * 2.39996;
    return Offset(math.cos(a) * d, math.sin(a) * d);
  }

  void _nucleus(Canvas canvas, double pixel, List<_Label> found) {
    // The nucleus, its 46 chromosomes each in a territory of its own.
    final double r = _in(ZoomLevel.nucleus, _nucleusMetres) / 2;
    final double spot = r * 0.14;
    canvas.drawCircle(Offset.zero, r, Paint()..color = inks.cell);
    canvas.drawCircle(
      Offset.zero,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6 * pixel
        ..color = inks.outline,
    );
    final Paint territory = Paint();
    for (int k = 0; k < 46; k++) {
      if (k == _followed) {
        continue;
      }
      territory.color = inks.nucleus.withValues(
        alpha: 0.14 + 0.12 * ((k * 7 % 5) / 4),
      );
      canvas.drawCircle(_territory(k), spot, territory);
    }
    // A nucleolus.
    canvas.drawCircle(
      Offset(-r * 0.32, -r * 0.3),
      r * 0.17,
      Paint()..color = inks.nucleus.withValues(alpha: 0.5),
    );
    final Offset followed = _territory(_followed);
    canvas.drawCircle(
      followed,
      spot,
      Paint()..color = inks.mark.withValues(alpha: 0.5),
    );
    canvas.drawCircle(
      followed,
      spot,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2 * pixel
        ..color = inks.mark,
    );
    found.add(
      _Label(
        'chromosome ${track.chromosome}',
        followed + Offset(0, spot + 12 * pixel),
        strong: true,
      ),
    );
  }

  // ---------------------------------------------------------- the chromosome

  /// The chromosome's length in the layer's units: the view is one and a half
  /// times it.
  static const double _chromosomeLength = 1 / 1.5;

  double _yOf(int base) =>
      -_chromosomeLength / 2 + (base - 1) / track.length * _chromosomeLength;

  double _bandY() => (_yOf(track.bandStart) + _yOf(track.bandEnd)) / 2;

  void _chromosome(Canvas canvas, double pixel, List<_Label> found) {
    const double half = 0.045;
    // The outline, rounded at the ends, and the bands inside it.
    final RRect outline = RRect.fromRectAndRadius(
      Rect.fromLTRB(-half, _yOf(1), half, _yOf(track.length + 1)),
      const Radius.circular(half),
    );
    canvas.save();
    canvas.clipRRect(outline);
    final Paint fill = Paint();
    for (final CytoBand band in track.bands) {
      final double top = _yOf(band.start);
      final double bottom = _yOf(band.end + 1);
      // The centromere is a waist; a stalk is thin.
      final double w = switch (band.stain) {
        Stain.acen => half * 0.55,
        Stain.stalk => half * 0.35,
        _ => half,
      };
      fill.color = switch (band.stain) {
        Stain.acen => Color.lerp(inks.pale, inks.stain, 0.55)!,
        Stain.gvar => Color.lerp(inks.pale, inks.stain, 0.35)!,
        _ => Color.lerp(inks.pale, inks.stain, 0.15 + 0.85 * band.stain.depth)!,
      };
      canvas.drawRect(Rect.fromLTRB(-w, top, w, bottom), fill);
    }
    canvas.restore();
    canvas.drawRRect(
      outline,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4 * pixel
        ..color = inks.outline,
    );
    // The gene's band: marked as a band, with its name. Never the gene.
    final Rect band = Rect.fromLTRB(
      -half - 4 * pixel,
      _yOf(track.bandStart),
      half + 4 * pixel,
      _yOf(track.bandEnd + 1),
    );
    canvas.drawRect(
      band,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2 * pixel
        ..color = inks.mark,
    );
    final double y = band.center.dy;
    canvas.drawLine(
      Offset(half + 6 * pixel, y),
      Offset(half + 26 * pixel, y),
      Paint()
        ..strokeWidth = 1.6 * pixel
        ..color = inks.mark,
    );
    found.add(
      _Label(
        track.locus,
        Offset(half + 30 * pixel, y),
        align: TextAlign.left,
        strong: true,
      ),
    );
    found.add(_Label('p', Offset(-half - 16 * pixel, _yOf(1) + 0.03)));
    found.add(
      _Label('q', Offset(-half - 16 * pixel, _yOf(track.length) - 0.05)),
    );
  }

  // ---------------------------------------------------------------- the gene

  HelixModel? _helix;

  void _gene(Canvas canvas, double pixel, Size size, List<_Label> found) {
    // The record's first bases on the shared helix, across a view 12 nm
    // wide: a base pair is 0.34 nm, the helix 2 nm across.
    final double pitchUnits =
        ZoomScale.basePairMetres / ZoomScale.widthOf(ZoomLevel.gene, track);
    final int count = math.min(bases.length, ZoomScale.helixBases);
    if (count < 4) {
      return;
    }
    final HelixModel model = _helix ??= HelixModel(
      rungCount: count,
      sampleCount: 3 * count,
      bases: Uint8List.fromList(<int>[
        for (int i = 0; i < count; i++) HelixPalette.ofBase(bases[i]),
      ]),
    );
    // One helical turn is 10.5 base pairs along the axis.
    final double turn = pitchUnits * HelixModel.basePairsPerTurn;
    final double radius = turn / (2 * HelixModel.pitchPerDiameter);
    final double length = count * pitchUnits;
    final List<(double, Offset, Offset, int, int)> parts =
        <(double, Offset, Offset, int, int)>[];
    Offset place(int i) =>
        Offset(model.pointAxial[i] * length, model.pointCos[i] * radius);
    for (int p = 0; p < model.primitiveCount; p++) {
      final int kind = model.primKind[p];
      if (kind == HelixPrimitiveKind.transcriptSegment ||
          kind == HelixPrimitiveKind.transcriptNode) {
        continue;
      }
      final int a = model.primStart[p];
      final int z = model.primEnd[p];
      parts.add((
        (model.pointSin[a] + model.pointSin[z]) / 2,
        place(a),
        place(z),
        kind,
        model.primPalette[p],
      ));
    }
    parts.sort(
      (
        (double, Offset, Offset, int, int) x,
        (double, Offset, Offset, int, int) y,
      ) => x.$1.compareTo(y.$1),
    );
    final Paint stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    for (final (double depth, Offset a, Offset z, int kind, int slot)
        in parts) {
      final double shade = 0.6 + 0.4 * (depth + 1) / 2;
      final Color colour = switch (slot) {
        HelixPalette.adenine => inks.bases.adenine,
        HelixPalette.thymine => inks.bases.thymine,
        HelixPalette.guanine => inks.bases.guanine,
        HelixPalette.cytosine => inks.bases.cytosine,
        _ => inks.outline,
      };
      if (kind == HelixPrimitiveKind.node) {
        canvas.drawCircle(
          a,
          3.2 * pixel,
          Paint()..color = Color.lerp(inks.pale, colour, shade)!,
        );
        continue;
      }
      stroke
        ..color = Color.lerp(inks.pale, colour, shade)!
        ..strokeWidth =
            (kind == HelixPrimitiveKind.strandSegment ? 2.4 : 3.2) * pixel;
      canvas.drawLine(a, z, stroke);
    }
    found.add(
      _Label(
        '5′ ${bases.substring(0, math.min(12, count))}…',
        Offset(-length / 2, radius + 0.06),
        align: TextAlign.left,
      ),
    );
  }

  // ----------------------------------------------------------------- helpers

  void _scaleBar(Canvas canvas, Size size, double width) {
    final (double _, double pixels, String label) = scaleBar(width, size.width);
    const double left = 16;
    final double y = size.height - 18;
    // A plate under it, so that it reads over the busiest layer.
    final TextPainter measure = TextPainter(
      text: TextSpan(text: label, style: labels),
      textDirection: TextDirection.ltr,
    )..layout();
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(
          left - 8,
          y - 14 - measure.height,
          left + math.max(pixels, measure.width) + 8,
          y + 10,
        ),
        const Radius.circular(6),
      ),
      Paint()..color = inks.ground.withValues(alpha: 0.8),
    );
    measure.dispose();
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
    _text(
      canvas,
      label,
      Offset(left, y - 8),
      1,
      size,
      align: TextAlign.left,
      above: true,
    );
  }

  void _text(
    Canvas canvas,
    String text,
    Offset at,
    double alpha,
    Size size, {
    TextAlign align = TextAlign.center,
    bool above = false,
  }) {
    final TextPainter painter = TextPainter(
      text: TextSpan(
        text: text,
        style: labels.copyWith(color: inks.label.withValues(alpha: alpha)),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: size.width * 0.6);
    final double x = switch (align) {
      TextAlign.left => at.dx,
      TextAlign.right => at.dx - painter.width,
      _ => at.dx - painter.width / 2,
    };
    painter.paint(
      canvas,
      Offset(
        x.clamp(4.0, math.max(4.0, size.width - painter.width - 4)),
        above ? at.dy - painter.height : at.dy - painter.height / 2,
      ),
    );
    painter.dispose();
  }

  @override
  bool shouldRepaint(covariant ZoomPainter old) =>
      old.scale != scale ||
      old.bases != bases ||
      old.inks != inks ||
      old.labels != labels;
}

final class _Label {
  const _Label(
    this.text,
    this.at, {
    this.align = TextAlign.center,
    this.strong = false,
  });

  final String text;
  final Offset at;
  final TextAlign align;
  final bool strong;
}

double _smooth(double t) {
  final double c = t.clamp(0.0, 1.0);
  return c * c * (3 - 2 * c);
}
