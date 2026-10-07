#!/usr/bin/env python3
"""Makes the zoom's body and organ outlines from the Expression Atlas
anatomograms.

    python3 tool/zoom/anatomogram.py            # fetch, convert, write
    python3 tool/zoom/anatomogram.py --check    # is the written file current?
    python3 tool/zoom/anatomogram.py --svg-dir DIR --preview DIR

The anatomograms (EMBL-EBI, https://github.com/ebi-gene-expression-group/
anatomogram, CC BY 4.0) are three Inkscape drawings: a female figure, a male
figure and a brain in four views, each with its line art in one layer and a
shape for every tissue, named by its UBERON id, in another. This reads them
at one pinned commit and writes `lib/features/zoom/domain/
anatomy_figures.g.dart`: for each figure its silhouette, its line art, and
the shapes of the tissues the zoom's table names (`anatomy_tables.dart`),
every contour simplified and measured in metres on a figure 1.70 m tall (the
brain 0.17 m long).

What is changed from the drawings, and said in the generated file and the
About sheet: contours are simplified (Ramer-Douglas-Peucker); only the
tissues the table names are kept; of the brain only its mid-sagittal view;
and where a figure draws no shape for a part, the part named in `STAND_IN`
stands in for it.

Standard library only. The output is Dart source, not a bundled asset: the
app's asset list is held by a walk test, and the outlines are code-sized.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import math
import os
import re
import sys
import tempfile
import urllib.request

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import svg_shapes as svg  # noqa: E402

REPOSITORY = "ebi-gene-expression-group/anatomogram"
COMMIT = "9fcc37022cce1e2862692a5f5fbfb78572b87e67"
SOURCES = {
    "female": (
        "homo_sapiens.female.svg",
        "895ecda0934595950746a13c16abb8bd49ae4a4f947d575878f2f95b33b18e28",
    ),
    "male": (
        "homo_sapiens.male.svg",
        "c19874f0ec6c6450525277d97679bfe57cb0fd280a920210d0961442d43162ab",
    ),
    "brain": (
        "homo_sapiens.brain.svg",
        "f885b63ef331d2d1163e09566a25144830c13b4ab73690e667669603afce6b55",
    ),
}

HERE = os.path.dirname(os.path.abspath(__file__))
APP = os.path.normpath(os.path.join(HERE, "..", ".."))
TABLE = os.path.join(APP, "lib/features/zoom/domain/anatomy_tables.dart")
OUT = os.path.join(APP, "lib/features/zoom/domain/anatomy_figures.g.dart")

# A standing figure's height, and a brain's length front to back, in metres.
FIGURE_HEIGHT = 1.70
BRAIN_LENGTH = 0.17

# One step of the integers the contours are written in, in metres.
STEP = 1e-4

# The brain's mid-sagittal view: the outline it is drawn with, and the part
# of the page it lies in (the drawing has four views side by side).
BRAIN_OUTLINE = "bottom_left_outline"

# Parts of the brain's view kept for the reader to find their way by, beside
# the ones the table names.
BRAIN_LANDMARKS = [
    "UBERON_0000956",  # cerebral cortex
    "UBERON_0002037",  # cerebellum
    "UBERON_0001894",  # diencephalon
    "UBERON_0001896",  # medulla oblongata
    "UBERON_0003027",  # cingulate cortex
    "UBERON_0002285",  # telencephalic ventricle
]

# Where a figure draws nothing for a part, the part that stands in for it.
# The female figure's tongue is an empty circle off the page; the mouth it
# lies in is drawn.
STAND_IN = {"UBERON_0001723": "UBERON_0000167"}


def fetch(directory: str | None) -> dict[str, str]:
    """The three drawings' paths, downloaded at the pinned commit unless
    [directory] already holds them. Each is held to its digest."""
    directory = directory or os.path.join(tempfile.gettempdir(), "helixpeek-anatomogram")
    os.makedirs(directory, exist_ok=True)
    paths = {}
    for name, (filename, digest) in SOURCES.items():
        path = os.path.join(directory, filename)
        if not os.path.exists(path):
            url = f"https://raw.githubusercontent.com/{REPOSITORY}/{COMMIT}/src/svg/{filename}"
            print(f"fetching {url}")
            with urllib.request.urlopen(url, timeout=60) as response:
                data = response.read()
            with open(path, "wb") as out:
                out.write(data)
        with open(path, "rb") as source:
            found = hashlib.sha256(source.read()).hexdigest()
        if found != digest:
            raise SystemExit(f"{path}: sha256 {found}, expected {digest}")
        paths[name] = path
    return paths


def table_ids() -> tuple[set[str], set[str]]:
    """The UBERON ids the app's table names: in a body, and in the brain."""
    source = open(TABLE, encoding="utf-8").read()
    body = set(re.findall(r"uberon:\s*'(\w+)'", source))
    brain = set(re.findall(r"inBrain:\s*'(\w+)'", source))
    if not body:
        raise SystemExit(f"{TABLE}: no uberon ids found")
    return body, brain


