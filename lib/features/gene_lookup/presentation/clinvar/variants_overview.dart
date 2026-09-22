import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../../../core/theme/app_typography.dart';
import '../../domain/entities/gene_clinvar.dart';
import '../../domain/entities/protein_constraint.dart';
import '../../domain/entities/variant_evidence.dart';
import '../anatomy/sequence_scrubber.dart';
import '../format.dart';
import 'clinvar_colors.dart';
import 'evidence_row.dart';
import 'evidence_sections.dart';
import 'evidence_strip.dart';
import 'sources_note.dart';

/// Where a record's link asks the walk to go.
sealed class VariantTarget {
  const VariantTarget();
}

/// A residue on the protein page, by precursor number.
final class ResidueTarget extends VariantTarget {
  const ResidueTarget(this.number);
  final int number;
}

/// A base of the gene, by record position.
final class BaseTarget extends VariantTarget {
  const BaseTarget(this.position);
  final int position;
}

/// What the overview was showing when it last closed.
///
/// The walk keeps one for as long as it shows a gene, so a reader sent to a
/// residue by a record's link comes back to the list as they left it: the
/// same scroll, the record still open, the same filter, regions and zoom.
class VariantsOverviewMemory {
  double offset = 0;
  String? open;
  ClinVarGroup? filter;
  Set<String> selected = const <String>{};

  /// The regions the reader closed, by section key.
  Set<String> collapsed = const <String>{};
  String? proteinZoom;
  String? dnaZoom;
}

/// Every ClinVar record of a gene, as one picture and one list.
///
/// The strip shows where the records sit and how each source reads them; the
/// list below it is grouped by the piece of the molecule each record falls in,
/// so the pattern the strip shows is also the order the list reads in. Every
/// piece is open; its heading closes it down to its count, for a reader
/// making their way past stretches they have read, and a mark on the strip
/// opens its own again. A record's row opens its evidence in place, and its
/// links send the walk to that residue or base, from where Back returns here.
///
/// Coverage and what the sources are live here, at the foot, and in the About
/// sheet — not in the sheets, which only speak for their own position.
class VariantsOverview extends StatefulWidget {
  const VariantsOverview({
    required this.snapshot,
    required this.evidence,
    required this.exons,
    this.runs = const <GeneRun>[],
    this.constraint,
    this.reversed = false,
    this.focus = const <String>[],
    this.memory,
    super.key,
  });

  final GeneClinVar snapshot;
  final List<VariantEvidence> evidence;

  /// The drawn gene's exons, in record positions, for the DNA strip.
  final List<(int, int)> exons;

  /// The gene's named pieces, which the DNA strip names and zooms to.
  final List<GeneRun> runs;
  final ProteinConstraint? constraint;
  final bool reversed;

  /// Records to open the overview on — the ones at the place the reader came
  /// from.
  final List<String> focus;

  /// Where the overview was left last time, which it returns to and keeps up
  /// to date. Without one it starts fresh.
  final VariantsOverviewMemory? memory;

  @override
  State<VariantsOverview> createState() => _VariantsOverviewState();
}

@immutable
final class _Section {
  const _Section(this.key, this.label, this.protein, this.span, this.records);

  /// What the section is remembered by: its name and where it starts, since a
  /// precursor can carry two pieces with one name.
  final String key;
  final String label;
  final bool protein;

  /// The precursor's own span for a protein region, e.g. `25–54`.
  final (int, int)? span;
  final List<VariantEvidence> records;
}

class _VariantsOverviewState extends State<VariantsOverview> {
  late final VariantsOverviewMemory _memory =
      widget.memory ?? VariantsOverviewMemory();
  late final ScrollController _scroll = ScrollController(
    initialScrollOffset: widget.focus.isEmpty ? _memory.offset : 0,
  );
  final Map<String, GlobalKey> _rows = <String, GlobalKey>{};

  /// Each section's heading, which is always built — the rows under it are
  /// built only near the screen — and so is where a row far down the list is
  /// measured from.
  final Map<String, GlobalKey> _headings = <String, GlobalKey>{};

