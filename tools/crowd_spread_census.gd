## **DOES THE CROWD WALK APART, OR IN LINES?** US-0103. DEBUG TOOL, SERVER SIDE.
##
## Reported from the controls on 2026-09-25 with a screenshot: figures walking in rows
## along one route, *"die Bots … gruppiert einem bestimmten Weg folgen"* — and the owner
## wants a few groups, with everybody else walking on their own. A crowd that walks in
## lines is a crowd a lone player stands out from, which is design law 2 from the
## wrong side.
##
## Two causes are possible and they need different fixes, so this measures both
## instead of guessing:
##
## - **Processions** (`WALKING_GROUP`, GDD-03 §5.2) walk together *by design* —
##   `TUN-CROWD-GROUP-COUNT` circuits of `TUN-CROWD-GROUP-SIZE`.
## - **Strollers** each pick their own anchor, and still may walk in lines: every one
##   takes the *shortest* navmesh path, so they share the same corners and the same
##   street centres. Crowd simulation calls that lane formation; here it would be an
##   artefact of pathing, not a choice.
##
##     godot --headless --path . res://tools/crowd_spread_census.tscn
##
## Prints, per state: the share of the crowd in it, and the share of walking samples
## with **company** — another walker within `COMPANY_RADIUS` heading the same way. And
## for strollers: the share of their walking spent on **shared lanes**, one-metre cells
## that `SHARED_LANE` or more different NPCs walked through.
extends Node

const SERVER_ROOT := "res://scenes/server_root.tscn"
const PEER := 910
const SAMPLE_EVERY := 0.5
const WATCH := 120.0
## Another walker this close and heading this similarly is company.
const COMPANY_RADIUS := 3.0
const COMPANY_HEADING := 0.6
## Faster than this between two samples is walking.
const WALKING := 0.5
## A cell this many different strollers crossed is a shared lane.
const SHARED_LANE := 5

var _root: Node
var _pool: NpcPool


func _ready() -> void:
	_root = (load(SERVER_ROOT) as PackedScene).instantiate()
	get_tree().get_root().add_child.call_deferred(_root)
	_run.call_deferred()


func _run() -> void:
	for _i: int in 600:
		await get_tree().physics_frame
		if _root.get("match_state") != null and _root.get("crowd") != null:
			break
	_pool = _root.get("crowd") as NpcPool
	# **THE BENCH IS ITS OWN LOBBY** (`ability_probe.gd`): below the floor no stage
	# runs, and a crowd that never moves walks in no lines at all.
	_root.match_state.min_players = 1
	_root.call(&"_on_peer_joined", PEER)
	var ctx: MatchContext = (_root.get("director") as MatchDirector).ctx
	while not MatchPhase.is_simulating(ctx.phase):
		await get_tree().create_timer(0.5).timeout
	await get_tree().create_timer(10.0).timeout
	print("crowd active: %d, watching %.0f s" % [_pool.active_count(), WATCH])
	var samples := await _watch()
	_report(samples)
	Net.bind_router(null, null)
	get_tree().quit(0)


## `[t][index] = [position, state]`, every `SAMPLE_EVERY` seconds.
func _watch() -> Array:
	var samples: Array = []
	var t := 0.0
	while t < WATCH:
		await get_tree().create_timer(SAMPLE_EVERY).timeout
		t += SAMPLE_EVERY
		var frame: Dictionary = {}
		for index: int in _pool.active_count():
			var body := _pool.body_of(index)
			var brain := _pool.brain_of(index)
			if body != null and brain != null:
				frame[index] = [body.global_position, brain.state]
		samples.append(frame)
	return samples


func _report(samples: Array) -> void:
	var share := {}
	var walking := {}
	var company := {}
	var lanes := {}
	var stroll_cells: Array = []
	for i: int in range(1, samples.size()):
		var moving := _walkers(samples[i - 1], samples[i])
		for index: int in samples[i]:
			var state: int = samples[i][index][1]
			share[state] = int(share.get(state, 0)) + 1
		for index: int in moving:
			var state: int = moving[index][2]
			walking[state] = int(walking.get(state, 0)) + 1
			if _has_company(index, moving):
				company[state] = int(company.get(state, 0)) + 1
			if state == NpcBrain.State.STROLL:
				var cell := Vector2i(floori(moving[index][0].x), floori(moving[index][0].z))
				var seen: Dictionary = lanes.get(cell, {})
				seen[index] = true
				lanes[cell] = seen
				stroll_cells.append(cell)
	var total := 0
	for state: int in share:
		total += share[state]
	for state: int in share:
		var walked: int = walking.get(state, 0)
		print(
			(
				"%-14s %3.0f %% of the crowd   walking with company %3.0f %%"
				% [
					NpcBrain.State.keys()[state],
					100.0 * share[state] / maxi(total, 1),
					100.0 * int(company.get(state, 0)) / maxi(walked, 1)
				]
			)
		)
	var shared := stroll_cells.filter(
		func(c: Vector2i) -> bool: return (lanes[c] as Dictionary).size() >= SHARED_LANE
	)
	print(
		(
			"strollers: %3.0f %% of walking on shared lanes (cells crossed by %d+ strollers)"
			% [100.0 * shared.size() / maxi(stroll_cells.size(), 1), SHARED_LANE]
		)
	)


## `{index: [position, heading, state]}` for everybody walking between two samples.
func _walkers(before: Dictionary, now: Dictionary) -> Dictionary:
	var out := {}
	for index: int in now:
		if not before.has(index):
			continue
		var a: Vector3 = before[index][0]
		var b: Vector3 = now[index][0]
		if CompassMath.distance_to(a, b) / SAMPLE_EVERY < WALKING:
			continue
		out[index] = [b, CompassMath.bearing_to(a, b), now[index][1]]
	return out


func _has_company(index: int, moving: Dictionary) -> bool:
	var me: Array = moving[index]
	for other: int in moving:
		if other == index:
			continue
		var them: Array = moving[other]
		if CompassMath.distance_to(me[0], them[0]) > COMPANY_RADIUS:
			continue
		if absf(CompassMath.angle_between(me[1], them[1])) < COMPANY_HEADING:
			return true
	return false
