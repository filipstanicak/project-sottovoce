## The stick is read in the camera's frame. GDD-02 §2.
##
## **A AND D WERE SWAPPED FOR NINE STORIES AND NO TEST NOTICED.** `LocomotionState`
## built its world direction as `Vector3(move.x, 0, move.y)`, spending the stick
## on fixed world axes: W walked north whatever the camera was doing, and A
## walked west — which at yaw 0, the heading everything spawns at, is the pawn's
## RIGHT.
##
## It survived because the code agreed with itself. `ProbeLayout.forward` cited
## `InputCommand.move` as the reason yaw 0 faces +Z, the backpedal test compared
## the stick against a world facing, and every test asserted that pressing
## forward moved the pawn — which was true. **Nothing compared the direction it
## moved to the direction the camera was pointing**, and that comparison is the
## whole feature.
##
## So every assertion here is against the camera basis rather than against a
## literal axis: an assertion that W moves along +Z is true of the bug.
extends GutTest

const DT := 1.0 / 60.0

## Enough ticks to build a velocity worth measuring, few enough to stay in state.
const TICKS := 10

var _machine: PawnStateMachine


func before_each() -> void:
	_machine = PawnStateMachine.new()
	for script: GDScript in PawnStateMachine.REGISTERED:
		_machine.register(script.new())


func after_each() -> void:
	_machine.free()


func _ctx() -> PawnContext:
	var ctx := PawnContext.new()
	ctx.state_id = PawnStateId.STROLL
	ctx.position = Vector3(20.0, 0.0, 20.0)
	ctx.grounded = true
	return ctx


func _command(move: Vector2, yaw: float) -> InputCommand:
	var command := InputCommand.new()
	command.move = move
	command.look_yaw = yaw
	return command


## The horizontal velocity after holding one stick direction at one heading.
func _travel(move: Vector2, yaw: float) -> Vector3:
	var ctx := _ctx()
	var command := _command(move, yaw)
	for i: int in TICKS:
		_machine.step(ctx, command, DT)
	return Vector3(ctx.velocity.x, 0.0, ctx.velocity.z)


func _assert_along(actual: Vector3, wanted: Vector3, what: String) -> void:
	assert_gt(actual.length(), 0.1, "%s produced no movement at all" % what)
	var cosine := actual.normalized().dot(wanted.normalized())
	assert_almost_eq(cosine, 1.0, 0.01, "%s went %.0f° off" % [what, rad_to_deg(acos(cosine))])


# ------------------------------------------------- the four cardinal presses --


func test_forward_goes_where_the_camera_looks() -> void:
	for yaw: float in [0.0, PI / 4.0, PI / 2.0, 2.5, -1.2]:
		_assert_along(
			_travel(Vector2(0.0, 1.0), yaw), ProbeLayout.forward(yaw), "W at yaw %f" % yaw
		)


func test_back_goes_away_from_where_the_camera_looks() -> void:
	for yaw: float in [0.0, PI / 3.0, -2.0]:
		_assert_along(
			_travel(Vector2(0.0, -1.0), yaw), -ProbeLayout.forward(yaw), "S at yaw %f" % yaw
		)


func test_d_goes_to_the_pawns_right() -> void:
	# **THE REPORTED SYMPTOM.** At yaw 0 the old code sent D to −X, which is the
	# pawn's left, so this is the assertion that was false in the shipped game.
	for yaw: float in [0.0, PI / 2.0, -0.8]:
		_assert_along(_travel(Vector2(1.0, 0.0), yaw), ProbeLayout.right(yaw), "D at yaw %f" % yaw)


func test_a_goes_to_the_pawns_left() -> void:
	for yaw: float in [0.0, PI / 2.0, -0.8]:
		_assert_along(
			_travel(Vector2(-1.0, 0.0), yaw), -ProbeLayout.right(yaw), "A at yaw %f" % yaw
		)


func test_a_and_d_are_opposite_at_every_heading() -> void:
	for yaw: float in [0.0, 1.0, 2.0, -3.0]:
		var left := _travel(Vector2(-1.0, 0.0), yaw).normalized()
		var right := _travel(Vector2(1.0, 0.0), yaw).normalized()
		assert_almost_eq(left.dot(right), -1.0, 0.01, "A and D were not opposites at yaw %f" % yaw)


# -------------------------------------------------------------- the rotation --


func test_turning_the_camera_turns_the_travel_with_it() -> void:
	# The direct statement of the bug: the same key at two headings must produce
	# two directions, separated by exactly the angle the camera turned.
	var north := _travel(Vector2(0.0, 1.0), 0.0).normalized()
	var turned := _travel(Vector2(0.0, 1.0), PI / 2.0).normalized()
	var between := rad_to_deg(acos(clampf(north.dot(turned), -1.0, 1.0)))
	assert_almost_eq(between, 90.0, 1.0, "a 90° camera turn moved the travel %.0f°" % between)


func test_a_diagonal_is_the_sum_of_its_parts() -> void:
	var yaw := 0.7
	var wanted := ProbeLayout.forward(yaw) + ProbeLayout.right(yaw)
	_assert_along(_travel(Vector2(1.0, 1.0).normalized(), yaw), wanted, "W+D at yaw 0.7")


func test_a_diagonal_is_not_faster_than_a_straight_line() -> void:
	# The normalisation, which the rotation must not have quietly undone.
	var straight := _travel(Vector2(0.0, 1.0), 0.9).length()
	var diagonal := _travel(Vector2(1.0, 1.0), 0.9).length()
	assert_almost_eq(diagonal, straight, 0.05, "moving diagonally was faster")


# ------------------------------------------------------------- the backpedal --


func test_backpedalling_is_slower_at_every_heading() -> void:
	# `TUN-SPEED-BACKPEDAL-MULT` used to be decided by dotting the stick against a
	# world facing, so which key counted as "back" rotated with the camera.
	for yaw: float in [0.0, 1.5, -2.6]:
		var forward := _travel(Vector2(0.0, 1.0), yaw).length()
		var back := _travel(Vector2(0.0, -1.0), yaw).length()
		assert_lt(back, forward, "S was not penalised at yaw %f" % yaw)


func test_strafing_is_not_backpedalling() -> void:
	for yaw: float in [0.0, 1.5]:
		var forward := _travel(Vector2(0.0, 1.0), yaw).length()
		assert_almost_eq(
			_travel(Vector2(1.0, 0.0), yaw).length(), forward, 0.05, "D was treated as backwards"
		)
