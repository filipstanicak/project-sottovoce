## **CROWD-SCAN THROUGH THE REAL CLIENT.** GDD-02 §4.3, US-0023.
##
## `INPUT-SCAN` has been bound in `project.godot` since US-0016 and read by
## nothing. This is where the button finally does something, and where the three
## things it does — a narrower lens, a slower pan, a capped pace — are checked
## against the real rig, the real sampler and the real speed ladder rather than
## against three unit-tested functions that might not be wired to each other.
##
## The fourth thing §4.3 lists, the audio duck, is NOT here: `Audio` is a stub
## until US-0075, so there is nothing to duck and nothing to assert.
extends GutTest

const CLIENT_ROOT := "res://scenes/client_root.tscn"
const FRAMES := 60

var _root: Node
var _rig: CameraRig
var _driver: LocalPawnDriver
var _sampler: InputSampler


func before_each() -> void:
	_release_everything()
	_root = add_child_autofree((load(CLIENT_ROOT) as PackedScene).instantiate())
	_rig = _root.get_node("World/CameraRig")
	_driver = _root.get_node("LocalPawnDriver")
	_sampler = _root.get_node("InputSampler")
	await get_tree().physics_frame


func after_each() -> void:
	_release_everything()


func _release_everything() -> void:
	for id: StringName in InputActions.ids():
		for name: StringName in InputActions.action_names(id):
			if InputMap.has_action(name):
				Input.action_release(name)


func _hold(actions: Array[StringName], frames: int = FRAMES) -> void:
	for action: StringName in actions:
		Input.action_press(action)
	for _i: int in frames:
		await get_tree().physics_frame
		await get_tree().process_frame


# ------------------------------------------------------------- the three effects --


func test_holding_scan_narrows_the_lens_past_every_rung() -> void:
	await _hold([&"input_scan"])
	assert_almost_eq(_rig.fov, Tuning.camera.crowdscan_fov, 1.0, "the lens did not lean in")
	assert_lt(_rig.fov, Tuning.camera.fov_blend, "the scan lens is not the narrowest in the game")


func test_the_lens_comes_back_when_the_button_is_released() -> void:
	await _hold([&"input_scan"])
	_release_everything()
	await _hold([], 40)
	assert_almost_eq(_rig.fov, Tuning.camera.fov_stroll, 1.0, "the lens stayed leaned in")


## Sweep the same 100 px of mouse motion through the real sampler and report how
## far the yaw actually turned.
func _yaw_swept() -> float:
	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(100.0, 0.0)
	var before: float = _sampler.sample(1.0 / 60.0).look_yaw
	_sampler._unhandled_input(motion)
	return absf(_sampler.sample(1.0 / 60.0).look_yaw - before)


func test_scanning_slows_the_look() -> void:
	# The same physical mouse movement, measured twice. Through the real sampler,
	# so this covers the ORDERING as well as the multiplier: buttons must resolve
	# before look within a frame, or a toggled scan applies one frame late and the
	# command disagrees with itself.
	var plain := _yaw_swept()
	Input.action_press(&"input_scan")
	var scanned := _yaw_swept()
	assert_gt(plain, 0.0, "the mouse never reached the sampler")
	assert_almost_eq(
		scanned / plain,
		Tuning.camera.crowdscan_speed,
		0.01,
		"the scan pan is not %.2f x the ordinary one" % Tuning.camera.crowdscan_speed
	)


func test_scanning_caps_the_pace_without_changing_the_rung() -> void:
	# Forward and run held throughout, which escalates to Run past
	# `TUN-SPEED-RUN-HOLD` — and must escalate identically whether or not the
	# player is scanning. The pawn keeps Run's label and Run's suspicion rate
	# while moving at a civilian's pace: the cost, with no refund attached.
	await _hold([&"input_move_forward", &"input_run"])
	var unscanned := _driver.ctx.state_id
	_release_everything()

	_root.queue_free()
	_root = add_child_autofree((load(CLIENT_ROOT) as PackedScene).instantiate())
	_driver = _root.get_node("LocalPawnDriver")
	await get_tree().physics_frame
	await _hold([&"input_move_forward", &"input_run", &"input_scan"])
	assert_eq(_driver.ctx.state_id, unscanned, "scanning changed which rung the ladder reached")
	assert_eq(unscanned, PawnStateId.RUN, "a held run never escalated, so this proved nothing")
	assert_lte(
		Vector3(_driver.ctx.velocity.x, 0.0, _driver.ctx.velocity.z).length(),
		Tuning.movement.blend_walk + 0.05,
		"a scanning runner outran the cap"
	)


func test_a_scanning_pawn_covers_less_ground() -> void:
	# The cap's consequence, where a body exists to be moved. `step()` only
	# computes a velocity — distance is the driver's, so the unit tests cannot
	# see this and it has to be asserted here.
	var start := _driver.ctx.position
	await _hold([&"input_move_forward", &"input_scan"])
	var scanned := _driver.ctx.position.distance_to(start)
	_release_everything()

	_root.queue_free()
	_root = add_child_autofree((load(CLIENT_ROOT) as PackedScene).instantiate())
	_driver = _root.get_node("LocalPawnDriver")
	await get_tree().physics_frame
	start = _driver.ctx.position
	await _hold([&"input_move_forward"])
	assert_gt(
		_driver.ctx.position.distance_to(start),
		scanned,
		"a scanning pawn kept up with a strolling one"
	)


func test_releasing_scan_returns_the_speed() -> void:
	await _hold([&"input_move_forward", &"input_run", &"input_scan"])
	Input.action_release(&"input_scan")
	await _hold([&"input_move_forward", &"input_run"], 40)
	assert_gt(
		Vector3(_driver.ctx.velocity.x, 0.0, _driver.ctx.velocity.z).length(),
		Tuning.movement.blend_walk + 0.05,
		"the pawn stayed capped after the scan ended"
	)


# ------------------------------------------------------------------ hold or toggle --


func test_it_is_available_as_a_toggle() -> void:
	# §9.3 requires hold AND toggle for every hold input, individually. A player
	# who cannot hold a middle mouse button for thirty seconds must still be able
	# to read a crowd — which is the whole game.
	assert_true(InputActions.is_toggleable(Ids.INPUT_SCAN), "INPUT-SCAN cannot be toggled")
	_sampler.set_mode(Ids.INPUT_SCAN, InputLatch.Mode.TOGGLE)
	await _hold([&"input_scan"], 4)
	Input.action_release(&"input_scan")
	await _hold([], 30)
	assert_almost_eq(_rig.fov, Tuning.camera.crowdscan_fov, 1.0, "the toggle did not latch on")


# ----------------------------------------------------------- and grants nothing --


func test_being_stunned_takes_the_scan_with_the_look() -> void:
	# Scanning is an act of looking, and a stun takes the look (US-0021). The
	# button may still be held and the bit may still be set; neither matters.
	await _hold([&"input_scan"], 20)
	assert_true(_rig.is_scanning(), "the rig never registered the scan")
	_driver.ctx.state_id = PawnStateId.STUNNED
	await _hold([&"input_scan"], 10)
	assert_false(_rig.is_scanning(), "a stunned player was still scanning")
	assert_almost_eq(_rig.fov, Tuning.camera.fov_stroll, 1.0, "the lens stayed leaned in")
