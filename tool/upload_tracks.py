"""Upload baked track assets to Supabase storage and record where they landed.

    DATABASE_URL=... SUPABASE_URL=... SUPABASE_SERVICE_KEY=... \
        python3 tool/upload_tracks.py --kind impact_explanations
    python3 tool/upload_tracks.py --kind impact_explanations --dry-run

One family at a time, because each is validated differently and each is worth
watching land on its own. The bytes go to a public bucket the client fetches
directly; this writes the `protein_track` row that names them.

**Stored plain, never pre-gzipped.** Measured 2026-09-24: Supabase's CDN
compresses in transit whenever the client sends `Accept-Encoding: gzip`, on
files of any size -- dystrophin's 9,563,683-byte ClinVar snapshot goes over the
wire in 572,718 bytes, within 0.7% of our own `gzip -9`. Storing a `.gz` makes
the CDN gzip an already gzipped payload and forces the client to decompress
twice for nothing.

**Paths carry the digest**: `<kind>/<slug>.<sha12>.json`. The client is handed
the URL out of the track row and never builds it, so the path is free to change
with the content -- which is what makes `cache-control: immutable` true rather
than merely convenient. A rebake writes a new object and the superseded one is
deleted once its row no longer points at it.

**Validated before it is written**, the same order `record_cache` uses: a
payload that would fail on the way out never becomes a row that says `ready`.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import sys
import urllib.error
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tool"))

from targets import TARGETS  # noqa: E402
from impact.check_explanations import validate as validate_explanations  # noqa: E402

# A year, and immutable: the digest is in the path, so these bytes never change.
CACHE_CONTROL = "public, max-age=31536000, immutable"


def asset_of(kind: str, target) -> Path | None:
    """The local file for this kind, or None where this protein has none."""
    if kind == "impact_explanations":
        return ROOT / f"assets/impact_explanations/{target.slug}.json"
    if kind == "constraint":
        return ROOT / target.constraint_asset if target.scored else None
    if kind == "impact":
        return ROOT / target.impact_asset if target.impact_scored else None
    if kind == "clinvar":
        path = ROOT / f"assets/clinvar/{target.slug}_clinvar.json"
        return path if target.clinvar_available else None
    if kind == "structure":
        return ROOT / target.structure_asset
    raise SystemExit(f"unknown kind {kind!r}")


def validate(kind: str, target, payload: bytes) -> dict:
    """Check the payload and return what its provenance should say.

    Raises ValueError with a reason. Nothing that raises here is uploaded, so a
    malformed asset cannot become a row that claims to be ready.
    """
    if kind == "structure":
        if payload[:4] != b"glTF":
            raise ValueError("not a .glb")
        return {"pdb": target.structure.pdb,
                "nodes": [c.node for c in target.structure.chains]}

    data = json.loads(payload)
    if not isinstance(data, dict):
        raise ValueError("payload is not an object")

    if kind == "impact_explanations":
        impact = (ROOT / target.impact_asset).read_bytes()
        # The same check the endpoint used to make on every read, made once on
        # the way in: scorer, schema version, and the digest binding this
        # payload to the exact AVI track it explains.
        validate_explanations(impact, data)
        if data.get("accession") != target.source.accession or data.get("gene") != target.gene:
            raise ValueError("accession/gene do not match the target")
        return {key: data.get(key) for key in
                ("scorer", "units", "scope", "selection", "schema_version",
                 "generated_at", "client_version", "impact_sha256")}

    if kind == "constraint":
        if data.get("gene") != target.gene:
            raise ValueError(f"gene is {data.get('gene')!r}, expected {target.gene!r}")
        return {key: data.get(key) for key in
                ("model", "revision", "method", "normalization", "score_units",
                 "entropy_vocabulary", "vocabulary_size", "context")}

    if kind == "impact":
        if data.get("gene") != target.gene:
            raise ValueError(f"gene is {data.get('gene')!r}, expected {target.gene!r}")
        return {key: data.get(key) for key in
                ("scorer", "score_units", "assembly", "annotation", "chromosome",
                 "transcript", "orientation", "complemented")}

    if kind == "clinvar":
        if data.get("gene") != target.gene:
            raise ValueError(f"gene is {data.get('gene')!r}, expected {target.gene!r}")
        return {key: data.get(key) for key in
                ("source", "schema_version", "assembly", "scope", "retrieved_at",
                 "searched_records", "excluded")}

    raise SystemExit(f"unknown kind {kind!r}")


class Storage:
    def __init__(self, url: str, key: str):
        self.base = url.rstrip("/") + "/storage/v1"
        self.headers = {"Authorization": f"Bearer {key}", "apikey": key}

    def put(self, bucket: str, path: str, payload: bytes, content_type: str) -> None:
        request = urllib.request.Request(
            f"{self.base}/object/{bucket}/{path}", method="POST", data=payload,
            headers={**self.headers, "Content-Type": content_type,
                     "Cache-Control": CACHE_CONTROL, "x-upsert": "true"})
        with urllib.request.urlopen(request, timeout=300):
            return

    def delete(self, bucket: str, paths: list[str]) -> None:
        if not paths:
            return
        request = urllib.request.Request(
            f"{self.base}/object/{bucket}", method="DELETE",
            data=json.dumps({"prefixes": paths}).encode(),
            headers={**self.headers, "Content-Type": "application/json"})
        try:
            with urllib.request.urlopen(request, timeout=120):
                return
        except urllib.error.HTTPError as exc:
            print(f"  could not delete {paths}: {exc.code}", file=sys.stderr)


_UPSERT = """
insert into protein_track
    (slug, kind, state, reason, bucket, object_path, bytes, sha256,
     content_encoding, format, provenance, updated_at)
