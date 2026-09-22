import 'dart:math' as math;

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
/// Every mark keeps its real position whatever is highlighted, so a filter
/// never moves the picture under the reader's eye. A dense stretch overlaps
/// rather than spreading out; tapping a region under it zooms that panel to
/// the region — the same positions at a larger scale — and the list below is
/// the precise path to each record.
class EvidenceStrip extends StatelessWidget {
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
    this.highlight,
    this.selected = const <String>{},
    this.proteinZoom,
    this.dnaZoom,
    this.onZoom,
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
  final ClinVarGroup? highlight;
  final Set<String> selected;
  final ValueChanged<String> onSelected;

  /// What each panel is zoomed to, by [regionKey] and [runKey]; null for the
  /// whole protein or the whole gene.
  final String? proteinZoom;
  final String? dnaZoom;

  /// Asks for a panel's zoom to change; null leaves the strip unzoomable.
  final void Function(StripPanel panel, String? zoom)? onZoom;

  static String regionKey(ConstraintRegion region) =>
      '${region.label}@${region.start}';

  static String runKey(GeneRun run) => '${run.label}@${run.start}';

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

  ConstraintRegion? get _zoomedRegion => proteinZoom == null
      ? null
      : constraint?.regions
            .where((ConstraintRegion r) => regionKey(r) == proteinZoom)
            .firstOrNull;

  GeneRun? get _zoomedRun => dnaZoom == null
      ? null
      : runs.where((GeneRun r) => runKey(r) == dnaZoom).firstOrNull;

  /// Where a base sits along the gene, 5′ to 3′ whichever strand it is on.
  int _index(int position) =>
      reversed ? geneEnd - position : position - geneStart;

  /// The protein runs from 0 to [proteinLength], residue r from r − 1 to r.
  (double, double) get _proteinWindow {
    final double length = proteinLength.toDouble();
    final ConstraintRegion? region = _zoomedRegion;
    if (region == null) {
      return (0, length);
    }
    // Two residues either side, so the cut site between two chains stays in
    // view from both of them.
    return _atLeast(region.start - 3.0, region.end + 2.0, 10, length);
  }

  /// The gene runs from 0 to its length, one unit a base.
  (double, double) get _geneWindow {
    final double length = (geneEnd - geneStart + 1).toDouble();
    final GeneRun? run = _zoomedRun;
    if (run == null) {
      return (0, length);
    }
    final (double from, double to) = _span(run);
    return _atLeast(from, to, 12, length);
  }

  (double, double) _span(GeneRun run) => _spanOf(run.start, run.end);

  (double, double) _spanOf(int start, int end) {
    final int a = _index(start);
    final int b = _index(end);
    return (math.min(a, b).toDouble(), math.max(a, b) + 1.0);
  }

