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
	_ctx.auto_kill_arrivals.append([A, _origin_of(A)])


## **THE DASH ORIGIN THE ARRIVAL IS JUDGED OVER.** `LungeEffect` records it at the
## burst; a fixture that appends by hand has to supply it, and supplying the pawn's
## *current* position models a dash of zero length — which is the corridor
## degenerating to a point, i.e. exactly the old endpoint rule.
func _origin_of(peer: int) -> Vector3:
	return (_ctx.pawn_contexts[peer] as PawnContext).position


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
	_ctx.auto_kill_arrivals.append([A, _origin_of(A)])
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
	_ctx.auto_kill_arrivals.append([A, _origin_of(A)])
	var command := InputCommand.new()
	command.buttons = InputBits.KILL
	command.received_ordinal = 0
	_system.report_input(C, command, MatchContext.net_dt())
	_advance()
	assert_eq(_state(A), PawnStateId.KILL_ANIM, "the presser took the claim off the lunger")
	assert_ne(_state(C), PawnStateId.KILL_ANIM, "both killers committed to the same victim")
	assert_lt(KillSystem.ARRIVAL_ORDINAL, 0, "the arrival ordinal stopped being below every press")


# --- the present ----------------------------------------------------------


## A hunter standing at the origin whose lag-comp history holds them `behind`
## metres back down the dash line — which is what a dash actually looks like in
## the ring, and what **every fixture above hides** by recording the pawn where it
## already stands.
func _dashed_in(behind: float, gap: float) -> void:
	_place(A, Vector3(0.0, 0.0, -behind))
	_place(B, Vector3(0.0, 0.0, gap))
	_ctx.announced_contracts[A] = B
	_fill_the_ring(8)
	(_ctx.pawn_contexts[A] as PawnContext).position = Vector3.ZERO
	_ctx.auto_kill_arrivals.append([A, _origin_of(A)])


## **AN ARRIVAL IS JUDGED AGAINST WHAT IS THERE, NOT AGAINST WHAT ANYBODY SAW.**
## US-0070, fixed 2026-09-02 after *"the autokill on lunge does not work"*.
##
## Lag compensation honours the moment an attacker **decided**, and an arrival has
## no such moment — the server decides it at the end of a dash the client is only
## predicting. `RewindClamp` has a floor of `TUN-NET-LAGCOMP-MIN` 100 ms even at
## zero ping, and at `TUN-LUNGE-SPEED` 9 m/s that is 0.9 m of the **hunter's own
## travel** taken off a 2.85 m reach. Measured on a real server before the fix: the
## auto-kill band ended at a 7.5 m approach against the 8.7 m the design gives it,
## and it shrank further the worse the hunter's connection.
##
## 2.5 m in the present and 3.4 m in the past, against a reach of 2.85 — so the two
## rules disagree and this test can tell which one ran.
func test_an_arrival_is_judged_in_the_present_and_not_at_the_rewound_tick() -> void:
	_dashed_in(0.9, 2.5)
	_advance()
	assert_eq(
		_system.arrivals_landed,
		1,
		(
			"the arrival was judged against the rewound world, so the hunter's own dash "
			+ "was subtracted from their reach"
		)
	)


## The counterfactual: the same geometry moved out of reach in **both** frames must
## still whiff, or the assertion above is satisfied by a system that never refuses.
func test_the_present_judgement_still_refuses_a_dash_that_ended_short() -> void:
	_dashed_in(0.9, 4.0)
	_advance()
	assert_eq(_system.arrivals_landed, 0, "a dash that ended out of reach killed anyway")
	assert_eq(_system.last_whiff, KillVerdict.V.OUT_OF_RANGE, "the whiff recorded the wrong reason")


## Places `B` `metres` along the dash line, with the hunter having travelled the
## full `TUN-LUNGE-DISTANCE` from behind them — a corridor, not a point.
func _dashed_through(metres: float) -> void:
	var run := LungingState.dash_distance()
	_place(A, Vector3(0.0, 0.0, run))
	_place(B, Vector3(0.0, 0.0, metres))
	_ctx.announced_contracts[A] = B
	_fill_the_ring(8)
	_ctx.auto_kill_arrivals.append([A, Vector3.ZERO])


## **A CONTRACT THE DASH WENT *THROUGH* IS KILLED.** Changed 2026-09-03, and this
## test asserted the opposite until then — that a contract left 1.85 m behind the
## hunter whiffed `OUT_OF_CONE`, which was true of the endpoint rule and was the
## defect: at a 4.0 m approach the contract ended **inside** the 2.85 m reach and
## was refused for being behind. `KillRules.resolve_swept` judges the corridor the
## dash travelled, which is what the reference does — it resolves against whoever
## the dash connects with — and it is why decision 8's overshoot hole is closed.
func test_a_contract_the_dash_passed_through_is_killed() -> void:
	_dashed_through(LungingState.dash_distance() - 1.85)
	_advance()
	assert_eq(_system.arrivals_landed, 1, "the dash went through the contract and did not kill")


## **AND THE CORRIDOR IS NOT A LICENCE.** A contract off to one side by more than
## the reach is still a miss, or the rule would be *dash anywhere near them*.
func test_a_contract_beside_the_corridor_still_whiffs() -> void:
	var run := LungingState.dash_distance()
	_place(A, Vector3(0.0, 0.0, run))
	_place(B, Vector3(KillRules.reach(Tuning.combat) + 1.0, 0.0, run * 0.5))
	_ctx.announced_contracts[A] = B
	_fill_the_ring(8)
	_ctx.auto_kill_arrivals.append([A, Vector3.ZERO])
	_advance()
	assert_eq(_system.arrivals_whiffed, 1, "a contract beside the whole dash was killed")
	assert_eq(_system.last_whiff, KillVerdict.V.OUT_OF_RANGE, "the whiff recorded the wrong reason")
