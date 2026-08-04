---
id: US-0054
title: Blend actions — static and concealment props
version: 0.1.0
status: draft
owner: Technical Director
last_updated: 2026-08-03
depends_on: [GDD-03-SOCIAL-STEALTH, GDD-05-LEVEL]
---

# US-0054 — Blend actions: static and concealment props

| | |
|---|---|
| **Milestone** | M4 |
| **Epic** | `EPIC-SUSPICION` |
| **Systems** | `SYS-BLEND` |
| **Estimate** | S |
| **Depends on** | US-0053 |

## Description

Bench and stall-lean blends, plus the five capacity-one concealment props.

## Acceptance criteria

- [ ] Static props require no NPCs nearby; any movement input breaks them.
- [ ] Concealment props hide the player completely — not rendered, not killable.
- [ ] Capacity is exactly 1; a second request is refused with DISTINCT feedback, not silence.
- [ ] The occupant can see nothing while inside.
- [ ] A 0.5 s exit-vulnerability window prevents door-flickering to dodge a kill.
- [ ] Occupancy is server-owned state.

## Test notes

`test_blend_prop_capacity.gd` asserts the refusal path gives feedback.

## Notes

The concealment prop is the strongest and most restricted blend: total safety in exchange for
total blindness and a fixed, learnable location. Capacity one makes each a claimable resource, so
a second player arriving is a real problem.

Every hiding spot has a POSITIONAL weakness rather than a mechanical one. The prop is always
perfect; the walk to it never is.
