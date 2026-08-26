## **`SYS-KILL` END TO END: PRESS, COMMIT, CONTACT FRAME, DEATH.** US-0060,
## TDD-10 §3, GDD-02 §3.
##
## The pure rules are exercised in `test/unit/core/combat/`. What is here is the
## sequencing: that a press becomes a committed animation, that the victim dies at
## the contact frame and not before, that a rejection is charged for once rather
## than every tick, and that a contest loser is staggered instead of scoring.
extends GutTest

const A := 61
const B := 62
const C := 63

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


## A pawn with its own state machine, in `Idle`, at `at`, facing +Z.
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


## A hunter and their contract, two metres apart and facing the same way — the
## patient approach, resolved.
func _two_players() -> void:
	_place(A, Vector3.ZERO)
	_place(B, Vector3(0.0, 0.0, 2.0))
	_ctx.announced_contracts[A] = B
	_fill_the_ring(8)


## Enough recorded history that a rewind finds the world. `RewindClamp` reaches
## three ticks back at zero round trip, so anything less than that is a rewind
## into an empty ring — which reads as `BUSY` and would make every test below
## pass for the wrong reason.
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


## Two hunters facing each other across one victim: A at the origin looking +Z,
## C three metres beyond looking back, and B between them. Both hold a contract on
## B, both are in range and in cone, and neither is nearer than the other.
func _a_shared_victim() -> void:
	_place(A, Vector3.ZERO)
	_place(B, Vector3(0.0, 0.0, 1.5))
	_place(C, Vector3(0.0, 0.0, 3.0))
	(_ctx.pawn_contexts[C] as PawnContext).yaw = PI
	_ctx.announced_contracts[A] = B
	_ctx.announced_contracts[C] = B
	_fill_the_ring(8)


func _press(peer: int) -> void:
	var command := InputCommand.empty(1)
	command.buttons = InputBits.KILL
	_ordinal += 1
	command.received_ordinal = _ordinal
	# Two commands, because the server receives two per tick and the second is a
	# HELD press. Only the first is an edge.
	_system.report_input(peer, command, MatchContext.step_dt())
	_system.report_input(peer, command, MatchContext.step_dt())


func _release(peer: int) -> void:
	_system.report_input(peer, InputCommand.empty(1), MatchContext.step_dt())


## One server tick: record the world as it now is, advance the clock, run the
## system. The recorder runs at the END of a tick on the real server, which is
## why the frame goes in before the increment.
func _advance(ticks: int = 1) -> void:
	for _i: int in ticks:
		_fill_the_ring(1)
		_ctx.tick += 1
		_system.tick(_ctx, MatchContext.net_dt())


func _state(peer: int) -> StringName:
	return (_ctx.pawn_contexts[peer] as PawnContext).state_id


# ------------------------------------------------------- the kill itself --


func test_a_valid_press_commits_the_killer_to_the_animation() -> void:
	# **THE PREMISE.** Every refusal below would be true of a system that never
	# allowed a kill at all.
	_two_players()
	_press(A)
	_advance()
	assert_eq(_state(A), PawnStateId.KILL_ANIM, "a valid kill did not start")
	assert_eq(_state(B), PawnStateId.IDLE, "the victim died on the initiation tick")
	assert_eq(_system.pending_count(), 1)


func test_the_victim_dies_at_the_contact_frame_and_not_before() -> void:
	# `TUN-KILL-CORPSE-SPAWN-DELAY` 0.9 s of the 1.4 s animation. The gap between
	# the two is where a last-second stun is a genuine save, which is why the
	# contact frame is a tunable rather than an art decision (GDD-02 §3.2 rule 1).
	var deaths: Array = []
	_system.killed.connect(func(k: int, v: int, _at: Vector3) -> void: deaths.append([k, v]))
	_two_players()
	_press(A)
	_advance()
	var contact := Tuning.ticks(&"TUN-KILL-CORPSE-SPAWN-DELAY")
	assert_gt(contact, 1, "the contact frame is one tick; this test proves nothing")

	_advance(contact - 1)
	assert_eq(_state(B), PawnStateId.IDLE, "the victim died before the contact frame")
	assert_eq(deaths.size(), 0)

	_advance()
	assert_eq(_state(B), PawnStateId.DEAD, "the victim did not die at the contact frame")
	assert_eq(deaths, [[A, B]], "the kill was announced wrongly")
	assert_eq(_system.kills_landed, 1)


