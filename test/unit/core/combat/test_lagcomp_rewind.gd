## **HOW FAR BACK A KILL MAY REACH, AND WHY THE CEILING IS THE HALF THAT MATTERS.**
## US-0060, ADR-0010, TDD-04 §8.1.
##
## A client draws remote players `TUN-NET-INTERP-BUFFER` 100 ms in the past plus
## half its round trip. Without compensation the patient approach fails
## arbitrarily — *you walk up behind someone, press kill at conversational
## distance, and nothing happens* — which ADR-0010 calls the worst possible bug in
## a game whose entire emotional payload is that approach.
##
## The cost is that the victim is sometimes killed where they no longer are. It is
## **bounded to `TUN-NET-LAGCOMP-MAX` 200 ms**, and that bound is what this file
## is about: above it, a high-ping player's kills start failing, which is the
## correct place for the pain.
extends GutTest

const KILLER := 41
const VICTIM := 42

var _history: LagCompHistory
var _t: CombatTuning


func before_each() -> void:
	_history = LagCompHistory.new()
	_t = Tuning.combat


# ------------------------------------------------------------- the clamp --


func test_zero_ping_still_rewinds_the_interpolation_buffer() -> void:
	# **THE FLOOR IS NOT AN ARBITRARY MINIMUM.** Even a client on the same machine
	# draws remotes 100 ms in the past, because that is what the interpolator does.
	# A rewind of zero at zero ping would deny every kill against a moving target
	# on a LAN.
	assert_almost_eq(RewindClamp.milliseconds_for(0.0), Tuning.net.interp_buffer, 0.001)
	assert_almost_eq(RewindClamp.milliseconds_for(0.0), Tuning.net.lagcomp_min, 0.001)


func test_the_rewind_is_half_the_round_trip_plus_the_buffer() -> void:
	# Half, not all of it. What the attacker saw left the server one trip-half ago;
	# counting the return leg too would reach a whole trip further into the past.
	assert_almost_eq(RewindClamp.milliseconds_for(100.0), 50.0 + Tuning.net.interp_buffer, 0.001)


func test_the_ceiling_holds_at_any_ping() -> void:
	# **THE IMPORTANT HALF.** A 600 ms player killing somebody half a second in
	# their past is indistinguishable from cheating (ADR-0010).
	for rtt: float in [300.0, 600.0, 2000.0, 100000.0]:
		assert_almost_eq(
			RewindClamp.milliseconds_for(rtt),
			Tuning.net.lagcomp_max,
			0.001,
			"the clamp let a %.0f ms client reach further back" % rtt
		)


func test_a_negative_round_trip_cannot_reach_forward() -> void:
	# Not paranoia about the transport: `Net.rtt_ms` returns 0.0 for a peer it does
	# not know, and a signed statistic read from ENet is somebody else's to
	# guarantee. Reaching *forward* would validate against a world that has not
	# happened.
	assert_almost_eq(RewindClamp.milliseconds_for(-500.0), Tuning.net.lagcomp_min, 0.001)


func test_the_rewind_never_asks_for_a_negative_tick() -> void:
	# A kill in the opening second of a match. `LagCompHistory` answers a tick
	# outside the ring with the **nearest** one it holds rather than refusing, so an
	# unclamped negative would silently resolve against the oldest frame.
	assert_eq(RewindClamp.tick_for(2, 0.0), 0)


func test_the_history_outlasts_the_deepest_rewind() -> void:
	# Invariant 16 in code rather than in a document: the ring must never be the
	# binding constraint on how far back a validation reaches.
	assert_gt(
		_history.capacity(),
		RewindClamp.max_ticks(),
		"the lag-comp ring is shorter than the maximum rewind"
	)


# ------------------------------------------ a kill against the past world --


