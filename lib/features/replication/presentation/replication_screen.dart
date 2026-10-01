import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../shared/anatomy/sequence_scrubber.dart';
import '../../../shared/motion/timeline_controller.dart';
import '../../../shared/motion/transport_bar.dart';
import '../domain/replication_tour.dart';
import 'replication_inks.dart';
import 'replication_molecules.dart';
import 'replication_scene.dart';

/// A local, immediately playable view of genome replication. No catalog, gene
/// record or network request is needed to enter the animation.
class ReplicationScreen extends StatefulWidget {
  const ReplicationScreen({super.key});

  static const Duration beat = Duration(seconds: 1);

  @override
  State<ReplicationScreen> createState() => _ReplicationScreenState();
}

class _ReplicationScreenState extends State<ReplicationScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  static const ReplicationTimeline _timeline = ReplicationTimeline();
  late final TimelineController _controller = TimelineController(
    vsync: this,
    timeline: _timeline,
    beat: ReplicationScreen.beat,
  );
  // Switching between the whole fork and the guided close-ups glides rather
  // than cuts; with reduced motion it cuts.
  late final AnimationController _follow = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 500),
    value: 1,
  );
  final ReplicationMolecules _molecules = ReplicationMolecules();
  bool _labels = true;
  bool _followCamera = true;
  bool _resumeOnForeground = false;

  void _toggleFollow() {
    setState(() => _followCamera = !_followCamera);
    final double target = _followCamera ? 1 : 0;
    if (MediaQuery.disableAnimationsOf(context)) {
      _follow.value = target;
    } else {
      _follow.animateTo(target, curve: Curves.linear);
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _controller.reducedMotion = MediaQuery.disableAnimationsOf(context);
      if (!_controller.reducedMotion) _controller.play();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (_resumeOnForeground) _controller.play();
      _resumeOnForeground = false;
    } else if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _resumeOnForeground = _resumeOnForeground || _controller.isPlaying;
      _controller.pause();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    _follow.dispose();
    _molecules.dispose();
    super.dispose();
  }

  Future<void> _showScience() async {
    final bool resume = _controller.isPlaying;
    _controller.pause();
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (BuildContext context) => const _ScienceSheet(),
    );
    if (mounted && resume && !_controller.reducedMotion) _controller.play();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final ReplicationInks inks = ReplicationInks.of(context);
    final double textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: math.max(kToolbarHeight, 44 * textScale),
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              'Replication',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              'Human DNA · 200 bp',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
        actions: <Widget>[
          IconButton(
            tooltip: _labels ? 'Hide molecule labels' : 'Show molecule labels',
            onPressed: () => setState(() => _labels = !_labels),
            icon: Icon(
              _labels ? Icons.label_outline_rounded : Icons.label_off_outlined,
            ),
          ),
          IconButton(
            tooltip: 'About this replication model',
            onPressed: _showScience,
            icon: const Icon(Icons.info_outline_rounded),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            // Let the scene take the space recovered from the old header,
            // horizontal slider and long captions. Small screens still scroll.
            final double canvasHeight = math.max(
              320,
              constraints.maxHeight - 164 - math.max(0, textScale - 1) * 140,
            );
            return SingleChildScrollView(
              key: const ValueKey<String>('replication-scroll'),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 620),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      SizedBox(
                        height: canvasHeight,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            Expanded(
                              child: Stack(
                                fit: StackFit.expand,
                                children: <Widget>[
                                  AnimatedBuilder(
                                    animation: _controller,
                                    builder:
                                        (BuildContext context, Widget? child) =>
                                            Semantics(
                                              label: _timeline
                                                  .stateAt(_controller.t)
                                                  .description,
                                              image: true,
                                              child: child,
                                            ),
                                    child: RepaintBoundary(
                                      child: CustomPaint(
                                        key: const ValueKey<String>(
                                          'replication-canvas',
                                        ),
                                        size: Size.infinite,
                                        painter: ReplicationScene(
                                          timeline: _timeline,
                                          at: () => _controller.t,
                                          molecules: _molecules,
                                          inks: inks,
                                          showLabels: _labels,
                                          followCamera: _followCamera,
                                          followBlend: () => _follow.value,
                                          reducedMotion:
                                              MediaQuery.disableAnimationsOf(
                                                context,
                                              ),
                                          repaint: Listenable.merge(
                                            <Listenable>[_controller, _follow],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    top: 0,
                                    left: 4,
                                    child: TextButton.icon(
                                      onPressed: _toggleFollow,
                                      icon: Icon(
                                        _followCamera
                                            ? Icons.zoom_out_map_rounded
                                            : Icons.center_focus_strong_rounded,
                                        size: 16,
                                      ),
                                      label: Text(
                                        _followCamera
                                            ? 'Whole fork'
                                            : 'Follow steps',
                                      ),
                                      style: TextButton.styleFrom(
                                        backgroundColor: colors.surface
                                            .withValues(alpha: 0.92),
                                        foregroundColor:
                                            colors.onSurfaceVariant,
                                        textStyle: theme.textTheme.labelSmall,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(
                              width: SequenceScrubber.width,
                              child: TimelineScrubber(
                                key: const ValueKey<String>('replication-seek'),
                                controller: _controller,
                                landmarks: <(double, String)>[
                                  for (final mark in _timeline.phases)
                                    (mark.t, mark.name),
                                ],
                                labelAt: (double t) =>
                                    '${(t * _timeline.beats).round()} / ${_timeline.beats} s',
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 16,
                          runSpacing: 6,
                          children: <Widget>[
                            _Legend('Parental', inks.parental),
                            _Legend('New DNA', inks.newDna),
                            _Legend('RNA', inks.rna),
                          ],
                        ),
                      ),
                      AnimatedBuilder(
                        animation: _controller,
                        builder: (BuildContext context, Widget? child) =>
                            Padding(
                              padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  minHeight: 42 * textScale,
                                ),
                                child: Text(
                                  _timeline.stateAt(_controller.t).caption,
                                  key: const ValueKey<String>(
                                    'replication-caption',
                                  ),
                                  style: theme.textTheme.bodyMedium,
                                ),
                              ),
                            ),
                      ),
                      TransportBar(
                        controller: _controller,
                        speeds: const <double>[0.25, 0.5, 1, 1.5, 2],
                      ),
                      const SizedBox(height: 4),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend(this.label, this.color);
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: <Widget>[
      Container(
        width: 13,
        height: 3,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
      const SizedBox(width: 6),
      Flexible(
        child: Text(label, style: Theme.of(context).textTheme.bodySmall),
      ),
    ],
  );
}

class _ScienceSheet extends StatelessWidget {
  const _ScienceSheet();

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    Widget paragraph(String title, String body) => Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title, style: text.titleSmall),
          const SizedBox(height: 6),
          Text(body, style: text.bodyMedium),
        ],
      ),
    );
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.8,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          children: <Widget>[
            Text('From an origin to two forks', style: text.titleLarge),
            const SizedBox(height: 22),
            paragraph(
              'Where replication starts',
              'Human chromosomes are copied from many origins in S phase. '
                  'In G1, ORC and Cdc6 bind an origin and, with Cdt1, load two '
                  'MCM2–7 rings head to head around the duplex: the '
                  'pre-replication complex. In S phase, the kinases DDK and CDK '
                  'add Cdc45 and GINS to each ring, making two CMG helicases. '
                  'The DNA melts first where it is A/T-rich: an A·T pair has two '
                  'hydrogen bonds and a G·C pair three, and A/T steps stack less '
                  'tightly. Human origins share no consensus sequence; this one '
                  'is drawn A/T-rich to show where melting starts.',
            ),
            paragraph(
              'Two forks',
              'The two CMGs pass each other and move apart, so one origin '
                  'makes two forks that copy in opposite directions. Each '
                  'fork’s leading strand starts at the origin and its lagging '
                  'strand ends there: each fork’s first Okazaki fragment '
                  'replaces the other fork’s leading primer. The animation then '
                  'follows the upper fork through two 100-nucleotide fragments. '
                  'The lower fork is drawn as its mirror image; in cells the two '
                  'move independently. The sequence is illustrative, not a '
                  'particular gene or a measured genomic locus.',
            ),
            paragraph(
              'The human machinery',
              'CMG unwinds the DNA by ATP hydrolysis in its MCM2–7 ring; the '
                  'animation lights its six ATPase sites in turn. RPA, the human '
                  'single-strand binding protein, coats exposed single strands, '
                  'which keeps them from reannealing and protects them from '
                  'nucleases. Primase lays a short RNA primer because DNA '
                  'polymerases cannot start a chain: they only extend an existing '
                  '3′ end. Pol α adds a short DNA stretch; RFC opens the PCNA '
                  'ring, a homotrimer, and closes it round the primer end. Pol ε '
                  'extends the leading strand and Pol δ the lagging fragments, '
                  'each on PCNA. Both new strands grow 5′ → 3′.',
            ),
            paragraph(
              'Supercoiling',
              'Unwinding overwinds the DNA ahead of each fork into positive '
                  'supercoils. Topoisomerase II, a dimer, captures a crossing '
                  'duplex, cuts the duplex it holds through both strands with two '
                  'tyrosines that stay bound to the cut ends, passes the captured '
                  'duplex through the break and reseals it, using ATP. Type I '
                  'topoisomerase (TOP1) relieves the same strain by nicking one '
                  'strand and letting the DNA swivel. Both act ahead of human '
                  'forks.',
            ),
            paragraph(
              'From fragments to a continuous strand',
              'This view shows a short-flap route: Pol δ displaces the earlier '
                  'primer as it synthesizes DNA, FEN1 cleaves each flap, and DNA '
                  'ligase I seals the nick. RNase H2 and DNA2 can also help process '
                  'primers in cells. The newest primer remains until the next '
                  'fragment reaches it, beyond this window.',
            ),
            paragraph(
              'Reading the animation',
              'Grey is parental DNA, teal new DNA and amber RNA; each strand’s '
                  'bases wear its colour, so which strand is old or new reads at '
                  'a glance. At the origin, the lines between paired bases count '
                  'their hydrogen bonds. The scene samples bases and enlarges and '
                  'separates the proteins to expose their work. Shapes, spacing '
                  'and motion are illustrative. The camera visits processes that '
                  'occur together. Playback takes 3 min 32 s at 1×; this is a '
                  'teaching sequence, not a cellular clock. Chromatin, '
                  'proofreading and most accessory factors are outside this view.',
            ),
            Text('Research & structures', style: text.titleSmall),
            const SizedBox(height: 8),
            const _SourceLink(
              'Human origins share no consensus sequence',
              'Prioleau & MacAlpine, 2016 · Genes & Development',
              'https://doi.org/10.1101/gad.285114.116',
            ),
            const _SourceLink(
              'MCM2–7 loaded as a double hexamer',
              'Remus et al., 2009 · Cell',
              'https://doi.org/10.1016/j.cell.2009.10.015',
            ),
            const _SourceLink(
              'How CMG helicase is activated',
              'Douglas et al., 2018 · Nature',
              'https://doi.org/10.1038/nature25787',
            ),
            const _SourceLink(
              'Human replisome · cryo-EM structure',
              'Jones et al., 2021 · PDB 7PFO',
              'https://www.rcsb.org/structure/7PFO',
            ),
            const _SourceLink(
              'Human PCNA, the sliding clamp',
              'Gulbis et al., 1996 · PDB 1AXC',
              'https://www.rcsb.org/structure/1AXC',
            ),
            const _SourceLink(
              'Human topoisomerase II cutting DNA',
              'Wu et al., 2011 · PDB 3QX3',
              'https://www.rcsb.org/structure/3QX3',
            ),
            const _SourceLink(
              'Topoisomerase IIα relaxes positive supercoils',
              'McClendon et al., 2005 · J Biol Chem',
              'https://doi.org/10.1074/jbc.M503320200',
            ),
            const _SourceLink(
              'How primase is positioned at the fork',
              'Jones et al., 2023 · Molecular Cell',
              'https://doi.org/10.1016/j.molcel.2023.06.035',
            ),
            const _SourceLink(
              'Human Okazaki-fragment maturation',
              'Raducanu et al., 2022 · Nature Communications',
              'https://doi.org/10.1038/s41467-022-34751-2',
            ),
            const _SourceLink(
              'How PCNA coordinates DNA ligase I',
              'Blair et al., 2022 · Nature Communications',
              'https://doi.org/10.1038/s41467-022-35475-z',
            ),
          ],
        ),
      ),
    );
  }
}

class _SourceLink extends StatelessWidget {
  const _SourceLink(this.title, this.subtitle, this.url);
  final String title;
  final String subtitle;
  final String url;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    title: Text(title, style: Theme.of(context).textTheme.bodyMedium),
    subtitle: Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
    trailing: const Icon(Icons.open_in_new_rounded, size: 17),
    onTap: () async {
      bool opened = false;
      try {
        opened = await launchUrl(Uri.parse(url));
      } catch (_) {
        // An unsupported platform should leave the readable reference in place.
      }
      if (!opened && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open the source. $url')),
        );
      }
    },
  );
}