def inside(contour: list[svg.Point], p: svg.Point) -> bool:
    odd = False
    for i, a in enumerate(contour):
        b = contour[(i + 1) % len(contour)]
        if (a[1] > p[1]) != (b[1] > p[1]):
            if p[0] < a[0] + (p[1] - a[1]) * (b[0] - a[0]) / (b[1] - a[1]):
                odd = not odd
    return odd


def edge_distance(contour: list[svg.Point], p: svg.Point) -> float:
    best = float("inf")
    for i, a in enumerate(contour):
        b = contour[(i + 1) % len(contour)]
        dx, dy = b[0] - a[0], b[1] - a[1]
        length = dx * dx + dy * dy
        t = 0.0 if length == 0 else max(0.0, min(1.0, ((p[0] - a[0]) * dx + (p[1] - a[1]) * dy) / length))
        best = min(best, math.hypot(p[0] - a[0] - t * dx, p[1] - a[1] - t * dy))
    return best


def site_of(contour: list[svg.Point]) -> svg.Point:
    """A point well inside [contour]: the one of a grid over it that lies
    farthest from its edge. Where the zoom goes into the part."""
    x0, y0, x1, y1 = svg.bounds([contour])
    best, at = -1.0, ((x0 + x1) / 2, (y0 + y1) / 2)
    n = 36
    for i in range(1, n):
        for j in range(1, n):
            p = (x0 + (x1 - x0) * i / n, y0 + (y1 - y0) * j / n)
            if inside(contour, p):
                d = edge_distance(contour, p)
                if d > best:
                    best, at = d, p
    return at


def encode(contour: list[svg.Point], place) -> list[int]:
    """A contour as integers: its first point, then each step to the next."""
    points = [place(p) for p in contour]
    out, last = [], (0, 0)
    for p in points:
        if out and p == last:
            continue
        out.extend((p[0] - last[0], p[1] - last[1]))
        last = p
    return out


def part_of(shapes_by_id, uberon: str) -> list[list[svg.Point]]:
    contours = [c for c in shapes_by_id.get(uberon, []) if abs(svg.area(c)) > 1e-6]
    if not contours and uberon in STAND_IN:
        contours = [c for c in shapes_by_id.get(STAND_IN[uberon], []) if abs(svg.area(c)) > 1e-6]
    return contours


def titles_of(layer) -> dict[str, str]:
    out = {}
    for child in layer:
        for sub in child:
            if sub.tag == svg.SVG + "title" and sub.text:
                out[child.get("id")] = sub.text.strip()
    return out


def convert_body(name: str, path: str, wanted: set[str]) -> dict:
    root, by_id = svg.read(path)
    outline_layer, tissue_layer = by_id["LAYER_OUTLINE"], by_id["LAYER_EFO"]
    lines: list[list[svg.Point]] = []
    for child in outline_layer:
        # The attribution badge is a link; it is credited in words instead.
        if child.tag == svg.SVG + "a":
            continue
        for shape in svg.shapes_of(child, by_id, svg.parse_transform(outline_layer.get("transform"))):
            lines.extend(shape.contours)
    silhouette = max(lines, key=lambda c: abs(svg.area(c)))
    x0, y0, x1, y1 = svg.bounds([silhouette])
    scale = FIGURE_HEIGHT / (y1 - y0)
    middle = (x0 + x1) / 2

    def place(p: svg.Point) -> tuple[int, int]:
        return (round((p[0] - middle) * scale / STEP), round((p[1] - y0) * scale / STEP))

    shapes_by_id = {
        child.get("id"): [
            c
            for shape in svg.shapes_of(child, by_id, svg.parse_transform(tissue_layer.get("transform")))
            for c in shape.contours
        ]
        for child in tissue_layer
    }
    titles = titles_of(tissue_layer)
    parts = {}
    for uberon in sorted(wanted):
        contours = part_of(shapes_by_id, uberon)
        if not contours:
            continue
        contours.sort(key=lambda c: -abs(svg.area(c)))
        followed = contours[0]
        bx0, by0, bx1, by1 = svg.bounds([followed])
        tolerance = max(0.01, 0.0025 * math.hypot(bx1 - bx0, by1 - by0))
        site = site_of(followed)
        parts[uberon] = {
            "title": titles.get(uberon) or titles.get(STAND_IN.get(uberon, ""), ""),
            "site": list(place(site)),
            "contours": [encode(svg.simplify(c, tolerance), place) for c in contours],
        }
    return {
        "name": name,
        "source": os.path.basename(path),
        "step": STEP,
        "silhouette": encode(svg.simplify(silhouette, 0.05), place),
        "lines": [
            encode(svg.simplify(c, 0.04), place)
            for c in lines
            if abs(svg.area(c)) > 0.25
        ],
        "parts": parts,
    }


