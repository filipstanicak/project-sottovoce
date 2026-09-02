## **A VICTIM KILLED WHILE FALLING WAS TOLD THEY DIED AND KEPT PLAYING.**
## US-0060 reported it, ADR-0017 priced it and recommended closing it, and this
## is where it is closed.
##
## GDD-02 §3's diagram declared no `Drop -> Dead` and no `StunAnim -> Dead`, and
## `KillSystem._land` emitted `killed` and counted the kill **whether or not the
## transition was legal**. So the cycle was repaired around the victim, a corpse
## was spawned, the crowd was startled, `NET-S2C-KILL-RESULT` went out — and
## `CombatTargets.is_dead` still answered **false**, because it reads `state_id`.
##
## **THAT IS NOT COSMETIC AND THE CORPUS CALLED IT COSMETIC FOR THREE
## MILESTONES**: *"the death still resolves and the pawn keeps walking."* An
## undead victim is a live target their killer's successor is still hunting, in a
## cycle that has already been repaired as though they were gone.
extends GutTest

const A := 91
const B := 92

var _system: KillSystem
var _ctx: MatchContext
var _machines: Array[PawnStateMachine] = []


func before_each() -> void:
	_machines.clear()
	_ctx = MatchContext.new()
	_ctx.tick = 200
	_system = KillSystem.new()
	add_child_autofree(_system)
	_system.setup(_ctx)
	_place(A, Vector3.ZERO)
	_place(B, Vector3(0.0, 0.0, 2.0))
	_ctx.announced_contracts[A] = B
	_fill_the_ring(8)


func after_each() -> void:
	for machine: PawnStateMachine in _machines:
		machine.free()
	_machines.clear()


func _place(peer: int, at: Vector3) -> PawnContext:
	var machine := PawnStateMachine.new()
	for script: GDScript in PawnStateMachine.REGISTERED:
		machine.register(script.new())
	_machines.append(machine)
	var pawn := PawnContext.new()
	pawn.peer_id = peer
	pawn.reset_for_spawn(at, 0.0)
	machine.spawn_into(pawn, PawnStateId.IDLE)
	_ctx.pawn_contexts[peer] = pawn
	_ctx.pawn_machines[peer] = machine
	return pawn


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


func _press(peer: int) -> void:
	var command := InputCommand.empty(1)
	command.buttons = InputBits.KILL
	_system.report_input(peer, command, MatchContext.step_dt())
	_system.report_input(peer, command, MatchContext.step_dt())


func _advance(ticks: int) -> void:
	for _i: int in ticks:
		_ctx.tick += 1
		_system.tick(_ctx, MatchContext.net_dt())


## Put the victim in `state`, kill them, and settle past the contact frame.
func _killed_while_in(state: StringName) -> PawnContext:
	var victim := _ctx.pawn_contexts[B] as PawnContext
	var machine := _ctx.pawn_machines[B] as PawnStateMachine
	machine.transition(victim, state, PawnState.PRIORITY_COMBAT)
	assert_eq(victim.state_id, state, "the fixture could not put the victim into %s" % state)
	_press(A)
	_advance(Tuning.ticks(&"TUN-KILL-CORPSE-SPAWN-DELAY") + 2)
	return victim


func test_the_premise_a_victim_standing_still_dies() -> void:
	# Guards the guard. Both assertions below are satisfied by a system that kills
	# everybody in every state, and this is what stops the file passing that way.
	_press(A)
	_advance(Tuning.ticks(&"TUN-KILL-CORPSE-SPAWN-DELAY") + 2)
	assert_true(
		CombatTargets.is_dead(_ctx.pawn_contexts[B] as PawnContext),
		"the fixture cannot kill anybody, so nothing below means anything"
	)


func test_a_victim_killed_while_falling_actually_dies() -> void:
	assert_true(
		CombatTargets.is_dead(_killed_while_in(PawnStateId.DROP)),
		"a victim killed mid-fall was announced dead and is still a live target"
	)


func test_a_victim_killed_mid_stun_swing_actually_dies() -> void:
	assert_true(
		CombatTargets.is_dead(_killed_while_in(PawnStateId.STUN_ANIM)),
		"a victim killed mid-swing was announced dead and is still a live target"
	)


## **AND A DEAD PLAYER MUST STILL REACH `Respawning`.** `SpawnSystem._enter_respawning`
## requires `state_id == DEAD`, so the missing edges cost the victim their five
## seconds of `TUN-RESPAWN-INVULN` as well — the second-order consequence the
## original report named and nobody had asserted.
func test_a_victim_killed_while_falling_can_still_respawn() -> void:
	var victim := _killed_while_in(PawnStateId.DROP)
	var machine := _ctx.pawn_machines[B] as PawnStateMachine
	assert_true(
		machine.is_valid_edge(victim.state_id, PawnStateId.RESPAWNING),
		"a victim killed mid-fall cannot reach Respawning either"
	)


## **THE FAIL-SAFE, WHICH IS THE HALF THAT SURVIVES THE NEXT NEW STATE.** Both
## edges exist now, so `_land`'s guard cannot fire — but the machine gained two
## states in two days, and each one is a fresh chance to forget a `-> Dead` edge.
## A kill that cannot be applied is refused loudly rather than announced.
func test_a_kill_that_cannot_be_applied_is_not_announced() -> void:
	var told: Array = []
	_system.killed.connect(func(_k: int, _v: int, _a: Vector3) -> void: told.append(1))
	var victim := _ctx.pawn_contexts[B] as PawnContext
	# `Respawning` has exactly one edge out and it is not `Dead`. Standing in for
	# whichever state somebody adds next without one.
	victim.state_id = PawnStateId.RESPAWNING
	_press(A)
	_advance(Tuning.ticks(&"TUN-KILL-CORPSE-SPAWN-DELAY") + 2)
	assert_eq(told.size(), 0, "a kill nothing could apply was still announced")
	assert_eq(_system.kills_landed, 0, "a kill nothing could apply was still counted")
