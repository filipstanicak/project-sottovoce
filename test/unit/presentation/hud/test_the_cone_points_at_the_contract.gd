## **THE SEAM BETWEEN TWO YAW CONVENTIONS, WHICH HAD NO TEST AND WAS WRONG.**
## US-0072, UI_UX_SPEC §3.
##
## This game's yaw 0 faces **+Z**; a Godot node's yaw 0 faces **−Z**. `HudRoot`
## reads `camera.global_rotation.y` and `CompassVm` speaks the game's convention,
## so the two meet in exactly one line — and it shipped without a conversion. The
## cone pointed at the **opposite** of the contract, and the owner found it by
## walking toward a cone that led them away.
##
## **EVERY TEST EITHER SIDE OF THAT LINE PASSED.** `test_compass_vm.gd` feeds
## `camera_yaw` directly and is right about what it asserts; `test_camera_arm.gd`
## asks where the arm sits. Neither could see that the number handed across was in
## the wrong frame — trap 4 in its purest form, an assertion that is true of both
## conventions.
##
## **AND THERE WERE TWO ERRORS, WHICH PARTLY CANCELLED.** Besides the missing half
## turn, the widget mapped the world angle straight onto a screen angle — and the
## two run opposite ways, because this game's yaw increases toward a screen turn to
## the **left** while a screen angle increases clockwise. Composed, they are a
## front-to-back flip: a contract at either shoulder drew **correctly** and one
## dead ahead drew at the bottom of the dial. Either error alone would have been
## obvious in a minute of play.
##
## So this file builds the camera the way `CameraRig` builds it, reads the heading
## back off the basis the way `HudRoot` reads it, hands the widget its view model,
## and asks **where on the screen the cone lands** — which is the only question a
## player asks.
extends GutTest

const FEET := Vector3(20.0, 0.0, 20.0)

var _vm: CompassVm
var _widget: CompassWidget


func before_each() -> void:
	_vm = CompassVm.new()
	# **THE WIDGET ITSELF ANSWERS, RATHER THAN THIS FILE RE-DERIVING IT.** The
	# screen mapping is one line and it was one of the two things that were wrong;
	# a test that recomputed it would agree with a widget that was wrong.
	_widget = CompassWidget.new()
	_widget.vm = _vm
	add_child_autofree(_widget)


## What `camera.global_rotation.y` reports for a rig aimed with this game's yaw.
## `CameraRig._process` is `global_position = CameraArm.position_at(...)` followed
## by `look_at(CameraArm.pivot(...))`, and this is those two lines.
func _node_yaw_of_rig(yaw: float) -> float:
	var eye := CameraArm.position_at(FEET, yaw, 0.0, Tuning.camera.arm_length)
	return (
		Transform3D(Basis(), eye).looking_at(CameraArm.pivot(FEET), Vector3.UP).basis.get_euler().y
	)


## Where the widget draws the cone, as a screen vector: +X right, **+Y down**.
func _drawn(yaw: float, contract: Vector3) -> Vector2:
	_vm.bucket = Quantise.distance_to_bucket(CompassMath.distance_to(FEET, contract))
	_vm.bearing = CompassMath.bearing_to(FEET, contract)
	_vm.camera_yaw = CameraArm.yaw_from_camera(_node_yaw_of_rig(yaw))
	return Vector2.from_angle(_widget.screen_angle())


func test_the_conversion_is_a_conversion_and_not_a_pass_through() -> void:
	# **THE VACUOUS-SUCCESS GUARD.** If `yaw_from_camera` were the identity, every
	# assertion below would still have to pass or fail on its own merits — but the
	# reader would have no way to tell the conversion was doing anything, and a
	# "tidying" commit that deleted it would look harmless.
	for yaw: float in [0.0, 1.0, -2.0]:
		assert_almost_eq(
			absf(CompassMath.angle_between(CameraArm.yaw_from_camera(yaw), yaw)),
			PI,
			0.0001,
			"the camera conversion is not the half turn the two conventions differ by"
		)


