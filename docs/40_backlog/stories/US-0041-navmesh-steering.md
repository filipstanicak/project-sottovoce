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

> **Five of six. The one that is not ticked was blocked on US-0045 and is now merely
> unstarted** — the bands exist as of 2026-08-16.

- [x] **Agent radius 0.4 m, height 1.8 m, max slope 35 degrees.** And they **survived
      quantisation**, which is the part that nearly went wrong — see below.
- [x] **Navmesh covers every street-level area a player can reach.** 2011 points sampled on
      US-0041's own 2 m grid; **17 uncovered, 0.85 %**. The remainder are where the canal cuts a
      floor rectangle and where stalls stand on one.
- [x] **Roofs, balconies, the canal and the campanile are EXCLUDED from the navmesh.** Excluded
      by never being offered to the baker rather than carved out afterwards — a filter that runs
      second can be forgotten. Asserted per block roof, on the Loggia balcony, and across the
      canal.
- [x] **Steering handles avoidance and slot seeking, and knows nothing about brain states.**
      Every entry point on `Steering` takes a point and a speed;
      `test_steering_knows_no_states.gd` scans the file for `NpcBrain`, `State.` and `brain`, and
      is falsified against a planted violation. `CrowdDirector._goal_for()` and `_speed_for()` are
      the only places a state becomes either.
- [x] **Repath requests are staggered, at most 3 per tick.** `RepathQueue` is pure and FIFO, and
      `TUN-PERF-CROWD-REPATH-PER-TICK` is the cap. A 90-NPC crowd is served in exactly 30 ticks,
      asserted; so is "everybody exactly once", which is the starvation half.
- [ ] **Far-band agents get longer path validity.** **No longer blocked — unstarted.**
      US-0045 built the bands and `CrowdDirector.band_of(index)` answers; what is missing is one
      line giving a Far agent a larger `NavigationAgent3D.path_max_distance` so it recomputes its
      route less often. Left undone rather than slipped into US-0045, which had no criterion for
      it.

## The crowd walks at 1.400 m/s against a stroll of 1.400

That is the assertion this story is actually about, and it is not the obvious one. "The NPCs
moved" is satisfied by NPCs moving at any speed at all — and the speed is the crowd's one
load-bearing number, because invariant 1 forces `TUN-CROWD-NPC-SPEED-STROLL` to equal
`TUN-SPEED-BLENDWALK` precisely so a blend-walking player is indistinguishable from the crowd by
motion. A crowd walking at some other speed passes every other test in the file and is a silent
`RISK-ANONYMITY-LEAK`, found eventually by a playtester saying the clones "look slow".

Two ways it nearly happened, both measured rather than reasoned about:

- **`NavigationAgent3D` emits `velocity_computed` every physics frame** once avoidance is on —
  nine callbacks over ten frames after a *single* `set_velocity()`. The safe velocity is therefore
  applied there, at 60 Hz, while the desired velocity is chosen at the 30 Hz net tick. Driving the
  body from the tick instead would have halved every NPC's speed in silence, because
  `move_and_slide()` always integrates by the **physics** delta whatever rate it is called at.
- **RVO may pick any velocity up to `max_speed`, not up to the one it was asked for.** With
  `max_speed` left at the flee speed, a *strolling* NPC dodging a neighbour sidestepped at
  **2.24 m/s against a stroll of 1.4** — a civilian moving faster than a civilian can, which
  would have shipped as "the clones look twitchy". `max_speed` is now set from the state's own
  speed on every `drive()`, with a 0.1 m/s floor so a standing NPC is still *shovable*: at exactly
  zero, a walking group would walk through an idle cluster instead of round it.

## An NPC spent every run standing on a market stall

`Npc003` at (38.3, **0.90**, 18.6) — inside StallA's footprint, on top of the counter, on the
navmesh, on the floor, and unable to leave. It is the exact failure `CrowdPlacement`'s own
docstring says it exists to prevent, wearing a disguise: the NPC was not *off* the mesh, it was on
a piece of mesh nothing can reach.

