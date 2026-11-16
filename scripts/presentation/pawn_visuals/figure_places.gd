## **WHERE A FIGURE SITS, AND WHERE IT LEANS.** US-0109. CLIENT ONLY.
##
## The server holds who is on which bench seat and at which counter; a client is
## told that about civilians (`NET-S2C-CROWD-GROUPS`) and **about another player
## it is told nothing** — a player's blend is their own. So a figure cannot be sat
## down by what the client knows it *is*. It is sat down by **where it is
## standing**: any figure that has stopped on a seat sits, and any that has stopped
## at a counter leans, player or civilian, on every screen alike.
##
## That is the only rule that cannot leak. A seated civilian and a standing player
## on the same bench would be the player circled.
##
## The places are the map's `static_props`; which way each faces is read from the
## bench or stall it belongs to, in the scene.
class_name FigurePlaces
extends RefCounted

## How close to the spot a figure must stand.
const REACH := 0.3
## How far a spot may be from the bench or stall it belongs to.
const BENCH_NEAR := 0.7
const STALL_NEAR := 0.9
## Where a seated figure's hips are, above the ground: on the bench.
const SEAT_HEIGHT := 0.5

## `[position, posture, facing yaw, how far back the seat is]` per place.
static var _spots: Array = []


## Read the places off `props`, facing each by the solid of `survey` it is at.
static func set_from(survey: DressingSurvey, props: Array) -> void:
	_spots = []
	for prop: Vector3 in props:
		var at := Vector2(prop.x, prop.z)
		var bench := _nearest(survey.of(DressingSurvey.Role.BENCH), at, BENCH_NEAR)
		if not bench.is_empty():
			var away: Vector2 = bench[0]
			var seat := (bench[2] as DressingSurvey.Part).size
			var back: float = bench[1] + minf(seat.x, seat.z) * 0.5
			add(prop, FigureMotion.Posture.SIT, atan2(away.x, away.y), back)
			continue
		var stall := _nearest(survey.of(DressingSurvey.Role.STALL), at, STALL_NEAR)
		if not stall.is_empty():
			var toward: Vector2 = -(stall[0] as Vector2)
			add(prop, FigureMotion.Posture.LEAN, atan2(toward.x, toward.y), 0.0)


## One place: where it is, what a figure does there, which way it faces, and how
## far behind it the seat is.
static func add(where: Vector3, posture: int, yaw: float, back: float) -> void:
	_spots.append([where, posture, yaw, back])


static func clear() -> void:
	_spots = []


static func count() -> int:
	return _spots.size()


## `[posture, facing yaw, seat depth]` for a figure standing at `position`, or
## empty when it is at no place.
static func at(position: Vector3) -> Array:
	for spot: Array in _spots:
		var where: Vector3 = spot[0]
		var dx := where.x - position.x
		var dz := where.z - position.z
		if dx * dx + dz * dz <= REACH * REACH and absf(where.y - position.y) < 1.0:
			return [spot[1], spot[2], spot[3]]
	return []


## `[direction away from it, distance, the part]` for the nearest of `parts`
## within `reach` of `at`, or empty.
static func _nearest(parts: Array[DressingSurvey.Part], at: Vector2, reach: float) -> Array:
	var best: Array = []
	var nearest := reach
	for part: DressingSurvey.Part in parts:
		var rect := part.rect()
		var on := Vector2(
			clampf(at.x, rect.position.x, rect.end.x), clampf(at.y, rect.position.y, rect.end.y)
		)
		var gap := at.distance_to(on)
		if gap < nearest and gap > 0.001:
			nearest = gap
			best = [(at - on).normalized(), gap, part]
	return best
