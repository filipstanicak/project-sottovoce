## **THE CONE DRIFTS, AND THE DRIFT IS LEARNABLE.** US-0057, GDD-03 §8.3,
## design law 6.
##
## The wobble is a function of `(contract, tick)` and of nothing else. For the
## duration of one hunt it is a **stable property of that hunt**: a player can
## learn "the cone is drifting left of true" and compensate.
##
## **RANDOM PER-FRAME NOISE WOULD BE A DELETED CHANNEL.** Law 6 asks for
## imprecision that is designed, bounded, deterministic and learnable. Noise that
## cannot be learned is worth exactly as much as a narrower cone plus a lie, and
## it costs the player attention they will never be repaid for.
extends GutTest

const HUNTED := 4242
const OTHER := 4243

var _t: CompassTuning


func before_each() -> void:
	_t = Tuning.compass


func _ticks_per_second() -> float:
	return Tuning.net.server_tick


func test_the_wobble_is_a_real_amplitude_and_period() -> void:
	# **WITHOUT THIS THE WHOLE FILE PROVES NOTHING.** At zero amplitude every
	# assertion below is true of a cone that never moves.
	assert_gt(_t.cone_wobble, 0.0, "TUN-COMPASS-CONE-WOBBLE is zero — there is no drift to test")
	assert_gt(_t.cone_wobble_period, 1.0, "TUN-COMPASS-CONE-WOBBLE-PERIOD is not a duration")


func test_the_same_contract_and_tick_always_give_the_same_drift() -> void:
	# Determinism, stated the way a desync would break it: two peers computing this
	# from the same inputs must agree exactly, not approximately.
	for tick: int in [0, 7, 91, 2600]:
		assert_eq(
			CompassMath.wobble_radians(HUNTED, tick, _t),
			CompassMath.wobble_radians(HUNTED, tick, _t),
			"the wobble is not a function of its arguments at tick %d" % tick
		)


func test_the_drift_stays_inside_the_tuned_amplitude() -> void:
	# Bounded, which is the half of law 6 a sine gives for free — and the half that
	# would break the moment somebody added a second term.
	var bound := deg_to_rad(_t.cone_wobble)
	var reached := 0.0
	for tick: int in int(_ticks_per_second() * _t.cone_wobble_period * 2.0):
		var drift: float = CompassMath.wobble_radians(HUNTED, tick, _t)
		reached = maxf(reached, absf(drift))
		assert_lte(absf(drift), bound + 0.0001, "the cone drifted past TUN-COMPASS-CONE-WOBBLE")
	# And it actually reaches the amplitude across two full periods, so the bound is
	# a description rather than a ceiling nothing approaches.
	assert_gt(reached, bound * 0.95, "the drift never got near its own amplitude")


func test_it_completes_one_cycle_in_the_tuned_period() -> void:
	# Non-integer and prime-ish so it never visibly syncs with the pulse — which
	# only means anything if the period is the one that was tuned.
	var period_ticks := int(round(_t.cone_wobble_period * _ticks_per_second()))
	for tick: int in [0, 13, 47]:
		assert_almost_eq(
			CompassMath.wobble_radians(HUNTED, tick, _t),
			CompassMath.wobble_radians(HUNTED, tick + period_ticks, _t),
			0.01,
			"the drift did not repeat after one TUN-COMPASS-CONE-WOBBLE-PERIOD"
		)


func test_it_is_not_constant_within_a_hunt() -> void:
	# The counterfactual for the repeat test above: a wobble that returned the same
	# number forever would satisfy it perfectly, and would be a cone that does not
	# drift at all.
	var quarter := int(round(_t.cone_wobble_period * _ticks_per_second() * 0.25))
	assert_gt(quarter, 2, "a quarter period is under three ticks — this proves nothing")
	var spread: float = absf(
		CompassMath.wobble_radians(HUNTED, 0, _t) - CompassMath.wobble_radians(HUNTED, quarter, _t)
	)
	assert_gt(spread, deg_to_rad(_t.cone_wobble) * 0.5, "the cone does not actually drift")