**`map_get_closest_point` is a 3D nearest-polygon query and knows nothing about connectivity.** A
stall counter is 0.9 m of flat surface with clearance above it, so Recast bakes its top as a
polygon; `agent_max_climb` decides whether that polygon is *linked* to the street and does nothing
whatever to stop a nearest-point query landing on it.

Three things changed, and only the third is the fix:

1. **`NAV_MAX_CLIMB` is declared at 0.4 rather than left at Godot's default.** The default is
   0.25, which Recast ceils to 0.4 against a 0.2 cell anyway, so this pins what was already
   happening — in the same spirit as `NAV_CELL_SIZE`. It is what keeps stall tops
   *disconnected*: the reachability check is falsified by rebaking at 0.9, where four of six
   stalls become reachable and the mesh grows from 195 polygons to 252.
2. **A snap that rises by more than `H_VAULT` is refused.** 0.9 m is the design's own line —
   what a player has to *vault* onto is not somewhere a civilian is placed.
3. **The snap is asked for from `H_VAULT` below the point.** Under a stall, the top is 2.2 m from
   that probe and the street at the stall's edge is about 1.6, so the answer comes out beside the
   stall. On open ground it changes nothing. Without this, the refusal in (2) merely fell back to
   the raw anchor — and the anchors in a stall row *are* partly inside stalls, so the NPC was
   placed in solid geometry and pushed out on top of it, which looked identical.

**The idle anchors themselves are still generated on a grid with no obstacle filter**, so some sit
inside stalls and blocks. That is a level-generation defect rather than a crowd one, and filtering
them would change the per-zone anchor density `test/unit/core/map/test_navmesh_coverage.gd`
asserts. Recorded here rather than fixed here.

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
| `test_crowd_moves.gd` | The agent is on the shipped NPC scene and configured from the capsule and from tuning; **the crowd walks at the stroll speed and not at half or twice it**; no tick exceeds the repath budget; everybody is given somewhere to go; nobody hovers, falls through or stands on a stall; an idle NPC stands still; a startled one is sent *away* from what scared it |
| `test_repath_queue.gd` | At most three a tick; 90 served in exactly 30 ticks; everybody exactly once; FIFO; a repeat request takes no extra slot; a non-positive budget stops the crowd rather than uncapping it |
| `test_steering_knows_no_states.gd` | `steering.gd` names no brain and no state, falsified against a planted `if brain.state == NpcBrain.State.STARTLE` |
| `test_crowd_is_wired_into_the_server.gd` | The NPC scene has an agent, the server scene has a `CrowdDirector`, and `server_root.gd` **registers** it |

`test_navmesh_coverage.gd` is an **integration** test: the baked resource is only half the claim,
and a mesh that loads but never syncs into a navigation map is a mesh nothing can path on.

## What steering does not do yet, said plainly

Only **Stroll** and **Idle** can be reached in a running match. Nothing assigns a formation slot
(US-0043), nothing grants a gawk token and nothing sets `startle_flag` (US-0044). Startle's goal
and speed are implemented and tested by setting the flag by hand, because the steering layer is
what US-0044 hangs off — but a crowd that strolls between anchors and stands at them is what a
server actually runs this milestone.

There is also **no LOD**: every active NPC steps every tick, 78 brains rather than TDD-08
§4.1's ~34. The bands are US-0045's, and inventing them here would put a distance check inside
the crowd's hot path that `test_lod_changes_rate_not_logic.gd` would later have to find and
remove.

Two deviations from TDD-08 §8's sketch, both deliberate: `CrowdDirector extends GameSystem`
rather than `Node`, so `MatchDirector` ticks it in `SystemOrder`'s order; and `setup()` takes only
`MatchContext`, because the map and the seed are on it. US-0043 adds `_rebalance()`, the circuits
and the slots to the same class.

## Notes

The navmesh boundary and the roof suspicion penalty describe the same design fact: NPCs cannot
reach roofs, which is precisely why standing there costs anonymity.

Steering is the one place permitted to cache tuning values, because per-agent autoload lookups
across 90 agents measured above the ADR-0005 threshold. Refresh on LOD transition and reload.
