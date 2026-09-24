import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../../../../core/theme/app_typography.dart';
import '../../domain/entities/gene_clinvar.dart';
import '../../domain/entities/gene_impact.dart';
import '../../domain/entities/protein_constraint.dart';
import '../../domain/entities/variant_evidence.dart';
import '../constraint/constraint_colors.dart';
import '../format.dart';
import 'clinvar_colors.dart';
import 'evidence_sections.dart';

/// The strip's two drawings: the protein, and the gene around it.
enum StripPanel { protein, dna }

/// A stretch of a panel in the panel's own units: residues along the protein,
/// residue r running from r − 1 to r, and bases along the drawn gene, 5′ to 3′.
typedef StripWindow = (double, double);

/// The whole snapshot at once, with each source on one channel of its own.
///
/// Along the protein, every record with a residue is a lollipop at that
/// residue: its height is the AVI score of its own allele, its head is its
/// ClinVar class, and it stands on the ESM constraint of the residue, drawn on
/// the same ramp as the protein page. Records off the protein stand on a
/// drawing of the gene in a second panel, where there is no protein for ESM to
/// speak for. Both panels share one AVI scale, so equal heights are equal
/// scores. Nothing is combined: a reader sees where the classified records
/// sit, how high AVI puts them and how constrained the ground under them is,
/// and draws the connection themselves.
///
/// Every mark keeps its real position and height whatever is shown: the
/// classes left out are simply not drawn, and the scale is set by every record
/// so leaving some out never moves the rest. A dense stretch overlaps rather
/// than spreading out. Each panel zooms — its − and + keys, a pinch, or a tap
/// on a region's name under it — and a zoomed panel carries a bar with the
/// whole on it and the window framed, which is dragged to move along. The same
/// positions, at a larger scale; the list below is the precise path to each
/// record.
class EvidenceStrip extends StatefulWidget {
  const EvidenceStrip({
    required this.evidence,
    required this.proteinLength,
    required this.geneStart,
    required this.geneEnd,
    required this.exons,
    required this.onSelected,
    this.runs = const <GeneRun>[],
    this.constraint,
    this.reversed = false,
    this.classes = const <ClinVarGroup>{},
    this.selected = const <String>{},
    this.proteinWindow,
    this.dnaWindow,
    this.onWindow,
    this.only,
    this.onExpand,
    this.onClose,
    super.key,
  });

  final List<VariantEvidence> evidence;
  final int proteinLength;

  /// The drawn gene, in record positions, and its exons, for the DNA panel.
  final int geneStart;
  final int geneEnd;
  final List<(int, int)> exons;

  /// The gene's named pieces, which the DNA panel names and zooms to.
  final List<GeneRun> runs;

  /// A minus-strand record, drawn 5′ to 3′ like every other page.
  final bool reversed;
  final ProteinConstraint? constraint;

  /// The classes drawn, or none for every class. A class left out is not
  /// drawn at all — no ring, no stem — and nothing of it can be tapped.
  final Set<ClinVarGroup> classes;
  final Set<String> selected;

  /// A tapped mark, and which of the heads drawn over one another there it
  /// is, counting from one: a second tap on it moves on to the next, and
  /// after the last — or on a head alone — lets it go. A tap on the plot away
  /// from every mark lets it go too. Letting go is a null id and cycle.
  final void Function(String? id, (int, int)? cycle) onSelected;

  /// What each panel shows, or null for the whole protein and the whole gene.
  final StripWindow? proteinWindow;
  final StripWindow? dnaWindow;

  /// Asks for a panel's window to change, null for the whole; without it the
  /// strip does not zoom.
  final void Function(StripPanel panel, StripWindow? window)? onWindow;

  /// The one panel drawn, on a page that gives it the whole screen: its
  /// title, its drawing as tall as the page allows, and the bar's room under
  /// it whether or not it is zoomed, so a zoom never resizes the drawing.
  /// Null for both panels, as the overview draws them.
  final StripPanel? only;

  /// Opens a panel on a page of its own, from a key at the end of its title.
  final void Function(StripPanel panel)? onExpand;

  /// Closes the page the panel is on, from a key at the start of its title.
  final VoidCallback? onClose;

  /// The narrowest a panel zooms to: ten residues, twelve bases.
  static const double leastResidues = 10;
  static const double leastBases = 12;

  /// How many residues apart the zoomed protein's numbers are: every fifth,
  /// or the first of every 10th, 20th, 50th, 100th… that leaves [room] points
  /// between two of them at [perResidue] points a residue.
  static int residueStep(double perResidue, double room) {
    if (perResidue <= 0) {
      return 5;
    }
    int step = 5;
    for (int scale = 10; step * perResidue < room; scale *= 10) {
      for (final int next in <int>[scale, scale * 2, scale * 5]) {
        step = next;
        if (step * perResidue >= room) {
          break;
        }
      }
    }
    return step;
  }

  /// Whether stems are drawn at [perMark] points of panel for each mark it
  /// draws. Below two, a stem is most of the ink on the panel and says nothing
  /// a head's place does not.
  static bool stems(double perMark) => perMark >= 2;

  /// How large a head is drawn at [perMark] points of panel for each mark: full
  /// size while marks have room, smaller as they crowd, so a dense stretch
  /// stays a shape rather than becoming a slab.
  static double headRadius(double perMark) => perMark >= 1
      ? 3.4
      : perMark >= 0.4
      ? 2.6
      : 2.0;

  /// The window a tap on [region]'s name zooms to: two residues either side,
  /// so the cut site between two chains stays in view from both of them.
  static StripWindow regionWindow(ConstraintRegion region, int proteinLength) =>
      _atLeast(
        region.start - 3.0,
        region.end + 2.0,
        leastResidues,
        proteinLength.toDouble(),
      );

  /// The window a tap on [run]'s name zooms to: the piece itself.
  static StripWindow runWindow(
    GeneRun run, {
    required int geneStart,
    required int geneEnd,
    bool reversed = false,
  }) {
    int index(int position) =>
        reversed ? geneEnd - position : position - geneStart;
    final int a = index(run.start);
    final int b = index(run.end);
    return _atLeast(
      math.min(a, b).toDouble(),
      math.max(a, b) + 1.0,
      leastBases,
      (geneEnd - geneStart + 1).toDouble(),
    );
  }

  double get _geneLength => (geneEnd - geneStart + 1).toDouble();

  /// A panel's whole length, in its own units.
  StripWindow whole(StripPanel panel) => panel == StripPanel.protein
      ? (0, proteinLength.toDouble())
      : (0, _geneLength);

  /// Whether [e]'s class is drawn.
  bool drawn(VariantEvidence e) =>
      classes.isEmpty || classes.contains(e.variant.group);

  /// Whether [e] is in its panel's window: always, unless that panel is
  /// zoomed to a stretch that leaves it out.
  bool shows(VariantEvidence e) {
    final StripWindow? window = e.variant.residue != null
        ? proteinWindow
        : dnaWindow;
    if (window == null) {
      return true;
    }
    final double u = coordinate(e);
    return u >= window.$1 && u <= window.$2;
  }

  /// Whether the panels draw [e]: its class is shown and its place is in view.
  /// The list under the strip holds exactly these.
  bool draws(VariantEvidence e) => drawn(e) && shows(e);

  /// Where [e] sits along its panel.
  double coordinate(VariantEvidence e) => switch (e.variant.residue) {
    final int residue => residue - 0.5,
    null => _index(e.variant.position) + 0.5,
  };

  /// Where a base sits along the gene, 5′ to 3′ whichever strand it is on.
  int _index(int position) =>
      reversed ? geneEnd - position : position - geneStart;

  (double, double) _span(GeneRun run) => _spanOf(run.start, run.end);

