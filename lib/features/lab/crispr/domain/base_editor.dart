import 'package:flutter/foundation.dart';

import 'guide_finder.dart';

/// A base editor: a deaminase carried to one place by a guide, which rewrites
/// one base without cutting both strands of the helix.
///
/// There are three of them and there is no way to write a fourth. The class is
/// sealed, each editor is its own type, and the base it writes is that type's
/// rather than a parameter of it. **An editor that turned A into T cannot be
/// named here** — not because something refuses it, but because there is
/// nothing to say it with. A constructor taking two bases would have let a
/// screen ask for the change that turns the sickle codon back, and no editor
/// makes that change.
///
/// An editor works on the strand its guide is aimed at, and a change to one
/// strand is a change to the pair. So on the page's own letters these three
/// write six of the twelve changes ([changes]), and A to T is not one of them
/// on either strand. [forChange] is the one place to ask.
@immutable
sealed class BaseEditor {
  const BaseEditor();

  /// The base this editor rewrites, on the strand its guide is aimed at.
  String get from;

  /// What it writes there.
  String get to;

  /// What it is called.
  String get name;

  /// What it is called in short.
  String get abbreviation;

  /// The three of them, in the order they arrived.
  static const List<BaseEditor> all = <BaseEditor>[
    AdenineBaseEditor(),
    CytosineBaseEditor(),
    CytosineToGuanineBaseEditor(),
  ];

  /// The first and last base of the protospacer an editor reaches, counted
  /// from the guide's own 5' end.
  ///
  /// A convention rather than a measurement, and the widely used editors
  /// differ: the deaminase is tethered to the nuclease, so it reaches the
  /// stretch of strand the nuclease holds open, and where that is depends on
  /// the tether. Four to eight is the window those editors are usually quoted
  /// with.
  static const int windowFrom = 4;
  static const int windowTo = 8;

  /// What this editor writes where the page draws [base], for a guide on
  /// [strand], or null where that base is not its substrate there.
  String? rewrites(String base, GuideStrand strand) {
    final bool sense = strand == GuideStrand.sense;
    final String substrate = sense ? from : complementOf(from);
    return base == substrate ? (sense ? to : complementOf(to)) : null;
  }

  /// The editor that writes [to] where the page draws [from], and the strand
  /// its guide has to be aimed at — or null where no editor writes it at all.
  static ({BaseEditor editor, GuideStrand strand})? forChange({
    required String from,
    required String to,
  }) {
    for (final BaseEditor editor in all) {
      for (final GuideStrand strand in GuideStrand.values) {
        if (editor.rewrites(from, strand) == to) {
          return (editor: editor, strand: strand);
        }
      }
    }
    return null;
  }

  /// Every change the three of them write between them, as the page draws
  /// them, in the order [all] and [GuideStrand.values] give them.
  static List<({String from, String to})> get changes {
    final List<({String from, String to})> written =
        <({String from, String to})>[];
    for (final BaseEditor editor in all) {
      for (final GuideStrand strand in GuideStrand.values) {
        final String from = strand == GuideStrand.sense
            ? editor.from
            : complementOf(editor.from);
        final String to = strand == GuideStrand.sense
            ? editor.to
            : complementOf(editor.to);
        if (!written.any(
          (({String from, String to}) change) =>
              change.from == from && change.to == to,
        )) {
          written.add((from: from, to: to));
        }
      }
    }
    return written;
  }

  @override
  String toString() => '$abbreviation ($from to $to)';
}

/// Adenine deaminated to inosine, which is read as G.
final class AdenineBaseEditor extends BaseEditor {
  const AdenineBaseEditor();

  @override
  String get from => 'A';

  @override
  String get to => 'G';

  @override
  String get name => 'adenine base editor';

  @override
  String get abbreviation => 'ABE';
}

/// Cytosine deaminated to uracil, which is read as T.
final class CytosineBaseEditor extends BaseEditor {
  const CytosineBaseEditor();

  @override
  String get from => 'C';

  @override
  String get to => 'T';

  @override
  String get name => 'cytosine base editor';

  @override
  String get abbreviation => 'CBE';
}

/// The same deamination, finished the other way: the uracil is cut out and the
/// gap filled with G instead of read as T.
final class CytosineToGuanineBaseEditor extends BaseEditor {
  const CytosineToGuanineBaseEditor();

  @override
  String get from => 'C';

  @override
  String get to => 'G';

  @override
  String get name => 'C-to-G base editor';

  @override
  String get abbreviation => 'CGBE';
}
