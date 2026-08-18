## **A CRITERION CAN BE TRUE OF A CLASS AND FALSE OF THE GAME.** US-0047.
##
## `test_clone_local_min.gd` proves the *rule*: given a crowd, some players and a
## map, `CloneBalance` finds local holes and fills them. Every assertion in it
## would stay green with the director never calling it — which is exactly what
## happened to US-0039, whose pool allocated ninety bodies in tests and none in a
## scene while the criterion saying so was ticked.
##
## So this file asks the director instead: does the shipped tick actually run
## layer 4, on the 2 s timer, and does `CrowdIntent` actually hand the reservation
## to the next stroll? Those are the two joints where the rule meets the game, and
## neither is visible from `CloneBalance`.
extends GutTest

const SEED := 20260818
const MAP_DATA := "res://data/maps/map_vetraio.tres"
const CROWD := 40

var _pool: NpcPool
var _director: CrowdDirector
var _ctx: MatchContext


func before_each() -> void:
	_pool = NpcPool.new()
	add_child_autofree(_pool)
	_pool.preallocate(CROWD)
	_pool.activate(CROWD, SEED, CrowdRoster.PLAYABLE, 6)
	_ctx = MatchContext.new()
	_ctx.crowd = _pool
	_ctx.map = load(MAP_DATA) as MapData
	_ctx.match_seed = SEED
	_ctx.rng = RandomNumberGenerator.new()
	_ctx.rng.seed = SEED
	# **THE WHOLE CROWD IN ONE CORNER**, so the district a player stands in is
	# guaranteed to be short of every persona. The point here is the wiring, not
	# the distribution.
	for index: int in CROWD:
		_pool.set_position(index, Vector3(100.0 + float(index % 8), 0.0, 100.0))
	_director = CrowdDirector.new()
	add_child_autofree(_director)


func _watch_from(where: Vector3) -> void:
	var observer := CharacterBody3D.new()
	add_child_autofree(observer)
	observer.global_position = where
	_ctx.pawns[1] = observer


func _tick(times: int) -> void:
	for _t: int in times:
		_ctx.tick += 1
		_director.tick(_ctx, MatchContext.net_dt())


func test_the_director_runs_layer_four_at_all() -> void:
	_watch_from(Vector3(20.0, 0.0, 20.0))
	_director.setup(_ctx)
	_tick(120)
	var clones := _director.clones()
	gut.p(
		(
			"%d passes, %d deficits on the last one, %d re-routes"
			% [clones.passes, clones.deficits_last_pass, clones.rerouted_total]
		)
	)
	assert_gt(clones.passes, 0, "CrowdDirector never called CloneBalance.rebalance")
	assert_gt(clones.rerouted_total, 0, "the director ran layer 4 and it re-routed nobody")


func test_it_runs_on_the_two_second_timer_and_never_per_tick() -> void:
	# The story's first criterion. `TUN-CROWD-DIRECTOR-INTERVAL` is 2.0 s, so 120
	# net ticks is exactly two passes — and the assertion is an equality, because
	# "at most" would also be satisfied by a rule that never ran.
	_watch_from(Vector3(20.0, 0.0, 20.0))
	_director.setup(_ctx)
	var interval := Tuning.ticks(&"TUN-CROWD-DIRECTOR-INTERVAL")
	assert_eq(interval, 60, "TUN-CROWD-DIRECTOR-INTERVAL is no longer 2 s at 30 Hz")
	_tick(interval * 2)
	assert_eq(_director.clones().passes, 2, "layer 4 did not run exactly once per 2 s")


func test_a_reservation_is_what_the_next_stroll_walks_to() -> void:
	# **THE SECOND JOINT.** `CloneBalance` can reserve an anchor for a clone all it
	# likes; unless `CrowdIntent` prefers it over its own seeded pick, the clone
	# strolls somewhere random and the whole layer is decoration.
	var map := _ctx.map
	var balance := CloneBalance.new()
	balance.setup(map, _ctx.rng)
	var intent := CrowdIntent.new()
	intent.setup(_pool, map, _ctx.rng, CrowdFormations.new(), CorpseRegister.new(), balance)

	var undirected := intent.goal_for(0, NpcBrain.State.STROLL)
	assert_true(map.idle_anchors.has(undirected), "an ordinary stroll does not pick an anchor")

	var chosen: Vector3 = map.idle_anchors[map.idle_anchors.size() - 1]
	balance.pending[0] = chosen
	assert_eq(
		intent.goal_for(0, NpcBrain.State.STROLL),
		chosen,
		"CrowdIntent ignored the reservation and picked its own anchor"
	)


func test_the_personas_it_holds_the_minimum_for_are_the_playable_four() -> void:
	# Nothing chooses a persona for a player yet — no lobby, `NET-C2S-LOADOUT` is
	# M4's — so the director holds the minimum for all four, which is the same call
	# `server_root` already makes for `NpcPool.activate`. Stated as an assertion so
	# that the day `SYS-MATCH` narrows it, something says so.
	assert_eq(
		_director.personas_in_use,
		CrowdRoster.PLAYABLE,
		"the in-use set is no longer the playable four — is there a lobby now?"
	)


func test_an_unwatched_server_reroutes_nobody_through_the_director() -> void:
	# No pawns at all, which is what the integration harness and every client hold.
	_director.setup(_ctx)
	_tick(120)
	assert_gt(_director.clones().passes, 0, "the pass did not run, so this proves nothing")
	assert_eq(_director.clones().rerouted_total, 0, "an empty server re-routed the crowd")
