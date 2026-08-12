## **SLOWING DOWN IS NEVER GATED, NEVER DELAYED, NEVER REFUSED.**
##
## US-0015 calls this the critical test, and ROADMAP §3.1 makes it a milestone
## exit criterion: *"slowing down is instant from every state, at every speed."*
##
## It is the escape hatch the whole speed economy depends on. Design law 1 says
## speed is spent anonymity — that only reads as a trade if the player can stop
## spending at any instant. A slow key that sometimes takes four ticks to answer
## converts a deliberate cost into an unpredictable one, and a player who cannot
## predict the cost stops using the ladder rather than learning it.
##
## Enumerated over every locomotion state at every speed, rather than spot-
## checked, because "from every state, at every speed" is the actual guarantee
## and a sample would leave the one broken rung to be found in a playtest.
extends GutTest

var _machine: PawnStateMachine


func before_each() -> void:
	_machine = PawnStateMachine.new()
	_machine.register(IdleState.new())
	_machine.register(BlendWalkState.new())
	_machine.register(StrollState.new())
	_machine.register(RunState.new())
	_machine.register(SprintState.new())


func after_each() -> void:
	_machine.free()


func _ctx_in(state: StringName, speed: float) -> PawnContext:
	var ctx := PawnContext.new()
	ctx.state_id = state
	ctx.velocity = Vector3(0.0, 0.0, speed)
	ctx.grounded = true
	return ctx


func _slow_input() -> InputCommand:
	var input := InputCommand.empty(1)
	input.slow = true
	input.move = Vector2(0.0, 1.0)
	return input


## Every speed on the ladder, so "at every speed" is literal.
func _speeds() -> Array[float]:
	return [
		0.0,
		Tuning.movement.blend_walk,
		Tuning.movement.stroll,
		Tuning.movement.run,
		Tuning.movement.sprint,
	]


func test_slow_reaches_blend_walk_in_one_tick_from_every_state() -> void:
	var failures: PackedStringArray = []
	for state: StringName in PawnStateId.LOCOMOTION:
		for speed: float in _speeds():
			var ctx := _ctx_in(state, speed)
			_machine.step(ctx, _slow_input(), 1.0 / 60.0)
			if ctx.state_id != PawnStateId.BLEND_WALK:
				failures.append(
					"%s at %.1f m/s -> %s after ONE tick" % [state, speed, ctx.state_id]
				)
	assert_eq(
		failures.size(),
		0,
		(
			"INPUT-SLOW did not reach BlendWalk in one tick.\n"
			+ "This is the escape hatch the speed economy depends on (ADR-0012).\n"
			+ "\n".join(failures)
		)
	)


func test_the_graph_permits_slowing_from_every_state() -> void:
	# The transition above could only succeed because the edge is legal. Asserted
	# separately so a failure says WHICH half broke.
	var illegal: PackedStringArray = []
	for state: StringName in PawnStateId.LOCOMOTION:
		if state == PawnStateId.BLEND_WALK:
			continue
		if not PawnTransitions.allows(state, PawnStateId.BLEND_WALK):
			illegal.append("%s -> BlendWalk is not a legal edge" % state)
	assert_eq(illegal.size(), 0, "ADR-0012 requires these edges.\n" + "\n".join(illegal))


func test_releasing_movement_reaches_idle_in_one_tick_from_every_state() -> void:
	# The other wildcard row in GDD-02 §2.2, and the other half of ADR-0012.
	var failures: PackedStringArray = []
	for state: StringName in PawnStateId.LOCOMOTION:
		if state == PawnStateId.IDLE:
			continue
		for speed: float in _speeds():
			var ctx := _ctx_in(state, speed)
			_machine.step(ctx, InputCommand.empty(1), 1.0 / 60.0)
			if ctx.state_id != PawnStateId.IDLE:
				failures.append("%s at %.1f m/s -> %s" % [state, speed, ctx.state_id])
	assert_eq(failures.size(), 0, "Releasing movement did not reach Idle.\n" + "\n".join(failures))


func test_slowing_is_never_refused_by_an_interrupt_rule() -> void:
	# A locomotion state that declared itself uninterruptible would silently gate
	# the escape hatch while every edge above still looked legal.
	var offenders: PackedStringArray = []
	for state: StringName in PawnStateId.LOCOMOTION:
		var obj := _machine.state_for(state)
		if not obj.is_interruptible(PawnContext.new()):
			offenders.append(String(state))
	assert_eq(
		offenders.size(), 0, "a locomotion state refuses interruption: " + ", ".join(offenders)
	)


func test_deceleration_is_faster_than_acceleration() -> void:
	# The asymmetry IS the thesis. If these ever equalise, stopping costs what
	# starting costs, and the defensive option stops being cheap.
	assert_gt(
		Tuning.movement.decel,
		Tuning.movement.accel,
		"stopping must be faster than starting (GDD-02 §2.2)"
	)


func test_slowing_decelerates_on_the_very_first_tick() -> void:
	# Not just the state label — the velocity must fall too, or "instant" is a
	# lie told by a state machine while the pawn is still travelling at sprint.
	var ctx := _ctx_in(PawnStateId.SPRINT, Tuning.movement.sprint)
	var before := ctx.velocity.length()
	_machine.step(ctx, _slow_input(), 1.0 / 60.0)
	assert_lt(ctx.velocity.length(), before, "velocity did not fall on the first tick")
