## **THE CAMERA MUST NOT BECOME AN INFORMATION CHANNEL.** GDD-02 §4.4, US-0021.
##
## Split from `test_camera_arm.gd`, which covers the framing. This covers the one
## rule here that is not about feel: §4.4's fairness rule, and the two rates that
## keep it from being annoying.
##
## A standard spring arm, blocked, **slides along the surface** until it finds
## clearance — so a player pressed against a corner gets a free look down the
## street beyond it. This one shortens along its own line instead. Pulling in
## costs the player the view, which is the honest answer: you cannot see round
## the corner, because you are not round the corner.
##
## "Can a player see round a corner they could not walk round" is a claim about
## geometry, and a claim about geometry should be a unit test rather than
## something you discover by standing in a doorway.
extends GutTest

const FEET := Vector3(10.0, 0.0, -4.0)


func test_a_clear_line_leaves_the_arm_at_full_length() -> void:
	assert_almost_eq(CameraArm.occluded_distance(2.6, INF), 2.6, 0.001)


func test_an_occluded_arm_stops_short_of_the_wall() -> void:
	# By `TUN-CAM-OCCLUSION-MARGIN`. Closer and the near plane clips through;
	# further and the camera reads as detached from what it is avoiding.
	var stopped := CameraArm.occluded_distance(2.6, 1.5)
	assert_almost_eq(stopped, 1.5 - Tuning.camera.occlusion_margin, 0.001)
	assert_lt(stopped, 1.5, "the camera stopped inside the wall")


func test_it_never_pushes_the_arm_out_past_its_length() -> void:
	# A hit beyond the arm is not an occluder at all.
	assert_almost_eq(CameraArm.occluded_distance(2.6, 9.0), 2.6, 0.001)


func test_a_wall_in_the_pawns_face_collapses_the_arm_to_the_pivot() -> void:
	# Not to a negative distance, and not behind the player's own head.
	assert_almost_eq(CameraArm.occluded_distance(2.6, 0.05), 0.0, 0.001)


func test_pulling_in_never_changes_the_direction() -> void:
	# **THE RULE.** §4.4: the arm pulls IN rather than sideways, so a player
	# pressed against a corner never gets a free look down the street beyond it.
	# Sliding is what an ordinary spring arm does; this asserts we do not.
	var full := CameraArm.position_at(FEET, 1.0, 0.2, 2.6)
	var pulled := CameraArm.position_at(FEET, 1.0, 0.2, 0.8)
	var pivot := CameraArm.pivot(FEET)
	assert_almost_eq(
		(full - pivot).normalized().distance_to((pulled - pivot).normalized()),
		0.0,
		0.0001,
		"the arm moved sideways when it pulled in"
	)
	assert_almost_eq((pulled - pivot).length(), 0.8, 0.001)


func test_the_arm_never_acquires_a_sideways_component() -> void:
	# **THE PEEK THE RULE FORBIDS**, asserted at every pull-in distance rather than
	# at one. The offset that used to be inside this line is gone (US-0092, the
	# pawn is centred), so the claim is now the stronger one: there is no lateral
	# displacement to keep, at any distance, at any pitch.
	var pivot := CameraArm.pivot(FEET)
	for distance: float in [0.2, 0.5, 1.4, 2.6]:
		for pitch: float in [-0.6, 0.0, 0.6]:
			var pulled := CameraArm.position_at(FEET, 0.0, pitch, distance)
			var lateral := (pulled - pivot).dot(CameraArm.right(0.0))
			assert_almost_eq(lateral, 0.0, 0.001, "the arm slid sideways at %.1f m" % distance)


# ------------------------------------------------------------- the two rates --


func test_pulling_in_is_faster_than_restoring() -> void:
	# **THE ASYMMETRY IS THE POINT.** Fast in, because a camera stuck in a wall in
	# a game about looking at people is a critical failure. Slow out, or the arm
	# oscillates in a doorway — clear, spring back, collide, repeat.
	assert_gt(Tuning.camera.occlusion_pull_rate, Tuning.camera.occlusion_restore_rate)
	assert_almost_eq(Tuning.camera.occlusion_pull_rate, 12.0, 0.001)
	assert_almost_eq(Tuning.camera.occlusion_restore_rate, 4.0, 0.001)


func test_the_arm_pulls_in_at_the_pull_rate() -> void:
	var moved := 2.6 - CameraArm.step_distance(2.6, 0.0, 0.1)
	assert_almost_eq(moved, Tuning.camera.occlusion_pull_rate * 0.1, 0.001)


func test_the_arm_restores_at_the_restore_rate() -> void:
	var moved := CameraArm.step_distance(0.0, 2.6, 0.1)
	assert_almost_eq(moved, Tuning.camera.occlusion_restore_rate * 0.1, 0.001)


func test_it_never_overshoots_what_it_was_asked_for() -> void:
	assert_almost_eq(CameraArm.step_distance(2.5, 2.6, 10.0), 2.6, 0.001)
	assert_almost_eq(CameraArm.step_distance(0.1, 0.0, 10.0), 0.0, 0.001)
