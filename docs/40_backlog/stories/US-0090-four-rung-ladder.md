---
id: US-0090
title: The ladder loses its Jog rung, and Shift resolves into Run or Sprint
version: 1.0.0
status: done
owner: Lead Game Designer
last_updated: 2026-08-12
depends_on: [GDD-02-PLAYER, TUN-INDEX]
---

# US-0090 — The four-rung ladder

| | |
|---|---|
| **Milestone** | M1 |
| **Epic** | `EPIC-PAWN` |
| **Systems** | `SYS-PAWN`, `SYS-INPUT` |
| **Estimate** | M |
| **Depends on** | US-0015, US-0016 |

## Description

**Requested by the owner at the controls, which is where every M1 defect has come from.** Two
complaints, one root: pressing `Shift` produced Jog rather than Run, and reaching Sprint ran
first and sprinted a moment later.

Both are the same shape — `INPUT-RUN` arriving somewhere the player did not ask for and leaving
again before they could read it. Holding the key used to open Jog immediately, Run at
`TUN-SPEED-RUN-HOLD` 0.35 s and Sprint at `TUN-SPEED-SPRINT-HOLD` 0.4 s, so **a sustained hold
gave fifty milliseconds of Run and then sprinted**, and a double-tap passed through Jog on its
way.

## Acceptance criteria

- [x] The speed ladder is blend-walk → stroll → run → sprint. `Jog` is retired, not renamed.
- [x] `INPUT-RUN` held past `TUN-SPEED-RUN-RESOLVE` is Run, and stays Run for as long as it is
      held.
- [x] A second press inside that window is Sprint, and **never passes through Run**.
- [x] `SCORE-PATIENT` is unchanged in meaning: `TUN-SCORE-PATIENT-SPEED` carries the Jog rung's
      3.4 m/s, and invariant §17.23 keeps it strictly between stroll and run.
- [x] Every retired ID is recorded in TUNABLES §19 and never reused.

## What was decided, and by whom

The owner chose all four, after the alternatives were laid out:

| Decision | Chosen | Rejected |
|---|---|---|
| What replaces `SCORE-PATIENT`'s threshold | Keep 3.4 as a scoring line | Patience = stroll (2.2), which is a real balance change; keeping Jog on the stick only |
| How Run and Sprint are told apart | A short window, then resolve | Instant Run with sprint on a hold; instant Run keeping the double-tap |

## The consequence nobody asked for, recorded

**`TUN-SPEED-SPRINT-HOLD` is deprecated, and that is a design change rather than a rename.**
A held key means Run and keeps meaning Run; it cannot also mean Sprint, because the two readings
are the same gesture. Sprint is the double-tap, plus the pad's full trigger + traverse.

GDD-02 §1.5 spends a page defending sprint's friction. That friction is **not** weakened: what is
gone is a second route to the same place, and a double-tap is still an input nobody enters by
leaning on a key. Design law 1 is intact and `ABIL-LUNGE` is still the answer to §1.5's
counter-argument.

## One window, not two

Kept as separate tunables, a 0.15 s resolve delay and a 0.25 s double-tap window fight each
other: Run engages at 0.15 and Sprint takes it away at 0.20 — which is the "it first runs a tiny
bit" this story exists to remove. `TUN-SPEED-RUN-RESOLVE` is therefore both the delay before Run
and the gap a double-tap must beat.

**The trade is real and it is the owner's to settle at the controls.** Shorter is a snappier Run
and a tighter double-tap. 0.15 s is a starting position, not a conclusion, and it is the single
most valuable thing to judge on the M1 feel-gate checklist.

## What it cost

| Retired | Successor |
|---|---|
| `TUN-SPEED-JOG` | `TUN-SCORE-PATIENT-SPEED` — same number, a scoring threshold now |
| `TUN-SUSPICION-GAIN-JOG` | none. Stroll is not cheap, it is free |
| `TUN-CAM-FOV-JOG` | none. Four rungs: 55 → 60 → 69 → 72 |
| `TUN-SPEED-RUN-HOLD` | `TUN-SPEED-RUN-RESOLVE` |
| `TUN-SPEED-SPRINT-HOLD` | none — see above |
| `TUN-SPEED-SPRINT-DOUBLETAP` | `TUN-SPEED-RUN-RESOLVE` |
| `PawnStateId.JOG`, `JogState` | none. Retained as a retired ID absent from `ALL` |
| `InputBits.RUN_FULL` | none. `TUN-SPEED-TRIGGER-RUN` decides whether the trigger is held at all |

**`TUN-CAM-FOV-CLIMB` was added, and it is a bug fix wearing a tunable.** `ClimbState` returned
`Tuning.camera.fov_jog` — a climb borrowing the lens of a speed rung it has nothing to do with.
GDD-02 §2.1 has framed a climb at 62° since it was written, without an ID. Removing the Jog rung
turned a borrowed value into a crash, which is the only reason anyone noticed.

## Test notes

`test_speed_gate.gd` asserts what the player **never reaches** as hard as what they do: a gate
that arrived at Run and escalated out of it a moment later would satisfy "a double-tap sprints"
and still be the defect. `test_a_double_tap_never_passes_through_run` is that assertion.

`test_input_sampled_once.gd` kept its job and changed its instrument. It measured
`TUN-SPEED-SPRINT-HOLD` opening in 13 ticks against 24 while input was sampled twice a frame
(trap 12); it measures `TUN-SPEED-RUN-RESOLVE` now, because a window counted twice is still half
the friction §1.5 prices.

## Out of scope, deliberately

The free jump and the wall system the same conversation asked for are **US-0091** and
**US-0092**. They are separate because one of them reverses a normative principle (§7's "assisted,
not simulated") and neither should be bundled into a change to the speed ladder.
