## **A PLAYER IN A WALKING GROUP IS WALKED ALONG WITH IT.** US-0107, 2026-10-09.
##
## The reference takes over a player who joins a group, until they walk out (the
## owner, from playing it). These run the client's steering through the same state
## machine the server simulates, against a slot moving at the group's pace and
## turning a corner, with the camera looking back over the player's shoulder.
extends GutTest

const DT := 1.0 / 60.0
## Behind the travel: the case that broke a hand-walked blend, because a pawn
## facing its camera walked backwards at `TUN-SPEED-BACKPEDAL-MULT`.
const LOOKING_BACK := PI

var _machine: PawnStateMachine


func before_each() -> void:
	_machine = PawnStateMachine.new()
	for script: GDScript in PawnStateMachine.REGISTERED:
		_machine.register(script.new())


func after_each() -> void:
	_machine.free()


## Where the slot is `t` seconds in: east at the group's pace for five seconds,
## then north.
func _slot_at(t: float) -> Vector3:
	var pace := Tuning.crowd.npc_speed_stroll
	if t <= 5.0:
		return Vector3(20.0 + pace * t, 0.0, 20.0)
	return Vector3(20.0 + pace * 5.0, 0.0, 20.0 + pace * (t - 5.0))


## Ten seconds of following; returns `[worst gap after settling, fastest speed,
## worst facing error while moving]`.
func _follow(with_bit: bool) -> Array:
	var ctx := PawnContext.new()
	ctx.state_id = PawnStateId.IDLE
	ctx.position = _slot_at(0.0)
	ctx.grounded = true
	var worst := 0.0
	var fastest := 0.0
	var facing := 0.0
	for frame: int in 600:
		var t := frame * DT
		var velocity := (_slot_at(t + DT) - _slot_at(t)) / DT
		var steered := GroupFollowSteer.steer(
			ctx.position, _slot_at(t), velocity, 0.0, LOOKING_BACK
		)
		var command := InputCommand.empty(frame)
		command.look_yaw = LOOKING_BACK
		command.move = InputCodec.quantise_move(steered[0])
		command.slow = steered[1]
		command.follow = with_bit
		ctx.state_timer_ticks += 1
		_machine.step(ctx, command, DT)
		ctx.yaw = PawnMotion.facing(ctx, command)
		ctx.position += Vector3(ctx.velocity.x, 0.0, ctx.velocity.z) * DT
		var flat := Vector2(ctx.velocity.x, ctx.velocity.z)
		fastest = maxf(fastest, flat.length())
		if t > 1.0:
			worst = maxf(
				worst,
				Vector2(ctx.position.x, ctx.position.z).distance_to(
					Vector2(_slot_at(t + DT).x, _slot_at(t + DT).z)
				)
			)
			if flat.length() > 1.0:
				facing = maxf(facing, absf(angle_difference(ctx.yaw, atan2(flat.x, flat.y))))
	return [worst, fastest, facing]


func test_a_group_walks_the_player_inside_the_slot_tolerance() -> void:
	var result := _follow(true)
	assert_lt(
		float(result[0]),
		Tuning.suspicion.blend_group_slot_tolerance * 0.5,
		"the steered player drifted toward the edge of the slot, round a corner"
	)


func test_it_never_reaches_the_speed_that_breaks_a_blend() -> void:
	assert_lt(float(_follow(true)[1]), Tuning.suspicion.break_on_speed)


func test_the_walked_player_faces_its_travel_as_the_group_does() -> void:
	assert_lt(
		float(_follow(true)[2]), deg_to_rad(10.0), "a figure walking sideways in a procession"
	)


func test_without_the_follow_bit_looking_back_loses_the_group() -> void:
	# The counterfactual: the same steering, read as a hand-walked pawn facing its
	# camera, backpedals at a fraction of the group's pace and falls out of the slot.
	assert_gt(float(_follow(false)[0]), Tuning.suspicion.blend_group_slot_tolerance)


func test_the_steering_stands_still_on_a_slot_that_has_stopped() -> void:
	var here := Vector3(10, 0, 10)
	var steered := GroupFollowSteer.steer(here, here, Vector3.ZERO, 0.1, 0.0)
	assert_eq(steered[0], Vector2.ZERO)


func test_the_command_is_in_the_camera_frame() -> void:
	# Slot due east of the player, camera facing east: straight ahead on the stick.
	var east := PI / 2.0
	var steered := GroupFollowSteer.steer(Vector3.ZERO, Vector3(0.3, 0, 0), Vector3.ZERO, 0.0, east)
	var move: Vector2 = steered[0]
	assert_almost_eq(move.x, 0.0, 0.001, "the stick pushed sideways for a slot straight ahead")
	assert_gt(move.y, 0.0)
	var world := ProbeLayout.right(east) * move.x + ProbeLayout.forward(east) * move.y
	assert_gt(world.x, 0.0, "the stick points away from the slot")
