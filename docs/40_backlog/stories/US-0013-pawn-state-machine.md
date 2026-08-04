---
id: US-0013
title: Pawn state machine skeleton
version: 0.1.0
status: draft
owner: Technical Director
last_updated: 2026-08-03
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
rather than an enum-and-match block (ADR-0008): fourteen states with per-state physics would be
~700 lines in one file with one 400-line function.

## Acceptance criteria

- [ ] PawnState declares enter, exit, step, suspicion_rate, camera_fov, interrupt_priority, is_interruptible.
- [ ] PawnContext is a RefCounted, not a Node, so states are unit-testable with no scene tree.
- [ ] PawnContext.body is nullable and states tolerate it being null.
- [ ] State objects hold no per-pawn data — one shared instance per state.
- [ ] pawn_server.tscn, pawn_local.tscn and pawn_remote.tscn exist per TDD-06 section 1.
- [ ] pawn_remote.tscn is NOT a physics body and has no state machine.
- [ ] Every state enter() resets state_timer_ticks.

## Test notes

`test_pawn_states_stateless.gd` asserts no PawnState subclass declares per-pawn data.
`test_pawn_state_enter_resets_timer.gd`.

## Notes

pawn_local and pawn_server share the state machine script and collision shape verbatim.
Prediction reconciliation replays inputs through the identical code path the server used.