  (double, double) _spanOf(int start, int end) {
    final int a = _index(start);
    final int b = _index(end);
    return (math.min(a, b).toDouble(), math.max(a, b) + 1.0);
  }

  static StripWindow _atLeast(
    double from,
    double to,
    double least,
    double length,
  ) {
    double a = from;
    double b = to;
    if (b - a < least) {
      final double middle = (a + b) / 2;
      a = middle - least / 2;
      b = middle + least / 2;
    }
    if (a < 0) {
      b -= a;
      a = 0;
    }
    if (b > length) {
      a -= b - length;
      b = length;
    }
    return (math.max(0, a), math.min(length, b));
  }

  /// How many of [at] fall in each of [pieces], counted in one pass rather
  /// than by scanning every record for every piece: dystrophin has thousands
  /// of records and over a hundred pieces. The pieces are in increasing order
  /// and do not overlap, as the constraint track's regions and [geneRuns] are.
  static List<int> _tally<T>(
    List<T> pieces,
    (int, int) Function(T) span,
    Iterable<int> at,
  ) {
    final List<int> counts = List<int>.filled(pieces.length, 0);
    for (final int p in at) {
      int low = 0;
      int high = pieces.length - 1;
      while (low <= high) {
        final int mid = (low + high) >> 1;
        final (int from, int to) = span(pieces[mid]);
        if (p < from) {
          high = mid - 1;
        } else if (p > to) {
          low = mid + 1;
        } else {
          counts[mid]++;
          break;
        }
      }
    }
    return counts;
  }

  @override
  State<EvidenceStrip> createState() => _EvidenceStripState();
}

/// One panel's records that have a place on it: those with an AVI score, in
/// the classes drawn.
final class _Records {
  _Records(Iterable<VariantEvidence> records, double Function(VariantEvidence) at) {
    for (final VariantEvidence e in records) {
      if (e.avi case final double avi) {
        list.add(e);
        us.add(at(e));
        avis.add(avi);
      }
    }
  }

  final List<VariantEvidence> list = <VariantEvidence>[];
  final List<double> us = <double>[];
  final List<double> avis = <double>[];
}

class _EvidenceStripState extends State<EvidenceStrip> {
  /// Windows a gesture is moving, not yet handed to the overview. The panels
  /// follow them without animating, so the picture moves with the finger.
  final Map<StripPanel, StripWindow> _live = <StripPanel, StripWindow>{};

  /// Where a pinch started: the window, and the place under the fingers.
  StripWindow? _pinchFrom;
  double _pinchAt = 0;

  List<VariantEvidence>? _source;
  Set<ClinVarGroup>? _sourceClasses;
  List<GeneRun>? _sourceRuns;
  ProteinConstraint? _sourceConstraint;
  late _Records _protein;
  late _Records _dna;

  /// What the strip reads off every record, worked out once for the records,
  /// classes and pieces it is given rather than on every build: the AVI
  /// ceiling, whether any record is off the protein, and each panel's records
  /// and how many of them are drawn.
  late double _ceiling;
  late bool _offProtein;
  final Map<StripPanel, (int, int)> _tallies = <StripPanel, (int, int)>{};

  /// The regions a tap on the protein's ground zooms to: those with a record
  /// drawn in them, or every region when the classes shown leave none.
  late List<ConstraintRegion> _zoomableRegions;

  /// The pieces of the gene holding a record the DNA panel draws, with how
  /// many they hold.
  late List<(GeneRun, int)> _heldRuns;

  /// What the records off the protein sit in, in transcript order: `5′ UTR ·
  /// introns · 3′ UTR`.
  late String _dnaKinds;

  /// Each panel's marks as last placed, and what they were placed for, so a
  /// rebuild that changes nothing about a panel does not place them again.
  final Map<StripPanel, (Object, _MarkBatch)> _batches =
      <StripPanel, (Object, _MarkBatch)>{};

  @override
  void didUpdateWidget(EvidenceStrip old) {
    super.didUpdateWidget(old);
    // A window set from outside — "Show all", or a record revealed outside
    // it — replaces whatever a gesture was holding.
    if (old.proteinWindow != widget.proteinWindow) {
      _live.remove(StripPanel.protein);
    }
    if (old.dnaWindow != widget.dnaWindow) {
      _live.remove(StripPanel.dna);
    }
  }

  void _cache() {
    if (identical(_source, widget.evidence) &&
        setEquals(_sourceClasses, widget.classes) &&
        identical(_sourceRuns, widget.runs) &&
        identical(_sourceConstraint, widget.constraint)) {
      return;
    }
    _source = widget.evidence;
    _sourceClasses = Set<ClinVarGroup>.of(widget.classes);
    _sourceRuns = widget.runs;
    _sourceConstraint = widget.constraint;
    _protein = _Records(
      widget.evidence.where(
        (VariantEvidence e) => e.variant.residue != null && widget.drawn(e),
      ),
      widget.coordinate,
    );
    _dna = _Records(
      widget.evidence.where(
        (VariantEvidence e) => e.variant.residue == null && widget.drawn(e),
      ),
      widget.coordinate,
    );
    _batches.clear();
    double highest = 0;
    // Each panel's records, and those of them in the classes drawn, with an
    // AVI score or without.
    int protein = 0;
    int proteinDrawn = 0;
    int dnaDrawn = 0;
    for (final VariantEvidence e in widget.evidence) {
      highest = math.max(highest, e.avi ?? 0);
      final bool drawn = widget.drawn(e);
      if (e.variant.residue != null) {
        protein++;
        if (drawn) {
          proteinDrawn++;
        }
      } else if (drawn) {
        dnaDrawn++;
      }
    }
    _ceiling = math.max(GeneImpact.barCeiling, (highest / 10).ceil() * 10.0);
    _offProtein = protein < widget.evidence.length;
    _tallies
      ..[StripPanel.protein] = (protein, proteinDrawn)
      ..[StripPanel.dna] = (widget.evidence.length - protein, dnaDrawn);
    _zoomableRegions = _regionsHeld();
    _heldRuns = _runsHeld();
    _dnaKinds = _kindsOffProtein();
  }

  _Records _records(StripPanel panel) =>
      panel == StripPanel.protein ? _protein : _dna;

  StripWindow? _committed(StripPanel panel) =>
      panel == StripPanel.protein ? widget.proteinWindow : widget.dnaWindow;

  StripWindow _window(StripPanel panel) =>
      _live[panel] ?? _committed(panel) ?? widget.whole(panel);

  bool _zoomed(StripPanel panel) =>
      _live.containsKey(panel) || _committed(panel) != null;

  double _least(StripPanel panel) => panel == StripPanel.protein
      ? EvidenceStrip.leastResidues
      : EvidenceStrip.leastBases;

  /// [from] and [span], moved inside the panel's whole length.
  StripWindow _within(StripPanel panel, double from, double span) {
    final double length = widget.whole(panel).$2;
    final double width = span.clamp(_least(panel), length);
    final double start = from.clamp(0.0, length - width);
    return (start, start + width);
  }

  /// Hands [window] to the overview — null, or anything as wide as the whole,
  /// meaning the whole.
  void _commit(StripPanel panel, StripWindow? window) {
    _live.remove(panel);
    final StripWindow whole = widget.whole(panel);
    final StripWindow? next =
        window == null || window.$2 - window.$1 >= whole.$2 - whole.$1 - 1e-6
        ? null
        : window;
    widget.onWindow?.call(panel, next);
    setState(() {});
  }

  /// The selected record's place, when it is on [panel] and in view: what the
  /// + key zooms in on.
  double? _focus(StripPanel panel) {
    if (widget.selected.length != 1) {
      return null;
    }
    final StripWindow window = _window(panel);
    for (final VariantEvidence e in _records(panel).list) {
      if (e.variant.id == widget.selected.single) {
        final double u = widget.coordinate(e);
        return u >= window.$1 && u <= window.$2 ? u : null;
      }
    }
    return null;
  }

