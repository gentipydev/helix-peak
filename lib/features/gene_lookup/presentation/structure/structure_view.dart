import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

import '../../../../core/theme/anatomy_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/entities/protein_target.dart';
import 'structure_loading_view.dart';
import 'structure_rotation.dart';

/// What the chain folds into, once the grid has run out of things to say.
///
/// Every page before this one is flat lettered squares, and a square is good at
/// two questions: *which residue*, and *which piece of the molecule*. It cannot
/// answer the third. Nothing in a grid explains why cutting insulin into three
/// pieces leaves a working hormone rather than three fragments, or why a
/// hundred and thirty residues of lysozyme close around a cleft exactly wide
/// enough for a bacterial cell wall.
///
/// Where disulfide bridges are the answer — insulin's A7-B7 and A20-B19 hold
/// the two mature chains together, and A6-A11 closes a loop inside the A chain
/// — they are drawn as rods rather than left to the ribbon, because a cartoon
/// representation hides cysteine side chains and would put the one fact the
/// page is for out of sight. A protein whose story is not its bridges is drawn
/// without them; see [ProteinTarget.chains].
///
/// The geometry is crystallographic, one entry per protein, chosen and baked by
/// `tool/structure/`: human insulin is RCSB `3I40`, X-ray at 1.85 A. Not the
/// AlphaFold model of the gene's own translation product, which predicts the
/// full 110-residue preproprotein at a mean pLDDT of 52.9 with half its
/// residues below 50 — that is the *third* page's molecule anyway, and it is
/// predicted to be largely disordered, so it would draw a coil of
/// low-confidence loops exactly where the reader has been promised a hormone.
///
/// Which nodes a model has, and what each is called, is the target's to say:
/// see [ProteinTarget.chains]. A protein that folds as one chain has no
/// `chainB`; one with no disulfides worth the page has no `bonds`.
///
/// ## Colour
///
/// A chain keeps the colour it had as squares one page earlier — the tokens the
/// grid's mature-peptide stage assigns, which for insulin makes B
/// [AnatomyColors.roleMature1] and A [AnatomyColors.roleMature3]. That
/// continuity is the point of the page rather than a nicety: the reader has to
/// recognise the fold as *these chains* and not as a new picture, and the
/// colour is the only thing carrying that across the transition.
///
/// The bridges take [AnatomyColors.aminoCysteine], which needs no special case:
/// they are cystines, and that is already the residue's colour in the palette.
///
/// The tokens are sRGB and glTF's `baseColorFactor` is linear, so they are
/// converted on the way in. What lands on screen is still the token *as lit* —
/// image-based lighting and the resolve pass's tone mapping both move it — and
/// that is wanted here: flat fills would draw a silhouette, and the shading is
/// what makes the fold legible as a three-dimensional thing at all.
///
/// ## Where the drags go
///
/// A sideways drag means two things on this page and only one of them can win.
/// Every other page of the walk reads it as a page turn; here it is also the
/// drag that spins the molecule about its own axis, which is the *useful* one —
/// yaw is what brings the far side of a fold round, and a model that can only
/// be tipped up and down cannot be turned around at all.
///
/// So the two meanings are given different ground rather than fought over. The
/// model is drawn across the whole box, and a [TurnZone] over the middle of it
/// takes the drags: inside that square a finger belongs to the molecule
/// whichever way it moves, and the walk's swipe is not on offer. Above and
/// below it the page keeps the bands the square leaves over, where the screen's
/// own gesture is untouched — and past those again lies the strip the paginator
/// floats in, which is not this view's box at all and was always the screen's.
///
/// The bands cost the picture nothing, because the picture is still the whole
/// box: the square is a place to put a finger, not a frame around the molecule,
/// and the camera's framing never learns it is there.
class StructureView extends StatefulWidget {
  const StructureView({
    required this.viewport,
    required this.target,
    this.legend = const <(Color, String)>[],
    super.key,
  });

