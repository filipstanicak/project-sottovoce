## Climb. GDD-02 §3.1 and §6, US-0020.
##
## **THE ROOFS ARE A HIGHWAY WITH A TOLL BOOTH**, and the toll is charged per
## metre. `TUN-SPEED-CLIMB` 2.8 m/s against `TUN-SUSPICION-GAIN-CLIMB` 12/s is
## 4.3 suspicion for every metre gained, so a 9 m façade costs 38.6 and puts you
## at **Noticed** before you arrive.
##
## The per-metre pricing is the assertion that matters. A fixed climb duration
## would make a 9 m façade cost what a 3 m one does, and §6.1's whole route
## economy — vertical costs, horizontal slow pays, down is free — rests on it
## not doing that.
extends GutTest

const DT := 1.0 / 60.0

var _state: ClimbState
var _ctx: PawnContext


func before_each() -> void:
	_state = ClimbState.new()
	_ctx = PawnContext.new()
	_ctx.state_id = PawnStateId.CLIMB


func _plan(height: float) -> void:
	_ctx.traverse_case = TraversalResolver.Case.CLIMB
	_ctx.traverse_start = Vector3.ZERO
	_ctx.traverse_target = Vector3(0.0, height, 0.9)
	_ctx.traverse_peak_y = height
	_ctx.position = Vector3.ZERO


func _forward_input() -> InputCommand:
	var input := InputCommand.empty(1)
	input.move = Vector2(0.0, 1.0)
	return input


func _backward_input() -> InputCommand:
	var input := InputCommand.empty(1)
	input.move = Vector2(0.0, -1.0)
	return input


# ------------------------------------------------------------- the price --


func test_it_climbs_at_the_tuned_speed() -> void:
	_plan(2.8)
	# One metre per 1/2.8 s. A 2.8 m face is exactly one second.
	assert_eq(ClimbState.duration_ticks(_ctx), int(round(Tuning.net.client_input_rate)))
	assert_almost_eq(Tuning.movement.climb, 2.8, 0.001)


func test_a_taller_face_takes_proportionally_longer() -> void:
	# **THE ASSERTION THIS FILE EXISTS FOR.** Per metre, not per manoeuvre.
	_plan(3.0)
	var short := ClimbState.duration_ticks(_ctx)
	_plan(9.0)
	var tall := ClimbState.duration_ticks(_ctx)
	assert_almost_eq(float(tall) / float(short), 3.0, 0.05, "climbing is not priced per metre")


func test_a_full_stratum_climb_costs_what_the_cost_table_says() -> void:
	# GDD-02 §6: a 9 m climb is 3.2 s and +38.6 suspicion — Noticed before you
	# arrive. If either number drifts, the roof economy changes without anyone
	# deciding to change it.
	_plan(Tuning.movement.traverse_climb_max_height)
	var seconds := ClimbState.duration_ticks(_ctx) / Tuning.net.client_input_rate
	assert_almost_eq(seconds, 3.2, 0.1, "a 9 m climb no longer takes 3.2 s")
	assert_almost_eq(seconds * Tuning.suspicion.gain_climb, 38.6, 1.5, "the 9 m toll moved")


func test_it_costs_the_climb_rate_throughout() -> void:
	_plan(4.0)
	assert_eq(_state.suspicion_rate(_ctx), Tuning.suspicion.gain_climb)


func test_climbing_costs_less_per_second_than_standing_on_the_roof() -> void:
	# §6: "Lower than roof-presence because a climb is brief and sometimes
	# necessary; the roof you arrive at is what really costs." If these inverted,
	# lingering on a wall would be cheaper than crossing and dropping.
	assert_lt(Tuning.suspicion.gain_climb, Tuning.suspicion.gain_roof)


# ------------------------------------------------------------- the climb --


func test_it_rises_to_the_top_and_ends() -> void:
	_plan(4.0)
	var ticks := ClimbState.duration_ticks(_ctx)
	var out := PawnState.STAY
	for _i: int in ticks + 2:
		_ctx.state_timer_ticks += 1
		out = _state.step(_ctx, _forward_input(), DT)
		if out != PawnState.STAY:
			break
	assert_eq(out, PawnStateId.IDLE, "the climb never reached the top")
	assert_almost_eq(_ctx.position.distance_to(_ctx.traverse_target), 0.0, 0.001)


