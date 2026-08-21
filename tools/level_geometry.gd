## **IS THIS POINT ON GROUND A CIVILIAN CAN STAND ON?** US-0041.
##
## PURE. Rectangles from `VetraioLayout` and nothing else — no navmesh, no scene,
## no server. Four callers needed the same three predicates and two of them had
## written their own.
##
## **IT IS ONE CLASS BECAUSE THE DUPLICATE COPIES DISAGREED.** `stuck_census.gd`
## and `test_circuit_separation.gd` each filtered street-level floors with
## `float(row[6])` — index 6 is the **material string**, and
## `float("MAT-GREY-FLOOR")` is `0.0`, which equals `STREET_Y`. So the guard never
## skipped anything and `LoggiaBalcony` at 3.5 m counted as walkable ground, in
## both files, because the second was copied from the first. That is `CrowdWire`'s
## lesson in a different domain: a rule two readers must agree on is one function.
##
## The height column is index **5**; index 6 is the material. Nothing else here is
## subtle.
class_name LevelGeometry


## Every floor whose surface is the street, as raw `FLOORS` rows. The Loggia
## balcony is at `BALCONY_Y` and is deliberately not walkable — GDD-05 §4.4 charges
## suspicion for standing up there, which is only meaningful if nobody routes over
## it by accident.
static func street_floors() -> Array:
	var out: Array = []
	for row: Array in VetraioLayout.FLOORS:
		if is_equal_approx(float(row[5]), VetraioLayout.STREET_Y):
			out.append(row)
	return out


static func on_a_floor(at: Vector2) -> bool:
	for row: Array in street_floors():
		if _rect_of(row).has_point(at):
			return true
	return false


## The building mass containing `at`, or "". Blocks are solid: a route point inside
## one is a slot no NPC can occupy, and `CrowdFormations` drives members straight
## at their slot with no path query.
static func block_at(at: Vector2) -> String:
	for row: Array in VetraioLayout.BLOCKS:
		if _rect_of(row).has_point(at):
			return str(row[0])
	return ""


## The market stall containing `at`, or "". Stalls are `H_VAULT` high — a player
## vaults them and an NPC cannot, so an NPC sent inside one presses into it.
static func stall_at(at: Vector2) -> String:
	for stall: Array in VetraioLayout.STALLS:
		var r := Rect2(float(stall[1]), float(stall[2]), float(stall[3]), float(stall[4]))
		if r.has_point(at):
			return str(stall[0])
	return ""


## How far `at` is outside the nearest street floor, and which one. `0.0` when it
## is standing on something. **A fall is named by the edge it left**, which a count
## of falls cannot say: nineteen bodies a minute went over while every route
## measured fully walkable, and only the positions showed they were leaving at
## floor seams rather than on the routes.
static func nearest_edge(at: Vector2) -> Array:
	var best := ""
	var nearest := INF
	for row: Array in street_floors():
		var r := _rect_of(row)
		var inside := Vector2(
			clampf(at.x, r.position.x, r.end.x), clampf(at.y, r.position.y, r.end.y)
		)
		var gap := at.distance_to(inside)
		if gap < nearest:
			nearest = gap
			best = str(row[0])
	return [nearest, best]


static func _rect_of(row: Array) -> Rect2:
	return Rect2(float(row[1]), float(row[2]), float(row[3]), float(row[4]))