def convert_brain(path: str, wanted: set[str]) -> dict:
    root, by_id = svg.read(path)
    outline_layer, tissue_layer = by_id["LAYER_OUTLINE"], by_id["LAYER_EFO"]
    lines = [
        c
        for shape in svg.shapes_of(by_id[BRAIN_OUTLINE], by_id, svg.parse_transform(outline_layer.get("transform")))
        for c in shape.contours
    ]
    silhouette = max(lines, key=lambda c: abs(svg.area(c)))
    x0, y0, x1, y1 = svg.bounds([silhouette])
    scale = BRAIN_LENGTH / (x1 - x0)
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2

    def place(p: svg.Point) -> tuple[int, int]:
        return (round((p[0] - cx) * scale / STEP), round((p[1] - cy) * scale / STEP))

    def in_view(contour: list[svg.Point]) -> bool:
        bx0, by0, bx1, by1 = svg.bounds([contour])
        return x0 <= (bx0 + bx1) / 2 <= x1 and y0 <= (by0 + by1) / 2 <= y1

    titles = titles_of(tissue_layer)
    parts = {}
    for child in tissue_layer:
        uberon = child.get("id")
        if uberon not in wanted and uberon not in BRAIN_LANDMARKS:
            continue
        contours = [
            c
            for shape in svg.shapes_of(child, by_id, svg.parse_transform(tissue_layer.get("transform")))
            for c in shape.contours
            if abs(svg.area(c)) > 1e-6 and in_view(c)
        ]
        if not contours:
            continue
        contours.sort(key=lambda c: -abs(svg.area(c)))
        site = site_of(contours[0])
        parts[uberon] = {
            "title": titles.get(uberon, ""),
            "site": list(place(site)),
            "contours": [encode(svg.simplify(c, 0.05), place) for c in contours],
        }
    missing = wanted - set(parts)
    if missing:
        raise SystemExit(f"the brain's view draws no {sorted(missing)}")
    return {
        "name": "brain",
        "source": os.path.basename(path),
        "step": STEP,
        "silhouette": encode(svg.simplify(silhouette, 0.06), place),
        "lines": [
            encode(svg.simplify(c, 0.06), place)
            for c in lines
            if abs(svg.area(c)) > 0.6
        ],
        "parts": parts,
    }


def decode(flat: list[int]) -> list[tuple[int, int]]:
    out, x, y = [], 0, 0
    for i in range(0, len(flat), 2):
        x, y = x + flat[i], y + flat[i + 1]
        out.append((x, y))
    return out


def dart(figures: dict[str, dict]) -> str:
    lines = [
        "// GENERATED by tool/zoom/anatomogram.py. Do not edit: run it again.",
        "//",
        "// Outlines made from the Expression Atlas anatomograms, EMBL-EBI,",
        f"// https://github.com/{REPOSITORY} at commit",
        f"// {COMMIT},",
        "// licensed CC BY 4.0 (https://creativecommons.org/licenses/by/4.0/).",
        "// Changed from the drawings: contours simplified, only the tissues the",
        "// zoom names kept, of the brain only its mid-sagittal view, and the",
        "// mouth standing in for the tongue the female figure does not draw.",
        "//",
        "// Each constant is one figure as JSON: `step` metres to the integer;",
        "// a contour is its first point, then each step to the next.",
        "",
        "// ignore_for_file: lines_longer_than_80_chars",
        "",
    ]
    for name, figure in figures.items():
        text = json.dumps(figure, separators=(",", ":"), sort_keys=True)
        if "'" in text or "$" in text:
            raise SystemExit("the JSON would need escaping in a Dart string")
        lines.append(f"/// The {name} figure: see the head of this file.")
        lines.append(f"const String anatomy{name.capitalize()}Json =")
        for i in range(0, len(text), 72):
            end = ";" if i + 72 >= len(text) else ""
            lines.append(f"    r'{text[i : i + 72]}'{end}")
        lines.append("")
    return "\n".join(lines)