func test_two_contracts_drift_out_of_step() -> void:
	# **SEEDED PER CONTRACT.** If adjacent peer ids produced adjacent phases, two
	# hunts would drift together and the drift would read as a property of the
	# world rather than of the hunt — which is the one thing that would make it
	# *un*learnable, by teaching the wrong lesson.
	var apart: float = absf(CompassMath.phase_of(HUNTED) - CompassMath.phase_of(OTHER))
	var folded: float = minf(apart, TAU - apart)
	gut.p("consecutive ids are %.2f rad apart in phase" % folded)
	assert_gt(folded, 0.5, "consecutive contract ids drift almost in step")


func test_the_phases_of_many_contracts_are_spread() -> void:
	# One pair could be luck. Sixty consecutive ids must not cluster.
	var buckets: Dictionary = {}
	for id: int in range(1000, 1060):
		buckets[int(CompassMath.phase_of(id) / TAU * 8.0)] = true
	assert_gte(
		buckets.size(), 6, "sixty contract phases fell into %d of 8 octants" % buckets.size()
	)


func test_the_shown_bearing_is_the_true_one_plus_the_drift() -> void:
	var here := Vector3.ZERO
	var there := Vector3(0.0, 0.0, 10.0)  # due +Z, which is yaw 0
	var truth := CompassMath.bearing_to(here, there)
	assert_almost_eq(truth, 0.0, 0.0001, "yaw 0 no longer faces +Z — check ProbeLayout.forward")
	for tick: int in [0, 5, 33, 200]:
		var shown := CompassMath.shown_bearing(here, there, HUNTED, tick, _t)
		var drift: float = CompassMath.angle_between(truth, shown)
		assert_almost_eq(
			drift,
			CompassMath.wobble_radians(HUNTED, tick, _t),
			0.0001,
			"the shown bearing is not the true bearing plus this tick's drift"
		)


func test_the_bearing_is_horizontal() -> void:
	# **GDD-03 §8.5 KEEPS ELEVATION OFF THIS CHANNEL ENTIRELY** — there is no z
	# component anywhere in the snapshot's compass block. A contract on a roof and
	# one in the street below must read identically.
	var here := Vector3.ZERO
	var street := Vector3(7.0, 0.0, 7.0)
	var roof := Vector3(7.0, VetraioLayout.ROOF_Y, 7.0)
	assert_eq(
		CompassMath.bearing_to(here, street),
		CompassMath.bearing_to(here, roof),
		"elevation changed the bearing"
	)
	assert_eq(
		CompassMath.distance_to(here, street),
		CompassMath.distance_to(here, roof),
		"elevation changed the distance, so the pulse would leak it"
	)


func test_the_bearing_folds_into_the_range_the_wire_expects() -> void:
	# `Quantise.yaw_to_u8` takes `[0, TAU)`. A negative angle would encode as a
	# plausible wrong direction rather than as an error.
	for at: Vector3 in [Vector3(-10, 0, 0), Vector3(0, 0, -10), Vector3(-10, 0, -10)]:
		var shown := CompassMath.shown_bearing(Vector3.ZERO, at, HUNTED, 17, _t)
		assert_gte(shown, 0.0, "a bearing came back negative")
		assert_lt(shown, TAU, "a bearing came back past a full turn")


func test_the_cone_is_wider_than_its_own_drift() -> void:
	# **THE CONE HAS TO CONTAIN THE LIE.** At `TUN-COMPASS-CONE-HALFWIDTH` 12° and
	# a 4° wobble, the true bearing is always inside the rendered arc — the drift
	# moves *which part* of the arc is honest, never puts the contract outside it.
	# Inverted, the Compass would point somewhere the contract demonstrably is not.
	assert_gt(
		_t.cone_halfwidth,
		_t.cone_wobble,
		"the wobble is wider than the cone — the arc can exclude the true bearing"
	)
