# Tuning code generation

`scripts/core/ids.gd`, the fourteen `*Tuning` classes, `ability_data.gd` and
`tuning_index.gd` are **generated from `docs/50_tuning/TUNABLES.md`**, then
committed.

## Why generated

269 numbers, each with a range, a unit and a one-line rationale, cannot be
hand-copied reliably, and nothing in the build would catch a single wrong digit.
Generating them means **the only way to change a shipped value is to change
TUNABLES.md**, which is exactly the property ADR-0005 is for.

Generating also caught three defects in TUNABLES.md that reading had not: a
phantom `TUN-CROWD-COUNT` with no definition row, a malformed row in the §11
scoring table whose cells were all shifted one left, and a documented count that
was wrong by 47 %.

## Running it

```bash
python tools/tuning_codegen/run_all.py
gdformat scripts/                       # the generators do not format
godot --headless --editor --quit-after 200
godot --headless -s res://tools/generate_default_tuning.gd
```

**Generate, then `gdformat`, then regenerate the `.tres`.** The generators emit
correct but unformatted GDScript; `gdformat` is the normaliser, and the committed
files are post-format. Skipping it produces a diff that is pure whitespace.

`generate_default_tuning.gd` is separate and runs *in the engine*, because the
`.tres` files must be written by Godot's own serialiser rather than by a Python
script guessing at the format.

## The pipeline

| Step | Reads | Writes |
|---|---|---|
| `parse_tunables.py` | `TUNABLES.md` | `tunables.json` |
| `extract_ids.py` | `docs/**/*.md` | `ids.json` |
| `map_fields.py` | `tunables.json`, `DATA_SCHEMA.md` | `fieldmap.json` |
| `gen_ids.py` | `ids.json` | `scripts/core/ids.gd` |
| `gen_tuning.py` | `tunables.json`, `fieldmap.json` | the twelve section classes |
| `gen_abilities.py` | `tunables.json` | `ability_tuning.gd`, `ability_data.gd`, `abilitymap.json` |
| `gen_index.py` | all three maps | `tuning_index.gd` |

The `.json` files are intermediates, gitignored, and regenerated every run.

## Things that will bite you

**`parse_tunables.py` maps columns by header, not position.** TUNABLES has three
table shapes — the standard five-column one, §11's six-column scoring table, and
§16's player-count table, which is not a definition table at all. Position-based
parsing silently mangles two of them, which is how the malformed §11 row survived
review.

**`map_fields.py` searches a class's own sections first.** It did not originally,
and `MatchTuning.duration` was populated from `TUN-CINDERFALL-DURATION` — a 4-second
smoke cloud shipped as the match length — because §8 precedes §10 in document
order. The correct value survived under the redundant name `match_duration`, so
nothing looked missing.

**`gen_index.py` asserts key uniqueness.** That assertion is what found the bug
above. Do not remove it.

**Field naming is mechanical with four enumerated exceptions**, listed in
`DATA_SCHEMA.md` §1 and mirrored in `map_fields.py`. Adding a fifth needs a row in
that table.

## Verifying

The generators must reproduce the committed tree exactly:

```bash
python tools/tuning_codegen/run_all.py && gdformat scripts/ && git diff --stat scripts/
```

An empty diff is the check. A non-empty one means either TUNABLES.md changed or
someone hand-edited a generated file — and hand-editing a generated file is a
change that the next run silently reverts.
