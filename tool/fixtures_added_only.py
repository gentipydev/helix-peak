"""Hold test/fixtures to additions since <start>: a new curated protein only.

    python3 tool/fixtures_added_only.py <start>

The walk's tests read test/fixtures, so changing what is there is a walk-test
edit (CLAUDE.md). Adding a curated protein adds to it: its files, and its row
in catalog.json. This passes when that is all that changed since <start>:

- every file there at <start> is unchanged, but catalog.json;
- catalog.json keeps every row it had, unchanged, and its `next`; new rows
  take orders after the old ones;
- every added file is a new protein's: its slug, or its gene for a record.

Prints what breaks the rule and exits 1, or says what was added and exits 0.
"""

from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
FIXTURES = "test/fixtures"
CATALOG = f"{FIXTURES}/catalog.json"


def git(*args: str) -> str:
    return subprocess.run(["git", *args], cwd=ROOT, check=True, capture_output=True,
                          text=True).stdout


def owner(path: str) -> str:
    """The slug or gene an added fixture is named by."""
    name = Path(path).name
    if name.startswith("gene_"):
        return name[len("gene_"):].split(".")[0]
    for suffix in ("_esm_constraint.json", "_avi.json", "_clinvar.json"):
        if name.endswith(suffix):
            return name[: -len(suffix)]
    return name.split(".")[0]


def main(start: str) -> int:
    problems: list[str] = []
    changed = [line.split("\t") for line in
               git("diff", "--name-status", "-M", start, "--", FIXTURES).splitlines()]
    # Files git does not track yet are additions too.
    changed += [["A", path] for path in
                git("ls-files", "--others", "--exclude-standard", "--", FIXTURES).splitlines()]

    before = json.loads(git("show", f"{start}:{CATALOG}"))
    after = json.loads((ROOT / CATALOG).read_text())
    old = {row["slug"]: row for row in before["proteins"]}
    new = {row["slug"]: row for row in after["proteins"]}
    if after.get("next") != before.get("next"):
        problems.append(f"{CATALOG}: `next` changed")
    for slug, row in old.items():
        if new.get(slug) != row:
            problems.append(f"{CATALOG}: the row for {slug} changed or went")
    last = max(row["catalog_order"] for row in old.values())
    added = {slug: row for slug, row in new.items() if slug not in old}
    for slug, row in added.items():
        if row["catalog_order"] <= last:
            problems.append(f"{CATALOG}: {slug} takes order {row['catalog_order']}, "
                            f"among the old rows' (up to {last})")
    names = {slug for slug in added} | {row["gene"].lower() for row in added.values()}

    files = []
    for status, *paths in changed:
        path = paths[-1]
        if status == "M" and path == CATALOG:
            continue
        if status != "A":
            problems.append(f"{path}: {status} (only additions are allowed)")
        elif owner(path) not in names:
            problems.append(f"{path}: added, but names no new protein ({sorted(names)})")
        else:
            files.append(path)

    for problem in problems:
        print(problem)
    if problems:
        return 1
    print(f"test/fixtures since {start}: {len(added)} protein(s) added "
          f"({', '.join(sorted(added)) or 'none'}), {len(files)} file(s); nothing else changed")
    return 0


if __name__ == "__main__":
    if len(sys.argv) != 2:
        raise SystemExit(__doc__.strip())
    raise SystemExit(main(sys.argv[1]))