  bool _canZoomIn(StripPanel panel) {
    final StripWindow window = _window(panel);
    return window.$2 - window.$1 > _least(panel) + 1e-6;
  }

  /// Halves the window, or doubles it for a [factor] of 0.5.
  void _zoomBy(StripPanel panel, double factor) {
    final StripWindow window = _window(panel);
    final double span = (window.$2 - window.$1) / factor;
    final double centre = _focus(panel) ?? (window.$1 + window.$2) / 2;
    _commit(panel, _within(panel, centre - span / 2, span));
  }

  List<ConstraintRegion> _regionsHeld() {
    final List<ConstraintRegion> regions =
        widget.constraint?.regions ?? const <ConstraintRegion>[];
    final List<int> counts = EvidenceStrip._tally<ConstraintRegion>(
      regions,
      (ConstraintRegion r) => (r.start, r.end),
      <int>[for (final VariantEvidence e in _protein.list) ?e.variant.residue],
    );
    final List<ConstraintRegion> held = <ConstraintRegion>[
      for (int i = 0; i < regions.length; i++)
        if (counts[i] > 0) regions[i],
    ];
    return held.isEmpty ? regions : held;
  }

  List<(GeneRun, int)> _runsHeld() {
    final List<int> counts = EvidenceStrip._tally<GeneRun>(
      widget.runs,
      (GeneRun r) => (r.start, r.end),
      <int>[for (final VariantEvidence e in _dna.list) e.variant.position],
    );
    return <(GeneRun, int)>[
      for (int i = 0; i < widget.runs.length; i++)
        if (counts[i] > 0) (widget.runs[i], counts[i]),
    ];
  }

  List<GeneRun> get _zoomableRuns {
    final List<GeneRun> held = <GeneRun>[
      for (final (GeneRun run, int _) in _heldRuns) run,
    ];
    return held.isEmpty ? widget.runs : held;
  }

  StripWindow _runWindow(GeneRun run) => EvidenceStrip.runWindow(
    run,
    geneStart: widget.geneStart,
    geneEnd: widget.geneEnd,
    reversed: widget.reversed,
  );

  static bool _same(StripWindow a, StripWindow b) =>
      (a.$1 - b.$1).abs() < 1e-6 && (a.$2 - b.$2).abs() < 1e-6;

  String _kindsOffProtein() {
    final List<VariantEvidence> off = <VariantEvidence>[
      for (final VariantEvidence e in widget.evidence)
        if (e.variant.residue == null) e,
    ]..sort((VariantEvidence a, VariantEvidence b) => a.order.compareTo(b.order));
    final List<String> labels = <String>[];
    for (final VariantEvidence e in off) {
      if (!labels.contains(e.section)) {
        labels.add(e.section);
      }
    }
    final int introns = labels.where((String l) => l.startsWith('Intron')).length;
    final List<String> kinds = <String>[];
    for (final String label in labels) {
      final String kind = label.startsWith('Intron') && introns > 1
          ? 'introns'
          : label[0].toLowerCase() + label.substring(1);
      if (!kinds.contains(kind)) {
        kinds.add(kind);
      }
    }
    return kinds.join(' · ');
  }

  /// A region's own name for a window made from it; otherwise the residues it
  /// spans.
  String _proteinTitle(StripWindow? window) {
    if (window == null) {
      return 'Protein · residues 1–${widget.proteinLength}';
    }
    for (final ConstraintRegion region
        in widget.constraint?.regions ?? const <ConstraintRegion>[]) {
      if (_same(EvidenceStrip.regionWindow(region, widget.proteinLength), window)) {
        return 'Protein · ${region.label} ${region.start}–${region.end}';
      }
    }
    final int from = (window.$1.floor() + 1).clamp(1, widget.proteinLength);
    final int to = window.$2.ceil().clamp(1, widget.proteinLength);
    return 'Protein · residues $from–$to of ${widget.proteinLength}';
  }

  /// A piece's own name for a window made from it, with its real length where
  /// it is drawn shortened; otherwise the pieces the window spans. Numbers
  /// along a gene whose introns are drawn shortened would not be the gene's.
  String _dnaTitle(StripWindow? window) {
    if (window == null) {
      return 'DNA · $_dnaKinds';
    }
    for (final GeneRun run in widget.runs) {
      if (_same(_runWindow(run), window)) {
        return 'DNA · ${run.label} · ${grouped(run.lengthBp)} bp';
      }
    }
    final List<String> spanned = <String>[
      for (final GeneRun run in widget.runs)
        if (widget._span(run) case (final double a, final double b)
            when b > window.$1 && a < window.$2)
          run.label,
    ];
    return switch (spanned) {
      <String>[] => 'DNA',
      <String>[final String one] => 'DNA · part of $one',
      _ => 'DNA · ${spanned.first} to ${spanned.last}',
    };
  }

  String _title(StripPanel panel) {
    final StripWindow? window = _live[panel] ?? _committed(panel);
    return panel == StripPanel.protein
        ? _proteinTitle(window)
        : _dnaTitle(window);
  }