values (%(slug)s, %(kind)s, 'ready', null, %(bucket)s, %(object_path)s, %(bytes)s,
        %(sha256)s, null, %(format)s, %(provenance)s, now())
on conflict (slug, kind) do update set
    state = 'ready', reason = null, bucket = excluded.bucket,
    object_path = excluded.object_path, bytes = excluded.bytes,
    sha256 = excluded.sha256, content_encoding = null,
    format = excluded.format, provenance = excluded.provenance,
    updated_at = now()
"""


def main() -> int:
    parser = argparse.ArgumentParser(description="Upload baked tracks to Supabase.")
    parser.add_argument("--kind", required=True, choices=[
        "impact_explanations", "constraint", "impact", "clinvar", "structure"])
    parser.add_argument("--target", action="append", default=None)
    parser.add_argument("--dry-run", action="store_true")
    arguments = parser.parse_args()

    kind = arguments.kind
    wanted = set(arguments.target) if arguments.target else None
    bucket = "models" if kind == "structure" else "tracks"
    suffix = "glb" if kind == "structure" else "json"
    content_type = "model/gltf-binary" if kind == "structure" else "application/json"

    planned = []
    for target in TARGETS:
        if wanted and target.slug not in wanted:
            continue
        path = asset_of(kind, target)
        if path is None or not path.exists():
            continue
        payload = path.read_bytes()
        try:
            provenance = validate(kind, target, payload)
        except (ValueError, KeyError) as exc:
            print(f"  {target.slug}: REFUSED -- {exc}", file=sys.stderr)
            continue
        digest = hashlib.sha256(payload).hexdigest()
        planned.append({
            "slug": target.slug, "kind": kind, "bucket": bucket,
            "object_path": f"{kind}/{target.slug}.{digest[:12]}.{suffix}",
            "bytes": len(payload), "sha256": digest, "format": suffix,
            "provenance": provenance, "_payload": payload,
        })

    total = sum(row["bytes"] for row in planned)
    for row in planned:
        print(f"  {row['slug']:<16} {row['bytes']:>10,} B  {row['object_path']}")
    print(f"\n{len(planned)} object(s), {total / 1e6:.2f} MB", file=sys.stderr)
    if arguments.dry_run:
        return 0

    url, key = os.environ.get("SUPABASE_URL"), os.environ.get("SUPABASE_SERVICE_KEY")
    database = os.environ.get("DATABASE_URL")
    if not (url and key and database):
        raise SystemExit("SUPABASE_URL, SUPABASE_SERVICE_KEY and DATABASE_URL must be set.")

    import psycopg
    from psycopg.types.json import Jsonb

    storage = Storage(url, key)
    superseded = []
    with psycopg.connect(database) as conn:
        with conn.cursor() as cur:
            for row in planned:
                old = cur.execute(
                    "select bucket, object_path from protein_track "
                    "where slug = %s and kind = %s and state = 'ready'",
                    (row["slug"], row["kind"])).fetchone()
                storage.put(bucket, row["object_path"], row.pop("_payload"), content_type)
                cur.execute(_UPSERT, {**row, "provenance": Jsonb(row["provenance"])})
                if old and old[1] != row["object_path"]:
                    superseded.append(old[1])
                print(f"  uploaded {row['slug']}", file=sys.stderr)
        conn.commit()

    # Only after the rows point elsewhere: nothing is deleted while it is still
    # what a client would be told to fetch.
    storage.delete(bucket, superseded)
    if superseded:
        print(f"  removed {len(superseded)} superseded object(s)", file=sys.stderr)
    print(f"{len(planned)} {kind} track(s) ready", file=sys.stderr)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
