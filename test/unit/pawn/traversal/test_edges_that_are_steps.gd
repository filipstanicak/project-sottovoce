## What `INPUT-TRAVERSE` does at the lip of something. GDD-02 §7.2 cases 2 and 3.
##
## **BOTH OF THESE WERE FOUND AT THE CONTROLS, ON THE SAME PRESS.**
##
## Standing on a 0.9 m market stall and pressing traverse gap-jumped a metre —
## *"he makes a small jump of the edge and slows down"*. It was case 2 doing
## exactly what it says, and the slowdown was not a punishment: every traversal
## is a planned interpolation, so it discards the pawn's momentum for a fixed
## arc. Paying that to cross one metre off a lip you could have walked off is a
## worse trade than walking.
##
## And standing on an 8.5 m roof, the probes could not see the street:
## `TUN-TRAVERSE-GAP-PROBE-DEPTH` was 5.0. `drop_height` came back `INF`, the
## planner substituted the probe depth for the missing number, and the pawn was
## set down in mid-air five metres below and left to gravity for the rest —
## *"i climb down instead of jumping or just falling down"*.
##
## The assertions are on the CASE rather than on the resulting position, because
## the case is the decision. A test that only checked "the pawn ended up lower"
## is true of every one of these, including both bugs.
extends GutTest

var _ctx: PawnContext


func before_each() -> void:
	_ctx = PawnContext.new()
	_ctx.position = Vector3(10.0, 4.0, 10.0)
	_ctx.grounded = true


## A probe result standing at an edge, with the landing `drop` below and `gap`
## metres out. Everything else is the "nothing else is there" case.
func _at_edge(drop: float, gap: float) -> ProbeResult:
	var probe := ProbeResult.new()
	probe.valid = true
	probe.ground_ahead = false
	probe.drop_height = drop
	probe.gap_distance = gap
	_ctx.probe_result = probe
	return probe


func _classify(drop: float, gap: float) -> int:
	_at_edge(drop, gap)
	return TraversalResolver.classify(_ctx)


func _adjacent() -> float:
	return Tuning.movement.gap_probe_ahead + Tuning.movement.gap_probe_step


# ------------------------------------------------------------- it is a step --


func test_a_market_stall_lip_is_a_step_and_not_a_jump() -> void:
	# The reported case, in its own numbers: 0.9 m down, street 1.0 m out.
	assert_eq(_classify(0.9, 1.0), TraversalResolver.Case.NONE, "a stall lip still gap-jumped")


func test_the_step_threshold_is_the_tunable_and_not_a_literal() -> void:
	var just_under := Tuning.movement.drop_min_height - 0.05
	var just_over := Tuning.movement.drop_min_height + 0.05
	assert_eq(_classify(just_under, _adjacent()), TraversalResolver.Case.NONE, "not a step")
	assert_ne(_classify(just_over, _adjacent()), TraversalResolver.Case.NONE, "swallowed a drop")


# ---------------------------------------------------- and these are not steps --


func test_a_real_gap_still_jumps() -> void:
	# **THE ASSERTION THE HEIGHT RULE ALONE WOULD HAVE BROKEN.** A gap's far side
	# is level, so its drop is near zero — the same "low" as a stall lip. What
	# makes it a gap is that the ground does not resume next to your feet.
	assert_eq(
		_classify(0.05, Tuning.movement.traverse_gap_max - 0.2),
		TraversalResolver.Case.GAP_JUMP,
		"a crossable gap stopped being a gap jump"
	)


func test_a_short_fall_onto_a_nearby_ledge_is_not_a_step() -> void:
	# The other half: the distance rule alone would have swallowed this. Adjacent,
	# but far enough down to be worth resolving. §7.2 case 2 keys on the gap, so a
	# landing this close and this shallow is a gap jump — what matters here is
	# that it is not silence.
	assert_ne(
		_classify(Tuning.movement.drop_min_height + 1.0, _adjacent()),
		TraversalResolver.Case.NONE,
		"a real drop was dismissed as a step"
	)


func test_a_roof_edge_is_a_drop_and_not_a_gap_jump() -> void:
	# **THE REGRESSION THE DEEPER PROBE WOULD HAVE CAUSED.** From a roof the
	# street is directly below and therefore horizontally *near*, so case 2's
	# gap test passes on it. Once the probes could see 10 m instead of 5, every
	# roof lip would have classified as a crossable gap without this guard.
	assert_eq(
		_classify(8.5, Tuning.movement.gap_probe_ahead),
		TraversalResolver.Case.DROP,
		"a roof edge read as a gap to jump"
	)


func test_a_long_fall_with_nothing_found_is_still_a_drop() -> void:
	# §7.2 case 3 as written: no landing within range resolves to Drop. An
	# unmeasured drop is a poor thing to *plan* — see the note on `_finite` — but
	# the case is not in doubt.
	assert_eq(_classify(INF, INF), TraversalResolver.Case.DROP, "a roof drop is not a drop")


# ------------------------------------------------ and this one is a refusal --


func test_the_probes_can_see_the_bottom_of_the_tallest_climb() -> void:
	# Invariant §17.24, asserted here as well because it is the reason the case
	# above is now rare rather than routine: anything you can climb up, you can
	# fall down, and MAP-VETRAIO's façades are 8.5 m.
	assert_gte(
		Tuning.movement.gap_probe_depth,
		Tuning.movement.traverse_climb_max_height,
		"the probes cannot measure a fall down the tallest thing you can climb"
	)
