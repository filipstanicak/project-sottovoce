## **THE LENS AGAINST REAL KEYS.** GDD-02 §4.2, US-0022.
##
## `test_camera_fov.gd` proves the arithmetic and `test_camera_fov_rungs.gd`
## proves each state names the right rung. Neither can prove the rig ever asks,
## or that a key press reaches the lens at all — and that is exactly the class of
## defect this project keeps finding late: US-0016's boot was broken with 222
## unit tests green, and US-0019's vault computed a perfect arc that never moved
## the pawn.
##
## So this drives the real `client_root.tscn` through the real `InputMap`
## bindings and reads `Camera3D.fov` off the real camera, at each steady speed
## state, to the 1° the story asks for.
extends GutTest

const CLIENT_ROOT := "res://scenes/client_root.tscn"

## Long enough for the slowest rung to be reached — Run needs
## `TUN-SPEED-RUN-RESOLVE` — plus the lens's own 0.19 s sweep, with margin.
const FRAMES := 90

var _root: Node
var _rig: CameraRig
var _driver: LocalPawnDriver


func before_each() -> void:
	_release_everything()
	_root = add_child_autofree((load(CLIENT_ROOT) as PackedScene).instantiate())
	_rig = _root.get_node("World/CameraRig")
	_driver = _root.get_node("LocalPawnDriver")
	await get_tree().physics_frame


func after_each() -> void:
	_release_everything()


func _release_everything() -> void:
	for id: StringName in InputActions.ids():
		for name: StringName in InputActions.action_names(id):
			if InputMap.has_action(name):
				Input.action_release(name)


## Hold `actions` for `frames` physics frames, letting the camera process between
## each — the lens blends in `_process`, not in the physics step.
func _hold(actions: Array[StringName], frames: int = FRAMES) -> void:
	for action: StringName in actions:
		Input.action_press(action)
	for _i: int in frames:
		await get_tree().physics_frame
		await get_tree().process_frame


## Tap `action`, release, press again inside `TUN-SPEED-RUN-RESOLVE`, and hold.
## Frame-counted rather than timed, because the gate counts ticks.
func _double_tap(action: StringName) -> void:
	# Two frames a phase, not one: the sampler runs inside a `_physics_process`
	# and a press released on the very next frame boundary can be sampled once or
	# not at all, depending on node order.
	Input.action_press(action)
	await _hold([], 2)
	Input.action_release(action)
	await _hold([], 2)
	await _hold([action])


# ------------------------------------------------------ the five steady rungs --


func test_standing_still_frames_a_civilian() -> void:
	await _hold([], 20)
	assert_eq(_driver.ctx.state_id, PawnStateId.IDLE)
	assert_almost_eq(_rig.fov, Tuning.camera.fov_stroll, 1.0)


func test_blend_walking_narrows_the_lens() -> void:
	await _hold([&"input_move_forward", &"input_slow"])
	assert_eq(_driver.ctx.state_id, PawnStateId.BLEND_WALK, "slow+forward did not blend-walk")
	assert_almost_eq(_rig.fov, Tuning.camera.fov_blend, 1.0, "blend-walk did not narrow the lens")


func test_strolling_holds_the_default() -> void:
	await _hold([&"input_move_forward"])
	assert_eq(_driver.ctx.state_id, PawnStateId.STROLL)
	assert_almost_eq(_rig.fov, Tuning.camera.fov_stroll, 1.0)


func test_running_widens_it() -> void:
	await _hold([&"input_move_forward", &"input_run"])
	assert_eq(_driver.ctx.state_id, PawnStateId.RUN, "a held run never escalated")
	assert_almost_eq(_rig.fov, Tuning.camera.fov_run, 1.0)


func test_sprinting_is_the_widest() -> void:
	# The loudest thing a player can do, and the lens says so before the tier
	# indicator does. **Reached by a double-tap, because that is now the only
	# route** — a sustained hold means Run and keeps meaning Run, which is the
	# whole point of `TUN-SPEED-RUN-RESOLVE`.
	Input.action_press(&"input_move_forward")
	await _double_tap(&"input_run")
	assert_eq(_driver.ctx.state_id, PawnStateId.SPRINT, "a held sprint never opened the gate")
	assert_almost_eq(_rig.fov, Tuning.camera.fov_sprint, 1.0)


# --------------------------------------------------------------- the channel --


func test_the_lens_returns_when_the_player_slows_down() -> void:
	# **THE WARNING HAS TO BE REVERSIBLE**, or it is a punishment rather than a
	# channel. Sprint, then release everything and let go: the lens must come
	# back, and come back to the civilian rung rather than to wherever it was.
	Input.action_press(&"input_move_forward")
	await _double_tap(&"input_run")
	var wide := _rig.fov
	_release_everything()
	await _hold([], 40)
	assert_lt(_rig.fov, wide, "the lens never came back")
	assert_almost_eq(_rig.fov, Tuning.camera.fov_stroll, 1.0)


func test_the_match_does_not_open_on_a_zoom() -> void:
	# `Camera3D` defaults to 75°. A rig that blended from the default rather than
	# setting it would spend the first fifth of a second zooming in, on every
	# spawn, for no reason the player could name.
	assert_almost_eq(_rig.fov, Tuning.camera.fov_stroll, 0.01, "the rig booted on the wrong lens")


func test_motion_reduction_holds_one_lens_at_every_speed() -> void:
	# GDD-02 §9.4, against the real rig. The trade this makes — losing the warning
	# channel for a persistent speed indicator on the HUD — is US-0084's to
	# complete; what US-0022 owes is that the lock actually locks.
	_rig.motion_reduction = true
	Input.action_press(&"input_move_forward")
	await _double_tap(&"input_run")
	assert_eq(_driver.ctx.state_id, PawnStateId.SPRINT, "the pawn did not reach the widest rung")
	assert_almost_eq(
		_rig.fov, Tuning.camera.fov_motion_reduced, 1.0, "motion reduction did not hold the lens"
	)
