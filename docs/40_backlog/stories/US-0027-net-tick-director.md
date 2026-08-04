---
id: US-0027
title: MatchDirector and the net tick
version: 0.1.0
status: draft
owner: Technical Director
last_updated: 2026-08-03
depends_on: [TDD-03-TICK, TDD-01-ARCHITECTURE]
---

# US-0027 — MatchDirector and the net tick

| | |
|---|---|
| **Milestone** | M2 |
| **Epic** | `EPIC-TRANSPORT` |
| **Systems** | — |
| **Estimate** | M |
| **Depends on** | US-0026 |

## Description

The 30 Hz net tick derived from the 60 Hz physics clock, and explicit system tick ordering.

Ordering is declared in one file rather than left to scene-tree order, because scene-tree order
is an invisible dependency that breaks when somebody drags a node.

## Acceptance criteria

- [ ] Net tick fires every second physics frame — exactly 30 per 60, no drift over 10 000 frames.
- [ ] Pawn integration substeps at 60 Hz, once per received InputCommand.
- [ ] All other systems tick once per net tick at dt = 1/30.
- [ ] System order is an explicit array, matching TDD-01 section 4.
- [ ] MatchContext.tick is monotonic from match start.
- [ ] Nothing gameplay-relevant runs in _process.

## Test notes

`test_net_tick_rate.gd` for drift. `test_system_tick_order.gd` asserts the declared order against
a recorded call sequence. `test_no_gameplay_in_process.gd` scans for _process in systems.

## Notes

Pawn substepping at 60 Hz is forced by prediction: a server integrating once at dt=1/30 while the
client predicts twice at dt=1/60 diverges on every acceleration curve, and at 18 m/s^2 that
divergence is immediate and permanent.
