## Print what the input layer reports with nobody touching the controls.
##
##     <godot> --path <project> -s res://tools/input_probe.gd
##
## **NEVER WITH `--headless`, AND THIS REPLACED A TOOL THAT WAS.** Its
## predecessor read `Input.get_connected_joypads()` once, at frame zero, under
## the headless display server, and printed "none — a spinning camera is NOT
## coming from a stick". Two things independently make that zero worthless:
## headless has no windowing layer and so nothing polling for pads, and
## enumeration takes a frame or two even where there is. The reading may well
## have been correct; it was not *evidence*, and it was phrased as proof. Same
## family as trap 3 — a check reporting clean over zero items. This one refuses
## to run where it cannot see, and polls instead of glancing.
##
## It polls for twelve seconds because pads enumerate a frame or two late, and it
## captures the mouse half way through, because the two suspects behave
## differently: a drifting stick reports the same phantom before and after, while
## a capture that generates its own motion only starts at the switch.
##
## Hands off the keyboard and mouse for the whole run. Anything it prints is
## something the game would have acted on.
extends Node

## Long enough for a pad to enumerate, short enough to sit through.
const SECONDS := 12.0
const CAPTURE_AT := 6.0
const INTERVAL := 0.5


## **A SCENE, NOT A `-s` SCRIPT — AND THIS TOOL COULD NOT LOAD AT ALL UNTIL
## 2026-09-05.** A `-s` script is compiled before the autoloads are registered, so
## `Tuning` is unresolvable; `CompassMath` reads it, `TuningInvariants` calls
## `CompassMath` for invariant 33, `TuningProfile` calls `TuningInvariants` — and
## `_deadzone()` below names `TuningProfile`. The whole chain failed to compile and
## took this file with it:
##
##     compass_math.gd:130   Identifier not found: Tuning
##     tuning_invariants.gd  Failed to compile depended scripts
##     tuning_profile.gd     Failed to compile depended scripts
##     input_probe.gd        Failed to compile depended scripts
##
## **It broke on 2026-08-27**, when invariant 33 put `CompassMath` into the
## profile's dependency chain — and nothing said so, because a tool that cannot
## load prints an engine error and no output of its own, which reads as the tool
## having nothing to report. Trap 14's shape: a documented command that does not
## run. `--headless` is still refused below, for its own separate reason (trap 13).
func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		print("REFUSING TO RUN HEADLESS.")
		print("  There is no windowing layer here to poll a pad or deliver mouse")
		print("  motion, so every reading below would be a zero that proves nothing.")
		print("  Re-run without --headless and keep the window focused.")
		get_tree().quit(1)
		return
	add_child(Probe.new())


## The probe itself, a node because `_input` needs one — mouse motion arrives as
## events, and polling `get_last_mouse_velocity()` would smooth away exactly the
## per-frame delta the sampler accumulates.
class Probe:
	extends Node

	var _elapsed := 0.0
	var _next := 0.0
	var _captured := false
	var _motion := Vector2.ZERO
	var _events := 0
	var _phantom_move := false
	var _phantom_look := false
	var _phantom_mouse_free := false
	var _phantom_mouse_captured := false

	func _input(event: InputEvent) -> void:
		var motion := event as InputEventMouseMotion
		if motion != null:
			_motion += motion.relative
			_events += 1

	func _process(delta: float) -> void:
		_elapsed += delta
		if not _captured and _elapsed >= CAPTURE_AT:
			_capture()
		if _elapsed >= _next:
			_report()
			_next += INTERVAL
		if _elapsed >= SECONDS:
			_verdict()
			get_tree().quit()

	func _capture() -> void:
		_captured = true
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		_motion = Vector2.ZERO
		_events = 0
		print("")
		print("--- mouse captured, as the game captures it on boot ---")

	func _report() -> void:
		var move := _vector(InputActions.action_names(Ids.INPUT_MOVE))
		var look := _vector(InputActions.action_names(Ids.INPUT_LOOK))
		var pads := Input.get_connected_joypads()
		print(
			(
				"t=%5.1f  mouse=%s  focus=%s  pads=%d  move=(%+0.3f,%+0.3f)  look=(%+0.3f,%+0.3f)"
				% [
					_elapsed,
					"held" if _captured else "free",
					"yes" if DisplayServer.window_is_focused() else "NO",
					pads.size(),
					move.x,
					move.y,
					look.x,
					look.y
				]
			)
		)
		_report_mouse()
		_report_held()
		_record(move, look)
		for id: int in pads:
			print("        pad [%d] %s" % [id, Input.get_joy_name(id)])

	func _report_mouse() -> void:
		if _events == 0:
			_motion = Vector2.ZERO
			return
		print("        mouse: %d events, %+0.1f,%+0.1f px" % [_events, _motion.x, _motion.y])
		if _captured:
			_phantom_mouse_captured = true
		else:
			_phantom_mouse_free = true
		_motion = Vector2.ZERO
		_events = 0

	## Name every action carrying strength, so a stuck key is identified rather
	## than inferred from a nonzero vector.
	func _report_held() -> void:
		for name: StringName in InputActions.all_action_names():
			var strength := Input.get_action_strength(name)
			if strength > 0.0:
				print("        HELD %s %.2f" % [name, strength])

	func _record(move: Vector2, look: Vector2) -> void:
		var gate := _deadzone()
		if move.length() > gate:
			_phantom_move = true
		if look.length() > gate:
			_phantom_look = true

	func _vector(names: Array[StringName]) -> Vector2:
		return Input.get_vector(names[0], names[1], names[2], names[3], _deadzone())

	## Straight from the resource rather than through `Tuning`, which is now a
	## preference rather than a necessity: this was a `-s` script when it was
	## written, and the note here said the autoloads arrive too late to rely on.
	## **That reasoning is what broke the tool** — naming `TuningProfile` at all is
	## what pulled the uncompilable chain in. As a scene either route works, and the
	## resource is kept because a diagnostic that reads the shipped file rather than
	## the running profile is the one you want when the two might disagree.
	func _deadzone() -> float:
		var profile := load("res://data/tuning/default/profile.tres") as TuningProfile
		return 0.15 if profile == null else profile.movement.stick_deadzone

	func _verdict() -> void:
		print("")
		print("--- what this run found, with nobody touching anything ---")
		_line(_phantom_move, "MOVE reported past the deadzone. The pawn would walk on its own.")
		_line(_phantom_look, "LOOK reported past the deadzone. The camera would turn forever.")
		_line(_phantom_mouse_free, "mouse motion arrived with the cursor free.")
		_line(
			_phantom_mouse_captured and not _phantom_mouse_free,
			"mouse motion arrived ONLY once captured — the capture is generating it."
		)
		_line(
			_phantom_mouse_captured and _phantom_mouse_free,
			"mouse motion arrived throughout — something outside the game moves the cursor."
		)
		if not (_phantom_move or _phantom_look or _phantom_mouse_free or _phantom_mouse_captured):
			print("  nothing. The input layer is quiet, so a spin in the game is OUR code.")

	func _line(found: bool, text: String) -> void:
		if found:
			print("  " + text)
