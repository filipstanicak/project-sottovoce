---
id: US-0013
title: Pawn state machine skeleton
version: 0.1.0
status: done
owner: Technical Director
last_updated: 2026-08-05
depends_on: [ADR-0008, TDD-06-PAWN, GDD-02-PLAYER]
---

# US-0013 — Pawn state machine skeleton

| | |
|---|---|
| **Milestone** | M1 |
| **Epic** | `EPIC-PAWN-STATES` |
| **Systems** | `SYS-PAWN` |
| **Estimate** | M |
| **Depends on** | US-0012 |

## Description

PawnState base class, PawnContext, PawnStateMachine, and the three pawn scenes. State objects
rather than an enum-and-match block (ADR-0008): fifteen states with per-state physics would be
~700 lines in one file with one 400-line function.

## Acceptance criteria

- [x] PawnState declares enter, exit, step, suspicion_rate, camera_fov, interrupt_priority, is_interruptible.
- [x] PawnContext is a RefCounted, not a Node, so states are unit-testable with no scene tree.
- [x] PawnContext.body is nullable and states tolerate it being null.
- [x] State objects hold no per-pawn data — one shared instance per state.
- [x] pawn_server.tscn, pawn_local.tscn and pawn_remote.tscn exist per TDD-06 section 1.
- [x] pawn_remote.tscn is NOT a physics body and has no state machine.
- [x] Every state enter() resets state_timer_ticks.

## Test notes

`test_pawn_states_stateless.gd` asserts no PawnState subclass declares per-pawn data.
`test_pawn_state_enter_resets_timer.gd`.

## Notes

pawn_local and pawn_server share the state machine script and collision shape verbatim.
Prediction reconciliation replays inputs through the identical code path the server used.

> **Done 2026-08-05.** `PawnState`, `PawnContext`, `PawnStateMachine`,
> `PawnStateId` and the three scenes. `InputCommand` and `ProbeResult` land here
> in minimal form because they are `step()`'s signature — a field typed `Variant`
> today is a field nobody types correctly later. Their real content is US-0016
> and US-0017.
>
> **The corpus said fourteen states; there are fifteen.** Both normative sources
> — the GDD-02 §3 diagram and the §3.1 table — list fifteen, while six places in
> the prose said fourteen. §3 says the diagram wins, so the prose was corrected.
> `test_pawn_state_count.gd` now compares `PawnStateId.ALL` against the table
> name-for-name, so the two can no longer drift silently.
>
> The transition table is US-0014; until then `is_valid_edge()` permits any edge
> between known states. Concrete states are US-0015 onward — the machine holds
> none yet, which is why the stateless guard is written against the base class
> and the folder rather than against a state list.
