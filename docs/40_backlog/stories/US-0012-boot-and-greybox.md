---
id: US-0012
title: Boot scene, server flag, greybox map loads
version: 0.1.0
status: draft
owner: Technical Director
last_updated: 2026-08-03
depends_on: [TDD-12-BUILD, GDD-05-LEVEL]
---

# US-0012 — Boot scene, server flag, greybox map loads

| | |
|---|---|
| **Milestone** | M0 |
| **Epic** | `EPIC-BOOT` |
| **Systems** | `SYS-MAP` |
| **Estimate** | **L** |
| **Depends on** | US-0008, US-0011 |

## Description

`boot.tscn` with the server branch, the two root scenes, and the greybox MAP-VETRAIO blockout
with navmesh, spawns, anchors, circuits and zone volumes authored as MapData.

This story closes M0. Its exit criterion is the milestone exit criterion.

## Acceptance criteria

- [ ] `boot.tscn` branches on --server to server_root.tscn, else client_root.tscn.
- [ ] CLI flags parse: --server, --port, --max-players, --connect, --seed.
- [ ] server_root.tscn contains no presentation nodes.
- [ ] Greybox MAP-VETRAIO built to the GDD-05 section 2 layout using the section 7.4 material set.
- [ ] MapData populated: 6 spawns, 4 circuits, idle anchors, zone volumes, 5 blend props, 2 theatre spaces.
- [ ] Navmesh baked; roofs, balconies and the canal excluded.
- [ ] `test_map_metrics.gd`, `test_map_dead_ends.gd` and `test_map_widths.gd` pass.
- [ ] MAT-VOID appears nowhere.

## Test notes

`test_navmesh_coverage.gd` samples street-level playable area on a 2 m grid.
`test_server_flag.gd` asserts topology per flag.

## Notes

Geometry must avoid the metrics boundary bands — a surface at 1.10 m resolves as vault or mantle
by sub-centimetre position, which reads to a player as the game being broken.
