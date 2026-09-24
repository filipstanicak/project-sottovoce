extends RefCounted
## **THE CIVILIAN BRAIN: A BOT THAT WALKS THE WAY THE CROWD WALKS.** US-0102. DEBUG TOOL.
##
## A bot that crossed the district in straight legs with sudden turns was the one
## figure in its colour that nobody had to look at twice — reported from the controls
## on 2026-09-24, once the district was dressed (US-0101) and the portrait named the
## colour to look for. **Identification cannot be tested alone against a target that
## identifies itself**, so this brain does not try to be clever. It copies the crowd.
##
## **BEHAVIOURAL PARITY, THE CLONE RULE APPLIED TO MOVEMENT.** Every choice below is
## the one an NPC makes, from the same source:
##
## - a stroll goes to an idle anchor chosen uniformly at random — `CrowdIntent._an_anchor`;
##   here `_next_anchor`;
## - the way there is a path on the district navmesh — `Steering`; here `_find_path`;
## - it strolls at `TUN-CROWD-NPC-SPEED-STROLL`, which invariant 1 makes blend-walk;
##   here `input_slow`;
## - it stands `TUN-CROWD-IDLE-DURATION-MIN`..`-MAX`, uniformly — `NpcBrain._enter`;
##   here `_idle_left`.
##
## **WHAT IT DOES NOT COPY, SAID RATHER THAN HIDDEN.** Processions (`WALKING_GROUP`),
## startles and gawking are the director's decisions about *other* NPCs, not a walk a
## lone figure makes; and a bot turns with the pad's look keys, never a mouse, so its
## corners are a little squarer than an agent's. `tools/bot_census.gd` measures how
## far the result is from the crowd rather than asserting that it is not.
##
## **IT IS NOT AN OPPONENT** (SCOPE_FENCE OUT #14). It plans nothing, hunts nobody and
## is excluded from every export preset with the rest of `tools/`.

enum Mode { STROLL, IDLE }

## Within this of the last path point, the anchor is reached. An NPC's agent stops at
## its own target distance; a bot has only its position to judge by.
const ARRIVE := 1.2
## Within this of an intermediate corner, the next one becomes the target.
const CORNER := 0.8
## How far off the next corner the bot tolerates before turning. Wide, because the
## look keys sweep rather than aim — `bot_hunt.gd` learned a tight value oscillates.
const AIM_TOLERANCE := 0.18
## Beyond this, the bot stops walking while it turns, rather than walking an arc
## into the wall the corner was there to avoid.
const TURN_IN_PLACE := 0.9
## How long the caller holds the decided keys before asking again, while moving.
const BEAT := 0.1
## Longest single wait while idle, so a disconnect or a death is noticed promptly.
const IDLE_BEAT := 1.0
## Displacement per beat below which the bot counts as not moving, and how many such
## beats before it gives up on this anchor. **Measured, not predicted**, for
## `bot_hunt.gd`'s reason: a wedged bot often has clear ground straight ahead.
const STUCK_STEP := 0.04
const STUCK_BEATS := 25

var mode: Mode = Mode.STROLL

var _rng := RandomNumberGenerator.new()
var _anchors: Array = []
## `(from: Vector3, to: Vector3) -> PackedVector3Array`. Injected so the brain can be
## tested without a navigation server; the bot hands it a real one.
var _find_path: Callable
var _path := PackedVector3Array()
var _corner: int = 0
var _idle_left := 0.0
var _last_at := Vector3.INF
var _still_for: int = 0
var _strolls: int = 0
## Whether the last decision held forward. **Only then does standing still count as
## stuck**: a bot turning in place is not moving and is not wedged either.
var _walking := false


func _init(seed_from: int, anchors: Array, find_path: Callable) -> void:
	_rng.seed = hash("sottovoce-bot-civilian-%d" % seed_from)
	_anchors = anchors
	_find_path = find_path


## The keys to hold and how long to hold them, as `[actions, seconds]` — the same
## contract `bot_hunt.gd` answers, so `bot_client.gd` drives either the same way.
func decide(pawn: PawnContext) -> Array:
	if pawn == null:
		return [[], IDLE_BEAT]
	if mode == Mode.IDLE:
		if _idle_left > 0.0:
			var wait := minf(_idle_left, IDLE_BEAT)
			_idle_left -= wait
			return [[], wait]
		_begin_stroll(pawn.position)
	if _path.is_empty() or (_walking and _stuck(pawn.position)):
		_begin_stroll(pawn.position)
		if _path.is_empty():
			return _stand()
	return _follow(pawn)