  @override
  Widget build(BuildContext context) {
    _cache();
    final double ceiling = _ceiling;
    final double labelScale = MediaQuery.textScalerOf(
      context,
    ).scale(1).clamp(1.0, 1.3);
    if (widget.only case final StripPanel only) {
      // A page of its own: its whole height goes to the AVI area, less the
      // title, the panel's own labels and the bar's room.
      return LayoutBuilder(
        key: const ValueKey<String>('evidence-strip'),
        builder: (BuildContext context, BoxConstraints bounds) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: _piece(
            context,
            only,
            plot: math.max(
              0.0,
              bounds.maxHeight -
                  _PanelTitle.height -
                  _Geometry.heightFor(0, labelScale) -
                  _WindowBar.height,
            ),
            ceiling: ceiling,
            labelScale: labelScale,
            keepBarRoom: true,
          ),
        ),
      );
    }
    // One AVI area for both panels, as tall as the screen can spare: 120
    // points on a 740-point phone, never under 96 or over 128.
    final double plot = (MediaQuery.sizeOf(context).height * 0.16).clamp(
      96.0,
      128.0,
    );
    final bool offProtein = _offProtein;
    return Column(
      key: const ValueKey<String>('evidence-strip'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (final StripPanel panel in <StripPanel>[
          StripPanel.protein,
          if (offProtein) StripPanel.dna,
        ]) ...<Widget>[
          if (panel == StripPanel.dna) const SizedBox(height: 8),
          ..._piece(
            context,
            panel,
            plot: plot,
            ceiling: ceiling,
            labelScale: labelScale,
          ),
        ],
      ],
    );
  }

  /// A panel's title, its drawing, and the bar under it while it is zoomed —
  /// or, with [keepBarRoom], the bar's room whether or not it is.
  List<Widget> _piece(
    BuildContext context,
    StripPanel panel, {
    required double plot,
    required double ceiling,
    required double labelScale,
    bool keepBarRoom = false,
  }) {
    final void Function(StripPanel)? expand = widget.onExpand;
    // The whole, with the window on it: only while there is a window, and
    // under the panel, so it moves nothing the reader was looking at when it
    // arrives.
    final Widget? bar = _zoomed(panel) && widget.onWindow != null
        ? _WindowBar(
            key: ValueKey<String>('evidence-window-${panel.name}'),
            panel: panel,
            whole: widget.whole(panel),
            window: _window(panel),
            constraint: panel == StripPanel.protein ? widget.constraint : null,
            exons: <(double, double)>[
              if (panel == StripPanel.dna)
                for (final (int a, int b) in widget.exons) widget._spanOf(a, b),
            ],
            onMove: (StripWindow window) =>
                setState(() => _live[panel] = window),
            onDone: () => _commit(panel, _window(panel)),
          )
        : null;
    return <Widget>[
      _PanelTitle(
        panel: panel,
        text: _title(panel),
        onWhole: _zoomed(panel) && widget.onWindow != null
            ? () => _commit(panel, null)
            : null,
        onZoomIn: widget.onWindow != null && _canZoomIn(panel)
            ? () => _zoomBy(panel, 2)
            : null,
        onZoomOut: widget.onWindow != null && _zoomed(panel)
            ? () => _zoomBy(panel, 0.5)
            : null,
        zoomable: widget.onWindow != null,
        onExpand: expand == null ? null : () => expand(panel),
        onClose: widget.onClose,
      ),
      _panel(
        context,
        panel,
        plot: plot,
        ceiling: ceiling,
        labelScale: labelScale,
      ),
      if (keepBarRoom)
        SizedBox(height: _WindowBar.height, child: bar)
      else
        ?bar,
    ];
  }

  Widget _panel(
    BuildContext context,
    StripPanel panel, {
    required double plot,
    required double ceiling,
    required double labelScale,
  }) {
    final ThemeData theme = Theme.of(context);
    final bool protein = panel == StripPanel.protein;
    final StripWindow target = _window(panel);
    final double height = _Geometry.heightFor(plot, labelScale);
    final _Records records = _records(panel);
    final (int count, int drawn) = _tallies[panel]!;
    final List<(GeneRun, int)> held = protein
        ? const <(GeneRun, int)>[]
        : _heldRuns;
    // What each zoom is called, which a screen reader needs to tell apart: a
    // region by its span, as the panel's title then names it, and a name the
    // gene uses twice — the stretch outside the transcript at either end — by
    // which one it is.
    final List<GeneRun> zoomableRuns = protein ? const <GeneRun>[] : _zoomableRuns;
    String called(int i) {
      final String label = zoomableRuns[i].label;
      final int same = zoomableRuns
          .where((GeneRun r) => r.label == label)
          .length;
      if (same == 1) {
        return label;
      }
      final int which = zoomableRuns
          .take(i + 1)
          .where((GeneRun r) => r.label == label)
          .length;
      return '$label ($which of $same)';
    }

    final Map<StripWindow, String> zoomable = <StripWindow, String>{
      if (protein)
        for (final ConstraintRegion region in _zoomableRegions)
          EvidenceStrip.regionWindow(region, widget.proteinLength):
              '${region.label} ${region.start}–${region.end}'
      else
        for (int i = 0; i < zoomableRuns.length; i++)
          _runWindow(zoomableRuns[i]): called(i),
    };
    // Everything the painter needs that does not move with the zoom, worked
    // out once per build rather than on every frame of the zoom's motion.
    final List<(double, double)> exonSpans = <(double, double)>[
      if (!protein)
        for (final (int a, int b) in widget.exons) widget._spanOf(a, b),
    ];
    final List<_Piece> pieces = <_Piece>[
      for (final (GeneRun run, int records) in held)
        _Piece(run.label, widget._span(run), records),
    ];
    final bool zoomed = _zoomed(panel);
    final bool live = _live.containsKey(panel);
    final String wholeName = protein ? 'the whole protein' : 'the whole gene';
    return Semantics(
      container: true,
      label: protein
          ? '$drawn ClinVar records on the ${widget.proteinLength} residues '
                'of the protein${drawn == count ? '' : ', of the classes shown'}. '
                'Heights are each record’s AVI score, with a dashed line at '
                '20, the top 1% genome-wide; the band under them is ESM '
                'constraint, and colours are ClinVar classes.'
          : '$drawn ClinVar records outside the protein, on the gene’s '
                '$_dnaKinds${drawn == count ? '' : ', of the classes shown'}. '
                'Heights are each record’s AVI score, with a dashed line at '
                '20, the top 1% genome-wide, and colours are ClinVar classes.',
      value: _title(panel),
      customSemanticsActions: widget.onWindow == null
          ? null
          : <CustomSemanticsAction, VoidCallback>{
              if (_canZoomIn(panel))
                const CustomSemanticsAction(label: 'Zoom in'): () =>
                    _zoomBy(panel, 2),
              if (zoomed) ...<CustomSemanticsAction, VoidCallback>{
                const CustomSemanticsAction(label: 'Zoom out'): () =>
                    _zoomBy(panel, 0.5),
                CustomSemanticsAction(label: 'Show $wholeName'): () =>
                    _commit(panel, null),
              },
              for (final MapEntry<StripWindow, String> entry
                  in zoomable.entries)
                if (!_same(entry.key, target))
                  CustomSemanticsAction(label: 'Zoom to ${entry.value}'): () =>
                      _commit(panel, entry.key),
            },
      excludeSemantics: true,
      child: TweenAnimationBuilder<Offset>(
        tween: Tween<Offset>(end: Offset(target.$1, target.$2)),
        // A gesture's window is followed as it moves; only a window chosen by
        // a key or a tap travels there.
        duration: live || MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
        builder: (BuildContext context, Offset window, Widget? _) =>
            LayoutBuilder(
              builder: (BuildContext context, BoxConstraints bounds) {
                final _Geometry geometry = _Geometry(
                  Size(bounds.maxWidth, height),
                  plot: plot,
                  ceiling: ceiling,
                  window: (window.dx, window.dy),
                  labelScale: labelScale,
                );
                final _MarkBatch batch = _batch(panel, records, geometry);
                return RawGestureDetector(
                  key: ValueKey<String>('evidence-strip-${panel.name}'),
                  behavior: HitTestBehavior.opaque,
                  gestures: _gestures(panel, geometry, batch),
                  // A layer of its own: the page scrolling moves the picture
                  // rather than painting thousands of marks again.
                  child: RepaintBoundary(
                    child: CustomPaint(
                      size: Size(bounds.maxWidth, height),
                      painter: _StripPainter(
                        panel: panel,
                        geometry: geometry,
                        batch: batch,
                        constraint: widget.constraint,
                        proteinLength: widget.proteinLength,
                        zoomed: zoomed,
                        exons: exonSpans,
                        pieces: pieces,
                        colors: theme.colorScheme,
                        labelScale: labelScale,
                        empty: records.list.isEmpty
                            ? (widget.classes.isEmpty
                                  ? null
                                  : 'No records of these classes here')
                            : batch.hits.isEmpty
                            ? 'No records in this window'
                            : null,
                      ),
                    ),
                  ),
                );
              },
            ),
      ),
    );
  }

  /// The marks [records] place at [geometry]: heads by class, stems where
  /// there is room for them, and rings on the selected.
  _MarkBatch _batch(
    StripPanel panel,
    _Records records,
    _Geometry geometry,
  ) {
    final Object key = Object.hash(
      records,
      geometry.size,
      geometry.window,
      geometry.plot,
      geometry.ceiling,
      Object.hashAllUnordered(widget.selected),
    );
    final (Object, _MarkBatch)? memo = _batches[panel];
    if (memo != null && memo.$1 == key) {
      return memo.$2;
    }
    final bool protein = panel == StripPanel.protein;
    final List<(String, ClinVarGroup, Offset)> hits =
        <(String, ClinVarGroup, Offset)>[];
    for (int i = 0; i < records.list.length; i++) {
      final double u = records.us[i];
      if (!geometry.visible(u)) {
        continue;
      }
      final VariantEvidence e = records.list[i];
      hits.add((
        e.variant.id,
        e.variant.group,
        Offset(geometry.x(u), geometry.y(records.avis[i])),
      ));
    }
    final double perMark = geometry.width / math.max(1, hits.length);
    final bool stems = EvidenceStrip.stems(perMark);
    final double radius = EvidenceStrip.headRadius(perMark);
    final Map<ClinVarGroup, List<double>> heads =
        <ClinVarGroup, List<double>>{};
    final List<double> stemPoints = <double>[];
    final List<Offset> rings = <Offset>[];
    final double ground = protein
        ? geometry.groundTop
        : geometry.geneLine - 3;
    for (final (String id, ClinVarGroup group, Offset at) in hits) {
      (heads[group] ??= <double>[])
        ..add(at.dx)
        ..add(at.dy);
      if (stems) {
        stemPoints
          ..add(at.dx)
          ..add(ground)
          ..add(at.dx)
          ..add(at.dy);
      }
      if (widget.selected.contains(id)) {
        rings.add(at);
      }
    }
    final _MarkBatch batch = _MarkBatch(
      hits: hits,
      heads: <ClinVarGroup, Float32List>{
        for (final MapEntry<ClinVarGroup, List<double>> entry
            in heads.entries)
          entry.key: Float32List.fromList(entry.value),
      },
      stems: Float32List.fromList(stemPoints),
      rings: rings,
      radius: radius,
      // A halo is what keeps a full-size head legible over its neighbours;
      // around small ones it would erase more than it separates.
      halo: radius >= 3.4,
    );
    _batches[panel] = (key, batch);
    return batch;
  }

  Map<Type, GestureRecognizerFactory> _gestures(
    StripPanel panel,
    _Geometry geometry,
    _MarkBatch batch,
  ) => <Type, GestureRecognizerFactory>{
    TapGestureRecognizer:
        GestureRecognizerFactoryWithHandlers<TapGestureRecognizer>(
          () => TapGestureRecognizer(debugOwner: this),
          (TapGestureRecognizer recognizer) => recognizer.onTapUp =
              (TapUpDetails details) =>
                  _tap(panel, geometry, batch, details.localPosition),
        ),
    if (widget.onWindow != null)
      _PinchGestureRecognizer:
          GestureRecognizerFactoryWithHandlers<_PinchGestureRecognizer>(
            () => _PinchGestureRecognizer(debugOwner: this),
            (_PinchGestureRecognizer recognizer) => recognizer
              ..onStart = (ScaleStartDetails details) {
                _pinchFrom = _window(panel);
                _pinchAt = geometry.u(details.localFocalPoint.dx);
              }
              ..onUpdate = (ScaleUpdateDetails details) {
                final StripWindow from = _pinchFrom ?? _window(panel);
                final double span =
                    (from.$2 - from.$1) /
                    math.max(1e-3, details.horizontalScale);
                final double width = span.clamp(
                  _least(panel),
                  widget.whole(panel).$2,
                );
                // The place that was under the fingers stays under them.
                final double start =
                    _pinchAt -
                    (details.localFocalPoint.dx - geometry.left) /
                        geometry.width *
                        width;
                setState(() => _live[panel] = _within(panel, start, width));
              }
              ..onEnd = (ScaleEndDetails details) {
                _pinchFrom = null;
                if (_live[panel] case final StripWindow window) {
                  _commit(panel, window);
                }
              },
          ),
    // A finger drawn sideways moves a zoomed panel along. On the whole there
    // is nowhere to move, and the drag is left to anything else that wants it.
    if (widget.onWindow != null && _zoomed(panel))
      HorizontalDragGestureRecognizer:
          GestureRecognizerFactoryWithHandlers<HorizontalDragGestureRecognizer>(
            () => HorizontalDragGestureRecognizer(debugOwner: this),
            (HorizontalDragGestureRecognizer recognizer) => recognizer
              ..onUpdate = (DragUpdateDetails details) {
                final StripWindow window = _window(panel);
                final double span = window.$2 - window.$1;
                setState(
                  () => _live[panel] = _within(
                    panel,
                    window.$1 - details.delta.dx / geometry.width * span,
                    span,
                  ),
                );
              }
              ..onEnd = (DragEndDetails details) {
                if (_live[panel] case final StripWindow window) {
                  _commit(panel, window);
                }
              },
          ),
  };

  void _tap(
    StripPanel panel,
    _Geometry geometry,
    _MarkBatch batch,
    Offset at,
  ) {
    final List<(String, ClinVarGroup, Offset)> near =
        <(String, ClinVarGroup, Offset)>[
          for (final (String, ClinVarGroup, Offset) hit in batch.hits)
            if ((hit.$3 - at).distance <= 18) hit,
        ]..sort(
          (
            (String, ClinVarGroup, Offset) a,
            (String, ClinVarGroup, Offset) b,
          ) => (a.$3 - at).distance.compareTo((b.$3 - at).distance),
        );
    // The ground zooms: to the piece under the finger, or back out again, so
    // the gesture is its own undo. A head resting on the ground — an AVI of
    // zero — is still the head's to answer when the finger is on it.
    if (at.dy >= geometry.groundTop - 2 &&
        (near.isEmpty || (near.first.$3 - at).distance > 8)) {
      if (widget.onWindow == null) {
        return;
      }
      if (_zoomed(panel)) {
        _commit(panel, null);
        return;
      }
      final double u = geometry.u(at.dx);
      final StripWindow? window = panel == StripPanel.protein
          ? _nearest<ConstraintRegion>(
              _zoomableRegions,
              (ConstraintRegion r) => (r.start - 1.0, r.end.toDouble()),
              u,
              (ConstraintRegion r) =>
                  EvidenceStrip.regionWindow(r, widget.proteinLength),
            )
          : _nearest<GeneRun>(_zoomableRuns, widget._span, u, _runWindow);
      if (window != null) {
        _commit(panel, window);
      }
      return;
    }
    // Away from every mark, the tap lets the selection go.
    if (near.isEmpty) {
      if (widget.selected.isNotEmpty) {
        widget.onSelected(null, null);
      }
      return;
    }
    // The mark tapped is the one nearest the finger. Heads drawn over one
    // another answer one tap between them, top first as they are painted —
    // the most severe class, and within a class the last drawn — so a place
    // steps through them in one order wherever the finger lands on it.
    final double touching = 2 * batch.radius;
    List<String> pile(Offset head) {
      final List<(int, ClinVarGroup, String)> heads =
          <(int, ClinVarGroup, String)>[
            for (int i = 0; i < batch.hits.length; i++)
              if ((batch.hits[i].$3 - head).distance <= touching)
                (i, batch.hits[i].$2, batch.hits[i].$1),
          ]..sort((
            (int, ClinVarGroup, String) a,
            (int, ClinVarGroup, String) b,
          ) {
            final int severity = ClinVarGroup.bySeverity
                .indexOf(a.$2)
                .compareTo(ClinVarGroup.bySeverity.indexOf(b.$2));
            return severity != 0 ? severity : b.$1.compareTo(a.$1);
          });
      return <String>[for (final (int _, ClinVarGroup _, String id) in heads) id];
    }

    final Offset tapped = near.first.$3;
    // A tap on the selected mark, or on a head drawn over it, moves on to the
    // next of its pile, and after the last lets it go: a head alone is a
    // pile of one, so a second tap on it is the way to put it down.
    if (widget.selected.length == 1) {
      final String current = widget.selected.single;
      for (final (String id, ClinVarGroup _, Offset head) in batch.hits) {
        if (id == current && (head - tapped).distance <= touching) {
          final List<String> heads = pile(head);
          final int next = heads.indexOf(current) + 1;
          if (next < heads.length) {
            widget.onSelected(heads[next], (next + 1, heads.length));
          } else {
            widget.onSelected(null, null);
          }
          return;
        }
      }
    }
    final List<String> heads = pile(tapped);
    widget.onSelected(heads.first, (1, heads.length));
  }

  /// The piece under [u], or the nearest one to it: a 42-base UTR is a few
  /// points wide on the whole gene, and a finger near it means it.
  static StripWindow? _nearest<T>(
    List<T> pieces,
    (double, double) Function(T) span,
    double u,
    StripWindow Function(T) window,
  ) {
    T? best;
    double distance = double.infinity;
    for (final T piece in pieces) {
      final (double from, double to) = span(piece);
      final double d = u < from
          ? from - u
          : u > to
          ? u - to
          : 0;
      if (d < distance) {
        best = piece;
        distance = d;
      }
    }
    return best == null ? null : window(best as T);
  }
}

