import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/biology/gene_record.dart';
import '../../../../core/catalog/protein_target.dart';
import '../../../../core/network/track_source.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/anatomy/anatomy_scene.dart';
import '../../../../shared/anatomy/anatomy_selection.dart';
import '../../../../shared/anatomy/anatomy_stages.dart';
import '../../../../shared/format.dart';
import '../../../gene_lookup/domain/usecases/fetch_gene.dart';
import '../../mutate/presentation/edit_ripple.dart';
import '../../mutate/presentation/mutate_cubit.dart';
import '../../mutate/presentation/mutate_screen.dart';
import '../../presentation/lab_anatomy_view.dart';
import '../../presentation/lab_protein_picker.dart';
import '../../presentation/lab_record.dart';
import '../domain/guide_finder.dart';
import '../domain/repair.dart';
import 'guide_sheet.dart';

/// `/lab/crispr/<slug>`: one protein's record, fetched through the lab's own
/// tracks, and the places a nuclease can be aimed at it.
class CrisprRoute extends StatelessWidget {
  const CrisprRoute({required this.slug, super.key});

  final String slug;

  @override
  Widget build(BuildContext context) => LabTargetLoader(
    slug: slug,
    builder: (BuildContext context, ProteinTarget target) => LabRecordView(
      target: target,
      title: 'CRISPR · ${target.display}',
      builder: (BuildContext context, GeneRecord record) =>
          CrisprScreen(target: target, record: record),
    ),
  );
}

/// Which page the canvas shows.
enum CrisprView {
  /// The whole gene, drawn as its regions: tap one to open it.
  gene,

  /// One region opened into its DNA, with every cut in it marked between the
  /// bases it falls between.
  region,
}

/// Find where a guide can cut this gene, then choose what the cell does with
/// the break.
///
/// The gene page and a region opened into its letters are the walk's own
/// pages, laid out by the shared layout and drawn by the shared painter, which
/// draws the cuts too. A cut is a mark in the mortar between two bases; tapping
/// one opens the guides that cut there, and choosing one opens the three
/// repair paths. Whatever is chosen becomes a [SequenceEdit] and is shown
/// through the lab's own mutate screen, so a repair is read exactly the way an
/// edit made by hand is read.
///
/// Off-target sites are not searched, anywhere, and the screen says so. No
/// guide is called safe.
class CrisprScreen extends StatefulWidget {
  const CrisprScreen({required this.target, required this.record, super.key});

  final ProteinTarget target;
  final GeneRecord record;

  @override
  State<CrisprScreen> createState() => _CrisprScreenState();
}

