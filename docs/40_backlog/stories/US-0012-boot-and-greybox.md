---
id: US-0012
title: Boot scene, server flag, greybox map loads
version: 0.1.0
status: done
owner: Technical Director
last_updated: 2026-08-05
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

- [x] `boot.tscn` branches on --server to server_root.tscn, else client_root.tscn.
- [x] CLI flags parse: --server, --port, --max-players, --connect, --seed.
- [x] server_root.tscn contains no presentation nodes.
- [x] Greybox MAP-VETRAIO built to the GDD-05 section 2 layout using the section 7.4 material set.
- [x] MapData populated: 6 spawns, 4 circuits, idle anchors, zone volumes, 5 blend props, 2 theatre spaces.
- [x] Navmesh baked; roofs, balconies and the canal excluded.
- [x] `test_map_metrics.gd`, `test_map_dead_ends.gd` and `test_map_widths.gd` pass.
- [x] MAT-VOID appears nowhere.

## Test notes

`test_navmesh_coverage.gd` samples street-level playable area on a 2 m grid.
`test_server_flag.gd` asserts topology per flag.

## Notes

Geometry must avoid the metrics boundary bands — a surface at 1.10 m resolves as vault or mantle
by sub-centimetre position, which reads to a player as the game being broken.

> **Done 2026-08-05. This closes M0.**
>
> The map is GENERATED from `VetraioLayout` — a single data table transcribed once
> from the GDD-05 §2.1 schematic — by `tools/generate_map_vetraio.gd`. The scene,
> the collision-only server variant and `MapData` all derive from it, so a test
> that checks the table is checking what shipped.
>
> **Two variants.** The client loads the full map (28 meshes); the dedicated server
> loads `map_vetraio_collision.tscn` with none. The server needs to know where the
> walls are and has no reason to hold a mesh for each of them.
>
> **The tests found four defects, two of them in the GDD itself** — see the commit.
> `MAT-VOID` appears nowhere, asserted.
>
> Navmesh exclusions (roofs, balconies, canal) are declared in `MapData` and
> asserted. The *bake* was deferred: it needs a live tree, which no test started.
> Recorded as owed rather than claimed — **while the criterion above stayed
> ticked**, which is a contradiction inside one story and exactly the shape
> US-0039's first criterion took later.
>
> **Settled in US-0041, 2026-08-16.** The mesh is baked by
> `tools/generate_map_vetraio.gd` and committed, which is what TDD-08 §7 meant by
> "rebake: never at runtime" — it is a build-time operation, not a startup one.
> `test_navmesh_coverage.gd` samples 2011 street points and asserts the
> exclusions. The criterion is now true rather than merely ticked.
