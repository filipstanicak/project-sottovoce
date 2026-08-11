## Print every connected joypad and its live stick values, then quit.
##
##     godot --headless --path <project> -s res://tools/list_joypads.gd
##
## **WRITTEN BECAUSE THE CAMERA SPUN AND NOTHING IN THE CODE DID IT.** Look is
## bound to right-stick axes 2 and 3 (`INPUT-LOOK`), so anything Windows presents
## as a gamepad — a real pad, a wheel, a flight stick, Steam Input's virtual
## device, DS4Windows — turns stick drift into a camera that rotates forever with
## nobody touching it.
##
## `TUN-SPEED-STICK-DEADZONE` is 0.15, so a resting axis reading above that is
## the answer. The fix is not in this repository: unplug it, or raise the
## deadzone knowing what that costs a player using the pad deliberately.
extends SceneTree


func _initialize() -> void:
	var pads := Input.get_connected_joypads()
	print("connected joypads: %d" % pads.size())
	if pads.is_empty():
		print("  none — a spinning camera is NOT coming from a stick")
		quit()
		return
	for id: int in pads:
		print("  [%d] %s (%s)" % [id, Input.get_joy_name(id), Input.get_joy_guid(id)])
	print("")
	print("resting axis values — anything past %.2f is drift the game will act on:" % _deadzone())
	for id: int in pads:
		for axis: int in [JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y, JOY_AXIS_RIGHT_X, JOY_AXIS_RIGHT_Y]:
			var value := Input.get_joy_axis(id, axis)
			var flag := "  <-- past the deadzone" if absf(value) > _deadzone() else ""
			print("  [%d] axis %d: %+0.3f%s" % [id, axis, value, flag])
	quit()


## Read straight from the resource: this script runs as a `SceneTree` with no
## autoloads, so `Tuning` does not exist here.
func _deadzone() -> float:
	var profile := load("res://data/tuning/default/profile.tres") as TuningProfile
	return 0.15 if profile == null else profile.movement.stick_deadzone
