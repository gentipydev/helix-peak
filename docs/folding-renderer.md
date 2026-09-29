# Folding: drawn in the fold page's own scene

The walk's fold page opens on the chain and folds it, in the four steps the
Lab used to play (hydrophobic collapse, helices coil, strands pair, bridges
snap shut), then hands over to the model the page has always drawn. The steps
are `FoldTimeline` (`lib/shared/folding/`), unchanged from the Lab: a pure
function of time, twelve beats of 750 ms, whose last frame puts every ordered
residue on the CA the `folding` track gives it. This note is about how that
is drawn.

## One scene, camera and lighting environment

The Lab drew the fold with a `CustomPainter` projecting the CA trace through
the page's camera. Ending on the model is a different job. A painted line
crossfading into a lit, tone-mapped ribbon is two kinds of picture, and the
reader sees the switch however exact the geometry is.

So the fold is drawn in the model's own `Scene` (`FoldMorph`,
`lib/shared/structure/fold_morph.dart`): the same camera (`structureCamera`),
the same image-based lighting and tone mapping, and the same material
(`structureMaterial`: matte, metallic 0, roughness 0.65).

## The fold is the model's own mesh

An earlier version swept its own ribbon along the chain and cross-faded it
into the stored model at the end. However closely its cross-sections matched
PyMOL's, it was not PyMOL's surface: its helices curled differently, its
strands had no arrows, its rods were smoother. The fade dissolved one shape
into another, with doubled outlines halfway through.

Now the ribbon *is* the stored model. `FoldSkin`
(`lib/shared/folding/fold_skin.dart`) copies each chain node of the loaded
model (`storedMeshesOf`, from the `.fsceneb` the page already has) and binds
every vertex to the chain; each frame it carries the copy with the moving
backbone. Once every residue is in its place the copy is the stored mesh,
float for float, so when the page swaps the untouched model back in at the
end (one render layer for the fold, one for the model), no pixel changes.

### How a vertex is bound

PyMOL sweeps a cartoon along the chain as rings, one cross-section at a time,
and emits it as triangle strips running along each piece of secondary
structure. The two vertices each step of a strip adds lie on one ring. So the
strips give every vertex its ring without asking where it is, and a ring (not
a vertex) is what gets bound: its centre to a point of the backbone, its
vertices to that point's frame.

- **No vertex is bound alone.** In a tightly packed sheet an arrowhead's edge
  can sit as close to the neighbouring strand as to its own; its ring's centre
  cannot.
- **Rings are bound outward from the certain ones.** A ring only one stretch
  of chain could hold is bound first; the rest are bound from their
  neighbours across the mesh, each taking the stretch its neighbours are on.
  The rings are then kept in order along each strip (pool adjacent violators;
  no ring on the twenty moves more than 0.023 residue).
- **The backbone is split at gaps.** Each run of placed residues is its own
  spline, so the loose residues' motion never reaches the model's mesh.
- **A gap the model draws across stays out of the chain.** PyMOL draws a short
  gap as a dashed line (somatotropin's three missing residues, the only case
  on the twenty). Those dashes are not on any run: they wait, collapsed, and
  grow in place as the fold finishes.

All twenty models bind; `test/shared/folding/fold_skin_test.dart` checks each
against the stored `.glb` fixtures, read as flutter_scene's compiler reads
them (z turned round, triangles rewound, every float kept).

### How a ring moves

Each ring rides the backbone at its own point. Its frame there is its frame on
the finished fold, turned the least way onto where the backbone now runs, so
it returns to its rest frame exactly, whatever path the chain took.