  /// The box the page is given, matching what the grid stages are handed.
  final Size viewport;

  /// Which protein's model to draw, and what to call it.
  final ProteinTarget target;

  /// What each colour on the model is, in the words of the page before it:
  /// the chains the reader just saw as squares, and the bridges between them.
  final List<(Color, String)> legend;

  /// Does the one-time part of drawing the fold ahead of the page.
  ///
  /// The first time a process draws the molecule, the renderer loads its
  /// shader library, uploads the model, builds its lighting environment and
  /// compiles its render pipelines — and all of it runs on the UI thread, where
  /// nothing else moves until it is done. Done on the page, that held the
  /// loading pulse still on its first frame for most of a second on a first
  /// launch. Every one of those results is cached for the life of the process,
  /// so the cost is paid once, and it can be paid where nobody is watching: the
  /// walk calls this while it is at rest, pages before the fold.
  ///
  /// Calling it again returns the same future. A failure is not kept, so the
  /// next call, or the page itself, tries again.
  static Future<void> prepare(BuildContext context, ProteinTarget target) =>
      _prepareWith(Theme.of(context).extension<AnatomyColors>()!, target);

  /// Keyed by protein: most of what warming buys — the shader library, the
  /// lighting environment, the render pipelines — is shared and paid once
  /// whichever model asks for it first, but the model upload is not, and a
  /// reader who walks two proteins should not pay it on the second page.
  static final Map<String, Future<void>> _preparing = <String, Future<void>>{};

  /// The proteins whose warming has finished, so their page can draw the fold
  /// within a few frames and has no wait to show a pulse for.
  static final Set<String> _warmed = <String>{};

  static Future<void> _prepareWith(AnatomyColors anatomy, ProteinTarget target) {
    return _preparing[target.slug] ??= _warm(anatomy, target)
        .then((_) {
          _warmed.add(target.slug);
        })
        .catchError((Object error, StackTrace stack) {
          _preparing.remove(target.slug);
          Error.throwWithStackTrace(error, stack);
        });
  }

  static Future<void> _warm(AnatomyColors anatomy, ProteinTarget target) async {
    // A scene of its own, dropped as soon as it has been drawn: all that is
    // wanted from it is what drawing it leaves in the caches.
    final Scene scene = Scene();
    // The pulse too, so that its first frame on the page is not a blank one
    // spent reading the asset.
    await StructureLoadingView.preload();
    await _StructureViewState._build(scene, anatomy, target);
  }

  @override
  State<StructureView> createState() => _StructureViewState();
}

class _StructureViewState extends State<StructureView> {
  /// Built in [_load] and not here.
  ///
  /// Constructing a [Scene] reaches straight for the GPU context, so a field
  /// initialiser would throw the moment this widget is mounted anywhere that
  /// has no Flutter GPU — a widget test, or a build where the platform flag was
  /// never set. The rule the engine states for geometry and materials, that
  /// nothing may be built before [Scene.initializeStaticResources] completes,
  /// covers the scene itself as well.
  Scene? _scene;

  Node? _molecule;
  PerspectiveCamera? _camera;
  bool _ready = false;
  bool _failed = false;

  /// Whether the reader has turned the model yet. Until they have, a line
  /// under it says that they can.
  bool _turned = false;

  /// Read once per dependency change rather than once per frame.
  bool _reducedMotion = false;

  /// Whether the model was already warm when the page opened. Then the load is
  /// a few frames, and a pulse for them would read as a flicker, not a wait:
  /// the page holds still instead.
  late final bool _warmAtOpen = StructureView._warmed.contains(widget.target.slug);

  final StructureRotation _rotation = StructureRotation();

