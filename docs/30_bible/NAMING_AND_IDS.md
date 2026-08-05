---
id: BIBLE-NAMING-IDS
title: Naming and ID Grammar
version: 0.1.0
status: draft
owner: Documentation Architect
last_updated: 2026-08-03
depends_on: [DOC-GLOSSARY, DOC-IP-GUARDRAILS]
---

# Naming and ID Grammar

> **The rule that governs this whole document: an ID is immutable once merged.** IDs appear in
> documentation cross-references, test names, telemetry archives, `.tres` files, commit messages
> and the string table. Renaming one breaks all of them at once, and the breakage is silent in
> most of those places.
>
> If a name turns out to be wrong, **deprecate it and add a new one**. Never reuse a retired ID.

---

## 1. The namespaces

| Prefix | Namespace | Regex | Example |
|---|---|---|---|
| `SYS-` | Gameplay system | `^SYS-[A-Z][A-Z0-9]*(-[A-Z0-9]+)*$` | `SYS-COMPASS`, `SYS-NET-LAGCOMP` |
| `TUN-` | Tunable constant | `^TUN-[A-Z0-9]+(-[A-Z0-9]+)+$` | `TUN-SUSPICION-DECAY-BASE` |
| `INPUT-` | Player input action | `^INPUT-[A-Z]+(-[A-Z0-9]+)*$` | `INPUT-SLOW`, `INPUT-ABILITY-1` |
| `SCORE-` | Score event kind | `^SCORE-[A-Z]+$` | `SCORE-BLENDED` |
| `ABIL-` | Ability | `^ABIL-[A-Z]+$` | `ABIL-CINDERFALL` |
| `PASV-` | Passive | `^PASV-[A-Z]+$` | `PASV-STILLNESS` |
| `PERSONA-` | Playable persona | `^PERSONA-[A-Z]+$` | `PERSONA-VETRAIO` |
| `ARCH-` | NPC filler archetype | `^ARCH-[A-Z]+$` | `ARCH-PORTER` |
| `MAP-` | Map | `^MAP-[A-Z]+$` | `MAP-VETRAIO` |
| `LOC-` | Named location on a map | `^LOC-[A-Z]+$` | `LOC-PIAZZASECCA` |
| `NET-` | Network message | `^NET-(C2S\|S2C)-[A-Z]+(-[A-Z]+)*$` | `NET-S2C-PREY-WARNING` |
| `EVT-` | Event-bus signal | `^EVT-[A-Z]+(-[A-Z]+)*$` | `EVT-SUSPICION-TIER-CHANGED` |
| `SFX-` | Sound effect | `^SFX-[A-Z]+(-[A-Z]+)*$` | `SFX-STUN-SUCCESS` |
| `MUS-` | Music stem | `^MUS-[A-Z]+(-[A-Z]+)*$` | `MUS-STEM-EXPOSED` |
| `ANIM-` | Animation clip | `^ANIM-[A-Z]+(-[A-Z]+)*$` | `ANIM-BLENDWALK-LOOP` |
| `MAT-` | Material / surface | `^MAT-[A-Z]+(-[A-Z]+)*$` | `MAT-STONE`, `MAT-GREY-WALL` |
| `PROP-` | World prop | `^PROP-[A-Z]+$` | `PROP-HAYCART` |
| `TEL-` | Telemetry event | `^TEL-[A-Z]+(-[A-Z]+)*$` | `TEL-HUNT-DURATION` |
| `US-` | User story | `^US-\d{4}$` | `US-0042` |
| `ADR-` | Decision record | `^ADR-\d{4}$` | `ADR-0007` |
| `ASM-` | Logged assumption | `^ASM-\d{4}$` | `ASM-0030` |
| `RISK-` | Risk register entry | `^RISK-[A-Z]+(-[A-Z]+)*$` | `RISK-CROWD-PERF` |
| `DOC-` / `GDD-` / `TDD-` / `BIBLE-` | Document front-matter | — | `TDD-04-NET` |

`test_id_grammar.gd` validates every ID appearing in the corpus and the codebase against these
regexes.

