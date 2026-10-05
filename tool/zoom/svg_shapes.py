"""Reads an Inkscape SVG's shapes as closed polygons, in the document's own
coordinates: paths (every command, curves flattened), ellipses, circles and
rects, through the transforms of the groups they are in and `use`.

Standard library only. Written for the Expression Atlas anatomograms, which
keep to basic shapes (see their `src/svg/README.md`).
"""

from __future__ import annotations

import math
import re
import xml.etree.ElementTree as ET

SVG = "{http://www.w3.org/2000/svg}"
XLINK = "{http://www.w3.org/1999/xlink}"

Point = tuple[float, float]
Matrix = tuple[float, float, float, float, float, float]

IDENTITY: Matrix = (1.0, 0.0, 0.0, 1.0, 0.0, 0.0)


def compose(m: Matrix, n: Matrix) -> Matrix:
    """`m` after `n`: a point goes through `n`, then `m`."""
    a, b, c, d, e, f = m
    g, h, i, j, k, l = n
    return (
        a * g + c * h,
        b * g + d * h,
        a * i + c * j,
        b * i + d * j,
        a * k + c * l + e,
        b * k + d * l + f,
    )


def apply(m: Matrix, p: Point) -> Point:
    a, b, c, d, e, f = m
    return (a * p[0] + c * p[1] + e, b * p[0] + d * p[1] + f)


_NUMBER = r"[-+]?(?:\d*\.\d+|\d+\.?)(?:[eE][-+]?\d+)?"


def parse_transform(text: str | None) -> Matrix:
    m = IDENTITY
    for name, args in re.findall(r"(\w+)\s*\(([^)]*)\)", text or ""):
        v = [float(x) for x in re.findall(_NUMBER, args)]
        if name == "matrix":
            t = (v[0], v[1], v[2], v[3], v[4], v[5])
        elif name == "translate":
            t = (1.0, 0.0, 0.0, 1.0, v[0], v[1] if len(v) > 1 else 0.0)
        elif name == "scale":
            t = (v[0], 0.0, 0.0, v[1] if len(v) > 1 else v[0], 0.0, 0.0)
        elif name == "rotate":
            a = math.radians(v[0])
            r = (math.cos(a), math.sin(a), -math.sin(a), math.cos(a), 0.0, 0.0)
            if len(v) == 3:
                r = compose(
                    (1, 0, 0, 1, v[1], v[2]),
                    compose(r, (1, 0, 0, 1, -v[1], -v[2])),
                )
            t = r
        else:
            raise ValueError(f"transform {name} is not read")
        m = compose(m, t)
    return m


def _cubic(p0: Point, p1: Point, p2: Point, p3: Point, steps: int) -> list[Point]:
    out = []
    for i in range(1, steps + 1):
        t = i / steps
        u = 1 - t
        out.append(
            (
                u**3 * p0[0] + 3 * u * u * t * p1[0] + 3 * u * t * t * p2[0] + t**3 * p3[0],
                u**3 * p0[1] + 3 * u * u * t * p1[1] + 3 * u * t * t * p2[1] + t**3 * p3[1],
            )
        )
    return out


def _arc(
    p0: Point, rx: float, ry: float, turn: float, large: bool, sweep: bool, p1: Point
) -> list[Point]:
    """An elliptical arc as SVG gives it, endpoint form, flattened."""
    if rx == 0 or ry == 0 or p0 == p1:
        return [p1]
    phi = math.radians(turn)
    cp, sp = math.cos(phi), math.sin(phi)
    dx, dy = (p0[0] - p1[0]) / 2, (p0[1] - p1[1]) / 2
    x1, y1 = cp * dx + sp * dy, -sp * dx + cp * dy
    rx, ry = abs(rx), abs(ry)
    scale = x1 * x1 / (rx * rx) + y1 * y1 / (ry * ry)
    if scale > 1:
        rx, ry = rx * math.sqrt(scale), ry * math.sqrt(scale)
    num = rx * rx * ry * ry - rx * rx * y1 * y1 - ry * ry * x1 * x1
    den = rx * rx * y1 * y1 + ry * ry * x1 * x1
    k = math.sqrt(max(0.0, num / den)) * (-1 if large == sweep else 1)
    cx1, cy1 = k * rx * y1 / ry, -k * ry * x1 / rx
    cx = cp * cx1 - sp * cy1 + (p0[0] + p1[0]) / 2
    cy = sp * cx1 + cp * cy1 + (p0[1] + p1[1]) / 2

    def angle(ux: float, uy: float, vx: float, vy: float) -> float:
        a = math.atan2(ux * vy - uy * vx, ux * vx + uy * vy)
        return a

    t0 = angle(1, 0, (x1 - cx1) / rx, (y1 - cy1) / ry)
    dt = angle((x1 - cx1) / rx, (y1 - cy1) / ry, (-x1 - cx1) / rx, (-y1 - cy1) / ry)
    if not sweep and dt > 0:
        dt -= 2 * math.pi
    elif sweep and dt < 0:
        dt += 2 * math.pi
    steps = max(4, int(abs(dt) / (math.pi / 16)))
    out = []
    for i in range(1, steps + 1):
        t = t0 + dt * i / steps
        x, y = rx * math.cos(t), ry * math.sin(t)
        out.append((cp * x - sp * y + cx, sp * x + cp * y + cy))
    return out


