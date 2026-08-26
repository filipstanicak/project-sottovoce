## **THE COMPASS REACHES ITS HUNTER, AND NOBODY ELSE.** US-0057, GDD-03 §8.
##
## `CompassMath` is pure and tested beside it. What this file tests is the pass:
## that a reading is made for every hunter with an **announced** contract and for
## no one else, that the distance is a bucket before it leaves the system, and
## that a hunter between contracts gets a Compass that says nothing rather than
## one pointing plausibly at the origin.
extends GutTest

const HUNTER := 21
const PREY := 22
const BYSTANDER := 23

var _system: DetectionSystem
var _ctx: MatchContext
var _t: CompassTuning


func before_each() -> void:
	_t = Tuning.compass
	_system = DetectionSystem.new()
	add_child_autofree(_system)
	_ctx = MatchContext.new()
	_system.setup(_ctx)
	_place(HUNTER, Vector3.ZERO)
	_place(PREY, Vector3(0.0, 0.0, 20.0))
	_place(BYSTANDER, Vector3(50.0, 0.0, 50.0))


func _place(peer: int, at: Vector3) -> PawnContext:
	var pawn := PawnContext.new()
	pawn.peer_id = peer
	pawn.reset_for_spawn(at, 0.0)
	pawn.state_id = PawnStateId.IDLE
	_ctx.pawn_contexts[peer] = pawn
	return pawn


func _tell(peer: int, contract: int) -> void:
	_ctx.announced_contracts[peer] = contract


func _resolve() -> void:
	_ctx.tick += 1
	_system.tick(_ctx, MatchContext.net_dt())


func test_a_hunter_with_a_contract_gets_a_reading() -> void:
	_tell(HUNTER, PREY)
	_resolve()
	assert_true(_ctx.compass.has_reading(HUNTER), "a hunter with a contract got no Compass")
	assert_eq(_ctx.compass.hunters(), 1, "%d readings for one contract" % _ctx.compass.hunters())


func test_a_player_with_no_announced_contract_gets_nothing() -> void:
	# **THE BREATH.** `TUN-CONTRACT-REASSIGN-DELAY` leaves a killer with no
	# announced contract for three seconds, and a Compass pointing due +Z at zero
	# metres would be followed. `NO_CONTRACT` is 255 rather than 0 for the same
	# reason: bucket 0 is a real reading, and it is the one that matters most.
	_resolve()
	assert_false(_ctx.compass.has_reading(HUNTER), "a player with no contract got a Compass")
	assert_eq(
		_ctx.compass.bucket_of(HUNTER), CompassBoard.NO_CONTRACT, "no contract read as a distance"
	)
	assert_ne(CompassBoard.NO_CONTRACT, 0, "NO_CONTRACT collides with standing on the contract")


func test_the_reading_follows_the_announced_contract_not_the_graph() -> void:
	# The same rule the render state follows, for the same reason — and here it is
	# sharper, because the Compass *is* the thing the breath exists to withhold.
	_resolve()
	assert_false(_ctx.compass.has_reading(HUNTER), "the premise failed")
	_tell(HUNTER, PREY)
	_resolve()
	assert_true(_ctx.compass.has_reading(HUNTER), "an announced contract produced no Compass")


func test_the_bearing_points_at_the_contract_within_the_wobble() -> void:
	_tell(HUNTER, PREY)
	_resolve()
	var truth := CompassMath.bearing_to(Vector3.ZERO, Vector3(0.0, 0.0, 20.0))
	var drift: float = absf(CompassMath.angle_between(truth, _ctx.compass.bearing_of(HUNTER)))
	assert_lte(
		drift, deg_to_rad(_t.cone_wobble) + 0.001, "the bearing is further off than the wobble"
	)


func test_the_distance_is_a_bucket_and_never_the_exact_metres() -> void:
	# **GDD-03 §8.5: NEARER, NEVER HOW FAR.** The bucket leaves the system already
	# quantised, so nothing downstream can hold the precision the server refused —
	# the rule lives in the value rather than in whoever reads it next.
	_tell(HUNTER, PREY)
	_resolve()
	var bucket := _ctx.compass.bucket_of(HUNTER)
	assert_eq(bucket, Quantise.distance_to_bucket(20.0), "the bucket is not the tuned quantisation")
	assert_almost_eq(
		Quantise.bucket_to_distance(bucket), 20.0, Quantise.BUCKET_STEP, "off by a bucket"
	)


