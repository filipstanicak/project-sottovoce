## **`SYS-STUN` END TO END: PRESS, GATE, FREEZE, EXILE.** US-0061, TDD-10 §4,
## GDD-03 §10.
##
## The pure rules are exercised in `test/unit/core/combat/`. What is here is the
## sequencing: that only a pursuer is a target, that an Anonymous one is
## unstunnable at any range, that the freeze and the exile both land, and that a
## committed kill is not saved by a stun that arrives after it.
extends GutTest

const PREY := 81
const HUNTER := 82
const STRANGER := 83

var _kills: KillSystem
var _stun: StunSystem
var _ctx: MatchContext
var _machines: Array[PawnStateMachine] = []
var _landed: Array = []
var _refused: Array = []


func before_each() -> void:
	_machines.clear()
	_landed = []
	_refused = []
	_ctx = MatchContext.new()
	_ctx.tick = 200
	_kills = KillSystem.new()
	add_child_autofree(_kills)
	_kills.setup(_ctx)
	_stun = _kills.stun
	_stun.stunned.connect(func(a: int, b: int, t: int) -> void: _landed.append([a, b, t]))
	_stun.stun_rejected.connect(func(a: int, v: int, b: int) -> void: _refused.append([a, v, b]))


func after_each() -> void:
	for machine: PawnStateMachine in _machines:
		machine.free()
	_machines.clear()


func _place(peer: int, at: Vector3, yaw: float = 0.0) -> PawnContext:
	var machine := PawnStateMachine.new()
	for script: GDScript in PawnStateMachine.REGISTERED:
		machine.register(script.new())
	_machines.append(machine)
	var pawn := PawnContext.new()
	pawn.peer_id = peer
	pawn.reset_for_spawn(at, yaw)
	machine.spawn_into(pawn, PawnStateId.IDLE)
	_ctx.pawn_contexts[peer] = pawn
	_ctx.pawn_machines[peer] = machine
	return pawn


## The prey at the origin facing +Z, their hunter 2.0 m ahead and Exposed. A
## revealed pursuer inside stun range and inside kill range — the moment the whole
## mechanic is about.
func _a_hunt() -> void:
	_place(PREY, Vector3.ZERO)
	_place(HUNTER, Vector3(0.0, 0.0, 2.0), PI)
	_ctx.announced_contracts[HUNTER] = PREY
	_tier(HUNTER, SuspicionMath.Tier.EXPOSED)
	_settle()


func _tier(peer: int, tier: int) -> void:
	(_ctx.pawn_contexts[peer] as PawnContext).tier = tier


func _fill_the_ring(ticks: int) -> void:
	for back: int in range(ticks, 0, -1):
		var ids := PackedInt32Array()
		var places := PackedVector3Array()
		var yaws := PackedFloat32Array()
		for peer: int in _ctx.pawn_contexts.keys():
			var pawn := _ctx.pawn_contexts[peer] as PawnContext
			ids.append(peer)
			places.append(pawn.position)
			yaws.append(pawn.yaw)
		_ctx.lag_comp.record(_ctx.tick - back, ids, places, yaws)


## **THE RING MUST BE CLEARED BEFORE IT IS REFILLED, AND THIS COST AN HOUR.**
## `LagCompHistory` is a ring and `_frame_at` returns the **first** frame it finds
## for a tick — so recording the same tick twice leaves the *stale* one winning.
## A fixture that placed a pawn, filled the ring, moved the pawn and filled again
## rewinds to where the pawn **used to be**, and every geometry assertion in the
## file is then about the wrong position. It reads as a rule that does not work.
func _settle() -> void:
	_ctx.lag_comp.clear()
	_fill_the_ring(8)


func _press(peer: int, bit: int = InputBits.STUN) -> void:
	var command := InputCommand.empty(1)
	command.buttons = bit
	# Two commands, because the server receives two per tick and only the first is
	# an edge. A system reading `held` would act twice.
	_kills.report_stun_input(peer, command, MatchContext.step_dt())
	_kills.report_stun_input(peer, command, MatchContext.step_dt())
	if bit == InputBits.KILL:
		_kills.report_input(peer, command, MatchContext.step_dt())
		_kills.report_input(peer, command, MatchContext.step_dt())


func _advance(ticks: int = 1) -> void:
	for _i: int in ticks:
		_fill_the_ring(1)
		_ctx.tick += 1
		_kills.tick(_ctx, MatchContext.net_dt())


func _state(peer: int) -> StringName:
	return (_ctx.pawn_contexts[peer] as PawnContext).state_id


# ------------------------------------------------------- the stun itself --


