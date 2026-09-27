import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/biology/gene_record.dart';
import '../../../../core/catalog/protein_target.dart';
import '../../../../core/network/track_source.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/format.dart';
import '../../../../shared/motion/timeline_controller.dart';
import '../../../../shared/motion/transport_bar.dart';
import '../../../gene_lookup/domain/usecases/fetch_gene.dart';
import '../../mutate/domain/apply_edit.dart';
import '../../mutate/presentation/mutate_cubit.dart';
import '../../mutate/presentation/mutate_screen.dart';
import '../../presentation/lab_protein_picker.dart';
import '../../presentation/lab_record.dart';
import '../domain/fidelity.dart';
import '../domain/replication_captions.dart';
import '../domain/replication_plan.dart';
import '../domain/replication_timeline.dart';
import 'replication_painters.dart';

/// `/lab/replication/<slug>`: one protein's gene, copied.
class ReplicationRoute extends StatelessWidget {
  const ReplicationRoute({required this.slug, super.key});

  final String slug;

  @override
  Widget build(BuildContext context) => LabTargetLoader(
    slug: slug,
    builder: (BuildContext context, ProteinTarget target) => LabRecordView(
      target: target,
      title: ReplicationScreen.titleOf(target),
      builder: (BuildContext context, GeneRecord record) {
        final String? refused = ReplicationPlan.refusal(record);
        if (refused == null) {
          return ReplicationScreen(
            key: ValueKey<String>(target.slug),
            target: target,
            plan: ReplicationPlan.of(record),
          );
        }
        return Scaffold(
          appBar: AppBar(title: Text(ReplicationScreen.titleOf(target))),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.screenPadding),
              child: Text(
                refused,
                key: const ValueKey<String>('replication-refused'),
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ),
          ),
        );
      },
    ),
  );
}

/// A gene copying itself, on the shared transport bar.
///
/// Three views of one timeline. At the top the fork base by base, on the
/// record's own helix as the shared geometry unzips it; below it the fork at
/// the scale of fragments, where the lagging strand's loop fits whole; and
/// the whole record as one bar, the bubble growing along it. The reader
/// chooses how much of the cell's error checking is on: the proofreading set
/// piece plays out as they choose, and the errors a thousand copies keep at
/// that level are listed. Each one opens on the mutate screen, as an edit to
/// the record, so what it does to the protein is read the way an edit made by
/// hand is.
class ReplicationScreen extends StatefulWidget {
  const ReplicationScreen({
    required this.target,
    required this.plan,
    super.key,
  });

  final ProteinTarget target;
  final ReplicationPlan plan;

  /// How long one beat takes at speed 1: thirty beats, half a minute.
  static const Duration beat = Duration(milliseconds: 1000);

  static String titleOf(ProteinTarget target) =>
      'Replication · ${target.display}';

  @override
  State<ReplicationScreen> createState() => _ReplicationScreenState();
}

