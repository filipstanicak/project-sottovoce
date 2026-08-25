## Vault and mantle. GDD-02 §3.1 and §6, US-0019.
##
## **A VAULT IS FREE AND A MANTLE IS NOT.** That asymmetry is the whole reason
## the two share a state and still need telling apart. Vault is the only athletic
## move in the game that costs no suspicion, and it is the backbone of
## ground-level route-finding — design law 4 needs patience to have *options* at
## civilian speed, not merely safety.
##
## The trajectory is asserted as arithmetic rather than watched, because "the
## pawn ends up on the far side" is a simulation claim, not a rendering one, and
## a vault that passed through the wall would look wrong long before anyone could
## say why.
extends GutTest

const DT := 1.0 / 60.0

var _state: VaultState
var _ctx: PawnContext


func before_each() -> void:
	_state = VaultState.new()
	_ctx = PawnContext.new()
	_ctx.state_id = PawnStateId.VAULT


## A committed vault over a `top`-high wall, landing `ahead` metres on.
func _plan_vault(top: float = 0.9, ahead: float = 1.4) -> void:
	_ctx.traverse_case = TraversalResolver.Case.VAULT
	_ctx.traverse_start = Vector3.ZERO
	_ctx.traverse_target = Vector3(0.0, 0.0, ahead)
	_ctx.traverse_peak_y = top + Tuning.movement.probe_height_foot


func _plan_mantle(top: float = 1.8, ahead: float = 0.9) -> void:
	_ctx.traverse_case = TraversalResolver.Case.MANTLE
	_ctx.traverse_start = Vector3.ZERO
	_ctx.traverse_target = Vector3(0.0, top, ahead)
	_ctx.traverse_peak_y = top


func _run_to_completion() -> StringName:
	var out := PawnState.STAY
	for _i: int in TraversalResolver.duration_ticks(_ctx.traverse_case) + 2:
		_ctx.state_timer_ticks += 1
		out = _state.step(_ctx, InputCommand.empty(1), DT)
		if out != PawnState.STAY:
			break
	return out


# ------------------------------------------------------------- durations --


func test_a_vault_lasts_its_tunable() -> void:
	assert_eq(
		TraversalResolver.duration_ticks(TraversalResolver.Case.VAULT),
		Tuning.step_ticks(&"TUN-TRAVERSE-VAULT-DURATION")
	)
	assert_almost_eq(Tuning.movement.vault_duration, 0.55, 0.001)


func test_a_mantle_lasts_its_tunable() -> void:
	assert_eq(
		TraversalResolver.duration_ticks(TraversalResolver.Case.MANTLE),
		Tuning.step_ticks(&"TUN-TRAVERSE-MANTLE-DURATION")
	)
	assert_almost_eq(Tuning.movement.mantle_duration, 0.95, 0.001)


func test_a_mantle_takes_longer_than_a_vault() -> void:
	# A mantle is a visible commitment from 30 m — an information event, which a
	# 0.55 s hop is not. If these ever equalised the distinction would be gone.
	assert_gt(
		TraversalResolver.duration_ticks(TraversalResolver.Case.MANTLE),
		TraversalResolver.duration_ticks(TraversalResolver.Case.VAULT)
	)


func test_neither_reaches_the_commitment_ceiling() -> void:
	# `TUN-FEEL-MAX-COMMIT` 1.4 s: no unskippable animation may exceed it, and the
	# kill is the only thing allowed to sit at it. A vault must never feel like a
	# trap.
	assert_lt(Tuning.movement.vault_duration, Tuning.movement.max_commit)
	assert_lt(Tuning.movement.mantle_duration, Tuning.movement.max_commit)


func test_it_ends_exactly_when_the_tunable_says() -> void:
	_plan_vault()
	var ticks := TraversalResolver.duration_ticks(TraversalResolver.Case.VAULT)
	for _i: int in ticks - 1:
		_ctx.state_timer_ticks += 1
		assert_eq(_state.step(_ctx, InputCommand.empty(1), DT), PawnState.STAY, "ended early")
	_ctx.state_timer_ticks += 1
	assert_eq(_state.step(_ctx, InputCommand.empty(1), DT), PawnStateId.IDLE, "did not end on time")


# ------------------------------------------------------------ the cost --


func test_a_vault_costs_nothing() -> void:
	# **THE ONLY FREE ATHLETIC MOVE.** Deliberate, and load-bearing for design
	# law 4: a patient player needs routes, not just the option to stand still.
	#
	# **ASKED OF `SuspicionMath`.** It used to ask `VaultState.suspicion_rate()`, a
	# second ladder nothing in the shipped game called.
	_plan_vault()
	assert_eq(_rate_for(_ctx), 0.0, "a vault charged suspicion")


func test_a_mantle_costs_the_climb_rate() -> void:
	# Hauling yourself onto a two-metre wall is visibly athletic, and a civilian
	# does not do it. GDD-02 §6.1 prices it at "+11.4 (climb rate × duration)".
	_plan_mantle()
	assert_eq(_rate_for(_ctx), Tuning.suspicion.gain_climb, "a mantle stopped costing the climb")
	assert_gt(Tuning.suspicion.gain_climb, 0.0, "the climb rate stopped costing anything")