func test_a_revealed_pursuer_in_reach_is_stunned() -> void:
	# **THE PREMISE.** Every refusal below is true of a system that never allows a
	# stun at all, so this assertion is what makes the rest of the file mean
	# something.
	_a_hunt()
	_press(PREY)
	_advance()
	assert_eq(_landed.size(), 1, "a revealed pursuer at 2 m was not stunned")
	assert_eq(_state(HUNTER), PawnStateId.STUNNED, "the pursuer was not frozen")
	assert_eq(_state(PREY), PawnStateId.STUN_ANIM, "the stunner did not commit to the swing")


func test_an_anonymous_pursuer_is_unstunnable_at_every_range() -> void:
	# **THE GATE, AND THE REASON PATIENCE IS GENUINELY SAFE.** GDD-03 §10.2: the
	# reward for perfect play is perfect safety. Swept, because one sample cannot
	# tell a tier gate from a range gate that is tighter than the sample.
	for metres: float in [0.5, 1.0, 1.5, 2.0, 2.9]:
		_a_hunt()
		(_ctx.pawn_contexts[HUNTER] as PawnContext).position = Vector3(0.0, 0.0, metres)
		_tier(HUNTER, SuspicionMath.Tier.ANONYMOUS)
		_settle()
		_press(PREY)
		_advance()
		assert_eq(_landed.size(), 0, "an Anonymous pursuer was stunned at %.1f m" % metres)
		before_each()


func test_the_tier_gate_reads_the_tunable() -> void:
	# Written as `!= ANONYMOUS` the gate agrees with `TUN-STUN-MIN-TIER` today and
	# stops agreeing the moment it moves. Invariant §17.8 also pins it to the warn
	# floor, so this assertion is the tripwire for both.
	assert_almost_eq(
		Tuning.combat.stun_min_tier,
		Tuning.compass.warn_min_tier,
		0.001,
		'"I was warned about them" and "I can stun them" have stopped being one condition'
	)
	assert_almost_eq(Tuning.combat.stun_min_tier, Tuning.suspicion.tier_noticed, 0.001)


func test_the_freeze_lasts_its_tuned_duration_and_not_a_tick_less() -> void:
	_a_hunt()
	_press(PREY)
	_advance()
	# **`step()` ADVANCES THE TIMER ITSELF**, so the count here is calls rather than
	# ticks added by hand — doing both would halve the measured freeze and look
	# like a tuning error.
	var steps := Tuning.step_ticks(&"TUN-STUN-FREEZE")
	var pawn := _ctx.pawn_contexts[HUNTER] as PawnContext
	var machine := _ctx.pawn_machines[HUNTER] as PawnStateMachine
	for _i: int in steps - 1:
		machine.step(pawn, InputCommand.empty(1), MatchContext.step_dt())
	assert_eq(pawn.state_id, PawnStateId.STUNNED, "the freeze ended early")
	machine.step(pawn, InputCommand.empty(1), MatchContext.step_dt())
	assert_eq(pawn.state_id, PawnStateId.IDLE, "the freeze never ended")


func test_the_exile_is_armed_for_the_tuned_length() -> void:
	_a_hunt()
	_press(PREY)
	_advance()
	var expected := StunSystem.lockout_ticks(false)
	assert_eq(int(_landed[0][2]), expected, "the reported lockout is not the tuned one")
	assert_eq(
		_ctx.lockouts.remaining(HUNTER, PREY, _ctx.tick),
		expected,
		"the exile on the table disagrees with the number both players were told"
	)


func test_the_exiled_hunter_cannot_kill_that_prey_and_can_kill_anybody_else() -> void:
	# **THIS IS WHAT MAKES A STUN COUNTERPLAY RATHER THAN A DELAY** (GDD-03 §10.2).
	# Without it the hunter is frozen for four seconds and walks back.
	_a_hunt()
	_place(STRANGER, Vector3(0.0, 0.0, 3.5))
	_settle()
	_press(PREY)
	_advance()
	# Out of the freeze, standing next to the prey again.
	(_ctx.pawn_contexts[HUNTER] as PawnContext).state_id = PawnStateId.IDLE
	assert_false(_kills.ready_for(HUNTER, _ctx), "the exiled hunter may still kill their prey")
	_ctx.announced_contracts[HUNTER] = STRANGER
	(_ctx.pawn_contexts[STRANGER] as PawnContext).position = Vector3(0.0, 0.0, 1.0)
	assert_true(_kills.ready_for(HUNTER, _ctx), "the exile spread to a brand-new contract")


func test_a_committed_kill_is_not_saved_by_a_stun() -> void:
	# **ADR-0013, read from the prey's side.** The hunter presses kill; the prey
	# presses stun on the same tick and again the tick after. Neither saves them.
	_a_hunt()
	var deaths: Array = []
	_kills.killed.connect(func(k: int, v: int, _at: Vector3) -> void: deaths.append([k, v]))
	_press(HUNTER, InputBits.KILL)
	_press(PREY)
	_advance()
	assert_eq(_state(HUNTER), PawnStateId.KILL_ANIM, "the kill did not commit")
	assert_eq(_landed.size(), 0, "the same-tick stun landed; the contest resolved for the prey")
	_advance(Tuning.ticks(&"TUN-KILL-CORPSE-SPAWN-DELAY") + 2)
	assert_eq(deaths.size(), 1, "the committed kill was cancelled")


