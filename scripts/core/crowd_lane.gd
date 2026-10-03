## **A STROLLER'S OWN SIDE OF THE STREET.** US-0103. PURE.
##
## Measured before this existed (`tools/crowd_spread_census.tscn`): **39 %** of
## strollers walked beside another stroller and **58–64 %** of stroller walking lay
## on lanes five or more strollers shared. Every stroller took the *shortest* navmesh
## path, so everybody bound for the same corner walked the same line through it —
## lane formation as an artefact of pathing, and a row a lone player stands out from.
##
## **ONE OFFSET PER FIGURE, KEPT FOR THE MATCH.** A figure that changed sides every
## few metres would weave, which is a tell; one that keeps its side walks like a
## person. The offset is derived from the match seed and the figure's index rather
## than drawn from `MatchContext.rng`, so it spends nothing from the generator the
## rest of the crowd reads — a recorded seed still replays the same district.
##
## **NPCs AND THE CIVILIAN TEST BOTS USE THIS SAME RULE**, or the bot becomes the one
## figure on the centre line (US-0102's parity, applied to a new rule).
class_name CrowdLane
extends RefCounted


## The offset, in metres, for figure `index` under `match_seed`: uniform in
## ±`spread`, the same every time it is asked.
static func lateral_for(match_seed: int, index: int, spread: float) -> float:
	var h := posmod(hash(Vector2i(match_seed & 0x7FFFFFFF, index)), 2001)
	return (float(h) / 1000.0 - 1.0) * spread


## **A WHOLE ROUTE MOVED ONTO THE FIGURE'S LANE, ONCE, WHEN IT IS PLANNED.** Every
## interior corner moves `lateral` metres along its bisector, and every leg gains a
## midpoint moved square to it, so even a straight crossing of a plaza bends onto the
## lane. The start and the goal stay where they are: a figure leaves from where it
## stands and arrives where it was going. `snap` takes a point and returns the nearest
## walkable one — the navmesh's own answer — so a corner moved toward a wall is put
## back on the street rather than steered into the wall (`Callable()` leaves points
## as moved, for a test with no navmesh).
##
## **ONCE PER ROUTE, NOT EVERY TICK, AND THAT IS THE SECOND VERSION.** The first moved
## the aim point every tick with no question of whether it was walkable: measured,
## strollers moved 77 % of the time without a lane, 55 % with 1 m and 43 % with 2 m —
## caught on walls and corners, and the lane figures looked better partly because a
## stuck figure is not walking.
static func offset_path(
	path: PackedVector3Array, lateral: float, snap: Callable = Callable()
) -> PackedVector3Array:
	if path.size() < 2 or is_zero_approx(lateral):
		return path
	var out := PackedVector3Array([path[0]])
	for i: int in range(1, path.size()):
		var leg := _square_to(path[i] - path[i - 1])
		out.append(_snapped((path[i - 1] + path[i]) * 0.5 + leg * lateral, snap))
		if i == path.size() - 1:
			out.append(path[i])
		else:
			var turn := leg + _square_to(path[i + 1] - path[i])
			var side := turn.normalized() if turn.length_squared() > 0.000001 else leg
			out.append(_snapped(path[i] + side * lateral, snap))
	return out


static func _square_to(leg: Vector3) -> Vector3:
	var flat := Vector3(-leg.z, 0.0, leg.x)
	return flat.normalized() if flat.length_squared() > 0.000001 else Vector3.ZERO


static func _snapped(point: Vector3, snap: Callable) -> Vector3:
	return point if not snap.is_valid() else snap.call(point)
