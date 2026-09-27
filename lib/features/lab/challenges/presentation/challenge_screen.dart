import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/biology/amino_acids.dart';
import '../../../../core/catalog/protein_target.dart';
import '../../../../core/network/track_client.dart';
import '../../../../core/theme/anatomy_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/clinvar/evidence_row.dart';
import '../../../../shared/structure/structure_view.dart';
import '../../../../shared/widgets/loading_view.dart';
import '../../../gene_lookup/data/repositories/protein_catalog_repository.dart';
import '../../share/share_action.dart';
import '../domain/challenge_materials.dart';
import '../domain/daily_puzzle.dart';
import '../domain/puzzle_generator.dart';
import 'challenge_card.dart';
import 'challenge_ledger.dart';
import 'challenge_shelf.dart';

sealed class ChallengeState {
  const ChallengeState();
}

final class ChallengeLoading extends ChallengeState {
  const ChallengeLoading();
}

/// The catalog this phone holds is too small to make a puzzle from: it has
/// not loaded yet.
final class ChallengeUnavailable extends ChallengeState {
  const ChallengeUnavailable();
}

final class ChallengeReady extends ChallengeState {
  const ChallengeReady({
    required this.puzzle,
    required this.streak,
    this.played,
  });

  final DailyPuzzle puzzle;

  /// Today's play, where it is done: a day is played once.
  final DayResult? played;
  final int streak;
}

/// Today's puzzle, made on the phone: the rounds' proteins from the date and
/// the catalog, then what the phone holds of them, then the puzzle. Nothing
/// here calls the network.
class ChallengeCubit extends Cubit<ChallengeState> {
  ChallengeCubit({
    required this.catalog,
    required this.shelf,
    required this.ledger,
    required this.now,
  }) : super(const ChallengeLoading());

  final List<ProteinTarget> Function() catalog;
  final ChallengeShelf shelf;
  final ChallengeLedger ledger;
  final DateTime Function() now;

  Future<void> load() async {
    emit(const ChallengeLoading());
    final List<ProteinTarget> proteins = catalog();
    if (proteins.length < 4) {
      emit(const ChallengeUnavailable());
      return;
    }
    final String day = PuzzleGenerator.dayOf(now());
    // The date alone chooses each round's protein; only then is the phone
    // asked what it holds of the ones that need tracks.
    final DailyPuzzle bare = PuzzleGenerator.generate(
      day: day,
      catalog: proteins,
    );
    final Map<String, ProteinMaterials> held = <String, ProteinMaterials>{};
    for (final ChallengeRound round in bare.rounds) {
      if (round case IdentifyRound(:final ProteinTarget subject)) {
        held[subject.slug] = await shelf.materialsOf(subject);
      }
    }
    final DailyPuzzle puzzle = PuzzleGenerator.generate(
      day: day,
      catalog: proteins,
      held: held,
    );
    final Map<String, DayResult> days = await ledger.read();
    if (!isClosed) {
      emit(
        ChallengeReady(
          puzzle: puzzle,
          played: days[day],
          streak: streakOf(days, now()),
        ),
      );
    }
  }

  Future<void> finish(DayResult result) async {
    await ledger.write(result);
    final Map<String, DayResult> days = await ledger.read();
    final ChallengeState state = this.state;
    if (!isClosed && state is ChallengeReady) {
      emit(
        ChallengeReady(
          puzzle: state.puzzle,
          played: days[result.day] ?? result,
          streak: streakOf(days, now()),
        ),
      );
    }
  }
}

/// `/lab/challenges`: today's puzzle.
class ChallengeRoute extends StatelessWidget {
  const ChallengeRoute({
    this.shelf,
    this.ledger,
    this.now,
    this.shareSheet = systemShareSheet,
    super.key,
  });

  /// What the phone holds, and where days are kept; the lab's own cache and
  /// folder where null.
  final ChallengeShelf? shelf;
  final ChallengeLedger? ledger;

  /// Today, where null.
  final DateTime Function()? now;

  final ShareSheet shareSheet;

  static const String title = 'Daily challenge';