## A victim who walks toward the killer and away again: far at eight ticks ago,
## **in reach at five**, far again at three, and in reach once more at eight-plus.
##
## The last part is the counterfactual. An implementation with no ceiling would
## reach past 200 ms and find the victim in range again — so removing the clamp
## turns the 250 ms case from a refusal into a kill.
func _record_a_walk_past(now: int) -> void:
	for back: int in range(12, -1, -1):
		var tick := now - back
		var distance := 6.0
		if back == 5 or back >= 9:
			distance = 1.5
		var ids := PackedInt32Array([KILLER, VICTIM])
		var places := PackedVector3Array([Vector3.ZERO, Vector3(0.0, 0.0, distance)])
		_history.record(tick, ids, places, PackedFloat32Array([0.0, 0.0]))


func _verdict_at(now: int, rtt_ms: float) -> KillVerdict.V:
	var tick := RewindClamp.tick_for(now, rtt_ms)
	var world := _history.rewind(tick, Vector3.ZERO, 12.0)
	return KillRules.resolve(world, KILLER, VICTIM, PackedInt32Array([VICTIM]), _t)[0]


func test_the_kill_lands_where_the_attacker_saw_the_victim() -> void:
	var now := 400
	_record_a_walk_past(now)
	# 100 ms of round trip is five ticks back, where the victim was at 1.5 m.
	assert_eq(RewindClamp.ticks_for(100.0), 5, "the tick arithmetic moved; the fixture is stale")
	assert_eq(
		_verdict_at(now, 100.0),
		KillVerdict.V.ALLOWED,
		"a kill against the world the attacker actually saw was denied"
	)


func test_the_same_kill_fails_with_no_compensation_at_all() -> void:
	# **THE POINT OF THE WHOLE MECHANISM.** Three ticks back — the floor — the
	# victim has already walked out of reach, and the press does nothing.
	var now := 400
	_record_a_walk_past(now)
	assert_eq(RewindClamp.ticks_for(0.0), 3, "the tick arithmetic moved; the fixture is stale")
	assert_eq(_verdict_at(now, 0.0), KillVerdict.V.OUT_OF_RANGE)


func test_a_high_ping_attacker_cannot_reach_the_moment_they_want() -> void:
	# **THE CLAMP, AS A KILL RATHER THAN AS ARITHMETIC.** At 300 ms of round trip
	# the raw rewind would be 250 ms — nine ticks, where the victim is in reach
	# again. The ceiling stops at six, where they are not.
	var now := 400
	_record_a_walk_past(now)
	assert_eq(RewindClamp.ticks_for(300.0), 6, "the clamp is not capping at TUN-NET-LAGCOMP-MAX")
	assert_eq(
		_verdict_at(now, 300.0),
		KillVerdict.V.OUT_OF_RANGE,
		"a 300 ms client reached past the ceiling and killed somebody 250 ms in their past"
	)

	# And the counterfactual: unclamped, that same request finds them.
	var unclamped := _history.rewind(now - 9, Vector3.ZERO, 12.0)
	assert_eq(
		KillRules.resolve(unclamped, KILLER, VICTIM, PackedInt32Array([VICTIM]), _t)[0],
		KillVerdict.V.ALLOWED,
		"the fixture does not distinguish a clamped rewind from an unclamped one"
	)


func test_only_positions_and_yaw_come_back_from_the_past() -> void:
	# **THE OMISSION IS THE DESIGN.** TDD-04 §8.2 rewinds transforms and explicitly
	# does not rewind suspicion tier, contract assignment or cooldowns — each would
	# hand an attacker something the present has already taken away. The way that
	# stays true under a year of M4 pressure is that `RewoundWorld` has nowhere to
	# put them.
	var world := RewoundWorld.new()
	var fields: PackedStringArray = []
	for prop: Dictionary in world.get_property_list():
		if int(prop["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE:
			fields.append(String(prop["name"]))
	assert_eq(
		fields,
		PackedStringArray(["ids", "positions", "yaws", "tick"]),
		"RewoundWorld gained a field. Tier, contract and cooldowns are NEVER rewound."
	)


func test_an_entity_outside_the_rewind_is_not_at_the_origin() -> void:
	# `position_of` answers `Vector3.INF` rather than zero for somebody it does not
	# hold. A caller that treated the fallback as the origin would validate a kill
	# from anywhere in the district for anyone standing near the map's corner.
	var world := _history.rewind(0, Vector3.ZERO, 12.0)
	assert_eq(world.position_of(999), Vector3.INF)
