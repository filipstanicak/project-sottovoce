## **WHERE THE NINETY START.** US-0041, TDD-08 §7. SERVER ONLY.
##
## PURE arithmetic over a navigation map: anchors and a seed in, one position per
## NPC out. No pool, no bodies — so "are they spread out?" and "are they all on
## the navmesh?" are questions a test can ask without standing a crowd up.
##
## **EVERY POSITION IS SNAPPED TO THE NAVMESH, AND THAT IS THE WHOLE JOB.** An
## NPC placed a metre off the mesh is an NPC its agent can never path away from:
## it stands there for the entire match, which reads as a broken NPC rather than
## a broken *placement*, and one of those is far harder to find than the other.
##
## **SPREAD FROM THE IDLE ANCHORS RATHER THAN UNIFORMLY.** A uniform scatter over
## a 120 × 120 m district would put NPCs in the middle of streets and none of
## them anywhere a person would actually stand. The anchors are where GDD-05 says
## the city gathers — benches, stalls, well edges — so starting there means the
## crowd's first frame already looks like a city rather than a spill.
class_name CrowdPlacement
extends RefCounted

## How far from its anchor an NPC may start. Wide enough that a popular anchor
## does not stack four NPCs on one point, tight enough that they still read as
## *at* it.
const SCATTER := 3.0

## How far a snap may move a point before it is refused. A position that lands
## this far from where it was asked for is on a different surface — across a
## canal, or on the wrong side of a wall — and would be worse than not placing.
const MAX_SNAP := 6.0


## One position per NPC, all on the navigation map.
##
## **DETERMINISTIC FROM THE SEED**, like the roster: two servers given the same
## seed place the same crowd, which is what lets a replay be a replay. Anchors
## are visited round-robin so a district with 62 anchors and 78 NPCs gets an even
## spread rather than sixty at the first anchor and the rest wherever.
static func positions(count: int, match_seed: int, anchors: Array, map: RID) -> PackedVector3Array:
	var out := PackedVector3Array()
	if anchors.is_empty():
		return out

	var rng := RandomNumberGenerator.new()
	rng.seed = hash(match_seed) ^ 0x9E3779B9

	for index: int in count:
		var anchor: Vector3 = anchors[index % anchors.size()]
		var wanted := (
			anchor
			+ Vector3(rng.randf_range(-SCATTER, SCATTER), 0.0, rng.randf_range(-SCATTER, SCATTER))
		)
		out.append(_snapped(wanted, anchor, map))
	return out


## `wanted` moved onto the navmesh, or the anchor itself if the snap would travel
## further than `MAX_SNAP`.
##
## Falling back to the anchor rather than to `wanted` matters: an anchor is a
## point the level author chose, so it is on the mesh by construction, whereas
## `wanted` is a random offset that may be inside a wall.
static func _snapped(wanted: Vector3, anchor: Vector3, map: RID) -> Vector3:
	# **NO MAP MEANS NOTHING TO SNAP TO, NOT "GIVE UP ON THE SCATTER".** The first
	# version returned the anchor here, which threw the offset away and stacked
	# every NPC on its anchor — the seed stopped mattering and a crowd of 78
	# occupied 20 points. Caught by the spread test, which is the only assertion
	# that could see it, because on a live map the path is never taken.
	if not map.is_valid():
		return wanted
	var snapped := _street_point(map, wanted)
	if _is_reasonable(snapped, wanted, anchor):
		return snapped
	var fallback := _street_point(map, anchor)
	return fallback if _is_reasonable(fallback, anchor, anchor) else anchor


## The nearest navmesh point to `at`, **asked for from below it**.
##
## `map_get_closest_point` is a 3D nearest-polygon query with no idea of
## connectivity, so a point inside a market stall's footprint answers with the
## stall's *top* — a real navmesh polygon, 0.9 m up, that `NAV_MAX_CLIMB` has
## disconnected from everything. An NPC placed there is on the navmesh, on the
## floor, and can never leave: Npc003 stood on StallA for every run of
## `test_crowd_moves.gd` until this function existed.
##
## Probing from `H_VAULT` below biases the query toward the street: directly under
## a stall the top is 2.2 m from the probe and the street at the stall's edge is
## about 1.6, so the answer comes out beside the stall rather than on it. On open
## ground it changes nothing — the nearest point is still directly above.
static func _street_point(map: RID, at: Vector3) -> Vector3:
	var probe := Vector3(at.x, at.y - VetraioLayout.H_VAULT, at.z)
	return NavigationServer3D.map_get_closest_point(map, probe)


## Is `point` a sane answer for something asked for at `wanted`, near `anchor`?
##
## **`map_get_closest_point` IGNORES CONNECTIVITY, AND THAT PUT AN NPC ON A MARKET
## STALL.** A stall counter is `H_VAULT` 0.9 m of flat, clearance-having surface,
## so Recast bakes its top as a polygon; `NAV_MAX_CLIMB` leaves that polygon
## *disconnected*, which stops anything pathing there — and does nothing at all to
## stop the nearest-point query snapping onto it. Npc003 spent every run standing
## on StallA at (38.3, 0.90, 18.6), on the navmesh, unable to leave it, which is
## the precise failure this file's own docstring exists to prevent.
##
## The height gate is `H_VAULT` because that is the design's own line: 0.9 m is
## what a player has to **vault** onto, and nothing a player has to vault onto is
## somewhere a civilian was placed. The navmesh's own 0.4 m rise above the street
## sits comfortably below it and a stall's 1.3 m comfortably above.
static func _is_reasonable(point: Vector3, wanted: Vector3, anchor: Vector3) -> bool:
	if point.distance_to(wanted) > MAX_SNAP:
		return false
	return absf(point.y - anchor.y) < VetraioLayout.H_VAULT