  @override
  Widget build(BuildContext context) => BlocProvider<ChallengeCubit>(
    create: (BuildContext context) => ChallengeCubit(
      catalog: () => context.read<ProteinCatalogRepository>().all,
      shelf: shelf ?? CachedShelf(context.read<TrackClient>()),
      ledger: ledger ?? FileLedger(),
      now: now ?? DateTime.now,
    )..load(),
    child: BlocBuilder<ChallengeCubit, ChallengeState>(
      builder: (BuildContext context, ChallengeState state) => switch (state) {
        ChallengeLoading() => Scaffold(
          appBar: AppBar(title: const Text(title)),
          body: const LoadingView(label: 'MAKING TODAY’S PUZZLE'),
        ),
        ChallengeUnavailable() => Scaffold(
          appBar: AppBar(title: const Text(title)),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.screenPadding),
              child: Text(
                'Today’s puzzle is made from the catalog, and the catalog has '
                'not loaded yet.',
                key: const ValueKey<String>('challenge-unavailable'),
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
        ChallengeReady() => ChallengeScreen(
          key: ValueKey<String>(state.puzzle.day),
          puzzle: state.puzzle,
          played: state.played,
          streak: state.streak,
          onFinished: (DayResult result) =>
              context.read<ChallengeCubit>().finish(result),
          shareSheet: shareSheet,
        ),
      },
    ),
  );
}

/// Today's four rounds, one at a time, and then how the day went.
///
/// A day is played once: where it is done, the screen opens on its result.
class ChallengeScreen extends StatefulWidget {
  const ChallengeScreen({
    required this.puzzle,
    required this.onFinished,
    this.played,
    this.streak = 0,
    this.shareSheet = systemShareSheet,
    super.key,
  });

  final DailyPuzzle puzzle;
  final DayResult? played;
  final int streak;
  final Future<void> Function(DayResult result) onFinished;
  final ShareSheet shareSheet;

  @override
  State<ChallengeScreen> createState() => _ChallengeScreenState();
}

class _ChallengeScreenState extends State<ChallengeScreen> {
  int _round = 0;
  final List<bool> _right = <bool>[];
  List<bool> _codons = const <bool>[];

  /// Whether the round on screen has been answered, and so says so and offers
  /// the next.
  bool? _answered;

  bool _sharing = false;

  /// True once the last round's answer is on its way to the ledger: a second
  /// tap then must not count a fifth round.
  bool _finishing = false;

  void _answer(bool right, {List<bool>? codons}) {
    setState(() {
      _answered = right;
      if (codons != null) {
        _codons = codons;
      }
    });
  }

  Future<void> _next() async {
    if (_finishing) {
      return;
    }
    final bool right = _answered ?? false;
    _right.add(right);
    if (_round + 1 < widget.puzzle.rounds.length) {
      setState(() {
        _round++;
        _answered = null;
      });
      return;
    }
    setState(() => _finishing = true);
    await widget.onFinished(
      DayResult(
        day: widget.puzzle.day,
        rounds: List<bool>.unmodifiable(_right),
        codons: List<bool>.unmodifiable(_codons),
      ),
    );
  }

