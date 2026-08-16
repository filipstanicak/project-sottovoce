## **THE CROWD ACTUALLY WALKS.** US-0041, TDD-08 §1.
##
## An integration test because every part of this claim is a part a unit test
## cannot reach: a live `NavigationServer3D` map, real `CharacterBody3D` bodies
## against the real map collision, and `NavigationAgent3D`'s avoidance callback,
## which fires on the physics frame rather than when anybody calls it.
##
## **THE ASSERTION THAT MATTERS IS THE SPEED, NOT THE DISPLACEMENT.** "The NPCs
## moved" is satisfied by NPCs moving at any speed at all, and the speed is the
## one number in the crowd that is load-bearing: invariant 1 forces
## `TUN-CROWD-NPC-SPEED-STROLL` to equal `TUN-SPEED-BLENDWALK` precisely so that
## a blend-walking player is indistinguishable from the crowd by motion. A crowd
## that walked at half the documented speed would satisfy every other test in
## this file and would be a silent anonymity leak — `RISK-ANONYMITY-LEAK`, found
## by nobody until a playtester said clones "look slow".
##
## That half-speed crowd is not hypothetical. `move_and_slide()` always
## integrates by the *physics* delta, so driving bodies from the 30 Hz net tick
## instead of the 60 Hz avoidance callback halves every NPC's speed with nothing
## in the log.
extends GutTest

const MAP_COLLISION := "res://scenes/map/map_vetraio_collision.tscn"
const MAP_DATA := "res://data/maps/map_vetraio.tres"

## Small enough to be quick, large enough that the repath stagger is visible —
## four ticks of queue at three a tick.
const CROWD := 12

const SEED := 20260817

## Net ticks to run. 60 at 30 Hz is two seconds, which is a comfortable margin
## over the ~0.9 m a strolling NPC covers per net tick... and well short of
## `TUN-CROWD-IDLE-DURATION-MIN`, so nobody who reaches an anchor sets off again.
const TICKS := 60

var _world: Node3D
var _pool: NpcPool
var _director: CrowdDirector
var _ctx: MatchContext
var _map: RID


func before_each() -> void:
	_world = Node3D.new()
	add_child_autofree(_world)
	_world.add_child((load(MAP_COLLISION) as PackedScene).instantiate())
	_map = get_tree().get_root().get_world_3d().navigation_map

	_pool = NpcPool.new()
	_pool.name = "Crowd"
	_world.add_child(_pool)

	_director = CrowdDirector.new()
	_world.add_child(_director)

	_ctx = MatchContext.new()
	_ctx.map = load(MAP_DATA) as MapData
	_ctx.match_seed = SEED
	_ctx.rng = RandomNumberGenerator.new()
	_ctx.rng.seed = SEED
	_ctx.crowd = _pool


## Stand the crowd up on a synchronised navigation map.
##
## **THE WAIT IS NOT OPTIONAL AND `before_each` CANNOT HOLD IT.** A query before
## the navigation server's second iteration answers with the origin rather than
## an error, so without this the whole crowd is placed in one corner and every
## assertion below becomes a statement about a pile. `before_each`'s coroutine
## returns at its first `await` and the test body runs anyway — which is why the
## wait lives in a function each test awaits explicitly.
func _stand_up() -> void:
	var started: int = NavigationServer3D.map_get_iteration_id(_map)
	for _i: int in 120:
		await get_tree().physics_frame
		if NavigationServer3D.map_get_iteration_id(_map) >= started + 2:
			break

	_pool.preallocate(CROWD)
	_pool.activate(CROWD, SEED, CrowdRoster.PLAYABLE, 6)
	var spots := CrowdPlacement.positions(CROWD, SEED, _ctx.map.idle_anchors, _map)
	for index: int in spots.size():
		_pool.set_position(index, spots[index])
	_director.setup(_ctx)
	# One frame for the bodies to settle onto the floor before anything is
	# measured: the navmesh does not sit on the street (see the height test).
	await get_tree().physics_frame


func _positions() -> PackedVector3Array:
	var out := PackedVector3Array()
	for index: int in CROWD:
		out.append(_pool.body_of(index).global_position)
	return out


## Run the director at the net rate — one tick every second physics frame,
## exactly as `MatchDirector` does. Returns the fastest horizontal speed any NPC
## reached, and the largest number of path queries any one tick issued.
func _run(ticks: int) -> Array:
	var fastest := 0.0
	var most_repaths := 0
	var dt := MatchContext.net_dt()
	for _tick: int in ticks:
		var before := _positions()
		# **THE TICK MUST ADVANCE, AND US-0045 IS THE FIRST THING THAT NOTICED.**
		# `CrowdLod.due()` staggers each band across its own period by `(tick + index)`,
		# so a harness whose `ctx.tick` stays 0 makes only every fifteenth NPC ever
		# eligible to think — and the symptom was twelve NPCs holding formation slots
		# with one of them in `WALKING_GROUP`. `IntegrationHarness` had exactly this
		# defect from US-0036 to US-0031: **zero is a plausible tick.**
		_ctx.tick += 1
		_director.tick(_ctx, dt)
		most_repaths = maxi(most_repaths, _director.served_last_tick)
		await get_tree().physics_frame
		await get_tree().physics_frame
		var after := _positions()
		for index: int in CROWD:
			var step := after[index] - before[index]
			step.y = 0.0
			fastest = maxf(fastest, step.length() / dt)
	return [fastest, most_repaths]


