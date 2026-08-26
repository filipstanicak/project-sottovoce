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
      **Still refused, and US-0060 sharpened the reason rather than clearing it.** The
      original argument was that geometry does not move, so a rewound query would answer
      exactly as a current one while looking correct about players who sat at today's
      positions. What US-0060 adds is that **kill validation performs no line-of-sight query
      at all**: TDD-10 §3's flowchart is Cinderfall, contract, range, cone, contest, and
      nothing else. So the rewound form still has no caller — and a query with no caller that
      answers plausibly is exactly the shape this criterion was left unticked to avoid.
      What *did* become rewindable is the cinder-cloud half: `CinderfallVolumes` records a
      lit tick as well as an expiry, and every liveness question now takes the tick it is
      asked about.
- [ ] Called by lock progression, Focus tracking and kill validation.
      **Two callers exist and the third is not going to be kill validation.**
      `SYS-COMPASS`'s lock calls it as of US-0058 — `TUN-COMPASS-LOCK-REQUIRES-LOS` — and
      `test_lock_through_crowd.gd` measures the ladder: zero raycasts for a hunter facing
      away, one for a hunter watching. **US-0060 added the witnessed-kill check**, which asks
      whether any living player has a clear line to a body at the contact frame.
      **Kill validation itself never asks**: TDD-10 §3's flowchart has no line-of-sight node,
      so as built a kill through a market stall at 2.4 m is legal. TDD-04 §10's test table
      implies otherwise. That contradiction is reported in US-0060 and is the owner's.
      Focus tracking is US-0064.

## Test notes

`test_los_ignores_npcs.gd` — a wall of ten NPCs between two players does not block.
`test_los_single_query.gd` is a source scan asserting all three consumers call the same function.

## Notes

NPCs not blocking LOS is counterintuitive and deliberate. If they did, a dense crowd would be
MECHANICALLY opaque and the skill of picking a person out of a crowd would be replaced by a
visibility calculation.

The crowd must hide you by being CONFUSING, never by being SOLID. That is the difference between
social stealth and cover shooting.
