## Where the probes go. GDD-02 §7.1, TDD-06 §4.1.
##
## The geometry is the half of traversal that can be wrong in a way no playtest
## would ever name. A waist probe 10 cm high turns a wall that vaulted into one
## that mantles, and the only symptom is that the district feels subtly worse to
## move through — which is not a bug report anyone can act on.
##
## Pure arithmetic, no world, no scene. `TraversalProbes` casts these; this file
## asserts they point where the design says.
extends GutTest


func test_the_three_origins_are_the_tunables() -> void:
	# Chest, waist, foot. Asserted against the tunables rather than against 1.35,
	# 0.85 and 0.25, so retuning cannot leave this passing against the old layout.
	assert_eq(
		ProbeLayout.origin_height(ProbeLayout.Probe.CHEST), Tuning.movement.probe_height_chest
	)
	assert_eq(
		ProbeLayout.origin_height(ProbeLayout.Probe.WAIST), Tuning.movement.probe_height_waist
	)
	assert_eq(ProbeLayout.origin_height(ProbeLayout.Probe.FOOT), Tuning.movement.probe_height_foot)


func test_the_origins_are_the_documented_values() -> void:
	# The other direction: the tunables still hold what GDD-02 §7.1 draws. Both
	# assertions are needed — the one above catches a wrong field, this one
	# catches a right field holding a wrong number.
	assert_almost_eq(Tuning.movement.probe_height_chest, 1.35, 0.001)
	assert_almost_eq(Tuning.movement.probe_height_waist, 0.85, 0.001)
	assert_almost_eq(Tuning.movement.probe_height_foot, 0.25, 0.001)
	assert_almost_eq(Tuning.movement.probe_length, 0.9, 0.001)


func test_they_are_ordered_chest_above_waist_above_foot() -> void:
	# Not decoration. The resolver reads CHEST for climb and WAIST for vault, so
	# an inverted pair would make every low wall look like a façade.
	assert_gt(Tuning.movement.probe_height_chest, Tuning.movement.probe_height_waist)
	assert_gt(Tuning.movement.probe_height_waist, Tuning.movement.probe_height_foot)


func test_reach_is_longer_than_the_pawn_radius() -> void:
	# The capsule is 0.35 m. A probe that only fired on contact would resolve a
	# vault the frame after the player had already stopped against the wall —
	# which is exactly the timing error §7 exists to abolish.
	assert_gt(Tuning.movement.probe_length, 0.35, "probes do not reach past the pawn's own body")


func test_forward_is_positive_z_at_yaw_zero() -> void:
	# Must match `LocomotionState._is_backpedalling` and `InputCommand.move`, or
	# the probes look behind the pawn while the pawn walks forwards.
	var forward := ProbeLayout.forward(0.0)
	assert_almost_eq(forward.z, 1.0, 0.001)
	assert_almost_eq(forward.x, 0.0, 0.001)
	assert_almost_eq(forward.length(), 1.0, 0.001)


func test_a_quarter_turn_points_along_x() -> void:
	var forward := ProbeLayout.forward(PI / 2.0)
	assert_almost_eq(forward.x, 1.0, 0.001)
	assert_almost_eq(forward.z, 0.0, 0.001)


func test_a_probe_runs_horizontally_from_its_origin() -> void:
	var feet := Vector3(10.0, 3.0, -4.0)
	var from := ProbeLayout.origin(feet, ProbeLayout.Probe.WAIST)
	var to := ProbeLayout.target(feet, 0.0, ProbeLayout.Probe.WAIST)
	assert_almost_eq(from.y, feet.y + Tuning.movement.probe_height_waist, 0.001)
	assert_almost_eq(to.y, from.y, 0.001, "a forward probe drifted vertically")
	assert_almost_eq(from.distance_to(to), Tuning.movement.probe_length, 0.001)


func test_the_gap_march_starts_where_the_gdd_says_and_ends_at_the_jump_limit() -> void:
	var offsets := ProbeLayout.gap_offsets()
	assert_gt(offsets.size(), 1, "the gap probe does not march")
	assert_almost_eq(offsets[0], Tuning.movement.gap_probe_ahead, 0.001)
	assert_almost_eq(offsets[0], 0.6, 0.001, "GDD-02 §7.1 puts the first probe at 0.6 m")
	assert_true(
		offsets[offsets.size() - 1] >= Tuning.movement.traverse_gap_max - 0.001,
		"the march stops short of TUN-TRAVERSE-GAP-MAX, so the furthest jumpable gap is invisible"
	)


func test_the_march_never_overshoots_the_jump_limit_by_more_than_a_step() -> void:
	# Probing beyond the furthest jumpable gap costs raycasts to learn something
	# the resolver would reject anyway.
	var offsets := ProbeLayout.gap_offsets()
	var last: float = offsets[offsets.size() - 1]
	assert_true(
		last <= Tuning.movement.traverse_gap_max + Tuning.movement.gap_probe_step,
		"the gap march runs past the jump limit"
	)