/// A pinch, and only a pinch: accepted the moment a second finger is down,
/// and never for one. A single finger's vertical drag is left to the page and
/// its tap to the marks — a plain scale recognizer would claim a one-finger
/// drag once it passed the pan slop and take the page's scroll with it.
class _PinchGestureRecognizer extends ScaleGestureRecognizer {
  _PinchGestureRecognizer({super.debugOwner});

  @override
  void addAllowedPointer(PointerDownEvent event) {
    super.addAllowedPointer(event);
    if (pointerCount >= 2) {
      resolve(GestureDisposition.accepted);
    }
  }

  @override
  void resolve(GestureDisposition disposition) {
    if (disposition == GestureDisposition.accepted && pointerCount < 2) {
      return;
    }
    super.resolve(disposition);
  }
}

/// A panel's name, and the keys that zoom it.
class _PanelTitle extends StatelessWidget {
  const _PanelTitle({
    required this.panel,
    required this.text,
    required this.zoomable,
    this.onWhole,
    this.onZoomIn,
    this.onZoomOut,
    this.onExpand,
    this.onClose,
  });

  final StripPanel panel;
  final String text;

  /// Whether the keys are drawn at all. At either end of the zoom one is
  /// disabled rather than taken away, so nothing on the row moves.
  final bool zoomable;
  final VoidCallback? onWhole;
  final VoidCallback? onZoomIn;
  final VoidCallback? onZoomOut;
  final VoidCallback? onExpand;
  final VoidCallback? onClose;

