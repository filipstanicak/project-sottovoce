## **THE ARC COVERS GROUND, NOT DEGREES.** GDD-03 §8.4, UI_UX_SPEC §3.1,
## invariant 33.
##
## `TUN-COMPASS-CONE-HALFWIDTH` is the half-width **at maximum range** and
## `TUN-COMPASS-CONE-FULL-RADIUS` is where the arc becomes a **whole ring**; the
## curve between those two anchors is derived, so no third number can disagree
## with them. Inside the ring the instrument has stopped saying *which way* and
## says only *here, somewhere*.
##
## **A FIXED ANGLE WOULD CONTRADICT THE TUNABLE'S OWN DESCRIPTION.** TUNABLES §4
## says the cone tells you *"which part of the plaza, never which body"*. At a
## fixed 12° that sentence is true at 60 m, where the arc spans 25 m of ground,
## and false at the 2.85 m a kill lands from, where it spans **1.06 m** — narrower
## than two people standing side by side, so it picks one.
## `test_a_fixed_cone_would_point_at_one_body` is that sentence checked at the
## distance nobody checked it at.
extends GutTest

## Two agent radii — the ground a single body stands on. `VetraioLayout` owns it
## because the navmesh is eroded by it, so it is the game's own answer to "how
## wide is a person" rather than a number chosen here.
const BODY_WIDTH := VetraioLayout.NAV_AGENT_RADIUS * 2.0

var _t: CompassTuning


func before_each() -> void:
	_t = Tuning.compass


## Half the ground the arc covers at `metres`, in metres.
##
## **`INF` ONCE THE ARC REACHES A QUARTER TURN**, which is honest rather than
## defensive: past 90 degrees the arc includes directions behind the player and
## there is no lateral bound left to state. Written as `tan` alone it comes back
## through infinity and reads **zero** at a full ring — the widest reading the
## instrument has, reported as the narrowest.
func _reach(metres: float) -> float:
	var half := CompassMath.cone_halfwidth_for(metres, _t)
	if half >= 90.0:
		return INF
	return metres * tan(deg_to_rad(half))


func test_it_never_narrows_past_the_tunable() -> void:
	# Beyond maximum range the pulse is clamped and the arc must be too, or a
	# contract across the map would draw a needle — the one thing §3.1 forbids by
	# name.
	for metres: float in [_t.range_max, _t.range_max * 1.5, 120.0]:
		assert_gte(
			CompassMath.cone_halfwidth_for(metres, _t),
			_t.cone_halfwidth - 0.001,
			"the arc narrowed past the tunable at %.0f m" % metres
		)


func test_it_widens_every_step_of_the_way_in() -> void:
	# **THE PREMISE OF THE WHOLE FILE.** A law that returned a constant satisfies
	# the ground-patch assertion below at exactly one distance and this one never.
	var previous := 0.0
	var metres := _t.range_max
	while metres >= 1.0:
		var half := CompassMath.cone_halfwidth_for(metres, _t)
		assert_gte(
			half, previous, "the arc narrowed as the contract got closer, at %.1f m" % metres
		)
		previous = half
		metres -= 0.5
	assert_almost_eq(previous, 180.0, 0.001, "the arc never reached a full ring on the way in")


func test_it_hits_both_anchors_exactly() -> void:
	# **THE TWO ENDS ARE THE WHOLE SPECIFICATION.** The exponent between them is
	# computed to pass through both, so if either end is off the derivation is
	# broken rather than the value merely retuned.
	assert_almost_eq(
		CompassMath.cone_halfwidth_for(_t.range_max, _t),
		_t.cone_halfwidth,
		0.01,
		"the arc is not TUN-COMPASS-CONE-HALFWIDTH at TUN-COMPASS-RANGE-MAX"
	)
	assert_almost_eq(
		CompassMath.cone_halfwidth_for(CompassMath.full_ring_distance(_t), _t),
		180.0,
		0.01,
		"the arc is not a whole ring at TUN-COMPASS-CONE-FULL-RADIUS"
	)


func test_the_approach_is_flat_and_the_arrival_is_steep() -> void:
	# **THE SHAPE ASSERTION, AND THE ONE A WRONG EXPONENT SLIPS PAST WITHOUT.**
	# Every other test here is satisfied by any monotone curve through the two
	# anchors, including a straight line — which would be 96 degrees at half range
	# and would delete the directional reading over most of the approach.
	# `test_compass_curve.gd` makes the same argument about the pulse, and this is
	# GDD-03 §8.2's sentence said a second time in a second channel.
	var full := CompassMath.full_ring_distance(_t)
	var far := (
		CompassMath.cone_halfwidth_for(_t.range_max - 15.0, _t)
		- CompassMath.cone_halfwidth_for(_t.range_max, _t)
	)
	var near := (
		CompassMath.cone_halfwidth_for(full, _t) - CompassMath.cone_halfwidth_for(full + 15.0, _t)
	)
	gut.p("the arc opens %.1f deg over the first 15 m and %.1f over the last" % [far, near])
	assert_gt(far, 0.0, "the arc does not open at all over the first fifteen metres")
	assert_gt(near, far * 4.0, "the arc opens as fast far away as it does close in")


