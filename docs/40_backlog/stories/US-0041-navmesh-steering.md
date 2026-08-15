---
id: US-0041
title: Navmesh, agents and steering
version: 1.0.0
status: in-progress
owner: Technical Director
last_updated: 2026-08-16
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

> **Three of six. The navmesh half is done and the steering half is not started** —
> said plainly rather than spread across half-finished code. See the closing section.

- [x] **Agent radius 0.4 m, height 1.8 m, max slope 35 degrees.** And they **survived
      quantisation**, which is the part that nearly went wrong — see below.
- [x] **Navmesh covers every street-level area a player can reach.** 2011 points sampled on
      US-0041's own 2 m grid; **17 uncovered, 0.85 %**. The remainder are where the canal cuts a
      floor rectangle and where stalls stand on one.
- [x] **Roofs, balconies, the canal and the campanile are EXCLUDED from the navmesh.** Excluded
      by never being offered to the baker rather than carved out afterwards — a filter that runs
      second can be forgotten. Asserted per block roof, on the Loggia balcony, and across the
      canal.
- [ ] **Steering handles avoidance and slot seeking, and knows nothing about brain states.** Not
      started. No `NavigationAgent3D` on `npc_server.tscn` yet and nothing ticks a brain, so
      steering would have neither a driver nor an agent to steer.
- [ ] **Repath requests are staggered, at most 3 per tick.** Part of the same steering layer.
- [ ] **Far-band agents get longer path validity.** Needs the LOD bands, which are
      **US-0045's** — TDD-08 §4.1 defines Near/Mid/Far at 20/45/70 m and nothing computes them
      yet. Blocked rather than merely unstarted.

## The navmesh existed only as a promise until now

US-0012 ticked *"Navmesh baked; roofs, balconies and the canal excluded"* and its own note said
the runtime bake was **"recorded as owed rather than claimed"** — a ticked criterion and a note
saying it was not done, in the same story. The exclusions were declared in `MapData` and asserted;
the mesh itself never existed.

TDD-08 §7 says **"Rebake: never at runtime — static geometry only"**, which is what resolves it:
the bake is a build-time operation, so it belongs in the map generator and is committed like the
scenes. Baking at startup instead would cost every server seconds of a countdown it does not have,
and would make a *level* defect appear as a *networking* one — clients waiting on a server that
looks hung.

**The generator had to be deferred by one frame to do it.** `_init()` fires while the `SceneTree`
is still being constructed: a node added to the root there is not yet *inside* the tree, and
`parse_source_geometry_data` refuses it. That single frame is the whole reason US-0012 recorded
the bake as owed.

## The agent dimensions were being silently changed

Setting `agent_radius = 0.4` does not mean the mesh is baked for a 0.4 m agent. **Recast quantises
the agent dimensions to whole voxels and ceils them**, so at Godot's default 0.25 cell size the
0.4 m radius bakes as **0.5** and the 1.8 m height as **2.0** — and only a warning says so.

Ticking criterion 1 on the property values would have been false. `NAV_CELL_SIZE` and
`NAV_CELL_HEIGHT` are 0.2, which divides both exactly (2 cells and 9), and the test asserts the
quotients are whole rather than trusting the properties.

**The bake parameters are deliberately not tunables.** TDD-08 §7 says the mesh is never rebaked at
runtime, so a `TUN-` value that did nothing until somebody re-ran a tool would be *worse* than a
constant: never-do #1 exists so that changing a number changes the game, and a tunable that
silently does not is the failure it guards against. They live in `VetraioLayout`, the map's single
source.

## Two hours went to one lesson about the navigation server

**An unsynced navigation map answers every query with the origin.** Not an error, not a null — the
origin. The first version of the coverage test reported **2011 of 2011 street points unreachable**,
which is a timing defect wearing a level defect's clothes and the most convincing possible way to
look like a broken bake.

- `map_force_update()` alone does nothing.
- Waiting for `map_get_iteration_id` to advance **once** breaks a step early: the first iteration
  registers the region, the second rasterises it. Measured 0 → 1 → 2, usable only at 2.
- Querying before the first synchronisation is an **error**, so polling with
  `map_get_closest_point` fills the log with failures on the way to succeeding.
- `before_all()` cannot hold the wait: its coroutine returns at the first `await` and the tests run
  anyway — which is why the **last** test in the file passed while the first did not.

The same wait had to go into `server_root._place_the_crowd`, for the same reason and with the same
consequence: without it every NPC snaps to (0, 0, 0) and the crowd stacks in one corner.

Also fixed: the navigation **map's** `cell_height` defaults to 0.25 and must be set to the mesh's,
or the engine warns about rasterisation errors on mesh edges.

## Placement, which is not a criterion here but had nowhere else to live

There is **no spawn-distribution story anywhere in M3**. Placement belongs with the navmesh
because a position that is not on the navmesh is a position an agent can never path away from —
an NPC that stands still for the whole match, which reads as a broken NPC rather than a broken
placement.

`CrowdPlacement` spreads the crowd round-robin over `MapData.idle_anchors` with a seeded scatter,
snapping each point onto the mesh. Anchors rather than a uniform scatter, because a uniform spread
over 120 × 120 m puts NPCs in the middle of streets and nobody anywhere a person would stand.

A real server now logs `crowd placed: 78 NPCs across 62 anchors`.

**Its first version threw the scatter away.** With no navigation map the snap fell back to the
anchor, which discarded the offset entirely: the seed stopped mattering and 78 NPCs occupied 20
points. Caught by the spread assertion — the only one that could see it, because on a live map
that path is never taken.

## Test notes

| Test | Asserts |
|---|---|
| `test_navmesh_coverage.gd` | The mesh loads and the map syncs; **the agent dimensions survived quantisation**; 2011 street points on a 2 m grid with under 15 % uncovered (measured 0.85 %); no block roof, no balcony and no canal crossing is navigable |
| `test_crowd_placement.gd` | One position per NPC; deterministic from the seed and **different for a different seed**; anchors used round-robin; nobody starts beyond the scatter; **not stacked on a handful of points**; no anchors places nobody rather than crashing |

`test_navmesh_coverage.gd` is an **integration** test: the baked resource is only half the claim,
and a mesh that loads but never syncs into a navigation map is a mesh nothing can path on.

## Notes

The navmesh boundary and the roof suspicion penalty describe the same design fact: NPCs cannot
reach roofs, which is precisely why standing there costs anonymity.

Steering is the one place permitted to cache tuning values, because per-agent autoload lookups
across 90 agents measured above the ADR-0005 threshold. Refresh on LOD transition and reload.
