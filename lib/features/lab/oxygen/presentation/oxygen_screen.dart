import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/catalog/protein_target.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/motion/timeline_controller.dart';
import '../../../../shared/motion/transport_bar.dart';
import '../../../../shared/structure/structure_rotation.dart';
import '../../../../shared/structure/structure_view.dart';
import '../../../../shared/widgets/error_view.dart';
import '../../../../shared/widgets/loading_view.dart';
import '../../../gene_lookup/data/repositories/protein_catalog_repository.dart';
import '../domain/binding_timeline.dart';
import '../domain/mwc.dart';
import '../domain/oxygen_captions.dart';
import '../domain/oxygen_morph.dart';
import 'oxygen_cubit.dart';
import 'oxygen_painters.dart';

/// `/lab/oxygen`: the assembly's oxygen binding, and the one-site contrast.
class OxygenRoute extends StatelessWidget {
  const OxygenRoute({this.source, super.key});

  /// Where the morph comes from; the service, unless a test says otherwise.
  final AssemblySource? source;

  static const String title = 'Oxygen';

  @override
  Widget build(BuildContext context) => BlocProvider<OxygenCubit>(
    create: (BuildContext context) =>
        OxygenCubit(source ?? ServiceAssemblySource(context.read<ApiClient>()))
          ..load(),
    child: BlocBuilder<OxygenCubit, OxygenState>(
      builder: (BuildContext context, OxygenState state) => switch (state) {
        OxygenLoading() => Scaffold(
          appBar: AppBar(title: const Text(title)),
          body: const LoadingView(label: 'LOADING'),
        ),
        OxygenFailed(:final String message) => Scaffold(
          appBar: AppBar(title: const Text(title)),
          body: ErrorView(
            title: 'Fetch failed',
            message: message,
            onRetry: () => context.read<OxygenCubit>().load(),
          ),
        ),
        OxygenUnavailable() => Scaffold(
          appBar: AppBar(title: const Text(title)),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.screenPadding),
              child: Text(
                'The two states this is drawn from are not published yet.',
                key: const ValueKey<String>('oxygen-unavailable'),
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
        OxygenReady(:final OxygenMorph morph) => OxygenScreen(
          morph: morph,
          contrast: context.read<ProteinCatalogRepository?>()?.bySlug(
            oneSiteContrast,
          ),
        ),
      },
    ),
  );
}

/// Oxygen binding one molecule at a time. The tetramer moves between tense and
/// relaxed as the MWC model says a molecule with that many bound does, and the
/// saturation curve the model gives draws itself alongside, its point marked.
/// pH, fetal hemoglobin and the one-site contrast each change the model, and
/// so the curve and the animation together.
class OxygenScreen extends StatefulWidget {
  const OxygenScreen({required this.morph, this.contrast, super.key});

  final OxygenMorph morph;

  /// The one-site protein, drawn by its own structure track where the catalog
  /// holds it.
  final ProteinTarget? contrast;

  static const Duration beat = Duration(milliseconds: 1100);

  static String titleOf(OxygenMorph morph) => 'Oxygen · ${morph.display}';

