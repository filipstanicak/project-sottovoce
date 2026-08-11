## **THE FEEL-GATE READOUT, ATTACHED TO THE REAL CLIENT.** US-0024.
##
## It exists so the owner can run the M1 feel gate without counting vaults in
## their head. It is loaded at runtime rather than placed in `client_root.tscn`,
## because the release presets strip `scripts/debug/*` and a scene referencing a
## stripped script fails **only in a real release build** — which on this project
## is a playtest with six people in the room.
##
## Runtime loading is easy to get subtly wrong and impossible to notice: a typo
## in the path, a guard that is always false, an `attach` that never connects its
## signal. Every one of those leaves the game running perfectly with no readout,
## and the owner discovering it at the moment they sat down to judge the gate.
extends GutTest

const CLIENT_ROOT := "res://scenes/client_root.tscn"
const READOUT := "res://scripts/debug/feel_readout.gd"

var _root: Node
var _driver: LocalPawnDriver


func before_each() -> void:
	_release_everything()
	_root = add_child_autofree((load(CLIENT_ROOT) as PackedScene).instantiate())
	_driver = _root.get_node("LocalPawnDriver")
	await get_tree().physics_frame
	await get_tree().process_frame


func after_each() -> void:
	_release_everything()


func _release_everything() -> void:
	for id: StringName in InputActions.ids():
		for name: StringName in InputActions.action_names(id):
			if InputMap.has_action(name):
				Input.action_release(name)


func _readout() -> CanvasLayer:
	for child: Node in _driver.get_children():
		if child is CanvasLayer:
			return child
	return null


func _text() -> String:
	var layer := _readout()
	if layer == null:
		return ""
	for child: Node in layer.get_children():
		if child is Label:
			return (child as Label).text
	return ""


func test_it_attaches_itself_in_a_debug_build() -> void:
	# Tests run under a debug build, so the guard is open here. If this ever fails
	# the readout is silently absent, which is exactly how it would be discovered
	# too late.
	assert_true(OS.has_feature("debug"), "the suite is not running a debug build")
	assert_not_null(_readout(), "the feel readout never attached to the driver")


func test_it_reports_the_state_and_the_lens() -> void:
	await get_tree().process_frame
	var text := _text()
	assert_string_contains(text, "STATE")
	assert_string_contains(text, String(PawnStateId.IDLE))
	assert_string_contains(text, "LENS")


func test_the_state_it_shows_follows_the_pawn() -> void:
	Input.action_press(&"input_move_forward")
	Input.action_press(&"input_run")
	for _i: int in 40:
		await get_tree().physics_frame
		await get_tree().process_frame
	assert_eq(_driver.ctx.state_id, PawnStateId.RUN, "the pawn never reached Run")
	assert_string_contains(_text(), String(PawnStateId.RUN))


func test_a_traverse_press_at_nothing_is_recorded_as_a_miss() -> void:
	# **THE HALF THAT MATTERS FOR THE GATE.** Ten sloppy vaults means counting the
	# ones that produced nothing, and a tally that only counted successes would
	# read 10/10 no matter how badly the approach went.
	Input.action_press(&"input_traverse")
	for _i: int in 30:
		await get_tree().physics_frame
		await get_tree().process_frame
	assert_string_contains(_text(), "of 1 resolved")
	assert_string_contains(_text(), "0 of 1 resolved")


func test_no_scene_carries_it() -> void:
	# The rule the runtime load exists to satisfy, asserted from the other side.
	# `test_no_scene_references_debug.gd` sweeps every scene; this checks the one
	# that would have been most tempting to edit.
	assert_false(
		SourceScanner.read(CLIENT_ROOT).contains(READOUT),
		"client_root.tscn references the debug readout — the release export will break"
	)