def preview(figures: dict[str, dict], directory: str) -> None:
    """Draws each figure's converted outlines, to look at. Needs Pillow,
    which nothing else here does."""
    from PIL import Image, ImageDraw  # type: ignore

    os.makedirs(directory, exist_ok=True)
    for name, figure in figures.items():
        everything = [decode(figure["silhouette"])] + [decode(c) for c in figure["lines"]]
        xs = [p[0] for c in everything for p in c]
        ys = [p[1] for c in everything for p in c]
        x0, y0 = min(xs), min(ys)
        scale = 1600 / max(max(xs) - x0, max(ys) - y0)

        def at(p):
            return ((p[0] - x0) * scale + 20, (p[1] - y0) * scale + 20)

        image = Image.new("RGB", (int((max(xs) - x0) * scale) + 40, int((max(ys) - y0) * scale) + 40), "#151312")
        draw = ImageDraw.Draw(image, "RGBA")
        draw.polygon([at(p) for p in decode(figure["silhouette"])], fill=(60, 52, 46, 255))
        for contour in figure["lines"]:
            draw.line([at(p) for p in decode(contour)] + [at(decode(contour)[0])], fill=(150, 132, 115, 255), width=1)
        for k, (uberon, part) in enumerate(sorted(figure["parts"].items())):
            hue = (k * 47) % 360
            colour = tuple(int(c) for c in _hsv(hue, 0.6, 0.95)) + (120,)
            for contour in part["contours"]:
                points = [at(p) for p in decode(contour)]
                if len(points) >= 3:
                    draw.polygon(points, fill=colour, outline=colour[:3] + (255,))
            sx, sy = at(part["site"])
            draw.ellipse([sx - 4, sy - 4, sx + 4, sy + 4], fill=(64, 224, 200, 255))
            draw.text((sx + 6, sy - 6), part["title"], fill=(240, 240, 240, 255))
        image.save(os.path.join(directory, f"anatomy_{name}.png"))


def _hsv(h: float, s: float, v: float) -> tuple[float, float, float]:
    c = v * s
    x = c * (1 - abs((h / 60) % 2 - 1))
    m = v - c
    r, g, b = [(c, x, 0), (x, c, 0), (0, c, x), (0, x, c), (x, 0, c), (c, 0, x)][int(h // 60) % 6]
    return ((r + m) * 255, (g + m) * 255, (b + m) * 255)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("--svg-dir", help="where the three SVGs are, or are to be kept")
    parser.add_argument("--out", default=OUT)
    parser.add_argument("--preview", help="a directory to draw the converted figures into")
    parser.add_argument(
        "--check",
        action="store_true",
        help="write nothing: fail if the file is not what this would write",
    )
    args = parser.parse_args()
    paths = fetch(args.svg_dir)
    body, brain = table_ids()
    figures = {
        "female": convert_body("female", paths["female"], body),
        "male": convert_body("male", paths["male"], body),
        "brain": convert_brain(paths["brain"], brain),
    }
    if args.check:
        with open(args.out, encoding="utf-8") as current:
            if current.read() != dart(figures):
                raise SystemExit(f"{os.path.relpath(args.out, APP)} is stale: run this without --check")
        print(f"{os.path.relpath(args.out, APP)} is current")
        return
    os.makedirs(os.path.dirname(args.out), exist_ok=True)
    with open(args.out, "w", encoding="utf-8") as out:
        out.write(dart(figures))
    for name, figure in figures.items():
        points = sum(len(c) // 2 for part in figure["parts"].values() for c in part["contours"])
        outline = len(figure["silhouette"]) // 2 + sum(len(c) // 2 for c in figure["lines"])
        size = len(json.dumps(figure, separators=(",", ":")))
        print(f"{name}: {len(figure['parts'])} parts, {points} points; outline {outline} points; {size:,} bytes")
    missing = {
        "female": sorted(body - set(figures["female"]["parts"])),
        "male": sorted(body - set(figures["male"]["parts"])),
    }
    print(f"not drawn in the female figure: {missing['female']}")
    print(f"not drawn in the male figure: {missing['male']}")
    if args.preview:
        preview(figures, args.preview)
    print(f"wrote {os.path.relpath(args.out, APP)}")


if __name__ == "__main__":
    main()