As its residue settles, a ring grows from a 0.35 Å thread to its full size,
exactly as the old ribbon did (width and thickness from the thread to the
model's). Its centre moves from the backbone out to where the model's ribbon
runs. A ring whose tangent points more than a right angle from its rest
tangent stays a thread until it turns back. The least turn onto a reversed
tangent is ill-defined, and a round thread shows no turn about its own axis.
(That case is a finished helix end whose next residue has not settled yet;
without the rule one ring of CFTR spun 118° in a frame.)

At rest (every residue settled, the bridges shut) a ring's frame is its rest
frame bit for bit, and the copy takes the stored floats verbatim.

## Bridges are the model's own rods

The structure bake builds each bridge as five rods (CA–CB–SG–SG–CB–CA) and a
joint at each bend, from the entry's atoms: the same atoms the track carries.
`FoldBonds` (`lib/shared/folding/fold_bonds.dart`) finds each rod and joint of
the model's `bonds` node by where it is. During the snap, each half grows as
before, from its CA through CB and SG to the middle of the S–S bond, carried
with its CA while the hold keeps the pair apart:

- A rod grows by its far end sliding out to the tip.
- A joint rides the tip, rounding it, until it reaches its atom.
- The middle rod is drawn twice, once for each half. The growing ends turn to
  the whole rod's shading as they meet: flutter_scene interpolates normals
  unnormalised, so each half then shades exactly as its part of the single
  rod.

At closure the node is the stored one, float for float.

## What the model never draws

`FoldMesh` (`lib/shared/folding/fold_mesh.dart`) is what is left:

- **Beads.** One per residue, as big as the unfolded chain leaves room for
  (0.42 of the middle gap between neighbours, 0.7 to 1.4 A), coloured by
  property as the chain collapses round the water-avoiding ones. Each melts as
  its residue settles; a bridge's cysteines melt as it closes.
- **Threads.** Only where the entry placed nothing: a swept tube from the
  placed residue each loose run hangs from to the one it hangs to. The thread
  closes to a point over half a residue where it meets the model's mesh,
  rather than ending open.

Over the last 787.5 ms (`FoldTimeline.finishAt`, a quintic ease from the
bridges' closing to the end) the loose beads and threads shrink away, while
the model's dashes across a gap, if any, grow in.

## The frame: z is turned round

The `.fsceneb` compiler bakes a glTF into flutter_scene's native frame by
negating z (`GltfCoordinatePolicy.bakeNative`) and rewinding its triangles. The
track is in the glTF's frame, so everything drawn from it negates z too, and
winds its own triangles as flutter_scene's swept geometry does (round each
ring with `binormal = tangent × normal`). The model's own mesh, copied from
the loaded scene, already is.

## Cost

Binding runs once per protein, in `StructureView.prepare`, on another isolate
(`Isolate.run`). On the iOS simulator's debug build it took 16 to 92 ms for
insulin, lysozyme, somatotropin, prion, TNF and CFTR.

A frame of the whole fold (`FoldMorph.update`: backbone, beads, threads,
skin, bonds, and the uploads) averaged 0.15 to 0.57 ms there. The copies are
indexed, one vertex per distinct position and normal: CFTR's is 12,590
vertices, against the 47,336 of the tube it replaces. After the bridges close
the copies no longer change and are not re-uploaded.

There is one render a frame throughout: the fold's layer while it plays, the
model's after. Frame timing on an Android device is still to be measured on a
phone.

## What is tested where

- `fold_skin_test.dart`, all twenty models:
  - every ring on its own chain;
  - the stored triangles drawn corner for corner;
  - every placed residue covered;
  - the copy equal to the stored mesh, float for float, from the bridges'
    closing on;
  - the unfolded chain a thread round the backbone;
  - the dashes waiting, then growing;
  - no vertex jumping between frames;
  - and the bridges: each one's rods and joints, nothing drawn while open,
    growth along their own atoms, and the stored node at closure.
- `fold_mesh_test.dart`: threads only for loose runs, closing at their
  anchors and shrinking away; beads melting.
- `fold_timeline_test.dart`: `finishAt`'s timing.
- `FoldMorph` needs Flutter GPU, which `flutter test` and the golden container
  do not have: the page there says it needs 3D rendering, as it always has.
  `tool/fold_review.dart` captures the fold on a simulator at 33 moments,
  times a frame, and renders the model alone. See
  [the review](fold-handover-review.md).
