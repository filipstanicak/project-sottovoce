## **THE MOUSE IS CAPTURED, OR THERE IS NO MOUSE LOOK.**
##
## An uncaptured cursor stops at the window edge and stops producing relative
## motion with it, so the camera turns until the pointer hits the side of the
## screen and then refuses to turn further — while a visible arrow slides around
## on top of the game.
##
## Nothing in the project set `Input.mouse_mode` until the owner tried to run the
## M1 feel gate and could not look around properly. No test could have caught it:
## the suites never had a window, and the camera turns perfectly in headless
## because the motion is injected directly.
##
## So these assert the CONTRACT rather than the effect — that the sampler takes
## the mouse on ready, gives it back on `INPUT-MENU`, and takes it again on a
## click. Whether the OS honours the request is the display server's business.
extends GutTest

const CLIENT_ROOT := "res://scenes/client_root.tscn"

var _root: Node
var _sampler: InputSampler


func before_each() -> void:
	_root = add_child_autofree((load(CLIENT_ROOT) as PackedScene).instantiate())
	_sampler = _root.get_node("InputSampler")
	await get_tree().physics_frame


func test_it_takes_the_mouse_on_boot() -> void:
	assert_true(_sampler.mouse_captured(), "the client started without capturing the mouse")


func test_the_menu_key_gives_it_back() -> void:
	# There is no options screen to release into yet (US-0079), which is exactly
	# why the escape hatch has to exist now: a captured cursor with no way out is
	# a window the player cannot leave.
	var event := InputEventAction.new()
	event.action = InputActions.action_names(Ids.INPUT_MENU)[0]
	event.pressed = true
	_sampler._unhandled_input(event)
	assert_false(_sampler.mouse_captured(), "INPUT-MENU did not release the mouse")


func test_a_click_takes_it_back() -> void:
	var release := InputEventAction.new()
	release.action = InputActions.action_names(Ids.INPUT_MENU)[0]
	release.pressed = true
	_sampler._unhandled_input(release)
	assert_false(_sampler.mouse_captured())

	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	_sampler._unhandled_input(click)
	assert_true(_sampler.mouse_captured(), "a click did not recapture the mouse")


func test_motion_is_dropped_while_the_cursor_is_free() -> void:
	# **THE REASON THE GATE EXISTS.** Without it, the pointer travelling across
	# the desktop between releasing and clicking back would arrive as one enormous
	# look delta and spin the camera on the frame the player returned.
	var release := InputEventAction.new()
	release.action = InputActions.action_names(Ids.INPUT_MENU)[0]
	release.pressed = true
	_sampler._unhandled_input(release)

	var before := _sampler.sample(1.0 / 60.0).look_yaw
	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(4000.0, 0.0)
	_sampler._unhandled_input(motion)
	assert_almost_eq(
		_sampler.sample(1.0 / 60.0).look_yaw,
		before,
		0.0001,
		"the camera turned from a mouse the game did not have"
	)
