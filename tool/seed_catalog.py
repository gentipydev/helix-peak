"""Seed the Supabase catalog from the two tables the twenty shipped with.

One-off, run by hand. `tool/targets.py` holds the coordinates, regions and
disulfides; `protein_catalog.dart` holds the prose, the facts and the chain
tints. Neither is the whole row, which is the reason this exists: after the
seed, one table holds both and `tool/check_assets.py --against <base-url>`
checks the service still agrees with `targets.py` field for field.

    NCBI_EMAIL=... DATABASE_URL=... python3 tool/seed_catalog.py
    python3 tool/seed_catalog.py --dry-run          # print the rows, touch nothing

The prose is read off the Dart source rather than moved into Python, for the
reason `check_assets.dart_catalog` already gives: generating the Dart would
take the screen's own words away from the people editing the screen. This
reads them one more time, into a database, and the Dart rows go away after.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tool"))

from targets import TARGETS, Target, partition  # noqa: E402

CATALOG = ROOT / "lib/features/gene_lookup/domain/entities/protein_catalog.dart"

RESOLVER_VERSION = 0  # 0 means "not resolved": these rows were written by hand.


# --- reading the Dart side --------------------------------------------------


def _dart_string(block: str, key: str) -> str | None:
    """One string field, with Dart's adjacent-literal concatenation joined.

    `semantics` is written as several quoted fragments on consecutive lines,
    which Dart concatenates and a single-literal regex would truncate.
    """
    match = re.search(rf"\b{key}:\s*((?:'(?:[^'\\]|\\.)*'\s*)+),", block)
    if match is None:
        return None
    parts = re.findall(r"'((?:[^'\\]|\\.)*)'", match.group(1))
    return "".join(parts).replace("\\'", "'").replace("\\\\", "\\")


def _dart_int(block: str, key: str) -> int | None:
    match = re.search(rf"\b{key}:\s*(\d+)", block)
    return int(match.group(1)) if match else None


def dart_rows() -> dict[str, dict]:
    """Every `const ProteinTarget`, and the order `all` lists them in."""
    text = CATALOG.read_text()

    order = {}
    listing = re.search(r"static const List<ProteinTarget> all = <ProteinTarget>\[(.*?)\];",
                        text, re.S)
    if listing is None:
        raise SystemExit("protein_catalog.dart has no `all` list to read the order from")
    for index, name in enumerate(re.findall(r"^\s*(\w+),\s*$", listing.group(1), re.M)):
        order[name] = index

    rows: dict[str, dict] = {}
    for name, block in re.findall(
        r"static const ProteinTarget (\w+) = ProteinTarget\((.*?)\n  \);", text, re.S
    ):
        slug = _dart_string(block, "slug")
        if slug is None:
            continue
        structure = re.search(r"structure: StructureChrome\((.*?)\n    \),", block, re.S)
        chrome = None
        if structure:
            inner = structure.group(1)
            modelled = re.search(r"modelled: \((\d+), (\d+)\)", inner)
            chrome = {
                "pdb": _dart_string(inner, "pdb"),
                "modelled": [int(modelled.group(1)), int(modelled.group(2))]
                if modelled else None,
                "label": _dart_string(inner, "label"),
                "count": _dart_int(inner, "count"),
                "unit": _dart_string(inner, "unit"),
                "sentence": _dart_string(inner, "sentence"),
                "semantics": _dart_string(inner, "semantics"),
            }
        rows[slug] = {
            "order": order.get(name),
            "display": _dart_string(block, "display"),
            "summary": _dart_string(block, "summary"),
            "chain": _dart_string(block, "chain"),
            "facts": {
                "residues": _dart_int(block, "residues"),
                "exons": _dart_int(block, "exons"),
                "chains": _dart_int(block, "chains"),
                "bridges": _dart_int(block, "bridges"),
            },
            "chains": [
                {"node": node, "tint": tint}
                for node, tint in re.findall(
                    r"StructureChain\('(\w+)',\s*ChainTint\.(\w+)\)", block
                )
            ],
            "chrome": chrome,
            "impact_explanations": bool(
                re.search(r"\bimpactExplanationsAvailable: true\b", block)
            ),
        }
    return rows


# --- building the rows ------------------------------------------------------


def _aliases(target: Target, dart: dict) -> list[tuple[str, str]]:
    """Every string `matching()` can rank against, as (alias, kind).

    The five whole names it compares, each word of the display name, and the
    slug this protein shipped with -- which is not `lower(gene)` for most of
    them, and is the key every existing asset path is built from.
    """
    display = dart["display"]
    found = [
        (display, "display"),
        (target.gene, "gene"),
        (target.slug, "slug"),
        (target.uniprot, "uniprot"),
        (target.source.accession, "accession"),
    ]
    for word in re.split(r"[\s()\-]+", display):
        if word and word.lower() != display.lower():
            found.append((word, "word"))
    if target.slug != target.gene.lower():
        found.append((target.slug, "legacy_slug"))
    # One row per (alias, kind); the primary key would reject a repeat.
    return sorted({(alias, kind) for alias, kind in found if alias})


def protein_row(target: Target, dart: dict) -> dict:
    source = target.source
    structure = None
    if dart["chrome"] is not None:
        structure = {"chrome": dart["chrome"], "chains": dart["chains"]}

    return {
        "slug": target.slug,
        "gene": target.gene,
        "uniprot": target.uniprot,
        "accession": source.accession,
        "slice_start": source.seq_start,
        "slice_end": source.seq_stop,
        # A slice is always fetched plus-strand and re-based to 1; the record's
        # own strand is a fact about the gene, not about how it was cut.
        "slice_strand": 1 if source.seq_start is not None else None,
        "transcript_id": source.transcript_id,
        "protein_id": source.protein_id,
        "taxon_id": 9606,
        "display": dart["display"],
        "summary": dart["summary"],
        "chain_name": dart["chain"],
        "mature_peptides": target.mature_peptides,
        "residues": dart["facts"]["residues"],
        "exons": dart["facts"]["exons"],
        "chains": dart["facts"]["chains"],
        "bridges": dart["facts"]["bridges"],
        "regions": partition(target),
        "disulfides": [list(pair) for pair in target.disulfides],
        "structure": structure,
        "provenance": {
            # Written by a person, checked against the live entries by hand, and
            # recorded in docs/protein-verification.md. Nothing here was derived.
            "source": "targets.py + protein_catalog.dart",
            "prose": "hand",
            "uniprot_variants": [list(v) for v in target.uniprot_variants],
            "cleaved": target.cleaved,
        },
        "resolver_version": RESOLVER_VERSION,
        "catalog_order": dart["order"],
    }


def track_rows(target: Target, dart: dict) -> list[dict]:
    """The four booleans the app shipped with, as track states.

    Every one of the twenty is baked, so these all start `absent` with the
    object still in the app bundle -- the state flips to `ready` in the phase
    that uploads the bytes, not in this one. Seeding them `ready` now would
    name objects that are not there yet.
    """
    baked = {
        "constraint": target.scored,
        "impact": target.impact_scored,
        "clinvar": target.clinvar_available,
        "impact_explanations": dart["impact_explanations"],
        "structure": dart["chrome"] is not None,
    }
    rows = [{
        "slug": target.slug,
        "kind": "record",
        "state": "absent",
        "reason": None,
        "format": "json",
        "provenance": {"source": "NCBI Entrez", "accession": target.source.accession},
    }]
    for kind, is_baked in baked.items():
        rows.append({
            "slug": target.slug,
            "kind": kind,
            "state": "absent",
            "reason": None if is_baked else "Not included for this protein.",
            "format": "glb" if kind == "structure" else "json",
            "provenance": {},
        })
    return rows


# --- writing ----------------------------------------------------------------

_UPSERT_PROTEIN = """
insert into protein (
    slug, gene, uniprot, accession, slice_start, slice_end, slice_strand,
    transcript_id, protein_id, taxon_id, display, summary, chain_name,
    mature_peptides, residues, exons, chains, bridges,
    regions, disulfides, structure, provenance, resolver_version, catalog_order
) values (
    %(slug)s, %(gene)s, %(uniprot)s, %(accession)s, %(slice_start)s, %(slice_end)s,
    %(slice_strand)s, %(transcript_id)s, %(protein_id)s, %(taxon_id)s, %(display)s,
    %(summary)s, %(chain_name)s, %(mature_peptides)s, %(residues)s, %(exons)s,
    %(chains)s, %(bridges)s, %(regions)s, %(disulfides)s, %(structure)s,
    %(provenance)s, %(resolver_version)s, %(catalog_order)s
)
on conflict (slug) do update set
    gene = excluded.gene, uniprot = excluded.uniprot,
    accession = excluded.accession, slice_start = excluded.slice_start,
    slice_end = excluded.slice_end, slice_strand = excluded.slice_strand,
    transcript_id = excluded.transcript_id, protein_id = excluded.protein_id,
    display = excluded.display, summary = excluded.summary,
    chain_name = excluded.chain_name, mature_peptides = excluded.mature_peptides,
    residues = excluded.residues, exons = excluded.exons,
    chains = excluded.chains, bridges = excluded.bridges,
    regions = excluded.regions, disulfides = excluded.disulfides,
    structure = excluded.structure, provenance = excluded.provenance,
    resolver_version = excluded.resolver_version,
    catalog_order = excluded.catalog_order,
    resolved_at = now()
