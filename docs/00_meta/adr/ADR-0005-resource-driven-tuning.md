---
id: ADR-0005
title: Resource-driven tuning; no hardcoded gameplay constants
version: 1.0.0
status: accepted
owner: Technical Director
last_updated: 2026-08-03
depends_on: [ADR-0001, TUN-INDEX]
supersedes: none
---

# ADR-0005 — Resource-driven tuning; no hardcoded gameplay constants

## Context

Project Sottovoce has roughly 180 gameplay constants, catalogued in
[`../../50_tuning/TUNABLES.md`](../../50_tuning/TUNABLES.md). Its central design claim —
"a patient player should win about 60 % of even matches" — is a *quantitative* claim that
can only be validated by playing, measuring, adjusting and playing again.

Three forces:

1. **The balance loop is the project's main risk-reduction activity.** Anything that adds
   friction between "I have a hypothesis about `TUN-SUSPICION-GAIN-SPRINT`" and "six people
   are playing with the new value" directly reduces how many hypotheses get tested.
2. **The team includes an AI agent as an implementer.** An agent that can write
   `var decay := 8.0` anywhere will, eventually, write it in two places with two values.
   The resulting bug — suspicion decaying at different rates in two code paths — is nearly
   invisible in review and extremely confusing in play.
3. **The documentation corpus is only useful if it is true.** A `TUN-` ID in a design
   document that does not correspond to anything in the running game is worse than no
   documentation, because it is *confidently* wrong.

## Options considered

| Option | Pros | Cons | Verdict |
|---|---|---|---|
| **Typed `Resource` (`.tres`) tuning profiles, loaded at boot, server-authoritative** | Editable in the Godot inspector with type checking and ranges; diffable text; hot-reloadable; naturally server-replicable; maps 1:1 onto TUNABLES.md sections. | Adds an indirection to every constant read; requires discipline to maintain. | **Chosen** |
| `const` at the top of each script | Zero indirection; fast. | Values scattered across ~40 files; no single source of truth; no runtime change; the exact failure mode described in force 2. | Rejected |
| One giant autoload of constants | Single location; simple. | Not inspector-editable; not diffable per-domain; no type/range validation; becomes a 400-line file that violates the file-length rule. | Rejected |
| JSON/CSV config loaded at runtime | Human-editable outside the editor; hot-reload trivial. | No type checking, no inspector, no autocomplete; typos become runtime nulls; loses everything the engine gives us for free. | Rejected |
| ProjectSettings custom properties | Built-in; editable in-editor. | Flat namespace, weak typing, awkward to replicate, and pollutes a settings surface meant for engine config. | Rejected |

## Decision

**Every gameplay constant lives in a typed `Resource` sub-profile of a `TuningProfile`.
No gameplay constant may appear as a literal in a script.**

```gdscript
class_name SuspicionTuning
extends Resource

## Suspicion decayed per second while at or below decay_speed_ceiling. TUN-SUSPICION-DECAY-BASE
@export_range(6.0, 12.0, 0.1) var decay_base: float = 8.0

## Speed at or below which decay applies. Must equal MovementTuning.stroll. TUN-SUSPICION-DECAY-SPEED-CEILING
@export_range(1.0, 4.0, 0.1) var decay_speed_ceiling: float = 2.2

## Suspicion gained per second while sprinting. TUN-SUSPICION-GAIN-SPRINT
@export_range(20.0, 32.0, 0.5) var gain_sprint: float = 25.0
# ...
```

Rules:

1. **Field naming is mechanical**: `TUN-<DOMAIN>-<NAME>` → `<Domain>Tuning.<name_lowercased>`.
   `TUN-SUSPICION-DECAY-BASE` → `SuspicionTuning.decay_base`. No judgement, no exceptions.
2. **Every `@export` carries `@export_range` matching the Range column** in TUNABLES.md, and
   a docstring ending in the `TUN-` ID. The ID in the docstring is what the docs-sync check
   greps for.