> **`INPUT-` was registered late, in US-0016.** GDD-02 §1.2 and §1.3 had been naming fifteen
> `INPUT-` IDs since the first draft, but this table never listed the prefix — so the scanner
> never harvested them, the grammar never checked them, and `Ids` never mirrored them. They read
> as IDs everywhere they appeared while being, mechanically, prose. Registering the namespace is
> what makes the input map checkable against the design instead of merely consistent with it.

---

## 2. Immutability

### 2.1 The rule

**Once an ID appears in a commit on `main`, it never changes.** Not its spelling, not its
casing, not its hyphenation.

### 2.2 Why it is stricter than it looks

An ID is referenced in places where a rename fails silently:

| Place | Failure mode on rename |
|---|---|
| Documentation cross-references | Broken link, or worse, a link to nothing that still renders |
| Test names (`test_compass_curve.gd`) | Test still passes, now testing the wrong thing |
| Archived telemetry | Historical data becomes uninterpretable; `TEL-MATCH-START` records a tuning hash for exactly this reason |
| `.tres` files | Silent property loss on load |
| String-table keys | Missing string at runtime, in a language nobody on the team reads |
| Commit messages and ADRs | Historical record becomes wrong |

### 2.3 Deprecating instead

```markdown
### TUN-SUSPICION-GAIN-WALK  — DEPRECATED 2026-09-14, superseded by TUN-SUSPICION-GAIN-JOG
Retained so historical telemetry and ADR-0014 remain interpretable. Not read by any code.
```

The retired ID stays in TUNABLES.md with a deprecation note. It is never deleted and never
reused.

---

## 3. `TUN-` — the strictest namespace

Because tunables have a **mechanical mapping to code** (ADR-0005), their grammar is tighter.

```
TUN-<DOMAIN>-<NAME>
    │        └── one or more UPPERCASE segments, hyphenated
    └── one of: SPEED TRAVERSE FEEL SUSPICION BLEND COMPASS KILL STUN
                CONTRACT RESPAWN SPAWN ABILITY CINDERFALL WHISPERBOLT
                SECONDFACE LUNGE PASV CROWD CORPSE LOBBY MATCH SCORE
                CAM NET PERF UI AUDIO
```

### 3.1 The field mapping

`TUN-<DOMAIN>-<NAME>` → `<Domain>Tuning.<name_lowercased_underscored>`

| ID | Resource | Field |
|---|---|---|
| `TUN-SUSPICION-DECAY-BASE` | `SuspicionTuning` | `decay_base` |
| `TUN-COMPASS-PULSE-EXP` | `CompassTuning` | `pulse_exp` |
| `TUN-KILL-CONTEST-WINDOW` | `CombatTuning` | `kill_contest_window` |
| `TUN-CINDERFALL-COOLDOWN` | `AbilityData` (cinderfall) | `cooldown` |

**No judgement, no exceptions.** The mapping is a pure string transform in both directions, which
is what makes `test_tuning_docs_sync.gd` possible: a missing field or an undocumented ID is
mechanically detectable. Every deviation would need a lookup table, and a lookup table is a place
for the two to silently disagree.

### 3.2 Domain grouping ≠ resource grouping

Ability-specific domains (`CINDERFALL`, `WHISPERBOLT`, `SECONDFACE`, `LUNGE`) map to fields on
that ability's `AbilityData` rather than to a `<Domain>Tuning` class. This is the one documented
exception, and `tuning_docs_sync.gd` knows about it explicitly.

---

## 4. `NET-` — direction is part of the ID

```
NET-C2S-INPUT          client -> server
NET-S2C-SNAPSHOT       server -> client
```

**There is no bidirectional message.** If something needs to flow both ways, it is two messages
with two IDs, because the authority check differs in each direction and a shared ID would hide
that.

---

## 5. Code naming

### 5.1 Files

| Kind | Convention | Example |
|---|---|---|
| Script | `snake_case.gd`, matching its `class_name` | `SuspicionSystem` → `suspicion_system.gd` |
| Scene | `snake_case.tscn`, matching its root node | `PawnServer` → `pawn_server.tscn` |
| Resource | `snake_case.tres`, matching what it configures | `cinderfall.tres` |
| Test | subject's path, `test_` prefixed | `scripts/core/math/suspicion_math.gd` → `test/unit/core/math/test_suspicion_math.gd` |
| Pawn state | `state_<name>.gd` | `state_blend_walk.gd` |
| NPC state | `npc_state_<name>.gd` | `npc_state_startle.gd` |
| Ability effect | `<name>_effect.gd` | `cinderfall_effect.gd` |
| Widget | `<name>_widget.gd` + `<name>_vm.gd` | `compass_widget.gd`, `compass_vm.gd` |

