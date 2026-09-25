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
## with **company** — another walker within `COMPANY_RADIUS` heading the same way —
## counted twice: among walkers **in the same state**, which is the stroller-rows
## figure, and among **anyone**, which also counts a stroller beside a procession. And
## for strollers: the share of their walking spent on **shared lanes**, one-metre cells
## that `SHARED_LANE` or more different NPCs walked through. The constants and the
## arithmetic live in `crowd_spread.gd`.
extends Node

const SERVER_ROOT := "res://scenes/server_root.tscn"
const PEER := 910
const SAMPLE_EVERY := 0.5
const WATCH := 120.0
## The arithmetic, pure and tested: `test/unit/tools/test_crowd_spread.gd`.
const SPREAD := preload("res://tools/crowd_spread.gd")

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
	var t := SPREAD.tally(samples, SAMPLE_EVERY, NpcBrain.State.STROLL)
	var total := 0
	for state: int in t["share"]:
		total += t["share"][state]
	for state: int in t["share"]:
		var walking := maxi(int(t["walking"].get(state, 0)), 1)
		print(
			(
				"%-14s %3.0f %% of the crowd   company: same state %3.0f %%, anyone %3.0f %%"
				% [
					NpcBrain.State.keys()[state],
					100.0 * t["share"][state] / maxi(total, 1),
					100.0 * int(t["same"].get(state, 0)) / walking,
					100.0 * int(t["any"].get(state, 0)) / walking,
				]
			)
		)
	print(
		(
			"strollers: %3.0f %% of walking on shared lanes (cells crossed by %d+ strollers)"
			% [100.0 * SPREAD.shared_lane_share(t), SPREAD.SHARED_LANE]
		)
	)