func test_the_agent_is_actually_on_the_npc_scene() -> void:
	# **A CRITERION CAN BE TRUE OF A CLASS AND FALSE OF THE GAME.** Steering with
	# no agent to steer would leave every test below asserting that nothing moved,
	# which is a much less legible failure than this one.
	await _stand_up()
	assert_not_null(_pool.agent_of(0), "npc_server.tscn has no NavigationAgent3D")
	assert_true(_pool.agent_of(0).avoidance_enabled, "avoidance was never switched on")


func test_the_agent_is_configured_from_the_capsule_and_from_tuning() -> void:
	await _stand_up()
	var agent := _pool.agent_of(0)
	# The avoidance radius is the NPC's own capsule, not the navmesh bake's 0.4:
	# they are different quantities and the capsule is the one that says how much
	# room this body takes up.
	assert_almost_eq(agent.radius, 0.35, 0.001, "the avoidance radius is not the capsule's")
	assert_almost_eq(agent.max_speed, Tuning.crowd.npc_speed_flee, 0.001)
	assert_almost_eq(agent.neighbor_distance, Tuning.suspicion.blend_pocket_radius, 0.001)
	assert_almost_eq(agent.target_desired_distance, Tuning.crowd.anchor_arrive_radius, 0.001)


func test_the_crowd_walks() -> void:
	await _stand_up()
	var start := _positions()
	await _run(TICKS)
	var travelled := 0
	for index: int in CROWD:
		var moved := start[index] - _pool.body_of(index).global_position
		moved.y = 0.0
		if moved.length() > 1.0:
			travelled += 1
	gut.p("%d of %d NPCs travelled more than a metre in %d ticks" % [travelled, CROWD, TICKS])
	# Not all of them: an NPC whose anchor was drawn close by arrives and stands,
	# which is the machine working. Most of them is the shape being asserted.
	assert_gt(travelled, CROWD / 2, "most of the crowd never went anywhere")


func test_they_walk_at_the_stroll_speed_and_not_at_half_of_it() -> void:
	# **THE ONE ASSERTION THIS FILE EXISTS FOR.** Both bounds are load-bearing: the
	# lower one catches a crowd driven from the net tick (half speed, silent), and
	# the upper one catches the body being moved twice a frame — which is exactly
	# what a `velocity_computed` handler connected twice would do.
	await _stand_up()
	var measured: Array = await _run(TICKS)
	var fastest: float = measured[0]
	var stroll: float = Tuning.crowd.npc_speed_stroll
	gut.p("fastest NPC observed at %.3f m/s against a stroll of %.3f" % [fastest, stroll])
	assert_gt(fastest, stroll * 0.9, "the crowd is walking slower than TUN-CROWD-NPC-SPEED-STROLL")
	assert_lt(fastest, stroll * 1.2, "the crowd is walking faster than it is allowed to")


func test_no_tick_issues_more_path_queries_than_the_budget() -> void:
	await _stand_up()
	var measured: Array = await _run(TICKS)
	assert_true(
		int(measured[1]) <= Tuning.perf.crowd_repath_per_tick,
		(
			"a tick issued %d path queries, over the %d TUN-PERF-CROWD-REPATH-PER-TICK allows"
			% [int(measured[1]), Tuning.perf.crowd_repath_per_tick]
		)
	)


func test_the_whole_crowd_is_given_somewhere_to_go() -> void:
	# The other half of the stagger: a cap that starved somebody would leave an
	# NPC standing still all match with nothing in any log.
	await _stand_up()
	await _run(30)
	var without := 0
	for index: int in CROWD:
		if _pool.agent_of(index).target_position == Vector3.ZERO:
			without += 1
	assert_eq(without, 0, "%d NPCs were never given a destination" % without)


func test_nobody_falls_through_the_world_or_hovers_over_it() -> void:
	# **THE BAKED NAVMESH DOES NOT SIT ON THE STREET.** Recast rasterises the
	# walkable surface to a whole number of `cell_height` voxels, so a point
	# snapped onto the mesh is a few centimetres up. Placement alone therefore
	# leaves the crowd in the air; gravity in the steering callback is what puts
	# it down, and this is where that stays true.
	await _stand_up()
	await _run(TICKS)
	var wrong: PackedStringArray = []
	for index: int in CROWD:
		var body := _pool.body_of(index)
		var y := body.global_position.y
		if y < VetraioLayout.STREET_Y - 0.5 or y > VetraioLayout.STREET_Y + 0.5:
			wrong.append(
				"Npc%03d at %v on_floor=%s" % [index, body.global_position, str(body.is_on_floor())]
			)
	assert_eq(wrong.size(), 0, "NPCs are not standing on the street:\n" + "\n".join(wrong))


