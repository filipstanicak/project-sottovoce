## **AN NPC BELOW THE WORLD IS A STATE NOTHING HAS A MEANING FOR.** US-0041.
## SERVER ONLY.
##
## Reported twice from the controls: first as NPCs "floating" over a hole instead
## of dropping, then as NPCs standing inside a wall. **Both were the same four
## bodies.** Members of `CIRC-B`'s procession walk off the Loggia's north edge at
## z = 54, where the floor ends, and fall for the rest of the match — measured at
## **y −140 to −207 m and still accelerating at −52 to −64 m/s**, drifting under
## `MercatoNorthWall`'s footprint on the way down.
##
## **THE CLIENT CANNOT DRAW THE TRUTH ABOUT THEM.** `Quantise.height_to_u8` spans
## 0 to 12.75 m, so −207 encodes as **0** and the body is drawn standing on the
## street inside masonry. The clamp is right — its own comment says pinning is
## debuggable where wrapping would put a market NPC on a rooftop — but it disguises
## a server defect as a rendering one, which is why this took two reports.
##
## **THIS IS NOT THE FIX FOR THE CAUSE AND MUST NOT BE MISTAKEN FOR ONE.** The cause
## is that 14-28 % of every procession route runs over ground that does not exist,
## which `test_circuit_separation.gd` reports and which re-authoring the four routes
## is the answer to. What this buys is three things the cause does not: the crowd
## stops draining, the client stops being told a lie, and **the count is a number
## somebody can read** rather than a district that quietly empties.
##
## `rescued` must be **zero** on a district whose routes are walkable. A number here
## is a level-data defect reporting itself.
class_name CrowdRescue
extends RefCounted

## How many bodies have been put back, for the whole match. Diagnostics only —
## nothing reads it to make a decision.
var rescued: int = 0

## Where the last few went over, in x/z. **The count alone cannot name a cause** —
## it says the district leaks without saying where the hole is, and the first
## re-authoring of the routes left it leaking at nineteen bodies a minute with every
## route measuring fully walkable.
var fell_at: Array[Vector2] = []


## Put back anything that has fallen below the world, and count it.
##
## **THE FLOOR IS `NAV_BAKE_FLOOR`**, the depth the navmesh bake already treats as
## below the district — derived rather than chosen, so a map that moves its ground
## carries this with it.
##
## The destination is a map anchor picked by index, never a player and never the
## origin: an NPC reappearing at (0, 0, 0) would put the whole crowd in one corner
## the first time a route broke, which is the failure `CrowdPlacement`'s scatter
## exists to prevent.
func sweep(pool: NpcPool, map: MapData) -> void:
	if pool == null or map == null or map.idle_anchors.is_empty():
		return
	for index: int in pool.active_count():
		var body := pool.body_of(index)
		if body == null or body.global_position.y > VetraioLayout.NAV_BAKE_FLOOR:
			continue
		rescued += 1
		var over := body.global_position
		fell_at.append(Vector2(over.x, over.z))
		while fell_at.size() > 24:
			fell_at.remove_at(0)
		body.velocity = Vector3.ZERO
		body.global_position = map.idle_anchors[index % map.idle_anchors.size()]
