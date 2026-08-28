## **ONE KEY TURNS EVERY DEBUG OVERLAY OFF.** `F3`. DEBUG BUILDS ONLY.
##
## Four overlays have accumulated — the feel readout, the netcode readout, the
## district map and the world tint that goes with it — and together they cover the
## top-left quarter of the screen and repaint the whole district. Every one of them
## exists because somebody needed to read a number while playing, and all four at
## once make the game itself hard to look at. The HUD this project spent US-0072
## and US-0073 building is drawn *underneath* them.
##
## **IT IS A RAW KEY AND DELIBERATELY NOT AN `InputMap` ACTION.** Every `INPUT-`
## id is harvested from `docs/` and guarded in both directions by
## `test_input_actions_match_the_docs.gd`; adding one for a debug toggle would put
## a developer convenience into the game's published control scheme, where it would
## need a GDD row, a rebinding entry and an accessibility consideration. Debug code
## reading a physical key is the honest version, and `scripts/debug/` is excluded
## from all three release presets so it cannot reach a player.
##
## **F3 BECAUSE IT IS WHAT EVERYBODY ELSE USES** for exactly this, and because the
## function row is empty here: the game binds WASD, Shift, Ctrl, Space, the mouse
## and Escape, so there is nothing to collide with.
class_name DebugOverlays
extends Node

const TOGGLE_KEY := KEY_F3

## Where the overlays live, and the only prefix this will touch. A node from
## anywhere else is somebody else's and is left alone.
const DEBUG_PREFIX := "res://scripts/debug/"

var _shown: bool = true


## Attached last, after the overlays it toggles, so its first `_gather` finds all
## of them. **Attached to the same node they are**, which is what makes them
## siblings and lets this find them without a path.
static func attach(to: Node) -> Node:
	var node: Node = (load("res://scripts/debug/debug_overlays.gd") as GDScript).new()
	node.name = "DebugOverlays"
	to.add_child(node)
	return node


func is_shown() -> bool:
	return _shown


## **`_unhandled_key_input`, NOT `_input`.** The mouse is captured and the HUD
## consumes nothing, so either would work today — but a menu that appears later
## must be able to swallow the key before it reaches a debug toggle, and only the
## unhandled path gives it that chance.
func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo or key.keycode != TOGGLE_KEY:
		return
	toggle()
	get_viewport().set_input_as_handled()


func toggle() -> void:
	set_shown(not _shown)


## **THE WORLD TINT IS PART OF THE OVERLAY, WHICH IS WHY THIS IS NOT JUST
## `visible`.** `DistrictMap` repaints every street floor with a flat hue so the
## map's colours mean something, and hiding a `CanvasLayer` would leave the
## district still painted — a half-off debug view is more confusing than a fully
## on one. Any overlay that has more to undo than its own visibility says so by
## offering `set_overlay_shown`.
func set_shown(shown: bool) -> void:
	_shown = shown
	for node: Node in _overlays():
		if node.has_method(&"set_overlay_shown"):
			node.call(&"set_overlay_shown", shown)
		elif node is CanvasLayer:
			(node as CanvasLayer).visible = shown
	Log.info("debug overlays %s (F3)" % ("shown" if shown else "hidden"), &"debug")


## Every sibling drawn by a script under `scripts/debug/`. **Found by script path
## rather than by a list**, so an overlay added later is toggled without anybody
## remembering to add it here — which is the mistake the fourth overlay would make.
func _overlays() -> Array[Node]:
	var found: Array[Node] = []
	var parent := get_parent()
	if parent == null:
		return found
	for node: Node in parent.get_children():
		if node == self:
			continue
		var script := node.get_script() as GDScript
		if script != null and script.resource_path.begins_with(DEBUG_PREFIX):
			found.append(node)
	return found