func test_a_stun_at_a_committed_hunter_costs_the_prey_nothing() -> void:
	# The press was correct and merely late. Charging for it is the shape of
	# weakening stun that never-do #13 forbids.
	_a_hunt()
	_press(HUNTER, InputBits.KILL)
	_advance()
	_press(PREY)
	_advance()
	assert_false(
		_ctx.lockouts.is_staggered(PREY, _ctx.tick),
		"the prey was staggered for stunning a hunter who had already committed"
	)
	assert_eq(_ctx.impulses.pending(PREY), 0.0, "the prey was charged suspicion for a late stun")


func test_nobody_can_stun_a_player_who_is_not_hunting_them() -> void:
	# The stranger is closer than the hunter and is Exposed. Proximity is not the
	# gate; the relationship is.
	_a_hunt()
	_place(STRANGER, Vector3(0.0, 0.0, 1.0))
	_tier(STRANGER, SuspicionMath.Tier.EXPOSED)
	(_ctx.pawn_contexts[HUNTER] as PawnContext).position = Vector3(0.0, 0.0, 8.0)
	_settle()
	_press(PREY)
	_advance()
	assert_eq(_landed.size(), 0, "a stranger standing in front of the prey was stunned")
	assert_eq(_state(STRANGER), PawnStateId.IDLE, "the wrong target was affected")


func test_a_pursuer_behind_the_prey_is_out_of_cone() -> void:
	_a_hunt()
	(_ctx.pawn_contexts[HUNTER] as PawnContext).position = Vector3(0.0, 0.0, -2.0)
	_settle()
	_press(PREY)
	_advance()
	assert_eq(_landed.size(), 0, "a pursuer directly behind the prey was stunned")


func test_the_stun_reaches_the_state_the_suspicion_hold_watches_for() -> void:
	# **`TUN-STUN-FORCES-EXPOSED` IS `SuspicionSystem`'s HOLD, NOT THIS SYSTEM'S.**
	# It was moved there in US-0053 — written from `StunnedState.enter()` it was
	# predicted code deciding gameplay state, and a single *set* rather than a
	# hold, so the decay it re-armed began eating the punishment on the next tick.
	#
	# **Until now nothing could reach `Stunned` at all**, so that hold was live code
	# with no way to execute. This is the join, asserted rather than assumed: the
	# day a stun put its target into some other state, the forced Exposed would
	# stop applying with nothing failing.
	_a_hunt()
	_press(PREY)
	_advance()
	assert_eq(_state(HUNTER), PawnStateId.STUNNED, "the target is not in the watched state")
	assert_true(Tuning.combat.forces_exposed, "TUN-STUN-FORCES-EXPOSED is off")
	assert_true(
		SourceScanner.code_contains(
			"res://scripts/systems/suspicion/suspicion_system.gd", "PawnStateId.STUNNED"
		),
		"SuspicionSystem no longer watches for the stunned state"
	)


func test_the_target_loses_the_camera_and_the_stunner_does_not() -> void:
	# GDD-02 §4: `Stunned` is **the only** state that takes the camera, and
	# `test_camera_control.gd` refuses a second one. Four seconds of watching
	# whatever is in front of you while your target walks away is the punishment;
	# the stunner keeps their own view, because 0.7 s of commitment is not one.
	_a_hunt()
	_press(PREY)
	_advance()
	var them := _ctx.pawn_machines[HUNTER] as PawnStateMachine
	var us := _ctx.pawn_machines[PREY] as PawnStateMachine
	assert_false(
		them.camera_controlled(_ctx.pawn_contexts[HUNTER] as PawnContext),
		"a stunned player kept the camera"
	)
	assert_true(
		us.camera_controlled(_ctx.pawn_contexts[PREY] as PawnContext),
		"the stunner lost the camera for swinging"
	)


func test_the_ready_bit_follows_the_same_rules_as_the_press() -> void:
	# `stun_ready` has existed in `Snapshot` since US-0029 with no writer. A hint
	# that disagreed with the rule would be worse than none.
	_a_hunt()
	_advance()
	assert_true(
		(_ctx.pawn_contexts[PREY] as PawnContext).stun_ready, "the prey's stun hint is dark"
	)
	_tier(HUNTER, SuspicionMath.Tier.ANONYMOUS)
	_advance()
	assert_false(
		(_ctx.pawn_contexts[PREY] as PawnContext).stun_ready,
		"the hint stays lit for an unstunnable pursuer"
	)
