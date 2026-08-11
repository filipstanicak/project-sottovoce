## The spring arm's arithmetic. GDD-02 §4.1 and §4.4, US-0021.
##
## **THE CAMERA MUST NOT BECOME AN INFORMATION CHANNEL.** That is the one rule
## here that is not about feel, and it is the reason the arithmetic is separated
## from the raycast at all: "can a player see round a corner they could not walk
## round" is a claim about geometry, and a claim about geometry should be a unit
## test rather than something you discover by standing in a doorway.
extends GutTest

const FEET := Vector3(10.0, 0.0, -4.0)
const RIGHT := float(CameraArm.Shoulder.RIGHT)
const LEFT := float(CameraArm.Shoulder.LEFT)

# ------------------------------------------------------------------ the rig --


func test_the_pivot_is_at_shoulder_height() -> void:
	# You must be able to see your own silhouette, and a pivot at the feet frames
	# the ground while a pivot at the head frames the sky.
	assert_almost_eq(CameraArm.pivot(FEET).y - FEET.y, Tuning.camera.arm_height, 0.001)
	assert_almost_eq(Tuning.camera.arm_height, 1.55, 0.001)


func test_the_arm_is_the_tuned_length() -> void:
	# Measured with the shoulder centred, because the lateral offset adds to the
	# distance and would otherwise make this test assert the wrong number.
	var offset := CameraArm.offset_direction(0.0, 0.0, 0.0)
	assert_almost_eq(offset.length(), Tuning.camera.arm_length, 0.001)
	assert_almost_eq(Tuning.camera.arm_length, 2.6, 0.001)


func test_the_camera_sits_behind_the_pawn() -> void:
	# Yaw 0 faces +Z (`ProbeLayout.forward`). A camera in front would show the
	# pawn walking away from the player, and every framing assertion below would
	# still pass.
	var offset := CameraArm.offset_direction(0.0, 0.0, 0.0)
	assert_lt(offset.z, 0.0, "the camera is in front of the pawn")


func test_it_agrees_with_the_probes_about_forward() -> void:
	# The camera and the traversal probes must share a definition of forward, or
	# the player aims one thing and probes another.
	for yaw: float in [0.0, PI / 3.0, -PI / 2.0, 2.0]:
		assert_almost_eq(CameraArm.forward(yaw).distance_to(ProbeLayout.forward(yaw)), 0.0, 0.0001)
		assert_almost_eq(CameraArm.right(yaw).distance_to(ProbeLayout.right(yaw)), 0.0, 0.0001)


func test_the_shoulder_offset_is_lateral_and_tuned() -> void:
	var centred := CameraArm.offset_direction(0.0, 0.0, 0.0)
	var over_right := CameraArm.offset_direction(0.0, 0.0, RIGHT)
	var sideways := over_right - centred
	assert_almost_eq(sideways.length(), Tuning.camera.shoulder_offset, 0.001)
	assert_almost_eq(sideways.dot(CameraArm.right(0.0)), Tuning.camera.shoulder_offset, 0.001)
	assert_almost_eq(Tuning.camera.shoulder_offset, 0.45, 0.001)


func test_the_two_shoulders_are_mirror_images() -> void:
	var over_right := CameraArm.offset_direction(0.0, 0.0, RIGHT)
	var over_left := CameraArm.offset_direction(0.0, 0.0, LEFT)
	assert_almost_eq(over_right.length(), over_left.length(), 0.001)
	assert_almost_eq(
		(over_right - over_left).dot(CameraArm.right(0.0)),
		Tuning.camera.shoulder_offset * 2.0,
		0.001
	)