func test_the_rig_reports_a_heading_half_a_turn_from_the_one_it_was_built_with() -> void:
	# The measurement the conversion is derived from, asserted rather than trusted.
	# If Godot ever changed which axis a Node3D looks down, this is what would say
	# so — and it would say so before the cone did.
	for degrees: float in [0.0, 45.0, 90.0, -90.0, 179.0]:
		var yaw := deg_to_rad(degrees)
		assert_almost_eq(
			absf(CompassMath.angle_between(_node_yaw_of_rig(yaw), yaw)),
			PI,
			0.001,
			"the rig's node heading is not half a turn from game yaw at %.0f deg" % degrees
		)
		assert_almost_eq(
			CompassMath.angle_between(CameraArm.yaw_from_camera(_node_yaw_of_rig(yaw)), yaw),
			0.0,
			0.001,
			"the converted heading is not the yaw the rig was built with at %.0f deg" % degrees
		)


func test_a_contract_dead_ahead_draws_the_cone_straight_up() -> void:
	# The one a player checks first, at four headings so it cannot pass by the
	# scene happening to face +Z.
	for degrees: float in [0.0, 90.0, 180.0, -135.0]:
		var yaw := deg_to_rad(degrees)
		var ahead := FEET + CameraArm.forward(yaw) * 12.0
		var drawn := _drawn(yaw, ahead)
		assert_almost_eq(drawn.y, -1.0, 0.01, "the cone is not up at heading %.0f" % degrees)
		assert_almost_eq(drawn.x, 0.0, 0.01, "the cone is off centre at heading %.0f" % degrees)


func test_a_contract_to_the_right_draws_the_cone_to_the_right() -> void:
	# **THE HALF THAT DISTINGUISHES A HALF-TURN ERROR FROM A MIRRORED ONE.** Ahead
	# alone would still pass if the sign of the rotation were inverted.
	for degrees: float in [0.0, 90.0, 180.0, -135.0]:
		var yaw := deg_to_rad(degrees)
		var right := FEET + CameraArm.right(yaw) * 12.0
		var left := FEET - CameraArm.right(yaw) * 12.0
		assert_almost_eq(_drawn(yaw, right).x, 1.0, 0.01, "right is not right at %.0f" % degrees)
		assert_almost_eq(_drawn(yaw, left).x, -1.0, 0.01, "left is not left at %.0f" % degrees)


func test_turning_toward_the_cone_brings_it_to_the_top() -> void:
	# **THE DEFECT AS THE OWNER REPORTED IT.** The cone sat to one side; turning
	# that way should walk it to the top of the dial, and it walked to the bottom.
	# A quarter turn in eighths, so it is the whole path that is asserted rather
	# than the endpoints — a front-to-back flip gets the endpoints of a quarter
	# turn right.
	var contract := FEET + Vector3(14.0, 0.0, 6.0)
	var yaw := CompassMath.bearing_to(FEET, contract) - PI * 0.5
	assert_almost_eq(
		_drawn(yaw, contract).x, -1.0, 0.01, "the fixture does not start off to one side"
	)
	var previous := 2.0
	for step: int in 9:
		var drawn := _drawn(yaw + PI * 0.5 * (float(step) / 8.0), contract)
		assert_lte(
			drawn.y, previous + 0.001, "the cone moved away from the top while turning to it"
		)
		previous = drawn.y
	assert_almost_eq(previous, -1.0, 0.01, "facing the contract did not put the cone at the top")


func test_a_contract_behind_you_draws_at_the_bottom() -> void:
	# **THE HALF THAT WAS WRONG WHILE THE SHOULDERS WERE RIGHT.** Ahead and behind
	# are the two points a front-to-back flip swaps, and the two nobody checked.
	for degrees: float in [0.0, 90.0, 180.0, -135.0]:
		var yaw := deg_to_rad(degrees)
		var behind := FEET - CameraArm.forward(yaw) * 12.0
		assert_almost_eq(
			_drawn(yaw, behind).y, 1.0, 0.01, "behind is not at the bottom at %.0f" % degrees
		)


func test_the_hud_root_still_converts() -> void:
	# The guard the seam needed. Every assertion above tests `CameraArm`; this is
	# the one that notices `HudRoot` going back to the raw node heading.
	var source := "res://scripts/presentation/hud/hud_root.gd"
	assert_true(
		SourceScanner.code_contains(source, "CameraArm.yaw_from_camera("),
		"HudRoot no longer converts the camera's heading — the cone will point backwards"
	)
