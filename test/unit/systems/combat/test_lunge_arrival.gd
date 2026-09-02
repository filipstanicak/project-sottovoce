## **WHAT A DASH IS WORTH WHEN IT LANDS.** US-0070, GDD-04 §3.4, TDD-10 §3.
##
## `LungeEffect` queues an arrival on `MatchContext.auto_kill_arrivals` and
## `SYS-KILL` judges it with the rules it already owns. **The effect decides
## nothing about whether the kill lands** — range, cone, the announced contract,
## the cloud and the contest are `KillRules`' and `KillSystem`'s, and an effect
## that pre-checked any of them would be that rule written a second time.
##
## **THE ONE DIFFERENCE AN ARRIVAL MAKES IS WHAT A REFUSAL COSTS**, and that is
## the assertion this file exists for: a miss is `TUN-LUNGE-WHIFF-STAGGER` and
## **not** `TUN-SUSPICION-GAIN-FAILED-KILL`, because the presser already paid a
## 30 s cooldown, +40 suspicion and a 6 m telegraph.
extends GutTest

const A := 71
const B := 72
const C := 73

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


## A hunter who has just finished a dash `metres` short of their contract.
func _arrived_at(metres: float) -> void:
	_place(A, Vector3.ZERO)
	_place(B, Vector3(0.0, 0.0, metres))
	_ctx.announced_contracts[A] = B
	_fill_the_ring(8)
	_ctx.auto_kill_arrivals.append(A)


func _advance(ticks: int = 1) -> void:
	for _i: int in ticks:
		_ctx.tick += 1
		_system.tick(_ctx, MatchContext.net_dt())


func _state(peer: int) -> StringName:
	return (_ctx.pawn_contexts[peer] as PawnContext).state_id


# --- the premise ----------------------------------------------------------


func test_a_dash_that_arrives_in_reach_kills() -> void:
	# **THE PREMISE.** Every "it whiffed" assertion below is satisfied by a system
	# that never kills anybody at all, and this is what stops the file passing that
	# way.
	_arrived_at(1.5)
	_advance()
	assert_eq(_system.arrivals_landed, 1, "an arrival inside kill range did not land")
	assert_eq(_state(A), PawnStateId.KILL_ANIM, "the auto-kill did not commit")


func test_the_queue_is_drained_rather_than_replayed() -> void:
	_arrived_at(1.5)
	_advance(3)
	assert_eq(_system.arrivals_judged, 1, "one arrival was judged more than once")
	assert_true(_ctx.auto_kill_arrivals.is_empty(), "the arrival queue was never cleared")


# --- the miss -------------------------------------------------------------


## **A MISS COSTS THE STAGGER AND NOTHING ELSE.** GDD-04 §3.4 prices it that way
## in as many words: *"Missing costs the lunger `TUN-LUNGE-WHIFF-STAGGER` 1.2 s
## standing in the open, Noticed."* `_reject`'s +30 is for somebody who pressed at
## nothing, and charging it here would price one mistake twice.
func test_a_dash_that_arrives_short_whiffs_and_is_not_charged_as_a_press() -> void:
	_arrived_at(6.0)
	_advance()
	assert_eq(_system.arrivals_whiffed, 1, "an arrival out of reach did not whiff")
	assert_eq(_system.arrivals_landed, 0, "an arrival out of reach killed anyway")
	assert_eq(_ctx.impulses.pending(A), 0.0, "the miss was charged failed-kill suspicion")


func test_the_whiff_is_a_state_and_a_lockout_together() -> void:
	_arrived_at(6.0)
	_advance()
	assert_eq(_state(A), PawnStateId.STAGGERED, "the whiff left the lunger free to move")
	assert_true(_ctx.lockouts.is_staggered(A, _ctx.tick), "the whiff left them free to initiate")
	assert_eq(
		(_ctx.pawn_contexts[A] as PawnContext).stagger_ticks,
		Tuning.step_ticks(&"TUN-LUNGE-WHIFF-STAGGER"),
		"the whiff stagger ran on somebody else's clock"
	)


## US-0070's third criterion. The verdict comes from `KillRules` and the
## **announced** contract, so a dash that ends on top of a stranger is a miss.
func test_a_dash_that_arrives_at_a_stranger_whiffs() -> void:
	_place(A, Vector3.ZERO)
	_place(C, Vector3(0.0, 0.0, 1.5))
	_place(B, Vector3(0.0, 0.0, 40.0))
	_ctx.announced_contracts[A] = B
	_fill_the_ring(8)
	_ctx.auto_kill_arrivals.append(A)
	_advance()
	assert_eq(_system.arrivals_whiffed, 1, "a dash into a stranger was allowed to kill")
	assert_eq(_state(C), PawnStateId.IDLE, "the stranger was affected")


# --- the contest ----------------------------------------------------------


## **A LUNGE COMMITTED 0.92 s AGO AND EVERY PRESS IN THIS TICK WAS MADE AFTER
## THAT.** `KillContest` resolves by who committed first; `ARRIVAL_ORDINAL` is
## below any `received_ordinal`, so the arrival sorts ahead of the press and keeps
## the claim rather than merely getting there first by luck of iteration order.
func test_an_arrival_beats_a_press_made_in_the_same_tick() -> void:
	_place(A, Vector3.ZERO)
	_place(B, Vector3(0.0, 0.0, 1.5))
	_place(C, Vector3(0.0, 0.0, 3.0))
	(_ctx.pawn_contexts[C] as PawnContext).yaw = PI
	_ctx.announced_contracts[A] = B
	_ctx.announced_contracts[C] = B
	_fill_the_ring(8)
	_ctx.auto_kill_arrivals.append(A)
	var command := InputCommand.new()
	command.buttons = InputBits.KILL
	command.received_ordinal = 0
	_system.report_input(C, command, MatchContext.net_dt())
	_advance()
	assert_eq(_state(A), PawnStateId.KILL_ANIM, "the presser took the claim off the lunger")
	assert_ne(_state(C), PawnStateId.KILL_ANIM, "both killers committed to the same victim")
	assert_lt(KillSystem.ARRIVAL_ORDINAL, 0, "the arrival ordinal stopped being below every press")