  /// How far back of a snug fit the camera sits.
  ///
  /// The model is normalised to a longest axis of 1 when it is baked, so the
  /// camera is framed once and left alone: `framing` fits the bounding sphere,
  /// and every rotation stays inside that same sphere, so nothing here needs a
  /// scale constant and nothing can swing out of shot.
  ///
  /// Measured on the page, and it has to be measured on *this* page. `framing`
  /// fits to the vertical field of view, so the shorter the box the larger the
  /// molecule: judged in a full-screen harness 1.35 looked lost, but the page
  /// gives up 96 points to the header and 48 to the stage bar, and in that
  /// box the same number is right. At 1.15 the silhouette reached 96% of the
  /// width and touched both edges. 1.35 holds it near 82%, which leaves the
  /// widest yaw — the x-z diagonal, 1.30 against the longest axis' 1.0 — clear
  /// of the sides.
  static const double _framingMargin = 1.35;

  /// How long the pulse plays before any renderer work starts.
  ///
  /// Once [StructureView.prepare] has run, the rest of the load finishes in
  /// well under a tenth of a second, which on its own left the pulse on screen
  /// for about four frames: a green blot that flickered and was gone, reading
  /// as a glitch rather than as loading. The asset plays at 90 fps and starts a
  /// new ring every 30 frames, so one second is three rings — enough for it to
  /// read as a pulse rather than a flicker.
  static const Duration _pulseMinimum = Duration(seconds: 1);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reducedMotion = MediaQuery.disableAnimationsOf(context);
  }

  Future<void> _load() async {
    // Constructing a Scene eagerly reads the GPU context, which throws at once
    // when there is no usable one — the package documents this as the fail-fast
    // probe its own GPU-gated suites skip on, so it is used as one here. It has
    // to come first: everything below assumes a context exists.
    final Scene scene;
    try {
      scene = Scene();
    } on Object catch (error) {
      // Flutter GPU is opted into per platform and a headless test never has it
      // at all. One page that cannot draw is not worth taking the other four
      // down with it, so this is reported in place and the walk survives.
      debugPrint('helixpeek: no Flutter GPU for the structure page ($error)');
      if (mounted) {
        setState(() => _failed = true);
      }
      return;
    }

    try {
      // Decode the pulse and let it paint before anything else starts.
      await StructureLoadingView.preload();
      if (!mounted) {
        return;
      }
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) {
        return;
      }

      // Then let it play, untouched, before any renderer work begins. Whatever
      // of that work still costs frames — all of it, if the walk never got to
      // prepare — lands at the end, just before the fold replaces the pulse,
      // and never on the pulse's first frames. A warm model has no such work
      // left, and no pulse to hold.
      if (!_warmAtOpen) {
        await Future<void>.delayed(_pulseMinimum);
        if (!mounted) {
          return;
        }
      }

      final AnatomyColors anatomy = Theme.of(context)
          .extension<AnatomyColors>()!;
      await StructureView._prepareWith(anatomy, widget.target);
      if (!mounted) {
        return;
      }
      final (Node molecule, PerspectiveCamera camera) = await _build(
        scene,
        anatomy,
        widget.target,
      );
      if (!mounted) {
        return;
      }

      setState(() {
        _scene = scene;
        _molecule = molecule;
        _camera = camera;
        _ready = true;
      });
    } on Object catch (error) {
      debugPrint('helixpeek: could not load the structure ($error)');
      if (mounted) {
        setState(() => _failed = true);
      }
    }
  }

  /// Loads the molecule into [scene], paints and frames it, and compiles what
  /// its first frame needs.
  ///
  /// [StructureView.prepare] runs this into a scene it then drops, so that
  /// when the page runs it for real everything expensive is already cached.
  static Future<(Node, PerspectiveCamera)> _build(
    Scene scene,
    AnatomyColors anatomy,
    ProteinTarget target,
  ) async {
    await Scene.initializeStaticResources();
    if (!Scene.isReadyToRender) {
      throw StateError('The 3D renderer did not initialize');
    }
    final Node molecule = await loadScene(target.structureAsset);
    for (final StructureChain chain in target.chains) {
      _paint(molecule, target, chain.node, chain.tint.of(anatomy));
    }

    scene.add(molecule);
    final vm.Aabb3? bounds = molecule.combinedWorldBounds;
    final PerspectiveCamera camera = bounds == null
        ? PerspectiveCamera()
        : PerspectiveCamera.framing(bounds, margin: _framingMargin);

    // Compile the pipelines the first frame needs before the SceneView is
    // mounted, rather than letting it warm up behind a loadingBuilder: that
    // builder is a second pulse, mounted in the frame the page's own is torn
    // down, and it starts over from frame 0. This is the same single view the
    // SceneView would warm up with.
    await scene.warmUp(<RenderView>[RenderView(camera: camera)]);
    return (molecule, camera);
  }

  /// Gives every primitive of one named node its own material.
  ///
  /// The nodes are named in the `.glb` by the bake, which is what lets the
  /// colour live here in the theme rather than baked into vertices where it
  /// could never answer to a token. A name the model does not have means the
  /// bake and the catalog have come apart, so the assert names both halves.
  static void _paint(
    Node root,
    ProteinTarget target,
    String name,
    Color colour,
  ) {
    final Node? node = _find(root, name);
    assert(node != null, '${target.structureAsset} has no node named "$name"');
    final Mesh? mesh = node?.mesh;
    if (mesh == null) {
      return;
    }
    for (final MeshPrimitive primitive in mesh.primitives) {
      primitive.material = PhysicallyBasedMaterial()
        ..baseColorFactor = _linear(colour)
        // Protein illustration convention: matte, so the form is read from
        // shading rather than from highlights sliding over it as it turns.
        ..metallicFactor = 0
        ..roughnessFactor = 0.65;
    }
  }

  /// The importer is free to nest what it loads, so the node is looked for
  /// rather than indexed.
  static Node? _find(Node node, String name) {
    if (node.name == name) {
      return node;
    }
    for (final Node child in node.children) {
      final Node? hit = _find(child, name);
      if (hit != null) {
        return hit;
      }
    }
    return null;
  }

  /// sRGB to linear, per the glTF specification's `baseColorFactor`.
  static vm.Vector4 _linear(Color colour) {
    double channel(double v) => v <= 0.04045
        ? v / 12.92
        : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
    return vm.Vector4(
      channel(colour.r),
      channel(colour.g),
      channel(colour.b),
      1,
    );
  }

  void _apply() {
    _molecule?.rotation = _rotation.value;
  }

  void _tick(Duration elapsed, double deltaSeconds) {
    if (_reducedMotion) {
      return;
    }
    _rotation.tick(deltaSeconds);
    _apply();
  }

  void _drag(DragUpdateDetails details) {
    _rotation.drag(details.delta);
    _apply();
    if (!_turned) {
      setState(() => _turned = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return SizedBox(
      width: widget.viewport.width,
      height: widget.viewport.height,
      child: _failed
          ? Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.screenPadding,
                ),
                child: Text(
                  'The structure needs 3D rendering, which is not available '
                  'here.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            )
          : !_ready
          ? (_warmAtOpen ? const SizedBox.expand() : const StructureLoadingView())
          : Stack(
              fit: StackFit.expand,
              children: <Widget>[
                Semantics(
                  label: widget.target.structure.semantics,
                  // Ungated on purpose: `_load` has already warmed the
                  // pipelines, so the view can draw on its first frame. Gating
                  // it again would put a restarted pulse back in between.
                  child: SceneView(_scene!, camera: _camera, onTick: _tick),
                ),
                if (widget.legend.length > 1)
                  Positioned(
                    left: AppSpacing.lg,
                    right: AppSpacing.lg,
                    top: AppSpacing.sm,
                    child: ExcludeSemantics(
                      child: Wrap(
                        spacing: AppSpacing.md,
                        runSpacing: AppSpacing.xs,
                        children: <Widget>[
                          for (final (Color colour, String name)
                              in widget.legend)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    color: colour,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 5),
                                Text(name, style: theme.textTheme.labelSmall),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
                TurnZone(viewport: widget.viewport, onTurn: _drag),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: AppSpacing.sm,
                  child: IgnorePointer(
                    child: AnimatedOpacity(
                      opacity: _turned ? 0 : 1,
                      duration: _reducedMotion
                          ? Duration.zero
                          : const Duration(milliseconds: 400),
                      child: ExcludeSemantics(
                        child: Text(
                          'Drag to rotate',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.labelSmall,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

/// The square in the middle of the page that a drag turns the model in.
///
/// Every drag that starts inside it is the model's, sideways ones included, and
/// that is the whole job: the screen behind this page turns a sideways drag
/// into a page turn, so without somewhere the page turn does not reach, a
/// reader trying to bring the back of the fold round loses the page instead.
///
/// It is laid over the model rather than around it — the molecule is drawn
/// across the whole box either way — so what the reader sees of it is the
/// behaviour, not an edge.
class TurnZone extends StatelessWidget {
  const TurnZone({required this.viewport, required this.onTurn, super.key});

  /// The box the page is given, which the square is centred in.
  final Size viewport;

  /// Called for each drag inside the square, in either axis.
  final GestureDragUpdateCallback onTurn;

  /// How much of the page's box is left to the walk's own swipe, at each end.
  ///
  /// A comfortable target rather than a hairline: the reader is not aiming at
  /// this strip, they are swiping the page the way they have on the four pages
  /// before it, and the throw has to start somewhere. On a phone the square
  /// takes the width and the bands come out well past this — it binds only
  /// where the box is short, which is a phone on its side, and there it is the
  /// difference between a page that can be left and one that cannot.
  static const double band = 56;

  /// The side of the square, given the box the page is drawn in.
  ///
  /// No wider than the box, and never so tall that the bands are squeezed out
  /// of it: where the height is what is scarce the square is what gives way,
  /// not the page turn. Giving way costs it little, because the model is framed
  /// to the vertical field of view and so is drawn smaller in a short box by
  /// the same measure.
  static double sideIn(Size viewport) =>
      math.max(0, math.min(viewport.width, viewport.height - 2 * band));

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox.square(
        dimension: sideIn(viewport),
        child: RawGestureDetector(
          behavior: HitTestBehavior.opaque,
          // The view labels the molecule and says that it turns. A second node
          // over the same pixels offering a drag is that sentence told twice.
          excludeFromSemantics: true,
          gestures: <Type, GestureRecognizerFactory>{
            _TurnGestureRecognizer:
                GestureRecognizerFactoryWithHandlers<_TurnGestureRecognizer>(
                  _TurnGestureRecognizer.new,
                  (_TurnGestureRecognizer instance) {
                    instance.onUpdate = onTurn;
                  },
                ),
          },
        ),
      ),
    );
  }
}

/// A pan that claims the finger where it lands, rather than after 36 points of
/// it have been spent finding out what the finger meant.
///
/// The screen behind this page turns a sideways drag into a page turn, and
/// [HorizontalDragGestureRecognizer] settles that at the touch slop — eighteen
/// points — where a pan waits for twice it. So the arena is not close: the page
/// turn wins every sideways drag inside the model, and the reader who meant to
/// spin the fold loses the page instead. That is the bug this recognizer exists
/// to close, and no threshold tuned against the other one closes it, because
/// the two gestures are the same gesture.
///
/// Accepting on the pointer down takes the question out of the arena entirely.
/// Inside the square there is nothing else a finger can be doing — no tap, no
/// scroll, no page — so there is nothing for it to be resolved against, and the
/// rotation starts on the first point of movement rather than the thirty-sixth,
/// which is what a control that turns an object should have done anyway.
class _TurnGestureRecognizer extends PanGestureRecognizer {
  @override
  void addAllowedPointer(PointerDownEvent event) {
    super.addAllowedPointer(event);
    resolve(GestureDisposition.accepted);
  }
}
