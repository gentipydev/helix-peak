# Fold animation: final transition review

## Result

The final transition now blends two independently rendered, opaque surfaces.
It starts as the bridges finish closing and eases into the original stored
model. The model's geometry, materials, lighting and camera remain unchanged.

## What caused the visible switch

1. **A second silhouette appeared immediately.** `_handOver` made the stored
   model fully visible before the animated surface started fading. Any part
   of the model outside the animation's silhouette appeared in that frame.
2. **Nearly coincident surfaces shared depth.** The animated ribbon samples
   measured ribbon centres and directions, but its triangles, loop curvature
   and normals differ from PyMOL's. Drawing both meshes together produced
   alternating visible surface patches as they rotated. Switching the
   animation's materials from opaque to blended also exposed back surfaces.
3. **The finish had a pause followed by a linear fade.** Ordered motion ends
   at 8.2125 s. The old implementation waited until 9 s and then faded for
   500 ms, with an abrupt change in fade speed at either end.
4. **Ribbon centres lost the bridge displacement too early.** A settled
   measured ribbon used its rest coordinates while the cysteine bead and
   growing bridge still followed the held backbone atom. The ribbon now
   carries the same small displacement until closure.

## Implementation

| Detail | Previous | Updated |
|---|---|---|
| Handover starts | 9 s | 8.2125 s, after bridge closure |
| Handover duration | 500 ms | 787.5 ms |
| Animation completes | 9.5 s | 9 s |
| Surface visibility | Model appears, animated materials fade | Complementary image weights |
| Depth during handover | Shared between the two surfaces | Independent for each surface |
| Easing | Linear | Quintic smoothstep |
| Final structure | Stored model | Same stored model |

`StructureSceneView` uses separate render layers under the same scene,
camera and rotation. During the handover, it renders the animation into one
temporary texture and records the model's normal screen render as GPU
drawing commands. There is no CPU image readback. `paintFoldHandover` mixes
their premultiplied images with additive compositing and weights that sum
to one. Matching surface pixels retain their brightness instead of briefly
showing the background through them.

The extra texture is released after the blend. Earlier and later frames
render one surface. The four biological phases retain their timeline and
announcements; the bridge alignment correction uses the existing hold
offsets. No model, track format, data payload or final material was changed.

## Verification

The GPU review ran on the iPhone 17 simulator with Metal/Impeller. For each
protein, the harness captured 21 handover positions at a fixed camera and
rotation, plus a direct render of the original model. Captures are 390×624
pixels; scene rendering uses the simulator's device pixel ratio.

| Protein | Coverage | Final pixels different from original |
|---|---|---:|
| Insulin | Two chains and three bridges | 0 |
| Lysozyme | Helices, sheets and bridges | 0 |
| p53 | Sheets and no drawn bridges | 0 |
| Vasopressin | Small tube representation | 0 |
| Prion | Long unresolved stretches | 0 |
| CFTR | Large model; 341 unresolved residues | 0 |

The harness also reproduces the old overlapping-material handover for visual
comparison and finishes by playing the live insulin fold through
`StructureView`.

- `flutter analyze`: no issues.
- `flutter test`: 1,800 passed; 32 environment-gated golden tests skipped.
- Focused fold/structure suite: 43 passed, including image compositing,
  endpoint easing and ribbon attachment during bridge closure.
- Linux visual baseline: 25 existing mRNA image mismatches reproduced on
  the unchanged starting commit `237b2716`. All 100 generated failure images
  match that baseline pixel for pixel. No new differences, and no committed
  goldens or existing walk tests were changed.

## Limits and next measurement

This is a smooth visual handover between closely aligned surfaces. Their
intermediate meshes remain different, so a paused midpoint can show a faint
double edge. Eliminating that entirely would require deforming the stored
mesh itself with a reliable vertex-to-backbone mapping, including sheet
tips, caps, bridges and gaps in unresolved chains. Sparse per-residue ribbon
measurements do not provide that mapping. A nearest-surface match can attach
vertices to the wrong nearby strand and is unsuitable as a general fix.

The blend adds a second GPU render for 787.5 ms. The final model returns to
one render. The Android device in the supplied screenshot was not available;
its frame times still need a physical-device measurement. Simulator visual
checks are evidence of continuity and endpoint fidelity, not a mobile
performance guarantee.

## Reproduce the GPU review

Serve a local folder containing `catalog.json` (an array of catalog rows)
and `<slug>.structure` / `<slug>.folding` payloads for the six proteins above:

```sh
python3 -m http.server 8765 --bind 127.0.0.1 --directory <review-input>
flutter run -d <ios-simulator-id> -t tool/fold_review.dart
```

The harness writes PNGs under the simulator app's `Documents/fold-review`
and prints that path. Compare `<slug>-new-20.png` with
`<slug>-reference.png` to check the endpoint independently. Local captures,
verification results and the insulin comparison GIF from this review are
under `build/fold-review/`.
