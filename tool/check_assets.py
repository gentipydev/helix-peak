"""Check the baked assets against each other, and against the Dart catalog.

Three tools write three families of asset from one table, and the Dart side
holds a fourth copy of the parts it needs. Nothing but this notices when they
come apart — a constraint track baked before a gene record was rebuilt still
parses, still loads, and quietly stops colouring the page it is for.

    python3 tool/check_assets.py

Exits non-zero on the first disagreement, with both sides named.
"""

from __future__ import annotations

import json
from pathlib import Path
import re
import struct
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tool"))

from targets import TARGETS, Target, partition  # noqa: E402

CATALOG = ROOT / "lib/features/gene_lookup/domain/entities/protein_catalog.dart"
MANIFEST = ROOT / "flutter_scene_generated/manifest.json"

problems: list[str] = []


def fail(message: str) -> None:
    problems.append(message)


def glb_nodes(path: Path) -> set[str]:
    """The node names in a binary glTF, read straight out of its JSON chunk."""
    blob = path.read_bytes()
    magic, _, _ = struct.unpack_from("<III", blob, 0)
    if magic != 0x46546C67:
        raise ValueError(f"{path} is not a .glb")
    length, kind = struct.unpack_from("<II", blob, 12)
    if kind != 0x4E4F534A:
        raise ValueError(f"{path} does not start with a JSON chunk")
    document = json.loads(blob[20 : 20 + length])
    return {n["name"] for n in document.get("nodes", []) if n.get("name")}


def dart_catalog() -> dict[str, dict]:
    """The `const ProteinTarget` rows, read off the Dart source.

    A regex over source is a blunt instrument, and it is the right one here:
    the alternative is generating the Dart, which would put the screen's own
    prose in a Python file and take it away from the people editing the screen.
    This only has to read the handful of fields both sides claim to know.
    """
    text = CATALOG.read_text()
    rows: dict[str, dict] = {}
    for block in re.findall(r"ProteinTarget\((.*?)\n  \);", text, re.S):
        row = {
            key: value
            for key, value in re.findall(r"(\w+): '([^']*)'", block)
        }
        chains = re.findall(r"StructureChain\('(\w+)',", block)
        if "slug" not in row:
            continue
        row["chains"] = chains
        modelled = re.search(r"modelled: \((\d+), (\d+)\)", block)
        row["modelled"] = (int(modelled.group(1)), int(modelled.group(2))) if modelled else None
        # Absent means scored, as the Dart constructor's default does.
        scored = re.search(r"\bscored: (true|false)\b", block)
        row["scored"] = scored is None or scored.group(1) == "true"
        rows[row["slug"]] = row
    return rows


# The standard code, which every protein here uses: no selenocysteine, no
# alternative start. `TCA` is serine, `TAA` a stop.
_BASES = "TCAG"
_AMINO = "FFLLSSSSYY**CC*WLLLLPPPPHHQQRRRRIIIMTTTTNNKKSSRRVVVVAAAADDEEGGGG"
CODONS = {
    a + b + c: _AMINO[16 * i + 4 * j + k]
    for i, a in enumerate(_BASES)
    for j, b in enumerate(_BASES)
    for k, c in enumerate(_BASES)
}


def translate(bases: str) -> str:
    return "".join(CODONS.get(bases[i : i + 3], "X") for i in range(0, len(bases) - 2, 3))


def positions(mock: dict, segments: list[dict]) -> list[int]:
    """Every position of `segments`, in transcript order."""
    reverse = mock["location"].get("strand") == -1
    out: list[int] = []
    for segment in sorted(segments, key=lambda s: s["start"], reverse=reverse):
        span = range(segment["start"], segment["end"] + 1)
        out.extend(reversed(span) if reverse else span)
    return out


def bases(mock: dict, at: list[int]) -> str:
    """The record's own bases at `at`. A minus-strand `sequence` is already
    reverse-complemented (R2.1), so it is indexed from the far end there."""
    start, end = mock["location"]["start"], mock["location"]["end"]
    reverse = mock["location"].get("strand") == -1
    sequence = mock["sequence"]
    return "".join(sequence[end - p] if reverse else sequence[p - start] for p in at)


