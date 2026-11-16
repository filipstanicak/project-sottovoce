## **A FIGURE MOVES BY HOW ITS BODY MOVES, WHERE IT STANDS AND WHAT IT DOES.** US-0109.
extends GutTest

const DT := 1.0 / 60.0
const FORWARD := Vector3(0.0, 0.0, 1.0)
const SEAT: Array = [FigureMotion.Posture.SIT, 0.0, 0.65]

var _animator: FigureAnimator
var _shape: FigureShape


func before_each() -> void:
	_animator = FigureAnimator.new()
	_shape = FigureShape.of(Ids.PERSONA_VETRAIO, 1.8)


## Advance `seconds` at `velocity`; the pose it ends in.
func _run(seconds: float, velocity: Vector3, place: Array = []) -> FigurePose:
	var pose: FigurePose = null
	for _i: int in int(round(seconds / DT)):
		pose = _animator.advance(DT, velocity, FORWARD, _shape, place)
	return pose


## The highest and lowest `joint` reached over `seconds` at `velocity`.
func _swing(joint: int, seconds: float, velocity: Vector3) -> Vector2:
	var low := INF
	var high := -INF
	for _i: int in int(round(seconds / DT)):
		var value := _animator.advance(DT, velocity, FORWARD, _shape, []).at(joint)
		low = minf(low, value)
		high = maxf(high, value)
	return Vector2(low, high)


func _walk() -> Vector3:
	return FORWARD * Tuning.movement.blend_walk


func test_a_still_figure_does_not_step() -> void:
	var swing := _swing(FigurePose.HIP_L, 2.0, Vector3.ZERO)
	assert_lt(swing.y - swing.x, 0.02, "a standing figure is walking on the spot")


func test_a_walking_figure_swings_its_legs() -> void:
	_run(0.5, _walk())
	var swing := _swing(FigurePose.HIP_L, 1.5, _walk())
	assert_gt(swing.y - swing.x, 0.5)


func test_ten_strides_take_the_specs_eleven_and_a_half_seconds() -> void:
	# The stride follows the ground: 1.15 s a cycle at blend-walk, eased or not.
	_run(1.0, _walk())
	var cycles := 0
	var before := 0.0
	for _i: int in int(round(11.5 / DT)):
		var now := _animator.advance(DT, _walk(), FORWARD, _shape, []).at(FigurePose.HIP_L)
		if before <= 0.0 and now > 0.0:
			cycles += 1
		before = now
	assert_almost_eq(cycles, 10, 1)


func test_walking_backwards_runs_the_stride_backwards() -> void:
	var ahead := _run(0.25, _walk()).at(FigurePose.HIP_L)
	_animator = FigureAnimator.new()
	var back := _run(0.25, -_walk()).at(FigurePose.HIP_L)
	assert_gt(ahead, 0.05, "the left leg did not lead off")
	assert_lt(back, -0.05, "a figure walking backwards stepped forwards")


func test_a_figure_sits_only_once_it_has_stood_there() -> void:
	var early := _run(FigureAnimator.SETTLE * 0.5, Vector3.ZERO, SEAT)
	assert_gt(early.at(FigurePose.HIPS_Y), -0.02, "it sat the moment it stopped")
	assert_false(_animator.is_settled())
	var sat := _run(1.5, Vector3.ZERO, SEAT)
	assert_true(_animator.is_settled())
	assert_almost_eq(sat.at(FigurePose.HIPS_Y), -(_shape.hip_y() - FigurePlaces.SEAT_HEIGHT), 0.02)


func test_a_figure_walking_past_a_seat_does_not_sit() -> void:
	var pose := _run(2.0, _walk(), SEAT)
	assert_gt(pose.at(FigurePose.HIPS_Y), -0.1)
	assert_false(_animator.is_settled())


func test_a_seated_figure_stands_the_moment_it_moves() -> void:
	_run(1.5, Vector3.ZERO, SEAT)
	_run(DT * 3.0, _walk(), SEAT)
	assert_false(_animator.is_settled())


func test_an_act_is_shown_over_the_walk() -> void:
	_animator.set_act(FigureMotion.Act.REEL)
	var pose := _run(0.6, _walk())
	assert_gt(pose.at(FigurePose.SPINE_PITCH), 0.5, "a stunned figure is upright")


func test_a_figure_that_is_acting_takes_no_seat() -> void:
	_animator.set_act(FigureMotion.Act.FALL)
	var pose := _run(2.0, Vector3.ZERO, SEAT)
	assert_false(_animator.is_settled())
	assert_almost_eq(pose.at(FigurePose.ROOT_PITCH), -PI * 0.5, 0.05, "a dead figure is not lying")
	assert_almost_eq(pose.at(FigurePose.ROOT_Z), 0.0, 0.01, "a dead figure was put on the bench")


func test_a_pose_is_eased_into_and_never_snapped() -> void:
	_animator.set_act(FigureMotion.Act.FALL)
	var pose := _run(DT, Vector3.ZERO)
	assert_lt(absf(pose.at(FigurePose.ROOT_PITCH)), 0.3, "the figure was on its back in one frame")


func test_the_same_act_again_does_not_start_it_again() -> void:
	_animator.set_act(FigureMotion.Act.STRIKE)
	_run(FigureActs.STRIKE_SECONDS, Vector3.ZERO)
	_animator.set_act(FigureMotion.Act.STRIKE)
	var pose := _run(0.3, Vector3.ZERO)
	assert_gt(pose.at(FigurePose.SHOULDER_R), 1.0, "the arm was drawn back a second time")


func test_an_arm_that_carries_does_not_swing() -> void:
	# The Lucerna's pole is in the right hand, on the player and on every clone.
	_shape = FigureShape.of(Ids.PERSONA_LUCERNA, 1.8)
	_run(0.5, _walk())
	var right := _swing(FigurePose.SHOULDER_R, 1.5, _walk())
	var left := _swing(FigurePose.SHOULDER_L, 1.5, _walk())
	assert_lt(right.y - right.x, 0.05, "the pole swings with the stride")
	assert_gt(left.y - left.x, 0.3, "the free arm does not swing")


func test_no_two_figures_stand_in_step() -> void:
	var others: Array[FigureAnimator] = [FigureAnimator.new(), FigureAnimator.new()]
	var seen: Dictionary = {}
	for animator: FigureAnimator in others:
		var pose: FigurePose = null
		for _i: int in 240:
			pose = animator.advance(DT, Vector3.ZERO, FORWARD, _shape, [])
		seen[snappedf(pose.at(FigurePose.HIPS_X), 0.0001)] = true
	assert_eq(seen.size(), 2, "two figures shift their weight in time with each other")


func test_the_measured_speed_is_smoothed() -> void:
	# Snapshots arrive in steps; one long step is not a sprint.
	_animator.advance(DT, FORWARD * 6.0, FORWARD, _shape, [])
	assert_lt(_animator.speed(), 2.0)
	_run(1.0, FORWARD * 6.0)
	assert_almost_eq(_animator.speed(), 6.0, 0.1)


func test_a_climb_is_paced_by_the_height_gained() -> void:
	_animator.set_act(FigureMotion.Act.CLIMB)
	_run(1.0, Vector3.ZERO)
	var hung := _swing(FigurePose.SHOULDER_L, 1.0, Vector3.ZERO)
	_run(0.3, Vector3(0.0, 1.5, 0.0))
	var climbing := _swing(FigurePose.SHOULDER_L, 1.5, Vector3(0.0, 1.5, 0.0))
	assert_lt(hung.y - hung.x, 0.3, "a figure hanging still is climbing")
	assert_gt(climbing.y - climbing.x, 0.5)
