## **A LOCK CANNOT COMPLETE THROUGH THE GAPS IN A WALKING GROUP.** US-0058,
## GDD-03 §8.4, ANIMATION_SPEC §2.2.
##
## Two rules together make that true, and neither does it alone:
##
## 1. **The fill is longer than one stride cycle.** `TUN-COMPASS-LOCK-FILL-TIME`
##    1.6 s against `ANIM-BLENDWALK-LOOP` 1.15 s, so a gap that opens and closes
##    with the crowd's own gait cannot span a whole lock.
## 2. **An interrupted view nets negative.** The drain is 1.4× the fill, so
##    glimpses do not accumulate — they subtract.
##
## **NPCs DO NOT BLOCK LINE OF SIGHT, AND THAT IS NOT A CONTRADICTION.** GDD-03
## §9.2 keeps the crowd confusing rather than solid, so what a walking group
## actually costs a hunter is their *aim*: the lock cone is 25° total and a target
## moving inside a group is one the hunter keeps losing off the edge of it. This
## file drives that as the cone breaking, which is what happens.
extends GutTest

const HUNTER := 51
const CONTRACT := 52

## `ANIM-BLENDWALK-LOOP`, ANIMATION_SPEC §2.1 row 7. **Transcribed, because it is
## a clip duration and there are no clips in this project** — the same treatment
## `test_compass_curve.gd` gives TUNABLES §4.2's sampled table. §2.2 calls it "a
## tunable-class number living in an animation, which is unusual and worth
## flagging", and this is the flag.
const STRIDE_CYCLE := 1.15

var _system: DetectionSystem
var _ctx: MatchContext
var _t: CompassTuning


func before_each() -> void:
	_t = Tuning.compass
	_system = DetectionSystem.new()
	add_child_autofree(_system)
	_ctx = MatchContext.new()
	_system.setup(_ctx)
	_place(HUNTER, Vector3.ZERO, 0.0)
	_place(CONTRACT, Vector3(0.0, 0.0, 10.0))
	_ctx.announced_contracts[HUNTER] = CONTRACT


func _place(peer: int, at: Vector3, yaw := 0.0) -> PawnContext:
	var pawn := PawnContext.new()
	pawn.peer_id = peer
	pawn.reset_for_spawn(at, yaw)
	pawn.state_id = PawnStateId.IDLE
	_ctx.pawn_contexts[peer] = pawn
	return pawn


func _look_at(yaw: float) -> void:
	(_ctx.pawn_contexts[HUNTER] as PawnContext).yaw = yaw


func _stand(peer: int, at: Vector3) -> void:
	(_ctx.pawn_contexts[peer] as PawnContext).position = at


func _watch(seconds: float) -> void:
	for _step: int in int(round(seconds * Tuning.net.server_tick)):
		_ctx.tick += 1
		_system.tick(_ctx, MatchContext.net_dt())


func _arc() -> float:
	return _ctx.compass.lock_of(HUNTER)


func test_the_fill_outlasts_one_stride_cycle() -> void:
	# **THE NUMBER THE WHOLE CLAIM RESTS ON.** ANIMATION_SPEC §2.2 says changing
	# the stride cycle changes the Compass lock's behaviour; this is where somebody
	# finds out that it did.
	assert_gt(
		_t.lock_fill_time,
		STRIDE_CYCLE,
		"the fill no longer outlasts ANIM-BLENDWALK-LOOP — a lock can complete through a gait"
	)


func test_a_clear_steady_view_completes() -> void:
	# **THE PREMISE.** Every negative below would be true of a lock that never
	# fills at all.
	_watch(_t.lock_fill_time + 0.2)
	assert_eq(_arc(), 1.0, "a clear 10 m view straight ahead did not complete a lock")
	assert_true(_ctx.compass.portrait_of(HUNTER), "a completed lock earned no portrait")