class _CrisprScreenState extends State<CrisprScreen>
    with SingleTickerProviderStateMixin {
  late final AnatomyModel _model = AnatomyModel.derive(
    widget.record,
    chain: widget.target.chain,
  );

  /// Every site the record offers. Found once, when the screen opens: it is
  /// one pass over the record's bases, and the record is already here.
  late final List<Guide> _guides = GuideFinder.find(widget.record);

  CrisprView _view = CrisprView.gene;

  /// The region opened into its DNA, and whether the opening is still to play.
  AnatomySelection? _region;
  bool _opening = false;

  /// The cut the sheet is about, as the record position 3' of it.
  int? _cut;

  /// The guide chosen there.
  Guide? _guide;

  final DraggableScrollableController _sheet = DraggableScrollableController();
  late final AnimationController _slide = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  );
  late final Animation<Offset> _slideIn = Tween<Offset>(
    begin: const Offset(0, 1),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _slide, curve: Curves.easeOutCubic));

  Object? _sceneKey;
  AnatomyScene? _scene;

  @override
  void dispose() {
    _slide.dispose();
    _sheet.dispose();
    super.dispose();
  }

  AnatomyStage get _stage =>
      _view == CrisprView.region ? _region!.stage : _model.stages.first;

  /// The guides cutting at [position], in the order the finder found them.
  List<Guide> _guidesAt(int position) => <Guide>[
    for (final Guide guide in _guides)
      if (guide.cutPosition == position) guide,
  ];

  /// The cells this page draws a cut before.
  ///
  /// Every cut inside an opened region — there are a great many, and that is
  /// the point: an NGG turns up every few bases. On the whole gene, where a
  /// cell is two points across and 348 marks would be a texture rather than a
  /// place, only the chosen guide's.
  List<int> _breaks() {
    final AnatomyStage stage = _stage;
    final Guide? chosen = _guide;
    final Iterable<Guide> drawn = _view == CrisprView.region
        ? _guides
        : <Guide>[?chosen];
    final Set<int> cells = <int>{};
    for (final Guide guide in drawn) {
      final int cell = stage.cellAt(guide.cutPosition);
      if (cell > 0) {
        cells.add(cell);
      }
    }
    return cells.toList()..sort();
  }

  AnatomySelection? _regionAt(int position) {
    final AnatomyStage gene = _model.stages.first;
    return gene.kind == StageKind.gene && gene.cellAt(position) >= 0
        ? AnatomySelection.of(_model, position)
        : null;
  }

  void _openRegion(int position) {
    final AnatomySelection? region = _regionAt(position);
    if (region == null) {
      return;
    }
    setState(() {
      _region = region;
      _opening = true;
      _view = CrisprView.region;
    });
  }

  void _openCut(int position) {
    setState(() {
      _cut = position;
      _guide = _guidesAt(position).length == 1
          ? _guidesAt(position).single
          : null;
    });
    _slide.forward();
  }

  void _closeSheet() {
    _slide.reverse();
    setState(() {
      _cut = null;
      _guide = null;
    });
  }

  void _backToGene() => setState(() {
    _view = CrisprView.gene;
    _region = null;
    _opening = false;
  });

  void _tapped(int cell) {
    final AnatomyScene? scene = _scene;
    if (scene == null) {
      return;
    }
    final AnatomyStage stage = scene.isTransition ? scene.to : scene.from;
    switch (_view) {
      case CrisprView.gene:
        _openRegion(stage.positionAt(cell));
      case CrisprView.region:
        _openCut(stage.positionAt(cell));
    }
  }

  /// The repair, made on the record and shown the way every other edit is.
  Future<void> _repair(Repair repair) async {
    final ProteinTarget target = widget.target;
    final FetchGene fetchGene = context.read<FetchGene>();
    final TrackSource tracks = context.read<TrackSource>();
    _closeSheet();
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => BlocProvider<MutateCubit>(
          create: (BuildContext context) => MutateCubit(
            target: target,
            fetchGene: fetchGene,
            tracks: tracks,
            applying: repair.edit,
          )..load(),
          child: MutateScreen(target: target),
        ),
      ),
    );
  }

  AnatomyScene _sceneFor(Size viewport) {
    final Object key = (_view, identityHashCode(_region), _opening, viewport);
    final AnatomyScene? held = _scene;
    if (held != null && key == _sceneKey) {
      return held;
    }
    final AnatomyScene scene = switch (_view) {
      CrisprView.gene => AnatomyScene.resting(
        model: _model,
        index: 0,
        canvas: canvasFor(<AnatomyStage>[_model.stages.first], viewport),
        viewport: viewport,
      ),
      CrisprView.region => AnatomyScene.selection(
        model: _model,
        selected: _region!.stage,
        canvas: canvasFor(<AnatomyStage>[
          _model.stages.first,
          _region!.stage,
        ], viewport),
        viewport: viewport,
        resting: !_opening,
      ),
    };
    _sceneKey = key;
    _scene = scene;
    return scene;
  }

  String _lead() {
    if (_guides.isEmpty) {
      return 'No guide can be aimed at this record: nothing in it reads '
          'twenty bases and then an NGG.';
    }
    if (_view == CrisprView.gene) {
      return 'Tap a region of the gene to open its bases and see where a '
          'nuclease can cut it.';
    }
    final AnatomyStage region = _region!.stage;
    final int here = _guides
        .where((Guide guide) => region.cellAt(guide.cutPosition) >= 0)
        .length;
    if (here == 0) {
      return 'No guide cuts inside ${region.label}.';
    }
    return '${spelledLeading(here)} ${here == 1 ? 'guide cuts' : 'guides cut'} '
        'inside ${region.label}. Tap a cut to see it.';
  }

  int? get _maskedCell {
    final int? cut = _cut;
    if (_view != CrisprView.region || cut == null) {
      return null;
    }
    final int cell = _region!.stage.cellAt(cut);
    return cell >= 0 ? cell : null;
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final int? cut = _cut;
    return Scaffold(
      appBar: AppBar(title: Text('CRISPR · ${widget.target.display}')),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenPadding,
                AppSpacing.sm,
                AppSpacing.screenPadding,
                0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      _lead(),
                      key: const ValueKey<String>('crispr-lead'),
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    GuideSheet.offTarget,
                    key: const ValueKey<String>('crispr-off-target'),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (_view == CrisprView.region)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.screenPadding,
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    key: const ValueKey<String>('crispr-whole-gene'),
                    onPressed: _backToGene,
                    child: const Text('Whole gene'),
                  ),
                ),
              ),
            const SizedBox(height: AppSpacing.sm),
            Expanded(
              child: LayoutBuilder(
                builder: (BuildContext context, BoxConstraints box) {
                  final Size viewport = Size(box.maxWidth, box.maxHeight);
                  final AnatomyScene scene = _sceneFor(viewport);
                  return Stack(
                    children: <Widget>[
                      Positioned.fill(
                        child: SingleChildScrollView(
                          child: LabAnatomyView(
                            key: const ValueKey<String>('crispr-canvas'),
                            scene: scene,
                            onTap: _tapped,
                            breaks: _breaks(),
                            maskedIndex: _maskedCell,
                            onSettled: _opening
                                ? () => setState(() => _opening = false)
                                : null,
                          ),
                        ),
                      ),
                      if (cut != null)
                        Positioned.fill(
                          child: GuideSheet(
                            key: const ValueKey<String>('crispr-sheet'),
                            record: widget.record,
                            model: _model,
                            cut: cut,
                            guides: _guidesAt(cut),
                            chosen: _guide,
                            controller: _sheet,
                            slide: _slideIn,
                            onChoose: (Guide guide) =>
                                setState(() => _guide = guide),
                            onRepair: _repair,
                            onDismiss: _closeSheet,
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