### 5.2 Identifiers

| Kind | Convention |
|---|---|
| Class | `PascalCase` |
| Function, variable | `snake_case` |
| Private | `_snake_case` |
| Constant | `SCREAMING_SNAKE_CASE` |
| Enum type | `PascalCase`; values `SCREAMING_SNAKE_CASE` |
| Signal | `past_tense_fact` |
| Node in a scene | `PascalCase`, matching its script's `class_name` where one exists |

### 5.3 Banned identifier names

| Banned | Reason | Instead |
|---|---|---|
| `utils`, `helpers`, `common`, `misc`, `shared`, `stuff` | Unnamed grab-bags never shrink | A named static class: `SuspicionMath`, `CompassMath`, `Locomotion` |
| `manager`, `handler`, `controller` (alone) | Says nothing about responsibility | Name the responsibility: `CrowdDirector`, `RpcRouter`, `MatchDirector` |
| `data`, `info`, `obj`, `temp`, `tmp` as variable names | Says nothing | Name the thing |
| `flag`, `check`, `do_thing` | Same | |

`test_no_utils_files.gd` enforces the file-level cases.

---

## 6. In-fiction naming

Governed by [`../00_meta/IP_GUARDRAILS.md`](../00_meta/IP_GUARDRAILS.md). The two rules that
matter most day to day:

1. **Functional-original.** A player who has never seen the name should be able to guess roughly
   what it does, and a lawyer should not find it in another company's register. **Cinderfall**,
   not "Smoke Bomb"; **Whisperbolt**, not "Throwing Knife".
2. **Original name first, always.** Write "**Cinderfall** — an area-denial ability", never "the
   smoke ability, which we're calling Cinderfall". If the team's internal shorthand stays "the
   smoke bomb", it will reach a screenshot eventually.

Every in-fiction name is registered in [`../00_meta/GLOSSARY.md`](../00_meta/GLOSSARY.md) with
its ID. **A name that is not in the glossary is not a name yet — it is a placeholder, and
placeholders may not be committed.**

---

## 7. The registry

Canonical list in [`../00_meta/GLOSSARY.md`](../00_meta/GLOSSARY.md) Appendix A, mirrored in code
as `scripts/core/ids.gd`. `test_ids_match_glossary.gd` asserts the two agree in both directions.

---

## 8. Adding an ID

1. Check it does not collide with a retired one (search the corpus, including deprecated rows).
2. Validate against the §1 regex.
3. Add it to `GLOSSARY.md` Appendix A **and** `scripts/core/ids.gd`, same commit.
4. For a `TUN-`: add the row to TUNABLES.md with value, unit, range and rationale, **and** the
   `@export` with a matching `@export_range` and the ID as its docstring's last token.
5. For a `NET-`: add it to `NETWORK_PROTOCOL.md` with direction, reliability, rate, payload and
   **a non-empty authority check** if it is C2S.
6. For an `EVT-`: add it to `SIGNAL_AND_EVENT_BUS.md` with its payload schema.
7. For a `SFX-`: add it to `AUDIO_BIBLE.md` with bus, diegetic flag, caption flag and radius.
8. Run `test_id_grammar.gd` and `test_ids_match_glossary.gd`.

---

## 9. Acceptance criteria

- [ ] `test_id_grammar.gd` validates every ID in the corpus and the codebase.
- [ ] `test_ids_match_glossary.gd` passes bidirectionally.
- [ ] `test_tuning_docs_sync.gd` passes bidirectionally.
- [ ] `test_file_naming.gd` asserts file ↔ `class_name` agreement.
- [ ] `test_signal_naming.gd` asserts past-tense, no `on_` prefix, no `_signal` suffix.
- [ ] `test_no_utils_files.gd` passes.
- [ ] No ID present on `main` has ever been renamed; deprecated IDs are retained with a note.
