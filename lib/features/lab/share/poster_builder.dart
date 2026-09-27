import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../core/catalog/protein_target.dart';
import '../../../core/theme/anatomy_colors.dart';
import '../../../core/theme/nucleotide_colors.dart';
import '../../../shared/anatomy/anatomy_layout.dart';
import '../../../shared/anatomy/anatomy_painter.dart';
import '../../../shared/anatomy/anatomy_scene.dart';
import '../../../shared/anatomy/anatomy_stages.dart';
import '../../../shared/format.dart';
import 'gene_link.dart';

/// One protein as a single high-resolution PNG: its fold, a slice of its
/// grid, its name and a link back to its walk.
///
/// Every part is drawn by what already draws it. The grid is the walk's own
/// [AnatomyPainter] on the walk's own resting scene of the protein page, so
/// its squares and colours are the ones the reader has seen. The fold is
/// whatever `renderFoldStill` made of the fold page's model, and where there
/// is none — no Flutter GPU, or no model — the grid takes its place rather
/// than the poster leaving a hole. The words are the catalog's name and
/// numbers read off the record.
@immutable
final class PosterBuilder {
  const PosterBuilder({
    required this.target,
    required this.model,
    required this.theme,
    this.size = defaultSize,
    this.pixelRatio = 2,
  });

  /// Portrait, four by five: the shape most feeds show whole.
  static const Size defaultSize = Size(1080, 1350);

  final ProteinTarget target;
  final AnatomyModel model;

  /// The lab's theme: its surface, ink and type, and its nucleotide and
  /// anatomy colours.
  final ThemeData theme;

  /// The logical size the poster is laid out at.
  final Size size;

  /// Pixels per logical pixel. At 2 the default poster is 2160×2700.
  final double pixelRatio;

  static const double _margin = 72;

  int get width => (size.width * pixelRatio).round();

  int get height => (size.height * pixelRatio).round();

  /// Where the fold goes, in logical pixels, so the caller can render the
  /// fold at this size times [pixelRatio].
  Rect get foldBox =>
      Rect.fromLTWH(_margin, 300, size.width - 2 * _margin, size.height * 0.4);

  /// The poster, encoded as PNG. [fold] is drawn but not disposed.
  Future<Uint8List> build({ui.Image? fold}) async {
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder)..scale(pixelRatio);
    paint(canvas, fold: fold);
    final ui.Picture picture = recorder.endRecording();
    final ui.Image image;
    try {
      image = await picture.toImage(width, height);
    } finally {
      picture.dispose();
    }
    try {
      final ByteData? png = await image.toByteData(
        format: ui.ImageByteFormat.png,
      );
      if (png == null) {
        throw StateError('The poster for ${target.slug} did not encode.');
      }
      return png.buffer.asUint8List(png.offsetInBytes, png.lengthInBytes);
    } finally {
      image.dispose();
    }
  }

  /// Draws the poster in logical pixels onto [canvas].
  void paint(Canvas canvas, {ui.Image? fold}) {
    final ColorScheme scheme = theme.colorScheme;
    canvas.drawColor(scheme.surface, BlendMode.src);

    final double inner = size.width - 2 * _margin;
    double y = _margin;
    y += _text(
      canvas,
      target.display,
      theme.textTheme.displayMedium?.copyWith(
            fontSize: 88,
            height: 1.1,
            color: scheme.onSurface,
          ) ??
          TextStyle(fontSize: 88, color: scheme.onSurface),
      Offset(_margin, y),
      inner,
      maxLines: 2,
    );
    y += 16;
    _text(
      canvas,
      _facts(),
      (theme.textTheme.titleLarge ?? const TextStyle()).copyWith(
        fontSize: 34,
        color: scheme.onSurfaceVariant,
      ),
      Offset(_margin, y),
      inner,
    );

    final Rect foldRect = foldBox;
    final double footerTop = size.height - _margin - 96;
    final double gridTop;
    if (fold != null) {
      final Rect fitted = _contain(
        Size(fold.width.toDouble(), fold.height.toDouble()),
        foldRect,
      );
      canvas.drawImageRect(
        fold,
        Rect.fromLTWH(0, 0, fold.width.toDouble(), fold.height.toDouble()),
        fitted,
        Paint()..filterQuality = FilterQuality.high,
      );
      gridTop = foldRect.bottom + 40;
    } else {
      gridTop = foldRect.top;
    }
    _grid(
      canvas,
      Rect.fromLTRB(_margin, gridTop, size.width - _margin, footerTop - 40),
    );

    final TextStyle footer = (theme.textTheme.bodyLarge ?? const TextStyle())
        .copyWith(fontSize: 30, color: scheme.onSurfaceVariant);
    final double used = _text(
      canvas,
      'Open it in Helix Peek',
      footer,
      Offset(_margin, footerTop),
      inner,
    );
    _text(
      canvas,
      geneLink(target).toString(),
      footer.copyWith(fontFamily: 'JetBrainsMono', color: scheme.primary),
      Offset(_margin, footerTop + used + 8),
      inner,
    );
  }

  /// The gene and the protein's length, as the record has them.
  String _facts() {
    final int residues = model.record.protein?.translation.length ?? 0;
    return residues == 0
        ? '${model.record.gene} gene'
        : '${model.record.gene} gene · ${grouped(residues)} residues';
  }

  /// The top of the protein page, as the walk lays it out at this width.
  void _grid(Canvas canvas, Rect box) {
    if (box.height <= 0 || model.stages.isEmpty) {
      return;
    }
    final int protein = model.stages.indexWhere(
      (AnatomyStage s) => s.kind == StageKind.protein,
    );
    final int index = protein >= 0 ? protein : model.stages.length - 1;
    final Size viewport = box.size;
    final Size canvasSize = Size(
      viewport.width,
      math.max(
        viewport.height,
        AnatomyLayout.heightFor(model.stages[index], viewport),
      ),
    );
    const Animation<double> still = AlwaysStoppedAnimation<double>(1);
    canvas
      ..save()
      ..translate(box.left, box.top)
      ..clipRect(Offset.zero & viewport);
    AnatomyPainter(
      repaint: still,
      scene: AnatomyScene.resting(
        model: model,
        index: index,
        canvas: canvasSize,
        viewport: viewport,
      ),
      progress: still,
      groove: still,
      reverse: false,
      tracer: null,
      status: null,
      inertTracer: null,
      background: theme.colorScheme.surface,
      nucleotides: theme.extension<NucleotideColors>() ?? NucleotideColors.dark,
      anatomy: theme.extension<AnatomyColors>() ?? AnatomyColors.dark,
      rulerInk: theme.colorScheme.onSurfaceVariant,
    ).paint(canvas, canvasSize);
    canvas.restore();
  }

  /// Lays [text] out at [width] and draws it at [at]; returns its height.
  static double _text(
    Canvas canvas,
    String text,
    TextStyle style,
    Offset at,
    double width, {
    int maxLines = 1,
  }) {
    final TextPainter painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      maxLines: maxLines,
      ellipsis: '…',
    )..layout(maxWidth: width);
    painter.paint(canvas, at);
    final double height = painter.height;
    painter.dispose();
    return height;
  }

  /// [image] scaled to fit inside [box], centred.
  static Rect _contain(Size image, Rect box) {
    final double scale = math.min(
      box.width / image.width,
      box.height / image.height,
    );
    final Size fitted = image * scale;
    return Rect.fromCenter(
      center: box.center,
      width: fitted.width,
      height: fitted.height,
    );
  }
}
