## `ProbeResult` is what every traversal rule reads, so its cleared state has to
## mean "found nothing" rather than "found something at zero".
##
## The distinction is the whole file. `obstacle_top = 0.0` is a kerb you can step
## over; `obstacle_top = INF` is no obstacle at all — and the resolver's first
## comparison is `obstacle_top <= 1.1`, which **zero passes**. A result that
## cleared to zero would report a vault against empty air on every frame the
## casts all missed.
extends GutTest

var _probe: ProbeResult


func before_each() -> void:
	_probe = ProbeResult.new()


func test_a_fresh_result_is_not_valid() -> void:
	# "Nothing is known" and "nothing is there" are different claims, and the
	# resolver acts on the second. `TraversalProbes` sets this last, after every
	# cast has run.
	assert_false(_probe.valid, "an unprobed result claims to be a real reading")


func test_a_fresh_result_found_nothing() -> void:
	assert_false(_probe.has_hit)
	assert_false(_probe.chest_hit)
	assert_false(_probe.waist_hit)
	assert_false(_probe.ground_ahead)
	assert_false(_probe.clear_beyond)
	assert_false(_probe.surface_is_climbable)


func test_foot_clear_defaults_to_clear() -> void:
	# Inverted against the others deliberately: the resolver asks "is the way
	# ahead open", and a default of false would read as "blocked" on a pawn
	# standing in an empty street.
	assert_true(_probe.foot_clear, "an unprobed pawn is reported as blocked at foot height")


func test_the_heights_clear_to_infinity_and_not_to_zero() -> void:
	# THE POINT OF THE FILE. `obstacle_top <= TUN-TRAVERSE-VAULT-MAX-HEIGHT` is
	# the resolver's vault test, and 0.0 satisfies it.
	assert_eq(_probe.obstacle_top, INF, "a missed cast would resolve as a vaultable kerb")
	assert_eq(_probe.gap_distance, INF, "a missed cast would resolve as a zero-metre gap")
	assert_eq(_probe.surface_height, INF)
	assert_eq(_probe.drop_height, INF)


func test_clear_wipes_a_filled_result() -> void:
	# Called at the top of every refresh. A stale reading surviving into a frame
	# whose casts all missed is a vault into the wall you were at last frame.
	_probe.valid = true
	_probe.has_hit = true
	_probe.chest_hit = true
	_probe.waist_hit = true
	_probe.foot_clear = false
	_probe.ground_ahead = true
	_probe.clear_beyond = true
	_probe.surface_is_climbable = true
	_probe.obstacle_top = 0.9
	_probe.gap_distance = 2.0
	_probe.surface_height = 4.0
	_probe.drop_height = 3.0
	_probe.distance = 0.5
	_probe.height = 0.9
	_probe.normal = Vector3.FORWARD

	_probe.clear()

	assert_false(_probe.valid)
	assert_false(_probe.has_hit)
	assert_false(_probe.chest_hit)
	assert_false(_probe.waist_hit)
	assert_true(_probe.foot_clear)
	assert_false(_probe.ground_ahead)
	assert_false(_probe.clear_beyond)
	assert_false(_probe.surface_is_climbable)
	assert_eq(_probe.obstacle_top, INF)
	assert_eq(_probe.gap_distance, INF)
	assert_eq(_probe.surface_height, INF)
	assert_eq(_probe.drop_height, INF)
	assert_eq(_probe.distance, 0.0)
	assert_eq(_probe.height, 0.0)
	assert_eq(_probe.normal, Vector3.UP)


func test_an_unprobed_pawn_is_never_at_an_edge() -> void:
	# THE DEFAULT THAT MATTERS. A cleared result satisfies both halves of the edge
	# test — foot clear, no ground found — so without `valid` a pawn whose probes
	# had not run would resolve to a drop off a cliff that is not there.
	_probe.foot_clear = true
	_probe.ground_ahead = false
	assert_false(_probe.valid)
	assert_false(_probe.at_edge(), "an unprobed pawn is standing at an edge")


func test_at_edge_needs_both_a_clear_foot_and_no_ground() -> void:
	_probe.valid = true
	_probe.foot_clear = true
	_probe.ground_ahead = true
	assert_false(_probe.at_edge(), "ground ahead is not an edge")
	_probe.ground_ahead = false
	assert_true(_probe.at_edge())
	_probe.foot_clear = false
	assert_false(_probe.at_edge(), "something at foot height is a wall, not an edge")


func test_an_unfound_far_side_is_never_crossable() -> void:
	assert_false(
		_probe.gap_is_crossable(Tuning.movement.traverse_gap_max),
		"a gap nothing was found across reported as jumpable"
	)
	_probe.gap_distance = Tuning.movement.traverse_gap_max
	assert_true(_probe.gap_is_crossable(Tuning.movement.traverse_gap_max), "the limit is inclusive")
	_probe.gap_distance = Tuning.movement.traverse_gap_max + 0.1
	assert_false(_probe.gap_is_crossable(Tuning.movement.traverse_gap_max))


func test_the_context_owns_one_and_a_respawn_clears_it() -> void:
	# `PawnContext` reuses a single instance for the pawn's whole life. A probe
	# reading taken a tick before death must not survive into the new spawn.
	var ctx := PawnContext.new()
	assert_not_null(ctx.probe_result, "PawnContext has no ProbeResult")
	ctx.probe_result.waist_hit = true
	ctx.probe_result.obstacle_top = 0.9
	ctx.reset_for_spawn(Vector3.ZERO, 0.0)
	assert_false(ctx.probe_result.waist_hit, "a probe reading survived a respawn")
	assert_eq(ctx.probe_result.obstacle_top, INF)