func test_the_navmesh_sits_above_the_street_which_is_why_gravity_is_needed() -> void:
	# Measured rather than assumed, and printed: the number is the reason the
	# steering callback applies gravity at all, and a future bake that put the
	# mesh on the floor would make that code look pointless.
	await _stand_up()
	var street := Vector3(45.0, VetraioLayout.STREET_Y, 15.0)
	var on_mesh := NavigationServer3D.map_get_closest_point(_map, street)
	gut.p("navmesh height above the street: %.3f m" % (on_mesh.y - VetraioLayout.STREET_Y))
	assert_gt(on_mesh.y, VetraioLayout.STREET_Y - 0.01, "the navmesh is below the street")


func test_the_spatial_hash_holds_this_tick_s_crowd_and_not_the_first_one() -> void:
	# **THE ONLY ASSERTION THAT CAN TELL A LIVE HASH FROM A STALE ONE.** A grid
	# built once at setup and never rebuilt has the right *count* forever, and
	# every unit test of the hash would still pass. What it does not have is the
	# crowd's current positions — so after thirty ticks of walking, asking whether
	# each NPC is findable **at its own feet** is the question that separates them.
	#
	# It matters because suspicion runs immediately after the crowd stage and asks
	# "is anybody within `TUN-SUSPICION-OPEN-RADIUS` of me". Against last minute's
	# crowd, a player standing in an emptied plaza would accrue nothing.
	await _stand_up()
	await _run(30)
	assert_eq(_ctx.crowd_hash.count(), CROWD, "the hash does not hold the active crowd")
	var missing := 0
	for index: int in CROWD:
		if _ctx.crowd_hash.count_within(_pool.body_of(index).global_position, 0.5) == 0:
			missing += 1
	assert_eq(missing, 0, "%d NPCs are not where the hash says they are" % missing)


func test_an_idle_npc_stands_still() -> void:
	# Idle is the state with no goal and no speed, and "no goal" is the case that
	# would otherwise re-enter the repath queue every tick and starve the rest.
	await _stand_up()
	var brain := _pool.brain_of(0)
	brain.handle(NpcBrain.Event.REACHED_ANCHOR, _pool.context_of(0))
	assert_eq(brain.state, NpcBrain.State.IDLE, "the brain did not reach Idle")
	var before := _pool.body_of(0).global_position
	await _run(20)
	assert_eq(brain.state, NpcBrain.State.IDLE, "Idle did not last — check TUN-CROWD-IDLE-DURATION")
	var drift := before - _pool.body_of(0).global_position
	drift.y = 0.0
	assert_lt(drift.length(), 0.2, "an idle NPC wandered")


func test_a_startled_npc_is_sent_away_from_what_scared_it() -> void:
	# Nothing sets `startle_flag` until US-0044, so it is set here by hand. The
	# steering layer is what that story will hang off, and a flee direction that
	# pointed at the violence would make the whole startle wave say the opposite
	# of what GDD-03 §6 promises a distant player it says.
	await _stand_up()
	var cctx := _pool.context_of(0)
	var here := _pool.body_of(0).global_position
	cctx.startle_origin = here + Vector3(5.0, 0.0, 0.0)
	cctx.startle_flag = true

	# **A FAR NPC DOES NOT THINK EVERY TICK, AND THAT IS US-0045 WORKING.** Nobody is
	# in `ctx.pawns` here, so the whole crowd is banded Far and steps every
	# fifteenth tick. The flag survives until it does — which is the property
	# `test_crowd_lod.gd` exists to hold, because clearing it meanwhile would drop
	# startles for two thirds of the crowd.
	await _run(CrowdLod.stride_of(CrowdLod.Band.FAR) + 1)
	assert_eq(_pool.brain_of(0).state, NpcBrain.State.STARTLE, "the interrupt did not land")

	# The NPC has been fleeing for a few ticks by now, so its own position has
	# moved; the flee goal is measured from where it was scared, not from where it
	# started the test.
	var goal := _pool.agent_of(0).target_position
	var scared_by := _pool.context_of(0).startle_origin
	assert_lt(goal.x, scared_by.x, "the startled NPC was sent toward what scared it")
	assert_gt(
		goal.distance_to(scared_by),
		Tuning.crowd.npc_speed_flee * Tuning.crowd.startle_duration * 0.9,
		"the flee goal is closer than a full flee would carry it"
	)
