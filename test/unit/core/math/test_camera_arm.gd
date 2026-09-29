## The spring arm's arithmetic. GDD-02 §4.1 and §4.4, US-0021.
##
## **THE CAMERA MUST NOT BECOME AN INFORMATION CHANNEL.** That is the one rule
## here that is not about feel, and it is the reason the arithmetic is separated
## from the raycast at all: "can a player see round a corner they could not walk
## round" is a claim about geometry, and a claim about geometry should be a unit
## test rather than something you discover by standing in a doorway.
extends GutTest

const FEET := Vector3(10.0, 0.0, -4.0)

# ------------------------------------------------------------------ the rig --


func test_the_pivot_is_at_shoulder_height() -> void:
	# You must be able to see your own silhouette, and a pivot at the feet frames
	# the ground while a pivot at the head frames the sky.
	assert_almost_eq(CameraArm.pivot(FEET).y - FEET.y, Tuning.camera.arm_height, 0.001)
	assert_almost_eq(Tuning.camera.arm_height, 1.55, 0.001)


func test_the_arm_is_the_tuned_length() -> void:
	# Measured with the shoulder centred, because the lateral offset adds to the
	# distance and would otherwise make this test assert the wrong number.
	var offset := CameraArm.offset_direction(0.0, 0.0)
	assert_almost_eq(offset.length(), Tuning.camera.arm_length, 0.001)
	assert_almost_eq(Tuning.camera.arm_length, 2.6, 0.001)


func test_the_camera_sits_behind_the_pawn() -> void:
	# Yaw 0 faces +Z (`ProbeLayout.forward`). A camera in front would show the
	# pawn walking away from the player, and every framing assertion below would
	# still pass.
	var offset := CameraArm.offset_direction(0.0, 0.0)
	assert_lt(offset.z, 0.0, "the camera is in front of the pawn")


func test_it_agrees_with_the_probes_about_forward() -> void:
	# The camera and the traversal probes must share a definition of forward, or
	# the player aims one thing and probes another.
	for yaw: float in [0.0, PI / 3.0, -PI / 2.0, 2.0]:
		assert_almost_eq(CameraArm.forward(yaw).distance_to(ProbeLayout.forward(yaw)), 0.0, 0.0001)
		assert_almost_eq(CameraArm.right(yaw).distance_to(ProbeLayout.right(yaw)), 0.0, 0.0001)


## **THE PAWN IS CENTRED**, US-0092. Three tests lived here asserting that the
## arm carried a lateral offset and that the two sides mirrored each other; the
## offset is deprecated, and this is the assertion that replaced them.
##
## It is a stronger claim than the ones it replaced: not "the offset is 0.45 m to
## the right" but "there is no sideways component at all, at any yaw or pitch".
func test_the_arm_is_on_the_centre_line() -> void:
	for yaw: float in [0.0, 1.0, -2.2]:
		for pitch: float in [-0.7, 0.0, 0.7]:
			var offset := CameraArm.offset_direction(yaw, pitch)
			var lateral := offset.dot(CameraArm.right(yaw))
			assert_almost_eq(lateral, 0.0, 0.001, "the arm sat off-centre at yaw %.1f" % yaw)


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
		var view := (pivot - CameraArm.ideal_position(FEET, 0.0, pitch)).normalized()
		assert_gt(view.y, 0.0, "pitch %.1f pointed the view downward" % pitch)
	for pitch: float in [-0.2, -0.6, -1.0]:
		var view := (pivot - CameraArm.ideal_position(FEET, 0.0, pitch)).normalized()
		assert_lt(view.y, 0.0, "pitch %.1f pointed the view upward" % pitch)


func test_a_level_look_is_level() -> void:
	var pivot := CameraArm.pivot(FEET)
	var view := (pivot - CameraArm.ideal_position(FEET, 0.0, 0.0)).normalized()
	assert_almost_eq(view.y, 0.0, 0.001, "a zero pitch was not level")


