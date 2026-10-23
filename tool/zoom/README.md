# The zoom's body and organ outlines

`anatomogram.py` makes `lib/features/zoom/domain/anatomy_figures.g.dart`
from the Expression Atlas anatomograms: the standing figures and the brain
the zoom draws at its body and organ stops.

```bash
python3 tool/zoom/anatomogram.py            # fetch, convert, write
python3 tool/zoom/anatomogram.py --check    # fail if the file is stale
python3 tool/zoom/anatomogram.py --svg-dir DIR --preview DIR
```

It needs Python 3.9 or later and nothing else. `--preview` draws the
converted figures to look at and needs Pillow.

## Source and licence

The drawings are `homo_sapiens.female.svg`, `homo_sapiens.male.svg` and
`homo_sapiens.brain.svg` from
<https://github.com/ebi-gene-expression-group/anatomogram>, by the Expression
Atlas team at EMBL-EBI, licensed
[CC BY 4.0](https://creativecommons.org/licenses/by/4.0/). Expression Atlas
states the licence, and the paper it asks to be cited by, at
<https://www.ebi.ac.uk/gxa/licence.html>: "Expression Atlas in 2026: enabling
FAIR and open expression data through community collaboration and
integration", Nucleic Acids Research, 2025.

The script fetches the drawings at one commit (`COMMIT`) and holds each to
its SHA-256, so a run is reproducible. They are not kept in this repository.

What is changed from the drawings, as the licence asks to be said:

- every outline is flattened and simplified (Ramer-Douglas-Peucker), and
  measured in metres on a figure 1.70 m tall, the brain 0.17 m long;
- only the tissues `anatomy_tables.dart` names are kept;
- of the brain's four views, only the mid-sagittal one;
- the female figure draws no tongue, and its mouth stands in for it
  (`STAND_IN`);
- the attribution badge in each drawing's corner is left out. The credit is
  given in words instead: in the generated file's head, in the zoom's About
  sheet (`ZoomFacts.about`) and in `docs/design/zoom.md`.

## Where the zoom goes in

Each part's `site` is where the zoom goes into it: the point of a 36 × 36
grid over its outline's box that lies inside the outline farthest from its
edge. A part named in `SITE_TOP` is gone into in a share of its box from the
top instead. The bone marrow is drawn as a femur, and an adult's femur keeps
its red marrow between its trochanters, its head, its shaft and its lower
end holding yellow marrow (Mitchell et al. 1986, Moore and Dawson 1990), so
its site is the farthest point inside the femur's upper fifth. A part named
in `SITE_RIGHT` is gone into a share of its width in from its right edge,
the body's left, at a share of its height. The heart muscle is drawn as the
heart cut open, its left ventricle's free wall forming that edge, and GTEx
takes heart muscle from the anterior left ventricle, so its site lies in the
middle of that wall, 56% of the way down, 3.5% of the width in: where the
heart's form (`heart_form.dart`) lays the wall through it on either figure.
A part named in `SITE_LEVEL` is gone into at a share of its height, midway
across its widest stretch there. Skeletal muscle is drawn as the front of
the thigh and gone into in its vastus lateralis, which is best biopsied
between half and three quarters of the way from the greater trochanter to
the lateral epicondyle, just in front of the iliotibial tract (Chen et al.
2019, Scand J Med Sci Sports 29:504): five eighths of the way lies 60% of
the way down the muscle's outline on either figure. GTEx takes its skeletal
muscle from the gastrocnemius, in the calf, which the anatomogram does not
draw for it.

## What the zoom follows, and where the view closes

The zoom follows a part into its largest outline, which the body rings and
the organ's scene draws in from: the outlines are written largest first. A
part named in `FOLLOW_OUTERMOST` is followed into the outline whose box's
middle lies farthest from the figure's midline instead, written as its
place among them (`followed`). Of skeletal muscle's five, that is its
vastus lateralis, the muscle human skeletal muscle is biopsied from with
the Bergström needle (Shanely et al. 2014, J Vis Exp 91:51812). The
outlines keep their order, and every one is simplified as before, so
nothing the figure draws round another organ changes.

The view closes on the middle of the followed outline's box, so that the
organ's scene has it whole. A part named in `FRAME_WHOLE` is written with a
`centre`, the middle of the box round all its outlines, and the view closes
there: the thigh is drawn whole round its vastus lateralis, which lies at
its lateral edge.

## Why generated Dart, not an asset

The app's bundled assets are held to a fixed list by a walk test
(`protein_catalog_test`, "every track is fetched, and none of them ships"),
and the three figures together are about 95 KB. They are compiled in.

## After changing the tissue table

`anatomy_tables.dart` names the parts by UBERON id (`uberon`, and `inBrain`
for a tissue of the brain). The script reads the ids from it, so a new
tissue needs a run, and `zoom_domain_test` fails until each tissue is found
on a figure of a body that has it.

`svg_shapes.py` is the reader: paths with every command, ellipses, circles
and rects, through group transforms and `use`.
