## ARCHITECTURE GUARD — do not weaken. See test/arch/README.md.
##
## Every action GDD-02 §1.2 and §1.3 declares is actually BOUND, on keyboard and
## on gamepad, and nothing is bound that no document describes.
##
## Why review misses this: an unbound action is not an error in Godot. It is a
## name `Input.is_action_pressed` will happily answer `false` to, forever. The
## symptom is a key that does nothing, discovered in a playtest, blamed on the
## state machine, and traced back here an hour later.
##
## The chain is GDD-02 -> `Ids` -> `InputActions` -> `project.godot`, and every
## hop has a guard. This file is the last one. It reads `project.godot` as TEXT
## rather than asking `InputMap`, because `InputMap` is mutable at runtime and a
## rebind applied during boot would make the check pass against something the
## repository does not contain.
extends GutTest

const PROJECT := "res://project.godot"

## Bindings are `Object(InputEventKey, ...)` and friends. The engine ones a
## keyboard or mouse can produce, and the ones a pad can.
const KBM_EVENTS: Array[String] = ["InputEventKey", "InputEventMouseButton"]
const PAD_EVENTS: Array[String] = ["InputEventJoypadButton", "InputEventJoypadMotion"]


## action name -> the text of its `{...}` block in `project.godot`.
func _blocks() -> Dictionary:
	var text := SourceScanner.read(PROJECT)
	var out: Dictionary = {}
	# (?m) so ^ anchors each line, (?s) so the block may span them.
	var re := RegEx.create_from_string("(?ms)^(input_[a-z0-9_]+)=\\{(.*?)^\\}")
	for m: RegExMatch in re.search_all(text):
		out[StringName(m.get_string(1))] = m.get_string(2)
	return out


func test_the_scan_found_the_input_section() -> void:
	# Guards the guard. A regex that stopped matching would make every assertion
	# below pass over an empty dictionary and report success.
	assert_gt(_blocks().size(), 15, "the project.godot [input] scan matched almost nothing")


func test_every_declared_action_is_bound() -> void:
	var blocks := _blocks()
	var missing: PackedStringArray = []
	for name: StringName in InputActions.all_action_names():
		if not blocks.has(name):
			missing.append(String(name))
	missing.sort()
	assert_eq(
		missing.size(),
		0,
		(
			"An action InputActions declares has no binding in project.godot.\n"
			+ "Godot answers `false` to an unbound action forever; nothing errors.\n"
			+ "\n".join(missing)
		)
	)


func test_nothing_is_bound_that_is_not_declared() -> void:
	# The more dangerous direction: a binding for an action no document describes
	# is a control the player can press that nobody designed.
	var declared: Dictionary = {}
	for name: StringName in InputActions.all_action_names():
		declared[name] = true

	var strays: PackedStringArray = []
	for name: StringName in _blocks():
		if not declared.has(name):
			strays.append("%s (%s)" % [name, InputActions.id_from_action_name(name)])
	strays.sort()
	assert_eq(strays.size(), 0, "project.godot binds an undeclared action:\n" + "\n".join(strays))


func test_every_action_has_a_keyboard_or_mouse_binding() -> void:
	# GDD-02 §1.2 is a complete table. `INPUT-LOOK` is the exception: mouse motion
	# is not an InputMap event, so its four actions carry the pad stick only and
	# the mouse is read directly by the sampler.
	var missing: PackedStringArray = []
	for name: StringName in _blocks():
		if String(name).begins_with("input_look_"):
			continue
		if not _has_any(_blocks()[name], KBM_EVENTS):
			missing.append(String(name))
	missing.sort()
	assert_eq(missing.size(), 0, "no keyboard/mouse binding for: " + ", ".join(missing))


func test_every_action_has_a_gamepad_binding() -> void:
	# GDD-02 §1.3 is also a complete table, and a pad missing one action is a pad
	# that cannot play the game.
	var missing: PackedStringArray = []
	for name: StringName in _blocks():
		if not _has_any(_blocks()[name], PAD_EVENTS):
			missing.append(String(name))
	missing.sort()
	assert_eq(missing.size(), 0, "no gamepad binding for: " + ", ".join(missing))


func test_kill_and_stun_do_not_ship_sharing_a_binding() -> void:
	# The one collision the design forbids outright (GDD-02 §1.4). `InputActions`
	# refuses it at rebind time; this asserts the SHIPPED map does not already
	# violate it, which no runtime rule would ever catch.
	var kill := _events_of(&"input_kill")
	var stun := _events_of(&"input_stun")
	assert_gt(kill.size(), 0, "input_kill is not bound")
	assert_gt(stun.size(), 0, "input_stun is not bound")

	var shared: PackedStringArray = []
	for event: String in kill:
		if stun.has(event):
			shared.append(event)
	assert_eq(shared.size(), 0, "kill and stun ship sharing:\n" + "\n".join(shared))


## Each `Object(...)` binding in an action's block, whole. Compared whole and not
## by substring: `"button_index":1` is a prefix of `"button_index":10`, and a
## check that missed that would call the left mouse button the same as R1.
func _events_of(name: StringName) -> Array:
	var block: String = _blocks().get(name, "")
	var out: Array = []
	var re := RegEx.create_from_string("Object\\([^)]*\\)")
	for m: RegExMatch in re.search_all(block):
		out.append(m.get_string())
	return out


func test_the_deadzone_does_not_clamp_the_tunable() -> void:
	# `TUN-SPEED-STICK-DEADZONE` is the authority (InputSampler applies it). An
	# action deadzone above it would silently swallow the tunable's lower range,
	# and lowering the tunable would appear to do nothing.
	var offenders: PackedStringArray = []
	var re := RegEx.create_from_string('"deadzone": ([0-9.]+)')
	for name: StringName in _blocks():
		var m := re.search(_blocks()[name])
		if m == null:
			offenders.append("%s has no deadzone" % name)
		elif m.get_string(1).to_float() > Tuning.movement.stick_deadzone:
			offenders.append("%s deadzone %s > TUN-SPEED-STICK-DEADZONE" % [name, m.get_string(1)])
	offenders.sort()
	assert_eq(offenders.size(), 0, "\n".join(offenders))


func test_only_the_pause_menu_is_unrebindable() -> void:
	assert_false(InputActions.is_rebindable(Ids.INPUT_MENU))
	assert_true(InputActions.is_rebindable(Ids.INPUT_KILL))


func _has_any(block: String, classes: Array[String]) -> bool:
	for name: String in classes:
		if block.contains(name):
			return true
	return false