## What `SYS-SUSPICION` would charge this pawn, read the way it reads it —
## including the one thing `PawnStateId.VAULT` alone cannot say.
func _rate_for(ctx: PawnContext) -> float:
	var s := SuspicionState.new()
	s.speed_state = ctx.state_id
	s.mantling = ctx.traverse_case == TraversalResolver.Case.MANTLE
	s.nearest_npc_distance = 0.5
	return SuspicionMath.gain_rate(s, Tuning.suspicion)


# ------------------------------------------------------- interruptibility --


func test_combat_may_interrupt_but_nothing_below_it() -> void:
	# GDD-02 §3.1: "Yes (to COMBAT+)". You can be killed or stunned mid-vault; you
	# cannot change your mind about the wall. The machine's rule is
	# `not is_interruptible and priority <= interrupt_priority` — so a NORMAL
	# request is refused and a COMBAT one is admitted.
	assert_false(_state.is_interruptible(_ctx), "a vault can be abandoned mid-air")
	assert_eq(_state.interrupt_priority(), PawnState.PRIORITY_NORMAL)

	var machine := PawnStateMachine.new()
	machine.register(VaultState.new())
	machine.register(IdleState.new())
	machine.register(StunnedState.new())
	_plan_vault()

	assert_false(
		machine.transition(_ctx, PawnStateId.IDLE, PawnState.PRIORITY_NORMAL),
		"a NORMAL transition interrupted a vault"
	)
	assert_true(
		machine.transition(_ctx, PawnStateId.STUNNED, PawnState.PRIORITY_COMBAT),
		"a stun could not interrupt a vault"
	)
	machine.free()


# ------------------------------------------------------- the trajectory --


func test_it_starts_where_the_pawn_stood_and_ends_on_the_plan() -> void:
	_plan_vault()
	assert_almost_eq(VaultState.position_at(_ctx, 0.0).distance_to(_ctx.traverse_start), 0.0, 0.001)
	assert_almost_eq(
		VaultState.position_at(_ctx, 1.0).distance_to(_ctx.traverse_target), 0.0, 0.001
	)


func test_a_vault_goes_over_the_wall_and_not_through_it() -> void:
	# THE ASSERTION THIS FILE EXISTS FOR. A straight lerp from start to target
	# passes through a waist-high wall, and the simulation is what decides whether
	# the pawn ends up on the far side.
	_plan_vault(0.9, 1.4)
	var peak := 0.0
	for i: int in 21:
		peak = maxf(peak, VaultState.position_at(_ctx, i / 20.0).y)
	assert_gt(peak, 0.9, "the vault passed through the top of the wall")


func test_the_arc_clears_the_top_by_the_foot_probe_height() -> void:
	_plan_vault(0.9, 1.4)
	var peak := 0.0
	for i: int in 101:
		peak = maxf(peak, VaultState.position_at(_ctx, i / 100.0).y)
	assert_almost_eq(peak, _ctx.traverse_peak_y, 0.01)


func test_a_mantle_rises_onto_the_top_without_overshooting() -> void:
	# The target IS the top, so a mantle needs no arc. Overshooting would put the
	# pawn briefly above a surface it is meant to be climbing onto.
	_plan_mantle(1.8, 0.9)
	var peak := 0.0
	for i: int in 101:
		peak = maxf(peak, VaultState.position_at(_ctx, i / 100.0).y)
	assert_almost_eq(peak, 1.8, 0.01, "the mantle overshot the surface")


func test_the_trajectory_advances_monotonically_forward() -> void:
	# A manoeuvre that moved backwards at any point would read as a stumble.
	_plan_vault()
	var last := -1.0
	for i: int in 41:
		var z := VaultState.position_at(_ctx, i / 40.0).z
		assert_true(z >= last - 0.0001, "the vault moved backwards at t=%.2f" % (i / 40.0))
		last = z


func test_it_lands_the_pawn_on_the_target() -> void:
	_plan_vault(0.9, 1.4)
	assert_eq(_run_to_completion(), PawnStateId.IDLE)
	assert_almost_eq(_ctx.position.distance_to(_ctx.traverse_target), 0.0, 0.001)
	assert_eq(_ctx.velocity, Vector3.ZERO, "the pawn left the vault still carrying speed")


func test_entering_drops_the_approach_speed() -> void:
	# The manoeuvre is a fixed displacement, not an integration. Carrying the
	# approach velocity into it would land the pawn somewhere the plan did not
	# choose — and differently on a client that approached a frame later.
	_ctx.velocity = Vector3(0.0, 0.0, 6.2)
	_state.enter(_ctx)
	assert_eq(_ctx.velocity, Vector3.ZERO)
	assert_eq(_ctx.state_timer_ticks, 0, "enter() did not reset the state timer")


func test_a_plan_with_no_duration_does_not_trap_the_pawn() -> void:
	# Defensive: a zero-tick duration would otherwise divide by zero or loop
	# forever, and being stuck in a vault is unrecoverable without a respawn.
	_plan_vault()
	_ctx.traverse_case = TraversalResolver.Case.NONE
	_ctx.state_timer_ticks = 1
	assert_ne(_state.step(_ctx, InputCommand.empty(1), DT), PawnState.STAY)
