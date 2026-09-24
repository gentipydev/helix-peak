import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../../../../core/theme/anatomy_colors.dart';
import '../../../../core/theme/nucleotide_colors.dart';
import '../../domain/entities/protein_constraint.dart';
import '../clinvar/clinvar_colors.dart';
import 'anatomy_layout.dart';
import 'anatomy_painter.dart';
import 'anatomy_scene.dart';
import 'anatomy_stages.dart';
import 'anatomy_tracer.dart';

/// The grid itself: one `CustomPaint`, one animation, two gestures.
class AnatomyCanvas extends StatefulWidget {
  const AnatomyCanvas({
    required this.model,
    required this.stageIndex,
    required this.viewport,
    required this.tracer,
    required this.status,
    required this.onTapped,
    this.onLongPress,
    this.sourceScrollOffset = 0,
    this.onSettled,
    this.constraint,
    this.conservation = false,
    this.maskedIndex,
    this.masking,
    this.bridges = const <int, int>{},
    this.marks = const <int, ClinVarMark>{},
    super.key,
  });

  final AnatomyModel model;
  final int stageIndex;
  final double sourceScrollOffset;

  /// Told the stage the canvas has come to rest on, and where a page scrolled
  /// before a transition should be put back to — once for every stage it
  /// arrives at, however it arrived: at the end of a transition, a frame after
  /// a jump, a reduced-motion step or a first build, or when a transition is
  /// cut short. A jump waits on this to open what it was sent to, so an
  /// arrival that went unreported was a jump that never landed.
  final void Function(int stage, double scrollOffset)? onSettled;
  final ProteinConstraint? constraint;
  final bool conservation;
  final int? maskedIndex;
  final Animation<double>? masking;

  /// Bonded cysteines on this page, cell to bridge number.
  final Map<int, int> bridges;

  /// Residues with ClinVar records, cell to mark; drawn in ESM mode only.
  final Map<int, ClinVarMark> marks;

  /// What the reader can see of the canvas without scrolling.
  ///
  /// The widget sizes itself to this on every stage that fits it. The
  /// transcript insists on 20pt bases and so comes out about twice as tall, and
  /// a long gene or protein keeps its floor and comes out taller still; the
  /// screen scrolls the difference.
  final Size viewport;

  final Tracer? tracer;
  final TracerStatus? status;

  /// The genomic coordinate the user hit, or null for empty canvas.
  /// A tap, as the position it landed on and the question it was asking:
  /// `asRun` for a whole piece of the gene, otherwise this one residue.
  final void Function(int? position, {bool asRun}) onTapped;

  /// A long press anywhere on the page: copy its sequence.
  final VoidCallback? onLongPress;

  /// How long the reading frame takes to groove itself open once a page that
  /// has one has settled.
  ///
  /// Longer than it looks, because most of it is the sweep: at
  /// [AnatomyMotion.codonStagger] the last row of the coding sequence does not
  /// set off until nearly half of this has gone.
  static const Duration grooveDuration = Duration(milliseconds: 700);

  // Keep the codon swap's original 1,080ms. Give the protein's movement and
  // expansion four times their previous 420ms, without slowing the swap.
  static const Duration _translationReadDuration = Duration(milliseconds: 1080);
  static const Duration _translationSettleDuration = Duration(
    milliseconds: 1680,
  );
  static const double _translationSwapEnd = 0.72;

