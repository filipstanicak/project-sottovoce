## **NO TIER OSCILLATES FASTER THAN 1 Hz.** US-0051, GDD-03 §3.4, TDD-07 §2.3.
##
## Without hysteresis a player hovering at exactly 30.0 — which happens constantly,
## because 30.0 is where a slow climb crosses — flickers between tiers at 30 Hz.
## The visible result is a strobing silhouette tint. **The actual result is that the
## tint stops being trustworthy**, and this game is an information economy: an
## unreliable channel is worse than a missing one, because players spend attention
## on it and get nothing back.
extends GutTest

const DT := 1.0 / 30.0

var _t: SuspicionTuning


func before_each() -> void:
	_t = Tuning.suspicion


## Drive a value through `samples` and count how many times the tier changes.
func _flips(values: Array) -> int:
	var tier: int = SuspicionMath.Tier.ANONYMOUS
	var flips := 0
	for value: float in values:
		var next := SuspicionMath.evaluate_tier(value, tier, _t)
		if next != tier:
			flips += 1
		tier = next
	return flips


func test_hovering_on_the_threshold_does_not_flicker() -> void:
	# **THE CASE THE RULE EXISTS FOR.** A value dithering by a hundredth of a point
	# either side of 30.0, for two seconds at the net tick.
	var values: Array = []
	for step: int in 60:
		values.append(_t.tier_noticed + (0.01 if step % 2 == 0 else -0.01))
	var flips := _flips(values)
	gut.p(
		"dithering on the Noticed threshold for %d ticks: %d tier changes" % [values.size(), flips]
	)
	assert_lte(flips, 1, "the tier flickered %d times on a value that never moved" % flips)


func test_the_same_dither_without_hysteresis_would_strobe() -> void:
	# **THE COUNTERFACTUAL.** Without this, the test above passes on any
	# implementation that happens not to change tier, including one that never
	# changes tier at all.
	var tier: int = SuspicionMath.Tier.ANONYMOUS
	var flips := 0
	for step: int in 60:
		var value: float = _t.tier_noticed + (0.01 if step % 2 == 0 else -0.01)
		# The naive rule: threshold only, no hysteresis.
		var next: int = (
			SuspicionMath.Tier.NOTICED if value >= _t.tier_noticed else SuspicionMath.Tier.ANONYMOUS
		)
		if next != tier:
			flips += 1
		tier = next
	assert_gt(flips, 30, "the naive rule did not strobe, so this dither proves nothing")


func test_a_tier_is_exited_exactly_the_hysteresis_below_its_threshold() -> void:
	var noticed: int = SuspicionMath.Tier.NOTICED
	assert_eq(
		SuspicionMath.evaluate_tier(_t.tier_noticed - _t.hysteresis, noticed, _t),
		SuspicionMath.Tier.NOTICED,
		"Noticed was exited AT the hysteresis rather than below it"
	)
	assert_eq(
		SuspicionMath.evaluate_tier(_t.tier_noticed - _t.hysteresis - 0.01, noticed, _t),
		SuspicionMath.Tier.ANONYMOUS,
		"Noticed was not exited below the hysteresis"
	)
	var exposed: int = SuspicionMath.Tier.EXPOSED
	assert_eq(
		SuspicionMath.evaluate_tier(_t.tier_exposed - _t.hysteresis, exposed, _t),
		SuspicionMath.Tier.EXPOSED,
		"Exposed was exited AT the hysteresis rather than below it"
	)
	assert_eq(
		SuspicionMath.evaluate_tier(_t.tier_exposed - _t.hysteresis - 0.01, exposed, _t),
		SuspicionMath.Tier.NOTICED,
		"Exposed was not exited below the hysteresis"
	)


func test_a_tier_is_entered_at_its_threshold_not_above_it() -> void:
	var anon: int = SuspicionMath.Tier.ANONYMOUS
	assert_eq(
		SuspicionMath.evaluate_tier(_t.tier_noticed, anon, _t),
		SuspicionMath.Tier.NOTICED,
		"Noticed was not entered AT its threshold"
	)
	assert_eq(
		SuspicionMath.evaluate_tier(_t.tier_noticed - 0.01, anon, _t),
		SuspicionMath.Tier.ANONYMOUS,
		"Noticed was entered below its threshold"
	)


func test_a_forced_tier_takes_effect_in_the_tick_it_is_forced() -> void:
	# **THE AMENDMENT TO TDD-07 §2.3's SKETCH.** That one walks one rung per tick in
	# both directions, so a stunned player — `TUN-STUN-FORCES-EXPOSED` sets the
	# scalar to 100 outright — would read Noticed for a tick first. A rule that
	# forces a tier is not kept if it lands a tick late.
	assert_eq(
		SuspicionMath.evaluate_tier(_t.max_value, SuspicionMath.Tier.ANONYMOUS, _t),
		SuspicionMath.Tier.EXPOSED,
		"a forced Exposed spent a tick at Noticed on the way"
	)


func test_a_fall_passes_through_the_rung_between() -> void:
	# **AND THE OTHER DIRECTION IS NOT SYMMETRICAL, ON PURPOSE.** Nothing forces a
	# tier downward: the only ways down are decay and a blend crush, and a crush
	# takes TUN-BLEND-CRUSH-TIME 1.2 s — 36 ticks — so passing through Noticed is a
	# real moment rather than an artefact of the rule.
	assert_eq(
		SuspicionMath.evaluate_tier(0.0, SuspicionMath.Tier.EXPOSED, _t),
		SuspicionMath.Tier.NOTICED,
		"a fall from Exposed skipped Noticed entirely"
	)


func test_a_real_decay_from_exposed_changes_tier_at_most_once_a_second() -> void:
	# **THE STORY'S ACTUAL CRITERION, ON A REAL CURVE RATHER THAN A DITHER.** A
	# player decaying from 100 crosses both thresholds; what must not happen is a
	# crossing that repeats.
	var s := SuspicionState.new()
	s.value = _t.max_value
	s.nearest_npc_distance = 0.5
	s.speed_state = PawnStateId.IDLE
	s.speed = 0.0
	s.ticks_since_gain = 999
	var tier: int = SuspicionMath.Tier.EXPOSED
	var changes: Array = []
	for step: int in 600:
		s.value = SuspicionMath.integrate(s, _t, DT)
		var next := SuspicionMath.evaluate_tier(s.value, tier, _t)
		if next != tier:
			changes.append(step)
			tier = next
	gut.p("decaying 100 -> 0 changed tier at ticks %s" % [changes])
	assert_eq(
		changes.size(), 2, "a monotone decay produced %d tier changes, not two" % changes.size()
	)
	assert_gt(
		int(changes[1]) - int(changes[0]),
		30,
		"two tier changes landed inside one second of a monotone decay"
	)
