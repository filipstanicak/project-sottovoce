## **WHAT IS UNDER YOUR FEET, AND WHERE THE DISTRICT ENDS.** US-0041.
## PURE — rectangles from `VetraioLayout` and arithmetic. No node, no navmesh.
##
## **IT IS ONE CLASS BECAUSE THE COPIES DISAGREED.** Three readers needed "is this
## point walkable": the live census, the circuit test, and now the map generator.
## Two had written their own and **both filtered street floors with `row[6]`** — the
## *material string*, which `float()` parses to `0.0`, which equals `STREET_Y`. So
## neither ever skipped anything and the Loggia balcony at 3.5 m counted as ground.
## The generator sits in a layer that cannot see `tools/`, which is what forced the
## question and is why this lives in Core.
class_name VetraioGround

## How finely an edge is tested for a drop. One metre is finer than any gap in the
## floor table and coarse enough that the whole district resolves in a few thousand
## probes at build time.
const EDGE_STEP := 1.0

## How far outside an edge to look for ground. Half a step: far enough to be clear
## of floating-point seams where two floors meet, near enough that a 1 m ledge is
## not mistaken for a drop.
const EDGE_PROBE := 0.5

## How thick a parapet is, and it sits **outside** the floor rather than on it, so
## the walkable width of a 2.6 m alley mouth is unchanged.
const PARAPET_THICKNESS := 0.4


static func street_floors() -> Array:
	var out: Array = []
	for row: Array in VetraioLayout.FLOORS:
		if is_equal_approx(float(row[5]), VetraioLayout.STREET_Y):
			out.append(row)
	return out


static func on_a_floor(at: Vector2) -> bool:
	for row: Array in street_floors():
		if rect_of(row).has_point(at):
			return true
	return false


static func block_at(at: Vector2) -> String:
	for row: Array in VetraioLayout.BLOCKS:
		if rect_of(row).has_point(at):
			return str(row[0])
	return ""


static func stall_at(at: Vector2) -> String:
	for stall: Array in VetraioLayout.STALLS:
		var r := Rect2(float(stall[1]), float(stall[2]), float(stall[3]), float(stall[4]))
		if r.has_point(at):
			return str(stall[0])
	return ""


## How far `at` is outside the nearest street floor, and which one. **A fall is
## named by the edge it left**, which a count of falls cannot say: nineteen bodies a
## minute went over while every route measured fully walkable, and only the
## positions showed they were leaving at floor seams rather than on the routes.
static func nearest_edge(at: Vector2) -> Array:
	var best := ""
	var nearest := INF
	for row: Array in street_floors():
		var r := rect_of(row)
		var inside := Vector2(
			clampf(at.x, r.position.x, r.end.x), clampf(at.y, r.position.y, r.end.y)
		)
		var gap := at.distance_to(inside)
		if gap < nearest:
			nearest = gap
			best = str(row[0])
	return [nearest, best]


static func rect_of(row: Array) -> Rect2:
	return Rect2(float(row[1]), float(row[2]), float(row[3]), float(row[4]))


## **EVERY FLOOR EDGE THAT BORDERS A DROP, AS A LOW WALL.** GDD-05 §2.1 draws the
## district with walls; the greybox had **none**, so nothing anywhere stopped a body
## walking into a void. Measured on a live server: NPCs went over at **0.2-1.1 m
## outside a floor edge**, nineteen in forty-five seconds, at the alley mouth, the
## bridge, the warehouse street and a seam between two floors. RVO jostles bodies
## sideways off a navmesh already eroded by the agent radius, and the same gap let a
## player walk off the piazza's south edge.
##
## **DERIVED FROM THE FLOOR TABLE, NEVER LISTED.** Hand-listing void edges is the
## transcription that produced four unwalkable procession routes; a floor added to
## `VetraioLayout` gets its parapet here without anybody remembering to.
##
## Returned as `[name, x, z, size_x, size_z, height]`, in the generator's own order.
static func parapets() -> Array:
	var out: Array = []
	for row: Array in street_floors():
		var r := rect_of(row)
		var who := str(row[0])
		out.append_array(_edge(who, r, Vector2.UP))
		out.append_array(_edge(who, r, Vector2.DOWN))
		out.append_array(_edge(who, r, Vector2.LEFT))
		out.append_array(_edge(who, r, Vector2.RIGHT))
	return out


