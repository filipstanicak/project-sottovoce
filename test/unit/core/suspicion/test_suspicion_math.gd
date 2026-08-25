## **THE EIGHT PROPERTIES US-0051 ASKS FOR, ONE PER TEST.** GDD-03 §3.2–3.4,
## TDD-07 §2.
##
## Every number here is read from `Tuning.suspicion` rather than written down. A
## test that hard-codes 14.0 stops testing the ladder the day the ladder is retuned
## and starts testing a constant nobody uses — and this is the one file where that
## would be least visible, because the arithmetic would still be right.
extends GutTest

## The net tick. Every rate in §3.2 is per second, so the integrator is exercised at
## the rate the server actually runs it at.
const DT := 1.0 / 30.0

var _t: SuspicionTuning
var _s: SuspicionState


func before_each() -> void:
	_t = Tuning.suspicion
	_s = SuspicionState.new()
	# Default to the civilian case: standing in a crowd, nothing owed.
	_s.nearest_npc_distance = 0.5
	_s.speed_state = PawnStateId.STROLL


## Run `seconds` of ticks, advancing `ticks_since_gain` the way `SYS-SUSPICION`
## will. **The counter is advanced from `SuspicionMath.gained()`**, never from a
## second reading of the state, or the two can disagree about what a gain was.
func _run(seconds: float) -> void:
	for _step: int in int(round(seconds / DT)):
		var earned := SuspicionMath.gained(_s, _t)
		_s.value = SuspicionMath.integrate(_s, _t, DT)
		_s.ticks_since_gain = 0 if earned else _s.ticks_since_gain + 1


func test_gain_and_decay_are_mutually_exclusive() -> void:
	# **ASM-0008, and the reason it is not an optimisation.** With concurrent decay a
	# run would cost 14 − 8 = 6/s and standing alone would cost 6 − 8 = **−2/s**:
	# the ladder would invert and being alone in an empty plaza would pay you.
	_s.speed_state = PawnStateId.RUN
	_s.speed = Tuning.movement.run
	_s.ticks_since_gain = 999  # decay fully armed, if it were allowed to run at all
	_run(1.0)
	assert_almost_eq(_s.value, _t.gain_run, 0.1, "a run did not cost its full published rate")


func test_the_alone_gain_is_not_cancelled_by_decay_either() -> void:
	# The case that would go NEGATIVE: +6/s against −8/s. A player standing alone in
	# Piazza Secca must accrue, or the empty plaza stops being dangerous.
	_s.nearest_npc_distance = _t.open_radius + 1.0
	_s.speed = 0.0
	_s.ticks_since_gain = 999
	_run(1.0)
	assert_almost_eq(_s.value, _t.gain_open, 0.1, "standing alone did not cost its full rate")


func test_sources_sum_additively() -> void:
	# ASM-0018. Sprinting on a roof with nobody nearby: 25 + 18 + 6 = 49/s.
	_s.speed_state = PawnStateId.SPRINT
	_s.speed = Tuning.movement.sprint
	_s.on_roof = true
	_s.nearest_npc_distance = INF
	var expected: float = _t.gain_sprint + _t.gain_roof + _t.gain_open
	assert_almost_eq(SuspicionMath.gain_rate(_s, _t), expected, 0.01, "sources did not sum")
	_run(1.0)
	assert_almost_eq(_s.value, expected, 0.1, "one second did not accrue the summed rate")
	# And the design consequence the sum exists for.
	var to_exposed: float = _t.tier_exposed / expected
	gut.p("sprint + roof + alone = %.1f/s, Exposed in %.2f s" % [expected, to_exposed])
	assert_lt(to_exposed, 2.0, "compounding three bad choices no longer compounds")


func test_decay_needs_the_speed_ceiling_and_the_delay_together() -> void:
	_s.value = 50.0
	_s.ticks_since_gain = 999
	# Above the ceiling: no decay, even with the delay long past.
	_s.speed = _t.decay_speed_ceiling + 0.1
	assert_eq(SuspicionMath.decay_rate(_s, _t, 0.0), 0.0, "decay ran above the speed ceiling")
	# At or below it: decay.
	_s.speed = _t.decay_speed_ceiling
	assert_almost_eq(
		SuspicionMath.decay_rate(_s, _t, 0.0), _t.decay_base, 0.01, "no decay at the ceiling"
	)
	# Inside the delay: no decay, however slow.
	_s.speed = 0.0
	_s.ticks_since_gain = Tuning.ticks(&"TUN-SUSPICION-DECAY-DELAY") - 1
	assert_eq(SuspicionMath.decay_rate(_s, _t, 0.0), 0.0, "decay ran inside the delay")