"""

_UPSERT_ALIAS = """
insert into protein_alias (slug, alias, kind) values (%s, %s, %s)
on conflict (slug, alias, kind) do nothing
"""

# Track rows are written only where there is not one already: this seeds the
# shape, and a later phase that has actually uploaded bytes owns the state.
_INSERT_TRACK = """
insert into protein_track (slug, kind, state, reason, format, provenance)
values (%(slug)s, %(kind)s, %(state)s, %(reason)s, %(format)s, %(provenance)s)
on conflict (slug, kind) do nothing
"""


def write(rows: list[tuple[dict, list[tuple[str, str]], list[dict]]], url: str) -> None:
    import psycopg
    from psycopg.types.json import Jsonb

    jsonb = ("regions", "disulfides", "structure", "provenance")
    with psycopg.connect(url) as conn:
        with conn.cursor() as cur:
            for protein, aliases, tracks in rows:
                payload = dict(protein)
                for key in jsonb:
                    payload[key] = Jsonb(payload[key]) if payload[key] is not None else None
                cur.execute(_UPSERT_PROTEIN, payload)
                cur.execute("delete from protein_alias where slug = %s", (protein["slug"],))
                for alias, kind in aliases:
                    cur.execute(_UPSERT_ALIAS, (protein["slug"], alias, kind))
                for track in tracks:
                    cur.execute(_INSERT_TRACK, {**track, "provenance": Jsonb(track["provenance"])})
        conn.commit()


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--dry-run", action="store_true",
                        help="print the rows as JSON and touch no database")
    parser.add_argument("--target", action="append", default=None,
                        help="one slug; repeatable. Default is every row.")
    args = parser.parse_args()

    dart = dart_rows()
    wanted = set(args.target) if args.target else None

    missing = [t.slug for t in TARGETS if t.slug not in dart]
    if missing:
        raise SystemExit(f"no protein_catalog.dart row for: {sorted(missing)}")
    extra = sorted(set(dart) - {t.slug for t in TARGETS})
    if extra:
        raise SystemExit(f"protein_catalog.dart rows with no targets.py row: {extra}")

    rows = []
    for target in TARGETS:
        if wanted and target.slug not in wanted:
            continue
        row = dart[target.slug]
        rows.append((protein_row(target, row), _aliases(target, row),
                     track_rows(target, row)))

    if args.dry_run:
        print(json.dumps(
            [{"protein": p, "aliases": [list(a) for a in al], "tracks": t}
             for p, al, t in rows],
            indent=2, sort_keys=True,
        ))
        print(f"\n{len(rows)} proteins, "
              f"{sum(len(a) for _, a, _ in rows)} aliases, "
              f"{sum(len(t) for _, _, t in rows)} track rows", file=sys.stderr)
        return 0

    url = os.environ.get("DATABASE_URL")
    if not url:
        raise SystemExit("DATABASE_URL is not set. Use --dry-run to see the rows.")
    write(rows, url)
    print(f"seeded {len(rows)} proteins", file=sys.stderr)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
