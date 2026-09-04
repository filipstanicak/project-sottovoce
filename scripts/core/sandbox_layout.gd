## **`MAP-SANDBOX`: A 40 m COURTYARD FOR REPRODUCING THINGS IN TEN SECONDS.**
## PURE. DEBUG ONLY — excluded from every release preset, and nothing in a shipped
## match may load it. Added 2026-09-04.
##
## **IT EXISTS BECAUSE `MAP-VETRAIO` IS THE WRONG INSTRUMENT FOR A DEFECT.** The
## district is 120 x 120 m with 78 civilians and six spawn points, and every defect
## reported from the controls this week cost minutes of walking to reach the
## arrangement that showed it. Nothing here is a design statement about the game;
## it is a bench.
##
## **EVERY SOLID IN IT IS HERE FOR A NAMED REASON**, which is the difference between
## a test fixture and a doodle:
##
## - **The courtyard** is one flat 40 m slab. Two spawn points are 15 m apart, so a
##   hunter and a prey meet inside ten seconds of blend-walk rather than a minute of
##   crossing a district.
## - **`CentreBlock`** breaks the sightline across the middle. Without it the
##   Compass never has anything to point around, a chase can never be opened and
##   broken, and `TUN-PURSUIT-DURATION` cannot be reached at all.
## - **The nook** is a deliberate corner trap with a single 2 m mouth. A hunting bot
##   walked into one on 2026-09-04 and stayed there, and the fix for that is only as
##   good as somewhere to reproduce it.
## - **The two stalls** are `H_VAULT` high, which is the one band whose only
##   geometry in the district is a market stall — the band that hid the floor-height
##   defect for three milestones.
##
## **AND WHAT IT DELIBERATELY HAS NOT GOT**: zones, circuits, theatre spaces, blend
## props and a canal. A procession needs a district to walk around, and a bench that
## modelled one would be a second map to keep in step with the first.
class_name SandboxLayout

## The courtyard is square and this is its side. Read by the navmesh bake's filter
## AABB, so it is the map's extent rather than a decorative number.
const MAP_SIZE := 40.0

## Walls are built **outside** the floor, so the walkable width is exactly `MAP_SIZE`.
const WALL_HEIGHT := 3.0
const WALL_THICKNESS := 1.0

## name, x, z, width, depth, surface y, material. **`y` IS THE WALKABLE SURFACE**,
## and the slab hangs below it — `MapBuild.FLOOR_THICKNESS`. Straddling it instead
## is what put the whole district 0.1 m high and made every stall unvaultable.
const FLOORS: Array = [
	["Courtyard", 0.0, 0.0, MAP_SIZE, MAP_SIZE, VetraioLayout.STREET_Y, "MAT-GREY-FLOOR"],
]

## name, x, z, width, depth, height, material. Minimum corner, never the centre.
const BLOCKS: Array = [
	# The perimeter. A player who can walk off the edge is a player falling out of
	# the world, which `test_the_district_is_enclosed.gd` exists to refuse.
	["WallSouth", -1.0, -1.0, MAP_SIZE + 2.0, WALL_THICKNESS, WALL_HEIGHT, "MAT-GREY-WALL"],
	["WallNorth", -1.0, MAP_SIZE, MAP_SIZE + 2.0, WALL_THICKNESS, WALL_HEIGHT, "MAT-GREY-WALL"],
	["WallWest", -1.0, 0.0, WALL_THICKNESS, MAP_SIZE, WALL_HEIGHT, "MAT-GREY-WALL"],
	["WallEast", MAP_SIZE, 0.0, WALL_THICKNESS, MAP_SIZE, WALL_HEIGHT, "MAT-GREY-WALL"],
	# Something to lose sight of somebody behind.
	["CentreBlock", 17.0, 17.0, 6.0, 6.0, 4.0, "MAT-GREY-WALL"],
	# The corner trap: a pocket at x 27-40, z 31-40 with one 2 m mouth at x 38-40.
	["NookWall", 26.0, 30.0, 12.0, WALL_THICKNESS, WALL_HEIGHT, "MAT-GREY-WALL"],
	["NookSide", 26.0, 31.0, WALL_THICKNESS, 9.0, WALL_HEIGHT, "MAT-GREY-WALL"],
]

## name, x, z, width, depth. Height is `TUN-TRAVERSE-VAULT-*`'s band, from
## `VetraioLayout.H_VAULT`, so a vault here is the vault the district has.
const STALLS: Array = [
	["StallWest", 8.0, 12.0, 4.0, 2.0],
	["StallEast", 28.0, 12.0, 4.0, 2.0],
]

## Four, and **two of them are 15.3 m apart on purpose**. `SpawnRules` wants 40 m
## between a victim and their killer, which a 40 m courtyard cannot give — so a
## respawn here always takes rule 7's fallback. That is a property of the bench and
## is said out loud in `MAP_SANDBOX.md`, because a rule silently taking its escape
## hatch every time is how a bench teaches the wrong lesson.
const SPAWNS: Array = [
	["S1", 5.0, 5.0],
	["S2", 35.0, 5.0],
	["S3", 5.0, 35.0],
	["S4", 20.0, 8.0],
]

## The idle-anchor grid. Derived rather than listed, for `VetraioLayout`'s own
## reason: a hand-listed point inside a wall is an NPC that can never walk away.
const ANCHOR_STEP := 6.0
const ANCHOR_MARGIN := 5.0


## Every anchor the grid offers that a body could actually stand on. Filtered
## against the blocks and the stalls with `NAV_AGENT_RADIUS` of clearance, because
## the navmesh is eroded by exactly that and a point against a face is **off** it —
## which `map_get_closest_point` then answers by snapping to whatever is inside the
## block, an anchor that looks placed and can never be left.
static func anchors() -> Array[Vector3]:
	var out: Array[Vector3] = []
	var at := ANCHOR_MARGIN
	while at <= MAP_SIZE - ANCHOR_MARGIN:
		var across := ANCHOR_MARGIN
		while across <= MAP_SIZE - ANCHOR_MARGIN:
			if is_standable(Vector2(at, across)):
				out.append(Vector3(at, VetraioLayout.STREET_Y, across))
			across += ANCHOR_STEP
		at += ANCHOR_STEP
	return out


## True when a body of `NAV_AGENT_RADIUS` fits at `point` — inside the courtyard and
## clear of every solid. The same question `VetraioGround.is_standable` answers for
## the district, asked of a table this one can hold in one screen.
static func is_standable(point: Vector2) -> bool:
	var r := VetraioLayout.NAV_AGENT_RADIUS
	if point.x < r or point.y < r or point.x > MAP_SIZE - r or point.y > MAP_SIZE - r:
		return false
	for b: Array in BLOCKS:
		if _grown(b[1], b[2], b[3], b[4], r).has_point(point):
			return false
	for s: Array in STALLS:
		if _grown(s[1], s[2], s[3], s[4], r).has_point(point):
			return false
	return true


static func _grown(x: float, z: float, w: float, d: float, by: float) -> Rect2:
	return Rect2(x - by, z - by, w + by * 2.0, d + by * 2.0)
