---
id: US-0056
title: Detection — the single line-of-sight query
version: 0.2.0
status: in-progress
owner: Technical Director
last_updated: 2026-08-25
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

- [x] `has_los(from, to, at_tick)` is the ONLY LOS query in the project.
      `test_los_single_query.gd` refuses a second one under `systems/`, `net/` or `server/`, and
      asserts the chokepoint still casts so it cannot pass by deletion. Falsified against a
      planted query in `CrowdAlarm`.
- [x] Blocked by world geometry and active Cinderfall volumes.
      The cloud is a **sphere against the segment**, not a body: a `StaticBody3D` on `WORLD` would
      also block the traversal probes, so a player could vault a cloud. Nothing places one until
      `SYS-ABILITY`.
- [x] NOT blocked by NPCs, other players or corpses.
      **The mask is the rule** — `WORLD` alone, and they are all on `PAWN`/`NPC`.
- [ ] `at_tick` rewinds for kill and stun validation; otherwise current.
      **Refused rather than faked.** Geometry does not move, so a rewound query against the world
      alone would answer exactly as a current one and look correct while the players it is about
      sat at today's positions. `RewoundWorld` carries those; `SYS-KILL` (US-0060) pairs the two.
- [ ] Called by lock progression, Focus tracking and kill validation.
      **One of the three exists.** `SYS-COMPASS`'s lock calls it as of US-0058 —
      `TUN-COMPASS-LOCK-REQUIRES-LOS` — and `test_lock_through_crowd.gd` measures the ladder:
      zero raycasts for a hunter facing away, one for a hunter watching. Focus tracking is
      US-0064 and kill validation is US-0060.

## Test notes

`test_los_ignores_npcs.gd` — a wall of ten NPCs between two players does not block.
`test_los_single_query.gd` is a source scan asserting all three consumers call the same function.

## Notes

NPCs not blocking LOS is counterintuitive and deliberate. If they did, a dense crowd would be
MECHANICALLY opaque and the skill of picking a person out of a crowd would be replaced by a
visibility calculation.

The crowd must hide you by being CONFUSING, never by being SOLID. That is the difference between
social stealth and cover shooting.
