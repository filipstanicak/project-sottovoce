## **THE MOST IMPORTANT GEOMETRIC RELATIONSHIP IN THE GAME.** GDD-03 §10.2,
## TUNABLES invariant §17.6, US-0061.
##
## *A hunter who has closed to kill range has already entered stun range.*
## Recklessness is punished by geometry before it is punished by scoring, and
## never-do #13 forbids trading it away.
##
## **THIS FILE DOES NOT COMPARE TWO TUNABLES**, because that comparison is already
## `TuningInvariants`' job and passes just as happily against a `StunRules` that
## reads the wrong field. It sweeps the two *rules* against each other over the
## whole band, which is the property a player actually experiences.
extends GutTest

var _t: CombatTuning


func before_each() -> void:
	_t = Tuning.combat


## The distance at which each rule stops answering true, found by sweeping in
## centimetres. Both are three-dimensional, so the sweep runs along +Z.
func _kill_reach(a: Vector3, b: Vector3) -> bool:
	return KillRules.in_reach(a, b, _t)


func _stun_reach(a: Vector3, b: Vector3) -> bool:
	return StunRules.in_reach(a, b, _t)


func _limit_of(rule: Callable) -> float:
	var last := 0.0
	for step: int in range(0, 800):
		var metres := float(step) * 0.01
		if not rule.call(Vector3.ZERO, Vector3(0.0, 0.0, metres)):
			break
		last = metres
	return last


func test_no_distance_kills_you_that_you_could_not_have_stunned_from() -> void:
	# The claim, stated as a sweep rather than as a subtraction. Every centimetre
	# from contact to the kill's own limit must also be inside stun range.
	var kill_limit := _limit_of(_kill_reach)
	var breaches: Array = []
	for step: int in range(0, int(kill_limit * 100.0) + 1):
		var metres := float(step) * 0.01
		var at := Vector3(0.0, 0.0, metres)
		if not StunRules.in_reach(Vector3.ZERO, at, _t):
			breaches.append(metres)
	assert_eq(
		breaches.size(),
		0,
		(
			"a hunter can kill from %d distances that are outside stun range — " % breaches.size()
			+ "GDD-03 §10.2's first number, and never-do #13"
		)
	)
	assert_gt(kill_limit, 0.0, "the kill rule refuses every distance; this sweep proves nothing")


func test_the_stun_reaches_strictly_further_and_the_margin_is_reported() -> void:
	var kill_limit := _limit_of(_kill_reach)
	var stun_limit := _limit_of(_stun_reach)
	gut.p(
		(
			"kill reach %.2f m, stun reach %.2f m, margin %.2f m"
			% [kill_limit, stun_limit, stun_limit - kill_limit]
		)
	)
	assert_gt(stun_limit, kill_limit, "the stun no longer out-reaches the kill")


func test_the_band_between_them_is_where_the_counterplay_lives() -> void:
	# **THE PREY'S WINDOW, MEASURED.** ADR-0013 moved the counterplay out of the
	# last instant and into the approach, so the one thing that still protects a
	# prey is that they can reach a hunter who cannot yet reach them. If this band
	# were empty the stun would only ever be usable at the moment it is already
	# too late.
	# **AND THE BAND IS BETWEEN THE REACHES, NOT BETWEEN THE PUBLISHED RANGES.**
	# The midpoint of 2.5 and 3.0 is 2.75, which is *inside* the kill's reach of
	# 2.85 once `TUN-KILL-VALIDATION-GRACE` is added — so the band a player
	# actually experiences is 2.85 to 3.35 rather than GDD-03 §10.1's 2.5 to 3.0.
	# **Its width is identical**, 0.50 m, and that is only true because the two
	# rules share one grace. This assertion is what would go red if they stopped.
	var midpoint := (KillRules.reach(_t) + StunRules.reach(_t)) * 0.5
	var at := Vector3(0.0, 0.0, midpoint)
	assert_true(StunRules.in_reach(Vector3.ZERO, at, _t), "%.2f m is outside stun reach" % midpoint)
	assert_false(KillRules.in_reach(Vector3.ZERO, at, _t), "%.2f m is inside kill reach" % midpoint)
	assert_almost_eq(
		StunRules.reach(_t) - KillRules.reach(_t),
		_t.stun_range - _t.kill_range,
		0.0001,
		"the validated band is a different width from the published one"
	)


func test_both_graces_are_the_same_number() -> void:
	# `StunRules.reach` deliberately shares `TUN-KILL-VALIDATION-GRACE` rather than
	# claiming its own. A second tunable for the same physical error is one that
	# gets retuned alone — and the day it drifted below the kill's, the range
	# advantage above would quietly narrow with nothing failing.
	assert_almost_eq(
		StunRules.reach(_t) - _t.stun_range,
		KillRules.reach(_t) - _t.kill_range,
		0.0001,
		"the stun and the kill absorb different amounts of network error"
	)


func test_the_stun_cone_is_the_wider_of_the_two() -> void:
	# GDD-03 §10.1: 120° against the kill's 60°, because the hunter is aiming and
	# the prey is spinning. Asserted as a relationship rather than as two numbers.
	assert_gt(
		_t.stun_facing_cone,
		_t.kill_facing_cone,
		"the prey's cone is no wider than the hunter's — they are the one turning in panic"
	)
	var behind_the_kill := deg_to_rad(_t.kill_facing_cone) * 0.5 + 0.05
	var at := Vector3(sin(behind_the_kill), 0.0, cos(behind_the_kill)) * 2.0
	assert_true(StunRules.within_cone(Vector3.ZERO, 0.0, at, _t), "the wider cone does not reach")
	assert_false(KillRules.within_cone(Vector3.ZERO, 0.0, at, _t), "the narrow cone is not narrow")


func test_the_reach_is_three_dimensional() -> void:
	# The strata are 3.5 m apart. A horizontal test would let a player on the
	# street stun one standing on the roof directly above them, which is the same
	# mistake `KillRules` refuses for the same reason.
	var overhead := Vector3(0.0, 3.5, 0.0)
	assert_false(
		StunRules.in_reach(Vector3.ZERO, overhead, _t),
		"a player 3.5 m overhead is stunnable — the reach is horizontal"
	)
