---
id: US-0042
title: Shared spatial hash
version: 0.1.0
status: draft
owner: Technical Director
last_updated: 2026-08-03
depends_on: [TDD-08-CROWD, TDD-07-SUSPICION]
---

# US-0042 — Shared spatial hash

| | |
|---|---|
| **Milestone** | M3 |
| **Epic** | `EPIC-CROWD-CORE` |
| **Systems** | `SYS-CROWD` |
| **Estimate** | S |
| **Depends on** | US-0041 |

## Description

A uniform grid rebuilt once per tick, shared by four consumers: nearest-NPC queries, blend
validation, startle propagation and gawk token issuance.

The naive alternative is O(pawns x NPCs) in three separate places — 540 distance checks per tick
for suspicion alone.

## Acceptance criteria

- [ ] Cell size 6.0 m, equal to the open-ground radius, so the hottest query touches at most 4 cells.
- [ ] Rebuilt each tick from 90 NPCs with no allocation after warm-up.
- [ ] Provides query, count_within, count_persona and nearest_distance.
- [ ] Query results match brute force for 1000 random queries.
- [ ] Rebuild costs at most 0.15 ms.

## Test notes

`test_spatial_hash_correctness.gd` compares against brute force.

## Notes

Not double-buffered. Suspicion must see THIS tick's crowd, not last tick's — a player accruing
alone-suspicion inside a pocket that has already re-formed is the silent failure this ordering
exists to prevent. Rebuild is cheap enough that correctness wins.
