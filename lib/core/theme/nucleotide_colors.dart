import 'package:flutter/material.dart';

@immutable
final class NucleotideColors extends ThemeExtension<NucleotideColors> {
  const NucleotideColors({
    required this.adenine,
    required this.thymine,
    required this.guanine,
    required this.cytosine,
    required this.unknown,
  });

  final Color adenine;

  final Color thymine;

  final Color guanine;
  final Color cytosine;

  final Color unknown;

  Color forBase(String base) {
    if (base.isEmpty) {
      return unknown;
    }
    return switch (base[0].toUpperCase()) {
      'A' => adenine,
      'T' || 'U' => thymine,
      'G' => guanine,
      'C' => cytosine,
      _ => unknown,
    };
  }

  static const NucleotideColors dark = NucleotideColors(
    adenine: Color(0xFFEDA92B),
    thymine: Color(0xFF56B4E9),
    guanine: Color(0xFFCC79A7),
    cytosine: Color(0xFFF2EA6B),
    unknown: Color(0xFF7C8798),
  );

  static const NucleotideColors light = NucleotideColors(
    adenine: Color(0xFFA96B00),
    thymine: Color(0xFF0B6FA4),
    guanine: Color(0xFF9C4F7C),
    cytosine: Color(0xFF7A6B00),
    unknown: Color(0xFF5A6169),
  );

  @override
  NucleotideColors copyWith({
    Color? adenine,
    Color? thymine,
    Color? guanine,
    Color? cytosine,
    Color? unknown,
  }) {
    return NucleotideColors(
      adenine: adenine ?? this.adenine,
      thymine: thymine ?? this.thymine,
      guanine: guanine ?? this.guanine,
      cytosine: cytosine ?? this.cytosine,
      unknown: unknown ?? this.unknown,
    );
  }

  @override
  NucleotideColors lerp(covariant NucleotideColors? other, double t) {
    if (other == null) {
      return this;
    }
    return NucleotideColors(
      adenine: Color.lerp(adenine, other.adenine, t)!,
      thymine: Color.lerp(thymine, other.thymine, t)!,
      guanine: Color.lerp(guanine, other.guanine, t)!,
      cytosine: Color.lerp(cytosine, other.cytosine, t)!,
      unknown: Color.lerp(unknown, other.unknown, t)!,
    );
  }
}

extension NucleotideColorsContext on BuildContext {
  NucleotideColors get nucleotideColors =>
      Theme.of(this).extension<NucleotideColors>() ?? NucleotideColors.dark;
}
