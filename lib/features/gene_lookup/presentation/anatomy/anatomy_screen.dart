import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/biology/amino_acids.dart';
import '../../../../core/network/track_source.dart';
import '../../../../core/router/rise_route.dart';
import '../../../../core/router/walk_route.dart';
import '../../../../core/theme/anatomy_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/entities/gene_clinvar.dart';
import '../../domain/entities/gene_impact.dart';
import '../../domain/entities/gene_record.dart';
import '../../domain/entities/protein_constraint.dart';
import '../../domain/entities/protein_target.dart';
import '../../domain/entities/variant_evidence.dart';
import '../clinvar/clinvar_block.dart';
import '../clinvar/clinvar_colors.dart';
import '../clinvar/evidence_row.dart';
import '../clinvar/evidence_sections.dart';
import '../clinvar/variants_overview.dart';
import '../constraint/constraint_panel.dart';
import '../constraint/constraint_toolbar.dart';
import '../format.dart';
import '../inspector/coding_evidence.dart';
import '../inspector/impact_panel.dart';
import '../inspector/inspector_sheet.dart';
import '../structure/structure_view.dart';
import 'anatomy_address.dart';
import 'anatomy_canvas.dart';
import 'anatomy_fasta.dart';
import 'anatomy_layout.dart';
import 'anatomy_ruler.dart';
import 'anatomy_scene.dart';
import 'anatomy_selection.dart';
import 'anatomy_selection_canvas.dart';
import 'anatomy_stages.dart';
import 'anatomy_tracer.dart';
import 'record_sheet.dart';
import 'sequence_scrubber.dart';
import 'stage_bar.dart';

/// One grid of squares, drawn as whatever the stage is actually about.
///
/// Every annotation layer of a gene overlaps every other — in INS a single base
/// of exon 2 is at once 5' UTR, coding sequence, signal peptide and B chain — so
/// no arrangement can draw them all side by side and stay honest. Drawing one
/// layer at a time dissolves that, and teaches containment by subtraction: the
/// introns fall away, the exons close ranks, and the reader *sees* that the
/// exons were a subset all along. **One layer, never two**, is the rule that
/// follows, and nothing here may break it.
///
/// The gene is the exception to what a colour means, because it is the only
/// page where the sequence is unreadable: 1,431 cells at ten pixels, too small
/// to letter, and colouring them by which of four letters they are produced
/// noise standing exactly where the answer should be. So that page alone is
/// coloured by the piece of the gene a cell belongs to, and each piece carries
/// its name written across it — which keeps the rule, because the name is a
/// label on the layer already drawn and not a second layer beside it.
///
/// Every page after the gene is short enough to letter, so the letter carries
/// the base and is drawn in that base's colour, on a tile that stays out of its
/// way; the residue pages colour by chemistry.
/// A selected gene feature also opens into these tiles after a short pause.
/// Its pieces move into DNA order while revealing a scrollable inspection;
/// returning restores the whole gene and its previous scroll position.
///
/// The transcript page is the one that bends the rule, and it is worth being
/// exact about how. It draws its 465 bases *and* the three regions they fall
/// into — but the regions are not a second layer beside the first: they are a
/// partition of the same cells, marked by strength rather than by hue, so a
/// base in the 5' UTR is still drawn as the A it is, only quieter. What the
/// page gains for that is the subtraction it used to only assert. It used to be
/// two pages — 465 bases, then 333 of them under a sentence claiming 59 fell
/// off the front and 73 off the back — and neither page showed it. Here the
/// ends that fall away are the ends already drawn as falling away, and the
/// reading frame is grooved into the only stretch that is ever read in threes.
///
/// It is also the one page that does not fit. A base has to be 20pt for its
/// letter to survive, and 465 of those is about twice a phone, so this page
/// scrolls where every other one is fitted to the screen. That is the right way
/// round: the gene page exists to be taken in at a glance and half of it would
/// be a different picture, while this one exists to be *read*, and a sequence
/// too small to read is not a smaller version of it either.
///
/// The header keeps the stage overview above the grid. Other stages replace
/// that overview with the tracer's details. On the protein page, a tap masks a
/// residue and opens a nonmodal score panel; its details live there so the
/// header stays steady while the reader compares positions. The mRNA page and
/// the opened-DNA page do the same one level down, for a base rather than a
/// residue, out of the bundled AlphaGenome track.
class AnatomyScreen extends StatefulWidget {
  const AnatomyScreen({
    required this.record,
    required this.target,
    this.constraint,
    this.impact,
    this.clinvar,
    super.key,
  }) : landing = null,
       conservation = false,
       _model = null,
       _reading = null;

  /// The walk a ClinVar record's link opens, above the list it came from.
  ///
  /// It is the same walk, opened on the page that holds [landing] with that
  /// residue or base already up, and it is a page of its own: Back, or its
  /// header's "← ClinVar", takes it away and leaves the list exactly as it was
  /// — and under the list, the walk the reader opened it from, untouched. The
  /// jump used to drive that walk itself, so closing the list left the reader
  /// wherever the record had sent them.
  const AnatomyScreen._landing({
    required this.record,
    required this.target,
    required VariantTarget this.landing,
    this.constraint,
    this.impact,
    this.clinvar,
    this.conservation = false,
    this._model,
    this._reading,
  });

  final GeneRecord record;

  /// Which protein this is, and so which constraint track and which model the
  /// walk reads. The record could almost answer for itself — it carries the
  /// gene symbol — but the asset paths and the fold's own caption are not in
  /// anything the backend sends, and inferring them from a symbol would put a
  /// lookup in the one place a wrong answer is a blank page.
  final ProteinTarget target;

  final ProteinConstraint? constraint;

  /// The per-base impact track, injected by tests the way [constraint] is; the
  /// screen loads it from the bundle otherwise.
  final GeneImpact? impact;
  final GeneClinVar? clinvar;

  /// The residue or base this walk was opened on, or null for a walk the
  /// reader came to by choosing a protein.
  final VariantTarget? landing;

  /// Whether a landing starts in ESM-2 colours: the walk it came from's
  /// setting, which is what the jump it replaced carried over.
  final bool conservation;

  /// The walk's model and its reading of the ClinVar snapshot, handed over so
  /// a landing neither derives the record nor reads thousands of records again.
  final AnatomyModel? _model;
  final _ClinVarReading? _reading;

  @override
  State<AnatomyScreen> createState() => _AnatomyScreenState();
}

