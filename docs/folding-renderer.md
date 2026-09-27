# Folding: can flutter_scene 0.23 build meshes at runtime?

The fold animation (feature 7) morphs a chain from an extended strand into
the fold the walk's last page draws. The walk's fold is a baked mesh: a
`.fsceneb` compiled from the `.glb` the backend's structure bake made, which
cannot morph. So the question, asked before any renderer code: can
flutter_scene 0.23 build meshes on the device, or does the morph need a
projected-coordinate painter?

## Answer: yes

flutter_scene 0.23.0 (`pubspec.lock`) builds and rebuilds meshes at runtime.
From the package's own source (`flutter_scene-0.23.0/lib/src/`):

- `geometry/mesh_geometry.dart:51`: `MeshGeometry`, "a triangle mesh built at
  runtime from vertex attribute arrays". `MeshGeometry.fromArrays` takes
  positions, normals, texture coordinates, colours and indices;
  `GeometryBuilder` (`:996`) assembles one incrementally.
- The same file: `GeometryStorage.updatable` makes a geometry mutable in place,
  `updatePositions` (`:351`), `updateNormals` and the rest replace one attribute
  when the vertex count holds, and `rebuild` replaces everything.
- `geometry/swept_geometry.dart:235`: `TubeGeometry`, a round cross-section
  swept along a `ScenePath`, and `RibbonGeometry`, a flat strip, each with
  `updatePath` (`:290`, `:91`) to follow a path that moves.
- `geometry/polyline_geometry.dart`: `PolylineGeometry`, a thick camera-facing
  line, regenerated each frame by `updateForCamera` (`:244`).
- `geometry/morphed_geometry.dart`: glTF morph targets, blended on the GPU.
- `instanced_mesh.dart:19`: `InstancedMesh`, one mesh drawn many times with
  per-instance transforms.

So a tube through the CA trace, rebuilt every frame and drawn in the same
scene and under the same camera as `StructureView`, is possible.

## What the morph is drawn with anyway: a projected-coordinate painter

Recommended, and built:

1. **Nothing here can prove a flutter_scene morph.** There is no Flutter GPU
   in `flutter test` or in the golden container: `StructureView` draws its
   "3D rendering is not available here" line in every test. A morph drawn by
   flutter_scene would have its domain tested and its pixels never, and it
   could not be looked at on a device in this session either. A painter is
   drawn by the suite and can be checked frame by frame.
2. **The lab's timelines paint.** The ribosome and the cell scene are
   `CustomPainter`s under the shared `TransportBar`, and `share/`'s
   `FrameRenderer` makes a flow's frames by painting them offscreen. A painted
   morph plays, scrubs and shares like them.
3. **Cost.** CFTR, the longest chain, is 1,480 residues. Projected segments
   are a few thousand line draws a frame; a swept tube over the same trace is
   on the order of a hundred thousand vertices rebuilt on the CPU every frame.
4. **Exactness does not need the GPU.** flutter_scene's camera is plain
   vector math. `PerspectiveCamera.framing` (`camera.dart:262`) places the
   camera from a model's bounds and the page's margin, and
   `Camera.worldToScreen` (`camera.dart:106`) maps a world point through the
   very projection `SceneView` renders with. The painter builds the camera the
   fold page builds, `structureFramingMargin` included, and projects each CA
   through it, so the morph's last frame lands where the page draws the fold.
   The one input the painter lacks is the stored model's bounds, which the
   page reads off the loaded model; the `folding` track carries them in its
   frame for this (`pipeline/folding` in the backend).

What would change the answer: a device-side need for lighting and shading
the painter cannot fake, or a morph that has to share one scene with the fold
itself. Either would be a flutter_scene `TubeGeometry` over the same timeline,
since the timeline is renderer-free.
