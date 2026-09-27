import '../../../../core/evidence/protein_constraint.dart';
import '../../../../shared/format.dart';
import 'route_evidence.dart';
import 'trafficking_route.dart';

/// One caption for each step of a route, built from its events and the
/// precursor's regions.
///
/// Every number is the record's: where the signal peptide ends, which
/// residues cross a membrane, how many bridges form, where a cut falls.
/// Nothing names the protein, a gene or a tissue, and nothing branches on
/// one. The route is worked out from sequence features, so the words say
/// what those features do, never where the protein is found or which cells
/// make it.
final class RouteCaptions {
  const RouteCaptions(this.route, {required this.chains});

  final TraffickingRoute route;

  /// How many chains the walk says the precursor is cut into, or 1 where the
  /// walk ends at one chain ([ProteinFacts.chains]). A precursor whose pieces
  /// overlap as alternatives is drawn as one, and a caption then says only
  /// that it is cut, not what into.
  final int chains;

  RouteEvidence get _evidence => route.evidence;

  /// The caption for step [step] of the route.
  String captionOf(int step) {
    final RouteStep here = route.steps[step];
    final List<String> said = switch (here.compartment) {
      Compartment.cytosol => _cytosol(here),
      Compartment.er => _er(here),
      Compartment.golgi => <String>['It moves on through the Golgi.'],
      Compartment.vesicle => _vesicle(here),
      Compartment.extracellular => <String>[
        'The vesicle fuses with the membrane and lets it out of the cell.',
      ],
      Compartment.membrane => _membrane(here),
      Compartment.gpiAnchored => <String>[
        'The vesicle fuses with the membrane, and the chain stays on its '
            'outer face, held by the anchor.',
      ],
      Compartment.nucleus => <String>['It is carried into the nucleus.'],
      Compartment.unknown => _unknown(step),
    };
    return said.join(' ');
  }

  List<String> _cytosol(RouteStep here) {
    final RouteEvidence evidence = _evidence;
    if (route.steps.length == 1) {
      final int residues = evidence.regions.lastOrNull?.end ?? 0;
      return <String>[
        'A ribosome in the cytosol makes all ${grouped(residues)} residues, '
            'with no signal peptide and no stretch that crosses a membrane to '
            'send the chain elsewhere.',
        ..._foldedHere(here),
      ];
    }
    if (evidence.signalPeptide case final ConstraintRegion signal) {
      return <String>[
        'A ribosome in the cytosol begins the chain. Its first '
            '${grouped(_length(signal.start, signal.end))} residues are a '
            'signal peptide, which takes the ribosome to the ER as the rest '
            'is made.',
      ];
    }
    if (_spans.firstOrNull case final (int, int) first) {
      return <String>[
        'A ribosome in the cytosol begins the chain. Its first stretch that '
            'crosses a membrane, residues ${_range(first)}, takes the '
            'ribosome to the ER as the rest is made.',
      ];
    }
    return <String>[
      'A ribosome in the cytosol makes the chain, which has no signal '
          'peptide to take it to the ER.',
    ];
  }

  List<String> _er(RouteStep here) {
    final RouteEvidence evidence = _evidence;
    final List<String> said = <String>[];
    for (final RouteEvent event in here.events) {
      final String? sentence = switch (event) {
        RouteEvent.signalPeptideCleaved => switch (evidence.signalPeptide) {
          final ConstraintRegion signal =>
            'the signal peptide, residues '
                '${_range((signal.start, signal.end))}, is cut off.',
          null => null,
        },
        RouteEvent.membraneInserted =>
          _spans.length == 1
              ? 'residues ${_range(_spans.single)} cross the membrane and '
                    'hold the chain in it.'
              : '${spelled(_spans.length)} stretches of it cross the '
                    'membrane, back and forth, and hold it there.',
        RouteEvent.disulfidesFormed => _bridges(),
        RouteEvent.gpiAnchorAttached => switch (evidence.gpiSignal) {
          final ConstraintRegion gpi =>
            'residues ${_range((gpi.start, gpi.end))} are cut off, and a GPI '
                'anchor is attached to residue ${grouped(gpi.start - 1)} in '
                'their place.',
          null => null,
        },
        RouteEvent.proproteinCut => null,
      };
      if (sentence != null) {
        said.add(sentence);
      }
    }
    if (said.isEmpty) {
      return <String>['It enters the ER.'];
    }
    return <String>[
      'In the ER, ${said.first}',
      for (final String sentence in said.skip(1)) _capitalised(sentence),
    ];
  }

  List<String> _vesicle(RouteStep here) => <String>[
    'A vesicle buds from the Golgi and carries it toward the surface.',
    if (here.events.contains(RouteEvent.proproteinCut))
      'On the way, ${_cut()}.',
  ];

  List<String> _membrane(RouteStep here) {
    final String holding = _spans.length == 1
        ? 'the stretch that crosses it'
        : 'the ${spelled(_spans.length)} stretches that cross it';
    final List<String> said = <String>[
      'The vesicle fuses with the membrane, and the chain stays in it, held '
          'by $holding.',
    ];
    if (here.events.contains(RouteEvent.proproteinCut)) {
      if (_shedBetween() case (final int before, final int after)) {
        said.add(
          'There it is cut between residues ${grouped(before)} and '
          '${grouped(after)}: the piece outside the membrane is let go, and '
          'the piece that crosses it stays.',
        );
      } else {
        said.add('There ${_cut()}.');
      }
    }
    return said;
  }

