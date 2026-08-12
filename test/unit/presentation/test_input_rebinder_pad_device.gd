## `InputRebinder` applying `PadSelection` to the real `InputMap`.
##
## **THIS SUITE TOUCHES GLOBAL STATE**, so every test restores the map it found.
## The engine's `InputMap` is process-wide: a test that left the joypad bindings
## pointing at device 7 would silently change what every later suite measures.
##
## What it cannot test is the thing that actually broke: a headless run has no
## joypad driver, so no pedal set can be attached and no phantom axis can arrive.
## Same shape as the mouse capture in #48 — the fix was verified by running the
## game with the device plugged in, and the number that proves it (11 m of drift
## in six seconds, gone) is in the PR, not in CI.
extends GutTest

const PAD_ACTION := &"input_move_left"
const KEY_ACTION := &"input_traverse"

var _rebinder: InputRebinder
var _saved: Dictionary = {}


func before_each() -> void:
	_saved.clear()
	for name: StringName in InputActions.all_action_names():
		if InputMap.has_action(name):
			_saved[name] = InputMap.action_get_events(name).duplicate()
	_rebinder = InputRebinder.new()


func after_each() -> void:
	for name: StringName in _saved:
		InputMap.action_erase_events(name)
		for event: InputEvent in _saved[name]:
			InputMap.action_add_event(name, event)


func _joypad_events(name: StringName) -> Array:
	var out: Array = []
	for event: InputEvent in InputMap.action_get_events(name):
		if event is InputEventJoypadMotion or event is InputEventJoypadButton:
			out.append(event)
	return out


func test_the_shipped_map_binds_every_device() -> void:
	# The premise. If `project.godot` ever stopped shipping `device: -1`, every
	# assertion below would still pass while testing nothing.
	var events := _joypad_events(PAD_ACTION)
	assert_gt(events.size(), 0, "%s has no joypad binding to restrict" % PAD_ACTION)
	assert_eq(int(events[0].device), -1, "the shipped binding is no longer wildcarded")


func test_restricting_moves_every_joypad_binding_to_that_device() -> void:
	_rebinder.restrict_pad_device(3)
	for name: StringName in InputActions.all_action_names():
		for event: InputEvent in _joypad_events(name):
			assert_eq(int(event.device), 3, "%s still answers another device" % name)


func test_keyboard_and_mouse_bindings_are_untouched() -> void:
	var before := InputMap.action_get_events(KEY_ACTION).size()
	_rebinder.restrict_pad_device(PadSelection.NO_DEVICE)
	var keys := 0
	for event: InputEvent in InputMap.action_get_events(KEY_ACTION):
		if event is InputEventKey or event is InputEventMouseButton:
			keys += 1
	assert_gt(keys, 0, "restricting the pad unbound the keyboard")
	assert_eq(InputMap.action_get_events(KEY_ACTION).size(), before, "an event was lost")


func test_no_device_leaves_the_bindings_in_place_but_unreachable() -> void:
	# The bindings must survive: a pad plugged in later has to be able to claim
	# them. Erasing them instead would make hot-plugging silently do nothing.
	_rebinder.restrict_pad_device(PadSelection.NO_DEVICE)
	var events := _joypad_events(PAD_ACTION)
	assert_gt(events.size(), 0, "the joypad binding was erased rather than parked")
	assert_eq(int(events[0].device), PadSelection.NO_DEVICE)


func test_a_reset_does_not_restore_the_wildcard() -> void:
	# **THE REGRESSION THIS FILE EXISTS FOR.** `reset()` restores what
	# `project.godot` shipped, and what it shipped is the bug. An options screen
	# offering "restore defaults" would hand the pedals the camera back.
	_rebinder.restrict_pad_device(PadSelection.NO_DEVICE)
	_rebinder.reset_all()
	for event: InputEvent in _joypad_events(PAD_ACTION):
		assert_eq(int(event.device), PadSelection.NO_DEVICE, "reset re-wildcarded the pad")


func test_restricting_twice_is_stable() -> void:
	var before := InputMap.action_get_events(PAD_ACTION).size()
	_rebinder.restrict_pad_device(1)
	_rebinder.restrict_pad_device(1)
	assert_eq(InputMap.action_get_events(PAD_ACTION).size(), before, "events were duplicated")
	assert_eq(_rebinder.pad_device(), 1)
