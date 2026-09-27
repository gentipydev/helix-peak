import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/catalog/protein_target.dart';
import '../../../../core/network/track_source.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/anatomy/anatomy_scene.dart';
import '../../../../shared/anatomy/anatomy_selection.dart';
import '../../../../shared/anatomy/anatomy_stages.dart';
import '../../../../shared/widgets/error_view.dart';
import '../../../../shared/widgets/loading_view.dart';
import '../../../gene_lookup/domain/usecases/fetch_gene.dart';
import '../../presentation/lab_anatomy_view.dart';
import '../../presentation/lab_protein_picker.dart';
import '../domain/apply_edit.dart';
import 'edit_ripple.dart';
import 'edit_sheet.dart';
import 'mutate_cubit.dart';
import 'outcome_sentence.dart';

/// `/lab/mutate/<slug>`: one protein's record, fetched through the lab's own
/// tracks, with a base to change.
class MutateRoute extends StatelessWidget {
  const MutateRoute({required this.slug, super.key});

  final String slug;

  @override
  Widget build(BuildContext context) {
    return LabTargetLoader(
      slug: slug,
      builder: (BuildContext context, ProteinTarget target) =>
          BlocProvider<MutateCubit>(
            create: (BuildContext context) => MutateCubit(
              target: target,
              fetchGene: context.read<FetchGene>(),
              tracks: context.read<TrackSource>(),
            )..load(),
            child: MutateScreen(target: target),
          ),
    );
  }
}

/// Which page the canvas shows.
enum MutateView {
  /// The whole gene, drawn as its regions: tap one to open it.
  gene,

  /// One region opened into its DNA: tap a base to change it.
  region,

  /// The mRNA read into protein, 5' to 3': after an edit, the edited record's
  /// own translation, which is where the consequence travels down the chain.
  mrna,

  /// The original protein turning into the edited one.
  protein,
}

/// Change a base, and watch what it does, 5' to 3'.
///
/// The gene page, a region opened into its letters and the protein page are
/// all the walk's own pages, laid out by the shared [AnatomyLayout] from the
/// record and drawn by the shared painter. A base is picked on the letters and
/// changed in the shared inspector sheet. The edit is made by the lab's edit
/// engine on the original record and never replaces it: the edited record is
/// derived afresh. Its mRNA page plays the walk's own translation over the
/// edited record, so the consequence travels down the chain 5' to 3' codon by
/// codon; its protein page plays the original protein turning into the edited
/// one, residues past a new stop drifting away and shrinking. An mRNA that
/// nonsense-mediated decay would destroy is faded instead, and no short
/// protein is drawn. "Original" puts everything back.
class MutateScreen extends StatelessWidget {
  const MutateScreen({required this.target, super.key});

  final ProteinTarget target;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MutateCubit, MutateState>(
      builder: (BuildContext context, MutateState state) => switch (state) {
        MutateLoading() => Scaffold(
          appBar: AppBar(title: Text('Mutate · ${target.display}')),
          body: LoadingView(label: 'LOADING ${target.accession}'),
        ),
        MutateFailed(:final String message) => Scaffold(
          appBar: AppBar(title: Text('Mutate · ${target.display}')),
          body: ErrorView(
            title: 'Fetch failed',
            message: message,
            onRetry: () => context.read<MutateCubit>().load(),
          ),
        ),
        final MutateReady ready => _MutateBody(target: target, state: ready),
      },
    );
  }
}

class _MutateBody extends StatefulWidget {
  const _MutateBody({required this.target, required this.state});

  final ProteinTarget target;
  final MutateReady state;

  @override
  State<_MutateBody> createState() => _MutateBodyState();
}

