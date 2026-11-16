## **A FIGURE'S GAIT IS THE SPEC'S, AND IT IS A PERSON'S.** ANIMATION_SPEC §2.2, US-0109.
##
## There is no clip to check a duration on, so the stride cycle is checked where
## it now lives: in arithmetic. 1.15 s at blend-walk is load-bearing twice over —
## it is what a clone walks at, and `TUN-COMPASS-LOCK-FILL-TIME` is deliberately
## longer than it.
extends GutTest


func _gait(phase: float, stride: float = 1.0, run: float = 0.0) -> FigurePose:
	var pose := FigurePose.new()
	FigureMotion.gait(pose, phase, stride, run)
	return pose


func test_the_stride_cycle_is_the_specs_at_each_rung() -> void:
	var m := Tuning.movement
	assert_almost_eq(FigureMotion.cycle_seconds(m.blend_walk), 1.15, 0.001, "ANIM-BLENDWALK-LOOP")
	assert_almost_eq(FigureMotion.cycle_seconds(m.stroll), 0.78, 0.001, "ANIM-STROLL-LOOP")
	assert_almost_eq(FigureMotion.cycle_seconds(m.run), 0.54, 0.001, "ANIM-RUN-LOOP")
	assert_almost_eq(FigureMotion.cycle_seconds(m.sprint), 0.44, 0.001, "ANIM-SPRINT-LOOP")


func test_the_lock_takes_longer_than_one_stride() -> void:
	# GDD-03 §8.4: a lock cannot complete through the gaps in a walking group.
	assert_gt(Tuning.compass.lock_fill_time, FigureMotion.CYCLE_BLEND_WALK)


func test_a_slower_walk_keeps_the_blend_walk_cycle() -> void:
	assert_almost_eq(FigureMotion.cycle_seconds(0.4), 1.15, 0.001)


func test_the_cycle_never_snaps_between_rungs() -> void:
	var before := FigureMotion.cycle_seconds(0.0)
	var speed := 0.05
	while speed < 8.0:
		var now := FigureMotion.cycle_seconds(speed)
		assert_lte(now, before + 0.0001, "the cycle lengthened at %.2f m/s" % speed)
		assert_lt(before - now, 0.03, "the cycle jumped at %.2f m/s" % speed)
		before = now
		speed += 0.05


func test_a_cycle_covers_the_ground_the_figure_covers() -> void:
	var walk: float = Tuning.movement.blend_walk
	assert_almost_eq(FigureMotion.cycle_metres(walk), walk * 1.15, 0.001)


func test_haste_runs_from_a_stroll_to_a_sprint() -> void:
	var m := Tuning.movement
	assert_eq(FigureMotion.haste(m.blend_walk), 0.0)
	assert_eq(FigureMotion.haste(m.stroll), 0.0)
	assert_eq(FigureMotion.haste(m.sprint), 1.0)
	assert_between(FigureMotion.haste(m.run), 0.2, 0.8)


func test_the_legs_are_half_a_cycle_apart() -> void:
	for step: int in 16:
		var phase := TAU * float(step) / 16.0
		assert_almost_eq(
			_gait(phase).at(FigurePose.HIP_L), _gait(phase + PI).at(FigurePose.HIP_R), 0.0001
		)
		assert_almost_eq(
			_gait(phase).at(FigurePose.KNEE_L), _gait(phase + PI).at(FigurePose.KNEE_R), 0.0001
		)


func test_each_arm_swings_against_its_own_leg() -> void:
	var pose := _gait(PI * 0.5)
	assert_gt(pose.at(FigurePose.HIP_L), 0.3, "the left leg is not forward at a quarter cycle")
	assert_lt(pose.at(FigurePose.SHOULDER_L), -0.2, "the left arm went with the left leg")
	assert_lt(pose.at(FigurePose.HIP_R), -0.3)
	assert_gt(pose.at(FigurePose.SHOULDER_R), 0.2)