func test_the_ground_it_covers_never_shrinks_as_you_close() -> void:
	# **THE PROPERTY THE FIXED CONE VIOLATED, AND THE ONE A PLAYER EXPERIENCES.**
	# A fixed angle covers less and less ground the closer you get, until it covers
	# one person. This never does: the ambiguity at maximum range is the *floor*.
	var at_max := _reach(_t.range_max)
	assert_gt(at_max, 5.0, "the patch at maximum range is under five metres — this proves nothing")
	var metres := 0.5
	while metres <= _t.range_max:
		assert_gte(
			_reach(metres),
			at_max - 0.01,
			"the arc covers less ground at %.1f m than it does at maximum range" % metres
		)
		metres += 0.5


func test_it_always_covers_at_least_one_body() -> void:
	# **THE SENTENCE TUNABLES §4 MAKES, CHECKED EVERYWHERE RATHER THAN AT 30 m.**
	# An arc narrower than a person points at a person.
	var metres := 0.5
	while metres <= _t.range_max:
		assert_gt(
			_reach(metres) * 2.0,
			BODY_WIDTH,
			"the arc is narrower than one body at %.1f m — it names a body" % metres
		)
		metres += 0.5


func test_a_fixed_cone_would_point_at_one_body() -> void:
	# **THE COUNTERFACTUAL, AND THE REASON THIS FILE EXISTS.** The rule that
	# shipped in US-0072 was `TUN-COMPASS-CONE-HALFWIDTH` at every distance. It is
	# fine far away and it names a single body close in, which is what the lock
	# spends 1.6 s buying.
	var reach: float = Tuning.combat.kill_range + Tuning.combat.kill_validation_grace
	var fixed := 2.0 * reach * tan(deg_to_rad(_t.cone_halfwidth))
	gut.p("a fixed arc is %.2f m wide at the %.2f m a kill lands from" % [fixed, reach])
	assert_lt(
		fixed,
		BODY_WIDTH * 2.0,
		"a fixed cone at kill reach is no longer narrower than two people side by side"
	)
	assert_almost_eq(
		CompassMath.cone_halfwidth_for(3.0, _t),
		180.0,
		0.001,
		"the shipped law still points somewhere at 3 m, where a fixed cone names a body"
	)


func test_the_ring_closes_where_the_lock_starts_working() -> void:
	# **INVARIANT 33's FIRST CLAUSE, AND WHERE THE 20.0 m COMES FROM.** The arc
	# stops saying *which way* at exactly the range the lock begins to work, so a
	# player learns one boundary rather than two: outside it the instrument points,
	# inside it you look, and looking is what the lock is for. Derived rather than
	# chosen, which is why it is asserted rather than written down.
	assert_almost_eq(
		CompassMath.full_ring_distance(_t),
		_t.lock_range,
		0.001,
		"the ring radius is no longer TUN-COMPASS-LOCK-RANGE, so it is now a chosen number"
	)
	# The hand-off only means anything while there is something to hand over to.
	assert_lt(_t.lock_range, _t.range_max, "the lock reaches as far as the Compass does")


func test_the_ring_closes_before_a_kill_is_possible() -> void:
	# Invariant 33's second clause, asserted where a reader looks for it. Inside
	# kill reach the arc says only "here, somewhere" — never which of the bodies in
	# front of you.
	var closes := CompassMath.full_ring_distance(_t)
	var reach: float = Tuning.combat.kill_range + Tuning.combat.kill_validation_grace
	gut.p("the ring closes at %.2f m; the validated kill reach is %.2f m" % [closes, reach])
	assert_gt(closes, reach, "the Compass still points at a body you could stab")
	assert_almost_eq(
		CompassMath.cone_halfwidth_for(reach, _t), 180.0, 0.001, "the arc is not full at kill reach"
	)


func test_zero_distance_is_a_full_ring_rather_than_a_division() -> void:
	# Bucket 0 is a real reading — a hunter standing on top of their contract — so
	# this is reachable, and `anchored / 0.0` is `INF`.
	assert_eq(CompassMath.cone_halfwidth_for(0.0, _t), 180.0)