  /// Each transition does one thing, and gets the time that one thing needs.
  ///
  /// Splicing gets a long beat because it is much the largest, and because
  /// it is the one transition a reader meets before they know what they are
  /// looking at. Two thirds of the gene leaves in it — intron 2 alone is more
  /// than half — and at 1,200 the removal was over as an event before it had
  /// been read as one: the ripple that carries it runs 5' to 3' across 1,431
  /// cells, so the last of them only sets off when the first is already
  /// arriving. Sixteen hundred is what it costs to watch the whole length of
  /// that rather than catch the end of it.
  ///
  /// The dibasic cut runs long for the opposite reason — it is four squares,
  /// and they are the most teachable second in the app.
  ///
  /// Translation first clears the untranslated ends, folds each codon into a
  /// residue, then settles the protein layout. The last part has its own slower
  /// pace so the small amino acids can be followed as they move and grow.
  ///
  /// Cleavage carries three: the signal peptide comes off here now rather than
  /// on a page of its own, so twenty-eight residues leave where four used to,
  /// and the whole chain reflows behind them into three separate blocks. It is
  /// given 1,200 milliseconds —
  /// a leader of twenty-four squares drawing back is worth watching, and at
  /// the old figure it was over before the eye had found it.
  ///
  /// [StageKind.proprotein] keeps its own timing for the records that still get
  /// that page: one where the proprotein is not a single unbroken run of its
  /// precursor, and so cannot be drawn as a named block of it.
  ///
  /// A backwards swipe reuses the arriving stage's figure, so the mRNA is as
  /// long to leave as it is to reach. The animation is the same one read the
  /// other way, and a reflow that took half as long in reverse would read as a
  /// different, hastier event.
  static Duration durationOf(StageKind arriving) => switch (arriving) {
    StageKind.mrna => const Duration(milliseconds: 1600),
    StageKind.protein => _translationReadDuration + _translationSettleDuration,
    StageKind.proprotein => const Duration(milliseconds: 800),
    StageKind.maturePeptides => const Duration(milliseconds: 1200),
    StageKind.gene => const Duration(milliseconds: 1200),
    StageKind.dna => const Duration(milliseconds: 700),
  };

  @override
  State<AnatomyCanvas> createState() => _AnatomyCanvasState();
}

