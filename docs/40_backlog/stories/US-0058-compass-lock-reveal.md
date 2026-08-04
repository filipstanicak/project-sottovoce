---
id: US-0058
title: Compass lock, reveal and portrait
version: 0.1.0
status: draft
owner: Lead Game Designer
last_updated: 2026-08-03
depends_on: [GDD-03-SOCIAL-STEALTH, TDD-07-SUSPICION]
---

# US-0058 — Compass lock, reveal and portrait

| | |
|---|---|
| **Milestone** | M4 |
| **Epic** | `EPIC-DETECTION` |
| **Systems** | `SYS-COMPASS` |
| **Estimate** | M |
| **Depends on** | US-0057 |

## Description

The lock arc, the silhouette reveal, and the permanent contract-portrait fill (ASM-0030).

## Acceptance criteria

- [ ] Lock requires the contract within a 25 degree cone, within 20 m, with server-side LOS.
- [ ] Fill time 1.6 s, reduced by the Cold Read passive.
- [ ] A broken lock DRAINS 1.4x faster than it filled.
- [ ] Completion reveals a silhouette for 1.5 s, with a 4 s re-reveal cooldown.
- [ ] Completion ALSO fills the contract portrait PERMANENTLY for that contract.
- [ ] The portrait resets to UNKNOWN on reassignment.
- [ ] A lock cannot complete through a walking group's incidental gaps.

## Test notes

`test_lock_through_crowd.gd`, `test_lock_decay_faster.gd`, `test_portrait_permanent.gd`.

## Notes

Fill time deliberately exceeds one NPC stride cycle, so a lock needs a genuinely clear view. A
shorter fill would let hunters lock through crowds, making the crowd cosmetic.

Drain being faster than fill pushes the hunter toward standing still and watching — which also
keeps their own suspicion at zero. The mechanic and the thesis agree.

The permanent portrait is what makes a lock worth its 1.6 s cost; the 1.5 s reveal alone is not.