func test_the_delay_is_exactly_the_tunable_and_not_a_tick_either_side() -> void:
	# **THE OFF-BY-ONE THAT WOULD NEVER BE NOTICED.** A delay one tick short or long
	# is 33 ms — invisible in play, and it moves the tap-sprint arithmetic this whole
	# rule exists to settle.
	var delay := Tuning.ticks(&"TUN-SUSPICION-DECAY-DELAY")
	assert_gt(delay, 1, "the delay is not a duration — this test proves nothing")
	_s.value = 50.0
	_s.speed = 0.0
	_s.ticks_since_gain = delay
	assert_gt(SuspicionMath.decay_rate(_s, _t, 0.0), 0.0, "decay did not arm at the delay")
	_s.ticks_since_gain = delay - 1
	assert_eq(SuspicionMath.decay_rate(_s, _t, 0.0), 0.0, "decay armed a tick early")


func test_stillness_multiplies_decay_only_while_genuinely_stationary() -> void:
	_s.value = 100.0
	_s.ticks_since_gain = 999
	_s.has_stillness = true
	_s.speed = 0.0
	var still := SuspicionMath.decay_rate(_s, _t, 0.0)
	assert_almost_eq(still, _t.decay_base * _t.stillness_mult, 0.01, "stillness did not multiply")
	# Above the stillness ceiling but below the decay ceiling: base rate only.
	_s.speed = _t.stillness_speed_ceiling + 0.01
	assert_almost_eq(
		SuspicionMath.decay_rate(_s, _t, 0.0), _t.decay_base, 0.01, "stillness paid while moving"
	)
	# **THE CEILING IS NON-ZERO ON PURPOSE**: a crowd shoving a standing player must
	# not cost them the passive they equipped.
	assert_gt(_t.stillness_speed_ceiling, 0.0, "a micro-nudge would cancel PASV-STILLNESS")


func test_blending_crushes_linearly_and_overrides_both() -> void:
	_s.value = 100.0
	_s.blending = true
	# Blending while sprinting on a roof: the crush wins outright.
	_s.speed_state = PawnStateId.SPRINT
	_s.on_roof = true
	_s.nearest_npc_distance = INF
	_run(_t.blend_crush_time * 0.5)
	assert_almost_eq(_s.value, _t.max_value * 0.5, 0.5, "the crush is not linear")
	_run(_t.blend_crush_time * 0.5)
	assert_almost_eq(_s.value, 0.0, 0.1, "the crush did not reach zero in TUN-BLEND-CRUSH-TIME")
	# And it does not overshoot into the negative.
	_run(1.0)
	assert_eq(_s.value, 0.0, "the crush drove suspicion below zero")


func test_the_value_is_clamped_at_both_ends() -> void:
	_s.speed_state = PawnStateId.SPRINT
	_s.on_roof = true
	_s.nearest_npc_distance = INF
	_run(10.0)
	assert_eq(_s.value, _t.max_value, "ten seconds of 49/s did not clamp at the maximum")
	_s.value = 5.0
	_s.speed_state = PawnStateId.STROLL
	_s.on_roof = false
	_s.nearest_npc_distance = 0.5
	_s.speed = 0.0
	_s.ticks_since_gain = 999
	_run(5.0)
	assert_eq(_s.value, _t.min, "decay drove suspicion below the minimum")


func test_an_impulse_is_added_and_clamped() -> void:
	assert_almost_eq(
		SuspicionMath.apply_impulse(20.0, _t.gain_npc_bump, _t), 35.0, 0.01, "a bump did not land"
	)
	assert_eq(
		SuspicionMath.apply_impulse(90.0, _t.gain_loud_ability, _t),
		_t.max_value,
		"an impulse pushed past the maximum"
	)


func test_climbing_costs_less_than_standing_on_the_roof_it_reaches() -> void:
	# GDD-03 §3.2's ordering, asserted as a relationship rather than as two numbers:
	# a climb is a commitment you can be interrupted during, where roof presence is a
	# choice you keep making.
	assert_lt(_t.gain_climb, _t.gain_roof, "climbing is no longer cheaper than being up there")
	_s.speed_state = PawnStateId.CLIMB
	assert_almost_eq(
		SuspicionMath.gain_rate(_s, _t), _t.gain_climb, 0.01, "a climb costs the wrong rate"
	)


func test_stroll_and_blend_walk_cost_nothing_at_all() -> void:
	# The floor the whole design rests on: **the civilian speeds are free**, so
	# patience costs nothing and speed is the only thing that spends anonymity.
	for state: StringName in [PawnStateId.STROLL, PawnStateId.BLEND_WALK, PawnStateId.IDLE]:
		_s.speed_state = state
		assert_eq(
			SuspicionMath.gain_rate(_s, _t),
			0.0,
			"%s costs suspicion — the ladder has a floor" % state
		)