func test_it_gains_height_monotonically() -> void:
	# A climb that dipped would read as slipping, which is a different mechanic
	# and one this game does not have.
	_plan(6.0)
	var ticks := ClimbState.duration_ticks(_ctx)
	var last := -1.0
	for _i: int in ticks:
		_ctx.state_timer_ticks += 1
		_state.step(_ctx, _forward_input(), DT)
		assert_true(_ctx.position.y >= last - 0.0001, "the climb lost height")
		last = _ctx.position.y


func test_the_plan_owns_the_position() -> void:
	# Trap 7: without this the driver runs move_and_slide() and overwrites the
	# climb from a body that, with the velocity frozen, has not moved.
	assert_true(_state.drives_position(), "the climb does not claim its own position")


# ------------------------------------------------------------ letting go --


func test_pulling_away_lets_go_into_a_drop() -> void:
	# GDD-02 §3.1: a climb exits at the "top / release / stun". A commitment you
	# could not back out of would make every façade a gamble on what is over it.
	_plan(9.0)
	_ctx.state_timer_ticks += 30
	_state.step(_ctx, _forward_input(), DT)
	var height := _ctx.position.y
	assert_gt(height, 0.0, "the pawn had not left the ground yet")

	_ctx.state_timer_ticks += 1
	assert_eq(_state.step(_ctx, _backward_input(), DT), PawnStateId.DROP, "letting go did nothing")
	assert_eq(_ctx.traverse_case, TraversalResolver.Case.DROP)


func test_letting_go_falls_back_to_where_the_climb_began() -> void:
	# The climb's own start IS the ground — the pawn was standing on it a moment
	# ago. The probes cannot help: a pawn halfway up a wall has nothing under its
	# forward casts.
	_plan(9.0)
	_ctx.state_timer_ticks += 40
	_state.step(_ctx, _forward_input(), DT)
	var height := _ctx.position.y
	_ctx.state_timer_ticks += 1
	_state.step(_ctx, _backward_input(), DT)

	assert_almost_eq(_ctx.traverse_start.y, height, 0.01, "the fall does not start where it let go")
	assert_almost_eq(_ctx.traverse_target.y, 0.0, 0.01, "the fall does not reach the ground")


func test_holding_forward_never_lets_go() -> void:
	_plan(6.0)
	for _i: int in 20:
		_ctx.state_timer_ticks += 1
		assert_eq(
			_state.step(_ctx, _forward_input(), DT), PawnState.STAY, "it let go while climbing"
		)


func test_no_input_at_all_never_lets_go() -> void:
	# Only pulling AWAY releases. A player who takes their hand off the stick is
	# still climbing, which is what makes the climb an action rather than a hold.
	_plan(6.0)
	for _i: int in 20:
		_ctx.state_timer_ticks += 1
		assert_eq(_state.step(_ctx, InputCommand.empty(1), DT), PawnState.STAY)


# ------------------------------------------------------ interruptibility --


func test_combat_may_interrupt_but_nothing_below_it() -> void:
	assert_false(_state.is_interruptible(_ctx))
	assert_eq(_state.interrupt_priority(), PawnState.PRIORITY_NORMAL)

	var machine := PawnStateMachine.new()
	machine.register(ClimbState.new())
	machine.register(IdleState.new())
	machine.register(StunnedState.new())
	_plan(6.0)
	assert_false(machine.transition(_ctx, PawnStateId.IDLE, PawnState.PRIORITY_NORMAL))
	assert_true(
		machine.transition(_ctx, PawnStateId.STUNNED, PawnState.PRIORITY_COMBAT),
		"a stun could not take a climber off a wall"
	)
	machine.free()


func test_a_zero_height_plan_does_not_trap_the_pawn() -> void:
	_plan(0.0)
	_ctx.state_timer_ticks += 1
	assert_ne(_state.step(_ctx, _forward_input(), DT), PawnState.STAY)