## How many strolls this brain has begun. Read by the tests and the census.
func strolls() -> int:
	return _strolls


## The point the bot is walking to, or `Vector3.INF` while it stands.
func target() -> Vector3:
	return Vector3.INF if mode == Mode.IDLE or _path.is_empty() else _path[_path.size() - 1]


func _follow(pawn: PawnContext) -> Array:
	var here := pawn.position
	var last := _path.size() - 1
	while _corner < last and CompassMath.distance_to(here, _path[_corner]) < CORNER:
		_corner += 1
	if CompassMath.distance_to(here, _path[last]) < ARRIVE:
		return _stand()
	var off := CompassMath.angle_between(pawn.yaw, CompassMath.bearing_to(here, _path[_corner]))
	var actions: Array = []
	_walking = absf(off) < TURN_IN_PLACE
	if _walking:
		actions.append_array(["input_move_forward", "input_slow"])
	else:
		_last_at = Vector3.INF
	if absf(off) > AIM_TOLERANCE:
		# This game's yaw increases toward a turn to the LEFT (`bot_hunt.gd`).
		actions.append("input_look_left" if off > 0.0 else "input_look_right")
	return [actions, BEAT]


## Arrived, or nowhere to go: stand for an NPC's idle duration, drawn the same way.
func _stand() -> Array:
	mode = Mode.IDLE
	_walking = false
	_path = PackedVector3Array()
	_idle_left = _rng.randf_range(Tuning.crowd.idle_duration_min, Tuning.crowd.idle_duration_max)
	_still_for = 0
	return [[], 0.0]


func _begin_stroll(from: Vector3) -> void:
	mode = Mode.STROLL
	_corner = 0
	_still_for = 0
	_last_at = Vector3.INF
	_path = PackedVector3Array()
	var goal := _next_anchor()
	if goal == Vector3.INF:
		return
	_path = _find_path.call(from, goal)
	_strolls += 1


## **UNIFORM OVER EVERY ANCHOR, `CrowdIntent._an_anchor`'s RULE.** Not the nearest:
## an NPC crosses the district to a bench it chose at random, and a bot that only
## ever hopped to its neighbour would be the one figure that never went far.
func _next_anchor() -> Vector3:
	if _anchors.is_empty():
		return Vector3.INF
	return _anchors[_rng.randi_range(0, _anchors.size() - 1)]


func _stuck(here: Vector3) -> bool:
	var moved := _last_at == Vector3.INF or _last_at.distance_to(here) > STUCK_STEP
	_last_at = here
	_still_for = 0 if moved else _still_for + 1
	return _still_for >= STUCK_BEATS


## **THE DISTRICT'S OWN NAVMESH, IN A NAVIGATION MAP OF THE BOT'S OWN.** The client
## scene carries meshes and no navigation region — the server scene has that — so
## the bot loads the committed bake beside `MapCatalogue.data_path` into a map nobody
## else reads. The same mesh the NPCs path on, which is the parity that matters.
##
## Built at `_ready` and queried after `bot_client.gd`'s settle, by which time the
## server has synchronised it; a query against an unsynchronised map answers empty
## and the brain then stands, which is honest rather than wrong.
static func path_finder(map_name: String) -> Callable:
	var mesh := load(MapCatalogue.data_path(map_name).replace(".tres", "_navmesh.tres"))
	if not mesh is NavigationMesh:
		push_warning("bot: no navmesh for %s, so the civilian bot will stand" % map_name)
		return func(_from: Vector3, _to: Vector3) -> PackedVector3Array: return []
	var map := NavigationServer3D.map_create()
	NavigationServer3D.map_set_cell_size(map, PawnNavigation.NAV_CELL_SIZE)
	NavigationServer3D.map_set_cell_height(map, PawnNavigation.NAV_CELL_HEIGHT)
	NavigationServer3D.map_set_active(map, true)
	var region := NavigationServer3D.region_create()
	NavigationServer3D.region_set_map(region, map)
	NavigationServer3D.region_set_navigation_mesh(region, mesh as NavigationMesh)
	return func(from: Vector3, to: Vector3) -> PackedVector3Array:
		var start := NavigationServer3D.map_get_closest_point(map, from)
		return NavigationServer3D.map_get_path(map, start, to, true)
