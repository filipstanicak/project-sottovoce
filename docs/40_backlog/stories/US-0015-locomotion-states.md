---
id: US-0015
title: Locomotion states and the speed ladder
version: 0.1.0
status: draft
owner: Technical Director
last_updated: 2026-08-03
depends_on: [TDD-06-PAWN, GDD-02-PLAYER, TUN-INDEX]
---

# US-0015 — Locomotion states and the speed ladder

| | |
|---|---|
| **Milestone** | M1 |
| **Epic** | `EPIC-PAWN-STATES` |
| **Systems** | `SYS-PAWN` |
| **Estimate** | M |
| **Depends on** | US-0014 |

## Description

Idle, BlendWalk, Stroll, Jog, Run and Sprint, plus the shared Locomotion acceleration helper.

Deceleration is faster than acceleration (24 vs 18) so stop-and-blend is always instantly
available. The asymmetry is the design thesis written into the acceleration curve.

## Acceptance criteria

- [ ] Six locomotion states exist, each reading its speed from MovementTuning.
- [ ] Speeds: 1.4 / 2.2 / 3.4 / 4.5 / 6.2 m/s, all from tunables, no literals.
- [ ] Backpedal applies the multiplier.
- [ ] Any state to BlendWalk succeeds within one tick, from every state, at every speed.
- [ ] Each state returns its correct suspicion_rate, read from SuspicionTuning.
- [ ] Sprint requires the deliberate double-tap or sustained-hold input.

## Test notes

`test_slow_always_available.gd` is the critical one — slowing down is never gated, never delayed,
never refused. It is the escape hatch the whole speed economy depends on.

## Notes

Suspicion values are wired here but not yet consumed; SuspicionSystem arrives at M4.