  static const double height = 44;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color muted = theme.colorScheme.onSurfaceVariant;
    // Standard density throughout the row: compact takes eight points off
    // every size asked for, which left these keys 36 tall in a 44-point row.
    // Thirty-two wide, the width they have always been drawn at: at forty,
    // three of them cut the zoomed title — the window's residues — short.
    final ButtonStyle key = IconButton.styleFrom(
      minimumSize: const Size(32, 44),
      padding: EdgeInsets.zero,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.standard,
    );
    final String whole = panel == StripPanel.protein
        ? 'the whole protein'
        : 'the whole gene';
    // One height zoomed or not, so the way out never moves the page.
    return SizedBox(
      height: height,
      child: Row(
        children: <Widget>[
          if (onClose != null)
            IconButton(
              key: ValueKey<String>('evidence-close-${panel.name}'),
              onPressed: onClose,
              tooltip: 'Close',
              style: key,
              iconSize: 20,
              icon: const Icon(Icons.close_rounded),
            ),
          Expanded(
            child: Text(
              text,
              key: ValueKey<String>('evidence-title-${panel.name}'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelMedium?.copyWith(
                fontFamily: AppTypography.sansFamily,
                color: muted,
                letterSpacing: 0,
              ),
            ),
          ),
          if (onWhole != null)
            TextButton(
              key: ValueKey<String>('evidence-whole-${panel.name}'),
              onPressed: onWhole,
              style: TextButton.styleFrom(
                minimumSize: const Size(0, 44),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.standard,
              ),
              child: Text('‹ whole', semanticsLabel: 'Show $whole'),
            ),
          if (zoomable) ...<Widget>[
            IconButton(
              key: ValueKey<String>('evidence-zoom-out-${panel.name}'),
              onPressed: onZoomOut,
              tooltip: 'Zoom out',
              style: key,
              iconSize: 20,
              icon: const Icon(Icons.remove_rounded),
            ),
            IconButton(
              key: ValueKey<String>('evidence-zoom-in-${panel.name}'),
              onPressed: onZoomIn,
              tooltip: 'Zoom in',
              style: key,
              iconSize: 20,
              icon: const Icon(Icons.add_rounded),
            ),
          ],
          if (onExpand != null)
            IconButton(
              key: ValueKey<String>('evidence-expand-${panel.name}'),
              onPressed: onExpand,
              tooltip: 'Full screen',
              style: key,
              iconSize: 20,
              icon: const Icon(Icons.fullscreen_rounded),
            ),
        ],
      ),
    );
  }
}

/// The whole protein or gene, drawn thin, with the zoomed panel's window framed
/// on it: where the reader is, and the handle for moving along.
class _WindowBar extends StatelessWidget {
  const _WindowBar({
    required this.panel,
    required this.whole,
    required this.window,
    required this.onMove,
    required this.onDone,
    this.constraint,
    this.exons = const <(double, double)>[],
    super.key,
  });

  final StripPanel panel;
  final StripWindow whole;
  final StripWindow window;
  final ProteinConstraint? constraint;
  final List<(double, double)> exons;

  /// The window as it moves, and when it has stopped.
  final ValueChanged<StripWindow> onMove;
  final VoidCallback onDone;

  static const double height = 32;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final double span = window.$2 - window.$1;
    final double length = whole.$2 - whole.$1;
    StripWindow at(double from) {
      final double start = from.clamp(whole.$1, whole.$2 - span);
      return (start, start + span);
    }

