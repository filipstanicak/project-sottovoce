## **THE SERVER HONOURS `FOLLOW` ONLY IN A WALKING GROUP, HANDS OFF.** Review of #253.
##
## The bit lifts the backpedal penalty: trusted from any command, setting it let a
## player walk backwards at full stroll anywhere — 2.2 m/s against 1.21. These go
## through `PawnHost.screen_follow` and the shared state machine the server steps.
extends GutTest

const DT := 1.0 / 60.0

var _machine: PawnStateMachine


func before_each() -> void:
	_machine = PawnStateMachine.new()
	for script: GDScript in PawnStateMachine.REGISTERED:
		_machine.register(script.new())


func after_each() -> void:
	_machine.free()


func _backwards(follow: bool, extra := InputBits.NONE) -> InputCommand:
	var command := InputCommand.empty(1)
	command.move = Vector2(0, -1)
	command.buttons |= extra
	command.follow = follow
	return command


## Speed after two seconds of the command, screened as the server screens it.
func _speed(blend_state: int, command: InputCommand) -> float:
	var ctx := PawnContext.new()
	ctx.state_id = PawnStateId.IDLE
	ctx.position = Vector3(20, 0, 20)
	ctx.grounded = true
	ctx.blend_state = blend_state
	for _i: int in 120:
		var each := command.duplicate_command()
		PawnHost.screen_follow(each, ctx)
		ctx.state_timer_ticks += 1
		_machine.step(ctx, each, DT)
	return Vector2(ctx.velocity.x, ctx.velocity.z).length()


func test_outside_a_group_the_bit_buys_nothing() -> void:
	var honest := _speed(BlendKind.Kind.NONE, _backwards(false))
	var forged := _speed(BlendKind.Kind.NONE, _backwards(true))
	assert_almost_eq(forged, honest, 0.01, "a forged FOLLOW walked backwards faster")
	assert_lt(forged, Tuning.movement.stroll * 0.6, "PREMISE: walking backwards is slow")


func test_after_the_group_ends_the_bit_buys_nothing() -> void:
	for state: int in [BlendKind.Kind.POCKET, BlendKind.Kind.PROP_STATIC]:
		var forged := _speed(state, _backwards(true))
		assert_lt(
			forged, Tuning.movement.stroll * 0.6, "FOLLOW honoured while blended as %d" % state
		)


func test_an_action_beside_the_bit_strips_it() -> void:
	for bit: int in [InputBits.KILL, InputBits.STUN, InputBits.ABILITY_1, InputBits.BLEND]:
		var command := _backwards(true, bit)
		var ctx := PawnContext.new()
		ctx.blend_state = BlendKind.Kind.GROUP
		PawnHost.screen_follow(command, ctx)
		assert_false(
			command.follow, "FOLLOW kept beside bit %d, so the action faced the travel" % bit
		)


func test_in_a_group_hands_off_the_bit_is_honoured() -> void:
	var carried := _speed(BlendKind.Kind.GROUP, _backwards(true))
	assert_gt(
		carried, Tuning.movement.stroll * 0.9, "the group could not walk a player looking back"
	)