class _MutateBodyState extends State<_MutateBody>
    with SingleTickerProviderStateMixin {
  MutateView _view = MutateView.gene;

  /// The region opened into its DNA, and whether the opening is still to
  /// play.
  AnatomySelection? _region;
  bool _opening = false;

  /// The base the sheet is about, as a record position.
  int? _base;

  /// Why the last edit was refused, if it was.
  String? _refusal;

  final DraggableScrollableController _sheet = DraggableScrollableController();
  late final AnimationController _slide = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  );
  late final Animation<Offset> _slideIn = Tween<Offset>(
    begin: const Offset(0, 1),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _slide, curve: Curves.easeOutCubic));

  /// The scene is rebuilt only when what it draws changes: a transition that
  /// is handed a new scene plays again from its start.
  Object? _sceneKey;
  AnatomyScene? _scene;

  MutateReady get _state => widget.state;
  MutateCubit get _cubit => context.read<MutateCubit>();

  @override
  void didUpdateWidget(_MutateBody old) {
    super.didUpdateWidget(old);
    if (!identical(old.state.shown, widget.state.shown) &&
        _view == MutateView.region) {
      // The record changed under an open region: open the same region of the
      // record now shown, standing.
      final int? position = _base;
      _region = position == null ? null : _regionAt(position);
      _opening = false;
    }
  }

  @override
  void dispose() {
    _slide.dispose();
    _sheet.dispose();
    super.dispose();
  }

  AnatomySelection? _regionAt(int position) {
    final AnatomyStage gene = _state.shown.stages.first;
    return gene.kind == StageKind.gene && gene.cellAt(position) >= 0
        ? AnatomySelection.of(_state.shown, position)
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
      _view = MutateView.region;
    });
  }

  void _pickBase(int position) {
    setState(() {
      _base = position;
      _refusal = null;
    });
    _slide.forward();
  }

  void _closeSheet() {
    _slide.reverse();
    setState(() {
      _base = null;
      _refusal = null;
    });
  }

  void _apply(SequenceEdit edit) {
    final String? refused = _cubit.apply(edit);
    setState(() {
      _refusal = refused;
      if (refused == null) {
        _view = _mrnaOf(_state.shown) >= 0
            ? MutateView.mrna
            : MutateView.protein;
      }
    });
  }

  static int _mrnaOf(AnatomyModel model) =>
      model.stages.indexWhere((AnatomyStage s) => s.kind == StageKind.mrna);

  void _revert() {
    _cubit.revert();
    setState(() {
      _refusal = null;
      if (_view == MutateView.protein || _view == MutateView.mrna) {
        _view = _region == null ? MutateView.gene : MutateView.region;
      }
    });
  }

  void _show(MutateView view) {
    setState(() {
      _view = view == MutateView.gene && _region != null
          ? MutateView.region
          : view;
      _opening = false;
    });
  }

  void _backToGene() => setState(() {
    _view = MutateView.gene;
    _region = null;
    _opening = false;
  });

  AnatomyScene _sceneFor(Size viewport) {
    final AnatomyModel shown = _state.shown;
    final AppliedEdit? applied = _state.applied;
    final Object key = (
      identityHashCode(shown),
      identityHashCode(applied),
      _view,
      identityHashCode(_region),
      _opening,
      viewport,
    );
    final AnatomyScene? held = _scene;
    if (held != null && key == _sceneKey) {
      return held;
    }
    final AnatomyScene scene = switch (_view) {
      MutateView.gene => AnatomyScene.resting(
        model: shown,
        index: 0,
        canvas: canvasFor(<AnatomyStage>[shown.stages.first], viewport),
        viewport: viewport,
      ),
      MutateView.region => AnatomyScene.selection(
        model: shown,
        selected: _region!.stage,
        canvas: canvasFor(<AnatomyStage>[
          shown.stages.first,
          _region!.stage,
        ], viewport),
        viewport: viewport,
        resting: !_opening,
      ),
      MutateView.mrna => _mrnaScene(viewport),
      MutateView.protein => _proteinScene(viewport),
    };
    _sceneKey = key;
    _scene = scene;
    return scene;
  }

  /// The mRNA page: at rest before an edit, and after one the edited
  /// record's own translation, mRNA into protein, the way the walk turns that
  /// page. An mRNA decay destroys stands, and fades.
  AnatomyScene _mrnaScene(Size viewport) {
    final AppliedEdit? applied = _state.applied;
    final AnatomyModel model = applied?.model ?? _state.model;
    final int mrna = _mrnaOf(model);
    final int protein = proteinStageOf(model);
    if (applied == null ||
        protein < 0 ||
        applied.outcome.kind == EditOutcomeKind.mrnaDegraded) {
      return AnatomyScene.resting(
        model: model,
        index: mrna,
        canvas: canvasFor(<AnatomyStage>[model.stages[mrna]], viewport),
        viewport: viewport,
      );
    }
    return AnatomyScene.between(
      model: model,
      fromIndex: mrna,
      toIndex: protein,
      canvas: canvasFor(<AnatomyStage>[
        model.stages[mrna],
        model.stages[protein],
      ], viewport),
      viewport: viewport,
    );
  }

  /// The protein page: at rest before an edit, and after one the original
  /// turning into the edited protein. Where decay destroys the mRNA no protein
  /// is made, and every residue leaves.
  AnatomyScene _proteinScene(Size viewport) {
    final AnatomyModel original = _state.model;
    final AppliedEdit? applied = _state.applied;
    final int protein = proteinStageOf(original);
    if (applied == null) {
      return AnatomyScene.resting(
        model: original,
        index: protein,
        canvas: canvasFor(<AnatomyStage>[original.stages[protein]], viewport),
        viewport: viewport,
      );
    }
    final String before = original.record.protein?.translation ?? '';
    final bool destroyed = applied.outcome.kind == EditOutcomeKind.mrnaDegraded;
    return editRipple(
      before: original,
      after: applied.model,
      target: destroyed
          ? (Int32List(before.length)..fillRange(0, before.length, -1))
          : rippleTargets(
              before: before,
              after: applied.record.protein?.translation ?? '',
              outcome: applied.outcome,
            ),
      viewport: viewport,
    );
  }

  String _lead() {
    final AppliedEdit? applied = _state.applied;
    return switch (_view) {
      MutateView.gene =>
        applied == null
            ? 'Tap a region of the gene to open its bases.'
            : 'The edited gene. Tap a region to open its bases.',
      MutateView.region =>
        'Tap a base in ${_region!.stage.label} to change it.',
      MutateView.mrna || MutateView.protein when applied == null =>
        'As the record reads it. Change a base on the gene to see what it '
            'does.',
      MutateView.mrna || MutateView.protein => outcomeSentence(
        applied!.outcome,
        before: _state.original,
        after: applied.record,
      ),
    };
  }

  int? get _maskedCell {
    final int? base = _base;
    final AnatomySelection? region = _region;
    if (_view != MutateView.region || base == null || region == null) {
      return null;
    }
    final int cell = region.stage.cellAt(base);
    return cell >= 0 ? cell : null;
  }

  void _tapped(int cell) {
    final AnatomyScene? scene = _scene;
    if (scene == null) {
      return;
    }
    final AnatomyStage stage = scene.isTransition ? scene.to : scene.from;
    switch (_view) {
      case MutateView.gene:
        _openRegion(stage.positionAt(cell));
      case MutateView.region:
        _pickBase(stage.positionAt(cell));
      case MutateView.mrna:
      case MutateView.protein:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppliedEdit? applied = _state.applied;
    final bool degraded =
        applied?.outcome.kind == EditOutcomeKind.mrnaDegraded &&
        _view == MutateView.mrna;
    final bool reduced = MediaQuery.disableAnimationsOf(context);
    return Scaffold(
      appBar: AppBar(
        title: Text('Mutate · ${widget.target.display}'),
        actions: <Widget>[
          if (applied != null)
            TextButton(
              key: const ValueKey<String>('mutate-original'),
              onPressed: _revert,
              child: const Text('Original'),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenPadding,
                AppSpacing.sm,
                AppSpacing.screenPadding,
                AppSpacing.sm,
              ),
              child: Semantics(
                liveRegion: true,
                child: Text(
                  _lead(),
                  key: const ValueKey<String>('mutate-lead'),
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.screenPadding,
              ),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: SegmentedButton<MutateView>(
                      showSelectedIcon: false,
                      segments: <ButtonSegment<MutateView>>[
                        const ButtonSegment<MutateView>(
                          value: MutateView.gene,
                          label: Text('Gene'),
                        ),
                        ButtonSegment<MutateView>(
                          value: MutateView.mrna,
                          label: const Text('mRNA'),
                          enabled: _mrnaOf(_state.shown) >= 0,
                        ),
                        const ButtonSegment<MutateView>(
                          value: MutateView.protein,
                          label: Text('Protein'),
                        ),
                      ],
                      selected: <MutateView>{
                        _view == MutateView.region ? MutateView.gene : _view,
                      },
                      onSelectionChanged: (Set<MutateView> views) =>
                          _show(views.single),
                    ),
                  ),
                  if (_view == MutateView.region) ...<Widget>[
                    const SizedBox(width: AppSpacing.sm),
                    TextButton(
                      onPressed: _backToGene,
                      child: const Text('Whole gene'),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Expanded(
              child: LayoutBuilder(
                builder: (BuildContext context, BoxConstraints box) {
                  final Size viewport = Size(box.maxWidth, box.maxHeight);
                  final AnatomyScene scene = _sceneFor(viewport);
                  Widget canvas = LabAnatomyView(
                    key: const ValueKey<String>('mutate-canvas'),
                    scene: scene,
                    // Translation reads a codon at a time, and gets the time
                    // the walk gives it; every other change is one movement.
                    duration: scene.translation != null
                        ? const Duration(milliseconds: 2800)
                        : const Duration(milliseconds: 1400),
                    onTap: _tapped,
                    maskedIndex: _maskedCell,
                    onSettled: _opening
                        ? () => setState(() => _opening = false)
                        : null,
                  );
                  if (degraded) {
                    // The mRNA is destroyed rather than read: it fades, and no
                    // short protein is drawn in its place.
                    canvas = TweenAnimationBuilder<double>(
                      key: ValueKey<Object>(applied!),
                      tween: Tween<double>(begin: 1, end: 0.25),
                      duration: reduced
                          ? Duration.zero
                          : const Duration(milliseconds: 1400),
                      builder: (
                        BuildContext context,
                        double value,
                        Widget? c,
                      ) => Opacity(opacity: value, child: c),
                      child: canvas,
                    );
                  }
                  return Stack(
                    children: <Widget>[
                      Positioned.fill(
                        child: SingleChildScrollView(child: canvas),
                      ),
                      if (_base != null)
                        Positioned.fill(
                          child: EditSheet(
                            key: const ValueKey<String>('mutate-sheet'),
                            state: _state,
                            position: _base!,
                            refusal: _refusal,
                            controller: _sheet,
                            slide: _slideIn,
                            onDismiss: _closeSheet,
                            onEdit: _apply,
                            onRevert: _revert,
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
