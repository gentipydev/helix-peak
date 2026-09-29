# Fold animation: the ending, reviewed

## Result

The fold no longer hands over by blending. From the moment each residue
settles, its ribbon is the stored model's own mesh, carried by the chain. By
the time the bridges close (8.2125 s), what the fold page draws is the model,
float for float. At 9 s the page swaps the untouched model in and no pixel
changes. See [the renderer note](folding-renderer.md) for how.

## What was wrong

The previous handover (commit `0758dbc`) blended two opaque renders over the
last 787.5 ms: the fold's own swept ribbon and the stored model. The blend was
clean, but the two shapes were different:

- Insulin's and lysozyme's helices curled differently from the model's.
- Lysozyme's strands had no arrows.
- The rods shaded differently.

So the ending read as one structure dissolving into another, with doubled
outlines mid-blend. The captures of that version are kept as the baseline in
`build/fold-review/baseline/`.

## Verification

GPU review on the iPhone 17 Pro simulator (iOS 26.5, Metal/Impeller),
`tool/fold_review.dart`. Each protein was captured at 33 moments (every twentieth
of the fold, and every 0.0125 over its last fifth) at a fixed turn, 390×624. Two
extra renders came from the same scene: the page's own model layer, and an
independent render of the stored model alone.

| Protein | Loose residues | Model layer vs model alone | Fold at 9 s vs model | Pixels off the model from 8.2125 s |
|---|---:|---:|---:|---|
| Insulin | 0 | 0 | 0 | 0 at every moment |
| Lysozyme | 0 | 0 | 0 | 0 at every moment |
| Somatotropin | 5 (and a dashed gap) | 0 | 0 | 281, falling to 0 |
| Prion | 98 | 0 | 0 | 7,238, falling to 0 |
| TNF | 4 | 0 | 0 | 191, falling to 0 |
| CFTR | 341 | 0 | 0 | 1,313, falling to 0 |

Where there are loose residues, the pixels still off the model after 8.2125 s
are those residues shrinking away, and somatotropin's dashes growing in. The
final frame is pixel-identical to the previous version's for all six.

The mean change between consecutive captures after the bridges close (7
steps, 0 to 255 per pixel, summed) measures what the blend used to add.

| Protein | Before | After |
|---|---:|---:|
| Insulin | 2.28 | 0 |
| Lysozyme | 1.94 | 0 |
| TNF | 1.34 | 0.24 |
| CFTR | 2.87 | 1.29 |

The snap before it is unchanged in size (insulin 6.68 → 6.37, lysozyme 3.10 →
3.13). The earlier steps look as they did: side-by-side GIFs of the whole fold,
before and after, are in `build/fold-review/compare/`, with the numbers in
`verification.json`.

- `flutter analyze`: no issues.
- `flutter test`: 1,807 passed, 32 environment-gated golden tests skipped.
  `fold_skin_test.dart` checks all twenty models against the stored `.glb`
  fixtures.
- The live `StructureView` played insulin's fold through to the model on the
  simulator, binding on its own isolate, with nothing in the log.
- CLAUDE.md's walk-test, fixture and golden-image checks print nothing. The
  golden container needs an x86 host; the fold page there only says it needs
  3D rendering.

## Cost

These figures are from the simulator's debug build, so a release build will
be faster.

- **Binding, once per protein, off the page:** 16 to 92 ms.
- **A frame of the whole fold:** a mean of 0.15 to 0.57 ms, including the
  uploads. The single worst frame, 6.3 ms, was the first frames' JIT warm-up.
- **One render a frame throughout.** The old blend's second render and image
  compositing are gone.

Frame timing on an Android phone has still not been measured: none was
attached here. The release APK is the way to judge it.

## Limits

- **The early thread takes the model's facets.** Before a residue settles,
  its part of the model's mesh is drawn as a 0.35 Å thread. That is PyMOL's
  rings shrunk:
  - ten-sided on a helix, six on a loop;
  - a small square on a strand, shaded round;
  - one ring a residue on CFTR, whose kinks sit under the beads.

  On insulin it looks as it did.
- **A reversed ring waits as a thread.** A ring whose tangent points more
  than a right angle from its finished direction stays a thread until it
  turns back. This happens at a finished helix's end, while the loop after
  it has not settled.
- **The captures are a sequence.** The review plays each fold forward, as
  the page does.

## Reproduce the GPU review

Serve a folder of `catalog.json` (an array of catalog rows) and
`<slug>.structure` / `<slug>.folding` payloads, then run the harness:

```sh
python3 -m http.server 8765 --bind 127.0.0.1 --directory <review-input>
flutter run -d <ios-simulator-id> -t tool/fold_review.dart
```

It writes PNGs under the simulator app's `Documents/fold-review`, prints that
path and each protein's binding and frame times, and ends by playing the live
insulin fold through `StructureView`. Compare the following pairs:

- `<slug>-t10000.png` against `<slug>-model.png`, for the swap;
- `<slug>-model.png` against `<slug>-reference.png`, for the model layer
  against the model alone;
- every `<slug>-t*.png` from `t09125` on against `<slug>-model.png`, for the
  ending.
