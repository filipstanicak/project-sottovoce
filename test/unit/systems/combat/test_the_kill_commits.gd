## **A KILL IN PROGRESS CANNOT BE STOPPED BY THE VICTIM.** ADR-0013, GDD-02 §3.2
## rule 1, US-0060.
##
## The rule this file exists for was **reversed** on 2026-08-26. `KillAnim` used to
## be interruptible until `TUN-KILL-CORPSE-SPAWN-DELAY`, which made a last-second
## stun a genuine save. The reference resolves a contested initiation for the
## **killer**, so it no longer is: the prey's counterplay lives entirely in the
## approach, where a revealed hunter is stunnable from further away than they can
## strike, for every second they are closing.
##
## **WHAT STILL STOPS A COMMITTED KILL IS A THIRD PARTY.** `PawnStateMachine`
## compares the requesting priority against the current state's own, and
## `PRIORITY_FATAL` exceeds `KillAnim`'s `PRIORITY_COMBAT` — so somebody killing the
## killer gets through where a stun does not. That asymmetry *is* the rule, and
## both halves are asserted here, because a state that refused everything would
## satisfy the first test and break the §3 diagram.
extends GutTest

const A := 71
const B := 72

var _system: KillSystem
var _ctx: MatchContext
var _machines: Array[PawnStateMachine] = []
var _ordinal: int = 0


func before_each() -> void:
	_ordinal = 0
	_machines.clear()
	_ctx = MatchContext.new()
	_ctx.tick = 200
	_system = KillSystem.new()
	add_child_autofree(_system)
	_system.setup(_ctx)


func after_each() -> void:
	for machine: PawnStateMachine in _machines:
		machine.free()
	_machines.clear()


func _place(peer: int, at: Vector3) -> void:
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


func _two_players() -> void:
	_place(A, Vector3.ZERO)
	_place(B, Vector3(0.0, 0.0, 2.0))
	_ctx.announced_contracts[A] = B
	_fill_the_ring(8)


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
	_ordinal += 1
	command.received_ordinal = _ordinal
	_system.report_input(peer, command, MatchContext.step_dt())


func _advance(ticks: int = 1) -> void:
	for _i: int in ticks:
		_fill_the_ring(1)
		_ctx.tick += 1
		_system.tick(_ctx, MatchContext.net_dt())


func _state(peer: int) -> StringName:
	return (_ctx.pawn_contexts[peer] as PawnContext).state_id


func test_a_stun_no_longer_saves_the_victim() -> void:
	# **THE RULE ADR-0013 REVERSED.** A stun landing after the hunter has committed
	# does nothing for the prey: the reference resolves a contested initiation for
	# the killer, and the prey's counterplay lives entirely in the approach.
	#
	# `SYS-STUN` does not exist (US-0061), so the stun is driven here as what it is
	# at the machine — a COMBAT-priority request to leave `KillAnim`.
	_two_players()
	_press(A)
	_advance()
	var killer := _ctx.pawn_contexts[A] as PawnContext
	var stunned: bool = (_ctx.pawn_machines[A] as PawnStateMachine).transition(
		killer, PawnStateId.STUNNED, PawnState.PRIORITY_COMBAT
	)
	assert_false(stunned, "a COMBAT-priority stun interrupted a committed kill")
	_advance(Tuning.ticks(&"TUN-KILL-CORPSE-SPAWN-DELAY") + 2)
	assert_eq(_state(B), PawnStateId.DEAD, "the kill was cancelled by a stun")
	assert_eq(_system.kills_landed, 1)


func test_a_third_party_kill_still_takes_the_killer_out_of_it() -> void:
	# The one thing that does stop a committed kill, and the §3 diagram draws it:
	# `KillAnim --> Dead: killed (contested loss to a third party)`. FATAL exceeds
	# `KillAnim`'s own COMBAT priority, so it gets through where a stun does not —
	# which is the whole of what "uninterruptible" means here.
	_two_players()
	_press(A)
	_advance()
	var killer := _ctx.pawn_contexts[A] as PawnContext
	var died: bool = (_ctx.pawn_machines[A] as PawnStateMachine).transition(
		killer, PawnStateId.DEAD, PawnState.PRIORITY_FATAL
	)
	assert_true(died, "a FATAL-priority kill could not reach a committed killer")
	_advance(Tuning.ticks(&"TUN-KILL-CORPSE-SPAWN-DELAY") + 2)
	assert_eq(_state(B), PawnStateId.IDLE, "a dead killer still landed the blow")
	assert_eq(_system.kills_landed, 0)


func test_the_commitment_is_total_at_every_tick_of_the_animation() -> void:
	# **THE COUNTERFACTUAL FOR THE OLD RULE.** The window that used to exist ran from
	# the press to `TUN-KILL-CORPSE-SPAWN-DELAY`, so a test that only probed the last
	# tick would pass against either rule. This sweeps the whole animation.
	var pawn := PawnContext.new()
	pawn.state_id = PawnStateId.KILL_ANIM
	var refused := 0
	var span := Tuning.step_ticks(&"TUN-KILL-ANIM-DURATION")
	assert_gt(span, 10, "the animation is too short for this sweep to mean anything")
	for tick: int in span:
		pawn.state_timer_ticks = tick
		if not KillAnimState.new().is_interruptible(pawn):
			refused += 1
	assert_eq(refused, span, "the kill was interruptible on %d ticks" % (span - refused))