  List<String> _unknown(int step) {
    final RouteEvidence evidence = _evidence;
    if (route.unresolved == Unresolved.conflict) {
      return <String>[
        if (evidence.signalPeptide == null)
          'It has a GPI-anchor signal but no signal peptide to take it to '
              'the ER, where the anchor is attached, so the route stops here.'
        else
          'It has a GPI-anchor signal and a stretch that crosses the '
              'membrane, and the two cannot both hold it, so the route stops '
              'here.',
      ];
    }
    final Compartment before = route.steps[step - 1].compartment;
    if (before == Compartment.vesicle) {
      return <String>[
        'The vesicle fuses with the membrane. Whether the chain is let go or '
            'stays in it turns on whether any stretch of it crosses a '
            'membrane, and its record does not say.',
      ];
    }
    final RouteStep here = route.steps[step];
    final List<String> also = <String>[
      if (here.events.contains(RouteEvent.disulfidesFormed))
        'where ${_bridgesAre()}',
      if (here.events.contains(RouteEvent.proproteinCut)) 'where it is cut',
    ];
    return <String>[
      'Whether it stays in the cytosol or goes into the ER membrane turns on '
          'whether any stretch of it crosses a membrane, and its record does '
          'not say.',
      if (also.isNotEmpty) 'So does ${also.join(' and ')}.',
    ];
  }

  /// What a chain that never leaves the cytosol has done to it there.
  List<String> _foldedHere(RouteStep here) => <String>[
    if (here.events.contains(RouteEvent.disulfidesFormed))
      'Here, in the cytosol, ${_bridgesAre()}.',
    if (here.events.contains(RouteEvent.proproteinCut))
      'Here, in the cytosol, ${_cut()}.',
  ];

  /// "its one disulfide bridge forms", "its three disulfide bridges form".
  String _bridgesAre() {
    final int count = _evidence.bridges.length;
    return count == 1
        ? 'its one disulfide bridge forms'
        : 'its ${spelled(count)} disulfide bridges form';
  }

  /// "one disulfide bridge forms.", "three disulfide bridges form."
  String _bridges() {
    final int count = _evidence.bridges.length;
    return count == 1
        ? 'one disulfide bridge forms.'
        : '${spelled(count)} disulfide bridges form.';
  }

  /// What a cut does, as a clause: "the precursor is cut into three pieces".
  String _cut() {
    final RouteEvidence evidence = _evidence;
    if (chains >= 2) {
      final String trimmed = _trimmed();
      return 'the precursor is cut into ${spelled(chains)} pieces'
          '${trimmed.isEmpty ? '' : ', and $trimmed'}';
    }
    if (evidence.pieces.isEmpty) {
      final List<String> spans = <String>[
        for (final ConstraintRegion region in _runs(evidence.cutOut))
          _range((region.start, region.end)),
      ];
      return spans.length == 1
          ? 'residues ${spans.single} are cut off'
          : 'residues ${_list(spans)} are cut off';
    }
    // Pieces that overlap as alternatives: the walk draws none of them as
    // what the precursor becomes, and neither does this.
    return 'the precursor is cut';
  }

  /// A stretch cut off either end of the pieces, where there is one: "residue
  /// 229 is trimmed off its end".
  String _trimmed() {
    final RouteEvidence evidence = _evidence;
    final List<ConstraintRegion> pieces = evidence.pieces;
    if (pieces.isEmpty) {
      return '';
    }
    final List<String> ends = <String>[
      for (final ConstraintRegion region in _runs(evidence.cutOut))
        if (region.end < pieces.first.start)
          '${_residues((region.start, region.end))} trimmed off its start'
        else if (region.start > pieces.last.end)
          '${_residues((region.start, region.end))} trimmed off its end',
    ];
    return _list(ends);
  }

  /// Where a membrane protein's cut parts the piece that crosses the membrane
  /// from one that does not: the last residue before the cut, and the first
  /// after it.
  (int, int)? _shedBetween() {
    final List<ConstraintRegion> pieces = _evidence.pieces;
    bool held(ConstraintRegion piece) => _spans.any(
      ((int, int) span) => span.$1 <= piece.end && span.$2 >= piece.start,
    );
    for (int i = 0; i + 1 < pieces.length; i++) {
      if (held(pieces[i]) != held(pieces[i + 1])) {
        return (pieces[i].end, pieces[i + 1].start);
      }
    }
    return null;
  }

  List<(int, int)> get _spans =>
      _evidence.transmembrane ?? const <(int, int)>[];

  /// Contiguous regions merged, so a cleavage site, a C-peptide and the site
  /// after it read as the one stretch they are.
  static List<ConstraintRegion> _runs(List<ConstraintRegion> regions) {
    final List<ConstraintRegion> runs = <ConstraintRegion>[];
    for (final ConstraintRegion region in regions) {
      final ConstraintRegion? last = runs.lastOrNull;
      if (last != null && last.end + 1 == region.start) {
        runs[runs.length - 1] = ConstraintRegion(
          label: last.label,
          short: last.short,
          start: last.start,
          end: region.end,
          origin: last.origin,
          kept: last.kept,
        );
      } else {
        runs.add(region);
      }
    }
    return runs;
  }

  static int _length(int start, int end) => end - start + 1;

  static String _range((int, int) span) => span.$1 == span.$2
      ? grouped(span.$1)
      : '${grouped(span.$1)}–${grouped(span.$2)}';

  /// "residue 229 is", "residues 179–180 are".
  static String _residues((int, int) span) => span.$1 == span.$2
      ? 'residue ${_range(span)} is'
      : 'residues ${_range(span)} are';

  static String _list(List<String> items) => switch (items.length) {
    0 => '',
    1 => items.single,
    _ => '${items.sublist(0, items.length - 1).join(', ')} and ${items.last}',
  };

  static String _capitalised(String sentence) => sentence.isEmpty
      ? sentence
      : sentence[0].toUpperCase() + sentence.substring(1);
}
