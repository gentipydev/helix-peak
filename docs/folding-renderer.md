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
the page's camera, and this note used to say why: nothing drawn by
flutter_scene can be tested without a GPU, the lab's timelines paint, and a
painter is cheap. On a page of its own that held. Ending on the model is a
different job. A painted line crossfading into a lit, tone-mapped ribbon is
two kinds of picture, and the reader sees the switch however exact the
geometry is.

So the fold is drawn in the model's own `Scene` (`FoldMorph`,
`lib/shared/structure/fold_morph.dart`): the same camera (`structureCamera`),
the same image-based lighting and tone mapping, and the same material
(`structureMaterial`: matte, metallic 0, roughness 0.65). Both surfaces stay
opaque. `StructureSceneView` renders them separately during the handover and
blends their completed images; the geometry never shares a depth buffer at
that point. The canvas only composites GPU renders, without drawing a second
representation of the molecule.

## The final handover

The animated ribbon approximates the stored PyMOL surface. Matching its
cross-sections and centres does not give it identical triangles, normals,
loop curvature, caps or sheet tips. The former handover exposed those
differences: it made the stored model fully visible in one frame, then faded
the animated mesh over it for 500 ms. Their intersecting surfaces competed
for depth; changing the animated material to transparent also changed how
its front and back surfaces were drawn.

The handover now starts when the bridges finish (`t = 0.9125`, 8.2125 s) and
ends at 9 s. This uses the final 787.5 ms of the existing timeline instead
of waiting there and adding another half-second afterwards. A quintic
smoothstep has zero velocity and acceleration at both ends.

The model occupies layer 1 and the animation layer 2. During the handover,
one `renderViews` call renders the animation into a `RenderTexture` and the
model into its usual screen buffers, under the same camera and rotation.
`paintFoldHandover` adds their premultiplied images with complementary
weights. Ordinary source-over of two partially transparent images would
let the background show through where their silhouettes agree. Material
opacity would reintroduce the depth problem.

Before and after the handover there is only one render. The extra render
target is released on completion or disposal. No image is read back to the
CPU. The stored model, its materials, framing and lighting are unchanged.

The measured ribbon centres also carry the timeline's small bridge-hold
offset until closure. Previously, a settled helix used its final ribbon
centre too early, while its cysteine bead and bridge still followed the
held CA. The correction keeps them together and reaches the same final
coordinates.

flutter_scene 0.23 builds the meshes at runtime, as this note found before:
`MeshGeometry.fromArrays` with `GeometryStorage.updatable` takes new positions
and normals each frame into the same buffers, and `InstancedMesh` draws the
beads and the bridge rods with a transform and a colour each.

## How the animated geometry approaches the model

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
- **The ribbon uses measured centres and directions.** A CA trace alone twists a
  helix's ribbon 25 to 40 degrees off PyMOL's at its ends, and PyMOL flattens
  a sheet up to 3.3 A from its CA atoms. The track carries the ribbon as
  measured on the stored model for each helix and strand residue (`ribbon`:
  where it passes, and which way it lies). These align the sampled
  cross-sections; they do not reproduce every vertex of PyMOL's surface.
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
residues). These are earlier CPU geometry measurements, not device frame
times. `StructureView.prepare` compiles the opaque pipelines while the walk
is at rest, pages before the fold. The last 787.5 ms adds a second GPU render
and image compositing; frame timing on an Android device remains to be
measured.

## What is tested where

- `FoldMesh`, in `test/shared/folding/fold_mesh_test.dart`: a fixed topology,
  the last frame on the model's ribbon and as wide and thick as its cartoon,
  the beads gone and the rods the model's, and ribbon centres following the
  held cysteines throughout closure.
- `fold_handover_test.dart`: timing, gentle endpoints, exact endpoint images,
  gradual silhouette changes, and constant brightness for matching pixels.
- `FoldMorph` and the handover need Flutter GPU, which `flutter test` and the
  golden container do not have: the page there says it needs 3D rendering, as
  it always has. `tool/fold_review.dart` captures the actual handover widget
  at 21 moments, the former overlapping-material fade, and an independent
  render of the original model. See [the handover review](fold-handover-review.md)
  for results and the remaining limits.
