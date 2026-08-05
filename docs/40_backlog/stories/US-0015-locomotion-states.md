---
id: US-0015
title: Locomotion states and the speed ladder
version: 0.1.0
status: done
owner: Technical Director
last_updated: 2026-08-05
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

- [x] Six locomotion states exist, each reading its speed from MovementTuning.
- [x] Speeds: 1.4 / 2.2 / 3.4 / 4.5 / 6.2 m/s, all from tunables, no literals.
- [x] Backpedal applies the multiplier.
- [x] Any state to BlendWalk succeeds within one tick, from every state, at every speed.
- [x] Each state returns its correct suspicion_rate, read from SuspicionTuning.
- [x] Sprint requires the deliberate double-tap or sustained-hold input.

## Test notes

`test_slow_always_available.gd` is the critical one — slowing down is never gated, never delayed,
never refused. It is the escape hatch the whole speed economy depends on.

## Notes

Suspicion values are wired here but not yet consumed; SuspicionSystem arrives at M4.

> **Done 2026-08-05.** Six locomotion states plus the shared `LocomotionState`
> acceleration helper. Every speed and rate read from tuning; no literals.
>
> **The story could not be satisfied as written.** GDD-02 §2.2 declares
> `Any → Blend-walk` "always available and instant" and `Any → Idle` on release,
> but the §3 diagram — declared normative, and asserted by US-0014 — drew neither,
> because Mermaid has no notation for a wildcard edge. `Sprint → BlendWalk` was
> therefore *illegal*. Resolved by
> [ADR-0012](../../00_meta/adr/ADR-0012-slow-is-always-available.md), which adds
> the six edges to the diagram and the table.
>
> **A real bug the test caught:** on the tick `INPUT-SLOW` is pressed the state
> label became `BlendWalk` while `_integrate` still aimed at sprint speed, so the
> body lagged the label by one tick. "Instant" was true of the state machine and
> false of the pawn. Downward targets now clamp on the same tick; escalation stays
> gradual.
>
> Two more bare prose numbers promoted to tunables: `TUN-SPEED-RUN-HOLD` (0.35 s)
> and `TUN-SPEED-SPRINT-HOLD` (0.4 s). GDD-02 now cites the IDs.
>
> **The M1 feel gate is not met by this story and cannot be** — it is subjective
> and needs a human at the controls. What is asserted is the mechanical half:
> slowing reaches BlendWalk in one tick from all six states at all six speeds, and
> the velocity falls on that same tick.
