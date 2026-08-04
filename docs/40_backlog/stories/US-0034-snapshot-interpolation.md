---
id: US-0034
title: Snapshot interpolation for remotes
version: 0.1.0
status: draft
owner: Technical Director
last_updated: 2026-08-03
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

## Acceptance criteria

- [ ] Fixed 100 ms buffer — not adaptive (ASM-0021).
- [ ] Interpolation is based on RECEIVED TIMESTAMPS, never an assumed fixed interval.
- [ ] Mixed 30 Hz and 10 Hz entity streams both interpolate with no stutter at the LOD boundary.
- [ ] NO extrapolation. Buffer underrun holds the last transform and freezes animation phase.
- [ ] Remote pawns are not physics bodies and run no state machine.

## Test notes

`test_interpolation_timestamps.gd` covers the mixed-rate case.

## Notes

Timestamp-based interpolation is required because far NPCs arrive at 10 Hz and near ones at 30 Hz.
Assuming a fixed interval would make the two rates fight.

100 ms is nearly free here: a remote player at blend-walk has moved 14 cm. The game is about
slowness, and slowness is what makes interpolation cheap.
