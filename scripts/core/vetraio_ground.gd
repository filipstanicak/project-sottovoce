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
