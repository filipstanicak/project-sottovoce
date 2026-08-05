---
id: US-0017
title: Traversal probes
version: 1.0.0
status: done
owner: Technical Director
last_updated: 2026-08-05
depends_on: [TDD-06-PAWN, GDD-02-PLAYER]
---

# US-0017 — Traversal probes

| | |
|---|---|
| **Milestone** | M1 |
| **Epic** | `EPIC-TRAVERSAL` |
| **Systems** | `SYS-TRAVERSAL` |
| **Estimate** | M |
| **Depends on** | US-0016 |

## Description

Three forward raycasts at chest, waist and foot plus one downward gap probe, refreshed once per
physics frame into a ProbeResult.

## Acceptance criteria

- [x] Probe origins at 1.35, 0.85 and 0.25 m; length 0.9 m, all from tunables.
- [x] A downward probe from 0.6 m ahead, 5 m deep, distinguishes gap from drop.
- [x] Probes mask the WORLD layer ONLY — not PAWN, not NPC.
- [x] ProbeResult exposes waist_hit, chest_hit, foot_clear, ground_ahead, gap_distance, obstacle_top, clear_beyond, surface_is_climbable.
- [x] Refreshed once per physics frame, before step().

**The down probe marches.** It starts where the criterion says — `TUN-TRAVERSE-GAP-PROBE-AHEAD`
0.6 m ahead, `TUN-TRAVERSE-GAP-PROBE-DEPTH` 5 m deep — and then steps outward to
`TUN-TRAVERSE-GAP-MAX`. A single cast can only report "no ground right here", which distinguishes
nothing: **every gap and every drop look identical at 0.6 m.** GDD-02 §7.1 asks the probe to tell
a gap from a drop by whether ground is found *within 3.2 m*, and one cast at 0.6 m cannot answer
that question.

## Test notes

`test_probes_mask_world_only.gd` is the important one.

## Notes

Masking WORLD only is a determinism requirement, not an optimisation. Static geometry is
identical on every peer; NPC and player positions are interpolated on clients and authoritative
on the server, so a probe that could hit a moving body would resolve differently on the two
machines and produce a different traversal.

---

## What this story actually found

### 1. The pawn had been falling through the map since US-0016

`MapData.spawn_points` are ground positions. `TUN-TRAVERSE-PROBE-HEIGHT-*` are heights above the
ground. The pawn capsule was **centred on the body origin**, so placing that origin on a spawn
point buried the pawn to the waist, and every probe would have looked from 0.9 m below its feet.

US-0016's own tests could not see it. `test_pressing_forward_actually_moves_the_pawn` asserted
the pawn had travelled more than half a metre — which a pawn dropping through the world satisfies
handsomely. **Distance alone cannot distinguish walking from falling.**

The probes were the first thing to notice, because they reported no floor under a pawn standing
in the middle of the district. Both pawn scenes now raise the capsule by half its height, so the
body origin is the feet and all three sources agree. `test_local_server_pawn_parity.gd` — which
TDD-06 §8 calls the chapter's highest-value test, and which had never been written — asserts the
two scenes stay identical, and `test_client_boot_walks.gd` now asserts the pawn's travel is
horizontal rather than merely nonzero.

### 2. A 4 m façade measured an obstacle top of 0.0

The obstacle-top cast starts at mantle height and looks down, so on anything taller it begins
*inside* the geometry. Godot does not report a shape a ray starts within: the ray passed straight
through the wall and hit the floor beyond.

`0.0` satisfies `obstacle_top <= TUN-TRAVERSE-VAULT-MAX-HEIGHT`. **Every façade in Vetraio would
have resolved as a vault into a wall.** Found by the geometry test, not by reasoning.

Fixed twice over: a "top" at or below foot height is rejected as the floor seen through a wall,
and a separate climb cast measures façade height from `TUN-TRAVERSE-CLIMB-MAX-HEIGHT` — the
ceiling §7.2 case 6 compares against — where it cannot start inside what it is measuring.

### 3. `ProbeResult` had to clear to `INF`, not to zero

Same defect class as the one above, one layer up. The resolver's vault test is
`obstacle_top <= 1.1`, and zero passes it. A result that cleared to zero would report a vault
against empty air on every frame the casts all missed.

The edge test is worse: `foot_clear and not ground_ahead` is satisfied by a *cleared* result, so
an unprobed pawn read as standing at a cliff. `ProbeResult.valid` now says whether a reading was
taken at all, and `at_edge()` requires it — because cases 2 and 3 of §7.2 both throw the pawn off
whatever it is standing on.

### 4. Three prose numbers promoted, one guard rewritten

`TUN-TRAVERSE-GAP-PROBE-AHEAD`, `-DEPTH` and `-STEP`. The step is the resolution at which a
landing edge is found: coarser and a narrow ledge across a gap is missed, finer and it costs
raycasts every frame on every pawn.

`test_pawn_states_stateless.gd` kept a **blacklist** of files under `scripts/pawn/` that were not
states, so every new non-state file failed the guard until someone added a name to it —
`pawn_input_buffer.gd` in US-0016, `traversal/` here. It now derives membership from the
`extends` chain. A list that has to grow to keep a guard quiet is a list that eventually gets a
state added to it by mistake.

Collision layers are named in `scripts/core/collision_layers.gd` and asserted against
`project.godot`, so "masks WORLD only" is a checkable claim rather than a `1` in a script.

## What this story does not do

- **No resolution.** Which manoeuvre a `ProbeResult` implies is US-0018, and nothing here
  anticipates its seven-case priority order. What is delivered is that the numbers it will read
  are the right numbers.
- **No ledge-grab magnetism.** `TUN-TRAVERSE-MAGNET-WINDOW` and `-RADIUS` are US-0018's
  forgiveness half; `ctx.ledge_magnet_ticks` is still unwritten.
- **No vault, mantle, climb or drop states.** US-0019 and US-0020.