func test_the_march_is_evenly_spaced_at_the_tunable() -> void:
	var offsets := ProbeLayout.gap_offsets()
	var wrong: PackedStringArray = []
	for i: int in range(1, offsets.size()):
		if absf(offsets[i] - offsets[i - 1] - Tuning.movement.gap_probe_step) > 0.001:
			wrong.append("%.2f -> %.2f" % [offsets[i - 1], offsets[i]])
	assert_eq(wrong.size(), 0, "uneven gap-probe spacing: " + ", ".join(wrong))


func test_a_zero_step_cannot_hang_the_march() -> void:
	# The step is range-limited in tuning, but a profile is data and data can be
	# wrong. An infinite `while` inside a physics frame is not a bug you debug —
	# it is a frozen game.
	assert_lt(ProbeLayout.gap_offsets().size(), 100, "the gap march produced an absurd number")


func test_the_gap_probe_starts_at_foot_height_and_looks_down() -> void:
	# Raised by the foot probe's height so a kerb does not read as solid ground.
	var feet := Vector3.ZERO
	var from := ProbeLayout.gap_origin(feet, 0.0, 1.0)
	assert_almost_eq(from.y, Tuning.movement.probe_height_foot, 0.001)
	assert_almost_eq(from.z, 1.0, 0.001)
	assert_almost_eq(ProbeLayout.gap_depth(), Tuning.movement.gap_probe_depth, 0.001)
	# **10.0 SINCE 2026-08-13, AND THE OLD 5.0 WAS THE BUG.** MAP-VETRAIO's façades
	# are 8.5 m, so a 5 m probe could not see the street from any roof: the drop
	# came back unmeasured and the planner substituted the probe depth, setting the
	# pawn down in mid-air. Invariant §17.24 ties the depth to
	# `TUN-TRAVERSE-CLIMB-MAX-HEIGHT` now — anything you can climb up, you can fall
	# down — which is a rule rather than a number somebody has to remember.
	assert_gte(
		ProbeLayout.gap_depth(),
		Tuning.movement.traverse_climb_max_height,
		"the probes cannot see the bottom of the tallest climb"
	)


func test_the_down_probe_reaches_past_a_safe_drop() -> void:
	# Resolving to a costly drop is a decision the player gets to make. Finding
	# nothing is the game declining to answer, which reads as a bug.
	assert_gt(Tuning.movement.gap_probe_depth, Tuning.movement.traverse_drop_safe_height)


func test_the_obstacle_top_casts_start_beyond_the_hit_and_above_a_mantle() -> void:
	# They must land on the obstacle's UPPER SURFACE, not on its near face — the
	# height they return is the vault/mantle decision.
	var origins := ProbeLayout.obstacle_top_origins(Vector3.ZERO, 0.0, 0.5)
	assert_gt(origins.size(), 1, "a single sample cannot measure a thin obstacle")
	for origin: Vector3 in origins:
		assert_gt(origin.z, 0.5, "a top cast is not past the hit")
		assert_almost_eq(origin.y, Tuning.movement.traverse_mantle_max_height, 0.001)


func test_the_nearest_top_sample_lands_inside_a_thin_obstacle() -> void:
	# **THE BUG THIS EXISTS FOR.** A single cast a full step past the face lands
	# BEYOND anything thinner than that — a fence, a railing, a stall edge — and
	# measures the floor behind it. The metrics bible constrains vaultable
	# geometry's height and says nothing about its thickness.
	var origins := ProbeLayout.obstacle_top_origins(Vector3.ZERO, 0.0, 0.5)
	var nearest: Vector3 = origins[0]
	assert_lt(
		nearest.z - 0.5,
		Tuning.movement.gap_probe_step,
		"the closest top sample is a full step out, so a thin obstacle is missed"
	)


func test_the_clear_beyond_cast_is_further_out_than_the_top_cast() -> void:
	# Landing ON the obstacle is a mantle. "Clear beyond" has to look past every
	# sample that could have measured its top.
	var origins := ProbeLayout.obstacle_top_origins(Vector3.ZERO, 0.0, 0.5)
	var furthest: Vector3 = origins[origins.size() - 1]
	var beyond := ProbeLayout.clear_beyond_origin(Vector3.ZERO, 0.0, 0.5)
	assert_gt(beyond.z, furthest.z, "the clear-beyond cast does not look past the obstacle")


func test_a_wall_is_climbable_and_a_floor_is_not() -> void:
	assert_true(ProbeLayout.is_climbable(Vector3.FORWARD), "a vertical façade is not climbable")
	assert_true(ProbeLayout.is_climbable(Vector3.RIGHT))
	assert_false(ProbeLayout.is_climbable(Vector3.UP), "a floor came back climbable")
	assert_false(ProbeLayout.is_climbable(Vector3.DOWN), "a ceiling came back climbable")


func test_a_shallow_ramp_is_not_climbable() -> void:
	# A player must never find themselves climbing a staircase. 30° off vertical
	# is the boundary; a 20°-from-horizontal ramp is well clear of it.
	var ramp := Vector3.UP.rotated(Vector3.RIGHT, deg_to_rad(20.0)).normalized()
	assert_false(ProbeLayout.is_climbable(ramp), "a 20 degree ramp reads as a climbable wall")