  Future<void> _share(DayResult result) async {
    final ThemeData theme = Theme.of(context);
    final RenderBox? box = context.findRenderObject() as RenderBox?;
    final Rect? origin = box == null
        ? null
        : box.localToGlobal(Offset.zero) & box.size;
    final ScaffoldMessengerState? messenger = ScaffoldMessenger.maybeOf(
      context,
    );
    setState(() => _sharing = true);
    try {
      final Uint8List png = await shareCard(
        theme: theme,
        puzzle: widget.puzzle,
        result: result,
      );
      await widget.shareSheet(
        png: png,
        fileName: 'helix-peek-${widget.puzzle.day}.png',
        text: shareText(widget.puzzle, result),
        origin: origin,
      );
    } on Object catch (error) {
      assert(() {
        debugPrint('helixpeek: could not share the day ($error)');
        return true;
      }());
      messenger?.showSnackBar(
        const SnackBar(content: Text('The result could not be shared.')),
      );
    } finally {
      if (mounted) {
        setState(() => _sharing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final DayResult? played = widget.played;
    return Scaffold(
      appBar: AppBar(title: const Text(ChallengeRoute.title)),
      body: SafeArea(
        child: played != null
            ? _Summary(
                puzzle: widget.puzzle,
                result: played,
                streak: widget.streak,
                sharing: _sharing,
                onShare: () => unawaited(_share(played)),
              )
            : _roundView(context),
      ),
    );
  }

  Widget _roundView(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ChallengeRound round = widget.puzzle.rounds[_round];
    final bool? answered = _answered;
    return ListView(
      key: ValueKey<String>('challenge-round-$_round'),
      padding: const EdgeInsets.all(AppSpacing.screenPadding),
      children: <Widget>[
        Text(
          'Round ${_round + 1} of ${widget.puzzle.rounds.length} · '
          '${widget.puzzle.day}',
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Semantics(
          header: true,
          child: Text(round.prompt, style: theme.textTheme.titleMedium),
        ),
        const SizedBox(height: AppSpacing.md),
        switch (round) {
          FoldRound() => _Choice(
            key: ValueKey<String>('challenge-choice-$_round'),
            options: round.options,
            answer: round.answer,
            onAnswer: _answer,
            above: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints box) {
                final Size viewport = Size(box.maxWidth, 260);
                return SizedBox.fromSize(
                  size: viewport,
                  child: StructureView(
                    viewport: viewport,
                    target: round.subject,
                  ),
                );
              },
            ),
          ),
          IdentifyRound() => _Choice(
            key: ValueKey<String>('challenge-choice-$_round'),
            options: round.options,
            answer: round.answer,
            onAnswer: _answer,
            above: Text(
              round.clue,
              key: const ValueKey<String>('challenge-clue'),
              style: theme.textTheme.titleSmall?.copyWith(
                fontFamily: AppTypography.monoFamily,
              ),
            ),
          ),
          MutationRound() => _Mutation(
            key: ValueKey<String>('challenge-mutation-$_round'),
            round: round,
            onAnswer: _answer,
          ),
          WalkOrderRound() => _Walk(
            key: ValueKey<String>('challenge-walk-$_round'),
            round: round,
            onAnswer: _answer,
          ),
          CodonRound() => _Codons(
            key: ValueKey<String>('challenge-codons-$_round'),
            round: round,
            // The round is right with half its codons or more: against the
            // clock, all of them would almost never be. The card shows each.
            onAnswer: (List<bool> codons) => _answer(
              codons.where((bool r) => r).length * 2 >= codons.length,
              codons: codons,
            ),
          ),
        },
        if (answered != null) ...<Widget>[
          const SizedBox(height: AppSpacing.md),
          Semantics(
            liveRegion: true,
            child: Text(
              answered ? 'Right.' : 'Not this time.',
              key: const ValueKey<String>('challenge-verdict'),
              style: theme.textTheme.titleSmall,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          FilledButton(
            key: const ValueKey<String>('challenge-next'),
            onPressed: _finishing ? null : () => unawaited(_next()),
            child: Text(
              _round + 1 < widget.puzzle.rounds.length
                  ? 'Next round'
                  : 'See how the day went',
            ),
          ),
        ],
      ],
    );
  }
}

/// Four names to choose from, under what the round shows.
class _Choice extends StatefulWidget {
  const _Choice({
    required this.options,
    required this.answer,
    required this.onAnswer,
    required this.above,
    super.key,
  });

  final List<ProteinTarget> options;
  final int answer;
  final void Function(bool right) onAnswer;
  final Widget above;

  @override
  State<_Choice> createState() => _ChoiceState();
}

class _ChoiceState extends State<_Choice> {
  int? _chosen;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final int? chosen = _chosen;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        widget.above,
        const SizedBox(height: AppSpacing.md),
        for (int i = 0; i < widget.options.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: OutlinedButton(
              key: ValueKey<String>('challenge-option-$i'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                backgroundColor: chosen == null
                    ? null
                    : i == widget.answer
                    ? theme.colorScheme.primaryContainer
                    : i == chosen
                    ? theme.colorScheme.errorContainer
                    : null,
              ),
              onPressed: chosen == null
                  ? () {
                      setState(() => _chosen = i);
                      widget.onAnswer(i == widget.answer);
                    }
                  : null,
              child: Text(widget.options[i].display),
            ),
          ),
        if (chosen != null && chosen != widget.answer)
          Text(
            'It is ${widget.options[widget.answer].display}.',
            style: theme.textTheme.bodyMedium,
          ),
      ],
    );
  }
}

/// A stretch of residues in the walk's own residue colours, each one a
/// button where [onTap] is given.
class _ResidueRow extends StatelessWidget {
  const _ResidueRow({
    required this.residues,
    required this.start,
    required this.label,
    this.onTap,
    this.marked,
  });

  final String residues;
  final int start;
  final String label;
  final ValueChanged<int>? onTap;