def parse_path(d: str, steps: int = 12) -> list[list[Point]]:
    """A path's subpaths as lists of points, curves flattened. A subpath
    that is closed, or ends where it began, has no repeat of its first
    point."""
    tokens = re.findall(r"[MmLlHhVvCcSsQqTtAaZz]|" + _NUMBER, d)
    subpaths: list[list[Point]] = []
    current: list[Point] = []
    pos: Point = (0.0, 0.0)
    start: Point = (0.0, 0.0)
    last_control: Point | None = None
    last_command = ""
    i = 0
    command = ""

    def take(n: int) -> list[float]:
        nonlocal i
        values = [float(tokens[i + k]) for k in range(n)]
        i += n
        return values

    while i < len(tokens):
        if re.fullmatch(r"[A-Za-z]", tokens[i]):
            command = tokens[i]
            i += 1
            if command in "Zz":
                if current:
                    subpaths.append(current)
                current = []
                pos = start
                last_command = command
                continue
        relative = command.islower()
        kind = command.upper()

        def point(x: float, y: float) -> Point:
            return (pos[0] + x, pos[1] + y) if relative else (x, y)

        if kind == "M":
            x, y = take(2)
            pos = point(x, y)
            if current:
                subpaths.append(current)
            current = [pos]
            start = pos
            # Further pairs after a move are lines.
            command = "l" if relative else "L"
        elif kind == "L":
            x, y = take(2)
            pos = point(x, y)
            current.append(pos)
        elif kind == "H":
            (x,) = take(1)
            pos = (pos[0] + x, pos[1]) if relative else (x, pos[1])
            current.append(pos)
        elif kind == "V":
            (y,) = take(1)
            pos = (pos[0], pos[1] + y) if relative else (pos[0], y)
            current.append(pos)
        elif kind == "C":
            x1, y1, x2, y2, x, y = take(6)
            c1, c2, end = point(x1, y1), point(x2, y2), point(x, y)
            current.extend(_cubic(pos, c1, c2, end, steps))
            last_control, pos = c2, end
        elif kind == "S":
            x2, y2, x, y = take(4)
            c1 = (
                (2 * pos[0] - last_control[0], 2 * pos[1] - last_control[1])
                if last_control and last_command.upper() in "CS"
                else pos
            )
            c2, end = point(x2, y2), point(x, y)
            current.extend(_cubic(pos, c1, c2, end, steps))
            last_control, pos = c2, end
        elif kind == "Q":
            x1, y1, x, y = take(4)
            c, end = point(x1, y1), point(x, y)
            c1 = (pos[0] + 2 / 3 * (c[0] - pos[0]), pos[1] + 2 / 3 * (c[1] - pos[1]))
            c2 = (end[0] + 2 / 3 * (c[0] - end[0]), end[1] + 2 / 3 * (c[1] - end[1]))
            current.extend(_cubic(pos, c1, c2, end, steps))
            last_control, pos = c, end
        elif kind == "T":
            x, y = take(2)
            c = (
                (2 * pos[0] - last_control[0], 2 * pos[1] - last_control[1])
                if last_control and last_command.upper() in "QT"
                else pos
            )
            end = point(x, y)
            c1 = (pos[0] + 2 / 3 * (c[0] - pos[0]), pos[1] + 2 / 3 * (c[1] - pos[1]))
            c2 = (end[0] + 2 / 3 * (c[0] - end[0]), end[1] + 2 / 3 * (c[1] - end[1]))
            current.extend(_cubic(pos, c1, c2, end, steps))
            last_control, pos = c, end
        elif kind == "A":
            rx, ry, turn, large, sweep, x, y = take(7)
            end = point(x, y)
            current.extend(_arc(pos, rx, ry, turn, large != 0, sweep != 0, end))
            pos = end
        else:
            raise ValueError(f"path command {command} is not read")
        last_command = command if kind != "M" else "M"
        if kind not in "CSQT":
            last_control = None
    if current:
        subpaths.append(current)
    cleaned = []
    for sub in subpaths:
        if len(sub) > 1 and math.dist(sub[0], sub[-1]) < 1e-9:
            sub = sub[:-1]
        if len(sub) >= 3:
            cleaned.append(sub)
    return cleaned


