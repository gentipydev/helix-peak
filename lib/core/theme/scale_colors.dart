import 'package:flutter/material.dart';

/// The colours the Lab's zoom sees each scale in, the way science sees it.
///
/// Every level of the zoom is drawn in the convention of the instrument
/// that shows that scale, because a reader who knows the field reads those
/// conventions without a legend:
///
/// - the body and its organs as anatomy is drawn, a ghosted figure with the
///   organs inside it;
/// - a tissue as a section stained with haematoxylin and eosin, under
///   brightfield: nuclei blue-purple, cytoplasm and matrix pink, on the
///   light of the lamp;
/// - a cell and its nucleus in immunofluorescence, as the Human Protein
///   Atlas images them: DNA blue, the endoplasmic reticulum yellow, the
///   protein green, on black. The Atlas stains microtubules red; here they
///   are magenta, so a reader who cannot tell red from green can still tell
///   them from the protein;
/// - territories in chromosome paint, 24 colours, one a chromosome;
/// - a chromosome in Giemsa's G-bands, the centromere in the genome
///   browser's red;
/// - the genome as a browser draws it, on the app's own ground.
@immutable
final class ScaleColors extends ThemeExtension<ScaleColors> {
  const ScaleColors({
    required this.bodyFill,
    required this.bodyEdge,
    required this.organ,
    required this.organEdge,
    required this.brightfield,
    required this.eosin,
    required this.eosinDeep,
    required this.haematoxylin,
    required this.haematoxylinLight,
    required this.redCell,
    required this.eyepiece,
    required this.fluorescence,
    required this.dapi,
    required this.microtubules,
    required this.reticulum,
    required this.protein,
    required this.membrane,
    required this.giemsaPale,
    required this.giemsaDark,
    required this.centromere,
    required this.paint,
    required this.histone,
    required this.backbone,
  });

  /// The body, ghosted, and its outline.
  final Color bodyFill;
  final Color bodyEdge;

  /// An organ seen in the body or on its own, and its outline.
  final Color organ;
  final Color organEdge;

  /// Brightfield: the lamp's light through the slide.
  final Color brightfield;

  /// Eosin: cytoplasm and matrix, light and deep.
  final Color eosin;
  final Color eosinDeep;

  /// Haematoxylin: nuclei, and the paler stain of their chromatin.
  final Color haematoxylin;
  final Color haematoxylinLight;

  /// A red cell on a stained slide: eosin at its reddest.
  final Color redCell;

  /// The dark round the eyepiece's field.
  final Color eyepiece;

  /// Immunofluorescence: the dark of the field and the four channels.
  final Color fluorescence;
  final Color dapi;
  final Color microtubules;
  final Color reticulum;
  final Color protein;

  /// A membrane's faint outline in the dark.
  final Color membrane;

  /// Giemsa: the bands that take no stain and those that take it fully.
  final Color giemsaPale;
  final Color giemsaDark;

  /// The centromere.
  final Color centromere;

  /// Chromosome paint, one colour a chromosome: 1 to 22, then X and Y.
  final List<Color> paint;

  /// A nucleosome's histone core, and DNA's backbone.
  final Color histone;
  final Color backbone;

  /// [chromosome]'s paint: `11`, `X`.
  Color paintOf(String chromosome) {
    final int? n = int.tryParse(chromosome);
    final int index = n != null
        ? n - 1
        : chromosome == 'X'
        ? 22
        : 23;
    return paint[index.clamp(0, paint.length - 1)];
  }

  static const ScaleColors analysis = ScaleColors(
    bodyFill: Color(0xFF2B2622),
    bodyEdge: Color(0xFF8C7B6B),
    organ: Color(0xFF7A5148),
    organEdge: Color(0xFFB08A7C),
    brightfield: Color(0xFFF3ECF1),
    eosin: Color(0xFFE6A7C4),
    eosinDeep: Color(0xFFC46A98),
    haematoxylin: Color(0xFF4A3B8C),
    haematoxylinLight: Color(0xFF8574C4),
    redCell: Color(0xFFD9566C),
    eyepiece: Color(0xFF0B0A09),
    fluorescence: Color(0xFF050506),
    dapi: Color(0xFF3F6DFF),
    microtubules: Color(0xFFD94BB0),
    reticulum: Color(0xFFE6C34A),
    protein: Color(0xFF3FE070),
    membrane: Color(0xFF7E8798),
    giemsaPale: Color(0xFFE8E2D6),
    giemsaDark: Color(0xFF2A2521),
    centromere: Color(0xFFC0574B),
    paint: <Color>[
      Color(0xFFE8604C),
      Color(0xFF4FA3E0),
      Color(0xFFE0B13A),
      Color(0xFF6BC46D),
      Color(0xFFB277E0),
      Color(0xFFE07FB0),
      Color(0xFF48C4BE),
      Color(0xFFE09454),
      Color(0xFF8C9BE6),
      Color(0xFFA9C94A),
      Color(0xFFE05C82),
      Color(0xFF5CBCE6),
      Color(0xFFD9C95A),
      Color(0xFF7FD69A),
      Color(0xFFC98AE0),
      Color(0xFFF09A8A),
      Color(0xFF6E93D9),
      Color(0xFFC6A374),
      Color(0xFF9ED9D3),
      Color(0xFFE6A1D3),
      Color(0xFF8FC27A),
      Color(0xFFD97A5C),
      Color(0xFFB6B0E8),
      Color(0xFFBFD97F),
    ],
    histone: Color(0xFFC9A35B),
    backbone: Color(0xFFB9C2D0),
  );

  @override
  ScaleColors copyWith() => this;

  @override
  ScaleColors lerp(covariant ScaleColors? other, double t) {
    if (other == null) {
      return this;
    }
    Color mix(Color a, Color b) => Color.lerp(a, b, t)!;
    return ScaleColors(
      bodyFill: mix(bodyFill, other.bodyFill),
      bodyEdge: mix(bodyEdge, other.bodyEdge),
      organ: mix(organ, other.organ),
      organEdge: mix(organEdge, other.organEdge),
      brightfield: mix(brightfield, other.brightfield),
      eosin: mix(eosin, other.eosin),
      eosinDeep: mix(eosinDeep, other.eosinDeep),
      haematoxylin: mix(haematoxylin, other.haematoxylin),
      haematoxylinLight: mix(haematoxylinLight, other.haematoxylinLight),
      redCell: mix(redCell, other.redCell),
      eyepiece: mix(eyepiece, other.eyepiece),
      fluorescence: mix(fluorescence, other.fluorescence),
      dapi: mix(dapi, other.dapi),
      microtubules: mix(microtubules, other.microtubules),
      reticulum: mix(reticulum, other.reticulum),
      protein: mix(protein, other.protein),
      membrane: mix(membrane, other.membrane),
      giemsaPale: mix(giemsaPale, other.giemsaPale),
      giemsaDark: mix(giemsaDark, other.giemsaDark),
      centromere: mix(centromere, other.centromere),
      paint: <Color>[
        for (int i = 0; i < paint.length; i++)
          mix(paint[i], other.paint[i % other.paint.length]),
      ],
      histone: mix(histone, other.histone),
      backbone: mix(backbone, other.backbone),
    );
  }
}

extension ScaleColorsContext on BuildContext {
  ScaleColors get scaleColors =>
      Theme.of(this).extension<ScaleColors>() ?? ScaleColors.analysis;
}