func test_glimpses_at_the_gait_of_a_walking_group_never_complete() -> void:
	# The target drifts in and out of the 25° cone at the crowd's own rhythm — a
	# half stride in view, a half stride out — for twenty cycles.
	var best := 0.0
	for _cycle: int in 20:
		_look_at(0.0)
		_watch(STRIDE_CYCLE * 0.5)
		best = maxf(best, _arc())
		_look_at(PI)
		_watch(STRIDE_CYCLE * 0.5)
	gut.p("twenty stride-length glimpses reached %.2f of the arc at best" % best)
	assert_lt(best, 1.0, "a lock completed through the gaps in a walking group")
	assert_false(_ctx.compass.portrait_of(HUNTER), "a glimpsed contract was identified")


func test_the_cone_is_the_total_width_not_the_half() -> void:
	# `TUN-COMPASS-LOCK-CONE` 25° means ±12.5°. Read as a half-width it would be
	# twice as forgiving, which is exactly the mistake that makes locking through a
	# crowd easy and would leave every test above passing.
	var half := deg_to_rad(_t.lock_cone) * 0.5
	_stand(CONTRACT, Vector3(sin(half * 0.8), 0.0, cos(half * 0.8)) * 10.0)
	_watch(_t.lock_fill_time + 0.2)
	assert_eq(_arc(), 1.0, "a contract inside the cone did not lock")

	_system.lock.clear()
	_stand(CONTRACT, Vector3(sin(half * 1.2), 0.0, cos(half * 1.2)) * 10.0)
	_watch(_t.lock_fill_time + 0.2)
	assert_eq(_arc(), 0.0, "a contract outside the cone locked anyway")


func test_range_gates_it() -> void:
	_stand(CONTRACT, Vector3(0.0, 0.0, _t.lock_range + 2.0))
	_watch(_t.lock_fill_time + 0.2)
	assert_eq(_arc(), 0.0, "a contract past TUN-COMPASS-LOCK-RANGE locked")
	_stand(CONTRACT, Vector3(0.0, 0.0, _t.lock_range - 2.0))
	_watch(_t.lock_fill_time + 0.2)
	assert_eq(_arc(), 1.0, "a contract inside the range did not lock")


func test_the_lock_is_the_first_thing_in_this_project_to_spend_a_raycast() -> void:
	# **`TUN-COMPASS-LOCK-REQUIRES-LOS` IS TRUE**, and this is `has_los()`'s first
	# caller. The render matrix beside it spends none, so a non-zero count here is
	# the lock and nothing else.
	assert_true(
		_t.lock_requires_los, "TUN-COMPASS-LOCK-REQUIRES-LOS is false — this proves nothing"
	)
	_watch(0.2)
	assert_gt(_system.raycasts_last_tick, 0, "the lock did not check line of sight")
	assert_lte(_system.raycasts_last_tick, 6, "more raycasts a tick than TDD-07 §4.3 budgets")


func test_a_hunter_looking_the_wrong_way_costs_no_raycast() -> void:
	# The early-out ladder, measured: the cone is one angle comparison and the range
	# is a number already computed for the bearing, so the raycast is last.
	_look_at(PI)
	_watch(0.2)
	assert_eq(_system.raycasts_last_tick, 0, "a hunter facing away still cast a ray")


func test_a_wall_between_them_stops_the_lock() -> void:
	var wall := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(6.0, 6.0, 1.0)
	shape.shape = box
	wall.add_child(shape)
	wall.collision_layer = 1
	add_child_autofree(wall)
	wall.global_position = Vector3(0.0, 0.0, 5.0)
	await get_tree().physics_frame
	_watch(_t.lock_fill_time + 0.2)
	assert_eq(_arc(), 0.0, "a lock completed through a wall")


func test_no_contract_means_no_arc_at_all() -> void:
	_ctx.announced_contracts.erase(HUNTER)
	_watch(_t.lock_fill_time + 0.2)
	assert_eq(_arc(), 0.0, "a hunter with no contract filled an arc")
	assert_false(_ctx.compass.portrait_of(HUNTER), "a hunter with no contract had a portrait")