  /// Bumped whenever the page's length changes without it being scrolled — a
  /// region closing, a record opening — so the thumb is redrawn for it. Only
  /// the thumb listens; the list itself has nothing new to build.
  final ValueNotifier<int> _metrics = ValueNotifier<int>(0);
  late final List<_Section> _sections = _group(widget.evidence);
  late final Map<ClinVarGroup, int> _counts = <ClinVarGroup, int>{
    for (final ClinVarGroup group in ClinVarGroup.values)
      group: widget.evidence.where((e) => e.variant.group == group).length,
  };
  late final Map<String, VariantEvidence> _byId = <String, VariantEvidence>{
    for (final VariantEvidence e in widget.evidence) e.variant.id: e,
  };
  late final Map<String, String> _sectionOf = <String, String>{
    for (final _Section s in _sections)
      for (final VariantEvidence e in s.records) e.variant.id: s.key,
  };
  ClinVarGroup? _filter;
  Set<String> _selected = const <String>{};
  String? _open;
  Set<String> _collapsed = const <String>{};
  String? _proteinZoom;
  String? _dnaZoom;

  @override
  void initState() {
    super.initState();
    _filter = _memory.filter;
    _collapsed = Set<String>.of(_memory.collapsed);
    _proteinZoom = _memory.proteinZoom;
    _dnaZoom = _memory.dnaZoom;
    if (widget.focus.isNotEmpty) {
      // Sent here for particular records: they are what opens, whatever was
      // open before, and nothing the reader left behind may hide them.
      _selected = widget.focus.toSet();
      _open = widget.focus.length == 1 ? widget.focus.first : null;
      _collapsed = Set<String>.of(_collapsed)
        ..removeAll(<String>[for (final String id in widget.focus) ?_sectionOf[id]]);
      if (_filter != null &&
          widget.focus.any((String id) => _byId[id]?.variant.group != _filter)) {
        _filter = null;
      }
      _unzoomFor(widget.focus);
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => unawaited(_reveal(widget.focus.first)),
      );
    } else {
      _selected = _memory.selected;
      _open = _memory.open;
      // The page is laid out as it was left, so the offset lands on the same
      // place; clamped in case it no longer exists.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted &&
            _scroll.hasClients &&
            _scroll.offset > _scroll.position.maxScrollExtent) {
          _scroll.jumpTo(_scroll.position.maxScrollExtent);
        }
      });
    }
    _remember();
    _scroll.addListener(_rememberOffset);
  }

  @override
  void dispose() {
    _scroll.removeListener(_rememberOffset);
    _scroll.dispose();
    _metrics.dispose();
    super.dispose();
  }

  void _rememberOffset() => _memory.offset = _scroll.offset;

  void _remember() {
    _memory
      ..open = _open
      ..filter = _filter
      ..selected = _selected
      ..collapsed = Set<String>.of(_collapsed)
      ..proteinZoom = _proteinZoom
      ..dnaZoom = _dnaZoom;
  }

  /// Protein regions in precursor order, then the gene's other pieces in
  /// transcript order: the order the strip draws them in, top to bottom.
  static List<_Section> _group(List<VariantEvidence> evidence) {
    // A region is keyed by where it starts as well as what it is called: a
    // precursor can carry two pieces with one name, and they are two sections.
    final Map<String, List<VariantEvidence>> byRegion =
        <String, List<VariantEvidence>>{};
    for (final VariantEvidence e in evidence) {
      (byRegion['${e.section}@${e.residue?.region.start ?? ''}'] ??=
              <VariantEvidence>[])
          .add(e);
    }
    final List<_Section> sections = <_Section>[
      for (final MapEntry<String, List<VariantEvidence>> entry
          in byRegion.entries)
        _Section(
          entry.key,
          entry.value.first.section,
          entry.value.first.protein,
          switch (entry.value.first.residue?.region) {
            final ConstraintRegion region => (region.start, region.end),
            null => null,
          },
          entry.value..sort(
            (VariantEvidence a, VariantEvidence b) => a.order != b.order
                ? a.order.compareTo(b.order)
                : a.variant.position.compareTo(b.variant.position),
          ),
        ),
    ];
    int first(_Section s) => s.records.first.order;
    return sections..sort(
      (_Section a, _Section b) => a.protein != b.protein
          ? (a.protein ? -1 : 1)
          : first(a).compareTo(first(b)),
    );
  }

  GlobalKey _keyFor(String id) => _rows[id] ??= GlobalKey();

  /// Brings a record's row into view.
  ///
  /// The list builds only the rows near the screen, so one far down a long
  /// gene's list may not exist yet. The scroll then jumps to where it should
  /// be — its section heading's place, plus the rows above it at the height of
  /// the rows laid out — and looks again once that frame is built.
  Future<void> _reveal(String id) async {
    for (int attempt = 0; attempt < 5; attempt++) {
      if (!mounted) {
        return;
      }
      final BuildContext? row = _rows[id]?.currentContext;
      if (row != null && row.mounted) {
        return Scrollable.ensureVisible(
          row,
          alignment: 0.25,
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
        );
      }
      final double? estimate = _estimate(id);
      if (estimate == null || !_scroll.hasClients) {
        return;
      }
      _scroll.jumpTo(
        estimate.clamp(0.0, _scroll.position.maxScrollExtent),
      );
      await WidgetsBinding.instance.endOfFrame;
    }
  }

  /// Where the top of a row that has not been built would be scrolled to.
  double? _estimate(String id) {
    final String? key = _sectionOf[id];
    final RenderObject? heading = key == null
        ? null
        : _headings[key]?.currentContext?.findRenderObject();
    if (heading is! RenderBox || !heading.attached) {
      return null;
    }
    final _Section section = _sections.firstWhere((_Section s) => s.key == key);
    final int index = _visible(section).indexWhere(
      (VariantEvidence e) => e.variant.id == id,
    );
    if (index < 0) {
      return null;
    }
    final double top = RenderAbstractViewport.of(
      heading,
    ).getOffsetToReveal(heading, 0).offset;
    return top + heading.size.height + index * _rowExtent();
  }

  /// The height of a closed row, read off the ones laid out.
  double _rowExtent() {
    final List<double> heights = <double>[
      for (final MapEntry<String, GlobalKey> entry in _rows.entries)
        if (entry.key != _open)
          if (entry.value.currentContext?.findRenderObject()
              case final RenderBox box when box.hasSize)
            box.size.height,
    ];
    return heights.isEmpty
        ? 56
        : heights.reduce((double a, double b) => a + b) / heights.length;
  }

  /// A section's records the filter leaves in.
  List<VariantEvidence> _visible(_Section section) => <VariantEvidence>[
    for (final VariantEvidence e in section.records)
      if (_filter == null || e.variant.group == _filter) e,
  ];

  EvidenceStrip _strip() {
    final GeneClinVar data = widget.snapshot;
    return EvidenceStrip(
      evidence: widget.evidence,
      proteinLength: data.proteinSequence.length,
      geneStart: data.start,
      geneEnd: data.start + data.sequence.length - 1,
      exons: widget.exons,
      runs: widget.runs,
      reversed: widget.reversed,
      constraint: widget.constraint,
      highlight: _filter,
      selected: _selected,
      proteinZoom: _proteinZoom,
      dnaZoom: _dnaZoom,
      onSelected: _pick,
      onZoom: _zoom,
    );
  }

  /// Zooms out whichever panel is zoomed away from one of [ids], so a
  /// selected record's ring is always on screen.
  void _unzoomFor(Iterable<String> ids) {
    final EvidenceStrip strip = _strip();
    for (final String id in ids) {
      final VariantEvidence? e = _byId[id];
      if (e == null || strip.shows(e)) {
        continue;
      }
      if (e.variant.residue != null) {
        _proteinZoom = null;
      } else {
        _dnaZoom = null;
      }
    }
  }

  void _pick(String id) {
    setState(() {
      _selected = <String>{id};
      _open = id;
      final ClinVarGroup group = _byId[id]!.variant.group;
      if (_filter != null && _filter != group) {
        _filter = null;
      }
      _collapsed = Set<String>.of(_collapsed)..remove(_sectionOf[id]);
      _remember();
    });
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => unawaited(_reveal(id)),
    );
  }

  void _toggleRow(String id) => setState(() {
    _open = _open == id ? null : id;
    _selected = _open == null ? const <String>{} : <String>{_open!};
    if (_open case final String open) {
      _unzoomFor(<String>[open]);
    }
    _remember();
  });

  void _toggleSection(String key) => setState(() {
    _collapsed = _collapsed.contains(key)
        ? (Set<String>.of(_collapsed)..remove(key))
        : <String>{..._collapsed, key};
    _remember();
  });

  void _zoom(StripPanel panel, String? zoom) => setState(() {
    if (panel == StripPanel.protein) {
      _proteinZoom = zoom;
    } else {
      _dnaZoom = zoom;
    }
    _remember();
  });

  /// The sections the filter leaves something in.
  List<_Section> get _shown => <_Section>[
    for (final _Section s in _sections)
      if (_filter == null ||
          s.records.any((VariantEvidence e) => e.variant.group == _filter))
        s,
  ];

  @override
  Widget build(BuildContext context) {
    final ThemeData base = Theme.of(context);
    final ThemeData theme = base.copyWith(
      textTheme: base.textTheme.apply(fontFamily: AppTypography.sansFamily),
    );
    final Color muted = theme.colorScheme.onSurfaceVariant;
    final GeneClinVar data = widget.snapshot;
    final List<_Section> shown = _shown;
    // The side margins every block of the page shares.
    const EdgeInsets side = EdgeInsets.symmetric(horizontal: 16);
    return Theme(
      data: theme,
      child: Scaffold(
        appBar: AppBar(
          title: Text('${data.gene} · ClinVar'),
          leading: CloseButton(onPressed: () => Navigator.of(context).pop()),
        ),
        body: SafeArea(
          child: Stack(
            children: <Widget>[
              // A region closing or a record opening changes how long the page
              // is without scrolling it; the thumb is redrawn for the new
              // length.
              NotificationListener<ScrollMetricsNotification>(
                onNotification: (_) {
                  _metrics.value++;
                  return false;
                },
                // Slivers, so that a gene with thousands of records builds
                // only the rows near the screen: the headings, the strip and
                // the foot are always there, the rows under each heading are
                // built as they come into view.
                child: CustomScrollView(
                  key: const ValueKey<String>('variants-overview-scroll'),
                  controller: _scroll,
                  slivers: <Widget>[
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                      sliver: SliverToBoxAdapter(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            Text(
                              '${grouped(widget.evidence.length)} single-base records · '
                              'snapshot ${data.snapshotDate}',
                              key: const ValueKey<String>('variants-headline'),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: muted,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: <Widget>[
                                for (final ClinVarGroup group in ClinVarGroup.values)
                                  if ((_counts[group] ?? 0) > 0)
                                    _ClassChip(
                                      group: group,
                                      count: _counts[group]!,
                                      selected: _filter == group,
                                      onTap: () => setState(() {
                                        _filter = _filter == group ? null : group;
                                        _remember();
                                      }),
                                    ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            if (widget.evidence.isEmpty)
                              Text(
                                'No mapped single-base record in this snapshot.',
                                style: theme.textTheme.bodySmall,
                              )
                            else ...<Widget>[
                              _strip(),
                              const SizedBox(height: 6),
                              Text(
                                'Height: AVI of each allele · band: ESM · colour: '
                                'ClinVar categorisation',
                                key: const ValueKey<String>('variants-key'),
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: muted,
                                  letterSpacing: 0,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    for (final _Section section in shown)
                      ..._section(context, theme, section, side),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                      sliver: SliverToBoxAdapter(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            const SizedBox(height: 8),
                            Divider(
                              height: 24,
                              color: theme.colorScheme.outlineVariant,
                            ),
                            Text('Coverage', style: theme.textTheme.titleSmall),
                            const SizedBox(height: 4),
                            Text(
                              '${grouped(data.searchedRecords)} records found for '
                              '${data.gene} · ${grouped(data.variants.length)} mapped to a '
                              'single base of the drawn gene',
                              key: const ValueKey<String>('variants-coverage'),
                              style: theme.textTheme.bodySmall,
                            ),
                            for (final MapEntry<String, int> entry
                                in data.excluded.entries)
                              if (entry.value > 0)
                                Text(
                                  '${grouped(entry.value)} excluded · ${_exclusion(entry.key)}',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: muted,
                                  ),
                                ),
                            const SizedBox(height: 16),
                            Text(
                              'About these sources',
                              style: theme.textTheme.titleSmall,
                            ),
                            const SizedBox(height: 4),
                            SourcesNote(snapshotDate: data.snapshotDate),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // A thumb for a page two screens long or more, where finding a
              // record by hand is slow: just the thumb, with no ticks along
              // its track and no bubble beside it.
              Positioned(
                top: 0,
                bottom: 0,
                right: 0,
                width: SequenceScrubber.width,
                child: ValueListenableBuilder<int>(
                  valueListenable: _metrics,
                  builder: (BuildContext context, int _, Widget? _) =>
                      SequenceScrubber(controller: _scroll, minScreens: 2),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// A section's heading, and its rows while it is open.
  List<Widget> _section(
    BuildContext context,
    ThemeData theme,
    _Section section,
    EdgeInsets side,
  ) {
    final List<VariantEvidence> records = _visible(section);
    final int n = records.length;
    final bool open = !_collapsed.contains(section.key);
    final String heading =
        '${section.label}'
        '${switch (section.span) {
          (final int from, final int to) => ' · $from–$to',
          null => '',
        }} · ${grouped(n)} record${n == 1 ? '' : 's'}';
    return <Widget>[
      SliverPadding(
        padding: side,
        sliver: SliverToBoxAdapter(
          child: Padding(
            key: _headings[section.key] ??= GlobalKey(),
            padding: const EdgeInsets.only(top: 10),
            child: Semantics(
              button: true,
              expanded: open,
              label: heading,
              excludeSemantics: true,
              child: InkWell(
                key: ValueKey<String>('variants-section-toggle-${section.key}'),
                onTap: () => _toggleSection(section.key),
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          heading,
                          key: ValueKey<String>('variants-section-${section.label}'),
                          style: theme.textTheme.titleSmall,
                        ),
                      ),
                      AnimatedRotation(
                        turns: open ? 0.5 : 0,
                        duration: MediaQuery.disableAnimationsOf(context)
                            ? Duration.zero
                            : const Duration(milliseconds: 180),
                        child: Icon(
                          Icons.expand_more_rounded,
                          size: 20,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      if (open)
        SliverPadding(
          padding: side,
          sliver: SliverList.builder(
            itemCount: records.length,
            itemBuilder: (BuildContext context, int index) {
              final VariantEvidence e = records[index];
              return KeyedSubtree(
                key: _keyFor(e.variant.id),
                child: EvidenceRow(
                  evidence: e,
                  column: EvidenceColumn.both,
                  expanded: _open == e.variant.id,
                  onToggle: () => _toggleRow(e.variant.id),
                  onResidue: (int number) =>
                      Navigator.of(context).pop(ResidueTarget(number)),
                  onBase: (int position) =>
                      Navigator.of(context).pop(BaseTarget(position)),
                ),
              );
            },
          ),
        ),
    ];
  }
}

/// A class, its count, and the filter it toggles. The chips are the strip's
/// legend too: the colour is learned here, once, with the word beside it.
class _ClassChip extends StatelessWidget {
  const _ClassChip({
    required this.group,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final ClinVarGroup group;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color colour = ClinVarColors.of(group);
    return Semantics(
      button: true,
      selected: selected,
      label: '${group.label}, $count records',
      hint: selected ? 'Show all classes' : 'Highlight this class',
      excludeSemantics: true,
      child: Material(
        color: selected ? colour.withValues(alpha: 0.12) : Colors.transparent,
        shape: StadiumBorder(
          side: BorderSide(
            color: selected
                ? colour.withValues(alpha: 0.8)
                : theme.colorScheme.outlineVariant,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: ValueKey<String>('variants-chip-${group.name}'),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 36),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  ClinVarDot(group: group, size: 9),
                  const SizedBox(width: 6),
                  Text(group.short, style: theme.textTheme.labelLarge),
                  const SizedBox(width: 6),
                  Text(
                    grouped(count),
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontFeatures: const <FontFeature>[
                        FontFeature.tabularFigures(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String _exclusion(String reason) => switch (reason) {
  'no_unique_GRCh38_location' => 'no unique GRCh38 location',
  'not_a_single_base_substitution' => 'other variant types',
  'outside_drawn_gene' => 'outside the drawn gene',
  'intron_not_drawn' => 'intron sequence not drawn',
  'reference_mismatch' => 'different reference base',
  'no_germline_classification' => 'no germline classification',
  'not_current' => 'superseded records',
  'not_a_simple_allele_of_gene' => 'complex records or another gene',
  _ => reason.replaceAll('_', ' '),
};
