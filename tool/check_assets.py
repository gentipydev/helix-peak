"""Check the baked assets against each other, and against the Dart catalog.

Three tools write three families of asset from one table, and the Dart side
holds a fourth copy of the parts it needs. Nothing but this notices when they
come apart — a constraint track baked before a gene record was rebuilt still
parses, still loads, and quietly stops colouring the page it is for.

    python3 tool/check_assets.py
    python3 tool/check_assets.py --against https://helix-peak-backend.onrender.com

Exits non-zero on the first disagreement, with both sides named.

`--against` checks a fifth copy: the catalog rows the service serves. It reads
`targets.py` and the Dart source directly rather than going through
`tool/seed_catalog.py`, so a seeder that writes the wrong thing is caught
rather than confirmed -- the same reason `tool/constraint/verify_cpu.py`
re-derives its numbers instead of calling the scorer.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
import re
import struct
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tool"))

from targets import TARGETS, Target, partition  # noqa: E402
from impact.check_explanations import validate as validate_explanations  # noqa: E402

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


def seed_tracks(text: str) -> dict[str, set[str]]:
    """The `const Map<TrackKind, TrackRef>` maps the rows point `tracks:` at.

    Phase 4a retired `scored` and `impactScored` out of the rows and into these
    maps, so this is where those two facts now live. Spreads are followed --
    `_seededWithExplanations` is `_seeded` plus one kind -- and a spread of
    something not yet read is an error rather than a silently smaller set.
    """
    maps: dict[str, set[str]] = {}
    for name, body in re.findall(
        r"const Map<TrackKind, TrackRef> (\w+) = <TrackKind, TrackRef>\{(.*?)\n\};",
        text,
        re.S,
    ):
        kinds = set(re.findall(r"TrackKind\.(\w+):", body))
        for spread in re.findall(r"\.\.\.(\w+)", body):
            if spread not in maps:
                raise SystemExit(f"{CATALOG.name}: {name} spreads unknown {spread}")
            kinds |= maps[spread]
        maps[name] = kinds
    if not maps:
        raise SystemExit(f"{CATALOG.name} has no seeded track maps to read")
    return maps


def dart_catalog() -> dict[str, dict]:
    """The `const ProteinTarget` rows, read off the Dart source.

    A regex over source is a blunt instrument, and it is the right one here:
    the alternative is generating the Dart, which would put the screen's own
    prose in a Python file and take it away from the people editing the screen.
    This only has to read the handful of fields both sides claim to know.
    """
    text = CATALOG.read_text()
    seeds = seed_tracks(text)
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
        # Which families the row is seeded with. This replaced four booleans
        # the rows never actually stated -- every one of them relied on the
        # constructor default, so the comparisons below were True against True
        # for all twenty and could not have caught anything.
        named = re.search(r"\btracks: (\w+)\b", block)
        if named is None:
            fail(f"{row['slug']}: the row seeds no tracks map")
            kinds: set[str] = set()
        elif named.group(1) not in seeds:
            fail(f"{row['slug']}: seeds {named.group(1)}, which is not a track map")
            kinds = set()
        else:
            kinds = seeds[named.group(1)]
        row["scored"] = "constraint" in kinds
        row["impact_scored"] = "impact" in kinds
        row["clinvar_available"] = "clinvar" in kinds
        row["impact_explanations"] = "impactExplanations" in kinds
        # The one that has not retired into the map yet is still a field, and
        # has to agree with it. A row whose boolean and whose map disagree is a
        # row the walk and this gate would read differently.
        explanations = re.search(r"\bimpactExplanationsAvailable: (true|false)\b", block)
        stated = explanations is not None and explanations.group(1) == "true"
        if stated != row["impact_explanations"]:
            fail(f"{row['slug']}: impactExplanationsAvailable and the seeded tracks disagree")
        row["facts"] = {
            key: int(value)
            for key, value in re.findall(r"(residues|exons|chains|bridges): (\d+)", block)
        }
        row["tints"] = re.findall(r"StructureChain\('(\w+)', ChainTint\.(\w+)\)", block)
        count = re.search(r"\bcount: (\d+)", block)
        row["count"] = int(count.group(1)) if count else None
        rows[row["slug"]] = row
    return rows


def service_rows(base_url: str) -> dict[str, dict]:
    """`GET /protein/{slug}` for every target, keyed by slug."""
    import urllib.error
    import urllib.request

    found: dict[str, dict] = {}
    for target in TARGETS:
        url = f"{base_url.rstrip('/')}/protein/{target.slug}"
        try:
            with urllib.request.urlopen(url, timeout=30) as response:
                found[target.slug] = json.loads(response.read())
        except urllib.error.HTTPError as exc:
            fail(f"{target.slug}: {url} returned {exc.code}")
        except (urllib.error.URLError, OSError, ValueError) as exc:
            raise SystemExit(f"Could not read {url}: {exc}")
    return found


def check_against(base_url: str, catalog: dict[str, dict]) -> None:
    """The service's catalog row against the two tables it was seeded from.

    Every field the app reads has to survive the move. A field that quietly
    arrives null is a protein page that draws one thing less than it used to,
    and nothing else in the suite would notice.
    """
    served = service_rows(base_url)
    for target in TARGETS:
        row = served.get(target.slug)
        if row is None:
            continue
        dart = catalog[target.slug]
        where = f"{target.slug}: served"
        source = target.source

        expected = {
            "gene": target.gene,
            "uniprot": target.uniprot,
            "accession": source.accession,
            "transcript_id": source.transcript_id,
            "protein_id": source.protein_id,
            "mature_peptides": target.mature_peptides,
            "display": dart["display"],
            "summary": dart["summary"],
            "chain": dart.get("chain"),
        }
        for key, want in expected.items():
            if row.get(key) != want:
                fail(f"{where} {key} is {row.get(key)!r}, table says {want!r}")

        if row.get("facts") != dart["facts"]:
            fail(f"{where} facts {row.get('facts')} != catalog {dart['facts']}")

        want_regions = partition(target)
        if row.get("regions") != want_regions:
            fail(f"{where} {len(row.get('regions') or [])} regions, "
                 f"partition() gives {len(want_regions)}")

        want_bonds = [list(pair) for pair in target.disulfides]
        if row.get("disulfides") != want_bonds:
            fail(f"{where} disulfides {row.get('disulfides')} != {want_bonds}")

        # The node names are the contract with structure_view.dart, and the
        # tint order is the order the record lists the mature peptides in.
        want_chains = [{"node": node, "tint": tint} for node, tint in dart["tints"]]
        if row.get("chains") != want_chains:
            fail(f"{where} chains {row.get('chains')} != catalog {want_chains}")

        chrome = row.get("structure") or {}
        if chrome.get("pdb") != target.structure.pdb:
            fail(f"{where} pdb {chrome.get('pdb')!r} != {target.structure.pdb!r}")
        want_modelled = list(dart["modelled"]) if dart["modelled"] else None
        if chrome.get("modelled") != want_modelled:
            fail(f"{where} modelled {chrome.get('modelled')} != {want_modelled}")
        if chrome.get("count") != dart["count"]:
            fail(f"{where} count {chrome.get('count')} != {dart['count']}")
        for key in ("label", "unit", "sentence", "semantics"):
            if not chrome.get(key):
                fail(f"{where} structure.{key} is empty")

        # The four booleans, as the four states that replaced them. Every one
        # of the twenty is baked, so a track that is neither ready nor absent
        # means the seed and the table disagree about what exists.
        states = row.get("tracks") or {}
        for kind, baked in (("constraint", target.scored),
                            ("impact", target.impact_scored),
                            ("clinvar", target.clinvar_available),
                            ("impact_explanations", dart["impact_explanations"])):
            if kind not in states:
                fail(f"{where} has no {kind} track state")
            elif states[kind] == "refused" and baked:
                fail(f"{where} {kind} is refused but the table says it is baked")

    if not problems:
        print(f"{len(served)} catalog rows on {base_url} agree with targets.py "
              f"and protein_catalog.dart.")


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
    impact_path = ROOT / target.impact_asset
    model_path = ROOT / target.structure_asset
    required = [mock_path, model_path]
    if target.scored:
        required.append(constraint_path)
    if target.impact_scored:
        required.append(impact_path)
    for path in required:
        if not path.exists():
            fail(f"{where}: missing {path.relative_to(ROOT)}")
            return
    if not target.scored and constraint_path.exists():
        fail(
            f"{where}: {constraint_path.relative_to(ROOT)} exists, but targets.py says this "
            "protein is not scored"
        )
    if not target.impact_scored and impact_path.exists():
        fail(
            f"{where}: {impact_path.relative_to(ROOT)} exists, but targets.py says this "
            "gene has no impact track"
        )

    clinical_path = ROOT / f"assets/clinvar/{target.slug}_clinvar.json"
    if target.clinvar_available != clinical_path.exists():
        fail(f"{where}: ClinVar asset availability differs from the table")
    mock = json.loads(mock_path.read_text())
    if target.clinvar_available and clinical_path.exists():
        check_clinvar(target, mock, json.loads(clinical_path.read_text()))

    if mock["gene"] != target.gene:
        fail(f"{where}: record is for {mock['gene']}, table says {target.gene}")

    span = mock["location"]["end"] - mock["location"]["start"] + 1
    if len(mock["sequence"]) != span:
        fail(f"{where}: {len(mock['sequence'])} bases of sequence for a {span} bp span")
    check_record(mock, where)

    if target.scored and not check_constraint(target, mock, json.loads(constraint_path.read_text())):
        return

    if target.impact_scored and not check_impact(
        target, mock, json.loads(impact_path.read_text())
    ):
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
    if row["clinvar_available"] != target.clinvar_available:
        fail(f"{where}: ClinVar availability differs in Dart and Python")
    if row["impact_scored"] != target.impact_scored:
        fail(
            f"{where}: catalog.dart says impactScored={row['impact_scored']}, "
            f"table says {target.impact_scored}"
        )
    if set(row["chains"]) != nodes:
        fail(
            f"{where}: catalog.dart paints {sorted(row['chains'])}, "
            f"{model_path.name} holds {sorted(nodes)}"
        )


def check_clinvar(target: Target, mock: dict, clinical: dict) -> None:
    """Independently rederive each allele and codon from the shipped record."""
    where = target.slug + " ClinVar"
    impact = json.loads((ROOT / target.impact_asset).read_text())
    if any(clinical.get(k) != impact[k] for k in
           ("gene", "accession", "assembly", "chromosome", "start", "sequence", "runs", "complemented")):
        fail(f"{where}: mapping differs from the gene/AVI track")
    if clinical.get("protein_sequence") != mock["protein"]["translation"]:
        fail(f"{where}: protein differs")
    variants = clinical["variants"]
    if len({v["variation_id"] for v in variants}) != len(variants):
        fail(f"{where}: repeated Variation ID")
    if len(variants) + sum(clinical["excluded"].values()) != clinical["searched_records"]:
        fail(f"{where}: incomplete search")
    cds = positions(mock, mock["protein"]["segments"])
    offsets = {p: i for i, p in enumerate(cds)}
    dna = bases(mock, cds)
    complement = str.maketrans("ACGT", "TGCA")
    for v in variants:
        local = v["position"]
        if bases(mock, [local]) != v["ref"] or len(v["alt"]) != 1 or v["alt"] not in "ACGT" or v["alt"] == v["ref"]:
            fail(f"{where}: reference/allele mismatch {v['variation_id']}")
        mapped = [r["genomic"] + r["step"] * (local - r["local"]) for r in impact["runs"]
                  if r["local"] <= local < r["local"] + r["length"]]
        if mapped != [v["genomic"]]:
            fail(f"{where}: genomic mismatch {v['variation_id']}")
        for key in ("ref", "alt"):
            genomic_base = v[key].translate(complement) if impact["complemented"] else v[key]
            if genomic_base != v["genomic_" + key]:
                fail(f"{where}: strand mismatch {v['variation_id']}")
        offset = offsets.get(local)
        if offset is not None:
            codon = dna[offset // 3 * 3:offset // 3 * 3 + 3]
            ref = translate(codon)
            alt = translate(codon[:offset % 3] + v["alt"] + codon[offset % 3 + 1:])
            residue = offset // 3 + 1 if ref != "*" else None
            expected = f"p.{ref}{residue}{'=' if ref == alt else alt}" if residue else None
            if v["residue"] != residue or v["protein_change"] != expected:
                fail(f"{where}: protein mapping mismatch {v['variation_id']}")
        elif v["residue"] is not None:
            fail(f"{where}: noncoding variant has a residue")
        if not v["classification"] or not v["review_status"] or not v["accession"].startswith("VCV"):
            fail(f"{where}: missing classification provenance")
    # The identifiers ClinVar gives the conditions it names: every entry names a
    # condition some record's RCV cites, and nothing is written in its place.
    named = {n for v in variants for c in v["conditions"] for n in c["names"]}
    for name, ids in clinical.get("traits", {}).items():
        if name not in named:
            fail(f"{where}: identifiers for {name!r}, which no record names")
        if (not re.fullmatch(r"CN?\d+", ids.get("medgen", ""))
                or not re.fullmatch(r"(PS)?\d{6}", ids.get("omim", "000000"))
                or not re.fullmatch(r"MONDO:\d{7}", ids.get("mondo", "MONDO:0000000"))
                or set(ids) - {"medgen", "symbol", "omim", "mondo"}):
            fail(f"{where}: malformed identifiers for {name!r}")


def check_impact(target: Target, mock: dict, impact: dict) -> bool:
    """The per-base AVI track against the record it is filed under.

    The bake's own gates are the real ones — every score is checked against the
    reference base the Atlas returned with it. What is left for here is that the
    file on disk still belongs to this record: the same letters, the same
    coordinates, a map that covers all of them, and the biology the feature
    claims still holding.
    """
    where = target.slug
    for field, mine in (
        ("gene", target.gene),
        ("uniprot", target.uniprot),
        ("accession", target.source.accession),
        ("assembly", "GRCh38"),
        ("annotation", "GENCODE v46"),
        ("scorer", "AVI_SCORE"),
        ("score_units", "phred"),
    ):
        if impact.get(field) != mine:
            fail(f"{where}: impact track says {field}={impact.get(field)!r}, expected {mine!r}")
            return False

    # The drawn letters in increasing record position, which is how the app
    # reads them. The same as the record's own `sequence` except on a
    # minus-strand record, which stores its letters from the far end (R2.1).
    loc = mock["location"]
    if impact["sequence"] != bases(mock, list(range(loc["start"], loc["end"] + 1))):
        fail(f"{where}: the impact track's sequence is not the record's drawn letters")
        return False
    if impact["start"] != mock["location"]["start"]:
        fail(
            f"{where}: impact track starts at {impact['start']}, "
            f"the record at {mock['location']['start']}"
        )
        return False

    covered = sum(run["length"] for run in impact["runs"])
    if covered != len(mock["sequence"]):
        fail(
            f"{where}: the coordinate map covers {covered:,} of "
            f"{len(mock['sequence']):,} drawn bases"
        )
        return False

    # Every run has to stay inside the record and inside the chromosome.
    for run in impact["runs"]:
        last_local = run["local"] + run["length"] - 1
        last_genomic = run["genomic"] + run["step"] * (run["length"] - 1)
        if run["local"] < impact["start"] or last_local > mock["location"]["end"]:
            fail(f"{where}: a coordinate run leaves the record at {run['local']}")
            return False
        if min(run["genomic"], last_genomic) < 1:
            fail(f"{where}: a coordinate run leaves the chromosome at {run['genomic']}")
            return False

    start = impact["start"]
    for local, values in impact["positions"].items():
        offset = int(local) - start
        if offset < 0 or offset >= len(impact["sequence"]):
            fail(f"{where}: a score at {local} is outside the record")
            return False
        if len(values) != 3:
            fail(f"{where}: {len(values)} substitutions at {local}, expected three")
            return False

    scored = len(impact["positions"])
    if scored < len(mock["sequence"]) * 0.98:
        fail(f"{where}: only {scored:,} of {len(mock['sequence']):,} drawn bases are scored")
        return False

    # The claim the sheet makes, checked on the file rather than on the bake's
    # report of it: a splice boundary is not a quiet place and an intron
    # interior is.
    peak = {int(k): max(v) for k, v in impact["positions"].items()}
    exons = sorted((e["start"], e["end"]) for e in mock["exons"])
    exonic = [peak[p] for a, b in exons for p in range(a, b + 1) if p in peak]
    junction: list[float] = []
    interior: list[float] = []
    for (_, a), (b, _) in zip(exons, exons[1:]):
        low, high = a + 1, b - 1
        if high < low:
            continue
        edge = min(8, (high - low + 1) // 2)
        for p in range(low, high + 1):
            if p not in peak:
                continue
            (junction if p < low + edge or p > high - edge else interior).append(peak[p])
    if exonic and interior:
        if median(exonic) <= median(interior):
            fail(
                f"{where}: exons score no higher than intron interiors "
                f"({median(exonic):.1f} vs {median(interior):.1f})"
            )
            return False
        if junction and median(junction) <= median(interior):
            fail(
                f"{where}: splice boundaries score no higher than intron interiors "
                f"({median(junction):.1f} vs {median(interior):.1f})"
            )
            return False
    return True


def median(values: list[float]) -> float:
    ordered = sorted(values)
    middle = len(ordered) // 2
    if len(ordered) % 2:
        return ordered[middle]
    return (ordered[middle - 1] + ordered[middle]) / 2


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
    parser = argparse.ArgumentParser(description="Check the baked assets against each other.")
    parser.add_argument(
        "--against", metavar="BASE_URL", default=None,
        help="also check the catalog rows a running service serves",
    )
    parser.add_argument(
        "--offline", action="store_true",
        help="skip the service check even when --against is given",
    )
    arguments = parser.parse_args()

    catalog = dart_catalog()

    if arguments.against and not arguments.offline:
        check_against(arguments.against, catalog)
        if problems:
            print(f"{len(problems)} problem(s):", file=sys.stderr)
            for problem in problems:
                print(f"  - {problem}", file=sys.stderr)
            raise SystemExit(1)
        raise SystemExit(0)

    extra = set(catalog) - {t.slug for t in TARGETS}
    if extra:
        fail(f"protein_catalog.dart has rows with no bake: {sorted(extra)}")

    for target in TARGETS:
        check(target, catalog)
        attribution = ROOT / f"assets/impact_explanations/{target.slug}.json"
        included = catalog.get(target.slug, {}).get("impact_explanations", False)
        if attribution.exists() != included:
            fail(f"{target.slug}: attribution asset and catalog availability disagree")
        elif included:
            try:
                validate_explanations((ROOT / target.impact_asset).read_bytes(), json.loads(attribution.read_text()))
            except (AssertionError, KeyError, TypeError, ValueError) as error:
                fail(f"{target.slug}: invalid AVI explanations: {error}")

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
        for path in (
            [t.mock_asset]
            + ([t.constraint_asset] if t.scored else [])
            + ([t.impact_asset] if t.impact_scored else [])
            + ([f"assets/clinvar/{t.slug}_clinvar.json"] if t.clinvar_available else [])
            + ([f"assets/impact_explanations/{t.slug}.json"] if catalog[t.slug]["impact_explanations"] else [])
        )
    )
    scenes = sum(
        f.stat().st_size for f in MANIFEST.parent.glob("*.fsceneb")
    )
    scored = sum(1 for t in TARGETS if t.scored)
    tracked = sum(1 for t in TARGETS if t.impact_scored)
    print(
        f"{len(TARGETS)} targets check out, {scored} scored and "
        f"{tracked} with an impact track. "
        f"{total / 1e6:.2f} MB of records and tracks, "
        f"{scenes / 1e6:.2f} MB of compiled scenes."
    )
