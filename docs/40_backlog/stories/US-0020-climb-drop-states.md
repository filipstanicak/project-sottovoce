---
id: US-0020
title: Climb, drop and gap-jump states
version: 0.1.0
status: draft
owner: Technical Director
last_updated: 2026-08-03
depends_on: [TDD-06-PAWN, GDD-05-LEVEL]
---

# US-0020 — Climb, drop and gap-jump states

| | |
|---|---|
| **Milestone** | M1 |
| **Epic** | `EPIC-TRAVERSAL` |
| **Systems** | `SYS-TRAVERSAL` |
| **Estimate** | M |
| **Depends on** | US-0019 |

## Description

StateClimb and StateDrop, the latter also handling the ballistic gap-jump arc.

## Acceptance criteria

- [ ] Climb at 2.8 m/s, up to 9 m in one unbroken climb.
- [ ] Climb can be released mid-way, transitioning to Drop.
- [ ] Drop under 4 m lands clean; over 4 m applies a 0.8 s stagger.
- [ ] Gap jump routes through Drop with an initial upward velocity.
- [ ] Drop is uninterruptible while airborne.
- [ ] Climb applies climb-rate suspicion; arriving on the roof stratum applies roof-presence suspicion.

## Test notes

Verify the balcony-to-street drop at 4.5 m costs a stagger — descending into the crowd is
deliberately a small skill check rather than a free action.

## Notes

Roof-to-balcony is exactly at the safe threshold, so upper transitions are free and only the
final descent costs. You can flee across the roofs cheaply but cannot rejoin the crowd cheaply.
