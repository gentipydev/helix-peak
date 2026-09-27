import 'dart:convert';

import 'package:flutter/foundation.dart';

/// A point in the morph's one frame for both states: centred, longest axis 1.0.
typedef MorphPoint = (double x, double y, double z);

/// One chain of the assembly: its residues' CA atoms in both states, and its
/// haem, and the oxygen the relaxed state has bound to it.
@immutable
final class MorphChain {
  const MorphChain({
    required this.node,
    required this.gene,
    required this.tense,
    required this.relaxed,
    required this.haemTense,
    required this.haemRelaxed,
    required this.oxygen,
  });

  final String node;
  final String gene;

  /// Each residue's CA, in the same order in both states.
  final List<MorphPoint> tense;
  final List<MorphPoint> relaxed;

  final MorphPoint haemTense;
  final MorphPoint haemRelaxed;

  /// The two atoms of the oxygen bound in the relaxed state.
  final List<MorphPoint> oxygen;
}

/// An assembly's `morph` track: the tetramer tense and relaxed, in one frame
/// (`pipeline/assemblies` in the backend: 2DN2 and 2DN1's biological
/// assembly, superposed on one alpha-beta pair).
@immutable
final class OxygenMorph {
  const OxygenMorph({
    required this.slug,
    required this.display,
    required this.chains,
    required this.boundsMin,
    required this.boundsMax,
    required this.entries,
    required this.turnedDegrees,
  });

  factory OxygenMorph.fromJson(Map<String, dynamic> json, String slug) {
    if (json['slug'] != slug) {
      throw FormatException('A morph of ${json['slug']}, not $slug');
    }
    final Map<String, dynamic> frame = json['frame'] as Map<String, dynamic>;
    final Map<String, dynamic> bounds = frame['bounds'] as Map<String, dynamic>;
    final List<String> states = <String>[
      for (final dynamic s in json['states'] as List<dynamic>)
        (s as Map<String, dynamic>)['name'] as String,
    ];
    if (states.length != 2 ||
        !states.contains('tense') ||
        !states.contains('relaxed')) {
      throw FormatException(
        'A morph of $slug without a tense and a relaxed state',
      );
    }
    final List<MorphChain> chains = <MorphChain>[];
    for (final dynamic raw in json['chains'] as List<dynamic>) {
      final Map<String, dynamic> chain = raw as Map<String, dynamic>;
      final List<MorphPoint> tense = <MorphPoint>[];
      final List<MorphPoint> relaxed = <MorphPoint>[];
      for (final dynamic r in chain['residues'] as List<dynamic>) {
        final Map<String, dynamic> residue = r as Map<String, dynamic>;
        tense.add(_point((residue['tense'] as Map<String, dynamic>)['ca']));
        relaxed.add(_point((residue['relaxed'] as Map<String, dynamic>)['ca']));
      }
      final Map<String, dynamic> haem = chain['haem'] as Map<String, dynamic>;
      final Map<String, dynamic> oxygen =
          chain['oxygen'] as Map<String, dynamic>;
      chains.add(
        MorphChain(
          node: chain['node'] as String,
          gene: chain['gene'] as String,
          tense: List<MorphPoint>.unmodifiable(tense),
          relaxed: List<MorphPoint>.unmodifiable(relaxed),
          haemTense: _point(haem['tense']),
          haemRelaxed: _point(haem['relaxed']),
          oxygen: List<MorphPoint>.unmodifiable(<MorphPoint>[
            for (final dynamic o in oxygen['relaxed'] as List<dynamic>)
              _point(o),
          ]),
        ),
      );
    }
    if (chains.isEmpty) {
      throw FormatException('A morph of $slug with no chain');
    }
    final Map<String, dynamic> superposition =
        frame['superposition'] as Map<String, dynamic>;
    return OxygenMorph(
      slug: slug,
      display: json['display'] as String,
      chains: List<MorphChain>.unmodifiable(chains),
      boundsMin: _point(bounds['min']),
      boundsMax: _point(bounds['max']),
      entries: <String, String>{
        for (final dynamic s in json['states'] as List<dynamic>)
          (s as Map<String, dynamic>)['name'] as String: s['pdb'] as String,
      },
      turnedDegrees: (superposition['turned_degrees'] as num).toDouble(),
    );
  }

  static OxygenMorph decode(Uint8List bytes, String slug) {
    final Object? json = jsonDecode(utf8.decode(bytes));
    if (json is! Map<String, dynamic>) {
      throw FormatException('Malformed morph for $slug');
    }
    return OxygenMorph.fromJson(json, slug);
  }

  final String slug;

  /// The assembly's name, as the backend's table has it.
  final String display;

  final List<MorphChain> chains;
  final MorphPoint boundsMin;
  final MorphPoint boundsMax;

  /// Each state's PDB entry: `tense` and `relaxed`.
  final Map<String, String> entries;

  /// How far the one alpha-beta pair turns against the other, T to R.
  final double turnedDegrees;

  static MorphPoint _point(Object? raw) {
    if (raw is! List<dynamic> || raw.length != 3) {
      throw FormatException('A malformed point: $raw');
    }
    return (
      (raw[0] as num).toDouble(),
      (raw[1] as num).toDouble(),
      (raw[2] as num).toDouble(),
    );
  }
}
