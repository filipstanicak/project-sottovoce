## Applies rebinds to the engine's `InputMap`, and refuses the ones the design
## forbids. GDD-02 §1.4.
##
## **THE ONLY FILE THAT WRITES `InputMap`.** The rules it enforces are not here —
## they are in `InputActions`, pure, where a unit test can exercise them without
## an engine. This file is the seam, and a seam should be too thin to hide a bug.
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


## Restore one action to what `project.godot` shipped.
func reset(id: StringName) -> void:
	for name: StringName in InputActions.action_names(id):
		if not _defaults.has(name):
			continue
		InputMap.action_erase_events(name)
		for event: InputEvent in _defaults[name]:
			InputMap.action_add_event(name, event)


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
