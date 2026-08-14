---
id: US-0033
title: Reconciliation
version: 1.0.0
status: done
owner: Technical Director
last_updated: 2026-08-14
depends_on: [ADR-0002, TDD-04-NET]
---

# US-0033 — Reconciliation

| | |
|---|---|
| **Milestone** | M2 |
| **Epic** | `EPIC-PREDICTION` |
| **Systems** | `SYS-NET-PREDICTION` |
| **Estimate** | **L** |
| **Depends on** | US-0032 |

## Description

On snapshot arrival, compare the authoritative state against what was predicted for that
sequence, and replay the unacknowledged buffer if the error exceeds threshold.

The highest-bug-density work in the project.

## The sentence the chapter calls its most important

**The simulation snaps; the visual blends.** If the simulation blended, every later prediction
would run from a position the server never had, and the error would **compound instead of
converging** — a client that drifts further from the truth the harder it tries to hide the
correction.

So on a divergence the context takes the server's answer *exactly*, every unacknowledged command
is replayed through the same `PawnMotion` the server used, and the difference between where the
pawn was **drawn** a moment ago and where it now **is** goes to the visuals as an offset decaying
over `TUN-NET-RECONCILE-SMOOTH-TIME`. The player sees a slide; the simulation sees a snap.

`PersonaVisuals` is a child of the collider, so a local offset draws the pawn away from where it
is simulated without the simulation ever learning about it.

## It reconciles on a physics frame, not on arrival

A replay calls `move_and_slide()` and re-casts the traversal probes, and both are only valid
inside the physics step — Godot delivers RPCs on the idle frame. The snapshot is held and
answered from `pawn_stepped`, which also guarantees the replay happens **after** this frame's
prediction rather than racing it.

## A snapshot with nothing to compare against is not an error

`state_at()` returns null when the acked command has already been discarded, or was never sent.
That is the ordinary case at a join, and the answer is to smooth rather than to guess: the next
snapshot will have a match.

## Acceptance criteria

- [x] Error under `TUN-NET-RECONCILE-THRESHOLD` 0.10 m is smoothed silently — `corrected` is
      emitted with `replayed = false`, and nothing moves.
- [x] Error over threshold snaps the SIMULATION and replays every unacked command.
- [x] The VISUAL blends the correction over `TUN-NET-RECONCILE-SMOOTH-TIME` — a correction is
      never a visible pop.
- [x] Acknowledged commands are discarded from the buffer, **across the `u16` wrap**.
- [x] Reconciliation converges rather than compounding, at all four latency profiles — asserted
      as four separate tests at 1, 3, 6 and 11 frames of held snapshots.

## What building it found

**The common case must be free, and it is.** `test_an_agreeing_server_never_replays` asserts zero
replays over 90 frames of ordinary walking. The client and the server run the same code from the
same commands, so there is nothing to correct — and a reconciler that replayed anyway would be
doing 32 steps of physics per snapshot for nothing.

**Two of this file's own tests were wrong before the code was.** The first looped four latency
profiles calling `before_each()` by hand, which stands up a second client and a second server
without freeing the first — three pawns sharing one input, reporting a divergence that grew
neatly with latency and looked exactly like a real finding. The second read the visual offset
"three frames after" a shove, which is a guess: the snapshot carrying it is built on the *next*
sampled command and then held for its latency. It now runs until the correction actually happens.

**Both are trap 4's family** — an assertion that is true of the wrong thing — and both were
caught only because the numbers were implausible rather than merely red.

## Test notes

`test_prediction_reconciliation.gd` covers both, against a **real** `PawnHost` driving
`pawn_server.tscn` fed the client's own sampled commands. Only the latency is synthetic —
snapshots are held for a chosen number of frames, which is the one thing a single process cannot
get for free.

| Test | Asserts |
|---|---|
| `test_it_converges_*` | Four latency profiles, each its own test, each walking 90 frames |
| `test_a_forced_divergence_snaps_the_simulation_exactly` | A two-metre shove replays and converges |
| `test_the_visual_blends_while_the_simulation_has_already_moved` | The offset exists after the snap and decays |
| `test_the_visual_offset_is_gone_within_the_smoothing_time` | It finishes |
| `test_an_agreeing_server_never_replays` | The common case is free |

## Notes

The simulation snaps and the visual blends. If the simulation blended, later predictions would
run from a position the server never had and the error would compound instead of converging.
This is the single most important property in the chapter.
