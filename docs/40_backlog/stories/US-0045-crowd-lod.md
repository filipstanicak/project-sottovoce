---
id: US-0045
title: Crowd LOD — update rate and animation
version: 0.1.0
status: draft
owner: Technical Director
last_updated: 2026-08-03
depends_on: [ADR-0003, TDD-08-CROWD, BIBLE-PERF-BUDGET]
---

# US-0045 — Crowd LOD: update rate and animation

| | |
|---|---|
| **Milestone** | M3 |
| **Epic** | `EPIC-CROWD-BEHAVIOUR` |
| **Systems** | `SYS-CROWD` |
| **Estimate** | M |
| **Depends on** | US-0044 |

## Description

Distance-banded update-rate LOD on the server and animation LOD on the client.

## Acceptance criteria

- [ ] Bands at 20 m near, 45 m mid, 70 m far, evaluated per tick as squared-distance compares.
- [ ] Brain rate: every tick near, every third mid, every fifteenth far — about 34 effective updates.
- [ ] LOD changes RATE only. No distance check appears inside `NpcBrain.step()`.
- [ ] Client animation LOD: full tree near, reduced mid, single clip far.
- [ ] Animation LOD NEVER changes silhouette or gait inside the 60 m compass range.
- [ ] Mesh LOD at 100, 50 and 20 percent triangle counts.

## Test notes

`test_lod_changes_rate_not_logic.gd` is a source scan.
`test_anim_lod_silhouette.gd` compares rendered silhouettes at band boundaries within a pixel
threshold.

## Notes

A crowd whose behaviour changed with observer distance would be a crowd that lies, and the crowd
is an information channel.

Mid band sits at 45 m rather than a cheaper 25 m specifically so it still produces a correct
silhouette and walk cycle at the distance players are trying to distinguish clones from humans.