  @override
  State<OxygenScreen> createState() => _OxygenScreenState();
}

class _OxygenScreenState extends State<OxygenScreen>
    with TickerProviderStateMixin {
  Carrier _carrier = Carrier.adult;
  double _ph = OxygenModel.neutralPh;
  late Mwc _model;
  late BindingTimeline _timeline;
  late TimelineController _controller;
  final StructureRotation _rotation = StructureRotation();
  final ValueNotifier<int> _turns = ValueNotifier<int>(0);

  @override
  void initState() {
    super.initState();
    _build();
  }

  void _build() {
    _model = OxygenModel.of(_carrier, _ph);
    _timeline = BindingTimeline(_model);
    _controller = TimelineController(
      vsync: this,
      timeline: _timeline,
      beat: OxygenScreen.beat,
    );
  }

  void _change({Carrier? carrier, double? ph}) {
    setState(() {
      _controller.dispose();
      _carrier = carrier ?? _carrier;
      _ph = ph ?? _ph;
      _build();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _turns.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final TextStyle? note = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final OxygenCaptions captions = OxygenCaptions(_model, _carrier, _ph);
    final OxygenMorph morph = widget.morph;
    final bool oneSite = _carrier == Carrier.oneSite;
    return Scaffold(
      appBar: AppBar(title: Text(OxygenScreen.titleOf(morph))),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.screenPadding,
          ),
          children: <Widget>[
            SizedBox(
              height: 300,
              child: oneSite
                  ? LayoutBuilder(
                      builder: (BuildContext context, BoxConstraints box) =>
                          widget.contrast == null
                          ? Center(child: Text(captions.mechanism, style: note))
                          : StructureView(
                              viewport: box.biggest,
                              target: widget.contrast!,
                            ),
                    )
                  : LayoutBuilder(
                      builder: (BuildContext context, BoxConstraints box) =>
                          Stack(
                            fit: StackFit.expand,
                            children: <Widget>[
                              AnimatedBuilder(
                                animation: _controller,
                                builder:
                                    (BuildContext context, Widget? child) =>
                                        Semantics(
                                          label: TetramerPainter.describe(
                                            morph,
                                            _timeline.stateAt(_controller.t),
                                          ),
                                          child: child,
                                        ),
                                child: RepaintBoundary(
                                  child: CustomPaint(
                                    key: const ValueKey<String>(
                                      'oxygen-tetramer',
                                    ),
                                    size: Size.infinite,
                                    painter: TetramerPainter(
                                      morph: morph,
                                      timeline: _timeline,
                                      at: () => _controller.t,
                                      rotation: () => _rotation.value,
                                      inks: TetramerInks.of(context),
                                      repaint: Listenable.merge(<Listenable>[
                                        _controller,
                                        _turns,
                                      ]),
                                    ),
                                  ),
                                ),
                              ),
                              TurnZone(
                                viewport: box.biggest,
                                onTurn: (DragUpdateDetails details) {
                                  _rotation.drag(details.delta);
                                  _turns.value++;
                                },
                              ),
                            ],
                          ),
                    ),
            ),
            SizedBox(
              height: 170,
              child: RepaintBoundary(
                child: CustomPaint(
                  key: const ValueKey<String>('oxygen-curve'),
                  painter: SaturationPainter(
                    model: _model,
                    timeline: _timeline,
                    at: () => _controller.t,
                    ink: theme.colorScheme.onSurface,
                    quiet: theme.colorScheme.onSurfaceVariant,
                    accent: theme.colorScheme.primary,
                    label:
                        theme.textTheme.labelSmall ??
                        const TextStyle(fontSize: 11),
                    baseline:
                        _carrier == Carrier.adult &&
                            _ph == OxygenModel.neutralPh
                        ? null
                        : OxygenModel.adult,
                    repaint: _controller,
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: <Widget>[
                SegmentedButton<Carrier>(
                  key: const ValueKey<String>('oxygen-carrier'),
                  segments: <ButtonSegment<Carrier>>[
                    const ButtonSegment<Carrier>(
                      value: Carrier.adult,
                      label: Text('Adult'),
                    ),
                    const ButtonSegment<Carrier>(
                      value: Carrier.fetal,
                      label: Text('Fetal'),
                    ),
                    ButtonSegment<Carrier>(
                      value: Carrier.oneSite,
                      label: Text(widget.contrast?.display ?? 'One site'),
                    ),
                  ],
                  selected: <Carrier>{_carrier},
                  onSelectionChanged: (Set<Carrier> chosen) =>
                      _change(carrier: chosen.single),
                ),
                SegmentedButton<double>(
                  key: const ValueKey<String>('oxygen-ph'),
                  segments: <ButtonSegment<double>>[
                    for (final double ph in OxygenModel.phs)
                      ButtonSegment<double>(
                        value: ph,
                        label: Text('pH ${ph.toStringAsFixed(1)}'),
                      ),
                  ],
                  selected: <double>{_ph},
                  onSelectionChanged: oneSite
                      ? null
                      : (Set<double> chosen) => _change(ph: chosen.single),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            AnimatedBuilder(
              animation: _controller,
              builder: (BuildContext context, _) => Text(
                captions.captionOf(
                  (_controller.t * _model.sites).floor().clamp(
                        0,
                        _model.sites - 1,
                      ) +
                      1,
                ),
                key: const ValueKey<String>('oxygen-caption'),
                style: theme.textTheme.bodyMedium,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              captions.mechanism,
              key: const ValueKey<String>('oxygen-mechanism'),
              style: note,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              captions.shift,
              key: const ValueKey<String>('oxygen-shift'),
              style: note,
            ),
            if (!oneSite) ...<Widget>[
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Tense is ${morph.entries['tense']}, relaxed '
                '${morph.entries['relaxed']}: one alpha-beta pair held still, '
                'the other turns ${morph.turnedDegrees.toStringAsFixed(0)} '
                'degrees as it relaxes. Textbook-scale numbers; an '
                'illustration of the mechanism.',
                key: const ValueKey<String>('oxygen-states'),
                style: note,
              ),
            ],
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: TransportBar(controller: _controller),
            ),
          ],
        ),
      ),
    );
  }
}
