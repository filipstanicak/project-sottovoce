---
id: US-0016
title: Input map, InputCommand and buffering
version: 1.0.0
status: done
owner: Technical Director
last_updated: 2026-08-05
depends_on: [GDD-02-PLAYER, TDD-03-TICK, TDD-06-PAWN]
---

# US-0016 — Input map, InputCommand and buffering

| | |
|---|---|
| **Milestone** | M1 |
| **Epic** | `EPIC-PAWN-STATES` |
| **Systems** | `SYS-INPUT` |
| **Estimate** | M |
| **Depends on** | US-0015 |

## Description

The full input map for keyboard and gamepad, the InputCommand struct, and the action buffer.

The action buffer must live inside PawnContext and inside step(), because it changes the
simulation result. A client-only buffer would mean predicting a vault the server never performed.

## Acceptance criteria

- [x] Every action from GDD-02 sections 1.2 and 1.3 is bound and rebindable.
- [x] INPUT-KILL and INPUT-STUN cannot share a binding; the UI refuses it.
- [x] InputCommand has the fixed layout from TDD-03 section 5.
- [x] client_tick is present but marked advisory-only in its docstring.
- [x] Action buffering forgives an input pressed up to 0.20 s early.
- [x] Hold and toggle modes for every hold input.
- [x] Sprint requires double-tap or a 0.4 s sustained hold on both KBM and pad.

**"The UI refuses it" is met at the API, not on a screen.** `InputRebinder.rebind()` returns
false and changes nothing, and `conflicts_for()` returns the names for the message. There is no
options screen until M5 (US-0083/84), and building one here would be a UI story in a pawn
milestone.

## Test notes

`test_cli_args.gd` for flags; manual verification for rebinding.

## Notes

Sprint friction is deliberate and is the only intentional friction in the scheme. An input
entered accidentally would spend the suspicion budget without the player deciding to.

---

## What this story actually found

### 1. Every duration counted inside `step()` was running at half length

`Tuning.ticks()` converts seconds at the **30 Hz net tick**. `ctx.state_timer_ticks` and the
action buffers advance once per `PawnState.step()`, which runs at **60 Hz** — TDD-03 §1.1 is
explicit that pawn integration substeps twice per net tick. Comparing one against the other
halves the window.

Merged, green, and wrong since US-0013:

| | Tuned | Actual | Shipped in |
|---|---|---|---|
| `TUN-STUN-FREEZE` | 2.0 s | 1.0 s | US-0013 |
| `TUN-KILL-ANIM-DURATION` | 1.4 s | 0.7 s | US-0013 |
| `TUN-KILL-CORPSE-SPAWN-DELAY` | — | half | US-0013 |
| `TUN-SPEED-RUN-HOLD` | 0.35 s | 0.18 s | US-0015 |

The stun one matters most: **design law 5 forbids weakening stun**, and the code had halved it
without anyone deciding to. Nothing failed, because both numbers are plausible integers and the
call site reads exactly like TDD-06 §3's own pseudocode.

Fixed with `Tuning.step_ticks()`, a second precomputed table at the input rate, and
`test_step_counters_use_step_ticks.gd`, which fails if anything under `scripts/pawn/` calls the
30 Hz conversion.

### 2. `INPUT-` was never a registered namespace

GDD-02 §1.2 and §1.3 had been naming fifteen `INPUT-` IDs since the first draft.
`NAMING_AND_IDS.md` §1 never listed the prefix, so `IdScanner` never harvested them, the grammar
never checked them, and `Ids` never mirrored them. They read as IDs everywhere they appeared
while being, mechanically, prose — and this story needed them to be real, because the `InputMap`
action names are derived from them.

Registered. The chain is now GDD-02 → `Ids` → `InputActions` → `project.godot`, with a guard on
every hop, in both directions.

### 3. The boot broke again, with 222 tests green

`PawnContext` starts in `Respawning`. Routing the spawn through `transition()` looked that state
up, found nothing — `SYS-SPAWN` is US-0062 — and took the client down on the first frame. The
same class of defect as the `change_scene_to_file` failure trap 4 records, and found the same
way: by launching the game.

Spawning is not a transition; a pawn being placed in the world has no state to come *from*.
`PawnStateMachine.spawn_into()` now says so, and `test_client_boot_walks.gd` — the first test in
this project that boots a scene — asserts a key press moves the pawn, end to end.

### 4. Four bare prose numbers promoted

`TUN-SPEED-SPRINT-DOUBLETAP` (the GDD said "double-tap" and never said how fast),
`TUN-SPEED-STICK-DEADZONE`, `TUN-SPEED-STICK-BLENDWALK-MAX`, `TUN-SPEED-TRIGGER-RUN`.

### 5. One bit appended to the wire format

`InputBits.RUN_FULL`. GDD-02 §1.3 requires "partial pull = jog, full pull = run", which the ten
bits in TDD-03 §5 cannot express: the ladder escalates Jog → Run on a sustained `RUN`, so a pad
player holding a half-pulled trigger would be dragged to Run against their intent, losing exactly
the fine speed control §1.3 calls the analogue advantage. A keyboard press has strength 1.0 and
therefore behaves precisely as before.

Appending is safe by construction; reordering is not, and `input_bits.gd` says so at the top.

## What this story does not do

- **No options screen.** Rebinding, hold/toggle and mode switching are complete as an API with
  unit tests. The screen is M5.
- **No camera rig.** `DebugFollowCamera` was scaffolding in `scripts/debug/` so a human could
  see the pawn at all. US-0021 replaced it with the real `SYS-CAMERA` rig and deleted it.
- **No networking.** `InputHistory` is filled but never replayed; reconciliation is US-0033.
- **The M1 feel gate is now judgeable and has not been judged.** It is subjective and needs a
  human at the controls.

## Recorded, not forgotten

- **The pad sprint combo shares a button with traverse.** GDD-02 §1.3 specifies "L2 full + A"
  and `INPUT-TRAVERSE` is `A`, so vaulting at full trigger also opens sprint. That is what the
  document says; whether it is what the document *means* is a question for the first pad
  playtest.
- **Look sensitivity is not a tunable.** It is a per-player preference in the same class as a
  volume slider, so it belongs to `IProfileStore` — stubbed in MVP (ASM-0026) — and is an
  `@export` on `InputSampler` until then.
