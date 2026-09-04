"""Parse every TUN- definition out of TUNABLES.md, mapping columns by header.

Three table shapes exist and position-based parsing silently mangles two of them:
  standard   ID | Value | Unit | Range | Rationale
  scoring    ID | Score event | Value | Unit | Range | Condition & rationale
  scaling    Tunable | 4 players | 5 players | 6 players | Rationale   <- NOT definitions
"""
import io, json, os, re, collections

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SRC = os.path.join(ROOT, "docs", "50_tuning", "TUNABLES.md")
OUT = os.path.join(os.path.dirname(__file__), "tunables.json")


def cells(line):
    return [c.strip() for c in line.strip().strip("|").split("|")]


def plain(cell):
    """A data cell with its markdown emphasis removed.

    **BOLDING A NUMBER USED TO DELETE THE TUNABLE.** `TUN-STUN-SCORE` and
    `TUN-SCORE-STUN` were written as `**200**` on 2026-09-03 to mark ADR-0018's
    change, and `gen_tuning.py`'s `^[+-]?\d` match then failed on the leading
    asterisk, so both fields were dropped from their classes. It printed the two ids
    on a `skipped:` line and exited 0 — and `scoring.stun` is read by invariant 19,
    so regenerating broke the build while reporting success.

    The rationale column has been stripped this way since M0 (`doc_lines`), so the
    pipeline already knew emphasis existed; it just cleaned one column of five.
    Stripped **here** rather than in each generator, because the failure was two
    consumers of one cell disagreeing about what the cell contains — and they
    disagree differently: `gen_abilities.py` calls `.group(1)` with no null check
    and would have raised instead.
    """
    return re.sub(r"\*\*|\*|`", "", cell).strip()


text = io.open(SRC, encoding="utf-8").read()
rows, scaling, section, subsection, header = [], [], "", "", None

for ln in text.split("\n"):
    m = re.match(r"^## (\d+)\. (.*)$", ln)
    if m:
        section, subsection, header = m.group(1), "", None
        continue
    m = re.match(r"^### ([\d.]+) (.*)$", ln)
    if m:
        subsection, header = m.group(2), None
        continue
    if not ln.startswith("|"):
        header = None
        continue
    c = cells(ln)
    if header is None:
        header = [h.lower() for h in c]
        continue
    if all(set(x) <= set("-: ") for x in c):     # the |---|---| separator
        continue
    if not c or not c[0].startswith("`TUN-"):
        continue

    def col(*names):
        for n in names:
            if n in header:
                i = header.index(n)
                if i < len(c):
                    return c[i]
        return ""

    tid = c[0].strip("` ")
    if "4 players" in header:                     # §16 scaling, not a definition
        scaling.append({"id": tid, "section": section, "cells": c})
        continue
    rows.append({
        "id": tid,
        "value": plain(col("value")),
        "unit": plain(col("unit")),
        "range": plain(col("range")),
        # The rationale keeps its markdown: it is prose, and `doc_lines` strips it
        # at the point it becomes a docstring.
        "rationale": col("rationale", "condition & rationale"),
        "score_event": plain(col("score event")),
        "section": int(section),
        "subsection": subsection,
    })

seen, dupes = {}, []
for r in rows:
    if r["id"] in seen:
        dupes.append(r["id"])
    seen[r["id"]] = r

print("definitions: %d unique (%d rows), duplicates: %s" % (len(seen), len(rows), dupes or "none"))
print("scaling-table rows skipped: %d  %s" % (len(scaling), [s["id"] for s in scaling]))
print("\nper section:", dict(sorted(collections.Counter(r["section"] for r in rows).items())))
print("\nunits:", dict(collections.Counter(r["unit"] for r in rows)))
print("\nno range:", sum(1 for r in rows if r["range"] in ("—", "-", "")))
bad = [r["id"] for r in rows if not r["rationale"] or not r["value"]]
print("rows missing value or rationale:", len(bad), bad[:5])

io.open(OUT, "w", encoding="utf-8").write(json.dumps(list(seen.values()), indent=1))
print("\nwrote tunables.json")
