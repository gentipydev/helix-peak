# Goldens

The render baseline: 120 PNGs under `test/goldens/`, compared pixel for pixel
(zero tolerance, Flutter's own `LocalFileComparator`) by three suites.

| Suite | Goldens | What it pins |
|---|---|---|
| `walk_surfaces_test.dart` | `surfaces/` (10) | The surfaces no assertion pins, in insulin with every track: the gene page, a region opened into its DNA, the mRNA page, a base sheet, the protein page with its conservation toolbar, in conservation colours, and unscored with no toolbar, a residue sheet, the ClinVar overview, the fold page. |
| `screen_render_test.dart` | `screens/` (18) | What `test/screen_render_check.dart` used to write and not compare: the home screen and the insulin walk through `GeneScreen`, including the frames caught mid-transition (splicing, the groove, translation, cleavage), the selected runs and the tracer. |
| `catalog_pages_test.dart` | `catalog/` (92) | Every page of every catalog protein, as `catalog_walk_test.dart` writes them to `SHOT_DIR`. The walk test itself is unchanged; this is its forward pass, compared. |

The fold page is drawn headless, where there is no Flutter GPU, so its
goldens pin the page around the model and the sentence that says it cannot be
drawn here. Nothing in this repo pins the 3D model itself.

## The environment

A golden is a picture of what the engine drew, and the engine hands text to
the host's rasteriser: FreeType on Linux, DirectWrite on Windows, CoreText on
macOS. Measured: drawn natively on Windows, with the same Flutter, engine and
fonts, all 28 `surfaces/` and `screens/` goldens fail, differing in 0.8–5.5%
of their pixels (2,558 to 18,245 per frame), and every differing pixel is on
a glyph edge; squares, lines and fills match exactly. So goldens are generated and verified in one
place only, the container built from `tool/goldens/Dockerfile`:

| Pinned | How |
|---|---|
| OS and C library | `ubuntu:24.04` by digest (`sha256:008173c2…`). `dart:math`'s `sin` and `cos` call glibc's libm; the home screen's helix is drawn from them. |
| Flutter, engine, Skia, FreeType | Flutter `3.47.5` by git tag: engine `ab598368`, Dart `3.13.4`. `flutter_tester` bundles Skia and FreeType and links only libc, libm, libdl and libpthread. |
| Fonts | SpaceGrotesk and JetBrainsMono from `assets/fonts/`, and MaterialIcons from the SDK, all loaded through `FontLoader` before any frame. |
| Frame | 390×844 logical pixels, captured at 1×, driven by the fake test clock. |
| Architecture | `linux/amd64`, on an x86-64 host. |

The goldens compare only when `HELIX_GOLDEN_ENV` is
`flutter-3.47.5-linux-x86_64` (`goldenEnvironment` in `test/goldens/golden.dart`),
which `tool/goldens/run.sh` sets from the container's own `flutter --version`
and `uname -m`. Anywhere else they skip, and say why. A native `flutter test`
on Windows or macOS therefore reports them as skipped, never as passed.

**Not pinned: the CPU's SIMD tier.** Skia picks its vector code path from the
CPU at run time, and `flutter_tester` carries AVX-512 code. These goldens were
made on an Intel i3-1215U (AVX2, no AVX-512). GitHub's x86-64 runners are a
mix of CPUs, some with AVX-512. Whether that can move a pixel is not known yet:
the first CI runs will say. `run.sh` prints the CPU and its AVX2 and AVX-512
flags at the top of every run, so a failure on one runner and not another can
be traced to it. If it does happen, trust the container on this laptop (the
machine the goldens were made on) as the source of truth, and treat a CI
failure as a lead to reproduce there, not as a verdict.

The container runs with Apple Silicon's emulation too, but emulated x86 has no
AVX2, so a run there is the unpinned case above. Use an x86-64 host.

## Commands

From Git Bash, Linux or macOS, with Docker running. The first run builds the
image (about 2 minutes) and fills the pub cache volume; after that a run of the
goldens alone takes about a minute and a half.

```bash
tool/goldens/goldens.sh                        # the whole suite, goldens included
tool/goldens/goldens.sh test/goldens           # the goldens alone
```

Arguments go to `flutter test` unchanged. From PowerShell, the same run is:

```powershell
docker build -t helixpeak-goldens:3.47.5 tool/goldens
docker run --rm -v "${PWD}:/src" -v helixpeak-pub-cache:/pub-cache helixpeak-goldens:3.47.5 test/goldens
```

The container copies the tree and never touches the host's `.dart_tool` or
`build/`. It writes back only two things: regenerated goldens, and the diffs of
any golden that failed, as `test/goldens/failures/*_isolatedDiff.png` and
friends (git ignores them).

`SHOT_DIR` still works everywhere: with it set, each golden test also writes
its frames there as 2× PNGs, and outside the container that is all it does.

## Regenerating

Never to make a session pass. A golden that fails is the walk drawing
something different, and the question is why.

When the walk changed on purpose (session 99), regenerate the affected
surfaces only, by naming them:

```bash
tool/goldens/goldens.sh --update-goldens test/goldens/walk_surfaces_test.dart \
  --plain-name 'the fold page'
```

Then look at every changed PNG, and commit the regenerated goldens alone, with
nothing else in the commit. Changing Flutter or the base image (the `ARG` and
`FROM` lines, and `goldenEnvironment`) regenerates everything, and is its own
commit for the same reason.

Adding a golden for a new surface is always allowed: a new name in a golden
test, generated once with `--update-goldens` on that test.