  static (double, double) _atLeast(
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

  double _coordinate(VariantEvidence e) => switch (e.variant.residue) {
    final int residue => residue - 0.5,
    null => _index(e.variant.position) + 0.5,
  };

  /// Whether [e] is in its panel's window: always, unless that panel is
  /// zoomed to a stretch that leaves it out.
  bool shows(VariantEvidence e) {
    final (double from, double to) = e.variant.residue != null
        ? _proteinWindow
        : _geneWindow;
    final double u = _coordinate(e);
    return u >= from && u <= to;
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

  /// The regions a tap on the protein's ground can zoom to: those with a
  /// record in them.
  List<ConstraintRegion> get _zoomableRegions {
    final List<ConstraintRegion> regions =
        constraint?.regions ?? const <ConstraintRegion>[];
    final List<int> counts = _tally<ConstraintRegion>(
      regions,
      (ConstraintRegion r) => (r.start, r.end),
      <int>[
        for (final VariantEvidence e in evidence) ?e.variant.residue,
      ],
    );
    return <ConstraintRegion>[
      for (int i = 0; i < regions.length; i++)
        if (counts[i] > 0) regions[i],
    ];
  }

  /// The pieces of the gene holding a record the DNA panel draws, with how
  /// many they hold.
  List<(GeneRun, int)> get _heldRuns {
    final List<int> counts = _tally<GeneRun>(
      runs,
      (GeneRun r) => (r.start, r.end),
      <int>[
        for (final VariantEvidence e in evidence)
          if (e.variant.residue == null) e.variant.position,
      ],
    );
    return <(GeneRun, int)>[
      for (int i = 0; i < runs.length; i++)
        if (counts[i] > 0) (runs[i], counts[i]),
    ];
  }

  List<GeneRun> get _zoomableRuns => <GeneRun>[
    for (final (GeneRun run, int _) in _heldRuns) run,
  ];

  /// What the records off the protein sit in, in transcript order: `5′ UTR ·
  /// introns · 3′ UTR`.
  String get _dnaKinds {
    final List<VariantEvidence> off = <VariantEvidence>[
      for (final VariantEvidence e in evidence)
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

  String get _proteinTitle => switch (_zoomedRegion) {
    final ConstraintRegion region =>
      'Protein · ${region.label} ${region.start}–${region.end}',
    null => 'Protein · residues 1–$proteinLength',
  };

  // A shortened intron is titled by its own length, as the gene page gives
  // it, not by the stand-in the panel draws.
  String get _dnaTitle => switch (_zoomedRun) {
    final GeneRun run => 'DNA · ${run.label} · ${grouped(run.lengthBp)} bp',
    null => 'DNA · $_dnaKinds',
  };

  @override
  Widget build(BuildContext context) {
    final double ceiling = math.max(
      GeneImpact.barCeiling,
      (evidence.fold<double>(0, (double m, e) => math.max(m, e.avi ?? 0)) / 10)
              .ceil() *
          10.0,
    );
    // One AVI area for both panels, as tall as the screen can spare: 120
    // points on a 740-point phone, never under 96 or over 128.
    final double plot = (MediaQuery.sizeOf(context).height * 0.16).clamp(
      96.0,
      128.0,
    );
    final double labelScale = MediaQuery.textScalerOf(
      context,
    ).scale(1).clamp(1.0, 1.3);
    final bool offProtein = evidence.any(
      (VariantEvidence e) => e.variant.residue == null,
    );
    return Column(
      key: const ValueKey<String>('evidence-strip'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _PanelTitle(
          panel: StripPanel.protein,
          text: _proteinTitle,
          onWhole: _zoomedRegion != null && onZoom != null
              ? () => onZoom!(StripPanel.protein, null)
              : null,
        ),
        _panel(
          context,
          StripPanel.protein,
          plot: plot,
          ceiling: ceiling,
          labelScale: labelScale,
        ),
        if (offProtein) ...<Widget>[
          const SizedBox(height: 8),
          _PanelTitle(
            panel: StripPanel.dna,
            text: _dnaTitle,
            onWhole: _zoomedRun != null && onZoom != null
                ? () => onZoom!(StripPanel.dna, null)
                : null,
          ),
          _panel(
            context,
            StripPanel.dna,
            plot: plot,
            ceiling: ceiling,
            labelScale: labelScale,
          ),
        ],
      ],
    );
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
    final (double from, double to) = protein ? _proteinWindow : _geneWindow;
    final double height = _Geometry.heightFor(plot, labelScale);
    final int count = evidence
        .where((VariantEvidence e) => (e.variant.residue != null) == protein)
        .length;
    final List<(GeneRun, int)> held = protein
        ? const <(GeneRun, int)>[]
        : _heldRuns;
    // What each zoom is called, which a screen reader needs to tell apart: a
    // region by its span, as the panel's title then names it, and a name the
    // gene uses twice — the stretch outside the transcript at either end — by
    // which one it is.
    String called(int i) {
      final String label = held[i].$1.label;
      final int same = held.where(((GeneRun, int) p) => p.$1.label == label).length;
      if (same == 1) {
        return label;
      }
      final int which = held
          .take(i + 1)
          .where(((GeneRun, int) p) => p.$1.label == label)
          .length;
      return '$label ($which of $same)';
    }

    final Map<String, String> zoomable = <String, String>{
      if (protein)
        for (final ConstraintRegion region in _zoomableRegions)
          regionKey(region): '${region.label} ${region.start}–${region.end}'
      else
        for (int i = 0; i < held.length; i++) runKey(held[i].$1): called(i),
    };
    // Everything the painter needs that does not move with the zoom, worked
    // out once per build rather than on every frame of the zoom's motion.
    final List<(double, double)> exonSpans = <(double, double)>[
      if (!protein)
        for (final (int a, int b) in exons) _spanOf(a, b),
    ];
    final List<_Piece> pieces = <_Piece>[
      for (final (GeneRun run, int records) in held)
        _Piece(run.label, _span(run), records),
    ];
    final String? zoom = protein ? proteinZoom : dnaZoom;
    return Semantics(
      container: true,
      label: protein
          ? '$count ClinVar records on the $proteinLength residues of the '
                'protein. Heights are each record’s AVI score, the band under '
                'them is ESM constraint, and colours are ClinVar classes.'
          : '$count ClinVar records outside the protein, on the gene’s '
                '$_dnaKinds. Heights are each record’s AVI score and colours '
                'are ClinVar classes.',
      value: protein ? _proteinTitle : _dnaTitle,
      customSemanticsActions: onZoom == null
          ? null
          : <CustomSemanticsAction, VoidCallback>{
              for (final MapEntry<String, String> entry in zoomable.entries)
                if (entry.key != zoom)
                  CustomSemanticsAction(label: 'Zoom to ${entry.value}'): () =>
                      onZoom!(panel, entry.key),
            },
      excludeSemantics: true,
      child: TweenAnimationBuilder<Offset>(
        tween: Tween<Offset>(end: Offset(from, to)),
        duration: MediaQuery.disableAnimationsOf(context)
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
                );
                final List<_Mark> marks = <_Mark>[
                  for (final VariantEvidence e in evidence)
                    if (e.avi != null &&
                        (e.variant.residue != null) == protein &&
                        geometry.visible(_coordinate(e)))
                      _Mark(
                        id: e.variant.id,
                        group: e.variant.group,
                        at: Offset(
                          geometry.x(_coordinate(e)),
                          geometry.y(e.avi!),
                        ),
                        base: Offset(
                          geometry.x(_coordinate(e)),
                          protein
                              ? geometry.groundTop
                              : geometry.geneLine - 3,
                        ),
                      ),
                ];
                return GestureDetector(
                  key: ValueKey<String>('evidence-strip-${panel.name}'),
                  behavior: HitTestBehavior.opaque,
                  onTapUp: (TapUpDetails details) =>
                      _tap(panel, geometry, marks, details.localPosition),
                  child: CustomPaint(
                    size: Size(bounds.maxWidth, height),
                    painter: _StripPainter(
                      panel: panel,
                      geometry: geometry,
                      marks: marks,
                      source: evidence,
                      constraint: constraint,
                      proteinLength: proteinLength,
                      zoomed: zoom != null,
                      exons: exonSpans,
                      pieces: pieces,
                      highlight: highlight,
                      selected: selected,
                      colors: theme.colorScheme,
                      labelScale: labelScale,
                    ),
                  ),
                );
              },
            ),
      ),
    );
  }

  void _tap(
    StripPanel panel,
    _Geometry geometry,
    List<_Mark> marks,
    Offset at,
  ) {
    final List<_Mark> near = <_Mark>[
      for (final _Mark m in marks)
        if ((highlight == null || m.group == highlight) &&
            (m.at - at).distance <= 18)
          m,
    ]..sort(
        (_Mark a, _Mark b) =>
            (a.at - at).distance.compareTo((b.at - at).distance),
      );
    // The ground zooms: to the piece under the finger, or back out again, so
    // the gesture is its own undo. A head resting on the ground — an AVI of
    // zero — is still the head's to answer when the finger is on it.
    if (at.dy >= geometry.groundTop - 2 &&
        (near.isEmpty || (near.first.at - at).distance > 8)) {
      final void Function(StripPanel, String?)? zoom = onZoom;
      if (zoom == null) {
        return;
      }
      if ((panel == StripPanel.protein ? proteinZoom : dnaZoom) != null) {
        zoom(panel, null);
        return;
      }
      final double u = geometry.u(at.dx);
      final String? key = panel == StripPanel.protein
          ? _nearest<ConstraintRegion>(
              _zoomableRegions,
              (ConstraintRegion r) => (r.start - 1.0, r.end.toDouble()),
              u,
              regionKey,
            )
          : _nearest<GeneRun>(_zoomableRuns, _span, u, runKey);
      if (key != null) {
        zoom(panel, key);
      }
      return;
    }
    if (near.isEmpty) {
      return;
    }
    // Coincident marks cycle, so a second tap in the same place moves on to
    // the next record there rather than reselecting the first.
    final int current = near.indexWhere((_Mark m) => selected.contains(m.id));
    onSelected(near[(current + 1) % near.length].id);
  }

  /// The piece under [u], or the nearest one to it: a 42-base UTR is a few
  /// points wide on the whole gene, and a finger near it means it.
  static String? _nearest<T>(
    List<T> pieces,
    (double, double) Function(T) span,
    double u,
    String Function(T) key,
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
    return best == null ? null : key(best as T);
  }
}

/// A panel's name, and the way back out of its zoom.
class _PanelTitle extends StatelessWidget {
  const _PanelTitle({required this.panel, required this.text, this.onWhole});

