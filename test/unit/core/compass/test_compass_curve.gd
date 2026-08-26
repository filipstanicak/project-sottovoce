## **EVERY ROW OF TUNABLES §4.2, TO A MILLISECOND.** US-0057, GDD-03 §8.2.
##
## The pulse curve is the single most carefully tuned number in the game, and the
## document commits to twelve sampled values. This file asserts all twelve rather
## than asserting the formula's *shape*, because a shape test passes on any
## monotone curve and the design argument is about the specific rates:
##
## > From 60 m to 20 m the rate creeps up about 8 % per 10 m — you can tell you
## > are getting closer, slowly. Inside 10 m, every step adds 15–25 %.
##
## **THE RECIPROCAL EXPONENT IS THE TRICK.** `pow(t, 1/2.2)` is flat far away and
## steep close in. Written as `pow(t, 2.2)` by mistake it is still monotone, still
## bounded by the same two tunables, and exactly backwards — a long tense approach
## followed by nothing. That mistake is what the sampled table catches and what a
## shape test would not.
extends GutTest

## `[distance_m, period_s]` — TUNABLES §4.2, transcribed.
const SAMPLED: Array = [
	[60.0, 0.900],
	[50.0, 0.840],
	[40.0, 0.774],
	[30.0, 0.697],
	[25.0, 0.654],
	[20.0, 0.605],
	[15.0, 0.549],
	[10.0, 0.482],
	[5.0, 0.392],
	[2.0, 0.310],
	[1.0, 0.267],
	[0.0, 0.150],
]

## US-0057's second criterion. The table is published to three decimals, so a
## millisecond is one unit in its last place.
const TOLERANCE := 0.001

var _t: CompassTuning


func before_each() -> void:
	_t = Tuning.compass


func test_the_shipped_tuning_is_the_one_the_table_was_computed_from() -> void:
	# **WITHOUT THIS, A RETUNE MAKES TWELVE ASSERTIONS FAIL AND SAY NOTHING.** The
	# table is a consequence of four numbers; if one of them moves, the table is
	# stale rather than the code being wrong, and the failure should say which.
	assert_almost_eq(_t.range_max, 60.0, 0.001, "TUN-COMPASS-RANGE-MAX moved — §4.2 is stale")
	assert_almost_eq(_t.pulse_min, 0.15, 0.001, "TUN-COMPASS-PULSE-MIN moved — §4.2 is stale")
	assert_almost_eq(_t.pulse_max, 0.90, 0.001, "TUN-COMPASS-PULSE-MAX moved — §4.2 is stale")
	assert_almost_eq(_t.pulse_exp, 2.2, 0.001, "TUN-COMPASS-PULSE-EXP moved — §4.2 is stale")


func test_every_sampled_distance_matches_the_published_period() -> void:
	var worst := 0.0
	for row: Array in SAMPLED:
		var period := CompassMath.period_for(float(row[0]), _t)
		worst = maxf(worst, absf(period - float(row[1])))
		assert_almost_eq(
			period,
			float(row[1]),
			TOLERANCE,
			"at %.0f m the curve gives %.4f s against §4.2's %.3f" % [row[0], period, row[1]]
		)
	gut.p("worst deviation from the published table: %.2f ms" % (worst * 1000.0))


func test_the_exponent_is_reciprocal_and_not_its_inverse() -> void:
	# **THE MISTAKE THIS CURVE IS MOST LIKELY TO SUFFER**, and it survives every
	# bound check: `pow(t, 2.2)` runs between the same two tunables and is monotone.
	# What separates them is where the *steepness* is — near, not far.
	var near_gradient: float = (
		(CompassMath.rate_for(0.0, _t) - CompassMath.rate_for(10.0, _t)) / 10.0
	)
	var far_gradient: float = (
		(CompassMath.rate_for(50.0, _t) - CompassMath.rate_for(60.0, _t)) / 10.0
	)
	gut.p(
		(
			"rate gradient: %.4f Hz/m near, %.4f Hz/m far — %.0fx steeper close in"
			% [near_gradient, far_gradient, near_gradient / maxf(far_gradient, 0.0001)]
		)
	)
	# The threshold is deliberately far below the measured 58x: this is a shape
	# guard, and an inverted exponent does not land near the line, it lands on the
	# other side of it.
	assert_gt(near_gradient, far_gradient * 4.0, "the curve is not steep close in — check 1/exp")


func test_the_design_claims_about_the_rate_hold() -> void:
	# GDD-03 §8.2's own sentences, asserted rather than admired. If a retune breaks
	# these, the prose is what needs rewriting — and this is where somebody finds out.
	var at_fifteen := CompassMath.rate_for(15.0, _t)
	var at_forty := CompassMath.rate_for(40.0, _t)
	var at_one := CompassMath.rate_for(1.0, _t)
	assert_almost_eq(at_fifteen / at_forty, 1.41, 0.02, "15 m is no longer 41 % faster than 40 m")
	assert_almost_eq(at_one / at_forty, 3.0, 0.1, "1 m is no longer triple 40 m")


func test_the_period_is_clamped_beyond_range_rather_than_extrapolated() -> void:
	# An ever-slowing pulse past `TUN-COMPASS-RANGE-MAX` would leak the difference
	# between 60 m and 110 m, which is most of the district. "Somewhere over there"
	# has to be one answer.
	var edge := CompassMath.period_for(_t.range_max, _t)
	for beyond: float in [_t.range_max + 0.5, _t.range_max * 2.0, 1000.0]:
		assert_eq(CompassMath.period_for(beyond, _t), edge, "the pulse kept slowing past the range")
	assert_almost_eq(edge, _t.pulse_max, 0.001, "the edge of range is not TUN-COMPASS-PULSE-MAX")


func test_a_negative_distance_cannot_produce_a_faster_pulse_than_zero() -> void:
	# Nothing should hand it one, and a squared distance subtracted the wrong way
	# would. The clamp is what makes that a dull bug rather than a division.
	assert_eq(
		CompassMath.period_for(-5.0, _t),
		CompassMath.period_for(0.0, _t),
		"a negative distance beat standing on top of the contract"
	)


func test_the_period_is_monotone_over_the_whole_range() -> void:
	# The curve's one structural promise: closer is never slower. Sampled every
	# 10 cm, because the sampled table only pins twelve points and a curve can do
	# something silly between two of them.
	var previous := CompassMath.period_for(0.0, _t)
	var steps := int(_t.range_max * 10.0)
	for step: int in range(1, steps + 1):
		var period := CompassMath.period_for(float(step) * 0.1, _t)
		assert_true(period >= previous, "the pulse got slower on approach at %.1f m" % (step * 0.1))
		previous = period
	assert_gt(steps, 100, "the sweep is too coarse to say anything")
