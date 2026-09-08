## Shared pawn navigation dimensions and static bake limits. No autoload dependencies.
## MapBuild and runtime clearance checks consume the same contract on every map.
class_name PawnNavigation
extends RefCounted

## --- NAVMESH BAKE PARAMETERS. TDD-08 §7. ---
##
## **DELIBERATELY NOT TUNABLES, AND THE REASON IS NOT LAZINESS.** TDD-08 §7 says
## the navmesh is baked from static geometry and **never rebaked at runtime**. A
## `TUN-` value that did nothing until somebody re-ran a tool would be worse than
## a constant: never-do #1 exists so that changing a number changes the game, and
## a tunable that silently does not is the exact failure it guards against.
##
## Shared by every map: pawn clearance and bake resolution must agree on the
## district and the sandbox.
const NAV_AGENT_RADIUS := 0.4

## 1.8 m — the NPC capsule, and the player's.
const NAV_AGENT_HEIGHT := 1.8

## 35°, above the 30° stair angle so stairs are navigable and roofs are not.
const NAV_MAX_SLOPE := 35.0

## **HOW HIGH A STEP A CIVILIAN CAN TAKE, AND THE REASON MARKET STALLS ARE NOT
## FURNITURE.** Godot's default is 0.9, which is exactly the height of a stall
## counter — so the baker connected every stall top to the street and the crowd
## treated them as walkable. Measured, not reasoned about: an NPC ended a run
## standing on StallA at (38.3, 0.90, 18.6).
##
## An NPC standing on a market stall is wrong twice over. It reads as a broken
## civilian, and 0.9–1.1 m is the **vault** band — the stalls are the things a
## player vaults, and a crowd that could stand on them would quietly make being
## up there ordinary. Two cells, so Recast's quantisation leaves it alone.
const NAV_MAX_CLIMB := 0.4

## The band the navmesh may be baked from: the street stratum and nothing above
## it. **This is the same design fact as `TUN-SUSPICION-GAIN-ROOF`** — NPCs cannot
## reach roofs or balconies, which is precisely why standing there costs
## anonymity. Baking a roof would quietly refund that cost.
const NAV_BAKE_FLOOR := -2.0
const NAV_BAKE_CEILING := 2.5

## **THE VOXEL SIZE THE BAKER ACTUALLY WORKS IN, AND IT MUST DIVIDE THE AGENT
## DIMENSIONS EXACTLY.** Recast quantises `agent_radius` and `agent_height` to
## whole cells and **ceils** them, so at Godot's default 0.25 the 0.4 m radius
## bakes as 0.5 and the 1.8 m height as 2.0 — the mesh would not be the mesh
## TDD-08 §7 specifies, and nothing but a warning would say so.
##
## 0.2 divides both: 0.4 / 0.2 = 2 cells, 1.8 / 0.2 = 9. Finer cells cost bake
## time and polygons, which is a build-time cost and therefore the cheap side of
## the trade.
const NAV_CELL_SIZE := 0.2
const NAV_CELL_HEIGHT := 0.2
