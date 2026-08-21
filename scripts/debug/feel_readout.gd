## The M1 feel-gate readout. US-0024, GDD-02 §5.
##
## **IT TELLS YOU WHAT YOU CANNOT FEEL, AND NOTHING ELSE.** Which state you were
## in, what the lens is doing, and how many of your last ten traverse presses
## resolved. It does **not** say whether slowing down felt instant — that is the
## judgement the gate is asking for, and a readout that answered it would replace
## the thing being measured with a number about the thing being measured.
##
## **STRIPPED FROM RELEASE, AND NOT REFERENCED BY ANY SCENE.** The three release
## presets exclude `scripts/debug/*`, so a `.tscn` naming this file would export a
## scene pointing at a script that is not there. `LocalPawnDriver` loads it at
## runtime instead, behind `OS.has_feature("debug")` and an existence check, and
## `test_no_scene_references_debug.gd` keeps it that way.
##
## Literals are allowed here. `test_no_literal_strings.gd` scans every layer
## except this one, deliberately: nothing below is ever shown to a player, so it
## is not part of the vocabulary `data/strings/en.csv` exists to hold.
extends CanvasLayer

## How many traverse attempts to remember. Ten, because the feel gate asks for
## ten deliberately sloppy vaults and counting them in your head while making
## them is the part that goes wrong.
const HISTORY := 10

var _driver: LocalPawnDriver
var _label: Label
var _outcomes: Array[bool] = []
var _was_held: bool = false
var _awaiting: bool = false


## Built by `LocalPawnDriver`, which emits **both** halves of what this displays.
## Not an `@export` on a scene node, for the export reason above.
##
## It took an `InputSampler` too until the double-sample fix (trap 12): the
## command came off `InputSampler.command_sampled` and the step off the driver.
## The sampler no longer emits anything — it is a service the driver calls once a
## frame — so there is one source here now, which is the point of that change.
static func attach(to: Node, driver: LocalPawnDriver) -> Node:
	var readout: CanvasLayer = (load("res://scripts/debug/feel_readout.gd") as GDScript).new()
	readout._driver = driver
	to.add_child(readout)
	return readout


func _ready() -> void:
	layer = 128
	_label = Label.new()
	# **CLEAR OF THE DISTRICT MAP**, which owns the top-left corner in debug builds.
	# Overlapping it made both unreadable: the text has no background and the map is
	# opaque, so whichever drew second won.
	_label.position = Vector2(DistrictMap.RESERVED_WIDTH, 12)
	_label.add_theme_font_size_override("font_size", 15)
	_label.add_theme_color_override("font_color", Color(0.85, 0.95, 1.0))
	_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_label.add_theme_constant_override("outline_size", 6)
	add_child(_label)
	if _driver != null:
		_driver.pawn_stepped.connect(_on_pawn_stepped)
		_driver.command_sampled.connect(_on_command_sampled)


## The press, read off the sampled command rather than off `Input` — the sampler
## is the only place that polls the device, and a debug node reaching past it
## would make that claim untrue. It would also poll it a second time, which is
## exactly the defect trap 12 records.
##
## **NOT off `ctx.traverse_buffer_ticks`**, which was the obvious idea and is
## always zero by the time anyone else can look: `PawnInputBuffer.tick()` arms the
## buffer and `TraversalResolver.resolve()` consumes it inside the same `step()`.
func _on_command_sampled(command: InputCommand) -> void:
	if command.traverse and not _was_held:
		_awaiting = true
	_was_held = command.traverse


## The outcome, one step later. A press resolves the tick it lands or not at all
## once the buffer is spent — and the gap between them IS the forgiveness window,
## which is worth watching go by.
func _on_pawn_stepped(ctx: PawnContext) -> void:
	if _awaiting:
		_record(_is_traversing(ctx))


func _record(resolved: bool) -> void:
	_awaiting = false
	_outcomes.append(resolved)
	if _outcomes.size() > HISTORY:
		_outcomes.remove_at(0)


static func _is_traversing(ctx: PawnContext) -> bool:
	return (
		ctx.state_id == PawnStateId.VAULT
		or ctx.state_id == PawnStateId.CLIMB
		or ctx.state_id == PawnStateId.DROP
	)


func _process(_delta: float) -> void:
	if _driver == null or _label == null:
		return
	var ctx := _driver.ctx
	var flat := Vector3(ctx.velocity.x, 0.0, ctx.velocity.z).length()
	var camera := get_viewport().get_camera_3d()
	var lines: PackedStringArray = [
		"STATE   %s" % ctx.state_id,
		"SPEED   %5.2f m/s%s" % [flat, "" if ctx.grounded else "   (airborne)"],
		"LENS    %5.1f deg" % (camera.fov if camera != null else 0.0),
		"HEIGHT  %5.2f m" % ctx.position.y,
		"",
		"TRAVERSE  %s" % _tally(),
		"          %d of %d resolved" % [_resolved(), _outcomes.size()],
	]
	_label.text = "\n".join(lines)


## The last ten attempts, oldest first. A dot is a press that produced nothing.
func _tally() -> String:
	var out := ""
	for ok: bool in _outcomes:
		out += "#" if ok else "."
	return out if not out.is_empty() else "(press Space at something)"


func _resolved() -> int:
	var n := 0
	for ok: bool in _outcomes:
		if ok:
			n += 1
	return n
