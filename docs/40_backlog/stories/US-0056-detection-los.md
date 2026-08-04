---
id: US-0056
title: Detection — the single line-of-sight query
version: 0.1.0
status: draft
owner: Technical Director
last_updated: 2026-08-03
depends_on: [GDD-03-SOCIAL-STEALTH, TDD-07-SUSPICION]
---

# US-0056 — Detection: the single line-of-sight query

| | |
|---|---|
| **Milestone** | M4 |
| **Epic** | `EPIC-DETECTION` |
| **Systems** | `SYS-DETECTION` |
| **Estimate** | S |
| **Depends on** | US-0055 |

## Description

One line-of-sight query used by everything, so Focus accumulation, compass lock and Cinderfall
occlusion can never disagree.

## Acceptance criteria

- [ ] `has_los(from, to, at_tick)` is the ONLY LOS query in the project.
- [ ] Blocked by world geometry and active Cinderfall volumes.
- [ ] NOT blocked by NPCs, other players or corpses.
- [ ] `at_tick` rewinds for kill and stun validation; otherwise current.
- [ ] Called by lock progression, Focus tracking and kill validation.

## Test notes

`test_los_ignores_npcs.gd` — a wall of ten NPCs between two players does not block.
`test_los_single_query.gd` is a source scan asserting all three consumers call the same function.

## Notes

NPCs not blocking LOS is counterintuitive and deliberate. If they did, a dense crowd would be
MECHANICALLY opaque and the skill of picking a person out of a crowd would be replaced by a
visibility calculation.

The crowd must hide you by being CONFUSING, never by being SOLID. That is the difference between
social stealth and cover shooting.
