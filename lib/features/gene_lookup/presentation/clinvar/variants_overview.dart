import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../../../core/router/landscape_route.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/entities/gene_clinvar.dart';
import '../../domain/entities/protein_constraint.dart';
import '../../domain/entities/variant_evidence.dart';
import '../anatomy/sequence_scrubber.dart';
import '../constraint/constraint_colors.dart';
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
/// The walk keeps one for as long as it shows a gene, so the list opens again
/// as the reader closed it: the same scroll, the record still open, the same
/// classes, regions and windows. (A record's link no longer closes it — the
/// residue or base opens above it — so this is only for opening it again.)
class VariantsOverviewMemory {
  double offset = 0;
  String? open;

  /// The classes shown, or none for every class.
  Set<ClinVarGroup> classes = const <ClinVarGroup>{};
  Set<String> selected = const <String>{};

  /// The regions the reader closed, by section key.
  Set<String> collapsed = const <String>{};

  /// What each panel of the strip shows, or null for the whole.
  StripWindow? proteinWindow;
  StripWindow? dnaWindow;
}

/// Every ClinVar record of a gene, as one picture and one list.
///
/// The strip shows where the records sit and how each source reads them; the
/// list below it is grouped by the piece of the molecule each record falls in,
/// so the pattern the strip shows is also the order the list reads in. Every
/// piece is open; its heading closes it down to its count, for a reader
/// making their way past stretches they have read, and a mark on the strip
/// opens its own again. A record's row opens its evidence in place, and its
/// links open that residue or base as a page above this one, from which Back
/// returns here exactly as it was.
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
    this.onOpen,
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

  /// Opens a record's residue or base above the list. It completes when that
  /// page is gone, with the records the reader asked for from there — which
  /// the list then opens on — or null. Without it, rows offer no such links.
  final Future<List<String>?> Function(VariantTarget target)? onOpen;

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

  /// Bumped when the tapped mark or a window changes, for a panel open on the
  /// whole screen: its page is built from this state, but the list's own
  /// rebuilds do not reach it.
  final ValueNotifier<int> _drawn = ValueNotifier<int>(0);
  late final List<_Section> _sections = _group(widget.evidence);
  late final Map<ClinVarGroup, int> _counts = <ClinVarGroup, int>{
    for (final ClinVarGroup group in ClinVarGroup.values)
      group: widget.evidence.where((e) => e.variant.group == group).length,
  };
  late final int _unscored = widget.evidence
      .where((VariantEvidence e) => e.avi == null)
      .length;
  late final Map<String, VariantEvidence> _byId = <String, VariantEvidence>{
    for (final VariantEvidence e in widget.evidence) e.variant.id: e,
  };
  late final Map<String, String> _sectionOf = <String, String>{
    for (final _Section s in _sections)
      for (final VariantEvidence e in s.records) e.variant.id: s.key,
  };
  Set<ClinVarGroup> _classes = const <ClinVarGroup>{};
  Set<String> _selected = const <String>{};

  /// Which of the heads drawn over one another at the last tap on the strip
  /// is the selected one, and of how many.
  (int, int)? _cycle;
  String? _open;

  /// Rows still closing. Every closed row is one height, which is what lets
  /// the list place any of thousands without building the rows above it; a
  /// row that is open, or on its way closed, has a place of its own until it
  /// is done.
  final Set<String> _settling = <String>{};
  Set<String> _collapsed = const <String>{};
  StripWindow? _proteinWindow;
  StripWindow? _dnaWindow;

  @override
  void initState() {
    super.initState();
    _classes = Set<ClinVarGroup>.of(_memory.classes);
    _collapsed = Set<String>.of(_memory.collapsed);
    _proteinWindow = _memory.proteinWindow;
    _dnaWindow = _memory.dnaWindow;
    if (widget.focus.isNotEmpty) {
      _focusOn(widget.focus);
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
    _drawn.dispose();
    super.dispose();
  }

  void _rememberOffset() => _memory.offset = _scroll.offset;

  /// Opens the list on [ids]: sent here for particular records, they are what
  /// opens, whatever was open before, and nothing the reader left behind may
  /// hide them.
  void _focusOn(List<String> ids) {
    _selected = ids.toSet();
    _cycle = null;
    _openRow(ids.length == 1 ? ids.first : null);
    _collapsed = Set<String>.of(_collapsed)
      ..removeAll(<String>[for (final String id in ids) ?_sectionOf[id]]);
    _show(ids);
    _unzoomFor(ids);
    _remember();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => unawaited(_reveal(ids.first)),
    );
  }

  /// Opens [id]'s row, or none, and lets the row open before it finish
  /// closing where it is.
  void _openRow(String? id) {
    final String? was = _open;
    _open = id;
    _settling.remove(id);
    if (was != null && was != id && !MediaQuery.disableAnimationsOf(context)) {
      _settling.add(was);
      _watchSettling();
    }
  }

  bool _watching = false;

  /// Looks at the closing rows once the next frame is laid out.
  void _watchSettling() {
    if (!_watching) {
      _watching = true;
      WidgetsBinding.instance.addPostFrameCallback(_settle);
    }
  }

  /// Rows back to a closed row's height, or no longer built, go back among
  /// the closed rows; the rest are looked at again after the next frame.
  ///
  /// By their height rather than their animation's end: an opening cut short
  /// by a closing stops without ever finishing.
  void _settle(Duration _) {
    _watching = false;
    if (!mounted || _settling.isEmpty) {
      return;
    }
    final List<String> done = <String>[
      for (final String id in _settling)
        if (_closedAgain(id)) id,
    ];
    if (done.isNotEmpty) {
      setState(() => _settling.removeAll(done));
    }
    if (_settling.isNotEmpty) {
      _watchSettling();
    }
  }

  bool _closedAgain(String id) {
    final BuildContext? row = _rows[id]?.currentContext;
    final RenderObject? box = row?.findRenderObject();
    return row == null ||
        box is! RenderBox ||
        !box.hasSize ||
        box.size.height <= EvidenceRow.closedExtent(row);
  }

  /// Whether a record's page is open above the list: a second tap on a link
  /// while it opens would open a second one.
  bool _opening = false;

  /// Follows a record's link, and opens on whatever the reader asked for from
  /// the page it opened.
  Future<void> _follow(VariantTarget target) async {
    final Future<List<String>?> Function(VariantTarget)? open = widget.onOpen;
    if (open == null || _opening) {
      return;
    }
    _opening = true;
    final List<String>? focus;
    try {
      focus = await open(target);
    } finally {
      _opening = false;
    }
    if (mounted && focus != null && focus.isNotEmpty) {
      setState(() => _focusOn(focus!));
    }
  }

  void _remember() {
    _memory
      ..open = _open
      ..classes = Set<ClinVarGroup>.of(_classes)
      ..selected = _selected
      ..collapsed = Set<String>.of(_collapsed)
      ..proteinWindow = _proteinWindow
      ..dnaWindow = _dnaWindow;
  }

  /// Adds the classes of [ids] to those shown, where a choice of classes
  /// would hide them: a record the reader was sent to is shown, and the rest
  /// of their choice stands.
  void _show(Iterable<String> ids) {
    if (_classes.isEmpty) {
      return;
    }
    _classes = <ClinVarGroup>{
      ..._classes,
      for (final String id in ids) ?_byId[id]?.variant.group,
    };
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

  /// Where the top of a row that has not been built would be scrolled to: its
  /// section's heading, the closed rows above it at their one height, and
  /// whatever a row open or closing above it adds.
  double? _estimate(String id) {
    final String? key = _sectionOf[id];
    final BuildContext? place = key == null
        ? null
        : _headings[key]?.currentContext;
    final RenderObject? heading = place?.findRenderObject();
    if (place == null || heading is! RenderBox || !heading.attached) {
      return null;
    }
    final _Section section = _sections.firstWhere((_Section s) => s.key == key);
    final List<VariantEvidence> records = _visible(section);
    final int index = records.indexWhere(
      (VariantEvidence e) => e.variant.id == id,
    );
    if (index < 0) {
      return null;
    }
    final double extent = EvidenceRow.closedExtent(place);
    double above = index * extent;
    for (final String loose in <String>{?_open, ..._settling}) {
      final int at = records.indexWhere(
        (VariantEvidence e) => e.variant.id == loose,
      );
      if (at >= 0 && at < index) {
        if (_rows[loose]?.currentContext?.findRenderObject()
            case final RenderBox box when box.hasSize) {
          above += box.size.height - extent;
        }
      }
    }
    final double top = RenderAbstractViewport.of(
      heading,
    ).getOffsetToReveal(heading, 0).offset;
    return top + heading.size.height + above;
  }

  /// A section's records the strip draws: of the classes shown, in the
  /// panels' windows.
  List<VariantEvidence> _visible(_Section section) {
    // Kept for the classes and windows they were read for: every build asks
    // for every section's, and a long gene has thousands of records.
    final Object shown = (_classes, _proteinWindow, _dnaWindow);
    if (_visibleFor != shown) {
      _visibleFor = shown;
      _visibleBySection.clear();
    }
    if (_visibleBySection[section.key] case final List<VariantEvidence> kept) {
      return kept;
    }
    final EvidenceStrip strip = _strip();
    return _visibleBySection[section.key] = <VariantEvidence>[
      for (final VariantEvidence e in section.records)
        if (strip.draws(e)) e,
    ];
  }

  Object? _visibleFor;
  final Map<String, List<VariantEvidence>> _visibleBySection =
      <String, List<VariantEvidence>>{};

  /// The strip as the list draws it, or as a page drawing [only] one panel
  /// on the whole screen, closed by [onClose].
  EvidenceStrip _strip({StripPanel? only, VoidCallback? onClose}) {
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
      classes: _classes,
      selected: _selected,
      proteinWindow: _proteinWindow,
      dnaWindow: _dnaWindow,
      onSelected: _pick,
      onWindow: _zoom,
      only: only,
      onExpand: only == null ? _expand : null,
      onClose: onClose,
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
        _proteinWindow = null;
      } else {
        _dnaWindow = null;
      }
    }
  }

  /// A mark tapped on the strip: named under it, which stays where it is —
  /// the list is not scrolled out from under the reader's finger. Null is the
  /// mark let go, which leaves the list as it is too.
  void _pick(String? id, (int, int)? cycle) {
    setState(() {
      _selected = id == null ? const <String>{} : <String>{id};
      _cycle = cycle;
      _remember();
    });
    _drawn.value++;
  }

  /// Opens [id]'s row and brings it into view.
  void _showInList(String id) {
    setState(() {
      _selected = <String>{id};
      _openRow(id);
      _show(<String>[id]);
      _unzoomFor(<String>[id]);
      _collapsed = Set<String>.of(_collapsed)..remove(_sectionOf[id]);
      _remember();
    });
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => unawaited(_reveal(id)),
    );
  }

  void _toggleRow(String id) => setState(() {
    _openRow(_open == id ? null : id);
    _selected = _open == null ? const <String>{} : <String>{_open!};
    _cycle = null;
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

  void _zoom(StripPanel panel, StripWindow? window) {
    setState(() {
      if (panel == StripPanel.protein) {
        _proteinWindow = window;
      } else {
        _dnaWindow = window;
      }
      _remember();
    });
    _drawn.value++;
  }

  /// Whether a panel is open on the whole screen: a second tap on its key
  /// while it opens would open a second one.
  bool _expanding = false;

  /// Opens [panel] on the whole screen, and once that page has closed, the
  /// record the reader asked to see in the list, if any.
  Future<void> _expand(StripPanel panel) async {
    if (_expanding) {
      return;
    }
    _expanding = true;
    final String? show;
    try {
      show = await Navigator.of(context).push<String>(
        landscapeRoute<String>(
          context,
          (BuildContext context, void Function([String? show]) close) =>
              _page(context, panel, close),
        ),
      );
    } finally {
      _expanding = false;
    }
    if (mounted && show != null) {
      _showInList(show);
    }
  }

  /// [panel] on a page of its own: its keys, its drawing with the screen's
  /// room for it, and the tapped mark named under it. What the reader does
  /// there is this list's own state, so the list shows it once the page has
  /// closed; "Show in list ›" closes it on the record's row.
  Widget _page(
    BuildContext context,
    StripPanel panel,
    void Function([String? show]) close,
  ) {
    final ThemeData base = Theme.of(context);
    return Theme(
      data: base.copyWith(
        textTheme: base.textTheme.apply(fontFamily: AppTypography.sansFamily),
      ),
      child: Scaffold(
        body: SafeArea(
          minimum: const EdgeInsets.fromLTRB(16, 4, 16, 4),
          child: ListenableBuilder(
            listenable: _drawn,
            builder: (BuildContext context, Widget? _) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Expanded(child: _strip(only: panel, onClose: close)),
                const SizedBox(height: 4),
                _Readout(
                  evidence: _selected.length == 1
                      ? _byId[_selected.single]
                      : null,
                  selected: _selected.length,
                  cycle: _cycle,
                  onShow: _selected.length == 1
                      ? () => close(_selected.single)
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Adds [group] to the classes shown, or takes it away; with none left, every
  /// class is shown again.
  void _toggleClass(ClinVarGroup group) => setState(() {
    _classes = _classes.contains(group)
        ? (Set<ClinVarGroup>.of(_classes)..remove(group))
        : <ClinVarGroup>{..._classes, group};
    // A selected record whose class has gone is no longer on the strip.
    _selected = <String>{
      for (final String id in _selected)
        if (_classes.isEmpty || _classes.contains(_byId[id]?.variant.group))
          id,
    };
    if (_selected.isEmpty) {
      _cycle = null;
    }
    _remember();
  });

  /// The sections the strip draws something of.
  List<_Section> get _shown => <_Section>[
    for (final _Section s in _sections)
      if (_visible(s).isNotEmpty) s,
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
                                      selected: _classes.contains(group),
                                      hint: _classes.isEmpty
                                          ? 'Show only this class'
                                          : !_classes.contains(group)
                                          ? 'Also show this class'
                                          : _classes.length == 1
                                          ? 'Show every class'
                                          : 'Stop showing this class',
                                      onTap: () => _toggleClass(group),
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
                              const SizedBox(height: 8),
                              _Readout(
                                evidence: _selected.length == 1
                                    ? _byId[_selected.single]
                                    : null,
                                selected: _selected.length,
                                cycle: _cycle,
                                onShow: _selected.length == 1
                                    ? () => _showInList(_selected.single)
                                    : null,
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'Height: AVI of each allele · band: ESM · colour: '
                                'ClinVar categorisation',
                                key: const ValueKey<String>('variants-key'),
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: muted,
                                  letterSpacing: 0,
                                ),
                              ),
                              const SizedBox(height: 4),
                              _RampKey(unscored: _unscored),
                              if (_proteinWindow != null ||
                                  _dnaWindow != null) ...<Widget>[
                                const SizedBox(height: 12),
                                _WindowNote(
                                  count: shown.fold<int>(
                                    0,
                                    (int n, _Section section) =>
                                        n + _visible(section).length,
                                  ),
                                  onAll: () => setState(() {
                                    _proteinWindow = null;
                                    _dnaWindow = null;
                                    _remember();
                                  }),
                                ),
                              ],
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
    final int total = section.records.length;
    // "of" only while the classes shown or a window leave some out, so the
    // heading never hides how many the region holds.
    final String heading =
        '${section.label}'
        '${switch (section.span) {
          (final int from, final int to) => ' · $from–$to',
          null => '',
        }} · ${n == total ? '${grouped(n)} record${n == 1 ? '' : 's'}' : '${grouped(n)} of ${grouped(total)} records'}';
    // Every row the same way, wherever it is placed.
    Widget row(VariantEvidence e) => KeyedSubtree(
      key: _keyFor(e.variant.id),
      child: EvidenceRow(
        evidence: e,
        column: EvidenceColumn.both,
        expanded: _open == e.variant.id,
        onToggle: () => _toggleRow(e.variant.id),
        onResidue: widget.onOpen == null
            ? null
            : (int number) => unawaited(_follow(ResidueTarget(number))),
        onBase: widget.onOpen == null
            ? null
            : (int position) => unawaited(_follow(BaseTarget(position))),
      ),
    );
    return <Widget>[
      SliverPadding(
        key: ValueKey<String>('variants-heading-${section.key}'),
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
        for (final (int from, int to, bool loose) in _runs(section, records))
          SliverPadding(
            key: ValueKey<String>('variants-rows-${section.key}-$from'),
            padding: side,
            // A row open or closing takes what it needs.
            sliver: loose
                ? SliverToBoxAdapter(child: row(records[from]))
                : _ClosedRows(
                    count: to - from,
                    row: (int index) => row(records[from + index]),
                  ),
          ),
    ];
  }

  /// A section's [records] as runs of closed rows, broken around each row
  /// that is open or still closing: `(from, to, loose)`.
  List<(int, int, bool)> _runs(
    _Section section,
    List<VariantEvidence> records,
  ) {
    final List<int> loose =
        <int>[
            for (final String id in <String>{?_open, ..._settling})
              if (_sectionOf[id] == section.key)
                records.indexWhere((VariantEvidence e) => e.variant.id == id),
          ]
          ..removeWhere((int i) => i < 0)
          ..sort();
    final List<(int, int, bool)> runs = <(int, int, bool)>[];
    int from = 0;
    for (final int at in loose) {
      if (at > from) {
        runs.add((from, at, false));
      }
      runs.add((at, at + 1, true));
      from = at + 1;
    }
    if (from < records.length) {
      runs.add((from, records.length, false));
    }
    return runs;
  }

}

/// A run of closed rows, all one height, so each is placed without building
/// the rows above it; only those near the screen are built, and nothing of a
/// run that is wholly further down the page than that — a list would still
/// build its first row, and a long gene has a hundred regions.
class _ClosedRows extends StatelessWidget {
  const _ClosedRows({required this.count, required this.row});

  final int count;
  final Widget Function(int index) row;

  @override
  Widget build(BuildContext context) {
    final double extent = EvidenceRow.closedExtent(context);
    // One list for every layout, so scrolling does not build its rows again.
    final Widget rows = SliverFixedExtentList.builder(
      itemExtent: extent,
      itemCount: count,
      itemBuilder: (BuildContext context, int index) => row(index),
    );
    return SliverLayoutBuilder(
      builder: (BuildContext context, SliverConstraints constraints) =>
          constraints.scrollOffset == 0 &&
              constraints.remainingCacheExtent == 0
          ? SliverToBoxAdapter(child: SizedBox(height: count * extent))
          : rows,
    );
  }
}

/// A class, its count, and the filter it toggles. The chips are the strip's
/// legend too: the colour is learned here, once, with the word beside it.
class _ClassChip extends StatelessWidget {
  const _ClassChip({
    required this.group,
    required this.count,
    required this.selected,
    required this.hint,
    required this.onTap,
  });

  final ClinVarGroup group;
  final int count;
  final bool selected;

  /// What a tap does, which depends on the other chips: with none chosen it
  /// shows only this class, and after that it adds or takes away.
  final String hint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color colour = ClinVarColors.of(group);
    return Semantics(
      button: true,
      selected: selected,
      label: '${group.label}, $count records',
      hint: hint,
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

/// The mark tapped on the strip, named under it on a card of its own: its
/// change and AVI, what ClinVar calls it, where it is among the heads drawn
/// over one another at that spot, and the way to its row. The strip stays
/// where it is; "Show in list ›" is the way to the record's row, and a second
/// tap on the mark lets it go.
///
/// The card is one height whatever it holds — a record, several, or none — so
/// the page under the strip never moves when a mark is tapped or let go. Its
/// first two lines are the list row's own; on a screen wide enough, the way
/// to the row sits beside them rather than on a line of its own.
class _Readout extends StatelessWidget {
  const _Readout({
    required this.evidence,
    required this.selected,
    required this.cycle,
    required this.onShow,
  });

  final VariantEvidence? evidence;

  /// How many records are selected: one from a tap, several from a sheet's
  /// "All ›".
  final int selected;
  final (int, int)? cycle;
  final VoidCallback? onShow;

  /// The narrowest card the way to the row fits beside the two lines on.
  static const double _wide = 560;

  /// The way to the row's height: a finger's.
  static const double _action = 44;

  /// Where the lines under the first start: past the dot and its gap.
  static const double _indent = 20;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final Color muted = colors.onSurfaceVariant;
    final TextStyle? small = theme.textTheme.bodySmall?.copyWith(color: muted);
    final VariantEvidence? e = evidence;
    return Semantics(
      liveRegion: true,
      container: true,
      // Its room is reserved rather than grown into: type turned up past this
      // point would push the list about every time a mark is tapped.
      child: MediaQuery.withClampedTextScaling(
        maxScaleFactor: 1.3,
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints bounds) {
            final bool wide = bounds.maxWidth >= _wide;
            final (double first, double second) = EvidenceRow.lines(context);
            final Widget body;
            if (e == null) {
              body = Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12 + _indent),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    selected > 1
                        ? '${grouped(selected)} records selected, opened in '
                              'the list'
                        : 'Tap a mark for its record',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: small,
                  ),
                ),
              );
            } else {
              final ClinVarVariant v = e.variant;
              final String change = v.transcriptChange;
              final TextStyle number = TextStyle(
                fontFamily: AppTypography.monoFamily,
                fontSize: 12,
                color: colors.onSurface,
                fontFeatures: const <FontFeature>[
                  FontFeature.tabularFigures(),
                ],
              );
              // What changed, and the height it is drawn at: the row's first
              // line, the number where the row puts its numbers.
              final Widget head = Row(
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.only(right: _indent - 10),
                    child: ClinVarDot(group: v.group, size: 10),
                  ),
                  // One line, whatever the change: one too long for it is
                  // drawn a little smaller rather than broken or cut.
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Text(v.shortLabel, style: theme.textTheme.titleSmall),
                          if (change != v.shortLabel) ...<Widget>[
                            const SizedBox(width: 8),
                            Text(
                              change,
                              style: TextStyle(
                                fontFamily: AppTypography.monoFamily,
                                fontSize: 12,
                                color: muted,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  if (e.avi case final double avi) ...<Widget>[
                    const SizedBox(width: 12),
                    Text.rich(
                      TextSpan(
                        children: <InlineSpan>[
                          TextSpan(
                            text: 'AVI ',
                            style: number.copyWith(color: muted),
                          ),
                          TextSpan(text: avi.toStringAsFixed(1), style: number),
                        ],
                      ),
                      key: const ValueKey<String>('evidence-readout-avi'),
                    ),
                  ],
                ],
              );
              // What ClinVar calls it, whole on a line of its own.
              final Widget classification = ClinVarSourced(
                child: Text(
                  v.classification,
                  key: const ValueKey<String>('evidence-readout-class'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: small,
                ),
              );
              final Widget? here = switch (cycle) {
                (final int i, final int n) when n > 1 => Text(
                  '$i of $n here',
                  key: const ValueKey<String>('evidence-readout-cycle'),
                  style: small,
                ),
                _ => null,
              };
              final Widget show = TextButton(
                key: const ValueKey<String>('evidence-readout-show'),
                onPressed: onShow,
                style: TextButton.styleFrom(
                  minimumSize: const Size(0, _action),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  // Compact would take eight points off the finger's height.
                  visualDensity: VisualDensity.standard,
                ),
                child: const Text('Show in list ›'),
              );
              // The button's own padding is the card's at its right edge; the
              // lines keep the rest of it, so the number above ends where the
              // button's words do.
              body = wide
                  ? Padding(
                      padding: const EdgeInsets.fromLTRB(12, 6, 4, 6),
                      child: Row(
                        children: <Widget>[
                          Expanded(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: <Widget>[
                                SizedBox(height: first, child: head),
                                Padding(
                                  padding: const EdgeInsets.only(left: _indent),
                                  child: SizedBox(
                                    height: second,
                                    child: Row(
                                      children: <Widget>[
                                        Expanded(child: classification),
                                        if (here != null) ...<Widget>[
                                          const SizedBox(width: 12),
                                          here,
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          show,
                        ],
                      ),
                    )
                  : Padding(
                      padding: const EdgeInsets.fromLTRB(12, 10, 4, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: SizedBox(height: first, child: head),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(
                              left: _indent,
                              right: 8,
                            ),
                            child: SizedBox(
                              height: second,
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: classification,
                              ),
                            ),
                          ),
                          SizedBox(
                            height: _action,
                            child: Row(
                              children: <Widget>[
                                const SizedBox(width: _indent),
                                Expanded(
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: here,
                                  ),
                                ),
                                show,
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
            }
            return SizedBox(
              key: const ValueKey<String>('evidence-readout'),
              // Every state is this height: the record's lines and the way
              // to its row, laid out as the width allows.
              height: wide
                  ? math.max(first + second, _action) + 12
                  : 10 + first + second + _action,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: colors.outline, width: 0.5),
                ),
                child: body,
              ),
            );
          },
        ),
      ),
    );
  }
}

/// What the key line names but a reader cannot read off it: the band's ramp,
/// the protein page's own, low to high; what the dashed line is; and, where
/// some records have no AVI score and so no height to be drawn at, how many.
class _RampKey extends StatelessWidget {
  const _RampKey({required this.unscored});

  final int unscored;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color muted = theme.colorScheme.onSurfaceVariant;
    final TextStyle? style = theme.textTheme.labelSmall?.copyWith(
      color: muted,
      letterSpacing: 0,
    );
    return Wrap(
      key: const ValueKey<String>('variants-ramp'),
      spacing: 14,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text('ESM low', style: style),
            Container(
              width: 48,
              height: 4,
              margin: const EdgeInsets.symmetric(horizontal: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(2),
                gradient: const LinearGradient(
                  colors: <Color>[
                    ConstraintColors.tolerant,
                    ConstraintColors.moderate,
                    ConstraintColors.constrained,
                  ],
                ),
              ),
            ),
            Text('high', style: style),
          ],
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            CustomPaint(
              size: const Size(18, 4),
              painter: _Dashes(theme.colorScheme.outlineVariant),
            ),
            const SizedBox(width: 6),
            Text('AVI 20, top 1% genome-wide', style: style),
          ],
        ),
        if (unscored > 0)
          Text(
            '${grouped(unscored)} without AVI, not drawn',
            key: const ValueKey<String>('variants-unscored'),
            style: style,
          ),
      ],
    );
  }
}

/// The strip's dashed line, for its key.
class _Dashes extends CustomPainter {
  const _Dashes(this.colour);

  final Color colour;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = colour
      ..strokeWidth = 1;
    final double y = size.height / 2;
    for (double x = 0; x < size.width; x += 6) {
      canvas.drawLine(
        Offset(x, y),
        Offset(x + 3 < size.width ? x + 3 : size.width, y),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_Dashes old) => old.colour != colour;
}

/// That the list under a zoomed strip holds only what the strip draws, and
/// the way back to all of it.
class _WindowNote extends StatelessWidget {
  const _WindowNote({required this.count, required this.onAll});

  final int count;
  final VoidCallback onAll;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Row(
      key: const ValueKey<String>('variants-window-note'),
      children: <Widget>[
        Expanded(
          child: Text(
            '${grouped(count)} record${count == 1 ? '' : 's'} in view',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        TextButton(
          key: const ValueKey<String>('variants-window-all'),
          onPressed: onAll,
          style: TextButton.styleFrom(
            minimumSize: const Size(0, 44),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.standard,
          ),
          child: const Text('Show all'),
        ),
      ],
    );
  }
}
