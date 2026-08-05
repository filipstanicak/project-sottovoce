## Every state's `enter()` resets `state_timer_ticks`, and the machine arbitrates
## transitions rather than trusting them.
##
## The timer is how a state knows when its animation is over — a vault ends after
## `TUN-TRAVERSE-VAULT-DURATION` worth of ticks. A state entered without the
## timer reset inherits the previous state's elapsed time, so the first vault
## after a long stroll ends instantly. That reads as the game dropping an input,
## and it is untraceable from the symptom.
extends GutTest


class _Recording:
	extends PawnState

	var entered := 0

	func id() -> StringName:
		return PawnStateId.IDLE

	func enter(ctx: PawnContext) -> void:
		super(ctx)
		entered += 1


class _Stubborn:
	extends PawnState

	func id() -> StringName:
		return PawnStateId.KILL_ANIM

	func interrupt_priority() -> int:
		return PawnState.PRIORITY_COMBAT

	func is_interruptible(_ctx: PawnContext) -> bool:
		return false


func _context() -> PawnContext:
	var ctx := PawnContext.new()
	ctx.state_id = PawnStateId.IDLE
	return ctx


func test_the_base_enter_resets_the_timer() -> void:
	var ctx := _context()
	ctx.state_timer_ticks = 137
	PawnState.new().enter(ctx)
	assert_eq(ctx.state_timer_ticks, 0, "enter() must reset the state timer")


func test_a_subclass_calling_super_still_resets_it() -> void:
	# The realistic failure: a subclass overrides enter(), forgets super(), and
	# inherits the previous state's elapsed ticks.
	var ctx := _context()
	ctx.state_timer_ticks = 99
	var state := _Recording.new()
	state.enter(ctx)
	assert_eq(ctx.state_timer_ticks, 0, "a subclass that calls super() must reset")
	assert_eq(state.entered, 1, "the override ran")


func test_transition_enters_the_target_and_resets() -> void:
	var machine := PawnStateMachine.new()
	var idle := _Recording.new()
	machine.register(idle)
	var ctx := _context()
	ctx.state_id = PawnStateId.KILL_ANIM
	machine.register(_Stubborn.new())
	ctx.state_timer_ticks = 40

	assert_true(machine.transition(ctx, PawnStateId.IDLE, PawnState.PRIORITY_FATAL))
	assert_eq(ctx.state_id, PawnStateId.IDLE)
	assert_eq(ctx.state_timer_ticks, 0, "the target's enter() must have reset the timer")
	machine.free()


func test_an_uninterruptible_state_refuses_a_lower_priority_request() -> void:
	# KillAnim is not interruptible below FATAL. A NORMAL request must bounce, or
	# a player could cancel their own kill by walking.
	var machine := PawnStateMachine.new()
	machine.register(_Recording.new())
	machine.register(_Stubborn.new())
	var ctx := _context()
	ctx.state_id = PawnStateId.KILL_ANIM

	assert_false(
		machine.transition(ctx, PawnStateId.IDLE, PawnState.PRIORITY_NORMAL),
		"a NORMAL request must not interrupt KillAnim"
	)
	assert_eq(ctx.state_id, PawnStateId.KILL_ANIM, "the pawn stayed put")
	assert_true(
		machine.transition(ctx, PawnStateId.IDLE, PawnState.PRIORITY_FATAL),
		"FATAL must get through"
	)
	machine.free()


func test_step_advances_the_timer() -> void:
	var machine := PawnStateMachine.new()
	machine.register(_Recording.new())
	var ctx := _context()
	machine.step(ctx, InputCommand.empty(1), 1.0 / 60.0)
	machine.step(ctx, InputCommand.empty(2), 1.0 / 60.0)
	assert_eq(ctx.state_timer_ticks, 2, "each step is one tick")
	machine.free()


func test_the_context_tolerates_a_null_body() -> void:
	# States must work with no scene tree. If any of this needed ctx.body, the
	# whole suite above would be impossible to write.
	var ctx := _context()
	assert_false(ctx.has_body(), "a fresh context has no body")
	ctx.reset_for_spawn(Vector3(10.0, 0.0, 20.0), 1.5)
	assert_eq(ctx.position, Vector3(10.0, 0.0, 20.0))
	assert_eq(ctx.suspicion, 0.0, "a life never begins already accruing suspicion")
