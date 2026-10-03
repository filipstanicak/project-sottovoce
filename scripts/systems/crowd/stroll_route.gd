## **A STROLLER'S WALK ON ITS OWN LANE.** US-0103. SERVER ONLY.
##
## Strollers each took the *shortest* navmesh path, so everybody bound for the same
## corner walked the same line through it: 39 % of strollers walked beside another and
## 58–64 % of their walking lay on shared lanes. This plans a stroller's route once,
## moves it onto the stroller's lane (`CrowdLane.offset_path`, snapped back onto the
## navmesh) and walks it point to point. Every other state keeps the agent's own path,
## through `Steering`, exactly as before.
##
## **IT ARRIVES AT THE END OF THE ROUTE IT WAS GIVEN.** `NavigationAgent3D` measured
## arrival against the raw target, so a stroller sent to an anchor it could not reach
## — 24 of 67 on `MAP-VETRAIO` — stood at the nearest reachable point being told to go
## on, forever. A route ends at that point, and so does the walk.
##
## **WALKED WITH `Steering.drive_to`, THE FORMATIONS' OWN CALL**: point at a time, RVO
## still steering round neighbours and the body still colliding with the world.
class_name StrollRoute
extends RefCounted

var _pool: NpcPool = null
var _steering: Steering = null
## `(from, to) -> PackedVector3Array` and `(point) -> Vector3`, injected by a test
## with no navigation server. Unset, the NPC's own navigation map answers both.
var _find: Callable
var _snap: Callable
## Per NPC: the route on its lane, and the next point on it. Empty means the NPC is
## not on a stroller's route and `Steering` drives it as before.
var _routes: Array[PackedVector3Array] = []
var _next: PackedInt32Array = PackedInt32Array()
## Per NPC: its side of the street, dealt once from the match seed (`CrowdLane`).
var _lanes: PackedFloat32Array = PackedFloat32Array()


func setup(pool: NpcPool, steering: Steering, match_seed: int) -> void:
	_pool = pool
	_steering = steering
	_routes.resize(pool.body_count())
	_next.resize(pool.body_count())
	_lanes.resize(pool.body_count())
	for index: int in pool.body_count():
		_routes[index] = PackedVector3Array()
		_lanes[index] = CrowdLane.lateral_for(match_seed, index, Tuning.crowd.lane_spread)


## NPC `index`'s lane, in metres.
func lane_of(index: int) -> float:
	return _lanes[index]


## For a test: answer the path and the nearest walkable point without a navmesh.
func inject(find: Callable, snap: Callable) -> void:
	_find = find
	_snap = snap


## Send NPC `index` to `goal`: on its lane when `on_lane` — the director asks it for
## strollers only — otherwise on the agent's own path, as before this existed.
func aim(index: int, goal: Vector3, on_lane: bool) -> void:
	var agent := _pool.agent_of(index)
	var lateral := _lanes[index] if on_lane else 0.0
	var path := PackedVector3Array()
	if not is_zero_approx(lateral):
		path = _path(agent, _pool.body_of(index).global_position, goal)
	# **NO ROUTE, NO LANE.** A map not yet synchronised answers an empty path, and an
	# NPC with neither a route nor a target would count as arrived at once.
	if path.size() < 2:
		_routes[index] = PackedVector3Array()
		_steering.aim(agent, goal)
		return
	_routes[index] = CrowdLane.offset_path(path, lateral, _snapper(agent))
	_next[index] = 1
	# **THE AGENT IS GIVEN THE GOAL TOO, THOUGH THE ROUTE IS WHAT IS WALKED.** An agent
	# that has arrived stops avoiding and answers `velocity_computed` with zero however
	# it is driven (`CrowdIntent.travels`), so a stroller left holding its last anchor
	# as its target stood still: measured, strollers moved 3–5 % of the time.
	_steering.aim(agent, goal)


## Has NPC `index` finished where it was going?
func arrived(index: int) -> bool:
	var route := _routes[index]
	if route.is_empty():
		return _steering.arrived(_pool.agent_of(index))
	var here := _pool.body_of(index).global_position
	var last := route.size() - 1
	return _next[index] >= last and _flat(here, route[last]) <= _steering.arrive_radius


## Walk NPC `index` at `speed`: along its route if it has one, otherwise on the
## agent's own path. A point is passed once the NPC is within its agent's
## `path_desired_distance` of it — the distance the agent itself uses.
func drive(index: int, speed: float) -> void:
	var body := _pool.body_of(index)
	var agent := _pool.agent_of(index)
	var route := _routes[index]
	if route.is_empty():
		_steering.drive(body, agent, speed)
		return
	var last := route.size() - 1
	var here := body.global_position
	while _next[index] < last and _flat(here, route[_next[index]]) <= agent.path_desired_distance:
		_next[index] += 1
	_steering.drive_to(body, agent, route[mini(_next[index], last)], speed)


func _path(agent: NavigationAgent3D, from: Vector3, goal: Vector3) -> PackedVector3Array:
	if _find.is_valid():
		return _find.call(from, goal)
	var map := agent.get_navigation_map()
	return NavigationServer3D.map_get_path(
		map, NavigationServer3D.map_get_closest_point(map, from), goal, true
	)


func _snapper(agent: NavigationAgent3D) -> Callable:
	if _snap.is_valid():
		return _snap
	var map := agent.get_navigation_map()
	return func(point: Vector3) -> Vector3:
		return NavigationServer3D.map_get_closest_point(map, point)


## Forget a route — the NPC stopped strolling, or left the crowd.
func forget(index: int) -> void:
	_routes[index] = PackedVector3Array()


static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()