class _AnatomyScreenState extends State<AnatomyScreen>
    with TickerProviderStateMixin {
  late AnatomyModel _model =
      widget._model ??
      AnatomyModel.derive(widget.record, chain: widget.target.chain);

  int _stage = 0;
  Tracer? _tracer;

  AnatomySelection? _selection;
  LocalHistoryEntry? _selectionHistory;

  /// The base lifted out of an open region, or null.
  int? _liftedBase;

  /// What the header says about [_liftedBase]: where it is in the transcript
  /// or the intron, and the codon it is read in.
  TracerStatus? get _liftedStatus {
    final int? cell = _liftedBase;
    final AnatomySelection? selection = _selection;
    if (cell == null || selection == null || !_selectionActive) {
      return null;
    }
    final AnatomyStage stage = selection.stage;
    if (cell >= stage.count) {
      return null;
    }
    final AnatomyAddress address = AnatomyAddress.of(_model);
    final int position = stage.positionAt(cell);
    final String base = stage.letters[cell];
    final String? c = address.cOf(position);
    final int? exon = address.exonOf(position);
    final String line = c != null
        ? '$c · $base${exon == null ? '' : ' · exon $exon'}'
        : '${selection.stage.label} base ${grouped(cell + 1)} · $base';
    final int? codon = address.codonOf(position);
    final int? residue = codon == null ? null : address.residueOfCodon(codon);
    return TracerStatus(
      alive: true,
      cell: cell,
      anchorStage: 0,
      anchorCell: cell,
      siblings: const <int>[],
      line: line,
      note: codon == null
          ? null
          : 'codon $codon · ${address.tripletOf(codon) ?? ''} · '
                '${residue == null ? 'stop' : address.residueName(residue)}',
    );
  }

  bool _selectionActive = false;
  bool _selectionReturning = false;
  double _geneScrollOffset = 0;
  double _detailScrollOffset = 0;
  late final AnimationController _selectionProgress = AnimationController(
    vsync: this,
    duration: AnatomyCanvas.durationOf(StageKind.dna),
    reverseDuration: const Duration(milliseconds: 600),
  )..addStatusListener(_selectionChanged);

  void _selectionChanged(AnimationStatus status) {
    if (mounted && status == AnimationStatus.completed) {
      setState(() {});
      if (_pendingLift != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _liftPending());
      }
    }
  }

  void _removeSelectionHistory() {
    final LocalHistoryEntry? entry = _selectionHistory;
    _selectionHistory = null;
    entry?.remove();
  }

  void _clearSelection() {
    _liftedBase = null;
    _pendingLift = null;
    _removeSelectionHistory();
    _selectionProgress.stop(canceled: true);
    // Closed, however it closed. With motion reduced a return skips the
    // reverse and left this at 1, where the next open's `value = 1` changed
    // nothing, reported nothing, and never lifted the base it was opened for.
    _selectionProgress.value = 0;
    _selection = null;
    _selectionActive = false;
    _selectionReturning = false;
    _detailScrollOffset = 0;
  }

  /// Selects the region at [position]. Its DNA opens only when the reader asks,
  /// from the strip's action — see [_openSelection].
  ///
  /// It used to open by itself a second and a half after the tap, which moved
  /// the page out from under a reader still reading the region's size.
  void _prepareSelection(int position) {
    _selection = AnatomySelection.of(_model, position);
  }

  /// Opens the selected region into its DNA.
  ///
  /// A landing's [arrival] opens it standing still and as the page itself,
  /// with no Back of its own: see [_sheetLanded].
  void _openSelection({bool arrival = false}) {
    if (!mounted || _selection == null || _stage != 0 || _selectionActive) {
      return;
    }
    if (_selectionHistory == null && !arrival) {
      late final LocalHistoryEntry entry;
      entry = LocalHistoryEntry(
        impliesAppBarDismissal: false,
        onRemove: () {
          if (identical(_selectionHistory, entry)) {
            _selectionHistory = null;
            unawaited(_returnToGene());
          }
        },
      );
      _selectionHistory = entry;
      ModalRoute.of(context)?.addLocalHistoryEntry(entry);
    }
    _geneScrollOffset =
        _geneScrollHold ?? (_scroll.hasClients ? _scroll.offset : 0);
    _geneScrollHold = null;
    if (_scroll.hasClients) {
      _scroll.jumpTo(0);
    }
    setState(() {
      _selectionActive = true;
      if (arrival || MediaQuery.disableAnimationsOf(context)) {
        _selectionProgress.value = 1;
      } else {
        unawaited(_selectionProgress.forward(from: 0));
      }
    });
  }

  Future<void> _returnToGene() async {
    if (_selection == null || _selectionReturning) {
      return;
    }
    if (!_selectionActive) {
      setState(() {
        _clearSelection();
        _tracer = null;
      });
      return;
    }
    _detailScrollOffset = _scroll.hasClients ? _scroll.offset : 0;
    if (_scroll.hasClients) {
      _scroll.jumpTo(0);
    }
    setState(() {
      _selectionReturning = true;
      _liftedBase = null;
    });
    try {
      if (!MediaQuery.disableAnimationsOf(context)) {
        await _selectionProgress.reverse().orCancel;
      }
      if (!mounted || _selection == null) {
        return;
      }
      setState(() {
        _clearSelection();
        _tracer = null;
      });
      // Restore after the gene's own scroll extent has been laid out.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _stage == 0 && _selection == null) {
          _restoreScroll(_geneScrollOffset);
        }
      });
    } on TickerCanceled {
      // A page or record change superseded this return.
    }
  }

  /// What the strip's second line says about the gene's regions, where it has
  /// something to say that a tracer's fact does not.
  ///
  /// With nothing picked, it is also where a page says what a tap on it opens
  /// — the gene its regions' DNA, a scored protein its residues' ESM-2 sheet,
  /// the transcript its bases' AVI sheet — once the track behind the sheet is
  /// there to open, and it goes the moment something is picked. A protein
  /// whose ESM-2 track failed to load says so here instead.
  String? get _selectionHint {
    final AnatomySelection? selection = _selection;
    if (selection == null) {
      if (_tracer != null || _maskedIndex != null) {
        return null;
      }
      final AnatomyStage? stage = _stage < _model.stages.length
          ? _model.stages[_stage]
          : null;
      return switch (stage?.kind) {
        StageKind.gene when _stage == 0 => 'Tap a region for its DNA',
        StageKind.protein when _constraintFailed => 'ESM-2 scores unavailable',
        StageKind.protein when _supportsConstraint(stage) =>
          'Tap a residue for its ESM-2 scores',
        StageKind.mrna when _supportsImpact(stage) =>
          'Tap a base for its AVI scores',
        _ => null,
      };
    }
    if (_selectionReturning || !_selectionActive || _liftedBase != null) {
      return null;
    }
    if (!_selectionProgress.isCompleted) {
      return null;
    }
    if (selection.shortened) {
      return 'Shortened: ${grouped(selection.stage.count)} of '
          '${grouped(selection.lengthBp)} bp available';
    }
    return selection.pieces > 1
        ? '${selection.pieces} pieces joined at exon junctions'
        : null;
  }

  ProteinConstraint? _constraint;
  bool _constraintFailed = false;
  bool _conservation = false;
  GeneImpact? _impact;
  GeneClinVar? _clinvar;
  bool _clinvarFailed = false;
  int _clinvarGeneration = 0;
  int? _maskedIndex;
  bool _panelVisible = false;
  bool _panelClosing = false;
  bool _visibilityScheduled = false;
  int _dismissGeneration = 0;
  LocalHistoryEntry? _sheetHistory;

  /// Whether the open sheet is the one a landing arrived with. It is the page
  /// the record's link opened rather than a layer the reader added, so it
  /// takes no Back of its own — one Back leaves the landing for the list —
  /// and a residue compared in it keeps it that way.
  bool _sheetLanded = false;
  bool _overviewOpen = false;

  /// Where the overview was left, for as long as this gene is shown.
  VariantsOverviewMemory _overviewMemory = VariantsOverviewMemory();

  /// The gene's named pieces, for the overview's gene drawing.
  List<GeneRun>? _geneRunsMemo;
  List<GeneRun> get _geneRuns => _geneRunsMemo ??= geneRuns(_model);
  final DraggableScrollableController _sheet = DraggableScrollableController();
  Timer? _reveal;
  Size _canvasViewport = Size.zero;
  double _panelHeight = 0;
  late final AnimationController _mask = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 300),
    reverseDuration: const Duration(milliseconds: 180),
  );
  late final AnimationController _sheetReveal = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 240),
    reverseDuration: const Duration(milliseconds: 180),
  );
  late final Animation<Offset> _sheetSlide = Tween<Offset>(
    begin: const Offset(0, 1),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _sheetReveal, curve: Curves.easeOutCubic));

  /// Where this page's tracks come from, and null where nothing provided one.
  ///
  /// Null is every widget test that pumps a page on its own, and it means the
  /// same thing null has always meant here: whatever was not handed in is not
  /// coming. A screen with no source is a screen that was given its tracks.
  TrackSource? _tracks;

  @override
  void initState() {
    super.initState();
    _tracks = context.read<TrackSource?>();
    _evidenceMemo = widget._reading;
    if (widget.landing case final VariantTarget landing) {
      _conservation = widget.conservation;
      _stage = _pageOf(landing);
      WidgetsBinding.instance.addPostFrameCallback((_) => _arrive(landing));
    }
    _sheet.addListener(_sheetSizeChanged);
    if (widget.constraint case final ProteinConstraint data) {
      _constraint = data;
    } else if (widget.target.scored) {
      // An unscored protein has no track to load and nothing has failed: its
      // protein page is drawn without the toolbar, which is what `_constraint`
      // staying null already means.
      unawaited(_loadConstraint());
    }
    if (widget.impact case final GeneImpact data) {
      _impact = data;
    } else if (widget.target.impactScored) {
      unawaited(_loadImpact());
    }
    _startClinVar();
    // A landing's walk was warmed by the walk it came from.
    if (widget.landing == null) {
      WidgetsBinding.instance.addPostFrameCallback(_prepareStructure);
    }
  }

  void _startClinVar() {
    _clinvarGeneration++;
    _clinvar = widget.clinvar;
    _clinvarFailed = false;
    if (_clinvar == null && widget.target.clinvarAvailable) {
      unawaited(_loadClinVar(_clinvarGeneration));
    }
  }

  Future<void> _loadClinVar(int generation) async {
    final TrackSource? tracks = _tracks;
    if (tracks == null) {
      return;
    }
    try {
      final GeneClinVar data = await GeneClinVar.load(
        widget.target,
        tracks: tracks,
      );
      if (mounted && generation == _clinvarGeneration) {
        setState(() => _clinvar = data);
      }
    } on Object {
      // See `_loadConstraint`: every way this can fail has to reach
      // `_clinvarFailed`, which is what makes the About sheet say "snapshot
      // unavailable" rather than "not yet included for DMD".
      if (mounted && generation == _clinvarGeneration) {
        setState(() => _clinvarFailed = true);
      }
    }
  }

  _ClinVarReading? _evidenceMemo;

  /// Every ClinVar record, read against whichever tracks match it — built once
  /// per combination of loaded tracks, not on every sheet build. Null while
  /// there is no snapshot, or none that matches the record on screen.
  List<VariantEvidence>? get _evidence => _evidenceState?.all;

  /// Each residue with records, keyed by precursor index, with its most
  /// severe group: the dots the protein page draws in ESM mode.
  Map<int, ClinVarMark> get _residueMarks =>
      _evidenceState?.marks ?? const <int, ClinVarMark>{};

  _ClinVarReading? get _evidenceState {
    final GeneClinVar? data = _clinvar;
    if (data == null) {
      return null;
    }
    final _ClinVarReading? memo = _evidenceMemo;
    if (memo != null &&
        identical(memo.snapshot, data) &&
        identical(memo.impact, _impact) &&
        identical(memo.constraint, _constraint)) {
      return memo;
    }
    return _evidenceMemo = _ClinVarReading(
      data,
      _impact,
      _constraint,
      data.matchesRecord(widget.record)
          ? VariantEvidence.build(
              data,
              impact: _impact,
              constraint: _constraint,
              nonCoding: nonCodingSections(_model),
            )
          : null,
      reversed: widget.record.strand == -1,
    );
  }

  /// The records at a residue or a base, in transcript order.
  List<VariantEvidence> _evidenceAt({int? residue, int? position}) =>
      (residue != null
          ? _evidenceState?.byResidue[residue]
          : _evidenceState?.byPosition[position]) ??
      const <VariantEvidence>[];

  /// What a sheet says about ClinVar at a residue or a base, or null for a
  /// gene with no snapshot — whose About sheet says so, once.
  Widget? _clinvarBlock({int? residue, int? position, required String scope}) {
    if (!widget.target.clinvarAvailable && widget.clinvar == null) {
      return null;
    }
    final List<VariantEvidence>? all = _evidence;
    final List<VariantEvidence> here = _evidenceAt(
      residue: residue,
      position: position,
    );
    return ClinVarBlock(
      key: ValueKey<String>('clinvar-${residue ?? 'base'}-${position ?? ''}'),
      status: all != null
          ? ClinVarStatus.ready
          : _clinvarFailed || _clinvar != null
          ? ClinVarStatus.unavailable
          : ClinVarStatus.loading,
      records: here,
      scope: scope,
      total: all?.length ?? 0,
      // Each sheet already shows its own model on its bars; its rows carry the
      // other one.
      column: residue != null ? EvidenceColumn.avi : EvidenceColumn.esm,
      allele: residue == null,
      place: residue == null,
      onOpenAll: all == null
          ? null
          : () => unawaited(
              _openVariants(
                focus: <String>[for (final VariantEvidence e in here) e.variant.id],
              ),
            ),
      onResidue: residue == null ? _goToResidue : null,
      onBase: residue == null ? null : _goToBase,
    );
  }

  /// The most severe group ClinVar records for each change at [records]'
  /// place, keyed by what the change is — an amino acid or a base — so the
  /// sheet can mark that change's own bar.
  static Map<String, ClinVarGroup> _reported(
    Iterable<VariantEvidence> records,
    String? Function(VariantEvidence) change,
  ) {
    final Map<String, List<ClinVarGroup>> groups =
        <String, List<ClinVarGroup>>{};
    for (final VariantEvidence e in records) {
      if (change(e) case final String key) {
        (groups[key] ??= <ClinVarGroup>[]).add(e.variant.group);
      }
    }
    return <String, ClinVarGroup>{
      for (final MapEntry<String, List<ClinVarGroup>> entry in groups.entries)
        entry.key: ClinVarGroup.mostSevere(entry.value),
    };
  }

  /// Every record of the gene, as the overview draws them. A record's link
  /// opens its residue or base as a page above the list — see
  /// [AnatomyScreen._landing] — so when that page is gone the list, and this
  /// walk under it, are both exactly as the reader left them.
  ///
  /// A landing already has a list, the one under it, so from there this goes
  /// back to that list carrying [focus] rather than stacking a second one.
  ///
  /// [over] is the sheet it was asked for from, which the list rises over and
  /// then takes away.
  Future<void> _openVariants({
    List<String> focus = const <String>[],
    Route<Object?>? over,
  }) async {
    if (widget.landing != null) {
      // The list is already under the landing: the sheet goes down, and the
      // landing goes with it.
      if (over != null && over.isCurrent) {
        Navigator.of(context).pop();
      }
      _leave(focus);
      return;
    }
    final GeneClinVar? data = _clinvar;
    final List<VariantEvidence>? all = _evidence;
    if (data == null || all == null || _overviewOpen) {
      return;
    }
    final CapturedThemes themes = _routeThemes();
    _overviewOpen = true;
    try {
      await Navigator.of(context).push<void>(
        riseRoute<void>(
          context,
          (BuildContext context) => themes.wrap(
            VariantsOverview(
              snapshot: data,
              evidence: all,
              exons: <(int, int)>[
                for (final Exon exon in widget.record.exons)
                  (exon.start, exon.end),
              ],
              runs: _geneRuns,
              reversed: widget.record.strand == -1,
              constraint: _constraint?.sequence == data.proteinSequence
                  ? _constraint
                  : null,
              focus: focus,
              memory: _overviewMemory,
              onOpen: _openLanding,
            ),
          ),
          over: over,
        ),
      );
    } finally {
      _overviewOpen = false;
    }
  }

  /// The themes a route pushed from here is drawn in: the walk's analysis
  /// theme, which the app's own theme would otherwise replace, and every theme
  /// between here and the navigator with it.
  CapturedThemes _routeThemes() => InheritedTheme.capture(
    from: context,
    to: Navigator.of(context).context,
  );

  /// Opens [target] as a landing above the overview, and hands the overview
  /// the records the reader asked for from there, if any.
  Future<List<String>?> _openLanding(VariantTarget target) {
    final CapturedThemes themes = _routeThemes();
    // Taken now: the route's builder can run again long after this, and the
    // landing is of the walk as it was when the link was followed.
    final AnatomyScreen landing = AnatomyScreen._landing(
      record: widget.record,
      target: widget.target,
      landing: target,
      constraint: _constraint,
      impact: _impact,
      clinvar: _clinvar,
      conservation: _conservation,
      model: _model,
      reading: _evidenceState,
    );
    return Navigator.of(context).push<List<String>>(
      walkRoute<List<String>>(
        context,
        (BuildContext context) => themes.wrap(landing),
      ),
    );
  }

  /// Leaves a landing for the list under it, with [focus] for the list to open
  /// on, or null — from the header — for the list as it was.
  ///
  /// Straight there, whatever the reader has opened since arriving: a plain
  /// pop would only close the newest of those.
  void _leave([List<String>? focus]) {
    // Once on its way out it is no longer current, and a second tap in the
    // same frame would take the list with it.
    if (!(ModalRoute.of(context)?.isCurrent ?? false)) {
      return;
    }
    _removeSheetHistory();
    _removeSelectionHistory();
    Navigator.of(context).pop<List<String>>(focus);
  }

  /// Gets the fold's one-time renderer work out of the way while the walk is
  /// at rest.
  ///
  /// That work holds the UI thread for as long as it runs, so it waits for a
  /// frame after which nothing is animating — the route's entrance and the
  /// first stage's reveal both finished — and runs over a page that is standing
  /// still, rather than on the structure page, where it froze the loading
  /// pulse. See [StructureView.prepare].
  void _prepareStructure(Duration _) {
    if (!mounted) {
      return;
    }
    if (WidgetsBinding.instance.transientCallbackCount > 0) {
      // Whatever is animating has already asked for the next frame.
      WidgetsBinding.instance.addPostFrameCallback(_prepareStructure);
      return;
    }
    // A device that cannot draw it is told so on the page itself.
    StructureView.prepare(context, widget.target).ignore();
  }

  Future<void> _loadConstraint() async {
    final TrackSource? tracks = _tracks;
    if (tracks == null) {
      return;
    }
    _constraintLoading = true;
    try {
      final ProteinConstraint data = await ProteinConstraint.load(
        widget.target,
        tracks: tracks,
      );
      if (mounted) {
        setState(() => _constraint = data);
      }
    } on Object {
      // `Object`, not `Exception`: a missing bundle asset throws a
      // `FlutterError` and a payload that is not the JSON object it claimed
      // throws a `TypeError`, both of which are `Error`s. Off the network there
      // are more ways still — an HTML error page, a truncated body — and every
      // one of them has to land here rather than leave the toolbar hidden with
      // nothing said about why.
      if (mounted) {
        setState(() => _constraintFailed = true);
      }
    } finally {
      _constraintLoading = false;
      _arriveWaiting();
    }
  }

  /// The impact track, loaded the same way and failing the same way: a gene
  /// without one draws its nucleotide pages exactly as it did before, and a tap
  /// there follows the tracer. There is no error to show because there is
  /// nothing the reader asked for that did not arrive.
  Future<void> _loadImpact() async {
    final TrackSource? tracks = _tracks;
    if (tracks == null) {
      return;
    }
    _impactLoading = true;
    try {
      final GeneImpact data = await GeneImpact.load(
        widget.target,
        tracks: tracks,
      );
      if (mounted) {
        setState(() => _impact = data);
      }
    } on Object {
      // Left null, which is the same state as a gene that has no track — and
      // the About sheet is where the two stop looking alike: it names AVI as a
      // source only where the track arrived, so a gene that has one and could
      // not fetch it is not credited with it. See `_openAbout`.
    } finally {
      _impactLoading = false;
      _arriveWaiting();
    }
  }

  /// Opens what a landing is waiting on a track for, now that the track has
  /// come — with its sheet — or has failed, when the page traces it instead.
  void _arriveWaiting() {
    if (_arrivalWaiting case final VariantTarget waiting when mounted) {
      _arrivalWaiting = null;
      WidgetsBinding.instance.addPostFrameCallback((_) => _arrive(waiting));
    }
  }

  /// Whether a tap on [stage] opens the base inspector.
  ///
  /// The mRNA page and the opened-DNA page, and not the gene page: at 24,000
  /// bases `AnatomyLayout.fit` puts a gene cell at its two-point floor, where
  /// no finger can pick one base out of its neighbours. A tap there means the
  /// run it lands in, which is what it has always meant, and the strip answers
  /// with what that whole run scores.
  bool _supportsImpact(AnatomyStage? stage) =>
      stage?.kind == StageKind.mrna && _impact != null;

  bool _supportsConstraint(AnatomyStage? stage) =>
      stage?.kind == StageKind.protein &&
      stage?.letters == _constraint?.sequence &&
      _constraint != null;

  void _clearMask() {
    _sheetLanded = false;
    _dismissGeneration++;
    _reveal?.cancel();
    _mask.stop();
    _mask.value = 0;
    _maskedIndex = null;
    _panelVisible = false;
    _panelClosing = false;
    _sheetReveal.stop();
    _sheetReveal.value = 0;
    _removeSheetHistory();
    if (_sheet.isAttached) {
      _sheet.reset();
    }
  }

  void _sheetSizeChanged() {
    if (!mounted || !_panelVisible || _panelClosing) {
      return;
    }
    setState(() {});
    _keepMaskedResidueVisible(animate: false);
  }

  void _addSheetHistory() {
    if (_sheetHistory != null || _sheetLanded) {
      return;
    }
    late final LocalHistoryEntry entry;
    entry = LocalHistoryEntry(
      impliesAppBarDismissal: false,
      onRemove: () {
        if (identical(_sheetHistory, entry)) {
          _sheetHistory = null;
          unawaited(_dismissPanel());
        }
      },
    );
    _sheetHistory = entry;
    ModalRoute.of(context)?.addLocalHistoryEntry(entry);
  }

  void _removeSheetHistory() {
    final LocalHistoryEntry? entry = _sheetHistory;
    _sheetHistory = null;
    entry?.remove();
  }

  void _showPanel(bool still) {
    _panelVisible = true;
    if (still) {
      _sheetReveal.value = 1;
    } else {
      unawaited(_sheetReveal.forward());
    }
  }

  /// Whether something is selected for the sheet to be about.
  ///
  /// Two kinds of selection, because the opened-DNA page is drawn by its own
  /// canvas and lifts a tile where the others mask one.
  bool get _panelSubject =>
      _maskedIndex != null || (_liftedBase != null && _selectionActive);

  Future<void> _dismissPanel() async {
    if (_panelClosing || !_panelSubject) {
      return;
    }
    _reveal?.cancel();
    _removeSheetHistory();
    final int generation = ++_dismissGeneration;
    if (!_panelVisible || MediaQuery.disableAnimationsOf(context)) {
      setState(_clearPanel);
      return;
    }
    _panelClosing = true;
    unawaited(_mask.reverse());
    try {
      await _sheetReveal.reverse().orCancel;
      if (mounted && generation == _dismissGeneration) {
        setState(_clearPanel);
      }
    } on TickerCanceled {
      // A fresh residue or a page change supersedes the closing animation.
    }
  }

  /// Puts back what the sheet was drawn over.
  ///
  /// The tracer survives an open region. On a masked page it is the cell the
  /// sheet was about and goes with it, but on the opened-DNA page it is the
  /// *region* — the thing the gene page selected and this page is a picture of
  /// — and [AnatomySelectionCanvas] is built around it. Clearing it there left
  /// that canvas with nothing to draw, which a release build renders as a grey
  /// rectangle where the bases were.
  void _clearPanel() {
    _clearMask();
    if (_selectionActive) {
      // The base goes back down with the sheet, as a masked cell does.
      _liftedBase = null;
    } else {
      _tracer = null;
    }
  }

  /// Masks the tapped cell and raises the inspector over it.
  ///
  /// Shared by the residue panel and the base panel: the 300 ms beat, the swap
  /// in place while comparing, the Back entry and the scroll that keeps the
  /// masked cell above the sheet are the same interaction either way. Only what
  /// the sheet then says differs.
  ///
  /// A landing's [arrival] raises the sheet standing still, as the page it
  /// opened on: see [_sheetLanded].
  void _selectCell(int? position, {bool arrival = false}) {
    final AnatomyStage stage = _model.stages[_stage];
    final int index = position == null ? -1 : stage.cellAt(position);
    if (index < 0 || index == _maskedIndex) {
      unawaited(_dismissPanel());
      return;
    }
    if (!arrival) {
      unawaited(HapticFeedback.selectionClick());
    }
    final bool comparing = _panelVisible;
    final bool wasClosing = _panelClosing;
    final bool still = arrival || MediaQuery.disableAnimationsOf(context);
    _reveal?.cancel();
    _dismissGeneration++;
    _panelClosing = false;
    if (wasClosing && _sheet.isAttached) {
      _sheet.jumpTo(InspectorSheet.initialSize);
    }
    setState(() {
      _maskedIndex = index;
      _tracer = Tracer(position!);
      if (arrival) {
        _sheetLanded = true;
      } else {
        _addSheetHistory();
      }
      if (still || comparing) {
        _mask.value = 1;
        _showPanel(still);
      } else {
        unawaited(_mask.forward(from: 0));
      }
    });
    if (still || comparing) {
      _keepMaskedResidueVisible(animate: !arrival);
    } else {
      _reveal = Timer(const Duration(milliseconds: 300), () {
        if (mounted && _maskedIndex == index) {
          setState(() => _showPanel(false));
          _keepMaskedResidueVisible();
        }
      });
    }
  }

  /// Whichever inspector the page under the sheet calls for, or null.
  ///
  /// One sheet at a time, one set of controllers: the residue panel and the
  /// base panel are never both up, because the pages they belong to are never
  /// both on screen.
  Widget? _inspector(double sheetSpace) {
    if (!_panelVisible) {
      return null;
    }
    final bool pin =
        sheetSpace * InspectorSheet.initialSize >=
        240 * MediaQuery.textScalerOf(context).scale(1);
    final AnatomyStage? stage = _shownStage;
    if (_maskedIndex case final int index) {
      if (_supportsConstraint(stage)) {
        final ResidueConstraint residue = _constraint!.positions[index];
        return ConstraintPanel(
          key: const ValueKey<String>('constraint-panel'),
          residue: residue,
          observedEvidence: _clinvarBlock(
            residue: index + 1,
            scope: '${AminoAcids.abbreviationOf(residue.wildtype)}${residue.number}',
          ),
          reported: _reported(
            _evidenceAt(
              residue: index + 1,
            ).where((VariantEvidence e) => e.esm != null),
            (VariantEvidence e) => e.variant.altResidue,
          ),
          length: _constraint!.sequence.length,
          controller: _sheet,
          slide: _sheetSlide,
          pinIdentity: pin,
          onDismiss: () => unawaited(_dismissPanel()),
        );
      }
      if (_supportsImpact(stage)) {
        return _basePanel(
          stage!.positionAt(index),
          pin,
          '${stage.label} base ${grouped(index + 1)}',
        );
      }
    }
    if (_liftedBase case final int cell) {
      final AnatomySelection? selection = _selection;
      if (selection != null &&
          _selectionActive &&
          cell < selection.stage.count) {
        return _basePanel(
          selection.stage.positionAt(cell),
          pin,
          '${selection.stage.label} base ${grouped(cell + 1)}',
        );
      }
    }
    return null;
  }

  /// The base inspector for a record position, with everything the page already
  /// knows how to say about that position filled in.
  Widget? _basePanel(int position, bool pin, String fallback) {
    final GeneImpact? impact = _impact;
    final BaseImpact? reading = impact?.at(position);
    if (impact == null || reading == null) {
      return null;
    }
    final AnatomyAddress address = AnatomyAddress.of(_model);
    final Role? transcript = _model.transcriptRoleAt(position);
    final Role? coding = _model.codingRoleAt(position);
    final String? c = address.cOf(position);
    final int? codon = address.codonOf(position);
    final int? residue = codon == null ? null : address.residueOfCodon(codon);
    // The same facts the tracer line gives, which is what this page has always
    // answered a tap with; the scores are what is new.
    final CodingEvidence? evidence = CodingEvidence.at(
      model: _model,
      position: position,
      track: _constraint,
    );
    // For a coding base the residue it encodes is named with its constraint
    // band, and the line opens that residue: the protein's own reading lives
    // on the protein page, not summarised a second time here.
    final String note = switch (transcript) {
      final Role role when role.kind == RoleKind.intron =>
        address.intronFacts(role) ?? '',
      _ when codon != null =>
        'codon $codon · ${address.tripletOf(codon) ?? ''} · '
            '${residue == null ? 'stop' : address.residueName(residue)}'
            '${evidence?.constraint == null ? '' : ' · ${evidence!.constraint!.level.label}'}',
      _ => '',
    };
    final String where = c ?? fallback;
    return ImpactPanel(
      key: const ValueKey<String>('impact-panel'),
      impact: reading,
      explanationTrack: impact.matchesRecord(widget.record) ? impact : null,
      observedEvidence: _clinvarBlock(position: position, scope: where),
      reported: _reported(
        _evidenceAt(position: position),
        (VariantEvidence e) => e.variant.alt,
      ),
      coding: evidence,
      onNote: residue == null || _constraint == null
          ? null
          : () => _goToResidue(residue),
      chromosome: impact.chromosome,
      // The transcript's own number where the base has one, and otherwise the
      // number the page above is already calling it by. Counting from the
      // record's first base instead would put a third numbering on screen.
      address: where,
      // Written on the sheet, not in a sentence, so without its article:
      // "signal peptide", "5′ UTR" — as the gene page writes them.
      region: _written(coding?.label ?? transcript?.label ?? 'gene'),
      note: note,
      // The colour the grid draws this cell in, read the same way the painter
      // reads it: the coding role where there is one, because 5' UTR and CDS
      // are the distinction worth carrying into the sheet, and the transcript's
      // exon or intron where there is not.
      tint:
          context.anatomyColors.forSlot(
            CellSlot.forRole(
              (coding ?? transcript)?.kind,
              (coding ?? transcript)?.index ?? 0,
            ),
          ) ??
          Theme.of(context).colorScheme.onSurfaceVariant,
      controller: _sheet,
      slide: _sheetSlide,
      pinIdentity: pin,
      onDismiss: () => unawaited(_dismissPanel()),
    );
  }

  /// [label] as written on the thing it names rather than in a sentence:
  /// without its article.
  static String _written(String label) =>
      label.toLowerCase().startsWith('the ') ? label.substring(4) : label;

  /// A base lifted out of an open region, and the inspector over it.
  ///
  /// The canvas owns the lift itself — the tile rises, and tapping it again
  /// sets it back down — so this only has to answer with the scores, on the
  /// same beat the masked pages use.
  void _liftBase(int? cell, {bool arrival = false}) {
    final AnatomySelection? selection = _selection;
    if (cell == null || selection == null || cell >= selection.stage.count) {
      setState(() => _liftedBase = null);
      unawaited(_dismissPanel());
      return;
    }
    final bool scored = _impact?.at(selection.stage.positionAt(cell)) != null;
    final bool comparing = _panelVisible;
    final bool wasClosing = _panelClosing;
    final bool still = arrival || MediaQuery.disableAnimationsOf(context);
    _reveal?.cancel();
    _dismissGeneration++;
    _panelClosing = false;
    if (wasClosing && _sheet.isAttached) {
      _sheet.jumpTo(InspectorSheet.initialSize);
    }
    setState(() {
      _liftedBase = cell;
      if (!scored) {
        // A gene with no track, or a base the model has nothing for. The lift
        // and the header line are what this page has always done, and they are
        // still what it does.
        _panelVisible = false;
        _sheetReveal.value = 0;
        _sheetLanded = false;
        _removeSheetHistory();
        return;
      }
      if (arrival) {
        _sheetLanded = true;
      } else {
        _addSheetHistory();
      }
      if (still || comparing) {
        _showPanel(still);
      }
    });
    if (scored && (still || comparing)) {
      _keepMaskedResidueVisible();
    }
    if (scored && !still && !comparing) {
      _reveal = Timer(const Duration(milliseconds: 300), () {
        if (mounted && _liftedBase == cell) {
          setState(() => _showPanel(false));
          _keepMaskedResidueVisible();
        }
      });
    }
  }

  void _keepMaskedResidueVisible({bool animate = true}) {
    if (_visibilityScheduled) {
      return;
    }
    _visibilityScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _visibilityScheduled = false;
      // A masked cell, or a base lifted out of an open region: the same
      // promise either way, that the thing the sheet is about stays above it.
      final int? lifted = _selectionActive ? _liftedBase : null;
      final int? index = _maskedIndex ?? lifted;
      if (!mounted || index == null || !_panelVisible || !_scroll.hasClients) {
        return;
      }
      final AnatomyLayout? layout = _maskedIndex != null
          ? AnatomyLayout.forStage(
              _model.stages[_stage],
              _canvasViewport,
              _canvasViewport,
            )
          : _shownLayout();
      if (layout == null) {
        return;
      }
      final double y = layout.centreOf(index).dy + _canvasInset;
      final double visibleHeight =
          _canvasViewport.height + _canvasInset - _panelHeight;
      if (visibleHeight < layout.side + 8) {
        return;
      }
      if (y - _scroll.offset + layout.side / 2 > visibleHeight ||
          y - _scroll.offset - layout.side / 2 < 0) {
        final double target = (y - visibleHeight * 0.55).clamp(
          0.0,
          _scroll.position.maxScrollExtent,
        );
        if (!animate || MediaQuery.disableAnimationsOf(context)) {
          _scroll.jumpTo(target);
        } else {
          unawaited(
            _scroll.animateTo(
              target,
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOutCubic,
            ),
          );
        }
      }
    });
  }

  /// The stages the record derives, plus the structure.
  ///
  /// The fold is a page of the same walk but not an [AnatomyStage]: it has no
  /// cells, no positions and no letters, and giving it empty ones would hollow
  /// out the contract every other page and the whole painter rely on. So it is
  /// counted here and branched on in [build], and `anatomy_stages.dart` never
  /// learns it exists.
  int get _pageCount => _model.stages.length + 1;

  /// The index of the structure page, which is always the last one.
  int get _structureIndex => _model.stages.length;

  final ScrollController _scroll = ScrollController();
  double _sourceScrollOffset = 0;

  /// The hair above the canvas. Sixteen points of it was a frame around the
  /// quantity as surely as a horizontal inset would have been.
  static const double _canvasInset = AppSpacing.xs;

  /// The strip at the foot of the screen the paginator floats in: the air above
  /// the pill, the pill, and its lift off the bottom.
  ///
  /// Taken off the viewport the canvas is given, which is what keeps the pill
  /// floating over the *background* rather than over the sequence. A fitted
  /// stage fills its box in one direction or the other, and on the gene page
  /// that direction is height — so a pill simply laid on top would be lying on
  /// a dozen real bases, and a translucent thing over data still hides it.
  static const double _paginatorBand = AppSpacing.sm + 48 + AppSpacing.lg;

  /// The fade the stage bar sits on: the band, and a little above it.
  static const double _fadeBand = _paginatorBand + AppSpacing.md;

  /// How far up from the foot of the screen the stage bar reaches.
  static const double _stageBarTop = AppSpacing.lg + StageBar.height;

  @override
  void dispose() {
    _removeSelectionHistory();
    _selectionProgress.dispose();
    _reveal?.cancel();
    _removeSheetHistory();
    _sheet.removeListener(_sheetSizeChanged);
    _sheet.dispose();
    _sheetReveal.dispose();
    _mask.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(AnatomyScreen old) {
    super.didUpdateWidget(old);
    if (old.target != widget.target || old.clinvar != widget.clinvar) {
      _startClinVar();
    }
    if (old.record != widget.record) {
      _evidenceMemo = null;
      // Another gene: its overview starts fresh.
      _overviewMemory = VariantsOverviewMemory();
      _geneRunsMemo = null;
      _onLanded = null;
      _clearSelection();
      _model = AnatomyModel.derive(widget.record, chain: widget.target.chain);
      _stage = 0;
      _tracer = null;
      _clearMask();
    }
  }

  Offset _swipeOrigin = Offset.zero;
  Offset _swipeTravel = Offset.zero;
  bool _verticalSwipe = false;

  void _trackSwipe(PointerMoveEvent event) {
    _swipeTravel = event.position - _swipeOrigin;
    // Once a drag is vertical, turning sideways must not change its purpose.
    if (_swipeTravel.dy.abs() > 18 &&
        _swipeTravel.dy.abs() > _swipeTravel.dx.abs()) {
      _verticalSwipe = true;
    }
  }

  void _finishSwipe(DragEndDetails details) {
    if (!_verticalSwipe &&
        _swipeTravel.dx.abs() >= 48 &&
        _swipeTravel.dx.abs() > _swipeTravel.dy.abs() * 1.5) {
      _step(_swipeTravel.dx < 0 ? 1 : -1);
    }
  }

  void _step(int delta) {
    // A page the reader turns to is theirs: a jump still on its way is let go.
    _onLanded = null;
    if (_selectionActive) {
      // Leave the inspection through its visible return action, a back gesture,
      // or a right swipe. A sideways slip while scrolling cannot skip mRNA.
      if (delta < 0) {
        unawaited(_returnToGene());
      }
      return;
    }
    final int next = (_stage + delta).clamp(0, _pageCount - 1);
    if (next == _stage) {
      return;
    }
    unawaited(HapticFeedback.selectionClick());
    // Translation carries the visible source positions into its own canvas,
    // then lifts the coding sequence as the untranslated ends disappear.
    _sourceScrollOffset = _scroll.hasClients ? _scroll.offset : 0;
    if (_scroll.hasClients && _scroll.offset != 0) {
      _scroll.jumpTo(0);
    }
    setState(() {
      _clearSelection();
      _clearMask();
      _stage = next;
      // A selected region is let go of on the way out of the gene. Only that
      // page is drawn as regions, so carrying the selection forward would leave
      // a caption naming something with nothing on screen to point at — and a
      // base traced from a residue is a different thing, and still travels.
      if (_tracer?.asRun ?? false) {
        if (next == _structureIndex ||
            _model.stages[next].kind != StageKind.gene) {
          _tracer = null;
        }
      }
    });
  }

  /// The stage whose cells are on screen: an open region's DNA, or the page.
  AnatomyStage? get _shownStage => _selectionActive
      ? _selection?.stage
      : _stage < _model.stages.length
      ? _model.stages[_stage]
      : null;

  (AnatomyStage, Size, AnatomyLayout)? _layoutMemo;

  AnatomyLayout? _shownLayout() {
    final AnatomyStage? stage = _shownStage;
    if (stage == null || _canvasViewport.isEmpty) {
      return null;
    }
    final (AnatomyStage, Size, AnatomyLayout)? memo = _layoutMemo;
    if (memo != null &&
        identical(memo.$1, stage) &&
        memo.$2 == _canvasViewport) {
      return memo.$3;
    }
    final AnatomyLayout layout = AnatomyLayout.forStage(
      stage,
      _canvasViewport,
      _canvasViewport,
    );
    _layoutMemo = (stage, _canvasViewport, layout);
    return layout;
  }

  /// Whether the page on screen runs on below [viewport] — the transcript, a
  /// long gene, a long region's DNA — so that live cells pass under the stage
  /// bar.
  bool _scrolls(Size viewport) {
    final AnatomyStage? stage = _shownStage;
    return stage != null &&
        !viewport.isEmpty &&
        AnatomyLayout.heightFor(stage, viewport) > viewport.height;
  }

  /// Whether the page on screen is long enough to want a scrubber: more than
  /// three screens of it.
  bool _scrubs(Size viewport) {
    final AnatomyStage? stage = _shownStage;
    return stage != null &&
        !viewport.isEmpty &&
        AnatomyLayout.heightFor(stage, viewport) > viewport.height * 3;
  }

  /// The number, or on the gene the region, of the row at the top of the view
  /// at scroll [offset].
  String? _rowLabelAt(double offset) {
    final AnatomyStage? stage = _shownStage;
    final AnatomyLayout? layout = _shownLayout();
    if (stage == null || layout == null) {
      return null;
    }
    final double x = layout.origin.dx + layout.cell / 2;
    for (int k = 0; k < 8; k++) {
      final int cell = layout.hitTest(
        Offset(x, offset - _canvasInset + layout.rowHeight * (k + 0.5)),
      );
      if (cell < 0) {
        continue;
      }
      if (!AnatomyRuler.rules(stage)) {
        return stage.runAt(cell).label;
      }
      final StageBlock block = stage.blocks[stage.blockOf(cell)];
      return AnatomyRuler.labelAt(
        stage,
        cell - (cell - block.start) % layout.columns,
      );
    }
    return null;
  }

  /// The named domains down a scored protein page, where it has any.
  List<(double, String)> _landmarks() {
    final ProteinConstraint? track = _constraint;
    final AnatomyStage? stage = _shownStage;
    final AnatomyLayout? layout = _shownLayout();
    if (track == null ||
        stage == null ||
        layout == null ||
        stage.kind != StageKind.protein) {
      return const <(double, String)>[];
    }
    return <(double, String)>[
      for (final ConstraintRegion region in track.regions)
        if (region.short.isNotEmpty && region.kept)
          (
            layout.centreOf(region.start - 1).dy -
                layout.rowHeight / 2 +
                _canvasInset,
            region.short,
          ),
    ];
  }

  /// The bonded cysteines [stage] draws, cell to bridge number, or none.
  Map<int, int> _bridgesOn(AnatomyStage? stage) {
    final ProteinConstraint? track = _constraint;
    if (track == null || stage == null || stage.positionsPerCell != 3) {
      return const <int, int>{};
    }
    final AnatomyStage precursor = _model.stages.firstWhere(
      (AnatomyStage s) => s.kind == StageKind.protein,
    );
    int cellOf(int number) => stage.kind == StageKind.protein
        ? number - 1
        : stage.cellAt(precursor.positionAt(number - 1));
    final Map<int, int> cells = <int, int>{};
    final List<(int, int)> bridges = track.bridges;
    for (int i = 0; i < bridges.length; i++) {
      for (final int number in <int>[bridges[i].$1, bridges[i].$2]) {
        final int cell = cellOf(number);
        if (cell >= 0) {
          cells[cell] = i + 1;
        }
      }
    }
    return cells;
  }

  /// A traced cysteine's bridge: its partner ringed beside it, and named.
  /// Adds what a whole run scores to the gene page's caption.
  ///
  /// The gene page cannot inspect one base — at 24,000 bases its cells are two
  /// points wide — so a tap there means the exon or intron it landed in, and
  /// what that run is worth is a median and a peak rather than three numbers.
  /// Both, because a run's interest is usually one or two positions in it and
  /// the median alone would hide exactly the thing worth opening the region
  /// for. Where that peak sits is the next question and not this line's: the
  /// strip has one line to say this in, and the DNA pill is already on it.
  TracerStatus? _withImpact(TracerStatus? status, AnatomyStage? stage) {
    final GeneImpact? impact = _impact;
    if (impact == null ||
        status == null ||
        !status.alive ||
        stage?.kind != StageKind.gene ||
        status.cell < 0) {
      return status;
    }
    final StageRun run = stage!.runAt(status.cell);
    if (run.count < 2) {
      return status;
    }
    final ImpactSummary? summary = impact.summaryOf(
      stage.positionAt(run.start),
      stage.positionAt(run.start + run.count - 1),
    );
    if (summary == null) {
      return status;
    }
    final String line =
        'AVI median ${summary.median.toStringAsFixed(1)} · '
        'peak ${summary.peak.toStringAsFixed(1)}';
    return TracerStatus(
      alive: status.alive,
      cell: status.cell,
      anchorStage: status.anchorStage,
      anchorCell: status.anchorCell,
      siblings: status.siblings,
      line: status.line,
      note: status.note == null ? line : '${status.note} · $line',
      fate: status.fate,
    );
  }

  TracerStatus? _withBridge(TracerStatus? status, AnatomyStage? stage) {
    final ProteinConstraint? track = _constraint;
    if (status == null ||
        !status.alive ||
        track == null ||
        stage == null ||
        stage.positionsPerCell != 3 ||
        status.cell < 0) {
      return status;
    }
    final int? number = AnatomyAddress.of(_model)
        .precursorNumberOf(stage, status.cell);
    if (number == null || number > track.positions.length) {
      return status;
    }
    final ResidueConstraint residue = track.positions[number - 1];
    final int? partner = residue.bondPartnerNumber;
    if (partner == null) {
      return status;
    }
    final AnatomyStage precursor = _model.stages.firstWhere(
      (AnatomyStage s) => s.kind == StageKind.protein,
    );
    final int partnerCell = stage.kind == StageKind.protein
        ? partner - 1
        : stage.cellAt(precursor.positionAt(partner - 1));
    return TracerStatus(
      alive: status.alive,
      cell: status.cell,
      anchorStage: status.anchorStage,
      anchorCell: status.anchorCell,
      siblings: partnerCell < 0 ? const <int>[] : <int>[partnerCell],
      line: status.line,
      note: 'S\u2013S ${residue.bondPartner}',
      fate: status.fate,
    );
  }

  /// Where the fold comes from: `PDB 2OCJ · residues 96–289 of 393`.
  String get _foldSource {
    final StructureChrome structure = widget.target.structure;
    return switch (structure.modelled) {
      (final int from, final int to) =>
        'PDB ${structure.pdb} · residues $from–$to of '
            '${grouped(widget.target.facts.residues)}',
      null => 'PDB ${structure.pdb}',
    };
  }

  /// The fold's colours, named the way the chains page names them.
  List<(Color, String)> _foldLegend(BuildContext context) {
    final AnatomyColors anatomy = context.anatomyColors;
    // One name per chain colour, in the order the chains page hands them out:
    // identical products share a colour, so they share a name.
    final List<String> products = <String>[];
    for (final Peptide peptide in widget.record.peptides) {
      final String name = peptide.product ?? 'chain';
      if (!products.contains(name)) {
        products.add(name);
      }
    }
    String nameOf(int ordinal) => ordinal < products.length
        ? products[ordinal]
        : widget.target.chain ?? widget.target.display;
    return <(Color, String)>[
      for (final StructureChain chain in widget.target.chains)
        (
          chain.tint.of(anatomy),
          switch (chain.tint) {
            ChainTint.mature1 => nameOf(0),
            ChainTint.mature2 => nameOf(1),
            ChainTint.mature3 => nameOf(2),
            ChainTint.cysteine => 'disulfide bridges',
          },
        ),
    ];
  }

  void _openAbout() {
    unawaited(
      showRecordSheet(
        context: context,
        model: _model,
        target: widget.target,
        scored: _constraint != null,
        onGoToResidue: _goToResidue,
        impactScored: _impact != null,
        clinvar: _evidence == null ? null : _clinvar,
        clinvarFailed: _clinvarFailed || (_clinvar != null && _evidence == null),
        onOpenVariants: _evidence == null
            ? null
            : (Route<Object?> sheet) => unawaited(_openVariants(over: sheet)),
      ),
    );
  }

  /// A jump waiting for the page it was sent to: that page, and what to do
  /// there once the canvas has come to rest on it.
  (int, VoidCallback)? _onLanded;

  /// A base to lift once its region's DNA has opened, and whether it is what a
  /// landing was opened on (see [_arrive]).
  (int, bool)? _pendingLift;

  /// The gene page's scroll offset while one open region gives way to another.
  /// [_openSelection] reads the offset it returns to off the scroll, which at
  /// that moment is still the departing region's.
  double? _geneScrollHold;

  /// A landing's base waiting for the AVI track: without it the page can only
  /// trace the base, not open its sheet.
  VariantTarget? _arrivalWaiting;
  bool _impactLoading = false;
  bool _constraintLoading = false;

  /// Sends the reader to page [page] and runs [then] there — at once if the
  /// page is already on screen, and otherwise when the canvas reports it has
  /// come to rest on it ([AnatomyCanvas.onSettled]). A newer jump, or the
  /// reader turning to another page first, drops [then] unrun.
  void _goToPage(int page, VoidCallback then) {
    if (page < 0 || !mounted) {
      return;
    }
    _onLanded = null;
    if (_selection != null) {
      if (_selectionActive) {
        _geneScrollHold = _geneScrollOffset;
      }
      setState(() {
        _clearSelection();
        _tracer = null;
      });
    }
    if (_stage == page) {
      then();
      return;
    }
    _step(page - _stage);
    _onLanded = (page, then);
  }

  /// Runs the waiting jump if the canvas has come to rest on its page.
  void _land(int stage) {
    final (int, VoidCallback)? pending = _onLanded;
    _onLanded = null;
    if (mounted && pending != null && pending.$1 == stage && stage == _stage) {
      pending.$2();
    }
  }

  /// Takes the reader to residue [number] of the precursor, and opens it.
  void _goToResidue(int number) => _goToPage(
    _model.stages.indexWhere((AnatomyStage s) => s.kind == StageKind.protein),
    () => _revealCell(StageKind.protein, (AnatomyStage stage) => number - 1),
  );

  /// Takes the reader to base [position] and opens it: on the mRNA page where
  /// the transcript has it, and otherwise inside its region's DNA, which is
  /// the only place an intron's bases are drawn.
  void _goToBase(int position) {
    final int mrna = _mrnaHolding(position);
    if (mrna >= 0) {
      _goToPage(
        mrna,
        () => _revealCell(
          StageKind.mrna,
          (AnatomyStage stage) => stage.cellAt(position),
        ),
      );
      return;
    }
    _goToPage(0, () => _openRegionAt(position));
  }

  /// The mRNA page, where it draws [position]; otherwise -1. An intron's base,
  /// or one outside the transcript, is drawn only in its region's DNA.
  int _mrnaHolding(int position) {
    final int mrna = _model.stages.indexWhere(
      (AnatomyStage s) => s.kind == StageKind.mrna,
    );
    return mrna >= 0 && _model.stages[mrna].cellAt(position) >= 0 ? mrna : -1;
  }

  /// The page a landing opens on.
  int _pageOf(VariantTarget target) => math.max(0, switch (target) {
    ResidueTarget() => _model.stages.indexWhere(
      (AnatomyStage s) => s.kind == StageKind.protein,
    ),
    BaseTarget(:final int position) => _mrnaHolding(position),
  });

  /// Opens what a landing was opened on, standing still — the route's slide is
  /// the motion — and as the page it is, not a layer over it: see
  /// [_sheetLanded].
  void _arrive(VariantTarget landing) {
    if (!mounted) {
      return;
    }
    if ((landing is BaseTarget && _impact == null && _impactLoading) ||
        (landing is ResidueTarget &&
            _constraint == null &&
            _constraintLoading)) {
      _arrivalWaiting = landing;
      return;
    }
    switch (landing) {
      case ResidueTarget(:final int number):
        _revealCell(
          StageKind.protein,
          (AnatomyStage stage) => number - 1,
          arrival: true,
        );
      case BaseTarget(:final int position)
          when _model.stages[_stage].kind == StageKind.mrna:
        _revealCell(
          StageKind.mrna,
          (AnatomyStage stage) => stage.cellAt(position),
          arrival: true,
        );
      case BaseTarget(:final int position):
        _openRegionAt(position, arrival: true);
    }
  }

  /// Scrolls the page's cell into view and selects it, which opens its sheet.
  ///
  /// Selects and never lets go: a page with no track to open a sheet from
  /// traces the cell instead, and a second tap on the same codon — which is
  /// what [_select] would make of it — would have cleared a trace the reader
  /// was sent to.
  void _revealCell(
    StageKind kind,
    int Function(AnatomyStage) cellOf, {
    bool arrival = false,
  }) {
    if (!mounted) {
      return;
    }
    final AnatomyStage stage = _model.stages[_stage];
    final int cell = stage.kind == kind ? cellOf(stage) : -1;
    if (cell < 0 || cell >= stage.count) {
      return;
    }
    if (_scroll.hasClients && !_canvasViewport.isEmpty) {
      final AnatomyLayout layout = AnatomyLayout.forStage(
        stage,
        _canvasViewport,
        _canvasViewport,
      );
      final double y = layout.centreOf(cell).dy + _canvasInset;
      _scroll.jumpTo(
        (y - _canvasViewport.height * 0.3).clamp(
          0.0,
          _scroll.position.maxScrollExtent,
        ),
      );
    }
    final int position = stage.positionAt(cell);
    if (_maskedIndex == cell) {
      // Already the open subject; selecting it again would close it.
      return;
    }
    if (_supportsConstraint(stage) || _supportsImpact(stage)) {
      _selectCell(position, arrival: arrival);
    } else {
      setState(() => _tracer = Tracer(position));
    }
  }

  /// Selects the gene region around [position], opens its DNA and, once it
  /// has opened, lifts that base — the reader asked for this base by name.
  void _openRegionAt(int position, {bool arrival = false}) {
    if (!mounted || _stage != 0) {
      return;
    }
    setState(() {
      _clearSelection();
      _clearMask();
      _tracer = Tracer(position, asRun: true);
      _prepareSelection(position);
    });
    _pendingLift = (position, arrival);
    _openSelection(arrival: arrival);
  }

  void _liftPending() {
    final (int, bool)? pending = _pendingLift;
    _pendingLift = null;
    final AnatomySelection? selection = _selection;
    if (!mounted || pending == null || selection == null || !_selectionActive) {
      return;
    }
    final (int position, bool arrival) = pending;
    // A shortened intron keeps only its ends; a base from its middle is not
    // drawn, and the open region is as close as the page can get.
    final int cell = selection.stage.cellAt(position);
    if (cell < 0) {
      return;
    }
    final AnatomyLayout? layout = _shownLayout();
    if (layout != null && _scroll.hasClients) {
      final double y = layout.centreOf(cell).dy + _canvasInset;
      _scroll.jumpTo(
        (y - _canvasViewport.height * 0.3).clamp(
          0.0,
          _scroll.position.maxScrollExtent,
        ),
      );
    }
    _liftBase(cell, arrival: arrival);
  }

  void _settled(int stage, double offset) {
    if (stage == _stage) {
      _restoreScroll(offset);
    }
    _land(stage);
  }

  /// Copies the page's sequence as FASTA, or says why there is none to copy.
  void _copyPage() {
    final AnatomyStage stage = _model.stages[_stage];
    _copy(
      AnatomyFasta.ofStage(_model, widget.target, stage),
      AnatomyFasta.sizeOf(stage),
      unavailable:
          'Introns are drawn shortened here. Copy the mRNA, or a '
          'region from its DNA view.',
    );
  }

  void _copySelection() {
    final AnatomySelection? selection = _selection;
    if (selection == null) {
      return;
    }
    _copy(
      AnatomyFasta.region(
        selection.stage,
        widget.target,
        shortened: selection.shortened,
      ),
      AnatomyFasta.sizeOf(selection.stage),
      unavailable:
          'This intron is drawn shortened, so its DNA here is not '
          'the intron.',
    );
  }

  void _copy(String? fasta, String size, {required String unavailable}) {
    final ScaffoldMessengerState? messenger = ScaffoldMessenger.maybeOf(
      context,
    );
    messenger?.hideCurrentSnackBar();
    if (fasta == null) {
      messenger?.showSnackBar(SnackBar(content: Text(unavailable)));
      return;
    }
    unawaited(Clipboard.setData(ClipboardData(text: fasta)));
    unawaited(HapticFeedback.mediumImpact());
    messenger?.showSnackBar(SnackBar(content: Text('Copied $size as FASTA')));
  }

  void _restoreScroll(double offset) {
    if (offset <= 0 || !mounted || !_scroll.hasClients) {
      return;
    }
    // The transition has retained the transcript's full scroll extent. Restore
    // the offset in the same frame as its resting layout, before either paints.
    _scroll.jumpTo(offset.clamp(0.0, _scroll.position.maxScrollExtent));
  }

  /// Tap means select, and only select. Giving it a second meaning — advance —
  /// would make every mis-swipe feel like an accidental trace, and the tracer is
  /// the best thing on this screen.
  ///
  /// Tapping the same thing twice clears it, so the gesture is its own undo.
  void _select(int? position, {bool asRun = false}) {
    if (_supportsConstraint(_model.stages[_stage]) ||
        _supportsImpact(_model.stages[_stage])) {
      _selectCell(position);
      return;
    }
    setState(() {
      final Tracer? current = _tracer;
      if (position == null || _isSame(current, position, asRun)) {
        _clearSelection();
        _tracer = null;
      } else {
        unawaited(HapticFeedback.selectionClick());
        _tracer = Tracer(position, asRun: asRun);
        if (asRun && _model.stages[_stage].kind == StageKind.gene) {
          _prepareSelection(position);
        } else {
          _clearSelection();
        }
      }
    });
  }

  /// Whether a tap landed on what is already selected — the same residue, the
  /// same codon, or anywhere in the same feature. Selecting a thing and then
  /// tapping it again should let go of it wherever in that thing the second tap
  /// fell, including the far side of a split: both halves of the 5' UTR are
  /// lit, so both have to be able to release it.
  bool _isSame(Tracer? current, int position, bool asRun) {
    if (current == null || current.asRun != asRun) {
      return false;
    }
    final AnatomyStage stage = _model.stages[_stage];
    final int was = stage.cellAt(current.genomicPosition);
    final int now = stage.cellAt(position);
    if (!asRun) {
      if (current.genomicPosition == position) {
        return true;
      }
      // On the transcript a tap asks about the codon, so the tap that lets go
      // of it may land on any of its three bases.
      final List<int> codon = was < 0 || now < 0
          ? const <int>[]
          : stage.codonCellsAt(now);
      return codon.contains(was);
    }
    return was >= 0 && now >= 0 && stage.featureAt(was) == stage.featureAt(now);
  }

  @override
  Widget build(BuildContext context) {
    final bool structure = _stage == _structureIndex;
    final AnatomyStage? stage = structure ? null : _model.stages[_stage];
    final bool constraintEnabled = _supportsConstraint(stage);
    final Color ground = Theme.of(context).colorScheme.surface;
    // Nothing is traced on the fold: there are no squares there to have tapped.
    final Tracer? tracer = structure ? null : _tracer;
    final TracerStatus? status = _withImpact(
      _withBridge(
        tracer == null
            ? null
            : TracerReader.resolve(
                model: _model,
                tracer: tracer,
                stageIndex: _stage,
                // The page as last laid out: where a long region folds depends
                // on how wide it is drawn, and only the layout knows that.
                hidden: stage == null || _canvasViewport.isEmpty
                    ? null
                    : AnatomyLayout.forStage(
                        stage,
                        _canvasViewport,
                        _canvasViewport,
                      ).isHidden,
              ),
        stage,
      ),
      stage,
    );

    return CallbackShortcuts(
      // Innermost first. The sheet is over the page, so it goes before the
      // page does; only with nothing open does Escape leave the open region.
      // The panel carries this binding too, for when it holds focus, and the
      // two agree so that it does not matter which one answers.
      bindings: <ShortcutActivator, VoidCallback>{
        if (_panelVisible)
          const SingleActivator(LogicalKeyboardKey.escape): () =>
              unawaited(_dismissPanel())
        else if (_selection != null)
          const SingleActivator(LogicalKeyboardKey.escape): () =>
              unawaited(_returnToGene())
        else if (_maskedIndex != null)
          const SingleActivator(LogicalKeyboardKey.escape): () =>
              unawaited(_dismissPanel()),
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          appBar: _Header(
            gene: widget.record.gene,
            name: widget.target.display,
            onAbout: _openAbout,
            chrome: stage == null
                ? _PageChrome.structure(widget.target)
                : _selectionActive
                ? _PageChrome.ofStage(_selection!.stage)
                : _PageChrome.ofStage(stage),
            status: _maskedIndex != null ? null : _liftedStatus ?? status,
            hint: structure ? _foldSource : _selectionHint,
            onOpenDna: _selection != null && !_selectionActive && _stage == 0
                ? _openSelection
                : null,
            textScale: MediaQuery.textScalerOf(context)
                .scale(1)
                .clamp(1.0, 1.2),
            // Only once the region is open: a selection waiting on the
            // strip's action is still the gene page, and its header says so.
            onWholeGene: _selectionActive
                ? () => unawaited(_returnToGene())
                : null,
            // Only while Back goes to the list: a region the reader opened in
            // a landing is closed first, and says so.
            onReturn: widget.landing == null || _selectionHistory != null
                ? null
                : _leave,
            liftedBase: _liftedStatus != null,
          ),
          body: SafeArea(
            // No horizontal inset. The gene is the whole width of the phone,
            // because the thing being shown is how much of it there is — and a
            // margin around that is a frame around a quantity. The prose keeps
            // the screen's gutter up in the header, where the reading column
            // stays where every other screen puts it.
            //
            // The paginator is stacked over the grid rather than laid out under
            // it, because it is where you are and not what you are looking at:
            // the transcript page is about twice a phone and scrolls, and the
            // dots have to stay put while it does.
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints bounds) {
                final double sheetSpace = math.max(
                  0,
                  bounds.maxHeight - ConstraintToolbar.height - _paginatorBand,
                );
                _panelHeight =
                    sheetSpace *
                    (_sheet.isAttached
                        ? _sheet.size
                        : ConstraintPanel.initialSize);
                // The box a grid page is drawn in, as the canvas below works
                // it out.
                final Size page = Size(
                  bounds.maxWidth,
                  math.max(
                    0,
                    bounds.maxHeight -
                        _canvasInset -
                        _paginatorBand -
                        (constraintEnabled ? ConstraintToolbar.height : 0),
                  ),
                );
                // A residue page ends at its toolbar; only the others pass
                // under the stage bar.
                final bool scrolls = !constraintEnabled && _scrolls(page);
                return Listener(
                  onPointerDown: (PointerDownEvent event) {
                    _swipeOrigin = event.position;
                    _swipeTravel = Offset.zero;
                    _verticalSwipe = false;
                  },
                  onPointerMove: _trackSwipe,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onHorizontalDragStart: (_) {},
                    onHorizontalDragEnd: _finishSwipe,
                    child: Stack(
                      fit: StackFit.expand,
                      children: <Widget>[
                        LayoutBuilder(
                          builder:
                              (
                                BuildContext context,
                                BoxConstraints constraints,
                              ) {
                                final double toolbarHeight = constraintEnabled
                                    ? ConstraintToolbar.height
                                    : 0;
                                final Size viewport = Size(
                                  constraints.maxWidth,
                                  math.max(
                                    0,
                                    constraints.maxHeight -
                                        _canvasInset -
                                        _paginatorBand -
                                        toolbarHeight,
                                  ),
                                );
                                _canvasViewport = viewport;
                                if (structure) {
                                  return Padding(
                                    padding: const EdgeInsets.only(
                                      top: _canvasInset,
                                    ),
                                    // The model keeps its own drag gestures for rotation.
                                    child: StructureView(
                                      viewport: viewport,
                                      target: widget.target,
                                      legend: _foldLegend(context),
                                    ),
                                  );
                                }
                                // A residue page ends at its toolbar, not under the
                                // pill: a long protein scrolls, and a strip of tiles
                                // between the toolbar and the pill reads as a second
                                // grid rather than as the one continuing.
                                return Padding(
                                  padding: EdgeInsets.only(
                                    bottom: constraintEnabled
                                        ? toolbarHeight + _paginatorBand
                                        : 0,
                                  ),
                                  child: SingleChildScrollView(
                                    controller: _scroll,
                                    physics:
                                        _selectionActive &&
                                            (!_selectionProgress.isCompleted ||
                                                _selectionReturning)
                                        ? const NeverScrollableScrollPhysics()
                                        : const ClampingScrollPhysics(),
                                    child: Column(
                                      children: <Widget>[
                                        const SizedBox(height: _canvasInset),
                                        if (_selectionActive)
                                          AnatomySelectionCanvas(
                                            model: _model,
                                            selection: _selection!,
                                            viewport: viewport,
                                            progress: _selectionProgress,
                                            tracer: tracer!,
                                            resting:
                                                _selectionProgress
                                                    .isCompleted &&
                                                !_selectionReturning,
                                            returning: _selectionReturning,
                                            sourceScrollOffset:
                                                _geneScrollOffset,
                                            targetScrollOffset:
                                                _detailScrollOffset,
                                            lifted: _liftedBase,
                                            onLongPress: _copySelection,
                                            onBaseTapped: _liftBase,
                                          )
                                        else
                                          AnatomyCanvas(
                                            model: _model,
                                            stageIndex: _stage,
                                            viewport: viewport,
                                            tracer: tracer,
                                            status: status,
                                            constraint: constraintEnabled
                                                ? _constraint
                                                : null,
                                            conservation: _conservation,
                                            maskedIndex: _maskedIndex,
                                            masking: _mask,
                                            bridges: _bridgesOn(stage),
                                            marks: constraintEnabled
                                                ? _residueMarks
                                                : const <int, ClinVarMark>{},
                                            onTapped: _select,
                                            onLongPress: _copyPage,
                                            sourceScrollOffset:
                                                _sourceScrollOffset,
                                            onSettled: _settled,
                                          ),
                                        // The band again, at the end of the scroll: the
                                        // transcript page runs past the bottom of the screen,
                                        // and its last row has to clear the pill the same way a
                                        // fitted stage's does — and, since it scrolls, the fade
                                        // above the pill too. A residue page's scroll already
                                        // stops above the band, so it only clears the panel.
                                        SizedBox(
                                          height: constraintEnabled
                                              ? (_panelVisible
                                                    ? _panelHeight
                                                    : 0)
                                              // Room for a base near the
                                              // end to rise above an open
                                              // sheet, as a residue can.
                                              : (scrolls
                                                        ? _fadeBand
                                                        : _paginatorBand) +
                                                    (_panelVisible
                                                        ? _panelHeight
                                                        : 0),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                        ),
                        if (_scrubs(page))
                          Positioned(
                            right: 0,
                            top: _canvasInset,
                            bottom:
                                _paginatorBand +
                                (constraintEnabled
                                    ? ConstraintToolbar.height
                                    : 0),
                            width: SequenceScrubber.width,
                            child: SequenceScrubber(
                              key: ValueKey<Object?>(_shownStage),
                              controller: _scroll,
                              labelAt: _rowLabelAt,
                              landmarks: _landmarks(),
                            ),
                          ),
                        if (constraintEnabled)
                          Positioned(
                            bottom: _paginatorBand,
                            left: 0,
                            right: 0,
                            child: ColoredBox(
                              color: ground,
                              child: ConstraintToolbar(
                                conservation: _conservation,
                                onChanged: (bool value) =>
                                    setState(() => _conservation = value),
                                onClinVar: _residueMarks.isEmpty
                                    ? null
                                    : () => unawaited(_openVariants()),
                              ),
                            ),
                          ),
                        // The one page that scrolls is the one page the band cannot keep
                        // clear: the transcript is about twice a phone, so at most
                        // offsets there are live bases passing under the pill however
                        // much room its own last row is given. A fade into the ground
                        // answers both halves of that — the pill keeps a legible field
                        // to sit on, and the edge of a page that continues below the
                        // screen stops pretending to be the end of it. On every fitted
                        // stage it falls on empty background and is invisible.
                        //
                        // Where the page does pass under it, it is solid from the
                        // stage bar's top edge down. Solid only at 0.65 of the way,
                        // it left the letters behind the stage names a third visible.
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          height: _fadeBand,
                          child: IgnorePointer(
                            child: DecoratedBox(
                              key: const ValueKey<String>('stage-bar-fade'),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: <Color>[
                                    ground.withValues(alpha: 0),
                                    ground,
                                  ],
                                  stops: scrolls
                                      ? const <double>[
                                          0,
                                          (_fadeBand - _stageBarTop) /
                                              _fadeBand,
                                        ]
                                      : const <double>[0, 0.65],
                                ),
                              ),
                            ),
                          ),
                        ),
                        if (_inspector(sheetSpace) case final Widget panel)
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom:
                                _paginatorBand +
                                (constraintEnabled
                                    ? ConstraintToolbar.height
                                    : 0),
                            top: 0,
                            child: CallbackShortcuts(
                              bindings: <ShortcutActivator, VoidCallback>{
                                const SingleActivator(
                                  LogicalKeyboardKey.escape,
                                ): () =>
                                    unawaited(_dismissPanel()),
                              },
                              child: Focus(
                                autofocus: true,
                                child: Align(
                                  alignment: Alignment.bottomCenter,
                                  child: panel,
                                ),
                              ),
                            ),
                          ),
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: AppSpacing.lg,
                          child: SizedBox(
                            height: StageBar.height,
                            child: Center(
                              child: Semantics(
                                container: true,
                                label: _selectionActive
                                    ? 'DNA detail on page 1 of $_pageCount. '
                                          'Return to the whole gene to continue.'
                                    : 'Page ${_stage + 1} of $_pageCount',
                                onIncrease:
                                    !_selectionActive && _stage < _pageCount - 1
                                    ? () => _step(1)
                                    : null,
                                onDecrease: _stage > 0 ? () => _step(-1) : null,
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: StageBar(
                                    labels: StageBar.labelsFor(_model),
                                    index: _stage,
                                    locked: _selectionActive,
                                    onSelect: (int page) =>
                                        _step(page - _stage),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// A gene's ClinVar records read against the tracks that were loaded with
/// them, and the lookups the walk makes into that reading.
///
/// A sheet rebuilds on every frame of a drag, and a gene like dystrophin has
/// thousands of records, so the records at each residue and each base are
/// found once here rather than by scanning the whole list per frame.
final class _ClinVarReading {
  _ClinVarReading(
    this.snapshot,
    this.impact,
    this.constraint,
    this.all, {
    required bool reversed,
  }) {
    for (final VariantEvidence e in all ?? const <VariantEvidence>[]) {
      (byPosition[e.variant.position] ??= <VariantEvidence>[]).add(e);
      if (e.variant.residue case final int residue) {
        (byResidue[residue] ??= <VariantEvidence>[]).add(e);
      }
    }
    final int Function(VariantEvidence, VariantEvidence) order =
        VariantEvidence.transcriptOrder(reversed: reversed);
    for (final List<VariantEvidence> records in byResidue.values) {
      records.sort(order);
    }
    for (final List<VariantEvidence> records in byPosition.values) {
      records.sort(order);
    }
  }

  final GeneClinVar snapshot;
  final GeneImpact? impact;
  final ProteinConstraint? constraint;

  /// Null where the snapshot does not match the record on screen.
  final List<VariantEvidence>? all;

  /// By precursor residue number, and by record position.
  final Map<int, List<VariantEvidence>> byResidue =
      <int, List<VariantEvidence>>{};
  final Map<int, List<VariantEvidence>> byPosition =
      <int, List<VariantEvidence>>{};

  /// Each residue with records, keyed by precursor index, with its most
  /// severe group.
  late final Map<int, ClinVarMark> marks = <int, ClinVarMark>{
    for (final MapEntry<int, List<VariantEvidence>> entry in byResidue.entries)
      entry.key - 1: ClinVarMark(
        ClinVarGroup.mostSevere(entry.value.map((e) => e.variant.group)),
        entry.value.length,
      ),
  };
}

/// The four things the header reads off a page.
///
/// [_Header] used to take an [AnatomyStage] and reach into it, which quietly
/// made "a page" and "a grid of cells" the same idea. The fold is a page and is
/// not a grid, so the four fields it shares with every stage are named here
/// instead. Nothing is lost by it: the header only ever wanted these.
final class _PageChrome {
  const _PageChrome({
    required this.label,
    required this.count,
    required this.unit,
    required this.shortUnit,
    required this.sentence,
  });

  _PageChrome.ofStage(AnatomyStage stage)
    : label = stage.label,
      count = stage.shownCount,
      unit = stage.unit,
      shortUnit = stage.shortUnit,
      sentence = stage.sentence;

  /// The fold, whose numbers are the crystal structure's and not the record's.
  ///
  /// Insulin's fifty-one residues against the eighty-two counted one page
  /// earlier: the thirty-one of the C-peptide are gone, which is the arithmetic
  /// the sentence is about and the reason the count is worth carrying over to
  /// this page at all. Every protein has its own version of that subtraction
  /// and some of them are not subtractions at all — dystrophin's page counts
  /// 238 of 3,685 because that is all anyone has ever solved — so the numbers
  /// and the sentence come from the catalog rather than from here.
  _PageChrome.structure(ProteinTarget target)
    : label = target.structure.label,
      count = target.structure.count,
      unit = target.structure.unit,
      shortUnit = target.structure.unit == 'residues' ? 'aa' : 'bp',
      sentence = target.structure.sentence;

  final String label;
  final int count;

  /// The unit in words, for a screen reader.
  final String unit;

  /// The unit as the badge sets it: bp, nt or aa.
  final String shortUnit;
  final String sentence;
}

/// Navigation, name, count and prose, in one fixed block above the grid.
///
/// Two rows and 96 points. Forty-four is the row the back arrow, the name and
/// the badge share — the touch target the arrow needs. Fifty-two is the prose:
/// two lines of a caption, or a traced feature's line with its fact under it.
///
/// Fifty-two rather than the thirty-nine those same three lines *fit* in.
/// They did fit, at 1.05 leading and three points between the line and the
/// note under it, and the result was a slab: the reader could not see where
/// the feature's name stopped and its explanation started, because nothing
/// between them said so. Space is the only thing that says so, and there is no
/// rate at which it can be bought more cheaply — a smaller note or a quieter
/// one still runs three points under the line it belongs to. So the thirteen
/// points come off the grid, and they come off it in every state, including
/// the untraced one where the room below the sentence is simply room.
///
/// Its height stays fixed across selection states, with extra room reserved
/// up front when the reader enlarges text. The canvas is sized by
/// subtracting what the header leaves, so a header that grew a line when a
/// sentence wrapped would resize the picture under the reader mid-sentence —
/// which is why every line below is boxed rather than left to the font.
class _Header extends StatelessWidget implements PreferredSizeWidget {
  const _Header({
    required this.gene,
    required this.name,
    required this.chrome,
    required this.status,
    this.onAbout,
    this.hint,
    this.onOpenDna,
    this.onWholeGene,
    this.onReturn,
    this.liftedBase = false,
    this.textScale = 1,
  });

  final String gene;

  /// The protein's name, as the catalog lists it. The same on every page: the
  /// header says what is being walked and the stage bar says where.
  final String name;

  /// Opens the record's sources and copy actions.
  final VoidCallback? onAbout;
  final _PageChrome chrome;
  final TracerStatus? status;
  final String? hint;
  final VoidCallback? onOpenDna;
  final VoidCallback? onWholeGene;

  /// Back to the ClinVar overview under a landing. It stands where "Whole gene"
  /// would, ahead of it, whenever Back goes to the list: the header names
  /// where Back goes.
  final VoidCallback? onReturn;

  /// Whether the status is a base lifted out of an open region.
  final bool liftedBase;
  final double textScale;

  /// The row carrying the back arrow, the name and the badge.
  static const double toolbarHeight = 44;

  @override
  Size get preferredSize =>
      Size.fromHeight(toolbarHeight + _ContextStrip.height * textScale);

  /// A labelled way back, where the title would be.
  Widget _back(
    ThemeData theme,
    String label,
    VoidCallback onPressed, {
    Key? key,
    String? spoken,
  }) {
    final Widget button = TextButton.icon(
      key: key,
      onPressed: onPressed,
      icon: const Icon(Icons.arrow_back_rounded, size: 18),
      label: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(label, maxLines: 1),
      ),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        foregroundColor: theme.colorScheme.onSurface,
      ),
    );
    return Align(
      alignment: Alignment.centerLeft,
      child: spoken == null
          ? button
          : Semantics(
              label: spoken,
              button: true,
              excludeSemantics: true,
              onTap: onPressed,
              child: button,
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.2,
      child: AppBar(
        toolbarHeight: toolbarHeight,
        // The gutter the strip below uses, and the one the title needs on a
        // deep link: `/gene` can be opened with nothing to go back to, and at
        // zero the gene symbol was left touching the edge of the screen.
        titleSpacing: AppSpacing.lg,
        automaticallyImplyLeading: onWholeGene == null && onReturn == null,
        // The strip below reads the whole state aloud as one live region, so the
        // pieces up here would only be a second, stuttering copy of it.
        title: onReturn != null
            ? _back(
                theme,
                'ClinVar',
                onReturn!,
                key: const ValueKey<String>('walk-return-clinvar'),
                spoken: 'Back to ClinVar records',
              )
            : onWholeGene != null
            ? _back(theme, 'Whole gene', onWholeGene!)
            : Semantics(
                button: true,
                label: 'About $gene, $name: sources and copy',
                excludeSemantics: true,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onAbout,
                  // One baseline for the three of them. Centred, the name sat
                  // three points above the line the symbol and the mark share,
                  // and the mark read as hanging under a word it belongs to.
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: <Widget>[
                      Text(gene, style: theme.textTheme.titleLarge),
                      Flexible(
                        child: Text(
                          // The catalog's name for the protein, which gives
                          // way before the symbol or the badge does. The
                          // record's own `/product` is the caption's to spell
                          // out.
                          '  ·  $name',
                          style: theme.textTheme.labelSmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      // Its own mark, not the name's last letter.
                      const SizedBox(width: 4),
                      Icon(
                        Icons.info_outline,
                        size: 14,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
              ),
        actions: <Widget>[
          // Centred, because `AppBar` stretches its actions to the toolbar's full
          // height and a pill drawn 44 points tall is not a badge any more.
          ExcludeSemantics(
            child: Center(child: _CountBadge(chrome: chrome)),
          ),
          const SizedBox(width: AppSpacing.lg),
        ],
        bottom: _ContextStrip(
          chrome: chrome,
          status: status,
          hint: hint,
          // An open region is explained by the bases it shows, not by a note
          // under its name — until a base is lifted, which has one.
          showNote: onWholeGene == null || liftedBase,
          onOpenDna: onOpenDna,
          textScale: textScale,
        ),
      ),
    );
  }
}

/// The count, as a thing you read rather than a thing you are shown.
class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.chrome});

  final _PageChrome chrome;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: <Widget>[
          // Two pieces of text rather than one interpolated string: the number
          // is the part that changes on every swipe and it carries its own
          // weight for that, while the unit is a label on it.
          Text(
            grouped(chrome.count),
            style: AppTypography.anatomyCount(theme.colorScheme.onSurface),
          ),
          const SizedBox(width: 5),
          Text(chrome.shortUnit, style: theme.textTheme.labelSmall),
        ],
      ),
    );
  }
}

/// The one sentence, and the note under it while something is traced.
///
/// The block is spent two ways and both of them are three lines' worth. With
/// nothing traced the stage's sentence gets two, because the longest of them —
/// "The introns are cut out. The 59 bases before and 73 after are never
/// translated." — is a near thing on a phone. With something traced the first line is the tracer's and the two
/// under it are its note, which is written as two lines of small type and
/// truncates into nonsense at one: "cut out of the transcript before it leaves
/// the…" is the half of that sentence that says nothing.
///
/// The note is set tighter than the line above it rather than smaller again.
/// It is already the smallest type in the app, and the hierarchy the reader
/// needs — name first, fact second — is carried by the point size and the
/// colour it already has.
class _ContextStrip extends StatelessWidget implements PreferredSizeWidget {
  const _ContextStrip({
    required this.chrome,
    required this.status,
    this.hint,
    this.showNote = true,
    this.onOpenDna,
    this.textScale = 1,
  });

  final _PageChrome chrome;
  final TracerStatus? status;
  final String? hint;

  /// Whether the traced feature's note may fill the second line when there
  /// is no [hint].
  final bool showNote;

  /// Opens the selected region into its DNA, or null where nothing is waiting
  /// to be opened.
  final VoidCallback? onOpenDna;
  final double textScale;

  /// Three lines at their worst, plus the air that makes them three lines
  /// rather than one block: 12pt of line, [_gap], and two 11pt lines of note,
  /// at the leadings below.
  ///
  /// Fifty-two was that sum with three points spare, and it was three points
  /// short of the truth: the row the line sits in is as tall as its tallest
  /// child, and where a region is waiting to be opened that is the DNA pill,
  /// which is set larger than the line it shares. Nothing reached two lines of
  /// note beside the pill until a tapped run started answering with what it
  /// scores, and then the strip overflowed by four points. Fifty-six is the
  /// row at the pill's height rather than the line's, with the same spare.
  static const double height = 52;

  /// The prose, and the note under it. Boxed here rather than left to the
  /// theme because [height] is computed from them.
  static const double _lineSize = 12;
  static const double _lineHeight = 1.35;
  static const double _noteSize = 11;
  static const double _noteHeight = 1.3;

  /// Between the feature's name and what the feature is.
  ///
  /// The one measurement on this screen that is doing nothing and has to be
  /// here anyway. The note is already smaller and quieter than the line above
  /// it and that was not enough: set three points under it, it read as the
  /// same sentence continuing, and the reader had to parse the block to find
  /// out otherwise. The gap is what makes them two things.
  static const double _gap = 4;

  /// How far in from the right edge a tap opens the selected region's DNA:
  /// the pill, the gutter beside it and a little to its left, down the whole
  /// strip.
  static const double _openDnaReach = 88;

  @override
  Size get preferredSize => Size.fromHeight(height * textScale);

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final TracerStatus? tracer = status;
    final String? below = hint ?? (showNote ? tracer?.note : null);
    final Color accent = theme.colorScheme.primary;

    return Semantics(
      liveRegion: true,
      label:
          '${grouped(chrome.count)} ${chrome.unit}, ${chrome.label}. '
          '${tracer?.line ?? chrome.sentence}'
          '${below == null ? '' : ' $below'}',
      excludeSemantics: true,
      // The strip is read as one, which folds the pill's own button into it;
      // the one thing here that can be pressed is offered on it instead.
      customSemanticsActions: onOpenDna == null
          ? null
          : <CustomSemanticsAction, VoidCallback>{
              const CustomSemanticsAction(label: _OpenDnaAction.spoken):
                  onOpenDna!,
            },
      child: SizedBox(
        height: height * textScale,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            // A tap beside the pill is a tap on it: the pill is 24 points tall
            // in a strip of 52, and nothing else here answers a tap. Laid under
            // the prose, which lets taps through, and under the pill, which
            // keeps its own.
            if (onOpenDna != null)
              Positioned(
                top: 0,
                right: 0,
                bottom: 0,
                width: _openDnaReach,
                child: GestureDetector(
                  key: const ValueKey<String>('open-dna-reach'),
                  behavior: HitTestBehavior.opaque,
                  excludeFromSemantics: true,
                  onTap: onOpenDna,
                ),
              ),
            Padding(
              // Sixteen, not the screen's twenty-four: the block is one line
              // of prose held to one or two lines, and the eight points either
              // side are the difference between the longest sentence fitting
              // and being cut off mid-clause.
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              // The heights above are reserved, not measured, so a reader who
              // has turned type up would overflow them. Clamped rather than
              // allowed to resize the header, because the canvas is sized off
              // what the header leaves and a header that moves moves the
              // picture.
              child: MediaQuery.withClampedTextScaling(
                maxScaleFactor: 1.2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Expanded(
                          child: IgnorePointer(
                            child: Text(
                              // While a base is traced its fate replaces the
                              // generic line. Nothing else on the screen moves
                              // — no panel, no reflow.
                              tracer?.line ?? chrome.sentence,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontSize: _lineSize,
                                height: _lineHeight,
                                color: tracer == null
                                    ? theme.colorScheme.onSurfaceVariant
                                    : theme.colorScheme.onSurface,
                              ),
                              maxLines: tracer == null ? 2 : 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        if (onOpenDna != null)
                          _OpenDnaAction(
                            key: const ValueKey<String>('open-dna'),
                            accent: accent,
                            // What has just been named. A second region picked
                            // without letting go of the first keeps the action
                            // on screen, and it should announce itself again.
                            flashOn: tracer?.line,
                            onTap: onOpenDna!,
                          ),
                      ],
                    ),
                    // What the feature is, under what it is called. Only ever
                    // shown for a selection: with nothing traced the stage's
                    // own sentence is already the general statement, and a
                    // second one under it would be two voices saying the same
                    // thing.
                    if (below != null) ...<Widget>[
                      const SizedBox(height: _gap),
                      IgnorePointer(
                        child: Text(
                          below,
                          style: AppTypography.anatomyNote(
                            theme.colorScheme.onSurfaceVariant,
                          ).copyWith(fontSize: _noteSize, height: _noteHeight),
                          // One line beside the DNA pill, two without it.
                          // [height] buys a line and two notes at the line's
                          // own height, and the pill is 24 points of tap target
                          // on a 16-point line — eight points it has been
                          // quietly taking out of the second note line since it
                          // was added. Nothing reached two lines there until a
                          // tapped run started answering with what it scores;
                          // this is the strip refusing to overflow rather than
                          // the header growing to 100 and breaking its budget.
                          //
                          // A hint is one line too: it sits under a sentence
                          // that may itself take two, and the strip does not
                          // grow.
                          maxLines: onOpenDna == null && hint == null ? 2 : 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The one action the strip carries: open the selected region as DNA.
///
/// A pill rather than bare type. The strip is prose and a filled control would
/// outweigh a sentence — but this is the only thing on the page waiting to be
/// pressed, and drawn as type at the top of its box it read as the end of the
/// caption and sat directly under the count badge. Tinted, centred on the line
/// it shares and set two points larger, it reads as the offer it is.
///
/// It announces itself once, on the highlight it lands in: the tint fades back
/// as the label arrives from the right. One flash, no loop — a control that
/// keeps moving in a fixed header is a control that has to be read past.
class _OpenDnaAction extends StatefulWidget {
  const _OpenDnaAction({
    required this.accent,
    required this.onTap,
    this.flashOn,
    super.key,
  });

  final Color accent;
  final VoidCallback onTap;

  /// What is currently named on the line beside it. A second region picked
  /// without letting go of the first leaves this widget in the tree, so the
  /// flash is replayed off this rather than off the mount.
  final String? flashOn;

  /// The label, and the air either side of it inside the pill.
  static const double _size = 15;
  static const double _padX = 7;
  static const double _padY = 3;

  /// The tint the pill settles at, and the one it arrives on.
  static const double _rest = 0.12;
  static const double _flash = 0.28;

  /// What it is called aloud, here and on the strip that carries it.
  static const String spoken = 'Open the selected region as DNA';

  @override
  State<_OpenDnaAction> createState() => _OpenDnaActionState();
}

class _OpenDnaActionState extends State<_OpenDnaAction>
    with SingleTickerProviderStateMixin {
  late final AnimationController _arrival = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
    value: 1,
  );

  /// Whether the arrival has been played for the region on screen. The first
  /// one runs from here rather than from [initState], where the media query
  /// that says whether it may run at all is not available yet.
  bool _arrived = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_arrived) {
      _arrived = true;
      _flash();
    }
  }

  @override
  void didUpdateWidget(_OpenDnaAction old) {
    super.didUpdateWidget(old);
    if (old.flashOn != widget.flashOn) {
      _flash();
    }
  }

  void _flash() {
    if (MediaQuery.disableAnimationsOf(context)) {
      _arrival.value = 1;
      return;
    }
    unawaited(_arrival.forward(from: 0));
  }

  @override
  void dispose() {
    _arrival.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Semantics(
      button: true,
      label: _OpenDnaAction.spoken,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 44, minHeight: 24),
          child: Padding(
            padding: const EdgeInsets.only(left: AppSpacing.sm),
            child: Align(
              alignment: Alignment.centerRight,
              widthFactor: 1,
              child: AnimatedBuilder(
                animation: _arrival,
                builder: (BuildContext context, Widget? label) {
                  final double t = Curves.easeOutCubic.transform(
                    _arrival.value,
                  );
                  return DecoratedBox(
                    decoration: BoxDecoration(
                      color: widget.accent.withValues(
                        alpha:
                            _OpenDnaAction._flash +
                            (_OpenDnaAction._rest - _OpenDnaAction._flash) * t,
                      ),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: _OpenDnaAction._padX,
                        vertical: _OpenDnaAction._padY,
                      ),
                      child: Opacity(
                        opacity: t,
                        child: Transform.translate(
                          offset: Offset(4 * (1 - t), 0),
                          child: label,
                        ),
                      ),
                    ),
                  );
                },
                child: Text(
                  'DNA \u203a',
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontSize: _OpenDnaAction._size,
                    height: 1,
                    color: widget.accent,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
