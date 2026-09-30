## **THE COMPASS, AS PICTURES.** UI_UX_SPEC §3, US-0072, US-0105.
##
## `hud_probe.tscn`'s boot, refusal and capture, with the Compass's own diagnostics:
## the cone's direction and width (moved here from `hud_probe.gd` when that file
## reached the length limit), and **up, down and in sight**, which US-0105 added to
## the ground ring. Each answers one yes-or-no question a busy frame cannot.
##
## Run it **windowed**, like `hud_probe`:
##
##     godot --path . res://tools/compass_probe.tscn
##
## Writes `user://hud_*.png`, numbered after `hud_probe`'s so both sets can sit
## side by side.
extends "res://tools/hud_probe.gd"

## 55 m, the narrowest arc. The direction frames used 10 m until US-0105 — inside
## the full-ring radius since 2026-08-27, so they drew a ring that pointed nowhere.
const FAR_BUCKET := 110


## **THE CAMERA IS UNHOOKED FIRST.** The cone is camera-relative, so a world bearing
## of zero points straight up only when the camera's yaw is also zero — and the
## client scene's rig is not. The first version of `hud_probe` drew the cone
## pointing down without this and read exactly like a widget inverted by pi.
func _capture() -> void:
	_hud.camera = null
	_hud.compass_vm.camera_yaw = 0.0
	EventBus.suspicion_tier_changed.emit(SuspicionMath.Tier.ANONYMOUS, SuspicionSources.NONE)
	EventBus.kill_ready_changed.emit(false, false)
	await _capture_cone_diagnostics()
	await _capture_up_down_and_sight()


## One Compass reading on the bus — the path a snapshot drives.
func _compass(bearing: float, bucket: int, vertical: int = 0, sight: bool = false) -> void:
	EventBus.compass_updated.emit(bearing, bucket, 0.0, vertical, sight)


## **THE TWO THAT ISOLATE THE CONE.** `hud_probe` shows the HUD as a player meets
## it; these answer one question with a yes or a no, which the busy frames
## cannot — the first version of this probe read a cone pointing *down* off a
## crowded capture and called the widget inverted. It was the camera's yaw.
func _capture_cone_diagnostics() -> void:
	# **A CONE ALONE, POINTING STRAIGHT AHEAD.** No lock arc to be mistaken for it,
	# and a bearing of exactly zero, so "is it drawn where it is aimed" has a
	# yes-or-no answer instead of an argument about which blob is which.
	#
	# **THE CAMERA IS UNHOOKED FIRST, AND THE FIRST VERSION OF THIS PROBE WAS WRONG
	# WITHOUT IT.** The cone is *camera-relative*, so a world bearing of zero points
	# straight up only when the camera's yaw is also zero — and the client scene's
	# rig is not. It drew the cone pointing **down** and read exactly like a widget
	# inverted by pi. The widget was right; the expectation was not.
	await _state(
		"07_cone_straight_ahead",
		"Bearing 0: the cone MUST point straight UP from the centre dot. No lock arc.",
		func() -> void:
			EventBus.suspicion_tier_changed.emit(
				SuspicionMath.Tier.ANONYMOUS, SuspicionSources.NONE
			)
			_compass(0.0, FAR_BUCKET)
			EventBus.kill_ready_changed.emit(false, false)
	)
	# **A CONTRACT ON THE PLAYER'S RIGHT IS BEARING MINUS 90, NOT PLUS.** This game's
	# yaw increases toward a turn to the LEFT, so +Z rotated by +90 degrees is +X,
	# which is the player's left shoulder. Getting this label the wrong way round
	# would turn the one diagnostic that catches a mirrored cone into one that
	# demands the mirror.
	await _state(
		"08_cone_quarter_right",
		"A contract on the player's RIGHT: the cone MUST point RIGHT. Left means a mirror.",
		func() -> void: _compass(-PI * 0.5, FAR_BUCKET)
	)
	await _capture_the_arc_widening()


## **THE SECOND PROXIMITY CHANNEL, WHICH A SINGLE FRAME CANNOT SHOW AT ALL.** The
## arc covers a constant patch of ground, so it widens as the contract closes and
## becomes a whole ring at `CompassMath.full_ring_distance`. Three frames at one
## bearing is the only way to see that it is a *sequence* rather than three
## unrelated shapes.
func _capture_the_arc_widening() -> void:
	var frames: Array = [
		["09_wide_far", 110, "55 m: 15 deg. The NARROWEST the arc ever gets, and clearly aimed."],
		["10_wide_near", 60, "30 m: 66 deg. Four times as wide, and still pointing."],
		["11_wide_ring", 40, "20 m: a COMPLETE RING, evenly lit. It has stopped saying which way."],
	]
	for frame: Array in frames:
		await _state(str(frame[0]), str(frame[2]), func() -> void: _compass(0.0, int(frame[1])))


## **UP, DOWN AND IN SIGHT** (US-0105, ADR-0024). The reference writes *up* and
## *down* at its ring's centre with a chevron, and lights the whole disc while its
## target can be seen. At 55 m, so the cone is narrow and the centre is clear.
func _capture_up_down_and_sight() -> void:
	await _state(
		"24_up",
		"A chevron POINTING UP above the word UP, upright, at the ring's centre.",
		func() -> void: _compass(0.0, FAR_BUCKET, CompassBoard.Vertical.UP)
	)
	await _state(
		"25_down",
		"A chevron POINTING DOWN below the word DOWN. Nothing else changed.",
		func() -> void: _compass(0.0, FAR_BUCKET, CompassBoard.Vertical.DOWN)
	)
	await _state(
		"26_in_sight",
		"The WHOLE DISC lit, with a bright rim; the cone still readable on top of it.",
		func() -> void: _compass(0.0, FAR_BUCKET, CompassBoard.Vertical.LEVEL, true)
	)
	await _state(
		"27_in_sight_up",
		"Lit AND up: both at once, and the word still legible over the glow.",
		func() -> void: _compass(0.0, FAR_BUCKET, CompassBoard.Vertical.UP, true)
	)


func _report() -> void:
	print("")
	for line: String in _shots:
		print("  ", line)
	print("")
	print("LOOK FOR: 07 up, 08 right; 09-11 one arc opening; 24/25 chevrons pointing the way")
	print("their words say, upright and unsquashed; 26/27 the disc lit without hiding the cone.")