  final StripPanel panel;
  final String text;
  final VoidCallback? onWhole;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color muted = theme.colorScheme.onSurfaceVariant;
    // One height zoomed or not, so the way out never moves the page.
    return SizedBox(
      height: 36,
      child: Row(
        children: <Widget>[
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
                minimumSize: const Size(0, 36),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              ),
              child: Text(
                '‹ whole',
                semanticsLabel: panel == StripPanel.protein
                    ? 'Show the whole protein'
                    : 'Show the whole gene',
              ),
            ),
        ],
      ),
    );
  }
}

@immutable
final class _Mark {
  const _Mark({
    required this.id,
    required this.group,
    required this.at,
    required this.base,
  });
  final String id;
  final ClinVarGroup group;

  /// The head.
  final Offset at;

  /// Where the stem meets the ground.
  final Offset base;
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
  });

  final Size size;

  /// The AVI area's height.
  final double plot;
  final double ceiling;

  /// The stretch drawn across the panel, in the panel's own coordinates.
  final (double, double) window;

  static const double gutter = 30;
  static const double top = 8;
  static const double band = 10;

  /// A panel for an AVI area of [plot] points: the area, the ground, and a row
  /// of names under it.
  static double heightFor(double plot, double labelScale) =>
      top + plot + 14 + 10 * labelScale + 6;

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
    required this.marks,
    required this.source,
    required this.constraint,
    required this.proteinLength,
    required this.zoomed,
    required this.exons,
    required this.pieces,
    required this.highlight,
    required this.selected,
    required this.colors,
    required this.labelScale,
  });

  final StripPanel panel;
  final _Geometry geometry;
  final List<_Mark> marks;

  /// The records [marks] were placed from. The marks are a new list on every
  /// build, but the same records under the same geometry are the same marks,
  /// so this is what a repaint is decided on.
  final List<VariantEvidence> source;
  final ProteinConstraint? constraint;
  final int proteinLength;
  final bool zoomed;

  /// The gene's exons and named pieces, in the panel's coordinates.
  final List<(double, double)> exons;
  final List<_Piece> pieces;
  final ClinVarGroup? highlight;
  final Set<String> selected;
  final ColorScheme colors;
  final double labelScale;

  void _label(
    Canvas canvas,
    String text,
    Offset at, {
    TextAlign align = TextAlign.left,
    double size = 10,
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

  double _measure(String text, {double size = 10, bool mono = false}) {
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

    // The AVI axis, the same in both panels: the top-1% line, labelled, and
    // its ceiling. The axis is named at the top of the gutter, under its
    // ceiling's number.
    _label(canvas, 'AVI', const Offset(0, _Geometry.top + 12));
    for (final double value in <double>[GeneImpact.highPhred, g.ceiling]) {
      _label(
        canvas,
        value.toStringAsFixed(0),
        Offset(g.left - 6, g.y(value) - 5),
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

  // Context first, faint and hollow, so a highlighted mark is never hidden
  // under one that is not; then the rest from least to most severe, so the
  // records that decide a stretch sit on top of it.
  void _paintMarks(Canvas canvas) {
    final Paint stem = Paint()
      ..color = colors.onSurfaceVariant.withValues(alpha: 0.3)
      ..strokeWidth = 1;
    final List<_Mark> ordered = List<_Mark>.of(marks)
      ..sort(
        (_Mark a, _Mark b) => ClinVarGroup.bySeverity
            .indexOf(b.group)
            .compareTo(ClinVarGroup.bySeverity.indexOf(a.group)),
      );
    for (final _Mark m in ordered) {
      if (highlight != null && m.group != highlight) {
        canvas.drawCircle(
          m.at,
          2.5,
          Paint()
            ..color = colors.onSurfaceVariant.withValues(alpha: 0.35)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1,
        );
      }
    }
    for (final _Mark m in ordered) {
      if (highlight != null && m.group != highlight) {
        continue;
      }
      canvas.drawLine(m.base, m.at, stem);
    }
    for (final _Mark m in ordered) {
      if (highlight != null && m.group != highlight) {
        continue;
      }
      ClinVarColors.paintMark(canvas, m.at, 3.4, m.group, halo: colors.surface);
    }
    for (final _Mark m in marks) {
      if (selected.contains(m.id)) {
        canvas.drawCircle(
          m.at,
          7,
          Paint()
            ..color = colors.onSurface
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_StripPainter old) =>
      old.geometry.size != geometry.size ||
      old.geometry.window != geometry.window ||
      old.geometry.plot != geometry.plot ||
      old.geometry.ceiling != geometry.ceiling ||
      !identical(old.source, source) ||
      old.constraint != constraint ||
      old.zoomed != zoomed ||
      old.highlight != highlight ||
      old.selected != selected ||
      old.colors != colors ||
      old.labelScale != labelScale;
}
