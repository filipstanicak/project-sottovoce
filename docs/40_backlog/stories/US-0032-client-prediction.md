---
id: US-0032
title: Client prediction
version: 1.0.0
status: done
owner: Technical Director
last_updated: 2026-08-14
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

## Most of this was already true, and that is the point

`LocalPawnDriver` has stepped the real `PawnStateMachine` from real input since US-0016 — which
*is* prediction, and is why M1's feel gate could be judged at all. What this story adds is the
half that only matters once a server disagrees: **the buffer remembers what it predicted**, not
only what it sent.

`InputHistory.push()` now takes a `PredictedState` alongside the command, captured **after** the
step. The history's job is to answer *what did we think was true once the server had this
command*, and that answer does not exist until the command has been applied.

## `PredictedState` has nowhere to put gameplay state

Position, velocity, the state machine's state, the state timer, grounded. That is the whole
object, and the omissions are load-bearing: **nothing gameplay-relevant is predicted** (ADR-0002
point 5), and the way to keep that true is to have nowhere to put it. A client-side suspicion
estimate "just for the HUD" would drift, and a HUD that disagrees with the server about your own
tier is worse than no HUD.

`test_a_predicted_state_carries_no_gameplay_state` asserts it structurally.

## The buffer's `ack` crossed the wrap wrongly

`seq` is a `u16` sent 60 times a second, so it rolls over about every 18 minutes — inside a
match. `ack()` compared with `<=`, which stops discarding at the wrap: the buffer would fill with
commands the server answered long ago, and the replay would re-run eighteen minutes of input on
every snapshot. It uses `SequenceGate.is_newer()` now, the same arithmetic the server's own gate
uses — which is the point, because both ends must agree on what "already answered" means.

## Acceptance criteria

- [x] Input sampled and sent at 60 Hz, one command per physics frame — `InputSender`, US-0030,
      and `test_input_sampled_once.gd` measures the rate.
- [x] The local pawn steps immediately through the same `PawnStateMachine` — and the same
      `PawnMotion`, which is the half US-0028 extracted.
- [x] Commands and their resulting states are buffered, capped at `TUN-NET-INPUT-BUFFER-SIZE`.
      Both arrays are trimmed together: if only one were, `state_at()` would answer with a
      neighbour's prediction, which is a plausible number and the worst kind.
- [x] Only the local pawn is predicted — nothing else, ever. Remote pawns are interpolated
      (US-0034) and have no state machine at all.
- [x] NO gameplay state is predicted: not suspicion, tier, detection, contracts, cooldowns or
      score.
- [x] Buffer overflow force-accepts server state with a visible correction. The buffer drops the
      oldest and counts it; the correction that follows is a replay from the server's answer,
      which is the visible one.

## Test notes

| Test | Asserts |
|---|---|
| `test_input_history_states.gd` | The buffer remembers a prediction per sequence; an unknown sequence reads as null; **acking works across the `u16` wrap**; states are dropped with their commands; `PredictedState` has no gameplay field |
| `test_prediction_reconciliation.gd` | The buffer never grows past its cap, and a 40-frame stall overflows it |

`test_pawn_determinism.gd` is covered by `test_substep_matches_server.gd` (US-0028), which asserts
the client and the server land in the **same place** from the same commands — the same claim,
measured against a real server rather than against a second run of the client.

## Notes

A client-side suspicion estimate "just for the HUD" would drift, and a HUD that disagrees with
the server about your own tier is worse than no HUD.
