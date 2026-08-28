## **THE TENSE, THROUGH A REAL `SYS-KILL`.** US-0065, GDD-07 §3, TDD-10 §2.
##
## Every bonus is judged at the moment the player **pressed**, and paid 0.9 s later
## when the body falls. The pure half is `test_score_bonuses.gd`; what is here is
## the half no pure test can reach — that `KillSystem` captures the facts at
## `_begin` and carries them on its pending row to the contact frame.
##
## **THE FAILURE THIS PREVENTS IS SILENT AND FAVOURS THE WRONG PLAY.** Evaluated at
## resolution, a hunter who was Anonymous when they committed loses Silent to the
## 1.4 s animation they cannot cancel — 200 points for a state change they had no
## way to prevent — while a hunter who sprinted into range gains Patient by
## standing still through it. Both directions are asserted, because a capture that
## simply read the wrong tick would pass a test of only one.
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
	_system.scoring = KillScoring.new()
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
	_ordinal += 1
	command.received_ordinal = _ordinal
	_system.report_input(peer, command, MatchContext.step_dt())
	_system.report_input(peer, command, MatchContext.step_dt())


func _advance(ticks: int = 1) -> void:
	for _i: int in ticks:
		_fill_the_ring(1)
		_ctx.tick += 1
		_system.tick(_ctx, MatchContext.net_dt())


func _kinds() -> Array:
	var out: Array = []
	for event: ScoreEvent in _ctx.score.events():
		if event.actor_id == A:
			out.append(event.kind)
	return out


## Press, then run past the contact frame.
func _kill_and_land() -> void:
	_press(A)
	_advance()
	_advance(Tuning.ticks(&"TUN-KILL-CORPSE-SPAWN-DELAY") + 2)


func test_the_fixture_actually_kills_somebody() -> void:
	# **THE PREMISE.** Every assertion below reads an empty log just as happily if
	# the press never landed, and a kill fixture that quietly rejects is the
	# commonest way a combat test passes for the wrong reason.
	_kill_and_land()
	assert_eq(_system.kills_landed, 1, "the press did not land, so nothing below means anything")
	assert_gt(_ctx.score.size(), 0, "a landed kill wrote nothing to the log")


func test_nothing_is_paid_before_the_contact_frame() -> void:
	# **CAPTURED AT INITIATION, PAID AT RESOLUTION.** A kill interrupted by a
	# third party before the contact frame pays nothing at all, so the awards
	# cannot be written when they are computed.
	_press(A)
	_advance()
	assert_eq(_ctx.score.size(), 0, "the kill was paid for while the animation was still running")
	assert_eq(
		(_ctx.pawn_contexts[A] as PawnContext).state_id,
		PawnStateId.KILL_ANIM,
		"the fixture did not commit the killer"
	)


func test_silent_survives_an_animation_that_makes_the_killer_conspicuous() -> void:
	# The first direction. The killer presses while Anonymous and the animation
	# makes them Exposed — which it does, in the real game, because
	# `TUN-SUSPICION-GAIN-FAILED-KILL` and the crowd's reaction both land inside it.
	(_ctx.pawn_contexts[A] as PawnContext).tier = SuspicionMath.Tier.ANONYMOUS
	_press(A)
	_advance()
	(_ctx.pawn_contexts[A] as PawnContext).tier = SuspicionMath.Tier.EXPOSED
	_advance(Tuning.ticks(&"TUN-KILL-CORPSE-SPAWN-DELAY") + 2)
	assert_has(
		_kinds(), Ids.SCORE_SILENT, "the killer lost Silent to an animation they committed to"
	)
	assert_does_not_have(_kinds(), Ids.SCORE_RECKLESS, "the ladder paid the resolution tier")


func test_recklessness_is_not_laundered_by_standing_still_afterwards() -> void:
	# The other direction, and the one that would be exploitable: press while
	# Exposed, then let the animation carry you back to Anonymous.
	(_ctx.pawn_contexts[A] as PawnContext).tier = SuspicionMath.Tier.EXPOSED
	_press(A)
	_advance()
	(_ctx.pawn_contexts[A] as PawnContext).tier = SuspicionMath.Tier.ANONYMOUS
	_advance(Tuning.ticks(&"TUN-KILL-CORPSE-SPAWN-DELAY") + 2)
	assert_has(_kinds(), Ids.SCORE_RECKLESS, "an Exposed kill was laundered into a clean one")
	assert_does_not_have(_kinds(), Ids.SCORE_SILENT, "the killer was paid for being seen")


func test_the_events_are_stamped_at_the_press_and_the_death_at_the_fall() -> void:
	# **TWO MOMENTS, 0.9 s APART, AND THE MULTIPLIER IS FROZEN FROM WHICHEVER IS ON
	# THE EVENT.** The bonuses were earned when the player pressed; the death
	# happened when the body fell.
	var pressed := _ctx.tick + 1
	_kill_and_land()
	for event: ScoreEvent in _ctx.score.events():
		if event.kind == Ids.SCORE_DEATH:
			assert_gt(event.tick, pressed, "the death was stamped at the press")
		else:
			assert_eq(event.tick, pressed, "%s was stamped away from the press" % event.kind)


func test_a_kill_pays_the_unit_and_one_rung_and_a_death_marker() -> void:
	_kill_and_land()
	assert_has(_kinds(), Ids.SCORE_CONTRACT)
	assert_eq(ScoreFold.deaths_of(_ctx.score.events(), B), 1, "no death marker for the victim")
	assert_eq(ScoreFold.total_for(_ctx.score.events(), B), 0, "the victim was paid or charged")


func test_the_whole_kill_is_one_feed_group() -> void:
	_kill_and_land()
	var groups: Dictionary = {}
	for event: ScoreEvent in _ctx.score.events():
		groups[event.group_id] = true
	assert_eq(groups.size(), 1, "one kill produced %d feed groups" % groups.size())


func test_the_debt_is_recorded_for_vendetta() -> void:
	_kill_and_land()
	assert_true(
		_ctx.score_windows.avenges(B, A), "the victim is not owed revenge against their killer"
	)


func test_an_unscored_kill_system_still_kills() -> void:
	# **NULL `scoring` IS LEGAL AND MEANS AN UNSCORED MATCH.** Every combat fixture
	# written before US-0065 leaves it null, and the alternative is a hundred tests
	# that must stand a score log up to press a button.
	_system.scoring = null
	_kill_and_land()
	assert_eq(_system.kills_landed, 1, "an unscored kill system stopped killing")
	assert_eq(_ctx.score.size(), 0, "an unscored kill system wrote to the log")
