## **A CLOSED WALKING ROUTE, PARAMETRISED BY DISTANCE.** GDD-05 §5.2, US-0043.
## SERVER ONLY, and PURE — a polyline in, a point out. No node, no navigation
## server, so "where is the group at 40 m along" is a question a unit test asks
## directly.
##
## **BY DISTANCE, NOT BY TIME.** The obvious parametrisation is a fraction of the
## circuit's *period*, and it is wrong in a way that hides: a route whose segments
## differ in length would then be walked at a different speed on every segment —
## fast down the long straight, crawling round the tight corner — while every
## number in the corpus said 1.4 m/s. The group advances by `speed × dt` and the
## period is what falls out of that, which is also why this class does not know
## what a period is.
class_name CrowdCircuit
extends RefCounted

var _points: PackedVector3Array = PackedVector3Array()

## Cumulative distance to the START of each segment, plus the total at the end.
## `_marks[i]` is the distance from `_points[0]` to `_points[i]`.
var _marks: PackedFloat32Array = PackedFloat32Array()


## Build from a closed loop of waypoints. The last point joins back to the first;
## it is not repeated in the input, and `MapData.circuits` does not repeat it.
func setup(points: PackedVector3Array) -> void:
	_points = points
	_marks.resize(points.size() + 1)
	if points.is_empty():
		return
	var running := 0.0
	for index: int in points.size():
		_marks[index] = running
		running += _flat(points[index]).distance_to(_flat(points[(index + 1) % points.size()]))
	_marks[points.size()] = running


func length() -> float:
	return _marks[_marks.size() - 1] if _marks.size() > 1 else 0.0


func waypoint_count() -> int:
	return _points.size()


## **HOW LONG A LAP TAKES AT `speed`.** Derived rather than authored, which is
## the whole of US-0043's first finding: `MapData.circuit_periods` declares
## 55–75 s, and at `TUN-CROWD-NPC-SPEED-STROLL` these routes take 107–169 s.
## The two cannot both be true, and the speed is the one the design laws pin.
func period_at(speed: float) -> float:
	return length() / speed if speed > 0.0 else INF


## The point `distance` metres along the loop, wrapping.
func point_at(distance: float) -> Vector3:
	if _points.size() < 2:
		return _points[0] if _points.size() == 1 else Vector3.ZERO
	var along := fposmod(distance, length())
	var segment := _segment_of(along)
	var from := _points[segment]
	var to := _points[(segment + 1) % _points.size()]
	var span := _marks[segment + 1] - _marks[segment]
	var t := 0.0 if span <= 0.0 else (along - _marks[segment]) / span
	return from.lerp(to, t)


## The direction of travel there. **Flat and normalised**: a formation is laid out
## across the ground, and a route that climbed a step would otherwise tilt the
## whole group's slot grid.
func heading_at(distance: float) -> Vector3:
	if _points.size() < 2:
		return Vector3.FORWARD
	var segment := _segment_of(fposmod(distance, length()))
	var step := _points[(segment + 1) % _points.size()] - _points[segment]
	step.y = 0.0
	return Vector3.FORWARD if step.length_squared() < 0.000001 else step.normalized()


## Which segment `along` falls in. Linear rather than a binary search: a circuit
## has ten waypoints, and the search would cost more to read than it saves.
func _segment_of(along: float) -> int:
	for index: int in _points.size():
		if along < _marks[index + 1]:
			return index
	return _points.size() - 1


## **HORIZONTAL LENGTHS.** A circuit's period is a walking time across the
## district; measuring it through a 0.4 m navmesh rise would make the same route
## time differently depending on how the mesh happened to rasterise.
static func _flat(point: Vector3) -> Vector3:
	return Vector3(point.x, 0.0, point.z)