    final String unit = panel == StripPanel.protein ? 'residues' : 'bases';
    String spoken(StripWindow w) =>
        '$unit ${w.$1.floor() + 1}–${w.$2.ceil()} of ${length.round()}';
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints bounds) {
        const double left = _Geometry.gutter;
        final double width = math.max(1, bounds.maxWidth - 8 - left);
        double u(double x) => whole.$1 + (x - left) / width * length;
        return Semantics(
          label: panel == StripPanel.protein
              ? 'Window on the whole protein'
              : 'Window on the whole gene',
          value: spoken(window),
          increasedValue: spoken(at(window.$1 + span / 2)),
          decreasedValue: spoken(at(window.$1 - span / 2)),
          onIncrease: () {
            onMove(at(window.$1 + span / 2));
            onDone();
          },
          onDecrease: () {
            onMove(at(window.$1 - span / 2));
            onDone();
          },
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onHorizontalDragUpdate: (DragUpdateDetails details) =>
                onMove(at(window.$1 + details.delta.dx / width * length)),
            onHorizontalDragEnd: (DragEndDetails details) => onDone(),
            onTapUp: (TapUpDetails details) {
              onMove(at(u(details.localPosition.dx) - span / 2));
              onDone();
            },
            child: CustomPaint(
              size: Size(bounds.maxWidth, height),
              painter: _WindowBarPainter(
                panel: panel,
                whole: whole,
                window: window,
                constraint: constraint,
                exons: exons,
                colors: colors,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _WindowBarPainter extends CustomPainter {
  _WindowBarPainter({
    required this.panel,
    required this.whole,
    required this.window,
    required this.constraint,
    required this.exons,
    required this.colors,
  });

  final StripPanel panel;
  final StripWindow whole;
  final StripWindow window;
  final ProteinConstraint? constraint;
  final List<(double, double)> exons;
  final ColorScheme colors;

  @override
  void paint(Canvas canvas, Size size) {
    const double left = _Geometry.gutter;
    final double right = size.width - 8;
    final double width = math.max(1, right - left);
    final double length = whole.$2 - whole.$1;
    double x(double u) => left + (u - whole.$1) / length * width;
    final double middle = size.height / 2;
    const double thickness = 8;
    final Rect bar = Rect.fromLTRB(
      left,
      middle - thickness / 2,
      right,
      middle + thickness / 2,
    );
    if (panel == StripPanel.protein) {
      final ProteinConstraint? track = constraint;
      final int residues = length.round();
      for (int r = 1; r <= residues; r++) {
        canvas.drawRect(
          Rect.fromLTRB(x(r - 1.0), bar.top, x(r.toDouble()) + 0.5, bar.bottom),
          Paint()
            ..color = track != null && r <= track.positions.length
                ? ConstraintColors.heat(track.positions[r - 1].conservation)
                : colors.surfaceContainerHighest,
        );
      }
    } else {
      canvas.drawLine(
        Offset(left, middle),
        Offset(right, middle),
        Paint()
          ..color = colors.outlineVariant
          ..strokeWidth = 1,
      );
      for (final (double from, double to) in exons) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTRB(
              x(from),
              middle - 3,
              math.max(x(to), x(from) + 1),
              middle + 3,
            ),
            const Radius.circular(1.5),
          ),
          Paint()..color = colors.onSurfaceVariant.withValues(alpha: 0.55),
        );
      }
    }
    // Outside the window, the whole goes quiet; the window itself is framed.
    final double from = x(window.$1);
    final double to = math.max(x(window.$2), from + 4);
    final Paint quiet = Paint()..color = colors.surface.withValues(alpha: 0.6);
    canvas.drawRect(Rect.fromLTRB(left - 1, 0, from, size.height), quiet);
    canvas.drawRect(Rect.fromLTRB(to, 0, right + 1, size.height), quiet);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(from, middle - 8, to, middle + 8),
        const Radius.circular(3),
      ),
      Paint()
        ..color = colors.primary
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(_WindowBarPainter old) =>
      old.window != window ||
      old.whole != whole ||
      old.constraint != constraint ||
      old.colors != colors ||
      !listEquals(old.exons, exons);
}

/// A panel's marks, placed: heads by class as flat point lists, stems as flat
/// line pairs, and each mark's place for a tap to find.
@immutable
final class _MarkBatch {
  const _MarkBatch({
    required this.hits,
    required this.heads,
    required this.stems,
    required this.rings,
    required this.radius,
    required this.halo,
  });

  final List<(String, ClinVarGroup, Offset)> hits;
  final Map<ClinVarGroup, Float32List> heads;
  final Float32List stems;

  /// Where the selected records' heads are.
  final List<Offset> rings;
  final double radius;
  final bool halo;
}

/// A named piece of the gene with records on it, in gene coordinates.
@immutable
final class _Piece {
  const _Piece(this.label, this.span, this.records);
  final String label;
  final (double, double) span;
  final int records;
}

/// Where everything goes in one panel, shared by the painter and the hit test
/// so a tap lands on what is drawn.
final class _Geometry {
  _Geometry(
    this.size, {
    required this.plot,
    required this.ceiling,
    required this.window,
    this.labelScale = 1,
  });

  final Size size;
  final double labelScale;

  /// The AVI area's height.
  final double plot;
  final double ceiling;

  /// The stretch drawn across the panel, in the panel's own coordinates.
  final (double, double) window;

  static const double gutter = 30;

  /// Room above the AVI area for the axis's name: its line, and half the
  /// ceiling's number under it. Twenty-two at the reader's own size, and more
  /// as they turn type up, so the name never sits on the number.
  static double topFor(double labelScale) =>
      math.max(22, 5 + labelSize * 1.5 * labelScale);
  double get top => topFor(labelScale);
  static const double band = 10;

  /// The strip's own labels. It was ten, which with the chemistry key and the
  /// ruler was the smallest type in the app.
  static const double labelSize = 11;

  /// A panel for an AVI area of [plot] points: the axis's name, the area, the
  /// ground, and a row of names under it.
  static double heightFor(double plot, double labelScale) =>
      topFor(labelScale) + plot + 14 + labelSize * labelScale + 6;

  double get left => gutter;
  double get right => size.width - 8;
  double get width => math.max(1, right - left);

  /// Where the ground starts: the ESM band's top, the gene's upper edge.
  double get groundTop => top + plot;
  double get bandBottom => groundTop + band;
  double get geneLine => groundTop + 5;
  double get namesTop => groundTop + 14;

  double x(double u) =>
      left + (u - window.$1) / math.max(1e-6, window.$2 - window.$1) * width;

  double u(double x) => window.$1 + (x - left) / width * (window.$2 - window.$1);

  bool visible(double u) => u >= window.$1 && u <= window.$2;

  double y(double phred) =>
      groundTop - 2 - math.min(phred, ceiling) / ceiling * (groundTop - 2 - top);
}

class _StripPainter extends CustomPainter {
  _StripPainter({
    required this.panel,
    required this.geometry,
    required this.batch,
    required this.constraint,
    required this.proteinLength,
    required this.zoomed,
    required this.exons,
    required this.pieces,
    required this.colors,
    required this.labelScale,
    this.empty,
  });

  final StripPanel panel;
  final _Geometry geometry;
  final _MarkBatch batch;
  final ProteinConstraint? constraint;
  final int proteinLength;
  final bool zoomed;

  /// The gene's exons and named pieces, in the panel's coordinates.
  final List<(double, double)> exons;
  final List<_Piece> pieces;
  final ColorScheme colors;
  final double labelScale;

  /// What the plot says when it has no mark to draw, or null.
  final String? empty;

  void _label(
    Canvas canvas,
    String text,
    Offset at, {
    TextAlign align = TextAlign.left,
    double size = _Geometry.labelSize,
    bool mono = true,
  }) {
    final TextPainter painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: mono ? AppTypography.monoFamily : AppTypography.sansFamily,
          fontSize: size * labelScale,
          color: colors.onSurfaceVariant,
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    final double dx = switch (align) {
      TextAlign.center => at.dx - painter.width / 2,
      TextAlign.right => at.dx - painter.width,
      _ => at.dx,
    };
    painter.paint(canvas, Offset(dx, at.dy));
    painter.dispose();
  }

  double _measure(
    String text, {
    double size = _Geometry.labelSize,
    bool mono = false,
  }) {
    final TextPainter painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: mono ? AppTypography.monoFamily : AppTypography.sansFamily,
          fontSize: size * labelScale,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    final double width = painter.width;
    painter.dispose();
    return width;
  }

  void _notch(Canvas canvas, double x, double y) {
    final Path notch = Path()
      ..moveTo(x, y + 2)
      ..lineTo(x - 3, y + 7)
      ..lineTo(x + 3, y + 7)
      ..close();
    canvas.drawPath(notch, Paint()..color = colors.onSurfaceVariant);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final _Geometry g = geometry;
    final Paint guide = Paint()
      ..color = colors.outlineVariant
      ..strokeWidth = 1;
    final double half = _Geometry.labelSize * labelScale / 2;

    // The AVI axis, the same in both panels: its name at the top of the
    // gutter, the ceiling under it, and the top-1% line, drawn dashed — the
    // key under the strip says what the dashes are, where no mark can sit on
    // the words. The gene panel's floor is zero; the protein's is the ESM
    // band, named below.
    _label(canvas, 'AVI', const Offset(0, 2));
    for (final double value in <double>[
      GeneImpact.highPhred,
      g.ceiling,
      if (panel == StripPanel.dna) 0,
    ]) {
      _label(
        canvas,
        value.toStringAsFixed(0),
        Offset(g.left - 6, g.y(value) - half),
        align: TextAlign.right,
      );
    }
    final double twenty = g.y(GeneImpact.highPhred);
    for (double x = g.left; x < g.right; x += 6) {
      canvas.drawLine(
        Offset(x, twenty),
        Offset(math.min(x + 3, g.right), twenty),
        guide,
      );
    }
    canvas.save();
    canvas.clipRect(Rect.fromLTRB(g.left, 0, g.right + 1, size.height));
    if (panel == StripPanel.protein) {
      _paintProtein(canvas, guide);
    } else {
      _paintGene(canvas, guide);
    }
    canvas.restore();
    if (panel == StripPanel.protein) {
      _label(canvas, 'ESM', Offset(0, g.groundTop));
    }
    if (empty case final String note) {
      _label(
        canvas,
        note,
        Offset(
          (g.left + g.right) / 2,
          g.top + (g.groundTop - g.top) / 2 - half,
        ),
        align: TextAlign.center,
        mono: false,
      );
    }

    // Heads may reach a little past the plot's edge, never into the gutter's
    // numbers.
    canvas.save();
    canvas.clipRect(Rect.fromLTRB(g.left - 4, 0, size.width, size.height));
    _paintMarks(canvas);
    canvas.restore();
  }

  /// The ground: ESM constraint per residue, on the protein page's own ramp,
  /// and the precursor's pieces under it — or, zoomed, the residue numbers.
  void _paintProtein(Canvas canvas, Paint guide) {
    final _Geometry g = geometry;
    final ProteinConstraint? track = constraint;
    final int first = math.max(1, g.window.$1.floor() + 1);
    final int last = math.min(proteinLength, g.window.$2.ceil());
    for (int r = first; r <= last; r++) {
      final double conservation = track != null && r <= track.positions.length
          ? track.positions[r - 1].conservation
          : 0;
      final double from = g.x(r - 1.0);
      canvas.drawRect(
        Rect.fromLTRB(from, g.groundTop, g.x(r.toDouble()) + 0.5, g.bandBottom),
        Paint()
          ..color = track == null
              ? colors.surfaceContainerHighest
              : ConstraintColors.heat(conservation),
      );
    }
    if (track == null) {
      return;
    }
    for (final ConstraintRegion region in track.regions) {
      final double from = g.x(region.start - 1.0);
      canvas.drawLine(
        Offset(from, g.bandBottom),
        Offset(from, g.bandBottom + 4),
        guide,
      );
    }
    if (zoomed) {
      final int step = EvidenceStrip.residueStep(
        g.x(1) - g.x(0),
        math.max(24, _measure('$last', mono: true) + 6),
      );
      for (int n = (first + step - 1) ~/ step * step; n <= last; n += step) {
        final double x = g.x(n - 0.5);
        canvas.drawLine(
          Offset(x, g.bandBottom),
          Offset(x, g.bandBottom + 3),
          guide,
        );
        // A number the panel's edge would cut in half keeps only its tick.
        final double half = _measure('$n', mono: true) / 2;
        if (x - half >= g.left && x + half <= g.right) {
          _label(canvas, '$n', Offset(x, g.namesTop), align: TextAlign.center);
        }
      }
      return;
    }
    // Named where the name fits; a piece too short for a word — a cut site —
    // is a notch.
    for (final ConstraintRegion region in track.regions) {
      final double from = g.x(region.start - 1.0);
      final double to = g.x(region.end.toDouble());
      final double span = to - from;
      final String name = region.label;
      final String? fits = <String>[
        name,
        name.split(' ').first,
        region.short,
      ].where((String s) => s.isNotEmpty && _measure(s) + 4 <= span).firstOrNull;
      if (fits != null) {
        _label(
          canvas,
          fits,
          Offset((from + to) / 2, g.namesTop),
          align: TextAlign.center,
          mono: false,
        );
      } else {
        _notch(canvas, (from + to) / 2, g.bandBottom);
      }
    }
  }

  /// The gene: exons as blocks, introns as a hairline, 5′ on the left, and
  /// under it the pieces that hold records, named where there is room.
  void _paintGene(Canvas canvas, Paint guide) {
    final _Geometry g = geometry;
    canvas.drawLine(
      Offset(g.left, g.geneLine),
      Offset(g.right, g.geneLine),
      guide,
    );
    for (final (double from, double to) in exons) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(
            g.x(from),
            g.geneLine - 3,
            math.max(g.x(to), g.x(from) + 1),
            g.geneLine + 3,
          ),
          const Radius.circular(1.5),
        ),
        Paint()..color = colors.onSurfaceVariant.withValues(alpha: 0.55),
      );
    }
    if (zoomed) {
      return;
    }
    // The pieces with the most records are named first; a name that would
    // run into one already placed gives way to a notch, and a notch that a
    // name already covers is left out.
    final List<_Piece> byRecords = List<_Piece>.of(pieces)
      ..sort((_Piece a, _Piece b) => b.records.compareTo(a.records));
    final List<(double, double)> placed = <(double, double)>[];
    final List<double> unnamed = <double>[];
    for (final _Piece piece in byRecords) {
      final double from = g.x(piece.span.$1);
      final double to = g.x(piece.span.$2);
      final double width = _measure(piece.label);
      final double left = ((from + to) / 2 - width / 2).clamp(
        g.left,
        math.max(g.left, g.right - width),
      );
      final bool clear = placed.every(
        ((double, double) other) =>
            left + width + 6 <= other.$1 || left >= other.$2 + 6,
      );
      if (clear) {
        placed.add((left, left + width));
        _label(
          canvas,
          piece.label,
          Offset(left, g.namesTop),
          mono: false,
        );
      } else {
        unnamed.add((from + to) / 2);
      }
    }
    for (final double x in unnamed) {
      if (placed.every(
        ((double, double) name) => x < name.$1 - 4 || x > name.$2 + 4,
      )) {
        _notch(canvas, x, g.geneLine + 3);
      }
    }
  }

  // Stems first, then the classes from least to most severe, so the records
  // that decide a stretch sit on top of it; a class's halos go down before its
  // heads, so a more severe head is never hidden under a milder one.
  void _paintMarks(Canvas canvas) {
    final _MarkBatch b = batch;
    if (b.stems.isNotEmpty) {
      canvas.drawRawPoints(
        ui.PointMode.lines,
        b.stems,
        Paint()
          ..color = colors.onSurfaceVariant.withValues(alpha: 0.3)
          ..strokeWidth = 1,
      );
    }
    for (final ClinVarGroup group in ClinVarGroup.bySeverity.reversed) {
      final Float32List? points = b.heads[group];
      if (points == null || points.isEmpty) {
        continue;
      }
      if (b.halo) {
        canvas.drawRawPoints(
          ui.PointMode.points,
          points,
          Paint()
            ..color = colors.surface
            ..strokeWidth = 2 * (b.radius + 1.2)
            ..strokeCap = StrokeCap.round,
        );
      }
      if (ClinVarColors.hollow(group)) {
        final Paint ring = Paint()
          ..color = ClinVarColors.of(group)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5;
        for (int i = 0; i + 1 < points.length; i += 2) {
          canvas.drawCircle(
            Offset(points[i], points[i + 1]),
            b.radius - 0.75,
            ring,
          );
        }
      } else {
        canvas.drawRawPoints(
          ui.PointMode.points,
          points,
          Paint()
            ..color = ClinVarColors.of(group)
            ..strokeWidth = 2 * b.radius
            ..strokeCap = StrokeCap.round,
        );
      }
    }
    for (final Offset at in b.rings) {
      canvas.drawCircle(
        at,
        7,
        Paint()
          ..color = colors.onSurface
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }
  }

  @override
  bool shouldRepaint(_StripPainter old) =>
      !identical(old.batch, batch) ||
      old.geometry.size != geometry.size ||
      old.geometry.window != geometry.window ||
      old.geometry.plot != geometry.plot ||
      old.geometry.ceiling != geometry.ceiling ||
      old.constraint != constraint ||
      old.zoomed != zoomed ||
      old.colors != colors ||
      old.labelScale != labelScale ||
      old.empty != empty;
}