func test_two_positions_inside_one_bucket_are_indistinguishable() -> void:
	# The counterfactual: a "bucket" that round-tripped the exact metres would
	# satisfy the test above and leak everything.
	_tell(HUNTER, PREY)
	_resolve()
	var near := _ctx.compass.bucket_of(HUNTER)
	(_ctx.pawn_contexts[PREY] as PawnContext).position = Vector3(
		0.0, 0.0, 20.0 + Quantise.BUCKET_STEP * 0.4
	)
	_resolve()
	assert_eq(_ctx.compass.bucket_of(HUNTER), near, "a sub-bucket step changed the reading")


func test_a_bystander_is_told_nothing_about_a_hunt_they_are_not_in() -> void:
	_tell(HUNTER, PREY)
	_resolve()
	assert_false(_ctx.compass.has_reading(BYSTANDER), "a bystander received a Compass")
	assert_false(_ctx.compass.has_reading(PREY), "the prey was given their pursuer's bearing")


func test_the_board_is_rebuilt_rather_than_accumulated() -> void:
	# A stale reading is a cone pointing at where a contract used to be, and it
	# would persist for the rest of the match.
	_tell(HUNTER, PREY)
	_resolve()
	assert_true(_ctx.compass.has_reading(HUNTER), "the premise failed")
	_ctx.announced_contracts.erase(HUNTER)
	_resolve()
	assert_false(_ctx.compass.has_reading(HUNTER), "a reading outlived the contract that caused it")


func test_a_contract_who_left_leaves_no_bearing_behind() -> void:
	_tell(HUNTER, PREY)
	_resolve()
	_ctx.pawn_contexts.erase(PREY)
	_resolve()
	assert_false(_ctx.compass.has_reading(HUNTER), "a departed contract still had a bearing")


func test_the_bearing_is_not_gated_on_line_of_sight() -> void:
	# **A COMPASS THAT NEEDED A CLEAR LINE WOULD STOP POINTING FOR MOST OF A HUNT.**
	# Bearing and distance are arithmetic; the raycast belongs to the **lock**
	# (US-0058), which is gated on `TUN-COMPASS-LOCK-REQUIRES-LOS` and is a
	# different question.
	#
	# This assertion used to read "the pass spends no raycast", which was true of
	# US-0057 and stopped being true the moment the lock arrived — and it was never
	# the property that mattered. What matters is that a wall does not switch the
	# Compass off.
	var wall := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(8.0, 8.0, 1.0)
	shape.shape = box
	wall.add_child(shape)
	wall.collision_layer = 1
	add_child_autofree(wall)
	wall.global_position = Vector3(0.0, 0.0, 10.0)
	await get_tree().physics_frame
	_tell(HUNTER, PREY)
	_resolve()
	assert_true(_ctx.compass.has_reading(HUNTER), "a wall switched the Compass off")
	assert_eq(_ctx.compass.lock_of(HUNTER), 0.0, "a lock filled through a wall")


func test_a_contract_beyond_range_still_gets_a_bearing() -> void:
	# 60 m guarantees that on a 120 m map a hunter is almost never *without* signal,
	# so the hunt never stalls — and past it the pulse simply stops slowing. What
	# must not happen is the reading disappearing.
	(_ctx.pawn_contexts[PREY] as PawnContext).position = Vector3(0.0, 0.0, _t.range_max * 1.5)
	_tell(HUNTER, PREY)
	_resolve()
	assert_true(_ctx.compass.has_reading(HUNTER), "a distant contract switched the Compass off")
	var metres := Quantise.bucket_to_distance(_ctx.compass.bucket_of(HUNTER))
	assert_almost_eq(
		CompassMath.period_for(metres, _t), _t.pulse_max, 0.001, "the pulse did not flatten"
	)
