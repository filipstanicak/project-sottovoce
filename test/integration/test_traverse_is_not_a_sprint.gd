## `INPUT-TRAVERSE` is not a speed input. GDD-02 §1.3 and §1.5.
##
## **THE OWNER RAN AT A WALL AND ARRIVED IN A SPRINT.** §1.3 gives the gamepad a
## second sprint route — "L2 full + A" — and nothing restricted it to a gamepad.
## `INPUT-TRAVERSE` is `Space` on a keyboard, so the combo made **Shift + Space**
## sprint. It predates US-0090 and became far easier to hit once a held Shift
## meant Run instead of Jog.
##
## `PadSelection` already knows whether a mapped pad is holding the joypad
## bindings; without one the combo does not exist. **CI has no pad, so the case
## that runs here is the keyboard case** — which is the one that was broken.
##
## Its own file because `test_client_boot_walks.gd` is at the linter's twenty
## public methods, and because this is a different claim: that file proves a key
## press moves the pawn, this one proves a key press does not move it *more*.
extends GutTest

const CLIENT_ROOT := "res://scenes/client_root.tscn"

var _root: Node
var _driver: LocalPawnDriver


func before_each() -> void:
	_release_everything()
	_root = add_child_autofree((load(CLIENT_ROOT) as PackedScene).instantiate())
	_driver = _root.get_node("LocalPawnDriver")
	await get_tree().physics_frame


func after_each() -> void:
	_release_everything()


func _release_everything() -> void:
	for id: StringName in InputActions.ids():
		for name: StringName in InputActions.action_names(id):
			if InputMap.has_action(name):
				Input.action_release(name)


func _run(frames: int) -> void:
	for _i: int in frames:
		await get_tree().physics_frame


func test_holding_run_and_pressing_traverse_does_not_sprint() -> void:
	Input.action_press(&"input_move_forward")
	Input.action_press(&"input_run")
	await _run(40)
	assert_eq(_driver.ctx.state_id, PawnStateId.RUN, "a held run did not reach Run")

	Input.action_press(&"input_traverse")
	await _run(3)
	Input.action_release(&"input_traverse")
	await _run(20)
	assert_ne(_driver.ctx.state_id, PawnStateId.SPRINT, "run + traverse sprinted")


func test_traverse_alone_still_reaches_the_resolver() -> void:
	# The other half: gating the combo must not cost the press its normal job.
	# Nothing is in front of the pawn here, so §7.2 case 7's silence is correct —
	# what matters is that it stays in a locomotion state rather than vanishing.
	Input.action_press(&"input_move_forward")
	await _run(30)
	Input.action_press(&"input_traverse")
	await _run(10)
	assert_true(
		_driver.ctx.state_id in PawnStateId.LOCOMOTION,
		"a traverse press in open ground left the locomotion group"
	)