func test_a_knee_never_bends_backwards() -> void:
	for step: int in 32:
		var pose := _gait(TAU * float(step) / 32.0, 1.0, float(step % 2))
		assert_gte(pose.at(FigurePose.KNEE_L), 0.0)
		assert_gte(pose.at(FigurePose.KNEE_R), 0.0)
		assert_gte(pose.at(FigurePose.ELBOW_L), 0.0)


func test_a_run_reaches_further_than_a_walk() -> void:
	var walk := _gait(PI * 0.5, 1.0, 0.0)
	var run := _gait(PI * 0.5, 1.0, 1.0)
	assert_gt(run.at(FigurePose.HIP_L), walk.at(FigurePose.HIP_L) + 0.2)
	assert_gt(run.at(FigurePose.SPINE_PITCH), walk.at(FigurePose.SPINE_PITCH) + 0.1)
	assert_gt(run.at(FigurePose.ELBOW_L), 1.0, "a runner's arms are bent")


func test_no_stride_swings_no_leg() -> void:
	var pose := _gait(PI * 0.5, 0.0)
	assert_almost_eq(pose.at(FigurePose.HIP_L), 0.0, 0.0001)
	assert_almost_eq(pose.at(FigurePose.KNEE_L), 0.0, 0.0001)
	assert_almost_eq(pose.at(FigurePose.SHOULDER_L), 0.0, 0.0001)


func test_standing_is_small_and_never_frozen() -> void:
	var seen: Dictionary = {}
	for step: int in 40:
		var pose := FigurePose.new()
		FigureMotion.idle(pose, float(step) * 0.7, 1.3)
		seen[snappedf(pose.at(FigurePose.HIPS_X), 0.001)] = true
		for i: int in FigurePose.COUNT:
			assert_lt(absf(pose.at(i)), 0.6, "joint %d swings wide in a figure standing still" % i)
		assert_almost_eq(pose.at(FigurePose.HIP_L), 0.0, 0.0001, "a standing figure is stepping")
	assert_gt(seen.size(), 10, "a standing figure does not shift its weight")


func test_two_figures_do_not_stand_in_step() -> void:
	var one := FigurePose.new()
	var other := FigurePose.new()
	FigureMotion.idle(one, 5.0, 0.0)
	FigureMotion.idle(other, 5.0, 2.4)
	assert_ne(one.at(FigurePose.HIPS_X), other.at(FigurePose.HIPS_X))
	assert_ne(one.at(FigurePose.HEAD_YAW), other.at(FigurePose.HEAD_YAW))


func test_sitting_lowers_the_hips_levels_the_thighs_and_hangs_the_shins() -> void:
	var pose := FigurePose.new()
	FigureMotion.sit(pose, 0.38, 0.65)
	assert_almost_eq(pose.at(FigurePose.HIPS_Y), -0.38, 0.0001)
	assert_almost_eq(pose.at(FigurePose.ROOT_Z), -0.65, 0.0001, "the seat is behind the figure")
	for side: int in 2:
		assert_almost_eq(pose.at(FigurePose.HIP_L + side), PI * 0.5, 0.12, "a thigh is not level")
		# Thigh forward and shin back by the same angle: the shin hangs straight down.
		assert_almost_eq(
			pose.at(FigurePose.KNEE_L + side), pose.at(FigurePose.HIP_L + side), 0.0001
		)


func test_leaning_bends_at_the_waist_and_puts_the_forearms_down() -> void:
	var pose := FigurePose.new()
	FigureMotion.lean(pose)
	assert_gt(pose.at(FigurePose.SPINE_PITCH), 0.3)
	assert_almost_eq(pose.at(FigurePose.HIPS_Y), 0.0, 0.0001, "a leaning figure is still standing")
	for side: int in 2:
		assert_gt(pose.at(FigurePose.ELBOW_L + side), 1.0)


func test_a_pose_eases_toward_another_without_overshoot() -> void:
	var from := FigurePose.new()
	var to := FigurePose.new()
	to.put(FigurePose.HIP_L, 1.0)
	from.ease_toward(to, 0.25)
	assert_almost_eq(from.at(FigurePose.HIP_L), 0.25, 0.0001)
	from.ease_toward(to, 1.0)
	assert_almost_eq(from.at(FigurePose.HIP_L), 1.0, 0.0001)
