## **THE BLEND-THEN-STRIKE PLAY MUST NOT BE FRAME-PERFECT.** US-0053,
## TDD-07 §3.2, `SCORE-BLENDED`.
##
## `TUN-BLEND-SCORE-GRACE` 1.0 s is what makes the single most valuable bonus in
## the game (+200) legible rather than a 33 ms window. A player who steps out of a
## pocket and kills their contract earned it; a player who has been standing in
## the street for two seconds did not.
extends GutTest

const PEER := 6

var _blend: BlendSystem
var _ctx: MatchContext
var _pawn: PawnContext
var _t: SuspicionTuning


func before_each() -> void:
	_t = Tuning.suspicion
	_blend = BlendSystem.new()
	_ctx = MatchContext.new()
	_ctx.crowd_hash.setup(AABB(Vector3(-20, -20, -20), Vector3(80, 40, 80)), 32)
	_pawn = PawnContext.new()
	_pawn.peer_id = PEER
	_pawn.reset_for_spawn(Vector3.ZERO, 0.0)
	_pawn.state_id = PawnStateId.IDLE
	_ctx.pawn_contexts[PEER] = _pawn
	_crowd(int(_t.blend_pocket_min_npc))


func _crowd(count: int) -> void:
	var at := PackedVector3Array()
	for i: int in count:
		at.append(Vector3(cos(float(i)), 0.0, sin(float(i))))
	_ctx.crowd_hash.rebuild(at, [], at.size())


func _resolve(times: int) -> void:
	for _i: int in times:
		_ctx.tick += 1
		_blend.resolve(_ctx)


## Seconds converted the way the server does — never a literal tick count, or the
## test stops following the tunable it is about.
func _ticks(seconds: float) -> int:
	return int(round(seconds * Tuning.net.server_tick))


## Enter, hold, then leave deliberately and let the exit window close.
func _blend_then_leave() -> void:
	_blend.request(PEER, _ctx)
	_resolve(maxi(Tuning.ticks(&"TUN-BLEND-ENTRY-TIME"), 1))
	assert_true(_blend.is_crushing(PEER), "the blend never reached HELD")
	_blend.request(PEER, _ctx)
	_resolve(maxi(Tuning.ticks(&"TUN-BLEND-EXIT-TIME"), 1))
	assert_eq(_blend.wire_kind(PEER), BlendKind.Kind.NONE, "the exit never completed")


func test_the_grace_is_a_real_window_and_not_a_single_tick() -> void:
	# Guards every assertion below: at one tick, "0.9 s after" and "1.1 s after"
	# are the same answer.
	assert_gt(Tuning.ticks(&"TUN-BLEND-SCORE-GRACE"), 2, "TUN-BLEND-SCORE-GRACE is not a duration")


func test_nine_tenths_of_a_second_after_exit_qualifies() -> void:
	_blend_then_leave()
	_resolve(_ticks(0.9))
	assert_gt(
		_blend.grace_ticks_remaining(PEER),
		0,
		"a kill 0.9 s after leaving a blend would not earn SCORE-BLENDED"
	)


func test_one_and_a_tenth_seconds_after_exit_does_not() -> void:
	_blend_then_leave()
	_resolve(_ticks(1.1))
	assert_eq(
		_blend.grace_ticks_remaining(PEER),
		0,
		"a kill 1.1 s after leaving a blend would still earn SCORE-BLENDED"
	)


func test_a_break_arms_the_grace_as_well_as_a_deliberate_exit() -> void:
	# **THE DECISION WORTH ARGUING ABOUT.** The alternative — only a deliberate
	# exit qualifies — hands a hunter a way to deny the bonus by sprinting past a
	# pocket and scattering it, which pays the reckless approach the whole design
	# exists to charge for. A player who was blended a second ago was blended.
	_blend.request(PEER, _ctx)
	_resolve(maxi(Tuning.ticks(&"TUN-BLEND-ENTRY-TIME"), 1))
	assert_true(_blend.is_crushing(PEER), "the blend never reached HELD")
	_crowd(0)
	_resolve(1)
	assert_eq(_blend.wire_kind(PEER), BlendKind.Kind.NONE, "the pocket did not break")
	assert_gt(_blend.grace_ticks_remaining(PEER), 0, "a scattered pocket denied the grace")


func test_a_blend_that_never_reached_held_arms_nothing() -> void:
	# Pressing blend and being scattered 0.1 s later is not a blend. Arming the
	# grace here would make the bonus reachable by tapping the key near a crowd,
	# which is the opposite of what it rewards.
	_blend.request(PEER, _ctx)
	_resolve(1)
	assert_false(_blend.is_crushing(PEER), "entry completed in one tick — this proves nothing")
	_crowd(0)
	_resolve(1)
	assert_eq(_blend.grace_ticks_remaining(PEER), 0, "an interrupted entry armed the score grace")


func test_the_grace_does_not_re_arm_while_it_runs_down() -> void:
	# It counts from the exit, not from the last tick anything happened. A grace
	# that re-armed would be permanent for a player standing next to a crowd.
	_blend_then_leave()
	var first := _blend.grace_ticks_remaining(PEER)
	_resolve(3)
	assert_lt(_blend.grace_ticks_remaining(PEER), first, "the grace stopped counting down")


func test_a_player_who_never_blended_has_no_grace() -> void:
	assert_eq(_blend.grace_ticks_remaining(PEER), 0, "an unblended player carried a score grace")
	assert_eq(_blend.grace_ticks_remaining(9999), 0, "an unknown peer carried a score grace")