func test_the_mouse_and_the_stick_agree_about_up() -> void:
	# The sampler's convention, asserted against the arm's. Mouse up gives a
	# NEGATIVE `relative.y`, which `InputSampler` subtracts — so up increases
	# pitch. `LOOK_SUFFIXES` puts `_down` before `_up` so a stick pushed up also
	# gives positive y. Both must mean the same thing to the arm, or the pad and
	# the mouse invert against each other.
	var pivot := CameraArm.pivot(FEET)
	var mouse_moved_up := -(-1.0) * 0.0022  # `look_pitch -= relative.y * sens`
	var view := (pivot - CameraArm.ideal_position(FEET, 0.0, mouse_moved_up)).normalized()
	assert_gt(view.y, 0.0, "moving the mouse up pointed the view down")


func test_the_arm_follows_the_pawn() -> void:
	var here := CameraArm.ideal_position(FEET, 0.0, 0.0)
	var there := CameraArm.ideal_position(FEET + Vector3(5.0, 0.0, 0.0), 0.0, 0.0)
	assert_almost_eq((there - here).distance_to(Vector3(5.0, 0.0, 0.0)), 0.0, 0.001)


# ------------------------------------------------------------- the resting tilt --


## How far below the view's centre the pawn's feet are, in radians, with the arm
## at `pitch` and full length — the angle a lens has to reach to show them.
func _feet_below_centre(pitch: float) -> float:
	var camera := CameraArm.ideal_position(FEET, 0.0, pitch)
	var view := (CameraArm.pivot(FEET) - camera).normalized()
	var to_feet := (FEET - camera).normalized()
	return asin(clampf(-to_feet.y, -1.0, 1.0)) - asin(clampf(-view.y, -1.0, 1.0))


func test_a_level_camera_cut_the_feet_off() -> void:
	# **THE FINDING, KEPT AS THE PREMISE.** Measured from the client on 2026-09-29:
	# level, the feet fell below the frame at the default lens, so a Compass drawn
	# round the legs had no legs to circle. If this stops being true the tilt below is
	# answering a question nobody is asking any more.
	var half := deg_to_rad(CameraFov.default_fov()) * 0.5
	assert_gt(_feet_below_centre(0.0), half, "a level camera already shows the feet")


func test_an_untouched_look_frames_the_feet() -> void:
	# US-0105: `TUN-CAM-REST-PITCH` tilts the resting view down, so the feet are in
	# frame at the default lens and the view looks down on the street ahead.
	var limit := deg_to_rad(70.0)
	var pitch := CameraArm.view_pitch(0.0, limit)
	var half := deg_to_rad(CameraFov.default_fov()) * 0.5
	assert_lt(_feet_below_centre(pitch), half, "the feet are still out of frame at rest")
	var view := (CameraArm.pivot(FEET) - CameraArm.ideal_position(FEET, 0.0, pitch)).normalized()
	assert_lt(view.y, 0.0, "the resting view does not look down")


func test_the_resting_tilt_is_added_to_the_look_and_the_limit_holds() -> void:
	var limit := deg_to_rad(70.0)
	var rest := deg_to_rad(Tuning.camera.rest_pitch)
	assert_almost_eq(CameraArm.view_pitch(0.0, limit), rest, 0.0001)
	assert_almost_eq(CameraArm.view_pitch(0.3, limit), 0.3 + rest, 0.0001)
	assert_almost_eq(CameraArm.view_pitch(PI / 2.0, limit), limit, 0.0001, "past the gimbal, up")
	assert_almost_eq(
		CameraArm.view_pitch(-PI / 2.0, limit), -limit, 0.0001, "past the gimbal, down"
	)
	# And the full upward range survives the tilt: a look of limit − rest reaches it.
	assert_almost_eq(CameraArm.view_pitch(limit - rest, limit), limit, 0.0001)