3. **`Tuning` is an autoload** exposing the loaded profile. Systems read
   `Tuning.suspicion.decay_base`. Nothing else caches these values across ticks except where
   a profiler says otherwise, and then with a comment saying so.
4. **Server-authoritative.** At match start the server sends its profile hash; a client with
   a different hash is sent the full profile and adopts it (`NET-S2C-TUNING-SYNC`). A
   mismatch is corrected, not kicked — it is far more often a stale build than an attack,
   and kicking makes that diagnosis harder.
5. **Hot reload.** In debug builds, `Tuning.reload()` re-reads the `.tres` files and emits
   `EVT-TUNING-RELOADED`. Systems that cached anything must listen. On the server this
   propagates to clients, so a single keypress re-tunes a live 3-client playtest — this is
   the whole point of the ADR.
6. **A local override directory** (`data/tuning/local/`, gitignored) may shadow the default
   profile for solo experimentation. It is refused by the server if any client tries to use
   it in a networked match, by hash comparison.

### What is *not* a tunable

Constants that are not gameplay may be literals:

- Layer/mask indices, node paths, string-table keys.
- Buffer sizes and container capacities that have no play-affecting consequence.
- Mathematical constants and unit conversions.

The test: *if changing this number would change how the game plays or feels, it is a
tunable.* If in doubt, make it a tunable — the cost is one line.

## Consequences

### Positive
- A balance change is a `.tres` edit plus a keypress, not a rebuild. In a live playtest this
  turns "we should try 20 instead of 25" from a next-session task into a next-round task.
- `@export_range` gives free validation in the inspector, and `test_tuning_ranges.gd`
  asserts it at load — including the 20 cross-field invariants in TUNABLES.md §17.
- The docs-sync check can mechanically verify that every `TUN-` ID in TUNABLES.md has a
  corresponding exported field and vice versa. This is the primary defence against
  `RISK-AGENT-DRIFT`.
- Replication of the whole tuning state is one resource, so "are we playing the same game?"
  is one hash comparison.

### Negative — stated honestly
- **Every constant read is a property lookup through an autoload.** In the crowd's inner
  loop this is measurable. Mitigation: the crowd steering layer caches its handful of values
  at LOD-transition time, with a comment naming this ADR. That is a deliberate, documented
  exception, and the only one permitted without a new ADR.
- Adding a tunable touches three places (the doc, the resource class, the `.tres`). This
  friction is intentional — it makes people think before inventing a number — but it is
  friction.
- Hot reload can leave a system in an inconsistent state if it holds derived values. Every
  system that derives from tuning must handle `EVT-TUNING-RELOADED`, and forgetting to do so
  produces a subtle bug. Listed in the Definition of Done checklist.
- `.tres` files diff poorly when the inspector reorders properties. Mitigated by never
  reordering exported properties in a resource class once merged.

### Neutral / follow-on
- Tuning profiles are versioned with the project; a saved telemetry log records the profile
  hash, so a match's data can always be interpreted against the values in force at the time.

## Compliance

- [ ] `gdlint` custom rule (or a CI grep) finds no bare float/int literal in files under
      `scripts/systems/` and `scripts/pawn/`, excluding 0, 1, -1 and array indices.
- [ ] Every `TUN-` ID in TUNABLES.md appears in exactly one `@export` docstring.
- [ ] Every `@export` in a `*Tuning` class has a `TUN-` ID in its docstring.
- [ ] Every `@export` numeric field has an `@export_range` matching the doc's Range column.
- [ ] `test_tuning_ranges.gd` passes, including all §17 cross-field invariants.
- [ ] `test_tuning_docs_sync.gd` passes — the bidirectional ID check above, run in CI.
- [ ] `data/tuning/local/` is in `.gitignore`.

## Revisit trigger

Reopen if profiling shows autoload property access in the crowd or suspicion inner loops
costs more than 0.2 ms/frame at `TUN-CROWD-COUNT-MAX` — in which case the fix is a
per-system cached struct refreshed on `EVT-TUNING-RELOADED`, not abandoning the ADR.