## One side of one floor, as however many runs of unsupported edge it has. `side` is
## the outward direction in x/z, so `UP` is the low-z edge.
static func _edge(who: String, r: Rect2, side: Vector2) -> Array:
	var along_x := absf(side.y) > 0.5
	var from := r.position.x if along_x else r.position.y
	var to := r.end.x if along_x else r.end.y
	var runs: Array = []
	var open := INF
	var at := from
	while at < to - 0.0001:
		var step := minf(EDGE_STEP, to - at)
		if _is_a_drop(r, side, at + step * 0.5, along_x):
			if open == INF:
				open = at
		elif open != INF:
			runs.append([open, at])
			open = INF
		at += step
	if open != INF:
		runs.append([open, to])
	var out: Array = []
	for i: int in runs.size():
		out.append(_box(who, r, side, float(runs[i][0]), float(runs[i][1]), i))
	return out


static func _is_a_drop(r: Rect2, side: Vector2, mid: float, along_x: bool) -> bool:
	var edge := (
		(r.position.y if side.y < 0.0 else r.end.y)
		if along_x
		else (r.position.x if side.x < 0.0 else r.end.x)
	)
	var probe := (
		Vector2(mid, edge + side.y * EDGE_PROBE)
		if along_x
		else Vector2(edge + side.x * EDGE_PROBE, mid)
	)
	return not on_a_floor(probe) and block_at(probe) == ""


## The parapet box for one run, sitting **outside** the floor so the walkable width
## is unchanged. Vault height: a civilian never goes over one, and a player who
## means to still can — which is the difference between falling and jumping.
static func _box(who: String, r: Rect2, side: Vector2, from: float, to: float, nth: int) -> Array:
	var t := PARAPET_THICKNESS
	var name := "Parapet_%s_%d_%d" % [who, int(side.x + side.y * 2.0 + 4.0), nth]
	if absf(side.y) > 0.5:
		var z := (r.position.y - t) if side.y < 0.0 else r.end.y
		return [name, from, z, to - from, t, VetraioLayout.H_VAULT]
	var x := (r.position.x - t) if side.x < 0.0 else r.end.x
	return [name, x, from, t, to - from, VetraioLayout.H_VAULT]


## **AN ANCHOR INSIDE A MARKET STALL IS A SEAT NOBODY CAN TAKE.** The grid above has
## no obstacle filter, so two anchors landed inside each of StallA-D — **8 of 67
## unreachable on foot**, and `map_get_closest_point` hides it by answering with the
## stall's own **top**, which is on the navmesh and unreachable from the street.
##
## **NUDGED, NOT DROPPED.** Deleting them would take the count to 59 and leave S6 —
## which has exactly `TUN-CROWD-CLONE-LOCAL-MIN` seats of 8 — short, so the fix for
## an unusable anchor would have created a starved spawn point. Moving each to the
## nearest walkable metre keeps the count, keeps the market's declared density, and
## makes the seat real.
##
## The search is a widening ring at half-metre steps, which resolves every one of
## these inside two metres because a stall is 6 x 2 m and the aisle is beside it.
static func clear_of_obstacles(at: Vector2) -> Vector3:
	if _is_usable(at):
		return Vector3(at.x, 0.0, at.y)
	var radius := 0.5
	while radius <= 4.0:
		for step: int in 16:
			var angle := TAU * float(step) / 16.0
			var near := at + Vector2(cos(angle), sin(angle)) * radius
			if _is_usable(near):
				return Vector3(near.x, 0.0, near.y)
		radius += 0.5
	# Nothing within four metres. Left where it is rather than moved somewhere
	# arbitrary: a wrong anchor that stays put is findable, one that teleports is not.
	return Vector3(at.x, 0.0, at.y)


## **CLEAR OF AN OBSTACLE MEANS CLEAR BY THE AGENT RADIUS, NOT MERELY OUTSIDE IT.**
## The navmesh is eroded by `NAV_AGENT_RADIUS`, so a point flush against a wall is
## **off** the walkable surface — and `map_get_closest_point` then answers with
## whatever mesh is nearest, which is the isolated patch **inside** the block. That
## is US-0041's `Npc003` standing on a market stall, in a new costume: an anchor
## that looks placed, snaps to something, and can never be walked away from.
##
## Found 2026-08-21 when interior massing put an idle anchor 0.1 m from
## `LampeIsland`'s west face, and the connectivity test seeded a floor onto the
## island inside that same block and reported the floor severed.
static func _is_usable(at: Vector2) -> bool:
	if not on_a_floor(at):
		return false
	var clearance := VetraioLayout.NAV_AGENT_RADIUS
	for row: Array in VetraioLayout.BLOCKS:
		if _grown(row, clearance).has_point(at):
			return false
	for row: Array in VetraioLayout.STALLS:
		if _grown(row, clearance).has_point(at):
			return false
	return true


## An obstacle's footprint widened by `by` on every side.
static func _grown(row: Array, by: float) -> Rect2:
	return Rect2(
		float(row[1]) - by, float(row[2]) - by, float(row[3]) + by * 2.0, float(row[4]) + by * 2.0
	)