class _AnatomyCanvasState extends State<AnatomyCanvas>
    with TickerProviderStateMixin {
  late final AnimationController _progress = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 800),
  );

  /// Map elapsed time onto the existing poses. Both geometry and lettering
  /// receive this same clock, including when a swipe reverses mid-transition.
  late final Animation<double> _translationProgress = TweenSequence<double>(
    <TweenSequenceItem<double>>[
      TweenSequenceItem<double>(
        tween: Tween<double>(begin: 0, end: AnatomyCanvas._translationSwapEnd),
        weight: AnatomyCanvas._translationReadDuration.inMilliseconds
            .toDouble(),
      ),
      TweenSequenceItem<double>(
        tween: Tween<double>(begin: AnatomyCanvas._translationSwapEnd, end: 1),
        weight: AnatomyCanvas._translationSettleDuration.inMilliseconds
            .toDouble(),
      ),
    ],
  ).animate(_progress);

  /// The reading frame opening, which is not a page turn and so is not
  /// [_progress].
  ///
  /// It runs only once the transition it follows has settled, and only on a
  /// page drawn in threes. Starting at 1 is what makes a cold start — or a
  /// rotation, or a reduced-motion jump — land on a page that is simply
  /// already grooved, with nothing to animate and nothing missing.
  late final AnimationController _groove = AnimationController(
    vsync: this,
    duration: AnatomyCanvas.grooveDuration,
    value: 1,
  );

  /// Both clocks, merged once. Built here rather than in `build` so the
  /// `CustomPaint` is handed the same Listenable every frame.
  late final Listenable _repaint = Listenable.merge(<Listenable>[
    _progress,
    _groove,
    if (widget.masking != null) widget.masking!,
  ]);

  Size _size = Size.zero;
  int _settled = 0;
  bool _reverse = false;
  AnatomyScene? _scene;
  Offset? _inert;

  /// Bumped whenever the scene is replaced, so a transition that was cancelled
  /// by the next swipe cannot settle on top of the one that replaced it.
  int _generation = 0;

  /// Bumped whenever [_settled] names a new stage. The scene is replaced far
  /// more often than that — a first layout, a rotation — so an arrival is
  /// reported against this rather than [_generation].
  int _arrivals = 0;

  /// The last arrival reported, so one arrival is never reported twice.
  int _reported = -1;

  @override
  void initState() {
    super.initState();
    _settled = widget.stageIndex;
    _progress.value = 1;
    _reportArrival();
  }

  /// Reports the arrival at [_settled] after this frame, unless the canvas has
  /// been sent on somewhere else by then.
  void _reportArrival() {
    final int arrival = _arrivals;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && arrival == _arrivals && _reported != arrival) {
        _reported = arrival;
        widget.onSettled?.call(_settled, 0);
      }
    });
  }

  @override
  void didUpdateWidget(AnatomyCanvas old) {
    super.didUpdateWidget(old);
    if (old.model != widget.model) {
      _settled = widget.stageIndex;
      _arrivals++;
      _rebuild();
      _reportArrival();
      return;
    }
    if (old.stageIndex != widget.stageIndex) {
      _move(old.stageIndex, widget.stageIndex);
    } else if (old.tracer != widget.tracer || old.viewport != widget.viewport) {
      _rebuild();
    }
  }

  /// The box the painter needs for a scene between [from] and [to].
  ///
  /// The maximum of the two, never just the destination's: a transition out of
  /// the transcript page starts with 465 cells spread over twice the screen,
  /// and a box sized to where they are going would clip most of them away
  /// before they set off.
  Size _boxFor(int from, int to) {
    final Size viewport = widget.viewport;
    double height = viewport.height;
    for (final int index in <int>{from, to}) {
      height = math.max(
        height,
        AnatomyLayout.heightFor(widget.model.stages[index], viewport),
      );
    }
    return Size(viewport.width, height);
  }

  @override
  void dispose() {
    _groove.dispose();
    _progress.dispose();
    super.dispose();
  }

  bool get _still => MediaQuery.disableAnimationsOf(context);

  /// Whether stage [index] is drawn in threes, and so has a frame to groove.
  bool _framed(int index) =>
      widget.model.stages[index].frameCodon(CodonMark.start).isNotEmpty;

  void _move(int from, int to) {
    // Reduced motion turns every stage change into a jump. Each stage still
    // says what it is standing still, so nothing is lost but the travel.
    if ((to - from).abs() != 1 || _still || _size.isEmpty) {
      _settled = to;
      _arrivals++;
      _rebuild();
      _reportArrival();
      return;
    }

    final int earlier = from < to ? from : to;
    final int generation = ++_generation;
    _reverse = to < from;
    _settled = to;
    _arrivals++;

    // A changed mind plays the current frame back. Recreating this scene at
    // either endpoint would teleport every codon before reversing direction.
    final AnatomyScene? active = _scene;
    if (_progress.isAnimating &&
        active?.translation != null &&
        active!.fromIndex == earlier &&
        active.toIndex == earlier + 1) {
      _run(generation);
      return;
    }
    final bool translating =
        widget.model.stages[earlier].kind == StageKind.mrna &&
        widget.model.stages[earlier + 1].kind == StageKind.protein;
    // Arriving at a page with a reading frame, the frame is not there yet: its
    // cells land flush and groove apart afterwards, so the reflow is the only
    // thing the eye has to follow while the reflow is what is happening.
    //
    // Leaving one, the groove is left exactly as it is — mid-sweep included.
    // Snapping it shut on the first frame of a departure would close a hundred
    // codons under a reader who was watching them go, and freezing it there
    // would send a block that is open at the top and flush at the bottom off
    // to be folded into residues.
    if (translating) {
      // The transcript's triplets remain open through translation, including
      // in reverse. A separate groove afterwards would undo the visible split.
      _groove.stop();
      if (_reverse) {
        _groove.value = 1;
      }
    } else if (_framed(to)) {
      _groove.value = 0;
    }
    _progress
      ..stop()
      ..duration = AnatomyCanvas.durationOf(
        widget.model.stages[earlier + 1].kind,
      )
      ..value = _reverse ? 1 : 0;

    _size = _boxFor(earlier, earlier + 1);
    _scene = AnatomyScene.between(
      model: widget.model,
      fromIndex: earlier,
      toIndex: earlier + 1,
      canvas: _size,
      viewport: widget.viewport,
      // Whichever page is being left is where the reader had scrolled it to.
      sourceScrollOffset: _reverse ? 0 : widget.sourceScrollOffset,
      targetScrollOffset: _reverse ? widget.sourceScrollOffset : 0,
    );
    _inert = _inertPoint();

    _run(generation);
  }

  void _run(int generation) {
    final TickerFuture run = _reverse
        ? _progress.reverse()
        : _progress.forward();
    run.whenCompleteOrCancel(() {
      if (mounted && generation == _generation) {
        final double scrollOffset = _reverse
            ? _scene?.translation?.sourceScrollOffset ?? 0
            : 0;
        _rebuild();
        if (_reported != _arrivals) {
          _reported = _arrivals;
          widget.onSettled?.call(_settled, scrollOffset);
        }
      }
    });
  }

  void _rebuild() {
    // A transition cut short — by a rotation, or a trace changed under it —
    // still ends on its stage, and says so.
    final bool cut = _progress.isAnimating;
    _generation++;
    _reverse = false;
    _progress
      ..stop()
      ..value = 1;
    if (cut) {
      _reportArrival();
    }
    if (!_framed(_settled) || _still) {
      // Nothing to open, or nothing to watch it with. Either way the page is
      // simply already grooved — reduced motion loses the travel here the same
      // way it loses it on a stage change, and says the same thing standing
      // still.
      _groove
        ..stop()
        ..value = 1;
    } else if (_groove.value < 1 && !_groove.isAnimating) {
      // Not restarted if it is already running: a tap lands here too, and a
      // reader who selects the start codon halfway through the sweep should
      // not see the sweep begin again under the caption that just answered.
      unawaited(_groove.forward());
    }
    _size = _boxFor(_settled, _settled);
    _scene = _size.isEmpty
        ? null
        : AnatomyScene.resting(
            model: widget.model,
            index: _settled,
            canvas: _size,
            viewport: widget.viewport,
          );
    _inert = _inertPoint();
    if (mounted) {
      setState(() {});
    }
  }

  /// Where to pin a ring for a base that was already gone before this scene.
  ///
  /// The base left during some earlier transition, and it drifted while it
  /// left — so the honest resting place is exactly where that drift ended,
  /// which is the same scene replayed to its last frame.
  Offset? _inertPoint() {
    final Tracer? tracer = widget.tracer;
    final AnatomyScene? scene = _scene;
    if (tracer == null || scene == null || _size.isEmpty) {
      return null;
    }
    if (scene.from.cellAt(tracer.genomicPosition) >= 0) {
      return null;
    }

    final int cut = TracerReader.cutAt(widget.model, tracer);
    if (cut < 1) {
      return null;
    }
    final AnatomyScene departure = AnatomyScene.between(
      model: widget.model,
      fromIndex: cut - 1,
      toIndex: cut,
      canvas: _boxFor(cut - 1, cut),
      viewport: widget.viewport,
    );
    final int cell = departure.from.cellAt(tracer.genomicPosition);
    if (cell < 0) {
      return null;
    }
    return departure.departurePoint(cell);
  }

  /// Called from inside `build`, so it assigns rather than calling `setState`:
  /// the new scene is consumed by the very frame that asked for it, and there
  /// is no blank first paint while a rebuild is scheduled.
  void _resize() {
    final Size size = _boxFor(_settled, _settled);
    if (size == _size && _scene != null) {
      return;
    }
    // A rotation mid-transition is left alone — replacing the scene there would
    // teleport every cell. The transition settles onto the new size instead.
    if (_progress.isAnimating || size.isEmpty) {
      return;
    }
    _size = size;
    _generation++;
    _scene = AnatomyScene.resting(
      model: widget.model,
      index: _settled,
      canvas: size,
      viewport: widget.viewport,
    );
    _inert = _inertPoint();
  }

  void _handleTap(TapUpDetails details) {
    // Endpoint hit testing cannot identify a tile while it is folding or
    // travelling. Wait for the layout to settle before accepting a selection.
    if (_progress.isAnimating) {
      return;
    }
    final AnatomyScene? scene = _scene;
    if (scene == null) {
      return;
    }
    final bool arrived = !scene.isTransition || _progress.value >= 0.5;
    final AnatomyLayout layout = (arrived ? scene.toLayout : scene.fromLayout)
        .opened(_groove.value.clamp(0.0, 1.0));
    final AnatomyStage stage = arrived ? scene.to : scene.from;

    // The released chains are the one page that answers for itself: every
    // residue there is already named, numbered and, where it is bonded, ringed
    // with its bridge. A tap only left a box behind — one that travelled back
    // to the precursor with the reader. Nothing is selected here; a trace
    // carried in from the precursor can still be let go of.
    if (stage.kind == StageKind.maturePeptides) {
      widget.onTapped(null, asRun: false);
      return;
    }

    final int cell = layout.hitTest(details.localPosition);

    // A tap means whatever the page is drawn in terms of. The gene is drawn as
    // regions, and a region is hundreds of cells wide and impossible to miss.
    // A residue is one square, lettered, and answers for itself. On the
    // transcript a base is a 20pt lettered square too, and what a reader asks
    // of one is its codon: the tracer marks the three and names them.
    final bool region = stage.kind == StageKind.gene;
    widget.onTapped(
      cell < 0 ? null : stage.positionAt(cell),
      asRun: cell >= 0 && region,
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AnatomyStage stage = widget.model.stages[widget.stageIndex];

    _resize();
    final AnatomyScene? scene = _scene;
    final Size box = _size.isEmpty ? widget.viewport : _size;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapUp: _handleTap,
      onLongPress: widget.onLongPress,
      child: Semantics(
        // Serpentine order means nothing to a screen reader, and a grid
        // coordinate means nothing to a biologist. Sequence position is the
        // only address that is meaningful to both.
        label:
            '${stage.label}, ${stage.count} ${stage.unit}, '
            'drawn 5 prime to 3 prime',
        customSemanticsActions: widget.onLongPress == null
            ? null
            : <CustomSemanticsAction, VoidCallback>{
                const CustomSemanticsAction(
                  label: 'Copy sequence as FASTA',
                ): widget.onLongPress!,
              },
        excludeSemantics: widget.constraint == null,
        child: RepaintBoundary(
          child: CustomPaint(
            painter: scene == null
                ? null
                : AnatomyPainter(
                    repaint: _repaint,
                    scene: scene,
                    progress: scene.translation == null
                        ? _progress
                        : _translationProgress,
                    groove: _groove,
                    reverse: _reverse,
                    // A masked residue is the sheet's to describe; otherwise a
                    // trace carried onto a scored page still shows where it is.
                    tracer: widget.maskedIndex == null ? widget.tracer : null,
                    status: widget.status,
                    inertTracer: _inert,
                    background: theme.colorScheme.surface,
                    nucleotides: context.nucleotideColors,
                    anatomy: context.anatomyColors,
                    constraint: widget.constraint,
                    conservation: widget.conservation,
                    maskedIndex: widget.maskedIndex,
                    masking: widget.masking,
                    maskAccent: theme.colorScheme.primary,
                    onConstraintTapped: (int index) =>
                        widget.onTapped(stage.positionAt(index), asRun: false),
                    rulerInk: theme.colorScheme.onSurfaceVariant,
                    bridges: widget.bridges,
                    marks: widget.marks,
                  ),
            willChange: true,
            size: box,
          ),
        ),
      ),
    );
  }
}
