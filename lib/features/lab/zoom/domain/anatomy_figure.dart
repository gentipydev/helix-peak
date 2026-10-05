import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';

import 'anatomy_figures.g.dart';
import 'anatomy_tables.dart';

/// One part of a figure, as the anatomogram draws it: a tissue's shape or
/// shapes, in the figure's metres.
@immutable
final class AnatomyPart {
  const AnatomyPart({
    required this.title,
    required this.site,
    required this.contours,
  });

  /// The anatomogram's own name for it, `liver`, or nothing where the
  /// drawing gives the shape no title of its own: its blood vessels are the
  /// shape it also draws for blood.
  final String title;

  /// A point well inside its largest outline: where the zoom goes into it.
  final Offset site;

  /// Its outlines, the largest first: two lungs, a chain of lymph nodes.
  final List<List<Offset>> contours;

  /// The outline the zoom follows: the largest.
  List<Offset> get followed => contours.first;

  /// The box the followed outline lies in.
  Rect get box {
    double left = double.infinity;
    double top = double.infinity;
    double right = double.negativeInfinity;
    double bottom = double.negativeInfinity;
    for (final Offset p in followed) {
      left = math.min(left, p.dx);
      right = math.max(right, p.dx);
      top = math.min(top, p.dy);
      bottom = math.max(bottom, p.dy);
    }
    return Rect.fromLTRB(left, top, right, bottom);
  }

  /// The middle of the followed outline: where the view closes on it, so
  /// that the organ is seen whole. Not always inside it, as [site] is.
  Offset get centre => box.center;

  /// How long the followed outline is, the longer way, in the figure's
  /// metres: the anatomogram is a diagram, and draws a stomach half as long
  /// as a stomach is.
  double get extent => box.longestSide;
}

/// One of the Expression Atlas anatomogram's drawings (EMBL-EBI, CC BY 4.0),
/// its outlines simplified by `tool/zoom/anatomogram.py`: a standing figure,
/// female or male, or the brain cut down its middle.
///
/// A standing figure is measured in metres on a body 1.70 m tall, across
/// from its midline (the body's own left to the reader's right) and down
/// from the top of its head. The brain is measured from its middle, 0.17 m
/// from front to back, its front to the left.
@immutable
final class AnatomyFigure {
  const AnatomyFigure({
    required this.name,
    required this.silhouette,
    required this.lines,
    required this.parts,
  });

  /// Reads a figure as the tool writes it: JSON, lengths in whole steps of
  /// `step` metres, each outline its first point and then every step to
  /// the next.
  factory AnatomyFigure.parse(String source) {
    final Map<String, dynamic> json =
        jsonDecode(source) as Map<String, dynamic>;
    final double step = (json['step'] as num).toDouble();
    List<Offset> outline(dynamic flat) {
      final List<dynamic> steps = flat as List<dynamic>;
      final List<Offset> out = <Offset>[];
      double x = 0;
      double y = 0;
      for (int i = 0; i + 1 < steps.length; i += 2) {
        x += (steps[i] as num).toDouble();
        y += (steps[i + 1] as num).toDouble();
        out.add(Offset(x * step, y * step));
      }
      return List<Offset>.unmodifiable(out);
    }

    AnatomyPart part(Map<String, dynamic> part) {
      final List<dynamic> site = part['site'] as List<dynamic>;
      return AnatomyPart(
        title: part['title'] as String,
        site: Offset((site[0] as num) * step, (site[1] as num) * step),
        contours: List<List<Offset>>.unmodifiable(<List<Offset>>[
          for (final dynamic contour in part['contours'] as List<dynamic>)
            outline(contour),
        ]),
      );
    }

    return AnatomyFigure(
      name: json['name'] as String,
      silhouette: outline(json['silhouette']),
      lines: List<List<Offset>>.unmodifiable(<List<Offset>>[
        for (final dynamic line in json['lines'] as List<dynamic>)
          outline(line),
      ]),
      parts: Map<String, AnatomyPart>.unmodifiable(<String, AnatomyPart>{
        for (final MapEntry<String, dynamic> entry
            in (json['parts'] as Map<String, dynamic>).entries)
          entry.key: part(entry.value as Map<String, dynamic>),
      }),
    );
  }

  /// `female`, `male` or `brain`.
  final String name;

  /// The figure's outer edge.
  final List<Offset> silhouette;

  /// Its line art: closed shapes, filled, a hole wherever one lies inside
  /// another.
  final List<List<Offset>> lines;

  /// Its tissues' shapes, by UBERON id.
  final Map<String, AnatomyPart> parts;

  static final AnatomyFigure female = AnatomyFigure.parse(anatomyFemaleJson);
  static final AnatomyFigure male = AnatomyFigure.parse(anatomyMaleJson);
  static final AnatomyFigure brain = AnatomyFigure.parse(anatomyBrainJson);

  /// How tall a standing figure is, in metres.
  static const double height = 1.7;

  /// The standing figure a zoom to [tissue] is drawn on. A tissue only one
  /// sex has is found on that figure. Any other is found on both, and the
  /// figure is then the one that has the most of the [others] the gene is
  /// read in as well, the female where they tie: so a gene of the liver and
  /// the testis is shown a body that has both.
  static AnatomyFigure bodyFor(String? tissue, Iterable<String> others) {
    final BodySex own = tissueAnatomy[tissue]?.sex ?? BodySex.either;
    if (own != BodySex.either) {
      return own == BodySex.male ? male : female;
    }
    int lean = 0;
    for (final String other in others) {
      lean += switch (tissueAnatomy[other]?.sex) {
        BodySex.male => 1,
        BodySex.female => -1,
        _ => 0,
      };
    }
    return lean > 0 ? male : female;
  }
}
