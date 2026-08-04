---
id: US-0041
title: Navmesh, agents and steering
version: 0.1.0
status: draft
owner: Technical Director
last_updated: 2026-08-03
depends_on: [TDD-08-CROWD, GDD-05-LEVEL]
---

# US-0041 — Navmesh, agents and steering

| | |
|---|---|
| **Milestone** | M3 |
| **Epic** | `EPIC-CROWD-CORE` |
| **Systems** | `SYS-CROWD` |
| **Estimate** | M |
| **Depends on** | US-0040 |

## Description

Navigation agents and the dumb steering layer beneath the state machine — local avoidance and
formation-slot seeking, with no knowledge of states.

## Acceptance criteria

- [ ] Agent radius 0.4 m, height 1.8 m, max slope 35 degrees.
- [ ] Navmesh covers every street-level area a player can reach.
- [ ] Roofs, balconies, the canal and the campanile are EXCLUDED from the navmesh.
- [ ] Steering handles avoidance and slot seeking, and knows nothing about brain states.
- [ ] Repath requests are staggered, at most 3 per tick, to avoid spikes.
- [ ] Far-band agents get longer path validity.

## Test notes

`test_navmesh_coverage.gd` samples street-level playable area on a 2 m grid and asserts no roof
or balcony is navigable.

## Notes

The navmesh boundary and the roof suspicion penalty describe the same design fact: NPCs cannot
reach roofs, which is precisely why standing there costs anonymity.

Steering is the one place permitted to cache tuning values, because per-agent autoload lookups
across 90 agents measured above the ADR-0005 threshold. Refresh on LOD transition and reload.
