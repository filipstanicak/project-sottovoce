---
id: US-0033
title: Reconciliation
version: 0.1.0
status: draft
owner: Technical Director
last_updated: 2026-08-03
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

## Acceptance criteria

- [ ] Error under 0.10 m is smoothed silently.
- [ ] Error over threshold snaps the SIMULATION and replays every unacked command.
- [ ] The VISUAL blends the correction over 0.12 s — a correction is never a visible pop.
- [ ] Acknowledged commands are discarded from the buffer.
- [ ] Reconciliation converges rather than compounding, at all four latency profiles.

## Test notes

`test_prediction_reconciliation.gd` at 5 / 40 / 90 / 180 ms RTT.
`test_reconcile_snaps_sim_blends_visual.gd` asserts simulation equals server exactly while the
visual is offset and decaying.

## Notes

The simulation snaps and the visual blends. If the simulation blended, later predictions would
run from a position the server never had and the error would compound instead of converging.
This is the single most important property in the chapter.
