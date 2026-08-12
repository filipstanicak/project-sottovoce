## Applies rebinds to the engine's `InputMap`, and refuses the ones the design
## forbids. GDD-02 §1.4.
##
## **THE ONLY FILE THAT WRITES `InputMap`.** The rules it enforces are not here —
## they are in `InputActions`, pure, where a unit test can exercise them without
## an engine. This file is the seam, and a seam should be too thin to hide a bug.
##
## It also applies `PadSelection` — which physical device the joypad bindings
## answer to. That is here rather than in `InputSampler` for one reason: it is a
## write to `InputMap`, and a second file writing that map is how the two
## disagree. The *policy* is pure and lives elsewhere; this is still only a seam.
##
## Rebinds do NOT persist across sessions in MVP. They are stored through
## `IProfileStore`, which is a no-op stub (ASM-0026), and this is a known,
## accepted limitation — the first thing a real profile store fixes. What
## `reset()` restores is the map as `project.godot` declared it at boot, captured
## here before anything can have changed it.
class_name InputRebinder
extends RefCounted

## action name -> the events `project.godot` shipped. Captured once; the engine's
## map is mutable and cannot be its own baseline.
var _defaults: Dictionary = {}

## Which physical device the joypad bindings are restricted to. `PadSelection`
## decides; this file only applies it, and remembers it so a `reset()` cannot
## quietly restore the shipped `device: -1` and let a pedal set drive again.
var _pad_device := PadSelection.NO_DEVICE


func _init() -> void:
	capture_defaults()


## Snapshot the shipped map. Call before applying any stored rebind.
func capture_defaults() -> void:
	_defaults.clear()
	for name: StringName in InputActions.all_action_names():
		if InputMap.has_action(name):
			_defaults[name] = InputMap.action_get_events(name).duplicate()


## Replace `id`'s binding, or refuse.
##
## Returns false and changes NOTHING when the action is not rebindable, or when
## the binding would collide with one it may never share (`InputActions.
## EXCLUSIVE_PAIRS`). The UI calls this and reports the refusal — GDD-02 §1.4
## permits duplicate bindings with a warning everywhere except here.
func rebind(id: StringName, event: InputEvent) -> bool:
	if not InputActions.may_bind(id, binding_key(event), _holders()):
		return false
	var name := InputActions.action_names(id)[0]
	if not InputMap.has_action(name):
		return false
	InputMap.action_erase_events(name)
	InputMap.action_add_event(name, event)
	return true


## Which other actions this binding would collide with, for the message the UI
## shows. Empty when the rebind is allowed.
func conflicts_for(id: StringName, event: InputEvent) -> Array:
	return InputActions.forbidden_conflicts(id, binding_key(event), _holders())


## Point every joypad binding at one device, so no other device can reach an
## action. `PadSelection` explains why this exists at all.
##
## The events are DUPLICATED rather than edited in place: `_defaults` holds the
## same object references the map does, and mutating one would rewrite the
## baseline `reset()` restores to.
func restrict_pad_device(device: int) -> void:
	_pad_device = device
	for name: StringName in InputActions.all_action_names():
		_apply_pad_device(name)


func pad_device() -> int:
	return _pad_device


func _apply_pad_device(name: StringName) -> void:
	if not InputMap.has_action(name):
		return
	for event: InputEvent in InputMap.action_get_events(name):
		if not (event is InputEventJoypadMotion or event is InputEventJoypadButton):
			continue
		if event.device == _pad_device:
			continue
		var moved := event.duplicate()
		moved.device = _pad_device
		InputMap.action_erase_event(name, event)
		InputMap.action_add_event(name, moved)


## Restore one action to what `project.godot` shipped — then re-apply the device
## restriction, because what it shipped is `device: -1` and that is the bug.
func reset(id: StringName) -> void:
	for name: StringName in InputActions.action_names(id):
		if not _defaults.has(name):
			continue
		InputMap.action_erase_events(name)
		for event: InputEvent in _defaults[name]:
			InputMap.action_add_event(name, event)
		_apply_pad_device(name)


func reset_all() -> void:
	for id: StringName in InputActions.ids():
		reset(id)


## The current binding of every single-event action, as comparison keys.
func _holders() -> Dictionary:
	var out: Dictionary = {}
	for id: StringName in InputActions.ids():
		if InputActions.kind_of(id) == InputActions.Kind.AXIS:
			continue
		var name := InputActions.action_names(id)[0]
		if not InputMap.has_action(name):
			continue
		var events := InputMap.action_get_events(name)
		out[id] = "" if events.is_empty() else binding_key(events[0])
	return out


## A comparable identity for an event. `InputEvent` is compared by reference, so
## two `Left Mouse Button` events are not equal to each other — which would make
## the kill/stun rule silently never fire.
static func binding_key(event: InputEvent) -> String:
	return "" if event == null else event.as_text()