func test_the_two_clocks_measuring_the_animation_agree() -> void:
	# **TRAP 9, IN THE ONE PLACE IT WOULD DECIDE A DEATH.** This system counts the
	# contact frame in NET ticks and `KillAnimState` counts the same moment in STEP
	# ticks, because it is incremented inside `step()` at 60 Hz. Both are plausible
	# integers, and getting one wrong halves or doubles the window in which a stun
	# can still save somebody.
	var net_ticks := Tuning.ticks(&"TUN-KILL-CORPSE-SPAWN-DELAY")
	var step_ticks := Tuning.step_ticks(&"TUN-KILL-CORPSE-SPAWN-DELAY")
	assert_almost_eq(float(net_ticks) / Tuning.net.server_tick, 0.9, 0.02)
	assert_almost_eq(float(step_ticks) / Tuning.net.client_input_rate, 0.9, 0.02)
	assert_ne(net_ticks, step_ticks, "the two tick domains agree; one of them is being read wrong")


# ---------------------------------------------------------- the refusals --


func test_a_rejected_press_costs_suspicion_once_not_every_tick() -> void:
	# Edge-triggered. `PawnContext.held_buttons` is rewritten inside `step()` at
	# 60 Hz, so a system reading it at the `combat` stage sees every press as held —
	# which is why this system keeps its own map, and why holding the button down
	# for a second must cost 30 rather than 900.
	_place(A, Vector3.ZERO)
	_place(C, Vector3(0.0, 0.0, 1.0))
	_ctx.announced_contracts[A] = B
	_fill_the_ring(8)
	_press(A)
	_advance(10)
	assert_almost_eq(
		_ctx.impulses.pending(A),
		Tuning.suspicion.gain_failed_kill,
		0.001,
		"a held kill button was charged more than once"
	)
	assert_eq(_system.presses_judged, 1)


func test_releasing_and_pressing_again_is_a_second_press() -> void:
	_place(A, Vector3.ZERO)
	_place(C, Vector3(0.0, 0.0, 1.0))
	_ctx.announced_contracts[A] = B
	_fill_the_ring(8)
	_press(A)
	_advance()
	_release(A)
	_press(A)
	_advance()
	assert_almost_eq(_ctx.impulses.pending(A), Tuning.suspicion.gain_failed_kill * 2.0, 0.001)


func test_a_rejection_announces_itself_because_silence_is_the_worst_answer() -> void:
	# GDD-02 §9 failure mode 7: *whatever the cause, the fix is feedback — a
	# rejected kill must play a distinct whiff, never silence.*
	var whiffs: Array = []
	_system.kill_rejected.connect(func(p: int, v: int, _t: int) -> void: whiffs.append([p, v]))
	_place(A, Vector3.ZERO)
	_place(C, Vector3(0.0, 0.0, 1.0))
	_ctx.announced_contracts[A] = B
	_fill_the_ring(8)
	_press(A)
	_advance()
	assert_eq(whiffs.size(), 1, "a rejected kill was silent")
	assert_eq(whiffs[0][1], KillVerdict.V.WRONG_TARGET)


func test_pressing_kill_while_already_killing_costs_nothing() -> void:
	# `BUSY` is not a mistake the player made. Charging for it would let a stagger
	# compound itself, and would punish a finger that stayed on the button.
	_two_players()
	_press(A)
	_advance()
	_release(A)
	_press(A)
	_advance()
	assert_almost_eq(_ctx.impulses.pending(A), 0.0, 0.001, "a press mid-animation was charged")


func test_a_cinder_cloud_refuses_the_initiation_including_the_casters_own() -> void:
	# TDD-10 §3's first gate. An area denial that exempted whoever threw it would be
	# a kill setup rather than a denial.
	_two_players()
	_ctx.cinderfall.add(Vector3.ZERO, _ctx.tick - 6)
	_press(A)
	_advance()
	assert_eq(_state(A), PawnStateId.KILL_ANIM if false else PawnStateId.IDLE)
	assert_almost_eq(
		_ctx.impulses.pending(A), 0.0, 0.001, "the cloud gate charged suspicion — it is Z1, not Z2"
	)

	# The counterfactual: with the cloud gone, the identical press lands.
	_ctx.cinderfall.clear()
	_release(A)
	_press(A)
	_advance()
	assert_eq(_state(A), PawnStateId.KILL_ANIM, "the fixture cannot tell a cloud from a bad kill")


