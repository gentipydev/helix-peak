# Folding: drawn in the fold page's own scene

The walk's fold page opens on the chain and folds it, in the four steps the
Lab used to play (hydrophobic collapse, helices coil, strands pair, bridges
snap shut), then hands over to the model the page has always drawn. The steps
are `FoldTimeline` (`lib/shared/folding/`), unchanged from the Lab: a pure
function of time, twelve beats of 750 ms, whose last frame puts every ordered
residue on the CA the `folding` track gives it. This note is about how that
is drawn.

## The answer changed: flutter_scene, not a painter

The Lab drew the fold with a `CustomPainter` projecting the CA trace through
the page's camera, and this note used to say why: nothing drawn by
flutter_scene can be tested without a GPU, the lab's timelines paint, and a
painter is cheap. On a page of its own that held. Ending on the model is a
different job. A painted line crossfading into a lit, tone-mapped ribbon is
two kinds of picture, and the reader sees the switch however exact the
geometry is.

So the fold is drawn in the model's own `Scene` (`FoldMorph`,
`lib/shared/structure/fold_morph.dart`): the same camera (`structureCamera`),
the same image-based lighting and tone mapping, and the same material
(`structureMaterial`: matte, metallic 0, roughness 0.65). What it becomes is
already the same kind of thing, and the handover is the model showing under
it while it fades off in half a second.

flutter_scene 0.23 builds the meshes at runtime, as this note found before:
`MeshGeometry.fromArrays` with `GeometryStorage.updatable` takes new positions
and normals each frame into the same buffers, and `InstancedMesh` draws the
beads and the bridge rods with a transform and a colour each.

## What is drawn, and why each is exact at the end

`FoldMesh` (`lib/shared/folding/fold_mesh.dart`) is the geometry, pure Dart and
tested without a GPU; `FoldMorph` only uploads it.

- **Residues are beads** on a thin thread, as big as the unfolded chain leaves
  room for (0.42 of the middle gap between neighbours, 0.7 to 1.4 A), so a
  long chain stays beads rather than running into a worm. Water-avoiding ones
  take the grid's property colour as the chain collapses round them.
- **The backbone is a swept tube**, a Catmull-Rom spline through the residues,
  8 rings a residue (6 past 200 residues, 4 past 600), 8 vertices a ring. As
  each residue settles its bead melts into it, and its ring turns into the
  model's shape for it: an oval for a helix, a slab with an arrowhead for a
  strand, a thin loop, or the tube a peptide with no secondary structure is
  drawn as. The sizes are PyMOL's own settings, carried by the track
  (`cartoon`).
- **It ends on the model's ribbon, not beside it.** A CA trace alone twists a
  helix's ribbon 25 to 40 degrees off PyMOL's at its ends, and PyMOL flattens
  a sheet up to 3.3 A from its CA atoms. The track carries the ribbon as
  measured on the stored model for each helix and strand residue (`ribbon`:
  where it passes, and which way it lies), and the tube ends on it: a median
  of under a degree off PyMOL's, 99% within 16.
- **Bridges grow along the model's rods.** The track carries each bridge's CA,
  CB, SG, SG, CB and CA, the atoms the structure bake built its rods through,
  and each half grows from its CA to the middle of the S-S bond. Closed, they
  are the rods.
- **Residues the entry never placed** stay loose beads to the end, and fade
  with the handover: the model does not draw them.

## The frame: z is turned round

The `.fsceneb` compiler bakes a glTF into flutter_scene's native frame by
negating z (`GltfCoordinatePolicy.bakeNative`) and rewinding its triangles. The
track is in the glTF's frame, so everything drawn from it negates z too, and
winds its own triangles as flutter_scene's swept geometry does (round each
ring with `binormal = tangent × normal`). Without it the fold ends on the
model's mirror image. The Lab's painter did not negate z, so its last frame
was, by the same reasoning, the page's fold mirrored.

## Cost

Rebuilding the mesh each frame costs, on the development Mac, 0.14 ms for
insulin (3,152 vertices) and 0.95 ms for CFTR (47,336 vertices, 1,480
residues). The pipelines the fold needs, opaque and fading, are compiled by
`StructureView.prepare` while the walk is at rest, pages before the fold.

## What is tested where

- `FoldMesh`, in `test/shared/folding/fold_mesh_test.dart`: a fixed topology,
  the last frame on the model's ribbon and as wide and thick as its cartoon,
  the beads gone and the rods the model's.
- `FoldMorph` and the handover need Flutter GPU, which `flutter test` and the
  golden container do not have: the page there says it needs 3D rendering, as
  it always has. They were checked on the iOS simulator frame by frame
  (insulin, lysozyme, the prion, oxytocin and CFTR), with the fold's last
  frame and the model's first compared across the handover.
