---
id: US-0035
title: Lag compensation history buffer
version: 0.1.0
status: draft
owner: Technical Director
last_updated: 2026-08-03
depends_on: [ADR-0010, TDD-04-NET]
---

# US-0035 — Lag compensation history buffer

| | |
|---|---|
| **Milestone** | M2 |
| **Epic** | `EPIC-PREDICTION` |
| **Systems** | `SYS-NET-LAGCOMP` |
| **Estimate** | S |
| **Depends on** | US-0034 |

## Description

A 500 ms ring buffer of pawn and NPC transforms, recorded every tick. **Recording only** — kill
and stun do not exist until M4.

Building it early means the buffer is proven before anything depends on it, and the M4 work is
validation logic rather than infrastructure.

## Acceptance criteria

- [ ] 15 entries at 30 Hz, 2.5x the maximum 200 ms rewind.
- [ ] Records pawn and NPC transforms every tick.
- [ ] `rewind(tick, around, radius)` returns a RewoundWorld for entities near a point only.
- [ ] Memory stays around 23 KB.
- [ ] The invariant lagcomp_max is at most history/2 is asserted.

## Test notes

`test_tuning_ranges.gd` covers the invariant. Rewind correctness is tested at M4 when there are
consumers.

## Notes

Rewinding only entities within about 7.5 m of the action keeps the per-validation cost at fewer
than 10 entities rather than 96.