def check_record(mock: dict, where: str) -> None:
    """What the bake proves once, proved again from the baked file alone.

    The record's pieces are read from positions, and the page draws them from
    positions, so every piece is checked the way the page will read it:

    - the CDS translates to the protein (R2.2);
    - the signal peptide, the proprotein and every peptide are whole codons of
      one stretch of that CDS, and translate to the protein at their own
      offset. A neighbouring gene's feature — LTA's peptides beside TNF, the
      INS-IGF2 readthrough beside insulin — fails here, which is what re-proves
      the backend's exact `/gene` match for every record rather than for the
      one it has a test fixture of;
    - every intron starts and ends as an intron can: GT-AG, GC-AG or AT-AC
      (R2.3). Shortened introns keep their own ends, so this holds for
      dystrophin's too.
    """
    protein = mock.get("protein")
    if not protein:
        fail(f"{where}: the record has no protein")
        return
    translation = protein["translation"]
    cds = positions(mock, protein["segments"])
    if translate(bases(mock, cds)).rstrip("*") != translation:
        fail(f"{where}: the CDS does not translate to the record's protein")
        return
    index = {p: i for i, p in enumerate(cds)}

    pieces = [("the signal peptide", mock.get("signal_peptide")), ("the proprotein", mock.get("proprotein"))]
    pieces += [(p.get("product") or "a peptide", p) for p in mock["peptides"]]
    for name, piece in pieces:
        if not piece:
            continue
        at = positions(mock, piece["segments"])
        offsets = [index.get(p) for p in at]
        if None in offsets or offsets != list(range(offsets[0], offsets[0] + len(at))) or offsets[0] % 3 or len(at) % 3:
            fail(f"{where}: {name} is not whole codons of one stretch of the CDS")
            continue
        first = offsets[0] // 3
        expected = translation[first : first + len(at) // 3]
        if translate(bases(mock, at)) != expected or piece.get("translation") != expected:
            fail(f"{where}: {name} does not translate to residues {first + 1}-{first + len(at) // 3}")

    transcript = mock.get("transcript") or {}
    segments = transcript.get("segments") or mock["exons"]
    reverse = mock["location"].get("strand") == -1
    ordered = sorted(segments, key=lambda s: s["start"], reverse=reverse)
    for number, (before, after) in enumerate(zip(ordered, ordered[1:]), 1):
        if reverse:
            intron = list(range(before["start"] - 1, after["end"], -1))
        else:
            intron = list(range(before["end"] + 1, after["start"]))
        if len(intron) < 4:
            continue
        ends = (bases(mock, intron[:2]), bases(mock, intron[-2:]))
        if ends not in {("GT", "AG"), ("GC", "AG"), ("AT", "AC")}:
            fail(f"{where}: intron {number} runs {ends[0]}…{ends[1]}, which no spliceosome cuts")


def check(target: Target, catalog: dict[str, dict]) -> None:
    where = target.slug

    mock_path = ROOT / target.mock_asset
    constraint_path = ROOT / target.constraint_asset
    model_path = ROOT / target.structure_asset
    required = (mock_path, constraint_path, model_path) if target.scored else (mock_path, model_path)
    for path in required:
        if not path.exists():
            fail(f"{where}: missing {path.relative_to(ROOT)}")
            return
    if not target.scored and constraint_path.exists():
        fail(
            f"{where}: {constraint_path.relative_to(ROOT)} exists, but targets.py says this "
            "protein is not scored"
        )

    mock = json.loads(mock_path.read_text())

    if mock["gene"] != target.gene:
        fail(f"{where}: record is for {mock['gene']}, table says {target.gene}")

    span = mock["location"]["end"] - mock["location"]["start"] + 1
    if len(mock["sequence"]) != span:
        fail(f"{where}: {len(mock['sequence'])} bases of sequence for a {span} bp span")
    check_record(mock, where)

    if target.scored and not check_constraint(target, mock, json.loads(constraint_path.read_text())):
        return

    nodes = glb_nodes(model_path)
    baked = {c.node for c in target.structure.chains} | (
        {"bonds"} if target.structure.bonds else set()
    )
    if nodes != baked:
        fail(f"{where}: {model_path.name} holds {sorted(nodes)}, the table says {sorted(baked)}")

    row = catalog.get(target.slug)
    if row is None:
        fail(f"{where}: no row in protein_catalog.dart")
        return
    for field, mine in (
        ("gene", target.gene),
        ("uniprot", target.uniprot),
        ("pdb", target.structure.pdb),
    ):
        if row.get(field) != mine:
            fail(f"{where}: catalog.dart says {field}={row.get(field)!r}, table says {mine!r}")
    if row["modelled"] != target.structure.residues:
        fail(
            f"{where}: catalog.dart says the model covers {row['modelled']}, "
            f"the table exports {target.structure.residues}"
        )
    if row["scored"] != target.scored:
        fail(f"{where}: catalog.dart says scored={row['scored']}, table says {target.scored}")
    if set(row["chains"]) != nodes:
        fail(
            f"{where}: catalog.dart paints {sorted(row['chains'])}, "
            f"{model_path.name} holds {sorted(nodes)}"
        )


def check_constraint(target: Target, mock: dict, constraint: dict) -> bool:
    """The track against the record it colours. False where nothing further is
    worth checking, because the two describe different proteins."""
    where = target.slug

    # The one that matters: the protein page is drawn from the record and
    # coloured from the track, and they are baked hours apart by different
    # tools. `AnatomyScreen` compares them too, and silently draws no colour.
    protein = mock["protein"]["translation"]
    if constraint["sequence"] != protein:
        fail(
            f"{where}: the constraint track is for a {len(constraint['sequence'])}-residue "
            f"protein, the record holds {len(protein)}. Re-run score_protein.py."
        )
        return False

    if len(constraint["positions"]) != len(protein):
        fail(f"{where}: {len(constraint['positions'])} positions for {len(protein)} residues")
    if constraint["uniprot"] != target.uniprot or constraint["gene"] != target.gene:
        fail(f"{where}: the track names {constraint['gene']}/{constraint['uniprot']}")

    expected_regions = partition(target)
    if constraint.get("regions") != expected_regions:
        fail(
            f"{where}: region table is stale. Re-run score_protein.py --metadata-only."
        )
    if constraint.get("disulfides") != [list(p) for p in target.disulfides]:
        fail(f"{where}: disulfide table is stale. Re-run --metadata-only.")
    return True


if __name__ == "__main__":
    catalog = dart_catalog()
    extra = set(catalog) - {t.slug for t in TARGETS}
    if extra:
        fail(f"protein_catalog.dart has rows with no bake: {sorted(extra)}")

    for target in TARGETS:
        check(target, catalog)

    if MANIFEST.exists():
        entries = {e["source"]: e["file"] for e in json.loads(MANIFEST.read_text())["entries"]}
        for target in TARGETS:
            compiled = entries.get(target.structure_asset)
            if compiled is None:
                fail(f"{target.slug}: no compiled scene; build the app to run the hook")
                continue
            # The `.fsceneb` is what actually ships, and it is what `_paint`
            # looks node names up in. Checking the `.glb` alone would miss a
            # compile that dropped or renamed one, which is a blank fold on a
            # phone and nothing anywhere else.
            blob = (MANIFEST.parent / compiled).read_bytes()
            wanted = {c.node for c in target.structure.chains} | (
                {"bonds"} if target.structure.bonds else set()
            )
            missing = {n for n in wanted if n.encode() not in blob}
            if missing:
                fail(f"{target.slug}: {compiled} has no node named {sorted(missing)}")
    else:
        fail("flutter_scene_generated/manifest.json is missing; build the app once")

    if problems:
        print(f"{len(problems)} problem(s):", file=sys.stderr)
        for problem in problems:
            print(f"  - {problem}", file=sys.stderr)
        raise SystemExit(1)

    total = sum(
        (ROOT / path).stat().st_size
        for t in TARGETS
        for path in ((t.mock_asset, t.constraint_asset) if t.scored else (t.mock_asset,))
    )
    scenes = sum(
        f.stat().st_size for f in MANIFEST.parent.glob("*.fsceneb")
    )
    scored = sum(1 for t in TARGETS if t.scored)
    print(
        f"{len(TARGETS)} targets check out, {scored} of them scored. "
        f"{total / 1e6:.2f} MB of records and tracks, "
        f"{scenes / 1e6:.2f} MB of compiled scenes."
    )