def _ellipse(cx: float, cy: float, rx: float, ry: float, steps: int = 48) -> list[Point]:
    return [
        (cx + rx * math.cos(2 * math.pi * k / steps), cy + ry * math.sin(2 * math.pi * k / steps))
        for k in range(steps)
    ]


def _style(el: ET.Element) -> dict[str, str]:
    style = {}
    for part in (el.get("style") or "").split(";"):
        if ":" in part:
            key, value = part.split(":", 1)
            style[key.strip()] = value.strip()
    return style


class Shape:
    """One basic shape: its subpaths in document coordinates, and the style
    it was drawn with."""

    def __init__(self, contours: list[list[Point]], style: dict[str, str], id: str):
        self.contours = contours
        self.style = style
        self.id = id


def shapes_of(
    el: ET.Element,
    by_id: dict[str, ET.Element],
    above: Matrix = IDENTITY,
    within: frozenset[int] = frozenset(),
) -> list[Shape]:
    """Every basic shape in `el`, through its own transform and those of the
    groups inside it, and through `use`. A `use` of something it lies inside
    (the female figure has one) is passed over."""
    tag = el.tag.replace(SVG, "")
    here = compose(above, parse_transform(el.get("transform")))
    within = within | {id(el)}
    if tag in ("g", "a", "svg"):
        out: list[Shape] = []
        for child in el:
            out.extend(shapes_of(child, by_id, here, within))
        return out
    if tag == "use":
        target = by_id.get((el.get(XLINK + "href") or "").lstrip("#"))
        if target is None or id(target) in within:
            return []
        shift = (1.0, 0.0, 0.0, 1.0, float(el.get("x") or 0), float(el.get("y") or 0))
        return shapes_of(target, by_id, compose(here, shift), within)
    if tag == "path":
        contours = parse_path(el.get("d") or "")
    elif tag == "ellipse":
        contours = [
            _ellipse(
                float(el.get("cx") or 0),
                float(el.get("cy") or 0),
                float(el.get("rx") or 0),
                float(el.get("ry") or 0),
            )
        ]
    elif tag == "circle":
        r = float(el.get("r") or 0)
        contours = [_ellipse(float(el.get("cx") or 0), float(el.get("cy") or 0), r, r)]
    elif tag == "rect":
        x, y = float(el.get("x") or 0), float(el.get("y") or 0)
        w, h = float(el.get("width") or 0), float(el.get("height") or 0)
        contours = [[(x, y), (x + w, y), (x + w, y + h), (x, y + h)]]
    else:
        return []
    return [
        Shape(
            [[apply(here, p) for p in contour] for contour in contours],
            _style(el),
            el.get("id") or "",
        )
    ]


def read(path: str) -> tuple[ET.Element, dict[str, ET.Element]]:
    root = ET.parse(path).getroot()
    return root, {el.get("id"): el for el in root.iter() if el.get("id")}


def area(contour: list[Point]) -> float:
    """A contour's signed area."""
    total = 0.0
    for i, p in enumerate(contour):
        q = contour[(i + 1) % len(contour)]
        total += p[0] * q[1] - q[0] * p[1]
    return total / 2


def bounds(contours: list[list[Point]]) -> tuple[float, float, float, float]:
    xs = [p[0] for c in contours for p in c]
    ys = [p[1] for c in contours for p in c]
    return (min(xs), min(ys), max(xs), max(ys))


def simplify(contour: list[Point], tolerance: float) -> list[Point]:
    """Ramer–Douglas–Peucker on a closed contour: split at its two farthest
    points and simplify each half."""
    if len(contour) < 5:
        return contour

    def rdp(points: list[Point]) -> list[Point]:
        keep = [False] * len(points)
        keep[0] = keep[-1] = True
        stack = [(0, len(points) - 1)]
        while stack:
            a, b = stack.pop()
            if b - a < 2:
                continue
            (x0, y0), (x1, y1) = points[a], points[b]
            dx, dy = x1 - x0, y1 - y0
            length = math.hypot(dx, dy)
            worst, at = -1.0, -1
            for k in range(a + 1, b):
                px, py = points[k]
                d = (
                    abs(dy * (px - x0) - dx * (py - y0)) / length
                    if length > 0
                    else math.hypot(px - x0, py - y0)
                )
                if d > worst:
                    worst, at = d, k
            if worst > tolerance:
                keep[at] = True
                stack.append((a, at))
                stack.append((at, b))
        return [p for p, k in zip(points, keep) if k]

    first = 0
    far = max(range(len(contour)), key=lambda k: math.dist(contour[first], contour[k]))
    one = rdp(contour[first : far + 1])
    two = rdp(contour[far:] + [contour[first]])
    return one[:-1] + two[:-1]
