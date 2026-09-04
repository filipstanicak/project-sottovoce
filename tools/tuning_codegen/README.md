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
| `gen_abilities.py` | `tunables.json` | `ability_tuning.gd`, `ability_data.gd`, `ability_defaults.gd`, `abilitymap.json` |
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

**MARKDOWN EMPHASIS IN A VALUE CELL DELETED THE TUNABLE, SILENTLY.** ADR-0018
wrote `TUN-STUN-SCORE`'s new value as `**200**` to mark that it had changed. The
parser's `^[+-]?\d` match fails on the two asterisks, so the row was **dropped**,
`combat_tuning.gd` kept the pre-ADR `100`, and regenerating on a clean checkout
produced a different file from the committed one — deleting `combat.score` and
`scoring.stun`, which `tuning_invariants_score.gd` reads for invariant 19. **The
guard written to catch exactly this drift was defeated by the same two
asterisks**: `test_tunables_match_the_document.gd` walked past the cell for the
same reason and dropped the row too. Both strip emphasis now, and `gen_tuning.py`
**refuses to write anything at all** if a documented value it was asked for cannot
be read — a codegen that silently emits less than it was given is worse than one
that stops.

**THE `.tres` WRITER USED TO CARRY THE ABILITY NUMBERS BY HAND, AND THIS README
TOLD YOU TO RUN IT.** `AbilityData` is one class holding four abilities' fields,
so a class default cannot carry a per-ability value — `duration` is 6 s of smoke
for Cinderfall and 15 s of a false face for Second Face. Every other section's
`.tres` is written from its own class's defaults; the abilities had nowhere to
read one from, so `generate_default_tuning.gd` held a **fourth copy of 45
numbers**. It had drifted: the command four lines above reverted
`TUN-CINDERFALL-THROW-RANGE` 0.0 → 8.0 (undoing ADR-0013), dropped
`TUN-CINDERFALL-DURATION` 6.0, and dropped `effect_script` from `cinderfall.tres`
and `lunge.tres`, which makes both abilities do nothing. **From a run that printed
success.** `gen_abilities.py` emits `ability_defaults.gd` now and the writer reads
it; what stays hand-written there is the wiring — an id, a display key, a tell
sound, the effect script — and `test_the_ability_writer_holds_no_tunables.gd`
refuses a fifth field with a `TUN-` id behind it.

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

**CHECK THE `.tres` TOO, WHICH NOBODY WAS DOING.** The step above stops at
`scripts/`, so the data the game actually loads was outside the verification for
four milestones — which is how the ability table drifted unnoticed:

```bash
godot --headless -s res://tools/generate_default_tuning.gd && git diff --stat data/tuning/
```

The `.tres` are byte-reproducible: Godot derives its `ext_resource` ids from
content rather than randomly, so unlike a `.tscn` they need no id stripping.
Hand-typed ids are therefore the signature of a hand-edit — `cinderfall.tres`
carried `id="2_cndrf"` and `lunge.tres` `id="2_lunge"`, which is how US-0067's
hand patch was identified.

**A `-s` SCRIPT CANNOT CHECK INVARIANT 33 AND SAYS SO IN THE OUTPUT.** Both this
generator and the `Tuning` autoload report *"Nonexistent function
'full_ring_distance' in base 'GDScript'"* on every run — a static call on a
`class_name` made while the global class registry is still being built. **It is
pre-existing, it is not a tuning defect, and it means `validate()` reports 36 of
the 37 invariants here.** Invariant 33 is checked by the unit suite, which boots
normally. Reported rather than fixed: it is one line of the invariant file and
belongs to whoever owns `CompassMath`, not to a codegen story.

## The other generator

`tools/generate_map_vetraio.gd` builds `scenes/map/*.tscn` and
`data/maps/map_vetraio.tres` from `scripts/core/vetraio_layout.gd` by the same
principle. It runs *in the engine*, because the scenes must be written by Godot's
own serialiser:

```bash
godot --headless -s res://tools/generate_map_vetraio.gd
```

It strips the random `unique_id` Godot stamps on every node, without which
re-running produces a 300-line diff in which nothing changed — and
"regenerate, then check `git diff` is empty" stops being a verification.
