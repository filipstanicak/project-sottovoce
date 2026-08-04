---
id: US-0052
title: SuspicionSystem and impulses
version: 0.1.0
status: draft
owner: Technical Director
last_updated: 2026-08-03
depends_on: [TDD-07-SUSPICION, GDD-03-SOCIAL-STEALTH]
---

# US-0052 — SuspicionSystem and impulses

| | |
|---|---|
| **Milestone** | M4 |
| **Epic** | `EPIC-SUSPICION` |
| **Systems** | `SYS-SUSPICION` |
| **Estimate** | M |
| **Depends on** | US-0051 |

## Description

The server system driving the integrator, applying impulses, and replicating own-value and tier.

## Acceptance criteria

- [ ] Runs once per net tick, AFTER the crowd resolves.
- [ ] Nearest-NPC distance comes from the shared spatial hash, not a physics query.
- [ ] Impulses queue on the pawn and drain at a fixed pipeline position, so ordering is deterministic.
- [ ] NPC bump debounced at 0.8 s — one shove is not five stacked charges.
- [ ] Witnessed kill applies only if another PLAYER had line of sight at initiation.
- [ ] Own suspicion and tier replicate to the owning client only.
- [ ] Active source bitfield replicates, driving the HUD source list.
- [ ] Suspicion is NEVER predicted client-side.

## Test notes

`test_suspicion_impulse_debounce.gd`. `test_suspicion_additive.gd` asserts sprint plus roof plus
open reaches Exposed in 1.4 s.

## Notes

Crowd must resolve before suspicion. Computing against last tick's crowd would let a player
accrue alone-suspicion inside a pocket that has already re-formed — the player believes they are
blended and is not.

The active-source list exists because a player who cannot attribute their suspicion cannot learn
from it, and the total alone is not attributable.