# ----------------------------------------------------------- the contest --


func test_the_first_arrival_kills_and_the_second_is_staggered() -> void:
	var losers: Array = []
	_system.contest_resolved.connect(func(l: int, _v: int) -> void: losers.append(l))
	_a_shared_victim()

	_press(A)
	_press(C)
	_advance()
	assert_eq(_state(A), PawnStateId.KILL_ANIM, "the first arrival did not get the kill")
	assert_eq(_state(C), PawnStateId.IDLE, "both killers committed to the same victim")
	assert_eq(losers, [C], "the contest loser was not announced")


func test_the_contest_loser_pays_tempo_and_nothing_else() -> void:
	# `TUN-KILL-CONTEST-STAGGER` 1.5 s. **No points, no lockout, no suspicion** —
	# losing a race should cost tempo, not the match.
	_a_shared_victim()
	_press(A)
	_press(C)
	_advance()
	assert_almost_eq(_ctx.impulses.pending(C), 0.0, 0.001, "the contest loser was charged")

	# And the stagger is a refusal to initiate, not a refusal to exist: they may
	# press again once it is served.
	_release(C)
	_press(C)
	_advance()
	assert_almost_eq(_ctx.impulses.pending(C), 0.0, 0.001, "a press during the stagger was charged")
	_advance(Tuning.ticks(&"TUN-KILL-CONTEST-STAGGER"))
	_release(C)
	_press(C)
	_advance()
	assert_gt(_system.presses_judged, 2, "the stagger never ended")


# -------------------------------------------------------- the reticle bit --


func test_the_reticle_opens_only_when_a_press_would_succeed() -> void:
	# GDD-06 §4. **Server-written**, because the client could compute the geometry
	# and would be wrong about the one thing that decides it: whether that player is
	# its contract.
	_two_players()
	_advance()
	assert_true((_ctx.pawn_contexts[A] as PawnContext).kill_ready, "the reticle stayed shut")
	assert_false(
		(_ctx.pawn_contexts[B] as PawnContext).kill_ready, "the victim's reticle opened too"
	)

	(_ctx.pawn_contexts[B] as PawnContext).position = Vector3(0.0, 0.0, 20.0)
	_advance()
	assert_false(
		(_ctx.pawn_contexts[A] as PawnContext).kill_ready, "the reticle stayed open at 20 m"
	)


func test_the_reticle_shuts_the_moment_the_killer_commits() -> void:
	# Computed after the presses, not before: a killer mid-animation cannot act, and
	# a reticle that stayed open for the whole 1.4 s would be inviting a press that
	# is refused as `BUSY`.
	_two_players()
	_press(A)
	_advance()
	assert_false((_ctx.pawn_contexts[A] as PawnContext).kill_ready, "the reticle was open mid-kill")


# ------------------------------------------------------------- lifecycle --


func test_a_departed_peer_leaves_nothing_behind() -> void:
	# ENet reuses peer ids. A pending kill or a stagger left behind is inherited by
	# the next joiner — US-0037's lesson.
	_two_players()
	_press(A)
	_advance()
	_system.forget(A)
	assert_eq(_system.pending_count(), 0)
	assert_eq(_system.contest.count(), 0)

	_two_players()
	_press(A)
	_advance()
	_system.forget(B)
	assert_eq(_system.pending_count(), 0, "a kill on a departed victim was still in flight")


func test_the_rewind_happens_once_per_judged_press() -> void:
	# ADR-0010 allows two rewind call sites in the whole project. The counter is
	# what makes "how often" answerable rather than assumed — and a system that
	# rewound per tick rather than per press would be doing it thirty times a second
	# for every player standing still.
	_two_players()
	_advance(5)
	assert_eq(_system.rewinds, 0, "the system rewound with nobody pressing anything")
	_press(A)
	_advance()
	assert_eq(_system.rewinds, 1, "one press cost %d rewinds" % _system.rewinds)