class _ReplicationScreenState extends State<ReplicationScreen>
    with TickerProviderStateMixin {
  late final ReplicationTimeline _timeline = ReplicationTimeline(widget.plan);
  late final ReplicationCaptions _captions = ReplicationCaptions(widget.plan);
  late final ErrorTally _tally = ErrorTally.of(widget.plan);
  late final TimelineController _controller = TimelineController(
    vsync: this,
    timeline: _timeline,
    beat: ReplicationScreen.beat,
  );
  final HelixWindow _window = HelixWindow();

  /// Everything on, to start: the reader switches layers off to watch errors
  /// get through.
  Fidelity _fidelity = Fidelity.repair;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// The errors that get through at the level chosen, the copy drawn first
  /// where the set piece's wrong base stays in it.
  List<(String, Substitution)> get _survivors {
    final ReplicationPlan plan = widget.plan;
    return <(String, Substitution)>[
      if (_fidelity == Fidelity.polymerase)
        (
          'The copy drawn above',
          Substitution(plan.positionOf(plan.setPieceSite), plan.setPieceWrong),
        ),
      for (final CopyingError e in _tally.survivors(_fidelity))
        ('Copy ${grouped(e.copy)}', e.editOf(plan)),
    ];
  }

  Future<void> _open(Substitution edit) async {
    final ProteinTarget target = widget.target;
    final FetchGene fetchGene = context.read<FetchGene>();
    final TrackSource tracks = context.read<TrackSource>();
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => BlocProvider<MutateCubit>(
          create: (BuildContext context) => MutateCubit(
            target: target,
            fetchGene: fetchGene,
            tracks: tracks,
            applying: edit,
          )..load(),
          child: MutateScreen(target: target),
        ),
      ),
    );
  }

  Future<void> _showErrors() async {
    final List<(String, Substitution)> errors = _survivors;
    final GeneRecord record = widget.plan.record;
    final Substitution? chosen = await showModalBottomSheet<Substitution>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (BuildContext context) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.6,
          child: ListView.builder(
            key: const ValueKey<String>('replication-error-list'),
            itemCount: errors.length + 1,
            itemBuilder: (BuildContext context, int index) {
              if (index == 0) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.screenPadding,
                    0,
                    AppSpacing.screenPadding,
                    AppSpacing.sm,
                  ),
                  child: Text(
                    'Errors that got through. Each opens as an edit to the '
                    'record, where you can see what it does.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                );
              }
              final (String copy, Substitution edit) = errors[index - 1];
              final String was = widget.plan.baseAt(
                record.strand == -1
                    ? record.end - edit.position
                    : edit.position - record.start,
              );
              return ListTile(
                key: ValueKey<String>('replication-error-${index - 1}'),
                title: Text(
                  '$copy · base ${grouped(edit.position)}: '
                  '$was → ${edit.newBase}',
                ),
                subtitle: Text(outcomeLabel(classify(record, edit))),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.of(context).pop(edit),
              );
            },
          ),
        ),
      ),
    );
    if (chosen != null && mounted) {
      await _open(chosen);
    }
  }

  void _choose(Fidelity fidelity) {
    setState(() => _fidelity = fidelity);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ReplicationInks inks = ReplicationInks.of(context);
    final TextStyle labels =
        theme.textTheme.labelSmall ?? const TextStyle(fontSize: 11);
    final TextStyle? note = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final int through = _survivors.length;
    return Scaffold(
      appBar: AppBar(title: Text(ReplicationScreen.titleOf(widget.target))),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Expanded(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (BuildContext context, Widget? views) => Semantics(
                  label: describe(
                    widget.plan,
                    _timeline.stateAt(_controller.t),
                  ),
                  child: views,
                ),
                child: ExcludeSemantics(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Expanded(
                        flex: 11,
                        child: RepaintBoundary(
                          child: CustomPaint(
                            key: const ValueKey<String>('replication-bases'),
                            size: Size.infinite,
                            painter: ForkBasePainter(
                              plan: widget.plan,
                              timeline: _timeline,
                              at: () => _controller.t,
                              fidelity: _fidelity,
                              inks: inks,
                              window: _window,
                              labels: labels,
                              repaint: _controller,
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 8,
                        child: RepaintBoundary(
                          child: CustomPaint(
                            key: const ValueKey<String>('replication-loop'),
                            size: Size.infinite,
                            painter: ForkLoopPainter(
                              plan: widget.plan,
                              timeline: _timeline,
                              at: () => _controller.t,
                              fidelity: _fidelity,
                              inks: inks,
                              labels: labels,
                              repaint: _controller,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(
                        height: 22,
                        child: RepaintBoundary(
                          child: CustomPaint(
                            key: const ValueKey<String>('replication-record'),
                            size: Size.infinite,
                            painter: GeneBarPainter(
                              plan: widget.plan,
                              timeline: _timeline,
                              at: () => _controller.t,
                              inks: inks,
                              repaint: _controller,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenPadding,
                AppSpacing.sm,
                AppSpacing.screenPadding,
                0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  SizedBox(
                    height: 128,
                    child: AnimatedBuilder(
                      animation: _controller,
                      builder: (BuildContext context, _) => Text(
                        _captions.captionOf(
                          _timeline.stateAt(_controller.t),
                          _fidelity,
                        ),
                        key: const ValueKey<String>('replication-caption'),
                        style: theme.textTheme.bodyMedium,
                        maxLines: 6,
                        overflow: TextOverflow.fade,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  SegmentedButton<Fidelity>(
                    key: const ValueKey<String>('replication-fidelity'),
                    showSelectedIcon: false,
                    segments: <ButtonSegment<Fidelity>>[
                      for (final Fidelity f in Fidelity.values)
                        ButtonSegment<Fidelity>(
                          value: f,
                          label: Text(ReplicationCaptions.nameOf(f)),
                        ),
                    ],
                    selected: <Fidelity>{_fidelity},
                    onSelectionChanged: (Set<Fidelity> chosen) =>
                        _choose(chosen.single),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    '${ReplicationCaptions.rateOf(_fidelity)} '
                    '${_captions.perCopy(_fidelity)} '
                    '${_captions.tallyOf(_tally, _fidelity)}',
                    key: const ValueKey<String>('replication-tally'),
                    style: note,
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      key: const ValueKey<String>('replication-errors'),
                      onPressed: through == 0 ? null : _showErrors,
                      child: Text(
                        through == 0
                            ? 'No error got through'
                            : 'Open an error that got through',
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: TransportBar(controller: _controller),
            ),
          ],
        ),
      ),
    );
  }
}

/// What the views show at [frame], for a screen reader.
String describe(ReplicationPlan plan, ReplicationFrame frame) {
  final double travel = frame.travel;
  final int copied = <int>[
    (plan.rightFork(travel).floor() - plan.origin + 1).clamp(
      0,
      plan.length - plan.origin,
    ),
    (plan.origin - plan.leftFork(travel).ceil()).clamp(0, plan.origin),
  ].reduce((int a, int b) => a + b);
  return 'A replication fork, drawn three ways. '
      '${grouped(copied)} of ${grouped(plan.length)} base pairs unwound. '
      '${ReplicationTimeline.nameOf(frame.phase)}.';
}

/// What an edit does, in a few words.
String outcomeLabel(EditOutcome outcome) {
  final int? codon = outcome.codonIndex;
  return switch (outcome.kind) {
    EditOutcomeKind.synonymous =>
      'Silent: residue ${grouped(codon ?? 0)} is '
          'unchanged',
    EditOutcomeKind.missense =>
      'Residue ${grouped(codon ?? 0)}: '
          '${outcome.oldResidue} to ${outcome.newResidue}',
    EditOutcomeKind.nonsense => 'A stop at residue ${grouped(codon ?? 0)}',
    EditOutcomeKind.mrnaDegraded =>
      'A stop at residue ${grouped(codon ?? 0)}, early enough that the mRNA '
          'is destroyed',
    EditOutcomeKind.stopLoss => 'The stop codon is lost',
    EditOutcomeKind.spliceSite => 'At a splice site',
    EditOutcomeKind.intronic => 'In an intron',
    EditOutcomeKind.utr => 'In an untranslated end',
    EditOutcomeKind.frameshift => 'The reading frame shifts',
    EditOutcomeKind.inFrameIndel => 'Residues gained or lost',
  };
}