func test_looking_up_points_the_view_up() -> void:
	# **THIS TEST USED TO ASSERT THE OPPOSITE, AND THE OPPOSITE WAS THE BUG.**
	# It checked that pitching up raised the arm — true, and not the question.
	# The rig looks AT the pivot, so an arm raised above it looks *down*. The
	# vertical shipped inverted from US-0021 until somebody played the game.
	#
	# So the assertion is on the VIEW direction now: pivot minus camera, which is
	# exactly what `look_at` will use. Where the arm sits is a consequence.
	var pivot := CameraArm.pivot(FEET)
	for pitch: float in [0.2, 0.6, 1.0]:
		var view := (pivot - CameraArm.ideal_position(FEET, 0.0, pitch, 0.0)).normalized()
		assert_gt(view.y, 0.0, "pitch %.1f pointed the view downward" % pitch)
	for pitch: float in [-0.2, -0.6, -1.0]:
		var view := (pivot - CameraArm.ideal_position(FEET, 0.0, pitch, 0.0)).normalized()
		assert_lt(view.y, 0.0, "pitch %.1f pointed the view upward" % pitch)


func test_a_level_look_is_level() -> void:
	var pivot := CameraArm.pivot(FEET)
	var view := (pivot - CameraArm.ideal_position(FEET, 0.0, 0.0, 0.0)).normalized()
	assert_almost_eq(view.y, 0.0, 0.001, "a zero pitch was not level")


func test_the_mouse_and_the_stick_agree_about_up() -> void:
	# The sampler's convention, asserted against the arm's. Mouse up gives a
	# NEGATIVE `relative.y`, which `InputSampler` subtracts — so up increases
	# pitch. `LOOK_SUFFIXES` puts `_down` before `_up` so a stick pushed up also
	# gives positive y. Both must mean the same thing to the arm, or the pad and
	# the mouse invert against each other.
	var pivot := CameraArm.pivot(FEET)
	var mouse_moved_up := -(-1.0) * 0.0022  # `look_pitch -= relative.y * sens`
	var view := (pivot - CameraArm.ideal_position(FEET, 0.0, mouse_moved_up, 0.0)).normalized()
	assert_gt(view.y, 0.0, "moving the mouse up pointed the view down")


func test_the_arm_follows_the_pawn() -> void:
	var here := CameraArm.ideal_position(FEET, 0.0, 0.0, RIGHT)
	var there := CameraArm.ideal_position(FEET + Vector3(5.0, 0.0, 0.0), 0.0, 0.0, RIGHT)
	assert_almost_eq((there - here).distance_to(Vector3(5.0, 0.0, 0.0)), 0.0, 0.001)


# ------------------------------------------------------- the shoulder swap --


func test_a_swap_takes_exactly_its_tunable() -> void:
	var delta := 1.0 / 60.0
	var blend := RIGHT
	var frames := 0
	while not is_equal_approx(blend, LEFT) and frames < 600:
		blend = CameraArm.blend_shoulder(blend, LEFT, delta)
		frames += 1
	assert_almost_eq(frames * delta, Tuning.camera.shoulder_swap_time, 0.02)
	assert_almost_eq(Tuning.camera.shoulder_swap_time, 0.25, 0.001)


func test_a_swap_is_gradual_rather_than_a_teleport() -> void:
	# A camera that jumped 0.9 m sideways in one frame would read as a glitch,
	# and in a game about reading other people it would cost a beat of attention.
	var after_one_frame := CameraArm.blend_shoulder(RIGHT, LEFT, 1.0 / 60.0)
	assert_lt(after_one_frame, RIGHT, "the swap did not start")
	assert_gt(after_one_frame, LEFT, "the swap finished in a single frame")


func test_a_swap_can_be_reversed_half_way() -> void:
	# The player changed their mind. The blend must turn round from where it is,
	# not restart.
	var blend := CameraArm.blend_shoulder(RIGHT, LEFT, 0.1)
	var back := CameraArm.blend_shoulder(blend, RIGHT, 1.0 / 60.0)
	assert_gt(back, blend, "reversing a swap did not turn it round")


func test_the_blend_never_leaves_its_range() -> void:
	var blend := CameraArm.blend_shoulder(RIGHT, 5.0, 10.0)
	assert_almost_eq(
		blend, RIGHT, 0.001, "an out-of-range target pushed the camera past a shoulder"
	)
