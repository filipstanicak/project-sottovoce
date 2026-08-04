---
id: US-0032
title: Client prediction
version: 0.1.0
status: draft
owner: Technical Director
last_updated: 2026-08-03
depends_on: [ADR-0002, TDD-04-NET, TDD-03-TICK]
---

# US-0032 — Client prediction

| | |
|---|---|
| **Milestone** | M2 |
| **Epic** | `EPIC-PREDICTION` |
| **Systems** | `SYS-NET-PREDICTION` |
| **Estimate** | M |
| **Depends on** | US-0031 |

## Description

The client runs the same state machine locally against its own input and buffers unacknowledged
commands for replay.

## Acceptance criteria

- [ ] Input sampled and sent at 60 Hz, one command per physics frame.
- [ ] The local pawn steps immediately through the same PawnStateMachine.
- [ ] Commands and their resulting states are buffered, capped at 32.
- [ ] Only the local pawn is predicted — nothing else, ever.
- [ ] NO gameplay state is predicted: not suspicion, tier, detection, contracts, cooldowns or score.
- [ ] Buffer overflow force-accepts server state with a visible correction.

## Test notes

`test_pawn_determinism.gd` asserts the same command sequence produces bit-identical results.
`test_input_buffer_overflow.gd` at 600 ms RTT.

## Notes

A client-side suspicion estimate "just for the HUD" would drift, and a HUD that disagrees with
the server about your own tier is worse than no HUD.
