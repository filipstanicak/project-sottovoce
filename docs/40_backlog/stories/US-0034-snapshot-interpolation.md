---
id: US-0034
title: Snapshot interpolation for remotes
version: 1.0.0
status: done
owner: Technical Director
last_updated: 2026-08-14
depends_on: [ADR-0002, TDD-04-NET]
---

# US-0034 — Snapshot interpolation for remotes

| | |
|---|---|
| **Milestone** | M2 |
| **Epic** | `EPIC-PREDICTION` |
| **Systems** | `SYS-NET-PREDICTION` |
| **Estimate** | M |
| **Depends on** | US-0033 |

## Description

Remote pawns and NPCs rendered 100 ms in the past, interpolated between bracketing snapshots.

## Two objects, and the split is the design

| Piece | Answers |
|---|---|
| `SnapshotInterpolator` | *Where was this thing at time T?* A stamped buffer per entity and the arithmetic between two samples. Pure |
| `RenderClock` | *What is T?* The newest server time seen, advanced by the frame's delta, minus `TUN-NET-INTERP-BUFFER`. Pure |

Keeping them apart is what makes both testable without a snapshot, a socket or a
frame — and it is what stops the interpolation delay from quietly becoming adaptive, because
the only thing that could make it drift lives in one nine-line object.

## Stamped, never spaced

Each sample carries the server time it describes, and the search brackets a render time between
two of them. Assuming a fixed 33 ms interval would be simpler and would break the moment the
crowd LOD arrives: **far NPCs come at 10 Hz and near ones at 30**, and a fixed interval makes the
two rates fight — the far ones race and the near ones stall.

`test_interpolation_timestamps.gd` runs the same straight-line motion through both rates and
asserts they read the same position at the same moment.

## The clock only moves forward, and never smooths

A snapshot describing a moment already passed does **not** wind the clock back. Remote pawns
would jump backwards, which reads as a rubber-band on somebody else's screen and is
indistinguishable from a real one. Late is late; the interpolator holds.

And it does not ease toward the server's time. A clock that eased would make the interpolation
delay drift, and **a drifting delay is an adaptive buffer by accident** — which ASM-0021 refuses,
because remote timing that changes between sessions confounds every balance judgement made
against it.

## Acceptance criteria

- [x] Fixed 100 ms buffer — not adaptive (ASM-0021). Read from `TUN-NET-INTERP-BUFFER`; the
      clock's only arithmetic is a subtraction, so there is nowhere for an adaptation to hide.
- [x] Interpolation is based on RECEIVED TIMESTAMPS, never an assumed fixed interval.
- [x] Mixed 30 Hz and 10 Hz entity streams both interpolate with no stutter at the LOD boundary.
- [x] NO extrapolation. Buffer underrun holds the last transform.
- [x] Remote pawns are not physics bodies and run no state machine — unchanged from
      `pawn_remote.tscn`, and asserted structurally by `test_npcview_is_inert.gd`'s sibling rule
      in TDD-06 §1.

**Animation phase is not frozen on underrun** because there is no animation phase to freeze:
`pawn_remote.tscn` wears `GreyboxBody` and there are no clips until US-0039. The field is carried
in the snapshot and read by nothing. Recorded rather than ticked.

## Why it is `_physics_process` and not `_process`

Interpolating on rendered frames would be marginally smoother on a 144 Hz display, and would put
a moving transform on a clock the player's hardware chooses. The fixed clock is already **twice**
the snapshot rate. `test_no_gameplay_in_process.gd` refuses `_process` under `scripts/net/`
outright, and it is right to.

## What building it found

**`test_input_sampled_by_one_caller.gd` failed on `SnapshotInterpolator.sample()`.** Its needle
was `.sample(` alone, so a new class with a perfectly ordinary method name tripped a guard about
input sampling. A guard that cries wolf gets relaxed, and the relaxation is what actually costs
you — it now requires the file to name `InputSampler` as well.

**And the first mixed-rate test failed for the right reason.** It fed 30 samples at 30 Hz into a
16-deep history, so the early ones were evicted and the test was reading the *hold* path while
claiming to measure interpolation. The setup was wrong, not the code — which is exactly the
shape trap 4 warns about, one layer up.

## Test notes

| Test | Asserts |
|---|---|
| `test_interpolation_timestamps.gd` | Halfway is halfway; **30 Hz and 10 Hz read the same line**; a slow stream still moves between its own samples; no extrapolation past the newest sample; yaw takes the short way round; the history outlasts the interpolation delay |
| `test_render_clock.gd` | No opinion before the first snapshot; the tuned delay behind the newest; it keeps running between snapshots; **a late snapshot never winds it back**; it does not ease |

## Notes

Timestamp-based interpolation is required because far NPCs arrive at 10 Hz and near ones at 30 Hz.
Assuming a fixed interval would make the two rates fight.

100 ms is nearly free here: a remote player at blend-walk has moved 14 cm. The game is about
slowness, and slowness is what makes interpolation cheap.
