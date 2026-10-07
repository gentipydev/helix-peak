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