  /// A residue to outline, once the round is answered.
  final int? marked;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AnatomyColors colours = context.anatomyColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label, style: theme.textTheme.labelMedium),
        const SizedBox(height: AppSpacing.xs),
        Wrap(
          spacing: 2,
          runSpacing: 2,
          children: <Widget>[
            for (int i = 0; i < residues.length; i++)
              Semantics(
                button: onTap != null,
                label: '${AminoAcids.abbreviationOf(residues[i])}${start + i}',
                excludeSemantics: true,
                child: InkWell(
                  key: onTap == null
                      ? null
                      : ValueKey<String>('challenge-residue-$i'),
                  onTap: onTap == null ? null : () => onTap!(i),
                  child: Container(
                    width: 48,
                    height: 48,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: colours.forResidue(residues[i]),
                      borderRadius: BorderRadius.circular(6),
                      border: marked == i
                          ? Border.all(color: colours.tracer, width: 3)
                          : null,
                    ),
                    child: Text(
                      residues[i],
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontFamily: AppTypography.monoFamily,
                        color: theme.colorScheme.surface,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// Which residue differs? Tap it in the changed stretch.
class _Mutation extends StatefulWidget {
  const _Mutation({required this.round, required this.onAnswer, super.key});

  final MutationRound round;
  final void Function(bool right) onAnswer;

  @override
  State<_Mutation> createState() => _MutationState();
}

class _MutationState extends State<_Mutation> {
  int? _chosen;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final MutationRound round = widget.round;
    final int? chosen = _chosen;
    final String? reported = round.reportedAs;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _ResidueRow(
          residues: round.reference,
          start: round.start,
          label: 'As ${round.subject.display} has it',
          marked: chosen == null ? null : round.at,
        ),
        const SizedBox(height: AppSpacing.md),
        _ResidueRow(
          residues: round.changed,
          start: round.start,
          label: 'Changed',
          marked: chosen == null ? null : round.at,
          onTap: chosen == null
              ? (int i) {
                  setState(() => _chosen = i);
                  widget.onAnswer(i == round.at);
                }
              : null,
        ),
        if (chosen != null) ...<Widget>[
          const SizedBox(height: AppSpacing.md),
          Text(
            round.reveal,
            key: const ValueKey<String>('challenge-reveal'),
            style: theme.textTheme.bodyMedium,
          ),
          if (reported != null)
            ClinVarSourced(
              child: Text(
                reported,
                key: const ValueKey<String>('challenge-reported'),
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
        ],
      ],
    );
  }
}

/// Put the walk in order: tap its pages in the order the walk turns them.
class _Walk extends StatefulWidget {
  const _Walk({required this.round, required this.onAnswer, super.key});

  final WalkOrderRound round;
  final void Function(bool right) onAnswer;

  @override
  State<_Walk> createState() => _WalkState();
}

class _WalkState extends State<_Walk> {
  final List<int> _order = <int>[];

  bool get _done => _order.length == widget.round.pages.length;

  void _tap(int page) {
    setState(() => _order.add(page));
    if (_done) {
      widget.onAnswer(
        <int>[
              for (int i = 0; i < _order.length; i++)
                if (_order[i] == i) i,
            ].length ==
            _order.length,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final WalkOrderRound round = widget.round;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          'Tap the pages in the order the walk turns them.',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: AppSpacing.sm),
        for (final int page in round.shown)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: OutlinedButton(
              key: ValueKey<String>('challenge-page-$page'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
              onPressed: _order.contains(page) || _done
                  ? null
                  : () => _tap(page),
              child: Text(
                _order.contains(page)
                    ? '${_order.indexOf(page) + 1}. ${round.pages[page]}'
                    : round.pages[page],
              ),
            ),
          ),
        if (!_done && _order.isNotEmpty)
          TextButton(
            key: const ValueKey<String>('challenge-walk-clear'),
            onPressed: () => setState(_order.clear),
            child: const Text('Start the order again'),
          ),
        if (_done)
          Text(
            'The walk: ${round.pages.join(', then ')}.',
            style: theme.textTheme.bodyMedium,
          ),
      ],
    );
  }
}

/// Codons against the clock: each codon's amino acid, from four.
///
/// With a screen reader on the clock gives twice the time: reading four
/// answers aloud takes longer than seeing them.
class _Codons extends StatefulWidget {
  const _Codons({required this.round, required this.onAnswer, super.key});

  final CodonRound round;
  final void Function(List<bool> codons) onAnswer;

  @override
  State<_Codons> createState() => _CodonsState();
}

class _CodonsState extends State<_Codons> {
  final List<bool> _right = <bool>[];
  Timer? _clock;
  int _left = 0;
  bool _started = false;

  bool get _done => _right.length == widget.round.questions.length;

  void _start() {
    final int seconds =
        widget.round.timeLimit.inSeconds *
        (MediaQuery.accessibleNavigationOf(context) ? 2 : 1);
    setState(() {
      _started = true;
      _left = seconds;
    });
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) {
        return;
      }
      setState(() => _left--);
      if (_left <= 0) {
        _finish();
      }
    });
  }

  void _pick(int option) {
    final CodonQuestion question = widget.round.questions[_right.length];
    setState(() => _right.add(option == question.answer));
    if (_done) {
      _finish();
    }
  }

  void _finish() {
    _clock?.cancel();
    _clock = null;
    final List<bool> right = <bool>[
      ..._right,
      // Codons the clock ran out on count as missed.
      for (int i = _right.length; i < widget.round.questions.length; i++) false,
    ];
    setState(() {
      _right
        ..clear()
        ..addAll(right);
    });
    widget.onAnswer(right);
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    if (!_started) {
      return FilledButton(
        key: const ValueKey<String>('challenge-codons-start'),
        onPressed: _start,
        child: const Text('Start the clock'),
      );
    }
    if (_done) {
      return Text(
        '${_right.where((bool r) => r).length} of ${_right.length} codons.',
        key: const ValueKey<String>('challenge-codons-score'),
        style: theme.textTheme.bodyMedium,
      );
    }
    final CodonQuestion question = widget.round.questions[_right.length];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        ExcludeSemantics(
          child: Text(
            '$_left s',
            key: const ValueKey<String>('challenge-clock'),
            style: theme.textTheme.labelLarge,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Semantics(
          liveRegion: true,
          label:
              'Codon ${_right.length + 1} of ${widget.round.questions.length}: '
              '${question.codon.split('').join(' ')}',
          excludeSemantics: true,
          child: Text(
            question.codon,
            key: const ValueKey<String>('challenge-codon'),
            textAlign: TextAlign.center,
            style: theme.textTheme.displaySmall?.copyWith(
              fontFamily: AppTypography.monoFamily,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        for (int i = 0; i < question.options.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: OutlinedButton(
              key: ValueKey<String>('challenge-codon-option-$i'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
              onPressed: () => _pick(i),
              child: Text(CodonQuestion.nameOf(question.options[i])),
            ),
          ),
      ],
    );
  }
}

/// How the day went: a square a round and a square a codon, the streak, and
/// the result to share.
class _Summary extends StatelessWidget {
  const _Summary({
    required this.puzzle,
    required this.result,
    required this.streak,
    required this.sharing,
    required this.onShare,
  });

  final DailyPuzzle puzzle;
  final DayResult result;
  final int streak;
  final bool sharing;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    Widget squares(List<bool> right, String what) => Semantics(
      label:
          '$what: ${right.where((bool r) => r).length} of ${right.length} right',
      excludeSemantics: true,
      child: Wrap(
        spacing: 6,
        children: <Widget>[
          for (final bool r in right)
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: r
                    ? theme.colorScheme.primary
                    : theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(5),
              ),
            ),
        ],
      ),
    );
    return ListView(
      key: const ValueKey<String>('challenge-summary'),
      padding: const EdgeInsets.all(AppSpacing.screenPadding),
      children: <Widget>[
        Semantics(
          header: true,
          child: Text(
            '${puzzle.day}: ${result.right} of ${puzzle.rounds.length}',
            style: theme.textTheme.titleLarge,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        squares(result.rounds, 'Rounds'),
        const SizedBox(height: AppSpacing.sm),
        squares(result.codons, 'Codons'),
        const SizedBox(height: AppSpacing.md),
        Text(
          streak == 1 ? 'A streak of one day.' : 'A streak of $streak days.',
          key: const ValueKey<String>('challenge-streak'),
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Kept on this phone only. A new puzzle tomorrow.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        FilledButton.icon(
          key: const ValueKey<String>('challenge-share'),
          onPressed: sharing ? null : onShare,
          icon: const Icon(Icons.ios_share_rounded),
          label: const Text('Share the day'),
        ),
      ],
    );
  }
}
