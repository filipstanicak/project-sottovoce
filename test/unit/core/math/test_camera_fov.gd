## The lens arithmetic. GDD-02 §4.2, US-0022.
##
## **THE FOV IS A WARNING, AND A WARNING IS A CONTRACT.** It must arrive at a
## known rate, in the right direction, and mean one thing. The tests below are
## the three halves of that: the ladder's shape, the blend's speed, and what
## motion-reduction replaces both with.
##
## Values are asserted against `Tuning` AND against the literal from the design
## document. Against `Tuning` alone, a table-wide edit would move the ladder and
## every test would follow it; against the literal alone, the tunable could be
## bypassed entirely. Both, and a change has to be deliberate in two places.
extends GutTest

# -------------------------------------------------------------- the ladder --


func test_the_ladder_is_the_documented_five_rungs() -> void:
	assert_almost_eq(Tuning.camera.fov_blend, 55.0, 0.001)
	assert_almost_eq(Tuning.camera.fov_stroll, 60.0, 0.001)
	assert_almost_eq(Tuning.camera.fov_jog, 65.0, 0.001)
	assert_almost_eq(Tuning.camera.fov_run, 69.0, 0.001)
	assert_almost_eq(Tuning.camera.fov_sprint, 72.0, 0.001)


func test_it_widens_with_speed() -> void:
	# **INVARIANT 21.** Inverted, the lens would still be a channel — it would
	# simply tell a sprinting player they were calm, which is worse than silence.
	var rungs: Array[float] = [
		Tuning.camera.fov_blend,
		Tuning.camera.fov_stroll,
		Tuning.camera.fov_jog,
		Tuning.camera.fov_run,
		Tuning.camera.fov_sprint,
	]
	for i: int in range(rungs.size() - 1):
		assert_lt(rungs[i], rungs[i + 1], "the FOV ladder is not monotonic at rung %d" % i)


func test_slowing_down_buys_a_narrower_lens_than_the_default() -> void:
	# The half that is easy to forget. Blend-walk compresses the scene and makes
	# distant faces larger — slowing down literally lets you see more clearly.
	assert_lt(Tuning.camera.fov_blend, Tuning.camera.fov_stroll, "blend-walk did not narrow")


func test_the_default_lens_is_the_civilian_one() -> void:
	assert_almost_eq(CameraFov.default_fov(), Tuning.camera.fov_stroll, 0.001)


# --------------------------------------------------------------- the blend --


func test_it_moves_at_exactly_the_tuned_rate() -> void:
	# Measured over a tenth of a second across the real span, blend-walk to
	# sprint, so the clamp at the far end is not what is being asserted. A whole
	# second would arrive long before it, and the test would silently be
	# measuring 17° of ladder rather than 90°/s of rate.
	var moved := CameraFov.step(Tuning.camera.fov_blend, Tuning.camera.fov_sprint, 0.1)
	assert_almost_eq(moved - Tuning.camera.fov_blend, Tuning.camera.fov_blend_rate * 0.1, 0.001)
	assert_almost_eq(Tuning.camera.fov_blend_rate, 90.0, 0.001)


func test_narrowing_and_widening_cost_the_same() -> void:
	# One rate, both directions. A lens that closed faster than it opened would
	# make the warning arrive later than the reassurance, and a player learns to
	# distrust a channel that lags in one direction only.
	var up := CameraFov.step(60.0, 72.0, 0.05) - 60.0
	var down := 60.0 - CameraFov.step(60.0, 55.0, 0.05)
	assert_almost_eq(up, down, 0.001)


func test_it_never_overshoots_its_target() -> void:
	assert_almost_eq(CameraFov.step(60.0, 65.0, 10.0), 65.0, 0.001, "the lens shot past the rung")
	assert_almost_eq(CameraFov.step(72.0, 55.0, 10.0), 55.0, 0.001)


func test_it_arrives_and_then_stays() -> void:
	assert_almost_eq(CameraFov.step(65.0, 65.0, 0.05), 65.0, 0.001)


func test_a_zero_or_negative_delta_moves_nothing() -> void:
	# `_process` can be handed a zero delta on the first frame after a load, and a
	# negative one is what a clamped-to-zero subtraction produces. Neither may
	# drag the lens backwards.
	assert_almost_eq(CameraFov.step(60.0, 72.0, 0.0), 60.0, 0.001)
	assert_almost_eq(CameraFov.step(60.0, 72.0, -1.0), 60.0, 0.001)


func test_the_whole_ladder_is_crossed_in_a_fifth_of_a_second() -> void:
	# 17° at 90°/s. This is the number that makes the rate meaningful: the sweep
	# has to outrun the acceleration ramp it is reporting on, or the lens would
	# still be widening after the player had already stopped.
	assert_almost_eq(CameraFov.full_sweep_seconds(), 0.19, 0.01)
	assert_lt(
		CameraFov.full_sweep_seconds(),
		Tuning.movement.sprint / Tuning.movement.accel,
		"the lens is slower than the acceleration it is meant to be reporting"
	)


# ----------------------------------------------------- motion reduction --


func test_motion_reduction_locks_the_lens_wherever_the_pawn_is() -> void:
	# GDD-02 §9.4. Every rung returns the same number: the mode REPLACES the
	# ladder rather than damping it, because a slower blend still sweeps the same
	# 17° and the sweep is the part that makes people ill.
	for rung: float in [55.0, 60.0, 65.0, 69.0, 72.0]:
		assert_almost_eq(CameraFov.wanted(rung, true), Tuning.camera.fov_motion_reduced, 0.001)
	assert_almost_eq(Tuning.camera.fov_motion_reduced, 62.0, 0.001)


func test_with_the_mode_off_the_rung_passes_straight_through() -> void:
	for rung: float in [55.0, 60.0, 65.0, 69.0, 72.0]:
		assert_almost_eq(CameraFov.wanted(rung, false), rung, 0.001)


func test_the_locked_value_sits_inside_the_ladder_it_replaces() -> void:
	# **INVARIANT 22.** Outside the span, the mode would frame every speed
	# unusually — a second cost on top of the warning channel it already gives up.
	assert_gte(Tuning.camera.fov_motion_reduced, Tuning.camera.fov_blend)
	assert_lte(Tuning.camera.fov_motion_reduced, Tuning.camera.fov_sprint)
